#!/usr/bin/env perl
use strict;
use warnings;
use Cwd;
use lib $ENV{'GALACTICUS_ANALYSIS_PERL_PATH'}."/perl";
use PDL;
use PDL::IO::HDF5;
use PDL::IO::HDF5::Dataset;
use PDL::NiceSlice;
use Text::Table;
use Math::SigFigs;
use GnuPlot::PrettyPlots;
use GnuPlot::LaTeX;

# Plot the star formation history of a galaxy split by metallicity and output the data in a form suitable for input to Grasil.
# Andrew Benson (06-September-2010)

# Read arguments.
die ("Usage: Extract_Star_Formation_History_for_Grasil.pl <inputFile> <outputIndex> <treeIndex> <nodeIndex> <grasilFile> [<plotFile>]")
    unless ( scalar(@ARGV) == 5 || scalar(@ARGV) == 6 );
my $inputFile   = $ARGV[0];
my $outputIndex = $ARGV[1];
my $treeIndex   = $ARGV[2];
my $nodeIndex   = $ARGV[3];
my $grasilFile  = $ARGV[4];
my $plotFile    = $ARGV[5] 
    if ( scalar(@ARGV) == 6 );

# Define prefixes.
my $giga        = 1.0e9;

# Define Solar metallicity.
my $metallicitySolar = 0.0188;

# Open the Galacticus file.
my $HDFfile = new PDL::IO::HDF5($inputFile);

# Get the output time.
my @outputTime          = $HDFfile->group("Outputs/Output".$outputIndex)->attrGet("outputTime");

# Get the metallicities at which star formation rates are tabulated.
my $metallicities       = $HDFfile->group("starFormationHistories")->dataset("metallicities")->get;

# Read the tree indices, offsets and node counts.
my $treeIndices         = $HDFfile->group("Outputs/Output".$outputIndex)->dataset("mergerTreeIndex"     )->get;
my $treeNodeStart       = $HDFfile->group("Outputs/Output".$outputIndex)->dataset("mergerTreeStartIndex")->get;
my $treeNodeCount       = $HDFfile->group("Outputs/Output".$outputIndex)->dataset("mergerTreeCount"     )->get;

# Get the offset positions for the tree.
my $selection = which($treeIndices == $treeIndex);
my $start = $treeNodeStart->index($selection);
my $count = $treeNodeCount->index($selection);
my $end   = $start+$count-1;

# Read in galaxy data.
my $nodeIndices         = $HDFfile->group("Outputs/Output".$outputIndex."/nodeData")->dataset("nodeIndex"                  )->get($start,$end);
my $diskScaleLength     = $HDFfile->group("Outputs/Output".$outputIndex."/nodeData")->dataset("diskRadius"                 )->get($start,$end);
my $spheroidScaleLength = $HDFfile->group("Outputs/Output".$outputIndex."/nodeData")->dataset("spheroidRadius"             )->get($start,$end);
my $diskStellarMass     = $HDFfile->group("Outputs/Output".$outputIndex."/nodeData")->dataset("diskMassStellar"            )->get($start,$end);
my $spheroidStellarMass = $HDFfile->group("Outputs/Output".$outputIndex."/nodeData")->dataset("spheroidMassStellar"        )->get($start,$end);
my $diskGasMass         = $HDFfile->group("Outputs/Output".$outputIndex."/nodeData")->dataset("diskMassGas"                )->get($start,$end);
my $spheroidGasMass     = $HDFfile->group("Outputs/Output".$outputIndex."/nodeData")->dataset("spheroidMassGas"            )->get($start,$end);
my $diskGasMetals       = $HDFfile->group("Outputs/Output".$outputIndex."/nodeData")->dataset("diskAbundancesGasMetals"    )->get($start,$end);
my $spheroidGasMetals   = $HDFfile->group("Outputs/Output".$outputIndex."/nodeData")->dataset("spheroidAbundancesGasMetals")->get($start,$end);

# Find the node in question.
my $selected = which($nodeIndices == $nodeIndex);

# Convert from total metals to metallicity.
my $diskGasMetallicity;
if ( $diskGasMass    (($selected)) > 0.0 ) {
    $diskGasMetallicity      = $diskGasMetals    (($selected))/$diskGasMass    (($selected));
    $diskGasMetallicity     .= 1.0 if ( $diskGasMetallicity > 1.0 );
    $diskGasMetallicity     /= $metallicitySolar;
} else {
    $diskGasMetallicity      = 0.0;
}
my $spheroidGasMetallicity;
if ( $spheroidGasMass(($selected)) > 0.0 ) {
    $spheroidGasMetallicity  = $spheroidGasMetals(($selected))/$spheroidGasMass(($selected));
    $spheroidGasMetallicity .= 1.0 if ( $spheroidGasMetallicity > 1.0 );
    $spheroidGasMetallicity /= $metallicitySolar;
} else {
    $spheroidGasMetallicity  = 0.0;
}

# Get a list of available datasets and convert to a hash.
my @dataSets = $HDFfile->group("starFormationHistories/Output".$outputIndex."/mergerTree".$treeIndex)->datasets;
my %availableDatasets;
foreach my $dataSet ( @dataSets ) {
    $availableDatasets{$dataSet} = 1;
}

# Read in the star formation data.
my $diskTime;
my $diskSFH;
if ( exists($availableDatasets{"diskTime".$nodeIndex}) ) {
    $diskTime            = $HDFfile->group("starFormationHistories/Output".$outputIndex."/mergerTree".$treeIndex)->dataset("diskTime"    .$nodeIndex)->get;
    $diskSFH             = $HDFfile->group("starFormationHistories/Output".$outputIndex."/mergerTree".$treeIndex)->dataset("diskSFH"     .$nodeIndex)->get;
    $diskSFH->where($diskSFH < 0.0) .= 0.0;
} else {
    $diskTime            = ones  (1);
    $diskSFH             = zeroes(1,nelem($metallicities));
}
my $spheroidTime;
my $spheroidSFH;
if ( exists($availableDatasets{"spheroidTime".$nodeIndex}) ) {
    $spheroidTime        = $HDFfile->group("starFormationHistories/Output".$outputIndex."/mergerTree".$treeIndex)->dataset("spheroidTime".$nodeIndex)->get;
    $spheroidSFH         = $HDFfile->group("starFormationHistories/Output".$outputIndex."/mergerTree".$treeIndex)->dataset("spheroidSFH" .$nodeIndex)->get;
    $spheroidSFH->where($spheroidSFH < 0.0) .= 0.0;
} else {
    $spheroidTime        = ones  (1);
    $spheroidSFH         = zeroes(1,nelem($metallicities));
}

# Compute time steps.
my $diskTimeBegin       = pdl [0.0];
if ( nelem($diskTime) > 1 ) {
    $diskTimeBegin       = $diskTimeBegin->append($diskTime->index(sequence(nelem($diskTime)-1)));
} else {
    $diskTimeBegin       = $diskTimeBegin;
}
my $diskTimeStep        = $diskTime-$diskTimeBegin;
my $diskTimeCentral     = ($diskTime+$diskTimeBegin)/2.0;
my $spheroidTimeBegin   = pdl [0.0];
if ( nelem($spheroidTime) > 1 ) {
    $spheroidTimeBegin   = $spheroidTimeBegin->append($spheroidTime->index(sequence(nelem($spheroidTime)-1)));
} else {
    $spheroidTimeBegin   = $spheroidTimeBegin;
}
my $spheroidTimeStep    = $spheroidTime-$spheroidTimeBegin;
my $spheroidTimeCentral = ($spheroidTime+$spheroidTimeBegin)/2.0;

# Open the Grasil output file.
open(gHndl,">".$grasilFile);

# Output file header.
print gHndl "# Output index     :\t".$outputIndex."\n";
print gHndl "# Tree   index     :\t".$treeIndex."\n";
print gHndl "# Node   index     :\t".$nodeIndex."\n";
print gHndl "# Output time [Gyr]:\t".$outputTime[0]."\n";
print gHndl "#\n";
print gHndl "# Galaxy properties:\n";
print gHndl "#  Stellar mass    (disk, spheroid) [M_Solar]:\t".$diskStellarMass   (($selected))."\t".$spheroidStellarMass   (($selected))."\n";
print gHndl "#  Gas     mass    (disk, spheroid) [M_Solar]:\t".$diskGasMass       (($selected))."\t".$spheroidGasMass       (($selected))."\n";
print gHndl "#  Scale length    (disk, spheroid) [Mpc    ]:\t".$diskScaleLength   (($selected))."\t".$spheroidScaleLength   (($selected))."\n";
print gHndl "#  Gas metallicity (disk, spheroid) [       ]:\t".$diskGasMetallicity             ."\t".$spheroidGasMetallicity             ."\n";

# See if we can check the integration of star formation histories.
print gHndl "#\n";
my @starFormationParameters = $HDFfile->group("Parameters")->attrGet("imfSelection","stellarPopulationProperties");
if ( $starFormationParameters[0] eq "fixed" && $starFormationParameters[1] eq "instantaneous" ) {
    my @imfSelectionFixed = $HDFfile->group("Parameters")->attrGet("imfSelectionFixed");
    my $imfRecycledAttributeName = "imf".$imfSelectionFixed[0]."RecycledInstantaneous";
    my @recycledFraction = $HDFfile->group("Parameters")->attrGet($imfRecycledAttributeName);
    my $diskSFHIntegrated     = (1.0-$recycledFraction[0])*$diskSFH    ->sum;
    my $spheroidSFHIntegrated = (1.0-$recycledFraction[0])*$spheroidSFH->sum;
    print gHndl "# Fractional error in SFH integration:\n";
    if ( $diskStellarMass    (($selected)) > 0.0 ) {
	print gHndl "#  Disk    :\t".abs($diskSFHIntegrated    -$diskStellarMass    (($selected)))/$diskStellarMass    (($selected))."\n";
    } else {
	print gHndl "#  Disk    :\tN/A\n";
    }
    if ( $spheroidStellarMass(($selected)) > 0.0 ) {
	print gHndl "#  Spheroid:\t".abs($spheroidSFHIntegrated-$spheroidStellarMass(($selected)))/$spheroidStellarMass(($selected))."\n";
    } else {
	print gHndl "#  Spheroid:\tN/A\n";
    }
} else {
    print gHndl "# Checks of star formation history integration are disabled for this model.\n";
}

# Output the metallicities.
print gHndl "#\n";
print gHndl "# Metallicities: ".join("\t",$metallicities->list)."\n";

# Compute mean star formation rates.
my $diskSFR             = $diskSFH    /$diskTimeStep    /$giga;
my $spheroidSFR         = $spheroidSFH/$spheroidTimeStep/$giga;

# Make a plot.
my $sfrMinimum = 1.0e-2;
if ( defined($plotFile) && ( any($diskSFR > $sfrMinimum) || any($spheroidSFR > $sfrMinimum) ) ) {
    # Declare variables for GnuPlot;
    my ($gnuPlot, $outputFile, $outputFileEPS, $plot);

    $outputFile = $plotFile;
    ($outputFileEPS = $outputFile) =~ s/\.pdf$/.eps/;
    open($gnuPlot,"|gnuplot");
    print $gnuPlot "set terminal epslatex color colortext lw 2 solid 7\n";
    print $gnuPlot "set output '".$outputFileEPS."'\n";
    print $gnuPlot "set lmargin screen 0.15\n";
    print $gnuPlot "set rmargin screen 0.95\n";
    print $gnuPlot "set bmargin screen 0.15\n";
    print $gnuPlot "set tmargin screen 0.95\n";
    print $gnuPlot "set key spacing 1.2\n";
    print $gnuPlot "set key at screen 0.45,0.5\n";
    print $gnuPlot "set key left\n";
    print $gnuPlot "set key bottom\n";
    print $gnuPlot "set logscale y\n";
    print $gnuPlot "set mytics 10\n";
    print $gnuPlot "set format y '\$10^{\%L}\$'\n";
    print $gnuPlot "set xlabel '\$t\$ [Gyr]'\n";
    print $gnuPlot "set ylabel '\$\\dot{M}_\\star\$ \$[M_\\odot \\hbox{yr}^{-1}]\$'\n";
    print $gnuPlot "set xrange [0.0:15.0]\n";
    print $gnuPlot "set yrange [1.0e-2:1.0e2]\n";
    my $iColor = -1;
    for(my $i=0;$i<$spheroidSFR->dim(1);++$i) {
	++$iColor;
	if (any($spheroidSFR(:,($i)) > $sfrMinimum)) {
	    my $metallicityLow;
	    my $metallicityHigh;
	    if ( $i == 0 ) {
		$metallicityLow = 0.0;
	    } else {
		$metallicityLow = FormatSigFigs($metallicities->index($i-1),2);
	    }
	    if ( $i == $spheroidSFR->dim(1)-1 ) {
		$metallicityHigh = "\\\\infty";
	    } else {
		$metallicityHigh = FormatSigFigs($metallicities->index($i),2);
	    }
	    my $label = "\\\\small Spheroid: \$".$metallicityLow."<Z<".$metallicityHigh."\$";
	    &GnuPlot::PrettyPlots::Prepare_Dataset(\$plot,
					  $spheroidTimeCentral, $spheroidSFR(:,($i)),
					  style => "point", symbol => [4,5], weight => [5,3],
					  color => $GnuPlot::PrettyPlots::colorPairs{${$GnuPlot::PrettyPlots::colorPairSequences{'sequence1'}}[$iColor]},
					  title => $label);
	}
    }
    $iColor = -1;
    for(my $i=0;$i<$diskSFR->dim(1);++$i) {
	++$iColor;
	if (any($diskSFR(:,($i)) > $sfrMinimum)) {
	    my $metallicityLow;
	    my $metallicityHigh;
	    if ( $i == 0 ) {
		$metallicityLow = 0.0;
	    } else {
		$metallicityLow = FormatSigFigs($metallicities->index($i-1),2);
	    }
	    if ( $i == $diskSFR->dim(1)-1 ) {
		$metallicityHigh = "\\\\infty";
	    } else {
		$metallicityHigh = FormatSigFigs($metallicities->index($i),2);
	    }
	    my $label = "\\\\small Disk: \$".$metallicityLow."<Z<".$metallicityHigh."\$";
	    &GnuPlot::PrettyPlots::Prepare_Dataset(\$plot,
					  $diskTimeCentral, $diskSFR(:,($i)),
					  style => "point", symbol => [6,7], weight => [5,3],
					  color => $GnuPlot::PrettyPlots::colorPairs{${$GnuPlot::PrettyPlots::colorPairSequences{'sequence1'}}[$iColor]},
					  title => $label);
	}
    }
    &GnuPlot::PrettyPlots::Plot_Datasets($gnuPlot,\$plot);
    close($gnuPlot);
    &GnuPlot::LaTeX::GnuPlot2PDF($outputFileEPS);
    
}

# Write disk SFR data.
print gHndl "#\n";
print gHndl "# Disk star formation rate:\n";
print gHndl "# Time [Gyr] | SFR [M_Solar/yr]\n";
my $table = Text::Table->new();
for(my $j=0;$j<$diskTimeCentral->nelem;++$j) {
    my @rowData;
    $rowData[0] = $diskTimeCentral->index($j);
    push(@rowData,$diskSFR(($j),:)->list);
    $table->add(@rowData);
}
print gHndl $table;

# Write spheroid SFR data.
print gHndl "#\n";
print gHndl "# Spheroid star formation rate:\n";
print gHndl "# Time [Gyr] | SFR [M_Solar/yr]\n";
$table = Text::Table->new();
for(my $j=0;$j<$spheroidTimeCentral->nelem;++$j) {
    my @rowData;
    $rowData[0] = $spheroidTimeCentral->index($j);
    push(@rowData,$spheroidSFR(($j),:)->list);
    $table->add(@rowData);
}
print gHndl $table;

exit;
