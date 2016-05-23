package Bio::Graphics::Glyph::segments;

use strict;
use Bio::Location::Simple;

use constant RAGGED_START_FUZZ => 25;  # will show ragged ends of alignments
                                       # up to this many bp.
use constant DEBUG => 0;

# These are just offsets into an array data structure
use constant TARGET    => 0;
use constant SRC_START => 1;
use constant SRC_END   => 2;
use constant TGT_START => 3;
use constant TGT_END   => 4;

eval { require Bio::Graphics::Browser2::Realign; 1; } || eval { require Bio::Graphics::Browser::Realign; };

use base qw(Bio::Graphics::Glyph::segmented_keyglyph Bio::Graphics::Glyph::generic);

my %complement = (g=>'c',a=>'t',t=>'a',c=>'g',n=>'n',
		  G=>'C',A=>'T',T=>'A',C=>'G',N=>'N');

sub my_description {
    return <<END;
This glyph draws multipart genomic features as a series of rectangles connected
by solid lines. If the feature is attached to a DNA sequence, then the glyph will
draw the sequence when magnification is high enough to show individual base pairs.
The glyph is also capable of drawing genomic alignments, and performing protein
translations.
END
}
sub my_options {
    {
	draw_target => [
	    'boolean',
	    undef,
	    'If true, draw the dna residues of the TARGET (aligned) sequence when the',
	    'magnification level allows.',
	    'See L<Bio::Graphics::Glyph::segments/"Displaying Alignments">.'
	    ],
	 draw_protein_target => [
	     'boolean',
	     undef,
	     'If true, draw the protein residues of the TARGET (aligned) sequence when the',
	     'magnification level allows.',
	     'See L<Bio::Graphics::Glyph::segments/"Displaying Alignments">.'],
	  ragged_extra => [
	      'boolean',
	      undef,
	      'When combined with -draw_target, draw extra bases beyond the end',
	      'of the alignment. The value is the maximum number of extra bases.',
	      'See L<Bio::Graphics::Glyph::segments/"Displaying Alignments">.'],
	  show_mismatch => [
	      'integer',
	      undef,
	      'When combined with -draw_target, highlights mismatched bases in',
	      'the mismatch color. A value of 0 or undef never shows mismatches.',
	      'A value of 1 shows mismatches at the base pair alignment level, but',
	      'not at magnifications too low to allow the DNA to be displayed.',
	      'Any other positive integer will show mismatches when the track is showing',
	      'a region less than or equal to the specified value.',
	      'See L<Bio::Graphics::Glyph::segments/"Displaying Alignments">.'],
	  mismatch_color => [
	      'color',
	      'lightgrey',
	      'The color to use for mismatched bases when displaying alignments.',
	      'See L<Bio::Graphics::Glyph::segments/"Displaying Alignments">.'],
	  indel_color => [
	      'color',
	      'lightgrey',
	      'The color to use for indels when displaying alignments.'],
	  insertion_color => [
	      'color',
	      'green',
	      'The color to use for insertions when displaying alignments; overrides indel_color'],
	  deletion_color => [
	      'color',
	      'red',
	      'The color to use for deletions when displaying alignments; overrides indel_color'],
	  mismatch_only => [
	      'boolean',
	      undef,
	      'If true, only print mismatched bases when displaying alignments.'],
	  true_target => [
	      'boolean',
	      undef,
	      'Show the target DNA in its native (plus strand) orientation, even',
	      'if the alignment is to the minus strand.',
	      'See L<Bio::Graphics::Glyph::segments/"Displaying Alignments">.'],
	  split_on_cigar => [
	      'boolean',
	      undef,
	      'If true, and if the feature contains a CIGAR string as the value of the Gap',
	      'tag, then split the feature into subparts based on the CIGAR.'],
	  realign => [
	      'boolean',
	      undef,
	      'Attempt to realign sequences at high magnification to account',
	      'for indels.',
	      'See L<Bio::Graphics::Glyph::segments/"Displaying Alignments">.'],
    }
}

sub mismatch_color {
    my $self = shift;
    my $c    = $self->option('mismatch_color') || 'lightgrey';
    return $self->translate_color($c);
}

sub indel_color {
    my $self = shift;
    my $c    = $self->option('indel_color');
    return $self->mismatch_color unless $c;
    return $self->translate_color($c);
}

sub insertion_color {
    my $self = shift;
    my $c    = $self->option('insertion_color');
    $c     ||= $self->option('indel_color');
    $c     ||= $self->my_options->{insertion_color}[1];
    return $self->translate_color($c);
}

sub deletion_color {
    my $self = shift;
    my $c    = $self->option('deletion_color');
    $c     ||= $self->option('indel_color');
    $c     ||= $self->my_options->{deletion_color}[1];
    return $self->translate_color($c);
}

sub show_mismatch {
    my $self = shift;
    my $smm = $self->option('show_mismatch');
    $smm  ||= 1 if $self->option('mismatch_only');
    return unless $smm;
    return 1 if $smm == 1 && $self->dna_fits;
    return 1 if $smm >= $self->panel->length;
}

sub mismatch_only { shift->option('mismatch_only') }


sub pad_left {
  my $self = shift;
  return $self->SUPER::pad_left unless $self->level > 0;
  my $ragged = $self->option('ragged_start') 
    ? RAGGED_START_FUZZ 
    : $self->option('ragged_extra');

  return $self->SUPER::pad_left 
    unless $self->draw_target && $ragged && $self->dna_fits;
  my $extra = 0;
  my $target = eval {$self->feature->hit} or return $self->SUPER::pad_left + $extra;
  return $self->SUPER::pad_left + $extra unless $target->start<$target->end && $target->start < $ragged;
  return ($target->start-1) * $self->scale + $extra;
}

sub pad_right {
  my $self = shift;
  return $self->SUPER::pad_right unless $self->level > 0;
  my $ragged = $self->option('ragged_start') 
    ? RAGGED_START_FUZZ 
    : $self->option('ragged_extra');
  return $self->SUPER::pad_right 
    unless $self->draw_target && $ragged && $self->dna_fits;
  my $target = eval {$self->feature->hit} or return $self->SUPER::pad_right;
  return $self->SUPER::pad_right unless $target->end < $target->start && $target->start < $ragged;
  return ($target->end-1) * $self->scale;
}

sub labelwidth {
  my $self = shift;
  return $self->SUPER::labelwidth unless $self->draw_target && $self->dna_fits && $self->label_position eq 'left';
  return $self->{labelwidth} ||= (length($self->label||'')+1) * $self->mono_font->width;
}
sub draw_target {
  my $self = shift;
  return if $self->option('draw_dna');
  return $self->option('draw_target');
}

sub draw_protein_target {
  my $self = shift;
  return if $self->option('draw_protein');
  return $self->option('draw_protein_target');
  return $self->option('draw_target');
}

sub height {
  my $self = shift;
  my $height = $self->SUPER::height;
  return $height unless $self->draw_target || $self->draw_protein_target;
  if ($self->draw_target) {
    return $height unless $self->dna_fits;
  }
  if ($self->draw_protein_target) {
    return $height unless $self->protein_fits;
  }
  my $fontheight = $self->mono_font->height;
  return $fontheight if $fontheight > $height;
}

# group sets connector to 'solid'
sub connector {
  my $self = shift;
  return $self->SUPER::connector(@_) if $self->all_callbacks;
  return ($self->SUPER::connector(@_) || 'solid');
}

# never allow our components to bump
sub bump {
  my $self = shift;
  my $bump = $self->SUPER::bump(@_);
  return $bump if $self->all_callbacks;
  return $self->parts_overlap ? $bump : 0;
}

sub maxdepth {
  my $self = shift;
  my $md   = $self->Bio::Graphics::Glyph::maxdepth;
  return $md if defined $md;
  return 1;
}

# this was willfully confusing
#sub fontcolor {
#  my $self = shift;
#  return $self->SUPER::fontcolor unless $self->draw_target;# || $self->option('draw_dna');
#  return $self->SUPER::fontcolor unless $self->dna_fits;
#  return $self->bgcolor;
#}

# Override _subfeat() method to make it appear that a top-level feature that
# has no subfeatures appears as a feature that has a single subfeature.
# Otherwise at high mags gaps will be drawn as components rather than
# as connectors.  Because of differing representations of split features
# in Bio::DB::GFF::Feature and Bio::SeqFeature::Generic, there is
# some breakage of encapsulation here.
sub _subfeat {
    my $self    = shift;
    my $feature = shift;

    my @subfeat = $self->SUPER::_subfeat($feature);

    if (!@subfeat && $self->option('split_on_cigar')) {
	my $cigar   = $self->_get_cigar($feature);
	if ($cigar && @$cigar) {
	    return $self->_split_on_cigar($feature,$cigar);
	}
    }

    return @subfeat if @subfeat;
    if ($self->level == 0 && !@subfeat && !$self->feature_has_subparts) {
	return $self->feature;
    } else {
	return;
    }
}

sub _split_on_cigar {
    my $self = shift;
    my ($feature,$cigar) = @_;

    my $source_start = $feature->start;
    my $source_end   = $feature->end;
    my $ss  = $feature->strand;
    my $ts  = $feature->hit->strand;
    my $target_start = eval {$feature->hit->start} || return $feature;

    my (@parts);

    # BUG: we handle +/+ and -/+ alignments, but not +/- or -/-
    # (i.e. the target has got to have forward strand coordinates)

    # forward strand
    if ($ss >= 0) {  
	for my $event (@$cigar) {
	    my ($op,$count) = @$event;
	    if ($op eq 'I' || $op eq 'S' || $op eq 'H') {
		$target_start += $count;
	    }
	    elsif ($op eq 'D' || $op eq 'N') {
		$source_start += $count;
	    }
	    elsif ($op eq 'P') {
		# Do NOTHING for pads. Irrelevant for pairwise
		# alignments, since we cannot show the pad in
		# the reference sequence
	    } else {  # everything else is assumed to be a match -- revisit
		push @parts,[$source_start,$source_start+$count-1,
			     $target_start,$target_start+$count-1];
		$source_start += $count;
		$target_start += $count;
	    }
	}

    # minus strand
    } else {
	for my $event (@$cigar) {
	    my ($op,$count) = @$event;
	    if ($op eq 'I' || $op eq 'S' || $op eq 'H') {
		$target_start += $count;
	    }
	    elsif ($op eq 'D' || $op eq 'N') {
		$source_end -= $count;
	    }
	    elsif ($op eq 'P') {
		# do nothing for pads
	    } else {  # everything else is assumed to be a match -- revisit
		push @parts,[$source_end-$count+1,$source_end,
			     $target_start,$target_start+$count-1];
		$source_end   -= $count;
		$target_start += $count;
	    }
	}
	
    }

    my $id  = $feature->seq_id;
    my $tid = $feature->hit->seq_id;
    my @result = map {
	my ($s1,$s2,$t1,$t2) = @$_;
	my $s = Bio::Graphics::Feature->new(-seq_id=> $id,
					    -start => $s1,
					    -end   => $s2,
					    -strand => $ss,
	    );
	my $h = Bio::Graphics::Feature->new(-seq_id=> $tid,
					    -start => $t1,
					    -end   => $t2,
					    -strand => $ts,
	    );
	$s->add_hit($h);
	$s;
    } @parts;
    return @result;
}

sub draw {
  my $self = shift;

  my $draw_target         = $self->draw_target && $self->dna_fits && eval {$self->feature->hit->seq};
  
  $self->SUPER::draw(@_);

  return if $self->feature_has_subparts;
  return unless $draw_target;

  my $drew_sequence;
  $drew_sequence = $self->draw_multiple_alignment(@_);

  my ($gd,$x,$y) = @_;
  $y  += $self->top + $self->pad_top if $drew_sequence;  # something is wrong - this is a hack/workaround
  my $connector     =  $self->connector;
  $self->draw_connectors($gd,$x,$y)
    if $connector && $connector ne 'none' && $self->level == 0;
}

sub draw_component {
    my $self = shift;
    my ($gd,$left,$top,$partno,$total_parts) = @_;
    my ($x1,$y1,$x2,$y2) = $self->bounds($left,$top);

    my $draw_target;
    my $strand   = $self->feature->strand;

    if ($self->draw_target && $self->dna_fits) {
	$draw_target++;
	my $stranded = $self->stranded;
	my $bgcolor  = $self->bgcolor;
	if ($stranded) {
	    $x1 -= 6 if $strand < 0 && $x1 >= $self->panel->left;
	    $x2 += 6 if $strand > 0 && $x2 <= $self->panel->right;
	    $self->filled_arrow($gd,$strand,$x1,$y1,$x2,$y2)
	} else {
	    $self->filled_box($gd,$x1,$y1,$x2,$y2,$bgcolor,$bgcolor);
	}
    } else {
	$self->SUPER::draw_component(@_);
    }

    return unless $self->show_mismatch;
    my $mismatch_color = $self->mismatch_color;
    my $feature = $self->feature;
    my $start   = $self->feature->start;
    my $end     = $feature->end;
    my (@mismatch_positions,@del_positions,@in_positions);

    if (my ($src,$matchstr,$tgt) = eval{$feature->padded_alignment}) {
	my @src   = split '',$src;
	my @match = split '',$matchstr;
	my @tgt   = split '',$tgt;
	my $pos   = $start;

	# skip over src padding (probably soft clipped)
	while ($src[0] eq '-') { 
	    shift @src; 
	    shift @tgt; 
	}
	while ($src[-1] eq '-') {
	    pop @src;
	    pop @tgt;
	}

	for (my $i=0;$i<@src;$i++) {
	    if ($src[$i] eq '-') {
		push @in_positions,$pos;
	    }
	    elsif ($tgt[$i] eq '-') {
		push @del_positions,$pos;
		$pos++;
	    } elsif ($src[$i] ne $tgt[$i]) {
		push @mismatch_positions,$pos;
		$pos++;
	    } else {
		$pos++;
	    }
	}
    }

    else {
	my $sdna = eval {$feature->dna};
	my $tdna = eval {$feature->target->dna};  # works with GFF files

	return unless $sdna =~ /[gatc]/i;
 	return unless $tdna =~ /[gatc]/i;

	my @src = split '',$sdna;
	my @tgt = split '',$tdna;
	for (my $i=0;$i<@src;$i++) {
	    next if $src[$i] eq $tgt[$i];
	    warn "$src[$i] eq $tgt[$i], strand=$strand";
	    my $pos = $strand >= 0 ? $i+$start : $end-$i;
	    push @mismatch_positions,$pos;
	}
    }

    my $pixels_per_base      = $self->scale;
    my $panel_right          = $self->panel->right;
    
    for my $a ([\@mismatch_positions,$self->mismatch_color],
	       [\@del_positions,$self->deletion_color],
	       [\@in_positions,$self->insertion_color,0.5,0.5]
	) {

	my $color            = $a->[1];
	my $offset           = $a->[2]||0;
	my $width            = $a->[3]||1;
	my @pixel_positions = $self->map_no_trunc(@{$a->[0]});

	foreach (@pixel_positions) {
	    next if $_ < $x1;
	    next if $_ > $x2;
	    next if $_ >= $panel_right;
	    my $left  = $_ - $pixels_per_base*$offset;
	    my $right = $left+($width*$pixels_per_base);
	    my $top   = $y1+1;
	    my $bottom= $y2-1;
	    my $middle= ($y1+$y2)/2;
	    if ($self->stranded && $left <= $x1+$pixels_per_base-1 && $self->strand < 0) {
		$self->filled_arrow($gd,$self->strand,
				    $draw_target ? ($left-4):$left+2,
				    $top,
				    $draw_target ? $right:$right+5,$bottom,$color,$color,1);
	    } elsif ($self->stranded && $right >= $x2-$pixels_per_base+1 && $self->strand > 0) {
		$self->filled_arrow($gd,$self->strand,
				    $left,$top,$draw_target ? ($right+4): $right-2,$bottom,$color,$color,1);
	    } else {
		$self->filled_box($gd,
				  $left,
				  $top,
				  $right,
				  $bottom,
				  $color,$color);
	    }
	}
    }
}

# BUG: this horrible subroutine has grown without control and needs
# to be broken down into manageable subrutines.
sub draw_multiple_alignment {
  my $self = shift;
  my $gd   = shift;
  my ($left,$top,$partno,$total_parts) = @_;

  my $flipped              = $self->flip;
  my $ragged_extra         = $self->option('ragged_start') 
                               ? RAGGED_START_FUZZ : $self->option('ragged_extra');
  my $true_target          = $self->option('true_target');
  my $show_mismatch        = $self->show_mismatch;
  my $do_realign           = $self->option('realign');

  my $pixels_per_base      = $self->scale;
  my $feature              = $self->feature;

  my $panel                = $self->panel;
  my ($abs_start,$abs_end)     = ($feature->start,$feature->end);
  my ($tgt_start,$tgt_end)     = ($feature->hit->start,$feature->hit->end);
  my ($panel_start,$panel_end) = ($self->panel->start,$self->panel->end);
  my $strand               = $feature->strand;
  my $panel_left           = $self->panel->left;
  my $panel_right          = $self->panel->right;
  my $bgcolor              = $self->bgcolor;

  my $drew_sequence;

  if ($tgt_start > $tgt_end) { #correct for data problems
    $strand    = -1;
    ($tgt_start,$tgt_end) = ($tgt_end,$tgt_start);
  }

  warn "TGT_START..TGT_END = $tgt_start..$tgt_end" if DEBUG;

  my ($bl,$bt,$br,$bb)     = $self->bounds($left,$top);
  $top = $bt;

  my $stranded = $self->stranded;

  my @s                     = $self->_subfeat($feature);

  # FIX ME
  # workaround for features in which top level feature does not have a hit but
  # subfeatures do. There is total breakage of encapsulation here because sometimes
  # a chado alignment places the aligned segment in the top-level feature, and sometimes
  # in the child feature.
  unless (@s) {            # || $feature->isa('Bio::DB::GFF::Feature')) {
    @s = ($feature);
  }

  my $can_realign;
  if (Bio::Graphics::Browser2::Realign->can('align_segs')) {
      $can_realign   = \&Bio::Graphics::Browser2::Realign::align_segs;
  } elsif (Bio::Graphics::Browser::Realign->can('align_segs')) {
      $can_realign   = \&Bio::Graphics::Browser::Realign::align_segs;
  }

  my (@segments,%strands);
  my ($ref_dna,$tgt_dna);

  for my $s (@s) {

    my $target = $s->hit;
    my ($src_start,$src_end) = ($s->start,$s->end);
#    next unless $src_start <= $panel_end && $src_end >= $panel_start;

    my ($tgt_start,$tgt_end) = ($target->start,$target->end);

    my $strand_bug;
    unless (exists $strands{$target}) {
      my $strand = $feature->strand;
      if ($tgt_start > $tgt_end) { #correct for data problems
	$strand    = -1;
	($tgt_start,$tgt_end) = ($tgt_end,$tgt_start);
	$strand_bug++;
      }
      $strands{$target} = $strand;
    }

    my $cigar = $self->_get_cigar($s);
    if ($cigar || ($can_realign && $do_realign)) {
	($ref_dna,$tgt_dna) = ($s->dna,$target->dna);
	warn "$s: ",$s->seq_id,":",$s->start,'..',$s->end if DEBUG;
	warn "ref/tgt"             if DEBUG;
	warn "$ref_dna\n$tgt_dna"  if DEBUG;
	
	my @exact_segments;

	if ($cigar) {
	    warn   "Segmenting [$target,$src_start,$src_end,$tgt_start,$tgt_end] via $cigar.\n" if DEBUG;
	    @exact_segments = $self->_gapped_alignment_to_segments($cigar,$ref_dna,$tgt_dna);
	}
	else {
	    warn   "Realigning [$target,$src_start,$src_end,$tgt_start,$tgt_end].\n" if DEBUG;
	    @exact_segments = $can_realign->($ref_dna,$tgt_dna);	    
	}

	foreach (@exact_segments) {
	    warn "=========> [$target,@$_]\n" if DEBUG;
	    my $a = $strands{$target} >= 0
		? [$target,$_->[0]+$src_start,$_->[1]+$src_start,$_->[2]+$tgt_start,$_->[3]+$tgt_start]
		: [$target,$src_end-$_->[1],$src_end-$_->[0],$_->[2]+$tgt_start,$_->[3]+$tgt_start];
	    warn "[$target,$_->[0]+$src_start,$_->[1]+$src_start,$tgt_end-$_->[3],$tgt_end-$_->[2]]" if DEBUG;
	    warn "=========> [@$a]\n" if DEBUG;
	    warn substr($ref_dna,     $_->[0],$_->[1]-$_->[0]+1),"\n" if DEBUG;
	    warn substr($tgt_dna,$_->[2],$_->[3]-$_->[2]+1),"\n"      if DEBUG;
	    push @segments,$a;
	}
    }
    else {
	push @segments,[$target,$src_start,$src_end,$tgt_start,$tgt_end];
    }
  }

  # get 'em in the right order so that we don't have to worry about
  # where the beginning and end are.
  @segments = sort {$a->[TGT_START]<=>$b->[TGT_START]} @segments;
    
  # adjust for ragged (nonaligned) ends
  my ($offset_left,$offset_right) = (0,0);
  if ($ragged_extra && $ragged_extra > 0) {

    # add a little rag to the left end
    $offset_left = $segments[0]->[TGT_START] > $ragged_extra ? $ragged_extra : $segments[0]->[TGT_START]-1;
    if ($strand >= 0) {
      $offset_left     = $segments[0]->[SRC_START]-1 if $segments[0]->[SRC_START] - $offset_left < 1;
      $abs_start                -= $offset_left;
      $tgt_start                -= $offset_left;
      $segments[0]->[SRC_START] -= $offset_left;
      $segments[0]->[TGT_START] -= $offset_left;
    } else {
      $abs_end                  += $offset_left;
      $tgt_start                -= $offset_left;
      $segments[0]->[SRC_END]   += $offset_left;
      $segments[0]->[TGT_START] -= $offset_left;
    }

    # add a little rag to the right end - this is complicated because
    # we don't know what the length of the underlying dna is, so we
    # use the subfeat method to find out
    my $current_end        = $segments[-1]->[TGT_END];
    $offset_right          = length $segments[-1]->[TARGET]->subseq($current_end+1,$current_end+$ragged_extra)->seq;
    if ($strand >= 0) {
      $abs_end                 += $offset_right;
      $tgt_end                 += $offset_left;
      $segments[-1]->[TGT_END] += $offset_right;
      $segments[-1]->[SRC_END] += $offset_right;
    } else {
      $abs_start                 -= $offset_right;
      $tgt_end                   += $offset_left;
      $segments[-1]->[TGT_END]   += $offset_right;
      $segments[-1]->[SRC_START] -= $offset_right;
    }
  }

  # get the DNAs now - a little complicated by the necessity of using
  # the subseq() method
  $ref_dna ||= $feature->subseq(1-$offset_left,$feature->length+$offset_right)->seq;

  # this may not be right if the alignment involves only a portion of the target DNA
  $tgt_dna ||= $feature->hit->dna;

  # none of these seem to be working properly with BAM alignments
  # my $tgt_len = abs($segments[-1]->[TGT_END] - $segments[0]->[TGT_START]) + 1;
  # my $tgt_dna = $feature->hit->subseq(1-$offset_left,$feature->length+$offset_right)->seq;
  # my $tgt_dna = $feature->hit->subseq(1-$offset_left,$tgt_len+$offset_right)->seq;

  # work around changes in the API
  $ref_dna    = $ref_dna->seq if ref $ref_dna and $ref_dna->can('seq');
  $tgt_dna    = $tgt_dna->seq if ref $tgt_dna and $tgt_dna->can('seq');

  $ref_dna    = lc $ref_dna;
  $tgt_dna    = lc $tgt_dna;

  # sanity check.  Let's see if they look like they're lining up
  warn "$feature dna sanity check:\n$ref_dna\n$tgt_dna\n" if DEBUG;

  # now we're all lined up, and we're going to adjust everything to fall within the bounds
  # of the left and right panel coordinates
  my %clip;
  for my $seg (@segments) {

    my $target = $seg->[TARGET];
    warn "preclip [@$seg]\n" if DEBUG;

    # left clipping
    if ( (my $delta = $seg->[SRC_START] - $panel_start) < 0 ) {
      warn "clip left delta = $delta" if DEBUG;
      $seg->[SRC_START] = $panel_start;
      if ($strand >= 0) {
	$seg->[TGT_START] -= $delta;
      }
    }

    # right clipping
    if ( (my $delta = $panel_end - $seg->[SRC_END]) < 0) {
      warn "clip right delta = $delta" if DEBUG;
      $seg->[SRC_END] = $panel_end;
      if ($strand < 0) {
	$seg->[TGT_START] -= $delta;
      }
    }

    my $length = $seg->[SRC_END]-$seg->[SRC_START]+1;
    $seg->[TGT_END] = $seg->[TGT_START]+$length-1;

    warn "Clipping gives [@$seg], tgt_start = $tgt_start\n" if DEBUG;
  }

  # remove segments that got clipped out of existence
  # no longer doing this because it interferes with ability to
  # detect insertions in the target
#  @segments = grep { $_->[SRC_START]<=$_->[SRC_END] } @segments;

  # relativize coordinates
  if ($strand < 0) {
# breaks BAM, but probably needed for non-BAM features
    $ref_dna = $self->reversec($ref_dna) unless eval { $feature->reversed } ;
    $tgt_dna = $self->reversec($tgt_dna);
  }

  my ($red,$green,$blue)   = $self->panel->rgb($bgcolor);
  my $avg         = ($red+$green+$blue)/3;
  my $color       = $self->translate_color($avg > 128 ? 'black' : 'white');
  my $font       = $self->mono_font;
  my $lineheight = $font->height;
  my $fontwidth  = $font->width;

  my $mismatch = $self->mismatch_color;
  my $insertion= $self->insertion_color;
  my $deletion = $self->deletion_color;
  my $grey     = $self->translate_color('gray');
  my $mismatch_font_color = eval {
      my ($r,$g,$b) = $self->panel->rgb($mismatch);
      $self->translate_color(($r+$g+$b)>128 ? 'black' : 'white');
  };
  my $insertion_font_color = eval {
      my ($r,$g,$b) = $self->panel->rgb($insertion);
      $self->translate_color(($r+$g+$b)>128 ? 'black' : 'white');
  };
  my $deletion_font_color = eval {
      my ($r,$g,$b) = $self->panel->rgb($deletion);
      $self->translate_color(($r+$g+$b)>128 ? 'black' : 'white');
  };


  unless (@segments) { # this will happen if entire region is a target gap
      for (my $i = $bl;$i<$br-$self->scale;$i+=$self->scale) {
	  $gd->char($font,$self->flip ? $i+$self->scale-4 : $i+2,$top,'-',$deletion_font_color);
      }
      return;
  }
  
  for my $seg (@segments) {
    $seg->[SRC_START] -= $abs_start - 1;
    $seg->[SRC_END]   -= $abs_start - 1;
    $seg->[TGT_START] -= $tgt_start - 1;
    $seg->[TGT_END]   -= $tgt_start - 1;

    if ($strand < 0) {
      ($seg->[TGT_START],$seg->[TGT_END]) = (length($tgt_dna)-$seg->[TGT_END]+1,length($tgt_dna)-$seg->[TGT_START]+1);
    }
    if (DEBUG) {
      warn "$feature: relativized coordinates = [@$seg]\n";
      warn $self->_subsequence($ref_dna,$seg->[SRC_START],$seg->[SRC_END]),"\n";
      warn $self->_subsequence($tgt_dna,$seg->[TGT_START],$seg->[TGT_END]),"\n";
    }
  }

  # draw
  my $base2pixel = 
    $self->flip ?
      sub {
	my ($src,$tgt) = @_;
	my $a = $fontwidth + ($abs_start + $src-$panel_start-1 + $tgt) * $pixels_per_base - 1;    
	$panel_right - $a;
      }
      : sub {
	my ($src,$tgt) = @_;
	$fontwidth/2 + $left + ($abs_start + $src-$panel_start-1 + $tgt) * $pixels_per_base - 1;    
      };

  my $mismatch_only = $self->mismatch_only;
  my ($tgt_last_end,$src_last_end,$leftmost,$rightmost,$gaps);

  my $segment = 0;

  for my $seg (sort {$a->[SRC_START]<=>$b->[SRC_START]} @segments) {
    my $y = $top-1;
    my $end = $seg->[SRC_END]-$seg->[SRC_START];

    for (my $i=0; $i<$end+1; $i++) {
      my $src_base = $self->_subsequence($ref_dna,$seg->[SRC_START]+$i,$seg->[SRC_START]+$i);
      my $tgt_base = $self->_subsequence($tgt_dna,$seg->[TGT_START]+$i,$seg->[TGT_START]+$i);
      my $x = $base2pixel->($seg->[SRC_START],$i);
      $leftmost = $x if !defined $leftmost  || $leftmost  > $x;
      $rightmost= $x if !defined $rightmost || $rightmost < $x;

      next unless $tgt_base && $x >= $panel_left && $x <= $panel_right;

      my $is_mismatch = $show_mismatch && $tgt_base && $src_base ne $tgt_base && $tgt_base !~ /[nN]/;
      $tgt_base = $complement{$tgt_base} if $true_target && $strand < 0;
      $gd->char($font,$x,$y,$tgt_base,$tgt_base =~ /[nN]/ ? $grey 
		                     :$is_mismatch        ? $mismatch_font_color
	                             :$color)
	  unless $mismatch_only && !$is_mismatch;

      $drew_sequence++;
    }

    # deal with gaps in the alignment
    if (defined $src_last_end && (my $delta = $seg->[SRC_START] - $src_last_end) > 1) {
	for (my $i=0;$i<$delta-1;$i++) {
	    my $x = $base2pixel->($src_last_end,$i+1);
	    next if $x > $panel_right;
	    next if $x < $panel_left;
	    $gd->char($font,$x,$y,'-',$deletion_font_color);
	}
	$gaps = $delta-1;
    }

    # indicate the presence of insertions in the target
    $gaps       ||= 0;
    my $pos       = $src_last_end + $gaps;
    my $delta     = $seg->[TGT_START] - $tgt_last_end;
    my $src_delta = $seg->[SRC_START] - $src_last_end;

    if ($segment && $delta && ($delta > $src_delta-$gaps)) {  # an insertion in the target relative to the source
	my $gap_left  = $base2pixel->($pos+0.5,0);
	my $gap_right = $base2pixel->($seg->[SRC_START],0);
	($gap_left,$gap_right) = ($gap_right+$fontwidth,$gap_left-$fontwidth) if $self->flip;
	warn "delta=$delta, gap_left=$gap_left, gap_right=$gap_right" if DEBUG;

	next if $gap_left <= $panel_left || $gap_right >= $panel_right;
	    
	my $length = $delta-1;
	$length    = 1 if $length <= 0;  # workaround
	my $gap_distance   = $gap_right - $gap_left;
	my $pixels_per_inserted_base = $gap_distance/$length;

	if ($pixels_per_inserted_base >= $fontwidth) {  # Squeeze the insertion in
	    for (my $i = 0; $i<$delta-1; $i++) {
		my $x = $gap_left + $pixels_per_inserted_base * $i;
		my $bp = $self->_subsequence($tgt_dna,$tgt_last_end+$i+1,$tgt_last_end+$i+1);
		next if $x < $panel_left;
		$gd->char($font,$x,$y,$bp,$color);
	    }
	} else {  #here's where we insert the insertion length
	    if ($gap_distance >= $fontwidth*length($length)) {
		$gd->string($font,$gap_left,$y,$length,$color);
	    }
	}
    }

  } continue {
    $tgt_last_end  = $seg->[TGT_END];
    $src_last_end  = $seg->[SRC_END];
    $segment++;
  }

  return $drew_sequence;
}

sub _gapped_alignment_to_segments {
    my $self = shift;
    my ($cigar,$sdna,$tdna) = @_;
    my ($pad_source,$pad_target,$pad_match);
    warn "_gapped_alignment_to_segments\n$sdna\n$tdna" if DEBUG;

    for my $event (@$cigar) {
	my ($op,$count) = @$event;
	warn "op=$op, count=$count" if DEBUG;
	if ($op eq 'I') {
	    $pad_source .= '-' x $count;
	    $pad_target .= substr($tdna,0,$count,'');
	    $pad_match  .= ' ' x $count;
	}
	elsif ($op eq 'D' || $op eq 'N') {
	    $pad_source .= substr($sdna,0,$count,'');
	    $pad_target .= '-' x $count;
	    $pad_match  .= ' ' x $count;
	}
	elsif ($op eq 'S') {
	    $pad_source .= '-' x $count;
	    $pad_target .= substr($tdna,0,$count,'');
	    $pad_match  .= ' ' x $count;

	}
	elsif ($op eq 'H' || $op eq 'P') {
	    # Nothing to do. This is simply an informational operation.
	} else {  # everything else is assumed to be a match -- revisit
	    $pad_source .= substr($sdna,0,$count,'');
	    $pad_target .= substr($tdna,0,$count,'');
	    $pad_match  .= '|' x $count;
	}
    }

    warn "pads:\n$pad_source\n$pad_match\n$pad_target" if DEBUG;

    return $self->pads_to_segments($pad_source,$pad_match,$pad_target);
}

sub pads_to_segments {
    my $self = shift;
    my ($gap1,$align,$gap2) = @_;
    warn "pads_to_segments" if DEBUG;
    warn "$gap1\n$align\n$gap2\n" if DEBUG;

    # create arrays that map residue positions to gap positions
    my @maps;
    for my $seq ($gap1,$gap2) {
	my @seq = split '',$seq;
	my @map;
	my $residue = 0;
	for (my $i=0;$i<@seq;$i++) {
	    $map[$i] = $residue;
	    $residue++ if $seq[$i] ne '-';
	}
	push @maps,\@map;
    }

    my @result;
    while ($align =~ /(\S+)/g) {
	my $align_end   = pos($align) - 1;
	my $align_start = $align_end  - length($1) + 1;
	push @result,[@{$maps[0]}[$align_start,$align_end],
		      @{$maps[1]}[$align_start,$align_end]];
    }
    return wantarray ? @result : \@result;
}

sub _get_cigar {
    my $self = shift;
    my $feat = shift;
    
    # some features have this built in
    if ($feat->can('cigar_array')) {
	my $cigar = $feat->cigar_array;
	@$cigar = reverse @$cigar if $feat->strand < 0;
	return $cigar;
    }

    my ($cigar) = $feat->get_tag_values('Gap');
    return unless $cigar;

    my @arry;
    my $regexp = $cigar =~ /^\d+/ ? '(\d+)([A-Z])' 
	                          : '([A-Z])(\d+)';
    if ($cigar =~ /^\d+/) {
	while ($cigar =~ /(\d+)([A-Z])/g) {
	    my ($count,$op) = ($1,$2);
	    push @arry,[$op,$count];
	}
    } else {
	while ($cigar =~ /([A-Z])(\d+)/g) {
	    my ($op,$count) = ($1,$2);
	    push @arry,[$op,$count];
	}
    }
    return \@arry;
}

sub _subsequence {
  my $self = shift;
  my ($seq,$start,$end,$strand) = @_;
  my $sub;
  if ((defined $strand && $strand < 0)) {
    my $piece = substr($seq,length($seq)-$end,$end-$start+1);
    $sub = $self->reversec($piece);
  } else {
    $sub = substr($seq,$start-1,$end-$start+1);
  }
  return $self->flip ? $complement{$sub} : $sub;
}

# draw the classic "i-beam" icon to indicate that an insertion fits between
# two bases
# sub _draw_insertion_point {
#   my $self = shift;
#   my ($gd,$x,$y,$color) = @_;
#   my $top    = $y;
#   $x--;
#   my $bottom = $y + $self->font->height - 4;
#   $gd->line($x,$top+2, $x,$bottom-2,$color);
#   $gd->setPixel($x+1,  $top+1,$color);
#   $gd->setPixel($x+$_, $top,$color) for (2..3);
#   $gd->setPixel($x-1,  $top+1,$color);
#   $gd->setPixel($x-$_, $top,$color) for (2..3);

#   $gd->setPixel($x+1,  $bottom-1,$color);
#   $gd->setPixel($x+$_, $bottom,  $color) for (2..3);
#   $gd->setPixel($x-1,  $bottom-1,$color);
#   $gd->setPixel($x-$_, $bottom,  $color) for (2..3);
# }

# don't like that -- try drawing carets
sub _draw_insertion_point {
   my $self = shift;
   my ($gd,$left,$right,$top,$bottom,$color) = @_;

   my $poly = GD::Polygon->new();
   $poly->addPt($left-3,$top+1);
   $poly->addPt($right+2,$top+1);
   $poly->addPt(($left+$right)/2-1,$top+3);
   $gd->filledPolygon($poly,$color);

   $poly = GD::Polygon->new();
   $poly->addPt($left-3,$bottom);
   $poly->addPt($right+2,$bottom);
   $poly->addPt(($left+$right)/2-1,$bottom-2);
   $gd->filledPolygon($poly,$color);
}

1;

__END__

=head1 NAME

Bio::Graphics::Glyph::segments - The "segments" glyph

=head1 SYNOPSIS

  See L<Bio::Graphics::Panel> and L<Bio::Graphics::Glyph>.

=head1 DESCRIPTION

This glyph is used for drawing features that consist of discontinuous
segments.  Unlike "graded_segments" or "alignment", the segments are a
uniform color and not dependent on the score of the segment.

=head2 METHODS

This module overrides the maxdepth() method to return 1 unless
explicitly specified by the -maxdepth option. This means that modules
inheriting from segments will only be presented with one level of
subfeatures. Override the maxdepth() method to get more levels.

=head2 OPTIONS

The following options are standard among all Glyphs.  See
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

In addition, the following glyph-specific options are recognized:

  -draw_dna     If true, draw the dna residues        0 (false)
                 when magnification level
                 allows.

  -draw_target  If true, draw the dna residues        0 (false)
                 of the TARGET sequence when
                 magnification level allows.
                 See "Displaying Alignments".

  -draw_protein_target  If true, draw the protein residues        0 (false)
                 of the TARGET sequence when
                 magnification level allows.
                 See "Displaying Alignments".

  -ragged_extra When combined with -draw_target,      0 (false)
                draw extra bases beyond the end
                of the alignment. The value is
                the maximum number of extra
                bases.
                See "Displaying Alignments".

  -ragged_start  Deprecated option.  Use
                 -ragged_extra instead

  -show_mismatch When combined with -draw_target,     0 (false)
                 highlights mismatched bases in
                 the mismatch color.  
                 Can be 0 (don't display);
                 1 (display when the DNA fits);
                 or another positive integer
                 (display when the region in
                 view is <= this value).
                 See "Displaying Alignments".

  -mismatch_only When combined with -draw_target,     0 (false)
                 draws only the mismatched bases
                 in the alignment. Implies
                 -show_mismatch.
                 See "Displaying Alignments".

  -mismatch_color The mismatch color to use           'lightgrey'

  -insertion_color The color to use for insertions    'green'
                   relative to the reference.          

  -deletion_color The color to use for deletions      'red'
                  relative to the reference.

  -indel_color   The color to use for indels, used   'lightgrey'
                 only if -insertion_color or
                 -deletion_color are absent

  -true_target   Show the target DNA in its native    0 (false)
                 (plus strand) orientation, even if
                 the alignment is to the minus strand.
                 See "Displaying Alignments".

  -realign       Attempt to realign sequences at      0 (false)
                 high mag to account for indels.
                 See "Displaying Alignments".

If the -draw_dna flag is set to a true value, then when the
magnification is high enough, the underlying DNA sequence will be
shown.  This option is mutually exclusive with -draw_target. See
Bio::Graphics::Glyph::generic for more details.

The -draw_target, -ragged_extra, and -show_mismatch options only work
with seqfeatures that implement the hit() method
(Bio::SeqFeature::SimilarityPair). -draw_target will cause the DNA of
the hit sequence to be displayed when the magnification is high enough
to allow individual bases to be drawn. The -ragged_extra option will
cause the alignment to be extended at the extreme ends by the
indicated number of bases, and is useful for looking for polyAs and
cloning sites at the ends of ESTs and cDNAs. -show_mismatch will cause
mismatched bases to be highlighted in with the color indicated by
-mismatch_color. A -show_mismatch value of "1" will highlight mismatches
only when the base pairs are displayed. A positive integer will cause
mismatches to be shown whenever the region in view is less than or equal
to the requested value.

At high magnifications, minus strand matches will automatically be
shown as their reverse complement (so that the match has the same
sequence as the plus strand of the source dna).  If you prefer to see
the actual sequence of the target as it appears on the minus strand,
then set -true_target to true.

Note that -true_target has the opposite meaning from
-canonical_strand, which is used in conjunction with -draw_dna to draw
minus strand features as if they appear on the plus strand.

=head2 Displaying Alignments

When the B<-draw_target> option is true, this glyph can be used to
display nucleotide alignments such as BLAST, FASTA or BLAT
similarities.  At high magnification, this glyph will attempt to show
how the sequence of the source (query) DNA matches the sequence of the
target (the hit).  For this to work, the feature must implement the
hit() method, and both the source and the target DNA must be
available.  If you pass the glyph a series of
Bio::SeqFeature::SimilarityPair objects, then these criteria will be
satisified.

Without additional help, this glyph cannot display gapped alignments
correctly.  To display gapped alignments, you can use the
Bio::Graphics::Brower::Realign module, which is part of the Generic
Genome Browser package (http://www.gmod.org).  If you wish to install
the Realign module and not the rest of the package, here is the
recipe:

  cd Generic-Genome-Browser-1.XX
  perl Makefile.PL DO_XS=1
  make
  make install_site

If possible, build the gbrowse package with the DO_XS=1 option.  This
compiles a C-based DP algorithm that both gbrowse and gbrowse_details
will use if they can.  If DO_XS is not set, then the scripts will use
a Perl-based version of the algorithm that is 10-100 times slower.

The display of alignments can be tweaked using the -ragged_extra,
-show_mismatch, -true_target, and -realign options.  See the options
section for further details.

There is also a B<-draw_protein_target> option, which is designed for
protein to nucleotide alignments. It draws the target sequence every
third base pair and is supposed to align correctly with the forward
and reverse translation glyphs. This option is experimental at the
moment, and may not work correctly, to use with care.

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

Lincoln Stein E<lt>lstein@cshl.orgE<gt>

Copyright (c) 2001 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut
