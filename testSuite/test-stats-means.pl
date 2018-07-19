#!/usr/bin/env perl
use strict;
use warnings;
use Cwd;
use lib $ENV{'GALACTICUS_ANALYSIS_PERL_PATH'}."/perl";
use PDL;
use PDL::NiceSlice;
use Data::Dumper;
use Stats::Means;

# Test Perl modules.
# Andrew Benson (7-July-2013)

# Statistics
#  Create bins.
my $bins = pdl sequence(3);

## Stats::Means
my $xm = pdl ( 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2 );
my $ym = pdl ( 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29 );
my $wm = pdl ( 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  1,  1,  1,  1,   1,  1, 1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1 );
my $eps      = pdl 1.0e-3;
my $mExpect  = pdl ( 4.5       , 14.5       , 24.5        );
my $meExpect = pdl ( 0.90829511,  0.90829511,  0.90829511 );
my $dExpect  = pdl ( 3.0276503 ,  3.0276503 ,  3.0276503  );
my $deExpect = pdl ( 1.6371658 ,  1.6371658 ,  1.6371658  );
(my $m, my $me, my $d, my $de) = &Stats::Means::BinnedMean($bins,$xm,$ym,$wm);
print "FAILED: Stats::Means::BinnedMean fails to compute correct means\n"
    unless ( all(abs($m - $mExpect) < $eps*$mExpect ) );
print "FAILED: Stats::Means::BinnedMean fails to compute correct errors on means\n"
    unless ( all(abs($me-$meExpect) < $eps*$meExpect) );
print "FAILED: Stats::Means::BinnedMean fails to compute correct standard deviation\n"
    unless ( all(abs($d - $dExpect) < $eps*$dExpect ) );
print "FAILED: Stats::Means::BinnedMean fails to compute correct errors on standard deviation\n"
    unless ( all(abs($de-$deExpect) < $eps*$deExpect) );

exit 0;
