package Bio::GMOD::Adaptor::generic;

use strict;
use vars qw/@ISA $AUTOLOAD/;
use Bio::GMOD::Adaptor;
use Bio::GMOD::Util::Rearrange;

@ISA = qw/Bio::GMOD::Adaptor/;

my %DEFAULTS;

sub defaults {
  my $self = shift;
  return (keys %DEFAULTS);
}


# Automatically create lc data accessor methods
# for each configuration variable
sub AUTOLOAD {
  my $self = shift;
  my $attr = $AUTOLOAD;
  $attr =~ s/.*:://;
  return unless $attr =~ /[^A-Z]/;  # skip DESTROY and all-cap methods
  return if $attr eq 'new'; # Provided by superclass
  #  die "invalid attribute method: ->$attr()" unless $DEFAULTS{uc($attr)};
  $self->{uc($attr)} = shift if @_;
  my $val = $self->{defaults}->{lc($attr)};  # Get what is already there
  $val ||= $DEFAULTS{uc($attr)};  # Perhaps it hasn't been defined yet.
  return $val;
}

__END__

=pod

=head1 NAME

Bio::GMOD::Adaptor::generic - A generic adaptor for working with multiple MODs simultaneously

=head1 SYNPOSIS

  my $adaptor = Bio::GMOD::Adaptor::generic->new();

=head1 DESCRIPTION

Bio::GMOD::Adaptor::generic objects are created internally by the
new() method provided by Bio::GMOD::Adaptor.  This adaptor is
typically used when a script needs to work with multiple MODs within
the same session.

=head1 BUGS

None reported.

=head1 SEE ALSO

L<Bio::GMOD>, L<Bio::GMOD::Adaptor>

=head1 AUTHOR

Todd W. Harris E<lt>harris@cshl.eduE<gt>.

Copyright (c) 2003-2005 Cold Spring Harbor Laboratory.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut



1;
