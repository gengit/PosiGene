package Bio::GMOD::Admin::Update;

use strict;
use vars qw/@ISA $AUTOLOAD/;

use Bio::GMOD;
use Bio::GMOD::Util::Mirror;
use Bio::GMOD::Util::CheckVersions;
use Bio::GMOD::Util::Rearrange;

@ISA = qw/Bio::GMOD Bio::GMOD::Util::CheckVersions/;

# Currently, there is no generic update method.  Bio::GMOD::Admin::Update
# must be subclassed for your particular MOD
sub update {
  my $self = shift;
  my $adaptor = $self->adaptor;
  my $name = $adaptor->name;
  $self->logit("$name does not currently support automated updates at this time. Please ask the administrators of $name to add this functionality.",
	       -die => 1);
}


# MORE TWEAKS NEEDED - configuration, verbosity, etc
sub mirror {
  my ($self,@p) = @_;
  my ($remote_path,$local_path,$is_optional)
    = rearrange([qw/REMOTE_PATH LOCAL_PATH IS_OPTIONAL/],@p);
  my $adaptor = $self->adaptor;
  $local_path ||= $adaptor->tmp_path;
  $self->logit(-msg => "Must supply a local path in which to download files",
	       -die => 1) unless $local_path;
  my $ftp = Bio::GMOD::Util::Mirror->new(-host      => $adaptor->ftp_site,
					 -path      => $remote_path,
					 -localpath => $local_path,
					 -verbose   => 1);
  my $result = $ftp->mirror();

  # TODO: Clear out the local directory if mirroring fails
  # TODO: Resumable downloads.
  if ($result) {
    $self->logit(-msg     => "$remote_path successfully downloaded");
  } else {
    if ($is_optional) {
      $self->logit(-msg => "$remote_path failed to download, installation is optional: $!");
    } else {
      $self->logit(-msg         => "$remote_path failed to download: $!",
		   -die         => 1);
    }
  }
  return 1;
}



#########################################################
# Rsync tasks
#########################################################
sub rsync_software {
  my ($self,@p) = @_;
  my ($rsync_module,$exclude,$install_root) = rearrange([qw/MODULE EXCLUDE INSTALL_ROOT/],@p);
  $self->logit(-msg=>"Rsync'ing software",-emphasis=>1);
  my $adaptor     = $self->adaptor;
  $adaptor->parse_params(@p);
  $install_root ||= $adaptor->install_root;
  $rsync_module .= '/' unless ($rsync_module =~ /\/$/);  # Add trailing slash

  my $rsync_url   = $adaptor->rsync_url;
  $rsync_module ||= $adaptor->rsync_module;
  my $rsync_path   = $rsync_url . ($rsync_module ? "/$rsync_module" : '');
  # print "$install_root $rsync_module $exclude $rsync_path\n";
  my $result = system("rsync -rztpovl $exclude $rsync_path $install_root");
  $self->test_for_error($result,"Rsync'ing the mirror site");
}


#########################################################
# Housecleaning: checking for diskspace, etc
#########################################################
sub check_disk_space {
  my ($self,@p) = @_;
  my ($path,$required,$component) = rearrange([qw/PATH REQUIRED COMPONENT/],@p);
  my ($mount_point,$available) = $self->get_available_space($path); # calculated in GB

  if ($available >= $required) {
    $self->logit(-msg=>"Sufficient space to install $component ($required GB required; $available GB available)");
  } else {
    $self->logit(-msg=>"Insufficient space to install $component ($required GB required; $available GB available)",-die=>1);
  }
  return 1;
}

sub get_available_space {
  my ($self,$path) = @_;
  return unless $path;

  my $cmd = "df -k $path";
  open (IN, "$cmd |") or $self->logit(-msg =>"get_available_space: Cannot run df command ($cmd): $!",-die=>1);

  my ($mount_point, $available_space);
  my $counter;
  while (<IN>) {
    next unless /^\//;
    my ($filesystem, $blocks, $used, $available, $use_percent, $mounted_on) = split(/\s+/);
    $mount_point = $mounted_on;
    $available_space = sprintf("%.2f", $available/1048576);
    $counter++;
  }

  unless ($mount_point && $available_space) { 
    $self->logit("get_available_space: Internal error: Cannot parse df cmd ($cmd)",-die=>1);
  }
  return ($mount_point,$available_space);
}

sub prepare_tmp_dir {
  my ($self,@p)  = @_;
  my ($tmp_path,$sync_to) = rearrange([qw/TMP_PATH SYNC_TO/],@p);
  my $adaptor  = $self->adaptor;
  $adaptor->{defaults}->{tmp_path} = $tmp_path if $tmp_path;

  my $method = $sync_to . "_version";
  my $version  = $self->$method || 'unknown_version';
  $tmp_path ||= $adaptor->tmp_path;
  my $full_path = "$tmp_path/$version";

  unless (-e "$full_path") {
    $self->logit(-msg => "Creating temporary directory at $full_path");
    my $command = <<END;
mkdir -p $full_path
chmod -R 0775 $full_path
END
;
  my $result = system($command);
    if ($result == 0) {
      $self->logit(-msg => "Successfully created temporary directory");
    } else {
      $self->logit(-msg => "Cannot make temporary directory: $!",
		   -die => 1);
    }
  }
  return 1;
}

sub cleanup {
  my ($self,@p) = @_;
  my $tmp = $self->tmp_path;
  $self->logit(-msg => "Cleaning up $tmp");
  system("rm -rf $tmp/*");
}


__END__


=pod

=head1 NAME

Bio::GMOD::Admin::Update - Generics methods for updating a Bio::GMOD installation

=head1 SYNOPSIS

  # Update your Bio::GMOD installation
  use Bio::GMOD::Admin::Update;
  my $mod = Bio::GMOD::Admin::Update->new(-mod => 'WormBase');
  $mod->update(-version => 'WS136');

=head1 DESCRIPTION

Bio::GMOD::Admin::Update contains subroutines that simplify the maintenance
of a Bio::GMOD installation.

=head1 PUBLIC METHODS

=over 4

=item $mod = Bio::GMOD::Admin::Update->new()

The generic new() method is provided by Bio::GMOD.pm.  new() provides
the ability to override system installation paths.  If you have a
default installation for your MOD of interest, this should not be
necessary. You will not normally interact with Bio::GMOD::Admin::Update
objects, but instead with Bio::GMOD::Admin::Update::"MOD" objects.

See Bio::GMOD.pm and Bio::GMOD::Adaptor::* for a full description of
all default paths for your MOD of interest.

=item $mod->update(@options)

update() is a wrapper method that should be overriden by
Bio::GMOD::Admin::Update::"MOD" update().  The update() method should execute
all steps necessary for a basic installation, returing an array of all
components installed.

See Bio::GMOD::Admin::Update::WormBase for an example subclass.  See
bin/gmod_update_installation-wormbase.pl for a more detailed script
that relies on this subclass.

=item $mod->mirror(@options);

Generic mirroring of files or directories provided by the
Bio::GMOD::Util::Mirror module.  If no options are provided, they will
be fetched from the MOD default values stored in Bio::GMOD::Adaptor::*

Options:
 -remote_path   Relative to the ftp root, file or directory to mirror
 -local_path    Full path to the local destination directory
 -is_optional   Warn instead of dying on errors

=item $mod->prepare_tmp_dir(@options)

 Options:
 -tmp_path    full path to a temporary download directory
 -sync_to     site to synchronize to (live || dev)

Prepare the temporary directory for downloading. The temporary
directory is supplied by Bio::GMOD::Adaptor::* or can be overridden by
passing a "-tmp_path=" option.  If provided with
"-sync_to=[live|dev]", this method will prepare a temporary directory
according at "$tmp_path/$version" of the appropriate live or
development site.

=item $mod->rsync_software(@options);

Rsync the local software to a remote module. Options will be culled
from the Adaptor::MOD unless specified.

 Options:
 -module        Name of the rsync module to sync to
 -exclude       Array referene of items to exclude
 -install_root  Local dsetination path

=item $mod->check_disk_space(@options);

Check that a provided path has sufficient disk space for an install.

 Options:
 -path      Full path to inspect for space
 -required  Amount of space required for an install
 -component Symbolic name of the component being installed (for logging)

Returns true if there is sufficient space; dies with an error message
otherwise.

=item $mod->get_available_space(-path => $path);

Companion method to check_disk_space.  Returns an array consisting of
the mount point and available space for the provided path.

=item $mod->cleanup()

Delete the contents of the temporary directory following an update.
See Bio::GMOD::Admin::Update::* for how this method might affect you!

=back

=head1 BUGS

None reported.

=head1 SEE ALSO

L<Bio::GMOD>, L<Bio::GMOD::Util::CheckVersions>

=head1 AUTHOR

Todd W. Harris E<lt>harris@cshl.eduE<gt>.

Copyright (c) 2003-2005 Cold Spring Harbor Laboratory.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


1;












