#!/usr/bin/perl

# Set these for your situation
my $MTDIR = "/opt/mailman";
my $BACKUPDIR = "/root/backups";
my $TARCMD = "/bin/tar czf";
my $SQLDUMPCMD = "/usr/bin/mysqldump";
my $VERSION = "1.0.0";
my $OPTION_FILE = "/root/.mmbackuprc";
my $LATESTFILE = "$BACKUPDIR/mailman.sql-1";
my $DOSNAPSHOT = 0;
my $MYSQLUSER = "";
my $MYSQLPSWD = "";
my $MYSQLDBNAME = "mailman";
my $FILEEDITOR = $ENV{EDITOR};

if ($FILEEDITOR eq "")
{
	$FILEEDITOR = "/usr/bin/nano";
}

my $templatefile = <<'END_TEMPLATE';
# Put mysql user here
mailman
# Put mysql password here
changeme
# Put database name here
mailman
END_TEMPLATE


# Get if they said a option
my $CMDOPTION = shift;

sub ReadPrefs
{
	my $LineCount = 0;
	if (! -f $OPTION_FILE)
	{
		open my $fh, '>', "$OPTION_FILE";
		print ($fh $templatefile);
		close($fh);
		system("$FILEEDITOR $OPTION_FILE");
	}

	open(my $fh, '<:encoding(UTF-8)', $OPTION_FILE)
		or die "Could not open file '$OPTION_FILE' $!";

	while (my $row = <$fh>)
	{
		chomp $row;
		if (substr($row, 0, 1) eq "#")
		{
			# Skip comment lines
			next;
		}

		if ($LineCount == 0)
		{
			$MYSQLUSER = $row;
		}
		elsif ($LineCount == 1)
		{
			$MYSQLPSWD = $row;
		}
		elsif ($LineCount == 2)
		{
			$MYSQLDBNAME = $row;
		}
		$LineCount += 1;
	}
	close($fh);
	if ($MYSQLUSER eq "")
	{
		print "Database username is empty - check the config file with \"mailmanbackup.pl -prefs\"\n";
		exit;
	}
	if ($MYSQLPSWD eq "")
	{
		print "Database password is empty - check the config file with \"mailmanbackup.pl -prefs\"\n";
		exit;
	}
	if ($MYSQLDBNAME eq "")
	{
		print "Database name is empty - check the config file with \"mailmanbackup.pl -prefs\"\n";
		exit;
	}
	# print "User = $MYSQLUSER, PSWD = $MYSQLPSWD\n";
}

sub DumpMysql
{
	my $DUMPFILE = $_[0];

	print "Backing up MYSQL data: ";
	if (-f "$DUMPFILE")
	{
		unlink("$DUMPFILE");
	}
	# print "User = $MYSQLUSER, PSWD = $MYSQLPSWD\n";
	system("$SQLDUMPCMD --user=$MYSQLUSER --password=$MYSQLPSWD --result-file=$DUMPFILE $MYSQLDBNAME");
	print "\n";
}

if (defined $CMDOPTION)
{
	if (($CMDOPTION ne "-snapshot") && ($CMDOPTION ne "-prefs"))
	{
		print "Unknown command line option: '$CMDOPTION'\nOnly allowed options are '-snapshot' and '-prefs'\n";
		exit 0;
	}
}

sub SnapShotFunc
{
	print "Backing up java files: ";
	if (-f "$BACKUPDIR/snapshot.tgz")
	{
		unlink("$BACKUPDIR/snapshot.tgz");
	}
	system("$TARCMD $BACKUPDIR/snapshot.tgz $MTDIR > /dev/null 2>\&1");
	print "\nBackup Completed.\nBacking up MYSQL data: ";
	if (-f "$BACKUPDIR/snapshot.sql")
	{
		unlink("$BACKUPDIR/snapshot.sql");
	}
	# print "User = $MYSQLUSER, PSWD = $MYSQLPSWD\n";
	DumpMysql("$BACKUPDIR/snapshot.sql");
	print "\n";
}

#-------------------
# No changes below here...
#-------------------

if ((defined $CMDOPTION) && ($CMDOPTION eq "-snapshot"))
{
	$DOSNAPSHOT = -1;
}

print "CoffeeBackup.pl version $VERSION\n";
if ($DOSNAPSHOT == -1)
{
	print "Running Manual Snapshot\n";
}
print "==============================\n";

if ((defined $CMDOPTION) && ($CMDOPTION eq "-prefs"))
{
	# Edit the prefs file
	print "Editing the prefs file\n";
	if (! -f $OPTION_FILE)
	{
		open my $fh, '>', "$OPTION_FILE";
		print ($fh $templatefile);
		close($fh);
	}
	system("$FILEEDITOR $OPTION_FILE");
	exit 0;
}

ReadPrefs();

if (! -d $BACKUPDIR)
{
	print "Backup dir $BACKUPDIR not found, creating...\n";
	system("mkdir -p $BACKUPDIR");
}
if ($DOSNAPSHOT == -1)
{
	SnapShotFunc();
	exit 0;
}

print "Moving existing backups: ";

if (-f "$BACKUPDIR/mailmanbackup-5.tgz")
{
	unlink("$BACKUPDIR/mailmanbackup-5.tgz") or warn "Could not unlink $BACKUPDIR/mailmanbackup-5.tgz: $!";
}

my $FileRevision = 4;
while ($FileRevision > 0)
{
	if (-f "$BACKUPDIR/mailmanbackup-$FileRevision.tgz")
	{
		my $NewVersion = $FileRevision + 1;
		rename("$BACKUPDIR/mailmanbackup-$FileRevision.tgz", "$BACKUPDIR/mailmanbackup-$NewVersion.tgz");
	}
	$FileRevision -= 1;
}

print "Done\nCreating New Backup: ";
system("$TARCMD $BACKUPDIR/mailmanbackup-1.tgz $MTDIR");
print "Done\nMoving Existing MySQL data: ";
if (-f "$BACKUPDIR/mailman.sql-5")
{
	unlink("$BACKUPDIR/mailman.sql-5") or warn "Could not unlink $BACKUPDIR/mailman.sql-5: $!";
}

$FileRevision = 4;
while ($FileRevision > 0)
{
	if (-f "$BACKUPDIR/mailman.sql-$FileRevision")
	{
		my $NewVersion = $FileRevision + 1;
		rename("$BACKUPDIR/mailman.sql-$FileRevision", "$BACKUPDIR/mailman.sql-$NewVersion");
	}
	$FileRevision -= 1;
}

DumpMysql($LATESTFILE);
print("Done!\n");
exit 0;
