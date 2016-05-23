package Bio::GMOD::Adaptor;

use strict;
use vars qw/@ISA/;
use LWP::UserAgent;
use Bio::GMOD::Util::CheckVersions;
use Bio::GMOD::Util::Rearrange;

@ISA = qw/
  Bio::GMOD
  Bio::GMOD::Util::CheckVersions
  /;
#  Bio::GMOD::StandardURLs

sub new {
  my ($self,$overrides) = @_;
  my $adaptor = bless {},$self;
  eval {"require $self"} or $self->logit(-msg => "Couldn't require the $self package: $!",-die => 1);

  # Is a defaults script available?
  # This should be converted to XML
  if ($adaptor->defaults_cgi) {
    my $ua      = LWP::UserAgent->new();
    my $version = $self->biogmod_version;
    $ua->agent("Bio::GMOD.pm/$version");
    my $request = HTTP::Request->new('GET',$adaptor->defaults_cgi);
    my $response = $ua->request($request);

    if ($response->is_success) {
      # Parse out the content and store the defaults in the object
      my $content = $response->content;
      my @lines = split("\n",$content);
      foreach (@lines) {
	next if /^\#/;  # ignore comments
	my ($key,$val) = split("=");
	$adaptor->{defaults}->{lc($key)} = $val;
      }
      $adaptor->{status} = "SUCCESS";
    } else {
      # Couldn't fetch the defaults script - maybe working offline

      # Until fully tested, let's require that you be online.
      # WiMax is coming anyways, right ;)

      $adaptor->logit(-msg => "Couldn't fetch defaults script:\n\t"
		      . $response->status_line .
		      "\n\tYou may be working offline. Defaults will be populated from adaptor object",
		      # -die=>1
		     );
    }
  }

  # Override some of the defaults if requested
  foreach my $key (keys %$overrides) {
    my $value = $overrides->{$key};
    next unless $value;
    $adaptor->{defaults}->{lc($key)} = $value;
  }

  my @defaults = $self->defaults;

  # Finally, fetch the values hardcoded in the Adaptor::*
  foreach my $key (@defaults) {
    next if defined $adaptor->{defaults}->{lc($key)};
    $key = lc ($key);
    my $hard_coded = $adaptor->$key;
    next unless $hard_coded;
    $adaptor->{defaults}->{$key} = $hard_coded;
  }
  return $adaptor;
}

# Generically accept parameters, loading them into the adaptor object.
sub parse_params {
  my ($self,@p) = @_;
  return unless @p;
  my %params = @p;
  foreach my $key (keys %params) {
    my $value = $params{$key};
    # strip of leading hypens.
    # Some may have two coming from @ARGV and command line
    $key =~ s/^\-\-{0,1}//;
    # next if defined $self->{defaults}->{lc($key)};
    $self->{defaults}->{lc($key)} = $value;
  }
}


__END__


=pod

=head1 NAME

Bio::GMOD::Adaptor - Generic factory for Bio::GMOD::Adaptor::* objects

=head1 SYNPOSIS

  my $adaptor = Bio::GMOD::Adaptor->new(-mod => 'WormBase');

=head1 DESCRIPTION

Bio::GMOD::Adaptor acts as a generic factor for Bio::GMOD::Adaptor::*
objects.  You will not interact directly with Bio::GMOD::Adaptor
objects.

Bio::GMOD::Adaptor primarily serves to read in default values for
common variables.  These can be provided by a CGI, hardcoded in the
Adaptor object, or supplied as named options to the new() constructor.

=head1 PUBLIC METHODS

=over 4

=item Bio::GMOD::Adaptor->new(@p);

Create a new Bio::GMOD::Adaptor::* object. new() reads in
default values from the WormBase server. These values will be
overridden by like-named key-value pairs passed in the @p array.

Defaults are stored in the object by lower case hash key corresponding
to the default name. Adaptor objects are usually housed within other
objects, say a Bio::GMOD::Update object.  You can always can access to
the adaptor object itself by calling

    my $adaptor = $gmod_object->adaptor;

And to access a variable:

    my $value = $adaptor->default_name

Variable names can be populated in one of three ways, or by mixing and
matching any of these approaches.  In order of precedence, they are:

=over 4

=item 1. As named arguments passed to new()

   Bio::GMOD::Update->new(-mysql_path => '/usr/local/var');

Options provided in this manner will override like-named variables
defined in steps 2 or 3.

=item 2. Via a custom CGI that returns key=value pairs

See, for example, the WormBase defaults cgi in
etc/defaults.wormbase.cgi.  This approach gives developers additionaly
flexibility for end users -- particularly in cases where file system
paths on the server-side or data model nuances may be in flux.  Users
need not have the newest version of the Bio::GMOD module in order to
have the most up-to-date data.

The obvious drawback of this approach is that it requires users to be
online.

=item 3. Hardcoded in the Adaptor::"Your Mod" module

=back

In reality, you may wish to provide some aspect of each of these
approaches to define site-specific variables.

=item $adaptor->parse_params(@p);

Parse supplied parameters for new variables of those overriding system
defaults.  Each option will be loaded into the Bio::GMOD::Adaptor::* object
with the option name as a key.  A corresponding (lowercase) accessor
method will also be created.

Returns an ordered list of:
    ftp_path : full path to the ftp site, including ftp://path/release
    tmp_path : full path to the temporary directory
    release  : the WSXXX release to fetch
    dl_only  : boolean flag whether the databases should simply be downloaded
    acedb_path : full path to the acedb data directory
    mysql_path : full path to the mysql data directory

=back

=head1 DEFINING YOUR OWN VARIABLE NAMES

You can freely define your own variables names in a
Bio::GMOD::Adaptor::"Your MOD" subclass for use in, say, a
Bio::GMOD::Update::"Your MOD" subclass.  These variables will be
AUTOLOAD'ed, becoming Bio::GMOD::Adaptor::"Your MOD" (or
Bio::GMOD::Adaptor) methods as appropriate.

The following variable names are protected. Some Bio::GMOD modules
utilize these variable names to set defaults.

  tmp_path      Full path to the temporary directory
  ftp_site      The FTP host from which to retrieve files
  version       The current version of the MOD of interest (may be
                   a live or development version)
  install_root  The full path to the MOD installation
  rsync_url     The URL of an rsync server, if required
  rsync_module  An rsync module name to sync to

These can always be overridden using the named parameter style of
method calls.

=head1 BUGS

None reported.

=head1 SEE ALSO

L<Bio::GMOD>

=head1 AUTHOR

Todd W. Harris E<lt>harris@cshl.eduE<gt>.

Copyright (c) 2003-2005 Cold Spring Harbor Laboratory.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


1;




