# Contains a Perl module which handles downloading and compiling Cloudy.

package Cloudy;
use strict;
use warnings;
use Cwd;
use lib $ENV{'GALACTICUS_ANALYSIS_PERL_PATH'}."/perl";
use File::Slurp;

sub Initialize {
    # Download and compile Cloudy so that it is ready for use.
    (my %options) = @_;
    # Specify Cloudy version.
    my $cloudyVersion = exists($options{'version'}) ? $options{'version'} : "17.02";
    (my $cloudyVersionMajor = $cloudyVersion) =~ s/\.\d+$//;
    # Specify Cloudy path.
    system("mkdir -p ".$ENV{'GALACTICUS_DATA_PATH'}."/dynamic/c".$cloudyVersion);
    my $cloudyPath =   $ENV{'GALACTICUS_DATA_PATH'}."/dynamic/c".$cloudyVersion;
    # Download the code.
    unless ( -e $cloudyPath.".tar.gz" ) {
	print "Cloudy::Initialize: downloading Cloudy code.\n";
	system("wget \"http://data.nublado.org/cloudy_releases/c".$cloudyVersionMajor."/c".$cloudyVersion.".tar.gz\" -O ".$cloudyPath.".tar.gz");
	die("Cloudy::Initialize: FATAL - failed to download Cloudy code.") 
	    unless ( -e $cloudyPath.".tar.gz" );
    }
    # Unpack the code.
    unless ( -e $cloudyPath."/source/Makefile" ) {
	print "Cloudy::Initialize: unpacking Cloudy code.\n";
	system("tar -x -v -z -C ".$ENV{'GALACTICUS_DATA_PATH'}."/dynamic -f ".$cloudyPath.".tar.gz");
	die("Cloudy::Initialize: FATAL - failed to unpack Cloudy code.")
	    unless ( -e $cloudyPath."/source/Makefile" );
    }    
    # Build the code.
    unless ( -e $cloudyPath."/source/cloudy.exe" ) {
	print "Cloudy::Initialize: compiling Cloudy code.\n";
	my $buildCommand = "cd ".$cloudyPath."/source; chmod u=wrx configure.sh capabilities.pl; ".(exists($ENV{'CLOUDY_COMPILER_PATH'}) ? "export PATH=".$ENV{'CLOUDY_COMPILER_PATH'}.":\$PATH; " : "")." make -f Makefile_modified";
	my $staticBuild = (exists($ENV{'CLOUDY_STATIC_BUILD'}) && $ENV{'CLOUDY_STATIC_BUILD'} eq "yes") ? 1 : 0;
	my $extra = $staticBuild ? "EXTRA = -static\n" : "EXTRA = \n";
	my @makeFileContent = map {$_ =~ /^EXTRA\s*=/ ? $extra : $_} read_file($cloudyPath."/source/Makefile");
	open(my $makeFile,">",$cloudyPath."/source/Makefile_modified");
	print $makeFile join("",@makeFileContent);
	close($makeFile);
	system($buildCommand);
	die("Cloudy::Initialize: FATAL - failed to build Cloudy code.")
	    unless ( -e $cloudyPath."/source/cloudy.exe" );
    }
    # Return path and version.
    return $cloudyPath."/", $cloudyVersion;
}

1;
