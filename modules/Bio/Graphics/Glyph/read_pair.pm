package Bio::Graphics::Glyph::read_pair;

#specialized for SAM read pairs

use base 'Bio::Graphics::Glyph::segments';

sub my_description {
    return <<END;
This glyph is designed to be used with SAM/BAM paired end read/mate-pair data. It has
the same properties as the segments glyph, but draws mate pairs as two gapped alignments
connected by dashed lines. Mate pairs that overlap are rendered in a rational fashion.
END
}

sub connector {
    my $self = shift;
    return $self->level == 0 ? 'dashed' : 'solid';
}

sub parts_overlap { 1 }

sub box_subparts { 2 }

sub stranded { 
    my $self = shift;
    my $s    = $self->SUPER::stranded;
    return defined $s ? $s : 1;
}

sub bgcolor {
    my $self = shift;
    my $bg   = $self->option('bgcolor');
    $bg      = $self->feature->strand > 0  ? 'red' : 'blue' unless defined $bg;
    return $self->factory->translate_color($bg);
}

sub draw_target {
    my $self = shift;
    my $t    = $self->option('draw_target');
    return $t if defined $t;
    return 1;
}

sub show_mismatch {
    my $self = shift;
    my $t    = $self->option('show_mismatch');
    return $t if defined $t;
    return 1;
}

sub label_position {
    my $self = shift;
    my $t    = $self->option('label_position');
    return $t if defined $t;
    return 'left';
}

sub maxdepth { 2 }

1;

