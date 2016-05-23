package Bio::GMOD::Query::FlyBase;

use strict;

use Ace;
use Bio::GMOD::Util::Rearrange;
use LWP::UserAgent;
use WWW::Mechanize;
use vars qw/@ISA @AVAILABLE_CLASSES/;

use constant FORMAT => 'text/tsv';

@ISA = qw/Bio::GMOD::Query/;

# Adjust this array to describe the classes that can be searched or
# retrieved at your MOD.  Classes should correspond to method names!
@AVAILABLE_CLASSES = qw/gene/;

sub available_classes { return @AVAILABLE_CLASSES; }

# Run a query for genes at WormBase
sub gene {
  my ($self,@p) = @_;
  my ($name) = rearrange([qw/NAME/],@p);
  my $adaptor  = $self->adaptor;
  my $gene_url = $adaptor->gene_url;
  my %params;
  $params{ids}     = (ref $name =~ /ARRAY/) ? join(',',@$name) : $name;
  $params{idclass} = 'FBgn';
  $params{format}  = FORMAT;

  my $params = join '&', map { "$_=$params{$_}"; }(keys %params);
  my @genes = $self->_do_request;
  unless (@genes) {
    %params = ();
    $params{xfield1} = $name;
    $params{xfieldname1} = 'all';
    $params{format}  = FORMAT;
    $params{old_query} = $name;
    @genes = $self->_do_search($adaptor->gene_search_url,\%params);
  }
  return \@genes;
}


sub protein {  }

sub _do_request {
  my ($self,$params) = @_;
  my $adaptor = $self->adaptor;
  my $url = $adaptor->datamining_url;

  # Create a request
  my $ua = LWP::UserAgent->new();
  my $req = HTTP::Request->new(POST => $url);
  my $version = $self->biogmod_version;
  $ua->agent("Bio::GMOD::Query::FlyBase/$version");

  $req->content_type('application/x-www-form-urlencoded');
  $req->content($params);

  # Pass request to the user agent and get a response back
  my $res = $ua->request($req);

  # Check the outcome of the response
  if ($res->is_success) {
    my $content = $res->content;
    my @content = split("\n",$content);
    return @content;
  } else {
  }
}

# Do a generic search of the database
sub _do_search {
  my ($self,$url,$params) = @_;

  my $agent = WWW::Mechanize->new();
  $agent->get($url);
  my $response = $agent->submit_form(#form_name => 'form1',
				     fields    => \%$params );
  if ($response->is_success) {
    my $content = $response->contet;
    print $content;
  } else {

  }
}

1;


=pod

=head1 NAME

Bio::GMOD::Query::WormBase - Defaults for programmatically interacting with Wormbase

=head1 SYNPOSIS

  my $adaptor = Bio::GMOD::Adaptor::FlyBase->new();

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

