package Bio::Graphics::Glyph::operon;
 
use strict;
use base 'Bio::Graphics::Glyph::segments';
#use Data::Dumper;

sub draw_component {
  my $self = shift;
  my ($gd,$dx,$dy) = @_;
  my ($left,$top,$right,$bottom) = $self->bounds($dx,$dy);
 
 my $feature = $self->feature;

	 $feature->type =~ /^([\S_]+):/; 
 
	if ($1 eq 'TSS') {

		# draw the promoter as an arrow
		if ($feature->strand == 1){
			$self->vline($gd, $left, $top-5, ($top+$bottom)/2);
  			$self->arrow($gd,$left,$left+5,$top-5);
		}
		if ($feature->strand == -1){
			$self->vline($gd, $right, $top-5, ($top+$bottom)/2);
  			$self->arrow($gd,$right,$right-5,$top-5);
		}
		return;
 		
	}
	if ($1 eq 'terminator') {

		# draw the terminator as an lollipop
		if ($feature->strand >= 0){
			$self->vline($gd, $right, $top-5, ($top+$bottom)/2);
		    $gd->filledEllipse($right,$top-4,6,6,$self->translate_color('red'));
		}
		if ($feature->strand < 0){
			$self->vline($gd, $left, $top-5, ($top+$bottom)/2);
		    $gd->filledEllipse($left,$top-4,6,6,$self->translate_color('red'));
		}
		return;
 		
	}
	$self->SUPER::draw_component(@_);
 
}

sub pad_top{
	return 10;
}

sub pad_right{
	return 10;
}

sub pad_left{
	return 10;
}
 
sub default_width{
  return 20;  
}
 
sub vline {
  my $self  = shift;
  my $image = shift;
  my ($x,$y1,$y2) = @_;
  my $fg     = $self->set_pen;

  $image->line($x,$y1,$x,$y2,$fg);
}
 
1;

=head1 NAME

Bio::Graphics::Glyph::operon - The "polycistronic operon" glyph

=head1 SYNOPSIS

  See L<Bio::Graphics::Panel> and L<Bio::Graphics::Glyph>.

=head1 DESCRIPTION

This glyph is used for drawing polycistronic operons.  It is essentially a
"segments" glyph in which subfeatures of specific types "TSS" and "terminator" are displayed
as line+arrow and a red lollipop, respectively.  Note that these are hardcoded SO types

=head2 OPTIONS

accepts standard options so far.  This version does not yet allow user configuration of things like
terminator color, promoter arrow size etc.

=head1 BUGS

Please report them.

=head1 SEE ALSO




=head1 AUTHOR

Jim Hu E<lt>jimhu@tamu.eduE<gt>

Copyright (c) 2011 Texas A&M Univ.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut
