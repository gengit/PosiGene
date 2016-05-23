#!/usr/bin/perl

package Bio::GMOD::CMap::Admin::Interactive;

# $Id: Interactive.pm,v 1.8 2008/06/28 19:49:43 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Admin::Interactive - A command line interface for admin
actions

=head1 SYNOPSIS

This object acts as a go between for the command line script cmap_admin.pm and
Admin.pm.


  use Bio::GMOD::CMap::Admin::Interactive;

  my $interactive = Bio::GMOD::CMap::Admin::Interactive->new(
    user       => $>,            # effective UID
    no_log     => $no_log,
    datasource => $datasource,
    config_dir => $config_dir,
    file       => shift,
  );

=head1 METHODS

=cut

use strict;
use vars '$VERSION';
$VERSION = '1.3';

use File::Path;
use File::Spec::Functions;
use IO::File;
use IO::Tee;
use Data::Dumper;
use Term::ReadLine;
use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Admin;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Data;
use Bio::GMOD::CMap::Utils;
use Bio::GMOD::CMap::Admin::Import();
use Bio::GMOD::CMap::Admin::Export();
use Bio::GMOD::CMap::Admin::MakeCorrespondences();
use Bio::GMOD::CMap::Admin::ImportCorrespondences();
use Bio::GMOD::CMap::Admin::ManageLinks();
use Bio::GMOD::CMap::Admin::SavedLink;
use Bio::GMOD::CMap::Admin::GFFProducer;
use Benchmark;

use base 'Bio::GMOD::CMap';

use constant STR => 'string';
use constant NUM => 'number';
use constant OFS => "\t";       # ouput field separator
use constant ORS => "\n";       # ouput record separator

#
# Turn off output buffering.
#
$| = 1;

# ----------------------------------------------------
sub init {

=pod

=head2 init

=head3 Description

Initializes the interface object.

=head3 Synopsis

  my $interactive = Bio::GMOD::CMap::Admin::Interactive->new(
    user       => $>,            # effective UID
    no_log     => $no_log,
    datasource => $datasource,
    config_dir => $config_dir,
    file       => shift,
  );

=head3 Parameters

=over 4

=item * datasource

CMap Datasource, required if using the command line options

=item * config_dir

Directory that the config files are located in.  Used when there are
alternative installations of CMap.

=item * no_log

Don't create a log file

=item * file

An inbput file

=item * user

user id for determining the home directory

=back

=cut

    my ( $self, $config ) = @_;
    $self->params( $config, qw[ config_dir file user no_log ] );
    unless ( $self->{'config'} ) {
        $self->{'config'} = Bio::GMOD::CMap::Config->new(
            config_dir => $self->{'config_dir'}, );
    }

    if ( $config->{'datasource'} ) {
        $self->data_source( $config->{'datasource'} ) or die $self->error;
    }
    return $self;
}

# ----------------------------------------------------
sub admin {

=pod

=head2 admin

=head3 Description

Get or initiate the CMap::Admin object

=head3 Parameters

No Parameters

=cut

    my $self = shift;

    unless ( $self->{'admin'} ) {
        $self->{'admin'} = Bio::GMOD::CMap::Admin->new(
            db          => $self->db,
            data_source => $self->data_source,
            config      => $self->{'config'},
        );
    }

    return $self->{'admin'};
}

# ----------------------------------------------------
sub file {

=pod

=head2 file

=head3 Description

Gets/Sets a single file that can be acted apon by the methods 

=head3 Parameters

=over 4

=item * file

=back

=cut

    my $self = shift;
    $self->{'file'} = shift if @_;
    return $self->{'file'} || '';
}

# ----------------------------------------------------
sub no_log {

=pod

=head2 no_log

=head3 Description

Gets/Sets the no_log flag

=head3 Parameters

=over 4

=item * arg

=back

=cut

    my $self = shift;
    my $arg  = shift;
    $self->{'no_log'} = $arg if defined $arg;

    unless ( defined $self->{'no_log'} ) {
        $self->{'no_log'} = 0;
    }
    return $self->{'no_log'};
}

# ----------------------------------------------------
sub user {

=pod

=head2 user

=head3 Description

Returns the user id

=head3 Parameters

No Parameters

=cut

    my $self = shift;
    return $self->{'user'} || '';
}

# ----------------------------------------------------
sub log_filename {

=pod

=head2 log_filename

=head3 Description

Creates the log file name based on the user's home directory

=head3 Parameters

No Parameters

=cut

    my $self = shift;
    unless ( $self->{'log_filename'} ) {
        my ($name,    $passwd, $uid,      $gid, $quota,
            $comment, $gcos,   $home_dir, $shell
        ) = getpwuid( $self->user );

        my $filename = 'cmap_admin_log';
        my $i        = 0;
        my $path;
        while (1) {
            $path = catfile( $home_dir, $filename . '.' . $i );
            last unless -e $path;
            $i++;
        }

        $self->{'log_filename'} = $path;
    }

    return $self->{'log_filename'};
}

# ----------------------------------------------------
sub log_fh {

=pod

=head2 log_fh

=head3 Description

The log file handle

=head3 Parameters

No Parameters

=cut

    my $self = shift;

    if ( $self->no_log ) {
        return *STDOUT;
    }
    else {
        unless ( $self->{'log_fh'} ) {
            my $path = $self->log_filename or return;
            my $fh = IO::Tee->new( \*STDOUT, ">$path" )
                or return $self->error("Unable to open '$path': $!");
            print $fh "Log file created '", scalar localtime, ".'\n";
            $self->{'log_fh'} = $fh;
        }
        return $self->{'log_fh'};
    }
}

# ----------------------------------------------------
sub term {

=pod

=head2 term

=head3 Description

Gets/Sets the terminal object

=head3 Parameters

No Parameters

=cut

    my $self = shift;

    unless ( $self->{'term'} ) {
        $self->{'term'} = Term::ReadLine->new('Map Importer');
    }

    return $self->{'term'};
}

# ----------------------------------------------------
sub quit {

=pod

=head2 quit

=head3 Description

Quits the program after tidying up.

=head3 Parameters

No Parameters

=cut

    my $self = shift;

    if ( defined $self->{'log_fh'} ) {
        my $log_fh = $self->log_fh;
        print $log_fh "Log file closed '", scalar localtime, ".'\n";
        print "Log file:  ", $self->log_filename, "\n\n";
    }

    exit(0);
}

# ----------------------------------------------------
sub show_greeting {

=pod

=head2 show_greeting

=head3 Description

Present the opening menu of options and returns the response

=head3 Parameters

No Parameters

=cut

    my $self      = shift;
    my $separator = '-=' x 10;

    my $menu_options = [
        {   action  => 'change_data_source',
            display => 'Change current data source',
        },
        {   action  => 'create_species',
            display => 'Create new species'
        },
        {   action  => 'create_map_set',
            display => 'Create new map set'
        },
        {   action  => 'import_data',
            display => 'Import data',
        },
        {   action  => 'export_data',
            display => 'Export data'
        },
        {   action  => 'delete_data',
            display => 'Delete data',
        },
        {   action  => 'make_name_correspondences',
            display => 'Make name-based correspondences'
        },
        {   action  => 'delete_duplicate_correspondences',
            display => 'Delete duplicate correspondences'
        },
        {   action  => 'reload_correspondence_matrix',
            display => 'Reload correspondence matrix'
        },
        {   action  => 'purge_query_cache_menu',
            display => 'Purge the cache to view new data'
        },
        {   action  => 'import_links',
            display => 'Import links'
        },
    ];

    if ( $self->config_data('gbrowse_compatible') ) {
        push @$menu_options,
            {
            action  => 'prepare_for_gbrowse',
            display => 'Prepare the Database for GBrowse data'
            };
        push @$menu_options,
            {
            action  => 'copy_cmap_into_gbrowse',
            display => 'Copy CMap into the GBrowse database'
            };
        push @$menu_options,
            {
            action  => 'copy_gbrowse_into_cmap',
            display => 'Copy GBrowse into the CMap database'
            };
    }

    push @$menu_options,
        {
        action  => 'quit',
        display => 'Quit'
        };
    print "\nCurrent data source: ", $self->data_source, "\n";

    my $action = $self->show_menu(
        title =>
            join( "\n", $separator, '  --= Main Menu =--  ', $separator ),
        prompt  => 'What would you like to do?',
        display => 'display',
        return  => 'action',
        data    => $menu_options,
    );

    return $action;
}

# ----------------------------------------------------
sub change_data_source {

=pod

=pod

=head2 change_data_source

=head3 Description

Menu system to change which datasource is being used

=head3 Parameters

No Parameters

=cut

    my $self = shift;

    my $data_source = $self->show_menu(
        title   => 'Available Data Sources',
        prompt  => 'Which data source?',
        display => 'display',
        return  => 'value',
        data    => [
            map { { value => $_->{'name'}, display => $_->{'name'} } }
                @{ $self->data_sources }
        ],
    );

    $self->data_source($data_source) or warn $self->error, "\n";
}

# ----------------------------------------------------
sub create_species {

=pod

=head2 create_species

=head3 Description

If command_line is true, checks for required options and creates a species.

If command_line is not true, uses a menu system to get the species options.

=head3 Parameters

=over 4

=item * command_line

=item * species_full_name (required if command_line)

=item * species_common_name

=item * species_acc

=back

=cut

    my ( $self, %args ) = @_;
    my $command_line        = $args{'command_line'};
    my $species_full_name   = $args{'species_full_name'};
    my $species_common_name = $args{'species_common_name'}
        || $species_full_name;
    my $species_acc = $args{'species_acc'} || '';
    print "Creating new species.\n";

    if ($command_line) {
        my @missing = ();
        unless ( defined($species_full_name) ) {
            push @missing, 'species_full_name';
        }
        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            return 0;
        }
    }
    else {
        print "Full Species Name (long): ";
        chomp( $species_full_name = <STDIN> || 'New Species' );

        print "Common Name [$species_full_name]: ";
        chomp( $species_common_name = <STDIN> );
        $species_common_name ||= $species_full_name;

        print "Accession ID (optional): ";
        chomp( $species_acc = <STDIN> );

        print "OK to create species '$species_full_name' in data source '",
            $self->data_source, "'?\n[Y/n] ";
        chomp( my $answer = <STDIN> );
        return if $answer =~ m/^[Nn]/;
    }

    my $admin      = $self->admin;
    my $species_id = $admin->species_create(
        species_acc         => $species_acc         || '',
        species_common_name => $species_common_name || '',
        species_full_name   => $species_full_name   || '',
        )
        or do {
        print "Error: ", $admin->error, "\n";
        return;
        };

    my $log_fh = $self->log_fh;
    print $log_fh "Species $species_common_name created\n";

    $self->purge_query_cache( cache_level => 1 );
    return $species_id;
}

# ----------------------------------------------------
sub create_map_set {

=pod

=head2 create_map_set

=head3 Description

If command_line is true, checks for required options and creates a map_set.

If command_line is not true, uses a menu system to get the map_set options.

=head3 Parameters

=over 4

=item * command_line

=item * map_type_acc (required if command_line)

=item * species_id or species_acc (required if command_line)

=item * map_set_name (required if command_line)

=item * map_set_acc

=item * map_color

=item * map_width

=item * map_set_short_name

=item * map_shape

=back

=cut

    my ( $self, %args ) = @_;
    my $sql_object         = $self->sql or die $self->error;
    my $command_line       = $args{'command_line'};
    my $map_set_name       = $args{'map_set_name'};
    my $map_set_short_name = $args{'map_set_short_name'};
    my $species_id         = $args{'species_id'};
    my $species_acc        = $args{'species_acc'};
    my $map_type_acc       = $args{'map_type_acc'};
    my $map_set_acc        = $args{'map_set_acc'};
    my $map_shape          = $args{'map_shape'};
    my $map_color          = $args{'map_color'};
    my $map_width          = $args{'map_width'};

    print "Creating new map set.\n";

    if ($command_line) {
        my @missing = ();
        unless ( defined($map_set_name) ) {
            push @missing, 'map_set_name';
        }
        unless ( defined($map_set_short_name) ) {
            $map_set_short_name ||= $map_set_name;
        }
        if ($species_id) {
            my $return
                = $sql_object->get_species( species_id => $species_id );
            unless ( @{ $return || [] } ) {
                print STDERR "The species_id, '$species_id' is not valid.\n";
                push @missing, 'species_id or species_acc';
            }
        }
        elsif ($species_acc) {
            $species_id = $sql_object->acc_id_to_internal_id(
                acc_id      => $species_acc,
                object_type => 'species'
            );
            unless ($species_id) {
                print STDERR
                    "The species_acc, '$species_acc' is not valid.\n";
                push @missing, 'species_id or species_acc';
            }
        }
        else {
            push @missing, 'species_id or species_acc';
        }

        if ( defined($map_type_acc) ) {
            unless ( $self->map_type_data($map_type_acc) ) {
                print STDERR
                    "The map_type_acc, '$map_type_acc' is not valid.\n";
                push @missing, 'map_type_acc';
            }
        }
        else {
            push @missing, 'map_type_acc';
        }

        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            return 0;
        }
    }
    else {
        my $species_info = $self->show_menu(
            title   => 'Available Species',
            prompt  => 'What species?',
            display => 'species_common_name',
            return  => 'species_id,species_common_name',
            data    => $sql_object->get_species(),
        );

        my $species_common_name;
        ( $species_id, $species_common_name ) = @{ $species_info || [] };

        unless ($species_id) {
            print "No species!  Please use cmap_admin.pl to create.\n";
            return;
        }
        my $map_type;
        ( $map_type_acc, $map_type ) = $self->show_menu(
            title   => 'Available Map Types',
            prompt  => 'What type of map?',
            display => 'map_type',
            return  => 'map_type_acc,map_type',
            data    => $self->fake_selectall_arrayref(
                $self->map_type_data(), 'map_type_acc', 'map_type'
            )
        );
        die "No map types! Please use the config file to add some.\n"
            unless $map_type_acc;

        print "Map Study Name (long): ";
        chomp( $map_set_name = <STDIN> || 'New map set' );

        print "Short Name [$map_set_name]: ";
        chomp( $map_set_short_name = <STDIN> );
        $map_set_short_name ||= $map_set_name;

        print "Accession ID (optional): ";
        chomp( $map_set_acc = <STDIN> );

        $map_color = $self->map_type_data( $map_type_acc, 'color' )
            || $self->config_data("map_color");

        $map_color = $self->show_question(
            question   => 'What color should this map set be?',
            default    => $map_color,
            valid_hash => COLORS,
        );

        $map_shape = $self->map_type_data( $map_type_acc, 'shape' )
            || 'box';

        $map_shape = $self->show_question(
            question   => 'What shape should this map set be?',
            default    => $map_shape,
            valid_hash => VALID->{'map_shapes'},
        );

        $map_width = $self->map_type_data( $map_type_acc, 'width' )
            || $self->config_data("map_width");

        $map_width = $self->show_question(
            question => 'What width should this map set be?',
            default  => $map_width,
        );

        print "OK to create set '$map_set_name' in data source '",
            $self->data_source, "'?\n[Y/n] ";
        chomp( my $answer = <STDIN> );
        return if $answer =~ m/^[Nn]/;
    }

    my $admin      = $self->admin;
    my $map_set_id = $admin->map_set_create(
        map_set_name       => $map_set_name,
        map_set_short_name => $map_set_short_name,
        species_id         => $species_id,
        map_type_acc       => $map_type_acc,
        map_set_acc        => $map_set_acc,
        shape              => $map_shape,
        color              => $map_color,
        width              => $map_width,
        )
        or do {
        print "Error: ", $admin->error, "\n";
        return;
        };

    my $log_fh = $self->log_fh;
    print $log_fh "Map set $map_set_name created\n";

    $self->purge_query_cache( cache_level => 1 );

    return $map_set_id;
}

# ----------------------------------------------------
sub delete_data {

=pod

=head2 delete_data

=head3 Description

Menu system that determines what kind of data to delete

=head3 Parameters

No Parameters

=cut

    #
    # Deletes data.
    #
    my $self = shift;

    my $action = $self->show_menu(
        title   => 'Delete Options',
        prompt  => 'What do you want to delete?',
        display => 'display',
        return  => 'action',
        data    => [
            {   action  => 'delete_maps',
                display => 'Delete a map set (or maps within it)',
            },
            {   action  => 'delete_features',
                display => 'Delete features',
            },
            {   action  => 'delete_correspondences',
                display => 'Feature correspondences',
            },
        ]
    );

    $self->$action();
    $self->purge_query_cache( cache_level => 1 );
    return 1;
}

# ----------------------------------------------------
sub delete_correspondences {

=pod

=head2 delete_correspondences

=head3 Description

If command_line is true, checks for required options and deletes correspondences

If command_line is not true, uses a menu system to get the delete correspondences options.

=head3 Parameters

=over 4

=item * command_line

=item * map_set_accs or map_type_acc or species_acc (required if command_line)

=item * evidence_type_accs

=back

=cut

    my ( $self, %args ) = @_;
    my $command_line           = $args{'command_line'};
    my $species_acc            = $args{'species_acc'};
    my $map_set_accs           = $args{'map_set_accs'};
    my $map_type_acc           = $args{'map_type_acc'};
    my $evidence_type_accs_str = $args{'evidence_type_accs'};
    my $sql_object             = $self->sql or die $self->error;
    my $map_sets;
    my @evidence_type_accs;

    if ($command_line) {
        my @missing = ();
        if ( defined($map_set_accs) ) {

            # split on space or comma
            my @map_set_accs = split /[,\s]+/, $map_set_accs;
            if (@map_set_accs) {
                $map_sets = $sql_object->get_map_sets(
                    map_set_accs => \@map_set_accs, );
            }
            unless ( @{ $map_sets || [] } ) {
                print STDERR
                    "Map set Accession(s), '$map_set_accs' is/are not valid.\n";
                push @missing, 'valid map_set_accs';
            }
        }
        elsif ( defined($species_acc) or $map_type_acc ) {
            my $species_id;
            if ( defined($species_acc) ) {
                $species_id = $sql_object->acc_id_to_internal_id(
                    acc_id      => $species_acc,
                    object_type => 'species'
                );
                unless ($species_id) {
                    print STDERR
                        "The species_acc, '$species_acc' is not valid.\n";
                    push @missing, 'valid species_acc';
                }
            }
            if ($map_type_acc) {
                unless ( $self->map_type_data($map_type_acc) ) {
                    print STDERR "The map_type_acc, '$map_type_acc' "
                        . "is not valid.\n";
                    push @missing, 'valid map_type_acc';
                }
            }
            $map_sets = $sql_object->get_map_sets(
                species_id   => $species_id,
                map_type_acc => $map_type_acc,
            );
        }
        else {
            push @missing, 'map_set_accs or species_acc or map_type_acc';
        }
        if ( not $evidence_type_accs_str
            or $evidence_type_accs_str =~ /all/i )
        {
            @evidence_type_accs = keys( %{ $self->evidence_type_data() } );
        }
        elsif ( defined($evidence_type_accs_str) ) {
            @evidence_type_accs = split /[,\s]+/, $evidence_type_accs_str;
            my $valid = 1;
            foreach my $fta (@evidence_type_accs) {
                unless ( $self->evidence_type_data($fta) ) {
                    print STDERR
                        "The evidence_type_acc, '$fta' is not valid.\n";
                    $valid = 0;
                }
            }
            unless ($valid) {
                push @missing, 'valid evidence_type_acc';
            }
        }
        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            return 0;
        }
    }
    else {
        $map_sets = $self->get_map_sets;
        return unless @{ $map_sets || [] };
        my @map_set_names;
        if ( @{ $map_sets || [] } ) {
            @map_set_names = map {
                join( '-',
                    $_->{'species_common_name'},
                    $_->{'map_set_short_name'} )
            } @$map_sets;
        }
        else {
            @map_set_names = ('All');
        }

        my @evidence_types = $self->show_menu(
            title      => 'Select Evidence Type (Optional)',
            prompt     => 'Select evidence types',
            display    => 'evidence_type',
            return     => 'evidence_type_acc,evidence_type',
            allow_null => 0,
            allow_mult => 1,
            allow_all  => 1,
            data       => $self->fake_selectall_arrayref(
                $self->evidence_type_data(), 'evidence_type_acc',
                'evidence_type'
            )
        );

        #
        # Confirm decisions.
        #
        print join( "\n",
            'OK to delete feature correspondences?',
            '  Data source          : ' . $self->data_source,
        );
        if (@$map_sets) {
            print "\n  Map Set(s)           :\n",
                join( "\n", map {"    $_"} @map_set_names );
        }
        if (@evidence_types) {
            print "\n  Evidence Types       :\n",
                join( "\n", map {"    $_->[1]"} @evidence_types );
        }
        @evidence_type_accs = map { $_->[0] } @evidence_types;
        print "\n[Y/n] ";
        chomp( my $answer = <STDIN> );
        return if $answer =~ /^[Nn]/;

    }

    unless (@evidence_type_accs) {
        print "No evidence types selected.  Doing Nothing.\n";
        return;
    }
    my %evidence_lookup    = map { $_, 1 } @evidence_type_accs;
    my $admin              = $self->admin;
    my $log_fh             = $self->log_fh;
    my $disregard_evidence = @evidence_type_accs ? 0 : 1;

    for my $map_set (@$map_sets) {
        print $log_fh "Deleting correspondences for ",
            $map_set->{'species_common_name'}, '-',
            $map_set->{'map_set_short_name'},  "\n";
        my $map_set_acc = $map_set->{'map_set_acc'};
        my $maps
            = $sql_object->get_maps_from_map_set( map_set_acc => $map_set_acc,
            ) if ($map_set_acc);

        next unless ( $maps and @$maps );

        foreach my $map (@$maps) {
            my $map_acc = $map->{'map_acc'};
            next unless ($map_acc);
            my $corrs = $sql_object->get_feature_correspondence_details(
                included_evidence_type_accs => \@evidence_type_accs,
                map_acc2                    => $map_acc,
                disregard_evidence_type     => $disregard_evidence,
            );
            print $log_fh "Deleting correspondences for ", $map->{'map_name'},
                "\n";

            #
            # If there is more evidence supporting the correspondence,
            # then just remove the evidence, otherwise remove the
            # correspondence (which will remove all the evidence).
            #
            for my $corr (@$corrs) {
                my $all_evidence
                    = $sql_object->get_correspondence_evidences(
                    feature_correspondence_id =>
                        $corr->{'feature_correspondence_id'}, );

                my $no_evidence_deleted = 0;
                for my $evidence (@$all_evidence) {
                    next
                        unless
                        $evidence_lookup{ $evidence->{'evidence_type_acc'} };
                    $admin->correspondence_evidence_delete(
                        correspondence_evidence_id =>
                            $evidence->{'correspondence_evidence_id'} );
                    $no_evidence_deleted++;
                }

                if ( $no_evidence_deleted == scalar @$all_evidence ) {
                    $admin->feature_correspondence_delete(
                        feature_correspondence_id =>
                            $corr->{'feature_correspondence_id'} );
                }
            }
        }
    }
    $self->purge_query_cache( cache_level => 1 );
    return 1;
}

# ----------------------------------------------------
sub delete_maps {

=pod

=head2 delete_maps

=head3 Description

If command_line is true, checks for required options and deletes maps

If command_line is not true, uses a menu system to get the delete maps options.

=head3 Parameters

=over 4

=item * map_accs

=item * map_set_acc

=item * command_line

=back

=cut

    #
    # Deletes a map set.
    #
    my ( $self, %args ) = @_;
    my $command_line = $args{'command_line'};
    my $map_set_acc  = $args{'map_set_acc'};
    my $map_accs_str = $args{'map_accs'};
    my $sql_object   = $self->sql or die $self->error;
    my $map_set_id;
    my $map_set;
    my @map_ids;

    if ($command_line) {
        my @missing = ();
        unless ( defined($map_set_acc) or defined($map_accs_str) ) {
            push @missing, 'map_set_acc or map_accs';
        }
        if ( defined($map_accs_str) ) {
            if ( $map_accs_str =~ /^all$/i ) {
                if ( defined($map_set_acc) ) {
                    my $maps = $sql_object->get_maps_from_map_set(
                        map_set_acc => $map_set_acc, );
                    if ( @{ $maps || [] } ) {
                        @map_ids = map { $_->{'map_id'} } @$maps;
                    }
                    else {
                        print STDERR
                            "The map_set_acc, '$map_set_acc' does not have any maps.\n";
                    }
                }
                else {
                    push @missing, 'map_set_acc';
                }

            }
            else {
                my @map_accs = split /[,\s]+/, $map_accs_str;
                my $valid = 1;
                foreach my $acc (@map_accs) {
                    my $map_id = $sql_object->acc_id_to_internal_id(
                        acc_id      => $acc,
                        object_type => 'map'
                    );
                    if ($map_id) {
                        push @map_ids, $map_id;
                    }
                    else {
                        print STDERR "The map_accs, '$acc' is not valid.\n";
                        $valid = 0;
                    }
                }
                unless ($valid) {
                    push @missing, 'valid map_accs';
                }
            }
        }
        elsif ( defined($map_set_acc) ) {
            my $map_sets
                = $sql_object->get_map_sets( map_set_acc => $map_set_acc, );
            if ( @{ $map_sets || [] } ) {
                $map_set    = $map_sets->[0];
                $map_set_id = $map_set->{'map_set_id'};
            }
            unless ($map_set_id) {
                print STDERR
                    "Map set Accession, '$map_set_acc' is not valid.\n";
                push @missing, 'valid map_set_acc';
            }
        }
        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            return 0;
        }
    }
    else {
        my $map_sets
            = $self->get_map_sets( allow_mult => 0, allow_null => 0 );
        return unless @{ $map_sets || [] };
        $map_set    = $map_sets->[0];
        $map_set_id = $map_set->{'map_set_id'};

        my $delete_what = $self->show_menu(
            title   => 'Delete',
            prompt  => 'How much to delete?',
            display => 'display',
            return  => 'value',
            data    => [
                { value => 'entire', display => 'Delete entire map set' },
                { value => 'some', display => 'Delete just some maps in it' }
            ],
        );

        if ( $delete_what eq 'some' ) {
            @map_ids = $self->show_menu(
                title      => 'Restrict by Map (optional)',
                prompt     => 'Select one or more maps',
                display    => 'map_name,map_acc',
                return     => 'map_id',
                allow_null => 1,
                allow_all  => 1,
                allow_mult => 1,
                data => $sql_object->get_maps( map_set_id => $map_set_id ),
            );
        }

        my $map_names;
        if (@map_ids) {
            foreach my $map_id (@map_ids) {
                push @$map_names,
                    $sql_object->get_object_name(
                    object_id   => $map_id,
                    object_type => 'map',
                    );
            }
        }

        print join(
            "\n",
            map { $_ || () } 'OK to delete?',
            '  Data source : ' . $self->data_source,
            '  Map Set     : '
                . $map_set->{'species_common_name'} . '-'
                . $map_set->{'map_set_short_name'},
            (   @{ $map_names || [] }
                ? '  Maps        : ' . join( ', ', @$map_names )
                : ''
            ),
            '[Y/n] ',
        );

        chomp( my $answer = <STDIN> );
        return if $answer =~ /^[Nn]/;
    }

    my $admin  = $self->admin;
    my $log_fh = $self->log_fh;
    if (@map_ids) {
        for my $map_id (@map_ids) {
            print $log_fh "Deleting map ID '$map_id.'\n";
            $admin->map_delete( map_id => $map_id )
                or return $self->error( $admin->error );
        }
    }
    else {
        print $log_fh "Deleting map set "
            . $map_set->{'species_common_name'} . '-'
            . $map_set->{'map_set_short_name'} . "'\n";
        $admin->map_set_delete( map_set_id => $map_set_id )
            or return $self->error( $admin->error );
    }
    $self->purge_query_cache( cache_level => 1 );
    return 1;
}

# ----------------------------------------------------
sub delete_features {

=pod

=head2 delete_features

=head3 Description

If command_line is true, checks for required options and deletes features

If command_line is not true, uses a menu system to get the delete features options.

=head3 Parameters

=over 4 

=item * map_accs

=item * map_set_acc

=item * command_line

=item * feature_type_accs

=back

=cut

    #
    # Deletes a map set.
    #
    my ( $self, %args ) = @_;
    my $command_line          = $args{'command_line'};
    my $map_set_acc           = $args{'map_set_acc'};
    my $map_accs_str          = $args{'map_accs'};
    my $feature_type_accs_str = $args{'feature_type_accs'};
    my $sql_object            = $self->sql or die $self->error;
    my $map_set_id;
    my $map_set;
    my @map_ids;
    my @feature_type_accs;

    if ($command_line) {
        my @missing = ();
        unless ( defined($map_set_acc) or defined($map_accs_str) ) {
            push @missing, 'map_set_acc or map_accs';
        }
        if ( defined($feature_type_accs_str) ) {
            @feature_type_accs = split /[,\s]+/, $feature_type_accs_str;
            my $valid = 1;
            foreach my $fta (@feature_type_accs) {
                unless ( $self->feature_type_data($fta) ) {
                    print STDERR
                        "The feature_type_acc, '$fta' is not valid.\n";
                    $valid = 0;
                }
            }
            unless ($valid) {
                push @missing, 'valid feature_type_acc';
            }
        }
        else {
            push @missing, 'feature_type_accs';
        }
        if ( defined($map_accs_str) ) {
            my @map_accs = split /[,\s]+/, $map_accs_str;
            my $valid = 1;
            foreach my $acc (@map_accs) {
                my $map_id = $sql_object->acc_id_to_internal_id(
                    acc_id      => $acc,
                    object_type => 'map'
                );
                if ($map_id) {
                    push @map_ids, $map_id;
                }
                else {
                    print STDERR "The map_accs, '$acc' is not valid.\n";
                    $valid = 0;
                }
            }
            unless ($valid) {
                push @missing, 'valid map_accs';
            }
        }
        elsif ( defined($map_set_acc) ) {
            my $map_sets
                = $sql_object->get_map_sets( map_set_acc => $map_set_acc, );
            if ( @{ $map_sets || [] } ) {
                $map_set    = $map_sets->[0];
                $map_set_id = $map_set->{'map_set_id'};
            }
            unless ($map_set_id) {
                print STDERR
                    "Map set Accession, '$map_set_acc' is not valid.\n";
                push @missing, 'valid map_set_acc';
            }
        }
        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            return 0;
        }
    }
    else {
        my $map_sets
            = $self->get_map_sets( allow_mult => 0, allow_null => 0 );
        return unless @{ $map_sets || [] };
        $map_set    = $map_sets->[0];
        $map_set_id = $map_set->{'map_set_id'};

        my $delete_what = $self->show_menu(
            title   => 'Delete',
            prompt  => 'How much to delete?',
            display => 'display',
            return  => 'value',
            data    => [
                {   value   => 'set',
                    display => 'Delete features from entire map set'
                },
                {   value   => 'maps',
                    display => 'Delete features from some maps'
                }
            ],
        );

        if ( $delete_what eq 'maps' ) {
            @map_ids = $self->show_menu(
                title      => 'Restrict by Map (optional)',
                prompt     => 'Select one or more maps',
                display    => 'map_name,map_acc',
                return     => 'map_id',
                allow_null => 1,
                allow_all  => 1,
                allow_mult => 1,
                data => $sql_object->get_maps( map_set_id => $map_set_id ),
            );
        }

        my $map_names;
        if (@map_ids) {
            foreach my $map_id (@map_ids) {
                push @$map_names,
                    $sql_object->get_object_name(
                    object_id   => $map_id,
                    object_type => 'map',
                    );
            }
        }

        my $feature_types_ref = $self->get_feature_types;
        my $display_feature_types;
        if (@$feature_types_ref) {
            $display_feature_types = $feature_types_ref;
        }
        else {
            $display_feature_types = [ [ 'All', 'All' ], ];
        }
        @feature_type_accs = map { $_->[0] } @$feature_types_ref;

        print join(
            "\n",
            map { $_ || () } 'OK to delete?',
            '  Data source : ' . $self->data_source,
            '  Map Set     : '
                . $map_set->{'species_common_name'} . '-'
                . $map_set->{'map_set_short_name'},
            (   @{ $map_names || [] }
                ? '  Maps        : ' . join( ', ', @$map_names )
                : ''
            ),
            "  Feature Types   :\n"
                . join( "\n", map {"    $_->[1]"} @$display_feature_types ),
            '[Y/n] ',
        );

        chomp( my $answer = <STDIN> );
        return if $answer =~ /^[Nn]/;
    }

    my $admin  = $self->admin;
    my $log_fh = $self->log_fh;
    if ( $map_set_id and not @map_ids ) {
        my $maps = $sql_object->get_maps_simple( map_set_id => $map_set_id, );
        @map_ids = map { $_->{'map_id'} } @{ $maps || [] };
    }
    if (@map_ids) {
        for my $map_id (@map_ids) {
            my $features = $sql_object->get_features_simple(
                map_id            => $map_id,
                feature_type_accs => \@feature_type_accs,
            );
            print $log_fh "Deleting "
                . scalar( @{ $features || [] } )
                . " features for map ID '$map_id.'\n";
            for my $feature ( @{ $features || [] } ) {
                $admin->feature_delete(
                    feature_id => $feature->{'feature_id'} )
                    or return $self->error( $admin->error );
            }
        }
    }
    else {
        print STDERR "Problem getting map ids\n";
        return;
    }
    $self->purge_query_cache( cache_level => 1 );
    return 1;
}

# ----------------------------------------------------
sub export_data {

=pod

=head2 export_data

=head3 Description

Menu system for exporing data (no command line interface).  The type of export
chosen is then called.

=head3 Parameters

No Parameters

=cut

    #
    # Exports data.
    #
    my $self = shift;

    my $action = $self->show_menu(
        title   => 'Data Export Options',
        prompt  => 'What do you want to export?',
        display => 'display',
        return  => 'action',
        data    => [
            {   action  => 'export_as_gff',
                display => 'Data in CMap GFF3 format',
            },
            {   action  => 'export_as_text',
                display => 'Data in tab-delimited CMap format',
            },
            {   action  => 'export_as_sql',
                display => 'Data as SQL INSERT statements',
            },
            {   action  => 'export_objects',
                display => 'Database objects [experimental]',
            },
        ]
    );

    $self->$action();
    return 1;
}

# ----------------------------------------------------
sub export_as_gff {

=pod

=head2 export_as_gff

=head3 Description

Exports CMap data a CMap GFF formated file.

See "perldoc Bio::DB::SeqFeature::Store::cmap" for more information on the CMap
GFF specification.

If command_line is true, checks for required options and exports.

If command_line is not true, uses a menu system to get the export options and
then exports.

=head3 Parameters

=over 4

=item * command_line

=item * map_set_accs (comma delimited string) or species_accs or map_accs

=item * only_corrs 

Set to true to only output correspondences.

=item * ignore_unit_granularity 

Set to true to tell the exporter not to use the unit_granularity to make all of
the positions into integers.

=item * export_file

=item * directory

Directory where output file is to be placed 

=back

=cut

    #
    # Exports data in tab-delimited import format.
    #
    my ( $self, %args ) = @_;
    my $command_line            = $args{'command_line'};
    my $species_accs            = $args{'species_accs'};
    my $map_set_accs            = $args{'map_set_accs'};
    my $map_accs                = $args{'map_accs'};
    my $dir_str                 = $args{'directory'} || '.';
    my $only_corrs              = $args{'only_corrs'} || 0;
    my $ignore_unit_granularity = $args{'ignore_unit_granularity'} || 0;
    my $export_file             = $args{'export_file'};

    unless ($export_file) {
        $export_file = $self->data_source() . ".gff";
        $export_file =~ s/\s/_/g;
    }

    my $sql_object = $self->sql or die $self->error;
    my $log_fh = $self->log_fh;
    my @species_accs;
    my $species_data;
    my @map_set_accs;
    my $map_set_data;
    my @map_accs;
    my $map_data;
    my @exclude_fields;
    my $dir;

    if ($command_line) {
        my @missing = ();

        if ( defined($species_accs) ) {

            # split on space or comma
            @species_accs = split /[,\s]+/, $species_accs;
            if (@species_accs) {
                foreach my $species_acc (@species_accs) {
                    $species_data = $sql_object->get_species(
                        species_acc => $species_acc, );
                    unless ( @{ $species_data || [] } ) {
                        print STDERR
                            "Species Accession, '$species_acc' is/are not valid.\n";
                        push @missing, 'valid species_accs';
                    }
                }
            }
        }
        if ( defined($map_set_accs) ) {

            # split on space or comma
            @map_set_accs = split /[,\s]+/, $map_set_accs;
            if (@map_set_accs) {
                foreach my $map_set_acc (@map_set_accs) {
                    $map_set_data = $sql_object->get_map_sets(
                        map_set_acc => $map_set_acc, );
                    unless ( @{ $map_set_data || [] } ) {
                        print STDERR
                            "Map Set Accession, '$map_set_acc' is/are not valid.\n";
                        push @missing, 'valid map_set_accs';
                    }
                }
            }
        }
        if ( defined($map_accs) ) {

            # split on space or comma
            @map_accs = split /[,\s]+/, $map_accs;
            if (@map_accs) {
                foreach my $map_acc (@map_accs) {
                    $map_data = $sql_object->get_maps( map_acc => $map_acc, );
                    unless ( @{ $map_data || [] } ) {
                        print STDERR
                            "Map Set Accession, '$map_acc' is/are not valid.\n";
                        push @missing, 'valid map_accs';
                    }
                }
            }
        }

        $dir = $self->_get_dir( dir_str => $dir_str ) or return;
        $export_file = $self->_get_export_file(
            file_str => $export_file,
            dir      => $dir,
            default  => $export_file,
        ) or return;

        unless ( defined($dir) ) {
            push @missing, 'valid directory';
        }
        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            return 0;
        }
    }
    else {
        my $select = $self->show_menu(
            title   => 'Limit Data Export',
            prompt  => 'How would you like to limit the data export?',
            display => 'display',
            return  => 'action',
            data    => [
                {   action  => 'by_species',
                    display => 'By Species',
                },
                {   action  => 'by_map_sets',
                    display => 'By Map Sets',
                },
                {   action  => 'by_maps',
                    display => 'By Maps',
                },
                {   action  => 'export_all',
                    display => 'Export All',
                },
            ],
        );

        if ( $select eq 'by_species' ) {
            $species_data = $self->get_species or return;
            @species_accs = map { $_->{'species_acc'} } @$species_data;
        }
        elsif ( $select eq 'by_map_sets' ) {
            $map_set_data = $self->get_map_sets or return;
            @map_set_accs = map { $_->{'map_set_acc'} } @$map_set_data;
        }
        elsif ( $select eq 'by_maps' ) {
            $map_data = $self->get_maps or return;
            @map_accs = map { $_->{'map_acc'} } @$map_data;
        }

        $dir = $self->_get_dir() or return;
        $export_file
            = $self->_get_export_file( dir => $dir, default => $export_file, )
            or return;

        print join( "\n", '', "Export only correspondences? [y/N]", );
        chomp( $only_corrs = <STDIN> );
        $only_corrs = ( $only_corrs =~ /^[Yy]/ ) ? 1 : 0;

        print join( "\n",
            'Unit Granularity:',
            'The GFF specification requires that all positions be integers.',
            'To accomodate this, the exporter will devide any start and stops',
            'by the unit granularity (which is defined in the cofiguration of',
            'each map_type).  If no unit granularity is defined, it will ',
            'default to 0.001.  For example, if using the default unit ',
            'granularity, a feature start of 53.32 will become 53,320.  ',
            '',
            'If the exported data is destined to be imported into CMap and not',
            'used with any other programs, or if the unit granularities are',
            'not defined but the data consists only of integers, then ignore',
            'the unit granularity',
            '',
            "Ignore Unit Granularity [y/N]",
        );
        chomp( $ignore_unit_granularity = <STDIN> );
        $ignore_unit_granularity
            = ( $ignore_unit_granularity =~ /^[Yy]/ ) ? 1 : 0;

        #
        # Confirm decisions.
        #
        print join( "\n",
            'OK to export?',
            '  Data source              : ' . $self->data_source,
        ) . "\n";
        if (@species_accs) {
            print "  Species                  :\n"
                . join( "\n",
                map { "    " . $_->{'species_common_name'} } @$species_data )
                . "\n";
        }
        elsif (@map_set_accs) {
            print "  Map Sets                 :\n"
                . join( "\n",
                map { "    " . $_->{'map_set_name'} } @$map_set_data )
                . "\n";
        }
        elsif (@map_accs) {
            print "  Maps                     :\n" . join(
                "\n",
                map {
                          "    "
                        . $_->{'map_name'} . " - "
                        . $_->{'map_set_name'}
                    } @$map_data
            ) . "\n";
        }
        else {
            print "  Data                     : Export All\n";
        }

        if ($only_corrs) {
            print "  Export Type              : Only Correspondences\n",;
        }
        else {
            print "  Export Type              : All Data\n",;
        }

        print join( "\n",
            "  Ignore Unit Granularity  : "
                . ( $ignore_unit_granularity ? 'Yes' : 'No' ),
            "  Directory                : $dir",
            "  Output File              : $export_file",
            "[Y/n] " );
        chomp( my $answer = <STDIN> );
        return if $answer =~ /^[Nn]/;
    }

    my $gff_producer = Bio::GMOD::CMap::Admin::GFFProducer->new(
        config      => $self->config,
        data_source => $self->data_source,
    );
    $gff_producer->purge_cache( cache_level => 1 );

    $gff_producer->export(
        output_file             => $export_file,
        species_accs            => \@species_accs,
        map_accs                => \@map_accs,
        map_set_accs            => \@map_set_accs,
        export_only_corrs       => $only_corrs,
        ignore_unit_granularity => $ignore_unit_granularity,
    );

    return 1;
}

# ----------------------------------------------------
sub export_as_text {

=pod

=head2 export_as_text

=head3 Description

Exports CMap data in a tab delimited file format readable by the CMap importer.

If command_line is true, checks for required options and exports.

If command_line is not true, uses a menu system to get the export options and
then exports.

=head3 Parameters

=over 4

=item * command_line

=item * map_set_accs (comma delimited string) or species_acc or map_type_acc (required if command_line)

=item * feature_type_accs (comma delimited string)

=item * exclude_fields (comma delimited string)

Exclude these fields from the output.

=item * directory

Directory where output file is to be placed 

=back

=cut

    #
    # Exports data in tab-delimited import format.
    #
    my ( $self, %args ) = @_;
    my $command_line          = $args{'command_line'};
    my $species_acc           = $args{'species_acc'};
    my $map_set_accs          = $args{'map_set_accs'};
    my $map_type_acc          = $args{'map_type_acc'};
    my $feature_type_accs_str = $args{'feature_type_accs'};
    my $exclude_fields_str    = $args{'exclude_fields'};
    my $dir_str               = $args{'directory'};
    $dir_str = "." unless defined($dir_str);

    my $sql_object = $self->sql or die $self->error;
    my $log_fh = $self->log_fh;
    my $map_sets;
    my @feature_type_accs;
    my @exclude_fields;
    my $dir;

    # Column Names
    my @col_names = qw(
        map_acc
        map_name
        map_start
        map_stop
        feature_acc
        feature_name
        feature_aliases
        feature_start
        feature_stop
        feature_type_acc
        feature_dbxref_name
        feature_dbxref_url
        is_landmark
        feature_attributes
    );

    # Names of values returned that correspond to col_names
    my @val_names = qw(
        map_acc
        map_name
        map_start
        map_stop
        feature_acc
        feature_name
        feature_aliases
        feature_start
        feature_stop
        feature_type_acc
        feature_dbxref_name
        feature_dbxref_url
        is_landmark
        feature_attributes
    );

    if ($command_line) {
        my @missing = ();

        # if map_set_accs is defined, get those, otherwise rely on the species
        # and map type.  Either or both of those can be undef.
        unless ( $map_set_accs or $species_acc or $map_type_acc ) {
            print STDERR "No map set constraints given.\n";
            push @missing, 'map_set_accs or species_acc or map_type_acc';
        }
        if ( defined($map_set_accs) ) {

            # split on space or comma
            my @map_set_accs = split /[,\s]+/, $map_set_accs;
            if (@map_set_accs) {
                $map_sets = $sql_object->get_map_sets(
                    map_set_accs => \@map_set_accs, );
            }
            unless ( @{ $map_sets || [] } ) {
                print STDERR
                    "Map set Accession(s), '$map_set_accs' is/are not valid.\n";
                push @missing, 'valid map_set_accs';
            }
        }
        else {
            my $species_id;
            if ( defined($species_acc) ) {
                $species_id = $sql_object->acc_id_to_internal_id(
                    acc_id      => $species_acc,
                    object_type => 'species'
                );
                unless ($species_id) {
                    print STDERR
                        "The species_acc, '$species_acc' is not valid.\n";
                    push @missing, 'valid species_acc';
                }
            }
            if ($map_type_acc) {
                unless ( $self->map_type_data($map_type_acc) ) {
                    print STDERR "The map_type_acc, '$map_type_acc' "
                        . "is not valid.\n";
                    push @missing, 'valid map_type_acc';
                }
            }
            $map_sets = $sql_object->get_map_sets(
                species_id   => $species_id,
                map_type_acc => $map_type_acc,
            );
            unless ( @{ $map_sets || [] } ) {
                print STDERR "No map set meets the constraints given.\n";
                push @missing, 'species_acc or map_type_acc with a map set';
            }
        }
        if ( defined($feature_type_accs_str) ) {
            @feature_type_accs = split /[,\s]+/, $feature_type_accs_str;
            my $valid = 1;
            foreach my $fta (@feature_type_accs) {
                unless ( $self->feature_type_data($fta) ) {
                    print STDERR
                        "The feature_type_acc, '$fta' is not valid.\n";
                    $valid = 0;
                }
            }
            unless ($valid) {
                push @missing, 'valid feature_type_acc';
            }
        }
        if ($exclude_fields_str) {
            @exclude_fields = split /[,\s]+/, $exclude_fields_str;
            my $valid = 1;
            foreach my $ef (@exclude_fields) {
                my $found = 0;
                foreach my $column (@col_names) {
                    if ( $ef eq $column ) {
                        $found = 1;
                        last;
                    }
                }
                unless ($found) {
                    print STDERR
                        "The exclude_fields name '$ef' is not valid.\n";
                    $valid = 0;
                }
            }
            unless ($valid) {
                return 0;
            }
            if ( @exclude_fields == @col_names ) {
                print "\nError:  Can't exclude all the fields!\n";
                return 0;
            }
        }
        $dir = $self->_get_dir( dir_str => $dir_str ) or return;
        unless ( defined($dir) ) {
            push @missing, 'valid directory';
        }
        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            return 0;
        }
    }
    else {

        $map_sets = $self->get_map_sets or return;
        my $feature_types_ref = $self->get_feature_types;

        @exclude_fields = $self->show_menu(
            title      => 'Select Fields to Exclude',
            prompt     => 'Which fields do you want to EXCLUDE from export?',
            display    => 'field_name',
            return     => 'field_name',
            allow_null => 1,
            allow_mult => 1,
            data       => [ map { { field_name => $_ } } @col_names ],
        );

        if ( @exclude_fields == @col_names ) {
            print "\nError:  Can't exclude all the fields!\n";
            return;
        }

        $dir = $self->_get_dir() or return;

        my @map_set_names;
        if ( @{ $map_sets || [] } ) {
            @map_set_names = map {
                join( '-',
                    $_->{'species_common_name'},
                    $_->{'map_set_short_name'} )
            } @$map_sets;
        }
        else {
            @map_set_names = ('All');
        }
        my $display_feature_types;
        if (@$feature_types_ref) {
            $display_feature_types = $feature_types_ref;
        }
        else {
            $display_feature_types = [ [ 'All', 'All' ], ];
        }

        @feature_type_accs = map { $_->[0] } @$feature_types_ref;

        my $excluded_fields
            = @exclude_fields ? join( ', ', @exclude_fields ) : 'None';

        #
        # Confirm decisions.
        #
        print join( "\n",
            'OK to export?',
            '  Data source     : ' . $self->data_source,
            "  Map Sets        :\n"
                . join( "\n", map {"    $_"} @map_set_names ),
            "  Feature Types   :\n"
                . join( "\n", map {"    $_->[1]"} @$display_feature_types ),
            "  Exclude Fields  : $excluded_fields",
            "  Directory       : $dir",
            "[Y/n] " );
        chomp( my $answer = <STDIN> );
        return if $answer =~ /^[Nn]/;
    }

    my %exclude = map { $_, 1 } @exclude_fields;
    for ( my $i = 0; $i <= $#col_names; $i++ ) {
        if ( $exclude{ $col_names[$i] } ) {
            splice( @col_names, $i, 1 );
            splice( @val_names, $i, 1 );
            $i--;
        }
    }

    for my $map_set (@$map_sets) {
        my $map_set_id          = $map_set->{'map_set_id'};
        my $map_set_short_name  = $map_set->{'map_set_short_name'};
        my $species_common_name = $map_set->{'species_common_name'};
        my $file_name
            = join( '-', $species_common_name, $map_set_short_name );
        $file_name =~ tr/a-zA-Z0-9-/_/cs;
        $file_name = "$dir/$file_name.dat";

        print $log_fh "Dumping '$species_common_name-$map_set_short_name' "
            . "to '$file_name'\n";
        open my $fh, ">$file_name" or die "Can't write to $file_name: $!\n";
        print $fh join( OFS, @col_names ), ORS;

        my $maps = $sql_object->get_maps_simple( map_set_id => $map_set_id, );

        my $attributes
            = $sql_object->get_attributes( object_type => 'feature', );

        my %attr_lookup = ();
        for my $a (@$attributes) {
            push @{ $attr_lookup{ $a->{'object_id'} } },
                qq[$a->{'attribute_name'}: "$a->{'attribute_value'}"];
        }

        for my $map (@$maps) {
            my $features = $sql_object->get_features(
                feature_type_accs => \@feature_type_accs,
                map_id            => $map->{'map_id'},
            );

            my $aliases = $sql_object->get_feature_aliases(
                map_id => $map->{'map_id'}, );

            my %alias_lookup = ();
            for my $a (@$aliases) {
                push @{ $alias_lookup{ $a->{'feature_id'} } }, $a->{'alias'};
            }

            for my $feature (@$features) {
                $feature->{'feature_stop'} = undef
                    if $feature->{'feature_stop'}
                        < $feature->{'feature_start'};

                $feature->{'feature_attributes'} = join( '; ',
                    @{ $attr_lookup{ $feature->{'feature_id'} } || [] } );

                $feature->{'feature_aliases'} = join( ',',
                    map { s/"/\\"/g ? qq["$_"] : $_ }
                        @{ $alias_lookup{ $feature->{'feature_id'} || [] } }
                );

                print $fh join(
                    OFS,
                    map {
                        ( defined( $feature->{$_} ) ? $feature->{$_} : q{} )
                        } @val_names
                    ),
                    ORS;
            }
        }

        close $fh;
    }
    return 1;
}

# ----------------------------------------------------
sub export_as_sql {

=pod

=head2 export_as_sql

=head3 Description

Exports CMap data as sql insert statements.

If command_line is true, checks for required options and exports.

If command_line is not true, uses a menu system to get the export options and
then exports.

=head3 Parameters

=over 4

=item * tables

=item * command_line

=item * export_file

File name of the output file

=item * add_truncate

Boolean: include TRUNCATE table statements in the output

=item * quote_escape (required if command_line)

How the embeded quotes should be escaped.  Options: 'doubled', 'backslash';

Hint: Oracle and Sybase like 'doubled', MySQL likes 'backslash',

=back

=cut

    #
    # Exports data as SQL INSERT statements.
    #
    my ( $self, %args ) = @_;
    my $command_line = $args{'command_line'};
    my $file         = $args{'export_file'};
    my $add_truncate = $args{'add_truncate'};
    $add_truncate = 1 unless ( defined($add_truncate) );
    my $quote_escape    = $args{'quote_escape'};
    my $dump_tables_str = $args{'tables'};
    my @dump_tables;
    my $default_file = './cmap_dump.sql';

    my $sql_object = $self->sql or die $self->error;
    my $db         = $self->db  or die $self->error;
    my $log_fh = $self->log_fh;

    my $quote_escape_options = [
        { display => 'Doubled',   action => 'doubled' },
        { display => 'Backslash', action => 'backslash' },
    ];
    my @tables = @{ $sql_object->get_table_info() };

    if ($command_line) {
        my @missing = ();
        if ( defined($file) ) {
            if ( -d $file ) {
                print
                    "'$file' is a directory.  Please give me a file path.\n";
                push @missing, 'export_file';
            }
            elsif ( -e _ && not -w _ ) {
                print "'$file' exists and you don't have "
                    . "permissions to overwrite.\n";
                push @missing, 'export_file';
            }
        }
        else {
            $file = $default_file;
        }
        if ($quote_escape) {
            my $found = 0;
            foreach my $item (@$quote_escape_options) {
                if ( $quote_escape eq $item->{'action'} ) {
                    $found = 1;
                }
            }
            unless ($found) {
                print STDERR "The quote_escape, '$quote_escape' "
                    . "is not valid.\n";
                push @missing, 'quote_escape';
            }
        }
        else {
            push @missing, 'quote_escape';
        }
        if ( !$dump_tables_str or $dump_tables_str =~ /^all$/i ) {
            @dump_tables = map { $_->{'name'} } @tables;
        }
        else {
            @dump_tables = split /[,\s]+/, $dump_tables_str;
            my $valid = 1;
            foreach my $dump_table (@dump_tables) {
                my $found = 0;
                foreach my $table (@tables) {
                    if ( $dump_table eq $table->{'name'} ) {
                        $found = 1;
                        last;
                    }
                }
                unless ($found) {
                    print STDERR
                        "The table name '$dump_table' is not valid.\n";
                    $valid = 0;
                }
            }
            unless ($valid) {
                push @missing, 'tables';
            }
        }

        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            return 0;
        }
    }
    else {

        #
        # Ask user what/how/where to dump.
        #
        @dump_tables = $self->show_menu(
            title     => 'Select Tables',
            prompt    => 'Which tables do you want to export?',
            display   => 'table_name',
            return    => 'table_name',
            allow_all => 1,
            data      => [ map { { 'table_name', $_->{'name'} } } @tables ],
        );

        print "Add 'TRUNCATE TABLE' statements? [Y/n] ";
        chomp( my $answer = <STDIN> );
        $answer ||= 'y';
        $add_truncate = $answer =~ m/^[yY]/;

        for ( ;; ) {
            print "Where would you like to write the file?\n",
                "['q' to quit, '$default_file' is default] ";
            chomp( my $user_file = <STDIN> );
            $user_file ||= $default_file;

            if ( -d $user_file ) {
                print
                    "'$user_file' is a directory.  Please give me a file path.\n";
                next;
            }
            elsif ( -e _ && -w _ ) {
                print "'$user_file' exists.  Overwrite? [Y/n] ";
                chomp( my $overwrite = <STDIN> );
                $overwrite ||= 'y';
                if ( $overwrite =~ m/^[yY]/ ) {
                    $file = $user_file;
                    last;
                }
                else {
                    print "OK, I won't overwrite.  Try again.\n";
                    next;
                }
            }
            elsif ( -e _ ) {
                print
                    "'$user_file' exists & isn't writable by you.  Try again.\n";
                next;
            }
            else {
                $file = $user_file;
                last;
            }
        }

        $quote_escape = $self->show_menu(
            title  => 'Quote Style',
            prompt => "How should embeded quotes be escaped?\n"
                . 'Hint: Oracle and Sybase like [1], MySQL likes [2]',
            display => 'display',
            return  => 'action',
            data    => $quote_escape_options,
        );

        #
        # Confirm decisions.
        #
        print join( "\n",
            'OK to export?',
            '  Data source  : ' . $self->data_source,
            '  Tables       : ' . join( ', ', @dump_tables ),
            '  Add Truncate : ' . ( $add_truncate ? 'Yes' : 'No' ),
            "  File         : $file",
            "  Escape Quotes: $quote_escape",
            "[Y/n] " );

        chomp( $answer = <STDIN> );
        return if $answer =~ /^[Nn]/;
    }

    print $log_fh "Making SQL dump of tables to '$file'\n";
    open my $fh, ">$file" or die "Can't write to '$file': $!\n";
    print $fh "--\n-- Dumping data for CMap v", $Bio::GMOD::CMap::VERSION,
        "\n-- Produced by cmap_admin.pl v", $VERSION, "\n-- ",
        scalar localtime, "\n--\n";

    my %table_used
        = map { my $tmp_table = $_; $tmp_table =~ s/`//g; $tmp_table => 1 }
        $db->tables( '%', '%', '%', '%' );
    my %dump_tables = map { $_, 1 } @dump_tables;
    for my $table (@tables) {
        my $table_name = $table->{'name'};
        next if %dump_tables && !$dump_tables{$table_name};
        unless ( $table_used{$table_name} ) {
            print $log_fh "WARNING: Failed to find table, "
                . $table_name
                . " in the database\n";
            next;
        }

        print $log_fh "Dumping data for '$table_name.'\n";
        print $fh "\n--\n-- Data for '$table_name'\n--\n";
        if ($add_truncate) {
            print $fh "TRUNCATE TABLE $table_name;\n";
        }

        my %fields    = %{ $table->{'fields'} };
        my @fld_names = sort keys %fields;

        my $insert
            = "INSERT INTO $table_name ("
            . join( ', ', @fld_names )
            . ') VALUES (';

        my $sth = $db->prepare(
            'select ' . join( ', ', @fld_names ) . " from $table_name" );
        $sth->execute;
        while ( my $rec = $sth->fetchrow_hashref ) {
            my @vals;
            for my $fld (@fld_names) {
                my $val = $rec->{$fld};
                if ( $fields{$fld} eq STR ) {

                    # Escape existing single quotes.
                    $val =~ s/'/\\'/g if $quote_escape eq 'backslash';
                    $val =~ s/'/''/g  if $quote_escape eq 'doubled';     #'
                    $val = defined $val ? qq['$val'] : qq[''];
                }
                else {
                    $val = defined $val ? $val : 'NULL';
                }
                push @vals, $val;
            }

            print $fh $insert, join( ', ', @vals ), ");\n";
        }
    }

    print $fh "\n--\n-- Finished dumping Cmap data\n--\n";
    return 1;
}

# ----------------------------------------------------
sub export_objects {

=pod

=head2 export_objects

=head3 Description

Exports serialized database objects.

If command_line is true, checks for required options and exports.

If command_line is not true, uses a menu system to get the export options and
then exports.

=head3 Parameters

=over 4

=item * command_line

=item * export_objects

The object to export: 'all', 'map_set', 'species', 'feature_correspondence' or 'xref'.

=item * export_file

Name of the output file.

=item * map_set_accs (comma separated list, only needed if map_set object is selected)

=item * directory

Directory where output file is to be placed 

=item * map_type_acc

=item * species_acc 

=item * feature_type_accs (Deprecated)

=back

=cut

    my ( $self, %args ) = @_;
    my $command_line = $args{'command_line'};
    my $species_acc  = $args{'species_acc'};
    my $map_set_accs = $args{'map_set_accs'};
    my $map_type_acc = $args{'map_type_acc'};

    #my $feature_type_accs_str = $args{'feature_type_accs'};
    my $object_str = $args{'export_objects'};
    my $file_name  = $args{'export_file'} || 'cmap_export.xml';
    my $dir_str    = $args{'directory'};
    $dir_str = "." unless defined($dir_str);
    my $sql_object = $self->sql;
    my $export_path;
    my @db_objects;
    my $map_sets;

    #my $feature_types

    my $object_options = [
        {   object_type => 'map_set',
            object_name => 'Map Sets',
        },
        {   object_type => 'species',
            object_name => 'Species',
        },
        {   object_type => 'feature_correspondence',
            object_name => 'Feature Correspondence',
        },
        {   object_type => 'xref',
            object_name => 'Cross-references',
        },
    ];

    if ($command_line) {
        my @missing = ();

        if ( !$object_str or $object_str =~ /^all$/i ) {
            @db_objects = map { $_->{'object_type'} } @$object_options;
        }
        else {
            @db_objects = split /[,\s]+/, $object_str;
            my $valid = 1;
            foreach my $ob (@db_objects) {
                my $found = 0;
                foreach my $option (@$object_options) {
                    if ( $ob eq $option->{'object_type'} ) {
                        $found = 1;
                        last;
                    }
                }
                unless ($found) {
                    print STDERR
                        "The export_objects name '$ob' is not valid.\n";
                    $valid = 0;
                }
            }
            unless ($valid) {
                return 0;
            }
        }

        # if map_set_accs is defined, get those, otherwise rely on the species
        # and map type.  Either or both of those can be undef.
        if ( grep {/map_set/} @db_objects ) {
            if ( defined($map_set_accs) ) {

                # split on space or comma
                my @map_set_accs = split /[,\s]+/, $map_set_accs;
                if (@map_set_accs) {
                    $map_sets = $sql_object->get_map_sets(
                        map_set_accs => \@map_set_accs, );
                }
                unless ( @{ $map_sets || [] } ) {
                    print STDERR
                        "Map set Accession(s), '$map_set_accs' is/are not valid.\n";
                    push @missing, 'valid map_set_accs';
                }
            }
            else {
                my $species_id;
                if ( defined($species_acc) ) {
                    $species_id = $sql_object->acc_id_to_internal_id(
                        acc_id      => $species_acc,
                        object_type => 'species'
                    );
                    unless ($species_id) {
                        print STDERR
                            "The species_acc, '$species_acc' is not valid.\n";
                        push @missing, 'valid species_acc';
                    }
                }
                if ($map_type_acc) {
                    unless ( $self->map_type_data($map_type_acc) ) {
                        print STDERR "The map_type_acc, '$map_type_acc' "
                            . "is not valid.\n";
                        push @missing, 'valid map_type_acc';
                    }
                }
                $map_sets = $sql_object->get_map_sets(
                    species_id   => $species_id,
                    map_type_acc => $map_type_acc,
                );
            }

     #if ( defined($feature_type_accs_str) ) {
     #    @feature_type_accs = split /[,\s]+/, $feature_type_accs_str;
     #    my $valid = 1;
     #    foreach my $fta (@feature_type_accs) {
     #        unless ( $self->feature_type_data($fta) ) {
     #            print STDERR "The feature_type_acc, '$fta' is not valid.\n";
     #            $valid = 0;
     #        }
     #    }
     #    unless ($valid) {
     #        push @missing, 'valid feature_type_acc';
     #    }
     #}
        }
        my $dir = $self->_get_dir( dir_str => $dir_str ) or return;
        unless ( defined($dir) ) {
            push @missing, 'valid directory';
        }
        $export_path = catfile( $dir, $file_name );

        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            return 0;
        }
    }
    else {
        for ( ;; ) {
            my $dir = $self->_get_dir() or return;

            print 'What file name [cmap_export.xml]? ';
            chomp( $file_name = <STDIN> );
            $file_name ||= 'cmap_export.xml';

            $export_path = catfile( $dir, $file_name );

            if ( -e $export_path ) {
                print "The file '$export_path' exists.  Overwrite? [Y/n] ";
                chomp( my $answer = <STDIN> );
                if ( $answer =~ /^[Nn]/ ) {
                    next;
                }
                else {
                    last;
                }
            }

            last if $export_path;
        }

        #
        # Which objects?
        #
        my @objects = $self->show_menu(
            title      => 'Which objects?',
            prompt     => 'Please select the objects you wish to export',
            display    => 'object_name',
            return     => 'object_type,object_name',
            allow_null => 0,
            allow_mult => 1,
            allow_all  => 1,
            data       => $object_options,
        );

        @db_objects = map { $_->[0] } @objects;
        my @object_names = map { $_->[1] } @objects;

        my @confirm = (
            '  Data source  : ' . $self->data_source,
            '  Objects      : ' . join( ', ', @object_names ),
            "  File name    : $export_path",
        );

        if ( grep {/map_set/} @db_objects ) {
            $map_sets = $self->get_map_sets or return;

            #$feature_types = $self->get_feature_types;
            #my @ft_names = map { $_->{'feature_type'} } @$feature_types;
            my @map_set_names = map {
                      $_->{'species_common_name'} . '-'
                    . $_->{'map_set_short_name'} . ' ('
                    . $_->{'map_type'} . ')'
            } @$map_sets;

            @map_set_names = ('All') unless @map_set_names;

            #@ft_names      = ('All') unless @ft_names;

            push @confirm, (
                "  Map Sets     :\n"
                    . join( "\n", map {"    $_"} @map_set_names ),

          #   "  Feature Types:\n" . join( "\n", map { "    $_" } @ft_names ),
            );
        }

        #
        # Confirm decisions.
        #
        print join( "\n", 'OK to export?', @confirm, '[Y/n] ' );
        chomp( my $answer = <STDIN> );
        return if $answer =~ /^[Nn]/;
    }

    my $exporter = Bio::GMOD::CMap::Admin::Export->new(
        config      => $self->config,
        data_source => $self->data_source
    );

    $exporter->export(
        objects     => \@db_objects,
        output_path => $export_path,
        log_fh      => $self->log_fh,
        map_sets    => $map_sets,

        #feature_types => $feature_types, NOT USED
        )
        or do {
        print "Error: ", $exporter->error, "\n";
        return;
        };

    return 1;
}

# ----------------------------------------------------
sub get_files {

=pod

=head2 get_files

=head3 Description

Get file names and validate them.  Will use file_str if supplied.

=head3 Parameters

=over 4

=item * file_str (comma delimeted list of files)

=item * prompt

String defining how to ask the user for the files.

=back

=cut

    #
    # Ask the user for files.
    #
    my ( $self, %args ) = @_;
    my $file_str = $args{'file_str'} || '';
    my $prompt
        = defined $args{'prompt'}
        ? $args{'prompt'}
        : 'Please specify the file(s)?[q to quit] ';
    my $term = $self->term;

    ###New File Handling
    while ( $file_str !~ /\S/ ) {
        $file_str = $term->readline($prompt);
        return undef if $file_str =~ m/^[Qq]$/;
    }
    $term->addhistory($file_str);

    my @file_strs = split( /\s+/, $file_str );
    my @files = ();

    # allow filename expantion and put into @files
    foreach my $str (@file_strs) {
        my @tmp_files = glob($str);
        print "WARNING: Unable to read '$str'!\n" unless (@tmp_files);
        push @files, @tmp_files;
    }
    foreach ( my $i = 0; $i <= $#files; $i++ ) {
        if ( -r $files[$i] and -f $files[$i] ) {
            print "$files[$i] read correctly.\n";
        }
        else {
            print "WARNING: Unable to read file '$files[$i]'!\n";
            splice( @files, $i, 1 );
            $i--;
        }
    }
    return \@files if (@files);
    return undef;
}

# ----------------------------------------------------
sub get_species {

=pod

=head2 get_species

=head3 Description

Menu system to select the species the user wants to act apon.

=head3 Parameters

=over 4

=item * explanation

A note to the user

=item * allow_null

Allow not selecting map sets to be a valid option

=item * allow_mult

Allow multiple map sets to be selected.

=back

=cut

    #
    # Help user choose map sets.
    #
    my ( $self, %args ) = @_;
    my $allow_mult = defined $args{'allow_mult'} ? $args{'allow_mult'} : 1;
    my $allow_null = defined $args{'allow_null'} ? $args{'allow_null'} : 1;
    my $sql_object = $self->sql or die $self->error;
    my $log_fh = $self->log_fh;

    if ( my $explanation = $args{'explanation'} ) {
        print join( "\n",
            "------------------------------------------------------",
            "NOTE: $explanation",
            "------------------------------------------------------",
        );
    }

    my $species_choices = $sql_object->get_species();

    my $species_ids = $self->show_menu(
        title      => 'Select Species',
        prompt     => 'Which species?',
        display    => 'species_common_name,species_full_name',
        return     => 'species_id',
        allow_null => $allow_null,
        allow_all  => 1,
        allow_mult => $allow_mult,
        data       => $species_choices,
    );
    if ( defined($species_ids) and ref $species_ids ne 'ARRAY' ) {
        $species_ids = [ $species_ids, ];
    }

    my $species = [];
    if ( $species_ids and @$species_ids ) {
        $species = $sql_object->get_species( species_ids => $species_ids, );
        $species = sort_selectall_arrayref( $species, 'species_common_name' );
    }

    return $species;
}

# ----------------------------------------------------
sub get_map_sets {

=pod

=head2 get_map_sets

=head3 Description

Menu system to select the map sets the user wants to act apon.

=head3 Parameters

=over 4

=item * explanation

A note to the user

=item * allow_null

Allow not selecting map sets to be a valid option

=item * allow_mult

Allow multiple map sets to be selected.

=back

=cut

    #
    # Help user choose map sets.
    #
    my ( $self, %args ) = @_;
    my $allow_mult = defined $args{'allow_mult'} ? $args{'allow_mult'} : 1;
    my $allow_null = defined $args{'allow_null'} ? $args{'allow_null'} : 1;
    my $sql_object = $self->sql or die $self->error;
    my $log_fh = $self->log_fh;

    if ( my $explanation = $args{'explanation'} ) {
        print join( "\n",
            "------------------------------------------------------",
            "NOTE: $explanation",
            "------------------------------------------------------",
        );
    }

    my $select = $self->show_menu(
        title   => 'Map Set Selection Method',
        prompt  => 'How would you like to select map sets?',
        display => 'display',
        return  => 'action',
        data    => [
            {   action  => 'by_accession_id',
                display => 'Supply Map Set Accession ID',
            },
            {   action  => 'by_menu',
                display => 'Use Menus'
            },
        ],
    );

    my $map_sets;
    if ( $select eq 'by_accession_id' ) {
        print
            'Please supply the accession IDs separated by commas or spaces: ';
        chomp( my $answer = <STDIN> );
        my @accessions = split( /[,\s+]/, $answer );
        return unless @accessions;
        $map_sets
            = $sql_object->get_map_sets( map_set_accs => \@accessions, );
        unless ( $map_sets and @$map_sets ) {
            print "Those map sets were not in the database!\n";
            return;
        }
        return unless @$map_sets;
    }
    else {
        my $map_type_results = $sql_object->get_used_map_types();
        unless (@$map_type_results) {
            print
                "No map sets in the database!  Use cmap_admin.pl to create.\n";
            return;
        }

        $map_type_results
            = sort_selectall_arrayref( $map_type_results, 'map_type' );

        my $map_types = $self->show_menu(
            title      => 'Select Map Types',
            prompt     => 'Limit map sets by which map types?',
            display    => 'map_type',
            return     => 'map_type_acc',
            allow_null => 0,
            allow_mult => 1,
            allow_all  => 1,
            data       => $map_type_results,
        );
        $map_types = [$map_types] unless ( ref($map_types) eq 'ARRAY' );

        my $map_set_species
            = $sql_object->get_map_sets( map_type_accs => $map_types, );
        die "No species! Please create.\n"
            unless @$map_set_species;

        # eliminate redundancy
        $map_set_species
            = sort_selectall_arrayref( $map_set_species, 'species_id' );
        my $tmp_species_id;
        for ( my $i = 0; $i <= $#{$map_set_species}; $i++ ) {
            if ( $tmp_species_id == $map_set_species->[$i]{'species_id'} ) {
                splice( @$map_set_species, $i, 1 );
                $i--;
            }
            $tmp_species_id = $map_set_species->[$i]{'species_id'};
        }

        my $species_ids = $self->show_menu(
            title      => 'Restrict by Species',
            prompt     => 'Limit by which species?',
            display    => 'species_common_name',
            return     => 'species_id',
            allow_null => 0,
            allow_mult => 1,
            allow_all  => 1,
            data       => $map_set_species,
        );

        if ( defined($species_ids) and ref $species_ids ne 'ARRAY' ) {
            $species_ids = [ $species_ids, ];
        }

        my $ms_choices = $sql_object->get_map_sets(
            map_type_accs => $map_types,
            species_ids   => $species_ids,
        );

        my $map_set_ids = $self->show_menu(
            title      => 'Select Map Set',
            prompt     => 'Which map set?',
            display    => 'map_type,species_common_name,map_set_short_name',
            return     => 'map_set_id',
            allow_null => $allow_null,
            allow_all  => 1,
            allow_mult => $allow_mult,
            data       => $ms_choices,
        );
        if ( defined($map_set_ids) and ref $map_set_ids ne 'ARRAY' ) {
            $map_set_ids = [ $map_set_ids, ];
        }

        if ( $map_set_ids and @$map_set_ids ) {
            $map_sets = $sql_object->get_map_sets(
                map_set_ids => $map_set_ids,
                species_ids => $species_ids,
            );
            $map_sets = sort_selectall_arrayref( $map_sets,
                'species_common_name, map_set_short_name' );
        }

    }
    return $map_sets;
}

# ----------------------------------------------------
sub get_maps {

=pod

=head2 get_maps

=head3 Description

Menu system to select the maps the user wants to act apon.

=head3 Parameters

=over 4

=item * explanation

A note to the user

=item * allow_null

Allow not selecting map sets to be a valid option

=item * allow_mult

Allow multiple map sets to be selected.

=back

=cut

    #
    # Help user choose map sets.
    #
    my ( $self, %args ) = @_;
    my $allow_mult = defined $args{'allow_mult'} ? $args{'allow_mult'} : 1;
    my $allow_null = defined $args{'allow_null'} ? $args{'allow_null'} : 1;
    my $sql_object = $self->sql or die $self->error;
    my $log_fh = $self->log_fh;

    if ( my $explanation = $args{'explanation'} ) {
        print join( "\n",
            "------------------------------------------------------",
            "NOTE: $explanation",
            "------------------------------------------------------",
        );
    }

    my @map_set_accs;
    my $do_map_set_search;
    print join( "\n", '', "Narrow search by map set? [Y/n]", );
    chomp( $do_map_set_search = <STDIN> );
    $do_map_set_search = ( $do_map_set_search =~ /^[Nn]/ ) ? 0 : 1;

    if ($do_map_set_search) {
        my $map_sets
            = $self->get_map_sets( allow_mult => 1, allow_null => 0 );
        foreach my $map_set ( @{ $map_sets || [] } ) {
            push @map_set_accs, $map_set->{'map_set_acc'};
        }
    }

    my %get_maps_args = ();
    if (@map_set_accs) {
        $get_maps_args{'map_set_accs'} = \@map_set_accs;
    }
    my $map_choices = $sql_object->get_maps( %get_maps_args, );

    my $map_ids = $self->show_menu(
        title      => 'Select Maps',
        prompt     => 'Which maps?',
        display    => 'map_name,map_set_name',
        return     => 'map_id',
        allow_null => $allow_null,
        allow_all  => 1,
        allow_mult => $allow_mult,
        data       => $map_choices,
    );
    if ( defined($map_ids) and ref $map_ids ne 'ARRAY' ) {
        $map_ids = [ $map_ids, ];
    }

    my $maps = [];
    if ( $map_ids and @$map_ids ) {
        $maps = $sql_object->get_maps( map_ids => $map_ids, );
        $maps = sort_selectall_arrayref( $maps, 'map_name' );
    }

    return $maps;
}

# ----------------------------------------------------
sub get_feature_types {

=pod

=head2 get_feature_types

=head3 Description

Menu system to select feature types.

=head3 Parameters

=over 4

=item * map_set_ids (array reference)

Use map_set_ids to restrict feature types to those used in the chosen map sets.

=back

=cut

    #
    # Allow selection of feature types
    #
    my ( $self, %args ) = @_;
    my @map_set_ids = @{ $args{'map_set_ids'} || [] };
    my $ft_sql;
    my $ft_sql_data;
    if (@map_set_ids) {
        my $sql_object = $self->sql or die $self->error;
        $ft_sql_data = $sql_object->get_used_feature_types(
            map_set_ids => \@map_set_ids, );
    }
    else {
        $ft_sql_data
            = $self->fake_selectall_arrayref( $self->feature_type_data(),
            'feature_type_acc', 'feature_type' );
    }
    $ft_sql_data = sort_selectall_arrayref( $ft_sql_data, 'feature_type' );

    my @feature_types = $self->show_menu(
        title      => 'Restrict by Feature Types',
        prompt     => 'Limit by feature types?',
        display    => 'feature_type',
        return     => 'feature_type_acc,feature_type',
        allow_null => 1,
        allow_mult => 1,
        data       => $ft_sql_data,
    );

    return \@feature_types;
}

# ----------------------------------------------------
sub import_data {

=pod

=head2 import_data

=head3 Description

Menu system for importing data (no command line interface).  The type of import
chosen is then called.

=head3 Parameters

No Parameters

=cut

    #
    # Determine what kind of data to import (new or old)
    #
    my $self = shift;

    my $action = $self->show_menu(
        title   => 'Import Options',
        prompt  => 'What would you like to import?',
        display => 'display',
        return  => 'action',
        data    => [
            {   action  => 'import_gff',
                display => 'Import a CMap GFF file'
            },
            {   action  => 'import_tab_data',
                display => 'Import tab-delimited data for existing map set'
            },
            {   action  => 'import_correspondences',
                display => 'Import feature correspondences'
            },
            {   action  => 'import_object_data',
                display => 'Import CMap objects [experimental]'
            },
        ],
    );

    return $self->$action();
}

# ----------------------------------------------------
sub manage_links {

=pod

=head2 manage_links

=head3 Description

Menu system for managing link data (no command line interface).  The action
that is chosen is then called.

=head3 Parameters

No Parameters

=cut

    #
    # Determine what kind of data to import (new or old)
    #
    my $self = shift;

    my $action = $self->show_menu(
        title   => 'Import Options',
        prompt  => 'What would you like to import?',
        display => 'display',
        return  => 'action',
        data    => [
            {   action  => 'import_links',
                display => 'Import Links'
            },
            {   action  => 'delete_links',
                display => 'Remove Link Set'
            },
        ],
    );

    $self->$action();
    return 1;
}

# ----------------------------------------------------
sub import_links {

=pod

=head2 import_links

=head3 Description

Importing "Saved links" into CMap.

If command_line is true, checks for required options and imports the links

If command_line is not true, uses a menu system to get the link import options.

=head3 Parameters

=over 4

=item * link_group

=item * command_line

=item * file_str (required if command_line)

Comma delimited string of file names to be imported

=back

=cut

    #
    # Imports links in simple tab-delimited format
    #
    my ( $self, %args ) = @_;
    my $file_str     = $args{'file_str'};
    my $link_group   = $args{'link_group'};
    my $command_line = $args{'command_line'};
    my $sql_object   = $self->sql or die $self->error;

    my $files;
    if ($command_line) {

        # Check for any missing and required fields
        my @missing = ();
        if ($file_str) {
            unless ( $files = $self->get_files( file_str => $file_str ) ) {
                print STDERR "None of the files, '$file_str' succeded.\n";
                push @missing, 'input file(s)';
            }
        }
        else {
            push @missing, 'input file(s)';
        }
        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            return 0;
        }
    }
    else {

        print "Importing Saved Links\n";
        ###New File Handling
        $files = $self->get_files() or return;

        $link_group = $self->show_question(
            question => "What should this link group be named?\n"
                . '(This selection will be overwridden if the '
                . 'group is defined in the file)' . "\n",
            allow_null => 1,
            default    => DEFAULT->{'link_group'},
        );

        #
        # Confirm decisions.
        #
        print join( "\n",
            'OK to import?',
            '  Data source     : ' . $self->data_source,
            '  File            : ' . join( ", ", @$files ),
            "  Link Group      : $link_group",
            "[Y/n] " );
        chomp( my $answer = <STDIN> );
        return if $answer =~ /^[Nn]/;
    }

    my $link_manager = Bio::GMOD::CMap::Admin::SavedLink->new(
        config      => $self->config,
        data_source => $self->data_source,
    );

    foreach my $file (@$files) {
        $link_manager->read_saved_links_file(
            file_name  => $file,
            link_group => $link_group,
            )
            or do {
            print "Error: ", $link_manager->error, "\n";
            return;
            };
    }
    return 1;
}

# ----------------------------------------------------
sub delete_links {

=pod

=head2 delete_links

=head3 Description

Menu system for deleting links (no command line interface)

=head3 Parameters

No Parameters

=cut

    #
    # Removes links
    #
    my ( $self, %args ) = @_;
    my $name_space = $self->get_link_name_space;

    my $link_manager = Bio::GMOD::CMap::Admin::ManageLinks->new(
        config      => $self->config,
        data_source => $self->data_source,
    );
    my @link_set_names = $link_manager->list_set_names(
        name_space => $self->get_link_name_space, );
    my @link_set_name_display;
    foreach my $name (@link_set_names) {
        $link_set_name_display[ ++$#link_set_name_display ]->{'link_set_name'}
            = $name;
    }
    my $link_set_name = $self->show_menu(
        title   => join("\n"),
        prompt  => 'Which would you like to remove?',
        display => 'link_set_name',
        return  => 'link_set_name',
        data    => \@link_set_name_display,
    );
    unless ($link_set_name) {
        print "No Link Sets\n";
        return;
    }

    #
    # Confirm decisions.
    #
    print join( "\n",
        'OK to remove?',
        '  Data source     : ' . $self->data_source,
        "  Link Set        : $link_set_name",
        "[Y/n] " );
    chomp( my $answer = <STDIN> );
    return if $answer =~ /^[Nn]/;

    $link_manager->delete_links(
        link_set_name => $link_set_name,
        log_fh        => $self->log_fh,
        name_space    => $self->get_link_name_space,
        )
        or do {
        print "Error: ", $link_manager->error, "\n";
        return;
        };
    return 1;
}

# ----------------------------------------------------
sub import_correspondences {

=pod

=head2 import_correspondences

=head3 Description

Import a tab delimited correspondence file

If command_line is true, checks for required options and imports the
correspondences.

If command_line is not true, uses a menu system to get the correspondence import options.

=head3 Parameters

=over 4

=item * command_line

=item * map_set_accs (required if command_line)

Comma delimited string of map_set accs to be considered for the correspondences

=item * file_str (required if command_line)

Comma delimited string of file names to be imported

=back 

=cut

    #
    # Gathers the info to import feature correspondences.
    #
    my ( $self, %args ) = @_;
    my $command_line = $args{'command_line'};
    my $file_str     = $args{'file_str'};
    my $map_set_accs = $args{'map_set_accs'};
    my $sql_object   = $self->sql or die $self->error;
    my $single_file  = $self->file;
    my $files;
    my @map_set_ids;

    if ($command_line) {
        my @missing = ();
        if ($file_str) {
            unless ( $files = $self->get_files( file_str => $file_str ) ) {
                print STDERR "None of the files, '$file_str' succeded.\n";
                push @missing, 'input file(s)';
            }
        }
        else {
            push @missing, 'input file(s)';
        }
        if ( defined($map_set_accs) ) {

            # split on space or comma
            my @map_set_accs = split /[,\s]+/, $map_set_accs;
            my $map_sets;
            if (@map_set_accs) {
                $map_sets = $sql_object->get_map_sets(
                    map_set_accs => \@map_set_accs, );
            }
            unless ( @{ $map_sets || [] } ) {
                print STDERR
                    "Map set Accession(s), '$map_set_accs' is/are not valid.\n";
                push @missing, 'map_set_accs';
            }
            @map_set_ids = map { $_->{'map_set_id'} } @$map_sets;
        }
        else {
            push @missing, 'map_set_accs';
        }
        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            return 0;
        }
    }
    else {

        #
        # Make sure we have a file to parse.
        #
        if ($single_file) {
            print "OK to use '$single_file'? [Y/n] ";
            chomp( my $answer = <STDIN> );
            $single_file = '' if $answer =~ m/^[Nn]/;
        }

        if ( -r $single_file and -f _ ) {
            push @$files, $single_file;
        }
        else {
            print "Unable to read '$single_file' or not a regular file.\n"
                if $single_file;
            $files = $self->get_files() or return;
        }

        #
        # Get the map set.
        #
        my @map_sets = $self->show_menu(
            title      => 'Restrict by Map Set (optional)',
            prompt     => 'Please select a map set to restrict the search',
            display    => 'species_common_name,map_set_short_name',
            return     => 'map_set_id,species_common_name,map_set_short_name',
            allow_null => 1,
            allow_mult => 1,
            data       => sort_selectall_arrayref(
                $sql_object->get_map_sets(),
                'species_common_name, map_set_short_name'
            ),
        );

        @map_set_ids = map { $_->[0] } @map_sets;

        print join( "\n",
            'OK to import?',
            '  Data source   : ' . $self->data_source,
            "  File          : " . join( ", ", @$files ),
        );

        if (@map_sets) {
            print join( "\n",
                '',
                '  From map sets :',
                map {"    $_"}
                    map { join( '-', $_->[1], $_->[2] ) } @map_sets );
        }
        print "\n[Y/n] ";

        chomp( my $answer = <STDIN> );
        return if $answer =~ /^[Nn]/;
    }

    my $importer = Bio::GMOD::CMap::Admin::ImportCorrespondences->new(
        config      => $self->config,
        data_source => $self->data_source,
    );
    foreach my $file (@$files) {
        my $fh = IO::File->new($file) or die "Can't read $file: $!";
        $self->file($file);
        $importer->import(
            fh          => $fh,
            map_set_ids => \@map_set_ids,
            log_fh      => $self->log_fh,
            )
            or do {
            print "Error: ", $importer->error, "\n";
            return;
            };
    }
    $self->purge_query_cache( cache_level => 4 );
    return 1;
}

# ----------------------------------------------------
sub delete_duplicate_correspondences {

=pod

=head2 delete_duplicate_correspondences

=head3 Description

If command_line is true, checks for required options and deletes duplicate correspondences

If command_line is not true, uses a menu system to get the delete duplicate correspondences options.

=head3 Parameters

=over 4

=item * command_line

=item * map_set_acc

=back

=cut

    #
    # deletes all duplicate correspondences.
    #
    my $self         = shift;
    my %args         = @_;
    my $map_set_acc  = $args{'map_set_acc'};
    my $command_line = $args{'command_line'};

    my $admin = Bio::GMOD::CMap::Admin->new(
        config      => $self->config,
        data_source => $self->data_source,
    );
    my $map_set_id;
    if ($command_line) {
        my $sql_object = $self->sql;
        my @missing    = ();
        if ( defined($map_set_acc) ) {
            my $map_sets
                = $sql_object->get_map_sets( map_set_acc => $map_set_acc, );
            if ( @{ $map_sets || [] } ) {
                $map_set_id = $map_sets->[0]{'map_set_id'};
            }
            else {
                print STDERR
                    "Map set Accession, '$map_set_acc' is/are not valid.\n";
                push @missing, 'valid map_set_acc';
            }
        }
        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            return 0;
        }
    }
    else {
        my $delete_what = $self->show_menu(
            title   => 'Delete Duplicates',
            prompt  => 'Limit duplicate deletion?',
            display => 'display',
            return  => 'value',
            data    => [
                {   value   => 'entire',
                    display => 'Delete all duplicates from the database'
                },
                {   value   => 'one',
                    display => 'Delete duplicates associated with one map set'
                }
            ],
        );

        if ( $delete_what eq 'one' ) {
            my $map_sets
                = $self->get_map_sets( allow_mult => 0, allow_null => 0 );
            my $map_set = $map_sets->[0];
            $map_set_id = $map_set->{'map_set_id'};
        }
    }

    $admin->delete_duplicate_correspondences( map_set_id => $map_set_id, );

    $self->purge_query_cache( cache_level => 4 );
    return 1;
}

# ----------------------------------------------------

sub purge_query_cache_menu {

=pod

=head2 purge_query_cache_menu

=head3 Description

Menu system for purging the query cache

=head3 Parameters

No Parameters

=cut

    my $self = shift;

    my $response;
    my $purge_all = 0;
    print "Purge query caches for all datasources? [y/N] ";
    chomp( $response = <STDIN> );
    if ( $response =~ m/^[Yy]/ ) {
        $purge_all = 1;
    }

    my $cache_level = $self->show_menu(
        title => '  --= Cache Level =--  ',
        prompt =>
            "At which cache level would you like to start the purging?\n"
            . "(The purges cascade down. ie selecting level 3 removes 3, 4 and 5):",
        display => 'display',
        return  => 'level',
        data    => [
            {   level => 1,
                display =>
                    'Cache Level 1 Purge All (Species/Map Sets changed)',
            },
            {   level   => 2,
                display => 'Cache Level 2 (purge map info)',
            },
            {   level   => 3,
                display => 'Cache Level 3 (purge feature info)',
            },
            {   level   => 4,
                display => 'Cache Level 4 (purge correspondence info)',
            },
            {   level   => 5,
                display => 'Cache Level 5 (purge whole-image cache )',
            },
            {   level   => 0,
                display => 'quit',
            },
        ],
    );
    return unless $cache_level;

    $self->purge_query_cache(
        cache_level => $cache_level,
        purge_all   => $purge_all,
    );
    return 1;
}

# ----------------------------------------------------
sub purge_query_cache {

=pod

=head2 purge_query_cache

=head3 Description

Purge the query cache of one or more datasources

If command_line is true, checks for required options and purges the cache.

If command_line is not true, uses a menu system to get the cache options.

=head3 Parameters

=over 4

=item * cache_level

The cache level to purged (see ADMINISTRATION.pod for furtherdetails).  Default
is 1.

=item * purge_all

Boolean: if true, all datasource caches will be purged otherwise just the
active datasource will be purged.

=back

=cut

    my ( $self, %args ) = @_;
    my $cache_level = $args{'cache_level'} || 1;
    my $purge_all   = $args{'purge_all'}   || 0;

    my $admin = Bio::GMOD::CMap::Admin->new(
        config      => $self->config,
        data_source => $self->data_source,
    );
    print "Purging cache at level $cache_level of "
        . $self->data_source() . ".\n";
    my $namespaces_purged = $admin->purge_cache(
        cache_level => $cache_level,
        purge_all   => $purge_all,
    );
    foreach my $namespace ( @{ $namespaces_purged || [] } ) {
        print "Purged $namespace\n";
    }
    return 1;
}

# ----------------------------------------------------
sub import_gff {

=pod

=head2 import_gff

=head3 Description

Import a tab CMap GFF file

If command_line is true, checks for required options and imports the data.

If command_line is not true, uses a menu system to get the import options.

=head3 Parameters

=over 4

=item * command_line

=item * map_set_acc (Can be defined in GFF file)

=item * file_str (required if command_line)

=back

=cut

    my ( $self, %args ) = @_;
    my $command_line = $args{'command_line'};
    my $file_str     = $args{'file_str'};
    my $map_set_acc  = $args{'map_set_acc'};
    my $overwrite    = $args{'overwrite'} || 0;
    my $allow_update = $args{'allow_update'} || 0;
    my $quiet        = $args{'quiet'} || 0;
    my $sql_object   = $self->sql;
    my ( $map_set, $files );

    require Bio::DB::SeqFeature::Store;
    require Bio::DB::SeqFeature::Store::GFF3Loader;

    if ($command_line) {
        my @missing = ();
        if ($file_str) {
            unless ( $files = $self->get_files( file_str => $file_str ) ) {
                print STDERR "None of the files, '$file_str' succeded.\n";
                push @missing, 'input file(s)';
            }
        }
        else {
            push @missing, 'input file(s)';
        }
        if ( defined($map_set_acc) ) {
            my $map_sets
                = $sql_object->get_map_sets( map_set_acc => $map_set_acc, );
            unless ( @{ $map_sets || [] } ) {
                print STDERR
                    "Map set Accession, '$map_set_acc' is not valid.\n";
                push @missing, 'map_set_acc';
            }
            $map_set = $map_sets->[0];
        }
        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            return 0;
        }
    }
    else {

        ###New File Handling
        $files = $self->get_files() or return;

        my $get_map_set = $self->show_question(
            question => "Do you wish to select a map set?\n"
                . '(This selection will be overwridden if the '
                . 'map set is defined in the file) [Y/n]' . "\n",
            allow_null => 1,
            default    => 'y',
        );

        unless ( $get_map_set =~ /^[Nn]/ ) {
            my $map_sets
                = $self->get_map_sets( allow_mult => 0, allow_null => 0 );
            return unless @{ $map_sets || [] };
            $map_set = $map_sets->[0];
        }

        #
        # Confirm decisions.
        #
        print join( "\n",
            'OK to import?',
            '  Data source : ' . $self->data_source,
            "  File        : " . join( ", ", @$files ),
        ) . "\n";
        if ($map_set) {
            print join( "\n",
                "  Species     : " . $map_set->{species_common_name},
                "  Map Type    : " . $map_set->{map_type},
                "  Map Set     : " . $map_set->{map_set_short_name},
                "  Map Set Acc : " . $map_set->{map_set_acc},
            ) . "\n";
        }
        else {
            print "  Map Set     : Not Selected\n";
        }
        print "[Y/n] ";
        chomp( my $answer = <STDIN> );
        return if $answer =~ /^[Nn]/;
    }

    my $store = Bio::DB::SeqFeature::Store->new(
        -adaptor     => 'cmap',
        -data_source => $self->data_source(),
        -map_set_acc => $map_set ? $map_set->{'map_set_acc'} : '',
    );
    my $loader = Bio::DB::SeqFeature::Store::GFF3Loader->new(
        -store   => $store,
        -verbose => 1,
        -fast    => 0
    );

    my $time_start = new Benchmark;
    my %maps;    #stores the maps info between each file
    foreach my $file (@$files) {
        $loader->load($file);
    }

    my $time_end = new Benchmark;
    print STDERR "import time: "
        . timestr( timediff( $time_end, $time_start ) ) . "\n"
        unless ($quiet);

    $self->purge_query_cache( cache_level => 1 );
    return 1;
}

# ----------------------------------------------------
sub import_tab_data {

=pod

=head2 import_tab_data

=head3 Description

Import a tab delimited CMap file

If command_line is true, checks for required options and imports the data.

If command_line is not true, uses a menu system to get the import options.

=head3 Parameters

=over 4

=item * command_line

=item * map_set_acc (required if command_line)

=item * file_str (required if command_line)

=item * allow_update

Boolean:  When true, looks for previously inserted data and updates with the new data where
applicable.

=item * overwrite

Boolean:  When true, removes any old data that wasn't in the new data file.

=back

=cut

    my ( $self, %args ) = @_;
    my $command_line = $args{'command_line'};
    my $file_str     = $args{'file_str'};
    my $map_set_acc  = $args{'map_set_acc'};
    my $overwrite    = $args{'overwrite'} || 0;
    my $allow_update = $args{'allow_update'} || 0;
    my $quiet        = $args{'quiet'} || 0;
    my $sql_object   = $self->sql;
    my ( $map_set, $files );

    if ($command_line) {
        my @missing = ();
        if ($file_str) {
            unless ( $files = $self->get_files( file_str => $file_str ) ) {
                print STDERR "None of the files, '$file_str' succeded.\n";
                push @missing, 'input file(s)';
            }
        }
        else {
            push @missing, 'input file(s)';
        }
        if ( defined($map_set_acc) ) {
            my $map_sets
                = $sql_object->get_map_sets( map_set_acc => $map_set_acc, );
            unless ( @{ $map_sets || [] } ) {
                print STDERR
                    "Map set Accession, '$map_set_acc' is not valid.\n";
                push @missing, 'map_set_acc';
            }
            $map_set = $map_sets->[0];
        }
        else {
            push @missing, 'map_set_acc';
        }
        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            return 0;
        }
    }
    else {

        ###New File Handling
        $files = $self->get_files() or return;

        my $map_sets
            = $self->get_map_sets( allow_mult => 0, allow_null => 0 );
        return unless @{ $map_sets || [] };
        $map_set = $map_sets->[0];

        print "Remove data in map set not in import file? [y/N] ";
        chomp( $overwrite = <STDIN> );
        $overwrite = ( $overwrite =~ /^[Yy]/ ) ? 1 : 0;

        print join( "\n",
            'It looks like you are updating an existing map set.  If you ',
            'like, I can see if feature accessions from your input file ',
            'are already present in the database and update the existing ',
            'features.  Otherwise, I will simply insert all your new data ',
            'without checking.  This will go much faster, but may cause ',
            'problems if your input file has feature accessions already ',
            'present in the database.',
            '',
            "Check for duplicate data (slow)? [y/N]",
        );
        chomp( $allow_update = <STDIN> );
        $allow_update = ( $allow_update =~ /^[Yy]/ ) ? 1 : 0;

        #
        # Confirm decisions.
        #
        print join( "\n",
            'OK to import?',
            '  Data source : ' . $self->data_source,
            "  File        : " . join( ", ", @$files ),
            "  Species     : " . $map_set->{species_common_name},
            "  Map Type    : " . $map_set->{map_type},
            "  Map Set     : " . $map_set->{map_set_short_name},
            "  Map Set Acc : " . $map_set->{map_set_acc},
            "  Overwrite   : " .     ( $overwrite    ? "Yes" : "No" ),
            "  Update Features : " . ( $allow_update ? "Yes" : "No" ),
            "[Y/n] " );
        chomp( my $answer = <STDIN> );
        return if $answer =~ /^[Nn]/;
    }

    my $importer = Bio::GMOD::CMap::Admin::Import->new(
        config      => $self->config,
        data_source => $self->data_source,
    );

    my $time_start = new Benchmark;
    my %maps;    #stores the maps info between each file
    foreach my $file (@$files) {
        my $fh = IO::File->new($file) or die "Can't read $file: $!";
        $importer->import_tab(
            map_set_id   => $map_set->{'map_set_id'},
            fh           => $fh,
            map_type_acc => $map_set->{'map_type_acc'},
            log_fh       => $self->log_fh,
            overwrite    => $overwrite,
            allow_update => $allow_update,
            maps         => \%maps,
            )
            or do {
            print "Error: ", $importer->error, "\n";
            return;
            };
    }

    my $time_end = new Benchmark;
    print STDERR "import time: "
        . timestr( timediff( $time_end, $time_start ) ) . "\n"
        unless ($quiet);

    $self->purge_query_cache( cache_level => 1 );
    return 1;
}

# ----------------------------------------------------
sub import_object_data {

=pod

=head2 import_object_data

=head3 Description

Import a CMap, XML object file

If command_line is true, checks for required options and imports the data.

If command_line is not true, uses a menu system to get the import options.

=head3 Parameters

=over 4

=item * command_line

=item * file_str (required if command_line)

=item * overwrite

Boolean:  When true, removes any old data that wasn't in the new data file.

=back

=cut

    #
    # Gathers the info to import physical or genetic maps.
    #
    my ( $self, %args ) = @_;
    my $command_line = $args{'command_line'};
    my $file_str     = $args{'file_str'};
    my $overwrite    = $args{'overwrite'} || 0;
    my $single_file  = $self->file;
    my $files;

    if ($command_line) {
        my @missing = ();
        if ($file_str) {
            unless ( $files = $self->get_files( file_str => $file_str ) ) {
                print STDERR "None of the files, '$file_str' succeded.\n";
                push @missing, 'input file(s)';
            }
        }
        else {
            push @missing, 'input file(s)';
        }
        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            return 0;
        }
    }
    else {

        #
        # Make sure we have a file to parse.
        #
        if ($single_file) {
            print "OK to use '$single_file'? [Y/n] ";
            chomp( my $answer = <STDIN> );
            $single_file = '' if $answer =~ m/^[Nn]/;
        }

        if ( -r $single_file and -f _ ) {
            push @$files, $single_file;
        }
        else {
            print "Unable to read '$single_file' or not a regular file.\n"
                if $single_file;
            $files = $self->get_files() or return;
        }

        print "Overwrite any existing data? [y/N] ";
        chomp( $overwrite = <STDIN> );
        $overwrite = ( $overwrite =~ /^[Yy]/ ) ? 1 : 0;

        #
        # Confirm decisions.
        #
        print join( "\n",
            'OK to import?',
            '  Data source : ' . $self->data_source,
            "  File        : " . join( ', ', @$files ),
            "  Overwrite   : " . ( $overwrite ? "Yes" : "No" ),
            "[Y/n] " );
        chomp( my $answer = <STDIN> );
        return if $answer =~ /^[Nn]/;
    }

    my $importer = Bio::GMOD::CMap::Admin::Import->new(
        config      => $self->config,
        data_source => $self->data_source,
    );
    foreach my $file (@$files) {
        my $fh = IO::File->new($file) or die "Can't read $file: $!";
        $self->file($file);
        $importer->import_objects(
            fh        => $fh,
            log_fh    => $self->log_fh,
            overwrite => $overwrite,
            )
            or do {
            print "Error: ", $importer->error, "\n";
            return;
            };
    }
    $self->purge_query_cache( cache_level => 1 );
    return 1;
}

# ----------------------------------------------------
sub make_name_correspondences {

=pod

=head2 make_name_correspondences

=head3 Description

Kicks off name based correpondence creation

If command_line is true, checks for required options and creates the
correspondences.

If command_line is not true, uses a menu system to get the options.

=head3 Parameters

=over 4

=item * command_line

=item * quiet

Boolean: When true, don't print out as much.

=item * allow_update

Boolean: When true, check for duplicate correspondences before creating, this
can be slow.

=item * from_map_set_accs (required if command_line)

A comma (or space) separated list of map set accessions that will be the
starting point of the correspondences.

=item * to_map_set_accs

A comma (or space) separated list of map set accessions that will be the
destination of the correspondences.  

Only specify if different that from_map_set_accs.

=item * evidence_type_acc (required if command_line)

=item * from_group_size

Number of 'from' maps to consider at once when comparing: A higher number is
more efficient but takes more memory.  This is useful when the from map set has
a lot of maps with few features on each one. 

=item * skip_feature_type_accs

A comma (or space) separated list of feature type accessions that should not be
used

=item * name_regex 

The name of the regular expression to be used (default: exact_match) 

Options: exact_match, read_pair


=back

=cut

    my ( $self, %args ) = @_;
    my $command_line               = $args{'command_line'};
    my $evidence_type_acc          = $args{'evidence_type_acc'};
    my $from_map_set_accs          = $args{'from_map_set_accs'};
    my $to_map_set_accs            = $args{'to_map_set_accs'};
    my $skip_feature_type_accs_str = $args{'skip_feature_type_accs'};
    my $allow_update               = $args{'allow_update'} || 0;
    my $name_regex_option          = $args{'name_regex'};
    my $from_group_size            = $args{'from_group_size'} || 1;
    my $quiet                      = $args{'quiet'} || 0;
    my $sql_object                 = $self->sql;

    my @from_map_set_ids;
    my @to_map_set_ids;
    my @skip_feature_type_accs;
    my $name_regex;
    my $regex_options = [
        {   regex_title => 'exact match only',
            regex       => '',
            option_name => 'exact_match',
        },
        {   regex_title => q[read pairs '(\S+)\.\w\d$'],
            regex       => '(\S+)\.\w\d$',
            option_name => 'read_pair',
        },
        {   regex_title => q[washu read pairs '(\S+)\.\w\d$'],
            regex       => '(\S+)[a-z]\.\w\d$',
            option_name => 'washu_read_pair',
        },
    ];

    if ($command_line) {
        my @missing = ();
        if ( defined($evidence_type_acc) ) {
            unless ( $self->evidence_type_data($evidence_type_acc) ) {
                print STDERR
                    "The evidence_type_acc, '$evidence_type_acc' is not valid.\n";
                push @missing, 'evidence_type_acc';
            }
        }
        else {
            push @missing, 'evidence_type_acc';
        }
        if ( defined($skip_feature_type_accs_str) ) {
            @skip_feature_type_accs = split /[,\s]+/,
                $skip_feature_type_accs_str;
            my $valid = 1;
            foreach my $fta (@skip_feature_type_accs) {
                unless ( $self->feature_type_data($fta) ) {
                    print STDERR
                        "The skip_feature_type_acc, '$fta' is not valid.\n";
                    $valid = 0;
                }
            }
            unless ($valid) {
                push @missing, 'valid feature_type_acc';
            }
        }
        if ( defined($from_map_set_accs) ) {

            # split on space or comma
            my @from_map_set_accs = split /[,\s]+/, $from_map_set_accs;
            if (@from_map_set_accs) {
                my $valid = 1;
                foreach my $acc (@from_map_set_accs) {
                    my $map_set_id = $sql_object->acc_id_to_internal_id(
                        acc_id      => $acc,
                        object_type => 'map_set'
                    );
                    if ($map_set_id) {
                        push @from_map_set_ids, $map_set_id;
                    }
                    else {
                        print STDERR
                            "from map set accession, '$acc' is not valid.\n";
                        $valid = 0;
                    }
                }
                unless ($valid) {
                    push @missing, 'valid from_map_set_accs';
                }
            }
            else {
                push @missing, 'valid from_map_set_accs';
            }
        }
        else {
            push @missing, 'from_map_set_accs';
        }
        if ( defined($to_map_set_accs) ) {

            # split on space or comma
            my @to_map_set_accs = split /[,\s]+/, $to_map_set_accs;
            if (@to_map_set_accs) {
                my $valid = 1;
                foreach my $acc (@to_map_set_accs) {
                    my $map_set_id = $sql_object->acc_id_to_internal_id(
                        acc_id      => $acc,
                        object_type => 'map_set'
                    );
                    if ($map_set_id) {
                        push @to_map_set_ids, $map_set_id;
                    }
                    else {
                        print STDERR
                            "to map set accession, '$acc' is not valid.\n";
                        $valid = 0;
                    }
                }
                unless ($valid) {
                    push @missing, 'valid to_map_set_accs';
                }
            }
            else {
                push @missing, 'valid to_map_set_accs';
            }
        }
        else {
            @to_map_set_ids = @from_map_set_ids;
        }
        if ($name_regex_option) {
            my $found = 0;
            foreach my $item (@$regex_options) {
                if ( $name_regex_option eq $item->{'option_name'} ) {
                    $found      = 1;
                    $name_regex = $item->{'regex'};
                    last;
                }
            }
            unless ($found) {
                print STDERR
                    "The name_regex '$name_regex_option' is not valid.\n";
                push @missing, 'valid name_regex';
            }
        }
        else {
            $name_regex = '';
        }
        if ($from_group_size) {
            unless ( $from_group_size =~ /^\d+$/ ) {
                print STDERR
                    "The from_group_size '$from_group_size' is not valid.\n";
                push @missing, 'valid from_group_size';
            }
        }

        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            return 0;
        }
    }
    else {

        #
        # Get the evidence type id.
        #
        my $evidence_type;
        ( $evidence_type_acc, $evidence_type ) = $self->show_menu(
            title   => 'Available evidence types',
            prompt  => 'Please select an evidence type',
            display => 'evidence_type',
            return  => 'evidence_type_acc,evidence_type',
            data    => sort_selectall_arrayref(
                $self->fake_selectall_arrayref(
                    $self->evidence_type_data(), 'evidence_type_acc',
                    'evidence_type'
                ),
                'evidence_type'
            ),
        );
        die "No evidence types!  Please use the config file to create.\n"
            unless $evidence_type;

        my $from_map_sets
            = $self->get_map_sets(
            explanation => 'First you will select the starting map sets' )
            or return;

        my $use_from_as_target_answer
            = $self->show_question( question =>
                'Do you want to use the starting map sets as the target sets? [y|N]',
            );
        my $to_map_sets;
        if ( $use_from_as_target_answer =~ /^y/ ) {
            $to_map_sets = $from_map_sets;
        }
        else {
            $to_map_sets = $self->get_map_sets(
                explanation => 'Now you will select the target map sets',
                allow_null  => 0,
            ) or return;
        }

        my @skip_features = $self->show_menu(
            title      => 'Skip Feature Types (optional)',
            prompt     => 'Select any feature types to skip in check',
            display    => 'feature_type',
            return     => 'feature_type_acc,feature_type',
            allow_null => 1,
            allow_mult => 1,
            data       => sort_selectall_arrayref(
                $self->fake_selectall_arrayref(
                    $self->feature_type_data(), 'feature_type_acc',
                    'feature_type'
                ),
                'feature_type'
            ),
        );
        @skip_feature_type_accs = map { $_->[0] } @skip_features;
        my $skip
            = @skip_features
            ? join( "\n     ", map { $_->[1] } @skip_features ) . "\n"
            : '    None';

        print "Check for duplicate data (slow)? [y/N] ";
        chomp( $allow_update = <STDIN> );
        $allow_update = ( $allow_update =~ /^[Yy]/ ) ? 1 : 0;

        $name_regex = $self->show_menu(
            title => "Match Type\n(You can add your own "
                . "match types by editing cmap_admin.pl)",
            prompt     => "Select the match type that you desire",
            display    => 'regex_title',
            return     => 'regex',
            allow_null => 0,
            allow_mult => 0,
            data       => $regex_options,
        );

        print "Number of 'from' maps to consider at once when comparing:  \n"
            . "A higher number is more efficient but takes more memory.\n"
            . "This is useful when the from map set has a lot of maps \n"
            . "with few features on each one. [1]: ";
        chomp( $from_group_size = <STDIN> );
        $from_group_size ||= 1;
        unless ( $from_group_size =~ /^\d+$/ ) {
            print STDERR
                "The from_group_size '$from_group_size' is not valid.\n";
            return;
        }

        my $from = join(
            "\n",
            map {
                      "    "
                    . $_->{species_common_name} . "-"
                    . $_->{map_set_short_name} . " ("
                    . $_->{map_set_acc} . ")"
                } @{$from_map_sets}
        );

        my $to = join(
            "\n",
            map {
                      "    "
                    . $_->{species_common_name} . "-"
                    . $_->{map_set_short_name} . " ("
                    . $_->{map_set_acc} . ")"
                } @{$to_map_sets}
        );
        print "Make name-based correspondences\n",
            '  Data source   : ' . $self->data_source, "\n",
            "  Evidence type : $evidence_type\n",
            "  From map sets :\n$from\n", "  To map sets   :\n$to\n",
            "  Skip features :\n$skip\n",
            "  Check for dups  : " . ( $allow_update ? "yes" : "no" );
        print "\nOK to make correspondences? [Y/n] ";
        chomp( my $answer = <STDIN> );
        return if $answer =~ m/^[Nn]/;
        @from_map_set_ids = map { $_->{map_set_id} } @$from_map_sets;
        @to_map_set_ids   = map { $_->{map_set_id} } @$to_map_sets;
    }

    my $corr_maker = Bio::GMOD::CMap::Admin::MakeCorrespondences->new(
        config      => $self->config,
        db          => $self->db,
        data_source => $self->data_source,
    );

    my $time_start = new Benchmark;
    $corr_maker->make_name_correspondences(
        evidence_type_acc      => $evidence_type_acc,
        from_map_set_ids       => \@from_map_set_ids,
        to_map_set_ids         => \@to_map_set_ids,
        skip_feature_type_accs => \@skip_feature_type_accs,
        log_fh                 => $self->log_fh,
        quiet                  => $quiet,
        name_regex             => $name_regex,
        allow_update           => $allow_update,
        from_group_size        => $from_group_size,
    ) or do { print "Error: ", $corr_maker->error, "\n"; return; };

    my $time_end = new Benchmark;
    print STDERR "make correspondence time: "
        . timestr( timediff( $time_end, $time_start ) ) . "\n"
        unless ($quiet);

    $self->purge_query_cache( cache_level => 4 );
    return 1;
}

# ----------------------------------------------------
sub reload_correspondence_matrix {

=pod

=head2 reload_correspondence_matrix

=head3 Description

Reloads the correspondence matrix to allow new data to be put into the matrix
view.

=head3 Parameters

=over 4

=item * command_line

=back

=cut

    my ( $self, %args ) = @_;
    my $command_line = $args{'command_line'};

    unless ($command_line) {
        print "OK to truncate table in data source '", $self->data_source,
            "' and reload? [Y/n] ";
        chomp( my $answer = <STDIN> );
        return if $answer =~ m/^[Nn]/;
    }

    my $admin = $self->admin;
    $admin->reload_correspondence_matrix or do {
        print "Error: ", $admin->error, "\n";
        return;
    };

    return 1;
}

# ----------------------------------------------------
sub prepare_for_gbrowse {

=pod

=head2 prepare_for_gbrowse

=head3 Description

Menu system that gathers the info to import CMap into GBrowse.

=head3 Parameters

No Parameters

=cut

    require Bio::GMOD::CMap::Admin::GBrowseLiason;

    my $self = shift;

    #
    # Get the map sets.
    #
    my $map_sets = $self->get_map_sets(
        explanation => 'Which map sets do you want to use',
        allow_mult  => 1,
        allow_null  => 0,
    ) or return;

    #
    # Get the feature types
    #
    my $feature_type_data = $self->feature_type_data();
    my $menu_options;
    foreach my $ft_acc ( keys(%$feature_type_data) ) {
        if ( $feature_type_data->{$ft_acc}->{'gbrowse_class'} ) {
            push @$menu_options,
                {
                feature_type =>
                    $feature_type_data->{$ft_acc}->{'feature_type'},
                feature_type_acc => $ft_acc,
                };
        }
    }
    $menu_options = sort_selectall_arrayref( $menu_options, 'feature_type' );

    unless ( $menu_options and @$menu_options ) {
        print "No GBrowse eligible feature types\n";
        return 0;
    }

    my @feature_types = $self->show_menu(
        title => 'Feature Types to be Prepared',
        prompt =>
            "Select the feature types that should be prepared for GBrowse data.\n"
            . "Only eligible feature type (that have a 'gbrowse_class' defined in their config) are displayed.",
        display    => 'feature_type',
        return     => 'feature_type_acc,feature_type',
        allow_null => 0,
        allow_mult => 1,
        data       => $menu_options,
    );

    print join(
        "\n",
        'OK to prepare for GBrowse?',
        '  Data source     : ' . $self->data_source,
        '  Map Sets        : '
            . join( "\n",
            map { "    " . $_->{'map_set_short_name'} } @$map_sets ),
        '  Feature Types   : '
            . join( "\n", map { "    " . $_->[1] } @feature_types ),
    );

    print "\n[Y/n] ";

    chomp( my $answer = <STDIN> );
    return if $answer =~ /^[Nn]/;

    my @map_set_ids       = map { $_->{'map_set_id'} } @$map_sets;
    my @feature_type_accs = map { $_->[0] } @feature_types;
    my $gbrowse_liason = Bio::GMOD::CMap::Admin::GBrowseLiason->new(
        config      => $self->config,
        data_source => $self->data_source,
    );
    $gbrowse_liason->prepare_data_for_gbrowse(
        map_set_ids       => \@map_set_ids,
        feature_type_accs => \@feature_type_accs,
        )
        or do {
        print "Error: ", $gbrowse_liason->error, "\n";
        return;
        };
    return 1;
}

# ----------------------------------------------------
sub copy_cmap_into_gbrowse {

=pod

=head2 copy_cmap_into_gbrowse

=head3 Description

Menu system that copies CMap into GBrowse after it has been prepared.

=head3 Parameters

No Parameters

=cut

    require Bio::GMOD::CMap::Admin::GBrowseLiason;

    my $self = shift;

    #
    # Get the map sets.
    #
    my $map_sets = $self->get_map_sets(
        explanation => 'Which map sets do you want to copy data from?',
        allow_mult  => 1,
        allow_null  => 0,
    ) or return;

    #
    # Get the feature types
    #
    my $feature_type_data = $self->feature_type_data();
    my $menu_options;
    foreach my $ft_acc ( keys(%$feature_type_data) ) {
        if (    $feature_type_data->{$ft_acc}->{'gbrowse_class'}
            and $feature_type_data->{$ft_acc}->{'gbrowse_ftype'} )
        {
            push @$menu_options,
                {
                feature_type =>
                    $feature_type_data->{$ft_acc}->{'feature_type'},
                feature_type_acc => $ft_acc,
                };
        }
    }
    $menu_options = sort_selectall_arrayref( $menu_options, 'feature_type' );

    unless ( $menu_options and @$menu_options ) {
        print "No GBrowse eligible feature types\n";
        return 0;
    }

    my @feature_types = $self->show_menu(
        title => 'Feature Types to be Prepared',
        prompt =>
            "Select the feature types that should be prepared for GBrowse data.\n"
            . "Only eligible feature types ('gbrowse_class' and 'gbrowse_ftype' defined in the config) are displayed.\n"
            . "Selecting none will select all.",
        display    => 'feature_type',
        return     => 'feature_type_acc,feature_type',
        allow_null => 1,
        allow_mult => 1,
        data       => $menu_options,
    );

    print join(
        "\n",
        'OK to copy data into GBrowse?',
        '  Data source     : ' . $self->data_source,
        '  Map Sets        : '
            . join( "\n",
            map { "    " . $_->{'map_set_short_name'} } @$map_sets ),
        '  Feature Types   : '
            . (
            @feature_types
            ? join( "\n", map { "    " . $_->[1] } @feature_types )
            : 'All'
            ),
    );

    print "\n[Y/n] ";

    chomp( my $answer = <STDIN> );
    return if $answer =~ /^[Nn]/;

    my @map_set_ids       = map { $_->{'map_set_id'} } @$map_sets;
    my @feature_type_accs = map { $_->[0] } @feature_types;
    my $gbrowse_liason = Bio::GMOD::CMap::Admin::GBrowseLiason->new(
        config      => $self->config,
        data_source => $self->data_source,
    );
    $gbrowse_liason->copy_data_into_gbrowse(
        map_set_ids       => \@map_set_ids,
        feature_type_accs => \@feature_type_accs,
        )
        or do {
        print "Error: ", $gbrowse_liason->error, "\n";
        return;
        };
    return 1;
}

# ----------------------------------------------------
sub copy_gbrowse_into_cmap {

=pod

=head2 copy_gbrowse_into_cmap

=head3 Description

Menu system that copies GBrowse info into CMap.

=head3 Parameters

No Parameters

=cut

    require Bio::GMOD::CMap::Admin::GBrowseLiason;

    my $self = shift;

    #
    # Get the map sets.
    #
    my $map_sets = $self->get_map_sets(
        explanation =>
            'Which map set do you want the copied data to be part of?',
        allow_mult => 0,
        allow_null => 0,
    ) or return;
    my $map_set_id = $map_sets->[0]{'map_set_id'};

    print join(
        "\n",
        'OK to copy data into CMap?',
        '  Data source     : ' . $self->data_source,
        '  Map Set         : '
            . join( "\n",
            map { "    " . $_->{'map_set_short_name'} } @$map_sets ),
    );

    print "\n[Y/n] ";

    chomp( my $answer = <STDIN> );
    return if $answer =~ /^[Nn]/;

    my $gbrowse_liason = Bio::GMOD::CMap::Admin::GBrowseLiason->new(
        config      => $self->config,
        data_source => $self->data_source,
    );
    $gbrowse_liason->copy_data_into_cmap( map_set_id => $map_set_id, )
        or do {
        print "Error: ", $gbrowse_liason->error, "\n";
        return;
        };
    $self->purge_query_cache( cache_level => 1 );
    return 1;
}

# ----------------------------------------------------
sub show_question {

=pod

=head2 show_question

=head3 Description

Menu system that displays a question to the user and returns the answer

=head3 Parameters

=over 4

=item * question

The question to pose to the user

=item * allow_null

Boolean: When true, allow user to give nothing as an answer

=item * valid_hash

A hash with valid answers in it for validation.

=item * default

The default answer.

=back

=cut

    my $self         = shift;
    my %args         = @_;
    my $question     = $args{'question'} or return;
    my $default      = $args{'default'};
    my $allow_null   = $args{'allow_null'};
    my $validHashRef = $args{'valid_hash'} || ();
    $allow_null = 1 unless ( defined($allow_null) );

    $question .= "<Default: $default>:" if ( defined $default );
    my $answer;
    while (1) {
        print $question;
        chomp( $answer = <STDIN> );
        if ( $validHashRef and $answer and not $validHashRef->{$answer} ) {
            print "Options:\n" . join( "\n", keys %{$validHashRef} ) . "\n";
            print
                "Your input was not valid, please choose from the above list\n";
            print $question;
            next;
        }
        elsif (( !$allow_null and not defined($answer) )
            or ( defined($answer) and $answer =~ /\s+/ ) )
        {
            print "Your input was not valid.\n";
            print $question;
            next;
        }
        $answer = $answer || $default;
        return $answer;
    }
}

# ----------------------------------------------------
sub show_menu {

=pod

=head2 show_menu

=head3 Description

Menu system that displays a prompt to the user with a menu of choices and
returns the answer

=head3 Parameters

=over 4

=item * allow_null

Boolean: When true, allow user to give nothing as an answer

=item * allow_all

Boolean: When true, allow user to select all

=item * allow_mult

Boolean: When true, allow user to give multiple answers

=item * data

The choices.

=item * prompt

How to prompt the user

=item * display

A comma delimited string of a set of hash keys that will be displayed to the
user.

=item * return

The values of the data to return when selected.

=item * title

Title to give to the menu

=back

=cut

    my $self   = shift;
    my %args   = @_;
    my $data   = $args{'data'} or return;
    my @return = split( /,/, $args{'return'} )
        or die "No return field(s) defined\n";
    my @display    = split( /,/, $args{'display'} );
    my $allow_null = $args{'allow_null'};
    my $allow_mult = $args{'allow_mult'};
    my $allow_all  = $args{'allow_all'};
    my $title      = $args{'title'};
    my $prompt     = $args{'prompt'} || 'Please select';
    my $result;

    if ( scalar @$data > 1 || $allow_null ) {
        my $i      = 1;
        my %lookup = ();

        my $title = $title || '';
        print $title ? "\n$title\n" : "\n";
        for my $row (@$data) {
            print "[$i] ", join( ' : ', map { $row->{$_} } @display ), "\n";
            $lookup{$i}
                = scalar @return > 1
                ? [ map { $row->{$_} } @return ]
                : $row->{ $return[0] };
            $i++;
        }

        if ( $allow_all and $allow_mult ) {
            print "[$i] All of the above\n";
        }

        $prompt .=
               $allow_null
            && $allow_mult ? "\n(<Enter> for nothing, multiple allowed): "
            : $allow_null  ? ' (0 or <Enter> for nothing): '
            : $allow_mult  ? ' (multiple allowed): '
            : $allow_mult  ? ' (multiple allowed):'
            :                ' (one choice only): ';

        for ( ;; ) {
            print "\n$prompt";
            chomp( my $answer = <STDIN> );

            if ( $allow_null && !$answer ) {
                $result = undef;
                last;
            }
            elsif ( $allow_all || $allow_mult ) {
                my %numbers =

                    # make a lookup
                    map { $_, 1 }

                    # take only numbers
                    grep {/\d+/}

                    # look for ranges
                    map { $_ =~ m/(\d+)-(\d+)/ ? ( $1 .. $2 ) : $_ }

                    # split on space or comma
                    split /[,\s]+/, $answer;

                if ( $allow_all && grep { $_ == $i } keys %numbers ) {
                    $result = [ map { $lookup{$_} } 1 .. $i - 1 ];
                    last;
                }

                $result = [
                    map { $_ || () }    # parse out nulls
                        map  { $lookup{$_} }    # look it up
                        sort { $a <=> $b }      # keep order
                        keys %numbers           # make unique
                ];

                next unless @$result;
                last;
            }
            elsif ( defined $lookup{$answer} ) {
                $result = $lookup{$answer};
                last;
            }
        }
    }
    elsif ( scalar @$data == 0 ) {
        $result = undef;
    }
    else {

        # only one choice, use it.
        $result = [ map { $data->[0]->{$_} } @return ];
        $result = [$result] if ($allow_mult);
        unless ( wantarray or scalar(@$result) != 1 ) {
            $result = $result->[0];
        }
        my $value = join( ' : ', map { $data->[0]->{$_} } @display );
        my $title = $title || '';
        print $title ? "\n$title\n" : "\n";
        print "Using '$value'\n";
    }

    return wantarray
        ? defined $result
            ? @$result
            : ()
        : $result;
}

# ----------------------------------------------------
sub _get_dir {

=pod

=head2 _get_dir

=head3 Description

Get a directory for writing files to.

If given, accepts whatever dir_str is set to.

=head3 Parameters

=over 4

=item * dir_str

=back

=cut

    my ( $self, %args ) = @_;
    my $dir_str = $args{'dir_str'};
    my $dir;
    my $fh = \*STDOUT;
    $fh = \*STDERR if ($dir_str);
    my $continue_loop = 1;
    while ( not defined($dir) and $continue_loop ) {
        my $answer;
        if ($dir_str) {
            $continue_loop = 0;
            $answer        = $dir_str;
        }
        else {
            print $fh
                "\nTo which directory should I write the output files?\n",
                "['q' to quit, current dir (.) is default] ";
            chomp( $answer = <STDIN> );
            $answer ||= '.';
            return if $answer =~ m/^[qQ]/;
        }

        if ( -d $answer ) {
            if ( -w _ ) {
                $dir = $answer;
                last;
            }
            else {
                print $fh "\n'$answer' is not writable by you.\n\n";
                next;
            }
        }
        elsif ( -f $answer ) {
            print $fh
                "\n'$answer' is not a directory.  Please try again.\n\n";
            next;
        }
        else {
            my $response;
            if ( not $dir_str ) {
                print $fh "\n'$answer' does not exist.  Create? [Y/n] ";
                chomp( $response = <STDIN> );
            }
            $response ||= 'y';
            if ( $response =~ m/^[Yy]/ ) {
                eval { mkpath( $answer, 0, 0711 ) };
                if ( my $err = $@ ) {
                    print $fh "I couldn't make that directory: $err\n\n";
                    next;
                }
                else {
                    $dir = $answer;
                    last;
                }
            }
        }
    }
    return $dir;
}

# ----------------------------------------------------
sub _get_export_file {

=pod

=head2 _get_export_file

=head3 Description

Get the name of an output file

If given, accepts whatever file_str is set to.

=head3 Parameters

=over 4

=item * file_str

=back

=cut

    my ( $self, %args ) = @_;
    my $file_str = $args{'file_str'};
    my $dir      = $args{'dir'};
    my $default  = $args{'default'};
    my $file;
    my $fh = \*STDOUT;
    $fh = \*STDERR if ($file_str);
    my $continue_loop = 1;
    while ( not defined($file) and $continue_loop ) {
        my $answer;
        if ($file_str) {
            $continue_loop = 0;
            $answer        = $file_str;
        }
        else {
            print $fh "\nTo which file should I write the output?\n",
                "['q' to quit, default: $default ] ";
            chomp( $answer = <STDIN> );
            $answer ||= $default;
            return if $answer =~ m/^[qQ]/;
        }

        if ( -d $dir . "/" . $answer ) {
            print $fh
                "\n'$answer' is a directory, please choose another file name.\n\n";
            next;
        }
        elsif ( -e $dir . "/" . $answer and not $file_str ) {
            my $response;
            print $fh "\n'$answer' already exists.  Overwrite? [y/N] ";
            chomp( $response = <STDIN> );
            $response ||= 'n';
            if ( $response =~ m/^[Yy]/ ) {
                $file = $answer;
                last;
            }
            else {
                print $fh "\nPlease choose another file name or quit.\n\n";
                next;
            }
        }
        else {
            $file = $answer;
            last;
        }
    }
    return $file;
}

# ----------------------------------------------------
# Life is full of misery, loneliness, and suffering --
# and it's all over much too soon.
# Woody Allen
# ----------------------------------------------------

=pod

=head1 cmap_admin.pl Synopsis

The rest of the documentation deals with cmap_admin.pl.

  ./cmap_admin.pl [options] [data_file]

  Options:

    -h|help          Display help message
    -i|info          Display more options
    -v|version       Display version
    -d|--datasource  The default data source to use
    -c|--config_dir  The location of the config files to use (useful when multiple installs)
    --no-log         Don't keep a log of actions
    --action         Command line action. See --info for more information

=head1 OPTIONS

This script has command line actions that can be used for scripting.  This allows the user to skip the menu system.  The following are the allowed actions.

=head2 create_species

cmap_admin.pl [-d data_source] --action create_species --species_full_name "full name" [--species_common_name "common name"] [--species_acc "accession"]

  Required:
    --species_full_name : Full name of the species
  Optional:
    --species_common_name : Common name of the species
    --species_acc : Accession ID for the species

=head2 create_map_set

cmap_admin.pl [-d data_source] --action  create_map_set --map_set_name "Map Set Name" (--species_id id OR --species_acc accession) --map_type_acc "Map_type_accession" [--map_set_short_name "Short Name"] [--map_set_acc accesssion] [--map_shape shape] [--map_color color] [--map_width integer]

  Required:
    --map_set_name
    (
        --species_id : ID for the species
        or
        --species_acc : Accession ID for the species
    )
    --map_type_acc
  Optional:
    --map_set_short_name : Short name 
    --map_set_acc : Accession ID for the map set
    --map_shape : Shape of the maps in this set
    --map_color : Color of the maps in this set
    --map_width : Width of the maps in this set

=head2 delete_correspondences

cmap_admin.pl [-d data_source] --action delete_correspondences (--map_set_accs "accession [, acc2...]" OR --map_type_acc accession OR --species_acc accession) [--evidence_type_accs "accession [, acc2...]"]

  Required:
    --map_set_accs : A comma (or space) separated list of map set accessions
    or
    --map_type_acc : Accession ID of for the map type
    or
    --species_acc : Accession ID for the species
                                                                                
  Optional:
    --evidence_type_accs : A comma (or space) separated list of evidence type accessions to be deleted

=head2 delete_maps

cmap_admin.pl [-d data_source] --action delete_maps (--map_set_acc accession [ --map_accs all ] OR --map_accs "accession [, acc2...]")

  Required:
    --map_set_acc : Accession Id of a map set to be deleted
    or
    --map_accs :  A comma (or space) separated list of map accessions to be deleted

To delete all the maps from a map set, supply the --map_set_acc and use "--map_accs all".

=head2 export_as_text

cmap_admin.pl [-d data_source] --action export_as_text (--map_set_accs "accession [, acc2...]" OR --map_type_acc accession OR --species_acc accession) [--feature_type_accs "accession [, acc2...]"] [--exclude_fields "field [, field2...]"] [--directory directory]

  Required:
    --map_set_accs : A comma (or space) separated list of map set accessions
    or
    --map_type_acc : Accession ID of for the map type
    or
    --species_acc : Accession ID for the species
  Optional:
    --feature_type_accs : A comma (or space) separated list of feature type accessions
    --exclude_fields : List of table fields to exclude from output
    --directory : Directory to place the output

=head2 export_as_sql

cmap_admin.pl [-d data_source] --action export_as_sql [--add_truncate] [--export_file file_name] [--quote_escape value] [--tables "table [, table2...]"] 
        Optional:
    --export_file : Name of the export file (default:./cmap_dump.sql)
    --add_truncate : Include to add 'TRUNCATE TABLE' statements
    --quote_escape : How embedded quotes are escaped
                     'doubled' for Oracle
                     'backslash' for MySQL
    --tables : Tables to be exported.  (default: 'all')

=head2 export_objects

cmap_admin.pl [-d data_source] --action export_objects --export_objects "all"|"map_set" (--map_set_accs "accession [, acc2...]" OR --map_type_acc accession OR --species_acc accession) [--export_file file_name] [--directory directory]

cmap_admin.pl [-d data_source] --action export_objects --export_objects "species"&|"feature_correspondence"&|"xref" [--export_file file_name] [--directory directory]

  Required:
    --export_objects : Objects to be exported
                       Accepted options:
                        all, map_set, species,
                        feature_correspondence, xref
  Required if exporting map_set (or all):
    --map_set_accs : A comma (or space) separated list of map set accessions
    or
    --map_type_acc : Accession ID of for the map type
    or
    --species_acc : Accession ID for the species
  Optional:
    --export_file : Name of the output file (default: cmap_export.xml)
    --directory : Directory where the output file goes (default: ./)

=head2 import_correspondences

cmap_admin.pl [-d data_source] --action  import_correspondences --map_set_accs "accession [, acc2...]" file1 [file2 ...]

  Required:
    --map_set_accs : A comma (or space) separated list of map set accessions

=head2 import_tab_data

cmap_admin.pl [-d data_source] --action import_tab_data --map_set_acc accession [--overwrite] [--allow_update] file1 [file2 ...]

  Required:
    --map_set_acc : Accession Id of a map set for information to be inserted into
  Optional:
    --overwrite : Include to remove data in map set not in import file
    --allow_update : Include to check for duplicate data (slow)

=head2 import_object_data
cmap_admin.pl [-d data_source] --action import_object_data [--overwrite] file1 [file2 ...]

  Optional:
    --overwrite : Include to remove data in map set not in import file

=head2 make_name_correspondences

cmap_admin.pl [-d data_source] --action make_name_correspondences --evidence_type_acc acc --from_map_set_accs "accession [, acc2...]" [--to_map_set_accs "accession [, acc2...]"] [--skip_feature_type_accs "accession [, acc2...]"] [--allow_update] [--name_regex name] [--from_group_size number]

  Required:
    --evidence_type_acc : Accession ID of the evidence type to be created
    --from_map_set_accs : A comma (or space) separated list of map set 
        accessions that will be the starting point of the correspondences.
  Optional:
    --to_map_set_accs : A comma (or space) separated list of map set 
        accessions that will be the destination of the correspondences.  
        Only specify if different that from_map_set_accs.
    --skip_feature_type_accs : A comma (or space) separated list of 
        feature type accessions that should not be used
    --allow_update : Include to check for duplicate data (slow)
    --name_regex : The name of the regular expression to be used
                    (default: exact_match)
                    Options: exact_match, read_pair
    --from_group_size : The number of maps from the "from" map set to group 
        together during name based correspondence creation.
                    (default: 1)

=head2 reload_correspondence_matrix

cmap_admin.pl [-d data_source] --action reload_correspondence_matrix

=head2 purge_query_cache

cmap_admin.pl [-d data_source] --action purge_query_cache [options]

  Optional:
    --cache_level           : The level of the cache to be purged (default: 1)
    --purge_all_datasources : purge the caches of all datasources enabled on
                              this machine.

=head2 delete_duplicate_correspondences

cmap_admin.pl [-d data_source] --action delete_duplicate_correspondences [--map_set_acc map_set_acc]

  Optional:
    --map_set_acc : Limit the search for duplicates to correspondences 
        related to one map set.  Any correspondences that the map set 
        has will be examined.

=head1 DESCRIPTION

This script is a complement to the web-based administration tool for
the GMOD-CMap application.  This tool handles all of the long-running
processes (e.g., importing/exporting data and correspondences,
reloading cache tables) and tasks which require interaction with
file-based data (i.e., map coordinates, feature correspondences,
etc.).

The output of the actions taken by the program (i.e., statements of
what happens, not the menu items, etc.) will be tee'd between your
terminal and a log file unless you pass the "--no-log" argument on the
command line.  The log will be placed into your home directory and
will be called "cmap_admin_log.x" where "x" is a number starting at
zero and ascending by one for each time you run the program (until you
delete existing logs, of course).  The name of the log file will be
echoed to you when you exit the program.

All the questions asked in cmap_admin.pl can be answered either by
choosing the number of the answer from a pre-defined list or by typing
something (usually a file path, notice that you can use tab-completion
if your system supports it).  When the answer must be selected from a
list and the answer is required, you will not be allowed to leave the
question until you have selected an answer from the list.
Occassionally the answer is not required, so you can just hit
"<Return>."  Sometimes more than one answer is acceptable, so you
should specify all your choices on one line, separating the numbers
with spaces or commas and alternately specifying ranges with a dash
(and no spaces around the dash).  For instance, the following are
eqivalent:

  This:               Equates to:
  1                   1
  1-3                 1,2,3
  1,3-5               1,3,4,5
  1 3 3-5             1,3,4,5
  1, 3  5-8 , 10      1,3,5,6,7,8,10

Finally, sometimes a question is never asked if there is only one
possible answer; the one answer is automatically taken and processing
moves on to the next question.

=head1 ACTIONS

=head2 Change data source

Whenever the "Main Menu" is displayed, the current data source is
displayed.  If you have configured CMap to work with multiple data
sources, you can use this option to change which one you are currently
using.  The one defined as the "default" will always be chosen when
you first begin. See the ADMINISTRATION document for more information
on creating multiple data sources.

=head2 Create new map set

This is the one feature duplicated with the web admin tool.  This is
a very simple implementation, however, meant strictly as a convenience
when loading new data sets.  You can only specify the species, map
type, long and short names.  Everything else about the map set must be
edited with the web admin tool.

=head2 Import data for existing map set

This allows you to import the feature data for a map set. The map set
may be one you just created and is empty or one that already has data
associated with it.  If the latter, you may choose to remove all the
data currently in the map set when isn't updated with the new data you
are importing.  For specifics on how the data should be formatted, see
the documentation ("perldoc") for Bio::GMOD::CMap::Admin::Import.  The
file containing the feature data can either be given as an argument to
this script or you can specify the file's location when asked.  

=head2 Make name-based correspondences

This option will create correspondences between any two features with
the same "feature_name" or "aliases," irrespective of case.  It
is possible to choose to make the correspondences from only one map
set (for the occasions when you bring in just one new map set, you
don't want to rerun this for the whole database -- it can take a long
time).

=head2 Import feature correspondences

Choose this option to import a file containing correspondences between
your features.  For more information on the format of this file, see
the documentation for Bio::GMOD::CMap::Admin::ImportCorrespondences.
Like the name-based correspondences, you can restrict the maps which
are involved in the search.  The lookups for the features will be done
as normal, but only if one of the two features falls on one of the
maps specified will a correspondence be created.  Again, the idea is
that this should take less time than reloading correspondences when
searching the entire database.

=head2 Reload correspondence matrix

You should choose this option whenever you've altered the number of
correspondences in the database.  This will truncate the
"cmap_correspondence_matrix" table and reload it with the pair-wise
comparison of every map set in the database.

=head2 Export data

There are three ways to dump the data in CMap:

=over 4 

=item 1 

All Data as SQL INSERT statements

This method creates an INSERT statement for every record in every
table (or just those selected) a la "mysqldump."  This is meant to be
an easy way to backup or migrate an entire CMap database, esp. when
moving between database platforms (e.g. Oracle to MySQL).  The output
will be put into a file of your choosing and can be fed directly into
another database to mirror your current one.  You can also choose to
add "TRUNCATE TABLE" statements just before the INSERT statements so
as to erase any existing data.

B<Note to Oracle users>: If you have ampersands in strings, Oracle
will think that they are variables and will prompt you for values when
you run the file.  Either "SET SCAN OFF" or "SET DEFINE OFF" to have
Oracle accept the string as is.

=item 2 

Map data in CMap import format

This method creates a separate file for each map set in the database.
The data is dumped to the same tab-delimited format used when
importing.  You can choose to dump every map set or just particular
ones, and you can choose to I<leave out> certain fields (e.g., maybe
you don't care to export your accession IDs).

=item 3 

Feature correspondence data in CMap import format

This method dumps the feature correspondence data in the same
tab-delimited format that is accepted for importing.  You can choose
to export with or without the feature accession IDs.  If you choose to
export feature accession IDs, it will affect how the importing of the
data will work.  When accession IDs are present in the feature
correspondence import file, only features with the specified accession
IDs are used to create the correspondences, which is what you'll want
if you're exporting your correspondences to another database which
uses the same accession IDs for the same features as the source.  If,
however, the accession ID can't be found while importing, a name
lookup is used to find all the features with that name
(case-insensitively), which is what would happen if the accession IDs
weren't present at all.  In short, exporting with accession IDs is a
Good Thing if the importing database has the same accession IDs
(this was is much faster and more exact), but a very, very Bad Thing
if the importing database has different accession IDs.

=back

=head2 Delete a map or map set

Along with creating a map set, this is the an task duplicated with the
web admin tool.  The reason is because very large maps or map sets can
take a very long time to delete.  As all of the referential integrity
(e.g., deleting from one table causes deletes in others so as to not
create orphan records) is handled in Perl, then can take a while to
completely remove a map or map set.  Such a long-running process can
time out in web browsers, so it can be more convenient to remove data
using cmap_admin.pl.

To remove just one (or more) map of a map set, first choose the map
set and then the map (or maps) within it.  If you wish to remove an
entire map set, then answer "0" (or just hit "Return") when given a
list of maps.

=head2 Purge the cache to view new data

Purge the query cache.  The results of many queries are cached in an
effort to reduce time querying the database for common queries.
Purging the cache is important after the data has changed or after
the configuration file has change.  Otherwise the changes will not
be consistantly displayed.

There are five layers of the cache.  When one layer is purged all of
the layers after it are purged.

=over 4

=item * Cache Level 1 Purge All

Purge all when a map set or species has been added or modified.  A
change to map sets or species has potential to impact all of the data.

=item * Cache Level 2 (purge map info on down)

Level 2 is purged when map information is changed.

=item * Cache Level 3 (purge feature info on down)

Level 3 is purged when feature information is changed.

=item * Cache Level 4 (purge correspondence info on down)

Level 4 is purged when correspondence information is changed.

=item * Cache Level 5 (purge whole image caching )

Level 5 is purged when any information changes

=back

=head2 Delete duplicate correspondences

If duplicate correspondences may have been added, this will remove them.

=head2 Manage links

This option is where to import and delete links that will show up in
the "Imported Links" section of CMap.  The import takes a tab delimited
file, see "perldoc /path/to/Bio/GMOD/CMap/Admin/ManageLinks.pm" for
more info on the format.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.eduE<gt>.
Ben Faga E<lt>faga@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-8 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=head1 SEE ALSO

Bio::GMOD::CMap::Admin::Import, Bio::GMOD::CMap::Admin::ImportCorrespondences.

=cut

