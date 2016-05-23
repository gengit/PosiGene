package Bio::GMOD::CMap::Config;

# vim: set ft=perl:

# $Id: Config.pm,v 1.17 2008/01/16 04:13:05 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Config - handles config files

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Config;

=head1 DESCRIPTION

This module handles config files

=head1 EXPORTED SUBROUTINES

=cut 

use strict;
use Class::Base;
use Config::General;
use Data::Dumper;
use Bio::GMOD::CMap::Constants;
use File::Spec::Functions;
use Carp;

use base 'Class::Base';

# ----------------------------------------------------
sub init {
    my ( $self, $config ) = @_;
    $self->params( $config, 'config_dir' );
    $self->set_config() or return $self->error();
    return $self;
}

# ----------------------------------------------------
sub read_config_dir {

=pod

=head2 read_config_dir

Reads in config files from the conf directory.
Requires a global conf and at least one db specific conf.
The conf dir and the global conf file are specified in Constants.pm

=cut

    my $self       = shift;
    my $suffix     = 'conf';
    my $global     = GLOBAL_CONFIG_FILE;
    my $config_dir = $self->config_dir;
    my %config_data;

    #
    # Get files from directory (taken from Bio/Graphics/Browser.pm by lstein)
    #
    croak "$config_dir is not a directory" unless -d $config_dir;
    opendir( D, $config_dir ) or croak "Couldn't open '$config_dir': $!";
    my @conf_files
        = map { catfile( $config_dir, $_ ) } grep {/\.$suffix$/} readdir(D);
    close D;

    #
    # Try to work around a bug in Apache/mod_perl which appears when
    # running under linux/glibc 2.2.1
    #
    unless (@conf_files) {
        @conf_files = glob( $config_dir . "/*.$suffix" );
    }

    #
    # Read config data from each file and store it all in a hash.
    #
    foreach my $conf_file (@conf_files) {
        my $conf = Config::General->new($conf_file)
            or croak "Trouble reading config '$conf_file'";
        my %config = $conf->getall
            or croak "No configuration options present in '$conf_file'";

        if ( $conf_file =~ /$global$/ ) {
            $self->{'global_config'} = \%config;
        }
        else {
            my $db_name = $config{'database'}{'name'}
                || croak
                qq[Config file "$conf_file" does not defined a db name];
            if ( $config_data{$db_name} ) {
                croak qq[Two config files share the "$db_name" name.];
            }
            $config_data{$db_name} = \%config;
        }
    }

    #
    # Need a global and specific conf file
    #
    croak 'No "global.conf" found in ' . $config_dir
        unless $self->{'global_config'};
    croak 'No database conf files found in ' . $config_dir
        unless %config_data;
    $self->{'config_data'} = \%config_data;

    return 1;
}

# ----------------------------------------------------
sub set_config {

=pod

=head2 set_config

Sets the active config data.

=cut

    my $self        = shift;
    my $config_name = shift;

    unless ( $self->{'config_data'} ) {
        $self->read_config_dir() or return $self->error;
    }

    #
    # If config_name specified, check if it exists.
    #
    if ($config_name) {
        if (    $self->{'config_data'}{$config_name}
            and $self->{'config_data'}{$config_name}{'is_enabled'} )
        {
            $self->{'current_config'} = $config_name;
            return 1;
        }
    }

    unless ( $self->{'current_config'} ) {

        #
        # If the default db is in the global_config
        # and it exists, set that as the config.
        #
        if (   $self->{'global_config'}{'default_db'}
            && $self->{'config_data'}
            { $self->{'global_config'}{'default_db'} }
            && $self->{'config_data'}
            { $self->{'global_config'}{'default_db'} }{'is_enabled'} )
        {
            $self->{'current_config'}
                = $self->{'global_config'}{'default_db'};
            return 1;
        }

        #
        # No preference set.  Just let Fate (keys) decide.
        #
        foreach my $config_name ( keys %{ $self->{'config_data'} } ) {
            if ( $self->{'config_data'}{$config_name}{'is_enabled'} ) {
                $self->{'current_config'} = $config_name;
                last;
            }
        }
    }

    return 1 if ( $self->{'current_config'} );

    croak "No enabled config files\n";
}

# ----------------------------------------------------
sub get_config_names {

=pod

=head2 get_config_names

Returns an array ref of the keys to $self->{'config_data'}.

=cut

    my $self = shift;
    return [
        grep { $self->{'config_data'}{$_}{'is_enabled'} }
            keys %{ $self->{'config_data'} }
    ];
}

# ----------------------------------------------------
sub get_config {

=pod

=head2 config

Returns one option from the config files.
optionally you can specify a set of config data to read from.

=cut

    my ( $self, $option, $specific_db ) = @_;

    #
    # If config not set, set it.
    #
    unless ( $self->{'current_config'} ) {
        $self->set_config() or return $self->error();
    }

    return $self unless $option;

   #
   # If a specific db conf file was asked for use it otherwise use the current
   # config
   #
    $specific_db ||= $self->{'current_config'};

    my $value;

    #
    # Is it in the global config
    #
    if ( defined $self->{'global_config'}{$option} ) {
        $value = $self->{'global_config'}{$option};
    }
    else {

        #
        # Otherwise get it from the other config.
        #
        $value
            = defined $self->{'config_data'}{$specific_db}{$option}
            ? $self->{'config_data'}->{$specific_db}{$option}
            : DEFAULT->{$option};
    }

    if ( defined($value) ) {
        return wantarray && ( ref $value eq "ARRAY" ) ? @$value : $value;
    }
    else {
        return wantarray ? () : '';
    }
}

# ----------------------------------------------------
sub config_dir {

=pod

=head2 config_dir

  $self->config_dir('/path/to/alt/conf');

Allows an alternate location of config files.

=cut

    my $self = shift;
    return $self->{'config_dir'} || CONFIG_DIR;
}

1;

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.
Ken Y. Clark E<lt>kclark@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-6 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

