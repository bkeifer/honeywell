#!/usr/bin/perl -w
use strict;

use WWW::Mechanize;
use HTML::TreeBuilder;
use Data::Dumper;

sub trim($);

our $user;
our $pass;

require('honeywell-auth.pl');

my $agent = WWW::Mechanize->new();
$agent->get("https://rs.alarmnet.com/TotalConnectComfort/");
my $fields = {
	'UserName' => $user,
	'Password' => $pass,
};
print Dumper $fields;
	
my $r = $agent->submit_form(form_number => 1,
							fields => $fields);

my @links = @{$agent->links};
my @zoneLinks;

for my $link (0..$#links) {
	next unless $links[$link][0] =~ /Device\/Control/;
	@zoneLinks[scalar(@zoneLinks)] = $links[$link][0];
}

my $page = HTML::TreeBuilder->new_from_content($agent->content());

my $zoneCount = 0;
my @zoneData;

foreach my $div ($page->find_by_tag_name('div')) {
	my $id = $div->attr('id') || next;
	if ($id eq 'zone-list') {
		foreach my $tr ($div->find_by_tag_name('tr')) {
			my ($name, $temp, $humidity);
			foreach my $td ($tr->find_by_tag_name('td')) {
				my $class = $td->attr('class') || next;
				if ($class eq 'location-zone-title') {
					$name = $td->as_text();
				} elsif ($class eq 'zone-temperature') {
					$temp = trim($td->as_text());
					$temp =~ s/^(\d+).*/$1/;
				} elsif ($class eq 'zone-humidity') {
					$humidity = trim($td->as_text());
					$humidity =~ s/^(\d+).*/$1/;
				}
			}
			if ($name ne '') {
				push @zoneData, { name => $name,
						  temp => $temp, 
						  humidity => $humidity, };
			}
		}
	}
}

foreach my $url (@zoneLinks) {
	my $deviceNum = $url;
	$deviceNum =~ s/\/TotalConnectComfort\/Device\/Control\/(\d+)/$1/;
	$agent->follow_link(url_regex => qr/Device\/Control\/$deviceNum/);
	my $outTemp = $agent->content();
	$outTemp =~ m/Control.Model.Property.outdoorTemp, (\d+)/;
	$outTemp = ${1};

	my $outHumidity = $agent->content();
	$outHumidity =~ m/Control.Model.Property.outdoorHumidity, (\d+)/;
	$outHumidity = ${1};

	$zoneData[$zoneCount]{'outTemp'} = $outTemp;
	$zoneData[$zoneCount]{'outHumidity'} = $outHumidity;

	my $zonePage = HTML::TreeBuilder->new_from_content($agent->content());
##	my $outdoorTempDisplay = $zonePage->find_by_attribute("class", "OutdoorTempDisplay");
##Control.Model.Property.outdoorTemp, 50.0000
##my $foo = $zonePage;
##print Dumper $foo;
##print Dumper $outdoorTempDisplay;
#	my $outsideTemp = $foo;
##	$outsideTemp =~ s/^(\d+).*/$1/;
#	$zoneData[$zoneCount]{'outTemp'} = $outsideTemp;
#	
#	my $outdoorHumidityDisplay = $zonePage->find_by_attribute("class", "OutdoorHumidityDisplay");
#	my $outsideHumidity = $outdoorHumidityDisplay->as_text();
#	$outsideHumidity =~ s/(\d+).*/$1/;
#	$zoneData[$zoneCount]{'outHumidity'} = $outsideHumidity;
#
	my $setPoint = $zonePage->find_by_attribute("id", "NonAutoModeTempControls");

	foreach my $div ($setPoint->find_by_tag_name('div')) {
		my $id = $div->attr('id');
		if (defined($id)) {
			if ($id eq 'NonAutoHeatSetpt' || $id eq 'NonAutoCoolSetpt') {
				if ($div->attr('style') eq 'display: none') {
					next;
				} else {
					my $dataDiv = $div->find_by_attribute("class", "DisplayValue");
					$zoneData[$zoneCount]{setPoint} = $dataDiv->as_text();
				}
			}
		}
	}
		
	$agent->follow_link(url_regex => qr/Zones/);
	$zoneCount++;
}

$agent->follow_link(url_regex => qr/LogOff/);


$zoneCount = 1;
foreach my $zone (@zoneData) {
	print "z" . $zoneCount . "t:" . $zone->{'temp'} . " ";
	print "z" . $zoneCount . "h:" . $zone->{'humidity'} . " ";
	print "z" . $zoneCount . "s:" . $zone->{'setPoint'} . " ";
	$zoneCount++;
}
print "ot:" . $zoneData[0]->{'outTemp'} . " ";
print "oh:" . $zoneData[0]->{'outHumidity'} . "\n";



sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}
