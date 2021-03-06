# Contains a Perl module which implements reading and writing of Galacticus metadata to the XMP data in PDF files.

package XMP::MetaData;
use strict;
use warnings;
use Cwd;
use lib $ENV{'GALACTICUS_ANALYSIS_PERL_PATH'}."/perl";
use Image::ExifTool qw(:Public);
use File::Slurp;
use PDL;
use PDL::IO::HDF5;
use Text::Wrap;
use XML::Simple;
use Data::Dumper;
use File::Which;

# Define new XMP tags.
my %sourceStruct = (
    STRUCT_NAME => "Source",
    NAMESPACE   => { "stSource"    => 'http://users.obs.carnegiescience.edu/abenson/galacticus/ns/xmpext/1.0' },
    gitDiff      => { },
    gitBundle    => { }
    );
my %versionStruct = (
    STRUCT_NAME => "Version",
    NAMESPACE   => { "stVersion"    => 'http://users.obs.carnegiescience.edu/abenson/galacticus/ns/xmpext/1.0' },
    branch      => { },
    hash        => { },
    revision    => { },
    runTime     => { }
    );
my %parameterStruct = (
    STRUCT_NAME => "Parameter",
    NAMESPACE   => { "stParameters" => 'http://users.obs.carnegiescience.edu/abenson/galacticus/ns/xmpext/1.0' },
    name        => { },
    value       => { }
    );
my %buildStruct     = (
    STRUCT_NAME => "Build",
    NAMESPACE   => { "stBuild"      => 'http://users.obs.carnegiescience.edu/abenson/galacticus/ns/xmpext/1.0' },
    FoX_library_version      => { },
    GSL_library_version      => { },
    HDF5_library_version     => { },
    make_CCOMPILER           => { },
    make_CCOMPILER_VERSION   => { },
    make_CFLAGS              => { },
    make_CPPCOMPILER         => { },
    make_CPPCOMPILER_VERSION => { },
    make_CPPFLAGS            => { },
    make_F03COMPILER         => { },
    make_F03COMPILER_VERSION => { },
    make_F03FLAGS            => { },
    make_F03FLAGS_NOOPT      => { },
    make_PREPROCESSOR        => { }
    );
%Image::ExifTool::UserDefined::galacticus = ( 
    GROUPS     => { 0 => 'XMP', 1 => 'XMP-galacticus', 2 => 'Image' },
    NAMESPACE  => { 'galacticus' => 'http://users.obs.carnegiescience.edu/abenson/galacticus/ns/xmpext/1.0' },
    WRITABLE   => 'string',
    Source     => { Struct => \%sourceStruct                   },
    Build      => { Struct => \%buildStruct                    },
    Version    => { Struct => \%versionStruct                  },
    Parameters => { Struct => \%parameterStruct, List => 'Seq' }
    );
# Add the new XMP namespace to the main XMP table.
%Image::ExifTool::UserDefined = ( 
    'Image::ExifTool::XMP::Main' => {
	galacticus => { 
	    SubDirectory => {
		TagTable => 'Image::ExifTool::UserDefined::galacticus',
	    }, 
	},
    }, 
    );

sub Write {
    # Write metadata to file.

    # Grab the arguments.
    my $plotFile       = shift;
    my $galacticusFile = shift;
    my $scriptFile     = shift;

    # Access the metadata of the plot file.
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(Struct => 1,List => 1);
    $exifTool->ExtractInfo($plotFile);

    # Initialize a hash that will be used to store the metadata.
    my %metaData;

    # Open the Galacticus file.
    my $hdfFile = new PDL::IO::HDF5($galacticusFile);

    # Specify the producer of this file.
    $metaData{'ProducerCode'} = "Galacticus";

    # Extract version information.
    my $versionGroup = $hdfFile->group("Version");
    my @version      = $versionGroup->attrGet("gitBranch","gitHash","runTime");
    $metaData{'Version'} =   
    {
	branch   => $version[0],
	hash     => $version[1],
	runTime  => $version[2]
    };

    # Package any Git changes.
    $metaData{'Source'} = {
	gitDiff   => "",
	gitBundle => ""
    };

    my $git =&File::Which::which("git");
    if ( $git ne "" && exists($ENV{'GALACTICUS_EXEC_PATH'}) ) {
	system "git show-ref ".$ENV{'GALACTICUS_EXEC_PATH'}." > /dev/null 2>&1" ;
	my $isGitBranch = $?;
	if ( $isGitBranch == 0 ) {
	    my $cwd    = `pwd`;
	    my $branch = `git rev-parse --abbrev-ref HEAD`;
	    chomp($branch);
	    system("cd ".$ENV{'GALACTICUS_EXEC_PATH'}."; git bundle create ".$cwd."/gitBundle.meta HEAD ^origin");
	    my $gitDiff   = `git diff $ENV{'GALACTICUS_EXEC_PATH'}`;
	    my $gitBundle = read_file("gitBundle.meta");
	    $metaData{'Source'} = {
		gitDiff   => $gitDiff,
		gitBundle => $gitBundle
	    };
	    unlink("gitBundle.meta");
	}
    }

    # Add build information.
    my @buildParameters = ( 
	"FoX_library_version",
	"GSL_library_version",
	"HDF5_library_version",
	"make_CCOMPILER",
	"make_CCOMPILER_VERSION",
	"make_CFLAGS",
	"make_CPPCOMPILER",
	"make_CPPCOMPILER_VERSION",
	"make_CPPFLAGS",
	"make_FCCOMPILER",
	"make_FCCOMPILER_VERSION",
	"make_FCFLAGS",
	"make_FCFLAGS_NOOPT",
	"make_PREPROCESSOR"
	);
    my $buildGroup = $hdfFile->group('Build');
    my @buildParameterValues = $buildGroup->attrGet(@buildParameters);
    for(my $i=0;$i<scalar(@buildParameters);++$i) {
	${$metaData{'Build'}}{$buildParameters[$i]} = $buildParameterValues[$i];
    }

    # Add model parameters.
    my $parametersGroup      = $hdfFile->group('Parameters');
    my @inputParameters      = $parametersGroup->attrs();
    my @inputParameterValues = $parametersGroup->attrGet(@inputParameters);
    my @parameterMetaData;
    for(my $i=0;$i<scalar(@inputParameters);++$i) {
	my $outputValue = $inputParameterValues[$i];;
	if ( UNIVERSAL::isa($inputParameterValues[$i],'PDL') ) {
	    if ( $inputParameterValues[$i]->isa('PDL::Char') ) {
		my $length = length($inputParameterValues[$i]->atstr(0));
		my $count  = nelem($inputParameterValues[$i])/$length;
		$outputValue = "";
		for(my $j=0;$j<$count;++$j) {
		    $outputValue .= " " if ( $j > 0 );
		    $outputValue .= $inputParameterValues[$i]->atstr($j);
		}
		$outputValue =~ s/\s\s+/ /g;
	    } else {
		$outputValue = join(" ",$inputParameterValues[$i]->list());
	    }
	}
	push(
	    @parameterMetaData,
	    {
		name  => $inputParameters[$i],
		value => $outputValue
	    }
	    );
    }
    $metaData{'Parameters'} = \@parameterMetaData;
    
    # Add the UUID of the model.
    my @uuid = $hdfFile->attrGet("UUID");
    $metaData{'UUID'} = $uuid[0];
    
    # Import script source code.
    $metaData{'Script'} = read_file($scriptFile);

    # Add the metadata to the file.
    foreach my $metaDatum ( keys(%metaData) ) {
	$Image::ExifTool::UserDefined::galacticus{$metaDatum} = { } unless ( exists($Image::ExifTool::UserDefined::galacticus{$metaDatum}) );
    }
    foreach my $metaDatum ( keys(%metaData) ) {
	$exifTool->SetNewValue($metaDatum,$metaData{$metaDatum}, Group => "XMP-galacticus");
    }

    # Write the metadata to file.
    $exifTool->WriteInfo($plotFile);

}

sub Read {
    # Read Galacticus metadata from a file and report on it.

    # Get arguments.
    my $plotFile      = shift;
    my $parameterFile = shift;
    my $scriptFile    = shift;
    my $mergeFile     = shift;
    my $patchFile     = shift;

    # Extract metadata from file.
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(Struct => 1,List => 1);
    $exifTool->ExtractInfo($plotFile);

    # Get producer info.
    my $producer = $exifTool->GetInfo('ProducerCode');
    unless ( $producer->{'ProducerCode'} eq "Galacticus" ) {
	print "File was not created by Galacticus [ProducerCode = ".$producer->{'ProducerCode'}."]\n";
    } else {
	# Report on producer.
	print "File was created by: ".$producer->{'ProducerCode'}."\n\n";

	# Get version info and report.
	my $version = $exifTool->GetInfo('Version');
	print "Galacticus Version:\n";
	print "  Version     : ".$version->{'Version'}->{'Version' }."\n";
	print "  Git Revision: ".$version->{'Version'}->{'Revision'}."\n";
	print "  Run Time    : ".$version->{'Version'}->{'RunTime' }."\n\n";
	print "==> Use:\n";
	print "         git clone --single-branch --branch ".$version->{'Version'}->{'Branch'}." https://github.com/galacticusorg/galacticus.git\n";
	print "         git bundle unbundle ".$mergeFile."\n";
	print "         patch < ".$patchFile."\n\n";
	print "    to obtain this version of Galacticus.\n\n";
	
	# Get source changeset.
	my $changeSet = $exifTool->GetInfo('Source');
	open(oHndl,">".$mergeFile);
	print oHndl $changeSet->{'Source'}->{'GitBundle'};
	close(oHndl);
	open(oHndl,">".$patchFile);
	print oHndl $changeSet->{'Source'}->{'GitDiff'};
	close(oHndl);

	# Get build info and report.
	my $build = $exifTool->GetInfo('Build');
	print "Libraries Used:\n";
	foreach my $buildData ( keys(%{$build->{'Build'}}) ) {
	    if ( $buildData =~ m/(.+)_library_version/ ) {
		my $library = $1;
		print "   ".$library.(" " x (6-length($library))).": v".$build->{'Build'}->{$buildData}."\n";
	    }
	}
	print "\n";
	
	# Get compiler versions and report.
	print "Compiler Versions:\n";
	$Text::Wrap::columns = 132;
	foreach my $buildData ( keys(%{$build->{'Build'}}) ) {
	    if ( $buildData =~ m/Make_(.+)_VERSION/ ) {
		my $compiler = $1;
		my $initial_tab    = "   ".$compiler.(" " x (12-length($compiler)))." : ";
		my $subsequent_tab = "                  ";
		print wrap($initial_tab, $subsequent_tab,$build->{'Build'}->{$buildData})."\n";
	    }
	}
	print "\n";
	
	# Get Makefile options and report.
	print "Makefile Options:\n";
	$Text::Wrap::columns = 132;
	foreach my $buildData ( keys(%{$build->{'Build'}}) ) {
	    if ( $buildData =~ m/Make_([^_]+$)/ ) {
		my $option = $1;
		my $initial_tab    = "   ".$option.(" " x (12-length($option)))." : ";
		my $subsequent_tab = "                  ";
		print wrap($initial_tab, $subsequent_tab,$build->{'Build'}->{$buildData})."\n";
	    }
	}
	print "\n";
	
	# Get model UUID and report.
	my $uuid = $exifTool->GetInfo('UUID');
	print "Model Metadata:\n";
	print "   UUID : ".$uuid->{'Uuid'}."\n\n";
	
	# Get plotting script and store to file.
	my $script = $exifTool->GetInfo('Script');
	open(oHndl,">".$scriptFile);
	print oHndl $script->{'Script'};
	close(oHndl);
	
	# Get parameters and write as XML file.
	my $parameterXML;
	my $parameters = $exifTool->GetInfo('Parameters');
	foreach my $parameter ( @{$parameters->{'Parameters'}} ) {
	    push(
		@{$parameterXML->{'parameter'}},
		{
		    name  => $parameter->{'Name' },
		    value => $parameter->{'Value'}
		}
		);
	}
	my $xml = new XML::Simple(NoAttr=>1, RootName=>"parameters");
	open(oHndl,">".$parameterFile);
	print oHndl $xml->XMLout($parameterXML);
	close(oHndl);

    }

}

1;
