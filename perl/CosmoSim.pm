package CosmoSim;
use strict;
use warnings;
use Cwd;
use lib $ENV{'GALACTICUS_ANALYSIS_PERL_PATH'}."/perl";
use WWW::Curl::Easy;
use WWW::Curl::Form;
use XML::Simple;
use DateTime;
use Data::Dumper;

sub query {
    # Run a query on the CosmoSim server and download results.
    my $queryString = shift;
    my $fileName    = shift;
    # Parse the Galacticus config file if it is present.
    my $sqlUser;
    my $sqlPassword;
    if ( -e $ENV{'GALACTICUS_EXEC_PATH'}."/galacticusConfig.xml" ) {
	my $xml    = new XML::Simple();
	my $config = $xml->XMLin($ENV{'GALACTICUS_EXEC_PATH'}."/galacticusConfig.xml");
	if ( exists($config->{'cosmosimDB'}->{'host'}) ) {
	    my %hosts;
	    if ( exists($config->{'cosmosimDB'}->{'host'}->{'name'}) ) {
		$hosts{'default'} = $config->{'cosmosimDB'}->{'host'};
	    } else {
		%hosts = %{$config->{'cosmosimDB'}->{'host'}};
	    }
	    foreach ( keys(%hosts) ) {
		if ( $_ eq $ENV{'HOSTNAME'} || $_ eq "default" ) {
		    $sqlUser     = $hosts{$_}->{'user'    }
		    if ( exists($hosts{$_}->{'user'    }) );
		    $sqlPassword = $hosts{$_}->{'password'}
		    if ( exists($hosts{$_}->{'password'}) );
		    if ( exists($hosts{$_}->{'passwordFrom'}) ) {
			if ( $hosts{$_}->{'passwordFrom'} eq "input" ) {
			    $sqlPassword = <>;
			    chomp($sqlPassword);
			}
		    }
		}
	    }
	}
    }
    die("CosmoSim::query: CosmoSim database username and password must be defined")
	unless ( defined($sqlUser) && defined($sqlPassword) );
    # Get Curl objects.
    my $xml      = new XML::Simple    ();
    my $curlPost = new WWW::Curl::Easy();
    my $curlGet  = new WWW::Curl::Easy();
    # Create the query job.
    my $createText;
    my $date       = DateTime->now();
    my $createForm = new WWW::Curl::Form();
    $createForm->formadd("query",$queryString);
    $createForm->formadd("queue","long"      );
    $createForm->formadd("table",$date       );
    $curlPost->setopt(CURLOPT_URL               ,"https://www.cosmosim.org/uws/query");
    $curlPost->setopt(CURLOPT_HTTPPOST          ,$createForm                         );
    $curlPost->setopt(CURLOPT_FOLLOWLOCATION    ,1                                   );
    $curlPost->setopt(CURLOPT_SSL_VERIFYPEER    ,0                                   );
    $curlPost->setopt(CURLOPT_USERPWD           ,$sqlUser.":".$sqlPassword           );
    $curlPost->setopt(CURLOPT_WRITEDATA         ,\$createText                        );
    print "CosmoSim::query: creating CosmoSim UWS job\n";
    unless ( $curlPost->perform() == 0 ) {
	print $curlPost->errbuf();
	die("CosmoSim::query(): failed to create job");
    }
    my $query = $xml->XMLin($createText);
    # Submit the job.
    my $submitText;
    my $submitForm = new WWW::Curl::Form();
    $submitForm->formadd("phase","run" );
    $curlPost->setopt(CURLOPT_URL      ,"https://www.cosmosim.org/uws/query/".$query->{'uws:jobId'});
    $curlPost->setopt(CURLOPT_HTTPPOST ,$submitForm                                                );
    $curlPost->setopt(CURLOPT_WRITEDATA,\$submitText                                               );
    print "CosmoSim::query: submitting CosmoSim UWS job\n";
    die("CosmoSim::query(): failed to submit job")
	unless ( $curlPost->perform() == 0 );
    # Check status.
    my $statusText;
    do {
	undef($statusText);
	sleep(10);
	$curlGet->setopt(CURLOPT_URL           ,"https://www.cosmosim.org/uws/query/".$query->{'uws:jobId'}."/phase");
	$curlGet->setopt(CURLOPT_USERPWD       ,$sqlUser.":".$sqlPassword                                           );
	$curlGet->setopt(CURLOPT_SSL_VERIFYPEER,0                                                                   );
	$curlGet->setopt(CURLOPT_WRITEDATA     ,\$statusText                                                        );
	my $status = $curlGet->perform();
	die("CosmoSim::query(): failed to check status")
	    unless ( $status == 0 );
	print "CosmoSim::query: CosmoSim UWS job status is '".$statusText."'\n";
	if ( $statusText eq "ERROR" || $statusText eq "ABORTED" ) {
	    print $curlGet->strerror($status)."\n";
	    print $curlGet->errbuf()."\n";
	    die;
	}
    }
    until ( $statusText eq "COMPLETED" );
    # Get results information.
    my $resultsText;
    $curlGet->setopt(CURLOPT_URL      ,"https://www.cosmosim.org/uws/query/".$query->{'uws:jobId'}."/results");
    $curlGet->setopt(CURLOPT_USERPWD  ,$sqlUser.":".$sqlPassword                                             );
    $curlGet->setopt(CURLOPT_WRITEDATA,\$resultsText                                                         );
    die("CosmoSim::query(): failed to get results information")
	unless ( $curlGet->perform() == 0 );
    my $results = $xml->XMLin($resultsText);
    # Download results.
    open(my $resultsFile,">".$fileName);
    $curlGet->setopt(CURLOPT_URL      ,$results->{'uws:result'}->{'csv'}->{'xlink:href'});
    $curlGet->setopt(CURLOPT_USERPWD  ,$sqlUser.":".$sqlPassword                        );
    $curlGet->setopt(CURLOPT_WRITEDATA,$resultsFile                                     );
    print "CosmoSim::query: downloading CosmoSim data\n";
    unless ( $curlGet->perform() == 0 ) {
	print $curlGet->errbuf();
	die("CosmoSim::query(): failed to get results information");
    }
    close($resultsFile);
    # Delete the job.
    my $deleteText;
    $curlGet->setopt(CURLOPT_URL          , "https://www.cosmosim.org/uws/query/".$query->{'uws:jobId'});
    $curlGet->setopt(CURLOPT_USERPWD      ,$sqlUser.":".$sqlPassword                                   );
    $curlGet->setopt(CURLOPT_CUSTOMREQUEST, "DELETE"                                                   ); 
    $curlGet->setopt(CURLOPT_WRITEDATA    ,\$deleteText                                                );
    print "CosmoSim::query: deleting CosmoSim UWS job\n";
    die("CosmoSim::query(): failed to get results information")
	unless ( $curlGet->perform() == 0 );
}

1;
