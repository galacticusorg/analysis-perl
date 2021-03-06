#!/usr/bin/env perl
use strict;
use warnings;
use Cwd;
use lib $ENV{'GALACTICUS_ANALYSIS_PERL_PATH'}."/perl";
use PDL;
use PDL::NiceSlice;
use Stats::Histograms;

# Test Perl modules.
# Andrew Benson (7-July-2013)

## Stats::Histograms
### Test binning.
my $xBins = pdl sequence(3);
my $yBins = pdl sequence(3);
my $x     = pdl 4.0*random(100);
my $y     = pdl 3.0*random(100);
my $w     = pdl random(100);
(my $h, my $e, my $c) = &Stats::Histograms::Histogram2D($xBins,$yBins,$x,$y,$w);
foreach my $i ( $xBins->list() ) {
    foreach my $j ( $yBins->list() ) {
	print "FAILED: Stats::Histograms::Histogram2D fails to compute correct weight in bin #1\n"
	    unless (
		&agree(
		     $h->(($i),($j)),
		     sum(
			 where(
			     $w,
			     ($x >= $i-0.5) & ($x < $i+0.5) & ($y >= $j-0.5) & ($y < $j+0.5)
			 )
		     ),
		     1.0e-3,
		     absolute => 1
		)
	    );
    }
}
### Test differential.
my $x2Bins = pdl 2*sequence(3);
my $y2Bins = pdl 2*sequence(3);
my $x2     = pdl 8.0*random(100);
my $y2     = pdl 6.0*random(100);
my $w2     = pdl random(100);
(my $h2, my $e2, my $c2) = &Stats::Histograms::Histogram2D($x2Bins,$y2Bins,$x2,$y2,$w2,differential => "xy");
for(my $i=0;$i<3;++$i) {
    for(my $j=0;$j<3;++$j) {
	print "FAILED: Stats::Histograms::Histogram2D fails to compute correct weight in bin #2\n"
	    unless (
		&agree(
		     $h2->(($i),($j)),
		     sum(
			 where(
			     $w2,
			     ($x2 >= 2.0*$i-1.0) & ($x2 < 2.0*$i+1.0) & ($y2 >= 2.0*$j-1.0) & ($y2 < 2.0*$j+1.0)
			 )
		     )
		     /4.0,
		     1.0e-3,
		     absolute => 1
		)
	    );
    }
}
### Test normalization.
#### xy
(my $hxyh, my $exyh, my $cxyh) = &Stats::Histograms::Histogram2D($xBins,$yBins,$x,$y,$w,normalized => "xy",normalizeBy => "histogram");
print "FAILED: Stats::Histograms::Histogram2D fails to normalize [xy:histogram]\n"
    unless ( &agree(sum($hxyh),1.0,1.0e-6) );
(my $hxyw, my $exyw, my $cxyw) = &Stats::Histograms::Histogram2D($xBins,$yBins,$x,$y,$w,normalized => "xy",normalizeBy => "weights"  );
print "FAILED: Stats::Histograms::Histogram2D fails to normalize [xy:weights]\n"
    unless (
	&agree(
	     sum($hxyw) 
	     , 
	     sum(
		 where(
		     $w,
		     ($x < 2.5)
		     &
		     ($y < 2.5)
		 )
	     )
	     /
	     sum($w)
	     ,
	     1.0e-6
	)
    );
#### x
(my $hxh, my $exh, my $cxh) = &Stats::Histograms::Histogram2D($xBins,$yBins,$x,$y,$w,normalized => "x", normalizeBy => "histogram");
(my $hxw, my $exw, my $cxw) = &Stats::Histograms::Histogram2D($xBins,$yBins,$x,$y,$w,normalized => "x", normalizeBy => "weights"  );
for(my $j=0;$j<3;++$j) {
    print "FAILED: Stats::Histograms::Histogram2D fails to normalize [x:histogram]\n"
	unless ( &agree(sum($hxh->(:,($j))),1.0,1.0e-6) );
    print "FAILED: Stats::Histograms::Histogram2D fails to normalize [x:weights]\n"
	unless ( &agree(sum($hxw->(:,($j))),sum(where($w,($x > -0.5) & ($x < 2.5) & ($y > $j-0.5) & ($y < $j+0.5)))/sum(where($w,($y > $j-0.5) & ($y < $j+0.5))),1.0e-6) );
}
#### y
(my $hyh, my $eyh, my $cyh) = &Stats::Histograms::Histogram2D($xBins,$yBins,$x,$y,$w,normalized => "y", normalizeBy => "histogram");
(my $hyw, my $eyw, my $cyw) = &Stats::Histograms::Histogram2D($xBins,$yBins,$x,$y,$w,normalized => "y", normalizeBy => "weights"  );
for(my $i=0;$i<3;++$i) {
    print "FAILED: Stats::Histograms::Histogram2D fails to normalize [y:histogram]\n"
	unless ( &agree(sum($hyh->(($i),:)),1.0,1.0e-6) );
    print "FAILED: Stats::Histograms::Histogram2D fails to normalize [y:weights]\n"
	unless ( &agree(sum($hyw->(($i),:)),sum(where($w,($x > $i-0.5) & ($x < $i+0.5) & ($y > -0.5) & ($y < 2.5)))/sum(where($w,($x > $i-0.5) & ($x < $i+0.5))),1.0e-6) );
}
### Test Gaussian smoothing
my $xs = pdl ( 1.0 );
my $ys = pdl ( 1.0 );
my $sx = pdl ( 1.0 );
my $sy = pdl ( 1.0 );
my $ws = pdl ( 1.0 );
(my $hs, my $es, my $cs) = &Stats::Histograms::Histogram2D($xBins,$yBins,$xs,$ys,$ws,gaussianSmoothX => $sx,gaussianSmoothY => $sy);
my $hst = pdl
    [
     [0.058433556, 0.092564571, 0.058433556],
     [0.092564571,   0.1466315, 0.092564571],
     [0.058433556, 0.092564571, 0.058433556]
    ];
print "FAILED: Stats::Histograms::Histogram2D fails to smooth\n"
    unless ( &agree($hs,$hst,1.0e-6) );
print "FAILED: Stats::Histograms::Histogram2D covariance fails for gaussian smoothing\n"
    unless ( &agree(sqrt($cs->diagonal(0,1)),$es->flat(),1.0e-6) );
#### Normalized in x
(my $hsxh, my $esxh, my $csxh) = &Stats::Histograms::Histogram2D($xBins,$yBins,$xs,$ys,$ws,gaussianSmoothX => $sx,gaussianSmoothY => $sy, normalized => "x", normalizeBy => "histogram");
(my $hsxw, my $esxw, my $csxw) = &Stats::Histograms::Histogram2D($xBins,$yBins,$xs,$ys,$ws,gaussianSmoothX => $sx,gaussianSmoothY => $sy, normalized => "x", normalizeBy => "weights");
for(my $j=0;$j<3;++$j) {
    print "FAILED: Stats::Histograms::Histogram2D fails to normalize [x:histogram]\n"
	unless ( &agree(sum($hsxh->(:,($j))),1.0000000000,1.0e-6) );
    print "FAILED: Stats::Histograms::Histogram2D fails to normalize [x:weights]\n"
	unless ( &agree(sum($hsxw->(:,($j))),0.8663855075,1.0e-6) );
}
####  Note that covariance should be zero as we have a single point and we've normalized it.
my $csxht = pdl zeroes(9);
print "FAILED: Stats::Histograms::Histogram2D covariance fails for gaussian smoothing\n"
    unless ( &agree(sqrt($csxh->diagonal(0,1)),$csxht,1.0e-6,absolute => 1) );
#### Normalized in y
(my $hsyh, my $esyh, my $csyh) = &Stats::Histograms::Histogram2D($xBins,$yBins,$xs,$ys,$ws,gaussianSmoothX => $sx,gaussianSmoothY => $sy, normalized => "y", normalizeBy => "histogram");
(my $hsyw, my $esyw, my $csyw) = &Stats::Histograms::Histogram2D($xBins,$yBins,$xs,$ys,$ws,gaussianSmoothX => $sx,gaussianSmoothY => $sy, normalized => "y", normalizeBy => "weights");
for(my $i=0;$i<3;++$i) {
    print "FAILED: Stats::Histograms::Histogram2D fails to normalize [y:histogram]\n"
	unless ( &agree(sum($hsyh->(($i),:)),1.0000000000,1.0e-6) );
    print "FAILED: Stats::Histograms::Histogram2D fails to normalize [y:weights]\n"
	unless ( &agree(sum($hsyw->(($i),:)),0.8663855075,1.0e-6) );
}
####  Note that covariance should be zero as we have a single point and we've normalized it.
my $csyht = pdl zeroes(9);
print "FAILED: Stats::Histograms::Histogram2D covariance fails for gaussian smoothing\n"
    unless ( &agree(sqrt($csyh->diagonal(0,1)),$csyht,1.0e-6,absolute => 1) );

exit;

sub agree {
    # Return true if two values agree to within the given fractional tolerance.
    my $a         = shift;
    my $b         = shift;
    my $tolerance = shift;
    my %options;
    if ( $#_ >= 1 ) {(%options) = @_};
    $options{'absolute'} = 0
	unless ( exists($options{'absolute'}) );
    if ( UNIVERSAL::isa($a, 'PDL') ) {
	my $scale = 0.5*(abs($a)+abs($b));
	$scale .= 1.0
	    if ( $options{'absolute'} == 1 );
	if ( all(abs($a-$b) < $tolerance*$scale) ) {
	    return 1;
	} else {
	    return 0;
	}
    } else {
	my $scale = 0.5*(abs($a)+abs($b));
	$scale = 1.0
	    if ( $options{'absolute'} == 1 );
	if ( abs($a-$b) < $tolerance*$scale ) {
	    return 1;
	} else {
	    return 0;
	}
    }
}
