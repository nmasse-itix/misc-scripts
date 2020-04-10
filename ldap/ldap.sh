#!/bin/sh

cd ~/bin/ldap || exit 1

./gen_ldif_users.pl < users.csv > data.ldif
if [ -f slapd.pid ] ; then
	kill `cat slapd.pid` ;
fi

mkdir -p /tmp/ldap_data
rm -f /tmp/ldap_data/*
cp DB_CONFIG /tmp/ldap_data/
/usr/sbin/slapadd -f slapd.conf -l data.ldif
/usr/sbin/slapd -h ldap://0.0.0.0:12345 -f slapd.conf 

