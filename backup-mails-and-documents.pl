#!/usr/bin/perl -w

use strict;
#use IO::Socket::SSL qw/debug3/; # SSL Debug
use Mail::IMAPClient;
use Data::Dumper;
use File::Temp;
use POSIX qw/ strftime /;
use POSIX ":sys_wait_h";
use Getopt::Long;

my $target;
my $mail = 1;
my $docs = 0;
my $svn = 0;
GetOptions("to=s" => \$target,
           "mail" => \$mail,
           "docs" => \$docs);

die "Wrong target directory"
    unless defined $target and -d $target;

# Slup SAMBA Credentials File...
open SMB_FILE, '<', $ENV{HOME}."/.smbpasswd-z"
    or die "open: .smbpasswd-z: $!";
my $holdTerminator = $/;
undef $/;
my $credentials = <SMB_FILE>;
$/ = $holdTerminator;
my ($username, $password);
($username) = $credentials =~ m/username\s*=\s*(\S+)\s*\n/;
($password) = $credentials =~ m/password\s*=\s*(\S+)\s*\n/;
close SMB_FILE;
die "missing username in ~/.smbpasswd-z"
    unless defined $username;
die "missing password in ~/.smbpasswd-z"
    unless defined $password;

# Create temp folder to store data
my $tmp = File::Temp->newdir(CLEANUP => 0); # So that childs do not try to remove temp dir while the father is still using it...
print "Using '$tmp' as temp dir...\n";
my $imap_dir = "Backup Mails";

my $target_filename = "mail-backup-".strftime("%Y%m%d-%H%M%S", localtime).".cpio.bz2";
print "Storing backup to '$target/$target_filename'...\n";

open BACKUP, ">", "$target/$target_filename"
    or die "open: $target/$target_filename: $!";

# Launch CPIO to store data
pipe FROM_FATHER, TO_CPIO0;
pipe FROM_CPIO2, TO_DELETE;
pipe FROM_CPIO1, TO_ZIP;
my $pid_cpio = fork();
die "fork: $!" unless defined $pid_cpio;
if ($pid_cpio == 0) { # Child: CPIO
    close TO_CPIO0;
    close FROM_CPIO1;
    close FROM_CPIO2;
    close BACKUP;

    open STDIN, '<&', \*FROM_FATHER;
    open STDOUT, '>&', \*TO_ZIP;
    open STDERR, '>&', \*TO_DELETE;

    chdir $tmp
        or die "chdir: $tmp: $!";
 
    exec "cpio", "-ov"
        or die "exec: cpio: $!";

    # Child stops here
} # The father continues...

my $pid_zip = fork();
die "fork: $!" unless defined $pid_zip;
if ($pid_zip == 0) { # Child: ZIP
    close TO_ZIP;
    close TO_DELETE;
    close FROM_FATHER;
    close TO_CPIO0;
    close FROM_CPIO2;
    
    open STDIN, '<&', \*FROM_CPIO1;
    open STDOUT, '>&', \*BACKUP;

    exec "bzip2", "--compress", "--force", "--stdout"
        or die "exec: bzip2: $!";
    # Child stops here
} # The father continues...

my $pid_delete = fork();
die "fork: $!" unless defined $pid_delete;
if ($pid_delete == 0) { # Child: DELETE
    close TO_ZIP;
    close TO_DELETE;
    close FROM_FATHER;
    close TO_CPIO0;
    close FROM_CPIO1;
    close BACKUP;
   
    chdir $tmp
        or die "chdir: $tmp: $!";
 
    while (<FROM_CPIO2>) {
        chomp;

        # The goal is to free space, so we do not delete directories...
        if (-e $_) {
            if ($_ =~ m/^$imap_dir\// and -f $_) {
                print "CLEANUP: Removing useless file '$_'...\n";
                unlink $_;
            }
        } else {
            print "CPIO: $_\n";
        }
    }

    # Child stops here
    exit 0;
} # The father continues...

# Clean up...
close TO_ZIP;
close TO_DELETE;
close FROM_FATHER;
close FROM_CPIO2;
close FROM_CPIO1;
close BACKUP;

# Childs will not clean up the temp folder. The father has to do it !
$tmp->unlink_on_destroy(1);

# Avoid warning of File::Temp cleanup process...
END {
    chdir $ENV{'HOME'}; 
}

chdir $tmp
    or die "chdir: $tmp: $!";

# Backup mails
if ($mail) {
    my $imap = Mail::IMAPClient->new;
    $imap->Server('zimbra.example.test');
    $imap->Port(993);
    $imap->Ssl(1);
    $imap->Uid(1);
    $imap->Peek(1);
    $imap->connect or die "IMAP: Could not connect: $@";
    print "IMAP: Logging in as $username\n";
    $imap->User($username);
    $imap->Password($password);
    $imap->login or die "IMAP: Could not login: $@";

    my $folders = $imap->folders
        or die "IMAP: Could not list folders: $@";

    mkdir $imap_dir
        or die "mkdir: $imap_dir: $!";
    print "IMAP: Using '$tmp/$imap_dir' to backup mails...\n";

    foreach my $folder (@$folders) {
        my @components = split /\//, $folder;
        my $mbox_name = delete $components[$#components];
        my $mbox_path = "$imap_dir/";
        foreach my $component (@components) {
            unless (-e "$mbox_path$component") {
                mkdir "$mbox_path$component"
                    or die "mkdir: $mbox_path$component: $!"
            }
            $mbox_path .= "$component/";
        }

        $imap->select($folder) 
        or die "IMAP: Could not select $folder: $@";

        my $msgcount = $imap->message_count($folder);
        die "IMAP: Could not message_count: $@"
        if not defined $msgcount;

        if ($msgcount == 0) {
            print "IMAP: Skipping empty folder '$folder'...\n";
            next;
        }

        print "IMAP: Backing up $msgcount messages in '$folder'...\n";
        my @msgs = $imap->messages
            or die "IMAP: Could not messages: $@";
        
        my $mbox_file = "$mbox_path$mbox_name.mbox";
        my $mbox_fh;
        $imap->message_to_file($mbox_file, @msgs)
            or die "IMAP: Could not backup messages of folder '$folder': $@";

        # Remove \r to have a valid MBOX file.
        system("fromdos", "$mbox_file") == 0 # fromdos = dos2unix
            or warn "system: fromdos: $?";

        # Backup this file !
        print TO_CPIO0 "$mbox_file\n";
    }
    $imap->disconnect()
        or die "IMAP: Could not logout: $@";
}

# Sends filenames to CPIO
sub compress_files {
    my ($dir) = @_;
    
    my $pid = fork();
    die "fork: $!" unless defined $pid;
    if ($pid == 0) { # Child: FIND
        open STDOUT, '>&', \*TO_CPIO0;

        exec "find", "$dir", "-print"
            or die "exec: find: $!";
    }
    
    waitpid $pid, 0;
}

# Backup Own Data
if ($docs) {
    my @files = 
    (
        ".ssh/",
        ".bashrc",
        ".bash_aliases",
        ".vimrc",
        ".mozilla/",
        "Documents/",
    );
    @files = map { "home/$_" } @files;
    symlink $ENV{'HOME'}, "home"
        or die "symlink: home: $!";

    foreach my $file (@files) {
        compress_files $file;
    }
}

# No more file to backup, notify CPIO...
close TO_CPIO0;

print "FINISH: Waiting for CPIO (pid = $pid_cpio) to complete...\n";
waitpid $pid_cpio, 0;

print "FINISH: Waiting for BZIP2 (pid = $pid_zip) to complete...\n";
waitpid $pid_zip, 0;

print "FINISH: Waiting for the cleanup process (pid = $pid_delete) to complete...\n";
waitpid $pid_delete, 0;


