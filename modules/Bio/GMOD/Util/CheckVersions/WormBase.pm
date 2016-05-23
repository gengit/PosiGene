package Bio::GMOD::Util::CheckVersions::WormBase;
use strict;

use Bio::GMOD::Util::CheckVersions;
use Bio::GMOD::Util::Rearrange;

use vars qw/@ISA/;

@ISA = qw/Bio::GMOD::Util::CheckVersions/;

sub local_version {
  my ($self,@p) = @_;
  my ($path,$parent) = rearrange([qw/ACEDB_PATH PARENT/],@p);
  my $adaptor = ($parent) ? $parent->adaptor : $self->adaptor;
  $path ||= $adaptor->acedb_path . '/elegans';
  my ($realdir,$modtime) = $self->read_symlink($path);
  my ($installed) = $realdir =~ /(WS\d+)$/;
  $installed = ($installed) ? $installed : 'None installed';

  my %response = ( title   => 'WormBase, the C. elegans database',
		   site     => "local installation at $path",
		   version  => $installed,
		   released => $modtime,
		   status   => ($installed ne 'None installed') ? 'SUCCESS' : $installed);
  return (wantarray ? %response : $response{version});
}


# =head3 PACKAGES
# SITE IS OPTIONAL (reads PACKAGE from SiteDefaults)
# The site/local should be model for other subs
# Pass --site to override the default site for the currently selected adaptor
# Pass --local to fetch the version from the local filesystem
#      (optionally include a --path option for the local path)
#       Defaults to reading CURRENT_PACKAGE_SYMLINK in the SiteDefaults
# INFRASTRUCUTRE FOR COMPATIBILITY
# There should be a current_release symlink pointing to
# the current package version

# Fetch the current version of the package
# This can be done by reading the local file system
# or from the CGI itself
#sub package_version {
#  my ($self,@p) = @_;
#  my ($path) = rearrange([qw/PATH/],@p);
#  my $response;
#  if ($path) {
#    # Try to fetch the current package version from the local filesystem
#    my ($realdir,$release,$modtime) = _read_symlink($path);
#    $response = ( # title   => 'WormBase, the C. elegans database',
#		 site     => "local installation at $path",
#		 version  => $release,
#		 released => $modtime,
#		 status   => ($release ne 'None installed') ? 'success' : $release);
#  } else {
#    # If not trying to fetch the data from a local server,
#    # just use the development server
#    $response = _check_version_cgi($self->development_url);
#  }
#  return \%$response;
#}


__END__



=pod

=head1 NAME

Bio::GMOD::Util::CheckVersions::WormBase - Versioning code for WormBase

=head1 SYNOPSIS

  use Bio::GMOD::Util::CheckVersions;
  my $gmod   = Bio::GMOD::Util::CheckVersions->new(-mod => 'WormBase');
  my $live   = $gmod->live_version();
  my $dev    = $gmod->development_version();
  my $local  = $gmod->local_version();

=head1 DESCRIPTION

Bio::GMOD::Util::CheckVersions::WormBase implements a single method
for checking the locally installed version of WormBase.  The generic
live_version and development_version provided by the CheckVersions
parent class are used to check the current versions on the live and
developement sites.

=head1 PUBLIC METHODS

=over 4

=item $mod->local_version()

Fetch the locally installed version of AceDB.  This script attempts to
read the symlink located at /usr/local/acedb/elegans, parsing out the
WSXXX version:

      elegans -> elegans_WS129

As with the other version checks, local_version() returns the WSXXX
when called in scalar context, or a hash containing status, title,
site, version, and released keys.

The -acedb_path option can be used to override the default path if you
store your databases in a different location.

If your installation does not symlink elegans to the installed version
of the database, this subroutine may fail.

=back

=head2 PRIVATE METHODS

None.

=head1 BUGS

None reported.

=head1 SEE ALSO

L<Bio::GMOD>

=head1 AUTHOR

Todd Harris E<lt>harris@cshl.eduE<gt>.

Copyright (c) 2003-2005 Cold Spring Harbor Laboratory.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


1;
