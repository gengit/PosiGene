package Bio::Graphics::Glyph::group;

use strict;
use base qw(Bio::Graphics::Glyph::segmented_keyglyph);

sub my_description {
    return <<END;
This glyph is used internally by Bio::Graphics::Panel for laying out
groups of glyphs that are linked together.  It should not be used
explicitly.
END
}

sub my_options {
    return
    {
	group_label => [
	    'boolean',
	    undef,
	    'Attach a label to the group; this is independent of the label option which applies',
	    'to features within the group'
	    ],
	group_label_position => [
	    [qw(top left)],
	    'left',
	    'Position in which to draw the group label.'
	],
    }
}

# group sets connector to 'dashed'
sub connector {
  my $self = shift;
  my $super = $self->SUPER::connector(@_);
  return $super if $self->all_callbacks;
  return 'dashed' unless defined($super) && ($super eq 'none' or !$super);
}

# we don't label group (yet)
sub label { my $self = shift;
	    return $self->{_group_label} if exists $self->{_group_label};
	    return $self->{_group_label}  = $self->option('group_label') ? $self->feature->display_name : '' 
}

sub labelfont {
  my $self = shift;
  return $self->getfont('groupfont','gdMediumBoldFont');
}

sub pad_left { 
    my $self = shift;
    return 0 unless $self->option('group_label');
    return $self->string_width($self->label,$self->labelfont) +3;
}

sub draw {
    my $self = shift;
    $self->SUPER::draw(@_) if $self->feature_has_subparts;
    $self->draw_label(@_)  if $self->option('group_label');
}

sub draw_label {
    my $self = shift;
    my $label = $self->label or return;
    my $panel= $self->panel;

    $self->SUPER::draw_label(@_) unless $panel->{suppress_key};

    my ($gd,$left,$top,$partno,$total_parts) = @_;
    my $font = $self->labelfont;

    my $x    = $self->left + $left; # valid for both "top" and "left" because the left-hand side is defined by pad_left
    my $y;
    if ($self->label_position eq 'top') {
	$x += $self->pad_left;  # offset to beginning of the drawn part of the feature
	$x = $panel->left + 1 if $x <= $panel->left;
	$y = $self->top + $top - 1;
    } elsif ($self->label_position eq 'left') {
	$y    = $self->{top} + ($self->height - $self->font_height($font))/2 + $top;
	$y    = $self->{top} + $top if $y < $self->{top} + $top;
    }
    $panel->add_key_box($self,$label,$x,$y);
}

sub label_position { 
    my $self = shift;
    my $pos  = $self->option('group_label_position') || 'left';
    return $pos;
}

sub new {
  my $self = shift;
  return $self->SUPER::new(@_,-level=>-1);
}


# don't allow simple bumping in groups -- it looks terrible...
sub bump {
    my $self = shift;
    my $bump = $self->SUPER::bump(@_);
    return 1  if $bump >  1;
    return -1 if $bump < -1;
    return $bump;
}

1;

__END__

=head1 NAME

Bio::Graphics::Glyph::group - The "group" glyph

=head1 SYNOPSIS

  See L<Bio::Graphics::Panel> and L<Bio::Graphics::Glyph>.

=head1 DESCRIPTION

This glyph is used internally by Bio::Graphics::Panel for laying out
groups of glyphs that move in concert.  It should not be used
explicitly.

=head1 BUGS

Please report them.

=head1 SEE ALSO

L<Ace::Sequence>, L<Ace::Sequence::Feature>, L<Bio::Graphics::Panel>,
L<Bio::Graphics::Track>, L<Bio::Graphics::Glyph::anchored_arrow>,
L<Bio::Graphics::Glyph::arrow>,
L<Bio::Graphics::Glyph::box>,
L<Bio::Graphics::Glyph::primers>,
L<Bio::Graphics::Glyph::segments>,
L<Bio::Graphics::Glyph::toomany>,
L<Bio::Graphics::Glyph::transcript>,

=head1 AUTHOR

Lincoln Stein E<lt>lstein@cshl.orgE<gt>

Copyright (c) 2001 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut
