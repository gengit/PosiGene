package Bio::GMOD::CMap::Admin::GFFProducer;

# vim: set ft=perl:

# $Id: GFFProducer.pm,v 1.5 2008/06/28 19:49:43 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Admin::GFFProducer - import alignments such as BLAST

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Admin::GFFProducer;
  my $gff_producer = Bio::GMOD::CMap::Admin::GFFProducer->new;
  $gff_producer->export() or return $gff_producer->error;

=head1 DESCRIPTION

This module encapsulates the logic for exporting the cmap data in GFF3 format
(cmap-gff-version 1).

=head1 Notes

The module currently (May 2008) only outputs attributes for the four major
objects (species, map set, map and feature).  It will also output attributes
for those four objects that don't have IDs but this is not supported by either
the database or the import module.

=cut

use strict;
use vars qw( $VERSION %COLUMNS $LOG_FH );
$VERSION = (qw$Revision: 1.5 $)[-1];

use Data::Dumper;
use Bio::GMOD::CMap;
use URI::Escape;

use base 'Bio::GMOD::CMap::Admin';
use constant NO_ID => 'no_id';

# ----------------------------------------------

=pod

=head2 export

=cut

sub export {
    my ( $self, %args ) = @_;

    # my $map_set_ids = $args{'map_set_ids'};
    my $output_file             = $args{'output_file'}             || '-';
    my $map_ids                 = $args{'map_ids'}                 || [];
    my $map_set_ids             = $args{'map_set_ids'}             || [];
    my $species_ids             = $args{'species_ids'}             || [];
    my $map_accs                = $args{'map_accs'}                || [];
    my $map_set_accs            = $args{'map_set_accs'}            || [];
    my $species_accs            = $args{'species_accs'}            || [];
    my $export_only_corrs       = $args{'export_only_corrs'}       || 0;
    my $ignore_unit_granularity = $args{'ignore_unit_granularity'} || 0;

    if (@$map_accs) {
        $map_ids = [
            map {
                $self->sql->acc_id_to_internal_id(
                    acc_id      => $_,
                    object_type => 'map',
                );
                } @$map_accs
        ];
    }
    if (@$map_set_accs) {
        $map_set_ids = [
            map {
                $self->sql->acc_id_to_internal_id(
                    acc_id      => $_,
                    object_type => 'map_set',
                );
                } @$map_set_accs
        ];
    }
    if (@$species_accs) {
        $species_ids = [
            map {
                $self->sql->acc_id_to_internal_id(
                    acc_id      => $_,
                    object_type => 'species',
                );
                } @$species_accs
        ];
    }

    $self->ignore_unit_granularity($ignore_unit_granularity);

    $self->set_object_limits(
        map_ids     => $map_ids,
        map_set_ids => $map_set_ids,
        species_ids => $species_ids,
    );

    $self->file_handle($output_file);
    $self->write_header();
    $self->preextract_attributes() unless ($export_only_corrs);
    $self->preextract_xrefs()      unless ($export_only_corrs);
    $self->export_species( export_only_corrs => $export_only_corrs, );
    $self->export_extras()
        unless ( @$map_ids
        or @$map_set_ids
        or @$species_ids
        or $export_only_corrs );

    return 1;
}

# ----------------------------------------------

=pod

=head2 set_object_limits

=cut

sub set_object_limits {
    my ( $self, %args ) = @_;
    my $map_ids     = $args{'map_ids'}     || [];
    my $map_set_ids = $args{'map_set_ids'} || [];
    my $species_ids = $args{'species_ids'} || [];

    $self->{'species_id_hash'} = {};
    $self->{'map_set_id_hash'} = {};
    $self->{'map_id_hash'}     = {};

    if (@$map_ids) {
        my $map_data = $self->sql->get_maps( map_ids => $map_ids, );
        foreach my $map ( @{ $map_data || [] } ) {
            $self->{'map_id_hash'}{ $map->{'map_id'} }         = 1;
            $self->{'map_set_id_hash'}{ $map->{'map_set_id'} } = 1;
            $self->{'species_id_hash'}{ $map->{'species_id'} } = 1;
        }
    }
    if (@$map_set_ids) {
        my $map_set_data
            = $self->sql->get_map_sets( map_set_ids => $map_set_ids, );
        foreach my $map_set ( @{ $map_set_data || [] } ) {
            $self->{'map_set_id_hash'}{ $map_set->{'map_set_id'} } = 1;
            $self->{'species_id_hash'}{ $map_set->{'species_id'} } = 1;
        }
    }
    if (@$species_ids) {
        my $species_data
            = $self->sql->get_species( species_ids => $species_ids, );
        foreach my $species ( @{ $species_data || [] } ) {
            $self->{'species_id_hash'}{ $species->{'species_id'} } = 1;
        }
    }
}

# ----------------------------------------------

=pod

=head2 write_header

=cut

sub write_header {
    my ( $self, %args ) = @_;

    my $fh = $self->file_handle();
    print $fh "##gff-version 3\n";
    print $fh "##cmap-gff-version 1\n";
    print $fh
        "# This file was produced from a CMap database using Bio::GMOD::CMap::Admin::GFFProducer\n";

}

# ----------------------------------------------

=pod

=head2 preextract_attributes

=cut

sub preextract_attributes {
    my $self = shift;
    unless ( $self->{'attributes'} ) {
        my $all_attributes = $self->sql()->get_attributes( get_all => 1, );

        foreach my $attr ( @{ $all_attributes || [] } ) {

            # Store attributes that have ids by their type and id.
            if ( $attr->{'object_id'} ) {
                push @{ $self->{'attributes'}{ $attr->{'object_type'} }
                        { $attr->{'object_id'} } }, $attr;
            }
            elsif ( $attr->{'object_type'} ) {
                push @{ $self->{'attributes'}{ $attr->{'object_type'} }
                        {NO_ID} }, $attr;
            }
        }
    }
}

# ----------------------------------------------

=pod

=head2 preextract_xrefs

=cut

sub preextract_xrefs {
    my $self = shift;
    unless ( $self->{'xrefs'} ) {
        my $all_xrefs = $self->sql()->get_xrefs();

        foreach my $xref ( @{ $all_xrefs || [] } ) {

            # Store xrefs that have ids by their type and id.
            if ( $xref->{'object_id'} ) {
                push @{ $self->{'xrefs'}{ $xref->{'object_type'} }
                        { $xref->{'object_id'} } }, $xref;
            }
            elsif ( $xref->{'object_type'} ) {
                push @{ $self->{'xrefs'}{ $xref->{'object_type'} }{NO_ID} },
                    $xref;
            }
        }
    }
}

# ----------------------------------------------

=pod

=head2 attributes_of_type

=cut

sub attributes_of_type {
    my $self = shift;
    my $type = shift;
    return $self->{'attributes'}{$type};
}

# ----------------------------------------------

=pod

=head2 xrefs_of_type

=cut

sub xrefs_of_type {
    my $self = shift;
    my $type = shift;
    return $self->{'xrefs'}{$type};
}

# ----------------------------------------------

=pod

=head2 export_remaining_attributes

Export remaining attributes

right now it only outputs attributes for objects that didn't have ids associated
with them.

=cut

sub export_remaining_attributes {
    my $self                  = shift;
    my %exported_with_objects = (
        species => 1,
        map_set => 1,
        map     => 1,
        feature => 1,
    );

    foreach my $object_type ( keys %{ $self->{'attributes'} || {} } ) {
        $self->write_attributes(
            attributes => $self->{'attributes'}{$object_type}{NO_ID}, );
    }

    return 1;
}

# ----------------------------------------------

=pod

=head2 export_remaining_xrefs

Export remaining xrefs 

right now it only outputs xrefs for objects that didn't have ids associated
with them.

=cut

sub export_remaining_xrefs {
    my $self                  = shift;
    my %exported_with_objects = (
        species => 1,
        map_set => 1,
        map     => 1,
        feature => 1,
    );

    foreach my $object_type ( keys %{ $self->{'xrefs'} || {} } ) {
        $self->write_xrefs( xrefs => $self->{'xrefs'}{$object_type}{NO_ID}, );
    }

    return 1;
}

# ----------------------------------------------

=pod

=head2 export_extras

Export remaining attributes and xrefs

=cut

sub export_extras {
    my ( $self, %args ) = @_;

    #$self->export_remaining_attributes();
    #$self->export_remaining_xrefs();

    return 1;
}

# ----------------------------------------------

=pod

=head2 export_species

=cut

sub export_species {
    my ( $self, %args ) = @_;
    my $export_only_corrs = $args{'export_only_corrs'};

    my @species_ids = keys %{ $self->{'species_id_hash'} || {} };
    my $species_list
        = $self->sql->get_species( species_ids => \@species_ids, );

    unless ( @{ $species_list || [] } ) {
        print STDERR "WARNING - No Species in the database.\n";
    }

    my $all_species_attributes = $self->attributes_of_type('species');
    my $all_species_xrefs      = $self->xrefs_of_type('species');
    foreach my $species_data ( @{ $species_list || [] } ) {
        my $species_id = $species_data->{'species_id'};
        $self->write_species(
            species_data => $species_data,
            attributes   => $all_species_attributes->{$species_id},
            xrefs        => $all_species_xrefs->{$species_id},
        ) unless ($export_only_corrs);
        $self->export_map_sets(
            species_id        => $species_data->{'species_id'},
            export_only_corrs => $export_only_corrs,
        );
    }

    return 1;
}

# ----------------------------------------------

=pod

=head2 export_map_sets

=cut

sub export_map_sets {
    my ( $self, %args ) = @_;
    my $species_id        = $args{'species_id'};
    my $export_only_corrs = $args{'export_only_corrs'};

    my @map_set_ids = keys %{ $self->{'map_set_id_hash'} || {} };
    my $map_set_list = $self->sql->get_map_sets(
        species_id  => $species_id,
        map_set_ids => \@map_set_ids,
    );

    my $all_map_set_attributes = $self->attributes_of_type('map_set');
    my $all_map_set_xrefs      = $self->xrefs_of_type('map_set');
    foreach my $map_set_data ( @{ $map_set_list || [] } ) {
        my $map_set_id = $map_set_data->{'map_set_id'};
        $self->write_map_set(
            map_set_data => $map_set_data,
            attributes   => $all_map_set_attributes->{$map_set_id},
            xrefs        => $all_map_set_xrefs->{$map_set_id},
        ) unless ($export_only_corrs);
        $self->export_maps(
            map_set_id        => $map_set_data->{'map_set_id'},
            export_only_corrs => $export_only_corrs,
        );
    }

    return 1;
}

# ----------------------------------------------

=pod

=head2 export_maps

=cut

sub export_maps {
    my ( $self, %args ) = @_;
    my $map_set_id        = $args{'map_set_id'};
    my $export_only_corrs = $args{'export_only_corrs'};

    my @map_ids = keys %{ $self->{'map_id_hash'} || {} };
    my $map_list = $self->sql->get_maps(
        map_set_id => $map_set_id,
        map_ids    => \@map_ids,
    );
    return unless ( @{ $map_list || [] } );

    my $map_type_acc     = $map_list->[0]{'map_type_acc'};
    my $unit_granularity = $self->unit_granularity($map_type_acc);

    my $all_map_attributes = $self->attributes_of_type('map');
    my $all_map_xrefs      = $self->xrefs_of_type('map');
    foreach my $map_data ( @{ $map_list || [] } ) {
        my $map_id = $map_data->{'map_id'};
        $self->write_map(
            map_data         => $map_data,
            unit_granularity => $unit_granularity,
            attributes       => $all_map_attributes->{$map_id},
            xrefs            => $all_map_xrefs->{$map_id},
        ) unless ($export_only_corrs);
        $self->export_features(
            map_id            => $map_data->{'map_id'},
            export_only_corrs => $export_only_corrs,
            unit_granularity  => $unit_granularity,
        );
    }

    return 1;
}

# ----------------------------------------------

=pod

=head2 export_features

=cut

sub export_features {
    my ( $self, %args ) = @_;
    my $map_id            = $args{'map_id'};
    my $unit_granularity  = $args{'unit_granularity'};
    my $export_only_corrs = $args{'export_only_corrs'};

    my $feature_list = $self->sql->get_features( map_id => $map_id, );
    return unless ( @{ $feature_list || [] } );

    # Get Corrs for all features on this map
    my $correspondence_list = $self->sql->get_feature_correspondence_details(
        map_id1                 => $map_id,
        disregard_evidence_type => 1,
        unordered               => 1
    );

    my %corrs_by_feature_id;
    my $species_id_hash = $self->{'species_id_hash'};
    my $map_set_id_hash = $self->{'map_set_id_hash'};
    my $map_id_hash     = $self->{'map_id_hash'};
    foreach my $corr_data ( @{ $correspondence_list || [] } ) {

        # Make sure the corr to a feature being reported
        if ((   %$species_id_hash
                and not $species_id_hash->{ $corr_data->{'species_id2'} }
            )
            or ( %$map_set_id_hash
                and not $map_set_id_hash->{ $corr_data->{'map_set_id2'} } )
            or ( %$map_id_hash
                and not $map_id_hash->{ $corr_data->{'map_id2'} } )
            )
        {
            next;
        }

        push @{ $corrs_by_feature_id{ $corr_data->{'feature_id1'} } },
            $corr_data;
    }
    unless ($unit_granularity) {
        my $map_type_acc = $feature_list->[0]{'map_type_acc'};
        $unit_granularity = $self->unit_granularity($map_type_acc);
    }

    my $all_feature_attributes = $self->attributes_of_type('feature');
    my $all_feature_xrefs      = $self->xrefs_of_type('feature');
    foreach my $feature_data ( @{ $feature_list || [] } ) {
        my $feature_id = $feature_data->{'feature_id'};
        if ($export_only_corrs) {
            $self->write_correspondences(
                feature_data1   => $feature_data,
                correspondences => $corrs_by_feature_id{$feature_id},
                file_handle     => $self->file_handle(),
            );
        }
        else {
            $self->write_feature(
                feature_data     => $feature_data,
                correspondences  => $corrs_by_feature_id{$feature_id},
                attributes       => $all_feature_attributes->{$feature_id},
                xrefs            => $all_feature_xrefs->{$feature_id},
                unit_granularity => $unit_granularity,
                file_handle      => $self->file_handle(),
            );
        }
    }

    return 1;
}

# ----------------------------------------------

=pod

=head2 write_generic_pragma

=cut

sub write_generic_pragma {
    my ( $self, %args ) = @_;
    my $data        = $args{'data'};
    my $pragma_name = $args{'pragma_name'};
    my $acc_name    = $args{'acc_name'};
    my $param_list  = $args{'param_list'} || [];

    my $fh = $self->file_handle();

   # If the accession is a number, then it is not an external accession and is
   # not worth keeping.
    if ( $data->{$acc_name} =~ /^\d+$/ ) {
        $data->{$acc_name} = undef;
    }

    my $pragma_string = "##" . $pragma_name . "\t";

    # Create a key=value pair for each defined param and separate them with a
    # semi-colon
    $pragma_string .= join(
        ";",
        (   map {
                defined( $data->{$_} )
                    ? $_ . "=" . uri_escape( $data->{$_} )
                    : ()
                } @$param_list
        )
    );
    $pragma_string .= "\n";

    print $fh $pragma_string;

    return 1;
}

# ----------------------------------------------

=pod

=head2 write_species

=cut

sub write_species {
    my ( $self, %args ) = @_;
    my $species_data = $args{'species_data'};
    my $attributes   = $args{'attributes'};
    my $xrefs        = $args{'xrefs'};

    my @species_params = qw(
        species_acc
        species_common_name
        species_full_name
        display_order
    );

    my $fh = $self->file_handle();
    print $fh "\n";
    $self->write_generic_pragma(
        data        => $species_data,
        param_list  => \@species_params,
        acc_name    => 'species_acc',
        pragma_name => 'cmap_species',
    );

    my $id_string = $self->build_species_id_string($species_data);
    $self->write_attributes(
        attributes => $attributes,
        id_string  => $id_string,
    );
    $self->write_xrefs( xrefs => $xrefs, id_string => $id_string, );

    return 1;
}

# ----------------------------------------------

=pod

=head2 write_map_set

=cut

sub write_map_set {
    my ( $self, %args ) = @_;
    my $map_set_data = $args{'map_set_data'};
    my $attributes   = $args{'attributes'};
    my $xrefs        = $args{'xrefs'};

    # Set the unit_modifier
    $map_set_data->{'unit_modifier'}
        = $self->unit_granularity( $map_set_data->{'map_type_acc'} );

    my @map_set_params = qw(
        map_set_name
        map_set_short_name
        map_type_acc
        map_set_acc
        display_order
        shape
        color
        width
        published_on
        unit_modifier
    );

    # Print the ### before the map set to make sure the previous features are
    # cleared.
    my $fh = $self->file_handle();
    print $fh "\n###\n";

    $self->write_generic_pragma(
        data        => $map_set_data,
        param_list  => \@map_set_params,
        acc_name    => 'map_set_acc',
        pragma_name => 'cmap_map_set',
    );

    my $id_string = $self->build_map_set_id_string($map_set_data);
    $self->write_attributes(
        attributes => $attributes,
        id_string  => $id_string,
    );
    $self->write_xrefs( xrefs => $xrefs, id_string => $id_string, );

    return 1;
}

# ----------------------------------------------

=pod

=head2 write_map

=cut

sub write_map {
    my ( $self, %args ) = @_;
    my $map_data         = $args{'map_data'};
    my $unit_granularity = $args{'unit_granularity'};
    my $attributes       = $args{'attributes'};
    my $xrefs            = $args{'xrefs'};

    my @map_params = qw(
        map_acc
        map_name
        map_start
        map_stop
        display_order
    );

    if ( $unit_granularity != 1 ) {
        $map_data->{'map_start'}
            = int( $map_data->{'map_start'} / $unit_granularity );
        $map_data->{'map_stop'}
            = int( $map_data->{'map_stop'} / $unit_granularity );
    }

    $self->write_generic_pragma(
        data        => $map_data,
        param_list  => \@map_params,
        acc_name    => 'map_acc',
        pragma_name => 'cmap_map',
    );

    # A map also needs a sequence-region pragma to be viewed in GBrowse
    my $fh = $self->file_handle();
    print $fh "##sequence-region\t"
        . uri_escape( $map_data->{'map_name'} ) . "\t"
        . $map_data->{'map_start'} . "\t"
        . $map_data->{'map_stop'} . "\n";

    my $id_string = $self->build_map_id_string($map_data);
    $self->write_attributes(
        attributes => $attributes,
        id_string  => $id_string,
    );
    $self->write_xrefs( xrefs => $xrefs, id_string => $id_string, );

    return 1;
}

# ----------------------------------------------

=pod

=head2 write_feature

=cut

sub write_feature {
    my ( $self, %args ) = @_;
    my $feature_data     = $args{'feature_data'};
    my $correspondences  = $args{'correspondences'};
    my $attributes       = $args{'attributes'};
    my $xrefs            = $args{'xrefs'};
    my $unit_granularity = $args{'unit_granularity'};
    my $fh               = $args{'file_handle'};

    my $feature_type_acc = $feature_data->{'feature_type_acc'};
    my $feature_id       = $feature_data->{'feature_id'};

    my $seq_id = uri_escape( $feature_data->{'map_name'} );
    my $source
        = uri_escape(
        $self->feature_type_data( $feature_type_acc, 'gbrowse_source' )
            || "CMap" );
    my $type = $self->feature_type_data( $feature_type_acc, 'gbrowse_type' )
        || $feature_type_acc;
    my $start = $feature_data->{'feature_start'};
    my $stop  = $feature_data->{'feature_stop'};
    if ( $unit_granularity != 1 ) {
        $start = int( $start / $unit_granularity );
        $stop  = int( $stop / $unit_granularity );
    }
    my $score   = ".";
    my $strand  = $feature_data->{'direction'} == -1 ? "-" : "+";
    my $phase   = ".";
    my $column9 = '';

    # Fill Column 9
    $column9 .= "ID="
        . $self->create_load_id(
        type_acc => $feature_type_acc,
        id       => $feature_id,
        ) . ";";
    $column9 .= "Name=" . uri_escape( $feature_data->{'feature_name'} );

    # Aliases
    foreach my $alias ( @{ $feature_data->{'aliases'} || [] } ) {
        $column9 .= ";Alias=" . uri_escape($alias);
    }

    # Correspondences
    foreach my $corr_data ( @{ $correspondences || [] } ) {
        $column9 .= ";corr_by_id="
            . $self->create_load_id(
            type_acc => $corr_data->{'feature_type_acc2'},
            id       => $corr_data->{'feature_id2'},
            )
            . " "
            . $corr_data->{'evidence_type_acc'};
        if ( $corr_data->{'score'} ) {
            $column9 .= " " . uri_escape( $corr_data->{'score'} );
        }
    }

    # Attributes
    foreach my $attr ( @{ $attributes || [] } ) {
        $column9
            .= ";attribute="
            . uri_escape( $attr->{'attribute_name'} ) . ":"
            . uri_escape( $attr->{'attribute_value'} );
    }
    foreach my $xref ( @{ $xrefs || [] } ) {
        $column9
            .= ";xref="
            . uri_escape( $xref->{'xref_name'} ) . ":"
            . uri_escape( $xref->{'xref_value'} );
    }

    # A map also needs a sequence-region pragma to be viewed in GBrowse
    print $fh join(
        "\t",
        (   $seq_id, $source, $type,  $start, $stop,
            $score,  $strand, $phase, $column9,
        )
    ) . "\n";
    return 1;
}

# ----------------------------------------------

=pod

=head2 write_correspondences

=cut

sub write_correspondences {
    my ( $self, %args ) = @_;
    my $feature_data1   = $args{'feature_data1'};
    my $correspondences = $args{'correspondences'};
    my $fh              = $args{'file_handle'};

    my $id_string1
        = $self->build_correspondence_id_string_feature1($feature_data1);

    # Correspondences
    foreach my $corr_data ( @{ $correspondences || [] } ) {
        my $key1 = $feature_data1->{'feature_id'} . "-"
            . $corr_data->{'feature_id2'};
        my $key2 = $corr_data->{'feature_id2'} . "-"
            . $feature_data1->{'feature_id'};
        if ( $self->{'wrote_corr'}{$key1} ) {
            next;
        }
        $self->{'wrote_corr'}{$key1} = 1;
        $self->{'wrote_corr'}{$key2} = 1;

        my $id_string2
            = $self->build_correspondence_id_string_feature2($corr_data);
        my $id_string = $id_string1 . ";" . $id_string2;
        $id_string .= ';evidence_type_acc='
            . uri_escape( $corr_data->{'evidence_type_acc'} );
        if ( $corr_data->{'score'} ) {
            $id_string .= ';score=' . uri_escape( $corr_data->{'score'} );
        }
        print $fh "##cmap_correspondence\t$id_string\n";
    }

    return 1;
}

# ----------------------------------------------

=pod

=head2 write_attributes

=cut

sub write_attributes {

    my ( $self, %args ) = @_;
    my $attributes = $args{'attributes'};
    my $id_string  = $args{'id_string'};

    my $fh = $self->file_handle();

    my @attribute_params = qw(
        object_type
        attribute_name
        attribute_value
        display_order
        is_public
    );

    foreach my $attr ( @{ $attributes || [] } ) {
        my $attr_str = "##cmap_attribute\t";

        foreach my $param (@attribute_params) {
            $attr_str
                .= uri_escape($param) . "="
                . uri_escape( $attr->{$param} ) . ";"
                if ( defined $attr->{$param} );
        }
        $attr_str .= $id_string;
        print $fh "$attr_str\n";

    }

    return 1;
}

# ----------------------------------------------

=pod

=head2 write_xrefs

=cut

sub write_xrefs {

    my ( $self, %args ) = @_;
    my $xrefs     = $args{'xrefs'};
    my $id_string = $args{'id_string'};

    my $fh = $self->file_handle();

    my @xref_params = qw(
        object_type
        xref_name
        xref_url
        display_order
        is_public
    );

    foreach my $xref ( @{ $xrefs || [] } ) {
        my $xref_str = "##cmap_xref\t";

        foreach my $param (@xref_params) {
            $xref_str
                .= uri_escape($param) . "="
                . uri_escape( $xref->{$param} ) . ";"
                if ( defined $xref->{$param} );
        }
        $xref_str .= $id_string;
        print $fh "$xref_str\n";

    }

    return 1;
}

# ----------------------------------------------

=pod

=head2 build_generic_id_string

Return a list:

 ($id_string, $finished)

where $finished lets the caller that an accession was used.

=cut

sub build_generic_id_string {
    my ( $self, %args ) = @_;
    my $data               = $args{'data'};
    my $acc_name           = $args{'acc_name'};
    my $identifying_params = $args{'identifying_params'} || [];

    if ( $data->{$acc_name} !~ /^\d+$/ ) {
        return ( $acc_name . "=" . $data->{$acc_name}, 1 );
    }

    my $id_string
        = join( ";", map { $_ . "=" . $data->{$_} } @$identifying_params );

    return ( $id_string, 0 );
}

# ----------------------------------------------

=pod

=head2 build_species_id_string

=cut

sub build_species_id_string {
    my $self = shift;
    my $data = shift;

    my ( $id_str, $finished ) = $self->build_generic_id_string(
        data               => $data,
        acc_name           => 'species_acc',
        identifying_params => [ 'species_common_name', 'species_full_name', ],
    );
    return $id_str;
}

# ----------------------------------------------

=pod

=head2 build_map_set_id_string

=cut

sub build_map_set_id_string {
    my $self = shift;
    my $data = shift;

    my ( $id_str, $finished ) = $self->build_generic_id_string(
        data     => $data,
        acc_name => 'map_set_acc',
        identifying_params =>
            [ 'map_set_name', 'map_set_short_name', 'map_type_acc', ],
    );
    $id_str .= ";" . $self->build_species_id_string($data) unless ($finished);
    return $id_str;
}

# ----------------------------------------------

=pod

=head2 build_map_id_string

=cut

sub build_map_id_string {
    my $self = shift;
    my $data = shift;

    my ( $id_str, $finished ) = $self->build_generic_id_string(
        data               => $data,
        acc_name           => 'map_acc',
        identifying_params => [ 'map_name', ],
    );
    $id_str .= ";" . $self->build_map_set_id_string($data) unless ($finished);
    return $id_str;
}

# ----------------------------------------------

=pod

=head2 build_feature_id_string

=cut

sub build_feature_id_string {
    my $self = shift;
    my $data = shift;

    my ( $id_str, $finished ) = $self->build_generic_id_string(
        data               => $data,
        acc_name           => 'feature_acc',
        identifying_params => [
            'feature_name',  'feature_type_acc',
            'feature_start', 'feature_stop',
        ],
    );
    $id_str .= ";" . $self->build_map_id_string($data) unless ($finished);
    return $id_str;
}

# ----------------------------------------------

=pod

=head2 build_correspondence_id_string_feature1

=cut

sub build_correspondence_id_string_feature1 {
    my $self          = shift;
    my $feature_data1 = shift;

    my $id_string = $self->build_feature_id_string($feature_data1);

    # Give the params a 1 after their names
    $id_string =~ s/=/1=/g;

    return $id_string;
}

# ----------------------------------------------

=pod

=head2 build_correspondence_id_string_feature2

=cut

sub build_correspondence_id_string_feature2 {
    my $self = shift;
    my $data = shift;

    # I have to redo the naming the second feature
    my $id_sting = '';
    my @id_sections;

    if ( $data->{'feature_acc2'} !~ /^\d+$/ ) {
        push @id_sections, "feature_acc2=" . $data->{'feature_acc2'};
        return join( ';', @id_sections );
    }
    else {
        my @identifying_params = (
            'feature_name2',  'feature_type_acc2',
            'feature_start2', 'feature_stop2',
        );

        push @id_sections, map { $_ . "=" . $data->{$_} } @identifying_params;
    }
    if ( $data->{'map_acc2'} !~ /^\d+$/ ) {
        push @id_sections, "map_acc2=" . $data->{'map_acc2'};
        return join( ';', @id_sections );
    }
    else {
        my @identifying_params = ( 'map_name2', );
        push @id_sections, map { $_ . "=" . $data->{$_} } @identifying_params;
    }
    if ( $data->{'map_set_acc2'} !~ /^\d+$/ ) {
        push @id_sections, "map_set_acc2=" . $data->{'map_set_acc2'};
        return join( ';', @id_sections );
    }
    else {
        my $map_set_id2        = $data->{'map_set_id2'};
        my $map_set_data       = $self->get_map_set_data( $map_set_id2, );
        my %identifying_params = (
            map_set_name       => 'map_set_name2',
            map_set_short_name => 'map_set_short_name2',
            map_type_acc       => 'map_type_acc2',
        );
        push @id_sections,
            map { $identifying_params{$_} . "=" . $map_set_data->{$_} }
            keys %identifying_params;
    }
    if ( $data->{'species_acc2'} !~ /^\d+$/ ) {
        push @id_sections, "species_acc2=" . $data->{'species_acc2'};
        return join( ';', @id_sections );
    }
    else {
        my @identifying_params = ( 'species_common_name2', );
        push @id_sections, map { $_ . "=" . $data->{$_} } @identifying_params;
    }

    return join( ';', @id_sections );
}

# ----------------------------------------------

=pod

=head2 get_map_set_data

=cut

sub get_map_set_data {
    my $self       = shift;
    my $map_set_id = shift;

    unless ( $self->{'map_set_data'}{$map_set_id} ) {
        my $map_set_data
            = $self->sql->get_map_sets( map_set_id => $map_set_id, );
        return undef unless ( @{ $map_set_data || [] } );
        $self->{'map_set_data'}{$map_set_id} = $map_set_data->[0];
    }
    return $self->{'map_set_data'}{$map_set_id};
}

# ----------------------------------------------

=pod

=head2 create_load_id

=cut

sub create_load_id {
    my ( $self, %args ) = @_;
    my $type_acc = $args{'type_acc'} or return;
    my $id       = $args{'id'}       or return;

    return $type_acc . $id;

}

# ----------------------------------------------

=pod

=head2 file_handle

=cut

sub file_handle {
    my ( $self, $file_name ) = @_;

    if ($file_name) {
        if ( $self->{'file_handle'} ) {
            close $self->{'file_handle'};
        }
        open $self->{'file_handle'}, ">" . $file_name;

    }
    return $self->{'file_handle'};
}

# ----------------------------------------------

=pod

=head2 ignore_unit_granularity

If not ignoring the unit granularity, then the output will use the unit
granularity make sure the starts and stops are integers.  This essentially
devides the start/stop by the unit granurity.

=cut

sub ignore_unit_granularity {
    my ( $self, $value ) = @_;

    if ( defined $value ) {
        $self->{'ignore_unit_granularity'} = $value;
    }

    return $self->{'ignore_unit_granularity'} = $value;
}

# ----------------------------------------------

=pod

=head2 unit_granularity

Overload the parent unit_granularity method to take "ignore_unit_granularity"
into account

=cut

sub unit_granularity {
    my ( $self, %args ) = @_;

    if ( $self->{'ignore_unit_granularity'} ) {
        return 1;
    }

    return $self->SUPER::unit_granularity(%args);
}

1;

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2008 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

