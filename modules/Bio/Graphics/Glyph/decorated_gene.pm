package Bio::Graphics::Glyph::decorated_gene;

use strict;
use base 'Bio::Graphics::Glyph::decorated_transcript';

sub extra_arrow_length {
  my $self = shift;
  return 0 unless $self->{level} == 1;
  local $self->{level} = 0;  # fake out superclass
  return $self->SUPER::extra_arrow_length;
}

sub pad_left {
  my $self = shift;
  my $type = $self->feature->primary_tag;
  return 0 unless $type =~ /gene|mRNA/;
  $self->SUPER::pad_left;
}

sub pad_right {
  my $self = shift;
  return 0 unless $self->{level} < 2; # don't invoke this expensive call on exons
  my $strand = $self->feature->strand;
  $strand *= -1 if $self->{flip};
  my $pad    = $self->SUPER::pad_right;
  return $pad unless defined($strand) && $strand > 0;
  my $al = $self->arrow_length;
  return $al > $pad ? $al : $pad;
}

sub pad_bottom {
  my $self = shift;
  return 0 unless $self->{level} < 2; # don't invoke this expensive call on exons
  return $self->SUPER::pad_bottom;
}

sub pad_top {
  my $self = shift;
  return 0 unless $self->{level} < 2; # don't invoke this expensive call on exons
  return $self->SUPER::pad_top;
}

sub bump {
  my $self = shift;
  return 1 if $self->{level} == 0; # top level bumps, other levels don't unless specified in config
  return $self->SUPER::bump;
}

sub label {
  my $self = shift;
  return unless $self->{level} < 2;
  if ($self->label_transcripts && $self->{feature}->primary_tag eq 'mRNA') { # the mRNA
    return $self->_label;
  } else {
    return $self->SUPER::label;
  }
}

sub label_position {
  my $self = shift;
  return 'top' if $self->{level} == 0;
  return 'left';
}

sub label_transcripts {
  my $self = shift;
  return $self->{label_transcripts} if exists $self->{label_transcripts};
  return $self->{label_transcripts} = $self->_label_transcripts;
}

sub _label_transcripts {
  my $self = shift;
  return $self->option('label_transcripts');
}

sub draw_connectors {
  my $self = shift;
  return if $self->feature->primary_tag eq 'gene';
  $self->SUPER::draw_connectors(@_);
}

sub maxdepth {
  my $self = shift;
  my $md   = $self->Bio::Graphics::Glyph::maxdepth;
  return $md if defined $md;
  return 2;
}


sub _subfeat {
  my $class   = shift;
  my $feature = shift;
  return $feature->get_SeqFeatures('mRNA') if $feature->primary_tag eq 'gene';

  my @subparts;
  if ($class->option('sub_part')) {
    @subparts = $feature->get_SeqFeatures($class->option('sub_part'));
  }
  else {

    @subparts = $feature->get_SeqFeatures(qw(CDS five_prime_UTR three_prime_UTR UTR));
  }
 
  # The CDS and UTRs may be represented as a single feature with subparts or as several features
  # that have different IDs. We handle both cases transparently.
  my @result;
  foreach (@subparts) {
    if ($_->primary_tag =~ /CDS|UTR/i) {
      my @cds_seg = $_->get_SeqFeatures;
      if (@cds_seg > 0) { push @result,@cds_seg  } else { push @result,$_ }
    } else {
      push @result,$_;
    }
  }
  return @result;
}

1;

__END__

=head1 NAME

Bio::Graphics::Glyph::decorated_gene - A GFF3-compatible gene glyph with protein decorations

=head1 SYNOPSIS

  See L<Bio::Graphics::Panel> and L<Bio::Graphics::Glyph>.

=head1 DESCRIPTION

This glyph has the same functionality as the L<Bio::Graphics::Glyph::gene> glyph, but uses
the L<Bio::Graphics::Glyph::decorated_transcript> glyph instead of the 
L<Bio::Graphics::Glyph::processed_transcript> glyph to draw transcripts. 

One usecase for the 'decorated_gene' glyph is to highlight protein features 
of different splice forms of the same gene to see how splice forms differ in terms of protein 
features, for example the presence of predicted signal peptides or protein domains. 

See L<Bio::Graphics::Glyph::decorated_transcript> for a description of how to provide 
protein decorations for transcripts.  

=head1 BUGS

=head1 SEE ALSO


L<Bio::Graphics::Glyph::gene>,
L<Bio::Graphics::Glyph::decorated_transcript>

=head1 AUTHOR

Christian Frech E<lt>cfa24@sfu.caE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut
