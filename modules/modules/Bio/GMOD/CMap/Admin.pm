package Bio::GMOD::CMap::Admin;

# vim: set ft=perl:

# $Id: Admin.pm,v 1.110 2008/05/23 14:10:06 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Admin - admin functions (update, create, etc.)

=head1 SYNOPSIS

Create an Admin object to have access to its data manipulation methods.
The "data_source" parameter is a string of the name of the data source 
to be used.  This information is found in the config file as the 
"<database>" name field.

  use Bio::GMOD::CMap::Admin;

  my $admin = Bio::GMOD::CMap::Admin->new(
      config      => $self->config,
      data_source => $data_source
  );

=head1 DESCRIPTION

This module gives access to many data manipulation methods.

Eventually all the database interaction currently in
Bio::GMOD::CMap::Apache::AdminViewer will be moved here so that it can be
shared by my "cmap_admin.pl" script.

=head1 METHODS

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.110 $)[-1];

use Data::Dumper;
use Data::Pageset;
use Time::ParseDate;
use Time::Piece;
use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Utils qw[ parse_words ];
use base 'Bio::GMOD::CMap';
use Bio::GMOD::CMap::Constants;
use Regexp::Common;
use Storable qw(nfreeze thaw);

# ----------------------------------------------------
sub attribute_create {

=pod

=head2 attribute_create

=head3 For External Use

=over 4

=item * Description

attribute_create

=item * Usage

    $admin->attribute_create(
        object_id       => $object_id,
        attribute_name  => $attribute_name,
        attribute_value => $attribute_value,
        object_type     => $object_type,
        display_order   => $display_order,
        is_public       => $is_public,
    );

=item * Returns

XRef ID

=item * Fields

=over 4

=item - object_id

The primary key of the object.

=item - attribute_name

=item - attribute_value

=item - object_type

The name of the table being reference.

=item - display_order

=item - is_public

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $sql_object  = $self->sql or return $self->error;
    my @missing     = ();
    my $object_id   = $args{'object_id'} || 0;
    my $object_type = $args{'object_type'}
        or push @missing, 'database object (table name)';
    my $attribute_name = $args{'attribute_name'}
        or push @missing, 'attribute name';
    my $attribute_value = $args{'attribute_value'}
        or push @missing, 'attribute value';
    my $display_order = $args{'display_order'};
    my $is_public     = $args{'is_public'};
    my $attribute_id;

    if (@missing) {
        return $self->error(
            'Cross-reference create failed.  Missing required fields: ',
            join( ', ', @missing ) );
    }

    #
    # See if one like this exists already.
    #
    my $attributes = $sql_object->get_attributes(
        object_type     => $object_type,
        object_id       => $object_id,
        attribute_name  => $attribute_name,
        attribute_value => $attribute_value,
    );

    if (@$attributes) {
        my $attribute = $attributes->[0];
        $attribute_id = $attribute->{'attribute_id'};
        if ((   defined $display_order
                && $attribute->{'display_order'} != $display_order
            )
            or ( defined $is_public
                && $attribute->{'is_public'} != $is_public )
            )
        {
            $sql_object->update_attributes(
                display_order => $display_order,
                is_public     => $is_public,
                attribute_id  => $attribute_id,
            );
        }
    }
    else {
        $attribute_id = $self->set_attributes(
            object_id   => $object_id,
            object_type => $object_type,
            attributes  => [
                {   name          => $attribute_name,
                    value         => $attribute_value,
                    display_order => $display_order,
                    is_public     => $is_public,
                },
            ],
        ) or return $self->error;
    }

    return $attribute_id;
}

# ----------------------------------------------------
sub attribute_delete {

=pod

=head2 attribute_delete

=head3 For External Use

=over 4

=item * Description

Delete an object's attributes.

=item * Usage

    $admin->attribute_delete(
        $object_type,
        $object_id
    );

=item * Returns

Nothing

=item * Fields

=over 4

=item - object_type

The name of the object being reference.

=item - object_id

The primary key of the object.

=back

=back

=cut

    my $self        = shift;
    my $object_type = shift or return;
    my $object_id   = shift or return;
    my $sql_object  = $self->sql or return;

    $sql_object->delete_attribute(
        object_type => $object_type,
        object_id   => $object_id,
    );
}

# ----------------------------------------------------
sub correspondence_evidence_delete {

=pod

=head2 correspondence_evidence_delete

=head3 For External Use

=over 4

=item * Description

Delete a correspondence evidence.

=item * Usage

    $admin->correspondence_evidence_delete(
        correspondence_evidence_id => $correspondence_evidence_id,
    );

=item * Returns

Nothing

=item * Fields

=over 4

=item - correspondence_evidence_id

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $corr_evidence_id = $args{'correspondence_evidence_id'}
        or return $self->error('No correspondence evidence id');
    my $sql_object = $self->sql;

    my $evidences = $sql_object->get_correspondence_evidences(
        correspondence_evidence_id => $corr_evidence_id, );
    return $self->error('Invalid correspondence evidence id')
        unless (@$evidences);
    my $feature_correspondence_id
        = $evidences->[0]{'feature_correspondence_id'};

    $self->attribute_delete( 'correspondence_evidence', $corr_evidence_id );
    $self->xref_delete( 'correspondence_evidence', $corr_evidence_id );

    $sql_object->delete_evidence(
        correspondence_evidence_id => $corr_evidence_id, );

    return $feature_correspondence_id;
}

# ----------------------------------------------------
sub feature_copy {

=pod

=head2 feature_copy

=head3 For External Use

=over 4

=item * Description

Create a new feature from an old one.  Copy all
correspondences/attributes/xrefs to the new feature.

=item * Usage

    $admin->feature_copy(
        ori_feature_id => $ori_feature_id,
        map_id => $map_id,
        feature_name => $feature_name,
        feature_acc => $feature_acc,
        feature_start => $feature_start,
        feature_stop => $feature_stop,
        is_landmark => $is_landmark,
        feature_type_acc => $feature_type_acc,
        direction => $direction,
    );

=item * Returns

Feature ID

=item * Required Fields

=over 4

=item - ori_feature_id

Identifier of the original feature that will be copied

=back

=item * Optional Fields

=over 4

=item - new_feature_id

Optional identifier of the feature that will have information copied to it.  If
this is not given, a new feature will be created

=back

=item * Feature Creation Fields

These are only used to create a new feature when "new_feature_id" is not given.
Any options not given will be copied from the original feature (exept
feature_acc).

=over 4

=item - map_id

Identifier of the map that this is on.

=item - feature_name

=item - feature_acc

Identifier that is used to access this object.  Can be alpha-numeric.  
If not defined, the object_id will be assigned to it.

=item - feature_start

Location on the map where this feature begins.

=item - feature_stop

Location on the map where this feature ends. (not required)

=item - is_landmark

Declares the feature to be a landmark.

=item - feature_type_acc

The accession id of a feature type that is defined in the config file.

=item - direction

The direction the feature points in relation to the map.

=back

=back

=cut

    my ( $self, %args ) = @_;
    my @missing          = ();
    my $ori_feature_id   = $args{'ori_feature_id'};
    my $new_feature_id   = $args{'new_feature_id'};
    my $map_id           = $args{'map_id'};
    my $feature_acc      = $args{'feature_acc'};
    my $feature_name     = $args{'feature_name'};
    my $feature_type_acc = $args{'feature_type_acc'};
    my $feature_start    = $args{'feature_start'};
    my $feature_stop     = $args{'feature_stop'};
    my $is_landmark      = $args{'is_landmark'};
    my $direction        = $args{'direction'};
    my $sql_object       = $self->sql or return $self->error;

    my $ori_features
        = $sql_object->get_features_simple( feature_id => $ori_feature_id, );
    return unless ( $ori_features and @$ori_features );
    my $ori_feature = $ori_features->[0];
    $map_id = $ori_feature->{'map_id'} unless ( defined $map_id );
    $feature_name = $ori_feature->{'feature_name'}
        unless ( defined $feature_name );
    $feature_type_acc = $ori_feature->{'feature_type_acc'}
        unless ( defined $feature_type_acc );
    $feature_start = $ori_feature->{'feature_start'}
        unless ( defined $feature_start );
    $feature_stop = $ori_feature->{'feature_stop'}
        unless ( defined $feature_stop );
    $is_landmark = $ori_feature->{'is_landmark'}
        unless ( defined $is_landmark );
    $direction = $ori_feature->{'direction'} unless ( defined $direction );

    my $default_rank = $ori_feature->{'default_rank'};

    unless ($new_feature_id) {
        $new_feature_id = $self->feature_create(
            map_id           => $map_id,
            feature_name     => $feature_name,
            feature_acc      => $feature_acc,
            feature_type_acc => $feature_type_acc,
            feature_start    => $feature_start,
            feature_stop     => $feature_stop,
            is_landmark      => $is_landmark,
            direction        => $direction,
            default_rank     => $default_rank,
        );
    }

    # Copy DBXrefs and Attributes
    $self->copy_attributes(
        ori_object_id => $ori_feature_id,
        new_object_id => $new_feature_id,
        object_type   => 'feature',
    );
    $self->copy_xrefs(
        ori_object_id => $ori_feature_id,
        new_object_id => $new_feature_id,
        object_type   => 'feature',
    );

    # Copy Correspondences
    $self->copy_correspondences(
        ori_object_id => $ori_feature_id,
        new_object_id => $new_feature_id,
    );

    return $new_feature_id;
}

# ----------------------------------------------------
sub copy_attributes {

=pod

=head2 copy_attributes

=head3 For External Use

=over 4

=item * Description

Copy attributes from one object to another.

=item * Usage

    $admin->copy_attribute(
        ori_object_id => $ori_object_id,
        new_object_id => $new_object_id,
        object_type    => $object_type,
    );

=item * Returns

1

=item * Required Fields

=over 4

=item - ori_object_id

Identifier of the original object that will be copied

=item - new_object_id

Identifier of the object that will have information copied to it.

=item - object_type

The type of item that is being copied to.

=back

=back

=cut

    my ( $self, %args ) = @_;
    my @missing       = ();
    my $ori_object_id = $args{'ori_object_id'} or return 0;
    my $new_object_id = $args{'new_object_id'} or return 0;
    my $object_type   = $args{'object_type'} or return 0;
    my $sql_object    = $self->sql or return $self->error;

    my $ori_attributes = $sql_object->get_attributes(
        object_id   => $ori_object_id,
        object_type => $object_type,
    );
    foreach my $ori_attribute ( @{ $ori_attributes || [] } ) {
        $self->attribute_create(
            object_id       => $new_object_id,
            attribute_name  => $ori_attribute->{'attribute_name'},
            attribute_value => $ori_attribute->{'attribute_value'},
            object_type     => $object_type,
            display_order   => $ori_attribute->{'display_order'},
        );

    }

    return 1;
}

# ----------------------------------------------------
sub copy_xrefs {

=pod

=head2 copy_xrefs

=head3 For External Use

=over 4

=item * Description

Copy xrefs from one object to another.

=item * Usage

    $admin->copy_xref(
        ori_object_id => $ori_object_id,
        new_object_id => $new_object_id,
        object_type    => $object_type,
    );

=item * Returns

1

=item * Required Fields

=over 4

=item - ori_object_id

Identifier of the original object that will be copied

=item - new_object_id

Identifier of the object that will have information copied to it.

=item - object_type

The type of item that is being copied to.

=back

=back

=cut

    my ( $self, %args ) = @_;
    my @missing       = ();
    my $ori_object_id = $args{'ori_object_id'} or return 0;
    my $new_object_id = $args{'new_object_id'} or return 0;
    my $object_type   = $args{'object_type'} or return 0;
    my $sql_object    = $self->sql or return $self->error;

    my $ori_xrefs = $sql_object->get_xrefs(
        object_id   => $ori_object_id,
        object_type => $object_type,
    );
    foreach my $ori_xref ( @{ $ori_xrefs || [] } ) {
        $self->xref_create(
            object_id     => $new_object_id,
            xref_name     => $ori_xref->{'xref_name'},
            xref_url      => $ori_xref->{'xref_url'},
            object_type   => $object_type,
            display_order => $ori_xref->{'display_order'},
        );

    }

    return 1;
}

# ----------------------------------------------------
sub copy_correspondences {

=pod

=head2 copy_correspondences

=head3 For External Use

=over 4

=item * Description

Copy correspondences from one feature to another.

=item * Usage

    $admin->copy_correspondence(
        ori_feature_id => $ori_feature_id,
        new_feature_id => $new_feature_id,
    );

=item * Returns

1

=item * Required Fields

=over 4

=item - ori_feature_id

Identifier of the original feature that will be copied

=item - new_feature_id

Identifier of the feature that will have information copied to it.

=back

=back

=cut

    my ( $self, %args ) = @_;
    my @missing        = ();
    my $ori_feature_id = $args{'ori_feature_id'} or return 0;
    my $new_feature_id = $args{'new_feature_id'} or return 0;
    my $sql_object     = $self->sql or return $self->error;

    my $ori_correspondences = $sql_object->get_feature_correspondence_details(
        feature_id1 => $ori_feature_id, );
    my $last_corr_id;
    my @evidence    = ();
    my %last_params = ();
    foreach my $ori_correspondence ( @{ $ori_correspondences || [] } ) {
        if ( defined($last_corr_id)
            and $last_corr_id ne
            $ori_correspondence->{'feature_correspondence_id'} )
        {
            $self->feature_correspondence_create(
                correspondence_evidence => \@evidence,
                %last_params,
            );
            @evidence    = ();
            %last_params = ();
        }

        $last_corr_id = $ori_correspondence->{'feature_correspondence_id'};

        %last_params = (
            feature_id1  => $new_feature_id,
            feature_id2  => $ori_correspondence->{'feature_id2'},
            feature_acc1 => $ori_correspondence->{'feature_acc1'},
            feature_acc2 => $ori_correspondence->{'feature_acc2'},
            is_enabled   => $ori_correspondence->{'is_enabled'},
        );
        push @evidence,
            {
            evidence_type_acc => $ori_correspondence->{'evidence_type_acc'},
            score             => $ori_correspondence->{'score'},
            };
    }
    if ( defined($last_corr_id) ) {
        $self->feature_correspondence_create(
            correspondence_evidence => \@evidence,
            %last_params,
        );
    }

    return 1;
}

# ----------------------------------------------------
sub feature_create {

=pod

=head2 feature_create

=head3 For External Use

=over 4

=item * Description

Create a feature.

=item * Usage

    $admin->feature_create(
        map_id => $map_id,
        feature_name => $feature_name,
        feature_acc => $feature_acc,
        feature_start => $feature_start,
        feature_stop => $feature_stop,
        is_landmark => $is_landmark,
        feature_type_acc => $feature_type_acc,
        direction => $direction,
        #gclass => $gclass,
    );

=item * Returns

Feature ID

=item * Fields

=over 4

=item - map_id

Identifier of the map that this is on.

=item - feature_name

=item - feature_acc

Identifier that is used to access this object.  Can be alpha-numeric.  
If not defined, the object_id will be assigned to it.

=item - feature_start

Location on the map where this feature begins.

=item - feature_stop

Location on the map where this feature ends. (not required)

=item - is_landmark

Declares the feature to be a landmark.

=item - feature_type_acc

The accession id of a feature type that is defined in the config file.

=item - direction

The direction the feature points in relation to the map.

=item - gclass

The gclass that the feature will have.  This only relates to using CMap
integrated with GBrowse and should not be used otherwise. 

=back

=back

=cut

    my ( $self, %args ) = @_;
    my @missing      = ();
    my $map_id       = $args{'map_id'} or push @missing, 'map_id';
    my $feature_acc  = $args{'feature_acc'};
    my $feature_name = $args{'feature_name'}
        or push @missing, 'feature_name';
    my $feature_type_acc = $args{'feature_type_acc'}
        or push @missing, 'feature_type_acc';
    my $feature_start = $args{'feature_start'};
    push @missing, 'feature_start' unless $feature_start =~ /^$RE{'num'}{'real'}$/;
    my $feature_stop = $args{'feature_stop'};
    my $is_landmark  = $args{'is_landmark'} || 0;
    my $direction    = $args{'direction'} || 1;
    my $gclass       = $args{'gclass'};
    $gclass = undef unless ( $self->config_data('gbrowse_compatible') );
    my $sql_object = $self->sql or return $self->error;

    my $default_rank
        = $self->feature_type_data( $feature_type_acc, 'default_rank' ) || 1;

    if (@missing) {
        return die 'Feature create failed.  Missing required fields: ',
            join( ', ', @missing );
    }

    my $feature_id = $sql_object->insert_feature(
        map_id           => $map_id,
        feature_name     => $feature_name,
        feature_acc      => $feature_acc,
        feature_type_acc => $feature_type_acc,
        feature_start    => $feature_start,
        feature_stop     => $feature_stop,
        is_landmark      => $is_landmark,
        direction        => $direction,
        default_rank     => $default_rank,
        gclass           => $gclass,
    );

    return $feature_id;
}

# ----------------------------------------------------
sub feature_alias_create {

=pod

=head2 feature_alias_create

=head3 For External Use

=over 4

=item * Description

Create an alias for a feature.  The alias is searchable.

=item * Usage

    $admin->feature_alias_create(
        feature_id => $feature_id,
        alias => $alias,
    );

=item * Returns

1

=item * Fields

=over 4

=item - feature_id

=item - alias

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $sql_object = $self->sql;
    my $feature_id = $args{'feature_id'}
        or return $self->error('No feature id');
    my $alias = $args{'alias'} or return 1;
    my $features
        = $sql_object->get_features_simple( feature_id => $feature_id, );

    if ( !@$features or $alias eq $features->[0]{'feature_name'} ) {
        return 1;
    }

    my $feature_aliases = $sql_object->get_feature_aliases(
        alias      => $alias,
        feature_id => $feature_id,
    );
    return 1 if (@$feature_aliases);

    my $feature_alias_id = $sql_object->insert_feature_alias(
        alias      => $alias,
        feature_id => $feature_id,
    );

    return $feature_alias_id;
}

# ----------------------------------------------------
sub feature_delete {

=pod

=head2 feature_delete

=head3 For External Use

=over 4

=item * Description

Delete a feature.

=item * Usage

    $admin->feature_delete(
        feature_id => $feature_id,
    );

=item * Returns

Nothing

=item * Fields

=over 4

=item - feature_id

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $feature_id = $args{'feature_id'}
        or return $self->error('No feature id');

    my $sql_object = $self->sql or return;

    my $features = $sql_object->get_features( feature_id => $feature_id, );
    return $self->error('Invalid feature id')
        unless (@$features);

    my $map_id = $features->[0]{'map_id'};

    my $corrs = $sql_object->get_feature_correspondence_details(
        feature_id1             => $feature_id,
        disregard_evidence_type => 1,
    );
    foreach my $corr (@$corrs) {
        $self->feature_correspondence_delete(
            feature_correspondence_id => $corr->{'feature_correspondence_id'},
        );
    }

    $self->attribute_delete( 'feature', $feature_id );
    $self->xref_delete( 'feature', $feature_id );

    $sql_object->delete_feature_alias( feature_id => $feature_id, );

    $sql_object->delete_feature( feature_id => $feature_id, );

    return $map_id;
}

# ----------------------------------------------------
sub feature_correspondence_create {

=pod

=head2 feature_correspondence_create

=head3 For External Use

=over 4

=item * Description

Inserts a correspondence.  Returns -1 if there is nothing to do.

=item * Usage

Requires feature_ids or feature accessions for both features.

    $admin->feature_correspondence_create(
        feature_id1 => $feature_id1,
        feature_id2 => $feature_id2,
        feature_acc1 => $feature_acc1,
        feature_acc2 => $feature_acc2,
        is_enabled => $is_enabled,
        evidence_type_acc => $evidence_type_acc,
        correspondence_evidence => $correspondence_evidence,
        feature_correspondence_acc => $feature_correspondence_acc,
    );

=item * Returns

Correpondence ID

=item * Fields

=over 4

=item - feature_id1

=item - feature_id2

=item - feature_acc1

=item - feature_acc2

=item - is_enabled

=item - evidence_type_acc

The accession id of a evidence type that is defined in the config file.

=item - correspondence_evidence

List of evidence hashes that correspond to the evidence types that this 
correspondence should have.  The hashes must have a "evidence_type_acc"
key.

=item - feature_correspondence_acc

Identifier that is used to access this object.  Can be alpha-numeric.  
If not defined, the object_id will be assigned to it.

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $feature_id1                = $args{'feature_id1'};
    my $feature_id2                = $args{'feature_id2'};
    my $feature_acc1               = $args{'feature_acc1'};
    my $feature_acc2               = $args{'feature_acc2'};
    my $evidence_type_acc          = $args{'evidence_type_acc'};
    my $score                      = $args{'score'};
    my $evidence                   = $args{'correspondence_evidence'};
    my $feature_correspondence_acc = $args{'feature_correspondence_acc'}
        || '';
    my $is_enabled = $args{'is_enabled'};
    $is_enabled = 1 unless defined $is_enabled;
    my $threshold = $args{'threshold'} || 0;
    my $sql_object = $self->sql or return;

    unless ( $feature_id1 or $feature_acc1 ) {

        # Flush the buffer;
        $sql_object->insert_feature_correspondence( threshold => 0, );
    }

    my $allow_update
        = defined( $args{'allow_update'} )
        ? $args{'allow_update'}
        : 1;

    if ($evidence_type_acc) {
        push @$evidence,
            {
            evidence_type_acc => $evidence_type_acc,
            score             => $score,
            };
    }

    #
    # See if we have only accession IDs and if we can find feature IDs.
    #
    if ( !$feature_id1 && $feature_acc1 ) {
        $feature_id1 = $sql_object->acc_id_to_internal_id(
            object_type => 'feature',
            acc_id      => $feature_acc1,
        );
    }

    if ( !$feature_id2 && $feature_acc2 ) {
        $feature_id2 = $sql_object->acc_id_to_internal_id(
            object_type => 'feature',
            acc_id      => $feature_acc2,
        );
    }

    #
    # Bail if no feature IDs.
    #
    return -1 unless $feature_id1 && $feature_id2;

    #
    # Bail if features are the same.
    #
    return -1 if $feature_id1 == $feature_id2;

    #
    # Bail if no evidence.
    #$self->error('No evidence')
    return -1
        unless @{ $evidence || [] };

    my $feature_correspondence_id = '';
    if ($allow_update) {

        #
        # See if a correspondence exists already.
        #
        my $corrs = $sql_object->get_feature_correspondence_details(
            feature_id1             => $feature_id1,
            feature_id2             => $feature_id2,
            disregard_evidence_type => 1,
        );
        if (@$corrs) {
            $feature_correspondence_id
                = $corrs->[0]{'feature_correspondence_id'};
        }
    }
    if ($feature_correspondence_id) {

        #
        # Add new evidences to correspondence
        # Skip if a correspondence with this evidence type exists already.
        #

        for ( my $i = 0; $i <= $#{$evidence}; $i++ ) {
            my $evidence_array = $sql_object->get_correspondence_evidences(
                feature_correspondence_id => $feature_correspondence_id,
                evidence_type_acc => $evidence->[$i]{'evidence_type_acc'},
            );
            next if @$evidence_array;

            $sql_object->insert_correspondence_evidence(
                feature_correspondence_id => $feature_correspondence_id,
                evidence_type_acc => $evidence->[$i]{'evidence_type_acc'},
                score             => $evidence->[$i]{'score'},
            );
        }
    }
    else {

        # New Correspondence

        $feature_correspondence_id
            = $sql_object->insert_feature_correspondence(
            feature_id1 => $feature_id1,
            feature_id2 => $feature_id2,
            is_enabled  => $is_enabled,
            evidence    => $evidence,
            threshold   => $threshold,
            );
    }

    return $feature_correspondence_id || -1;
}

# ----------------------------------------------------
sub delete_duplicate_correspondences {

=pod

=head2 delete_duplicate_correspondences

=head3 For External Use

=over 4

=item * Description

Searches the database for duplicate correspondences and removes one
instance.  Any evidence from the deleted one that is not duplicated 
is moved to the remaining correspondence.

=item * Usage

    $admin->delete_duplicate_correspondences();

Optionally, a map_set_id can be included to limit the ammount of data being
looked at.

=item * Returns

Nothing

=back

=cut

    my ( $self, %args ) = @_;
    my $sql_object = $self->sql or return;
    my $map_set_id = $args{'map_set_id'};

    print "Deleting Duplicate Correspondences\n";
    print "Retrieving list of correspondences\n";
    my $corr_hash = $sql_object->get_duplicate_correspondences_hash(
        map_set_id => $map_set_id, );
    print "Retrieved list of correspondences\n\n";
    print
        "Examining correspondences.\n (A '.' will appear for each deleted correspondence)\n";

    my $feature_count = 0;
    my $delete_count  = 0;
    my $report_num    = 5000;
    ### Move any non-duplicate evidence from the duplicate to the original.
    foreach my $feature_id1 ( keys %{$corr_hash} ) {
        $feature_count++;
        print "Examined $feature_count features.\n"
            unless ( $feature_count % $report_num );
        foreach my $feature_id2 ( keys %{ $corr_hash->{$feature_id1} } ) {
            next
                if (
                scalar( @{ $corr_hash->{$feature_id1}{$feature_id2} } )
                == 1 );

            my @corr_list = sort { $a <=> $b }
                @{ $corr_hash->{$feature_id1}{$feature_id2} };
            my $original_id = shift @corr_list;

            foreach my $duplicate_id (@corr_list) {
                $delete_count++;
                print "Deleted $delete_count duplicates.\n"
                    unless ( $delete_count % $report_num );
                print ".";
                my $move_evidence = $sql_object->get_moveable_evidence(
                    original_id  => $original_id,
                    duplicate_id => $duplicate_id,
                );
                if ( scalar(@$move_evidence) ) {
                    foreach my $evidence_id (@$move_evidence) {
                        $sql_object->update_correspondence_evidence(
                            correspondence_evidence_id => $evidence_id,
                            feature_correspondence_id  => $original_id,
                        );
                    }
                }
                $self->feature_correspondence_delete(
                    feature_correspondence_id => $duplicate_id );
            }
        }
    }
    print "\n\nDone. Deleted $delete_count duplicates.\n";
}

sub purge_cache {

=pod

=head2 purge_cache

=head3 For External Use

=over 4

=item * Description

Purge the query cache from the level supplied on down.

=item * Usage

    $admin->purge_cache( $cache_level );

=item * Returns

Nothing

=item * Fields

=over 4

=item - cache_level

This is the level that you want to purge.

There are four levels of caching.  This is so that if some part of
the database is changed, the whole chache does not have to be purged.
Only the cache level and the levels above it need to be cached.

 Level 1: Species or Map Sets.
 Level 2: Maps
 Level 3: Features
 Level 4: Correspondences
 Level 4: images

For example if features are added, then Level 3,4 and 5 need to be purged.
If a new Map is added, Levels 2,3,4 and 5 need to be purged.


=back

=back

=cut

    my ( $self, @remainder ) = @_;

    # Allow either a parameter list or hash to be passed
    my ( $cache_level, $purge_all, );
    if ( $remainder[0] =~ /^\d$/ ) {
        $cache_level = $remainder[0];
        $purge_all   = $remainder[1];
    }
    else {
        my %args = @remainder;
        $cache_level = $args{'cache_level'};
        $purge_all   = $args{'purge_all'};
    }

    $cache_level = 1 unless $cache_level;

    my @namespaces;
    if ($purge_all) {
        foreach
            my $datasource ( @{ $self->config()->get_config_names() || [] } )
        {
            for ( my $i = $cache_level - 1; $i <= CACHE_LEVELS; $i++ ) {
                push @namespaces, $self->cache_level_name( $i, $datasource )
                    || die $self->ERROR();
            }
        }
    }
    else {
        for ( my $i = $cache_level - 1; $i <= CACHE_LEVELS; $i++ ) {
            push @namespaces,
                $self->cache_level_name($i) || die $self->ERROR();
        }
    }

    foreach my $namespace (@namespaces) {
        my %params = ( 'namespace' => $namespace, );
        my $cache = new Cache::SizeAwareFileCache( \%params );
        $cache->clear;
    }
    return \@namespaces;
}

# ----------------------------------------------------
sub feature_correspondence_delete {

=pod

=head2 feature_correspondence_delete

=head3 For External Use

=over 4

=item * Description

Delete a feature correspondence.

=item * Usage

    $admin->feature_correspondence_delete(
        feature_correspondence_id => $feature_correspondence_id,
    );

=item * Returns

Nothing

=item * Fields

=over 4

=item - feature_correspondence_id

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $feature_correspondence_id = $args{'feature_correspondence_id'}
        or return $self->error('No feature correspondence id');

    my $sql_object = $self->sql or return;

    $sql_object->delete_evidence(
        feature_correspondence_id => $feature_correspondence_id, );

    $sql_object->delete_correspondence(
        feature_correspondence_id => $feature_correspondence_id, );

    $self->attribute_delete( 'feature_correspondence',
        $feature_correspondence_id, );
    $self->xref_delete( 'feature_correspondence', $feature_correspondence_id,
    );

    return 1;
}

# ----------------------------------------------------
sub get_aliases {

=pod

=head2 get_aliases

=head3 For External Use

=over 4

=item * Description

Retrieves the aliases attached to a feature.

=item * Usage

    $admin->get_aliases( $feature_id );

=item * Returns

Arrayref of hashes with keys "feature_alias_id", "feature_id" and "alias".

=back

=cut

    my ( $self, $feature_id ) = @_;
    my $sql_object = $self->sql or return;

    return $sql_object->get_feature_aliases( feature_id => $feature_id, );
}

# ----------------------------------------------------
sub feature_search {

=pod

=head2 feature_search

=head3 For External Use

=over 4

=item * Description

Find all the features matching some criteria.

=item * Usage

None of the fields are required.

    $admin->feature_search(
        search_field => $search_field,
        species_ids => $species_ids,
        order_by => $order_by,
        map_acc => $map_acc,
        feature_type_accs => $feature_type_accs,
    );

=item * Returns

Hash with keys "results" and "pager".

"results": Arrayref of hashes with column names as keys.

"pager": a Data::Pageset object.

=item * Fields

=over 4

=item - feature_name

A string with one or more feature names or accessions to search.

=item - search_field

Eather 'feature_name' or 'feature_acc'

=item - species_ids

=item - order_by

List of columns (in order) to order by. Options are
feature_name, species_common_name, map_set_short_name, map_name and feature_start.

=item - map_acc

=item - feature_type_accs

=back

=back

=cut

    my ( $self, %args ) = @_;
    my @feature_names = (
        map {
            s/\*/%/g;          # turn stars into SQL wildcards
            s/,//g;            # kill commas
            s/^\s+|\s+$//g;    # kill leading/trailing whitespace
            s/"//g;            # kill double quotes
            s/'/\\'/g;         # backslash escape single quotes
            uc $_ || ()        # uppercase what's left
            } parse_words( $args{'feature_name'} )
    );
    my $map_acc           = $args{'map_acc'}           || '';
    my $species_ids       = $args{'species_ids'}       || [];
    my $feature_type_accs = $args{'feature_type_accs'} || [];
    my $search_field      = $args{'search_field'}      || 'feature_name';
    my $order_by          = $args{'order_by'}
        || 'feature_name,species_common_name,map_set_short_name,map_name,feature_start';
    my $sql_object = $self->sql or return;

    #
    # "-1" is a reserved value meaning "all"
    #
    $species_ids       = [] if grep {/^-1$/} @$species_ids;
    $feature_type_accs = [] if grep {/^-1$/} @$feature_type_accs;

    my %features;
    for my $feature_name ( map { uc $_ } @feature_names ) {

        my $feature_results;
        if ( $search_field eq 'feature_name' ) {
            $feature_results = $sql_object->get_features(
                map_acc           => $map_acc,
                feature_name      => $feature_name,
                feature_type_accs => $feature_type_accs,
                species_ids       => $species_ids,
                aliases_get_rows  => 1,
            );
        }
        else {
            $feature_results = $sql_object->get_features(
                map_acc           => $map_acc,
                feature_acc       => $feature_name,
                feature_type_accs => $feature_type_accs,
                species_ids       => $species_ids,
                aliases_get_rows  => 1,
            );
        }

        foreach my $f (@$feature_results) {
            $features{ $f->{'feature_id'} } = $f;
        }
    }

    my @results = ();
    if ( $order_by =~ /position/ ) {
        @results = map { $_->[1] }
            sort { $a->[0] <=> $b->[0] }
            map { [ $_->{$order_by}, $_ ] } values %features;
    }
    else {
        my @sort_fields = split( /,/, $order_by );
        @results = map { $_->[1] }
            sort { $a->[0] cmp $b->[0] }
            map { [ join( '', @{$_}{@sort_fields} ), $_ ] } values %features;
    }

    #
    # Slice the results up into pages suitable for web viewing.
    #
    my $pager = Data::Pageset->new(
        {   total_entries    => scalar @results,
            entries_per_page => $args{'entries_per_page'},
            current_page     => $args{'current_page'},
            pages_per_set    => $args{'pages_per_set'},
        }
    );

    if (@results) {
        @results = $pager->splice( \@results );

        for my $f (@results) {
            $f->{'aliases'} = $sql_object->get_feature_aliases(
                feature_id => $f->{'feature_id'}, );
        }
    }

    return {
        results => \@results,
        pager   => $pager,
    };
}

# ----------------------------------------------------
sub feature_name_by_id {

=pod

=head2 feature_name_by_id

=head3 For External Use

=over 4

=item * Description

Find a feature's name by either its internal or accession ID.

=item * Usage

    $admin->feature_name_by_id(
        feature_id => $feature_id,
        feature_acc => $feature_acc,
    );

=item * Returns

Array of feature names.

=item * Fields

=over 4

=item - feature_id

=item - feature_acc

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $feature_id  = $args{'feature_id'}  || 0;
    my $feature_acc = $args{'feature_acc'} || 0;
    $self->error('Need either feature id or accession id')
        unless $feature_id || $feature_acc;

    my $sql_object = $self->sql or return;
    my $features = $sql_object->get_features_simple(
        feature_id  => $feature_id,
        feature_acc => $feature_acc,
    );
    return unless (@$features);
    return $features->[0]{'feature_name'};
}

# ----------------------------------------------------
sub feature_types {

=pod

=head2 feature_types

=head3 For External Use

=over 4

=item * Description

Find all the feature types.

=item * Usage

    $admin->feature_types(
        order_by => $order_by,
    );

=item * Returns

Arrayref of hashes with feature_type data.

=item * Fields

=over 4

=item - order_by

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $order_by = $args{'order_by'} || 'feature_type_acc';

    my @feature_type_accs = keys( %{ $self->config_data('feature_type') } );
    my $feature_types;
    foreach my $type_acc ( sort { $a->{$order_by} cmp $b->{$order_by} }
        @feature_type_accs )
    {
        $feature_types->[ ++$#{$feature_types} ]
            = $self->feature_type_data($type_acc)
            or return $self->error("No feature type accession '$type_acc'");
    }
    return $feature_types;
}

# ----------------------------------------------------
sub map_create {

=pod

=head2 map_create

=head3 For External Use

=over 4

=item * Description

map_create

=item * Usage

    $admin->map_create(
        map_name => $map_name,
        map_set_id => $map_set_id,
        map_acc => $map_acc,
        map_start => $map_start,
        map_stop => $map_stop,
        display_order => $display_order,
    );

=item * Returns

Map ID

=item * Fields

=over 4

=item - map_name

Name of the map being created

=item - map_set_id

=item - map_acc

Identifier that is used to access this object.  Can be alpha-numeric.  
If not defined, the object_id will be assigned to it.

=item - map_start

Begining point of the map.

=item - map_stop

End point of the map.

=item - display_order

=back

=back

=cut

    my ( $self, %args ) = @_;
    my @missing    = ();
    my $map_set_id = $args{'map_set_id'}
        or push @missing, 'map_set_id';
    my $map_name = $args{'map_name'};
    my $display_order = $args{'display_order'} || 1;
    push @missing, 'map name' unless defined $map_name && $map_name ne '';
    my $map_start = $args{'map_start'};
    push @missing, 'start position'
        unless defined $map_start && $map_start ne '';
    my $map_stop = $args{'map_stop'};
    push @missing, 'stop position'
        unless defined $map_stop && $map_stop ne '';
    my $map_acc = $args{'map_acc'};

    if (@missing) {
        return $self->error( 'Map create failed.  Missing required fields: ',
            join( ', ', @missing ) );
    }

    unless ( $map_start =~ /^$RE{'num'}{'real'}$/ ) {
        return $self->error("Bad start position ($map_start)");
    }

    unless ( $map_stop =~ /^$RE{'num'}{'real'}$/ ) {
        return $self->error("Bad stop position ($map_stop)");
    }

    my $sql_object = $self->sql or return $self->error;
    my $map_id = $sql_object->insert_map(
        map_acc       => $map_acc,
        map_set_id    => $map_set_id,
        map_name      => $map_name,
        map_start     => $map_start,
        map_stop      => $map_stop,
        display_order => $display_order,
    );

    return $map_id;
}

# ----------------------------------------------------
sub map_delete {

=pod

=head2 map_delete

=head3 For External Use

=over 4

=item * Description

Delete a map.

=item * Usage

    $admin->map_delete(
        map_id => $map_id,
    );

=item * Returns

Nothing

=item * Fields

=over 4

=item - map_id

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $map_id     = $args{'map_id'} or return $self->error('No map id');
    my $sql_object = $self->sql      or return;

    my $maps = $sql_object->get_maps( map_id => $map_id, );
    return $self->error('Invalid map id')
        unless (@$maps);

    my $map_set_id = $maps->[0]{'map_set_id'};

    my $features = $sql_object->get_features_simple( map_id => $map_id, );

    foreach my $feature (@$features) {
        $self->feature_delete( feature_id => $feature->{'feature_id'}, );
    }

    $self->attribute_delete( 'map', $map_id );
    $self->xref_delete( 'map', $map_id );

    $sql_object->delete_map( map_id => $map_id, );

    return $map_set_id;
}

# ----------------------------------------------------
sub map_set_create {

=pod

=head2 map_set_create

=head3 For External Use

=over 4

=item * Description

map_set_create

=item * Usage

    $admin->map_set_create(
        map_set_name => $map_set_name,
        map_set_acc => $map_set_acc,
        map_type_acc => $map_type_acc,
        width => $width,
        is_relational_map => $is_relational_map,
        published_on => $published_on,
        map_set_short_name => $map_set_short_name,
        display_order => $display_order,
        species_id => $species_id,
        color => $color,
        shape => $shape,
    );

=item * Returns

Map Set ID

=item * Fields

=over 4

=item - map_set_name

Name of the map set being created

=item - map_set_acc

Identifier that is used to access this object.  Can be alpha-numeric.  
If not defined, the object_id will be assigned to it.

=item - map_type_acc

The accession id of a map type that is defined in the config file.

=item - width

Pixel width of the map

=item - published_on

=item - map_set_short_name

=item - display_order

=item - species_id

=item - color

Identifier that is used to access this object.  Can be alpha-numeric.  
If not defined, the object_id will be assigned to it.

=item - shape

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $sql_object   = $self->sql;
    my @missing      = ();
    my $map_set_name = $args{'map_set_name'}
        or push @missing, 'map_set_name';
    my $map_set_short_name = $args{'map_set_short_name'}
        or push @missing, 'map_set_short_name';
    my $species_id = $args{'species_id'}
        or push @missing, 'species';
    my $map_type_acc = $args{'map_type_acc'}
        or push @missing, 'map_type_acc';
    my $map_set_acc   = $args{'map_set_acc'}   || '';
    my $display_order = $args{'display_order'} || 1;
    my $shape         = $args{'shape'}         || '';
    my $color         = $args{'color'}         || '';
    my $width         = $args{'width'}         || 0;
    my $published_on  = $args{'published_on'}  || 'today';

    if (@missing) {
        return $self->error(
            'Map set create failed.  Missing required fields: ',
            join( ', ', @missing ) );
    }

    if ($published_on) {
        my $pub_date = parsedate( $published_on, VALIDATE => 1 )
            or return $self->error(
            "Publication date '$published_on' is not valid");
        my $t = localtime($pub_date);
        $published_on = $t->strftime( $self->data_module->sql->date_format );
    }
    my $map_units = $self->map_type_data( $map_type_acc, 'map_units' );

           $color ||= $self->map_type_data( $map_type_acc, 'color' )
        || $self->config_data("map_color")
        || DEFAULT->{'map_color'}
        || 'black';

           $shape ||= $self->map_type_data( $map_type_acc, 'shape' )
        || $self->config_data("map_shape")
        || DEFAULT->{'map_shape'}
        || 'box';

           $width ||= $self->map_type_data( $map_type_acc, 'width' )
        || $self->config_data("map_width")
        || DEFAULT->{'map_width'}
        || '0';

    my $is_relational_map
        = $self->map_type_data( $map_type_acc, 'is_relational_map' ) || 0;

    my $map_set_id = $sql_object->insert_map_set(
        map_set_acc        => $map_set_acc,
        map_set_short_name => $map_set_short_name,
        map_set_name       => $map_set_name,
        species_id         => $species_id,
        published_on       => $published_on,
        map_type_acc       => $map_type_acc,
        display_order      => $display_order,
        shape              => $shape,
        width              => $width,
        color              => $color,
        map_units          => $map_units,
        is_relational_map  => $is_relational_map,
    );

    return $map_set_id;
}

# ----------------------------------------------------
sub map_set_delete {

=pod

=head2 map_set_delete

=head3 For External Use

=over 4

=item * Description

Delete a map set.

=item * Usage

    $admin->map_set_delete(
        map_set_id => $map_set_id,
    );

=item * Returns

Nothing

=item * Fields

=over 4

=item - map_set_id

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $map_set_id = $args{'map_set_id'}
        or return $self->error('No map set id');
    my $sql_object = $self->sql or return;
    my $maps = $sql_object->get_maps( map_set_id => $map_set_id, );

    foreach my $map (@$maps) {
        $self->map_delete( map_id => $map->{'map_id'}, );
    }

    $self->attribute_delete( 'map_set', $map_set_id );
    $self->xref_delete( 'map_set', $map_set_id );

    $sql_object->delete_map_set( map_set_id => $map_set_id, );

    return 1;
}

# ----------------------------------------------------
sub reload_correspondence_matrix {

=pod

=head2 reload_correspondence_matrix

=head3 For External Use

=over 4

=item * Description

Reload the matrix data table with up to date information

=item * Usage

    $admin->reload_correspondence_matrix();

=item * Returns

Nothing

=back

=cut

    my ( $self, %args ) = @_;
    my $sql_object = $self->sql or return;

    my $new_records = $sql_object->reload_correspondence_matrix();

    print("\n$new_records new records inserted.\n");
}

# ----------------------------------------------------
sub set_attributes {

=pod

=head2 set_attributes

=head3 For External Use

=over 4

=item * Description

Set the attributes for a database object.

=item * Usage

    $admin->set_attributes(
        object_id   => $object_id,
        overwrite   => $overwrite,
        object_type => $object_type,
        attributes  => [
            {   name          => $attribute_name,
                value         => $attribute_value,
                display_order => $display_order,
                is_public     => $is_public,
            },
        ],
    );

=item * Returns

1

=item * Fields

=over 4

=item - object_id

The primary key of the object.

=item - overwrite

Set to 1 to delete old data first.

=item - object_type

The name of the object being reference.

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $object_id = $args{'object_id'}
        or return $self->error('No object id');
    my $object_type = $args{'object_type'}
        or return $self->error('No table name');
    my @attributes = @{ $args{'attributes'} || [] } or return;
    my $overwrite = $args{'overwrite'} || 0;
    my $sql_object = $self->sql or return;

    if ($overwrite) {
        $sql_object->delete_attribute(
            object_id   => $object_id,
            object_type => $object_type,
        );
    }

    for my $attr (@attributes) {
        my $attr_id = $attr->{'attribute_id'};
        my $attr_name = $attr->{'name'} || $attr->{'attribute_name'};
        my $attr_value
            = defined( $attr->{'value'} )
            ? $attr->{'value'}
            : $attr->{'attribute_value'};
        my $is_public     = $attr->{'is_public'};
        my $display_order = $attr->{'display_order'};

        next
            unless defined $attr_name
                && $attr_name ne ''
                && defined $attr_value
                && $attr_value ne '';

        unless ($attr_id) {

            # Check for duplicate attribute
            my $attribute = $sql_object->get_attributes(
                object_id       => $object_id,
                object_type     => $object_type,
                attribute_name  => $attr_name,
                attribute_value => $attr_value,
            );
            if ( @{ $attribute || [] } ) {
                $attr_id = $attribute->[0]{'attribute_id'};
            }
        }

        if ($attr_id) {
            $sql_object->update_attribute(
                attribute_id    => $attr_id,
                object_id       => $object_id,
                object_type     => $object_type,
                attribute_name  => $attr_name,
                attribute_value => $attr_value,
                display_order   => $display_order,
                is_public       => $is_public,
            );
        }
        else {
            $is_public = 1 unless defined $is_public;
            $attr_id = $sql_object->insert_attribute(
                object_id       => $object_id,
                object_type     => $object_type,
                attribute_name  => $attr_name,
                attribute_value => $attr_value,
                display_order   => $display_order,
                is_public       => $is_public,
            );
        }
    }

    return 1;
}

# ----------------------------------------------------
sub set_xrefs {

=pod

=head2 set_xrefs

=head3 For External Use

=over 4

=item * Description

Set the attributes for a database object.

=item * Usage

    $admin->set_xrefs(
        object_id => $object_id,
        overwrite => $overwrite,
        object_type => $object_type,
    );

=item * Returns

1

=item * Fields

=over 4

=item - object_id

The primary key of the object.

=item - overwrite

Set to 1 to delete old data first.

=item - object_type

The name of the object being reference.

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $object_id   = $args{'object_id'};
    my $object_type = $args{'object_type'}
        or return $self->error('No object name');
    my @xrefs = @{ $args{'xrefs'} || [] } or return;
    my $overwrite = $args{'overwrite'} || 0;
    my $sql_object = $self->sql or return;

    if ( $overwrite && $object_id ) {
        $sql_object->delete_xref(
            object_id   => $object_id,
            object_type => $object_type,
        );
    }

    for my $xref (@xrefs) {
        my $xref_id   = $xref->{'xref_id'};
        my $xref_name = $xref->{'name'} || $xref->{'xref_name'};
        my $xref_url  = $xref->{'url'} || $xref->{'xref_url'};
        my $is_public
            = defined( $xref->{'is_public'} ) ? $xref->{'is_public'} : 1;

        my $display_order = $xref->{'display_order'};

        next
            unless defined $xref_name
                && $xref_name ne ''
                && defined $xref_url
                && $xref_url ne '';

        unless ($xref_id) {

            # Check for duplicate xref
            my $xref = $sql_object->get_xrefs(
                object_id   => $object_id,
                object_type => $object_type,
                xref_name   => $xref_name,
                xref_url    => $xref_url,
            );
            if ( @{ $xref || [] } ) {
                $xref_id = $xref->[0]{'xref_id'};
            }
        }

        if ($xref_id) {
            $sql_object->update_xref(
                xref_id       => $xref_id,
                object_id     => $object_id,
                object_type   => $object_type,
                xref_name     => $xref_name,
                xref_url      => $xref_url,
                display_order => $display_order,
            );
        }
        else {
            $is_public = 1 unless defined $is_public;
            $xref_id = $sql_object->insert_xref(
                object_id     => $object_id,
                object_type   => $object_type,
                xref_name     => $xref_name,
                xref_url      => $xref_url,
                display_order => $display_order,
            );
        }
    }

    return 1;
}

# ----------------------------------------------------
sub species_create {

=pod

=head2 species_create

=head3 For External Use

=over 4

=item * Description

species_create

=item * Usage

    $admin->species_create(
        species_full_name => $species_full_name,
        species_common_name => $species_common_name,
        display_order => $display_order,
        species_acc => $species_acc,
    );

=item * Returns

Species ID

=item * Fields

=over 4

=item - species_full_name

Full name of the species, such as "Homo Sapiens".

=item - species_common_name

Short name of the species, such as "Human".

=item - display_order

=item - species_acc

Identifier that is used to access this object.  Can be alpha-numeric.  
If not defined, the object_id will be assigned to it.

=back

=back

=cut

    my ( $self, %args ) = @_;
    my @missing;
    my $sql_object          = $self->sql;
    my $species_common_name = $args{'species_common_name'}
        or push @missing, 'common name';
    my $species_full_name = $args{'species_full_name'}
        or push @missing, 'full name';
    if (@missing) {
        return $self->error(
            'Species create failed.  Missing required fields: ',
            join( ', ', @missing ) );
    }

    my $display_order = $args{'display_order'} || 1;
    my $species_acc = $args{'species_acc'};

    my $species_id = $sql_object->insert_species(
        species_acc         => $species_acc,
        species_full_name   => $species_full_name,
        species_common_name => $species_common_name,
        display_order       => $display_order,
    ) or return $sql_object->error;

    return $species_id;
}

# ----------------------------------------------------
sub species_delete {

=pod

=head2 species_delete

=head3 For External Use

=over 4

=item * Description

Delete a species.

=item * Usage

    $admin->species_delete(
        species_id => $species_id,
    );

=item * Returns

Nothing

=item * Fields

=over 4

=item - species_id

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $species_id = $args{'species_id'}
        or return $self->error('No species id');
    my $cascade_delete = $args{'cascade_delete'} || 0;

    my $sql_object = $self->sql or return;

    my $map_sets = $sql_object->get_map_sets( species_id => $species_id, );

    if ( scalar(@$map_sets) > 0 and !$cascade_delete ) {
        return $self->error(
            'Unable to delete ',
            $map_sets->[0]{'species_common_name'},
            ' because ', scalar(@$map_sets), ' map sets are linked to it.'
        );
    }

    foreach my $map_set (@$map_sets) {
        $self->map_set_delete( map_set_id => $map_set->{'map_set_id'}, );
    }

    $self->attribute_delete( 'species', $species_id );
    $self->xref_delete( 'species', $species_id );

    $sql_object->delete_species( species_id => $species_id, );

    return 1;
}

# ----------------------------------------------------
sub xref_create {

=pod

=head2 xref_create

=head3 For External Use

=over 4

=item * Description

xref_create

=item * Usage

    $admin->xref_create(
        object_id => $object_id,
        xref_name => $xref_name,
        xref_url => $xref_url,
        object_type => $object_type,
        display_order => $display_order,
    );

=item * Returns

XRef ID

=item * Fields

=over 4

=item - object_id

The primary key of the object.

=item - xref_name

=item - xref_url

=item - object_type

The name of the table being reference.

=item - display_order

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $sql_object  = $self->sql or return $self->error;
    my @missing     = ();
    my $object_id   = $args{'object_id'} || 0;
    my $object_type = $args{'object_type'}
        or push @missing, 'database object (table name)';
    my $xref_name = $args{'xref_name'} or push @missing, 'xref name';
    my $xref_url  = $args{'xref_url'}  or push @missing, 'xref URL';
    my $display_order = $args{'display_order'};
    my $xref_id;

    if (@missing) {
        return $self->error(
            'Cross-reference create failed.  Missing required fields: ',
            join( ', ', @missing ) );
    }

    #
    # See if one like this exists already.
    #
    my $xrefs = $sql_object->get_xrefs(
        object_type => $object_type,
        object_id   => $object_id,
        xref_name   => $xref_name,
        xref_url    => $xref_url,
    );

    if (@$xrefs) {
        my $xref = $xrefs->[0];
        $xref_id = $xref->{'xref_id'};
        if ( defined $display_order
            && $xref->{'display_order'} != $display_order )
        {
            $sql_object->update_xrefs(
                display_order => $display_order,
                xref_id       => $xref_id,
            );
        }
    }
    else {
        $xref_id = $self->set_xrefs(
            object_id   => $object_id,
            object_type => $object_type,
            xrefs       => [
                {   name          => $xref_name,
                    url           => $xref_url,
                    display_order => $display_order,
                },
            ],
        ) or return $self->error;
    }

    return $xref_id;
}

# ----------------------------------------------------
sub xref_delete {

=pod

=head2 xref_delete

=head3 For External Use

=over 4

=item * Description

Delete a cross reference.

=item * Usage

    $admin->xref_delete(
        $object_type,
        $object_id
    );

=item * Returns

Nothing

=item * Fields

=over 4

=item - object_type

The name of the table being reference.

=item - object_id

The primary key of the object.

=back

=back

=cut

    my $self        = shift;
    my $object_type = shift or return;
    my $object_id   = shift or return;
    my $sql_object  = $self->sql or return;

    $sql_object->delete_xref(
        object_type => $object_type,
        object_id   => $object_id,
    );

    return 1;
}

# ----------------------------------------------------
sub map_to_feature_create {

=pod

=head2 map_to_feature_create

=head3 For External Use

=over 4

=item * Description

Create a map_to_feature link.  Basically this is just a wrapper.

=item * Usage

    $admin->map_to_feature_create(
        feature_id => $feature_id,
        feature_acc => $feature_acc,
        map_id => $map_id,
        map_acc => $map_acc,
    );

=item * Returns

Feature ID

=item * Fields

=over 4

=item - map_id (Required unless map_acc is given)

Identifier of the map to be linked.

=item - map_acc (Required unless map_id is given)

Accession of the map to be linked.

=item - feature_id (Required unless feature_acc is given)

Identifier of the feature to be linked.

=item - feature_acc (Required unless feature_id is given)

Accession of the feature to be linked.

=back

=back

=cut

    my ( $self, %args ) = @_;
    my @missing     = ();
    my $map_id      = $args{'map_id'};
    my $map_acc     = $args{'map_acc'};
    my $feature_id  = $args{'feature_id'};
    my $feature_acc = $args{'feature_acc'};

    push @missing, "map"     unless ( $map_id     or $map_acc );
    push @missing, "feature" unless ( $feature_id or $feature_acc );

    if (@missing) {
        return die 'Feature create failed.  Missing required fields: ',
            join( ', ', @missing );
    }
    my $sql_object = $self->sql or return $self->error;

    return $sql_object->insert_map_to_feature(
        map_id      => $map_id,
        map_acc     => $map_acc,
        feature_id  => $feature_id,
        feature_acc => $feature_acc,
    );
}

# ----------------------------------------------------
sub commit_changes {

=pod

=head2 commit_changes

=head3 For External Use

=over 4

=item * Description

Commit changes from the editor

=item * Usage

    $admin->commit_changes( change_actions => $change_actions, );

=item * Returns

Nothing

=item * Fields

=over 4

=item - change_actions

A list of the changes that are to be made.

=item - object_id

The primary key of the object.

=back

=back

=cut

    my $self           = shift;
    my $change_actions = shift or return;
    my $sql_object     = $self->sql or return;

    my $time_str            = localtime();
    my $temp_to_real_map_id = {};

    my $transaction_id = $sql_object->insert_transaction();
    $sql_object->start_transaction();
    my $commit_text;

    foreach my $action ( @{ $change_actions || [] } ) {
        if ( $action->{'action'} eq 'move_map' ) {
            my $feature_id = $action->{'feature_id'} or next;

            my $map_id
                = $self->_translate_map_id( $action->{'new_parent_map_id'},
                $temp_to_real_map_id );

            my $direction     = $action->{'direction'} || undef;
            my $feature_start = $action->{'new_feature_start'};
            my $feature_stop  = $action->{'new_feature_stop'};

            # Handle commit log
            my $map_data = $sql_object->get_maps( map_id => $map_id );
            die "$map_id is not a valid map ID\n"
                unless ( @{ $map_data || [] } );
            $map_data = $map_data->[0];
            my $commit_type = 'move_map';

            $commit_text .= join( ";",
                "action=$commit_type",
                "feature_id=$feature_id",
                "map_id=$map_id",
                "feature_start=$feature_start",
                "feature_stop=$feature_stop",
                "direction=" . ( defined($direction) ? $direction : '' ) );

            $sql_object->insert_commit_log(
                transaction_id => $transaction_id,
                commit_type    => $commit_type,
                commit_text    => $commit_text,
                commit_object  => nfreeze($action),
                species_id     => $map_data->{'species_id'},
                species_acc    => $map_data->{'species_acc'},
                map_set_id     => $map_data->{'map_set_id'},
                map_set_acc    => $map_data->{'map_set_acc'},
                map_id         => $map_data->{'map_id'},
                map_acc        => $map_data->{'map_acc'},
            );

            # Done with commit log

            $sql_object->update_feature(
                feature_id    => $feature_id,
                map_id        => $map_id,
                feature_start => $feature_start,
                feature_stop  => $feature_stop,
                direction     => $direction,
            );
        }
        elsif ( $action->{'action'} eq 'flip_map' ) {
            my $feature_id = $action->{'feature_id'} or next;
            my $map_id = $self->_translate_map_id( $action->{'map_id'},
                $temp_to_real_map_id );

            # Start commit log
            my $map_data = $sql_object->get_maps( map_id => $map_id );
            die "$map_id is not a valid map ID\n"
                unless ( @{ $map_data || [] } );
            $map_data = $map_data->[0];
            my $commit_type = 'flip_map';

            $commit_text .= join( ";",
                "action=$commit_type", "map_id=$map_id",
                "feature_id=$feature_id", );
            my %commit_log = (
                transaction_id => $transaction_id,
                commit_type    => $commit_type,
                commit_text    => $commit_text,
                commit_object  => nfreeze($action),
                species_id     => $map_data->{'species_id'},
                species_acc    => $map_data->{'species_acc'},
                map_set_id     => $map_data->{'map_set_id'},
                map_set_acc    => $map_data->{'map_set_acc'},
                map_id         => $map_data->{'map_id'},
                map_acc        => $map_data->{'map_acc'},
            );

            if ( $action->{'subsection'} ) {
                my $super_map_id
                    = $self->_translate_map_id( $action->{'super_map_id'},
                    $temp_to_real_map_id );
                my $super_unit_granularity
                    = $action->{'super_unit_granularity'};
                my $subsection_feature_accs
                    = $action->{'subsection_feature_accs'};
                my $reverse_start = $action->{'reverse_start'};
                my $reverse_stop  = $action->{'reverse_stop'};
                $self->reverse_features_on_map(
                    map_id            => $super_map_id,
                    unit_granularity  => $super_unit_granularity,
                    feature_acc_array => $subsection_feature_accs,
                    reverse_start     => $reverse_start,
                    reverse_stop      => $reverse_stop,
                );

                # Add subsection specific data to the commit log
                $commit_log{'commit_text'} = join( ";",
                    $commit_log{'commit_text'},
                    "subsection=" . $action->{'subsection'},
                    "super_map_id=$super_map_id",
                    "reverse_start=$reverse_start",
                    "reverse_stop=$reverse_stop",
                );
            }
            else {
                my $feature_data = $sql_object->get_features_simple(
                    feature_id => $feature_id );
                die "$feature_id is not a valid feature ID\n"
                    unless ( @{ $feature_data || [] } );
                $feature_data = $feature_data->[0];

                my $new_direction = $feature_data->{'direction'} < 0 ? 1 : -1;

                $sql_object->update_feature(
                    feature_id => $feature_id,
                    direction  => $new_direction,
                );
            }
            $sql_object->insert_commit_log( %commit_log, );

        }
        elsif ( $action->{'action'} eq 'split_map' ) {

            # Get the info for the old map
            my $ori_map_id
                = $self->_translate_map_id( $action->{'ori_map_id'},
                $temp_to_real_map_id );
            my $ori_map_data
                = $sql_object->get_maps( map_id => $ori_map_id, );
            next unless $ori_map_data;
            $ori_map_data = $ori_map_data->[0];

            # Create new maps
            my $first_map_id = $sql_object->insert_map(
                map_set_id    => $ori_map_data->{'map_set_id'},
                map_name      => $action->{'first_map_name'},
                display_order => $ori_map_data->{'display_order'},
                map_start     => $action->{'first_map_start'},
                map_stop      => $action->{'first_map_stop'},
            );

            my $second_map_id = $sql_object->insert_map(
                map_set_id    => $ori_map_data->{'map_set_id'},
                map_name      => $action->{'second_map_name'},
                display_order => $ori_map_data->{'display_order'},
                map_start     => $action->{'second_map_start'},
                map_stop      => $action->{'second_map_stop'},
            );

            # Handle commit log
            my $map_data = $sql_object->get_maps( map_id => $ori_map_id );
            die "$ori_map_id is not a valid map ID\n"
                unless ( @{ $map_data || [] } );
            $map_data = $map_data->[0];
            my $commit_type = 'split_map';

            $commit_text .= join( ";",
                "action=$commit_type",
                "ori_map_id=$ori_map_id",
                "first_map_id=$first_map_id",
                "first_map_name=" . $action->{'first_map_name'},
                "first_map_start=" . $action->{'first_map_start'},
                "first_map_stop=" . $action->{'first_map_stop'},
                "second_map_id=" . $second_map_id,
                "second_map_name=" . $action->{'second_map_name'},
                "second_map_start=" . $action->{'second_map_start'},
                "second_map_stop=" . $action->{'second_map_stop'},
            );

            $sql_object->insert_commit_log(
                transaction_id => $transaction_id,
                commit_type    => $commit_type,
                commit_text    => $commit_text,
                commit_object  => nfreeze($action),
                species_id     => $map_data->{'species_id'},
                species_acc    => $map_data->{'species_acc'},
                map_set_id     => $map_data->{'map_set_id'},
                map_set_acc    => $map_data->{'map_set_acc'},
                map_id         => $map_data->{'map_id'},
                map_acc        => $map_data->{'map_acc'},
            );

            # Done with commit log

            # Add the new IDs to the hash for later lookup
            $temp_to_real_map_id->{ $action->{'first_map_id'} }
                = $first_map_id;
            $temp_to_real_map_id->{ $action->{'second_map_id'} }
                = $second_map_id;

            # Move features
            foreach my $feature_acc (
                @{ $action->{'first_map_feature_accs'} || [] } )
            {
                my $feature_data = $sql_object->get_features_simple(
                    feature_acc => $feature_acc, );
                next unless $feature_data;
                $feature_data = $feature_data->[0];
                my $feature_id = $feature_data->{'feature_id'};
                $sql_object->update_feature(
                    feature_id => $feature_id,
                    map_id     => $first_map_id,
                );
            }
            foreach my $feature_acc (
                @{ $action->{'second_map_feature_accs'} || [] } )
            {
                my $feature_data = $sql_object->get_features_simple(
                    feature_acc => $feature_acc, );
                next unless $feature_data;
                $feature_data = $feature_data->[0];
                my $feature_id = $feature_data->{'feature_id'};
                $sql_object->update_feature(
                    feature_id => $feature_id,
                    map_id     => $second_map_id,
                );
            }

            # Maybe Move any features that were missed.

            # Validate the start and stop of each new map
            $self->validate_update_map_start_stop($first_map_id);
            $self->validate_update_map_start_stop($second_map_id);

            # If the map was a sub map
            if ( defined $action->{'first_feature_start'} ) {
                my $ori_map_to_features
                    = $sql_object->get_map_to_features( map_id => $ori_map_id,
                    );
                if (    $ori_map_to_features
                    and @$ori_map_to_features
                    and my $ori_feature_id
                    = $ori_map_to_features->[0]{'feature_id'} )
                {

                    # Create and Copy feature info to new features
                    my $first_feature_id = $self->feature_copy(
                        feature_name   => $action->{'first_map_name'},
                        feature_start  => $action->{'first_feature_start'},
                        feature_stop   => $action->{'first_feature_stop'},
                        ori_feature_id => $ori_feature_id,
                    );
                    $sql_object->insert_map_to_feature(
                        feature_id => $first_feature_id,
                        map_id     => $first_map_id,
                    );

                    my $second_feature_id = $self->feature_copy(
                        feature_name   => $action->{'second_map_name'},
                        feature_start  => $action->{'second_feature_start'},
                        feature_stop   => $action->{'second_feature_stop'},
                        ori_feature_id => $ori_feature_id,
                    );
                    $sql_object->insert_map_to_feature(
                        feature_id => $second_feature_id,
                        map_id     => $second_map_id,
                    );

                    # Delete original sub-map feature
                    $self->feature_delete( feature_id => $ori_feature_id, );
                }
            }

            # Copy Map Attributes/DBXrefs
            $self->copy_attributes(
                ori_object_id => $ori_map_id,
                new_object_id => $first_map_id,
                object_type   => 'map',
            );
            $self->copy_xrefs(
                ori_object_id => $ori_map_id,
                new_object_id => $first_map_id,
                object_type   => 'map',
            );
            $self->copy_attributes(
                ori_object_id => $ori_map_id,
                new_object_id => $second_map_id,
                object_type   => 'map',
            );
            $self->copy_xrefs(
                ori_object_id => $ori_map_id,
                new_object_id => $second_map_id,
                object_type   => 'map',
            );

            # Delete original map
            $self->map_delete( map_id => $ori_map_id, );

        }
        elsif ( $action->{'action'} eq 'merge_maps' ) {

            # Get map data for one of the maps
            my $first_map_id
                = $self->_translate_map_id( $action->{'first_map_id'},
                $temp_to_real_map_id );
            my $first_map_data
                = $sql_object->get_maps( map_id => $first_map_id, );
            next unless $first_map_data;
            $first_map_data = $first_map_data->[0];

            # Translate the second map id too.
            my $second_map_id
                = $self->_translate_map_id( $action->{'second_map_id'},
                $temp_to_real_map_id );

            # Create new map
            # If adding a map_acc be sure to add it to the insert_commit_log
            # below
            my $merged_map_id = $sql_object->insert_map(
                map_set_id    => $first_map_data->{'map_set_id'},
                map_name      => $action->{'merged_map_name'},
                display_order => $first_map_data->{'display_order'},
                map_start     => $action->{'merged_map_start'},
                map_stop      => $action->{'merged_map_stop'},
            );

            # Handle commit log
            my $map_data = $sql_object->get_maps( map_id => $first_map_id );
            die "$first_map_id is not a valid map ID\n"
                unless ( @{ $map_data || [] } );
            $map_data = $map_data->[0];
            my $commit_type = 'merge_maps';

            $commit_text .= join( ";",
                "action=$commit_type",
                "first_map_id=$first_map_id",
                "second_map_id=$second_map_id",
                "second_map_offset=" . $action->{'second_map_offset'},
                "merged_map_id=$merged_map_id",
                "merged_map_name=" . $action->{'merged_map_name'},
                "merged_map_start=" . $action->{'merged_map_start'},
                "merged_map_stop=" . $action->{'merged_map_stop'},
                "reverse_second_map=" . $action->{'reverse_second_map'},
            );

            $sql_object->insert_commit_log(
                transaction_id => $transaction_id,
                commit_type    => $commit_type,
                commit_text    => $commit_text,
                commit_object  => nfreeze($action),
                species_id     => $map_data->{'species_id'},
                species_acc    => $map_data->{'species_acc'},
                map_set_id     => $map_data->{'map_set_id'},
                map_set_acc    => $map_data->{'map_set_acc'},
                map_id         => $merged_map_id,
                map_acc        => $merged_map_id,
            );

            # Done with commit log

            $temp_to_real_map_id->{ $action->{'merged_map_id'} }
                = $merged_map_id;

            # Move features
            my $first_feature_data
                = $sql_object->get_features_simple( map_id => $first_map_id,
                );
            foreach my $feature ( @{ $first_feature_data || [] } ) {
                $sql_object->update_feature(
                    feature_id => $feature->{'feature_id'},
                    map_id     => $merged_map_id,
                );
            }

            # If second map was reversed, reverse it back now.
            my ( $second_map_data, )
                = @{ $sql_object->get_maps( map_id => $second_map_id )
                    || [] };
            my $unit_granularity = $self->unit_granularity(
                $second_map_data->{'map_type_acc'} );

            if ( $action->{'reverse_second_map'} ) {
                $self->reverse_features_on_map(
                    map_id            => $second_map_id,
                    unit_granularity  => $unit_granularity,
                    feature_acc_array => $action->{'second_map_feature_accs'},
                    reverse_start     => $second_map_data->{'map_start'},
                    reverse_stop      => $second_map_data->{'map_stop'},
                );
            }

            my $second_map_offset = $action->{'second_map_offset'} || 0;
            my $second_feature_data
                = $sql_object->get_features_simple( map_id => $second_map_id,
                );
            foreach my $feature ( @{ $second_feature_data || [] } ) {
                $sql_object->update_feature(
                    feature_id    => $feature->{'feature_id'},
                    map_id        => $merged_map_id,
                    feature_start => $feature->{'feature_start'}
                        + $second_map_offset,
                    feature_stop => $feature->{'feature_stop'}
                        + $second_map_offset,
                );
            }

            # Validate the start and stop of the new map
            $self->validate_update_map_start_stop($merged_map_id);

            # If the maps were a sub map
            if ( defined $action->{'merged_feature_start'} ) {
                my $first_map_to_features = $sql_object->get_map_to_features(
                    map_id => $first_map_id, );
                my $second_map_to_features = $sql_object->get_map_to_features(
                    map_id => $second_map_id, );
                if (    $first_map_to_features
                    and @$first_map_to_features
                    and $second_map_to_features
                    and @$second_map_to_features
                    and my $first_feature_id
                    = $first_map_to_features->[0]{'feature_id'}
                    and my $second_feature_id
                    = $second_map_to_features->[0]{'feature_id'} )
                {

                    # Create/Copy feature info to new feature
                    my $merged_feature_id = $self->feature_copy(
                        feature_name   => $action->{'merged_map_name'},
                        feature_start  => $action->{'merged_feature_start'},
                        feature_stop   => $action->{'merged_feature_stop'},
                        ori_feature_id => $first_feature_id,
                    );
                    $self->feature_copy(
                        new_feature_id => $merged_feature_id,
                        ori_feature_id => $second_feature_id,
                    );

                    $sql_object->insert_map_to_feature(
                        feature_id => $merged_feature_id,
                        map_id     => $merged_map_id,
                    );

                    # Delete original sub-map features
                    $self->feature_delete( feature_id => $first_feature_id, );
                    $self->feature_delete( feature_id => $second_feature_id,
                    );

                }
            }

            # Copy Map Attributes/DBXrefs
            $self->copy_attributes(
                ori_object_id => $first_map_id,
                new_object_id => $merged_map_id,
                object_type   => 'map',
            );
            $self->copy_xrefs(
                ori_object_id => $first_map_id,
                new_object_id => $merged_map_id,
                object_type   => 'map',
            );
            $self->copy_attributes(
                ori_object_id => $second_map_id,
                new_object_id => $merged_map_id,
                object_type   => 'map',
            );
            $self->copy_xrefs(
                ori_object_id => $second_map_id,
                new_object_id => $merged_map_id,
                object_type   => 'map',
            );

            # Delete original maps
            $self->map_delete( map_id => $first_map_id, );
            $self->map_delete( map_id => $second_map_id, );

        }
        elsif ( $action->{'action'} eq 'move_map_subsection' ) {

            my $subsection_feature_start
                = $action->{'subsection_feature_start'};
            my $subsection_feature_stop
                = $action->{'subsection_feature_stop'};
            my $delete_starting_map  = $action->{'delete_starting_map'};
            my $insertion_point      = $action->{'insertion_point'};
            my $starting_back_offset = $action->{'starting_back_offset'};
            my $destination_back_offset
                = $action->{'destination_back_offset'};
            my $subsection_offset = $action->{'subsection_offset'};

            # STARTING MAP
            # Get map data for the starting map
            my $starting_map_id
                = $self->_translate_map_id( $action->{'starting_map_id'},
                $temp_to_real_map_id );
            my $starting_map_data
                = $sql_object->get_maps( map_id => $starting_map_id, );
            next unless $starting_map_data;
            $starting_map_data = $starting_map_data->[0];

            # Move features
            my $starting_feature_data = $sql_object->get_features_simple(
                map_id => $starting_map_id, );
            my @subsection_features;
            my @subsection_feature_accs;
            foreach my $feature ( @{ $starting_feature_data || [] } ) {
                if ( $feature->{'feature_stop'} < $subsection_feature_start )
                {
                    next;
                }
                elsif (
                    $feature->{'feature_start'} > $subsection_feature_stop )
                {
                    $sql_object->update_feature(
                        feature_id    => $feature->{'feature_id'},
                        feature_start => $feature->{'feature_start'}
                            + $starting_back_offset,
                        feature_stop => $feature->{'feature_stop'}
                            + $starting_back_offset,
                    );
                }
                else {
                    push @subsection_features,     $feature;
                    push @subsection_feature_accs, $feature->{'feature_acc'};
                }
            }

           # If subsection is to be reversed, reverse the features on it now.
           # These are already stored in subsection_features, so we don't have
           # to worry about the features that were moved in the section above
           # getting in the way
            if ( $action->{'reverse_subsection'} ) {
                my $unit_granularity = $self->unit_granularity(
                    $starting_map_data->{'map_type_acc'} );
                $self->reverse_features_on_map(
                    map_id            => $starting_map_id,
                    unit_granularity  => $unit_granularity,
                    feature_acc_array => \@subsection_feature_accs,
                    reverse_start     => $subsection_feature_start,
                    reverse_stop      => $subsection_feature_stop,
                );
            }

            # DESTINATION MAP
            # Get map data for the destination map
            my $destination_map_id
                = $self->_translate_map_id( $action->{'destination_map_id'},
                $temp_to_real_map_id );
            my $destination_map_data
                = $sql_object->get_maps( map_id => $destination_map_id, );
            next unless $destination_map_data;
            $destination_map_data = $destination_map_data->[0];

            # Move features
            my $destination_feature_data = $sql_object->get_features_simple(
                map_id => $destination_map_id, );
            foreach my $feature ( @{ $destination_feature_data || [] } ) {
                if ( $feature->{'feature_stop'} < $insertion_point ) {
                    next;
                }
                elsif ( $feature->{'feature_start'} >= $insertion_point ) {
                    $sql_object->update_feature(
                        feature_id    => $feature->{'feature_id'},
                        feature_start => $feature->{'feature_start'}
                            + $destination_back_offset,
                        feature_stop => $feature->{'feature_stop'}
                            + $destination_back_offset,
                    );
                }
            }

            # Handle commit log
            my $subsection_map_id = $action->{'subsection_map_id'};
            my $map_data
                = $sql_object->get_maps( map_id => $subsection_map_id );
            die "$subsection_map_id is not a valid map ID\n"
                unless ( @{ $map_data || [] } );
            $map_data = $map_data->[0];
            my $commit_type = 'move_map_subsection';

            $commit_text .= join( ";",
                "action=$commit_type",
                "subsection_map_id=$subsection_map_id",
                "destination_map_id=$destination_map_id",
                "insertion_point=$insertion_point",
            );

            $sql_object->insert_commit_log(
                transaction_id => $transaction_id,
                commit_type    => $commit_type,
                commit_text    => $commit_text,
                commit_object  => nfreeze($action),
                species_id     => $map_data->{'species_id'},
                species_acc    => $map_data->{'species_acc'},
                map_set_id     => $map_data->{'map_set_id'},
                map_set_acc    => $map_data->{'map_set_acc'},
                map_id         => $map_data->{'map_id'},
                map_acc        => $map_data->{'map_acc'},
            );

            # Done with commit log

            # Now Move the subsection features
            foreach my $feature (@subsection_features) {
                $sql_object->update_feature(
                    feature_id    => $feature->{'feature_id'},
                    map_id        => $destination_map_id,
                    feature_start => $feature->{'feature_start'}
                        + $subsection_offset,
                    feature_stop => $feature->{'feature_stop'}
                        + $subsection_offset,
                );
            }

            # Delete or Shrink Starting map
            if ($delete_starting_map) {
                $sql_object->delete_map( map_id => $starting_map_id, );
            }
            else {

                # Shrink Starting Map
                my $new_map_stop = $starting_map_data->{'map_stop'}
                    + $starting_back_offset;
                $sql_object->update_map(
                    map_id   => $starting_map_id,
                    map_stop => $new_map_stop,
                );

                # Validate the start and stop of the new map
                $self->validate_update_map_start_stop($starting_map_id);
            }

            # Enlarge the Destination Map
            $sql_object->update_map(
                map_id   => $destination_map_id,
                map_stop => $destination_map_data->{'map_stop'}
                    + $destination_back_offset,
            );

            # Validate the start and stop of the new map
            $self->validate_update_map_start_stop($destination_map_id);

            $temp_to_real_map_id->{ $action->{'new_starting_map_id'} }
                = $starting_map_id
                unless ($delete_starting_map);
            $temp_to_real_map_id->{ $action->{'new_destination_map_id'} }
                = $destination_map_id;
        }
    }
    $sql_object->commit_transaction();

    return $temp_to_real_map_id;
}

# ----------------------------------------------------
sub reverse_features_on_map {

=pod

=head2 reverse_feature_on_map

Given a list of feature_accs, move them in memory 

=cut

    my ( $self, %args ) = @_;
    my $map_id = $args{'map_id'}
        or die "reverse_features_on_map called without a map_id\n";
    my $unit_granularity = $args{'unit_granularity'}
        or die "reverse_features_on_map called without a unit_granularity\n";
    my $feature_acc_array = $args{'feature_acc_array'};
    my $reverse_start     = $args{'reverse_start'};
    my $reverse_stop      = $args{'reverse_stop'};

    #Check if passed an empty feature acc array
    if ( defined $feature_acc_array and not(@$feature_acc_array) ) {
        return 1;
    }

    my $sql_object = $self->sql or return;

    my %feature_data;

    # If not given a feature_acc_array, reverse all the features on a map.
    # May as well build a feature_data hash if we've got the data already
    if ( not defined $feature_acc_array ) {
        my $feature_results
            = $sql_object->get_features_simple( map_id => $map_id, );
        foreach my $feature ( @{ $feature_results || [] } ) {
            push @$feature_acc_array, $feature->{'feature_acc'};
            $feature_data{ $feature->{'feature_acc'} } = $feature;
        }
    }

    # set start and stop to the map start and stop unless defined
    if ( ( not defined $reverse_start ) or ( not defined $reverse_stop ) ) {
        my $map_data = $sql_object->get_maps_simple( map_id => $map_id );
        if ( not defined $reverse_start ) {
            $reverse_start = $map_data->{'map_start'};
        }
        if ( not defined $reverse_stop ) {
            $reverse_stop = $map_data->{'map_stop'};
        }

    }

    my $modifier_to_be_subtracted_from = $reverse_start + $reverse_stop;
    foreach my $feature_acc (@$feature_acc_array) {
        my $this_feature_data;
        unless ( $this_feature_data = $feature_data{$feature_acc} ) {
            my $feature_results = $sql_object->get_features_simple(
                feature_acc => $feature_acc, );
            next unless ( @{ $feature_results || [] } );
            $this_feature_data = $feature_results->[0];
        }

        # Start and stop have to swap places after being reversed
        my $new_feature_start = $modifier_to_be_subtracted_from
            - $this_feature_data->{'feature_stop'};
        my $new_feature_stop = $modifier_to_be_subtracted_from
            - $this_feature_data->{'feature_start'};

        my $new_direction
            = ( $this_feature_data->{'feature_direction'} || 1 ) * -1;

        $sql_object->update_feature(
            feature_id    => $this_feature_data->{'feature_id'},
            feature_start => $new_feature_start,
            feature_stop  => $new_feature_stop,
            direction     => $new_direction,
        );
    }

    return 1;
}

sub _translate_map_id {

    my $self                = shift;
    my $map_id              = shift;
    my $temp_to_real_map_id = shift;

    # Translate map id if a temp was used.
    if ( $map_id and $map_id < 0 ) {
        $map_id = $temp_to_real_map_id->{$map_id};
    }

    return $map_id;
}

# ----------------------------------------------------
sub validate_update_map_start_stop {

=pod

=head2 validate_update_map_start_stop

=head3 For External Use

=over 4

=item * Description

Given a map_id, make sure that the map boundaries are that of the features on
it.  If not, update the map to extend the start and stop.

=item * Usage

    $admin->validate_update_map_start_stop( $map_id );

=item * Returns

Nothing

=item * Fields

=over 4

=item - map_id

The primary key of the map.

=back

=back

=cut

    my $self       = shift;
    my $map_id     = shift or return;
    my $sql_object = $self->sql or return;

    my $map_array = $sql_object->get_maps_simple( map_id => $map_id, );
    my ( $map_start,     $map_stop );
    my ( $ori_map_start, $ori_map_stop );
    if (@$map_array) {
        $ori_map_start = $map_start = $map_array->[0]{'map_start'};
        $ori_map_stop  = $map_stop  = $map_array->[0]{'map_stop'};
    }

    my ( $min_start, $max_start, $max_stop )
        = $sql_object->get_feature_bounds_on_map( map_id => $map_id, );

    #
    # Verify that the map start and stop coordinates at least
    # take into account the extremes of the feature coordinates.
    #
    $min_start = 0 unless defined $min_start;
    $max_start = 0 unless defined $max_start;
    $max_stop  = 0 unless defined $max_stop;
    $map_start = 0 unless defined $map_start;
    $map_stop  = 0 unless defined $map_stop;

    $max_stop  = $max_start if $max_start > $max_stop;
    $map_start = $min_start if $min_start < $map_start;
    $map_stop  = $max_stop  if $max_stop > $map_stop;

    if (   $ori_map_start != $map_start
        or $ori_map_stop != $map_stop )
    {
        $map_id = $sql_object->update_map(
            map_id    => $map_id,
            map_start => $map_start,
            map_stop  => $map_stop,
        );
    }

    return 1;
}

1;

# ----------------------------------------------------
# I should have been a pair of ragged claws,
# Scuttling across the floors of silent seas.
# T. S. Eliot
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

