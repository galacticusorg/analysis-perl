#!/usr/bin/env perl
use strict;
use warnings;
use Cwd;
use lib $ENV{'GALACTICUS_EXEC_PATH'}."/perl";
use Date::Format;
use XML::Simple;
use MIME::Lite;
use Net::SMTP::SSL;
use Data::Dumper;
use File::Slurp qw( slurp );
use File::Find;
use Term::ReadKey;
use System::Redirect;
use Galacticus::Launch::PBS;

# Run a suite of tests on the Galacticus Perl anlaysis tools.
# Andrew Benson (19-Aug-2010).

# Read in any configuration options.
my $config;
if ( -e "galacticusConfig.xml" ) {
    my $xml = new XML::Simple;
    $config = $xml->XMLin("galacticusConfig.xml");
}

# Identify e-mail options for this host.
my $emailConfig;
my $smtpPassword;
if ( exists($config->{'email'}->{'host'}->{$ENV{'HOSTNAME'}}) ) {
    $emailConfig = $config->{'email'}->{'host'}->{$ENV{'HOSTNAME'}};
} elsif ( exists($config->{'email'}->{'host'}->{'default'}) ) {
    $emailConfig = $config->{'email'}->{'host'}->{'default'};
} else {
    $emailConfig->{'method'} = "sendmail";
}
if ( $emailConfig->{'method'} eq "smtp" && exists($emailConfig->{'passwordFrom'}) ) {
    # Get any password now.
    if ( $emailConfig->{'passwordFrom'} eq "input" ) {
	print "Please enter your e-mail SMTP password:\n";
	$smtpPassword = &getPassword;
    }
    elsif ( $emailConfig->{'passwordFrom'} eq "kdewallet" ) {
	my $appName          = "Galacticus";
	my $folderName       = "glc-test-all";
	require Net::DBus;
	my $bus           = Net::DBus->find;
	my $walletService = $bus->get_service("org.kde.kwalletd");
	my $walletObject  = $walletService->get_object("/modules/kwalletd");
	my $walletID      = $walletObject->open("kdewallet",0,$appName);
	if ( $walletObject->hasEntry($walletID,$folderName,"smtpPassword",$appName) == 1 ) {
	    $smtpPassword = $walletObject->readPassword($walletID,$folderName,"smtpPassword",$appName); 
	} else {
	    print "Please enter your e-mail SMTP password:\n";
	    $smtpPassword = &getPassword;
	    $walletObject->writePassword($walletID,$folderName,"smtpPassword",$smtpPassword,$appName); 
	}
    }
}

# Open a log file.
my $logFile = "testSuite/allTests.log";
open(lHndl,">".$logFile);

# Create a directory for test suite outputs.
system("rm -rf testSuite/outputs");
system("mkdir -p testSuite/outputs");

# Write header to log file.
print lHndl ":-> Running test suite:\n";
print lHndl "    -> Host:\t".$ENV{'HOSTNAME'}."\n";
print lHndl "    -> Time:\t".time2str("%a %b %e %T (%Z) %Y", time)."\n";

# Stack to be used for PBS jobs.
my @jobStack;

# Set options for PBS launch.
my %pbsOptions =
    (
     pbsJobMaximum       => 100,
     submitSleepDuration =>   1,
     waitSleepDuration   =>  10
    );

# Perform tests.
my  @launchPBS;
my  @launchLocal;
# Find all test scripts to run.
my @testDirs = ( "testSuite" );
find(\&runTestScript,@testDirs);
# Run scripts that require us to launch them under PBS.
&Galacticus::Launch::PBS::SubmitJobs(\%pbsOptions,@launchPBS);
# Run scripts that can launch themselves using PBS.
foreach ( @launchLocal ) {
    print           ":-> Running test script: ".$_."\n";
    print lHndl "\n\n:-> Running test script: ".$_."\n";
    &System::Redirect::tofile("cd testSuite; ".$_,"testSuite/allTests.tmp");
    print lHndl slurp("testSuite/allTests.tmp");
    unlink("testSuite/allTests.tmp");
}

# Close the log file.
close(lHndl);

# Scan the log file for FAILED.
my $lineNumber = 0;
my @failLines;
open(lHndl,$logFile);
while ( my $line = <lHndl> ) {
    ++$lineNumber;
    if ( $line =~ m/FAILED/ ) {
	push(@failLines,$lineNumber);
    }
    if ( $line =~ m/SKIPPED/ ) {
	push(@failLines,$lineNumber);
    }
}
close(lHndl);
open(lHndl,">>".$logFile);
my $emailSubject = "Galacticus Perl analysis test suite log";
my $exitStatus;
if ( scalar(@failLines) == 0 ) {
    print lHndl "\n\n:-> All tests were successful.\n";
    print       "All tests were successful.\n";
    $emailSubject .= " [success]";
    $exitStatus = 0;
} else {
    print lHndl "\n\n:-> Failures found. See following lines in log file:\n\t".join("\n\t",@failLines)."\n";
    print "Failure(s) found - see ".$logFile." for details.\n";
    $emailSubject .= " [FAILURE]";
    $exitStatus = 1;
}
close(lHndl);

# If we have an e-mail address to send the log to, then do so.
if ( defined($config->{'contact'}->{'email'}) ) {
    if ( $config->{'contact'}->{'email'} =~ m/\@/ ) {
	# Get e-mail configuration.
	my $sendMethod = $emailConfig->{'method'};
	# Construct the message.
	my $message  = "Galacticus Perl analysis test suite log is attached.\n";
	my $msg = MIME::Lite->new(
	    From    => '',
	    To      => $config->{'contact'}->{'email'},
	    Subject => $emailSubject,
	    Type    => 'TEXT',
	    Data    => $message
	    );
	system("bzip2 -f ".$logFile);
	$msg->attach(
	    Type     => "application/x-bzip",
	    Path     => $logFile.".bz2",
	    Filename => "allTests.log.bz2"
	    );
	if ( $sendMethod eq "sendmail" ) {
	    $msg->send;
	}
	elsif ( $sendMethod eq "smtp" ) {
	    my $smtp; 
	    $smtp = Net::SMTP::SSL->new($config->{'email'}->{'host'}, Port=>465) or die "Can't connect";
	    $smtp->auth($config->{'email'}->{'user'},$smtpPassword) or die "Can't authenticate:".$smtp->message();
	    $smtp->mail( $config->{'contact'}->{'email'}) or die "Error:".$smtp->message();
	    $smtp->to( $config->{'contact'}->{'email'}) or die "Error:".$smtp->message();
	    $smtp->data() or die "Error:".$smtp->message();
	    $smtp->datasend($msg->as_string) or die "Error:".$smtp->message();
	    $smtp->dataend() or die "Error:".$smtp->message();
	    $smtp->quit() or die "Error:".$smtp->message();
	}
    }
}

exit $exitStatus;

sub runTestScript {
    # Run a test script.
    my $fileName = $_;
    chomp($fileName);

    # Test if this is a script to run.
    if ( $fileName =~ m/^test\-.*\.pl$/ && $fileName ne "test-all.pl" ) {
	system("grep -q launch.pl ".$fileName);
	if ( $? == 0 ) {
	    # This script will launch its own models.
	    push(
		@launchLocal,
		$fileName
		);
	} else {
	    # We need to launch this script.
	    (my $label = $fileName) =~ s/\.pl$//;
	    push(
		@launchPBS,
		{
		    launchFile   => "testSuite/".$label.".pbs",
		    label        => "testSuite-".$label       ,
		    logFile      => "testSuite/".$label.".log",
		    command      => "cd testSuite; ".$fileName,
		    ppn          => 16,
		    onCompletion => 
		    {
			function  => \&testFailure,
			arguments => [ "testSuite/".$label.".log", "Test script '".$label."'" ]
		    }
		}
		);
	}
    }
}

sub getPassword {
    # Read a password from standard input while echoing asterisks to the screen.
    ReadMode('noecho');
    ReadMode('raw');
    my $password = '';
    while (1) {
	my $c;
	1 until defined($c = ReadKey(-1));
	last if $c eq "\n";
	print "*";
	$password .= $c;
    }
    ReadMode('restore');
    print "\n";
    return $password;
}

sub testFailure {
    # Callback function which checks for failure of jobs run in PBS.
    my $logFile     = shift();
    my $jobMessage  = shift();
    my $jobID       = shift();
    my $errorStatus = shift();
    # Check for failure message in log file.
    if ( $errorStatus == 0 ) {
	system("grep -q FAIL ".$logFile);
	$errorStatus = 1
	    if ( $? == 0 );
    }
    # Report success or failure.
    if ( $errorStatus == 0 ) {
	# Job succeeded.
	print lHndl "SUCCESS: ".$jobMessage."\n";
	unlink($logFile);
    } else {
	# Job failed.
	print lHndl "FAILED: ".$jobMessage."\n";
	print lHndl "Job output follows:\n";
	print lHndl slurp($logFile);
    }
}
