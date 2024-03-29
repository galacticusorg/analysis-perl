#!/usr/bin/env perl
use strict;
use warnings;
use Cwd;
use lib $ENV{'GALACTICUS_ANALYSIS_PERL_PATH'}."/perl";
use PDL;
use PDL::NiceSlice;
use PDL::IO::HDF5;
use Data::Dumper;
use GnuPlot::PrettyPlots;
use GnuPlot::LaTeX;
use Galacticus::HDF5;
use XMP::MetaData;

# Plot the rotation curve of a galaxy computed by Galacticus.
# Andrew Benson (04-February-2013)

# Get ourself.
my $self             = $0;

# Read arguments.
die("Usage: plotRotationCurve.pl <galacticusFile> <output> <mergerTreeIndex> <nodeIndex> <outputFile>")
    unless ( scalar(@ARGV) >= 5 );
my $galacticusFile   = $ARGV[0];
my $outputNumber     = $ARGV[1];
my $mergerTreeIndex  = $ARGV[2];
my $nodeIndex        = $ARGV[3];
my $outputFile       = $ARGV[4];

# Get named arguments.
my %arguments;
my $iArg = 4;
while ( $iArg < scalar(@ARGV)-1 ) {
    ++$iArg;
    if ( $ARGV[$iArg] =~ m/^\-\-(.*)/ ) {
	$arguments{$1} = $ARGV[$iArg+1];
	++$iArg;
    }
}

# Initialize the model object.
my $galacticus;
$galacticus->{'file' } = $galacticusFile;
$galacticus->{'store'} = 0;
$galacticus->{'tree' } = "all";
&Galacticus::HDF5::Get_Parameters($galacticus);
&Galacticus::HDF5::Get_Times     ($galacticus);
my $redshift;
for(my $i=0;$i<nelem($galacticus->{'outputs'}->{'outputNumber'});++$i) {
    $redshift = $galacticus->{'outputs'}->{'redshift'}->(($i))
       if ( $galacticus->{'outputs'}->{'outputNumber'}->(($i)) == $outputNumber );
}
die('plotRotationCurve.pl: unrecognized output number')
    unless ( defined($redshift) );
&Galacticus::HDF5::Select_Output         ($galacticus,$redshift);
&Galacticus::HDF5::Get_Datasets_Available($galacticus          );

# Define datasets to read.
my @dataSets = ( 'nodeIndex', 'mergerTreeIndex' );
my @rotationCurveDataSets;
foreach ( keys(%{$galacticus->{'dataSetsAvailable'}}) ) {
    push(@rotationCurveDataSets,$_)
	if ( $_ =~ m/^rotationCurve:/ );
    push(@dataSets,$_)
	if
	(
	 $_ =~ m/^diskRadius$/
	 ||
	 $_ =~ m/^spheroidRadius$/
	 ||
	 $_ =~ m/^darkMatterProfileScale$/
	 ||
	 $_ =~ m/^nodeVirialRadius$/
	);
}
push(@dataSets,@rotationCurveDataSets);
&Galacticus::HDF5::Get_Dataset($galacticus,\@dataSets);

# Locate the requested node.
my $selectedNode = 
    which
    (
     ($galacticus->{'dataSets'}->{'mergerTreeIndex'} == $mergerTreeIndex)
     &
     ($galacticus->{'dataSets'}->{'nodeIndex'      } == $nodeIndex      )
    );
die('plotRotationCurve.pl: unique node was not found')
    unless ( nelem($selectedNode) == 1 );
my $selected = $selectedNode->((0));

# Extract rotation curve by category and radius.
my $rotationCurve;
foreach ( @rotationCurveDataSets ) {
    if ( $_ =~ m/^rotationCurve:([^:]+):(.*):([0-9\.eE\-\+]+)$/ ) {
	my $scale  = $1;
	my $type   = $2;
	my $radius = $3;
	my $scaleFactor = 1.0;
	if ( $scale eq "diskRadius"             ) {
	    $scaleFactor = $galacticus->{'dataSets'}->{'diskRadius'            }->(($selected))                ;
	} elsif ( $scale eq "spheroidRadius"         ) {
	    $scaleFactor = $galacticus->{'dataSets'}->{'spheroidRadius'        }->(($selected))                ;
	} elsif ( $scale eq "diskHalfMassRadius"     ) {
	    # Ensure that exponential disks are being used.
	    die('plotRotationCurve.pl: only exponential disks are supported at present')
		unless ( $galacticus->{'parameters'}->{'comopnentDisk'}->{'value'} eq "exponential" );
	    $scaleFactor = $galacticus->{'dataSets'}->{'diskRadius'   }->(($selected))*1.678346990    ;
	} elsif ( $scale eq "spheroidHalfMassRadius" ) {
	    # Ensure that Hernquist spheroids are being used.
	    die('plotRotationCurve.pl: only Hernquist spheroids are supported at present')
		unless ( $galacticus->{'parameters'}->{'spheroidMassDistribution'}->{'value'} eq "hernquist" );
	    $scaleFactor = $galacticus->{'dataSets'}->{'spheroidRadius'        }->(($selected))/(sqrt(2.0)-1.0);
	} elsif ( $scale eq "virialRadius"           ) {
	    $scaleFactor = $galacticus->{'dataSets'}->{'nodeVirialRadius'      }->(($selected))                ;
	} elsif ( $scale eq "darkMatterScaleRadius"  ) {
	    $scaleFactor = $galacticus->{'dataSets'}->{'darkMatterProfileScale'}->(($selected))                ;
	} else { 
	    die('plotRotationCurve.pl: unrecognized scale');
	}
	$radius *= 1000.0*$scaleFactor;
	my $velocity = $galacticus->{'dataSets'}->{$_}->(($selected));
	if ( $radius > 0.0 ) {
	    if ( exists($rotationCurve->{$type}) ) {
		$rotationCurve->{$type}->{'radius'  } = $rotationCurve->{$type}->{'radius'  }->append($radius  );
		$rotationCurve->{$type}->{'velocity'} = $rotationCurve->{$type}->{'velocity'}->append($velocity);
	    } else {
		$rotationCurve->{$type}->{'radius'  } = pdl                                           $radius   ;
		$rotationCurve->{$type}->{'velocity'} = pdl                                           $velocity ;
	    }
	}
    } else {
	die('plotRotationCurve.pl: non-conforming rotation curve property name');
    }
}

# Define datasets to plot.
my @toPlot =
(
 {
     type  => "all:dark:unloaded",
     color => "slateGray",
     label => "dark matter (uncontracted)"
 },
 {
     type  => "all:dark:loaded",
     color => "blackGray",
     label => "dark matter (contracted)"
 },
 {
     type  => "spheroid:baryonic:loaded",
     color => "indianRed",
     label => "spheroid"
 },
 {
     type  => "disk:baryonic:loaded",
     color => "lightSkyBlue",
     label => "disk"
 },
 {
     type  => "all:baryonic:loaded",
     color => "mediumSeaGreen",
     label => "baryonic"
 },
 {
     type  => "all:all:loaded",
     color => "redYellow",
     label => "total"
 },
);

# Find ranges for plotting.
my $radiusMaximum   = 0.0;
my $velocityMaximum = 0.0;
foreach ( @toPlot ) {
    $radiusMaximum   = max($rotationCurve->{$_->{'type'}}->{'radius'  },$radiusMaximum  );
    $velocityMaximum = max($rotationCurve->{$_->{'type'}}->{'velocity'},$velocityMaximum);
}
$velocityMaximum *= 1.05;
$radiusMaximum = $arguments{'maximumRadius'}
   if ( exists($arguments{'maximumRadius'}) );

# Create a plot of the rotation curve.
my $plot;
my $gnuPlot;
my $plotFile = $outputFile;
(my $plotFileEPS = $plotFile) =~ s/\.pdf$/.eps/;
open($gnuPlot,"|gnuplot 1>/dev/null 2>&1");
print $gnuPlot "set terminal epslatex color colortext lw 2 7\n";
print $gnuPlot "set output '".$plotFileEPS."'\n";
print $gnuPlot "set title 'Rotation curve for output ".$outputNumber.", tree ".$mergerTreeIndex.", node ".$nodeIndex."' offset 0,-0.25\n";
print $gnuPlot "set xlabel 'Radius; [kpc]'\n";
print $gnuPlot "set ylabel 'Rotation curve; [km/s]'\n";
print $gnuPlot "set lmargin screen 0.15\n";
print $gnuPlot "set rmargin screen 0.95\n";
print $gnuPlot "set bmargin screen 0.15\n";
print $gnuPlot "set tmargin screen 0.95\n";
print $gnuPlot "set key spacing 1.2\n";
print $gnuPlot "set key at screen 0.275,0.16\n";
print $gnuPlot "set key left\n";
print $gnuPlot "set key bottom\n";
print $gnuPlot "set xrange [0.0:".$radiusMaximum  ."]\n";
print $gnuPlot "set yrange [0.0:".$velocityMaximum."]\n";
print $gnuPlot "set pointsize 2.0\n";
foreach ( @toPlot ) {
    if ( any($rotationCurve->{$_->{'type'}}->{'velocity'} > 0.0) ) {
	my $sortIndex = $rotationCurve->{$_->{'type'}}->{'radius'}->qsorti();
	&GnuPlot::PrettyPlots::Prepare_Dataset(
	    \$plot,
	    $rotationCurve->{$_->{'type'}}->{'radius'  }->($sortIndex),
	    $rotationCurve->{$_->{'type'}}->{'velocity'}->($sortIndex),
	    title      => $_->{'label'},
	    style      => "line",
	    weight     => [3,1],
	    color      => $GnuPlot::PrettyPlots::colorPairs{$_->{'color'}},
	    );
    }
}
&GnuPlot::PrettyPlots::Plot_Datasets($gnuPlot,\$plot);
close($gnuPlot);
&GnuPlot::LaTeX::GnuPlot2PDF($plotFileEPS, margin => 2);
&XMP::MetaData::Write($plotFile,$galacticusFile,$self);

exit;
