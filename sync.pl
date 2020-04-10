#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use File::Temp;
use POSIX qw/ strftime /;
use POSIX ":sys_wait_h";

my $sync_dir = $ENV{HOME}."/sync/";
my $doclib_path = "/path/to/products";
my $homes = "rsync.server.example.test";

sub version_compare {
    my ($a, $b) = @_;
    
    my @left  = split( /\./, $a );
    my @right = split( /\./, $b );

    my $i = 0;
    while ((defined $left[$i]) and (defined $right[$i])) {
        my $cmp = $left[$i] <=> $right[$i];
        return $cmp if $cmp;
        $i++;
    }
    return ($left[$i] || 0) <=> ($right[$i] || 0);
}

sub split_path_with_prefix {
    my ($path, $prefix) = @_;
    my ($product, $version, $file);

    if (($product, $version, $file) = $path =~ m#^${prefix}([A-Z]+)/(?:[-a-z]+[- ])?\1[- v]([0-9]+\.[0-9]+(?:\.[0-9]+)?)(/.+)?$#i) {
        return ($product, $version, $file);
    }
    return;
}

print "\n+".("-"x76)."+\n";
print "|".(" "x31)."ACME Data Sync".(" "x31)."|\n";
print "+".("-"x76)."+\n\n";


open FIND_PRODUCTS, "-|", "ssh $homes find $doclib_path -maxdepth 2 -type d"
    or die "open: ssh: $!";

my %keep = map { $_ => 1 } qw/PRODUCTA PRODUCTB PRODUCTC/;
my %available_products;

while (my $path = <FIND_PRODUCTS>) {
    chomp $path;
    my ($product, $version, $file) = split_path_with_prefix($path, $doclib_path);
    next unless defined $product and $keep{$product};
    $path = substr $path, length $doclib_path;
    $available_products{$product}->{$version} = $path;
}

close FIND_PRODUCTS;

my %remote_major_versions;
while (my ($product, $versions) = each(%available_products)) {
    my @versions = keys %{$versions};
    
    # Compute major versions
    @versions = sort {version_compare($a, $b)} @versions;
    my %versions = map { m/^([0-9]+\.[0-9]+)/; $1 => $_ } @versions;
    $remote_major_versions{$product} = \%versions;
}

my %local_versions;
open FIND_LOCAL_PRODUCTS, "-|", "find $sync_dir -maxdepth 2 -type d"
    or die "open: find: $!";
while (my $path = <FIND_LOCAL_PRODUCTS>) {
    chomp $path;
    my ($product, $version, $file) = split_path_with_prefix($path, $sync_dir);
    next unless defined $product;
    $path = substr $path, length $sync_dir;
    push @{$local_versions{$product}}, { version => $version, path => $path };
}
close FIND_LOCAL_PRODUCTS;

my %local_major_versions;
while (my ($product, $versions) = each(%local_versions)) {
    my @versions = sort {version_compare($a, $b)} map { $_->{version} } @{$versions};
    my %versions = map { m/^([0-9]+\.[0-9]+)/; $1 => $_ } @versions;
    $local_major_versions{$product} = \%versions;
}

my %upgrades;
my %new_versions;
while (my ($product, $versions) = each(%remote_major_versions)) {
    # Upgrade already fetched major versions
    while (my ($major_version, $minor_version) = each(%{$versions})) {
        if (exists $local_major_versions{$product} and exists $local_major_versions{$product}->{$major_version}) {
            # Upgrade ?
            if (version_compare($remote_major_versions{$product}->{$major_version}, $local_major_versions{$product}->{$major_version}) > 0) {
                # Upgrade needed
                $upgrades{$product}->{$local_major_versions{$product}->{$major_version}} = $minor_version;
            }
        } 
    }

    # Fetch the last version of new products
    my @sorted_versions = sort {-version_compare($a, $b)} keys %{$versions};
    unless (defined $local_major_versions{$product}) {
        push @{$new_versions{$product}}, $remote_major_versions{$product}->{$sorted_versions[0]};
        next;
    }

    # Fetch new major versions of existing products
    foreach my $version (@sorted_versions) {
        last if exists $local_major_versions{$product}->{$version};
        push @{$new_versions{$product}}, $remote_major_versions{$product}->{$version};
    }
}

unless ((scalar keys %new_versions) + (scalar keys %upgrades)) {
    print "Nothing to do !\n";
    exit;
}

print "New Versions: \n";
foreach my $product (sort keys %keep) {
    if (exists $upgrades{$product}) {
        while (my ($major, $minor) = each(%{$upgrades{$product}})) {
            print "  $product".(" "x(16 - length $product))."$minor\n";
        }
    }
    if (exists $new_versions{$product}) {
        foreach my $version (@{$new_versions{$product}}) {
            print "  $product".(" "x(16 - length $product))."$version\n";
        }
    }
}

print "\nSync is starting...\n\n";

# Start RSYNC
pipe FROM_FATHER, TO_RSYNC0;
my $pid_rsync = fork();
die "fork: $!" unless defined $pid_rsync;
if ($pid_rsync == 0) { # Child: RSYNC
    close TO_RSYNC0;
    
    open STDIN, '<&', \*FROM_FATHER;

    exec "rsync", "-aizy", "--progress", "--filter=. -", "$homes:$doclib_path", $sync_dir
        or die "exec: rsync: $!";
    # Child stops here
} # The father continues...

# Clean up...
close FROM_FATHER;

# Dump files to sync
my %seen_product_path;
while (my ($product, $versions) = each(%new_versions)) {
    foreach my $version (@{$versions}) {
        my $path = $available_products{$product}->{$version};
        my ($product_path, @remaining_items) = split "/", $path;
        unless (defined $seen_product_path{$product_path}) {
            print TO_RSYNC0 "+ /$product_path\n";
            $seen_product_path{$product_path} = 1;
        }
        print TO_RSYNC0 "+ /$path\n";
        print TO_RSYNC0 "+ /$path/**\n";
    }
}
print TO_RSYNC0 "- *\n";

# No more file to sync, notify RSYNC...
close TO_RSYNC0;

# Wait for RSYNC
waitpid $pid_rsync, 0;

