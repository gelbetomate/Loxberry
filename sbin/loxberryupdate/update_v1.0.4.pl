#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::System;
use LoxBerry::Log;
use CGI;

my $cgi = CGI->new;
 

# Initialize logfile and parameters
	my $logfilename;
	if ($cgi->param('logfilename')) {
		$logfilename = $cgi->param('logfilename');
	}
	my $log = LoxBerry::Log->new(
			package => 'LoxBerry Update',
			name => 'update',
			filename => $logfilename,
			logdir => "$lbslogdir/loxberryupdate",
			loglevel => 7,
			stderr => 1,
			append => 1,
	);
	$logfilename = $log->filename;

	if ($cgi->param('updatedir')) {
		$updatedir = $cgi->param('updatedir');
	}
	my $release = $cgi->param('release');

# Finished initializing
# Start program here
########################################################################

my $errors = 0;
LOGOK "Update script $0 started.";

#
# Remove old usbautomount
#
LOGINF "Removing old usbmount";

qx { rm -f /etc/systemd/system/systemd-udevd.service };
qx { rm -rf $lbhomedir/system/storage };
qx { rm -rf /media/smb };
qx { rm -rf /media/usb };

my $output = qx { /usr/bin/dpkg --configure -a };
my $exitcode  = $? >> 8;
if ($exitcode != 0) {
        LOGERR "Error configuring dkpg with /usr/bin/dpkg --configure -a - Error $exitcode";
        LOGDEB $output;
                $errors++;
} else {
        LOGOK "Configuring dpkg successfully.";
}
$output = qx { /usr/bin/apt-get -q -y update };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
        LOGERR "Error updating apt database - Error $exitcode";
                LOGDEB $output;
        $errors++;
} else {
        LOGOK "Apt database updated successfully.";
}

qx { dpkg -l | grep -q -e "ii *usbmount" };
$exitcode  = $? >> 8;
if ($exitcode eq 0) {
	$output = qx { DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get -q -y remove usbmount };
	$exitcode  = $? >> 8;
	if ($exitcode != 0) {
	        LOGERR "Error uninstalling packages usbmount pmount with apt-get - Error $exitcode";
	        LOGDEB $output;
	        $errors++;
	} else {
	        LOGOK "Uninstalling usbmount pmount successfully.";
	}
}

qx { dpkg -l | grep -q -e "ii *pmount" };
$exitcode  = $? >> 8;
if ($exitcode eq 0) {
	$output = qx { DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get -q -y remove pmount };
	$exitcode  = $? >> 8;
	if ($exitcode != 0) {
	        LOGERR "Error uninstalling packages usbmount pmount with apt-get - Error $exitcode";
	        LOGDEB $output;
	        $errors++;
	} else {
	        LOGOK "Uninstalling usbmount pmount successfully.";
	}
}

#
# Install new usbautomount
#
LOGINF "Installing usb automount";
qx { mkdir -p /media/smb };
qx { mkdir -p /media/usb };
qx { mkdir -p $lbhomedir/system/storage };
qx { mkdir -p $lbhomedir/system/storage/smb };
qx { rm -fr $lbhomedir/system/storage/usb };
$output = qx { ln -f -s /media/usb $lbhomedir/system/storage/usb };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error creating symlink $lbhomedir/system/storage/usb - Error $exitcode";
	LOGDEB $output;
	$errors++;
} else {
	LOGOK "Symlink $lbhomedir/system/storage/usb created successfully";
}
qx { chown -R loxberry:loxberry $lbhomedir/system/storage };

#
# Installing autofs for SMB automounts
#
LOGINF "Installing Autofs and smbclient";

$output = qx { DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get -q -y install autofs smbclient };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
        LOGERR "Error installing packages autofs smbclient with apt-get - Error $exitcode";
        LOGDEB $output;
        $errors++;
} else {
        LOGOK "Installing autofs and smbclient successfully.";
}

$output = qx {awk -v s='/media/smb /etc/auto.smb --timeout=300 --ghost' '/^\\/media\\/smb/{\$0=s;f=1} {a[++n]=\$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/auto.master };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
        LOGERR "Error replacing string /media/smb in /etc/auto.master - Error $exitcode";
        LOGDEB $output;
        $errors++;
} else {
        LOGOK "Replacing string /media/smb successfully in /etc/auto.master";
}

#
# Samba
#
LOGINF "Replacing system samba config file";

qx { mkdir -p $lbhomedir/system/samba/credentials };
$output = qx { if [ -e $updatedir/system/samba/smb.conf ] ; then cp -f $updatedir/system/samba/smb.conf $lbhomedir/system/samba/ ; fi };
$exitcode  = $? >> 8;

if ($exitcode != 0) {
	LOGERR "Error copying new samba config file - Error $exitcode";
	LOGDEB $output;
	$errors++;
} else {
	LOGOK "New samba config file copied.";
}

qx { rm -fr /etc/creds };
$output = qx { ln -f -s $lbhomedir/system/samba/credentials /etc/creds };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error creating symlink /etc/creds - Error $exitcode";
	LOGDEB $output;
	$errors++;
} else {
	LOGOK "Symlink /etc/creds created successfully";
}

qx { chown loxberry:loxberry $lbhomedir/system/samba/smb.conf };
qx { chown -R loxberry:loxberry $lbhomedir/system/samba/credentials };
qx { chmod 700 $lbhomedir/system/samba/credentials };

#
# Remove obsolete Apache2 logrotate
#
LOGINF "Removing obsolete Apache2 logrotate config";
qx { rm -f /etc/logrotate.d/apache2 };

#
# Copy new logrotate
#
LOGINF "Installing new logrotate config";
copy_to_loxberry("/system/logrotate/logrotate");

#
# Copy new apache2.conf
#
LOGINF "Installing new apache2 config";
copy_to_loxberry("/system/apache2/apache2.conf");

#
# Install cronjob for notification maintenance (weekly reduce notifys to 20 per package)
#
LOGINF "Install job for notification maintenance (weekly reduce notifys to 20 per package)";
copy_to_loxberry("/system/cron/cron.weekly/db_maint");

#
# Correct symlink from /etc/sudoers.d to ~/system/sudoers
#
LOGINF "Creating new symlink from /etc/sudoers.d to ~/system/susdoers";
if ( -d "/etc/sudoers.d") {
	qx { mv /etc/sudoers.d /etc/sudoers.d.orig };
} else {
	qx { rm -rf /etc/sudoers.d };
}
$output = qx { ln -f -s $lbhomedir/system/sudoers/ /etc/sudoers.d };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error creating symlink /etc/sudoers.d - Error $exitcode";
	LOGDEB $output;
	$errors++;
} else {
	LOGOK "Symlink /etc/sudoeers.d created successfully";
}
if ( -d "/etc/sudoers.d.orig") {
	qx { cp -fv /etc/sudoers.d.orig/* /etc/sudoers.d };
	qx { rm -fr /etc/sudoers.d.orig };
}

#
# Sudoers
#

LOGINF "Replacing system default sudoers file";
LOGINF "Copying new";

my $output = qx { if [ -e $updatedir/system/sudoers/lbdefaults ] ; then cp -f $updatedir/system/sudoers/lbdefaults $lbhomedir/system/sudoers/ ; fi };
my $exitcode  = $? >> 8;

if ($exitcode != 0) {
       LOGERR "Error copying new lbdefaults - Error $exitcode";
       $errors++;
} else {
       LOGOK "New lbdefaults copied.";
}
qx { chown root:root $lbhomedir/system/sudoers/lbdefaults };


## If this script needs a reboot, a reboot.required file will be created or appended
LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
reboot_required("LoxBerry Update requests a reboot.");

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End of script
exit($errors);


sub delete_directory
{
	
	require File::Path;
	my $delfolder = shift;
	
	if (-d $delfolder) {   
		rmtree($delfolder, {error => \my $err});
		if (@$err) {
			for my $diag (@$err) {
				my ($file, $message) = %$diag;
				if ($file eq '') {
					LOGERR "     Delete folder: general error: $message";
				} else {
					LOGERR "     Delete folder: problem unlinking $file: $message";
				}
			}
		return undef;
		}
	}
	return 1;
}


####################################################################
# Copy a file or dir from updatedir to lbhomedir including error handling
# Parameter:
#	file/dir starting from ~ 
#   (without /opt/loxberry, with leading /)
####################################################################
sub copy_to_loxberry
{
	my ($destparam) = @_;
		
	my $destfile = $lbhomedir . $destparam;
	my $srcfile = $updatedir . $destparam;
		
	if (! -e $srcfile) {
		LOGERR "$srcfile does not exist";
		$errors++;
		return;
	}
	
	my $output = qx { cp -f $srcfile $destfile };
	my $exitcode  = $? >> 8;

	if ($exitcode != 0) {
		LOGERR "Error copying $destparam - Error $exitcode";
		LOGINF "Message: $output";
		$errors++;
	} else {
		LOGOK "$destparam installed.";
	}
}

