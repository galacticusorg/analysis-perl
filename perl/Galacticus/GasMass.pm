# Contains a Perl module which implements total gas mass calculations for Galacticus.

package Galacticus::GasMass;
use strict;
use warnings;
use Cwd;
use lib $ENV{'GALACTICUS_ANALYSIS_PERL_PATH'}."/perl";
use PDL;
use PDL::NiceSlice;
use Data::Dumper;
use Galacticus::HDF5;

%Galacticus::HDF5::galacticusFunctions = ( %Galacticus::HDF5::galacticusFunctions,
    "massColdGas"   => \&Galacticus::GasMass::Get_Cold_Gas_Mass  ,
    "metalsColdGas" => \&Galacticus::GasMass::Get_Cold_Gas_Metals
    );

sub Get_Cold_Gas_Mass {
    my $model       = shift;
    my $dataSetName = $_[0];

    # Get available datasets.
    &Galacticus::HDF5::Get_Datasets_Available($model);

    # Decide which datasets to get.
    my @dataSetsRequired = ( "mergerTreeWeight" );
    my @gasMassComponents;
    push(@gasMassComponents,"diskMassGas"    )
	if ( exists($model->{'dataSetsAvailable'}->{'diskMassGas'    }) );
    push(@gasMassComponents,"spheroidMassGas")
	if ( exists($model->{'dataSetsAvailable'}->{'spheroidMassGas'}) );
    push(@dataSetsRequired,@gasMassComponents);

    # Get the datasets.
    &Galacticus::HDF5::Get_Dataset($model,\@dataSetsRequired);

    # Sum the gas masses.
    $model->{'dataSets'}->{$dataSetName} = pdl zeroes(nelem($model->{'dataSets'}->{'mergerTreeWeight'}));
    foreach my $component ( @gasMassComponents ) {
	$model->{'dataSets'}->{$dataSetName} += $model->{'dataSets'}->{$component};
    }

}

sub Get_Cold_Gas_Metals {
    my $model       = shift;
    my $dataSetName = $_[0];

    # Get available datasets.
    &Galacticus::HDF5::Get_Datasets_Available($model);

    # Decide which datasets to get.
    my @dataSetsRequired = ( "mergerTreeWeight" );
    my @gasMassComponents;
    push(@gasMassComponents,"diskAbundancesGasMetals"    )
	if ( exists($model->{'dataSetsAvailable'}->{'diskAbundancesGasMetals'    }) );
    push(@gasMassComponents,"spheroidAbundancesGasMetals")
	if ( exists($model->{'dataSetsAvailable'}->{'spheroidAbundancesGasMetals'}) );
    push(@dataSetsRequired,@gasMassComponents);

    # Get the datasets.
    &Galacticus::HDF5::Get_Dataset($model,\@dataSetsRequired);

    # Sum the gas masses.
    $model->{'dataSets'}->{$dataSetName} = pdl zeroes(nelem($model->{'dataSets'}->{'mergerTreeWeight'}));
    foreach my $component ( @gasMassComponents ) {
	$model->{'dataSets'}->{$dataSetName} += $model->{'dataSets'}->{$component};
    }

}

1;
