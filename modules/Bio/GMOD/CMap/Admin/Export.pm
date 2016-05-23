package Bio::GMOD::CMap::Admin::Export;

# vim: set ft=perl:

# $Id: Export.pm,v 1.26 2007/09/28 20:17:01 mwz444 Exp $

=pod

=head1 NAME

Bio::GMOD::CMap::Admin::Export - export CMap data

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Admin::Export;

  my $exporter = Bio::GMOD::CMap::Admin::Export->new();
  $exporter->export(
      map_set_id => $map_set_id,
      fh         => $fh,
  ) or print "Error: ", $exporter->error, "\n";

=head1 DESCRIPTION

This module encapsulates the logic for exporting all the various types
of data out of CMap.

=cut

use strict;
use vars qw( $VERSION %DISPATCH %COLUMNS );
$VERSION = (qw$Revision: 1.26 $)[-1];

use Data::Dumper;
use File::Spec::Functions;
use XML::Simple;
use Bio::GMOD::CMap;

use base 'Bio::GMOD::CMap';

use vars '$LOG_FH';

# ----------------------------------------------------
sub export {

=pod

=head2 export

=head3 For External Use

=over 4

=item * Description

Export data.

=item * Usage

    $exporter->export(
        output => $output,
        log_fh => $log_fh,
        objects => $objects,
        output_path => $output_path,
    );

=item * Returns

1

=item * Fields

=over 4

=item - output

File handle of the output file.
Must specify either an output or output_path

=item - output_path

String of the path and file name of an output file.
Must specify either an output or output_path

=item - log_fh

File handle of the log file (defaults to STDOUT)

=item - objects

An arrayref of object names to be exported, such as "map_set"

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $objects     = $args{'objects'};
    my $output      = $args{'output'};
    my $output_path = $args{'output_path'};
    return $self->error('No output path') unless $output || $output_path;
    return $self->error('Output arg not a scalar reference')
        if defined $output && ref $output ne 'SCALAR';
    $LOG_FH = $args{'log_fh'} || \*STDOUT;

    return $self->error('No objects to export') unless @$objects;

    local $| = 1;

    my %dump;
    for my $object_type (@$objects) {
        my $method = 'get_export_' . $object_type;

        if ( $self->can($method) ) {
            my $pretty = $object_type;
            $pretty =~ s/_/ /g;

            # $self->Print("Dumping objects for type '$pretty'.\n");

            my $objects = $self->$method(%args);

            if ( ref $objects eq 'ARRAY' ) {

                # preserve the "cmap_" format in the export file
                push @{ $dump{ "cmap_" . $object_type } }, @$objects;
            }
            elsif ( ref $objects eq 'HASH' ) {
                while ( my ( $k, $v ) = each %$objects ) {

                    # preserve the "cmap_" format in the export file
                    push @{ $dump{ "cmap_" . $k } }, @$v;
                }
            }
        }
        else {
            $self->Print("Can't do '$method' -- skipping object\n");
        }
    }

    my $date = localtime;
    $dump{'dump_date'} = $date;
    my @comments = (
        'This file contains data from CMap (http://www.gmod.org/cmap)',
        'From the ' . $self->data_source . ' data source',
        "Created on $date"
    );

    my $xml = join(
        "\n",
        "<?xml version='1.0'?>",
        ( join( "\n", map {"<!-- $_ -->"} @comments ) ),
        '', '',
        XMLout(
            \%dump,
            RootName      => 'cmap_export',
            NoAttr        => 1,
            SuppressEmpty => 1,
            XMLDecl       => 0,
        )
    );

    if ($output_path) {
        open my $out_fh, ">$output_path" or die "Can't open '$output_path'\n";
        print $out_fh $xml;
        close $out_fh;
    }
    else {
        $$output = $xml;
    }

    return 1;
}

# ----------------------------------------------------
sub get_attributes_and_xrefs {

=pod

=head2 get_attributes_and_xrefs

=head3 NOT For External Use

=over 4

=item * Description

get_attributes_and_xrefs

=item * Usage

    $exporter->get_attributes_and_xrefs();

=item * Returns

1

=back

=cut

    my $self        = shift;
    my $object_type = shift;
    my @objects     = ref $_[0] eq 'ARRAY' ? @{ $_[0] } : @_;
    my $pk_name     = $self->sql->pk_name($object_type);

    my $attributes
        = $self->sql->get_attributes( object_type => $object_type, )
        or return $self->error;

    my $xrefs = $self->sql->get_xrefs( object_type => $object_type, )
        or return $self->error;

    my %attr_lookup;
    for my $a (@$attributes) {
        push @{ $attr_lookup{ $a->{'object_id'} } }, $a;
    }

    my %xref_lookup;
    for my $x (@$xrefs) {
        next unless $x->{'object_id'};
        push @{ $xref_lookup{ $x->{'object_id'} } }, $x;
    }

    for my $o (@objects) {
        if ( defined $attr_lookup{ $o->{$pk_name} } ) {
            $o->{'attribute'} = $attr_lookup{ $o->{$pk_name} };
        }

        if ( defined $xref_lookup{ $o->{$pk_name} } ) {
            $o->{'xref'} = $xref_lookup{ $o->{$pk_name} };
        }
    }

    return 1;
}

# ----------------------------------------------------
sub get_export_feature_correspondence {

=pod

=head2 get_export_feature_correspondence

=head3 NOT For External Use

=over 4

=item * Description

get_export_feature_correspondence

=item * Usage

    $exporter->get_export_feature_correspondence(
        feature_type_id => $feature_type_id,
    );

=item * Returns

Feature correspondence

=item * Fields

=over 4

=item - feature_type_id

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $map_set_ids = join( ', ',
        map { $_->{'map_set_id'} } @{ $args{'map_sets'} || [] } );

    my $sql_object = $self->sql or return;
    my @map_set_ids = map { $_->{'map_set_id'} } @{ $args{'map_sets'} || [] };
    my $fc = $sql_object->get_feature_correspondences_simple(
        map_set_ids1 => \@map_set_ids,
        map_set_ids2 => \@map_set_ids,
    );

    unless ( $args{'no_attributes'} ) {
        $self->get_attributes_and_xrefs( 'feature_correspondence', $fc );
    }

    my $evidence = $sql_object->get_correspondence_evidences_simple(
        map_set_ids => \@map_set_ids, );
    my %evidence_lookup = ();
    for my $e (@$evidence) {
        push @{ $evidence_lookup{ $e->{'correspondence_evidence_id'} } }, $e;
    }

    for my $corr (@$fc) {
        $corr->{'correspondence_evidence'}
            = $evidence_lookup{ $corr->{'feature_correspondence_id'} };
    }

    return $fc;
}

# ----------------------------------------------------
sub get_export_map_set {

=pod

=head2 get_export_map_set

=head3 NOT For External Use

=over 4

=item * Description

get_export_map_set

=item * Usage

    $exporter->get_export_map_set(
        map_type_id => $map_type_id,
    );

=item * Returns

hash with map set and species

=item * Fields

=over 4

=item - map_type_id

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $sql_object = $self->sql or return;

    my $map_sets = $sql_object->get_map_sets_simple( map_set_ids =>
            [ map { $_->{'map_set_id'} } @{ $args{'map_sets'} || [] } ], );

    my ( %species_ids, %map_type_accs, %ft_ids );
    for my $ms (@$map_sets) {
        $species_ids{ $ms->{'species_id'} }     = 1;
        $map_type_accs{ $ms->{'map_type_acc'} } = 1;

        $ms->{'map'}
            = $sql_object->get_maps_simple( map_set_id => $ms->{'map_set_id'},
            );

        $self->get_attributes_and_xrefs( 'map', $ms->{'map'} );

        unless ( $args{'no_attributes'} ) {
            $self->get_attributes_and_xrefs( 'map', $ms->{'map'} );
        }

        for my $map ( @{ $ms->{'map'} } ) {
            $map->{'feature'} = $sql_object->get_features_simple(
                map_id => $map->{'map_id'}, );

            my $aliases = $sql_object->get_feature_aliases(
                map_id => $map->{'map_id'}, );
            foreach my $row (@$aliases) {
                delete( $row->{'feature_acc'} );
                delete( $row->{'feature_name'} );
            }

            unless ( $args{'no_attributes'} ) {
                $self->get_attributes_and_xrefs( 'feature_alias', $aliases );
            }

            my %alias_lookup = ();
            for my $alias (@$aliases) {
                push @{ $alias_lookup{ $alias->{'feature_id'} } }, $alias;
            }

            for my $f ( @{ $map->{'feature'} } ) {
                $ft_ids{ $f->{'feature_type_acc'} } = 1;
                if ( defined $alias_lookup{ $f->{'feature_id'} } ) {
                    $f->{'feature_alias'}
                        = $alias_lookup{ $f->{'feature_id'} };
                }
            }

            $self->get_attributes_and_xrefs( 'feature', $map->{'feature'} )
                unless $args{'no_attributes'};
        }
    }

    unless ( $args{'no_attributes'} ) {
        $self->get_attributes_and_xrefs( 'map_set', $map_sets );
    }

    my @species;
    for my $species_id ( keys %species_ids ) {
        push @species,
            @{ $self->get_export_species( species_id => $species_id ) };
    }

    return {
        map_set => $map_sets,
        species => \@species,

        #map_type     => \@map_type,
        #feature_type => \@feature_types,
    };
}

# ----------------------------------------------------
sub get_export_species {

=pod

=head2 get_export_species

=head3 NOT For External Use

=over 4

=item * Description

get_export_species

=item * Usage

    $exporter->get_export_species(
        species_id => $species_id,
    );

=item * Returns

Species object

=item * Fields

=over 4

=item - species_id

=back

=back

=cut

    my ( $self, %args ) = @_;

    my $sql_object = $self->sql or return;
    my $species
        = $sql_object->get_species( species_id => $args{'species_id'}, );

    unless ( $args{'no_attributes'} ) {
        $self->get_attributes_and_xrefs( 'species', $species );
    }

    return $species;
}

# ----------------------------------------------------
sub get_export_xref {

=pod    

=head2 get_export_xref    

=head3 NOT For External Use

=over 4

=item * Description

calls sql->get_generic_xrefs

=item * Usage   

    $exporter->get_export_xref();

=item * Returns 

Xref data   

=back

=cut

    my ( $self, %args ) = @_;
    return $self->sql->get_generic_xrefs();
}

# ----------------------------------------------------
sub Print {

=pod

=head2 Print

=head3 NOT For External Use

=over 4

=item * Description

Print

=item * Usage

    $exporter->Print();

=item * Returns

Nothing

=back

=cut

    my $self = shift;
    print $LOG_FH @_;
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

