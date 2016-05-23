package Bio::GMOD::CMap::Admin::Import;

# vim: set ft=perl:

# $Id: Import.pm,v 1.85 2008/03/07 21:26:30 mwz444 Exp $

=pod

=head1 NAME

Bio::GMOD::CMap::Admin::Import - import map data

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Admin::Import;

  my $importer = Bio::GMOD::CMap::Admin::Import->new(data_source=>$data_source);
  $importer->import(
      map_set_id => $map_set_id,
      fh         => $fh,
  ) or print "Error: ", $importer->error, "\n";

The "data_source" parameter is a string of the name of the data source
to be used.  This information is found in the config file as the
"<database>" name field.

=head1 DESCRIPTION

This module encapsulates the logic for importing all the various types
of maps into the database.

=cut

use strict;
use vars qw( $VERSION %DISPATCH %COLUMNS );
$VERSION = (qw$Revision: 1.85 $)[-1];

use Data::Dumper;
use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Constants;
use Text::RecordParser;
use Text::ParseWords 'parse_line';
use XML::Simple;
use Regexp::Common;
use base 'Bio::GMOD::CMap';

use constant FIELD_SEP => "\t";      # use tabs for field separator
use constant STRING_RE => qr{\S+};
use constant RE_LOOKUP => {
    string => STRING_RE,
    number => '^' . $RE{'num'}{'real'} . '$',
};

use vars '$LOG_FH';

%COLUMNS = (
    map_name            => { is_required => 1, datatype => 'string' },
    map_acc             => { is_required => 0, datatype => 'string' },
    map_display_order   => { is_required => 0, datatype => 'number' },
    map_start           => { is_required => 0, datatype => 'number' },
    map_stop            => { is_required => 0, datatype => 'number' },
    feature_name        => { is_required => 1, datatype => 'string' },
    feature_acc         => { is_required => 0, datatype => 'string' },
    feature_alt_name    => { is_required => 0, datatype => 'string' },
    feature_aliases     => { is_required => 0, datatype => 'string' },
    feature_start       => { is_required => 1, datatype => 'number' },
    feature_stop        => { is_required => 0, datatype => 'number' },
    feature_direction   => { is_required => 0, datatype => 'number' },
    feature_type_acc    => { is_required => 1, datatype => 'string' },
    feature_note        => { is_required => 0, datatype => 'string' },
    is_landmark         => { is_required => 0, datatype => 'number' },
    feature_dbxref_name => { is_required => 0, datatype => 'string' },
    feature_dbxref_url  => { is_required => 0, datatype => 'string' },
    feature_attributes  => { is_required => 0, datatype => 'string' },
);

# ----------------------------------------------------

sub import_tab {

=pod

=head2 import_tab

=head3 For External Use

=over 4

=item * Description

Imports tab-delimited file with the following fields:

    map_name *
    map_acc
    map_display_order
    map_start
    map_stop
    feature_name *
    feature_alt_name +
    feature_acc
    feature_aliases
    feature_start *
    feature_stop
    feature_direction
    feature_type_acc *
    feature_note +
    is_landmark
    feature_dbxref_name +
    feature_dbxref_url +
    feature_attributes

Fields with an asterisk are required.  Order of fields is not important.

Fields with a plus sign are deprecated.

When you import data for an map set that already has data, all
existing maps and features will be updated.  If you choose, any of the
pre-existing maps or features that aren't updated can be deleted (this
is what you'd want if the import file contains *all* the data you
have for the map set).


=item * Usage

    $importer->import_tab(
        map_set_id => $map_set_id,
        fh => $fh,
        overwrite => $overwrite,
        log_fh => $log_fh,
        allow_update => $allow_update,
    );

=item * Returns

1

=item * Fields

=over 4

=item - map_set_id

=item - overwrite

Set to 1 to delete and re-add the data if overwriting. 
Otherwise will just add.

=item - fh

File handle of the imput file.

=item - log_fh

File handle of the log file (default is STDOUT).

=item - allow_update 

If allow is set to 1, the database will be searched for duplicates 
which is slow.  Setting to 0 is recommended.

=back

=item * Feature Attributes

Feature attributes are defined as key:value pairs separated by
semi-colons, e.g.:

    Genbank ID: "BH245189"; Overgo: "SOG1776";

Which defines two separate attributes, one of type "Genbank ID" with
the value "BH245189" and another of type "Overgo" with the value of
"SOG1776."  It isn't strictly necessary to place double-quotes around
the values of the attributes, but it is recommended.  It is actually
required if the values themselves contain a delimiter (colons or
semi-colons), e.g.:

    DBXRef: "http://www.gramene.org/db/markers/marker_view?marker_name=CDO590"

If, in addition, you wish to include literal double-quotes in the
attribute values, they must be backslash-escapes, e.g.:

    DBXRef: "<a href=\"http://www.gramene.org/db/markers/marker_view?marker_name=CDO590\">View At Gramene</a>"

(But see below about importing actual cross-references.)

Version 0.08 of CMap added the "feature_note" field.  This is now
considered just another type of attribute.  The "feature_note" field
is provided only for backward-compatibility and will simply be added
as an attribute of type "Note."

Attribute names can be as wide as 255 characters while the values can
be quite large (exactly how large depends on which database you use
and how that field is defined).  The order of the attributes will be
used to determine the "display_order."

=item * Feature Aliases

Feature aliases should be a comma-separated list of values.  They may
either occur in the "feature_aliases" (or "feature_alt_name" in order to 
remain backward-compatible) field or in the "feature_attributes" field 
with the key "aliases" (case-insensitive), e.g.:

    Aliases: "SHO29a, SHO29b"

Note that an alias which is the same (case-sensitive) as the feature's 
primary name will be discarded.

=item * Cross-references

Any attribute of type "dbxref" or "xref" (case-insensitive) will be 
entered as an xref for the feature.  The field value should be enclosed
in double-quotes with the xref name separated from the URL by a 
semicolon like so:

    XRef: "View at Gramene;http://www.gramene.org/db/markers/marker_view?marker_name=CDO590"

The older "feature_dbxref*" fields are still accepted and are simply
appended to the list of xrefs.

=back

=cut

    my ( $self, %args ) = @_;
    my $sql_object = $self->sql          or die 'No database handle';
    my $map_set_id = $args{'map_set_id'} or die 'No map set id';
    my $fh         = $args{'fh'}         or die 'No file handle';
    my $overwrite = $args{'overwrite'} || 0;
    my $allow_update =
        defined( $args{'allow_update'} )
        ? $args{'allow_update'}
        : 2;
    my $maps = $args{'maps'} || {};

    $LOG_FH = $args{'log_fh'} || \*STDOUT;

    my $file_pos = $fh->getpos;
    return $self->error("File did not pass inspection\n")
        unless (
        $self->validate_tab_file(
            fh     => $fh,
            log_fh => $LOG_FH,
        )
        );
    $fh->setpos($file_pos);

    my $max_simultaneous_inserts = 1000;

    my $admin = Bio::GMOD::CMap::Admin->new(
        config      => $self->config,
        data_source => $self->data_source
        )
        or return $self->error( "Can't create admin object: ",
        Bio::GMOD::CMap::Admin->error );

    #
    # Examine map set.
    #
    $self->Print("Importing map set data.\n");
    $self->Print("Examining map set.\n");
    my $map_set_array
        = $sql_object->get_map_sets( map_set_id => $map_set_id, );
    return unless (@$map_set_array);
    my $map_set = $map_set_array->[0];

    my $map_set_name = $map_set->{'species_common_name'} . "-"
        . $map_set->{'map_set_name'};

    my $map_info = $sql_object->get_maps_simple( map_set_id => $map_set_id, );

    unless (%$maps) {
        %$maps
            = map { uc $_->{'map_name'}, { map_id => $_->{'map_id'} } }
            @$map_info;

        #
        # Memorize the features originally on each map.
        #
        if ($overwrite) {
            for my $map_name ( keys %$maps ) {
                my $map_id = $maps->{$map_name}{'map_id'}
                    or return $self->error("Map '$map_name' has no ID!");

                my $features
                    = $sql_object->get_features_simple( map_id => $map_id, );

                foreach my $feature (@$features) {
                    $maps->{$map_name}{'features'}{ $feature->{'feature_id'} }
                        = 0
                        unless ( $maps->{$map_name}{'features'}
                        { $feature->{'feature_id'} } );
                }

                $self->Print(
                    "Map '$map_name' currently has ",
                    scalar @$features,
                    " features\n"
                );
            }
        }
    }
    my %map_accs      = map { $_->{'map_acc'}, $_->{'map_name'} } @$map_info;
    my %modified_maps = ();

    $self->Print(
        "'$map_set_name' currently has ",
        scalar keys %$maps,
        " maps.\n"
    );


    #
    # Make column names lowercase, convert spaces to underscores
    # (e.g., make "Feature Name" => "feature_name").
    #
    $self->Print("Reading File.\n");
    my $parser = Text::RecordParser->new(
        fh              => $fh,
        field_separator => FIELD_SEP,
        header_filter   => sub { $_ = shift; s/\s+/_/g; lc $_ },
        field_filter => sub {
            $_ = shift;
            if ($_) { s/^\s+|\s+$//g; }
            $_;
        },
    );
    $parser->field_compute( 'feature_aliases',
        sub { [ parse_line( ',', 0, shift() ) ] } );
    $parser->bind_header;

    $self->Print("Parsing file...\n");
    my ( %feature_type_accs, %feature_ids, %map_info );
    my ( $last_map_name, $last_map_id ) = ( '', '' );
    my $feature_index = 0;
    my (@bulk_insert_aliases, @bulk_insert_atts,
        @bulk_insert_xrefs,   @bulk_feature_names
    );

    while ( my $record = $parser->fetchrow_hashref ) {
        for my $field_name ( $parser->field_list ) {
            my $field_attr = $COLUMNS{$field_name} or next;
            my $field_val  = $record->{$field_name};

            if ( $field_attr->{'is_required'}
                && ( !defined $field_val || $field_val eq '' ) )
            {
                return $self->error("Field '$field_name' is required");
            }

            my $datatype = $field_attr->{'datatype'} || '';
            if ( $datatype && defined $field_val && $field_val ne '' ) {
                if ( my $regex = RE_LOOKUP->{$datatype} ) {

                    #
                    # The following line forces the string a numeric
                    # context where it's more likely to succeed in the
                    # regex.  This solves ".4" being bad according to
                    # the regex.
                    #
                    $field_val += 0 if $datatype eq 'number';
                    return $self->error( "Value of '$field_name' is wrong.  "
                            . "Expected $datatype and got '$field_val'." )
                        unless $field_val =~ $regex;
                }
            }
            elsif ( $datatype eq 'number' && $field_val eq '' ) {
                $field_val = undef;
            }
        }

        my $feature_type_acc = $record->{'feature_type_acc'};

        #
        # Not in the database, so ask to create it.
        #
        unless ( $self->feature_type_data($feature_type_acc) ) {
            $self->Print(
                "Feature type accession '$feature_type_acc' doesn't exist.  "
                    . "After import, please add it to your configuration file.[<enter> to continue] "
            );
            chomp( my $answer = <STDIN> );
            exit;
        }

        #
        # Figure out the map id (or create it).
        #
        my ( $map_id, $map_name );
        my $map_acc = $record->{'map_acc'}
            || $record->{'map_accession_id'}
            || '';
        if ($map_acc) {
            $map_name = $map_accs{$map_acc} || '';
        }

        $map_name ||= $record->{'map_name'};
        if ( ( $map_name eq $last_map_name ) && $last_map_id ) {
            $map_id = $last_map_id;
        }
        else {
            if ( exists $maps->{ uc $map_name } ) {
                $map_id = $maps->{ uc $map_name }{'map_id'};
                $maps->{ uc $map_name }{'touched'} = 1;
                $modified_maps{ ( uc $map_name, ) } = 1;
            }

            my $display_order = $record->{'map_display_order'} || 1;
            my $map_start     = $record->{'map_start'}         || 0;
            my $map_stop      = $record->{'map_stop'}          || 0;

            if (   defined $map_start
                && defined $map_stop
                && $map_start > $map_stop )
            {
                ( $map_start, $map_stop ) = ( $map_stop, $map_start );
            }

            #
            # If the map already exists, just remember stuff about it.
            #
            unless ($map_id) {
                $map_id = $sql_object->insert_map(
                    map_acc       => $map_acc,
                    map_set_id    => $map_set_id,
                    map_name      => $map_name,
                    map_start     => $map_start,
                    map_stop      => $map_stop,
                    display_order => $display_order,
                );

                $self->Print("Created map $map_name ($map_id).\n");
                $maps->{ uc $map_name }{'map_id'}  = $map_id;
                $maps->{ uc $map_name }{'touched'} = 1;
                $modified_maps{ ( uc $map_name, ) } = 1;

                $map_info{$map_id}{'map_id'}        ||= $map_id;
                $map_info{$map_id}{'map_set_id'}    ||= $map_set_id;
                $map_info{$map_id}{'map_name'}      ||= $map_name;
                $map_info{$map_id}{'map_start'}     ||= $map_start;
                $map_info{$map_id}{'map_stop'}      ||= $map_stop;
                $map_info{$map_id}{'display_order'} ||= $display_order;
                $map_info{$map_id}{'map_acc'}       ||= $map_acc;

                $last_map_id   = $map_id;
                $last_map_name = $map_name;
            }
        }

        #
        # Basic feature info
        #
        my $feature_name = $record->{'feature_name'}
            or warn "feature name blank! ", Dumper($record), "\n";
        my $feature_acc = $record->{'feature_acc'}
            || $record->{'feature_accession_id'};
        my $aliases      = $record->{'feature_aliases'};
        my $attributes   = $record->{'feature_attributes'} || '';
        my $start        = $record->{'feature_start'};
        my $stop         = $record->{'feature_stop'};
        my $direction    = $record->{'feature_direction'} || 1;
        my $is_landmark  = $record->{'is_landmark'} || 0;
        my $default_rank = $record->{'default_rank'}
            || $self->feature_type_data( $feature_type_acc, 'default_rank' );

        #
        # Feature attributes
        #
        my ( @fattributes, @xrefs );
        if ($attributes) {
            for my $attr ( parse_line( ';', 1, $attributes ) ) {
                my ( $key, $value ) =
                    map { s/^\s+|\s+$//g; s/^"|"$//g; $_ }
                    parse_line( ':', 1, $attr );

                if ( $key =~ /^alias(es)?$/i ) {
                    push @$aliases,
                        map { s/^\s+|\s+$//g; s/\\"/"/g; $_ }
                        parse_line( ',', 1, $value );
                }
                elsif ( $key =~ /^(db)?xref$/i ) {
                    $value =~ s/^"|"$//g;
                    if ( my ( $xref_name, $xref_url ) = split( /;/, $value ) )
                    {
                        push @xrefs, { name => $xref_name, url => $xref_url };
                    }
                }
                else {
                    $value =~ s/\\"/"/g;
                    push @fattributes, { name => $key, value => $value };
                }
            }
        }

        #
        # Backward-compatibility stuff
        #
        if ( my $alt_name = $record->{'feature_alt_name'} ) {
            push @$aliases, $alt_name;
        }

        if ( my $feature_note = $record->{'feature_note'} ) {
            push @fattributes, { name => 'Note', value => $feature_note };
        }

        my $dbxref_name = $record->{'feature_dbxref_name'} || '';
        my $dbxref_url  = $record->{'feature_dbxref_url'}  || '';

        if ( $dbxref_name && $dbxref_url ) {
            push @xrefs, { name => $dbxref_name, url => $dbxref_url };
        }

        #
        # Check start and stop positions, flip if necessary.
        #
        if (   defined $start
            && defined $stop
            && $start ne ''
            && $stop  ne ''
            && $stop < $start )
        {
            ( $start, $stop ) = ( $stop, $start );
            $direction *= -1;
        }

        my $feature_id = '';
        if ($allow_update) {
            if ($feature_acc) {
                my $features_array = $sql_object->get_features_simple(
                    map_id      => $map_id,
                    feature_acc => $feature_acc,
                );
                if (@$features_array) {
                    $feature_id = $features_array->[0]{'feature_id'};
                }
            }

            #
            # If there's no accession ID, see if another feature
            # with the same name exists.
            #
            if ( !$feature_id && !$feature_acc ) {
                my $features_array = $sql_object->get_features_simple(
                    map_id       => $map_id,
                    feature_name => $feature_name,
                );
                if (@$features_array) {
                    $feature_id = $features_array->[0]{'feature_id'};
                }
            }

            my $action = 'Inserted';
            if ($feature_id) {
                $action = 'Updated';
                $sql_object->update_feature(
                    feature_id       => $feature_id,
                    feature_acc      => $feature_acc,
                    map_id           => $map_id,
                    feature_type_acc => $feature_type_acc,
                    feature_name     => $feature_name,
                    feature_start    => $start,
                    feature_stop     => $stop,
                    is_landmark      => $is_landmark,
                    default_rank     => $default_rank,
                    direction        => $direction,
                );

                $maps->{ uc $map_name }{'features'}{$feature_id} = 1
                    if
                    defined $maps->{ uc $map_name }{'features'}{$feature_id};
            }
            else {

                #
                # Create a new feature record.
                #
                $feature_id = $sql_object->insert_feature(
                    feature_acc      => $feature_acc,
                    map_id           => $map_id,
                    feature_type_acc => $feature_type_acc,
                    feature_name     => $feature_name,
                    feature_start    => $start,
                    feature_stop     => $stop,
                    is_landmark      => $is_landmark,
                    default_rank     => $default_rank,
                    direction        => $direction,
                );
            }

            my $pos = join( '-', map { defined $_ ? $_ : () } $start, $stop );
            $self->Print(
                "$action $feature_type_acc '$feature_name' on map $map_name at $pos.\n"
            );

            for my $name (@$aliases) {
                next if $name eq $feature_name;
                $sql_object->insert_feature_alias(
                    feature_id => $feature_id,
                    alias      => $name,
                    )
                    or warn $sql_object->error;
            }

            if (@fattributes) {
                $admin->set_attributes(
                    object_id   => $feature_id,
                    object_type => 'feature',
                    attributes  => \@fattributes,
                    overwrite   => $overwrite,
                    )
                    or return $self->error( $admin->error );
            }

            if (@xrefs) {
                $admin->set_xrefs(
                    object_id   => $feature_id,
                    object_type => 'feature',
                    overwrite   => $overwrite,
                    xrefs       => \@xrefs,
                    )
                    or return $self->error( $admin->error );
            }
        }
        else {

            #
            # Always Create a new feature record
            #

            $feature_id = $sql_object->insert_feature(
                feature_acc      => $feature_acc,
                map_id           => $map_id,
                feature_type_acc => $feature_type_acc,
                feature_name     => $feature_name,
                feature_start    => $start,
                feature_stop     => $stop,
                is_landmark      => $is_landmark,
                default_rank     => $default_rank,
                direction        => $direction,
                threshold        => $max_simultaneous_inserts,
            );

            push @bulk_insert_aliases, $aliases;
            push @bulk_insert_atts,    \@fattributes;
            push @bulk_insert_xrefs,   \@xrefs;
            push @bulk_feature_names,  $feature_name;

            if ( defined($feature_id) ) {
                my $base_feature_id = $feature_id - $feature_index;
                for ( my $i = 0; $i <= $feature_index; $i++ ) {
                    my $current_feature_id = $base_feature_id + $i;
                    for my $name ( @{ $bulk_insert_aliases[$i] } ) {
                        next if $name eq $bulk_feature_names[$i];
                        $sql_object->insert_feature_alias(
                            feature_id => $current_feature_id,
                            alias      => $name,
                            )
                            or warn $sql_object->error;
                    }

                    if ( @{ $bulk_insert_atts[$i] } ) {
                        $admin->set_attributes(
                            object_id   => $current_feature_id,
                            object_type => 'feature',
                            attributes  => $bulk_insert_atts[$i],
                            overwrite   => $overwrite,
                            )
                            or return $self->error( $admin->error );
                    }

                    if ( @{ $bulk_insert_xrefs[$i] } ) {
                        $admin->set_xrefs(
                            object_id   => $current_feature_id,
                            object_type => 'feature',
                            overwrite   => $overwrite,
                            xrefs       => $bulk_insert_xrefs[$i],
                            )
                            or return $self->error( $admin->error );
                    }
                }
                $feature_index       = 0;
                @bulk_insert_aliases = ();
                @bulk_insert_atts    = ();
                @bulk_insert_xrefs   = ();
                @bulk_feature_names  = ();
            }
            else {
                $feature_index++;
            }
        }
    }

    my $feature_id = $sql_object->insert_feature( threshold => 0 );

    if ( defined($feature_id) ) {
        $feature_index--;    # reverse the last ++
        my $base_feature_id = $feature_id - $feature_index;
        for ( my $i = 0; $i <= $feature_index; $i++ ) {
            my $current_feature_id = $base_feature_id + $i;
            for my $name ( @{ $bulk_insert_aliases[$i] } ) {
                next if $name eq $bulk_feature_names[$i];
                $sql_object->insert_feature_alias(
                    feature_id => $current_feature_id,
                    alias      => $name,
                    )
                    or warn $sql_object->error;
            }

            if ( @{ $bulk_insert_atts[$i] } ) {
                $admin->set_attributes(
                    object_id   => $current_feature_id,
                    object_type => 'feature',
                    attributes  => $bulk_insert_atts[$i],
                    overwrite   => $overwrite,
                    )
                    or return $self->error( $admin->error );
            }

            if ( @{ $bulk_insert_xrefs[$i] } ) {
                $admin->set_xrefs(
                    object_id   => $current_feature_id,
                    object_type => 'feature',
                    overwrite   => $overwrite,
                    xrefs       => $bulk_insert_xrefs[$i],
                    )
                    or return $self->error( $admin->error );
            }
        }
        $feature_index       = 0;
        @bulk_insert_aliases = ();
        @bulk_insert_atts    = ();
        @bulk_insert_xrefs   = ();
    }

    #
    # Go through and update all the maps.
    #
    for my $map ( values %map_info ) {
        $sql_object->update_map(
            map_id        => $map->{'map_id'},
            map_acc       => $map->{'map_acc'},
            map_set_id    => $map->{'map_set_id'},
            map_name      => $map->{'map_name'},
            map_start     => $map->{'map_start'},
            map_stop      => $map->{'map_stop'},
            display_order => $map->{'display_order'},
        );
        $self->Print("Updated map $map->{'map_name'} ($map->{'map_id'}).\n");
    }

    #
    # Go through existing maps and features, delete any that weren't
    # updated, if necessary.
    #
    if ($overwrite) {
        for my $map_name ( sort keys %$maps ) {
            my $map_id = $maps->{ uc $map_name }{'map_id'}
                or return $self->error("Map '$map_name' has no ID!");

            unless ( $maps->{ uc $map_name }{'touched'} ) {
                $self->Print( "Map '$map_name' ($map_id) ",
                    "wasn't updated or inserted, so deleting\n" );
                $admin->map_delete( map_id => $map_id )
                    or return $self->error( $admin->error );
                delete $maps->{ uc $map_name };
                next;
            }

            while ( my ( $feature_id, $touched )
                = each %{ $maps->{ uc $map_name }{'features'} } )
            {
                next if $touched;
                $self->Print( "Feature '$feature_id' ",
                    "wasn't updated or inserted, so deleting\n" );
                $admin->feature_delete( feature_id => $feature_id )
                    or return $self->error( $admin->error );
            }
        }
    }

    #
    # Make sure the maps have legitimate starts and stops.
    #
    for my $map_name ( sort keys %modified_maps ) {
        my $map_id = $maps->{$map_name}{'map_id'};
        $admin->validate_update_map_start_stop($map_id);

        $self->Print( "Verified map $map_name ($map_id).\n" );
    }

    $self->Print("Done\n");

    return 1;
}

# ----------------------------------------------------

sub validate_tab_file {

=pod

=head2 validate_tab_file

=head3 For External Use

=over 4

=item * Description

Checks a tab-delimited file to make sure it can be imported using the following
columns.

    map_name *
    map_acc
    map_display_order
    map_start
    map_stop
    feature_name *
    feature_alt_name +
    feature_acc
    feature_aliases
    feature_start *
    feature_stop
    feature_direction
    feature_type_acc *
    feature_note +
    is_landmark
    feature_dbxref_name +
    feature_dbxref_url +
    feature_attributes

Fields with an asterisk are required.  Order of fields is not important.

Fields with a plus sign are deprecated.

If a feature_type_acc is found that is not in the config file, the user 
will be alerted and this will return false.


=item * Usage

    $importer->validate_tab_file(
        fh => $fh,
        log_fh => $log_fh,
    );

=item * Returns

1

=item * Fields

=over 4

=item - fh

File handle of the input file.

=item - log_fh

File handle of the log file (default is STDOUT).

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $fh = $args{'fh'} or die 'No file handle';
    $LOG_FH = $args{'log_fh'} || \*STDOUT;

    my $valid = 1;

    #
    # Make column names lowercase, convert spaces to underscores
    # (e.g., make "Feature Name" => "feature_name").
    #
    my $parser = Text::RecordParser->new(
        fh              => $fh,
        field_separator => FIELD_SEP,
        header_filter   => sub { $_ = shift; s/\s+/_/g; lc $_ },
        field_filter => sub {
            $_ = shift;
            if ($_) { s/^\s+|\s+$//g; }
            $_;
        },
    );
    $parser->field_compute( 'feature_aliases',
        sub { [ parse_line( ',', 0, shift() ) ] } );
    $parser->bind_header;

    my %required =
        map { $_, 0 }
        grep { $COLUMNS{$_}{'is_required'} }
        keys %COLUMNS;

    for my $column_name ( $parser->field_list ) {
        if ( exists $COLUMNS{$column_name} ) {
            $required{$column_name} = 1
                if defined $required{$column_name};
        }
        else {
            $valid = 0;
            print $LOG_FH "Column name '$column_name' is not valid.\n";
        }
    }

    if (my @missing =
        grep { $required{$_} == 0 } keys %required
        )
    {
        $valid = 0;
        print $LOG_FH "Missing following required columns: "
            . join( ', ', @missing );
    }

    return 0 unless ( $required{'feature_type_acc'} );

    my (%feature_type_accs);
    while ( my $record = $parser->fetchrow_hashref ) {
        $feature_type_accs{ $record->{'feature_type_acc'} } = 1;
    }

    foreach my $ft_acc ( keys(%feature_type_accs) ) {
        unless ( $self->feature_type_data($ft_acc) ) {
            $valid = 0;
            print $LOG_FH
                "You must define a feature type with the accession id, '"
                . $ft_acc . "'.\n";
        }
    }

    return $valid;
}

# ----------------------------------------------------
sub import_objects {

=pod

=head2 import_objects

=head3 For External Use

=over 4

=item * Description

Imports an XML document containing CMap database objects.
Not guaranteed to work.

=item * Usage

    $importer->import_objects(
        overwrite => $overwrite,
        fh => $fh,
        log_fh => $log_fh,
    );

=item * Returns

1

=item * Fields

=over 4

=item - overwrite

Set to 1 to delete and re-add the data if overwriting. 
Otherwise will just add.

=item - fh

File handle of the input file.

=item - log_fh

File handle of the log file (default is STDOUT).

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $sql_object = $self->sql  or die 'No database handle';
    my $fh         = $args{'fh'} or die 'No file handle';
    my $overwrite = $args{'overwrite'} || 0;
    $LOG_FH = $args{'log_fh'} || \*STDOUT;

    my $admin = Bio::GMOD::CMap::Admin->new(
        config      => $self->config,
        data_source => $self->data_source
        )
        or return $self->error( "Can't create admin object: ",
        Bio::GMOD::CMap::Admin->error );

    my $import = XMLin(
        $fh,
        KeepRoot      => 0,
        SuppressEmpty => 1,
        ForceArray    => [
            qw(
                cmap_map_set map feature xref attribute
                cmap_species feature_alias
                cmap_feature_correspondence cmap_xref correspondence_evidence
                )
        ],
    );

    #
    # Species.
    #
    my %species;
    for my $species ( @{ $import->{'cmap_species'} || [] } ) {
        my $species_id = $species->{'object_id'} || $species->{'species_id'};

        $self->import_object(
            overwrite   => $overwrite,
            object_type => 'species',
            object      => $species,
            )
            or return;

        $species{$species_id} = $species;
    }

    #
    # Map sets, maps, features
    #
    my %feature_ids;
    for my $ms ( @{ $import->{'cmap_map_set'} || [] } ) {

        $self->Print("Importing map set '$ms->{map_set_name}'\n");

        my $species      = $species{ $ms->{'species_id'} };
        my $map_type_acc = $ms->{'map_type_acc'};
        $ms->{'species_id'} = $species->{'new_species_id'}
            or return $self->error('Cannot determine species id');

        $self->import_object(
            overwrite   => $overwrite,
            object_type => 'map_set',
            object      => $ms,
            )
            or return;

        for my $map ( @{ $ms->{'map'} || [] } ) {
            $map->{'map_set_id'} = $ms->{'new_map_set_id'};
            $self->import_object(
                overwrite   => $overwrite,
                object_type => 'map',
                object      => $map,
                )
                or return;

            for my $feature ( @{ $map->{'feature'} || [] } ) {
                $feature->{'map_id'} = $map->{'new_map_id'};
                $self->import_object(
                    overwrite   => $overwrite,
                    object_type => 'feature',
                    object      => $feature,
                    )
                    or return;
                my $feature_id = $feature->{'object_id'}
                    || $feature->{'feature_id'};

                $feature_ids{$feature_id} = $feature->{'new_feature_id'};

                for my $alias ( @{ $feature->{'feature_alias'} || [] } ) {
                    $alias->{'feature_id'} = $feature->{'new_feature_id'};
                    $self->import_object(
                        overwrite   => $overwrite,
                        object_type => 'feature_alias',
                        object      => $alias,
                        lookup_acc  => 0,
                        )
                        or return;
                }
            }
        }
    }

    #
    # Feature correspondences
    #
    for my $fc ( @{ $import->{'cmap_feature_correspondence'} || [] } ) {
        $fc->{'feature_id1'} = $feature_ids{ $fc->{'feature_id1'} };
        $fc->{'feature_id2'} = $feature_ids{ $fc->{'feature_id2'} };

        $self->import_object(
            object_type => 'feature_correspondence',
            object      => $fc,
            )
            or return $self->error;
    }

    #
    # Cross-references
    #
    for my $xref ( @{ $import->{'cmap_xref'} || [] } ) {
        $self->import_object(
            object_type => 'xref',
            object      => $xref,
            lookup_acc  => 0,
            )
            or return;
    }

    return 1;
}

# ----------------------------------------------------
sub import_object {

=pod

=head2 import_object

=head3 NOT For External Use

=over 4

=item * Description

Imports an object.

=item * Usage

    $importer->import_object(
        object => $object,
        object_type => $object_type,
    );

=item * Returns

1

=item * Fields

=over 4

=item - object

=item - object_type

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $object_type = $args{'object_type'};
    my $object      = $args{'object'} || {};
    my $lookup_acc  =
        defined $args{'lookup_acc'}
        ? $args{'lookup_acc'}
        : 1;

    my $sql_object = $self->sql;
    my $pk_name    = $sql_object->pk_name($object_type);
    my $admin      = $self->admin;

    my $new_object_id;

    if ($lookup_acc) {
        $new_object_id = $sql_object->acc_id_to_internal_id(
            acc_id => $object->{ $object_type . "_acc" }
                || $object->{"accession_id"},
            object_type => $object_type,
        );
    }

    if ( $new_object_id && $args{'overwrite'} ) {
        $self->Print("Updating $object_type\n");
        my $update_method = 'update_' . $object_type;
        $object->{$pk_name} = $new_object_id;
        $sql_object->$update_method(
            no_validation => 1,
            %$object,
            )
            or return $sql_object->error( $admin->error );
    }
    elsif ( !$new_object_id ) {
        $self->Print("Creating new data in $object_type\n");
        my $create_method = 'insert_' . $object_type;
        $new_object_id = $sql_object->$create_method(
            no_validation => 1,
            %$object,
            )
            or return $self->error( $sql_object->error );
    }

    $object->{"new_$pk_name"} = $new_object_id;

    if ( @{ $object->{'attribute'} || [] } ) {
        $admin->set_attributes(
            object_type => $object_type,
            object_id   => $new_object_id,
            attributes  => $object->{'attribute'},
        );
    }

    if ( @{ $object->{'xref'} || [] } ) {
        $admin->set_xrefs(
            object_type => $object_type,
            object_id   => $new_object_id,
            xrefs       => $object->{'xref'},
        );
    }

    return 1;
}

# ----------------------------------------------------
sub Print {

=pod

=head2 Print

=head3 NOT For External Use

=over 4

=item * Description

Prints to log file.

=item * Usage

    $importer->Print();

=item * Returns

nothing

=back

=cut

    my $self = shift;
    print $LOG_FH @_;
}

# ----------------------------------------------------
sub admin {

=pod

=head2 admin

=head3 NOT For External Use

=over 4

=item * Description

Creates or retrieves Admin object for internal use.

=item * Usage

    $importer->admin();

=item * Returns

Bio::GMOD::CMap::Admin object

=back

=cut

    my $self = shift;

    unless ( defined $self->{'admin'} ) {
        $self->{'admin'} = Bio::GMOD::CMap::Admin->new(
            config      => $self->config,
            data_source => $self->data_source
            )
            or return $self->error( "Can't create admin object: ",
            Bio::GMOD::CMap::Admin->error );
    }

    return $self->{'admin'};
}

1;

# ----------------------------------------------------
# Which way does your beard point tonight?
# Allen Ginsberg
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.
Ken Y. Clark E<lt>kclark@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-7 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

