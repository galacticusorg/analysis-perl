package NBody::Rockstar;
use strict;
use warnings;
use Cwd;
use lib $ENV{'GALACTICUS_ANALYSIS_PERL_PATH'}."/perl";

# Module providing functions for manipulating Rockstar parameter files.

sub readParameters {
    # Read Rockstar parameter file and return a hash of parameter values.
    my $rockstarParametersFileName = shift();
    # Extract Rockstar parameters.
    my %rockstarParameters;
    die("NBody::Rockstar::readParameters(): cannot find Rockstar parameter file")
	unless ( -e $rockstarParametersFileName );
    open(my $rockstarParametersFile,$rockstarParametersFileName);
    while ( my $line = <$rockstarParametersFile> ) {
	if ( $line =~ m/^([a-zA-Z0-9\._]+)\s*=\s*([a-zA-Z0-9\._\+\-\/]+)/ ) {	    
	    $rockstarParameters{$1} =  $2;
	    $rockstarParameters{$1} =~ s/^"//;
	    $rockstarParameters{$1} =~ s/"$//;
	}
    }
    close($rockstarParametersFile);
    # Return the hash.
    return %rockstarParameters;
}

1;
