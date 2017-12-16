#!/usr/bin/perl
use LoxBerry::System;
use strict;
use warnings;
use experimental 'smartmatch';
use CGI;
use JSON;
use File::Path;
use LWP::UserAgent;
require HTTP::Request;

my $updatedir;

my $cgi = CGI->new;

if ($cgi->param('updatedir')) {
	$updatedir = $cgi->param('updatedir');

if (!$updatedir) {
	$joutput{'error'} = "No updatedir sent.";
	&err;
	exit (1);
}

# Set up rsync command line
my @rsynccommand = (
	"rsync",
	"--checksum",
	"--archive", # equivalent to -rlptgoD
	"--backup",
	"--backup-dir /opt/loxberry_backup",
	"--keep-dirlinks",
	"--delete",
	"-F",
	"--exclude-from=$lbhomedir/config/system/update_ignore.system",
	"--exclude-from=$lbhomedir/config/system/update_ignore.user",
	"--human-readable",
	"--dry-run",
	"$updatedir",
	"$lbhomedir"
);

# -o und -g verhindern
	
	
system(@rsynccommand);
 

















sub err
{
	if ($joutput{'error'}) {
		print STDERR "ERROR: " . $joutput{'error'} . "\n";
	} elsif ($joutput{'info'}) {
		print STDERR "INFO: " . $joutput{'info'} . "\n";
	}
}
