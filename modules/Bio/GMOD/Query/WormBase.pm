package Bio::GMOD::Query::WormBase;

use strict;

use Ace;
use Bio::GMOD::Util::Rearrange;
use vars qw/@ISA @AVAILABLE_CLASSES/;

@ISA = qw/Bio::GMOD::Query/;

# Adjust this array to describe the classes that can be searched or
# retrieved at your MOD.  Classes should correspond to method names!
@AVAILABLE_CLASSES = qw/gene protein/;

sub available_classes { return @AVAILABLE_CLASSES; }

# Run a query for genes at WormBase
sub gene {
  my ($self,@p) = @_;
  my ($name,@remainder) = rearrange([qw/NAME/],@p);
  my $adaptor = $self->adaptor;
  my $db      = $self->_connect_to_ace;
  my $query   = sprintf($adaptor->gene_fetch_query,$name);
  my @genes = $db->aql($query);
  my @results = _do_grep($db,'Gene',$name) unless @genes;
  if (@results) {
    @genes = map { [ $_,$_->Public_name,$_->Concise_description ] } @results;
  }
  return \@genes;
}

sub protein {
  my ($self,@p) = @_;
  my ($name,@remainder) = rearrange([qw/NAME/],@p);
  my $adaptor = $self->adaptor;
  my $db      = $self->_connect_to_ace;
  my $query   = sprintf($adaptor->protein_fetch_query,$name);
  my @proteins = $db->aql($query);
  my @results = _do_grep($db,'Protein',$name) unless @proteins;
  if (@results) {
    @proteins = map { [ $_,$_->Public_name,$_->Concise_description ] } @results;
  }
  return \@proteins;
}

sub allele {
  my ($self,@p) = @_;
  my ($name,@remainder) = rearrange([qw/NAME/],@p);
  my $adaptor = $self->adaptor;
  my $db      = $self->_connect_to_ace;
  my $query   = sprintf($adaptor->protein_fetch_query,$name);
  my @alleles = $db->aql($query);
  my @results = _do_grep($db,'Variation',$name) unless @alleles;
  if (@results) {
    @alleles = map { [ $_,$_->Public_name,$_->Concise_description ] } @results;
  }
  return \@alleles;
}

sub _connect_to_ace {
  my $self = shift;
  my $adaptor = $self->adaptor;
  my $host = $adaptor->data_mining_server;
  my $port = $adaptor->data_mining_port;
  return $self->{db} if $self->{db};
  my $db = Ace->connect(-host=>$host,-port=>$port) or $self->logit(-msg=>"Couldn't connect to $host:$port: $!",-die=>1);
  $self->{db} = $db;
  return $db;
}

# Do a full database grep in cases where we can't specifically fetch something
sub _do_grep {
  my ($db,$class,$name) = @_;
  my @results = grep { $_->class eq $class } $db->grep(-pattern => $name,
						       -long    => 'true');
  return @results;
}


1;




=pod

=head1 NAME

Bio::GMOD::Query::WormBase - Defaults for programmatically interacting with Wormbase

=head1 SYNPOSIS

  my $adaptor = Bio::GMOD::Adaptor::WormBase->new();

=head1 DESCRIPTION

Bio::GMOD::Adaptor::WormBase objects are created internally by the new()
method provided by Bio::GMOD::Adaptor.  Adaptor::* objects contain
appropriate defaults for interacting programmatically with the GMOD of
choice.

Defaults are read dynamically from the WormBase server at runtime.
This helps to insulate your scripts from changes in the WormBase
infrastructure.  If using Bio::GMOD offline, defaults will be
populated from those hard-coded in this adaptor.  You may also supply
these defaults as hash=>key pairs to the new method.

For descriptions of all currently known parameters, see
Bio::GMOD::Adaptor::WormBase.pm or the default list maintained at
http://dev.wormbase.org/db/gmod/defaults

=head1 BUGS

None reported.

=head1 SEE ALSO

L<Bio::GMOD>, L<Bio::GMOD::Query>

=head1 AUTHOR

Todd W. Harris E<lt>harris@cshl.eduE<gt>.

Copyright (c) 2003-2005 Cold Spring Harbor Laboratory.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

