package Bio::GMOD::Query;

use strict;
use vars qw/@ISA/;
use LWP::UserAgent;
use Bio::GMOD;
use Bio::GMOD::Util::Rearrange;

@ISA = qw/Bio::GMOD/;


# Subclasses of Bio::GMOD::Query should implement the following methods.
# See Bio::GMOD::Query::WormBase for an example.

sub fetch {
  my ($self,@p) = @_;
  my ($class,$name,@rest) = rearrange([qw/CLASS NAME/],@p);
  eval { "require $self"; } or die;

  # Class names correspond with method names
  $self->$class(-name=>$name,@rest);
};


# This is a generic database search
sub search {
  my ($self,@p) = @_;
  my ($class,$name,@rest) = rearrange([qw/CLASS NAME/],@p);
  eval { "require $self"; };

  $self->search(-name=>$name,@rest);
}

######################################################
# The following methods should be provided in the
# Query::Mod subclass
######################################################
# Gene
# Execute a query on the database for to fetch or search for
# specific genes, returning a list of lists.  Each list contains the
# gene ID, its public name, and a brief functional description.

# Note that the behavior of the subroutine can be modified according
# to whether this is a simple search or a fetch. You can determine the
# type of action by examining the "search_type" parameter.
sub gene    {
  my ($self,@p) = @_;
  my ($query,$type) = rearrange([qw/query/],@p);
}

# Gene sequence
# Provided with a Gene ID (or public_name), return the maximal extent
# sequence of the gene
sub gene_sequence {
  my ($self,@p) = @_;
  my ($id) = rearrange([qw/id/],@p);
}

# Protein
# Execute a query on the database for specific proteins
sub protein { }

# Protein sequence
# Provided with a protein ID (or public_name), return the sequence of the protein
sub protein_sequence {
  my ($self,@p) = @_;
  my ($id) = rearrange([qw/id/],@p);
}

# mRNA
sub mrna    { }

# ncRNA
sub ncrna   { }

__END__


=pod

=head1 NAME

Bio::GMOD::Query - Execute generic queries for different MODs

=head1 SYNPOSIS

  my $agent = Bio::GMOD::Query->new(-mod => 'WormBase');

=head1 DESCRIPTION

Bio::GMOD::Query is a generic place holder describing methods that
subclasses should implement.  MODs that wish to support
Bio::GMOD::Query should subclass this module.  Each general data type
that can be fetched should also be a method name.

Bio::GMOD::Query itslef provides a single method: fetch().  This
method is a generic wrapper around the various methods for fetching
datatypes.

=head1 BUGS

None reported.

=head1 SEE ALSO

L<Bio::GMOD>,L<Bio::GMOD::Query::WormBase>

=head1 AUTHOR

Todd W. Harris E<lt>harris@cshl.eduE<gt>.

Copyright (c) 2003-2005 Cold Spring Harbor Laboratory.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

