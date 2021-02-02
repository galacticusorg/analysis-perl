# Contains a Perl module which implements calculations of binned percentiles in weighted data.

package Stats::Percentiles;
use strict;
use warnings;
use PDL;
use PDL::NiceSlice;
use PDL::Ufunc;

sub BinnedPercentiles {
    # Distribute input data into specified bins, find the cumulative distribution of (weighted) values and determine the specified
    # percentiles of that distribution.

    # Get the arguments.
    my $binCenters  = shift;
    my $xValues     = shift;
    my $yValues     = shift;
    my $weights     = shift;
    my $percentiles = shift;
    my %options;
    if ( $#_ >= 1 ) {(%options) = @_};

    # Minimum number of points in a bin.
    my $binCountMinimum = exists($options{'binCountMinimum'}) ? $options{'binCountMinimum'} : 2;
    
    # Compute bin size.
    my $binWidth = ($binCenters->index(nelem($binCenters)-1)-$binCenters->index(0))/(nelem($binCenters)-1);

    # Compute bin ranges.
    my $binMinimum = $binCenters-0.5*$binWidth;
    my $binMaximum = $binCenters+0.5*$binWidth;

    # Create a PDL for results.
    my $results = pdl zeroes(nelem($binCenters),nelem($percentiles));

    # Loop through bins.
    for(my $iBin=0;$iBin<nelem($binCenters);++$iBin) {
	# Select properties in this bin.
	my $yValuesSelected = where($yValues,($xValues >= $binMinimum->index($iBin)) & ($xValues < $binMaximum->index($iBin)) );
	my $weightsSelected = where($weights,($xValues >= $binMinimum->index($iBin)) & ($xValues < $binMaximum->index($iBin)) );

        # Only compute results for cases where we have more than one entry.
	if ( nelem($yValuesSelected) >= $binCountMinimum ) {	

	    # Sort the selected values.
	    my $sortIndex = qsorti $yValuesSelected;
	    
	    # Get the cumulative weight and normalize to 100%.
	    my $cumulativeWeightsSelected  = cumusumover($weightsSelected->index($sortIndex));
	    $cumulativeWeightsSelected *= 100.0/$cumulativeWeightsSelected->index(nelem($cumulativeWeightsSelected)-1);
	    
	    # Interpolate to the desired percentiles to get the corresponding y values.
	    $results(($iBin),:) .= interpol($percentiles,$cumulativeWeightsSelected,$yValuesSelected->index($sortIndex));

	}

    }

    # Return the results.
    return $results;
}

sub AdaptiveBinnedPercentiles {
    # Distribute input data into adapatively-chosen bins containing equal numbers of points, find the cumulative distribution of
    # (weighted) values and determine the specified percentiles of that distribution.

    # Get the arguments.
    my $x           = shift();
    my $y           = shift();
    my $weights     = shift();
    my $percentiles = shift();
    my $countPerBin = shift();
    my %options;
    if ( $#_ >= 1 ) {(%options) = @_};

    # Construct output arrays.
    my $binCount    = int(nelem($x)/$countPerBin);
    ++$binCount
	unless ( nelem($x) % $countPerBin == 0 );
    
    # Minimum number of points in a bin.
    my $binCountMinimum = exists($options{'binCountMinimum'}) ? $options{'binCountMinimum'} : 2;
    
    # Order the x values.
    my $xIndex      = $x->qsorti();

    # Create a PDL for results.
    my $results    = pdl zeroes($binCount,nelem($percentiles));
    my $binCenters = pdl zeroes($binCount);

    # Loop through bins.
    my $jMinimum = -1;
    my $jMaximum = -1;
    my $iBin     = -1;
    while ($jMaximum < nelem($x)-1) {
	# Find minimum and maximum indices to include in this bin.
	++$iBin;
	$jMinimum = $jMaximum+1;
	$jMaximum = $jMinimum+$countPerBin-1;
	$jMaximum = nelem($x)-1
	    if ( $jMaximum > nelem($x)-1 );
	if ( exists($options{'binWidthMinimum'}) && $jMinimum > 0 ) {
	    while ( $jMaximum < nelem($x)-1 && $x->($xIndex)->(($jMaximum))-$x->($xIndex)->(($jMinimum)) < $options{'binWidthMinimum'} ) {
		++$jMaximum;	 
	    }
	}
	# Select properties in this bin.
	my $xSelected       = $x      ->($xIndex)->($jMinimum:$jMaximum);
	my $ySelected       = $y      ->($xIndex)->($jMinimum:$jMaximum);
	my $weightsSelected = $weights->($xIndex)->($jMinimum:$jMaximum);

        # Only compute results for cases where we have more than one entry.
	if ( nelem($ySelected) >= $binCountMinimum ) {	

	    # Sort the selected values.
	    my $sortIndex = qsorti $ySelected;
	    
	    # Get the cumulative weight and normalize to 100%.
	    my $cumulativeWeightsSelected  = cumusumover($weightsSelected->index($sortIndex));
	    $cumulativeWeightsSelected *= 100.0/$cumulativeWeightsSelected->index(nelem($cumulativeWeightsSelected)-1);
	    
	    # Interpolate to the desired percentiles to get the corresponding y values.
	    $results(($iBin),:) .= interpol($percentiles,$cumulativeWeightsSelected,$ySelected->index($sortIndex));

	    # Find the median x-coordinate in the bin.
	    my $sortIndexX = qsorti $xSelected;
	    my $cumulativeWeightsSelectedX  = cumusumover($weightsSelected->index($sortIndexX));
	    $cumulativeWeightsSelectedX *= 100.0/$cumulativeWeightsSelectedX->index(nelem($cumulativeWeightsSelectedX)-1);
	    my $median = pdl [ 50.0 ];
	    $binCenters(($iBin)) .= interpol($median,$cumulativeWeightsSelectedX,$xSelected->index($sortIndexX));


	}

    }

    # Return the results.
    return ($binCenters, $results);
}

sub AdaptiveBinnedMedian {
    # Distribute input data into adapatively-chosen bins containing equal numbers of points, find the cumulative distribution of
    # (weighted) values and determine the median and median absolute deviation.

    # Get the arguments.
    my $x           = shift();
    my $y           = shift();
    my $weights     = shift();
    my $countPerBin = shift();
    my %options;
    if ( $#_ >= 1 ) {(%options) = @_};

    # Construct output arrays.
    my $binCount    = int(nelem($x)/$countPerBin);
    ++$binCount
	unless ( nelem($x) % $countPerBin == 0 );
    
    # Minimum number of points in a bin.
    my $binCountMinimum = exists($options{'binCountMinimum'}) ? $options{'binCountMinimum'} : 2;
    
    # Order the x values.
    my $xIndex      = $x->qsorti();

    # Create a PDL for results.
    my $medians    = pdl zeroes($binCount);
    my $deviations = pdl zeroes($binCount);
    my $binCenters = pdl zeroes($binCount);

    # Loop through bins.
    my $jMinimum = -1;
    my $jMaximum = -1;
    my $iBin     = -1;
    while ($jMaximum < nelem($x)-1) {
	# Find minimum and maximum indices to include in this bin.
	++$iBin;
	$jMinimum = $jMaximum+1;
	$jMaximum = $jMinimum+$countPerBin-1;
	$jMaximum = nelem($x)-1
	    if ( $jMaximum > nelem($x)-1 );
	if ( exists($options{'binWidthMinimum'}) && $jMinimum > 0 ) {
	    while ( $jMaximum < nelem($x)-1 && $x->($xIndex)->(($jMaximum))-$x->($xIndex)->(($jMinimum)) < $options{'binWidthMinimum'} ) {
		++$jMaximum;	 
	    }
	}
	# Select properties in this bin.
	my $xSelected       = $x      ->($xIndex)->($jMinimum:$jMaximum);
	my $ySelected       = $y      ->($xIndex)->($jMinimum:$jMaximum);
	my $weightsSelected = $weights->($xIndex)->($jMinimum:$jMaximum);

        # Only compute results for cases where we have more than one entry.
	if ( nelem($ySelected) >= $binCountMinimum ) {	

	    # Sort the selected values.
	    my $sortIndex = qsorti $ySelected;
	    
	    # Get the cumulative weight and normalize to 100%.
	    my $cumulativeWeightsSelected  = cumusumover($weightsSelected->index($sortIndex));
	    $cumulativeWeightsSelected *= 100.0/$cumulativeWeightsSelected->index(nelem($cumulativeWeightsSelected)-1);
	    
	    # Interpolate to the desired percentiles to get the corresponding y values.
	    my $median = pdl [ 50.0 ];
	    $medians(($iBin)) .= interpol($median,$cumulativeWeightsSelected,$ySelected->index($sortIndex));

	    # Construct the median absolute deviation.
	    my $devs = abs($ySelected-$medians(($iBin)));
	    my $sortIndexD = qsorti($devs);
	    my $cumulativeWeightsSelectedD  = cumusumover($weightsSelected->index($sortIndexD));
	    $cumulativeWeightsSelectedD *= 100.0/$cumulativeWeightsSelectedD->index(nelem($cumulativeWeightsSelectedD)-1);
	    $deviations(($iBin)) .= interpol($median,$cumulativeWeightsSelectedD,$devs->index($sortIndexD));
	    
	    # Find the median x-coordinate in the bin.
	    my $sortIndexX = qsorti $xSelected;
	    my $cumulativeWeightsSelectedX  = cumusumover($weightsSelected->index($sortIndexX));
	    $cumulativeWeightsSelectedX *= 100.0/$cumulativeWeightsSelectedX->index(nelem($cumulativeWeightsSelectedX)-1);
	    $binCenters(($iBin)) .= interpol($median,$cumulativeWeightsSelectedX,$xSelected->index($sortIndexX));


	}

    }

    # Return the results.
    return ($binCenters, $medians, $deviations);
}

1;
