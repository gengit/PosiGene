package Bio::Graphics::Glyph::scale;

use strict;
use base qw(Bio::Graphics::Glyph::segmented_keyglyph Bio::Graphics::Glyph::xyplot);

sub my_description {
    return <<END;
This glyph is used internally by GBrowse to draw a scale bar.
It should not be used explicitly.
END
}

sub my_options {
    return;
}

sub draw {
    my $self = shift;

    my ($gd,$dx,$dy) = @_;
    my ($left,$top,$right,$bottom) = $self->calculate_boundaries($dx,$dy);

    $self->panel->startGroup($gd);

    my $max_score = $self->max_score || 100;
    my $min_score = $self->min_score || 0;

    $max_score = Bio::Graphics::Glyph::xyplot::max10($max_score);
    $min_score = Bio::Graphics::Glyph::xyplot::min10($min_score);

    my $height = $bottom - $top;
    my $scale  = $max_score > $min_score ? $height/($max_score-$min_score)
                                       : 1;
    my $x = $left;
    my $y = $top + $self->pad_top;

    # position of "0" on the scale
    my $y_origin = $min_score <= 0 ? $bottom - (0 - $min_score) * $scale : $bottom;
    $y_origin    = $top if $max_score < 0;

    $self->panel->startGroup($gd);
    $self->_draw_scale($gd,$scale,$min_score,$max_score,$dx,$dy,$y_origin);

    $self->panel->endGroup($gd);
}

sub _determine_side {
    my $self = shift;
    return 'three';
}

# Added pad_top subroutine (pad_top of Glyph.pm, which is called when executing $self->pad_top
# returns 0, so we need to override it here)
sub pad_top {
  my $self = shift;
  my $pad = $self->Bio::Graphics::Glyph::generic::pad_top(@_);
  if ($pad < ($self->font('gdTinyFont')->height)) {
    $pad = $self->font('gdTinyFont')->height;  # extra room for the scale
  }
  $pad;
}

sub pad_left {
    my $self = shift;
    my $pad  = $self->SUPER::pad_left(@_);
    return $pad unless $self->option('variance_band');
    $pad    += length('+1sd')/2 * $self->font('gdTinyFont')->width+3;
    return $pad;
}

sub new {
  my $self = shift;
  return $self->SUPER::new(@_,-level=>-1);
}

1;

__END__

=head1 NAME

Bio::Graphics::Glyph::scale - The "scale" glyph

=head1 SYNOPSIS

  See L<Bio::Graphics::Panel> and L<Bio::Graphics::Glyph>.

=head1 DESCRIPTION

This glyph is used internally by GBrowse to draw a scale bar.
It should not be used explicitly.

=head1 BUGS

Please report them.

=head1 SEE ALSO

L<Bio::Graphics::Glyph::xyplot>,

=head1 AUTHOR

Copyright (c) 2010 Ontario Institute for Cancer Research

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut
