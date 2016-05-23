package Bio::GMOD::CMap::Apache::CMap3D;

=pod

=head1 Bio::GMOD::CMap::Apache::CMap3D

=head1 Usage

The following line is an example of the URL used to access the data.

 http://127.0.0.1/cgi-bin/cmap/cmap3d?action=get_species;data_source=CMap;

The "action" parameter tells the script what data needs to be returned.  The
"data_source" parameter is important to tell CMap which data source will be
used.

=head1 Actions

=head2 get_species

URL contains by "action=get_species"

=head3 URL Parameters

No other URL parameters.

=head3 Example Output

    <species_listing>
        <species acc="rice08">
            <species_common_name>Rice</species_common_name>
            <species_full_name>Oryza sativa</species_full_name>
        </species>
    </species_listing>

=head2 get_map_sets

URL contains by "action=get_map_sets"

=head3 URL Parameters

=over 4

=item * species_acc [Optional]

If specified, the method will only print map sets that are in this species.

=item * ref# [Optional]

The "ref#" params (where # is a number starting with 0) hold map_accs of each
map being displayed currently.  These are treated as reference maps.  If
specified, this will only return map_sets that have correspondences to the
reference maps.

If not specified, this will print all map sets.

Example:  "ref0=2442;ref1=1221"

=back

=head3 Example Output

The value in the <map_set> tag is the map_set_acc.

    <map_set_listing>
        <map_set>1</map_set>
        <map_set>3</map_set>
        <map_set>7</map_set>
        <map_set>2</map_set>
    </map_set_listing>

=head2 get_map_sets

URL contains by "action=get_map_sets"

=head3 URL Parameters

=over 4

=item * species_acc [Optional]

If specified, the method will only print map sets that are in this species.

=item * ref# [Optional]

The "ref#" params (where # is a number starting with 0) hold map_accs of each
map being displayed currently.  These are treated as reference maps.  If
specified, this will only return map_sets that have correspondences to the
reference maps.

If not specified, this will print all map sets.

Example:  "ref0=2442;ref1=1221"

=back

=head3 Example Output

The value in the <map_set> tag is the map_set_acc.

    <map_set_listing>
        <map_set>1</map_set>
        <map_set>3</map_set>
        <map_set>7</map_set>
        <map_set>2</map_set>
    </map_set_listing>

=head2 get_map_data

URL contains by "action=get_map_data"

Prints xml that describe map ids.

=head3 URL Parameters

=over 4

=item * map_set_acc [Optional]

If specified, the method will only print map_data that are in this map set.

=item * map_acc# [Optional]

The "map_acc#" params (where # is a number starting with 0) hold map_accs of each
map being displayed currently.  These are the maps for which data will be
printed.

If not specified, this will return all maps.

Example:  "ref0=2442;ref1=1221"

=back

=head3 Example Output

  <cmap3d server="0100" client="0100" cmap="1.0">
    <types>
        <type value="clone"/>
        <type value="marker"/>
        <type value="stacked_contig"/>
    </types>
    <maps>
        <map 
            map_id="411"
            map_acc="im_2"
            map_set_id="7"
            map_name="I-Map on 2"
            display_order="1"
            map_start="1.00"
            map_stop="5359.00"
            map_units="bands"
            ranged_count="1776"
            singular_count="8"
            feature_count="1784"
        >
            <map_details>
                <map_name>I-Map on 2</map_name>
            </map_details>
            <ranged_features>
                <features type="stacked_contig">
                    <feature
                        feature_id="36582"
                        feature_acc="36582"
                        feature_type_acc="stacked_contig"
                        feature_name="ctg28"
                        is_landmark="1"
                        feature_start="1.00"
                        feature_stop="419.00"
                        default_rank="1"
                        direction="1"/>
                </features>
            </ranged_features>
            <singular_features>
                <features type="marker">
                    <feature
                        feature_id="36866"
                        feature_acc="36866"
                        feature_type_acc="marker"
                        feature_name="OJ000310"
                        is_landmark="0"
                        feature_start="573.00"
                        feature_stop="573.00"
                        default_rank=""
                        direction="1"/>
                </features>
            </singular_features>
            </map>
        </maps>
    <correspondences>
        <correspondence
            feature_correspondence_id="1350529"
            feature_acc1="38205"
            feature_acc2="jrgp-2000-1-52"
            map_acc1="2311"
            map_acc2="jrgp-rflp-2000-1"
            feature_type_acc1="marker"
            feature_type_acc2="marker"/>
    </correspondences>
  </cmap3d>

=head1 Methods

=cut

# vim: set ft=perl:

# $Id: CMap3D.pm,v 1.2 2008/07/01 05:24:37 chrisduran Exp $

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.2 $)[-1];

use Bio::GMOD::CMap::Apache;
use Storable qw(nfreeze thaw);
use Data::Dumper;
use base 'Bio::GMOD::CMap::Apache';

sub handler {

    #
    # Make a jazz noise here...
    #
    my ( $self, $apr ) = @_;
    $self->data_source( $apr->param('data_source') ) or return;
    my $action = $apr->param('action');

    print $apr->header( -type => 'text/xml', );
	print "<?xml version='1.0' encoding='ISO-8859-1' ?>\n";
    if ( $action eq 'get_species' ) {
        $self->get_species( apr => $apr, );
    }
    elsif ( $action eq 'get_map_sets' ) {
        $self->get_map_sets( apr => $apr, );
    }
    elsif ( $action eq 'get_maps' ) {
        $self->get_maps( apr => $apr, );
    }
    elsif ( $action eq 'get_map_data' ) {
        $self->get_map_data( apr => $apr, );
    }
    else {
        print "<err>Incorrect or Absent Action Parameter.</err>";
    }
    return 1;
}

# ----------------------------------------------------

=pod

=head2 get_species

Used when url contains by "action=get_species"

=head3 Parameters

=over 4

=item * apr (the object that holds parameters)

=back

=cut

sub get_species {

    my ( $self, %args ) = @_;
    my $apr = $args{'apr'};
    print "<species_listing>\n";
    my $species_data = $self->sql()->get_species();
    foreach my $species ( @{ $species_data || [] } ) {
        print "<species acc='" . $species->{'species_acc'} . "'>\n";
        print "<species_common_name>"
            . $species->{'species_common_name'}
            . "</species_common_name>\n";
        print "<species_full_name>"
            . $species->{'species_full_name'}
            . "</species_full_name>\n";
        print "</species>\n";
    }
    print "</species_listing>\n";
}

# ----------------------------------------------------

=pod

=head2 get_map_sets

Used when url contains by "action=get_map_sets"

=head3 URL Parameters

=over 4

=item * species_acc [Optional]

If specified, the method will only print map sets that are in this species.

=item * ref# [Optional]

The "ref#" params (where # is a number starting with 0) hold map_accs of each
map being displayed currently.  These are treated as reference maps.  If
specified, this will only return map_sets that have correspondences to the
reference maps.

If not specified, this will print all map sets.

Example:  "ref0=2442;ref1=1221"

=back

=cut

sub get_map_sets {

    my ( $self, %args ) = @_;
    my $apr = $args{'apr'};
    my $species_acc = $apr->param('species_acc') || undef;

    my @corresponding_map_set_accs;
    if ( $apr->param('ref0') ) {
        my $step = 0;
        my @map_accs;
        while ( my $map_acc = $apr->param( 'ref' . $step ) ) {
            push @map_accs, $map_acc;
            $step++;
        }

        my %corresponding_maps = $self->get_corresponding_objects(
            map_accs     => \@map_accs,
            species_acc2 => $species_acc,
            key_param    => 'map_set_acc2',
        );
        @corresponding_map_set_accs = keys %corresponding_maps;
    }
    else {

        my $map_set_data
            = $self->sql()->get_map_sets( species_acc => $species_acc, );
        foreach my $map_set ( @{ $map_set_data || [] } ) {
            push @corresponding_map_set_accs, $map_set->{'map_set_acc'};
        }
    }

    print "<map_set_listing>\n";
    foreach my $map_set_acc (@corresponding_map_set_accs) {
        print "<map_set>$map_set_acc</map_set>\n";
    }
    print "</map_set_listing>\n";
}

# ----------------------------------------------------

=pod

=head2 get_maps

Used when url contains by "action=get_maps"

Prints xml that describe map ids.

=head3 URL Parameters

=over 4

=item * map_set_acc [Optional]

If specified, the method will only print maps that are in this map set.

=item * ref# [Optional]

The "ref#" params (where # is a number starting with 0) hold map_accs of each
map being displayed currently.  These are treated as reference maps.  If
specified, this will only return maps that have correspondences to the
reference maps.

If not specified, this will return all maps.

Example:  "ref0=2442;ref1=1221"

=back

=cut

sub get_maps {

    my ( $self, %args ) = @_;
    my $apr = $args{'apr'};
    my $map_set_acc = $apr->param('map_set_acc') || undef;

    my @corresponding_map_accs;
    if ( $apr->param('ref0') ) {
        my $step = 0;
        my @map_accs;
        while ( my $map_acc = $apr->param( 'ref' . $step ) ) {
            push @map_accs, $map_acc;
            $step++;
        }

        my %corresponding_maps = $self->get_corresponding_objects(
            map_accs     => \@map_accs,
            map_set_acc2 => $map_set_acc,
            key_param    => 'map_acc2',
        );
        @corresponding_map_accs = keys %corresponding_maps;
    }
    else {
        my $map_data = $self->sql()->get_maps( map_set_acc => $map_set_acc, );
        foreach my $map ( @{ $map_data || [] } ) {
            push @corresponding_map_accs, $map->{'map_acc'};
        }
    }

    print "<map_listing>\n";
    foreach my $map_acc (@corresponding_map_accs) {
        print qq[<map acc="$map_acc"/>\n];
    }
    print "</map_listing>\n";
}

sub get_corresponding_objects {

    my ( $self, %args ) = @_;
    my $map_accs     = $args{'map_accs'};
    my $key_param    = $args{'key_param'};
    my $other_params = $args{'other_params'};
    my $species_acc2 = $args{'species_acc2'} || undef;
    my $map_set_acc2 = $args{'map_set_acc2'} || undef;

    my %map_acc_is_reference;
    foreach my $map_acc ( @{ $map_accs || [] } ) {
        $map_acc_is_reference{$map_acc} = 1;
    }

    my %param_hash;
    foreach my $map_acc ( @{ $map_accs || [] } ) {
        my $map_id = $self->sql->acc_id_to_internal_id(
            acc_id      => $map_acc,
            object_type => 'map',
        );

        my $corr_data = $self->sql()->get_feature_correspondence_details(
            disregard_evidence_type => 1,
            map_id1                 => $map_id,
            species_acc2            => $species_acc2,
            map_set_acc2            => $map_set_acc2,
            unordered               => 1,
        );
        foreach my $corr ( @{ $corr_data || [] } ) {
            next if ( $param_hash{ $corr->{$key_param} } );
            next if ( $map_acc_is_reference{ $corr->{'map_acc2'} } );

            my %params;
            foreach my $other_param ( @{ $other_params || [] } ) {
                $params{$other_param} = $corr->{$key_param};
            }
            $param_hash{ $corr->{$key_param} } = \%params;
        }
    }

    return %param_hash;
}

# ----------------------------------------------------

=pod

=head2 get_map_data

Used when url contains by "action=get_map_data"

Prints xml that describe map ids.

=head3 URL Parameters

=over 4

=item * map_set_acc [Optional]

If specified, the method will only print map_data that are in this map set.

=item * map_acc# [Optional]

The "map_acc#" params (where # is a number starting with 0) hold map_accs of each
map being displayed currently.  These are the maps for which data will be
printed.

If not specified, this will return all maps.

Example:  "ref0=2442;ref1=1221"

=back

=cut

sub get_map_data {

    my ( $self, %args ) = @_;
    my $apr = $args{'apr'};

    # Print the starting cmap3d tag
    my $cmap_version   = $Bio::GMOD::CMap::VERSION;
    my $server_version = "1.2";
    my $client_version = "0150";
    print
        qq[<cmap3d server="$server_version" client="$client_version" cmap="$cmap_version">\n];

    # Extract the map ids from the param list
    my @map_accs;
    foreach my $map_acc_param ( sort grep /^map_acc\d+$/, $apr->param() ) {
        push @map_accs, $apr->param($map_acc_param);
    }
    if (@map_accs) {
        my @map_ids;
        my %map_id_to_acc;
        foreach my $map_acc (@map_accs) {
            my $map_id = $self->sql->acc_id_to_internal_id(
                acc_id      => $map_acc,
                object_type => 'map',
            );
            next unless ($map_id);
            push @map_ids, $map_id;
            $map_id_to_acc{$map_id} = $map_acc;
        }

        # Feature Types
        $self->print_feature_types( map_ids => \@map_ids, );

        # Maps and Features
        print qq[<maps>\n];
        foreach my $map_id (@map_ids) {
            $self->print_map( map_id => $map_id, );
        }
        print qq[</maps>\n];

        # Correspondences
        $self->print_correspondences(
            map_ids       => \@map_ids,
            map_id_to_acc => \%map_id_to_acc,
        );
    }

    # Close the cmap3d tag
    print qq[</cmap3d>\n];
}

# ----------------------------------------------------

=pod

=head2 print_feature_types

=cut

sub print_feature_types {

    my ( $self, %args ) = @_;
    my $map_ids = $args{'map_ids'};

    my $feature_count_by_type = $self->sql()->get_feature_count(
        map_ids               => $map_ids,
        group_by_feature_type => 1,
    );
    return unless ( @{ $feature_count_by_type || [] } );

    print "<types>\n";
    foreach my $feature_type_count (@$feature_count_by_type) {
        print qq[<type value="]
            . $feature_type_count->{'feature_type_acc'}
            . qq["/>\n];
    }
    print "</types>\n";

    return;
}

# ----------------------------------------------------

=pod

=head2 print_map

=cut

sub print_map {

    my ( $self, %args ) = @_;
    my $map_id = $args{'map_id'};

    my $map_data = $self->sql()->get_maps( map_id => $map_id, );
    return unless ( @{ $map_data || [] } );
    my $map = $map_data->[0];

    my %feature_return_values
        = $self->create_feature_xml( map_id => $map_id );

    my $map_xml = q[<map ];
    foreach my $attribute (
        qw(
        map_id
        map_acc
        map_set_id
        map_name
        display_order
        map_start
        map_stop
        map_units
        )
        )
    {
        $map_xml .= qq[$attribute="] . $map->{$attribute} . q[" ];
    }
    $map_xml .= qq[ranged_count="]
        . $feature_return_values{'ranged_features_count'} . q[" ];
    $map_xml .= qq[singular_count="]
        . $feature_return_values{'singular_features_count'} . q[" ];
    $map_xml
        .= qq[feature_count="]
        . (   $feature_return_values{'ranged_features_count'}
            + $feature_return_values{'singular_features_count'} )
        . q[" ];
    $map_xml .= qq[>\n];

    # Open Map
    print $map_xml;

    # Map Details
    print "<map_details>\n";
    print "<map_name>" . $map->{'map_name'} . "</map_name>\n";
    print "</map_details>\n";

    # Print the features
    print $feature_return_values{'ranged_features_xml'};
    print $feature_return_values{'singular_features_xml'};

    # Close Map
    print "</map>\n";

    return;
}

# ----------------------------------------------------

=pod

=head2 print_correspondences

=cut

sub print_correspondences {

    my ( $self, %args ) = @_;
    my $map_ids       = $args{'map_ids'};
    my $map_id_to_acc = $args{'map_id_to_acc'};
    return unless @{ $map_ids || [] };

    print "<correspondences>\n";
    for ( my $i = 0; $i <= $#{$map_ids} - 1; $i++ ) {
        my $map_id1  = $map_ids->[$i];
        my $map_acc1 = $map_id_to_acc->{$map_id1};
        for ( my $j = $i + 1; $j <= $#{$map_ids}; $j++ ) {
            my $map_id2 = $map_ids->[$j];
            my $corrs   = $self->sql->get_feature_correspondence_details(
                map_id1                 => $map_id1,
                map_id2                 => $map_id2,
                disregard_evidence_type => 1,
                unordered               => 1,
            );
            foreach my $corr ( @{ $corrs || [] } ) {
                $corr->{'map_acc1'} = $map_acc1;
                my $corr_xml = q[<correspondence ];
                foreach my $attribute (
                    qw(
                    feature_correspondence_id
                    feature_acc1
                    feature_acc2
                    map_acc1
                    map_acc2
                    feature_type_acc1
                    feature_type_acc2
                    )
                    )
                {
                    $corr_xml
                        .= qq[$attribute="] . $corr->{$attribute} . q[" ];
                }
                $corr_xml .= qq[/>\n];
                print $corr_xml;
            }
        }
    }
    print "</correspondences>\n";

    return;
}

# ----------------------------------------------------

=pod

=head2 create_feature_xml

Takes a map_id.

Returns a hash.

    $return = {
        ranged_features_xml     => $ranged_features_xml,
        singular_features_xml   => $singular_features_xml,
        ranged_features_count   => $ranged_features_count,
        singular_features_count => $singular_features_count,
    };

=cut

sub create_feature_xml {

    my ( $self, %args ) = @_;
    my $map_id = $args{'map_id'};

    my $features = $self->sql()->get_features( map_id => $map_id );

    my $ranged_count   = 0;
    my $singular_count = 0;
    my $ranged_xml     = '';
    my $singular_xml   = '';

    my %ranged_features_by_type;
    my %singular_features_by_type;
    foreach my $feature ( @{ $features || [] } ) {
        if ( $feature->{'feature_start'} == $feature->{'feature_stop'} ) {
            $singular_count++;
            push @{ $singular_features_by_type{ $feature->{
                        'feature_type_acc'} } }, $feature;
        }
        else {
            $ranged_count++;
            push @{ $ranged_features_by_type{ $feature->{
                        'feature_type_acc'} } }, $feature;
        }
    }

    if (%ranged_features_by_type) {
        $ranged_xml .= qq[<ranged_features>\n];
        foreach my $feature_type_acc ( keys %ranged_features_by_type ) {
            $ranged_xml .= qq[<features type="$feature_type_acc">\n];
            foreach my $feature (
                @{ $ranged_features_by_type{$feature_type_acc} || [] } )
            {

                $ranged_xml .= $self->create_individual_feature_xml(
                    feature => $feature );

            }
            $ranged_xml .= qq[</features>\n];
        }

        $ranged_xml .= qq[</ranged_features>\n];
    }

    if (%singular_features_by_type) {
        $singular_xml .= qq[<singular_features>\n];
        foreach my $feature_type_acc ( keys %singular_features_by_type ) {
            $singular_xml .= qq[<features type="$feature_type_acc">\n];
            foreach my $feature (
                @{ $singular_features_by_type{$feature_type_acc} || [] } )
            {

                $singular_xml .= $self->create_individual_feature_xml(
                    feature => $feature );

            }
            $singular_xml .= qq[</features>\n];
        }

        $singular_xml .= qq[</singular_features>\n];
    }

    return (
        ranged_features_xml     => $ranged_xml,
        singular_features_xml   => $singular_xml,
        ranged_features_count   => $ranged_count,
        singular_features_count => $singular_count,
    );
}

# ----------------------------------------------------

=pod

=head2 create_individual_feature_xml

Takes a hash of feature data (from get_features).

Returns an xml entry

=cut

sub create_individual_feature_xml {

    my ( $self, %args ) = @_;
    my $feature = $args{'feature'};

    my $feature_xml = q[<feature ];
    foreach my $attribute (
        qw(
        feature_id
        feature_acc
        feature_type_acc
        feature_name
        is_landmark
        feature_start
        feature_stop
        default_rank
        direction
        )
        )
    {
        $feature_xml .= qq[$attribute="] . $feature->{$attribute} . q[" ];
    }
    $feature_xml .= qq[/>\n];

    return $feature_xml;
}

1;

=head1 NAME

Bio::GMOD::CMap::Apache::CMap3D - handles data requests from CMap3D

=head1 DESCRIPTION

This module serves data to the CMap3D viewer being developed by Chris Duran and
Dave Edwards.

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.

Ported from PHP scripts by Chris Duran.

=head1 COPYRIGHT

Copyright (c) 2008 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

