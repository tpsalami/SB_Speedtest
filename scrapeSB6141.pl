#!/usr/bin/perl -w
###################################################################
#
# Script to scrape the data from the status screen of the Motorla Surfboard SB6141
# and spit it out for logging
#
# relies on the fact that firmware is rarely updated and the web page remains
# static.   IP address of SB6141 is 192.168.100.1

# Set Variables
use strict;

use CGI qw(param);
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Response;
use Time::localtime;
use List::Util qw(sum);
#use Net::Google::Spreadsheets;

#stuff I use to test locally before uploading it somewhere
my $localbasedir = "/data/306wd/";

my @downChannels = ();
my @downFreqs = ();
my @downSNRs = ();
my @downPowers= ();
my @upChannels = ();
my @upFreqs = ();
my @upPowers = ();



my $url = "http://192.168.100.1/cmSignalData.htm";
my $ua = LWP::UserAgent ->new();
$ua->agent("Atari/2600");				#say what i am
my $req = HTTP::Request->new(GET=> $url);
$req->referer("http://www.306wd.com/");	#say who I am

my $response = $ua->request($req);
my $status = $response->status_line;
my $stuff = $response->content();
my @outstuff = split(/\n/,$stuff);

my $importantline = "none";
my $searchstring = ">Channel ID<";
my $tableCount = 0;
my $lineCount = 0;
my $nChannelsDown = 0;

for(my $i=0; $i<@outstuff;$i++){
	if($outstuff[$i] =~ /$searchstring/i){
		$tableCount++;
		$lineCount = 0;
	}

	if($tableCount == 1){  #downstream table
		if($lineCount == 1){ 	#channel IDs
			my $splitstring = "<TD>";
			my @moreparts = split(/$splitstring/,$outstuff[$i]);
			for (my $nn=0; $nn<@moreparts; $nn++){
				$splitstring = "&nbsp; ";
				my @evenmoreparts = split(/$splitstring/,$moreparts[$nn]);
				if(exists($evenmoreparts[0])){
					if($evenmoreparts[0]=~ /^[0-9,.E]+$/ ) {
						push(@downChannels, $evenmoreparts[0]);
						$nChannelsDown++;
					}
				}
			}
		}
		if($lineCount==2){
			my $splitstring = "<TD>";	#channel freq
			my @moreparts = split(/$splitstring/,$outstuff[$i]);
			for (my $nn=0; $nn<@moreparts; $nn++){
				$splitstring = " Hz";
				my @evenmoreparts = split(/$splitstring/,$moreparts[$nn]);
				if(exists($evenmoreparts[0])){
					if($evenmoreparts[0]=~ /^[0-9,.E]+$/ ) {
						push(@downFreqs, $evenmoreparts[0]/1000000);
					}
				}
			}
		}
		if($lineCount==3){   #channel SNR
			my $splitstring = "<TD>";	
			my @moreparts = split(/$splitstring/,$outstuff[$i]);
			for (my $nn=0; $nn<@moreparts; $nn++){
				$splitstring = " dB";
				my @evenmoreparts = split(/$splitstring/,$moreparts[$nn]);
				if(exists($evenmoreparts[0])){
					if($evenmoreparts[0]=~ /^-?\d+$/ ) {
						push(@downSNRs, $evenmoreparts[0]);
					}
				}
			}
		}
		for(my $mm=5; $mm < (5+$nChannelsDown); $mm++) {
			if($lineCount==$mm){	
				my $splitstring = "<TD>";
				my @moreparts = split(/$splitstring/,$outstuff[$i]);
				for (my $nn=0; $nn<@moreparts; $nn++){
					$splitstring = " dB";
					my @evenmoreparts = split(/$splitstring/,$moreparts[$nn]);
					if(exists($evenmoreparts[0])){
						if($evenmoreparts[0]=~ /^-?\d+$/ ) {
							push(@downPowers, $evenmoreparts[0]);
						}
					}
				}
			}
		}
		
		$lineCount++;
		if($outstuff[$i] =~ /<P>/i){  #catch getting lost,
			$lineCount = 100;
		}
	}
	
	if($tableCount == 2) {  #upstream table
		if($lineCount == 1) { #channel ID
			my $splitstring = "<TD>";
			my @moreparts = split(/$splitstring/,$outstuff[$i]);
			for (my $nn=0; $nn<@moreparts; $nn++){
				$splitstring = "&nbsp; ";
				my @evenmoreparts = split(/$splitstring/,$moreparts[$nn]);
				if(exists($evenmoreparts[0])){
					if($evenmoreparts[0]=~ /^[0-9,.E]+$/ ) {
						push(@upChannels, $evenmoreparts[0]);
						$nChannelsDown++;
					}
				}
			}		
		}
		if($lineCount == 2) { #channel frequency
			my $splitstring = "<TD>";
			my @moreparts = split(/$splitstring/,$outstuff[$i]);
			for (my $nn=0; $nn<@moreparts; $nn++){
				$splitstring = " Hz";
				my @evenmoreparts = split(/$splitstring/,$moreparts[$nn]);
				if(exists($evenmoreparts[0])){
					if($evenmoreparts[0]=~ /^[0-9,.E]+$/ ) {
						push(@upFreqs, $evenmoreparts[0]/1000000);
						$nChannelsDown++;
					}
				}
			}		
		}
		if($lineCount == 5) { #power level
			my $splitstring = "<TD>";
			my @moreparts = split(/$splitstring/,$outstuff[$i]);
			for (my $nn=0; $nn<@moreparts; $nn++){
				$splitstring = " dB";
				my @evenmoreparts = split(/$splitstring/,$moreparts[$nn]);
				if(exists($evenmoreparts[0])){
					if($evenmoreparts[0]=~ /^[0-9,.E]+$/ ) {
						push(@upPowers, $evenmoreparts[0]);
						$nChannelsDown++;
					}
				}
			}		
		}
		
		$lineCount++;
		if($outstuff[$i] =~ /<P>/i){  #catch getting lost,
			$lineCount = 100;
		}
	
	}
}

my @maxDownPower = ();
my @maxDownSNR = ();
if (scalar(@downChannels)>0){
	my $idxMax = 0;
	$downPowers[$idxMax] > $downPowers[$_] or $idxMax = $_ for 1 .. $#downPowers;
	@maxDownPower = ($downChannels[$idxMax], $downFreqs[$idxMax], $downSNRs[$idxMax], $downPowers[$idxMax]);
	
	$downSNRs[$idxMax] > $downSNRs[$_] or $idxMax = $_ for 1 .. $#downSNRs;
	@maxDownSNR = ($downChannels[$idxMax], $downFreqs[$idxMax], $downSNRs[$idxMax], $downPowers[$idxMax]);
}

my $x;
my $filetoopen = "PowerLevelData.csv";

if (open(FILE,">>$filetoopen")) {

	print FILE time() . ",";
	foreach $x (@maxDownPower) {
		print FILE "$x,";
	}
	foreach $x (@maxDownSNR) {
		print FILE "$x,";
	}
	print FILE sum(@downPowers) / @downPowers;
	print FILE ",". scalar(@downPowers);
	print FILE "\n";


	close(FILE);
}
else {
	print "cannot open file\n";
}
#now, what do we do with that data

exit;