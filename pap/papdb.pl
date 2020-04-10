#!/usr/bin/perl -w

use strict;
use XML::LibXML;
use Data::Dumper;
use LWP::UserAgent;
use File::Temp qw/tempdir/;
use DBI;

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $tmp = tempdir(DIR => "tmp");
my $parser = XML::LibXML->new;
my $dbh = DBI->connect("dbi:Pg:dbname=immodb;host=/var/run/postgresql/", "john", "", {'RaiseError' => 1});

sub slurp_p2p_db {
    my $filename = shift;

    my %data;
    my $dom = $parser->parse_file($filename);
    my $root = $dom->getDocumentElement();
    my @placemarks = $root->getElementsByTagNameNS("http://www.opengis.net/kml/2.2", "Placemark");
    foreach my $placemark (@placemarks) {
        my $desc = $placemark->getElementsByTagNameNS("http://www.opengis.net/kml/2.2", "description")->[0]->firstChild->data;
        my $name = $placemark->getElementsByTagNameNS("http://www.opengis.net/kml/2.2", "name")->[0]->firstChild->data;
        my $gps = $placemark->getElementsByTagNameNS("http://www.opengis.net/kml/2.2", "coordinates")->[0]->firstChild->data;

        my $id = "$name|$gps";
        my ($prix_appartement) = $desc =~ m/<span class='label'>Appartement<\/span> <span class='prix'>([^<]+)<\/span>/g;
        $prix_appartement =~ tr/ //d
            if defined $prix_appartement;
        my ($prix_maison) = $desc =~ m/<span class='label'>Maison<\/span> <span class='prix'>([^<]+)<\/span>/g;
        $prix_maison =~ tr/ //d
            if defined $prix_maison;
        unless (defined $prix_appartement or defined $prix_maison) {
            warn "no price for '$id'";
            next;
        }
        $data{$id} = { appartement => $prix_appartement, maison => $prix_maison };
    }
    return \%data;
}

warn "Parsing XML files";
my $ventes = slurp_p2p_db("tmp/kml-vente.xml");
my $locations = slurp_p2p_db("tmp/kml-location.xml");

warn "Updating database";
my $sth_update = $dbh->prepare('UPDATE ville SET pap_prix_vente_appartement_m2 = ?, pap_prix_vente_maison_m2 = ? WHERE nom = ? AND coordonnees_gps = ?')
    or die "could not prepare: ".$dbh->errstr;
my $sth_insert = $dbh->prepare('INSERT INTO ville (nom, coordonnees_gps) VALUES (?, ?)')
    or die "could not prepare: ".$dbh->errstr;
foreach my $id (sort keys %{$ventes}) {
    my ($nom, $gps) = split /[|]/, $id;
    my $prix = $ventes->{$id};
    my $nb = $sth_update->execute($prix->{appartement}, $prix->{maison}, $nom, $gps);
    unless ($nb > 0) {
        $sth_insert->execute($nom, $gps)
            or warn "could not insert $id: ".$sth_insert->errstr;
        $sth_update->execute($prix->{appartement}, $prix->{maison}, $nom, $gps)
            or warn "could not update $id: ".$sth_update->errstr;
    }
}

$sth_update = $dbh->prepare('UPDATE ville SET pap_prix_location_appartement_m2 = ?, pap_prix_location_maison_m2 = ? WHERE nom = ? AND coordonnees_gps = ?')
    or die "could not prepare: ".$dbh->errstr;
foreach my $id (sort keys %{$locations}) {
    my ($nom, $gps) = split /[|]/, $id;
    my $prix = $locations->{$id};
    my $nb = $sth_update->execute($prix->{appartement}, $prix->{maison}, $nom, $gps);
    unless ($nb > 0) {
        $sth_insert->execute($nom, $gps)
            or warn "could not insert $id: ".$sth_insert->errstr;
        $sth_update->execute($prix->{appartement}, $prix->{maison}, $nom, $gps)
            or warn "could not update $id: ".$sth_update->errstr;
    }
}

$dbh->commit()
    or die "could not commit: ".$dbh->errstr;
$dbh->disconnect();

