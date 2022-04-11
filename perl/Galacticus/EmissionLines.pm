# Contains a Perl module which implements calculation of emission line luminosities, based on
# the methodology of Panuzzo et al. (2003; http://adsabs.harvard.edu/abs/2003A%26A...409...99P).

package Galacticus::EmissionLines;
use strict;
use warnings;
use Cwd;
use lib $ENV{'GALACTICUS_ANALYSIS_PERL_PATH'}."/perl";
use lib $ENV{'GALACTICUS_EXEC_PATH'         }."/perl";
use PDL;
use PDL::NiceSlice;
use PDL::IO::HDF5;
use PDL::GSL::INTEG;
use Storable;
use Data::Dumper;
use Cloudy;
use Galacticus::Options;
use Galacticus::Launch::Hooks;
use Galacticus::Launch::PBS;
use Galacticus::Launch::Slurm;
use Galacticus::Launch::Local;
use Galacticus::HDF5;
use Galacticus::IonizingContinuua;
use Galacticus::Filters;

%Galacticus::HDF5::galacticusFunctions = ( %Galacticus::HDF5::galacticusFunctions,
    "^(disk|spheroid)LineLuminosity:[^:]+(:[^:]+){0,2}:z[\\d\\.]+\$" => \&Galacticus::EmissionLines::Get_Line_Luminosity      ,
    "^totalLineLuminosity:[^:]+(:[^:]+){0,2}:z[\\d\\.]+\$"           => \&Galacticus::EmissionLines::Get_Total_Line_Luminosity
    );

# Module data.
our $emissionLines;
our $energyThermal;
our $lineData;
our $tableFileName;

# Line list.
our %lineList;

# Constants used in these calculations.
our $Pi                          = pdl  3.1415927000000000e+00;
our $centi                       = pdl  1.0000000000000000e-02;
our $mega                        = pdl  1.0000000000000000e+06;
our $erg                         = pdl  1.0000000000000000e-07; # J
our $plancksConstant             = pdl  6.6260700400000000e-34; # J s
our $speedOfLight                = pdl  2.9979245800000000e+08; # m/s
our $angstroms                   = pdl  1.0000000000000000e-10; # m
our $luminositySolar             = pdl  3.8390000000000000e+26; # W
our $luminosityAB                = pdl  4.4659201576470211e+13; # W/Hz
our $massSolar                   = pdl  1.9891000000000000e+30; # kg
our $parsec                      = pdl  3.0856775800000000e+16; # m
our $megaParsec                  = pdl  $mega*$parsec         ; # m
our $massAtomic                  = pdl  1.6605389200000000e-27; # kg
our $atomicMassHydrogen          = pdl  1.0079400000000000e+00; # amu
our $massFractionHydrogen        = pdl  0.7070000000000000e+00; # Solar composition
our $metallicitySolar            = pdl  0.0188000000000000e+00; # Solar metallicity
our $boltzmannsConstant          = pdl  1.3810000000000000e-23; # J/K
our $electronVolt                = pdl  1.6021766340000000e-19; # J
our $rydbergEnergy               = pdl 13.6056931229940000e+00; # eV
our $hydrogenOneIonizationEnergy = pdl 13.5990000000000000e+00; # eV
our $heliumOneIonizationEnergy   = pdl 24.5880000000000000e+00; # eV
our $heliumTwoIonizationEnergy   = pdl 54.4180000000000000e+00; # eV
our $oxygenTwoIonizationEnergy   = pdl 35.1180000000000000e+00; # eV
our $massGMC                     = pdl  3.7000000000000000e+07; # Mass of a giant molecular cloud at critical surface density; M☉.
our $densitySurfaceCritical      = pdl  8.5000000000000000e+13; # Critical surface density for molecular clouds; M☉ Mpc⁻².

sub Get_Total_Line_Luminosity {
    my $model       = shift;
    my $dataSetName = $_[0];
    (my $diskDataset     = $dataSetName) =~ s/^total/disk/;
    (my $spheroidDataset = $dataSetName) =~ s/^total/spheroid/;
    &Galacticus::HDF5::Get_Dataset($model,[$diskDataset,$spheroidDataset]);
    my $dataSets = $model->{'dataSets'};
    $dataSets->{$dataSetName} =
	+$dataSets->{$diskDataset}
        +$dataSets->{$spheroidDataset};
}

sub Get_Line_Luminosity {
    my $model       = shift;
    my $dataSetName = $_[0];
    # Define interpolants.
    my @interpolant = 
	(
	 'metallicity'                 ,
	 'densityHydrogen'             ,
	 'ionizingFluxHydrogen'        ,
	 'ionizingFluxHeliumToHydrogen',
	 'ionizingFluxOxygenToHelium'
	);
    # Define HII region properties.
    my $efficiencyHIIRegion = pdl 1.0e-2; # Efficiency (mass fraction converted into stars).
    my $massHIIRegion       = pdl 7.5e+3; # Solar masses.
    my $durationHIIRegion   = pdl 1.0e-3; # Gyr.
    my $densityMultiplier   = pdl 1.0e+0;
    $efficiencyHIIRegion .= $model->{'emissionLines'}->{'hiiRegion'}->{'efficiency'       }
        if ( exists($model->{'emissionLines'}->{'hiiRegion'}->{'efficiency'       }) );
    $massHIIRegion       .= $model->{'emissionLines'}->{'hiiRegion'}->{'mass'             }
        if ( exists($model->{'emissionLines'}->{'hiiRegion'}->{'mass'             }) );
    $durationHIIRegion   .= $model->{'emissionLines'}->{'hiiRegion'}->{'lifetime'         }
        if ( exists($model->{'emissionLines'}->{'hiiRegion'}->{'lifetime'         }) );
    $densityMultiplier   .= $model->{'emissionLines'}->{'hiiRegion'}->{'densityMultiplier'}
        if ( exists($model->{'emissionLines'}->{'hiiRegion'}->{'densityMultiplier'}) );
    # Read the emission lines file if necessary.
    unless ( defined($emissionLines) ) {
	my $tableFileName = $ENV{'GALACTICUS_DATA_PATH'}."/static/hiiRegions/emissionLines.hdf5";
	unless ( -e $tableFileName ) {
	    &Generate_Tables($tableFileName,$model);
	    &Patch_Tables   ($tableFileName,$model);
	}
	$emissionLines->{'file'} = new PDL::IO::HDF5($tableFileName);
	$emissionLines->{$_} = log10($emissionLines->{'file'}->dataset($_)->get())
	    foreach ( @interpolant );
	@{$emissionLines->{'lineNames'}} = $emissionLines->{'file'}->group('lines')->datasets();
    }
    # Check that the dataset name matches the expected regular expression.
    if ( $dataSetName =~ m/^(disk|spheroid)LineLuminosity:([^:]+)(:[^:]+)??(:[^:]+)??:z([\d\.]+)$/ ) {
	# Extract the name of the line and redshift.
	my $component  = $1;
	my $lineLabel  = $2;
	my $filterName = $3;
	my $frame      = $4;
	my $redshift   = $5;
	# Load the line if necessary.
	unless ( exists($emissionLines->{'lines'}->{$lineLabel}) ) {
	    die("Galacticus::EmissionLines: unable to find line '".$lineLabel."' in database")
		unless ( grep {$_ eq $lineLabel} @{$emissionLines->{'lineNames'}} );
	    $emissionLines ->{'lines'}->{$lineLabel}->{'luminosity'}  = $emissionLines->{'file'}->group('lines')->dataset($lineLabel)->get    (            );
	    ($emissionLines->{'lines'}->{$lineLabel}->{'wavelength'}) = $emissionLines->{'file'}->group('lines')->dataset($lineLabel)->attrGet('wavelength');
	}
	# Construct the name of the corresponding luminosity property.
	my @properties = (
	    $component."LymanContinuumLuminosity:z" .$redshift,
	    $component."HeliumContinuumLuminosity:z".$redshift,
	    $component."OxygenContinuumLuminosity:z".$redshift,
	    $component."MassGas"                              ,
	    $component."AbundancesGasMetals"                  ,
	    $component."Radius"                               ,
	    $component."StarFormationRate"
	    );
	&Galacticus::HDF5::Get_Dataset($model,\@properties);
	my $dataSets = $model->{'dataSets'};
	my $properties;
	# Compute the metallicity in Solar units.
	my $hasGas = which($dataSets->{$component."MassGas"} > 0.0);
	$properties->{'metallicity'} = pdl zeroes(nelem($dataSets->{$component."MassGas"}));
	$properties->{'metallicity'}->($hasGas) .=
	    log10(
		+$dataSets->{$component."AbundancesGasMetals"}->($hasGas)
		/$dataSets->{$component."MassGas"            }->($hasGas)
		/$metallicitySolar
	    );
	# Compute hydrogen density.
	$properties->{'densityHydrogen'} = pdl zeroes(nelem($dataSets->{$component."MassGas"}));
	my $densitySurfaceGas                       = 
	    +$dataSets->{$component."MassGas"}->($hasGas)
	    /$dataSets->{$component."Radius" }->($hasGas)**2
	    /2.0
	    /$Pi;
	my $massClouds                               = 
	    +$massGMC
	    *$densitySurfaceGas
	    /$densitySurfaceCritical;
	my $densitySurfaceClouds                     = 
	    +max(                               
	         +$densitySurfaceCritical,       
	         +$densitySurfaceGas             
	        );
	$properties->{'densityHydrogen'}->($hasGas) .=
	    +log10(                             
	           +3.0                       
	           /4.0                       
	           *sqrt($Pi        )             
	           /sqrt($massClouds)            
	           *$densitySurfaceClouds**1.5
	           /$megaParsec          **3     
	           *$centi               **3     
	           *$massFractionHydrogen         
	           *$massSolar                   
	           /$atomicMassHydrogen
	           /$massAtomic
	           *$densityMultiplier
	    );
	# Compute Lyman continuum luminosity.
	my $hasFlux = which($dataSets->{$component."LymanContinuumLuminosity:z".$redshift} > 0.0);
	$properties->{'ionizingFluxHydrogen'} = pdl zeroes(nelem($dataSets->{$component."MassGas"}));
	$properties->{'ionizingFluxHydrogen'}->($hasFlux) .=
	    log10($dataSets->{$component."LymanContinuumLuminosity:z".$redshift}->($hasFlux))+50.0;
	# Compute helium to Lyman continuum luminosity ratio.
	$properties->{'ionizingFluxHeliumToHydrogen'} = pdl zeroes(nelem($dataSets->{$component."MassGas"}));
	$properties->{'ionizingFluxHeliumToHydrogen'}->($hasFlux) .=
	    log10(
		+$dataSets->{$component."HeliumContinuumLuminosity:z".$redshift}->($hasFlux)
		/$dataSets->{$component."LymanContinuumLuminosity:z" .$redshift}->($hasFlux)
	    );
	# Compute oxygen to helium continuum luminosity ratio.
	$properties->{'ionizingFluxOxygenToHelium'} = pdl zeroes(nelem($dataSets->{$component."MassGas"}));
	$properties->{'ionizingFluxOxygenToHelium'}->($hasFlux) .=
	    log10(
		+$dataSets->{$component."OxygenContinuumLuminosity:z".$redshift}->($hasFlux)
		/$dataSets->{$component."HeliumContinuumLuminosity:z".$redshift}->($hasFlux)
	    );
	# Check whether a raw line luminosity, or the luminosity under a filter is required.
	my $luminosityMultiplier = pdl 1.0;
	if ( defined($filterName) ) {
	    # A filter was specified.
	    $filterName =~ s/^://;
	    # A frame must also be specified in this case.
	    if ( defined($frame) ) {
		$frame =~ s/^://;
		die("Get_Line_Luminosity(): frame must be either 'rest' or 'observed'")
		    unless ( $frame eq "rest" || $frame eq "observed" );
	    } else {
		die("Get_Line_Luminosity(): a frame ('rest' or 'observed') must be specified");
	    }
	    # Load the filter transmission curve.
	    my $filterFile = $ENV{'GALACTICUS_DATA_PATH'}."/static/filters/".$filterName.".xml";
	    (my $wavelengths, my $response) = &Galacticus::Filters::Load($filterName);	  
	    # Check if the line lies within the extent of the filter.
	    my $observedWavelength = $emissionLines->{'lines'}->{$lineLabel}->{'wavelength'}->copy();
	    $observedWavelength *= (1.0+$redshift) if ( $frame eq "observed" );
	    if ( $observedWavelength >= $wavelengths((0)) && $observedWavelength <= $wavelengths((-1)) ) {
		# Interpolate the transmission to the line wavelength.
		(my $transmission, my $interpolateError)
		    = interpolate($observedWavelength,$wavelengths,$response);
		# Integrate a zero-magnitude AB source under the filter.
		my $filterLuminosityAB = pdl 0.0;
		for(my $i=0;$i<nelem($wavelengths);++$i) {
		    my $deltaWavelength;
		    if ( $i == 0 ) {
			$deltaWavelength = $wavelengths->index($i+1)-$wavelengths->index($i  );
		    } elsif ( $i == nelem($wavelengths)-1 ) {
			$deltaWavelength = $wavelengths->index($i  )-$wavelengths->index($i-1);
		    } else {
			$deltaWavelength = $wavelengths->index($i+1)-$wavelengths->index($i-1);
		    }
		    $filterLuminosityAB 
			+=
			+$speedOfLight
			/$angstroms
			*$luminosityAB
			/$luminositySolar
			*$response       ->index($i)
			*$deltaWavelength
			/$wavelengths    ->index($i)**2
			/2.0;
		}
		# Compute the multiplicative factor to convert line luminosity to luminosity in
		# AB units in the filter.
		$luminosityMultiplier .= $transmission/$filterLuminosityAB;
		# Galacticus defines observed-frame luminosities by simply redshifting the
		# galaxy spectrum without changing the amplitude of F_ν (i.e. the compression of
		# the spectrum into a smaller range of frequencies is not accounted for). For a
		# line, we can understand how this should affect the luminosity by considering
		# the line as a Gaussian with very narrow width (such that the full extent of
		# the line always lies in the filter). In this case, when the line is redshifted
		# the width of the Gaussian (in frequency space) is reduced, while the amplitude
		# is unchanged (as, once again, we are not taking into account the compression
		# of the spectrum into the smaller range of frequencies). The integral over the
		# line will therefore be reduced by a factor of (1+z) - this factor is included
		# in the following line. Note that, when converting this observed luminosity
		# into an observed flux a factor of (1+z) must be included to account for
		# compression of photon frequencies (just as with continuum luminosities in
		# Galacticus) which will counteract the effects of the 1/(1+z) included below.
		$luminosityMultiplier /= (1.0+$redshift)
		    if ( $frame eq "observed" );
	    } else {
		# Line lies outside of the filter, so it contributes zero luminosity.
		$luminosityMultiplier .= 0.0;
	    }
	}
	# Find the number of HII regions.
	my $ageWindow         = $durationHIIRegion;
	$ageWindow = $model->{'ionizingContinuum'}->{'ageWindow'}
	    if ( exists($model->{'ionizingContinuum'}->{'ageWindow'}) && $model->{'ionizingContinuum'}->{'ageWindow'} < $ageWindow );
	my $numberHIIRegion   = 
	    +$dataSets->{$component."StarFormationRate"}
	    *$ageWindow
	    /$massHIIRegion
	    /$efficiencyHIIRegion;
	# Convert the hydrogen ionizing luminosity to be per HII region.
	$properties->{'ionizingFluxHydrogen'} -= log10($numberHIIRegion);
	# Find interpolation indices for all five interpolants.
	my $index;
	my $error;
	($index->{$_}, $error->{$_}) = 
	    interpolate(
		               $properties   ->{$_}  ,
		               $emissionLines->{$_}  ,
		sequence(nelem($emissionLines->{$_}))
	    )
	    foreach ( @interpolant );
	my $indices = 
	    cat(
		$index->{'ionizingFluxOxygenToHelium'  },
		$index->{'ionizingFluxHeliumToHydrogen'},
		$index->{'ionizingFluxHydrogen'        },
		$index->{'densityHydrogen'             },
		$index->{'metallicity'                 }
	    )->xchg(0,1);
	# Interpolate in all five parameters to get the line luminosity per HII region.
	my $lineLuminosityPerHIIRegion = 
	    $emissionLines->{'lines'}->{$lineLabel}->{'luminosity'}->interpND($indices);
	# Convert to line luminosity in Solar luminosities (or AB maggies if a filter was specified).
	$dataSets->{$dataSetName} = 
	    +$luminosityMultiplier
	    *$lineLuminosityPerHIIRegion
	    *$erg
	    *$numberHIIRegion
	    /$luminositySolar;
    } else {
	die("Get_Line_Luminosity(): unable to parse data set: ".$dataSetName);
    }
}

sub setLineList {
    # Set the line lists.
    my $cloudyVersion = shift();
    (my $cloudyVersionMajor = $cloudyVersion) =~ s/\.\d+$//;
    if ( $cloudyVersionMajor >= 17 ) {
	%lineList =
	    (
	     "H  1      6564.62A" => "balmerAlpha6565"  ,
	     "H  1      4862.69A" => "balmerBeta4863"   ,
	     "H  1      4341.68A" => "balmerGamma4342"  ,
	     "H  1      4102.89A" => "balmerDelta4103"  ,
	     "H  1      1.87561m" => "paschenAlpha18756",
	     "H  1      1.28215m" => "paschenBeta12822" ,
	     "O  2      3727.09A" => "oxygenII3727"     ,
	     "O  2      3729.88A" => "oxygenII3730"     ,
	     "O  3      4960.29A" => "oxygenIII4960"    ,
	     "O  3      5008.24A" => "oxygenIII5008"    ,
	     "O  3      4932.60A" => "oxygenIII4933"    ,
	     "N  2      6585.27A" => "nitrogenII6585"   ,
	     "N  2      6549.86A" => "nitrogenII6550"   ,
	     "S  2      6732.67A" => "sulfurII6733"     ,
	     "S  2      6718.29A" => "sulfurII6718"     ,
	     "S  3      9071.11A" => "sulfurIII9071"    ,
	     "S  3      9533.23A" => "sulfurIII9533"
	    );
    } else {
	# Prior to Cloudy v17 a shorter labelling was used.
	%lineList =
	    (
	     "H  1  6563A" => "balmerAlpha6563"  ,
	     "H  1  4861A" => "balmerBeta4861"   ,
	     "H  1  4340A" => "balmerGamma4340"  ,
	     "H  1  4102A" => "balmerDelta4102"  ,
	     "H  1 1.875m" => "paschenAlpha18750",
	     "H  1 1.282m" => "paschenBeta12820" ,
	     "O II  3726A" => "oxygenII3726"     ,
	     "O II  3729A" => "oxygenII3729"     ,
	     "O  3  4959A" => "oxygenIII4959"    ,
	     "O  3  5007A" => "oxygenIII5007"    ,
	     "O  3  4931A" => "oxygenIII4931"    ,
	     "N  2  6584A" => "nitrogenII6584"   ,
	     "N  2  6548A" => "nitrogenII6548"   ,
	     "S II  6731A" => "sulfurII6731"     ,
	     "S II  6716A" => "sulfurII6716"     ,
	     "S  3  9069A" => "sulfurIII9069"    ,
	     "S  3  9532A" => "sulfurIII9531"
	    );
    }
}

sub Generate_Tables {
    # Generate tables of line luminosities using Cloudy.
    $tableFileName = shift();
    my $model      = shift();
    # Parse config options.
    my $queueManager = &Galacticus::Options::Config(                'queueManager' );
    my $queueConfig  = &Galacticus::Options::Config($queueManager->{'manager'     });
    # Get path to Cloudy.
    my %cloudyOptions = %{$model->{'emissionLines'}->{'Cloudy'}};
    (my $cloudyPath, my $cloudyVersion) = &Cloudy::Initialize(%cloudyOptions);
    (my $cloudyVersionMajor = $cloudyVersion) =~ s/\.\d+$//;
    # Determine HII region model to use.
    $model->{'emissionLines'}->{'hiiRegionModel'} = "new"
	unless ( exists($model->{'emissionLines'}->{'hiiRegionModel'}) );
    # Set line list.
    &setLineList($cloudyVersion);
    # Compute cloud properties.
    my $densityClouds           = +3.0                       
	                          /4.0                       
	                          *sqrt($Pi     )             
	                          /sqrt($massGMC)            
	                          *$densitySurfaceCritical**1.5;
    my $radiusClouds            = (3.0*$massGMC/4.0/$Pi/$densityClouds)**(1.0/3.0)*$mega;
    my $radiusCloudsLogarithmic = log10($radiusClouds);
    # Set plausible ranges of ionizing ratios. If a stellar population library file is provided then measure these values from it
    # for young stellar populations.
    my $QHeQHMinimum = pdl 0.0024;
    my $QHeQHMaximum = pdl 0.3650;
    my $QOQHeMinimum = pdl 0.0060;
    my $QOQHeMaximum = pdl 0.4100;
    if ( exists($model->{'emissionLines'}->{'stellarPopulationFile'}) ) {
	# Read data from an SSP model.
	my $stellarPopulationsFileName = $model->{'emissionLines'}->{'stellarPopulationFile'};
	my $stellarPopulations         = new PDL::IO::HDF5($stellarPopulationsFileName);
	my $age                        = $stellarPopulations->dataset('ages'         )->get();
	my $metallicity                = $stellarPopulations->dataset('metallicities')->get();
	my $wavelength                 = $stellarPopulations->dataset('wavelengths'  )->get();
	my $spectra                    = $stellarPopulations->dataset('spectra'      )->get();
	# Construct wavelength intervals.
	my $deltaWavelength       = $wavelength->copy();
	$deltaWavelength->(0:-2) .= $wavelength->(1:-1)-$deltaWavelength->(0:-2);
	$deltaWavelength->((-1)) .=                     $deltaWavelength->((-1));
	# Construct the integrand.
	$spectra                 *= $deltaWavelength/$wavelength;
	# Find the range to include in each integral.
	my $hydrogenContinuum     = which($wavelength < 911.76);
	my $heliumContinuum       = which($wavelength < 504.10);
	my $oxygenContinuum       = which($wavelength < 350.70);
	# Consider only the young stellar populations (less than 10 Myr).
	my $young                 = which($age        <   0.01);
	# Evaluate the integrals.
	my $QH                    = $spectra->($hydrogenContinuum,$young,:)->sumover();
	my $QHe                   = $spectra->($heliumContinuum  ,$young,:)->sumover();
	my $QO                    = $spectra->($oxygenContinuum  ,$young,:)->sumover();
	# Construct the ratios.
	my $QHeQH                 = $QHe/$QH ;
	my $QOQHe                 = $QO /$QHe;
	# Find minimum and maximum values.
	$QHeQHMinimum            .= $QHeQH->flat()->minimum();
	$QHeQHMaximum            .= $QHeQH->flat()->maximum();
	$QOQHeMinimum            .= $QOQHe->flat()->minimum();
	$QOQHeMaximum            .= $QOQHe->flat()->maximum();
    }
    # Generate look-up table of oxygen-to-helium ionizing photons emission rate ratio as a function of temperature.
    my $integrationRuleOrder         = 6;
    my $integrationToleranceRelative = 1.0e-3;
    my $integrationToleranceAbsolute = 0.0;
    my $intervalsMaximum             = 1000;
    # Iterate over temperature.
    my $temperatureMinimum = pdl   2000.0;
    my $temperatureMaximum = pdl 250000.0;
    my $temperatureStep    = pdl     50.0;
    my $temperatureCount   = int(($temperatureMaximum-$temperatureMinimum)/$temperatureStep)+1;
    my $temperatures       = pdl ($temperatureMaximum-$temperatureMinimum)*sequence($temperatureCount)/($temperatureCount-1)+$temperatureMinimum;
    my $ratiosOxygenHelium = pdl zeroes($temperatureCount);
    $energyThermal = pdl 0.0;
    for(my $i=0;$i<$temperatureCount;++$i) {
    	$energyThermal .= $boltzmannsConstant*$temperatures->(($i))/$electronVolt;
    	(my $oxygenRate, my $oxygenError, my $oxygenStatus) 
    	    = gslinteg_qag
    	    (
    	     \&planckFunction             ,
    	     $oxygenTwoIonizationEnergy   ,
    	     $heliumTwoIonizationEnergy   ,
    	     $integrationToleranceRelative,
    	     $integrationToleranceAbsolute,
    	     $intervalsMaximum            ,
    	     $integrationRuleOrder
    	    );
    	(my $heliumRate, my $heliumError, my $heliumStatus) 
    	    = gslinteg_qag
    	    (
    	     \&planckFunction             ,
    	     $heliumOneIonizationEnergy   ,
    	     $heliumTwoIonizationEnergy   ,
    	     $integrationToleranceRelative,
    	     $integrationToleranceAbsolute,
    	     $intervalsMaximum            ,
    	     $integrationRuleOrder
    	    );
    	$ratiosOxygenHelium->(($i)) .= $oxygenRate/$heliumRate;
    }
    # Find temporary workspace.
    my $workspace = "./emissionLinesWork/";
    $workspace = $model->{'emissionLines'}->{'workspace'}
        if ( exists($model->{'emissionLines'}->{'workspace'}) );
    $workspace .= "/"
	unless ( $workspace =~ m/\/$/ );
    system("mkdir -p ".$workspace);
    # Initialize PBS job stack.
    my @pbsStack;
    # Specify ranges of metallicity, density, and ionizing fluxes.
    my $gridCountMetallicities          = 8;
    my $gridCountHydrogenDensities      = 7;
    my $gridCountHydrogenLuminosities   = 7;
    my $gridCountHeliumToHydrogenRatios = 6;
    my $gridCountOxygenToHeliumRatios   = 6;
    my $metallicityMinimum              = 1.0e-03;
    my $metallicityMaximum              = 3.0e+00;
    my $hydrogenDensityMinimum          = 1.0e-01;
    my $hydrogenDensityMaximum          = 3.0e+02;
    my $hydrogenLuminosityMinimum       = 1.0e+48;
    my $hydrogenLuminosityMaximum       = 1.0e+52;
    my $logMetallicities                = pdl sequence($gridCountMetallicities         )/($gridCountMetallicities         -1)*(log10($metallicityMaximum       )-log10($metallicityMinimum       ))+log10($metallicityMinimum       );
    my $logHydrogenDensities            = pdl sequence($gridCountHydrogenDensities     )/($gridCountHydrogenDensities     -1)*(log10($hydrogenDensityMaximum   )-log10($hydrogenDensityMinimum   ))+log10($hydrogenDensityMinimum   );
    my $logHydrogenLuminosities         = pdl sequence($gridCountHydrogenLuminosities  )/($gridCountHydrogenLuminosities  -1)*(log10($hydrogenLuminosityMaximum)-log10($hydrogenLuminosityMinimum))+log10($hydrogenLuminosityMinimum);
    my $logHeliumToHydrogenRatios       = pdl sequence($gridCountHeliumToHydrogenRatios)/($gridCountHeliumToHydrogenRatios-1)*(log10($QHeQHMaximum             )-log10($QHeQHMinimum             ))+log10($QHeQHMinimum             );
    my $logOxygenToHeliumRatios         = pdl sequence($gridCountOxygenToHeliumRatios  )/($gridCountOxygenToHeliumRatios  -1)*(log10($QOQHeMaximum             )-log10($QOQHeMinimum             ))+log10($QOQHeMinimum             );
    my $modelsCount                     =
	+nelem($logOxygenToHeliumRatios  )
	*nelem($logHeliumToHydrogenRatios)
	*nelem($logHydrogenLuminosities  )
	*nelem($logHydrogenDensities     )
	*nelem($logMetallicities         );
    # Initialize line arrays.
    $lineData->{$lineList{$_}}->{'luminosity'} =
	pdl zeroes
	(
	 nelem($logOxygenToHeliumRatios  ),
	 nelem($logHeliumToHydrogenRatios),
	 nelem($logHydrogenLuminosities  ),
	 nelem($logHydrogenDensities     ),
	 nelem($logMetallicities         )
	)
	foreach ( keys(%lineList) );
    $lineData->{'status'} =
	pdl long zeroes
	(
	 nelem($logOxygenToHeliumRatios  ),
	 nelem($logHeliumToHydrogenRatios),
	 nelem($logHydrogenLuminosities  ),
	 nelem($logHydrogenDensities     ),
	 nelem($logMetallicities         )
	);
    # Iterate over ranges.
    my $jobCount               = -1;
    my $iLogHydrogenLuminosity = -1;
    foreach my $logHydrogenLuminosity ( $logHydrogenLuminosities->list() ) {
	++$iLogHydrogenLuminosity;
	my $iHeliumToHydrogenRatio = -1;
	foreach my $logHeliumToHydrogenRatio ( $logHeliumToHydrogenRatios->list() ) {
	    ++$iHeliumToHydrogenRatio;
	    my $heliumToHydrogenRatio = 10.0**$logHeliumToHydrogenRatio;
	    my $iOxygenToHeliumRatio  = -1;
	    foreach my $logOxygenToHeliumRatio ( $logOxygenToHeliumRatios->list() ) {
		++$iOxygenToHeliumRatio;
		my $oxygenToHeliumRatio   = 10.0**$logOxygenToHeliumRatio;
		my $oxygenToHydrogenRatio = +$oxygenToHeliumRatio
		                            *$heliumToHydrogenRatio;
		# Find helium-region temperature.
		(my $temperatureHelium, my $temperatureError) = interpolate($oxygenToHeliumRatio,$ratiosOxygenHelium,$temperatures);
		$temperatureHelium = $temperatureMaximum
		    if ( $temperatureHelium > $temperatureMaximum );
		# Find helium-region normalization.
		$energyThermal .= $boltzmannsConstant*$temperatureHelium/$electronVolt;
		(my $normalizationHelium, my $normalizationHeliumError, my $normalizationHeliumStatus) 
		    = gslinteg_qag
		    (
		     \&planckFunction             ,
		     $heliumOneIonizationEnergy   ,
		     $heliumTwoIonizationEnergy   ,
		     $integrationToleranceRelative,
		     $integrationToleranceAbsolute,
		     $intervalsMaximum            ,
		     $integrationRuleOrder
		    );
		$normalizationHelium = $heliumToHydrogenRatio/$normalizationHelium;
		# Find hydrogen-region temperature.
		my $temperatureHydrogen;
		if ( $heliumToHydrogenRatio >= 0.005 ) {
		    $temperatureHydrogen = 3.0e4+4.0e4*      $heliumToHydrogenRatio ;
		} else {
		    $temperatureHydrogen = 4.0e4+0.5e4*log10($heliumToHydrogenRatio);
		}
		# Find hydrogen-region normalization.
		$energyThermal .= $boltzmannsConstant*$temperatureHydrogen/$electronVolt;
		(my $normalizationHydrogen, my $normalizationHydrogenError, my $normalizationHydrogenStatus) 
		    = gslinteg_qag
		    (
		     \&planckFunction             ,
		     $hydrogenOneIonizationEnergy ,
		     $heliumOneIonizationEnergy   ,
		     $integrationToleranceRelative,
		     $integrationToleranceAbsolute,
		     $intervalsMaximum            ,
		     $integrationRuleOrder
		    );
		$normalizationHydrogen = (1.0-$heliumToHydrogenRatio)/$normalizationHydrogen;
		# Get non-ionizing temperature and normalization.
		my $temperatureNonIonizing;
		my $normalizationNonIonizing;
		if ( $heliumToHydrogenRatio >= 0.005 ) {
		    if ( $temperatureHydrogen > 40000.0 ) {
			$temperatureNonIonizing   = 40000.0;
		    } else {
			$temperatureNonIonizing   = $temperatureHydrogen;
		    }
		    $normalizationNonIonizing = 2.5*$normalizationHydrogen;
		} else {
		    $temperatureNonIonizing = 30000.0;
		    $normalizationNonIonizing = 3.5*$normalizationHydrogen;
		}
		# Find the bolometric luminosity.
		my $energyZero  = pdl 0.0;
		$energyThermal .= $boltzmannsConstant*$temperatureNonIonizing/$electronVolt;
		(my $luminosityNonIonizing, my $luminosityNonIonizingError, my $luminosityNonIonizingStatus) =
		    gslinteg_qag
		    (
		     \&planckFunctionLuminosity   ,
		     $energyZero                  ,
		     $hydrogenOneIonizationEnergy ,
		     $integrationToleranceRelative,
		     $integrationToleranceAbsolute,
		     $intervalsMaximum            ,
		     $integrationRuleOrder
		    );
		$energyThermal .= $boltzmannsConstant*$temperatureHydrogen/$electronVolt;
		(my $luminosityHydrogen, my $luminosityHydrogenError, my $luminosityHydrogenStatus) =
		    gslinteg_qag
		    (
		     \&planckFunctionLuminosity   ,
		     $hydrogenOneIonizationEnergy ,
		     $heliumOneIonizationEnergy   ,
		     $integrationToleranceRelative,
		     $integrationToleranceAbsolute,
		     $intervalsMaximum            ,
		     $integrationRuleOrder
		    );
		(my $photonRateHydrogen, my $photonRateHydrogenError, my $photonRateHydrogenStatus) =
		    gslinteg_qag
		    (
		     \&planckFunction   ,
		     $hydrogenOneIonizationEnergy ,
		     $heliumOneIonizationEnergy   ,
		     $integrationToleranceRelative,
		     $integrationToleranceAbsolute,
		     $intervalsMaximum            ,
		     $integrationRuleOrder
		    );
		$energyThermal .= $boltzmannsConstant*$temperatureHelium/$electronVolt;
		(my $luminosityHelium, my $luminosityHeliumError, my $luminosityHeliumStatus) =
		    gslinteg_qag
		    (
		     \&planckFunctionLuminosity   ,
		     $heliumOneIonizationEnergy   ,
		     $heliumTwoIonizationEnergy   ,
		     $integrationToleranceRelative,
		     $integrationToleranceAbsolute,
		     $intervalsMaximum            ,
		     $integrationRuleOrder
		    );
		(my $photonRateHelium, my $photonRateHeliumError, my $photonRateHeliumStatus) =
		    gslinteg_qag
		    (
		     \&planckFunction   ,
		     $heliumOneIonizationEnergy   ,
		     $heliumTwoIonizationEnergy   ,
		     $integrationToleranceRelative,
		     $integrationToleranceAbsolute,
		     $intervalsMaximum            ,
		     $integrationRuleOrder
		    );
		## Find the normalization of the photon emission rate in the Lyman continuum to give the overall normalization of
		## our spectrum.
		my $normalization = (10.0**$logHydrogenLuminosity)/($normalizationHydrogen*$photonRateHydrogen+$normalizationHelium*$photonRateHelium);		
		my $luminosityBolometric =
		    +$normalization
		    *(
		      +$normalizationNonIonizing*$luminosityNonIonizing
		      +$normalizationHydrogen   *$luminosityHydrogen   
		      +$normalizationHelium     *$luminosityHelium     
		    )
		    *$electronVolt;
		my $recombinationCoefficientCharacteristic = pdl 3.0e-13; # cm³ s⁻¹ (Yeh et al.; 2013; ApJ; 769; 11; https://ui.adsabs.harvard.edu/abs/2013ApJ...769...11Y)
		my $temperatureCharacteristic              = pdl 8.0e+03; # K       (Yeh et al.; 2013; ApJ; 769; 11; https://ui.adsabs.harvard.edu/abs/2013ApJ...769...11Y)
		my $radiusCharacteristicLogarithmic        =
		    log10
		    (
		     ($recombinationCoefficientCharacteristic*$centi**3)
		     *$luminosityBolometric**2
		     /12.0/$Pi
		     /(2.2*$boltzmannsConstant*$temperatureCharacteristic*$speedOfLight)**2
		     /(10.0**$logHydrogenLuminosity)
		     /$parsec
		    );
		# Iterate over metallicity.
		my $iMetallicity = -1;
		foreach my $logMetallicity ( $logMetallicities->list() ) {
		    ++$iMetallicity;
		    my $iLogHydrogenDensity = -1;
		    foreach my $logHydrogenDensity ( $logHydrogenDensities->list() ) {
			++$iLogHydrogenDensity;
			++$jobCount;
			# Report
			print "Generating model ".$jobCount." of ".$modelsCount."\n"
			    if ( $jobCount % 100 == 0 );
			# Generate Cloudy script.
			my $cloudyScript;
			$cloudyScript .= "title emission line job number ".$jobCount."\n";
			$cloudyScript .= "# [".$iMetallicity          ."] log Z        = ".$logMetallicity          ."\n";
			$cloudyScript .= "# [".$iLogHydrogenDensity   ."] log n_H      = ".$logHydrogenDensity      ."\n";
			$cloudyScript .= "# [".$iLogHydrogenLuminosity."] log Q_H      = ".$logHydrogenLuminosity   ."\n";
			$cloudyScript .= "# [".$iHeliumToHydrogenRatio."] log Q_He/Q_H = ".$logHeliumToHydrogenRatio."\n";
			$cloudyScript .= "# [".$iOxygenToHeliumRatio  ."] log Q_O/Q_He = ".$logOxygenToHeliumRatio  ."\n";
			# Generate spectrum table.
			my $counter = -1;
			for(my $logWavelength=11.5;$logWavelength>=2.0;$logWavelength-=0.005) {
			    my $wavelength = 10.0**$logWavelength;
			    my $normalization;
			    my $temperature;
			    if      (                         $wavelength < 227.80 ) {
				$normalization = 0.0;
			    } elsif ( $wavelength >= 227.8 && $wavelength < 504.10 ) {
				$normalization = $normalizationHelium;
				$temperature   = $temperatureHelium;
			    } elsif ( $wavelength >= 504.1 && $wavelength < 911.76 ) {
				$normalization = $normalizationHydrogen;
				$temperature   = $temperatureHydrogen;
			    } else                                           {
				$normalization = $normalizationNonIonizing;
				$temperature    =$temperatureNonIonizing;
			    }
			    if ( $normalization > 0.0 ) {
				++$counter;
				if ( $counter % 3 == 0 ) {
				    if ( $counter == 0 ) {
					$cloudyScript .= "interpolate";
				    } else {
					$cloudyScript .= "\ncontinue";
				    }
				}
				my $energy          = $plancksConstant*$speedOfLight/$wavelength/$angstroms/$electronVolt;
				my $energyRydbergs  = $energy/$rydbergEnergy;
				$energyThermal     .= $boltzmannsConstant*$temperature/$electronVolt;
				my $luminosity      = $normalization*$energy**3/(exp($energy/$energyThermal)-1.0);
				my $logLuminosity   = $luminosity < 1.0e-37 ? -37.0 : log10($luminosity);
				$cloudyScript      .= " (".$energyRydbergs." ".$logLuminosity.")";
			    }
			}
			$cloudyScript .= "\n";
			# Determine which HII region model to use, and construct it.
			if ( $model->{'emissionLines'}->{'hiiRegionModel'} eq "new" ) {
			    $cloudyScript .= "q(h) = ".$logHydrogenLuminosity."\n";
			    # Use Cloudy's abundance table for the ISM - this includes depletion onto grains. But, do not include
			    # grains here - we want to set them later so that we can switch off quantum heating.
			    $cloudyScript .= "abundances ISM no grains\n";
			    # Set dust grains for the ISM, and switch off quantum heating of grains. Without switching off this
			    # heating some models exit with a failed assertion
			    # (https://cloudyastrophysics.groups.io/g/Main/message/4618). According to Gary Ferland
			    # (https://cloudyastrophysics.groups.io/g/Main/message/4049): "It is safe to turn off quantum heating since
			    # that only affects the NIR continuous spectrum, assuming you do not care about grain emission in that
			    # part of the spectrum."
			    $cloudyScript .= "grains ISM no qheat\n";
			    # Scale metals by our metallicity, also scale grain abundances by the metallicity (to preserve a constant
			    # dust-to-metals ratio).
			    $cloudyScript .= "metals ".$logMetallicity       ." log grains\n";
			    $cloudyScript .= "constant pressure\n";
			    $cloudyScript .= "gravity spherical\n";
			    # Increase the number of times the ionization solver can be invoked before Cloudy issues an error. With
			    # the default number (3000) some models fail.
			    $cloudyScript .= "set pressure ionize 10000\n";
			    $cloudyScript .= "hden   ".$logHydrogenDensity   ."\n";
			    $cloudyScript .= "sphere expanding\n";
			    $cloudyScript .= "radius ".$radiusCharacteristicLogarithmic." ".$radiusCloudsLogarithmic." parsecs\n";
			    $cloudyScript .= "stop temperature 100 k\n";
			    # Include the cosmic ray background to ensure that we have some heating in optically thick regions.
			    $cloudyScript .= "cosmic ray background\n";
			    $cloudyScript .= "iterate to convergence\n";
			} elsif ( $model->{'emissionLines'}->{'hiiRegionModel'} eq "old" ) {
			    $cloudyScript .= "q(h) = ".$logHydrogenLuminosity.    "\n";
			    $cloudyScript .= "metals ".$logMetallicity       ." log\n";
			    $cloudyScript .= "hden   ".$logHydrogenDensity   .    "\n";
			    $cloudyScript .= "sphere expanding\n";
			    $cloudyScript .= "radius 16.0\n";
			    $cloudyScript .= "stop temperature 1000 k\n";
			    $cloudyScript .= "iterate to convergence\n";
			} else {
			    die("Unknown HII region model");
			}
			# Write save location.
			$cloudyScript .= "print lines faint _off\n";
			$cloudyScript .= "print line vacuum\n" # Use vacuum wavelengths for all lines in Cloudy v17+
			    if ( $cloudyVersionMajor >= 17 );
			$cloudyScript .= "save lines, array \"".$workspace."lines".$jobCount.".out\"\n";
			# Write the Cloudy script to file.
			my $cloudyScriptFileName = $workspace."cloudyInput".$jobCount.".txt";
			open(my $cloudyScriptFile,">".$cloudyScriptFileName);
			print $cloudyScriptFile $cloudyScript;
			close($cloudyScriptFile);
			# Generate PBS job.
			my %pbsJob = 
			    (
			     launchFile   => $workspace."emissionLines".$jobCount.".pbs",
			     label        =>            "emissionLines".$jobCount       ,
			     logFile      => $workspace."emissionLines".$jobCount.".log",
			     command      => 
			                     "ulimit -c 0\n"                                               .
       			                     $cloudyPath."/source/cloudy.exe < ".$cloudyScriptFileName."\n".
			                     "if [ $? != 0 ]; then\necho CLOUDY FAILED\nfi\n"              ,
			     ppn          => 1,
			     walltime     => "10:00:00",
			     onCompletion => 
			     {
				 function  => \&linesParse,
				 arguments => 
				     [
				      $workspace."lines"        .$jobCount.".out",
				      $workspace."emissionLines".$jobCount.".pbs",
				      $workspace."emissionLines".$jobCount.".log",
				      $cloudyScriptFileName                      ,
				      $iLogHydrogenLuminosity                    ,
				      $iHeliumToHydrogenRatio                    ,
				      $iOxygenToHeliumRatio                      ,
				      $iMetallicity                              ,
				      $iLogHydrogenDensity
				     ]
			     }
			    );
			# Push job to PBS queue stack.
			push(@pbsStack,\%pbsJob);
		    }
		}
	    }
	}
    }
    # Submit jobs.
    my %launchOptions = %{$model->{'emissionLines'}->{'launcher'}}
    if ( exists($model->{'emissionLines'}->{'launcher'}) );
    &{$Galacticus::Launch::Hooks::moduleHooks{$queueManager->{'manager'}}->{'jobArrayLaunch'}}(\%launchOptions,@pbsStack);
    # Write the line data to file.
    my $tableFile = new PDL::IO::HDF5(">".$tableFileName);
    # Write parameter grid points.
    $tableFile->dataset('metallicity'                 )->set(10.0**$logMetallicities         );
    $tableFile->dataset('densityHydrogen'             )->set(10.0**$logHydrogenDensities     );
    $tableFile->dataset('ionizingFluxHydrogen'        )->set(10.0**$logHydrogenLuminosities  );
    $tableFile->dataset('ionizingFluxHeliumToHydrogen')->set(10.0**$logHeliumToHydrogenRatios);
    $tableFile->dataset('ionizingFluxOxygenToHelium'  )->set(10.0**$logOxygenToHeliumRatios  );
    # Write parameter grid point attributes.
    $tableFile->dataset('metallicity'                 )->attrSet(description => "Metallicity relative to Solar."                                    );
    $tableFile->dataset('densityHydrogen'             )->attrSet(description => "Total hydrogen number density."                                    );
    $tableFile->dataset('densityHydrogen'             )->attrSet(units       => "cm⁻³"                                                              );
    $tableFile->dataset('densityHydrogen'             )->attrSet(unitsInSI   => 1.0e6                                                               );
    $tableFile->dataset('ionizingFluxHydrogen'        )->attrSet(description => "Hydrogen ionizing photon emission rate."                           );
    $tableFile->dataset('ionizingFluxHydrogen'        )->attrSet(units       => "photons/s"                                                         );
    $tableFile->dataset('ionizingFluxHydrogen'        )->attrSet(unitsInSI   => 1.0                                                                 );
    $tableFile->dataset('ionizingFluxHeliumToHydrogen')->attrSet(description => "Helium ionizing photon emission rate relative to that of hydrogen.");
    $tableFile->dataset('ionizingFluxOxygenToHelium'  )->attrSet(description => "Oxygen ionizing photon emission rate relative to that of helium."  );
    # Write line data.
    my $lineGroup = $tableFile->group('lines');
    $lineGroup->dataset('status')->set($lineData->{'status'});
    $lineGroup->dataset('status')->attrSet(description => "Cloudy model status: 0 = success; 1 = disaster; 2 = non-zero exit status; 3 = missing output file; 4 = missing emission lines");
    foreach ( keys(%lineList) ) {
	my $lineName = $lineList{$_};
	$lineGroup->dataset($lineName)->set    (               $lineData->{$lineName}->{'luminosity'});
	$lineGroup->dataset($lineName)->attrSet(description => "Luminosity of the line."             );
	$lineGroup->dataset($lineName)->attrSet(units       => "erg/s"                               );
	$lineGroup->dataset($lineName)->attrSet(unitsInSI   => 1.0e-7                                );
	$lineGroup->dataset($lineName)->attrSet(wavelength  => $lineData->{$lineName}->{'wavelength'});
    }
    # Write model meta-data.
    $tableFile->attrSet(model => $model->{'emissionLines'}->{'hiiRegionModel'});
    print "Table written to file\n";
}

sub planckFunction {
    # Blackbody spectrum for integration.
    my ($energy) = @_;
    return $energy**2/(exp($energy/$energyThermal)-1.0);
}

sub planckFunctionLuminosity {
    # Blackbody spectrum for integration.
    my ($energy) = @_;
    return $energy**3/(exp($energy/$energyThermal)-1.0);
}

sub linesParse {
    # Parse output from a Cloudy job to extract line data.
    my $linesFileName          = shift();
    my $pbsLaunchFileName      = shift();
    my $pbsLogFileName         = shift();
    my $cloudyScriptFileName   = shift();
    my $iLogHydrogenLuminosity = shift();
    my $iHeliumToHydrogenRatio = shift();
    my $iOxygenToHeliumRatio   = shift();
    my $iMetallicity           = shift();
    my $iLogHydrogenDensity    = shift();
    # Check for successful completion.
    system("grep -q DISASTER ".$pbsLogFileName);
    if ( $? == 0 ) {
	print "FAIL (Cloudy failed disasterously): ".$iLogHydrogenLuminosity." ".$iHeliumToHydrogenRatio." ".$iOxygenToHeliumRatio." ".$iMetallicity." ".$iLogHydrogenDensity." see ".$pbsLogFileName."\n";
    $lineData
	->{'status'}
        ->(
	($iOxygenToHeliumRatio  ),
	($iHeliumToHydrogenRatio),
	($iLogHydrogenLuminosity),
	($iLogHydrogenDensity   ),
	($iMetallicity          )
	) .= 1
	if (
	    $lineData
	    ->{'status'}
	    ->(
		($iOxygenToHeliumRatio  ),
		($iHeliumToHydrogenRatio),
		($iLogHydrogenLuminosity),
		($iLogHydrogenDensity   ),
		($iMetallicity          )
	    ) == 0
	);
    }
    system("grep -q FAILED ".$pbsLogFileName);
    if ( $? == 0 ) {
	print "FAIL [Cloudy exited with non-zero status]: ".$iLogHydrogenLuminosity." ".$iHeliumToHydrogenRatio." ".$iOxygenToHeliumRatio." ".$iMetallicity." ".$iLogHydrogenDensity." see ".$pbsLogFileName."\n";
    $lineData
	->{'status'}
        ->(
	($iOxygenToHeliumRatio  ),
	($iHeliumToHydrogenRatio),
	($iLogHydrogenLuminosity),
	($iLogHydrogenDensity   ),
	($iMetallicity          )
	) .= 2
	if (
	    $lineData
	    ->{'status'}
	    ->(
		($iOxygenToHeliumRatio  ),
		($iHeliumToHydrogenRatio),
		($iLogHydrogenLuminosity),
		($iLogHydrogenDensity   ),
		($iMetallicity          )
	    ) == 0
	);
    }
    # Allow multiple attempts to read the lines file in case the file is written over NFS and we must wait for it to catch up.
    my $attemptsMaximum = 10;
    my @linesFound;
    for(my $attempt=0;$attempt<$attemptsMaximum;++$attempt) {
	# Read the lines file.
	my $badFile = 0;
	open(my $linesFile,$linesFileName);
	while ( my $line = <$linesFile> ) {
	    unless ( $line =~ m/^#/ ) {
		my @columns        = split(/\t/,$line);
		$badFile = 1
		    unless ( scalar(@columns) == 5 );
		my $lineEnergy     = $columns[0];
		my $lineLabel      = $columns[1];
		my $lineLuminosity = $columns[3];
		if ( exists($lineList{$lineLabel}) ) {
		    my $lineName = $lineList{$lineLabel};
		    $lineLuminosity =~ s/^\s+//;
		    $lineLuminosity =~ s/\s+$//;
		    $lineEnergy     =~ s/^\s+//;
		    $lineEnergy     =~ s/\s+$//;
		    my $lineWavelength = $plancksConstant*$speedOfLight/$rydbergEnergy/$electronVolt/$lineEnergy/$angstroms;
		    $lineData
			->{$lineName}
		    ->{'luminosity'}
		    ->(
			($iOxygenToHeliumRatio  ),
			($iHeliumToHydrogenRatio),
			($iLogHydrogenLuminosity),
			($iLogHydrogenDensity   ),
			($iMetallicity          )
			)
			.= 10.0**$lineLuminosity;
		    $lineData
			->{$lineName}
		    ->{'wavelength'}
		    = $lineWavelength;
		    push(@linesFound,$lineName);
		}
	    }
	}
	close($linesFile);
	if ( $badFile == 0 ) {
	    last;
	} else {
	    if ( $attempt == $attemptsMaximum-1 ) {
		print "FAIL [unable to find Cloudy output lines file]: ".$iLogHydrogenLuminosity." ".$iHeliumToHydrogenRatio." ".$iOxygenToHeliumRatio." ".$iMetallicity." ".$iLogHydrogenDensity." see ".$pbsLogFileName."\n";
		$lineData
		->{'status'}
		->(
		    ($iOxygenToHeliumRatio  ),
		    ($iHeliumToHydrogenRatio),
		    ($iLogHydrogenLuminosity),
		    ($iLogHydrogenDensity   ),
		    ($iMetallicity          )
		    ) .= 3
		    if (
			$lineData
			->{'status'}
			->(
			    ($iOxygenToHeliumRatio  ),
			    ($iHeliumToHydrogenRatio),
			    ($iLogHydrogenLuminosity),
			    ($iLogHydrogenDensity   ),
			    ($iMetallicity          )
			) == 0
		    );
	    } else {
		sleep(10);
	    }
	}
    }
    # Check that we found all lines.
    foreach my $lineName ( keys(%lineList) ) {	
	unless ( grep {$_ eq $lineList{$lineName}} @linesFound ) {
	    print "FAIL [some emission lines missing]: ".$iLogHydrogenLuminosity." ".$iHeliumToHydrogenRatio." ".$iOxygenToHeliumRatio." ".$iMetallicity." ".$iLogHydrogenDensity." '".$lineName."' see ".$pbsLogFileName."\n";
	    $lineData
	    ->{'status'}
	    ->(
		($iOxygenToHeliumRatio  ),
		($iHeliumToHydrogenRatio),
		($iLogHydrogenLuminosity),
		($iLogHydrogenDensity   ),
		($iMetallicity          )
		) .= 4
		if (
		    $lineData
		    ->{'status'}
		    ->(
			($iOxygenToHeliumRatio  ),
			($iHeliumToHydrogenRatio),
			($iLogHydrogenLuminosity),
			($iLogHydrogenDensity   ),
			($iMetallicity          )
		    ) == 0
		);
	}
    }
    # Clean up.
    unlink($linesFileName,$pbsLaunchFileName,$pbsLogFileName,$cloudyScriptFileName)
	if (
	    $lineData
	    ->{'status'}
	    ->(
		($iOxygenToHeliumRatio  ),
		($iHeliumToHydrogenRatio),
		($iLogHydrogenLuminosity),
		($iLogHydrogenDensity   ),
		($iMetallicity          )
	    ) == 0
	);
}

sub Patch_Tables {
    # Patch tables of line luminosities for any missing values.
    $tableFileName = shift();
    my $model      = shift();
    # Get path to Cloudy.
    my %cloudyOptions = %{$model->{'emissionLines'}->{'Cloudy'}};
    (my $cloudyPath, my $cloudyVersion) = &Cloudy::Initialize(%cloudyOptions);
    # Set line list.
    &setLineList($cloudyVersion);
    # Read tables from file.
    my $tableFile = new PDL::IO::HDF5(">".$tableFileName);
    # Read parameter grid points.
    my $logMetallicities          = log10($tableFile->dataset('metallicity'                 )->get());
    my $logHydrogenDensities      = log10($tableFile->dataset('densityHydrogen'             )->get());
    my $logHydrogenLuminosities   = log10($tableFile->dataset('ionizingFluxHydrogen'        )->get());
    my $logHeliumToHydrogenRatios = log10($tableFile->dataset('ionizingFluxHeliumToHydrogen')->get());
    my $logOxygenToHeliumRatios   = log10($tableFile->dataset('ionizingFluxOxygenToHelium'  )->get());
    # Read line data.
    my $lineGroup = $tableFile->group('lines');
    my $lineData;
    $lineData->{'status'}= $lineGroup->dataset('status')->get();
    foreach ( keys(%lineList) ) {
	my $lineName = $lineList{$_};
	$lineData->{$lineName} = $lineGroup->dataset($lineName)->get();
    }
    my $done     = 0;
    my $stepSize = 1;
    while ( ! $done ) {
	$done        = 1;
	my $changed  = 0;
	for(my $iMetallicity=0;$iMetallicity<nelem($logMetallicities);++$iMetallicity) {
	    (my $jMetallicity, my $hMetallicity) = &interpolants($iMetallicity,$logMetallicities,$stepSize);
	    for(my $iDensity=0;$iDensity<nelem($logHydrogenDensities);++$iDensity) {
		(my $jDensity, my $hDensity) = &interpolants($iDensity,$logHydrogenDensities,$stepSize);
		for(my $iHydrogen=0;$iHydrogen<nelem($logHydrogenLuminosities);++$iHydrogen) {
		    (my $jHydrogen, my $hHydrogen) = &interpolants($iHydrogen,$logHydrogenLuminosities,$stepSize);
		    for(my $iHelium=0;$iHelium<nelem($logHeliumToHydrogenRatios);++$iHelium) {
			(my $jHelium, my $hHelium) = &interpolants($iHelium,$logHeliumToHydrogenRatios,$stepSize);
			for(my $iOxygen=0;$iOxygen<nelem($logOxygenToHeliumRatios);++$iOxygen) {
			    (my $jOxygen, my $hOxygen) = &interpolants($iOxygen,$logOxygenToHeliumRatios,$stepSize);
			    if ( $lineData->{'status'}->(($iOxygen),($iHelium),($iHydrogen),($iDensity),($iMetallicity)) != 0 ) {
				# Check that all required neighbor points are available.
				if
				    (
				     all
				     (
				      $lineData->{'status'}->
				      (
				       $jOxygen,
				       $jHelium,
				       $jHydrogen,
				       $jDensity,
				       $jMetallicity,
				      )
				      ==
				      0
				     )
				    )
				{
				    # Interpolate if possbile.
				    $lineData->{'status'}->(($iOxygen),($iHelium),($iHydrogen),($iDensity),($iMetallicity)) .= 0;
				    foreach ( keys(%lineList) ) {
					my $lineName = $lineList{$_};
					next
					    unless ( $lineData->{$lineName}->(($iOxygen),($iHelium),($iHydrogen),($iDensity),($iMetallicity)) == 0.0 );
					$lineData->{$lineName}->(($iOxygen),($iHelium),($iHydrogen),($iDensity),($iMetallicity)) .= 0.0;
					for(my $kMetallicity=0;$kMetallicity<2;++$kMetallicity) {
					    my $lMetallicity = $jMetallicity->(($kMetallicity));
					    for(my $kDensity=0;$kDensity<2;++$kDensity) {
						my $lDensity = $jDensity->(($kDensity));
						for(my $kHydrogen=0;$kHydrogen<2;++$kHydrogen) {
						    my $lHydrogen = $jHydrogen->(($kHydrogen));
						    for(my $kHelium=0;$kHelium<2;++$kHelium) {
							my $lHelium = $jHelium->(($kHelium));
							for(my $kOxygen=0;$kOxygen<2;++$kOxygen) {
							    my $lOxygen = $jOxygen->(($kOxygen));
							    $lineData->{$lineName}->(($iOxygen),($iHelium),($iHydrogen),($iDensity),($iMetallicity)) +=
								+$lineData->{$lineName}->(($lOxygen),($lHelium),($lHydrogen),($lDensity),($lMetallicity))
								*$hMetallicity->(($kMetallicity))
								*$hDensity->(($kDensity))
								*$hHydrogen->(($kHydrogen))
								*$hHelium->(($kHelium))
								*$hOxygen->(($kOxygen));
							}
						    }
						}
					    }
					}
					# If the extrapolation lead to a non-positive result, resort to simply taking an average of the nearby points.
					$lineData->{$lineName}->(($iOxygen),($iHelium),($iHydrogen),($iDensity),($iMetallicity)) .= $lineData->{$lineName}->($jOxygen,$jHelium,$jHydrogen,$jDensity,$jMetallicity)->average()
					    if ( $lineData->{$lineName}->(($iOxygen),($iHelium),($iHydrogen),($iDensity),($iMetallicity)) <= 0.0 );
				    }
				    $changed = 1;
				} else {
				    $done = 0;
				}
			    }
			}
		    }
		}
	    }
	}
	if ( ! $changed ) {
	    ++$stepSize;
	    die("unable to patch table")
		if ( $stepSize > 3 );	    
	}
    }
    # Write modified data back to file. Note that we do not overwrite the "status" property - it's useful to know which points in
    # the table were patched (and why they failed originally).
    foreach ( keys(%lineList) ) {
	my $lineName = $lineList{$_};
	$lineGroup->dataset($lineName)->set($lineData->{$lineName});
    }
}

sub interpolants {
    # Construct interpolants (indices and weights) for patching the emission lines table.
    my $i = shift(); # Index to be patched.
    my $a = shift(); # Array of property values.
    my $s = shift(); # Step size in index.
    my $n = nelem($a);
    my $j = pdl zeros(2);
    my $h = pdl zeros(2);
    if ( $i == 0 ) {
	if ( $s+1 > $n-1 ) {
	    $j->((1)) .= $n-1;
	} else {
	    $j->((1)) .= $s+1;
	}
	$j->((0)) .= $j->((1))-1;
	my $deltaA = $a->($j)->((1))-$a->($j)->((0));
	$h->((0)) .= 1.0-($a      ->(($i))-$a->($j)->(( 0)))/$deltaA;
	$h->((1)) .=    -($a->($j)->(( 0))-$a      ->(($i)))/$deltaA;
    } elsif ( $i == $n-1 ) {
	if ( $n-2-$s < 0 ) {
	    $j->((0)) .= 0;
	} else {
	    $j->((0)) .= $n-2-$s;
	}
	$j->((1)) .= $j->((0))+1;
	my $deltaA = $a->($j)->((1))-$a->($j)->((0));
	$h->((0)) .= 1.0-($a      ->(($i))-$a->($j)->(( 0)))/$deltaA;
	$h->((1)) .=    -($a->($j)->(( 0))-$a      ->(($i)))/$deltaA;
    } else {
	if ( $i-$s < 0 ) {
	    $j->((0)) .= 0;
	} else {
	    $j->((0)) .= $i-$s;
	}

	if ( $i+$s > $n-1 ) {
	    $j->((1)) .= $n-1;
	} else {
	    $j->((1)) .= $i+$s;
	}
	my $deltaA = $a->($j)->((1))-$a->($j)->((0));
	$h->((0)) .= (+$a->(($i))-$a->($j)->((0)))/$deltaA;
	$h->((1)) .= (-$a->(($i))+$a->($j)->((1)))/$deltaA;
    }
    return ($j, $h);
}

1;
