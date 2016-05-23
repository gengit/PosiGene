=pod

# NOT YET CONVERTED!!!

=head1 NAME

Bio::GMOD::Admin::Archive::WormBase - archiving of WormBase releases

=head1 SYNOPSIS

 use Bio::GMOD::Admin::Archive;
 my $archive = Bio::GMOD::Admin::Archive->new(-mod=>'WormBase');

 $archive->create_archive();

=head1 METHODS

=over 4

=item Bio::GMOD::ADmin::Archive->new(@options)

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



#############################################
# PRIVATE SUBROUTINES
#############################################
# Acedb
sub _package_acedb {
  my $self     = shift;
  my $repository    = $self->database_repository;
  my $new_archive   = $self->{to_package};
  my $acedb_path    = $self->acedb_path;
  my $base = "$repository/$new_archive";
  my $command = <<END;
mkdir -p $base
tar -czf $base/elegans_${new_archive}.ace.tgz -C ${acedb_path} elegans_${new_archive} --exclude 'database/oldlogs' --exclude 'database/serverlog.wrm*' --exclude 'database/log.wrm'
END
;

system($command) == 0 or return 0;
return 1;
}

# The elegans GFF database
sub _package_elegans_gff {
  my $self     = shift;
  my $repository = $self->database_repository;
  my $new_archive  = $self->{to_package};
  my $mysql_data   = $self->mysql_path;
  my $base = "$repository/$new_archive";
my $command = <<END;
mkdir -p $base
tar -czf $base/elegans_${new_archive}.gff.tgz -C ${mysql_data} elegans elegans_pmap --exclude '*bak*'
END
;

system($command) == 0 or return 0;
return 1;
}

# The C. briggsae GFF database
sub _package_briggsae_gff {
  my $self     = shift;
  my $repository = $self->database_repository;
  my $new_archive   = $self->{to_package};
  my $mysql_data   = $self->mysql_path;
  my $base = "$repository/$new_archive";
  my $command = <<END;
mkdir -p $base
tar -czf $base/briggsae_${new_archive}.gff.tgz -C ${mysql_data} briggsae --exclude '*bak*'
END
;

system($command) == 0 or return 0;
return 1;
}

  # package up the blast and blat databases together
  sub _package_blast {
    my $self     = shift;
    my $repository = $self->database_repository;
    my $new_archive   = $self->{to_package};
    my $base = "$repository/$new_archive";
    my $command = <<END;
mkdir -p $base
tar -czf $base/blast.${new_archive}.tgz -C /usr/local/wormbase/blast blast_${new_archive} -C /usr/local/wormbase blat --exclude 'old_nib' --exclude  'CVS'
END
;

system($command) == 0 or return 0;
return 1;
}

=pod

=item _adjust_symlink()

Adjust the current_release symlink in the archives directory so that
it points at the newly packaged databases.

=cut

# Adjust the symlink for the current archive
sub _adjust_symlink {
  my $self     = shift;
  my $repository = $self->database_repository;
  my $new_archive   = $self->{to_package};
  chdir($repository);

  $new_archive     =~ /WS(.*)/;
  my $dev_version  = $1;
  my $live_version = 'WS' . ($dev_version - 1);

  unlink("$repository/development_release");
  symlink("$new_ws","$tarballs/development_release");
  unlink("$repository/live_release");
  symlink("$live_version","$tarballs/live_release");
}


=pod

=item do_archive()

=cut

# Archive critical files from the raw release
# THIS WORKS FOR WORMBASE BUT NOT FOR GENERIC RELEASES
#sub do_archive {
#  my $self = shift;
#  my $new_archive = $self->{to_package};
#  $new_archive =~ /WS(.*)/;
#  my $ws = $1;
#  my $base = $self->ftp_root;
#
#  # Files to archive
#  my $wormpep   = CURRENT . "/wormpep$ws.tar.gz";
#  my $wormrna   = CURRENT . "/wormrna$ws.tar.gz";
#  my $gff       = CURRENT . "/GENE_DUMPS/elegans$new_ws.gff.gz";
#  my $pmap      = CURRENT . "/GENE_DUMPS/elegans-pmap$new_ws.gff.gz";
#  my $confirmed = CURRENT . "/confirmed_genes.$new_ws.gz";
#  my $genes     = CURRENT . "/gene_interpolated_map_positions.$new_ws.gz";
#  my $geneids   = CURRENT . "/geneIDs.$new_ws.gz";
#  my $letter    = CURRENT . "/letter.$new_ws";
#
#  my $archive = $self->archive_repository;
#
#  my $command = <<END;
#mkdir $archive/$new_ws;
#cp $wormpep $archive/$new_ws/.
#cp $wormrna $archive/$new_ws/.
#cp $gff $archive/$new_ws/.
#cp $pmap $archive/$new_ws/.
#cp $confirmed $archive/$new_ws/.
#cp $genes $archive/$new_ws/.
#cp $geneids $archive/$new_ws/.
#cp $letter $archive/$new_ws/.
#
#END
#;
#
#system($command) == 0 or return 0;
#return 1;
#}


=head1 BUGS

None reported.

=head1 SEE ALSO

=head1 AUTHOR

Todd W. Harris E<lt>harris@cshl.eduE<gt>.

Copyright (c) 2003-2005 Cold Spring Harbor Laboratory.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


