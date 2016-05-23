package Bio::Graphics::Glyph::minmax;

use strict;
use base qw(Bio::Graphics::Glyph);

sub my_description {
    return <<END;
This is an internal glyph that defines options standard to those glyphs that
use colors or xyplots to display a range of quantitative values. Do not use it directly.
END
}
sub my_options {
    return {
	min_score => [
	    'float',
	    undef,
	    'The minimum score of the quantitative range.'],
	max_score => [
	    'float',
	    undef,
	    'The maximum score of the quantitative range.'],
	bicolor_pivot => [
	    ['mean','zero','float','max','min','1SD','2SD','3SD'],
	    undef,
	    'A value to pivot the display on. Typically this involves changing the color of the',
	    'glyph (and scale axis) depending on whether the feature is above or below the pivot value.',
	    'Provide "mean" to pivot on the mean of the data series, "zero" to pivot on the',
	    'zero value, "min" to pivot on the min and "max" on max of data series, also it is',
            'possible to use any arbitrary integer or floating point number to pivot at that value.'],
	pos_color => [
	    'color',
	    undef,
	    'The color to use for values that exceed the bicolor_pivot value.'],
	neg_color => [
	    'color',
	    undef,
	    'The color to use for values that are below the bicolor_pivot value.'],
    };
}

sub min_score {
  shift->option('min_score');
}

sub max_score {
  shift->option('max_score');
}

sub minmax {
  my $self = shift;
  my $parts = shift;

  # figure out the colors
  my $max_score = $self->max_score;
  my $min_score = $self->min_score;

  my $do_min = !defined $min_score;
  my $do_max = !defined $max_score;

  if ($do_min or $do_max) {
    my $first = $parts->[0];
    for my $part (@$parts) {
      my $s = eval { $part->feature->score } || $part;
      next unless defined $s;
      $max_score = $s if $do_max && (!defined $max_score or $s > $max_score);
      $min_score = $s if $do_min && (!defined $min_score or $s < $min_score);
    }
  }
  return $self->sanity_check($min_score,$max_score);
}

sub sanity_check {
    my $self = shift;
    my ($min_score,$max_score,@rest) = @_;
    return ($min_score,$max_score,@rest) if $max_score > $min_score;

    if ($max_score > 0) {
	$min_score = 0;
    } else {
	$max_score = $min_score + 1;
    }

    return ($min_score,$max_score,@rest);
}

sub midpoint {
    my $self    = shift;
    my $default = shift;

    my $pivot = $self->bicolor_pivot;
    if ($pivot eq 'none') {
	return
    } elsif ($pivot eq 'zero') {
	return 0;
    } elsif ($pivot eq 'mean') {
	return eval {$self->series_mean} || 0;
    } elsif ($pivot eq 'min') {
	return eval {$self->series_min} || 0;
    } elsif ($pivot eq 'max') {
        return eval {$self->series_max} || 0;
    } elsif ($pivot =~ /^(\d+)SD/i) {
	my $stdevs = $1;
	return eval {$self->series_mean + $self->series_stdev * $stdevs} || 0;
    } elsif  ($pivot =~ /^[\d.eE+-]+$/){
	return $pivot;
    } else {
	my $min = $self->min_score or return $default;
	my $max = $self->max_score or return $default;;
	return (($min+$max)/2);
    }
}

sub bicolor_pivot {
    my $self = shift;
    my $pivot = $self->option('bicolor_pivot');
    return if defined $pivot && $pivot eq 'none';
    return $pivot;
}

sub pos_color {
    my $self  = shift;
    my $pivot = $self->bicolor_pivot || 'none';
    return $self->bgcolor if $pivot eq 'none';
    return defined $self->color('pos_color')  ? $self->color('pos_color') : $self->bgcolor;
}

sub neg_color {
    my $self = shift;
    my $pivot = $self->bicolor_pivot || 'none';
    return $self->bgcolor if $pivot eq 'none';
    return defined $self->color('neg_color') ? $self->color('neg_color') : $self->bgcolor;
}

# change the scaling of the y axis
sub rescale {
    my $self = shift;
    my ($min,$max) = @_;
    return ($min,$max);  # don't do anything here
}



1;

__END__

=head1 NAME

Bio::Graphics::Glyph::minmax - The minmax glyph

=head1 SYNOPSIS

  See L<Bio::Graphics::Panel> and L<Bio::Graphics::Glyph>.

=head1 DESCRIPTION

This glyph is a common base class for
L<Bio::Graphics::Glyph::graded_segments> and
L<Bio::Graphics::Glyph::xyplot>.  It adds an internal method named
minmax() for calculating the upper and lower boundaries of scored
features, and is not intended for end users.

=head1 BUGS

Please report them.

=head1 SEE ALSO

L<Bio::Graphics::Panel>,
L<Bio::Graphics::Track>,
L<Bio::Graphics::Glyph::graded_segments>,
L<Bio::Graphics::Glyph::xyplot>,

=head1 AUTHOR

Lincoln Stein E<lt>lstein@cshl.orgE<gt>

Copyright (c) 2003 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

