#!/usr/bin/env perl
use strict;
use warnings;

# Run a set of short Galacticus models and make plots from them to test the plotting scripts.
# Andrew Benson (10-Oct-2012)

# Check that we have the executable.
unless ( exists($ENV{'GALACTICUS_EXEC_PATH'}) ) {
    print "SKIPPED: GALACTICUS_EXEC_PATH is not defined";
    exit 0;
}
unless ( -e $ENV{'GALACTICUS_EXEC_PATH'}."/Galacticus_noMPI.exe" ) {
    system("cd ".$ENV{'GALACTICUS_EXEC_PATH'}."; make -j16 Galacticus.exe; cp Galacticus.exe Galacticus_noMPI.exe");
    unless ( -e $ENV{'GALACTICUS_EXEC_PATH'}."/Galacticus_noMPI.exe" ) {
	print "SKIPPED: Galacticus executable not available and could not be built";
	exit 0;
    }
}

# First run the models.
system("cd ..; ".$ENV{'GALACTICUS_EXEC_PATH'}."/scripts/aux/launch.pl testSuite/parameters/test-plotting-scripts.xml");

# Check for failed models.
system("grep -q -i fatal outputs/test-plotting-scripts/galacticus_*/galacticus.log");
if ( $? == 0 ) {
    # Failures were found. Output their reports.
    my @failures = split(" ",`grep -l -i fatal outputs/test-plotting-scripts/galacticus_*/galacticus.log`);
    foreach my $failure ( @failures ) {
	print "FAILED: log from ".$failure.":\n";
	system("cat ".$failure);
    }
} else {
    print "SUCCESS!\n";
}

# Run plotting commands.
my @plottingScripts =
    (
     {
	 script     => "Plot_Black_Hole_vs_Bulge_Mass.pl",
	 model      => "0:1"
     },
     {
	 script     => "Plot_HI_Mass_Function.pl",
	 model      => "0:1"
     },
     {
	 script     => "Plot_K_Luminosity_Function.pl",
	 model      => "0:1"
     },
     {
	 script     => "Plot_Morphological_Luminosity_Function.pl",
	 model      => "0:1"
     },
     {
	 script     => "Plot_SDSS_Color_Distribution.pl",
	 model      => "0:1"
     },
     {
	 script     => "Plot_SDSS_Gas_Metallicity.pl",
	 model      => "0:1"
     },
     {
	 script     => "Plot_Disk_Scalelengths.pl",
	 model      => "0:1"
     },
     {
	 script     => "Plot_SDSS_Tully_Fisher.pl",
	 model      => "0:1"
     },
     {
	 script     => "Plot_bJ_Luminosity_Function.pl",
	 model      => "0:1"
     }
    );
foreach ( @plottingScripts ) {
    system("cd ..; scripts/observables/".$_->{'script'}." testSuite/outputs/test-plotting-scripts/galacticus_".$_->{'model'}."/galacticus.hdf5 testSuite/outputs/test-plotting-scripts/galacticus_".$_->{'model'}." 1");
    print "FAILED: plotting script ".$_->{'script'}." failed\n"
	unless ( $? == 0 );
}

exit;
