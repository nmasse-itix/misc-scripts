#!/usr/bin/perl -w

use strict;

my %o = ();

while (<>) {
  chomp;
  my ($cn, $short_uid, $long_uid, $ou, $org) = split /;/;
  my ($first_name, $family_name) = split / /, $cn;
  if (not exists $o{$org}) {
      print <<LDIF;
dn: o=$org
o: $org
objectClass: organization

LDIF
      $o{$org} = {};
  }
  if (not exists $o{$org}->{$ou}) {
      print <<LDIF;
dn: ou=$ou, o=$org
ou: $ou
objectClass: organizationalUnit

LDIF
      $o{$org}->{$ou} = 1;
  }
  print <<LDIF;
dn: cn=$cn,ou=$ou,o=$org
givenName: $first_name
sn: $family_name
userPassword: changem
mail: $long_uid\@example.test
telephoneNumber: 123456
objectClass: top
objectClass: inetOrgPerson
objectClass: pkiUser
uid: $short_uid
cn: $cn

LDIF
}

