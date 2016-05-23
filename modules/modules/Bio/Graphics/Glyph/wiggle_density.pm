package Bio::Graphics::Glyph::wiggle_density;
use strict;
use base qw(Bio::Graphics::Glyph::wiggle_data
            Bio::Graphics::Glyph::box 
            Bio::Graphics::Glyph::smoothing
            Bio::Graphics::Glyph::xyplot
 );

sub my_description {
    return <<END;
This glyph draws quantitative data as a heatmap. Higher-intensity parts of the feature
will be drawn with more saturation.

For this glyph to work, the feature must define one of the following tags:

  wigfile -- a path to a Bio::Graphics::Wiggle file

  wigdata -- Wiggle data in the Bio::Graphics::Wiggle "wif" format, as created
             by \$wig->export_to_wif().

  coverage-- a simple comma-delimited string containing the quantitative values,
             assumed to be one value per pixel.

END
}

sub my_options {
    {
	basedir => [
	    'string',
	    undef,
	    'If a relative path is used for "wigfile", then this option provides',
	    'the base directory on which to resolve the path.'
	    ],
        z_score_bounds => [
	    'integer',
	    4,
	    'When using z_score autoscaling, this option controls how many standard deviations',
	    'above and below the mean to show.'
	],
	autoscale => [
	    ['local','chromosome','global','z_score','clipped_global'],
            'clipped_global',
	    'If set to "global" , then the minimum and maximum values of the XY plot',
	    'will be taken from the wiggle file as a whole. If set to "chromosome", then',
            'scaling will be to minimum and maximum on the current chromosome.',
	    '"clipped_global" is similar to "global", but clips the top and bottom values',
	    'to the multiples of standard deviations indicated by "z_score_bounds"',
	    'If set to "z_score", then the whole plot will be rescaled to z-scores in which',
	    'the "0" value corresponds to the mean across the genome, and the units correspond',
	    'to standard deviations above and below the mean. The number of SDs to show are',
	    'controlled by the "z_score_bound" option.',
	    'Otherwise, the plot will be',
	    'scaled to the minimum and maximum values of the region currently on display.',
	    'min_score and max_score override autoscaling if one or both are defined'
        ],
	 graph_type => [
	     undef,
	     undef,
	     'Unused option',
	     ],
    };
}

sub pad_top { 
    my $self = shift;
    my $overlap = $self->bump eq 'overlap';
    return $overlap ?$self->Bio::Graphics::Glyph::xyplot::pad_top(@_)
	            :$self->SUPER::pad_top(@_);
}

sub draw {
  my $self = shift;
  my ($gd,$dx,$dy) = @_;

  my $retval    = $self->SUPER::draw(@_);
  if ($retval) {
    $self->draw_label(@_)       if $self->option('label');
    $self->draw_description(@_) if $self->option('description');
    $self->panel->endGroup($gd);
    return $retval;
  } else {
      # This draws a filled box for null value data
      #return $self->Bio::Graphics::Glyph::box::draw(@_);
  }
}

sub draw_coverage {
    my $self    = shift;
    my $feature = shift;
    my $array   = shift;


    if (! $array || ref($array) ne 'ARRAY'){
     unshift(@_,$array);
     my @arr = (eval{$feature->get_tag_values('coverage')});
     $array  = $arr[0];
    } else {
     $array   = [split ',',$array] unless ref $array;
    }
    return unless @$array;

    my ($gd,$left,$top) = @_;

    my ($start,$end)    = $self->effective_bounds($feature);
    my $length          = $end - $start + 1;
    my $bases_per_bin   = ($end-$start)/@$array;
    my @parts;
    my $samples = $length < $self->panel->width ? $length
                                                : $self->panel->width;
    my $samples_per_base = $samples/$length;

    for (my $i=0;$i<$samples;$i++) {
        my $offset = $i/$samples_per_base;
        my $v      = $array->[$offset/$bases_per_bin];
        push @parts,$v;
    }

    my ($x1,$y1,$x2,$y2) = $self->bounds($left,$top);
    $self->draw_segment($gd,
             	        $start,$end,
                        \@parts,
                        $start,$end,
                        1,1,
                        $x1,$y1,$x2,$y2);
}

sub draw_segment {
  my $self = shift;
  my ($gd,
      $start,$end,
      $seg_data,
      $seg_start,$seg_end,
      $step,$span,
      $x1,$y1,$x2,$y2) = @_;

  # clip, because wig files do no clipping
  $seg_start = $start      if $seg_start < $start;
  $seg_end   = $end        if $seg_end   > $end;

  # figure out where we're going to start
  my $scale           = $self->scale;  # pixels per base pair
  my $pixels_per_span = $scale * $span + 1;
  my $pixels_per_step = 1;
  my $length          = $end-$start+1;

  # if the feature starts before the data starts, then we need to draw
  # a line indicating missing data (this only happens if something went
  # wrong upstream)
  if ($seg_start > $start) {
    my $terminus = $self->map_pt($seg_start);
    $start = $seg_start;
    $x1    = $terminus;
  }
  # if the data ends before the feature ends, then we need to draw
  # a line indicating missing data (this only happens if something went
  # wrong upstream)
  if ($seg_end < $end) {
    my $terminus = $self->map_pt($seg_end);
    $end = $seg_end;
    $x2    = $terminus;
  }

  return unless $start < $end;

  # get data values across the area
  my $samples = $length < $self->panel->width ? $length
                                              : $self->panel->width;
  my $data    = ref $seg_data eq 'ARRAY' ? $seg_data
                                         : $seg_data->values($start,$end,$samples);


  # scale the glyph if the data end before the panel does
  my $data_width = $end - $start;
  my $data_width_ratio;
  if ($data_width < $self->panel->length) {
    $data_width_ratio = $data_width/$self->panel->length;
  }
  else {
    $data_width_ratio = 1;
  }
 return unless $data && ref $data && @$data > 0;

  my $min_value = $self->min_score;
  my $max_value = $self->max_score;

  my ($min,$max,$mean,$stdev) = $self->minmax($data);
  unless (defined $min_value && defined $max_value) {
      $min_value ||= $min;
      $max_value ||= $max;
  }

  my $rescale  = $self->option('autoscale') eq 'z_score';
  my ($scaled_min,$scaled_max);
  if ($rescale) {
      my $bound  = $self->z_score_bound;
      $scaled_min = -$bound;
      $scaled_max = +$bound;
  } else {
      ($scaled_min,$scaled_max) = ($min_value,$max_value);
  }

  my $t = 0; for (@$data) {$t+=$_}

  # allocate colors
  # There are two ways to do this. One is a scale from min to max. The other is a
  # bipartite scale using one color range from zero to min, and another color range
  # from 0 to max. The latter behavior is triggered when the config file contains
  # entries for "pos_color" and "neg_color" and the data ranges from < 0 to > 0.

  my $poscolor       = $self->pos_color || $self->fgcolor;
  my $negcolor       = $self->neg_color || $self->bgcolor;

  my $data_midpoint  =   $self->midpoint;
  $data_midpoint     =   0 if $rescale;
  my $bicolor   = $poscolor != $negcolor
                       && $scaled_min < $data_midpoint
                       && $scaled_max > $data_midpoint;
  
  my ($rgb_pos,$rgb_neg,$rgb);
  if ($bicolor) {
      $rgb_pos = [$self->panel->rgb($poscolor)];
      $rgb_neg = [$self->panel->rgb($negcolor)];
  } else {
      $rgb = $scaled_max > $scaled_min ? ([$self->panel->rgb($poscolor)] || [$self->panel->rgb($self->bgcolor)])
                                       : ([$self->panel->rgb($negcolor)] || [$self->panel->rgb($self->bgcolor)]);
  }


  my %color_cache;

  @$data = reverse @$data if $self->flip;

  if (@$data <= $self->panel->width) { # data fits in width, so just draw it

    $pixels_per_step = $scale * $step;
    $pixels_per_step = 1 if $pixels_per_step < 1;
    my $datapoints_per_base  = @$data/$length;
    my $pixels_per_datapoint = $self->panel->width/@$data * $data_width_ratio;

    my %temps;
    map{$temps{$_}++} (@$data);
    my %colorss = (); 
    for (my $i = 0; $i <= @$data ; $i++) {
      my $x          = $x1 + $pixels_per_datapoint * $i;
      my $data_point = $data->[$i];
      defined $data_point || next;
      $data_point    = ($data_point-$mean)/$stdev if $rescale;
      $data_point    = $scaled_min if $scaled_min > $data_point;
      $data_point    = $scaled_max if $scaled_max < $data_point;
      my ($r,$g,$b)  = $bicolor
          ? $data_point > $data_midpoint ? $self->calculate_color($data_point,$rgb_pos,
                                                                  $data_midpoint,$scaled_max)
                                         : $self->calculate_color($data_point,$rgb_neg,
                                                                  $data_midpoint,$scaled_min)
          : $self->calculate_color($data_point,$rgb,
                                   $scaled_min,$scaled_max);

      my $idx        = $color_cache{$r,$g,$b} ||= $self->panel->translate_color($r,$g,$b);
      $colorss{$idx} = $data_point;
      $self->filled_box($gd,$x,$y1,$x+$pixels_per_datapoint,$y2,$idx,$idx);
    }
  (keys %colorss);  # Alleviate a silent crash somewhere in GD that causes density graph get drawn as a solid-colored box
  } else {     # use Sheldon's code to subsample data
      $pixels_per_step = $scale * $step;
      my $pixels = 0;

      # only draw boxes 2 pixels wide, so take the mean value
      # for n data points that span a 2 pixel interval
      my $binsize = 2/$pixels_per_step;
      my $pixelstep = $pixels_per_step;
      $pixels_per_step *= $binsize;
      $pixels_per_step *= $data_width_ratio;
      $pixels_per_span = 2;

      my $scores = 0;
      my $defined;

      for (my $i = $start; $i < $end ; $i += $step) {
        # draw the box if we have accumulated >= 2 pixel's worth of data.
        if ($pixels >= 2) {
          my $data_point = $defined ? $scores/$defined : 0;
          $scores  = 0;
          $defined = 0;

          $data_point    = $scaled_min if $scaled_min > $data_point;
          $data_point    = $scaled_max if $scaled_max < $data_point;
          my ($r,$g,$b)  = $bicolor
              ? $data_point > $data_midpoint ? $self->calculate_color($data_point,$rgb_pos,
                                                                      $data_midpoint,$scaled_max)
                                             : $self->calculate_color($data_point,$rgb_neg,
                                                                      $data_midpoint,$scaled_min)
              : $self->calculate_color($data_point,$rgb,
                                       $scaled_min,$max_value);
          my $idx        = $color_cache{$r,$g,$b} ||= $self->panel->translate_color($r,$g,$b);
          $self->filled_box($gd,$x1,$y1,$x1+$pixels_per_span,$y2,$idx,$idx);
          $x1 += $pixels;
          $pixels = 0;
        }

        my $val = shift @$data;
        # don't include undef scores in the mean calculation
        # $scores is the numerator; $defined is the denominator
        $scores += $val if defined $val;
        $defined++ if defined $val;

        # keep incrementing until we exceed 2 pixels
        # the step is a fraction of a pixel, not an integer
        $pixels += $pixelstep;
      }
  }
}

sub draw_plot {
    my $self            = shift;
    my $parts           = shift;
    my ($gd,$dx,$dy)    = @_;

    my $x_scale     = $self->scale;
    my $panel_start = $self->panel->start;
    my $feature     = $self->feature;
    my $f_start     = $feature->start > $panel_start 
	                  ? $feature->start 
			  : $panel_start;

    my ($left,$top,$right,$bottom) = $self->calculate_boundaries($dx,$dy);

    # There is a minmax inherited from xyplot as well as wiggle_data, and I don't want to
    # rely on Perl's multiple inheritance DFS to find the right one.
    my ($min_score,$max_score,$mean,$stdev)     = $self->minmax($parts);
    my $rescale  = $self->option('autoscale') eq 'z_score';

    my ($scaled_min,$scaled_max);
    if ($rescale) {
	$scaled_min = int(($min_score-$mean)/$stdev + 0.5);
	$scaled_max = int(($max_score-$mean)/$stdev + 0.5);
	my $bound  = $self->z_score_bound;
	$scaled_max = $bound  if $scaled_max > $bound;
	$scaled_min = -$bound if $scaled_min < -$bound;
    } else {
	($scaled_min,$scaled_max) = ($min_score,$max_score);
    }

    my $pivot    = $self->bicolor_pivot;
    my $positive = $self->pos_color;
    my $negative = $self->neg_color;
    my $midpoint = $self->midpoint;
    my ($rgb_pos,$rgb_neg,$rgb);
    if ($pivot) {
	$rgb_pos = [$self->panel->rgb($positive)];
	$rgb_neg = [$self->panel->rgb($negative)];
    } else {
	$rgb = $scaled_max > $scaled_min ? ([$self->panel->rgb($positive)] || [$self->panel->rgb($self->bgcolor)]) 
	                                 : ([$self->panel->rgb($negative)] || [$self->panel->rgb($self->bgcolor)]);
    }

    my %color_cache;
    my $flip     = $self->{flip};

    $self->panel->startGroup($gd);
    foreach (@$parts) {
	my ($start,$end,$score) = @$_;
	next unless defined $score; # undefined (absent) score transparent
	$score    = ($score-$mean)/$stdev if $rescale;
	$score    = $scaled_min if $scaled_min > $score;
	$score    = $scaled_max if $scaled_max < $score;

	my $x1     = $left    + ($start - $f_start) * $x_scale;
	my $x2     = $left    + ($end   - $f_start) * $x_scale;
	if ($flip) {
	    $x1 = $right - ($x1-$left);
	    $x2 = $right - ($x2-$left);
	    ($x1,$x2) = ($x2,$x1);
	}

	my ($r,$g,$b)  = $pivot
	  ? ($score > $midpoint ? $self->calculate_color($score,$rgb_pos,
							  $midpoint,$scaled_max)
	                        : $self->calculate_color($score,$rgb_neg,
							  $midpoint,$scaled_min)
	  )
          : $self->calculate_color($score,$rgb,
				   $scaled_min,$scaled_max);
	my $idx        = $color_cache{$r,$g,$b} ||= $self->panel->translate_color($r,$g,$b);
	$self->filled_box($gd,$x1,$top,$x2,$bottom,$idx,$idx);
    }
    return 1;
}

sub _draw_coverage {
    my $self    = shift;
    my $feature = shift;
    my $array   = shift;

    $array      = [split ',',$array] unless ref $array;
    return unless @$array;

    my ($start,$end)    = $self->effective_bounds($feature);
    my $bases_per_bin   = ($end-$start)/@$array;
    my $pixels_per_base = $self->scale;
    my @parts;
    for (my $pixel=0;$pixel<$self->width;$pixel++) {
	my $offset = $pixel/$pixels_per_base;
	my $s      = $start + $offset;
	my $e      = $s+1;  # fill in gaps
	my $v      = $array->[$offset/$bases_per_bin];
	#$v         = 0 unless defined $v; # don't want undefined values
	push @parts,[$s,$s,$v];
    }
    $self->Bio::Graphics::Glyph::wiggle_density::draw_plot(\@parts,@_);
}

sub calculate_color {
  my $self = shift;
  my ($s,$rgb,$min_score,$max_score) = @_;
  $s ||= $min_score;

  return (255,255,255) unless $max_score - $min_score; # avoid div by zero

  my $relative_score = ($s-$min_score)/($max_score-$min_score);
  $relative_score    = 0 if $relative_score < 0;
  $relative_score    = 1 if $relative_score > 1;
  return map { int(255 - (255-$_) * $relative_score) } @$rgb;
}

sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

sub record_label_positions { 
    my $self = shift;
    my $rlp  = $self->option('record_label_positions');
    return $rlp if defined $rlp;
    return 1;
}

sub draw_label {
    shift->Bio::Graphics::Glyph::xyplot::draw_label(@_);
}

1;

__END__

=head1 NAME

Bio::Graphics::Glyph::wiggle_density - A density plot compatible with dense "wig"data

=head1 SYNOPSIS

  See <Bio::Graphics::Panel> and <Bio::Graphics::Glyph>.

=head1 DESCRIPTION

This glyph works like the regular density but takes value data in
Bio::Graphics::Wiggle file format:

 reference = chr1
 ChipCHIP Feature1 1..10000 wigfile=./test.wig;wigstart=0
 ChipCHIP Feature2 10001..20000 wigfile=./test.wig;wigstart=656
 ChipCHIP Feature3 25001..35000 wigfile=./test.wig;wigstart=1312

The "wigfile" attribute gives a relative or absolute pathname to a
Bio::Graphics::Wiggle format file. The optional "wigstart" option
gives the offset to the start of the data. If not specified, a linear
search will be used to find the data. The data consist of a packed
binary representation of the values in the feature, using a constant
step such as present in tiling array data.

=head2 OPTIONS

The same as the regular graded_segments glyph, except that the
following options are recognized:

   Name        Value        Description
   ----        -----        -----------

   basedir     path         Path to be used to resolve "wigfile" and "densefile"
                                tags giving relative paths. Default is to use the
                                current working directory. Absolute wigfile &
                                densefile paths will not be changed.

   autoscale   "local" or "global"
                             If one or more of min_score and max_score options 
                             are absent, then these values will be calculated 
                             automatically. The "autoscale" option controls how
                             the calculation is done. The "local" value will
                             scale values according to the minimum and maximum
                             values present in the window being graphed. "global"   
                             will use chromosome-wide statistics for the entire
                             wiggle or dense file to find min and max values.

   smoothing   method name  Smoothing method: one of "mean", "max", "min" or "none"

   smoothing_window 
               integer      Number of values across which data should be smoothed.

   bicolor_pivot
               name         Where to pivot the two colors when drawing bicolor plots.
                               Options are "mean" and "zero". A numeric value can
                               also be provided.

   pos_color   color        When drawing bicolor plots, the fill color to use for values
                              that are above the pivot point.

   neg_color   color        When drawing bicolor plots, the fill color to use for values
                              that are below the pivot point.

=head2 SPECIAL FEATURE TAGS

The glyph expects one or more of the following tags (attributes) in
feature it renders:

   Name        Value        Description
   ----        -----        -----------

   wigfile     path name    Path to the Bio::Graphics::Wiggle file for vales.
                            (required)

   densefile   path name    Path to a Bio::Graphics::DenseFeature object
                               (deprecated)

   denseoffset integer      Integer offset to where the data begins in the
                               Bio::Graphics::DenseFeature file (deprecated)

   densesize   integer      Integer size of the data in the Bio::Graphics::DenseFeature
                               file (deprecated)

=head1 BUGS

Please report them.

=head1 SEE ALSO

L<Bio::Graphics::Panel>,
L<Bio::Graphics::Glyph>,
L<Bio::Graphics::Glyph::arrow>,
L<Bio::Graphics::Glyph::cds>,
L<Bio::Graphics::Glyph::crossbox>,
L<Bio::Graphics::Glyph::diamond>,
L<Bio::Graphics::Glyph::dna>,
L<Bio::Graphics::Glyph::dot>,
L<Bio::Graphics::Glyph::ellipse>,
L<Bio::Graphics::Glyph::extending_arrow>,
L<Bio::Graphics::Glyph::generic>,
L<Bio::Graphics::Glyph::graded_segments>,
L<Bio::Graphics::Glyph::heterogeneous_segments>,
L<Bio::Graphics::Glyph::line>,
L<Bio::Graphics::Glyph::pinsertion>,
L<Bio::Graphics::Glyph::primers>,
L<Bio::Graphics::Glyph::rndrect>,
L<Bio::Graphics::Glyph::segments>,
L<Bio::Graphics::Glyph::ruler_arrow>,
L<Bio::Graphics::Glyph::toomany>,
L<Bio::Graphics::Glyph::transcript>,
L<Bio::Graphics::Glyph::transcript2>,
L<Bio::Graphics::Glyph::translation>,
L<Bio::Graphics::Glyph::allele_tower>,
L<Bio::DB::GFF>,
L<Bio::SeqI>,
L<Bio::SeqFeatureI>,
L<Bio::Das>,
L<GD>

=head1 AUTHOR

Lincoln Stein E<lt>steinl@cshl.eduE<gt>.

Copyright (c) 2007 Cold Spring Harbor Laboratory

This package and its accompanying libraries is free software; you can
redistribute it and/or modify it under the terms of the GPL (either
version 1, or at your option, any later version) or the Artistic
License 2.0.  Refer to LICENSE for the full license text. In addition,
please see DISCLAIMER.txt for disclaimers of warranty.

=cut
