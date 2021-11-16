# Contains a Perl module which implements simple, yet pretty plotting of PDL datasets using GnuPlot.

package GnuPlot::PrettyPlots;
use strict;
use warnings;
use Cwd;
use lib $ENV{'GALACTICUS_ANALYSIS_PERL_PATH'}."/perl";
use PDL;
use Imager::Color;

# A set of color definitions in #RRGGBB format.
our %colors = (
    Snow                       => "#FFFAFA",
    Snow2                      => "#EEE9E9",
    Snow3                      => "#CDC9C9",
    Snow4                      => "#8B8989",
    GhostWhite                 => "#F8F8FF",
    WhiteSmoke                 => "#F5F5F5",
    Gainsboro                  => "#DCCDC",
    FloralWhite                => "#FFFAF0",
    OldLace                    => "#FDF5E6",
    Linen                      => "#FAF0E6",
    AntiqueWhite               => "#FAEBD7",
    AntiqueWhite2              => "#EEDFCC",
    AntiqueWhite3              => "#CDC0B0",
    AntiqueWhite4              => "#8B8378",
    PapayaWhip                 => "#FFEFD5",
    BlanchedAlmond             => "#FFEBCD",
    Bisque                     => "#FFE4C4",
    Bisque2                    => "#EED5B7",
    Bisque3                    => "#CDB79E",
    Bisque4                    => "#8B7D6B",
    PeachPuff                  => "#FFDAB9",
    PeachPuff2                 => "#EECBAD",
    PeachPuff3                 => "#CDAF95",
    PeachPuff4                 => "#8B7765",
    NavajoWhite                => "#FFDEAD",
    Moccasin                   => "#FFE4B5",
    Cornsilk                   => "#FFF8DC",
    Cornsilk2                  => "#EEE8DC",
    Cornsilk3                  => "#CDC8B1",
    Cornsilk4                  => "#8B8878",
    Ivory                      => "#FFFFF0",
    Ivory2                     => "#EEEEE0",
    Ivory3                     => "#CDCDC1",
    Ivory4                     => "#8B8B83",
    LemonChiffon               => "#FFFACD",
    Seashell                   => "#FFF5EE",
    Seashell2                  => "#EEE5DE",
    Seashell3                  => "#CDC5BF",
    Seashell4                  => "#8B8682",
    Honeydew                   => "#F0FFF0",
    Honeydew2                  => "#E0EEE0",
    Honeydew3                  => "#C1CDC1",
    Honeydew4                  => "#838B83",
    MintCream                  => "#F5FFFA",
    Azure                      => "#F0FFFF",
    AliceBlue                  => "#F0F8FF",
    Lavender                   => "#E6E6FA",
    LavenderBlush              => "#FFF0F5",
    MistyRose                  => "#FFE4E1",
    White                      => "#FFFFFF",
    # Grays
    Black                      => "#000000",
    DarkSlateGray              => "#2F4F4F",
    DimGray                    => "#696969",
    SlateGray                  => "#708090",
    LightSlateGray             => "#778899",
    Gray                       => "#BEBEBE",
    LightGray                  => "#D3D3D3",
    # Blues
    MidnightBlue               => "#191970",
    Navy                       => "#000080",
    CornflowerBlue             => "#6495ED",
    DarkSlateBlue              => "#483D8B",
    SlateBlue                  => "#6A5ACD",
    MediumSlateBlue            => "#7B68EE",
    LightSlateBlue             => "#8470FF",
    MediumBlue                 => "#0000CD",
    RoyalBlue                  => "#4169E1",
    Blue                       => "#0000FF",
    DodgerBlue                 => "#1E90FF",
    DeepSkyBlue                => "#00BFFF",
    SkyBlue                    => "#87CEEB",
    LightSkyBlue               => "#87CEFA",
    SteelBlue                  => "#4682B4",
    LightSteelBlue             => "#B0C4DE",
    LightBlue                  => "#ADD8E6",
    PowderBlue                 => "#B0E0E6",
    PaleTurquoise              => "#AFEEEE",
    DarkTurquoise              => "#00CED1",
    MediumTurquoise            => "#48D1CC",
    Turquoise                  => "#40E0D0",
    Cyan                       => "#00FFFF",
    LightCyan                  => "#E0FFFF",
    CadetBlue                  => "#5F9EA0",
    # Greens
    MediumAquamarine           => "#66CDAA",
    Aquamarine                 => "#7FFFD4",
    DarkGreen                  => "#006400",
    DarkOliveGreen             => "#556B2F",
    DarkSeaGreen               => "#8FBC8F",
    SeaGreen                   => "#2E8B57",
    MediumSeaGreen             => "#3CB371",
    LightSeaGreen              => "#20B2AA",
    PaleGreen                  => "#98FB98",
    SpringGreen                => "#00FF7F",
    LawnGreen                  => "#7CFC00",
    Chartreuse                 => "#7FFF00",
    MediumSpringGreen          => "#00FA9A",
    GreenYellow                => "#ADFF2F",
    LimeGreen                  => "#32CD32",
    YellowGreen                => "#9ACD32",
    ForestGreen                => "#228B22",
    OliveDrab                  => "#6B8E23",
    DarkKhaki                  => "#BDB76B",
    Khaki                      => "#F0E68C",
    Yellow                     => "#FFFF00",
    PaleGoldenrod              => "#EEE8AA",
    LightGoldenrodYellow       => "#FAFAD2",
    LightYellow                => "#FFFFE0",
    Gold                       => "#FFD700",
    LightGoldenrod             => "#EEDD82",
    Goldenrod                  => "#DAA520",
    DarkGoldenrod              => "#B8860B",
    Green                      => "#00FF00",
    # Browns
    RosyBrown                  => "#BC8F8F",
    IndianRed                  => "#CD5C5C",
    SaddleBrown                => "#8B4513",
    Sienna                     => "#A0522D",
    Peru                       => "#CD853F",
    Burlywood                  => "#DEB887",
    Beige                      => "#F5F5DC",
    Wheat                      => "#F5DEB3",
    SandyBrown                 => "#F4A460",
    Tan                        => "#D2B48C",
    Chocolate                  => "#D2691E",
    Firebrick                  => "#B22222",
    Brown                      => "#A52A2A",
    # Oranges
    DarkSalmon                 => "#E9967A",
    Salmon                     => "#FA8072",
    LightSalmon                => "#FFA07A",
    Orange                     => "#FFA500",
    DarkOrange                 => "#FF8C00",
    Coral                      => "#FF7F50",
    LightCoral                 => "#F08080",
    Tomato                     => "#FF6347",
    OrangeRed                  => "#FF4500",
    Red                        => "#FF0000",
    # Pinks/Violets
    HotPink                    => "#FF69B4",
    DeepPink                   => "#FF1493",
    Pink                       => "#FFC0CB",
    LightPink                  => "#FFB6C1",
    PaleVioletRed              => "#DB7093",
    Maroon                     => "#B03060",
    MediumVioletRed            => "#C71585",
    VioletRed                  => "#D02090",
    Violet                     => "#EE82EE",
    Plum                       => "#DDA0DD",
    Orchid                     => "#DA70D6",
    MediumOrchid               => "#BA55D3",
    DarkOrchid                 => "#9932CC",
    DarkViolet                 => "#9400D3",
    BlueViolet                 => "#8A2BE2",
    Purple                     => "#A020F0",
    MediumPurple               => "#9370DB",
    Thistle                    => "#D8BFD8",
    # Okabe-Ito palette "Set of colors that is unambiguous both to colorblinds and non-colorblinds"; https://jfly.uni-koeln.de/color/
    OkabeItoBlack              => "#000000",
    OkabeItoOrange             => "#E69F00",
    OkabeItoSkyBlue            => "#56B4E9",
    OkabeItoBluishGreen        => "#009E73",
    OkabeItoYellow             => "#F0E442",
    OkabeItoBlue               => "#0072B2",
    OkabeItoVermillion         => "#D55E00",
    OkabeItoReddishPurple      => "#CC79A7",
    OkabeItoBlackShade         => "#333333",
    OkabeItoOrangeShade        => "#cc6600",
    OkabeItoSkyBlueShade       => "#29cccc",
    OkabeItoBluishGreenShade   => "#06cc33",
    OkabeItoYellowShade        => "#b8c214",
    OkabeItoBlueShade          => "#0066cc",
    OkabeItoVermillionShade    => "#cc2900",
    OkabeItoReddishPurpleShade => "#b83dcc"
    );

# Sets of color pairs suitable for plotting points with a light middle and darker border.
our %colorPairs = (
    greenRed              => [$colors{'Green'                },$colors{'Red'                       }],
    redYellow             => [$colors{'Red'                  },$colors{'Yellow'                    }],
    redYellowFaint        => [$colors{'OrangeRed'            },$colors{'LightYellow'               }],
    salmon                => [$colors{'DarkSalmon'           },$colors{'Salmon'                    }],
    orange                => [$colors{'DarkOrange'           },$colors{'Orange'                    }],
    blackGray             => [$colors{'SlateGray'            },$colors{'Black'                     }],
    blueCyan              => [$colors{'Blue'                 },$colors{'Cyan'                      }],
    peachPuff             => [$colors{'Bisque3'              },$colors{'PeachPuff'                 }],
    slateGray             => [$colors{'DarkSlateGray'        },$colors{'SlateGray'                 }],
    lightGray             => [$colors{'Gray'                 },$colors{'LightGray'                 }],
    darkSlateBlue         => [$colors{'MidnightBlue'         },$colors{'DarkSlateBlue'             }],
    cornflowerBlue        => [$colors{'DarkSlateBlue'        },$colors{'CornflowerBlue'            }],
    lightSkyBlue          => [$colors{'DodgerBlue'           },$colors{'LightSkyBlue'              }],
    mediumSeaGreen        => [$colors{'SeaGreen'             },$colors{'MediumSeaGreen'            }],
    lightSeaGreen         => [$colors{'MediumSeaGreen'       },$colors{'LightSeaGreen'             }],
    yellowGreen           => [$colors{'OliveDrab'            },$colors{'YellowGreen'               }],
    lightGoldenrod        => [$colors{'Goldenrod'            },$colors{'LightGoldenrod'            }],
    indianRed             => [$colors{'Sienna'               },$colors{'IndianRed'                 }],
    orange                => [$colors{'OrangeRed'            },$colors{'Orange'                    }],
    plum                  => [$colors{'VioletRed'            },$colors{'Plum'                      }],
    thistle               => [$colors{'MediumPurple'         },$colors{'Thistle'                   }],
    hotPink               => [$colors{'Maroon'               },$colors{'HotPink'                   }],
    midnightBlue          => [$colors{'Navy'                 },$colors{'MidnightBlue'              }],
    okabeItoBlack         => [$colors{'OkabeItoBlack'        },$colors{'OkabeItoBlackShade'        }],
    okabeItoOrange        => [$colors{'OkabeItoOrange'       },$colors{'OkabeItoOrangeShade'       }],
    okabeItoSkyBlue       => [$colors{'OkabeItoSkyBlue'      },$colors{'OkabeItoSkyBlueShade'      }],
    okabeItoBluishGreen   => [$colors{'OkabeItoBluishGreen'  },$colors{'OkabeItoBluishGreenShade'  }],
    okabeItoYellow        => [$colors{'OkabeItoYellow'       },$colors{'OkabeItoYellowShade'       }],
    okabeItoBlue          => [$colors{'OkabeItoBlue'         },$colors{'OkabeItoBlueShade'         }],
    okabeItoVermillion    => [$colors{'OkabeItoVermillion'   },$colors{'OkabeItoVermillionShade'   }],
    okabeItoReddishPurple => [$colors{'OkabeItoReddishPurple'},$colors{'OkabeItoReddishPurpleShade'}]
    );

# Sets of sequences of color pairs suitable for plotting multiple datasets.
our %colorPairSequences = (
    sequence1 => [
	 "peachPuff"  ,"slateGray"     ,"cornflowerBlue","lightSkyBlue","mediumSeaGreen"
	,"yellowGreen","lightGoldenrod","indianRed"     ,"orange"      ,"plum"
        ,"thistle"
    ],
    sequence2 => [
	 "redYellow"  ,"hotPink", "indianRed"
    ],
    slideSequence => [
	 "yellowGreen", "thistle", "orange", "lightGoldenrod"
    ],
    contrast => [
	"cornflowerBlue", "yellowGreen", "indianRed", "peachPuff", "midnightBlue", "yellowGreen"
    ]
    );

# Dash pattern sequences.
our @dashPatterns;
push(@dashPatterns,pdl [ 20.0,  0.0 ]);
push(@dashPatterns,pdl [ 20.0, 10.0 ]);
push(@dashPatterns,pdl [ 10.0,  5.0 ]);
push(@dashPatterns,pdl [ 10.0,  5.0, 5.0, 5.0 ]);
push(@dashPatterns,pdl [ 20.0,  5.0, 2.0, 5.0 ]);
push(@dashPatterns,pdl [ 20.0,  5.0, 2.0, 5.0, 2.0, 5.0 ]);

# Color gradients.
our %colorGradients =
    (
     rainbow =>
     {
	 fraction   => [   0.000,   1.000 ],
	 hue        => [   0.000, 240.000 ],
	 saturation => [   1.000,   1.000 ],
	 value      => [   1.000,   1.000 ]
     },
     redGreen =>
     {
	 fraction   => [   0.000,   1.000 ],
	 hue        => [   0.000, 120.000 ],
	 saturation => [   1.000,   1.000 ],
	 value      => [   1.000,   1.000 ]
     },
     spectrum =>
     {
	 fraction   => [   0.000,   0.500,   1.000 ],
	 hue        => [ 360.000, 180.000,   0.000 ],
	 saturation => [   1.000,   1.000,   1.000 ],
	 value      => [   1.000,   1.000,   1.000 ]
     },
     dark2 =>
     {
	 fraction   => [   0.000,   0.143,   0.286,   0.429,   0.571,   0.714,   0.857,   1.000 ],
	 hue        => [ 162.000,  25.000, 244.000, 330.000,  88.000,  44.000,  38.000,   0.000 ],
	 saturation => [   0.829,   0.991,   0.374,   0.823,   0.819,   0.991,   0.825,   0.000 ],
	 value      => [   0.620,   0.851,   0.702,   0.906,   0.651,   0.902,   0.651,   0.400 ]
     },
     accent =>
     {
	 fraction   => [   0.000,   0.143,   0.286,   0.429,   0.571,   0.714,   0.857,   1.000 ],
	 hue        => [ 120.000, 265.000,  29.000,  60.000, 214.000, 329.000,  24.000,   0.000 ],
	 saturation => [   0.368,   0.179,   0.470,   0.400,   0.682,   0.992,   0.880,   0.000 ],
	 value      => [   0.788,   0.831,   0.992,   1.000,   0.690,   0.941,   0.749,   0.400 ]
     },
     eightSet1 =>
     {
	 fraction   => [   0.000,   0.143,   0.286,   0.429,   0.571,   0.714,   0.857,   1.000 ],
	 hue        => [   0.000, 206.000, 118.000, 292.000,  29.000,  60.000,  21.000, 329.000 ],
	 saturation => [   0.886,   0.701,   0.577,   0.521,   1.000,   0.800,   0.759,   0.478 ],
	 value      => [   0.894,   0.722,   0.686,   0.639,   1.000,   1.000,   0.651,   0.969 ]
     }
    );

sub gradientColor {
    my $fraction  = shift();
    my $gradient  = shift();
    my @hsv;
    ($hsv[0]) = interpolate($fraction,$gradient->{'fraction'},$gradient->{'hue'       });
    ($hsv[1]) = interpolate($fraction,$gradient->{'fraction'},$gradient->{'saturation'});
    ($hsv[2]) = interpolate($fraction,$gradient->{'fraction'},$gradient->{'value'     });
    my $color = Imager::Color->new(hsv => \@hsv);
    return sprintf("#%02lx%02lx%02lx%02lx", $color->rgba() );
}

sub Color_Gradient {
    my $f         =   shift() ;
    my @start     = @{shift()};
    my @end       = @{shift()};
    my @thisHSV   = 
	(
	 $start[0]+($end[0]-$start[0])*$f,
	 $start[1]+($end[1]-$start[1])*$f,
	 $start[2]+($end[2]-$start[2])*$f
	);
    my $hsv = Imager::Color->new(hsv => \@thisHSV);
    return sprintf("#%02lx%02lx%02lx", $hsv->rgba() );
}

sub Morgenstemning {
    # Return a color from the "Morgenstemning" color-blind-friendly color table. Our table uses 256 vaues (calculated using this
    # tool: https://rdrr.io/cran/morgenstemning/src/R/ametrine.R). The argument to this function is just the index into this
    # table, running from 0-255.
    my $i = shift();
    my @table =
	(
	 "#1E3C96", "#203C96", "#223D96", "#233D96", "#253D96", "#273E96", "#293E96",
	 "#2A3E96", "#2C3F96", "#2E3F97", "#304097", "#314097", "#334097", "#354197",
	 "#374197", "#384197", "#3A4297", "#3C4297", "#3E4297", "#404397", "#414397",
	 "#434397", "#454497", "#474497", "#484497", "#4A4597", "#4C4598", "#4E4698",
	 "#4F4698", "#514698", "#534798", "#554798", "#564798", "#584898", "#5A4898",
	 "#5C4898", "#5E4998", "#5F4998", "#614998", "#634A98", "#654A98", "#664A98",
	 "#684B98", "#6A4B99", "#6C4C99", "#6D4C99", "#6F4C99", "#714D99", "#734D99",
	 "#744D99", "#764E99", "#784E99", "#7A4E99", "#7C4F99", "#7D4F99", "#7F4F99",
	 "#815099", "#835099", "#845099", "#865199", "#88519A", "#8A529A", "#8B529A",
	 "#8D529A", "#8F539A", "#91539A", "#92539A", "#94549A", "#96549A", "#98549A",
	 "#9A559A", "#9B559A", "#9D559A", "#9F569A", "#A1569A", "#A2569A", "#A4579A",
	 "#A6579B", "#A8589B", "#A9589B", "#AB589B", "#AD599B", "#AF599B", "#B0599B",
	 "#B25A9B", "#B45A9B", "#B55A9A", "#B55A99", "#B65A98", "#B65A97", "#B75A96",
	 "#B85A95", "#B85A94", "#B95A93", "#B95991", "#BA5990", "#BA598F", "#BB598E",
	 "#BC598D", "#BC598C", "#BD598B", "#BD598A", "#BE5989", "#BF5988", "#BF5987",
	 "#C05986", "#C05985", "#C15984", "#C25983", "#C25982", "#C35981", "#C3587F",
	 "#C4587E", "#C4587D", "#C5587C", "#C6587B", "#C6587A", "#C75879", "#C75878",
	 "#C85877", "#C95876", "#C95875", "#CA5874", "#CA5873", "#CB5872", "#CC5871",
	 "#CC5870", "#CD586F", "#CD576D", "#CE576C", "#CE576B", "#CF576A", "#D05769",
	 "#D05768", "#D15767", "#D15766", "#D25765", "#D35764", "#D35763", "#D45762",
	 "#D45761", "#D55760", "#D6575F", "#D6575E", "#D7575D", "#D7565B", "#D8565A",
	 "#D85659", "#D95658", "#DA5657", "#DA5656", "#DB5655", "#DB5654", "#DC5653",
	 "#DD5652", "#DD5651", "#DE5650", "#DE564F", "#DF564E", "#E0564D", "#E0564C",
	 "#E1564B", "#E15549", "#E25548", "#E25547", "#E35546", "#E45545", "#E45544",
	 "#E55543", "#E55542", "#E65541", "#E65740", "#E6583F", "#E65A3F", "#E65B3E",
	 "#E55D3D", "#E55F3C", "#E5603C", "#E5623B", "#E5633A", "#E56539", "#E56639",
	 "#E56838", "#E46A37", "#E46B36", "#E46D36", "#E46E35", "#E47034", "#E47233",
	 "#E47332", "#E47532", "#E47631", "#E37830", "#E37A2F", "#E37B2F", "#E37D2E",
	 "#E37E2D", "#E3802C", "#E3812C", "#E3832B", "#E2852A", "#E28629", "#E28829",
	 "#E28928", "#E28B27", "#E28D26", "#E28E25", "#E29025", "#E29124", "#E19323",
	 "#E19522", "#E19622", "#E19821", "#E19920", "#E19B1F", "#E19C1F", "#E19E1E",
	 "#E0A01D", "#E0A11C", "#E0A31C", "#E0A41B", "#E0A61A", "#E0A819", "#E0A918",
	 "#E0AB18", "#E0AC17", "#DFAE16", "#DFB015", "#DFB115", "#DFB314", "#DFB413",
	 "#DFB612", "#DFB712", "#DFB911", "#DEBB10", "#DEBC0F", "#DEBE0F", "#DEBF0E",
	 "#DEC10D", "#DEC30C", "#DEC40B", "#DEC60B", "#DEC70A", "#DDC909", "#DDCB08",
	 "#DDCC08", "#DDCE07", "#DDCF06", "#DDD105", "#DDD205", "#DDD404", "#DCD603",
	 "#DCD702", "#DCD902", "#DCDA01", "#DCDC00"
	);
    return $table[$i];
}

# Subroutine to generate plotting commands for a specified dataset and accumulate them to a buffer for later writing to GnuPlot.
sub Prepare_Dataset {
    # Extract the plot structure and datasets to plot.
    my $plot = shift;
    my $x    = shift;
    my $y    = shift;
    # Extract any remaining options.
    my (%options) = @_ if ( $#_ >= 1 );
    
    # Determine the GnuPlot version.
    my ($versionMajor,$versionMinor,$versionPatchLevel);
    my $gnuplotVersion = `gnuplot -V`;
    chomp($gnuplotVersion);
    if ( $gnuplotVersion =~ m/gnuplot (\d+)\.(\d+) patchlevel (\d+)/ ) {
	$versionMajor      = $1;
	$versionMinor      = $2;
	$versionPatchLevel = $3;
    } else {
	$versionMajor      = -1;
	$versionMinor      = -1;
	$versionPatchLevel = -1;
    }

    # Determine the plot style, assuming points by default.
    my $style = "point";
    $style = $options{'style'} if ( exists($options{'style'}) );

    # Create attributes for line weight, assuming no specification if weight option is not present.
    my %lineWeight;
    $lineWeight{'lower'} = "";
    $lineWeight{'upper'} = "";
    my %lineWeightValue;
    if ( exists($options{'weight'}) ) {
	$lineWeightValue{'lower'} =        ${$options{'weight'}}[0];
	$lineWeightValue{'upper'} =        ${$options{'weight'}}[1];
	$lineWeight     {'lower'} = " lw ".${$options{'weight'}}[0];
	$lineWeight     {'upper'} = " lw ".${$options{'weight'}}[1];
    }
    
    # Create attribute for line type, assuming no specification if type option is not present.
    my %lineType;
    my $lineTypeCommand = $versionMajor >= 5 ? "dt" : "lt";
    if ( exists($options{'linePattern'}) ) {
	if ( UNIVERSAL::isa($options{'linePattern'},'PDL') ) {
	    my $dashes; 
	    $dashes->{$_} = $options{'linePattern'}*($lineWeightValue{'lower'}/$lineWeightValue{$_})**0.37
	        foreach ( "lower", "upper" );
	    $lineType{$_} = " ".$lineTypeCommand." (".join(",",$dashes->{$_}->list()).")"
	        foreach ( "lower", "upper" );
	} else {
	    $lineType{$_} = " ".$lineTypeCommand." ".$options{'linePattern'}
	        foreach ( "lower", "upper" );
	}
    } else {
	$lineType{$_} = " ".$lineTypeCommand." 1"
	    foreach ( "lower", "upper" );
    }

    # Create attribute for line color, assuming no specification if color option is not present.
    my %lineColor;
    $lineColor{'lower'} = "";
    $lineColor{'upper'} = "";
    if ( exists($options{'color'}) ) {
	if ( ${$options{'color'}}[0] =~ m/palette/ ) {
	    $lineColor{'lower'} = " lc ".${$options{'color'}}[0];
	    $lineColor{'upper'} = " lc ".${$options{'color'}}[1];
	} else {
	    $lineColor{'lower'} = " lc rgbcolor \"".${$options{'color'}}[0]."\"";
	    $lineColor{'upper'} = " lc rgbcolor \"".${$options{'color'}}[1]."\"";
	}
    }

    # Create attribute for point type, assuming no specification if symbol option is not present.
    my %pointType;
    $pointType{'lower'} = "";
    $pointType{'upper'} = "";
    $pointType{'lower'} = " pt ".${$options{'symbol'}}[0] if ( exists($options{'symbol'}) );
    $pointType{'upper'} = " pt ".${$options{'symbol'}}[1] if ( exists($options{'symbol'}) );

    # Create attribute for point size, assuming no specification if pointSize option is not present.
    my %pointSize;
    $pointSize{'lower'} = "";
    $pointSize{'upper'} = "";
    $pointSize{'lower'} = " ps ".$options{'pointSize'} if ( exists($options{'pointSize'}) );
    $pointSize{'upper'} = " ps ".$options{'pointSize'} if ( exists($options{'pointSize'}) );

    # Create a title attribute, defaulting to no title if none is specified.
    my $title = " notitle";
    $title = " title \"".$options{'title'}."\"" if ( exists($options{'title'}) );

    # Define the dummy point and end points.
    my $dummyPoint;
    if (
	$versionMajor > 4
	||
	( $versionMajor == 4 &&
	  ( $versionMinor > 4 
	    ||
	    ( $versionMinor == 4 && $versionPatchLevel >= 2 )
	  )
	)
       )
    {
	$dummyPoint = "inf inf\n";
    } else {
	$dummyPoint = "inf inf\n";
    }
    my $endPoint   = "e\n";

    # We have three plotting phases:
    #  keyLower - the lower layer of the key.
    #  keyUpper - the upper layer of the key.
    #  data     - actually plots the data.
    my %phaseRules = (
	keyLower => {
	    level => "lower"
	},
	keyUpper => {
	    level => "upper"
	},
	data => {
	}
	);

    # Loop over phases.
    foreach my $phase ( keys(%phaseRules) ) {
	# Initialize phase prefix if necessary.
	${$plot}->{$phase}->{'prefix'} = "plot" unless ( exists(${$plot}->{$phase}->{'prefix'}) );
	# Set plotting axes.
	my $xAxis = exists($options{'xaxis'}) ? $options{'xaxis'} : 1;
	my $yAxis = exists($options{'yaxis'}) ? $options{'yaxis'} : 1;
	# Branch depending on style of dataset, points, boxes or lines.
	if ( $style eq "line" ) {
	    # Check if we are asked to plot just a single level.
	    if ( exists($phaseRules{$phase}->{'level'}) ) {
		# Plot just a single level, no real data.
		${$plot}->{$phase}->{'command'} .= ${$plot}->{$phase}->{'prefix'}." '-' with lines axes x".$xAxis."y".$yAxis
	        .$lineType  {$phaseRules{$phase}->{'level'}}
		.$lineColor {$phaseRules{$phase}->{'level'}}
		.$lineWeight{$phaseRules{$phase}->{'level'}}
		.$title;
		${$plot}->{$phase}->{'data'   } .= $dummyPoint;
		${$plot}->{$phase}->{'data'   } .= $endPoint;
		${$plot}->{$phase}->{'prefix'} = ",";
	    } else {
		# Plot the actual data.
		foreach my $level ( 'lower', 'upper' ) {
		    # If transparency is requested, adjust line color.
		    my $currentLineColor = $lineColor{$level};
		    if ( exists($options{'transparency'}) && $currentLineColor =~ m/rgbcolor "\#(.*)"/ ) {
			$currentLineColor = " lc rgbcolor \"#".sprintf("%2X",int(255*$options{'transparency'})).$1."\"";
		    }
		    ${$plot}->{$phase}->{'data'} .= "plot '-' with lines".$lineType{$level}.$currentLineColor.$lineWeight{$level}." notitle axes x".$xAxis."y".$yAxis."\n";
		    for(my $iPoint=0;$iPoint<nelem($x);++$iPoint) {
			${$plot}->{$phase}->{'data'} .= $x->index($iPoint)." ".$y->index($iPoint)."\n";
		    }
		    ${$plot}->{$phase}->{'data'} .= $endPoint;
		}
	    }
	} elsif ( $style eq "filledCurve" ) {
	    # Draw a filled curve - using the "y2" option as the second set of y points.
	    $options{'filledCurve'} = "closed"
		unless ( exists($options{'filledCurve'}) );
	    if ( $options{'filledCurve'} eq "closed" ) {
		die ("GnuPlot::PrettyPlots - filledCurve requires a 'y2' vector")
		    unless ( exists($options{'y2'}) );
	    }
	    my $currentLineColor = $lineColor{'upper'};
	    if ( exists($options{'transparency'}) && $currentLineColor =~ m/rgbcolor "\#(.*)"/ ) {
		$currentLineColor = " lc rgbcolor \"#".sprintf("%2X",int(255*$options{'transparency'})).$1."\"";
	    }
	    if ( exists($phaseRules{$phase}->{'level'}) ) {
		# Plot just a single level, no real data.
		my $level = "upper";
		${$plot}->{$phase}->{'command'} .= ${$plot}->{$phase}->{'prefix'}." '-' with filledcurve "
		    .$options{'filledCurve'}
		.$lineType  {$level}
		.$currentLineColor
		.$lineWeight{$level}
		." fill noborder";
		${$plot}->{$phase}->{'command'} .= $title;
		${$plot}->{$phase}->{'data'   } .= $dummyPoint;
		${$plot}->{$phase}->{'data'   } .= $endPoint;
		${$plot}->{$phase}->{'prefix'} = ",";
	    } else {
		my $level = "upper";
		${$plot}->{$phase}->{'data'} .= "set style fill solid 1.0 noborder\n";
		${$plot}->{$phase}->{'data'} .= "plot '-' with filledcurve ".$options{'filledCurve'}."".$lineType{$level}.$currentLineColor.$lineWeight{$level}." fill border notitle";
		${$plot}->{$phase}->{'data'} .= "\n";
		${$plot}->{$phase}->{'data'} .= $x->index(0)." ".$y->index(0)." ".$y->index(0)."\n"
		    if ( $options{'filledCurve'} eq "closed" );
		for(my $iPoint=0;$iPoint<nelem($x);++$iPoint) {
		    ${$plot}->{$phase}->{'data'} .= $x->index($iPoint)." ".$y->index($iPoint);
		    ${$plot}->{$phase}->{'data'} .= " ".$options{'y2'}->index($iPoint)
			if ( $options{'filledCurve'} eq "closed" );
		    ${$plot}->{$phase}->{'data'} .= "\n";
		}
		${$plot}->{$phase}->{'data'} .= $x->index(nelem($x)-1)." ".$y->index(nelem($x)-1)." ".$y->index(nelem($x)-1)."\n"
		    if ( $options{'filledCurve'} eq "closed" );
		${$plot}->{$phase}->{'data'} .= $endPoint;
	    }
	} elsif ( $style eq "boxes") {
	    # Check if we are asked to plot just a single level.
	    if ( exists($phaseRules{$phase}->{'level'}) ) {
		# Plot just a single level, no real data.		
		${$plot}->{$phase}->{'command'} .= ${$plot}->{$phase}->{'prefix'}." '-' with boxes fs solid"
		    .$lineType  {$phaseRules{$phase}->{'level'}}
		.$lineColor{$phaseRules{$phase}->{'level'}}
		.$lineWeight{$phaseRules{$phase}->{'level'}}
		.$title;
		${$plot}->{$phase}->{'data'   } .= $dummyPoint;
		${$plot}->{$phase}->{'data'   } .= $endPoint;
		${$plot}->{$phase}->{'prefix'} = ",";
	    } else {
		# Plot the actual data.
		foreach my $level ( 'lower', 'upper' ) {
		    ${$plot}->{$phase}->{'data'} .= "set boxwidth 0.9 relative\n";
		    ${$plot}->{$phase}->{'data'} .= "set style fill solid 1.0\n";
		    # If the "shading" option is specified we make
		    # the bar color vary with height and add some
		    # highlighting toward the center of the bar.
		    if ( exists($options{'shading'}) && $options{'shading'} == 1 ) {
			# Number of steps to take in shading.
			my $stepCount = 64;
			# Maximum y-value of bars.
			my $maximumY  = maximum($y);
			$maximumY .= 1.0 
			    if ( $maximumY > 1.0 );
			# Extract the RGB components of the start and end colors.
			my $colorStart = ${$options{'color'}}[0];
			my $redStart   = hex(substr($colorStart,1,2));
			my $greenStart = hex(substr($colorStart,3,2));
			my $blueStart  = hex(substr($colorStart,5,2));
			my $colorEnd   = ${$options{'color'}}[1];
			my $redEnd     = hex(substr($colorEnd  ,1,2));
			my $greenEnd   = hex(substr($colorEnd  ,3,2));
			my $blueEnd    = hex(substr($colorEnd  ,5,2));
			# Loop through steps.
			for(my $i=$stepCount;$i>=1;--$i) {
			    # Compute the fractional step.
			    my $fraction = $i/$stepCount;
			    # Specify number of box "radii" for highlighting.
			    my $rCount   = 32;
			    # Loop through radii steps.
			    for(my $j=0;$j<$rCount;++$j) {
				# Determine the width of the box to draw for this step.
				my $boxWidth = 0.9*cos($j/$rCount*3.1415927/2.0);
				${$plot}->{$phase}->{'data'} .= "set boxwidth ".$boxWidth." relative\n";
				# Compute the fraction of gray to mix in to the color, then mix it.
				my $grayFraction = 0.7*$j/$rCount;
				my $red      = int(($redStart  *(1.0-$fraction)+$redEnd  *$fraction)*(1.0-$grayFraction)+255.0*$grayFraction); 
				my $green    = int(($greenStart*(1.0-$fraction)+$greenEnd*$fraction)*(1.0-$grayFraction)+255.0*$grayFraction); 
				my $blue     = int(($blueStart *(1.0-$fraction)+$blueEnd *$fraction)*(1.0-$grayFraction)+255.0*$grayFraction);  
				# Set the color for the boxes.
				my $color = " lc rgbcolor \"#".sprintf("%2.2X%2.2X%2.2X",$red,$green,$blue)."\"";
				# Plot the boxes.
				${$plot}->{$phase}->{'data'} .= "plot '-' with boxes".$lineType{$level}.$color.$lineWeight{$level}." notitle\n";
				for(my $iPoint=0;$iPoint<nelem($x);++$iPoint) {
				    # Maximum height allowed on this step.
				    my $yHeightMaximum = $maximumY*$fraction;
				    # Compute the height of the bar, with a little rounding.
				    my $yHeight = $y->index($iPoint)+(-0.02+0.02*sin($j/$rCount*3.1415927/2.0))*$maximumY;
				    # Limit the height of the bar to be within range.
				    $yHeight = 0.0
					if ( $yHeight < 0.0 );
				    $yHeight = $yHeightMaximum
					if ( $yHeight > $yHeightMaximum );
				    # Plot the bar.
				    ${$plot}->{$phase}->{'data'} .= $x->index($iPoint)." ".$yHeight."\n";
				}
				${$plot}->{$phase}->{'data'} .= $endPoint;
			    }
			}
		    } else {
			# If transparency is requested, adjust point color.
			my $currentLineColor = $lineColor{$level};
			if ( exists($options{'transparency'}) && $currentLineColor =~ m/rgbcolor "\#(.*)"/ ) {
			    $currentLineColor = " lc rgbcolor \"#".sprintf("%2X",int(255*$options{'transparency'})).$1."\"";
			}
			${$plot}->{$phase}->{'data'} .= "plot '-' with boxes".$lineType{$level}.$currentLineColor.$lineWeight{$level}." notitle\n";
			for(my $iPoint=0;$iPoint<nelem($x);++$iPoint) {
			    ${$plot}->{$phase}->{'data'} .= $x->index($iPoint)." ".$y->index($iPoint)."\n";
			}
			${$plot}->{$phase}->{'data'} .= $endPoint;
		    }
		}
	    }
	} elsif ( $style eq "point" ) {
	    # Check if we are asked to plot just a single level.
	    if ( exists($phaseRules{$phase}->{'level'}) ) {
		# If transparency is requested, adjust point color.
		my $currentLineColor = $lineColor{$phaseRules{$phase}->{'level'}};
		if ( exists($options{'transparency'}) && $currentLineColor =~ m/rgbcolor "\#(.*)"/ ) {
		    $currentLineColor = " lc rgbcolor \"#".sprintf("%2X",int(255*$options{'transparency'})).$1."\"";
		}
		# Plot just a single level, no real data.
		${$plot}->{$phase}->{'command'} .= ${$plot}->{$phase}->{'prefix'}." '-'"
		    .$pointType{$phaseRules{$phase}->{'level'}}.$pointSize{$phaseRules{$phase}->{'level'}}.$currentLineColor.$lineWeight{$phaseRules{$phase}->{'level'}}.$title;
		${$plot}->{$phase}->{'data'   } .= $dummyPoint;
		${$plot}->{$phase}->{'data'   } .= $endPoint;
		${$plot}->{$phase}->{'prefix'} = ",";
	    } else {
		# Plot the actual data.
		for(my $iPoint=0;$iPoint<nelem($x);++$iPoint) {
		    # Determine if vertical errors are present.
		    my $showVerticalErrors = 0;
		    $showVerticalErrors = 1 if (
			( exists($options{'errorDown' }) && $options{'errorDown' }->index($iPoint) > 0.0 )
			||
			( exists($options{'errorUp'   }) && $options{'errorUp'   }->index($iPoint) > 0.0 )
			);
		    my $showHorizontalErrors = 0;
		    $showHorizontalErrors = 1 if (
			( exists($options{'errorLeft' }) && $options{'errorLeft' }->index($iPoint) > 0.0 )
			||
			( exists($options{'errorRight'}) && $options{'errorRight'}->index($iPoint) > 0.0 )
			);
		    my $errorCommand;
		    if ( $showVerticalErrors == 1 ) {
			if ( $showHorizontalErrors == 1 ) {
			    $errorCommand = " with xyerrorbars";
			} else {
			    $errorCommand = " with errorbars";
			}
		    } else {
			if ( $showHorizontalErrors == 1 ) {
			    $errorCommand = " with xerrorbars";
			} else {
			    $errorCommand = "";
			}
		    }
		    
		    # Add error bar data.
		    my $errors = "";
		    if ( $showHorizontalErrors == 1 ) {
			if ( exists($options{'errorLeft'}) && $options{'errorLeft'}->index($iPoint) > 0.0 ) {
			    # Add a standard leftware error bar.
			    my $errorPosition = $x->index($iPoint)-$options{'errorLeft'}->index($iPoint);
			    $errors .= " ".$errorPosition;
			} else  {
			    # No leftward error bar.
			    $errors .= " ".$x->index($iPoint);
			}
			if ( exists($options{'errorRight'}) && $options{'errorRight'}->index($iPoint) > 0.0 ) {
			    # Add a standard rightward error bar.
			    my $errorPosition = $x->index($iPoint)+$options{'errorRight'}->index($iPoint);
			    $errors .= " ".$errorPosition;
			} else  {
			    # No rightward error bar.
			    $errors .= " ".$x->index($iPoint);
			}
		    }
		    if ( $showVerticalErrors == 1 ) {
			if ( exists($options{'errorDown'}) && $options{'errorDown'}->index($iPoint) > 0.0 ) {
			    # Add a standard downward error bar.
			    my $errorPosition = $y->index($iPoint)-$options{'errorDown'}->index($iPoint);
			    $errors .= " ".$errorPosition;
			} else  {
			    # No downward error bar.
			    $errors .= " ".$y->index($iPoint);
			}
			if ( exists($options{'errorUp'}) && $options{'errorUp'}->index($iPoint) > 0.0 ) {
			    # Add a standard upward error bar.
			    my $errorPosition = $y->index($iPoint)+$options{'errorUp'}->index($iPoint);
			    $errors .= " ".$errorPosition;
			} else  {
			    # No upward error bar.
			    $errors .= " ".$y->index($iPoint);
			}
		    }
		    
		    # Add arrows.
		    my $arrows      = "";
		    my $clearArrows = "";
		    # If transparency is requested, adjust line color.
		    my $currentLineColor = $lineColor{'lower'};
		    if ( exists($options{'transparency'}) && $currentLineColor =~ m/rgbcolor "\#(.*)"/ ) {
			$currentLineColor = " lc rgbcolor \"#".sprintf("%2X",int(255*$options{'transparency'})).$1."\"";
		    }
		    if ( exists($options{'errorLeft'}) && $options{'errorLeft'}->index($iPoint) < 0.0 ) {
			my $tipX = $x->index($iPoint)+$options{'errorLeft'}->index($iPoint);
			$arrows .= "set arrow from first ".$x->index($iPoint).",".$y->index($iPoint)." to first "
			    .$tipX.",".$y->index($iPoint)." filled back ".$currentLineColor.$lineWeight{'upper'}."\n";
			$clearArrows = "unset arrow\n";
		    }
		    if ( exists($options{'errorRight'}) && $options{'errorRight'}->index($iPoint) < 0.0 ) {
			my $tipX = $x->index($iPoint)-$options{'errorRight'}->index($iPoint);
			$arrows .= "set arrow from first ".$x->index($iPoint).",".$y->index($iPoint)." to first "
			    .$tipX.",".$y->index($iPoint)." filled back ".$currentLineColor.$lineWeight{'upper'}."\n";
			$clearArrows = "unset arrow\n";
		    }
		    if ( exists($options{'errorDown'}) && $options{'errorDown'}->index($iPoint) < 0.0 ) {
			my $tipY = $y->index($iPoint)+$options{'errorDown'}->index($iPoint);
			$arrows .= "set arrow from first ".$x->index($iPoint).",".$y->index($iPoint)." to first "
			    .$x->index($iPoint).",".$tipY." filled back ".$currentLineColor.$lineWeight{'upper'}."\n";
			$clearArrows = "unset arrow\n";
		    }
		    if ( exists($options{'errorUp'}) && $options{'errorUp'}->index($iPoint) < 0.0 ) {
			my $tipY = $y->index($iPoint)-$options{'errorUp'}->index($iPoint);
			$arrows .= "set arrow from first ".$x->index($iPoint).",".$y->index($iPoint)." to first "
			    .$x->index($iPoint).",".$tipY." filled back ".$currentLineColor.$lineWeight{'upper'}."\n";
			$clearArrows = "unset arrow\n";
		    }
		    
		    # Output the point.
		    foreach my $level ( 'lower', 'upper' ) {
			${$plot}->{$phase}->{'data'} .= $arrows if ( $level eq "lower" );
			# If transparency is requested, adjust point color.
			my $currentLineColor = $lineColor{$level};
			if ( exists($options{'transparency'}) && $currentLineColor =~ m/rgbcolor "\#(.*)"/ ) {
			    $currentLineColor = " lc rgbcolor \"#".sprintf("%2X",int(255*$options{'transparency'})).$1."\"";
			}
			${$plot}->{$phase}->{'data'} .= "plot '-'".$errorCommand.$pointType{$level}.$pointSize{$level}.$currentLineColor.$lineWeight{$level}." notitle\n";
			${$plot}->{$phase}->{'data'} .= $x->index($iPoint)." ".$y->index($iPoint).$errors."\n";
			${$plot}->{$phase}->{'data'} .= $endPoint;
			${$plot}->{$phase}->{'data'} .= $clearArrows if ( $level eq "lower" );
			# Clear any error bars after lower layer plot.
			$errorCommand = "";
			$errors       = "";	
		    }
		}
	    }
	}
    }
}

# Subroutine to output plotting commands to GnuPlot for a set of accumulated datasets.
sub Plot_Datasets {
    my $gnuPlot = shift;
    my $plot    = shift;
    # Extract any remaining options.
    my (%options) = @_ if ( $#_ >= 1 );
    print $gnuPlot "set multiplot\n"
	unless ( exists($options{'multiPlot'}) && $options{'multiPlot'} == 1 );
    foreach my $phase ( 'keyLower', 'keyUpper' ) {
	print $gnuPlot ${$plot}->{$phase}->{'command'}."\n";
	print $gnuPlot ${$plot}->{$phase}->{'data'   };
	# Switch off borders and tics after the first plot.	
	print $gnuPlot "unset label; unset border; unset xtics; unset ytics; unset x2tics; unset y2tics; set xlabel ''; set ylabel ''; set x2label ''; set y2label ''\n" if ( $phase eq "keyLower" );
    }
    print $gnuPlot ${$plot}->{'data'}->{'data'};
    print $gnuPlot "unset multiplot\n"
	unless ( exists($options{'multiPlot'}) && $options{'multiPlot'} == 1 );
    undef(${$plot});
}
