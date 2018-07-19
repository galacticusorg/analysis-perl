# Contains a Perl module which implements baryon fraction calculations for Galacticus.

package Galacticus::Baryons;
use strict;
use warnings;
use Cwd;
use lib $ENV{'GALACTICUS_ANALYSIS_PERL_PATH'}."/perl";
use PDL;
use Data::Dumper;
use Galacticus::HDF5;

%Galacticus::HDF5::galacticusFunctions = ( %Galacticus::HDF5::galacticusFunctions,
    "hotHalo(Fraction|Frac)" => \&Galacticus::Baryons::Get_hotHaloFraction
    );

sub Get_hotHaloFraction {
    my $dataSet = shift;
    my $dataSetName = $_[0];
    &Galacticus::HDF5::Get_Dataset($dataSet,['hotHaloMass','nodeMass']);
    my $dataSets = $dataSet->{'dataSets'};
    $dataSets->{$dataSetName} = $dataSets->{'hotHaloMass'}/$dataSets->{'nodeMass'};
}

1;
