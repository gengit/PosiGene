package Bio::GMOD::StandardURLs;

use strict;
use vars qw/@ISA/;
use Bio::GMOD::Util::CheckVersions;
use Bio::GMOD::Util::Rearrange;
use LWP::UserAgent;
use XML::Simple;
use Data::Dumper;

@ISA = qw/Bio::GMOD Bio::GMOD::Util::CheckVersions/;

sub available_species {
  my ($self,@p) = @_;
  my ($expanded) = rearrange([qw/EXPANDED/],@p);
  my $config  = ($self->standard_urls) ? $self->standard_urls : $self->_parse_xml();

  my %species;
  my @species = @{$config->{species}};
  foreach (@species) {
    $species{$_->{binomial_name}} = $_->{short_name};
  }
  return \%species if $expanded;
  return (wantarray) ? ( sort values %species ) : (scalar keys %species);
}


sub releases {
  my ($self,@p)  = @_;
  my ($requested_species,$expanded,$status) = rearrange([qw/SPECIES EXPANDED STATUS/],@p);
  my $config  = ($self->standard_urls) ? $self->standard_urls : $self->_parse_xml();
  $status ||= 'available';
  my @available_releases;
  my @species = @{$config->{species}};
  foreach my $species (@species) {
    if ($requested_species) {
      next unless ($species->{short_name} eq $requested_species || $species->{binomial_name} eq $requested_species);
    }
    my @releases = _fetch_releases($species);
    foreach (@releases) {
      my $available = $_->{available};
      next if ($available eq 'yes' && $status eq 'unavailable');
      next if ($available ne 'yes' && $status eq 'available');
      if ($expanded) {
	push (@available_releases,[$_->{version},$_->{release_date},$_->{available}]);
      } else {
	push (@available_releases,$_->{version});
      }
    }
  }
  return @available_releases;
}

sub datasets {
  my ($self,@p) = @_;
  my ($requested_species,$release) = rearrange([qw/SPECIES RELEASE/],@p);
  my $config  = ($self->standard_urls) ? $self->standard_urls : $self->_parse_xml();
  $release ||= $self->get_current($requested_species);
  $release = $self->get_current($requested_species) if $release eq 'current';

  my @species = @{$config->{species}};
  my @supported_datasets = $self->supported_datasets;
  my $short_name;
  my $root = $config->{mod}->{mod_url};
  foreach (@species) {
    next unless ($_->{short_name} eq $requested_species || $_->{binomial_name} eq $requested_species);
    $short_name = $_->{short_name};
    my @releases = _fetch_releases($_);
    foreach (@releases) {
      next unless $_->{version} eq $release;
      my %urls = map { $_ => "$root/genome/$short_name/$release/$_" } @supported_datasets;
      return \%urls;
    }
  }
}


sub supported_datasets {
  my $self = shift;
  my $config  = ($self->standard_urls) ? $self->standard_urls : $self->_parse_xml();
  my @datasets = keys %{$config->{mod}->{supported_datasets}};
  return @datasets;
}


sub get_current {
  my ($self,$requested_species) = @_;
  my $config  = ($self->standard_urls) ? $self->standard_urls : $self->_parse_xml();
  my @species = @{$config->{species}};
  foreach (@species) {
    next unless ($_->{short_name} eq $requested_species || $_->{binomial_name} eq $requested_species);
    my @releases = _fetch_releases($_);
    my $most_recent = $releases[-1]->{version};
    return $most_recent;
  }
}

sub fetch {
  my ($self,@p) = @_;
  my ($species,$dataset,$release,$url) = rearrange([qw/SPECIES DATASET RELEASE URL/],@p);
  my $config  = ($self->standard_urls) ? $self->standard_urls : $self->_parse_xml();
  my $version = $self->biogmod_version;
  my $ua = LWP::UserAgent->new();
  $ua->agent("Bio::GMOD::StandardURLs.pm/$version");
  my $root = $config->{mod}->{mod_url};

  $species = $self->get_shortname($species);
  unless ($url) {
    $release ||= $self->get_current($species);
    $release = $self->get_current($species) if $release eq 'current';
    $self->logit(-msg=>"You must specify a species, dataset, and release") unless ($species && $dataset && $release);
    $url = "$root/genome/$species/$release/$dataset";
  }

  # Does this work?
  my $request = HTTP::Request->new('GET',$url);
  my $response = $ua->request($request);
  $self->logit(-msg=>"Couldn't fetch $url: $!") unless $response->is_success;

  if ($response->is_success) {
    my $content = $response->content();
    return $content;
  }
  return 0;
}

# Accessors
sub standard_urls { return shift->{standard_urls}; }

sub get_shortname {
  my ($self,$species) = @_;
  my $config  = ($self->standard_urls) ? $self->standard_urls : $self->_parse_xml();
  my @species = @{$config->{species}};
  foreach (@species) {
    return $_->{short_name} if ($_->{short_name} eq $species);
    return $_->{short_name} if ($_->{binomial_name} eq $species);
  }
}

# Parse the standard URLs XML
sub _parse_xml {
  my $self = shift;
  my $adaptor = $self->adaptor;
  my $standard_urls = $adaptor->standard_urls_xml;
  my $version = $self->biogmod_version;
  my $ua = LWP::UserAgent->new();
  $ua->agent("Bio::GMOD::StandardURLS.pm/$version");
  my $request = HTTP::Request->new('GET',$standard_urls);

  my $response = $ua->request($request);
  die "Couldn't fetch $standard_urls: $!\n" unless $response->is_success;

  my $content = $response->content;
  my $config = XMLin($content);

  # Cache the content for multiple requests
  $self->{standard_urls} = $config;
  return $config;
}


sub _fetch_releases {
  my $species = shift;
  my @releases;
  if (ref $species->{release} eq 'ARRAY') {
    @releases = @{$species->{release}};
  } else {
    my %release = %{$species->{release}};
    push @releases,\%release;
  }
  return @releases;
}



1;


__END__


=pod

=head1 NAME

Bio::GMOD::StandardURLs - Discover and fetch Standard URLs from MODs

=head1 SYNPOSIS

  my $mod = Bio::GMOD::StandardURLS->new(-mod => 'WormBase');
  my @species  = $mod->available_species;

=head1

This module provides a programmatic interface to the common URLs
provided by Model Organism Databases. These URLs simplify the
retrieval of common datasets from using standard URLs.  The full
specification is described at the end of this document.

=head1 PUBLIC METHODS

=over 4

=item $mod->available_species();

Fetch a list of available species available by the Standard URL
mechanism at the current MOD.  Called in array context, returns a list
of species in the form "G_species" (e.g. C_elegans). These abbreviated
binomial names conform to the specification for subsequent requests.
Called in scalar context, this method returns the number of species
available.  If passed the optional "-expanded" parameters, this method
returns a hash reference of full binomial names pointing to their
abbreviated name.

This method is a programmatic equivalent to accessing the standard URL:

    http://your.site/genome

=item $mod->releases(-species=>'Caenorhabditis elegans',-status=>'available');

Fetch all of the available releases for a provided species. Called in
array context, releases() returns an array of all available releases
for the given species.  Species can be either the full binomial name
(e.g. "Caenorhabditis elegans") or the abbreviated short form
(e.g. "C_elegans").

Provided with the optional '--expanded' method, this method returns an
array of arrays containing the version, date released, and
availability of the release.  The optional '-status' parameter filters
the returned releases.  Options are 'available' to return only those
that are currently available, 'unavailable' to return those no longer
available.  If not supplied, all known releases will be returned.

This method is a programmatic equivalent to accessing the standard URL:

    http://your.site/genome/Binomial_name

=item $mod->data_sets(-species=>$species,-release=>$release);

Fetch all of the available urls for a given species and data
release. If release is not provided, defaults to the current release
(or you may explictly request "current". Returns a hash reference
where the keys are symbolic names of datasets and values are URLs to
the dataset.

This method is a programmatic equivalent to accessing the standard URL:

    http://your.site/genome/Binomial_name/release_name

=item $mod->fetch(@options);

Fetch the specified dataset.  Note: this could be a very large file!
Available options.

 Options:
 -url      The full URL to the dataset
   OR specify a dataset with species, release, and dataset:
 -species  The binomial name or abbreviated form of the species
 -release  The version to fetch
 -dataset  The symbolic name of the dataset (dna, mrna, etc)

This method is a programmatic equivalent to accessing the standard URL:

    http://your.site/genome/Binomial_name/release_name/[dataset]


=item $mod->supported_datasets();

Fetch a list of symbolic names of supported datasets.  This typically
will be a list like "dna", "mrna", "ncrna", "protein", and "feature".

=back

=head1 Standard URL Specification

=head2 PHASE I

Substitutions:

	your.site	Host address, e.g. www.wormbase.org
	Binomial_name	NCBI Taxonomy scientific name, e.g.
			Caenorhabditis_elegans
        release_name    Data release, in whatever is the local
			format (e.g. release date, release number)

=over 4

=item http://your.site/genome/

Leads to index page for species. This should be an HTML-format page
that contains links to each of the species whose genomes are available
for download.

=item http://your.site/genome/Binomial_name/

Leads to index for releases for species Binomial_name. This will be an
HTML-format page containing links to each of the genome releases.

=item http://your.site/genome/Binomial_name/release_name/ 

Leads to index for the named release.  It should be an HTML-format
page containing links to each of the data sets described below.

=item http://your.site/genome/Binomial_name/current/

Leads to the index for the most recent release, symbolic link style.

=item http://your.site/genome/Binomial_name/current/dna

Returns a FASTA file containing big DNA fragments
(e.g. chromosomes). MIME type is application/x-fasta.

=item http://your.site/genome/Binomial_name/current/mrna

Returns a FASTA file containing spliced mRNA transcript
sequences. MIME type is application/x-fasta.

=item http://your.site/genome/Binomial_name/current/ncrna

Returns a FASTA file containing non-coding RNA sequences. MIME type is
application/x-fasta.

=item http://your.site/genome/Binomial_name/current/protein

Returns a FASTA file containing all the protein sequences known to be
encoded by the genome. MIME type is application/x-fasta

=item http://your.site/genome/Binomial_name/current/feature

Returns a GFF3 file describing genome annotations. MIME type is
application/x-gff3.

=back

=head2  PHASE II

In the phase 2 URL scheme, we'll be able to attach ?format=XXXX to
each of the URLs:

=item http://your.site/genome/?format=HTML

    Same as default for phase I.

=item http://your.site/genome/?format=RSS

Return RSS feed indicating what species are available.

=item http://your.site/genome/Binomial_name/?format=RSS
	
Return RSS feed indicating what releases are available.

=item http://your.site/genome/Binomial_name/release_name/?format=RSS
	
Return RSS feed indicating what data sets are available.

=item http://your.site/genome/Binomial_name/current/protein?format=XXX

Alternative formats for sequence data.  E.g. XXX could be FASTA, RAW,
or whatever (for further discussion).

=cut
