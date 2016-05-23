package Bio::Graphics::Glyph::hybrid_plot;

use strict;
use base qw(Bio::Graphics::Glyph::wiggle_xyplot);
use constant DEBUG=>0;
use constant NEGCOL=>"orange";
use constant POSCOL=>"blue";
our $VERSION = '1.0';

sub my_options {
    {   
        min_score => [
            'integer',
            undef,
            "Minimum value of the signal graph feature's \"score\" attribute."],
        max_score => [
            'integer',
            undef,
            "Maximum value of the signal graph feature's \"score\" attribute."],
        flip_sign => [
            'boolean',
            0,
            "Optionally flip the signal for wigfileB (if the scores are positive but we wish to paint the signal along negative y-axis)"]
    };
}

sub my_description {
    return <<END;
This glyph draws signal graph (wiggle_xyplot) using wiggle or BigWig files
requires a special load gff file that uses attributes 'wigfileA' and 'wigfileB'
For BigWig support it is also required to have 'fasta' attribute set to point
to a fasta file for your organism of interest

Example:

2L  test   hybrid    5407   23011573    .     .     .     Name=Experiment 1;wigfileA=SomeWigFile1.wigdb;wigfileB=SomeWigFile2.wigdb

END
}

#Checking the method for individual features (RNA-Seq reads)
sub _check_uni {
 return shift->option('u_method') || 'match';
}


# Override height and pad functions (needed to correctly space features with different sources):
sub height {
  my $self = shift;
  my $h    = $self->SUPER::height;
  return $self->feature->method eq $self->_check_uni ? 3 : $h;
}

sub pad_top {
  my $self = shift;
  return $self->feature->method eq $self->_check_uni ? 0 : 4;
}

sub pad_bottom {
  my $self = shift;
  return $self->feature->method eq $self->_check_uni ? 0 : 4;
}

# we override the draw method so that it dynamically creates the parts needed
# from the wig file rather than trying to fetch them from the database
sub draw {
 
 my $self = shift;
 my ($gd,$dx,$dy) = @_;
 my ($left,$top,$right,$bottom) = $self->calculate_boundaries($dx,$dy);
 my $height   = $bottom - $top;
 my $feature  = $self->feature;
 my $set_flip = $self->option('flip_sign') || 0;

 #Draw individual features for reads (unlike wiggle features reads will have scores)
 my $t_id = $feature->method;
 if($t_id && $t_id eq $self->_check_uni){return Bio::Graphics::Glyph::generic::draw_component($self,@_);}

 #Draw multiple graph if we don't have a score
 my @wiggles = $self->get_wiggles($feature);

 my ($fasta)   = $feature->get_tag_values('fasta');
 my($scale,$y_origin,$min_score,$max_score);

 $self->panel->startGroup($gd);

 #Depending on what we have (wiggle or BigWig) pick the way to paint the signal graph
 for(my $w = 0; $w < @wiggles; $w++){
     if ($w > 0) {
	 $self->configure('bgcolor', NEGCOL);
	 $self->configure('no_grid', 1);
     } else {
	 $self->configure('bgcolor', POSCOL);
     }
     if ($wiggles[$w] =~ /\.wi\w{1,3}$/) {
	 $self->draw_wigfile($feature,$wiggles[$w],@_);
     } elsif ($wiggles[$w] =~ /\.bw$/) {
	 my $flip = ($w > 0 && $set_flip) ? -1 : 1;
	 eval "require Bio::DB::BigWig;1" or die $@;
	 eval "require Bio::DB::Sam; 1"   or die $@;
	 my @args = (-bigwig => "$wiggles[$w]");
	 push @args,(-fasta  => Bio::DB::Sam::Fai->open($fasta)) if $fasta;
	 my $wig = Bio::DB::BigWig->new(@args);
	 my ($summary) = $wig->features(-seq_id => $feature->segment->ref,
					-start  => $self->panel->start,
					-end    => $self->panel->end,
					-type   => 'summary');
	 my $stats = $summary->statistical_summary($self->width);
	 my $interval_method = $self->option('interval_method') || 'mean';
	 my @vals;
	 if ($interval_method eq 'mean') {
		@vals  = map {$_->{validCount} ? $_->{sumData}/$_->{validCount} * $flip : undef} @$stats;
	 }
	 elsif ($interval_method eq 'sum') {
		@vals  = map {$_->{validCount} ? $_->{sumData} * $flip : undef} @$stats;
	 }
	 elsif ($interval_method eq 'min') {
		@vals  = map {$_->{validCount} ? $_->{minVal} * $flip : undef} @$stats;
	 }
	 elsif ($interval_method eq 'max') {
		@vals  = map {$_->{validCount} ? $_->{maxVal} * $flip : undef} @$stats;
	 }
	 else {
		warn "unrecognized interval method $interval_method!";
	 }
	 $self->_draw_coverage($summary,\@vals,@_);
     }
 }
}

sub get_wiggles {
    my $self = shift;
    my $feature = shift;
    my @wiggles;
    foreach ('A'..'Z') {
	my $filename = 'wigfile'.$_;
	my ($wiggle) = $feature->get_tag_values('wigfile'.$_);
	push (@wiggles, $wiggle) if $wiggle;
    }
    return @wiggles;
}

sub minmax {
    my $self   = shift;
    my $parts  = shift;

    my $autoscale  = $self->option('autoscale') || 'local';
    my $set_flip = $self->option('flip_sign') || 0;

    my $min_score  = $self->min_score  unless $autoscale eq 'z_score';
    my $max_score  = $self->max_score  unless $autoscale eq 'z_score';

    my $do_min     = !defined $min_score;
    my $do_max     = !defined $max_score;

    my @wiggles = $self->get_wiggles($self->feature);
    my ($min,$max,$mean,$stdev);
    my @args = (-seq_id => (eval{$self->feature->segment->ref}||''),
		-start  => $self->panel->start,
		-end    => $self->panel->end,
		-type   => 'summary');
    
    for my $w (@wiggles) {
	my ($a,$b,$c,$d);
	if ($w =~ /\.bw$/) {
	    eval "require Bio::DB::BigWig;1" or die $@;
	    my $wig = Bio::DB::BigWig->new(-bigwig=>$w) or next;
	    ($a,$b,$c,$d) = $self->bigwig_stats($autoscale,$wig->features(@args));
	} elsif ($w =~ /\.wi\w{1,3}$/) {
	    eval "require Bio::Graphics::Wiggle;1" or die $@;
	    my $wig = Bio::Graphics::Wiggle->new($w);
	    ($a,$b,$c,$d) = $self->wig_stats($autoscale,$wig);
	}
	$min    = $a if !defined $min || $min > $a;
	$max    = $b if !defined $max || $max < $b;
	$mean  += $c;
	$stdev += $d**2;
    }
    $stdev = sqrt($stdev);
    $min = $max * -1 if ($set_flip);

    $min_score = $min if $do_min;
    $max_score = $max if $do_max;
    return $self->sanity_check($min_score,$max_score,$mean,$stdev);
}

1;
__END__

=head1 NAME

Bio::Graphics::Glyph::hybrid_plot - An xyplot plot drawing dual graph using data from two or more wiggle files per track

=head1 SYNOPSIS

See <Bio::Graphics::Panel> <Bio::Graphics::Glyph> and <Bio::Graphics::Glyph::wiggle_xyplot>.

=head1 DESCRIPTION

Note that for full functionality this glyph requires Bio::Graphics::Glyph::generic (generic glyph is used for drawing individual
matches for small RNA alignments at a high zoom level, specified by semantic zooming in GBrowse conf file)
Unlike the regular xyplot, this glyph draws two overlapping graphs
using value data in Bio::Graphics::Wiggle file format:

track type=wiggle_0 name="Experiment" description="snRNA seq data" visibility=pack viewLimits=-2:2 color=255,0,0 altColor=0,0,255 windowingFunction=mean smoothingWindow=16
 
 2L 400 500 0.5
 2L 501 600 0.5
 2L 601 700 0.4
 2L 701 800 0.1
 2L 800 900 0.1
  
##gff-version 3

2L      Sample_rnaseq  rnaseq_wiggle 41   3009 . . . ID=Samlpe_2L;Name=Sample;Note=YourNoteHere;wigfileA=/datadir/track_001.2L.wig;wigfileB=/datadir/track_002.2L.wig
  

The "wigfileA" and "wigfileB" attributes give a relative or absolute pathname to 
Bio::Graphics::Wiggle format files for two concurrent sets of data. Basically,
these wigfiles contain the data on signal intensity (counts) for sequences 
aligned with genomic regions. In wigfileA these data are additive, so for each
sequence region the signal is calculated as a sum of signals from overlapping
matches (signal). In wigfileB the signal represents the maximum value among all 
sequences (signal quality) aligned with the current region so the user can see
the difference between accumulated signal from overlapping multiple matches 
(which may likely be just a noise from products of degradation) and high-quality 
signal from unique sequences.

For a third wiggle file use the attribute "wigfileC" and so forth.
 
It is essential that wigfile entries in gff file do not have score, because
score used to differentiate between data for dual graph and data for matches
(individual features visible at higher magnification). After an update to
wiggle_xyplot code colors for dual plot are now hard-coded (blue for signal and
orange for signal quality). Alpha channel is also handled by wiggle_xyplot code now.

=head2 OPTIONS

In addition to some of the wiggle_xyplot glyph options, the following options are
recognized:

 Name        Value        Description
 ----        -----        -----------

 wigfileA    path name    Path to a Bio::Graphics::Wiggle file for accumulated vales in 10-base bins

 wigfileB    path name    Path to a Bio::Graphics::Wiggle file for max values in 10-base bins

 fasta       path name    Path to fasta file to enable BigWig drawing

 u_method    method name  Use method of [method name] to identify individual features (like alignment matches) 
                          to show at high zoom level. By default it is set to 'match'    

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

Peter Ruzanov E<lt>pruzanov@oicr.on.caE<gt>.

Copyright (c) 2008 Ontario Institute for Cancer Research

This package and its accompanying libraries is free software; you can
redistribute it and/or modify it under the terms of the GPL (either
version 1, or at your option, any later version) or the Artistic
License 2.0.  Refer to LICENSE for the full license text. In addition,
please see DISCLAIMER.txt for disclaimers of warranty.

=cut
