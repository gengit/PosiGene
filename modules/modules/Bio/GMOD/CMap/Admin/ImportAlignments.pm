package Bio::GMOD::CMap::Admin::ImportAlignments;

# vim: set ft=perl:

# $Id: ImportAlignments.pm,v 1.9 2007/09/28 20:17:07 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Admin::ImportAlignments - import alignments such as BLAST

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Admin::ImportAlignments;
  my $importer = Bio::GMOD::CMap::Admin::ImportAlignments->new;
  $importer->import_alignments(
      fh       => $fh,
      log_fh   => $self->log_fh,
  ) or return $importer->error;

=head1 DESCRIPTION

This module encapsulates all the logic for importing feature
alignments from blast files.

=cut

use strict;
use vars qw( $VERSION %COLUMNS $LOG_FH );
$VERSION = (qw$Revision: 1.9 $)[-1];

use Data::Dumper;
use Bio::SearchIO;
use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Admin;

use base 'Bio::GMOD::CMap';

# ----------------------------------------------
sub import_alignments {
    my ( $self, %args ) = @_;
    my $file_name = $args{'file_name'}
        or return $self->error('No file');
    my $query_map_set_id = $args{'query_map_set_id'}
        or return $self->error('No map set');
    my $hit_map_set_id = $args{'hit_map_set_id'}
        || $query_map_set_id;
    my $feature_type_acc = $args{'feature_type_acc'}
        or return $self->error('No feature_type_acc');
    my $evidence_type_acc = $args{'evidence_type_acc'}
        or return $self->error('No evidence_type_acc');
    my $min_identity = $args{'min_identity'} || 0;
    my $min_length   = $args{'min_length'}   || 0;
    my $format       = $args{'format'}       || 'blast';
    $LOG_FH = $args{'log_fh'} || \*STDOUT;
    print $LOG_FH "Importing Alignment\n";

    $self->{'admin'} = Bio::GMOD::CMap::Admin->new(
        config      => $self->config,
        data_source => $self->data_source,
    );

    my $in = new Bio::SearchIO(
        -format => $format,
        -file   => $file_name
    );
    $self->{'added_feature_ids'} = {};

    while ( my $result = $in->next_result ) {
        my $query_map_id = $self->get_map_id(
            object     => $result,
            map_set_id => $query_map_set_id,
            )
            or return $self->error(
            "Unable to find or create map " . $result->query_name() . "\n" );
        while ( my $hit = $result->next_hit ) {
            my $hit_map_id = $self->get_map_id(
                object     => $hit,
                map_set_id => $hit_map_set_id,
                )
                or return $self->error(
                "Unable to find or create map " . $hit->name() . "\n" );
            while ( my $hsp = $hit->next_hsp ) {
                if ( $hsp->length('total') > $min_length ) {
                    if ( $hsp->percent_identity >= $min_identity ) {
                        my @query_range = $hsp->range('query');
                        my @hit_range   = $hsp->range('hit');

                        my $query_feature_id = $self->get_feature_id(
                            feature_type_acc => $feature_type_acc,
                            map_id           => $query_map_id,
                            start            => $query_range[0],
                            end              => $query_range[1],
                            format           => $format,
                            )
                            or return $self->error(
                            "Unable to find or create feature for query \n");
                        my $hit_feature_id = $self->get_feature_id(
                            feature_type_acc => $feature_type_acc,
                            map_id           => $hit_map_id,
                            start            => $hit_range[0],
                            end              => $hit_range[1],
                            format           => $format,
                            )
                            or return $self->error(
                            "Unable to find or create feature for subject \n"
                            );

                        $self->{'admin'}->feature_correspondence_create(
                            feature_id1       => $query_feature_id,
                            feature_id2       => $hit_feature_id,
                            evidence_type_acc => $evidence_type_acc,
                        );
                    }
                }
            }
        }
    }
    return 1;
}

# get_map_id
#
# Check if this map needs adding, if so add it.
# Return the map_id of the map.
sub get_map_id {
    my ( $self, %args ) = @_;
    my $object     = $args{'object'};
    my $map_set_id = $args{'map_set_id'};

    my $sql_object = $self->sql;

    my ( $map_name, $map_desc, $map_acc, $map_length );

    if ( ref($object) eq 'Bio::Search::Result::BlastResult' ) {
        $map_name   = $object->query_name();
        $map_desc   = $object->query_description();
        $map_acc    = $object->query_accession();
        $map_length = $object->query_length();
    }
    elsif ( ref($object) eq 'Bio::Search::Hit::BlastHit' ) {
        $map_name   = $object->name();
        $map_desc   = $object->description();
        $map_acc    = $object->accession();
        $map_length = $object->length();
    }
    else {
        return 0;
    }
    if ( $map_name =~ /^\S+\|\S+/ and $map_desc ) {
        $map_name = $map_desc;
    }

    $map_acc = '' unless defined($map_acc);

    # Check if added before
    my $map_key
        = $map_set_id . ":" . $map_name . ":" . $map_acc . ":" . $map_length;
    if ( $self->{'maps'}->{$map_key} ) {
        return $self->{'maps'}->{$map_key};
    }

    # Check for existance of map in cmap_map

    my $map_id_results = $sql_object->get_maps(
        map_acc    => $map_acc,
        map_name   => $map_name,
        map_length => $map_length,
    );

    my $map_id;
    if ( $map_id_results and @$map_id_results ) {
        $map_id = $map_id_results->[0]{'map_id'};
    }
    else {

        # Map not found, creat it.
        print "Map \"$map_name\" not found.  Creating.\n";
        $map_id = $sql_object->insert_map(
            map_name   => $map_name,
            map_set_id => $map_set_id,
            map_acc    => $map_acc,
            map_start  => '1',
            map_stop   => $map_length,
        );
    }
    $self->{'maps'}->{$map_key} = $map_id;
    return $map_id;
}

# get_feature_id
#
# Check if this feature needs adding, if so add it.
# Return the map_id of the map.
sub get_feature_id {
    my ( $self, %args ) = @_;
    my $feature_type_acc = $args{'feature_type_acc'};
    my $map_id           = $args{'map_id'};
    my $start            = $args{'start'};
    my $end              = $args{'end'};
    my $format           = $args{'format'};
    my $direction        = 1;
    if ( $end < $start ) {
        ( $start, $end ) = ( $end, $start );
        $direction = -1;
    }

    my $sql_object = $self->sql;

    my $feature_key = $direction
        . $feature_type_acc . ":"
        . $map_id . ":"
        . $start . ":"
        . $end;
    if ( $self->{'added_feature_ids'}->{$feature_key} ) {
        return $self->{'added_feature_ids'}->{$feature_key};
    }
    my $feature_id;

    # Check for existance of feature in cmap_feature

    my $feature_id_results = $sql_object->get_features(
        feature_start     => $start,
        feature_stop      => $end,
        feature_type_accs => [$feature_type_acc],
        direction         => $direction,
    );

    if ( $feature_id_results and @$feature_id_results ) {
        $feature_id = $feature_id_results->[0]{'feature_id'};
    }
    else {

        # Feature not found, creat it.
        my $feature_name = $format . "_hsp:$direction:$start,$end";
        $feature_id = $self->{'admin'}->feature_create(
            map_id           => $map_id,
            feature_name     => $feature_name,
            feature_start    => $start,
            feature_stop     => $end,
            is_landmark      => 0,
            feature_type_acc => $feature_type_acc,
            direction        => $direction,
        );
    }

    $self->{'added_feature_ids'}->{$feature_key} = $feature_id;
    return $self->{'added_feature_ids'}->{$feature_key};
}

1;

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.
Ken Y. Clark E<lt>kclark@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2005-7 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

