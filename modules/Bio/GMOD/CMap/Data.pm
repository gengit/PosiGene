package Bio::GMOD::CMap::Data;

# vim: set ft=perl:

# $Id: Data.pm,v 1.294 2008/02/28 17:12:56 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Data - base data module

=head1 SYNOPSIS

use Bio::GMOD::CMap::Data;
my $data = Bio::GMOD::CMap::Data->new;
my $foo  = $data->foo_data;

=head1 DESCRIPTION

A module for getting data from a database.  Think DBI for whatever
RDBMS you want to use underneath.  I'll try to write generic SQL to
work with anything, and customize it in subclasses.

=head1 METHODS

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.294 $)[-1];

use Data::Dumper;
use Date::Format;
use Regexp::Common;
use Time::ParseDate;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Utils;
use Bio::GMOD::CMap::Admin::Export;
use Bio::GMOD::CMap::Admin::ManageLinks;

use base 'Bio::GMOD::CMap';

# ----------------------------------------------------
sub init {
    my ( $self, $config ) = @_;
    $self->config( $config->{'config'} );
    $self->data_source( $config->{'data_source'} );
    $self->aggregate( $config->{'aggregate'} );
    $self->show_intraslot_corr( $config->{'show_intraslot_corr'} );
    $self->split_agg_ev( $config->{'split_agg_ev'} );
    $self->ref_map_order( $config->{'ref_map_order'} );
    $self->comp_menu_order( $config->{'comp_menu_order'} );

    return $self;
}

# ----------------------------------------------------

=pod

=head2 correspondence_detail_data

Gets the specifics on a feature correspondence record.

=cut

sub correspondence_detail_data {

    my ( $self, %args ) = @_;
    my $correspondence_acc = $args{'correspondence_acc'}
        or return $self->error('No correspondence accession ID');
    my $sql_object = $self->sql;
    my $cache_key  = "correspondence_detail_data_" . $correspondence_acc;
    my ( $corr, $feature1, $feature2 );

    if ( my $array_ref = $self->get_cached_results( 4, $cache_key ) ) {
        ( $corr, $feature1, $feature2 ) = @$array_ref;
    }
    else {
        $corr
            = $sql_object->get_feature_correspondences(
            feature_correspondence_acc => $correspondence_acc, )
            or return $sql_object->error();

        $corr->{'attributes'} = $sql_object->get_attributes(
            object_type => 'feature_correspondence',
            object_id   => $corr->{'feature_correspondence_id'},
        );

        $corr->{'xrefs'} = $sql_object->get_xrefs(
            object_type => 'feature_correspondence',
            object_id   => $corr->{'feature_correspondence_id'},
        );

        $feature1
            = $sql_object->get_features( feature_id => $corr->{'feature_id1'},
            );
        $feature1 = $feature1->[0] if $feature1;
        $feature2
            = $sql_object->get_features( feature_id => $corr->{'feature_id2'},
            );
        $feature2 = $feature2->[0] if $feature2;

        $corr->{'evidence'}
            = $sql_object->get_correspondence_evidences(
            feature_correspondence_id => $corr->{'feature_correspondence_id'},
            );

        $corr->{'evidence'}
            = sort_selectall_arrayref( $corr->{'evidence'}, '#rank',
            'evidence_type' );
        $self->store_cached_results( 4, $cache_key,
            [ $corr, $feature1, $feature2 ] );
    }
    return {
        correspondence => $corr,
        feature1       => $feature1,
        feature2       => $feature2,
    };
}

# ----------------------------------------------------
sub data_download {

=pod

=head2 data_download

Returns a string of tab-delimited data for either a map or map set.

=cut

    my ( $self, %args ) = @_;
    my $map_set_acc = $args{'map_set_acc'} || '';
    my $map_acc     = $args{'map_acc'}     || '';
    my $format      = uc $args{'format'}   || 'TAB';
    return $self->error("Not enough arguments for data_download")
        unless $map_set_acc || $map_acc;

    return $self->error("'$format' not a valid download format")
        unless $format =~ /^(TAB|GFF|XML)$/;

    return $self->error("XML format only valid for map sets")
        if $format eq 'XML' && !$map_set_acc;

    my $sql_object = $self->sql;
    my ( $map_set_id, $map_id );

    if ($map_acc) {
        $map_id = $sql_object->acc_id_to_internal_id(
            object_type => 'map',
            acc_id      => $map_acc,
            )
            or
            return $self->error("'$map_acc' is not a valid map accession ID");
    }

    if ($map_set_acc) {
        $map_set_id = $sql_object->acc_id_to_internal_id(
            object_type => 'map_set',
            acc_id      => $map_set_acc,
            )
            or return $self->error(
            "'$map_set_acc' is not a valid map set accession ID");
    }

    my $return;
    if ( $format eq 'XML' ) {
        my $object = $map_set_acc ? 'map_set' : 'map';
        my $exporter = Bio::GMOD::CMap::Admin::Export->new(
            config      => $self->config,
            data_source => $self->data_source
        ) or return $self->error( Bio::GMOD::CMap::Admin::Export->error );

        $exporter->export(
            objects  => [$object],
            output   => \$return,
            map_sets => $map_set_id ? [ { map_set_id => $map_set_id } ] : [],
            no_attributes => 1,
            )
            or do {
            print "Error: ", $exporter->error, "\n";
            return;
            };
    }
    else {

        my $features;
        if ($map_acc) {
            $features = $sql_object->get_features( map_id => $map_id, );
        }
        else {
            $features
                = $sql_object->get_features( map_set_id => $map_set_id, );
        }

        if ( $format eq 'TAB' ) {

            my @col_headers = qw[ map_acc map_name map_start map_stop
                feature_acc feature_name feature_aliases feature_start
                feature_stop feature_type_acc is_landmark
            ];
            my @col_names = qw[ map_acc map_name map_start map_stop
                feature_acc feature_name feature_aliases feature_start
                feature_stop feature_type_acc is_landmark
            ];

            $return = join( "\t", @col_headers ) . "\n";

            for my $f (@$features) {
                $f->{'feature_aliases'}
                    = join( ',', sort @{ $f->{'aliases'} || [] } );
                $return .= join( "\t", map { $f->{$_} } @col_names ) . "\n";
            }
        }
        elsif ( $format eq 'GFF' ) {

            #
            # Fields are: <seqname> <source> <feature> <start> <end>
            # <score> <strand> <frame> [attributes] [comments]
            # http://www.sanger.ac.uk/Software/formats/GFF/GFF_Spec.shtml
            #
            for my $f (@$features) {
                $return .= join( "\t",
                    $f->{'feature_name'},     'CMap',
                    $f->{'feature_type_acc'}, $f->{'feature_start'},
                    $f->{'feature_stop'},     '.',
                    '.',                      '.',
                    $f->{'map_name'} )
                    . "\n";
            }

        }
    }

    return $return;
}

# ----------------------------------------------------

=pod

=head2 cmap_data

Organizes the data for drawing comparative maps.

=cut

sub cmap_data {

    my ( $self, %args ) = @_;
    my $slots                      = $args{'slots'};
    my $slot_min_corrs             = $args{'slot_min_corrs'} || {};
    my $stack_slot                 = $args{'stack_slot'} || {};
    my $eliminate_orphans          = $args{'eliminate_orphans'} || 0;
    my $included_feature_type_accs = $args{'included_feature_type_accs'}
        || [];
    my $corr_only_feature_type_accs = $args{'corr_only_feature_type_accs'}
        || [];
    my $ignored_feature_type_accs = $args{'ignored_feature_type_accs'} || [];
    my $url_feature_default_display = $args{'url_feature_default_display'};
    my $ignored_evidence_type_accs  = $args{'ignored_evidence_type_accs'}
        || [];
    my $included_evidence_type_accs = $args{'included_evidence_type_accs'}
        || [];
    my $less_evidence_type_accs = $args{'less_evidence_type_accs'} || [];
    my $greater_evidence_type_accs = $args{'greater_evidence_type_accs'}
        || [];
    my $evidence_type_score = $args{'evidence_type_score'} || {};
    my $pid = $$;

    $self->fill_type_arrays(
        ref_map_set_acc             => $slots->{0}{'map_set_acc'},
        included_feature_type_accs  => $included_feature_type_accs,
        corr_only_feature_type_accs => $corr_only_feature_type_accs,
        ignored_feature_type_accs   => $ignored_feature_type_accs,
        url_feature_default_display => $url_feature_default_display,
        ignored_evidence_type_accs  => $ignored_evidence_type_accs,
        included_evidence_type_accs => $included_evidence_type_accs,
        less_evidence_type_accs     => $less_evidence_type_accs,
        greater_evidence_type_accs  => $greater_evidence_type_accs,
    );

    my ($data,                      %feature_correspondences,
        %intraslot_correspondences, %map_correspondences,
        %correspondence_evidence,   %feature_types,
        %map_type_accs
    );
    $self->slot_info(
        $slots,                       $ignored_feature_type_accs,
        $included_evidence_type_accs, $less_evidence_type_accs,
        $greater_evidence_type_accs,  $evidence_type_score,
        $slot_min_corrs,              $eliminate_orphans,
    ) or return;
    $self->update_slots( $slots, $slot_min_corrs, $stack_slot );

    my @slot_nos         = keys %$slots;
    my @pos              = sort { $a <=> $b } grep { $_ >= 0 } @slot_nos;
    my @neg              = sort { $b <=> $a } grep { $_ < 0 } @slot_nos;
    my @ordered_slot_nos = ( @pos, @neg );
    for my $slot_no (@ordered_slot_nos) {
        my $cur_map = $slots->{$slot_no};
        my $ref_slot_no
            = $slot_no == 0 ? undef
            : $slot_no > 0  ? $slot_no - 1
            :                 $slot_no + 1;
        my $ref_map = defined $ref_slot_no ? $slots->{$ref_slot_no} : undef;

        $data->{'slot_data'}{$slot_no} = $self->slot_data(
            map                       => \$cur_map,                     # pass
            feature_correspondences   => \%feature_correspondences,     # by
            intraslot_correspondences => \%intraslot_correspondences,   #
            map_correspondences       => \%map_correspondences,         # ref
            correspondence_evidence   => \%correspondence_evidence,     # "
            feature_types             => \%feature_types,               # "
            reference_map             => $ref_map,
            slot_no                   => $slot_no,
            ref_slot_no               => $ref_slot_no,

            #min_correspondences         => $min_correspondences,
            included_feature_type_accs  => $included_feature_type_accs,
            corr_only_feature_type_accs => $corr_only_feature_type_accs,
            ignored_feature_type_accs   => $ignored_feature_type_accs,
            ignored_evidence_type_accs  => $ignored_evidence_type_accs,
            included_evidence_type_accs => $included_evidence_type_accs,
            less_evidence_type_accs     => $less_evidence_type_accs,
            greater_evidence_type_accs  => $greater_evidence_type_accs,
            evidence_type_score         => $evidence_type_score,
            pid                         => $pid,
            map_type_accs               => \%map_type_accs,
        ) or last;

        #Set the map order for this slot
        $self->sorted_map_ids( $slot_no, $data->{'slot_data'}{$slot_no} );

    }
    ###Get the extra javascript that goes along with the feature_types.
    ### and get extra forms
    my ( $extra_code, $extra_form );
    ( $extra_code, $extra_form )
        = $self->get_web_page_extras( \%feature_types, \%map_type_accs,
        $extra_code, $extra_form );

    #
    # Allow only one correspondence evidence per (the top-most ranking).
    #
    for my $fc_id ( keys %correspondence_evidence ) {
        my @evidence
            = sort { $a->{'evidence_rank'} <=> $b->{'evidence_rank'} }
            @{ $correspondence_evidence{$fc_id} };
        $correspondence_evidence{$fc_id} = $evidence[0];
    }

    $data->{'correspondences'}             = \%feature_correspondences;
    $data->{'intraslot_correspondences'}   = \%intraslot_correspondences;
    $data->{'map_correspondences'}         = \%map_correspondences;
    $data->{'correspondence_evidence'}     = \%correspondence_evidence;
    $data->{'feature_types'}               = \%feature_types;
    $data->{'included_feature_type_accs'}  = $included_feature_type_accs;
    $data->{'corr_only_feature_type_accs'} = $corr_only_feature_type_accs;
    $data->{'ignored_feature_type_accs'}   = $ignored_feature_type_accs;
    $data->{'included_evidence_type_accs'} = $included_evidence_type_accs;
    $data->{'ignored_evidence_type_accs'}  = $ignored_evidence_type_accs;
    $data->{'less_evidence_type_accs'}     = $less_evidence_type_accs;
    $data->{'greater_evidence_type_accs'}  = $greater_evidence_type_accs;
    $data->{'evidence_type_score'}         = $evidence_type_score;
    $data->{'extra_code'}                  = $extra_code;
    $data->{'extra_form'}                  = $extra_form;
    $data->{'max_unit_size'}
        = $self->get_max_unit_size( $data->{'slot_data'} );
    $data->{'ref_unit_size'}
        = $self->get_ref_unit_size( $data->{'slot_data'} );
    $data->{'feature_default_display'}
        = $self->feature_default_display($url_feature_default_display);

    return ( $data, $slots );
}

# ----------------------------------------------------

=pod

=head2 slot_data

Returns the feature and correspondence data for the maps in a slot.

=cut

sub slot_data {

    my ( $self, %args ) = @_;
    my $this_slot_no = $args{'slot_no'};
    my $ref_slot_no  = $args{'ref_slot_no'};

    # my $min_correspondences         = $args{'min_correspondences'} || 0;
    my $included_feature_type_accs = $args{'included_feature_type_accs'}
        || [];
    my $included_evidence_type_accs = $args{'included_evidence_type_accs'};
    my $ignored_evidence_type_accs  = $args{'ignored_evidence_type_accs'};
    my $less_evidence_type_accs     = $args{'less_evidence_type_accs'};
    my $greater_evidence_type_accs  = $args{'greater_evidence_type_accs'};
    my $evidence_type_score         = $args{'evidence_type_score'};
    my $slot_map                = ${ $args{'map'} };                 # hashref
    my $reference_map           = $args{'reference_map'};
    my $feature_correspondences = $args{'feature_correspondences'};
    my $intraslot_correspondences   = $args{'intraslot_correspondences'};
    my $map_correspondences         = $args{'map_correspondences'};
    my $correspondence_evidence     = $args{'correspondence_evidence'};
    my $feature_types_seen          = $args{'feature_types'};
    my $corr_only_feature_type_accs = $args{'corr_only_feature_type_accs'}
        || [];
    my $ignored_feature_type_accs = $args{'ignored_feature_type_accs'};
    my $map_type_accs             = $args{'map_type_accs'};
    my $pid                       = $args{'pid'};
    my $max_no_features           = 200000;
    my $sql_object                = $self->sql or return;
    my $slot_info                 = $self->slot_info or return;

    #
    # If there is more than 1 map in this slot, we will return totals
    # for all the features on every map and the number of
    # correspondences on them to the reference map.
    #
    # If there is just one map in this slot, then we will look to see
    # if the total number of features on the map exceeds some number
    # -- 200 for now.  If so, we will chunk the map's features and
    # correspondences;  if not, we will show all.
    #

    #
    # Sort out the map(s) in the current slot ("this" map) -- are we
    # looking at just one map or all the maps in the set?
    #
    my @map_accs              = keys( %{ $slot_map->{'maps'} } );
    my @map_set_accs          = keys( %{ $slot_map->{'map_sets'} } );
    my $no_flanking_positions = $slot_map->{'no_flanking_positions'} || 0;

    #
    # Gather necessary info on all the maps in this slot.
    #
    my @maps = ();

    if ( $slot_info->{$this_slot_no}
        and %{ $slot_info->{$this_slot_no} } )
    {
        my $tempMap = $sql_object->get_maps(
            map_ids => [ keys( %{ $slot_info->{$this_slot_no} } ) ], );

        foreach my $row (@$tempMap) {
            if ($slot_info->{$this_slot_no}{ $row->{'map_id'} }
                and
                defined( $slot_info->{$this_slot_no}{ $row->{'map_id'} }[0] )
                and ( $slot_info->{$this_slot_no}{ $row->{'map_id'} }[0]
                    > $row->{'map_start'} )
                )
            {
                $row->{'map_start'}
                    = $slot_info->{$this_slot_no}{ $row->{'map_id'} }[0];
            }
            if ( $slot_info->{$this_slot_no}{ $row->{'map_id'} }
                and
                defined( $slot_info->{$this_slot_no}{ $row->{'map_id'} }[1] )
                and defined( $row->{'map_stop'} )
                and ( $slot_info->{$this_slot_no}{ $row->{'map_id'} }[1] )
                < $row->{'map_stop'} )
            {
                $row->{'map_stop'}
                    = $slot_info->{$this_slot_no}{ $row->{'map_id'} }[1];
            }
        }
        push @maps, @{$tempMap};
    }

    #
    # Store all the map types
    #
    if ( scalar @maps == 1 ) {
        $map_type_accs->{ $maps[0]{'map_type_acc'} } = 1;
    }
    else {
        for (@maps) {
            $map_type_accs->{ $_->{'map_type_acc'} } = 1;
        }
    }

    my $return;

    #
    # Register the feature types on the maps in this slot.
    #
    my $ft = $sql_object->get_used_feature_types(
        map_ids => [ keys( %{ $slot_info->{$this_slot_no} } ) ],
        included_feature_type_accs =>
            [ @$included_feature_type_accs, @$corr_only_feature_type_accs ],
    );
    $feature_types_seen->{ $_->{'feature_type_acc'} } = $_ for @$ft;

    #
    # check to see if it is compressed
    #
    if ( !$self->{'aggregate'} or !$self->compress_maps($this_slot_no) ) {

        #
        # Figure out how many features are on each map.
        #
        my %count_lookup;

        # Include current slot maps
        my $f_counts = $sql_object->get_feature_count(
            this_slot_info  => $slot_info->{$this_slot_no},
            group_by_map_id => 1,
        );

        for my $f (@$f_counts) {
            $count_lookup{ $f->{'map_id'} } = $f->{'feature_count'};
        }

        my %corr_lookup = %{
            $self->count_correspondences(
                included_evidence_type_accs => $included_evidence_type_accs,
                ignored_evidence_type_accs  => $ignored_evidence_type_accs,
                less_evidence_type_accs     => $less_evidence_type_accs,
                greater_evidence_type_accs  => $greater_evidence_type_accs,
                evidence_type_score         => $evidence_type_score,
                map_correspondences         => $map_correspondences,
                this_slot_no                => $this_slot_no,
                ref_slot_no                 => $ref_slot_no,
                maps                        => \@maps,

            )
            };

        for my $map (@maps) {
            my $map_start
                = $slot_info->{$this_slot_no}{ $map->{'map_id'} }[0];
            my $map_stop = $slot_info->{$this_slot_no}{ $map->{'map_id'} }[1];
            $map->{'map_start'} = $map_start if defined($map_start);
            $map->{'map_stop'}  = $map_stop  if defined($map_stop);
            $map->{'no_correspondences'} = $corr_lookup{ $map->{'map_id'} };

#            if (   $min_correspondences
#                && defined $ref_slot_no
#                && $map->{'no_correspondences'} < $min_correspondences )
#            {
#                delete $self->{'slot_info'}{$this_slot_no}{ $map->{'map_id'} };
#                next;
#            }
            $map->{'no_features'} = $count_lookup{ $map->{'map_id'} };

            $map->{'features'} = $sql_object->slot_data_features(
                map_id                      => $map->{'map_id'},
                map_start                   => $map_start,
                map_stop                    => $map_stop,
                slot_info                   => $slot_info,
                this_slot_no                => $this_slot_no,
                included_feature_type_accs  => $included_feature_type_accs,
                ignored_feature_type_accs   => $ignored_feature_type_accs,
                corr_only_feature_type_accs => $corr_only_feature_type_accs,
                show_intraslot_corr         => $self->show_intraslot_corr,
            );

            ###set $feature_correspondences and$correspondence_evidence
            if ( defined $ref_slot_no ) {
                $self->get_feature_correspondences(
                    $feature_correspondences,
                    $correspondence_evidence,
                    $map->{'map_id'},
                    $ref_slot_no,
                    $included_evidence_type_accs,
                    $ignored_evidence_type_accs,
                    $less_evidence_type_accs,
                    $greater_evidence_type_accs,
                    $evidence_type_score,
                    [   @$included_feature_type_accs,
                        @$corr_only_feature_type_accs
                    ],
                    $map_start,
                    $map_stop
                );
            }
            $return->{ $map->{'map_id'} } = $map;
        }
    }
    else {

        #
        # Figure out how many features are on each map.
        #
        my %count_lookup;
        my $f_counts = $sql_object->get_feature_count(
            map_ids         => [ keys( %{ $slot_info->{$this_slot_no} } ) ],
            group_by_map_id => 1,
        );

        for my $f (@$f_counts) {
            $count_lookup{ $f->{'map_id'} } = $f->{'feature_count'};
        }

        my %corr_lookup = %{
            $self->count_correspondences(
                included_evidence_type_accs => $included_evidence_type_accs,
                ignored_evidence_type_accs  => $ignored_evidence_type_accs,
                less_evidence_type_accs     => $less_evidence_type_accs,
                greater_evidence_type_accs  => $greater_evidence_type_accs,
                evidence_type_score         => $evidence_type_score,
                map_correspondences         => $map_correspondences,
                this_slot_no                => $this_slot_no,
                ref_slot_no                 => $ref_slot_no,
                maps                        => \@maps,

            )
            };

        for my $map (@maps) {
            my $map_start
                = $slot_info->{$this_slot_no}{ $map->{'map_id'} }[0];
            my $map_stop = $slot_info->{$this_slot_no}{ $map->{'map_id'} }[1];
            $map->{'map_start'} = $map_start if defined($map_start);
            $map->{'map_stop'}  = $map_stop  if defined($map_stop);
            $map->{'no_correspondences'} = $corr_lookup{ $map->{'map_id'} };

#            if (   $min_correspondences
#                && defined $ref_slot_no
#                && $map->{'no_correspondences'} < $min_correspondences )
#            {
#                delete $self->{'slot_info'}{$this_slot_no}{ $map->{'map_id'} };
#                next;
#            }
            $map->{'no_features'} = $count_lookup{ $map->{'map_id'} };

            ###set $feature_correspondences and$correspondence_evidence
            if ( defined $ref_slot_no ) {
                $self->get_feature_correspondences(
                    $feature_correspondences,
                    $correspondence_evidence,
                    $map->{'map_id'},
                    $ref_slot_no,
                    $included_evidence_type_accs,
                    $ignored_evidence_type_accs,
                    $less_evidence_type_accs,
                    $greater_evidence_type_accs,
                    $evidence_type_score,
                    [   @$included_feature_type_accs,
                        @$corr_only_feature_type_accs
                    ],
                    $map_start,
                    $map_stop
                );
            }
            $return->{ $map->{'map_id'} } = $map;
        }
    }

    # Get the intra-slot correspondence
    if ( $self->show_intraslot_corr ) {
        $self->get_intraslot_correspondences(
            $intraslot_correspondences,
            $correspondence_evidence,
            $this_slot_no,
            $included_evidence_type_accs,
            $ignored_evidence_type_accs,
            $less_evidence_type_accs,
            $greater_evidence_type_accs,
            $evidence_type_score,
            [ @$included_feature_type_accs, @$corr_only_feature_type_accs ],
        );
    }

    return $return;

}

# ----------------------------------------------------

=pod

=head2 get_web_page_extras

Gets the extra javascript code that needs to go on the web
page for these features.

=cut

sub get_web_page_extras {
    my $self          = shift;
    my $feature_types = shift;
    my $map_type_accs = shift;
    my $extra_code    = shift;
    my $extra_form    = shift;

    my %snippet_accs;
    my %extra_form_accs;
    my $required_string;
    my $map_type_data     = $self->map_type_data();
    my $feature_type_data = $self->feature_type_data();

    ###Get the feature type info
    foreach my $key ( keys %{$feature_types} ) {
        ###First get the code snippets
        $required_string = $feature_type_data->{$key}{'required_page_code'};
        if ($required_string) {
            foreach my $snippet_acc ( split( /\s*,\s*/, $required_string ) ) {
                $snippet_accs{$snippet_acc} = 1;
            }
        }
        ###Then get the extra form stuff
        $required_string = $feature_type_data->{$key}{'extra_forms'};
        if ($required_string) {
            foreach
                my $extra_form_acc ( split( /\s*,\s*/, $required_string ) )
            {
                $extra_form_accs{$extra_form_acc} = 1;
            }
        }
    }

    ###Get the map type info
    foreach my $key ( keys %{$map_type_accs} ) {
        ###First get the code snippets
        $required_string = $map_type_data->{$key}{'required_page_code'};
        foreach my $snippet_acc ( split( /\s*,\s*/, $required_string ) ) {
            $snippet_accs{$snippet_acc} = 1;
        }
        ###Then get the extra form stuff
        $required_string = $map_type_data->{$key}{'extra_forms'};
        foreach my $extra_form_acc ( split( /\s*,\s*/, $required_string ) ) {
            $extra_form_accs{$extra_form_acc} = 1;
        }

    }

    foreach my $snippet_acc ( keys(%snippet_accs) ) {
        $extra_code
            .= $self->config_data('page_code')->{$snippet_acc}->{'page_code'};
    }
    foreach my $extra_form_acc ( keys(%extra_form_accs) ) {
        $extra_form .= $self->config_data('extra_form')->{$extra_form_acc}
            ->{'extra_form'};
    }
    return ( $extra_code, $extra_form );
}

# ----------------------------------------------------

=pod
    
=head2 get_feature_correspondences

inserts correspondence info into $feature_correspondence and 
$correspondence_evidence based on corrs from the slot
and the provided id.

=cut

sub get_feature_correspondences {

    my ($self,                       $feature_correspondences,
        $correspondence_evidence,    $map_id,
        $slot_no,                    $included_evidence_type_accs,
        $ignored_evidence_type_accs, $less_evidence_type_accs,
        $greater_evidence_type_accs, $evidence_type_score,
        $feature_type_accs,          $map_start,
        $map_stop
    ) = @_;
    my $sql_object = $self->sql;

    my $ref_correspondences
        = $sql_object->get_feature_correspondences_by_maps(
        map_id                      => $map_id,
        ref_map_info                => $self->slot_info->{$slot_no},
        map_start                   => $map_start,
        map_stop                    => $map_stop,
        included_evidence_type_accs => $included_evidence_type_accs,
        less_evidence_type_accs     => $less_evidence_type_accs,
        greater_evidence_type_accs  => $greater_evidence_type_accs,
        evidence_type_score         => $evidence_type_score,
        feature_type_accs           => $feature_type_accs,
        );

    for my $corr ( @{$ref_correspondences} ) {
        $feature_correspondences->{ $corr->{'feature_id'} }
            { $corr->{'ref_feature_id'} }
            = $corr->{'feature_correspondence_id'};

        $feature_correspondences->{ $corr->{'ref_feature_id'} }
            { $corr->{'feature_id'} } = $corr->{'feature_correspondence_id'};

        push @{ $correspondence_evidence
                ->{ $corr->{'feature_correspondence_id'} } },
            {
            evidence_type_acc => $corr->{'evidence_type_acc'},
            evidence_type     => $corr->{'evidence_type'},
            evidence_rank     => $corr->{'evidence_rank'},
            line_color        => $corr->{'line_color'},
            line_type         => $corr->{'line_type'},
            };
    }

}

# ----------------------------------------------------

=pod
    
=head2 get_intraslot_correspondences

inserts correspondence info into $intraslot_correspondence and 
$correspondence_evidence based on corrs from the slot

This is basically the same as get_feature_correspondences (but with the
intraslot value) but I am keeping it separate in case we decide to make it
fancier.

=cut

sub get_intraslot_correspondences {

    my ($self,                        $intraslot_correspondences,
        $correspondence_evidence,     $slot_no,
        $included_evidence_type_accs, $ignored_evidence_type_accs,
        $less_evidence_type_accs,     $greater_evidence_type_accs,
        $evidence_type_score,         $feature_type_accs
    ) = @_;

    my $ref_correspondences = $self->sql->get_feature_correspondences_by_maps(
        ref_map_info                => $self->slot_info->{$slot_no},
        included_evidence_type_accs => $included_evidence_type_accs,
        less_evidence_type_accs     => $less_evidence_type_accs,
        greater_evidence_type_accs  => $greater_evidence_type_accs,
        evidence_type_score         => $evidence_type_score,
        feature_type_accs           => $feature_type_accs,
        intraslot                   => 1,
    );

    for my $corr ( @{$ref_correspondences} ) {
        $intraslot_correspondences->{ $corr->{'feature_id'} }
            { $corr->{'ref_feature_id'} }
            = $corr->{'feature_correspondence_id'};

        $intraslot_correspondences->{ $corr->{'ref_feature_id'} }
            { $corr->{'feature_id'} } = $corr->{'feature_correspondence_id'};

        push @{ $correspondence_evidence
                ->{ $corr->{'feature_correspondence_id'} } },
            {
            evidence_type_acc => $corr->{'evidence_type_acc'},
            evidence_type     => $corr->{'evidence_type'},
            evidence_rank     => $corr->{'evidence_rank'},
            line_color        => $corr->{'line_color'},
            };
    }

}

# ----------------------------------------------------
sub matrix_correspondence_data {

=pod

=head2 matrix_data

Returns the data for the correspondence matrix.

=cut

    my ( $self, %args ) = @_;
    my $species_acc      = $args{'species_acc'}      || '';
    my $map_type_acc     = $args{'map_type_acc'}     || '';
    my $map_set_acc      = $args{'map_set_acc'}      || '';
    my $map_name         = $args{'map_name'}         || '';
    my $hide_empty_rows  = $args{'hide_empty_rows'}  || '';
    my $link_map_set_acc = $args{'link_map_set_acc'} || 0;
    my $sql_object = $self->sql or return;

    #
    # Get all the species.
    #
    my $species = $sql_object->get_species(
        is_relational_map => 0,
        is_enabled        => 1,
    );

    #
    # And map types.
    #
    my $map_types = $sql_object->get_used_map_types(
        is_relational_map => 0,
        is_enabled        => 1,
    );

    unless ( $args{'show_matrix'} ) {
        return {
            species_acc => $species_acc,
            map_types   => $map_types,
            species     => $species,
        };
    }

    #
    # Make sure that species_acc is set if map_set_id is.
    #
    if ( $map_set_acc && !$species_acc ) {
        $species_acc
            = $sql_object->get_species_acc( map_set_acc => $map_set_acc, );
    }

    #
    # Make sure that map_type_acc is set if map_set_id is.
    #
    if ( $map_set_acc && !$map_type_acc ) {
        $map_type_acc
            = $sql_object->get_map_type_acc( map_set_acc => $map_set_acc, );
    }

    #
    # Get all the map sets for a given species and/or map type.
    #
    my ( $maps, $map_sets );
    if ( $species_acc || $map_type_acc ) {

        $map_sets = $sql_object->get_map_sets(
            species_acc       => $species_acc,
            map_type_acc      => $map_type_acc,
            is_relational_map => 0,
            is_enabled        => 1,
        );

        $maps = $sql_object->get_maps(
            is_relational_map => 0,
            is_enabled        => 1,
            map_type_acc      => $map_type_acc,
            species_acc       => $species_acc,
            map_set_acc       => $map_set_acc,
        );
    }

    #
    # Select all the map sets for the left-hand column
    # (those which can be reference sets).
    #
    my @reference_map_sets = ();
    if ($map_set_acc) {

        my $tempMapSet = $sql_object->get_maps(
            is_enabled  => 1,
            map_set_acc => $map_set_acc,
            map_name    => $map_name,
        );

        @reference_map_sets = @$tempMapSet;
    }
    else {

        my $tempMapSet;
        if ($map_name) {

            $tempMapSet = $sql_object->get_maps(
                is_enabled        => 1,
                is_relational_map => 0,
                map_type_acc      => $map_type_acc,
                species_acc       => $species_acc,
                map_set_acc       => $map_set_acc,
                map_name          => $map_name,
            );
        }
        else {

            $tempMapSet = $sql_object->get_map_sets(
                map_set_acc       => $map_set_acc,
                species_acc       => $species_acc,
                map_type_acc      => $map_type_acc,
                is_relational_map => 0,
                is_enabled        => 1,
            );
        }

        @reference_map_sets = @{
            sort_selectall_arrayref(
                $tempMapSet,           '#map_type_display_order',
                'map_type',            '#species_display_order',
                'species_common_name', '#map_set_display_order',
                'map_set_short_name',  'epoch_published_on desc',
            )
            };
    }

    #
    # Select the relationships from the pre-computed table.
    # If there's a map_set_id, then we should break down the
    # results by map, else we sum it all up on map set ids.
    # If there's both a map_set_id and a link_map_set_id, then we should
    # break down the results by map by map, else we sum it
    # all up on map set ids.
    #
    my $select_sql;

    my $data = $sql_object->get_matrix_relationships(
        map_set_acc      => $map_set_acc,
        link_map_set_acc => $link_map_set_acc,
        species_acc      => $species_acc,
        map_name         => $map_name,
    );

    #
    # Create a lookup hash from the data.
    #
    my %lookup;
    for my $hr (@$data) {
        if ( $map_set_acc && $link_map_set_acc ) {

            #
            # Map sets that can't be references won't have a "link_map_id."
            #
            my $link_acc = $hr->{'link_map_acc'}
                || $hr->{'link_map_set_acc'};
            $lookup{ $hr->{'reference_map_acc'} }{$link_acc}[0]
                = $hr->{'correspondences'};
            $lookup{ $hr->{'reference_map_acc'} }{$link_acc}[1]
                = $hr->{'map_count'};
        }
        elsif ($map_set_acc) {
            $lookup{ $hr->{'reference_map_acc'} }{ $hr->{'link_map_set_acc'} }
                [0] = $hr->{'correspondences'};
            $lookup{ $hr->{'reference_map_acc'} }{ $hr->{'link_map_set_acc'} }
                [1] = $hr->{'map_count'};
        }
        else {
            $lookup{ $hr->{'reference_map_set_acc'} }
                { $hr->{'link_map_set_acc'} }[0] = $hr->{'correspondences'};
            $lookup{ $hr->{'reference_map_set_acc'} }
                { $hr->{'link_map_set_acc'} }[1] = $hr->{'map_count'};
        }
    }

    #
    # Select ALL the map sets to go across.
    #

    my $link_map_can_be_reference;
    if ($link_map_set_acc) {

        my $map_sets = $sql_object->get_map_sets_simple(
            map_set_acc => $link_map_set_acc, );
        my $is_rel;
        $is_rel = $map_sets->[0]{'is_relational_map'} if $map_sets;

        $link_map_can_be_reference = ( !$is_rel );
    }

    #
    # If given a map set id for a map set that can be a reference map,
    # select the individual map.  Otherwise, if given a map set id for
    # a map set that can't be a reference or if given nothing, grab
    # the entire map set.
    #
    my $link_map_set_sql;
    my $tempMapSet;
    if (   $map_set_acc
        && $link_map_set_acc
        && $link_map_can_be_reference )
    {

        $tempMapSet = $sql_object->get_maps(
            is_enabled  => 1,
            map_set_acc => $link_map_set_acc,
        );
    }
    else {

        $tempMapSet = $sql_object->get_map_sets(
            map_set_acc => $link_map_set_acc,
            is_enabled  => 1,
        );
    }

    my @all_map_sets = @$tempMapSet;

    #
    # Figure out the number by type and species.
    #
    my ( %no_by_type, %no_by_type_and_species );
    for my $map_set (@all_map_sets) {
        my $map_type_acc = $map_set->{'map_type_acc'};
        my $species_acc  = $map_set->{'species_acc'};

        $no_by_type{$map_type_acc}++;
        $no_by_type_and_species{$map_type_acc}{$species_acc}++;
    }

    #
    # The top row of the table is a listing of all the map sets.
    #
    my $top_row = {
        no_by_type             => \%no_by_type,
        no_by_type_and_species => \%no_by_type_and_species,
        map_sets               => \@all_map_sets
    };

    #
    # Fill in the matrix with the reference set and all it's correspondences.
    # Herein lies madness.
    #
    my ( @matrix, %no_ref_by_species_and_type, %no_ref_by_type );
    my %empty_map_sets;
    for my $map_set (@reference_map_sets) {
        my $r_map_acc      = $map_set->{'map_acc'} || '';
        my $r_map_set_acc  = $map_set->{'map_set_acc'};
        my $r_map_type_acc = $map_set->{'map_type_acc'};
        my $r_species_acc  = $map_set->{'species_acc'};
        my $reference_acc
            = $map_name && $map_set_acc ? $r_map_acc
            : $map_name ? $r_map_set_acc
            :             $r_map_acc || $r_map_set_acc;

        my $found_non_zero = 0;
        for my $comp_map_set (@all_map_sets) {
            my $comp_map_set_acc = $comp_map_set->{'map_set_acc'};
            my $comp_map_acc     = $comp_map_set->{'map_acc'} || '';
            my $comparative_acc  = $comp_map_acc || $comp_map_set_acc;
            my $correspondences;
            my $map_count;
            if (   $r_map_acc
                && $comp_map_acc
                && $r_map_acc eq $comp_map_acc )
            {
                $correspondences = 'N/A';
                $map_count       = 'N/A';
            }
            else {
                $found_non_zero
                    ||= $lookup{$reference_acc}{$comparative_acc}[0];
                $correspondences
                    = $lookup{$reference_acc}{$comparative_acc}[0]
                    || 0;
                $map_count = $lookup{$reference_acc}{$comparative_acc}[1]
                    || 0;
            }

            push @{ $map_set->{'correspondences'} },
                {
                map_set_acc => $comp_map_set_acc,
                map_acc     => $comp_map_acc,
                number      => $correspondences,
                map_count   => $map_count,
                };
        }
        if ( $found_non_zero or !$hide_empty_rows ) {
            push @matrix, $map_set;
            $no_ref_by_type{$r_map_type_acc}++;
            $no_ref_by_species_and_type{$r_species_acc}{$r_map_type_acc}++;
        }
        else {
            $empty_map_sets{$r_map_set_acc} = 1;
        }
    }

    if ($hide_empty_rows) {
        my %found_column_value;
        my $key_separator = " ";
        for ( my $i = 0; $i <= $#matrix; $i++ ) {
            my $found_non_zero = 0;
            foreach my $corr ( @{ $matrix[$i]->{'correspondences'} } ) {
                if ( $corr->{'number'} ) {
                    $found_column_value{ $corr->{'map_set_acc'}
                            . $key_separator
                            . $corr->{'map_acc'} } = 1;
                }
            }

        }

        # remove empty columns from @matrix
        for ( my $i = 0; $i <= $#matrix; $i++ ) {
            for (
                my $j = 0;
                $j <= $#{ $matrix[$i]->{'correspondences'} };
                $j++
                )
            {
                unless (
                    $found_column_value{
                        $matrix[$i]->{'correspondences'}[$j]{'map_set_acc'}
                            . $key_separator
                            . $matrix[$i]->{'correspondences'}[$j]{'map_acc'}
                    }
                    )
                {
                    splice( @{ $matrix[$i]->{'correspondences'} }, $j, 1 );
                    $j--;
                }
            }
        }

        # remove empty columns from $top_row
        for ( my $i = 0; $i <= $#{ $top_row->{'map_sets'} }; $i++ ) {
            unless (
                $found_column_value{
                          $top_row->{'map_sets'}[$i]{'map_set_acc'}
                        . $key_separator
                        . ( $top_row->{'map_sets'}[$i]{'map_acc'} || '' )
                }
                )
            {
                my $map_type_acc = $top_row->{'map_sets'}[$i]{'map_type_acc'};
                my $species_acc  = $top_row->{'map_sets'}[$i]{'species_acc'};
                $top_row->{'no_by_type'}{$map_type_acc}--;
                $top_row->{'no_by_type_and_species'}{$map_type_acc}
                    {$species_acc}--;
                splice( @{ $top_row->{'map_sets'} }, $i, 1 );
                $i--;
            }
        }
    }

    my $matrix_data = {
        data                   => \@matrix,
        no_by_type             => \%no_ref_by_type,
        no_by_species_and_type => \%no_ref_by_species_and_type,
    };

    return {
        top_row      => $top_row,
        species_acc  => $species_acc,
        map_set_acc  => $map_set_acc,
        map_type_acc => $map_type_acc,
        map_name     => $map_name,
        matrix       => $matrix_data,
        data         => $data,
        species      => $species,
        map_sets     => $map_sets,
        map_types    => $map_types,
        maps         => $maps,
    };
}

# ----------------------------------------------------

=pod

=head2 cmap_form_data

Returns the data for the main comparative map HTML form.

=cut

sub cmap_form_data {

    my ( $self, %args ) = @_;
    my $slots = $args{'slots'} or return;
    my $menu_min_corrs              = $args{'menu_min_corrs'}          || 0;
    my $feature_type_accs           = $args{'included_feature_types'}  || [];
    my $ignored_feature_type_accs   = $args{'ignored_feature_types'}   || [];
    my $included_evidence_type_accs = $args{'included_evidence_types'} || [];
    my $ignored_evidence_type_accs  = $args{'ignored_evidence_types'}  || [];
    my $less_evidence_type_accs     = $args{'less_evidence_types'}     || [];
    my $greater_evidence_type_accs  = $args{'greater_evidence_types'}  || [];
    my $evidence_type_score         = $args{'evidence_type_score'}     || {};
    my $ref_species_acc             = $args{'ref_species_acc'}         || '';
    my $ref_slot_data               = $args{'ref_slot_data'}           || {};
    my $ref_map                     = $slots->{0};
    my $ref_map_set_acc             = $args{'ref_map_set_acc'}         || 0;
    my $flip_list                   = $args{'flip_list'}               || [];
    my $sql_object = $self->sql or return;

    my $pid = $$;

    my @ref_maps = ();

    if ( @{ $self->sorted_map_ids(0) } ) {
        foreach my $map_id ( @{ $self->sorted_map_ids(0) } ) {
            my %temp_hash = (
                'map_id'    => $map_id,
                'map_acc'   => $ref_slot_data->{$map_id}{'map_acc'},
                'map_name'  => $ref_slot_data->{$map_id}{'map_name'},
                'map_start' => $self->slot_info->{0}{$map_id}[0],
                'map_stop'  => $self->slot_info->{0}{$map_id}[1],
            );
            push @ref_maps, \%temp_hash;
        }
    }

    my $sql_str;
    if ( $ref_map_set_acc && !$ref_species_acc ) {

        $ref_species_acc
            = $sql_object->get_species_acc( map_set_acc => $ref_map_set_acc,
            );
    }

    #
    # Select all the map set that can be reference maps.
    #

    my $ref_species = $sql_object->get_species(
        is_relational_map => 0,
        is_enabled        => 1,
    );

    #
    # Select all the map set that can be reference maps.
    #
    my $ref_map_sets = [];
    if ($ref_species_acc) {

        $ref_map_sets = $sql_object->get_map_sets(
            species_acc       => $ref_species_acc,
            is_relational_map => 0,
            is_enabled        => 1,
        );
    }

    #
    # If there's only one map set, pretend it was submitted.
    #
    if ( !$ref_map_set_acc && scalar @$ref_map_sets == 1 ) {
        $ref_map_set_acc = $ref_map_sets->[0]{'map_set_acc'};
    }

    #
    # If the user selected a map set, select all the maps in it.
    #
    my ( $ref_maps, $ref_map_set_info );

    if ($ref_map_set_acc) {
        unless ( ( $ref_map->{'maps'} and %{ $ref_map->{'maps'} } )
            or ( $ref_map->{'map_sets'} and %{ $ref_map->{'map_sets'} } ) )
        {

            $ref_maps = $sql_object->get_maps_from_map_set(
                map_set_acc => $ref_map_set_acc, );
            $self->error(
                qq[No maps exist for the ref. map set acc. id "$ref_map_set_acc"]
            ) unless @$ref_maps;
        }

        unless (@ref_maps) {

            my $tempMapSet
                = $sql_object->get_map_sets( map_set_acc => $ref_map_set_acc,
                );
            $ref_map_set_info = $tempMapSet->[0];

            $ref_map_set_info->{'attributes'} = $sql_object->get_attributes(
                object_type => 'map_set',
                object_id   => $ref_map_set_info->{'map_set_id'},
            );
            $ref_map_set_info->{'xrefs'} = $sql_object->get_xrefs(
                object_type => 'map_set',
                object_id   => $ref_map_set_info->{'map_set_id'},
            );
        }
    }

    my @slot_nos = sort { $a <=> $b } keys %$slots;

    #
    # Correspondence evidence types.
    #
    my @evidence_types = @{
        $self->fake_selectall_arrayref(
            $self->evidence_type_data(), 'evidence_type_acc',
            'evidence_type'
        )
        };

    #
    # Fill out all the info we have on every map.
    #
    my $slot_info;
    if ( scalar @ref_maps >= 1 ) {
        $slot_info = $self->fill_out_slots( $slots, $flip_list, );
    }

    return {
        ref_species_acc  => $ref_species_acc,
        ref_species      => $ref_species,
        ref_map_sets     => $ref_map_sets,
        ref_map_set_acc  => $ref_map_set_acc,
        ref_maps         => $ref_maps,
        ordered_ref_maps => \@ref_maps,
        ref_map_set_info => $ref_map_set_info,
        slot_info        => $slot_info,
        evidence_types   => \@evidence_types,
    };
}

# ----------------------------------------------------

=pod

=head2 correspondence_form_data

Returns the data for the main comparative map HTML form.

=cut

sub correspondence_form_data {

    my ( $self, %args ) = @_;
    my $slots = $args{'slots'} or return;
    my $menu_min_corrs = $args{'menu_min_corrs'} || 0;
    my $url_feature_default_display = $args{'url_feature_default_display'}
        || q{};
    my $included_feature_type_accs  = $args{'included_feature_types'}  || [];
    my $ignored_feature_type_accs   = $args{'ignored_feature_types'}   || [];
    my $corr_only_feature_type_accs = $args{'corr_only_feature_types'} || [];
    my $included_evidence_type_accs = $args{'included_evidence_types'} || [];
    my $ignored_evidence_type_accs  = $args{'ignored_evidence_types'}  || [];
    my $less_evidence_type_accs     = $args{'less_evidence_types'}     || [];
    my $greater_evidence_type_accs  = $args{'greater_evidence_types'}  || [];
    my $evidence_type_score         = $args{'evidence_type_score'}     || {};
    my $slot_min_corrs              = $args{'slot_min_corrs'}          || {};
    my $side                        = $args{'side'}                    || q{};

    $self->fill_type_arrays(
        ref_map_set_acc             => $slots->{0}{'map_set_acc'},
        included_feature_type_accs  => $included_feature_type_accs,
        corr_only_feature_type_accs => $corr_only_feature_type_accs,
        ignored_feature_type_accs   => $ignored_feature_type_accs,
        url_feature_default_display => $url_feature_default_display,
        ignored_evidence_type_accs  => $ignored_evidence_type_accs,
        included_evidence_type_accs => $included_evidence_type_accs,
        less_evidence_type_accs     => $less_evidence_type_accs,
        greater_evidence_type_accs  => $greater_evidence_type_accs,
    );
    $self->slot_info(
        $slots,                       $ignored_feature_type_accs,
        $included_evidence_type_accs, $less_evidence_type_accs,
        $greater_evidence_type_accs,  $evidence_type_score,
        $slot_min_corrs,
    ) or return;

    my $comp_maps;
    my @slot_nos = sort { $a <=> $b } keys %$slots;
    if ( $self->slot_info and @slot_nos ) {
        $comp_maps = $self->get_comparative_maps(
            min_correspondences         => $menu_min_corrs,
            feature_type_accs           => $included_feature_type_accs,
            ignored_feature_type_accs   => $ignored_feature_type_accs,
            included_evidence_type_accs => $included_evidence_type_accs,
            ignored_evidence_type_accs  => $ignored_evidence_type_accs,
            less_evidence_type_accs     => $less_evidence_type_accs,
            greater_evidence_type_accs  => $greater_evidence_type_accs,
            evidence_type_score         => $evidence_type_score,
            ref_slot_no => lc($side) eq 'left' ? $slot_nos[0] : $slot_nos[-1],
        );
    }

    return { comp_maps => $comp_maps, };
}

# ----------------------------------------------------
sub get_comparative_maps {

=pod

=head2 get_comparative_maps

Given a reference map and (optionally) start and stop positions, figure
out which maps have relationships.

=cut

    my ( $self, %args ) = @_;
    my $min_correspondences         = $args{'min_correspondences'};
    my $feature_type_accs           = $args{'feature_type_accs'};
    my $ignored_feature_type_accs   = $args{'ignored_feature_type_accs'};
    my $included_evidence_type_accs = $args{'included_evidence_type_accs'};
    my $ignored_evidence_type_accs  = $args{'ignored_evidence_type_accs'};
    my $less_evidence_type_accs     = $args{'less_evidence_type_accs'};
    my $greater_evidence_type_accs  = $args{'greater_evidence_type_accs'};
    my $evidence_type_score         = $args{'evidence_type_score'};
    my $ref_slot_no                 = $args{'ref_slot_no'};
    my $sql_object                  = $self->sql or return;
    return unless defined $ref_slot_no;

    my $feature_correspondences
        = $sql_object->get_comparative_maps_with_count(
        slot_info                   => $self->slot_info->{$ref_slot_no},
        included_evidence_type_accs => $included_evidence_type_accs,
        ignored_evidence_type_accs  => $ignored_evidence_type_accs,
        less_evidence_type_accs     => $less_evidence_type_accs,
        greater_evidence_type_accs  => $greater_evidence_type_accs,
        evidence_type_score         => $evidence_type_score,
        ignored_feature_type_accs   => $ignored_feature_type_accs,
        include_map1_data           => 0,
        );

    #
    # Gather info on the maps and map sets.
    #
    my %map_set_ids
        = map { $_->{'map_set_id2'}, 1 } @$feature_correspondences;

    my ( %map_sets, %comp_maps );
    for my $map_set_id ( keys %map_set_ids ) {
        my $tempMapSet
            = $sql_object->get_map_sets( map_set_id => $map_set_id, );
        my $ms_info = $tempMapSet->[0];
        $map_sets{ $ms_info->{'map_set_acc'} } = $ms_info;
    }
    if (@$feature_correspondences) {
        my $maps
            = $sql_object->get_maps(
            map_ids => [ map { $_->{'map_id2'} } @$feature_correspondences ],
            );
        for my $map (@$maps) {
            $comp_maps{ $map->{'map_id'} } = $map;
        }
    }
    for my $fc (@$feature_correspondences) {
        my $map_id2 = $fc->{'map_id2'};
        next unless ( $comp_maps{$map_id2} );

        $comp_maps{$map_id2}->{'no_correspondences'} += $fc->{'no_corr'};
        $comp_maps{$map_id2}->{'max_no_correspondences'} = $fc->{'no_corr'}
            if ( !$comp_maps{$map_id2}->{'max_no_correspondences'}
            or $comp_maps{$map_id2}->{'max_no_correspondences'}
            < $fc->{'no_corr'} );
    }
    for my $comp_map ( values(%comp_maps) ) {
        my $ref_map_set_acc = $comp_map->{'map_set_acc'} or next;

        push @{ $map_sets{$ref_map_set_acc}{'maps'} }, $comp_map;
    }

    #
    # Sort the map sets and maps for display, count up correspondences.
    #
    my @sorted_map_sets;
    for my $map_set (
        sort {
            $a->{'map_type_display_order'} <=> $b->{'map_type_display_order'}
                || $a->{'map_type'} cmp $b->{'map_type'}
                || $a->{'species_display_order'} <=> $b->{
                'species_display_order'}
                || $a->{'species_common_name'} cmp $b->{'species_common_name'}
                || $a->{'ms_display_order'} <=> $b->{'ms_display_order'}
                || $b->{'published_on'} <=> $a->{'published_on'}
                || $a->{'map_set_name'} cmp $b->{'map_set_name'}
        } values %map_sets
        )
    {
        my @maps;    # the maps for the map set
        my $total_corrs = 0;    # all the correspondences for the map set
        my $total_maps  = 0;    # all the matching maps in the map set

        my $display_order_sort = sub {
            $a->{'display_order'} <=> $b->{'display_order'}
                || $a->{'map_name'} cmp $b->{'map_name'};
        };
        my $no_corr_sort = sub {
            $b->{'no_correspondences'} <=> $a->{'no_correspondences'}
                || $a->{'display_order'} <=> $b->{'display_order'}
                || $a->{'map_name'} cmp $b->{'map_name'};
        };

        my $sort_sub;
        if ( $self->comp_menu_order eq 'corrs' ) {
            $sort_sub = $no_corr_sort;
        }
        else {
            $sort_sub = $display_order_sort;
        }

        for my $map ( sort $sort_sub @{ $map_set->{'maps'} || [] } ) {
            next
                if $min_correspondences
                    && $map->{'max_no_correspondences'}
                    < $min_correspondences;

            $total_corrs += $map->{'no_correspondences'};
            $total_maps++;
            push @maps, $map if not $map_set->{'is_relational_map'};
        }

        next unless $total_corrs;
        next if ( !@maps and not $map_set->{'is_relational_map'} );

        push @sorted_map_sets,
            {
            map_type            => $map_set->{'map_type'},
            species_common_name => $map_set->{'species_common_name'},
            map_set_name        => $map_set->{'map_set_name'},
            map_set_short_name  => $map_set->{'map_set_short_name'},
            map_set_acc         => $map_set->{'map_set_acc'},
            no_correspondences  => $total_corrs,
            map_count           => $total_maps,
            maps                => \@maps,
            };
    }

    return \@sorted_map_sets;
}

# ----------------------------------------------------
sub feature_alias_detail_data {

=pod

=head2 feature_alias_detail_data

Returns the data for the feature alias detail page.

=cut

    my ( $self, %args ) = @_;
    my $feature_acc = $args{'feature_acc'}
        or return $self->error('No feature acc. id');
    my $feature_alias = $args{'feature_alias'}
        or return $self->error('No feature alias');

    my $sql_object = $self->sql;

    my $alias_array = $sql_object->get_feature_aliases(
        feature_acc => $feature_acc,
        alias       => $feature_alias,
    ) or return $self->error('No alias');
    my $alias = $alias_array->[0];

    $alias->{'object_id'}  = $alias->{'feature_alias_id'};
    $alias->{'attributes'} = $self->sql->get_attributes(
        object_type => 'feature_alias',
        object_id   => $alias->{'feature_alias_id'},
    );
    $self->get_multiple_xrefs(
        object_type => 'feature_alias',
        objects     => [$alias],
    );

    return $alias;
}

# ----------------------------------------------------
sub feature_correspondence_data {

=pod

=head2 feature_correspondence_data

Retrieve the data for a feature correspondence.

=cut

    my ( $self, %args ) = @_;
    my $feature_correspondence_id = $args{'feature_correspondence_id'}
        or return;
}

# ----------------------------------------------------

=pod

=head2 fill_out_slots

Gets the names, IDs, etc., of the maps in the slots.

Returns:

  [   
    {   map_set_acc       => $map_set_acc,
        species_acc       => $species_acc,
        description       => $description,
        min_corrs         => $min_corrs,
        stack_slot        => $stack_slot,
        is_reference_slot => $is_reference_slot,
        slot_no           => $slot_no,
        maps              => {
            $map_acc => {
                map_order     => $map_order,
                map_name      => $map_name,
                ori_map_start => $ori_map_start,
                ori_map_stop  => $ori_map_stop,
                start         => $start,
                stop          => $stop,
                flip          => $flip,
                bgcolor       => $bgcolor,
            },
        },
    },
  ]

=cut

sub fill_out_slots {

    my $self             = shift;
    my $slots            = shift;
    my $flip_list        = shift || [];
    my $sql_object       = $self->sql or return;
    my @ordered_slot_nos = sort { $a <=> $b } keys %$slots;

    my %flip_hash;
    foreach my $row ( @{$flip_list} ) {
        $flip_hash{ $row->{'slot_no'} }->{ $row->{'map_acc'} } = 1;
    }

    my @filled_slots;

    my $menu_bgcolor_tint = $self->config_data('menu_bgcolor_tint')
        || 'lightgrey';
    my $menu_bgcolor = $self->config_data('menu_bgcolor')
        || 'white';
    my $menu_ref_bgcolor_tint = $self->config_data('menu_ref_bgcolor_tint')
        || 'aqua';
    my $menu_ref_bgcolor = $self->config_data('menu_ref_bgcolor')
        || 'lightblue';

    for my $i ( 0 .. $#ordered_slot_nos ) {
        my $filled_slot;
        my $slot_no   = $ordered_slot_nos[$i];
        my $slot_info = $self->slot_info->{$slot_no};
        my $map_sets  = $sql_object->get_map_set_info_by_maps(
            map_ids => [ keys(%$slot_info) ], );
        my %desc_by_species;
        foreach my $row (@$map_sets) {
            $filled_slot->{'map_set_acc'} = $row->{'map_set_acc'};
            $filled_slot->{'species_acc'} = $row->{'species_acc'};
            if ( $desc_by_species{ $row->{'species_common_name'} } ) {
                $desc_by_species{ $row->{'species_common_name'} }
                    .= "," . $row->{'map_set_short_name'};
            }
            else {
                $desc_by_species{ $row->{'species_common_name'} }
                    .= $row->{'species_common_name'} . "-"
                    . $row->{'map_set_short_name'};
            }
        }
        $filled_slot->{'description'} = join( ";",
            map { $desc_by_species{$_} } keys(%desc_by_species) );
        $filled_slot->{'min_corrs'}  = $slots->{$slot_no}->{'min_corrs'};
        $filled_slot->{'stack_slot'} = $slots->{$slot_no}->{'stack_slot'};

        if ( $slot_no == 0 ) {
            $filled_slot->{'is_reference_slot'} = 1;
        }
        $filled_slot->{'slot_no'} = $slot_no;
        $filled_slot->{'maps'}    = $slots->{$slot_no}{'maps'};

        # Get map information for each map
        my @map_accs = keys %{ $filled_slot->{'maps'} || {} };
        if (@map_accs) {

            my $maps = $sql_object->get_maps( map_accs => \@map_accs, );
            $maps = sort_selectall_arrayref( $maps, '#display_order',
                'map_name', 'map_acc' );
            my $grey_cell = 0;
            foreach my $map ( @{ $maps || [] } ) {
                my $map_acc = $map->{'map_acc'};
                push @{ $filled_slot->{'map_order'} }, $map_acc;
                $filled_slot->{'maps'}{$map_acc}{'map_name'}
                    = $map->{'map_name'};
                $filled_slot->{'maps'}{$map_acc}{'ori_map_start'}
                    = $map->{'map_start'};
                $filled_slot->{'maps'}{$map_acc}{'ori_map_stop'}
                    = $map->{'map_stop'};
                unless ( defined $filled_slot->{'maps'}{$map_acc}{'start'} ) {
                    $filled_slot->{'maps'}{$map_acc}{'start'}
                        = $map->{'map_start'};
                }
                unless ( defined $filled_slot->{'maps'}{$map_acc}{'stop'} ) {
                    $filled_slot->{'maps'}{$map_acc}{'stop'}
                        = $map->{'map_stop'};
                }
                $filled_slot->{'maps'}{$map_acc}{'flip'}
                    = ( $flip_hash{$slot_no}->{$map_acc} ) ? 1 : 0;
                if ($slot_no) {
                    if ($grey_cell) {
                        $filled_slot->{'maps'}{$map_acc}{'bgcolor'}
                            = $menu_bgcolor_tint;
                        $grey_cell = 0;
                    }
                    else {
                        $filled_slot->{'maps'}{$map_acc}{'bgcolor'}
                            = $menu_bgcolor;
                        $grey_cell = 1;
                    }
                }
                else {
                    if ($grey_cell) {
                        $filled_slot->{'maps'}{$map_acc}{'bgcolor'}
                            = $menu_ref_bgcolor_tint;
                        $grey_cell = 0;
                    }
                    else {
                        $filled_slot->{'maps'}{$map_acc}{'bgcolor'}
                            = $menu_ref_bgcolor;
                        $grey_cell = 1;
                    }
                }
            }
        }

        push @filled_slots, $filled_slot;
    }

    return \@filled_slots;
}

# ----------------------------------------------------
sub feature_detail_data {

=pod

=head2 feature_detail_data

Given a feature acc. id, find out all the details on it.

=cut

    my ( $self, %args ) = @_;
    my $feature_acc = $args{'feature_acc'} or die 'No accession id';
    my $sql_object  = $self->sql           or return;

    my $feature_array
        = $sql_object->get_features( feature_acc => $feature_acc, );
    my $feature = $feature_array->[0];
    return $self->error(
        "Feature acc: $feature_acc, is not a valid feature accession.")
        unless ( defined($feature) and %$feature );

    $feature->{'object_id'}  = $feature->{'feature_id'};
    $feature->{'attributes'} = $self->sql->get_attributes(
        object_type => 'feature',
        object_id   => $feature->{'feature_id'},
    );

    my $correspondences = $sql_object->get_feature_correspondence_details(
        feature_id1             => $feature->{'feature_id'},
        disregard_evidence_type => 1,
    );

    my $last_corr_id = 0;
    for ( my $i = 0; $i <= $#{$correspondences}; $i++ ) {
        my $corr = $correspondences->[$i];
        if ( $last_corr_id == $corr->{'feature_correspondence_id'} ) {
            splice @$correspondences, $i, 1;
            $i--;
            next;
        }
        $last_corr_id = $corr->{'feature_correspondence_id'};

        $corr->{'evidence'}
            = $sql_object->get_correspondence_evidences(
            feature_correspondence_id => $corr->{'feature_correspondence_id'},
            );
        $corr->{'evidence'}
            = sort_selectall_arrayref( $corr->{'evidence'}, '#rank',
            'evidence_type' );

        my $aliases = $sql_object->get_feature_aliases(
            feature_id => $corr->{'feature_id2'}, );
        $corr->{'aliases'} = [ map { $_->{'alias'} } @$aliases ];
    }

    $feature->{'correspondences'} = $correspondences;

    $self->get_multiple_xrefs(
        object_type => 'feature',
        objects     => [$feature],
    );

    return $feature;
}

# ----------------------------------------------------
sub link_viewer_data {

=pod

=head2 link_viewer_data

Given a list of feature names, find any maps they occur on.

=cut

    my ( $self, %args ) = @_;
    my $selected_link_set = $args{'selected_link_set'};

    my $link_manager = Bio::GMOD::CMap::Admin::ManageLinks->new(
        config      => $self->config,
        data_source => $self->data_source
    );

    my @link_set_names = $link_manager->list_set_names(
        name_space => $self->get_link_name_space );

    my @links = $link_manager->output_links(
        name_space    => $self->get_link_name_space,
        link_set_name => $selected_link_set,
    );

    return {
        links     => \@links,
        link_sets => \@link_set_names,
    };
}

# ----------------------------------------------------
sub feature_search_data {

=pod

=head2 feature_search_data

Given a list of feature names, find any maps they occur on.

=cut

    my ( $self, %args ) = @_;
    my $species_accs               = $args{'species_accs'};
    my $incoming_feature_type_accs = $args{'feature_type_accs'};
    my $feature_string             = $args{'features'};
    my $page_data                  = $args{'page_data'};
    my $page_size                  = $args{'page_size'};
    my $page_no                    = $args{'page_no'};
    my $pages_per_set              = $args{'pages_per_set'};
    my $feature_type_data          = $self->feature_type_data();
    my $sql_object                 = $self->sql or return;
    my @feature_names              = (
        map {
            s/\*/%/g;          # turn stars into SQL wildcards
            s/,//g;            # remove commas
            s/^\s+|\s+$//g;    # remove leading/trailing whitespace
            s/"//g;            # remove double quotes"
            s/'/\\'/g;         # backslash escape single quotes
            $_ || ()
            } parse_words($feature_string)
    );
    my $order_by = $args{'order_by'}
        || 'feature_name,species_common_name,map_set_name,map_name,feature_start';
    my $search_field = $args{'search_field'}
        || $self->config_data('feature_search_field');
    $search_field = DEFAULT->{'feature_search_field'}
        unless VALID->{'feature_search_field'}{$search_field};

    #
    # We'll get the feature ids first.  Use "like" in case they've
    # included wildcard searches.
    #
    my %features = ();
    for my $feature_name (@feature_names) {

        my $features = $sql_object->get_features(
            feature_type_accs => $incoming_feature_type_accs,
            species_accs      => $species_accs,
            $search_field     => $feature_name,
            aliases_get_rows  => 1,
        );

        for my $f (@$features) {
            $features{ $f->{'feature_id'} } = $f;
        }
    }

    #
    # Perform sort on accumulated results.
    #
    my @found_features = ();
    if ( $order_by eq 'feature_start' ) {
        @found_features = map { $_->[1] }
            sort { $a->[0] <=> $b->[0] }
            map { [ $_->{$order_by}, $_ ] } values %features;
    }
    else {
        my @sort_fields = split( /,/, $order_by );
        @found_features = map { $_->[1] }
            sort { $a->[0] cmp $b->[0] }
            map { [ join( '', @{$_}{@sort_fields} ), $_ ] } values %features;
    }

    #
    # Page the data here so as to make the "IN" statement
    # below managable.
    #
    my $pager = Data::Pageset->new(
        {   total_entries    => scalar @found_features,
            entries_per_page => $page_size,
            current_page     => $page_no,
            pages_per_set    => $pages_per_set,
        }
    );

    if ( $page_data && @found_features ) {
        @found_features = $pager->splice( \@found_features );
    }

    my @feature_ids = map { $_->{'feature_id'} } @found_features;
    if (@feature_ids) {

        my $aliases
            = $sql_object->get_feature_aliases( feature_ids => \@feature_ids,
            );
        my %aliases;
        for my $alias (@$aliases) {
            push @{ $aliases{ $alias->{'feature_id'} } }, $alias->{'alias'};
        }

        for my $f (@found_features) {
            $f->{'aliases'} = [ sort { lc $a cmp lc $b }
                    @{ $aliases{ $f->{'feature_id'} } || [] } ];
        }
    }

    #
    # If no species was selected, then look at what's in the search
    # results so they can narrow down what they have.  If no search
    # results, then just show all.
    #
    my $species = $sql_object->get_species();

    #
    # Get the feature types.
    #
    my $feature_types
        = $self->fake_selectall_arrayref( $feature_type_data, 'feature_type',
        'feature_type_acc' );

    return {
        data          => \@found_features,
        species       => $species,
        feature_types => $feature_types,
        pager         => $pager,
    };
}

# ----------------------------------------------------
sub evidence_type_info_data {

=pod

=head2 evidence_type_info_data

Return data for a list of evidence type acc. IDs.

=cut

    my ( $self, %args ) = @_;

    my @return_array;

    my @evidence_types = keys( %{ $self->config_data('evidence_type') } );

    my $evidence_type_data = $self->evidence_type_data();
    my %supplied_evidence_types;
    if ( $args{'evidence_types'} ) {
        %supplied_evidence_types
            = map { $_ => 1 } @{ $args{'evidence_types'} };
    }
    foreach my $evidence_type (@evidence_types) {
        if (%supplied_evidence_types) {
            next unless ( $supplied_evidence_types{$evidence_type} );
        }
        my @attributes = ();
        my @xrefs      = ();

        # Get Attributes from config file
        my $configured_attributes
            = $evidence_type_data->{$evidence_type}{'attribute'};
        if ( ref($configured_attributes) ne 'ARRAY' ) {
            $configured_attributes = [ $configured_attributes, ];
        }
        foreach my $att (@$configured_attributes) {
            next
                unless ( defined( $att->{'name'} )
                and defined( $att->{'value'} ) );
            push @attributes,
                {
                attribute_name  => $att->{'name'},
                attribute_value => $att->{'value'},
                is_public       => defined( $att->{'is_public'} )
                ? $att->{'is_public'}
                : 1,
                };
        }

        # Get Xrefs from config file
        my $configured_xrefs = $evidence_type_data->{$evidence_type}{'xref'};
        if ( ref($configured_xrefs) ne 'ARRAY' ) {
            $configured_xrefs = [ $configured_xrefs, ];
        }
        foreach my $xref (@$configured_xrefs) {
            next
                unless ( defined( $xref->{'name'} )
                and defined( $xref->{'url'} ) );
            push @xrefs,
                {
                xref_name => $xref->{'name'},
                xref_url  => $xref->{'url'},
                };
        }

        $return_array[ ++$#return_array ] = {
            'evidence_type_acc' => $evidence_type,
            'evidence_type' =>
                $evidence_type_data->{$evidence_type}{'evidence_type'},
            'rank' => $evidence_type_data->{$evidence_type}{'rank'},
            'line_color' =>
                $evidence_type_data->{$evidence_type}{'line_color'},
            'attributes' => \@attributes,
            'xrefs'      => \@xrefs,
        };
    }
    my $default_color = $self->config_data('connecting_line_color');

    for my $ft (@return_array) {
        $ft->{'line_color'} ||= $default_color;
    }

    my $all_evidence_types
        = $self->fake_selectall_arrayref( $evidence_type_data,
        'evidence_type_acc', 'evidence_type' );
    $all_evidence_types
        = sort_selectall_arrayref( $all_evidence_types, 'evidence_type' );

    return {
        all_evidence_types => $all_evidence_types,
        evidence_types     => \@return_array,
        }

}

# ----------------------------------------------------
sub feature_type_info_data {

=pod

=head2 feature_type_info_data

Return data for a list of feature type acc. IDs.

=cut

    my ( $self, %args ) = @_;

    my @return_array;

    my @feature_types = keys( %{ $self->config_data('feature_type') } );

    my $feature_type_data = $self->feature_type_data();
    my %supplied_feature_types;
    if ( $args{'feature_types'} ) {
        %supplied_feature_types = map { $_ => 1 } @{ $args{'feature_types'} };
    }
    foreach my $feature_type (@feature_types) {
        if (%supplied_feature_types) {
            next unless ( $supplied_feature_types{$feature_type} );
        }
        my @attributes = ();
        my @xrefs      = ();

        # Get Attributes from config file
        my $configured_attributes
            = $feature_type_data->{$feature_type}{'attribute'};
        if ( ref($configured_attributes) ne 'ARRAY' ) {
            $configured_attributes = [ $configured_attributes, ];
        }
        foreach my $att (@$configured_attributes) {
            next
                unless ( defined( $att->{'name'} )
                and defined( $att->{'value'} ) );
            push @attributes,
                {
                attribute_name  => $att->{'name'},
                attribute_value => $att->{'value'},
                is_public       => defined( $att->{'is_public'} )
                ? $att->{'is_public'}
                : 1,
                };
        }

        # Get Xrefs from config file
        my $configured_xrefs = $feature_type_data->{$feature_type}{'xref'};
        if ( ref($configured_xrefs) ne 'ARRAY' ) {
            $configured_xrefs = [ $configured_xrefs, ];
        }
        foreach my $xref (@$configured_xrefs) {
            next
                unless ( defined( $xref->{'name'} )
                and defined( $xref->{'url'} ) );
            push @xrefs,
                {
                xref_name => $xref->{'name'},
                xref_url  => $xref->{'url'},
                };
        }

        $return_array[ ++$#return_array ] = {
            'feature_type_acc' => $feature_type,
            'feature_type' =>
                $feature_type_data->{$feature_type}{'feature_type'},
            'shape'      => $feature_type_data->{$feature_type}{'shape'},
            'color'      => $feature_type_data->{$feature_type}{'color'},
            'attributes' => \@attributes,
            'xrefs'      => \@xrefs,
        };
    }

    my $default_color = $self->config_data('feature_color');

    for my $ft (@return_array) {
        $ft->{'color'} ||= $default_color;
    }

    @return_array
        = sort { lc $a->{'feature_type'} cmp lc $b->{'feature_type'} }
        @return_array;

    my $all_feature_types
        = $self->fake_selectall_arrayref( $feature_type_data,
        'feature_type_acc', 'feature_type' );
    $all_feature_types
        = sort_selectall_arrayref( $all_feature_types, 'feature_type' );

    return {
        all_feature_types => $all_feature_types,
        feature_types     => \@return_array,
    };
}

# ----------------------------------------------------
sub map_set_viewer_data {

=pod

=head2 map_set_viewer_data

Returns the data for drawing comparative maps.

=cut

    my ( $self, %args ) = @_;
    my @map_set_accs = @{ $args{'map_set_accs'} || [] };
    my $species_acc  = $args{'species_acc'}  || 0;
    my $map_type_acc = $args{'map_type_acc'} || 0;
    my $sql_object = $self->sql or return;

    my $map_type_data = $self->map_type_data();
    for ( $species_acc, $map_type_acc ) {
        $_ = 0 if $_ == -1;
    }

    #
    # Map sets
    #
    my $map_sets = $sql_object->get_map_sets(
        map_set_accs => \@map_set_accs,
        species_acc  => $species_acc,
        map_type_acc => $map_type_acc,
    );

    #
    # Maps in the map sets
    #
    my $maps = $sql_object->get_maps(
        is_relational_map => 0,
        map_set_accs      => \@map_set_accs,
        species_acc       => $species_acc,
        map_type_acc      => $map_type_acc,
    );
    my %map_lookup;
    for my $map (@$maps) {
        push @{ $map_lookup{ $map->{'map_set_id'} } }, $map;
    }

    #
    # Attributes of the map sets
    #
    my $attributes = $sql_object->get_attributes(
        object_type => 'map_set',
        get_all     => 1,
        order_by    => ' object_id, display_order, attribute_name ',
    );
    my %attr_lookup;
    for my $attr (@$attributes) {
        push @{ $attr_lookup{ $attr->{'object_id'} } }, $attr;
    }

    #
    # Make sure we have something
    #
    if ( @map_set_accs && scalar @$map_sets == 0 ) {
        return $self->error( 'No map sets match the following accession IDs: '
                . join( ', ', @map_set_accs ) );
    }

    #
    # Sort it all out
    #
    for my $map_set (@$map_sets) {
        $map_set->{'object_id'}  = $map_set->{'map_set_id'};
        $map_set->{'attributes'} = $attr_lookup{ $map_set->{'map_set_id'} };
        $map_set->{'maps'}       = $map_lookup{ $map_set->{'map_set_id'} }
            || [];
        if ( $map_set->{'published_on'} ) {
            if ( my $pubdate
                = parsedate( $map_set->{'published_on'}, VALIDATE => 1 ) )
            {
                my @time = localtime($pubdate);
                $map_set->{'published_on'} = strftime( "%d %B, %Y", @time );
            }
            else {
                $map_set->{'published_on'} = '';
            }
        }
    }

    $self->get_multiple_xrefs(
        object_type => 'map_set',
        objects     => $map_sets,
    );

    #
    # Grab species and map type info for form restriction controls.
    #
    my $species = $sql_object->get_species();

    my $map_types
        = $self->fake_selectall_arrayref( $map_type_data, 'map_type_acc',
        'map_type' );
    $map_types
        = sort_selectall_arrayref( $map_types, '#display_order', 'map_type' );

    return {
        species   => $species,
        map_types => $map_types,
        map_sets  => $map_sets,
    };
}

# ----------------------------------------------------
sub map_detail_data {

=pod

=head2 map_detail_data

Returns the detail info for a map.

=cut

    my ( $self, %args ) = @_;
    my $map                       = $args{'ref_map'};
    my $highlight                 = $args{'highlight'} || '';
    my $order_by                  = $args{'order_by'} || 'f.feature_start';
    my $comparative_map_field     = $args{'comparative_map_field'} || '';
    my $comparative_map_field_acc = $args{'comparative_map_field_acc'} || '';
    my $page_size                 = $args{'page_size'} || 25;
    my $max_pages                 = $args{'max_pages'} || 0;
    my $page_no                   = $args{'page_no'} || 1;
    my $page_data                 = $args{'page_data'};
    my $sql_object                = $self->sql or return;
    my $map_id                    = $map->{'map_id'};
    my $map_start                 = $map->{'map_start'};
    my $map_stop                  = $map->{'map_stop'};
    my $feature_type_data         = $self->feature_type_data();
    my $evidence_type_data        = $self->evidence_type_data();

    my $feature_type_accs           = $args{'included_feature_types'}  || [];
    my $corr_only_feature_type_accs = $args{'corr_only_feature_types'} || [];
    my $ignored_feature_type_accs   = $args{'ignored_feature_types'}   || [];
    my $included_evidence_type_accs = $args{'included_evidence_types'};
    my $ignored_evidence_type_accs  = $args{'ignored_evidence_types'};
    my $less_evidence_type_accs     = $args{'less_evidence_types'};
    my $greater_evidence_type_accs  = $args{'greater_evidence_types'};
    my $evidence_type_score         = $args{'evidence_type_score'};

    my ( $pager, $comparative_map_acc, $comparative_map_set_acc );
    if ( $comparative_map_field eq 'map_set_acc' ) {
        $comparative_map_set_acc = $comparative_map_field_acc;
    }
    elsif ( $comparative_map_field eq 'map_acc' ) {
        $comparative_map_acc = $comparative_map_field_acc;
    }

    #
    # Figure out hightlighted features.
    #
    my $highlight_hash = {
        map {
            s/^\s+|\s+$//g;
            defined $_ && $_ ne '' ? ( uc $_, 1 ) : ()
            } parse_words($highlight)
    };

    my $maps = $sql_object->get_maps( map_id => $map_id, );
    my $reference_map = $maps->[0] if $maps;

    $map_start = $reference_map->{'map_start'}
        unless defined $map_start
            and $map_start =~ /^$RE{'num'}{'real'}$/;
    $map_stop = $reference_map->{'map_stop'}
        unless defined $map_stop
            and $map_stop =~ /^$RE{'num'}{'real'}$/;
    $reference_map->{'start'}      = $map_start;
    $reference_map->{'stop'}       = $map_stop;
    $reference_map->{'object_id'}  = $map_id;
    $reference_map->{'attributes'} = $sql_object->get_attributes(
        object_type => 'map',
        object_id   => $map_id,
    );
    $self->get_multiple_xrefs(
        object_type => 'map',
        objects     => [$reference_map]
    );

    #
    # Get the reference map features.
    #
    my $features = [];
    $features = $sql_object->get_features(
        map_id => $map_id,
        feature_type_accs =>
            [ ( @$feature_type_accs, @$corr_only_feature_type_accs ) ],
        map_start => $map_start,
        map_stop  => $map_stop,
    ) if ( @$feature_type_accs || @$corr_only_feature_type_accs );

    my $feature_count_by_type = $sql_object->get_feature_count(
        map_id                => $map_id,
        group_by_feature_type => 1,
    );

    if ( !$comparative_map_field ) {

        #
        # Page the data here so as to reduce the calls below
        # for the comparative map info.
        #
        $pager = Data::Pageset->new(
            {   total_entries    => scalar @$features,
                entries_per_page => $page_size,
                current_page     => $page_no,
                pages_per_set    => $max_pages,
            }
        );
        $features = [ $pager->splice($features) ]
            if $page_data && @$features;
    }

    #
    # Get all the feature types on all the maps.
    #
    my $tempFeatureTypes = $sql_object->get_used_feature_types(
        map_ids => [
            map { keys( %{ $self->slot_info->{$_} } ) }
                keys %{ $self->slot_info }
        ],
    );

    my @feature_types
        = sort { lc $a->{'feature_type'} cmp lc $b->{'feature_type'} }
        @{$tempFeatureTypes};

    #
    # Correspondence evidence types.
    #
    my @evidence_types
        = sort { lc $a->{'evidence_type'} cmp lc $b->{'evidence_type'} } @{
        $self->fake_selectall_arrayref(
            $self->evidence_type_data(), 'evidence_type_acc',
            'evidence_type'
        )
        };

    #
    # Find every other map position for the features on this map.
    #
    my %comparative_maps;
    for ( my $i = 0; $i <= $#{$features}; $i++ ) {
        my $feature = $features->[$i];

        my $positions = $sql_object->get_feature_correspondence_details(
            feature_id1                 => $feature->{'feature_id'},
            map_set_acc2                => $comparative_map_set_acc,
            map_acc2                    => $comparative_map_acc,
            included_evidence_type_accs => \@$included_evidence_type_accs,
            less_evidence_type_accs     => $less_evidence_type_accs,
            greater_evidence_type_accs  => $greater_evidence_type_accs,
            evidence_type_score         => $evidence_type_score,
        );
        if ( $comparative_map_field and not( $positions and @$positions ) ) {
            splice( @$features, $i, 1 );
            $i--;
            next;
        }

        my ( %distinct_positions, %evidence );
        for my $position (@$positions) {
            my $map_set_acc = $position->{'map_set_acc2'};
            my $map_acc     = $position->{'map_acc2'};
            $comparative_maps{$map_set_acc}{'map_acc'}
                = $position->{'map_acc2'};
            $comparative_maps{$map_set_acc}{'map_type_display_order'}
                = $position->{'map_type_display_order2'};
            $comparative_maps{$map_set_acc}{'map_type'}
                = $position->{'map_type2'};
            $comparative_maps{$map_set_acc}{'species_display_order'}
                = $position->{'species_display_order2'};
            $comparative_maps{$map_set_acc}{'species_common_name'}
                = $position->{'species_common_name2'};
            $comparative_maps{$map_set_acc}{'ms_display_order'}
                = $position->{'ms_display_order2'};
            $comparative_maps{$map_set_acc}{'map_set'}
                = $position->{'map_set2'};
            $comparative_maps{$map_set_acc}{'map_set_name'}
                = $position->{'map_set_name2'};
            $comparative_maps{$map_set_acc}{'map_set_acc'}
                = $position->{'map_set_acc2'};
            $comparative_maps{$map_set_acc}{'published_on'}
                = parsedate( $position->{'published_on'} );

            unless (
                defined $comparative_maps{$map_set_acc}{'maps'}{$map_acc} )
            {
                $comparative_maps{$map_set_acc}{'maps'}{$map_acc} = {
                    display_order => $position->{'map_display_order2'},
                    map_name      => $position->{'map_name2'},
                    map_acc       => $position->{'map_acc2'},
                };
            }

            $distinct_positions{ $position->{'feature_id2'} } = $position;
            push @{ $evidence{ $position->{'feature_id2'} } },
                $position->{'evidence_type'};
        }

        for my $position ( values %distinct_positions ) {
            $position->{'evidence'} = $evidence{ $position->{'feature_id2'} };
        }

        $feature->{'no_positions'} = scalar keys %distinct_positions;
        $feature->{'positions'}    = [ values %distinct_positions ];

        for my $val (
            $feature->{'feature_name'},
            @{ $feature->{'aliases'} || [] },
            $feature->{'feature_acc'}
            )
        {
            if ( $highlight_hash->{ uc $val } ) {
                $feature->{'highlight_color'}
                    = $self->config_data('feature_highlight_bg_color');
            }
        }
    }
    if ($comparative_map_field) {

#
# Page the data here if the number of features could have been reduced after getting the comparative map info.
#
        $pager = Data::Pageset->new(
            {   total_entries    => scalar @$features,
                entries_per_page => $page_size,
                current_page     => $page_no,
                pages_per_set    => $max_pages,
            }
        );
        $features = [ $pager->splice($features) ]
            if $page_data && @$features;
    }

    my @comparative_maps;
    for my $map_set (
        sort {
            $a->{'map_type_display_order'} <=> $b->{'map_type_display_order'}
                || $a->{'map_type'} cmp $b->{'map_type'}
                || $a->{'species_display_order'} <=> $b->{
                'species_display_order'}
                || $a->{'species_common_name'} cmp $b->{'species_common_name'}
                || $a->{'ms_display_order'} <=> $b->{'ms_display_order'}
                || $b->{'published_on'} <=> $a->{'published_on'}
                || $a->{'map_set_name'} cmp $b->{'map_set_name'}
        } values %comparative_maps
        )
    {
        my @maps = sort {
                   $a->{'display_order'} <=> $b->{'display_order'}
                || $a->{'map_name'} cmp $b->{'map_name'}
        } values %{ $map_set->{'maps'} };

        push @comparative_maps,
            {
            map_set_name => $map_set->{'species_common_name'} . ' - '
                . $map_set->{'map_set_short_name'},
            map_set_acc => $map_set->{'map_set_acc'},
            map_type    => $map_set->{'map_type'},
            maps        => \@maps,
            };
    }

    return {
        features              => $features,
        feature_count_by_type => $feature_count_by_type,
        feature_types         => \@feature_types,
        evidence_types        => \@evidence_types,
        reference_map         => $reference_map,
        comparative_maps      => \@comparative_maps,
        pager                 => $pager,
    };
}

# ----------------------------------------------------
sub map_type_viewer_data {

=pod

=head2 map_type_viewer_data

Returns data on map types.

=cut

    my ( $self, %args ) = @_;
    my @return_array;

    my @map_types = keys( %{ $self->config_data('map_type') } );

    my $map_type_data = $self->map_type_data();
    my %supplied_map_types;
    if ( $args{'map_types'} ) {
        %supplied_map_types = map { $_ => 1 } @{ $args{'map_types'} };
    }

    foreach my $map_type (@map_types) {
        if (%supplied_map_types) {
            next unless $supplied_map_types{$map_type};
        }
        my @attributes = ();
        my @xrefs      = ();

        # Get Attributes from config file
        my $configured_attributes = $map_type_data->{$map_type}{'attribute'};
        if ( ref($configured_attributes) ne 'ARRAY' ) {
            $configured_attributes = [ $configured_attributes, ];
        }
        foreach my $att (@$configured_attributes) {
            next
                unless ( defined( $att->{'name'} )
                and defined( $att->{'value'} ) );
            push @attributes,
                {
                attribute_name  => $att->{'name'},
                attribute_value => $att->{'value'},
                is_public       => defined( $att->{'is_public'} )
                ? $att->{'is_public'}
                : 1,
                };
        }

        # Get Xrefs from config file
        my $configured_xrefs = $map_type_data->{$map_type}{'xref'};
        if ( ref($configured_xrefs) ne 'ARRAY' ) {
            $configured_xrefs = [ $configured_xrefs, ];
        }
        foreach my $xref (@$configured_xrefs) {
            next
                unless ( defined( $xref->{'name'} )
                and defined( $xref->{'url'} ) );
            push @xrefs,
                {
                xref_name => $xref->{'name'},
                xref_url  => $xref->{'url'},
                };
        }

        $return_array[ ++$#return_array ] = {
            map_type_acc  => $map_type,
            map_type      => $map_type_data->{$map_type}{'map_type'},
            shape         => $map_type_data->{$map_type}{'shape'},
            color         => $map_type_data->{$map_type}{'color'},
            width         => $map_type_data->{$map_type}{'width'},
            display_order => $map_type_data->{$map_type}{'display_order'},
            map_units     => $map_type_data->{$map_type}{'map_units'},
            is_relational_map =>
                $map_type_data->{$map_type}{'is_relational_map'},
            'attributes' => \@attributes,
            'xrefs'      => \@xrefs,
        };
    }

    my $default_color = $self->config_data('map_color');

    my $all_map_types
        = $self->fake_selectall_arrayref( $map_type_data, 'map_type_acc',
        'map_type' );
    $all_map_types = sort_selectall_arrayref( $all_map_types, 'map_type' );

    for my $mt (@return_array) {
        $mt->{'width'} ||= DEFAULT->{'map_width'};
        $mt->{'shape'} ||= DEFAULT->{'map_shape'};
        $mt->{'color'} ||= DEFAULT->{'map_color'};
    }

    @return_array
        = sort { lc $a->{'feature_type'} cmp lc $b->{'feature_type'} }
        @return_array;

    return {
        all_map_types => $all_map_types,
        map_types     => \@return_array,
    };
}

# ----------------------------------------------------
sub species_viewer_data {

=pod

=head2 species_viewer_data

Returns data on species.

=cut

    my ( $self, %args ) = @_;
    my @species_accs = @{ $args{'species_accs'} || [] };
    my $sql_object = $self->sql;

    my $species = $sql_object->get_species( species_accs => \@species_accs, );

    my $all_species = $sql_object->get_species();

    my $attributes = $sql_object->get_attributes(
        object_type => 'species',
        get_all     => 1,
        order_by    => ' object_id, display_order, attribute_name ',
    );

    my %attr_lookup;
    for my $attr (@$attributes) {
        push @{ $attr_lookup{ $attr->{'object_id'} } }, $attr;
    }

    for my $s (@$species) {
        $s->{'object_id'}  = $s->{'species_id'};
        $s->{'attributes'} = $attr_lookup{ $s->{'species_id'} };

        $s->{'map_sets'}
            = $sql_object->get_map_sets( species_id => $s->{'species_id'}, );
    }

    $self->get_multiple_xrefs(
        object_type => 'species',
        objects     => $species,
    );

    return {
        all_species => $all_species,
        species     => $species,
    };
}

# ----------------------------------------------------
sub view_feature_on_map {

=pod

=head2 view_feature_on_map


=cut

    my ( $self, $feature_acc ) = @_;
    my $sql_object = $self->sql or return;

    my ( $map_set_acc, $map_acc, $feature_name );
    my $return_object
        = $sql_object->get_features( feature_acc => $feature_acc, );

    if ( $return_object and $return_object->[0] ) {
        $map_set_acc  = $return_object->[0]{'map_set_acc'};
        $map_acc      = $return_object->[0]{'map_acc'};
        $feature_name = $return_object->[0]{'feature_name'};
    }

    return ( $map_set_acc, $map_acc, $feature_name );
}

# ----------------------------------------------------
sub count_correspondences {

    my ( $self, %args ) = @_;
    my $included_evidence_type_accs = $args{'included_evidence_type_accs'};
    my $ignored_evidence_type_accs  = $args{'ignored_evidence_type_accs'};
    my $less_evidence_type_accs     = $args{'less_evidence_type_accs'};
    my $greater_evidence_type_accs  = $args{'greater_evidence_type_accs'};
    my $evidence_type_score         = $args{'evidence_type_score'};
    my $map_correspondences         = $args{'map_correspondences'};
    my $this_slot_no                = $args{'this_slot_no'};
    my $ref_slot_no                 = $args{'ref_slot_no'};
    my $maps                        = $args{'maps'};
    my $sql_object                  = $self->sql;
    my $this_slot_info              = $self->slot_info->{$this_slot_no};
    my $ref_slot_info
        = defined($ref_slot_no) ? $self->slot_info->{$ref_slot_no} : {};

    my $show_intraslot_corr
        = ( $self->show_intraslot_corr
            and scalar( keys( %{ $self->slot_info->{$this_slot_no} } ) )
            > 1 );

    #
    # Query for the counts of correspondences.
    #
    my $map_corrs_for_counting = [];
    if ( defined $ref_slot_no ) {

        $map_corrs_for_counting
            = $sql_object->get_feature_correspondence_for_counting(
            slot_info                   => $this_slot_info,
            slot_info2                  => $ref_slot_info,
            split_evidence_types        => $self->split_agg_ev,
            show_intraslot_corr         => $show_intraslot_corr,
            included_evidence_type_accs => $included_evidence_type_accs,
            ignored_evidence_type_accs  => $ignored_evidence_type_accs,
            less_evidence_type_accs     => $less_evidence_type_accs,
            greater_evidence_type_accs  => $greater_evidence_type_accs,
            evidence_type_score         => $evidence_type_score,
            );

    }

    my %map_id_lookup = map { $_->{'map_id'}, 1 } @$maps;
    my %corr_lookup;
    if (@$map_corrs_for_counting) {
        my $current_map_id1 = 0;
        my $current_map_id2 = 0;
        my $current_evidence_type_acc;
        my $corr_count        = 0;
        my $min_position1     = undef;
        my $min_position2     = undef;
        my $avg_position_sum1 = 0;
        my $avg_position_sum2 = 0;
        my $max_position1     = 0;
        my $max_position2     = 0;
        my $map_corrs         = [];

        for my $row (@$map_corrs_for_counting) {
            next unless $map_id_lookup{ $row->{'map_id1'} };
            if (   $row->{'map_id1'} != $current_map_id1
                or $row->{'map_id2'} != $current_map_id2
                or $row->{'evidence_type_acc'} ne $current_evidence_type_acc )
            {
                if ($current_map_id1) {

                    # Create the data object
                    push @{ $map_correspondences->{$this_slot_no}
                            {$current_map_id1}{$current_map_id2} },
                        {
                        evidence_type_acc => $current_evidence_type_acc,
                        map_id1           => $current_map_id1,
                        map_id2           => $current_map_id2,
                        no_corr           => $corr_count,
                        map_corrs         => $map_corrs,
                        min_position1     => $min_position1,
                        min_position2     => $min_position2,
                        max_position1     => $max_position1,
                        max_position2     => $max_position2,
                        avg_mid1          => $avg_position_sum1 / $corr_count,
                        avg_mid2          => $avg_position_sum2 / $corr_count,
                        };
                    $corr_lookup{$current_map_id1} += $corr_count;
                }

                # Reset values
                $current_map_id1           = $row->{'map_id1'};
                $current_map_id2           = $row->{'map_id2'};
                $current_evidence_type_acc = $row->{'evidence_type_acc'};
                $corr_count                = 0;
                $min_position1             = undef;
                $min_position2             = undef;
                $avg_position_sum1         = 0;
                $avg_position_sum2         = 0;
                $max_position1             = 0;
                $max_position2             = 0;
                $map_corrs                 = [];
            }
            $corr_count++;
            push @$map_corrs, $row;

            my $map_start1 = $this_slot_info->{$current_map_id1}[0];
            my $map_start2 = $ref_slot_info->{$current_map_id2}[0];
            my $map_stop1  = $this_slot_info->{$current_map_id1}[1];
            my $map_stop2  = $ref_slot_info->{$current_map_id2}[1];
            my $feature_start1
                = ( defined($map_start1)
                    and $map_start1 > $row->{'feature_start1'} )
                ? $map_start1
                : $row->{'feature_start1'};
            my $feature_start2
                = ( defined($map_start2)
                    and $map_start2 > $row->{'feature_start2'} )
                ? $map_start2
                : $row->{'feature_start2'};
            my $feature_stop1
                = ( defined($map_stop1)
                    and $map_stop1 < $row->{'feature_stop1'} )
                ? $map_stop1
                : $row->{'feature_stop1'};
            my $feature_stop2
                = ( defined($map_stop2)
                    and $map_stop2 < $row->{'feature_stop2'} )
                ? $map_stop2
                : $row->{'feature_stop2'};

            $avg_position_sum1 += ( $feature_stop1 + $feature_start1 ) / 2;
            $avg_position_sum2 += ( $feature_stop2 + $feature_start2 ) / 2;

            $min_position1 = $feature_start1
                if ( not defined($min_position1)
                or $min_position1 > $feature_start1 );
            $min_position2 = $feature_start2
                if ( not defined($min_position2)
                or $min_position2 > $feature_start2 );
            $max_position1 = $feature_stop1
                if ( not defined($max_position1)
                or $max_position1 < $feature_stop1 );
            $max_position2 = $feature_stop2
                if ( not defined($max_position2)
                or $max_position2 < $feature_stop2 );
        }

        # Catch the last one.
        if ($current_map_id1) {

            # Create the data object
            push @{ $map_correspondences->{$this_slot_no}{$current_map_id1}
                    {$current_map_id2} },
                {
                evidence_type_acc => $current_evidence_type_acc,
                map_id1           => $current_map_id1,
                map_id2           => $current_map_id2,
                no_corr           => $corr_count,
                map_corrs         => $map_corrs,
                min_position1     => $min_position1,
                min_position2     => $min_position2,
                max_position1     => $max_position1,
                max_position2     => $max_position2,
                avg_mid1          => $avg_position_sum1 / $corr_count,
                avg_mid2          => $avg_position_sum2 / $corr_count,
                };
            $corr_lookup{$current_map_id1} += $corr_count;
        }

    }
    return \%corr_lookup;
}

# ----------------------------------------------------

=pod

=head2 cmap_map_search_data

Returns the data for the map_search page.

=cut

sub cmap_map_search_data {

    my ( $self, %args ) = @_;
    my $slots = $args{'slots'} or return;
    my $min_correspondence_maps = $args{'min_correspondence_maps'} || 0;
    my $min_correspondences     = $args{'min_correspondences'}     || 0;
    my $feature_type_accs       = $args{'included_feature_types'}  || [];
    my $ref_species_acc         = $args{'ref_species_acc'}         || '';
    my $page_no                 = $args{'page_no'}                 || 1;
    my $name_search             = $args{'name_search'}             || '';
    my $order_by                = $args{'order_by'}                || '';
    my $ref_map                 = $slots->{0};
    my $ref_map_set_acc         = $ref_map->{'map_set_acc'}        || 0;
    my $sql_object = $self->sql or return;
    my $pid = $$;
    my $no_maps;

    my @ref_maps;

    if ( $self->slot_info ) {
        foreach my $map_id ( keys( %{ $self->slot_info->{0} } ) ) {
            my %temp_hash = (
                'map_id'    => $self->slot_info->{0}{$map_id}[0],
                'map_start' => $self->slot_info->{0}{$map_id}[1],
                'map_stop'  => $self->slot_info->{0}{$map_id}[2],
            );
            push @ref_maps, \%temp_hash;
        }
    }

    my $sql_str;
    if ( $ref_map_set_acc && !$ref_species_acc ) {

        $ref_species_acc
            = $sql_object->get_species_acc( map_set_acc => $ref_map_set_acc,
            );
    }

    #
    # Select all Species with map set
    #

    my $ref_species = $sql_object->get_species( is_enabled => 1, );

    #
    # Select all the map sets that can be reference maps.
    #
    my $ref_map_sets = [];
    if ($ref_species_acc) {

        $ref_map_sets = $sql_object->get_map_sets(
            species_acc => $ref_species_acc,
            is_enabled  => 1,
        );
    }

    #
    # If there's only one map set, pretend it was submitted.
    #
    if ( !$ref_map_set_acc && scalar @$ref_map_sets == 1 ) {
        $ref_map_set_acc = $ref_map_sets->[0]{'map_set_acc'};
    }
    my $ref_map_set_id;
    ###Get ref_map_set_id
    if ($ref_map_set_acc) {

        $ref_map_set_id = $self->sql->acc_id_to_internal_id(
            object_type => 'map_set',
            acc_id      => $ref_map_set_acc,
        );
    }

    #
    # If the user selected a map set, select all the maps in it.
    #
    my ( $map_info, @map_ids, $ref_map_set_info );
    my ( $feature_info, @feature_type_accs );

    my $cache_key
        = $ref_map_set_id . "-"
        . $name_search . "-"
        . $min_correspondence_maps . "-"
        . $min_correspondences;
    if ($ref_map_set_id) {
        ###Get map info
        unless (
            $map_info = $self->get_cached_results(
                4, "get_map_search_info" . $cache_key
            )
            )
        {
            $map_info = $sql_object->get_map_search_info(
                map_set_id              => $ref_map_set_id,
                map_name                => $name_search,
                min_correspondence_maps => $min_correspondence_maps,
                min_correspondences     => $min_correspondences,
            );
            $self->error(
                qq[No maps exist for the ref. map set acc. id "$ref_map_set_acc"]
            ) unless %$map_info;

            ### Work out the numbers per unit and reformat them.
            foreach my $map_id ( keys(%$map_info) ) {
                ### Comp Map Count
                # Divisor set to one if map length == 0
                # Contributed by David Shibeci
                my $divisor
                    = (   $map_info->{$map_id}{'map_stop'}
                        - $map_info->{$map_id}{'map_start'} )
                    || 1;
                my $raw_no = $map_info->{$map_id}{'cmap_count'} / $divisor;
                $map_info->{$map_id}{'cmap_count_per'}
                    = presentable_number_per($raw_no);
                $map_info->{$map_id}{'cmap_count_per_raw'} = $raw_no;
                ### Correspondence Count
                $raw_no = $map_info->{$map_id}{'corr_count'} / $divisor;

                $map_info->{$map_id}{'corr_count_per'}
                    = presentable_number_per($raw_no);
                $map_info->{$map_id}{'corr_count_per_raw'} = $raw_no;

            }
            $self->store_cached_results( 4,
                "get_map_search_info" . $cache_key, $map_info );
        }
        @map_ids = keys(%$map_info);

        ### Add feature type information
        my $feature_info_results;
        if ( @map_ids
            and ( $min_correspondence_maps or $min_correspondences ) )
        {
            $feature_info_results = $sql_object->get_feature_count(
                map_ids               => [ keys(%$map_info) ],
                map_name              => $name_search,
                group_by_map_id       => 1,
                group_by_feature_type => 1,
            );
        }
        else {
            $feature_info_results = $sql_object->get_feature_count(
                map_set_id            => $ref_map_set_id,
                map_name              => $name_search,
                group_by_map_id       => 1,
                group_by_feature_type => 1,
            );
        }

        my %feature_type_hash;
        foreach my $row (@$feature_info_results) {
            $feature_type_hash{ $row->{'feature_type_acc'} } = 1;
            $feature_info->{ $row->{'map_id'} }{ $row->{'feature_type_acc'} }
                {'total'} = $row->{'feature_count'};
            my $devisor
                = $map_info->{ $row->{'map_id'} }{'map_stop'}
                - $map_info->{ $row->{'map_id'} }{'map_start'}
                || 1;

            my $raw_no = ( $row->{'feature_count'} / $devisor );
            $feature_info->{ $row->{'map_id'} }{ $row->{'feature_type_acc'} }
                {'raw_per'} = $raw_no;
            $feature_info->{ $row->{'map_id'} }{ $row->{'feature_type_acc'} }
                {'per'} = presentable_number_per($raw_no);
        }
        @feature_type_accs = keys(%feature_type_hash);

        ###Sort maps
        if (my $array_ref = $self->get_cached_results(
                4, "sort_maps_" . $cache_key . $order_by
            )
            )
        {
            @map_ids = @$array_ref;
        }
        else {
            if ( $order_by =~ /^feature_total_(\S+)/ ) {
                my $ft_acc = $1;
                @map_ids = sort {
                    $feature_info->{$b}{$ft_acc}
                        {'total'} <=> $feature_info->{$a}{$ft_acc}{'total'}
                } @map_ids;
            }
            elsif ( $order_by =~ /^feature_per_(\S+)/ ) {
                my $ft_acc = $1;
                @map_ids = sort {
                    $feature_info->{$b}{$ft_acc}
                        {'raw_per'} <=> $feature_info->{$a}{$ft_acc}
                        {'raw_per'}
                } @map_ids;
            }
            elsif ( $order_by eq "display_order" or !$order_by ) {
                ###DEFAULT sort
                @map_ids = sort {
                    return (
                        $map_info->{$a}{'display_order'} <=> $map_info->{$b}
                            {'display_order'} )
                        if (
                        $map_info->{$a}{'display_order'} <=> $map_info->{$b}
                        {'display_order'} );
                    return ( $map_info->{$a}{'map_name'}
                            cmp $map_info->{$b}{'map_name'} );
                } @map_ids;
            }
            else {
                @map_ids = sort {
                    $map_info->{$b}{$order_by} <=> $map_info->{$a}{$order_by}
                } @map_ids;
            }
            $self->store_cached_results( 4,
                "sort_maps_" . $cache_key . $order_by, \@map_ids );
        }
    }

    my %feature_types
        = map { $_ => $self->feature_type_data($_) } @feature_type_accs;

    #
    # Slice the results up into pages suitable for web viewing.
    #
    my $pager = Data::Pageset->new(
        {   total_entries    => scalar @map_ids,
            current_page     => $page_no,
            entries_per_page => 25,
            pages_per_set    => 1,
        }
    );
    @map_ids = $pager->splice( \@map_ids ) if @map_ids;
    $no_maps = scalar @map_ids;

    return {
        ref_species_acc   => $ref_species_acc,
        ref_species       => $ref_species,
        ref_map_sets      => $ref_map_sets,
        ref_map_set_acc   => $ref_map_set_acc,
        map_info          => $map_info,
        feature_info      => $feature_info,
        no_maps           => $no_maps,
        map_ids           => \@map_ids,
        feature_type_accs => \@feature_type_accs,
        feature_types     => \%feature_types,
        pager             => $pager,
    };
}

# ----------------------------------------------------

=pod

=head2 cmap_spider_links

Returns the links for the spider page.

=cut

sub cmap_spider_links {

    my ( $self, %args ) = @_;
    my $map_acc          = $args{'map_acc'};
    my $degrees_to_crawl = $args{'degrees_to_crawl'};
    my $min_corrs        = $args{'min_corrs'};
    my $apr              = $args{'apr'};

    return []
        unless ( $map_acc
        and defined($degrees_to_crawl)
        and $degrees_to_crawl =~ /^\d+$/ );

    my $sql_object = $self->sql or return;

    my %seen_map_ids        = ();
    my %map_accs_per_degree = ();
    my @links               = ();

    my $map_viewer_url = 'viewer';

    # Set up degree 0.
    $seen_map_ids{$map_acc} = {};
    $map_accs_per_degree{0} = [ $map_acc, ];

    my $link = $self->create_viewer_link(
        ref_map_accs => \%seen_map_ids,
        data_source  => $self->data_source,
        base_url     => $map_viewer_url,
    );
    push @links,
        {
        link       => $link,
        tier_maps  => scalar( @{ $map_accs_per_degree{0} } ),
        total_maps => scalar( keys %seen_map_ids ),
        };
    for ( my $i = 1; $i <= $degrees_to_crawl; $i++ ) {
        last unless ( defined( $map_accs_per_degree{ $i - 1 } ) );

        my $query_results = $sql_object->get_comparative_maps_with_count(
            map_accs        => $map_accs_per_degree{ $i - 1 },
            ignore_map_accs => [ keys(%seen_map_ids) ],
            intraslot_only  => 1,
        );

        # Add results to data structures.
        foreach my $row ( @{$query_results} ) {
            unless ( $seen_map_ids{ $row->{'map_acc2'} } ) {
                push @{ $map_accs_per_degree{$i} }, $row->{'map_acc2'};
                $seen_map_ids{ $row->{'map_acc2'} } = {};
            }
        }

        # We're done if there are no new maps
        last unless ( defined( $map_accs_per_degree{$i} ) );

        my $map_order = '';
        for ( my $j = 0; $j <= $i; $j++ ) {
            $map_order
                .= join( ":", sort @{ $map_accs_per_degree{$j} } ) . ",";
        }

        $link = $self->create_viewer_link(
            ref_map_accs  => \%seen_map_ids,
            data_source   => $self->data_source,
            base_url      => $map_viewer_url,
            ref_map_order => $map_order,
        );
        push @links,
            {
            link       => $link,
            tier_maps  => scalar( @{ $map_accs_per_degree{$i} } ),
            total_maps => scalar( keys %seen_map_ids ),
            };
    }

    return \@links;
}

# ----------------------------------------------------
sub get_all_feature_types {
    my $self = shift;

    my $slot_info  = $self->slot_info;
    my $sql_object = $self->sql;
    my @map_id_list;
    foreach my $slot_no ( keys %{$slot_info} ) {
        push @map_id_list, keys( %{ $slot_info->{$slot_no} } );
    }
    return [] unless @map_id_list;

    my $return
        = $sql_object->get_used_feature_types( map_ids => \@map_id_list, );

    return $return;
}

# ----------------------------------------------------
sub get_max_unit_size {
    my $self  = shift;
    my $slots = shift;

    my %max_per_unit;

    foreach my $slot_id ( keys %$slots ) {
        foreach my $map_id ( keys %{ $slots->{$slot_id} } ) {
            my $map = $slots->{$slot_id}{$map_id};
            unless ($max_per_unit{ $map->{'map_units'} }
                and $max_per_unit{ $map->{'map_units'} }
                > ( $map->{'map_stop'} - $map->{'map_start'} ) )
            {
                $max_per_unit{ $map->{'map_units'} }
                    = $map->{'map_stop'} - $map->{'map_start'};
            }
        }
    }

    return \%max_per_unit;
}

# ----------------------------------------------------
sub get_ref_unit_size {
    my $self  = shift;
    my $slots = shift;

    my $scale_conversion = $self->scale_conversion;
    my %ref_for_unit;
    my %set_by_slot;
    foreach my $slot_id ( sort orderOutFromZero keys %$slots ) {
    MAPID: foreach my $map_id ( keys %{ $slots->{$slot_id} } ) {
            my $map      = $slots->{$slot_id}{$map_id};
            my $map_unit = $map->{'map_units'};

            # If the unit size is already defined by a different
            # slot, we don't want to redifine it.
            if (    defined( $set_by_slot{$map_unit} )
                and $set_by_slot{$map_unit} != $slot_id
                and $ref_for_unit{$map_unit} )
            {
                last MAPID;
            }

            $set_by_slot{$map_unit} = $slot_id;

            # If there is a unit defined that we have a conversion
            # factor for, use that.
            if ( $scale_conversion->{$map_unit} ) {
                while ( my ( $unit, $conversion )
                    = each %{ $scale_conversion->{$map_unit} } )
                {
                    if ( $ref_for_unit{$unit} ) {
                        $ref_for_unit{$map_unit}
                            = $ref_for_unit{$unit} * $conversion;
                        last MAPID;
                    }
                }
            }

            # If the unit hasn't been defined or
            # this map is bigger, set ref_for_unit
            if ( !$ref_for_unit{$map_unit}
                or $ref_for_unit{$map_unit}
                < $map->{'map_stop'} - $map->{'map_start'} )
            {
                $ref_for_unit{$map_unit}
                    = $map->{'map_stop'} - $map->{'map_start'};
            }
        }
    }

    return \%ref_for_unit;
}

# ----------------------------------------------------
sub scale_conversion {

=pod

=head2 scale_conversion

Returns a hash with the conversion factors between unit types as defined in the
config file.

=cut

    my $self = shift;

    unless ( $self->{'scale_conversion'} ) {
        my $config_scale = $self->config_data('scale_conversion');
        if ($config_scale) {
            while ( my ( $unit1, $convs ) = each %$config_scale ) {
                while ( my ( $unit2, $factor ) = each %$convs ) {
                    $self->{'scale_conversion'}{$unit2}{$unit1} = $factor;
                    $self->{'scale_conversion'}{$unit1}{$unit2} = 1 / $factor;
                }
            }
        }
    }
    return $self->{'scale_conversion'};
}

# ----------------------------------------------------
sub compress_maps {

=pod

=head2 compress_maps

Decide if the maps should be compressed.
If it is aggregated, compress unless the slot contain only 1 map.
If it is not aggregated, don't compress 

=cut

    my $self         = shift;
    my $this_slot_no = shift;

    return unless defined $this_slot_no;
    return 0 if ( $this_slot_no == 0 );
    return $self->{'compressed_maps'}{$this_slot_no}
        if defined( $self->{'compressed_maps'}{$this_slot_no} );

    if ( scalar( keys( %{ $self->slot_info->{$this_slot_no} } ) ) > 1
        and $self->aggregate )
    {
        $self->{'compressed_maps'}{$this_slot_no} = 1;
    }
    else {
        $self->{'compressed_maps'}{$this_slot_no} = 0;

    }

    return $self->{'compressed_maps'}{$this_slot_no};
}

# ----------------------------------------------------
sub getDisplayedStartStop {

=pod

=head2 getDisplayedStartStop

get start and stop of a map set.

=cut

    my $self    = shift;
    my $slot_no = shift;
    my $map_id  = shift;
    return ( undef, undef )
        unless ( defined($slot_no) and defined($map_id) );

    my ( $start, $stop );
    if (    $self->slot_info->{$slot_no}
        and %{ $self->slot_info->{$slot_no} }
        and @{ $self->slot_info->{$slot_no}{$map_id} } )
    {
        my $map_info = $self->slot_info->{$slot_no}{$map_id};
        if ( defined( $map_info->[0] ) ) {
            $start = $map_info->[0];
        }
        else {
            $start = $map_info->[2];
        }
        if ( defined( $map_info->[1] ) ) {
            $stop = $map_info->[1];
        }
        else {
            $stop = $map_info->[3];
        }
    }
    return ( $start, $stop );

}

# ----------------------------------------------------
sub truncatedMap {

=pod

=head2 truncatedMap

test if the map is truncated

=cut

    my $self    = shift;
    my $slot_no = shift;
    my $map_id  = shift;
    return undef
        unless ( defined($slot_no) and defined($map_id) );

    if (    $self->slot_info->{$slot_no}
        and %{ $self->slot_info->{$slot_no} }
        and @{ $self->slot_info->{$slot_no}{$map_id} } )
    {
        my $map_info          = $self->slot_info->{$slot_no}{$map_id};
        my $map_top_truncated = ( defined( $map_info->[0] )
                and $map_info->[0] != $map_info->[2] );
        my $map_bottom_truncated = ( defined( $map_info->[1] )
                and $map_info->[1] != $map_info->[3] );
        if ( $map_top_truncated and $map_bottom_truncated ) {
            return 3;
        }
        elsif ($map_top_truncated) {
            return 1;
        }
        elsif ($map_bottom_truncated) {
            return 2;
        }
        return 0;
    }
    return undef;
}

# ----------------------------------------------------
sub scroll_data {

=pod

=head2 scroll_data

return the start and stop for the scroll buttons

=cut

    my $self       = shift;
    my $slot_no    = shift;
    my $map_id     = shift;
    my $is_flipped = shift;
    my $dir        = shift;
    my $is_up      = ( $dir eq 'UP' );
    return ( undef, undef, 1 )
        unless ( defined($slot_no) and defined($map_id) );

    if (    $self->slot_info->{$slot_no}
        and %{ $self->slot_info->{$slot_no} }
        and @{ $self->slot_info->{$slot_no}{$map_id} } )
    {
        my $map_info = $self->slot_info->{$slot_no}{$map_id};

        my $mag = $map_info->[4] || 1;
        return ( undef, undef, $mag )
            unless ( defined( $map_info->[0] )
            or defined( $map_info->[1] ) );

        my $start = $map_info->[0];
        my $stop  = $map_info->[1];

        if (   ( $is_up and not $is_flipped )
            or ( $is_flipped and not $is_up ) )
        {

            # Scroll data for up arrow
            return ( undef, undef, $mag ) unless defined($start);
            my $view_length
                = defined($stop)
                ? ( $stop - $start )
                : $map_info->[3] - $start;
            my $new_start = $start - ( $view_length / 2 );
            my $new_stop = $new_start + $view_length;
            if ( $new_start <= $map_info->[2] ) {

              # Start is smaller than real map start.  Use the real map start;
                $new_start = "''";
                $new_stop  = $map_info->[2] + $view_length;
            }
            if ( $new_stop >= $map_info->[3] ) {

                # Stop is greater than the real end.
                $new_stop = "''";
            }

            return ( $new_start, $new_stop, $mag );
        }
        else {

            # Scroll data for down arrow
            return ( undef, undef, $mag ) unless defined($stop);
            my $view_length
                = defined($start)
                ? ( $stop - $start )
                : $stop - $map_info->[2];
            my $new_stop = $stop + ( $view_length / 2 );
            my $new_start = $new_stop - $view_length;
            if ( $new_stop >= $map_info->[3] ) {

              # Start is smaller than real map start.  Use the real map start;
                $new_stop  = "''";
                $new_start = $map_info->[3] - $view_length;
            }
            if ( $new_start <= $map_info->[2] ) {

                # Stop is greater than the real end.
                $new_stop = "''";
            }

            return ( $new_start, $new_stop, $mag );
        }
    }
    return ( undef, undef, 1 );
}

# ----------------------------------------------------
sub magnification {

=pod

=head2 magnification

Given the slot_no and map_id

=cut

    my $self    = shift;
    my $slot_no = shift;
    my $map_id  = shift;
    return 1 unless defined $slot_no and defined $map_id;

    if (    $self->slot_info->{$slot_no}
        and %{ $self->slot_info->{$slot_no} }
        and @{ $self->slot_info->{$slot_no}{$map_id} } )
    {
        my $map_info = $self->slot_info->{$slot_no}{$map_id};
        if ( defined( $map_info->[4] ) ) {
            return $map_info->[4];
        }
    }

    return 1;
}

# ----------------------------------------------------
sub feature_default_display {

=pod

=head2 feature_default_display



=cut

    my $self                        = shift;
    my $url_feature_default_display = shift;
    my $feature_type_acc            = shift;
    my $map_type_acc                = shift;

    # Try to get the default for a specific feature from the map_type first
    unless ( defined($url_feature_default_display)
        and $url_feature_default_display =~ /^\d$/ )
    {

        if (    $map_type_acc
            and $feature_type_acc
            and (
                my $defaults = $self->map_type_data(
                    $map_type_acc, 'feature_default_display'
                )
            )
            )
        {
            if ( my $return_val = $defaults->{$feature_type_acc} ) {
                return $return_val;
            }
        }

        # Try to get the default for a specific feature type.
        if ($feature_type_acc
            and (
                my $return_val = $self->feature_type_data(
                    $feature_type_acc, 'feature_default_display'
                )
            )
            )
        {
            return $return_val;
        }
    }

    # If needed use url value
    unless ( $self->{'feature_default_display'} ) {
        if ( defined($url_feature_default_display)
            and $url_feature_default_display =~ /^\d$/ )
        {
            if ( $url_feature_default_display == 0 ) {
                $self->{'feature_default_display'} = 'ignore';
            }
            elsif ( $url_feature_default_display == 1 ) {
                $self->{'feature_default_display'} = 'corr_only';
            }
            elsif ( $url_feature_default_display == 2 ) {
                $self->{'feature_default_display'} = 'display';
            }
        }
    }

    # If needed use default value
    unless ( $self->{'feature_default_display'} ) {
        my $feature_default_display
            = lc( $self->config_data('feature_default_display') );
        unless ( $feature_default_display eq 'corr_only'
            or $feature_default_display eq 'ignore' )
        {
            $feature_default_display = 'display';    #Default value
        }
        $self->{'feature_default_display'} = $feature_default_display;
    }

    return $self->{'feature_default_display'};
}

# ----------------------------------------------------
sub evidence_default_display {

=pod

=head2 evidence_default_display

Given the slot_no and map_id

=cut

    my $self        = shift;
    my $ev_type_acc = shift;

    my %valid_values = ( 'default' => 1, 'ignore' => 1, );

    unless ( $self->{'evidence_default_display'}{$ev_type_acc} ) {
        my $evidence_default_display;
        my $individual_default = lc $self->evidence_type_data( $ev_type_acc,
            'evidence_default_display', );
        if (    $ev_type_acc
            and $individual_default
            and $valid_values{$individual_default} )
        {
            $evidence_default_display = $individual_default;
        }

        $evidence_default_display
            = lc $self->config_data('evidence_default_display')
            unless ($evidence_default_display);

        unless ( $valid_values{$evidence_default_display} ) {
            $evidence_default_display = 'display';    #Default value
        }
        $self->{'evidence_default_display'}{$ev_type_acc}
            = $evidence_default_display;
    }

    return $self->{'evidence_default_display'}{$ev_type_acc};
}

# ----------------------------------------------------
sub ref_map_order_hash {

=pod

=head2 ref_map_order_hash

Uses ref_map_order() to create a hash designating the maps order.

=cut

    my $self = shift;

    unless ( $self->{'ref_map_order_hash'} ) {
        my %return_hash      = ();
        my $ref_map_order    = $self->ref_map_order();
        my @ref_map_acc_list = split( /[,]/, $ref_map_order );
        for ( my $i = 0; $i <= $#ref_map_acc_list; $i++ ) {
            my @ref_map_accs = split( /[:]/, $ref_map_acc_list[$i] );
            foreach my $acc (@ref_map_accs) {
                my $map_id = $self->sql->acc_id_to_internal_id(
                    object_type => 'map',
                    acc_id      => $acc,
                );
                $return_hash{$map_id} = $i + 1;
            }
        }
        $self->{'ref_map_order_hash'} = \%return_hash;
    }

    return $self->{'ref_map_order_hash'};
}

# ----------------------------------------------------
sub ref_maps_equal {

=pod

=head2 ref_maps_equal

Uses ref_map_order_hash() to compare the placement of each map
in the order.  returns 1 if they are equally placed.

=cut

    my $self          = shift;
    my $first_map_id  = shift;
    my $second_map_id = shift;
    my %map_order     = %{ $self->ref_map_order_hash };

    return 0 unless (%map_order);

    if ( $map_order{$first_map_id} and $map_order{$second_map_id} ) {
        return ( $map_order{$first_map_id} == $map_order{$second_map_id} );
    }

    return 0;
}

# ----------------------------------------------------
sub cmp_ref_map_order {

=pod

=head2 cmp_ref_map_order

Uses ref_map_order_hash() to compare the placement of each map
in the order.  returns -1, 0 or 1 as cmp does.

=cut

    my $self          = shift;
    my $first_map_id  = shift;
    my $second_map_id = shift;
    my %map_order     = %{ $self->ref_map_order_hash };

    return 0 unless (%map_order);

    if ( $map_order{$first_map_id} and $map_order{$second_map_id} ) {
        return ( $map_order{$first_map_id} <=> $map_order{$second_map_id} );
    }
    elsif ( $map_order{$first_map_id} ) {
        return -1;
    }
    else {
        return 1;
    }
}

# ----------------------------------------------------

=pod

=head2 fill_type_arrays

Organizes the data for drawing comparative maps.

=cut

sub fill_type_arrays {

    my ( $self, %args ) = @_;
    my $ref_map_set_acc = $args{'ref_map_set_acc'}
        or return;
    my $included_feature_type_accs = $args{'included_feature_type_accs'}
        || [];
    my $corr_only_feature_type_accs = $args{'corr_only_feature_type_accs'}
        || [];
    my $ignored_feature_type_accs = $args{'ignored_feature_type_accs'} || [];
    my $url_feature_default_display = $args{'url_feature_default_display'};
    my $ignored_evidence_type_accs  = $args{'ignored_evidence_type_accs'}
        || [];
    my $included_evidence_type_accs = $args{'included_evidence_type_accs'}
        || [];
    my $less_evidence_type_accs = $args{'less_evidence_type_accs'} || [];
    my $greater_evidence_type_accs = $args{'greater_evidence_type_accs'}
        || [];

    my $map_sets = $self->sql()
        ->get_map_sets_simple( map_set_acc => $ref_map_set_acc, );
    my $ref_map_type_acc = $map_sets->[0]{'map_type_acc'} if $map_sets;

    # Fill the default array with any feature types not accounted for.
    my %found_feature_type;
    foreach
        my $ft ( @$included_feature_type_accs, @$corr_only_feature_type_accs,
        @$ignored_feature_type_accs )
    {
        $found_feature_type{$ft} = 1;
    }
    my $feature_type_data = $self->feature_type_data();

    foreach my $key ( keys(%$feature_type_data) ) {
        my $acc = $feature_type_data->{$key}{'feature_type_acc'};
        unless ( $found_feature_type{$acc} ) {
            my $feature_default_display = $self->feature_default_display(
                $url_feature_default_display, $acc, $ref_map_type_acc );

            if ( $feature_default_display eq 'corr_only' ) {
                push @$corr_only_feature_type_accs, $acc;
            }
            elsif ( $feature_default_display eq 'ignore' ) {
                push @$ignored_feature_type_accs, $acc;
            }
            else {
                push @$included_feature_type_accs, $acc;
            }
        }
    }

    # Fill the default array with any evidence types not accounted for.

    my %found_evidence_type;
    foreach my $et (
        @$included_evidence_type_accs, @$ignored_evidence_type_accs,
        @$less_evidence_type_accs,     @$greater_evidence_type_accs,
        )
    {
        $found_evidence_type{$et} = 1;
    }
    my $evidence_type_data = $self->evidence_type_data();

    foreach my $key ( keys(%$evidence_type_data) ) {
        my $ev_type_acc = $evidence_type_data->{$key}{'evidence_type_acc'};
        unless ( $found_evidence_type{$ev_type_acc} ) {

            my $evidence_default_display
                = $self->evidence_default_display($ev_type_acc);
            if ( $evidence_default_display eq 'ignore' ) {
                push @$ignored_evidence_type_accs, $ev_type_acc;
            }
            else {
                push @$included_evidence_type_accs, $ev_type_acc;
            }
        }
    }
}

# ----------------------------------------------------
sub sorted_map_ids {

=pod

=head2 sorted_map_ids

Sets and returns the sorted map ids for each slot

=cut

    my $self      = shift;
    my $slot_no   = shift;
    my $slot_data = shift;

    if ($slot_data) {
        my @map_ids = keys(%$slot_data);
        if ( $slot_no == 0 ) {
            @map_ids = map { $_->[0] }
                sort {
                (          $self->cmp_ref_map_order( $a->[0], $b->[0] )
                        || $a->[1] <=> $b->[1]
                        || $a->[2] cmp $b->[2]
                        || $a->[0] <=> $b->[0] )
                }
                map {
                [   $_,
                    $slot_data->{$_}{'display_order'},
                    $slot_data->{$_}{'map_name'},
                ]
                } @map_ids;
        }
        else {
            @map_ids = map { $_->[0] }
                sort { $b->[1] <=> $a->[1] }
                map { [ $_, $slot_data->{$_}{'no_correspondences'} ] }
                @map_ids;
        }
        $self->{'sorted_map_ids'}{$slot_no} = \@map_ids;
    }
    if ( defined($slot_no) ) {
        return $self->{'sorted_map_ids'}{$slot_no} || [];
    }
    return $self->{'sorted_map_ids'} || [];
}

# ----------------------------------------------------
sub update_slots {

=pod
                                                                                
=head2 update_slots

update the slots object to reflect the new data in slot_info


Data Structures:
  slot_info  =  {
    slot_no  => {
      map_id => [ current_start, current_stop, ori_start, ori_stop, magnification, map_acc ],
    }
  }

  slots = {
    slot_no => {
        stack_slot  => $stack_slot,
        map_set_acc => $map_set_acc,
        map_sets    => { $map_set_acc => () },
        maps        => { $map_acc => {
                start => $start,
                stop  => $stop,
                map   => $magnification,
            }
        }
    }
  }

=cut

    my $self           = shift;
    my $slots          = shift;
    my $slot_min_corrs = shift;
    my $stack_slot     = shift;
    my $slot_info      = $self->slot_info;

    my %used_slot_nos;

    # Repopulate the 'maps' object in $slots
    foreach my $slot_no ( keys(%$slot_info) ) {
        $used_slot_nos{$slot_no} = 1;
        $slots->{$slot_no}{'maps'} = {};
        foreach my $map_id ( keys( %{ $slot_info->{$slot_no} } ) ) {
            my $map_info = $slot_info->{$slot_no}{$map_id};
            $slots->{$slot_no}{'maps'}{ $map_info->[5] } = {
                start => $map_info->[0],
                stop  => $map_info->[1],
                mag   => $map_info->[4],
            };
        }
    }

    # Remove any spare slots and update the stack and min_corrs value
    foreach my $slot_no ( keys(%$slots) ) {
        unless ( $used_slot_nos{$slot_no} ) {
            delete( $slots->{$slot_no} );
            next;
        }
        $slots->{$slot_no}->{'stack_slot'} = $stack_slot->{$slot_no};
        $slots->{$slot_no}->{'min_corrs'}  = $slot_min_corrs->{$slot_no}
            if defined( $slot_min_corrs->{$slot_no} );
    }
}

# ----------------------------------------------------
sub slot_info {

=pod
                                                                                
=head2 slot_info

Stores and retrieve the slot info.

Creates and returns some map info for each slot.

Data Structure:
  slot_info  =  {
    slot_no  => {
      map_id => [ current_start, current_stop, ori_start, ori_stop, magnification, map_acc ]
    }
  }

"current_start" and "current_stop" are undef if using the 
original start and stop. 

=cut

    my $self                        = shift;
    my $slots                       = shift;
    my $ignored_feature_list        = shift;
    my $included_evidence_type_accs = shift;
    my $less_evidence_type_accs     = shift;
    my $greater_evidence_type_accs  = shift;
    my $evidence_type_score         = shift;
    my $slot_min_corrs              = shift;
    my $eliminate_orphans           = shift;
    my $sql_object                  = $self->sql;

    # Return slot_info is not setting it.
    return $self->{'slot_info'} unless ($slots);

    $self->{'slot_info'} = $sql_object->get_slot_info(
        slots                       => $slots,
        ignored_feature_type_accs   => $ignored_feature_list,
        included_evidence_type_accs => $included_evidence_type_accs,
        less_evidence_type_accs     => $less_evidence_type_accs,
        greater_evidence_type_accs  => $greater_evidence_type_accs,
        evidence_type_score         => $evidence_type_score,
        slot_min_corrs              => $slot_min_corrs,
        eliminate_orphans           => $eliminate_orphans,
    ) or return $self->error( $sql_object->error() );

    # Check Map Bounds
    foreach my $slot_id ( keys %{ $self->{'slot_info'} } ) {
        foreach my $map_acc ( keys %{ $self->{'slot_info'}->{$slot_id} } ) {
            if ( $self->{'slot_info'}->{$slot_id}{$map_acc}[0]
                < $self->{'slot_info'}->{$slot_id}{$map_acc}[2] )
            {
                $self->{'slot_info'}->{$slot_id}{$map_acc}[0]
                    = $self->{'slot_info'}->{$slot_id}{$map_acc}[2];
                $slots->{$slot_id}{'maps'}{$map_acc}{'start'}
                    = $self->{'slot_info'}->{$slot_id}{$map_acc}[2];
            }
            if ( $self->{'slot_info'}->{$slot_id}{$map_acc}[1]
                > $self->{'slot_info'}->{$slot_id}{$map_acc}[3] )
            {
                $self->{'slot_info'}->{$slot_id}{$map_acc}[1]
                    = $self->{'slot_info'}->{$slot_id}{$map_acc}[3];
                $slots->{$slot_id}{'maps'}{$map_acc}{'stop'}
                    = $self->{'slot_info'}->{$slot_id}{$map_acc}[3];
            }
        }
    }

    return $self->{'slot_info'};
}

# ----------------------------------------------------
sub get_feature_correspondence_with_slot_comparisons {

=pod
                                                                                
=head2 get_feature_correspondence_with_slot_comparisons

Given a set of slot_comparisons,

 Structure:
    @slot_comparisons = (
        {   map_id1          => $map_id1,
            slot_info1       => {$map_id1 => [ current_start, current_stop, ori_start, ori_stop, magnification ]},
            fragment_offset1 => $fragment_offset1,
            slot_info2       => {$map_id2 => [ current_start, current_stop, ori_start, ori_stop, magnification ]},
            fragment_offset2 => $fragment_offset2,
            map_id2          => $map_id2,
        },
    );



=cut

    my $self             = shift;
    my $slot_comparisons = shift or return [];
    my $sql_object       = $self->sql;

    my @results;
    foreach my $slot_comparison (@$slot_comparisons) {
        my $corrs = $self->sql()->get_feature_correspondence_for_counting(
            slot_info      => $slot_comparison->{'slot_info1'},
            slot_info2     => $slot_comparison->{'slot_info2'},
            allow_intramap => $slot_comparison->{'allow_intramap'},
        ) || [];

        # Modify the correspondences to match up to the maps
        my $map_id1          = $slot_comparison->{'map_id1'};
        my $fragment_offset1 = $slot_comparison->{'fragment_offset1'};
        my $map_id2          = $slot_comparison->{'map_id2'};
        my $fragment_offset2 = $slot_comparison->{'fragment_offset2'};
        foreach my $corr ( @{ $corrs || [] } ) {
            $corr->{'map_id1'} = $map_id1;
            $corr->{'feature_start1'} += $fragment_offset1;
            $corr->{'feature_stop1'}  += $fragment_offset1;
            $corr->{'map_id2'} = $map_id2;
            $corr->{'feature_start2'} += $fragment_offset2;
            $corr->{'feature_stop2'}  += $fragment_offset2;
        }
        push @results,
            {
            cache_key => $slot_comparison->{'cache_key'},
            corrs     => $corrs,
            };

    }

    return \@results;
}

sub orderOutFromZero {
    ###Return the sort in this order (0,1,-1,-2,2,-3,3,)
    return ( abs($a) cmp abs($b) );
}

1;

# ----------------------------------------------------
# An aged man is but a paltry thing,
# A tattered coat upon a stick.
# William Butler Yeats
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>, L<DBI>.

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

