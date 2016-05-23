package Bio::GMOD::Admin::Update::WormBase;

use strict;
use vars qw/@ISA/;
use Bio::GMOD::Admin::Update;
#use Bio::GMOD::Admin::Monitor::httpd;
#use Bio::GMOD::Admin::Monitor::acedb;
#use Bio::GMOD::Admin::Monitor::mysqld;
#use Bio::GMOD::Admin::Monitor::blat;
use Bio::GMOD::Util::Rearrange;
use File::Path 'rmtree';


@ISA = qw/Bio::GMOD::Admin::Update/;

################################################
#  WormBase-specific update methods
################################################
sub update {
  my ($self,@p) = @_;
  my $adaptor = $self->adaptor;
  $adaptor->parse_params(@p);

  my $version = $adaptor->version;
  my $rsync_module = $adaptor->rsync_module;

  $self->analyze_logs(-version => $version,
		      -site    => `hostname`);
  $self->prepare_tmp_dir();
  $self->fetch_acedb(-version        => $version);
  $self->fetch_elegans_gff(-version  => $version);
  $self->fetch_briggsae_gff(-version => $version);
  $self->fetch_blast_blat(-version   => $version);
  $self->rsync_software(-module       => $rsync_module,
                        -install_root => '/usr/local/wormbase/');
}

sub fetch_acedb {
  my ($self,@p) = @_;
  $self->logit(-msg      => 'Fetching and installing Acedb',
	       -emphasis => 1);

  my $adaptor = $self->adaptor;
  $adaptor->parse_params(@p);

  # Version to update to
  my $version = $adaptor->version;

  # Where to find the database tarballs.
  my $databases = $adaptor->database_repository;

  # The acedb tarball
  my $acedb  = sprintf($adaptor->acedb_tarball,$version);

  # Local and remote paths
  my $remote_path = "$databases/$version/$acedb";
  my $local_path  = $adaptor->tmp_path . "/$version";

  # Make sure there is enough space first
  my $disk_space = $adaptor->acedb_disk_space;
  $self->check_disk_space(-path      => $local_path,
			  -required  => $disk_space,
			  -component => 'acedb');

  $self->mirror(-remote_path => $remote_path,
		-local_path  => $local_path);

  my $acedb_path = $adaptor->acedb_path;

  unless ($adaptor->dl_only) {
    $self->logit(-msg => "Unpacking and installing $acedb");
    chdir($acedb_path);
    system("gunzip -c $local_path/$acedb | tar -x --no-same-owner -f -");
    unlink($acedb_path . '/elegans');
    symlink("elegans_$version",'elegans');

    # Adjust permissions
    my $command = <<END;
chown -R acedb $acedb_path/elegans*
chgrp -R acedb $acedb_path/elegans*
chmod 2775 $acedb_path/elegans*
##chown acedb $acedb_path/bin/*
##chgrp acedb $acedb_path/bin/*
END

    $self->test_for_error(system($command),"Fetching and installing acedb for WormBase");
  }
}


sub fetch_elegans_gff {
  my ($self,@p) = @_;
  $self->logit(-msg=>'Fetching and installing C. elegans GFF database',
	       -emphasis => 1);
  my $adaptor = $self->adaptor;
  $adaptor->parse_params(@p);

  # Version to update to
  my $version = $adaptor->version;

  # Where to find the database tarballs.
  my $databases = $adaptor->database_repository;

  # The gff tarball
  my $gff       = sprintf($adaptor->elegans_gff_tarball,$version);

  # Local and remote paths
  my $remote_path = "$databases/$version/$gff";
  my $local_path  = $adaptor->tmp_path . "/$version";

  # Make sure there is enough space first
  my $disk_space = $adaptor->elegans_gff_disk_space;
  $self->check_disk_space(-path      => $local_path,
			  -required  => $disk_space,
			  -component => 'elegans_gff');

  $self->mirror(-remote_path => $remote_path,
		-local_path  => $local_path);

  my $mysql_path = $adaptor->mysql_path;


  unless ($adaptor->dl_only) {
    $self->logit(-msg => "Unpacking and installing $gff");
    my $command = <<END;
cd $mysql_path
mv elegans elegans.bak
mv elegans_pmap elegans_pmap.bak
gunzip -c $local_path/$gff | tar xvf -
rm -rf elegans.bak
rm -rf elegans_pmap.bak
chgrp -R mysql elegans_pmap
chgrp -R mysql elegans
chown -R mysql elegans_pmap
chown -R mysql elegans
END

    $self->test_for_error(system($command),"Fetching and installing C. elegans GFF database for WormBase");
  }
}

sub fetch_blast_blat {
  my ($self,@p) = @_;
  $self->logit(-msg=>'Fetching and installing BLAST databases',
	       -emphasis => 1);
  my $adaptor = $self->adaptor;
  $adaptor->parse_params(@p);

  # Version to update to
  my $version = $adaptor->version;

  # Where to find the database tarballs.
  my $databases = $adaptor->database_repository;

  # The gff tarball
  my $blast = sprintf($adaptor->blast_tarball,$version);

  # Local and remote paths
  my $remote_path = "$databases/$version/$blast";
  my $local_path  = $adaptor->tmp_path . "/$version";

  # Make sure there is enough space first
  my $disk_space = $adaptor->blast_disk_space;
  $self->check_disk_space(-path      => $local_path,
			  -required  => $disk_space,
			  -component => 'blast');

  $self->mirror(-remote_path => $remote_path,
		-local_path  => $local_path);

  unless ($adaptor->dl_only) {
    $self->logit(-msg => "Unpacking and installing $blast");
    my $command = <<END;
cd /usr/local/wormbase
# Deal with blat
rm -rf blat.previous
mkdir blat.previous
mv blat/* blat.previous/.

# Create the blast directory
mkdir blast
gunzip -c $local_path/$blast | tar -x --no-same-owner -f -
mv blast_$version blast/.
rm -f blast/blast
cd blast/
ln -s blast_$version blast

# Fix permissions as necessary
chgrp -R wormbase /usr/local/wormbase/blat
chmod 2775 /usr/local/wormbase/blat

END

  $self->test_for_error(system($command),"Fetching and installing blast databases for WormBase");
  }
}


sub fetch_briggsae_gff {
  my ($self,@p) = @_;
  $self->logit(-msg=>'Fetching and installing C. briggsae GFF database',
	       -emphasis => 1);
  my $adaptor = $self->adaptor;
  $adaptor->parse_params(@p);

  # Version to update to
  my $version = $adaptor->version;

  # Where to find the database tarballs.
  my $databases = $adaptor->database_repository;

  # The gff tarball
  my $gff       = sprintf($adaptor->briggsae_gff_tarball,$version);

  # Local and remote paths
  my $remote_path = "$databases/$version/$gff";
  my $local_path  = $adaptor->tmp_path . "/$version";

  my $disk_space = $adaptor->briggsae_disk_space;
  $self->check_disk_space(-path      => $local_path,
			  -required  => $disk_space,
			  -component => 'briggsae_gff');

  my $result = $self->mirror(-remote_path => $remote_path,
			     -local_path  => $local_path);

  # If the briggsae GFF isn't present it hasn't been updated
  # This is not yet complete!  Note that the packaging script also
  # needs to be updated.
  #  unless ($result) {
  #    # Do we have a briggsae DB installed? If not, fetch the stable version
  #    unless (-d "$mysql_path/briggsae") {
  #      my $stable = $adaptor->database_repository_stable;
  #      my $remote_path = $stable . "/briggsae/$gff";
  #    }
  #  }

  my $mysql_path = $adaptor->mysql_path;
  unless ($adaptor->dl_only) {
    $self->logit(-msg => "Unpacking and installing $gff");
    my $command = <<END;
cd $mysql_path
mv briggsae briggsae.bak
gunzip -c $local_path/$gff | tar -xf -
rm -rf briggsae.bak
chgrp -R mysql briggsae
chown -R mysql briggsae
END

    $self->test_for_error(system($command),"Fetching and installing C. briggsae GFF database for WormBase");
  }
}


# THe libraires are not included above
# This really needs to be worked in
# This will only be used for WormBase packages
#sub fetch_libraries {
#  my $version = shift;
#  my $ftp = "ftp://$ftp_site/$ftp_path/$version";
#  chdir("$TMP/$version");
#
#  my $ignore_libraries;
#  if (! -e "libraries_$version.tgz") {
#    $self->logit(-msg     => "Downloading libraries_$version.ace.tgz - $version-specific libraries");
#    my $lib_path = $ftp_site . FTP_LIBRARIES;
#    $ignore_libraries = system("curl -O ftp://$lib_path/libraries_$version.tgz");
#    # $ignore_libraries = system("curl -O ftp://$lib_path/libraries_current.tgz");
#    $self->logit(-msg     => "Couldn't fetch/no new libraries for $version: $!, not rebuilding");
#  }
#  
#  unless ($ignore_libraries) {
#    $self->logit(-msg     => "Unpacking and installing libraries_$version.tgz");
#    system("gunzip -c libraries_$version.tgz | tar xf -");
#    chdir("libraries_$version");
#    system("cp -r Library /Library");
#    system("cp -r usr /usr");
#    # Link the current blast databases
#    chdir("/usr/local/blast");
#    symlink('/usr/local/wormbase/blast/blast','databases');
#  }
#}



#########################################################
# Log analysis
#########################################################
sub analyze_logs {
  my ($self,@p) = @_;
  my ($site,$version) = rearrange(qw/SITE VERSION/,@p);
  $site    ||= `hostname`;
  return unless $version;

  $self->logit(-msg      => 'Analyzing server logs',
	       -emphasis => 1);

  $version    =~ /WS(.*)/;
  my $old_version = 'WS' . ($version - 1);
  my $result = system("/usr/local/wormbase/util/log_analysis/analyze_logs $old_version $site");

  # We've already fired off the log analysis.  Restart apache to intialize new logs.
  # THIS SHOULD BE PART OF MONITOR
  system('sudo /usr/local/apache/bin/apachectl restart');
}



# This is rather out of date
# Configure MySQL and nobody for access to the current database I
# should make sure that the database is running.  If not, start it.
#sub add_user_perms_to_db {
#  my $self = shift;
#  # This privs should be granted to the current user?
#  # Granting of privs will be handled in the individual data modules
#  my $command = <<END;
#mysql -u root -e 'grant select on elegans.* to nobody@localhost'
#mysql -u root -e 'grant select on elegans_pmap.* to nobody@localhost'
#mysql -u root -e 'grant select on briggsae.* to nobody@localhost'
#END
#
#  $self->test_for_error(system($command),"Adjusting permissions for MySQL databases");
#}


# clear the cache
sub clear_cache {
  my ($self,@p) = @_;
  my ($cache) = rearrange([qw/CACHE/],@p);
  $self->logit(-msg      => 'Clearing disk cache',
	       -emphasis => 1);

  $cache ||= '/usr/local/wormbase/cache';
  chdir $cache;
  my @remove;
  opendir(D,$cache) or $self->logit(-msg => "Couldn't open $cache: $!",die=>1);
  while (my $f = readdir(D)) {
    next unless -d $f;
    next if $f eq 'README';
    next if $f eq 'CVS';
    next if $f =~ /^\./;
    push @remove,$f;
  }
  closedir D;
  rmtree(\@remove,0,0);
}



__END__

=pod

=head1 NAME

Bio::GMOD::Admin::Update::WormBase - Methods for updating a WormBase installation

=head1 SYNOPSIS

  # Update your WormBase installation
  use Bio::GMOD::Admin::Update;
  my $mod = Bio::GMOD::Admin::Update->new(-mod => 'WormBase');
  $mod->update(-version => 'WS136');

=head1 DESCRIPTION

Bio::GMOD::Admin::Update::WormBase contains subroutines that simplify the
maintenance of a WormBase installation.  You will not normally need to
create a Bio::GMOD::Admin::Update::WormBase object manually - these will be
created automatically by Bio::GMOD::Admin::Update.

=head1 PUBLIC METHODS

=over 4

=item $mod = Bio::GMOD::Admin::Update->new()

The generic new() method is provided by Bio::GMOD.pm.  new() provides
the ability to override system installation paths.  If you have a
default WormBase installation this should not be necessary. In
particular, the following paths may differ on your system:

  --tmp_path    The full path to your temporary download directory
  --mysql_path  The full path to your mysql directory
  --acedb_path  The full path to your acedb directory

If these options are not provided, the installer will download files
to /usr/local/gmod/tmp, install acedb files at /usr/local/acedb,
and install GFF mysql databases at /usr/local/mysql/data.

See Bio::GMOD.pm and Bio::GMOD::Adaptor for a full description of all default
paths for your MOD of interest.

=item $mod->update(@options)

update() is provided as convenience, wrapping individual methods for
downloading prepackaged databases necessary for a MOD installation.
Typically, update() is provided by the MOD adaptor of interest.

For the Bio::GMOD::Admin::Update::WormBase module, update() performs the
following steps:

   - fetch a tarball of the acedb database
   - fetch tarballs of several MySQL GFF databases
   - fetch blast and blat database tarballs
   - unpack tarballs and adjust permissions
   - rsyncs software to the production server

Required options are:

 -version     The WS version to update to (if available on the server)

If you'd like to simply download but not install the prepackaged
databases, you can pass boolean true using:

 -dl_only    download but not install

update() returns a list of all components succesfully downloaded (and
installed) if succesful or false if an error occured.  You can fetch
the nature of the error by calling $mod->status

=item fetch_acedb, fetch_elegans_gff, fetch_briggsae_gff, fetch_blast

These four methods can all be used to fetch and install the four
primary components of a WormBase installation as outlined above.

Like update(), you can specify the -version and -dl_only options as
discussed above.  This enables you to write scripts that download
several different versions of the database for a single instance of
WormBase::Update.  You may also specify either acedb_path or
mysql_path to specify the path to the acedb installation directory or
the mysql data directory as appropriate instead of supplying it to the
new() method.

=item $mod->analyze_logs(-version=>'WS130');

Analyze WormBase logs for the previous version. You must specify the
WS version of the previous version.  This method requires that you
have both Analog and Report Magic installed and that they exist in
your path (or the superusers path).  Large access logs can take some
time to analyze.  This option will also analyze logs on a year-to-date
and server lifetime-to-date basis.

=item $mod->cleanup()

Delete the contents of the temporary directory.  Due to the size of
the prepackaged databases, this is not recommended unless all steps
have succeeded!

=back

=head1 PRIVATE METHODS

None.

=head1 BUGS

None reported.

=head1 SEE ALSO

L<Bio::GMOD>, L<Bio::GMOD::Admin::Update>, L<Bio::GMOD::Adaptor>

=head1 AUTHOR

Todd W. Harris E<lt>harris@cshl.eduE<gt>.

Copyright (c) 2003-2005 Cold Spring Harbor Laboratory.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


1;
