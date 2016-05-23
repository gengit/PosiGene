=pod

# NOT YET CONVERTED!!!

=head1 NAME

WormBase::Archive::Build - Create archives of Wormbase releases

=head1 SYNOPSIS

 use Bio::GMOD::Admin::Archive;
 my $archive = Bio::GMOD::Admin::Archive->new();

 $archive->create_archive();

=head1 METHODS

=over 4

=item Bio::GMOD::Admin::Archive->new(@options)

Create a new WormBase::Archive object for archiving WormBase releases.

The options consist largely of file system and remote paths.  If none
are provided, they will all be populated from the default file located
on the primary WormBase server.  This is the recommended idiom as it
insulates your programs from structural changes at WormBase.  In this
case, archives will be built in /pub/wormbase/RELEASE where RELEASE is
a WSXXX release.

There are, however, at least two options that you will wish to
provide:

  --database_repository  Full path where to store archives on your filesystem
  --mysql_path           Full path to the mysql data dir

See WormBase.pm for additional details on all system-dependent paths
that can be overridden.

=head1 ARCHIVING RELEASES

Creating an archive of a release is as easy as

  my $result = $archive->create_archive();

Read on for full details about how this works.

=head1 PUBLIC METHODS

=item $archive->create_archive(@options)

Build tarballs of WormBase releases. Available options are:

  -components  Which packages to create (see below)
  -release  WSXXX release version (default is the current release)
  -rebuild  Pass a boolean true to force rebuilding of a package that
            has already been built.

The --components option accepts an array reference of which packages

to create.

Available components are:
  acedb         the acedb database for the current release
  elegans_gff   the C. elegans GFF database
  briggsae_gff  the C. briggsae GFF database
  blast         the blast and blat databases

If --components is not specified, all of the above will be packaged.

=item _package_acedb
      _package_elegans_gff
      _package_briggsae_gff
      _package_blast_blat

Subroutines that handle packaging of each of the individual
components.

=cut

package Bio::GMOD::Admin::Archive;

use vars qw/@ISA $VERSION/;
use Bio::GMOD;
use Bio::GMOD::Util::CheckVersions;
use Bio::GMOD::Util::Rearrange;
@ISA = qw/Bio::GMOD Bio::GMOD::Util::CheckVersions/;

sub create_archive {
  my ($self,@p) = @_;
  my ($to_package,$rebuild,$components) = rearrange([qw/RELEASE REBUILD COMPONENTS/],@p);
  my $current_db = $self->local_version();

  # Is the requested version on the server?
  if ($to_package) {
    if ($to_package ne $current_db) {
      return "The currently installed version ($current_db) does not match the requested package build ($to_package). Package not created. Exiting...";
    }
  } else {
    $to_package = $current_db;
  }

  # Check to see if this release has already been packaged
  my $current_package = $self->package_version();
  if ($current_package eq $to_package && !$rebuild) {
    return "$to_package has already been packaged. Pass the --rebuild option to build_package() to rebuild"
  }

  $self->{to_package} = $to_package;
  my @components = @$components if ($components);
  @components = qw/acedb elegans_gff briggsae_gff blast/ unless @components > 0;
  my %components = map {$_ => 1 } @components;
  $self->_package_acedb()          or die "Couldn't package acedb database for $to_package: $!\n" 
    if (defined $components{acedb});
  $self->_package_elegans_gff()    or die "Couldn't package elegans GFF database for $to_package: $!\n"
    if (defined $components{elegans_gff});
  $self->_package_briggsae_gff()   or die "Couldn't package briggsae GFF database for $to_package: $!\n"
    if (defined $components{briggsae_gff});
  $self->_package_blast()          or die "Couldn't package blast/blat databases for $to_package: $!\n"
    if (defined $components{blast});
  $self->_adjust_symlink()         or die "Couldn't adjust symlinks to new database tarballs for $to_package: $!\n";
  $self->do_archive()              or die "Couldn't do archiving for $to_package: $!\n";
}



# This should be handling tarring and gzipping
sub create_archive {

}


=head1 BUGS

None reported.

=head1 SEE ALSO

=head1 AUTHOR

Todd W. Harris E<lt>harris@cshl.eduE<gt>.

Copyright (c) 2003-2005 Cold Spring Harbor Laboratory.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


