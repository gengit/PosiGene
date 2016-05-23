package Bio::Graphics::Glyph::line;

use strict;
use base qw(Bio::Graphics::Glyph::generic);

sub my_description {
    return <<END;
This glyph draws a horizontal line spanning the feature.
END
}

sub draw {
    my $self = shift;
    $self->SUPER::draw(@_);

    my $gd = shift;

    my $fg = $self->fgcolor;
    my $linewidth = $self->linewidth;
    $fg = $self->set_pen($linewidth) if $linewidth > 1;

    my ($x1,$y1,$x2,$y2) = $self->calculate_boundaries(@_);
    my $center = ($y1+$y2)/2;

    my ($lowest,$highest);

    my @parts = $self->parts;
    my $previous = -1;
    for (my $i = 0;$i<@parts;$i++) {
	my $part      = $parts[$i];
	my ($l,undef,$xx1,$yy1) = $part->calculate_boundaries(@_);

	$lowest  = $l   if !defined $lowest  || $lowest > $l;
	$highest = $xx1 if !defined $xx1     || $highest < $xx1;

	my $next_part = $parts[$i+1] or last;
	my ($xx2,$yy2,undef,undef) = $next_part->calculate_boundaries(@_);

	$self->draw_connector($gd,$xx1,$xx2,$y1,$y2) if $xx1 < $xx2;
    }

    if ($lowest && $x1 < $lowest) {
	$self->draw_connector($gd,$x1,$lowest,$y1,$y2);
    }

    if ($highest && $x2 > $highest) {
	$self->draw_connector($gd,$highest,$x2,$y1,$y2);
    }

    my $height = $self->height;
    $height    = 12 unless $height > 12;

    return unless $self->parts;
    if ($self->feature->strand > 0) {
	$self->arrow($gd,$x2,$x2+$height/2,$center);
    } elsif ($self->feature->strand < 0) {
	$self->arrow($gd,$x1,$x1-$height/2,$center);
    }
}

sub draw_connector {
    my $self = shift;
    my $gd   = shift;
    my ($left,$right,$high,$low) = @_;
    my $fg = $self->fgcolor;
    my $center = ($high+$low)/2;
    $gd->line($left,$center,$right,$center,$fg);
}

sub bump { 0 }

sub maxdepth { return }


1;

__END__

=head1 NAME

Bio::Graphics::Glyph::line - The "line" glyph

=head1 SYNOPSIS

  See L<Bio::Graphics::Panel> and L<Bio::Graphics::Glyph>.

=head1 DESCRIPTION

This glyph draws a line parallel to the sequence segment. It is
different from other glyphs in that it is designed to work with DAS
tracks. The line is drawn BETWEEN the subparts, as if you specified a
connector type of "line".

=head2 OPTIONS

This glyph takes only the standard options. See
L<Bio::Graphics::Glyph> for a full explanation.

  Option      Description                      Default
  ------      -----------                      -------

  -fgcolor      Foreground color	       black

  -outlinecolor	Synonym for -fgcolor

  -bgcolor      Background color               turquoise

  -fillcolor    Synonym for -bgcolor

  -linewidth    Line width                     1

  -height       Height of glyph		       10

  -font         Glyph font		       gdSmallFont

  -connector    Connector type                 0 (false)

  -connector_color
                Connector color                black

  -label        Whether to draw a label	       0 (false)

  -description  Whether to draw a description  0 (false)

  -strand_arrow Whether to indicate            0 (false)
                 strandedness

  -hilite       Highlight color                undef (no color)

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
L<Bio::Graphics::Glyph::triangle>,
L<Bio::DB::GFF>,
L<Bio::SeqI>,
L<Bio::SeqFeatureI>,
L<Bio::Das>,
L<GD>

=head1 AUTHOR

Allen Day E<lt>day@cshl.orgE<gt>.

Copyright (c) 2001 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut
