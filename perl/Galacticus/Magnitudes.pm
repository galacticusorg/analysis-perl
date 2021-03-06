# Contains a Perl module which implements magnitude calculations for Galacticus.

package Galacticus::Magnitudes;
use strict;
use warnings;
use Cwd;
use lib $ENV{'GALACTICUS_ANALYSIS_PERL_PATH'}."/perl";
use PDL;
use Data::Dumper;
use XML::Simple;
use Galacticus::HDF5;
use Galacticus::DustAttenuation;
use Galacticus::Luminosities;
use Galacticus::Survey;

%Galacticus::HDF5::galacticusFunctions = ( %Galacticus::HDF5::galacticusFunctions,
    "^magnitude([^:]+):([^:]+):([^:]+):z([\\d\\.]+)(:dust[^:]+)?(:vega|:AB)?"         => \&Galacticus::Magnitudes::Get_Magnitude                 ,
    "^apparentMagnitude([^:]+):([^:]+):([^:]+):z([\\d\\.]+)(:dust[^:]+)?(:vega|:AB)?" => \&Galacticus::Magnitudes::Get_Apparent_Magnitude        ,
    "^magnitude:.*(:vega|:AB)?"                                                       => \&Galacticus::Magnitudes::Get_Generic_Magnitude         ,
    "^apparentMagnitude:.*"                                                           => \&Galacticus::Magnitudes::Get_Generic_Apparent_Magnitude
    );

my %vegaOffsets;
my $vegaMagnitude;
my $filter;

sub Get_Magnitude {
    my $dataSet = shift;
    my $dataSetName = $_[0];
    # Check that the dataset name matches the expected regular expression.
    if ( $dataSetName =~ m/^magnitude([^:]+):([^:]+):([^:]+):z([\d\.]+)(:dust[^:]+)?(:vega|:AB)?/ ) {
	# Extract the dataset name information.
	my $component     = $1;
	$filter           = $2;
	my $frame         = $3;
	my $redshift      = $4;
	my $dustExtension = $5;
	$dustExtension = ""
	    unless ( defined($dustExtension) );
	if ( defined($6) && $6 eq ":vega" ) {
	    $vegaMagnitude = 1;
	} else {
	    $vegaMagnitude = 0;
	}
	# Construct the name of the corresponding luminosity property.
	my $luminosityDataset = lc($component)."LuminositiesStellar:".$filter.":".$frame.":z".$redshift.$dustExtension;
	&Galacticus::HDF5::Get_Dataset($dataSet,[$luminosityDataset]);
	my $dataSets = $dataSet->{'dataSets'};
	$dataSets->{$dataSetName} = -2.5*log10($dataSets->{$luminosityDataset}+1.0e-40);
	# If a Vega magnitude was requested, add the appropriate offset.
	if ( $vegaMagnitude == 1 ) {
	    unless ( exists($vegaOffsets{$filter}) ) {
		my $filterPath = $ENV{'GALACTICUS_DATA_PATH'}."/static/filters/".$filter.".xml";
		die("Get_Magnitudes(): can not find filter file for: ".$filter) unless ( -e $filterPath );
		my $xml = new XML::Simple;
		my $filterData = $xml->XMLin($filterPath);
		unless ( exists($filterData->{'vegaOffset'}) ) {
		    # No Vega offset data available for filter - run the script that computes it.
		    system("scripts/filters/vega_offset_effective_lambda.pl");
		    $filterData = $xml->XMLin($filterPath);
		    die ("Get_Magnitudes(): failed to compute Vega offsets for filters") unless ( exists($filterData->{'vegaOffset'}) );
		}
		$vegaOffsets{$filter} = pdl $filterData->{'vegaOffset'};
	    }
	    $dataSets->{$dataSetName} += $vegaOffsets{$filter};
	}
    } else {
	die("Get_Magnitude(): unable to parse data set: ".$dataSetName);
    }
}

sub Get_Apparent_Magnitude {
    my $dataSet     = shift;
    my $dataSetName = $_[0];
    # Construct the name of the corresponding absolute magnitude property.
    (my $absoluteMagnitudeDataset = $dataSetName) =~ s/^apparentMagnitude/magnitude/;
    &Galacticus::HDF5::Get_Dataset($dataSet,[$absoluteMagnitudeDataset,"distanceModulus"]);
    my $dataSets = $dataSet->{'dataSets'};
    $dataSets->{$dataSetName} = $dataSets->{$absoluteMagnitudeDataset}+$dataSets->{'distanceModulus'};
}

sub Get_Generic_Magnitude {
    my $dataSet     = shift;
    my $dataSetName = $_[0];
    # Construct the name of the corresponding luminosity property.
    (my $luminosityDataset = $dataSetName) =~ s/^magnitude:/luminosity:/;
    $luminosityDataset =~ s/(:vega|:AB)$//;
    &Galacticus::HDF5::Get_Dataset($dataSet,[$luminosityDataset]);
    my $dataSets = $dataSet->{'dataSets'};
    $dataSets->{$dataSetName} = -2.5*log10($dataSets->{$luminosityDataset}+1.0e-40);
    # If a Vega magnitude was requested, add the appropriate offset.
    if ( $vegaMagnitude == 1 ) {
	unless ( exists($vegaOffsets{$filter}) ) {
	    my $filterPath = $ENV{'GALACTICUS_DATA_PATH'}."/static/filters/".$filter.".xml";
	    die("Get_Magnitudes(): can not find filter file for: ".$filter) unless ( -e $filterPath );
	    my $xml = new XML::Simple;
	    my $filterData = $xml->XMLin($filterPath);
	    unless ( exists($filterData->{'vegaOffset'}) ) {
		# No Vega offset data available for filter - run the script that computes it.
		system("scripts/filters/vega_offset_effective_lambda.pl");
		$filterData = $xml->XMLin($filterPath);
		die ("Get_Magnitudes(): failed to compute Vega offsets for filters") unless ( exists($filterData->{'vegaOffset'}) );
	    }
	    $vegaOffsets{$filter} = pdl $filterData->{'vegaOffset'};
	}
	$dataSets->{$dataSetName} += $vegaOffsets{$filter};
    }
}

sub Get_Generic_Apparent_Magnitude {
    my $dataSet     = shift;
    my $dataSetName = $_[0];
    # Construct the name of the corresponding absolute magnitude property.
    (my $absoluteMagnitudeDataset = $dataSetName) =~ s/^apparentMagnitude:/magnitude:/;
    &Galacticus::HDF5::Get_Dataset($dataSet,[$absoluteMagnitudeDataset,"distanceModulus"]);
    my $dataSets = $dataSet->{'dataSets'};
    $dataSets->{$dataSetName} = $dataSets->{$absoluteMagnitudeDataset}+$dataSets->{'distanceModulus'};
}

1;
