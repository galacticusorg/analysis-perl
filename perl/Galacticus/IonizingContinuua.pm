# Contains a Perl module which implements calculation of Lyman continuum luminosity in units of
# 10⁵⁰ photons/s.

# Contributions to this file from: Andrew Benson; Christoph Behrens.

package Galacticus::IonizingContinuua;
use strict;
use warnings;
use Cwd;
use lib $ENV{'GALACTICUS_ANALYSIS_PERL_PATH'}."/perl";
use PDL;
use XML::Simple;
use Galacticus::HDF5;
use Data::Dumper;

%Galacticus::HDF5::galacticusFunctions = ( %Galacticus::HDF5::galacticusFunctions,
    "^(disk|spheroid|total)(Lyman|Helium|Oxygen)ContinuumLuminosity:z[\\d\\.]+\$" => \&Galacticus::IonizingContinuua::Get_Ionizing_Luminosity
    );

sub Get_Ionizing_Luminosity {
    my $model       = shift;
    my $dataSetName = $_[0];
    # Check to see if a particular postprocessing chain was specified for Lyman-continuum flux.
    my $postprocessingChain = "";
    $postprocessingChain = ":".$model->{'ionizingContinuum'}->{'postProcessingChain'} 
        if ( exists($model->{'ionizingContinuum'}->{'postProcessingChain'}) );
    # Required constants.
    my $plancksConstant = pdl 6.6260680000000000e-34; # J s
    my $luminosityAB    = pdl 4.4659201576470211e+13; # W/Hz
    my $continuumUnits  = pdl 1.0000000000000000e+50; # photons/s
    # Continuum filter names.
    my %filterName =
	(
	 Lyman  => "Lyc",
	 Oxygen => "OxygenContinuum",
	 Helium => "HeliumContinuum"
	);
    # Find the continuum requested.
    if ( $dataSetName =~ m/^(disk|spheroid|total)(Lyman|Helium|Oxygen)ContinuumLuminosity:z([\d\.]+)$/ ) {
	# Extract the name of the component and redshift.
	my $component     = $1;
	my $continuumName = $2;
	my $redshift      = $3;
	# Read the relevant continuum filter.
	my $xml       = new XML::Simple;
	my $continuumFilter = $xml->XMLin($ENV{'GALACTICUS_DATA_PATH'}."/static/filters/".$filterName{$continuumName}.".xml");
	my $wavelengthMaximum = pdl 0.0;
	my $wavelengthMinimum = pdl 1.0e30;
	foreach my $datum ( @{$continuumFilter->{'response'}->{'datum'}} ) {
	    $datum =~ s/^\s*//;
	    my @columns = split(/\s+/,$datum);
	    my $wavelength   = pdl $columns[0];
	    my $transmission = pdl $columns[1];
	    if ( $transmission > 0.0 ) {
		$wavelengthMaximum = $wavelength
		    if ( $wavelength > $wavelengthMaximum );
		$wavelengthMinimum = $wavelength
		    if ( $wavelength < $wavelengthMinimum );
	    }
	}
	# Construct the name of the corresponding luminosity properties.
	&Galacticus::HDF5::Get_Datasets_Available($model);
	my @luminosityDatasets;
	my $luminosityDatasetName;
	if ( grep {$_ eq "diskLuminositiesStellar:".$filterName{$continuumName}.":rest:z".$redshift.$postprocessingChain} keys(%{$model->{'dataSetsAvailable'}}) ) {
	    $luminosityDatasetName->{'disk'} = "diskLuminositiesStellar:".$filterName{$continuumName}.":rest:z".$redshift.$postprocessingChain;
	} elsif ( grep {$_ eq "diskLuminositiesStellar:".$filterName{$continuumName}.":rest:z".$redshift.":zOut".$redshift.$postprocessingChain} keys(%{$model->{'dataSetsAvailable'}}) ) {
	    $luminosityDatasetName->{'disk'} = "diskLuminositiesStellar:".$filterName{$continuumName}.":rest:z".$redshift.":zOut".$redshift.$postprocessingChain;
	}
	if ( grep {$_ eq "spheroidLuminositiesStellar:".$filterName{$continuumName}.":rest:z".$redshift.$postprocessingChain} keys(%{$model->{'dataSetsAvailable'}}) ) {
	    $luminosityDatasetName->{'spheroid'} = "spheroidLuminositiesStellar:".$filterName{$continuumName}.":rest:z".$redshift.$postprocessingChain;
	} elsif ( grep {$_ eq "spheroidLuminositiesStellar:".$filterName{$continuumName}.":rest:z".$redshift.":zOut".$redshift.$postprocessingChain} keys(%{$model->{'dataSetsAvailable'}}) ) {
	    $luminosityDatasetName->{'spheroid'} = "spheroidLuminositiesStellar:".$filterName{$continuumName}.":rest:z".$redshift.":zOut".$redshift.$postprocessingChain;
	}
	if ( $component eq "total" ) {
	    die("luminosity datasets do not exist")
		unless ( exists($luminosityDatasetName->{'disk'}) && exists($luminosityDatasetName->{'spheroid'}) );
	    push(
		@luminosityDatasets                 ,
		$luminosityDatasetName->{'disk'    },
		$luminosityDatasetName->{'spheroid'}
		);
	} else {
	    die("luminosity datasets do not exist")
		unless ( exists($luminosityDatasetName->{$component}) );
	    push(
		@luminosityDatasets                 ,
		$luminosityDatasetName->{$component}
		);
	}
	&Galacticus::HDF5::Get_Dataset($model,\@luminosityDatasets);
	my $dataSets = $model->{'dataSets'};
	foreach ( @luminosityDatasets ) {
	    $dataSets->{$dataSetName} += $dataSets->{$_}*($luminosityAB/$plancksConstant/$continuumUnits)*log($wavelengthMaximum/$wavelengthMinimum);
	}
    } else {
	die("Galacticus::IonizingContinuua::Get_Ionizing_Luminosity: unrecognized continuum name ".$dataSetName);
    }
}

1;
