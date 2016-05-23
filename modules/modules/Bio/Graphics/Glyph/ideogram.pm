package Bio::Graphics::Glyph::ideogram;

# Glyph to draw chromosome ideograms

use strict qw/vars refs/;
use vars '@ISA';
use GD;

use base qw(Bio::Graphics::Glyph::generic Bio::Graphics::Glyph::heat_map);

sub my_description {
    return <<END;
This glyph draws a section of a chromosome ideogram. It relies
on certain data from the feature to determine which color should
be used (stain) and whether the segment is a telomere or 
centromere or a regular cytoband. See the full manual page for this
glyph for instructions on formatting the ideogram.
END
}
sub my_options {
    {
	bgcolor => [
	    'string',

	    ' gneg:white gpos25:silver gpos50:gray gpos:gray  gpos75:darkgray gpos100:black acen:cen gvar:var',

	    'This option is redefined to map each chromosome band\'s "stain" attribute',
	    'into a color or pattern. The default value is saying to use ',
	    '"white" for features whose stain attribute is',
	    '"gneg", "silver" for those whose stain attribute is "gpos25", and so',
	    'on. Several special values are recognized: "B<stalk>" draws a narrower',
	    'gray region and is usually used to indicate an acrocentric',
	    'stalk. "B<var>" creates a diagonal black-on-white pattern if B<-pattern> is enabled.',
	    '"B<cen>" draws a centromere.',
	    'If -bgcolor is just a color name, like "yellow", the glyph will ignore',
	    'all bands and just draw a filled in chromosome.'],
	 bgfallback => [
		'color',
		'yellow',
		'Color to use when no bands are present.'],
         pattern => [
	     'boolean',
	     undef,
	     'Enable drawing a vertical line pattern for centromeres and "var" regions.',
	     'This is off by default due to an intermittent gd2 library crash on certain 64-bit platforms.'],
    }
}
sub demo_feature {
    my $self     = shift;
    my $data     = <<END;
##gff-version 3
22	ensembl	chromosome	1	500	.	.	.	ID=22;Name=Chr22
22	ensembl	chromosome_band	1	30	.	.	.	Parent=22;Name=p13;Alias=22p13;Stain=gvar
22	ensembl	chromosome_band	31	66	.	.	.	Parent=22;Name=p12;Alias=22p12;Stain=stalk
22	ensembl	chromosome_band	67	97	.	.	.	Parent=22;Name=p11.2;Alias=22p11.2;Stain=gvar
22	ensembl	centromere	98	164	.	.	.	Parent=22;Name=22_cent;Alias=2222_cent
22	ensembl	chromosome_band	165	206	.	.	.	Parent=22;Name=q11.21;Alias=22q11.21;Stain=gneg
22	ensembl	chromosome_band	207	220	.	.	.	Parent=22;Name=q11.22;Alias=22q11.22;Stain=gpos25
22	ensembl	chromosome_band	221	245	.	.	.	Parent=22;Name=q11.23;Alias=22q11.23;Stain=gneg
22	ensembl	chromosome_band	246	281	.	.	.	Parent=22;Name=q12.1;Alias=22q12.1;Stain=gpos50
22	ensembl	chromosome_band	282	307	.	.	.	Parent=22;Name=q12.2;Alias=22q12.2;Stain=gneg
22	ensembl	chromosome_band	308	361	.	.	.	Parent=22;Name=q12.3;Alias=22q12.3;Stain=gpos50
22	ensembl	chromosome_band	362	396	.	.	.	Parent=22;Name=q13.1;Alias=22q13.1;Stain=gneg
22	ensembl	chromosome_band	397	430	.	.	.	Parent=22;Name=q13.2;Alias=22q13.2;Stain=gpos50
22	ensembl	chromosome_band	431	472	.	.	.	Parent=22;Name=q13.31;Alias=22q13.31;Stain=gneg
22	ensembl	chromosome_band	473	482	.	.	.	Parent=22;Name=q13.32;Alias=22q13.32;Stain=gpos50
22	ensembl	chromosome_band	483	500	.	.	.	Parent=22;Name=q13.33;Alias=22q13.33;Stain=gneg
END
;
    eval "require Bio::Graphics::FeatureFile"
	unless Bio::Graphics::FeatureFile->can('new');
    my $db = Bio::Graphics::FeatureFile->new(-text=>$data) or die;
    return $db->get_features_by_name('Chr22');
}

sub bgfallback {
    my $self = shift;
    return $self->option('bgfallback') || 'yellow';
}

sub bgcolor {
    my $self    = shift;
    my $bgcolor  = $self->option('bgcolor');
    return $bgcolor if defined $bgcolor;
    return 'gneg:white gpos25:silver gpos50:gray gpos:gray  gpos75:darkgray gpos100:black acen:cen gvar:var';
}

sub can_pattern {
    my $self = shift;
    return unless $self->option('pattern');
    return  $self->panel->image_class !~ /svg/i;
}

sub draw {
  my $self = shift;
  my ($gd,$left,$top,$partno,$total_parts) = @_;

  my $fstart = $self->feature->start;
  my $fstop  = $self->feature->end;

  my @parts = $self->parts;

  # Draw the sides for the whole chromosome (in case
  # there are missing data).
  $self->draw_component(@_) if $self->level == 0;

  if (@parts) {
      $left += $self->left + $self->pad_left;
      $top  += $self->top  + $self->pad_top;
  } else {
      @parts    = ($self);
  }

  # Make unaggregated bands invisible if requested.
  # This is for making image maps for individual
  # bands of whole aggregate chromosomes.
  $self->{invisible} ||= $self->option('invisible') 
      unless @parts > 1;

  $parts[0]->{single}++ if @parts == 1;

  # if the bands are subfeatures of an aggregate chromosome,
  # we can draw the centomere and telomeres last to improve
  # the appearance

  my @last;
  for my $part (@parts) {
    push @last, $part and next if
        $part->feature->primary_tag =~ /centromere/i ||
	$part->feature->start      <= $fstart ||
	$part->feature->end        >= $fstop;
    my $tile = $part->create_tile('left');
    $part->draw_component($gd,$left,$top);
  }

  for my $part (@last) {
    my $tile;
    if ($part->feature->method =~ /centromere/) {
      $tile = $self->create_tile('right');
    }

    else {
      $tile = $part->create_tile('left');
    }
    my $status =  $part->{single}                        ? 'single'
	        : $part->feature->method =~ /centromere/ ? 'centromere'
                : $part->feature->start <= $fstart       ? 'left telomere'
		: $part->feature->end   >= $fstop        ? 'right telomere'
                : undef;
    $part->draw_component($gd,$left,$top,$status);
  }


  $self->draw_label(@_)       if $self->option('label');
  $self->draw_description(@_) if $self->option('description');
}

sub draw_component {
  my $self = shift;
  my $gd   = shift;
  my ($x,$y,$status) = @_;

  my $feat = $self->feature;

  my $arcradius = $self->option('arcradius') || 7;
  my ($x1, $y1, $x2, $y2 ) = $self->bounds(@_);

  return if $x2 <= $self->panel->left;
  return if $x1 >= $self->panel->right;

  $x2 = $self->panel->right if $x2 > $self->panel->right;

  # force odd width so telomere arcs are centered
  $y2 ++ if ($y2 - $y1) % 2;

  my ($stain) = $feat->get_tag_values('stain');
  ($stain)    = $feat->get_tag_values('Stain') unless $stain;

  # Some genome sequences don't contain substantial telomere sequence (i.e. Arabidopsis)
  # We can suggest their presence at the tips of the chromosomes by setting fake_telomeres = 1
  # in the configuration file, resulting in the tips of the chromosome being painted black.
  my $fake_telomeres = $self->option('fake_telomeres') || 0;

  my $bgcolor_index = $self->bgcolor;

  if ((my $fallback = $self->bgfallback) && !$stain) {
      $bgcolor_index = $fallback;
  }
  elsif ($bgcolor_index =~ /\w+:/) {
      ($bgcolor_index)        = $self->bgcolor =~ /$stain:(\S+)/ if $stain;
      ($bgcolor_index,$stain) = qw/white none/ if !$stain;
  }

  my $black = $gd->colorAllocate( 0, 0, 0 );
  my $cm_color  = $self->{cm_color}  ||= $self->cm_color;
  my $var_color = $self->{var_color} ||= $self->var_color;

  my $bgcolor = $self->factory->translate_color($bgcolor_index);
  my $fgcolor = $self->fgcolor;

  # special color for gvar bands
  if ( $bgcolor_index =~ /var/) {
      $bgcolor = $self->can_pattern ? gdTiled : $var_color;
  }

  if ( $feat->method !~ /centromere/i && $stain ne 'acen') {

    # are we at the end of the chromosome?
    if (($status eq 'single' || $status eq 'left telomere') && $stain ne 'tip') {

      # left telomere
      my $state = $status eq 'single' ? -1 
                 : $self->panel->flip ? 0 : 1;

      $bgcolor = $black if $fake_telomeres;
      $self->draw_telomere( $gd, $x1, $y1, $x2, $y2, 
			    $bgcolor, $fgcolor,
			    $arcradius, $state );
    }
    elsif ($status eq 'right telomere' && $stain ne 'tip') {
      # right telomere
      my $state = $self->panel->flip ? 1 : 0;
      $bgcolor   = $black if $fake_telomeres;
      $self->draw_telomere( $gd, $x1, $y1, $x2, $y2, $bgcolor, $fgcolor,
        $arcradius, $state );
    }

    # or a stalk?
    elsif ( $stain eq 'stalk') {
      $self->draw_stalk( $gd, $x1, $y1, $x2, $y2, $bgcolor, $fgcolor );
    }

    # or a regular band?
    else {
      $self->draw_cytoband( $gd, $x1, $y1, $x2, $y2, $bgcolor, $fgcolor );
      $self->draw_outline( $gd,$x1,$y1,$x2,$y2,$bgcolor,$fgcolor) if $bgcolor_index =~ /var/i;
    }
  }

  # or a centromere?
  else {
    if ( $self->can_pattern ) {
      my $tile = $self->create_tile('right');
      $self->draw_centromere( $gd, $x1, $y1, $x2, $y2, gdTiled, $fgcolor );
    }
    else {
      $self->draw_centromere( $gd, $x1, $y1, $x2, $y2, $cm_color, $fgcolor );
    }
  }

}

sub draw_cytoband {
  my $self = shift;
  my ( $gd, $x1, $y1, $x2, $y2, $bgcolor, $fgcolor) = @_;

  # draw the filled box
  $self->filled_box($gd,$x1,$y1,$x2,$y2,$bgcolor,$bgcolor);   
  # outer border
  $gd->line($x1,$y1,$x2,$y1,$fgcolor);
  $gd->line($x1,$y2,$x2,$y2,$fgcolor);
}

sub draw_outline {
  my $self = shift;
  my ( $gd, $x1, $y1, $x2, $y2, $bgcolor, $fgcolor) = @_;

  # side borders
  $gd->line($x1,$y1,$x1,$y2,$fgcolor);
  $gd->line($x2,$y1,$x2,$y2,$fgcolor);
}

sub draw_centromere {
  my $self = shift;
  my ( $gd, $x1, $y1, $x2, $y2, $bgcolor, $fgcolor ) = @_;

  # blank slate
  $self->wipe(@_);

  # draw a sort of hour-glass shape to represent the centromere
  my $poly = GD::Polygon->new;
  $poly->addPt( $x1, $y1 );
  $poly->addPt( $x1, $y2 );
  $poly->addPt( $x2, $y1 );
  $poly->addPt( $x2, $y2 );

  $gd->filledPolygon( $poly, $bgcolor );    # filled
  $gd->line( $x2 - 1, $y1 + 1, $x2 - 1, $y2 - 1, $fgcolor );
  $gd->polygon( $poly, $fgcolor );          # outline
}

sub draw_telomere {
  my $self = shift;
  my ($gd, $x1, $y1, $x2, $y2,
      $bgcolor, $fgcolor, $arcradius, $state ) = @_;

  # blank slate 
  $self->wipe(@_);

  # For single, unaggregated bands, make the terminal band
  # a bit wider to accomodate the arc
  if ($self->{single}) {
    $x1 -= 5 if $state == 1;
    $x2 += 5 if $state == 0;
  }

  # state should be one of:
  # 0 right telomere
  # 1 left telomere
  # -1 round at both ends (whole chromosome)
  my $outline++ if $state == -1;

  my $arcsize = $y2 - $y1;
  my $bwidth  = $x2 - $x1;
  my $new_x1  = $x1 + $arcradius - 1;
  my $new_x2  = $x2 - $arcradius;
  my $new_y   = $y1 + int($arcsize/2 + 0.5);
  
  my $orange = $self->panel->translate_color('lemonchiffon');
  my $bg     = $self->panel->bgcolor;

  $self->draw_cytoband( $gd, $x1, $y1, $x2, $y2, $bgcolor, $fgcolor );
  $self->draw_outline(  $gd, $x1, $y1, $x2, $y2, $bgcolor, $fgcolor );
  if ( $state ) {    # left telomere
    my $x = $new_x1;
    my $y = $new_y;

    # erase extra stuff
    $gd->line($x1,$y1,$x1+5,$y1,$bg);
    $gd->line($x1,$y1,$x1,$y2,$bg);
    $gd->line($x1,$y2,$x1+5,$y2,$bg);

    $gd->arc( $x, $y, $arcradius * 2,
	      $arcsize, 90, 270, $fgcolor);

    # erase off-target colors
    $gd->fill($x1+1,$y1+1,$bg);
    $gd->fill($x1+1,$y2-1,$bg);
  }
  
  if ( $state < 1 ) {    # right telomere
    my $x = $new_x2;
    my $y = $new_y;

    # erase extra stuff
    $gd->line($x2-5,$y1,$x2,$y1,$bg);
    $gd->line($x2,$y1,$x2,$y2,$bg);
    $gd->line($x2-5,$y2,$x2,$y2,$bg);

    $gd->arc( $x, $y, $arcradius * 2,
	      $arcsize, 270, 90, $fgcolor);

    # erase off-target colors
    $gd->fill($x2-1,$y1+1,$bg);
    $gd->fill($x2-1,$y2-1,$bg);
  }

  unless ( $self->can_pattern ) {
    $self->draw_cytoband( $gd, $new_x1 - 1, $y1 + 2, 
			       $new_x1 + 1, $y2 - 2, 
			       $bgcolor, $bgcolor );
  }
}

# for acrocentric stalk structure, draw a narrower cytoband
sub draw_stalk {
  my $self = shift;
  my ( $gd, $x1, $y1, $x2, $y2, $bgcolor, $fgcolor, $inset ) = @_;
  
  # blank slate
  $self->wipe(@_);

  my $height = $self->height;
  $inset ||= $height > 10 ? int( $height / 10 + 0.5 ) : 2;
  $_[2] += $inset;
  $_[4] -= $inset;
  $self->draw_cytoband(@_);

  $gd->line( $x1,   $y1, $x1,   $y2, $fgcolor );
  $gd->line( $x2,   $y1, $x2,   $y2, $fgcolor );
}

sub create_tile {
  my $self      = shift;
  my $direction = shift;

  my $gd = $self->panel->gd;
  return unless $gd->can('setTile');

  # Prepare tile to use for filling an area
  my $tile;
  if ( $direction eq 'right' ) {
    $tile     = GD::Image->new(3,3);
    my $black = $tile->colorAllocate(0,0,0);
    my $white = $tile->colorAllocate(255,255,255);
    $tile->filledRectangle(0, 0, 3, 3, $white);
    $tile->line( 0, 0, 3, 3, $black);
  }
  elsif ( $direction eq 'left' ) {
    $tile = GD::Image->new(4,4);
    my $black = $tile->colorAllocate(0,0,0);
    my $white = $tile->colorAllocate(255,255,255);
    $tile->filledRectangle(0,0,4,4, $white);
    $tile->line( 4, 0, 0, 4, $black);
  }

  $gd->setTile($tile);
  return $tile;
}

# This overrides the Glyph::parts method until I
# can figure out how the bands get mangled there
sub parts {
  my $self  = shift;
  my $f     = $self->feature;
  my $level = $self->level + 1;
  my @subf  = sort {$a->start <=> $b->start} $f->get_SeqFeatures;
  return  $self->factory->make_glyph($level,@subf);
}

# erase anthing that might collide.  This is for
# clean telomeres, centromeres and stalks
sub wipe {
  my $self = shift;
  my $whitewash = $self->panel->bgcolor;
  $self->filled_box(@_[0..4],$whitewash,$whitewash);
}

# Disable bumping entirely, since it messes up the ideogram
sub bump { return 0; }

sub cm_color {
    my $self    = shift;
    my $bgcolor = $self->bgcolor;
    my ($c)     = $bgcolor =~ /cen:(\S+)/;
    $c         ||= 'lightgrey';
    return $self->translate_color($c);
}

sub var_color {
    my $self    = shift;
    my $bgcolor = $self->bgcolor;
    my ($c)     = $bgcolor =~ /var:(\S+)/;
    $c         ||= '#805080';
    return $self->translate_color($c);
}

1;

__END__

=head1 NAME

Bio::Graphics::Glyph::ideogram - The "ideogram" glyph

=head1 SYNOPSIS

  See L<Bio::Graphics::Panel> and L<Bio::Graphics::Glyph>.

=head1 DESCRIPTION

This glyph draws a section of a chromosome ideogram. It relies on
certain data from the feature to determine which color should be used
(stain) and whether the segment is a telomere or centromere or a
regular cytoband. The centromeres and 'var'-marked bands are rendered
with diagonal black-on-white patterns if the "-patterns" option is
true, otherwise they are rendered in dark gray. This is to prevent a
libgd2 crash on certain 64-bit platforms when rendering patterned
images.

The cytobandband features would typically be formatted like this in GFF3:

 ...
 ChrX    UCSC    cytoband        136700001       139000000       .       .       .       Parent=ChrX;Name=Xq27.1;Alias=ChrXq27.1;stain=gpos75;
 ChrX    UCSC    cytoband        139000001       140700000       .       .       .       Parent=ChrX;Name=Xq27.2;Alias=ChrXq27.2;stain=gneg;
 ChrX    UCSC    cytoband        140700001       145800000       .       .       .       Parent=ChrX;Name=Xq27.3;Alias=ChrXq27.3;stain=gpos100;
 ChrX    UCSC    cytoband        145800001       153692391       .       .       .       Parent=ChrX;Name=Xq28;Alias=ChrXq28;stain=gneg;
 ChrY    UCSC    cytoband        1       1300000 .       .       .       Parent=ChrY;Name=Yp11.32;Alias=ChrYp11.32;stain=gneg;

 which in this case is a GFF-ized cytoband coordinate file from UCSC:

 http://hgdownload.cse.ucsc.edu/goldenPath/hg16/database/cytoBand.txt.gz

 and the corresponding GBrowse config options would be like this to 
 create an ideogram overview track for the whole chromosome:

 The 'chromosome' feature below would aggregated from bands and centromere using the default 
 chromosome aggregator

 [CYT:overview]
 feature       = chromosome
 glyph         = ideogram
 fgcolor       = black
 bgcolor       = gneg:white gpos25:silver gpos50:gray 
                 gpos:gray  gpos75:darkgray gpos100:black acen:cen gvar:var
 arcradius     = 6
 height        = 25
 bump          = 0
 label         = 0

 A script to reformat UCSC annotations to  GFF3 format can be found at
 the end of this documentation.

=head2 OPTIONS

The following options are standard among all Glyphs.  See
L<Bio::Graphics::Glyph> for a full explanation.

  Option      Description                      Default
  ------      -----------                      -------

  -fgcolor      Foreground color	       black

  -outlinecolor	Synonym for -fgcolor

  -linewidth    Line width                     1

  -height       Height of glyph		       10

  -font         Glyph font		       gdSmallFont

  -connector    Connector type                 0 (false)

  -connector_color
                Connector color                black

  -label        Whether to draw a label	       0 (false)

  -description  Whether to draw a description  0 (false)

The following options are specific to the ideogram glyph.


  Option      Description                      Default
  ------      -----------                      -------

  -bgcolor    Band coloring string	       none
  
  -bgfallback Coloring to use when no bands    yellow
                 are present

B<-bgcolor> is used to map each chromosome band's "stain" attribute
into a color or pattern. It is a string that looks like this:

  gneg:white gpos25:silver gpos50:gray \
  gpos:gray  gpos75:darkgray gpos100:black acen:cen gvar:var

This is saying to use "white" for features whose stain attribute is
"gneg", "silver" for those whose stain attribute is "gpos25", and so
on. Several special values are recognized: "B<stalk>" draws a narrower
gray region and is usually used to indicate an acrocentric
stalk. "B<var>" creates a diagonal black-on-white pattern. "B<cen>"
draws a centromere.

If -bgcolor is just a color name, like "yellow", the glyph will ignore
all bands and just draw a filled in chromosome.

If -bgfallback is set to a color name or value, then the glyph will
fall back to the indicated background color if the chromosome contains
no bands.

=head1 UCSC TO GFF CONVERSION SCRIPT

The following short script can be used to convert a UCSC cytoband annotation file
into GFF format.  If you have the lynx web-browser installed you can
call it like this in order to download and convert the data in a
single operation:

  fetchideogram.pl http://hgdownload.cse.ucsc.edu/goldenPath/hg18/database/cytoBand.txt.gz

Otherwise you will need to download the file first. Note the difference between this script
and input data from previous versions of ideogram.pm: UCSC annotations are used in place
of NCBI annotations.


#!/usr/bin/perl

use strict;
my %stains;
my %centros;
my %chrom_ends;


foreach (@ARGV) {
    if (/^(ftp|http|https):/) {
	$_ = "lynx --dump $_ |gunzip -c|";
    } elsif (/\.gz$/) {
	$_ = "gunzip -c $_ |";
    }
    print STDERR "Processing $_\n";
}

print "##gff-version 3\n";
while(<>)
{
    chomp;
    my($chr,$start,$stop,$band,$stain) = split /\t/;
    $start++;
    $chr = ucfirst($chr);
    if(!(exists($chrom_ends{$chr})) || $chrom_ends{$chr} < $stop)
    {
	$chrom_ends{$chr} = $stop;
    }
    my ($arm) = $band =~ /(p|q)\d+/;
    $stains{$stain} = 1;
    if ($stain eq 'acen')
    {
	$centros{$chr}->{$arm}->{start} = $stop;
	$centros{$chr}->{$arm}->{stop} = $start;
	next;
    }
    $chr =~ s/chr//i;
    print qq/$chr\tUCSC\tcytoband\t$start\t$stop\t.\t.\t.\tParent=$chr;Name=$chr;Alias=$chr$band;stain=$stain;\n/;
}

foreach my $chr(sort keys %chrom_ends)
{
    my $chr_orig = $chr;
    $chr =~ s/chr//i;
    print qq/$chr\tUCSC\tcentromere\t$centros{$chr_orig}->{p}->{stop}\t$centros{$chr_orig}->{q}->{start}\t.\t+\t.\tParent=$chr;Name=$chr\_cent\n/;
}



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

Gudmundur A. Thorisson E<lt>mummi@cshl.eduE<gt>

Copyright (c) 2001-2006 Cold Spring Harbor Laboratory

=head1 CONTRIBUTORS

Sheldon McKay E<lt>mckays@cshl.edu<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut







