package Bio::Graphics::Glyph::wiggle_data;

use strict;
use base qw(Bio::Graphics::Glyph::minmax);
use File::Spec;
use Data::Dumper;
sub minmax {
    my $self   = shift;
    my $parts  = shift;

    my $autoscale  = $self->option('autoscale') || 'local';

    my $min_score  = $self->min_score  unless $autoscale eq 'z_score';
    my $max_score  = $self->max_score  unless $autoscale eq 'z_score';

    my $do_min     = !defined $min_score;
    my $do_max     = !defined $max_score;

    if (@$parts && $self->feature->can('statistical_summary')) {
	my ($min,$max,$mean,$stdev) = eval {$self->bigwig_stats($autoscale,$self->feature)};
	$min_score = $min if $do_min;
	$max_score = $max if $do_max;
	return $self->sanity_check($min_score,$max_score,$mean,$stdev);
    }

    elsif (eval {$self->wig}) {
	if (my ($min,$max,$mean,$stdev) = eval{$self->wig_stats($autoscale,$self->wig)}) {
	    $min_score = $min if $do_min;
	    $max_score = $max if $do_max;
	    return $self->sanity_check($min_score,$max_score,$mean,$stdev);
	}
    }

    if ($do_min or $do_max) {
	my $first = $parts->[0];
	for my $part (@$parts) {
	    my $s   = ref $part ? $part->[2] : $part;
	    next unless defined $s;
	    $min_score = $s if $do_min && (!defined $min_score or $s < $min_score);
	    $max_score = $s if $do_max && (!defined $max_score or $s > $max_score);
	}
    }
    return $self->sanity_check($min_score,$max_score);
}

sub bigwig_stats {
    my $self = shift;
    my ($autoscale,$feature) = @_;
    my $s;
    if ($autoscale =~ /global/ or $autoscale eq 'z_score') {
	$s = $feature->global_stats;
    } elsif ($autoscale eq 'chromosome') {
	$s = $feature->chr_stats;
    } else {
	$s = $feature->score;
    }
    return $self->clip($autoscale,
		       $s->{minVal},$s->{maxVal},Bio::DB::BigWig::binMean($s),Bio::DB::BigWig::binStdev($s));
}

sub wig_stats {
    my $self = shift;
    my ($autoscale,$wig) = @_;

    if ($autoscale =~ /global|chromosome|z_score/) {
	my $min_score = $wig->min;
	my $max_score = $wig->max;
	my $mean  = $wig->mean;
	my $stdev = $wig->stdev;
	return $self->clip($autoscale,$min_score,$max_score,$mean,$stdev);
    }  else {
	return;
    }
}

sub clip {
    my $self = shift;
    my ($autoscale,$min,$max,$mean,$stdev) = @_;
    return ($min,$max,$mean,$stdev) unless $autoscale =~ /clipped/;
    my $fold = $self->z_score_bound;
    my $clip_max = $mean + $stdev*$fold;
    my $clip_min = $mean - $stdev*$fold;
    $min = $clip_min if $min < $clip_min;
    $max = $clip_max if $max > $clip_max;
    return ($min,$max,$mean,$stdev);
}


sub z_score_bound {
    my $self = shift;
    return $self->option('z_score_bound') || 4;
}

# change the scaling of the data points if z-score autoscaling requested
sub rescale {
    my $self   = shift;
    my $points = shift;
    return $points unless $self->option('autoscale') eq 'z_score';

    my ($min,$max,$mean,$stdev)  = $self->minmax($points);
    foreach (@$points) {
	$_ = ($_ - $mean) / $stdev;
    }
    return $points;
}

sub global_mean_and_variance {
    my $self = shift;
    if (my $wig = $self->wig) {
	return ($wig->mean,$wig->stdev);
    } elsif ($self->feature->can('global_mean')) {
	my $f = $self->feature;
	return ($f->global_mean,$f->global_stdev);
    }
    return;
}

sub global_min_max {
    my $self = shift;
    if (my $wig = $self->wig) {
	return ($wig->min,$wig->max);
    } elsif (my $stats = eval {$self->feature->global_stats}) {
	return ($stats->{minVal},$stats->{maxVal});
    }
    return;
}
sub series_stdev {
    my $self = shift;
    my ($mean,$stdev) = $self->global_mean_and_variance;
    return $stdev;
}

sub series_mean {
    my $self = shift;
    my ($mean) = $self->global_mean_and_variance;
    return $mean;
}

sub series_min {
    my $self = shift;
    return ($self->global_min_max)[0];
}

sub series_max {
    my $self = shift;
    return ($self->global_min_max)[1];
}

sub wig {
  my $self = shift;
  my $d = $self->{wig};
  $self->{wig} = shift if @_;
  $d;
}

sub datatype {
    my $self = shift;
    my $feature = $self->feature;

    my ($tag,$value);
    for my $t ('wigfile','wigdata','densefile','coverage') {
	if (my ($v) = eval{$feature->get_tag_values($t)}) {
	    $value = $v;
	    $tag   = $t;
	    last;
	}
    }
    if (!$value && $feature->can('statistical_summary')) {
	$tag   = 'statistical_summary';
	$value = eval{$feature->statistical_summary};
    }

    $tag ||= 'generic';

    return wantarray ? ($tag,$value) : $tag;
}

sub get_parts {
    my $self = shift;
    my $feature = $self->feature;
    my ($start,$end) = $self->effective_bounds($feature);
    my ($datatype,$data) = $self->datatype;
    return $self->subsample($data,$start,$end)                      if $datatype eq 'wigdata';
    return $self->create_parts_from_wigfile($data,$start,$end)      if $datatype eq 'wigfile';
    return $self->create_parts_for_dense_feature($data,$start,$end) if $datatype eq 'densefile';
    return $self->create_parts_from_coverage($data,$start,$end)     if $datatype eq 'coverage';
    return $self->create_parts_from_summary($data,$start,$end)      if $datatype eq 'statistical_summary';
    return [];
}

sub effective_bounds {
    my $self    = shift;
    my $feature = shift;
    my $panel_start = $self->panel->start;
    my $panel_end   = $self->panel->end;
    my $start       = $feature->start>$panel_start 
                         ? $feature->start 
                         : $panel_start;
    my $end         = $feature->end<$panel_end   
                         ? $feature->end   
                         : $panel_end;
    return ($start,$end);
}

sub create_parts_for_dense_feature {
    my $self = shift;
    my ($dense,$start,$end) = @_;

    my $span = $self->scale> 1 ? $end - $start : $self->width;
    my $data = $dense->values($start,$end,$span);
    my $points_per_span = ($end-$start+1)/$span;
    my @parts;

    for (my $i=0; $i<$span;$i++) {
	my $offset = $i * $points_per_span;
	my $value  = shift @$data;
	next unless defined $value;
	push @parts,[$start + int($i * $points_per_span),
		     $start + int($i * $points_per_span),
		     $value];
    }
    return \@parts;
}

sub create_parts_from_coverage {
    my $self    = shift;
    my ($array,$start,$end) = @_;
    $array      = [split ',',$array] unless ref $array;
    return unless @$array;

    my $bases_per_bin   = ($end-$start)/@$array;
    my $pixels_per_base = $self->scale;
    my @parts;
    for (my $pixel=0;$pixel<$self->width;$pixel++) {
	my $offset = $pixel/$pixels_per_base;
	my $s      = $start + $offset;
	my $e      = $s+1;  # fill in gaps
	my $v      = $array->[$offset/$bases_per_bin];
	push @parts,[$s,$s,$v];
    }
    return \@parts;
}

sub create_parts_from_summary {
    my $self = shift;
    my ($stats,$start,$end) = @_;
    $stats ||= [];
    my $interval_method = $self->option('interval_method') || 'mean';
    my @vals;
    if ($interval_method eq 'mean') {
    	@vals  = map {$_->{validCount} ? $_->{sumData}/$_->{validCount} : undef} @$stats;
    }
    elsif ($interval_method eq 'sum') {
    	@vals  = map {$_->{validCount} ? $_->{sumData} : undef} @$stats;
    }
    elsif ($interval_method eq 'min') {
    	@vals  = map {$_->{validCount} ? $_->{minVal} : undef} @$stats;
    }
    elsif ($interval_method eq 'max') {
    	@vals  = map {$_->{validCount} ? $_->{maxVal} : undef} @$stats;
    }
    else {
    	warn "unrecognized interval method $interval_method!";
    }
    return \@vals;
}

sub create_parts_from_wigfile {
    my $self = shift;
    my ($path,$start,$end) = @_;
    if (ref $path && $path->isa('Bio::Graphics::Wiggle')) {
     return $self->create_parts_for_dense_feature($path,$start,$end);
    }
    $path = $self->rel2abs($path);
    if ($path =~ /\.wi\w{1,3}$/) {
	eval "require Bio::Graphics::Wiggle" unless Bio::Graphics::Wiggle->can('new');
	my $wig = eval { Bio::Graphics::Wiggle->new($path)};
	return $self->create_parts_for_dense_feature($wig,$start,$end);
    } elsif ($path =~ /\.bw$/i) { 
	eval "use Bio::DB::BigWig" unless Bio::DB::BigWig->can('new');
	my $bigwig = Bio::DB::BigWig->new(-bigwig=>$path);
	my ($summary) = $bigwig->features(-seq_id => $self->feature->segment->ref,
					  -start  => $start,
					  -end    => $end,
					  -type   => 'summary');
	return $self->create_parts_from_summary($summary->statistical_summary($self->width));
    }
}

sub subsample {
  my $self = shift;
  my ($data,$start,$end) = @_;
  my $span = $self->scale > 1 ? $end - $start 
                              : $self->width;
  my $points_per_span = ($end-$start+1)/$span;
  my @parts;
  for (my $i=0; $i<$span;$i++) {
    my $offset = $i * $points_per_span;
    my $value  = $data->[$offset + $points_per_span/2];
    push @parts,[$start + int($i*$points_per_span),
		 $start + int($i*$points_per_span),
		 $value];
  }
  return \@parts;
}

sub rel2abs {
    my $self = shift;
    my $wig  = shift;
    return $wig if ref $wig;
    my $path = $self->option('basedir');
    return File::Spec->rel2abs($wig,$path);
}

sub draw {
  my $self = shift;
  my ($gd,$dx,$dy) = @_;

  my $feature     = $self->feature;
  my $datatype    = $self->datatype;

  my $retval;
  $retval =  $self->draw_wigfile($feature,@_)   if $datatype eq 'wigfile';
  $retval =  $self->draw_wigdata($feature,@_)   if $datatype eq 'wigdata';
  $retval =  $self->draw_densefile($feature,@_) if $datatype eq 'densefile';
  $retval =  $self->draw_coverage($feature,@_)  if $datatype eq 'coverage';
  $retval =  $self->draw_statistical_summary($feature,@_) if $datatype eq 'statistical_summary';
  $retval =  $self->SUPER::draw(@_) if $datatype eq 'generic';

  return $retval;
}

sub draw_wigfile {
  my $self = shift;
  my $feature = shift;

  my ($wigfile) = eval{$feature->get_tag_values('wigfile')};
  $wigfile      = $self->rel2abs($wigfile);

  eval "require Bio::Graphics::Wiggle" unless Bio::Graphics::Wiggle->can('new');
  my $wig = ref $wigfile && $wigfile->isa('Bio::Graphics::Wiggle') 
      ? $wigfile
      : eval { Bio::Graphics::Wiggle->new($wigfile) };
  unless ($wig) {
      warn $@;
      return $self->SUPER::draw(@_);
  }
  $self->_draw_wigfile($feature,$wigfile,@_);
}

sub draw_wigdata {
    my $self    = shift;
    my $feature = shift;

    my ($data)    = eval{$feature->get_tag_values('wigdata')};

    if (ref $data eq 'ARRAY') {
	my ($start,$end) = $self->effective_bounds($feature);
	my $parts = $self->subsample($data,$start,$end);
	$self->draw_plot($parts,@_);
    }

    else {
	my $wig = eval { Bio::Graphics::Wiggle->new() };
	unless ($wig) {
	    warn $@;
	    return $self->SUPER::draw(@_);
	}

	$wig->import_from_wif64($data);
	$self->_draw_wigfile($feature,$wig,@_);
    }
}

sub draw_densefile {
    my $self = shift;
    my $feature = shift;

    my ($densefile) = eval{$feature->get_tag_values('densefile')};
    $densefile      = $self->rel2abs($densefile);
    
    my ($denseoffset) = eval{$feature->get_tag_values('denseoffset')};
    my ($densesize)   = eval{$feature->get_tag_values('densesize')};
    $denseoffset ||= 0;
    $densesize   ||= 1;
    
    my $smoothing      = $self->get_smoothing;
    my $smooth_window  = $self->smooth_window;
    my $start          = $self->smooth_start;
    my $end            = $self->smooth_end;

    my $fh         = IO::File->new($densefile) or die "can't open $densefile: $!";
    eval "require Bio::Graphics::DenseFeature" unless Bio::Graphics::DenseFeature->can('new');
    my $dense = Bio::Graphics::DenseFeature->new(-fh=>$fh,
						 -fh_offset => $denseoffset,
						 -start     => $feature->start,
						 -smooth    => $smoothing,
						 -recsize   => $densesize,
						 -window    => $smooth_window,
	) or die "Can't initialize DenseFeature: $!";
    my $parts = $self->get_parts;
    $self->draw_plot($parts);
}

sub draw_coverage {
    my $self    = shift;
    my $feature = shift;

    my ($array)   = eval{$feature->get_tag_values('coverage')};
    $self->_draw_coverage($feature,$array,@_);
}

sub draw_statistical_summary {
    my $self = shift;
    my $feature = shift;
    my $stats = $feature->statistical_summary($self->width);
    $stats   ||= [];
    my $interval_method = $self->option('interval_method') || 'mean';
    my @vals;
    if ($interval_method eq 'mean') {
    	@vals  = map {$_->{validCount} ? $_->{sumData}/$_->{validCount} : undef} @$stats;
    }
    elsif ($interval_method eq 'sum') {
    	@vals  = map {$_->{validCount} ? $_->{sumData} : undef} @$stats;
    }
    elsif ($interval_method eq 'min') {
    	@vals  = map {$_->{validCount} ? $_->{minVal} : undef} @$stats;
    }
    elsif ($interval_method eq 'max') {
    	@vals  = map {$_->{validCount} ? $_->{maxVal} : undef} @$stats;
    }
    else {
    	warn "unrecognized interval method $interval_method!";
    }
    return $self->_draw_coverage($feature,\@vals,@_);
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
	next unless defined $v; # skip missing values
	push @parts,[$s,$s,$v];
    }
    $self->draw_plot(\@parts,@_);
}

sub _draw_wigfile {
    my $self    = shift;
    my $feature = shift;
    my $wigfile = shift;
    
    $self->feature->remove_tag('wigfile') if $self->feature->has_tag('wigfile');
    $self->feature->add_tag_value('wigfile',$wigfile);

    eval "require Bio::Graphics::Wiggle" unless Bio::Graphics::Wiggle->can('new');
    my $wig = ref $wigfile && $wigfile->isa('Bio::Graphics::Wiggle')
      ? $wigfile
      : eval { Bio::Graphics::Wiggle->new($wigfile) };

    $wig->smoothing($self->get_smoothing);
    $wig->window($self->smooth_window);
    $self->wig($wig);
    my $parts = $self->get_parts;
    $self->draw_plot($parts,@_);
}

1;
