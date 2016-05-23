package Bio::GMOD::CMap::Data::Generic;

# vim: set ft=perl:

# $Id: Generic.pm,v 1.184 2008/07/01 18:13:19 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Data::Generic - generic SQL module

=head1 SYNOPSIS

  package Bio::GMOD::CMap::Data::FooDB;

  use Bio::GMOD::CMap::Data::Generic;
  use base 'Bio::GMOD::CMap::Data::Generic';

  sub sql_method_that_doesnt_work {
      return $sql_tailored_to_my_db;
  }

  1; 

=head1 DESCRIPTION

This module will hold what is meant to be database-independent, ANSI
SQL.  Whenever this doesn't work for a specific RDBMS, then you can
drop into the derived class and override a method.

=head1 Note

The cmap_object in the validation hashes is there for legacy code.

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.184 $)[-1];

use Data::Dumper;    # really just for debugging
use Time::ParseDate;
use Regexp::Common;
use Time::Piece;
use Params::Validate qw(:all);
use Bio::GMOD::CMap::Utils;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap;
use base 'Bio::GMOD::CMap';

use constant STR => 'string';
use constant NUM => 'number';

# ----------------------------------------------------

=pod

=head1 Maintenance Methods

=cut 

sub init {

=pod

=head2 init()

=over 4

=item * Description

Initialize values that will be needed.

=item * Adaptor Writing Info

This is a handy place to put lookup hashes for object type to table names.

=back

=cut

    my ( $self, $args ) = @_;
    $self->config( $args->{'config'} );
    $self->data_source( $args->{'data_source'} ) or return;

    $self->{'NAME_FIELDS'} = {
        cmap_attribute               => 'attribute_name',
        cmap_correspondence_evidence => 'correspondence_evidence_id',
        cmap_feature                 => 'feature_name',
        cmap_feature_alias           => 'alias',
        cmap_feature_correspondence  => 'feature_correspondence_id',
        cmap_map                     => 'map_name',
        cmap_map_set                 => 'map_set_short_name',
        cmap_saved_link              => 'saved_link_id',
        cmap_species                 => 'species_common_name',
        cmap_xref                    => 'xref_name',
        cmap_commit_log              => 'commit_log_id',
        cmap_transaction             => 'transaction_id',
    };
    $self->{'ID_FIELDS'} = {
        cmap_attribute               => 'attribute_id',
        cmap_correspondence_evidence => 'correspondence_evidence_id',
        cmap_feature                 => 'feature_id',
        cmap_feature_alias           => 'feature_alias_id',
        cmap_feature_correspondence  => 'feature_correspondence_id',
        cmap_map                     => 'map_id',
        cmap_map_set                 => 'map_set_id',
        cmap_saved_link              => 'saved_link_id',
        cmap_species                 => 'species_id',
        cmap_xref                    => 'xref_id',
        cmap_commit_log              => 'commit_log_id',
        cmap_transaction             => 'transaction_id',
    };
    $self->{'ACC_FIELDS'} = {
        cmap_attribute               => '',
        cmap_correspondence_evidence => 'correspondence_evidence_acc',
        cmap_feature                 => 'feature_acc',
        cmap_feature_alias           => '',
        cmap_feature_correspondence  => 'feature_correspondence_acc',
        cmap_map                     => 'map_acc',
        cmap_map_set                 => 'map_set_acc',
        cmap_saved_link              => '',
        cmap_species                 => 'species_acc',
        cmap_xref                    => '',
        cmap_commit_log              => '',
        cmap_transaction             => '',
    };
    $self->{'TABLE_NAMES'} = {
        correspondence_evidence => 'cmap_correspondence_evidence',
        feature                 => 'cmap_feature',
        feature_alias           => 'cmap_feature_alias',
        feature_correspondence  => 'cmap_feature_correspondence',
        map                     => 'cmap_map',
        map_set                 => 'cmap_map_set',
        saved_link              => 'cmap_saved_link',
        species                 => 'cmap_species',
        xref                    => 'cmap_xref',
        attribute               => 'cmap_attribute',
        commit_log              => 'cmap_commit_log',
        transaction             => 'cmap_transaction',
    };
    $self->{'OBJECT_TYPES'} = {
        cmap_correspondence_evidence => 'correspondence_evidence',
        cmap_feature                 => 'feature',
        cmap_feature_alias           => 'feature_alias',
        cmap_feature_correspondence  => 'feature_correspondence',
        cmap_map                     => 'map',
        cmap_map_set                 => 'map_set',
        cmap_saved_link              => 'saved_link',
        cmap_species                 => 'species',
        cmap_xref                    => 'xref',
        cmap_attribute               => 'attribute',
        cmap_commit_log              => 'commit_log',
        cmap_transaction             => 'transaction',
    };

    $self->{'real_number_regex'} = $RE{'num'}{'real'};

    return $self;
}

# ----------------------------------------------------
sub date_format {

=pod

=head2 date_format()

The strftime string for date format.  This is specific to RDBMS.

=cut

    my $self = shift;
    return '%Y-%m-%d';
}

=pod

=head1 Object Access Methods

=cut 

#-----------------------------------------------
sub acc_id_to_internal_id {

=pod

=head2 acc_id_to_internal_id()

=over 4

=item * Description

Return the internal id that corresponds to the accession id

=item * Adaptor Writing Info

If you db doesn't have accessions, this function can just accept an id and
return the same id.

Fully implementing this will require conversion from object type to a table.

=item * Required Input

=over 4

=item - Accession ID (acc_id)

=item - Object type such as feature or map_set (object_type)

=back

=item * Output

ID Scalar

=item * Cache Level (Not Used): 4

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        object_type   => 1,
        acc_id        => 1,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $object_type = $args{'object_type'}
        or return $self->error('No object name');
    die "Object type: $object_type not valid.  \n<br>"
        . "Method giving error: acc_id_to_internal_id<br>"
        . "Calling information:<pre>"
        . Dumper( caller() )
        . "</pre>\n"
        unless ( $self->{'TABLE_NAMES'}->{$object_type} );
    my $acc_id = $args{'acc_id'} or return $self->error('No accession id');
    my $table_name = $self->{'TABLE_NAMES'}->{$object_type} if $object_type;
    my $id_field   = $self->{'ID_FIELDS'}->{$table_name};
    my $acc_field  = $self->{'ACC_FIELDS'}->{$table_name};

    my $db = $self->db;
    my $return_object;

    my $sql_str = qq[
            select $id_field 
            from   $table_name
            where  $acc_field=?
      ];
    $return_object = $db->selectrow_array( $sql_str, {}, ($acc_id) );

    return $return_object;
}

#-----------------------------------------------
sub internal_id_to_acc_id {

=pod

=head2 internal_id_to_acc_id()

=over 4

=item * Description

Return the accession id that corresponds to the internal id

=item * Adaptor Writing Info

If you db doesn't have accessions, this function can just accept an id and
return the same id.

Fully implementing this will require conversion from object type to a table.

=item * Required Input

=over 4

=item - ID (id)

=item - Object type such as feature or map_set (object_type)

=back

=item * Output

Accession ID Scalar

=item * Cache Level (If Used): 4

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        object_type   => 1,
        id            => 1,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $object_type = $args{'object_type'}
        or return $self->error('No object name');
    die "Object type: $object_type not valid.  \n<br>"
        . "Method giving error: internal_id_to_acc_id<br>"
        . "Calling information:<pre>"
        . Dumper( caller() )
        . "</pre>\n"
        unless ( $self->{'TABLE_NAMES'}->{$object_type} );
    my $id = $args{'id'} or return $self->error('No id');
    my $table_name = $self->{'TABLE_NAMES'}->{$object_type} if $object_type;
    my $id_field   = $self->{'ID_FIELDS'}->{$table_name};
    my $acc_field  = $self->{'ACC_FIELDS'}->{$table_name};

    my $db = $self->db;
    my $return_object;

    my $sql_str = qq[
            select $acc_field as ] . $object_type . qq[_acc 
            from   $table_name
            where  $id_field=?
      ];
    $return_object = $db->selectrow_array( $sql_str, {}, ($id) )
        or return $self->error(
        qq[Unable to find accession id for id "$id" in table "$table_name"]);

    return $return_object;
}

#-----------------------------------------------
sub get_object_name {

=pod

=head2 get_object_name()

=over 4

=item * Description

Retrieves the name attached to a database object given the object type and the
object id.

=item * Adaptor Writing Info

This will require conversion from object type to a table.

=item * Required Input

=over 4

=item - Object type such as feature or map_set (object_type)

=item - Object ID (object_id) 

=back

=item * Optional Input

=over 4

=item - Order by clause (order_by)

=back

=item * Output

Object Name

=item * Cache Level (Not Used): 4

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        object_type   => 1,
        object_id     => 1,
        order_by      => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $object_type = $args{'object_type'}
        or return $self->error('No object type');
    die "Object type: $object_type not valid.  \n<br>"
        . "Method giving error: get_object_name<br>"
        . "Calling information:<pre>"
        . Dumper( caller() )
        . "</pre>\n"
        unless ( $self->{'TABLE_NAMES'}->{$object_type} );
    my $object_id = $args{'object_id'} or return $self->error('No object id');
    my $order_by = $args{'order_by'};
    die "Order by clause ($order_by) has SQL code in it\n"
        if ( has_sql_command($order_by) );
    my $object_id_field = $object_type . "_id";

    my $db = $self->db;
    my $return_object;
    my @identifiers = ();

    my $table_name = $self->{'TABLE_NAMES'}->{$object_type} if $object_type;
    my $object_name_field = $self->{'NAME_FIELDS'}->{$table_name};

    my $sql_str = qq[
        select $object_name_field
        from   $table_name
        where  $object_id_field = ?
    ];
    if ( $order_by eq 'display_order' ) {
        $sql_str .= " order by display_order, $object_name_field ";
    }
    elsif ($order_by) {
        $sql_str .= " order by $order_by ";
    }

    $return_object = $db->selectrow_array( $sql_str, {}, $object_id );

    return $return_object;
}

=pod

=head1 Table Information Methods

=cut 

# ----------------------------------------------------
sub pk_name {

=pod

=head2 pk_name()

=over 4

=item * Description

Return the name of the primary key field for an object type.

Example:  $primary_key_field = $sql_object->pk_name('feature');

=item * Adaptor Writing Info

In another db schema, this might be a little more complex than the generic
method.

=item * Input

=over 4

=item - object type (shifted in);

=back

=item * Output

Primary key field

=back

=cut

    my $self        = shift;
    my $object_type = shift;
    die "Object type: $object_type not valid.  \n<br>"
        . "Method giving error: pk_name<br>"
        . "Calling information:<pre>"
        . Dumper( caller() )
        . "</pre>\n"
        unless ( $self->{'TABLE_NAMES'}->{$object_type} );
    $object_type .= '_id';
    return $object_type;
}

#-----------------------------------------------
sub get_table_info {

=pod

=head2 get_table_info()

=over 4

=item * Description

Give a description of the database for export.

=item * Adaptor Writing Info

Only implement this if you want to export data as sql statements.

=item * Output

Array of Hashes:

  Keys:
    name   - table name
    fields - hash of fields in the table

=back

=cut

    my $self   = shift;
    my @tables = (
        {   name   => 'cmap_attribute',
            fields => {
                attribute_id    => NUM,
                table_name      => STR,
                object_id       => NUM,
                display_order   => NUM,
                is_public       => NUM,
                attribute_name  => STR,
                attribute_value => STR,
            }
        },
        {   name   => 'cmap_correspondence_evidence',
            fields => {
                correspondence_evidence_id  => NUM,
                correspondence_evidence_acc => STR,
                feature_correspondence_id   => NUM,
                evidence_type_acc           => STR,
                score                       => NUM,
                rank                        => NUM,
            }
        },
        {   name   => 'cmap_correspondence_lookup',
            fields => {
                feature_id1               => NUM,
                feature_id2               => NUM,
                feature_correspondence_id => NUM,
                feature_start1            => NUM,
                feature_start2            => NUM,
                feature_stop1             => NUM,
                feature_stop2             => NUM,
                map_id1                   => NUM,
                map_id2                   => NUM,
                feature_type_acc1         => STR,
                feature_type_acc2         => STR,

            }
        },
        {   name   => 'cmap_correspondence_matrix',
            fields => {
                reference_map_acc     => STR,
                reference_map_name    => STR,
                reference_map_set_acc => STR,
                reference_species_acc => STR,
                link_map_acc          => STR,
                link_map_name         => STR,
                link_map_set_acc      => STR,
                link_species_acc      => STR,
                no_correspondences    => NUM,
            }
        },
        {   name   => 'cmap_feature',
            fields => {
                feature_id       => NUM,
                feature_acc      => STR,
                map_id           => NUM,
                feature_type_acc => STR,
                feature_name     => STR,
                is_landmark      => NUM,
                feature_start    => NUM,
                feature_stop     => NUM,
                default_rank     => NUM,
                direction        => NUM,
            }
        },
        {   name   => 'cmap_feature_alias',
            fields => {
                feature_alias_id => NUM,
                feature_id       => NUM,
                alias            => STR,
            }
        },
        {   name   => 'cmap_feature_correspondence',
            fields => {
                feature_correspondence_id  => NUM,
                feature_correspondence_acc => STR,
                feature_id1                => NUM,
                feature_id2                => NUM,
                is_enabled                 => NUM,
            }
        },
        {   name   => 'cmap_map',
            fields => {
                map_id        => NUM,
                map_acc       => STR,
                map_set_id    => NUM,
                map_name      => STR,
                display_order => NUM,
                map_start     => NUM,
                map_stop      => NUM,
            }
        },
        {   name   => 'cmap_next_number',
            fields => {
                table_name  => STR,
                next_number => NUM,
            }
        },
        {   name   => 'cmap_species',
            fields => {
                species_id          => NUM,
                species_acc         => STR,
                species_common_name => STR,
                species_full_name   => STR,
                display_order       => STR,
            }
        },
        {   name   => 'cmap_map_set',
            fields => {
                map_set_id         => NUM,
                map_set_acc        => STR,
                map_set_name       => STR,
                map_set_short_name => STR,
                map_type_acc       => STR,
                species_id         => NUM,
                published_on       => STR,
                display_order      => NUM,
                is_enabled         => NUM,
                shape              => STR,
                color              => STR,
                width              => NUM,
                map_units          => STR,
                is_relational_map  => NUM,
            },
        },
        {   name   => 'cmap_xref',
            fields => {
                xref_id       => NUM,
                table_name    => STR,
                object_id     => NUM,
                display_order => NUM,
                xref_name     => STR,
                xref_url      => STR,
            }
        },

        # Omit saved links because the step object won't export nicely
        #{   name   => 'cmap_saved_link',
        #    fields => {
        #        saved_link_id       => NUM,
        #        saved_on            => STR,
        #        last_access         => STR,
        #        session_step_object => STR,
        #        saved_url           => STR,
        #        legacy_url          => STR,
        #        link_title          => STR,
        #        link_comment        => STR,
        #        link_group          => STR,
        #        hidden              => STR,
        #    }
        #},

        {   name   => 'cmap_map_to_feature',
            fields => {
                map_id      => NUM,
                map_acc     => STR,
                feature_id  => NUM,
                feature_acc => STR,
            }
        },

        {   name   => 'cmap_transaction',
            fields => {
                transaction_id   => NUM,
                transaction_date => STR,
            }
        },

        {   name   => 'cmap_commit_log',
            fields => {
                commit_log_id  => NUM,
                species_id     => NUM,
                species_acc    => STR,
                map_set_id     => NUM,
                map_set_acc    => STR,
                map_id         => NUM,
                map_acc        => STR,
                commit_type    => STR,
                commit_text    => STR,
                commit_object  => STR,
                commit_date    => STR,
                transaction_id => NUM,
            }
        },
    );

    return \@tables;
}

=pod

=head1 Special Information Methods

=cut 

#-----------------------------------------------
sub get_slot_info {

=pod

=head2 get_slot_info()

=over 4

=item * Description

Creates and returns map info for each slot in a very specific format.  

It iterates through the slots starting from the inside and going out (0,1,-1,2,-2...).  After slot 0, it makes sure that only maps that have correspondences to the preceding slot.  It uses the map set accessions from the map_sets hash and the information in the maps hash to get the maps.  

The other optional inputs are used to widdle down the correspondences.

=item * Adaptor Writing Info

It might be a good idea to follow the code follows.

=item * Required Input

=over 4

=item - Slot information (slots)

 Data Structure
  slots = {
    slot_no => {
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

=back

=item * Optional Input

=over 4

=item - Included Evidence Types Accessions (included_evidence_type_accs)

=item - Ev. types that must be less than score (less_evidence_type_accs)

=item - Ev. types that must be greater than score (greater_evidence_type_accs)

=item - Scores for comparing to evidence types (evidence_type_score)

=item - Feature Type Accessions to ignore (ignored_feature_type_accs)

=item - Hash that holds the minimum number of correspondences for each slot (slot_min_corrs)

=item - Set to true if the maps w/out corrs should be removed (eliminate_orphans)

=back

=item * Output

 Data Structure:
  slot_info  =  {
    slot_no  => {
      map_id => [ current_start, current_stop, ori_start, ori_stop, magnification, map_acc ]
    }
  }

"current_start" and "current_stop" are undef if using the
original start and stop.

=item * Cache Level: 4

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object                 => 0,
        no_validation               => 0,
        slots                       => 1,
        included_evidence_type_accs => 0,
        ignored_feature_type_accs   => 0,
        less_evidence_type_accs     => 0,
        greater_evidence_type_accs  => 0,
        evidence_type_score         => 0,
        slot_min_corrs              => 0,
        eliminate_orphans           => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $slots = $args{'slots'} || {};
    my $ignored_feature_type_accs = $args{'ignored_feature_type_accs'} || [];
    my $included_evidence_type_accs = $args{'included_evidence_type_accs'}
        || [];
    my $less_evidence_type_accs = $args{'less_evidence_type_accs'} || [];
    my $greater_evidence_type_accs = $args{'greater_evidence_type_accs'}
        || [];
    my $evidence_type_score = $args{'evidence_type_score'} || {};
    my $slot_min_corrs      = $args{'slot_min_corrs'}      || {};
    my $eliminate_orphans   = $args{'eliminate_orphans'}   || 0;
    my $db                  = $self->db;
    my $return_object       = {};

    # Return.  slot_info is not setting it.
    return {} unless ($slots);

    my @num_sorted_slot_nos = sort { $a <=> $b } keys %{$slots};
    my $left_slot_no        = $num_sorted_slot_nos[0];
    my $right_slot_no       = $num_sorted_slot_nos[-1];

    my $sql_base = q[
      select distinct m.map_id,
             m.map_start,
             m.map_stop,
             m.map_start,
             m.map_stop,
             m.map_acc
      from   cmap_map m
      ];

    my $real_number_regex = $self->{'real_number_regex'};

    #print S#TDERR Dumper($slots)."\n";
    my $sql_suffix;
    foreach my $slot_no ( sort orderOutFromZero keys %{$slots} ) {
        next unless ( $slots->{$slot_no} );
        my $from                 = ' ';
        my $where                = '';
        my $group_by_sql         = '';
        my $having               = '';
        my $acc_where            = '';
        my $sql_str              = '';
        my $map_sets             = $slots->{$slot_no}{'map_sets'};
        my $maps                 = $slots->{$slot_no}{'maps'};
        my $ori_min_corrs        = $slots->{$slot_no}{'min_corrs'};
        my $applied_min_corrs    = $ori_min_corrs;
        my $new_min_corrs        = $slot_min_corrs->{$slot_no};
        my $use_corr_restriction = 0;

        if ( $slot_no == 0 ) {
            if ( $maps and %{$maps} ) {

                $acc_where .= ' or ' if ($acc_where);
                $acc_where
                    .= " m.map_acc in ("
                    . join( ",",
                    map { $db->quote($_) } sort keys( %{$maps} ) )
                    . ")";
            }
            elsif ( $map_sets and %{$map_sets} ) {
                $from .= q[,
                  cmap_map_set ms ];
                $where .= " m.map_set_id=ms.map_set_id ";

                #Map set acc
                $acc_where .= " (ms.map_set_acc = "
                    . join( " or ms.map_set_acc = ",
                    map { $db->quote($_) } sort keys( %{$map_sets} ) )
                    . ") ";
            }
        }
        else {
            my $slot_modifier = $slot_no > 0 ? -1 : 1;
            my $corr_restrict;  # -1 if less restrictive, 1 if more, 0 if same
            if ( not defined($new_min_corrs) ) {
                $corr_restrict = 0;
            }
            elsif ( not $new_min_corrs ) {
                if ( not $ori_min_corrs ) {
                    $corr_restrict = 0;
                }
                else {
                    $corr_restrict = -1;
                }
            }
            elsif ( not $ori_min_corrs ) {
                $corr_restrict = 1;
            }
            else {
                $corr_restrict = ( $new_min_corrs <=> $ori_min_corrs );
            }

            if ($corr_restrict) {

                # restriction has changed use new one
                $applied_min_corrs = $new_min_corrs;
            }

            if (    $maps
                and %{$maps}
                and !$eliminate_orphans
                and $corr_restrict <= 0 )
            {

                $acc_where .= ' and ' if ($acc_where);
                $acc_where
                    .= " m.map_acc in ("
                    . join( ",",
                    map { $db->quote($_) } sort keys( %{$maps} ) )
                    . ")";
            }
            else {

                $from .= q[,
                  cmap_correspondence_lookup cl
                  ];
                $where .= q[ m.map_id=cl.map_id1 
                     and cl.map_id1!=cl.map_id2 ];

                ### Add the information about the adjoinint slot
                ### including info about the start and end.
                $where .= " and (";
                my @ref_map_strs = ();
                my $ref_slot_id  = $slot_no + $slot_modifier;
                my $slot_info    = $return_object->{$ref_slot_id};
                next unless $slot_info;
                foreach my $m_id (
                    sort keys( %{ $return_object->{$ref_slot_id} } ) )
                {
                    my $r_m_str = " (cl.map_id2 = $m_id ";
                    if (    defined( $slot_info->{$m_id}->[0] )
                        and defined( $slot_info->{$m_id}->[1] ) )
                    {
                        $r_m_str
                            .= " and (( cl.feature_start2>="
                            . $db->quote( $slot_info->{$m_id}->[0] )
                            . " and cl.feature_start2<="
                            . $db->quote( $slot_info->{$m_id}->[1] )
                            . " ) or ( cl.feature_stop2 is not null and "
                            . "  cl.feature_start2<="
                            . $db->quote( $slot_info->{$m_id}->[0] )
                            . " and cl.feature_stop2>="
                            . $db->quote( $slot_info->{$m_id}->[0] )
                            . " ))) ";
                    }
                    elsif ( defined( $slot_info->{$m_id}->[0] ) ) {
                        $r_m_str
                            .= " and (( cl.feature_start2>="
                            . $db->quote( $slot_info->{$m_id}->[0] )
                            . " ) or ( cl.feature_stop2 is not null "
                            . " and cl.feature_stop2>="
                            . $db->quote( $slot_info->{$m_id}->[0] )
                            . " ))) ";
                    }
                    elsif ( defined( $slot_info->{$m_id}->[1] ) ) {
                        $r_m_str .= " and cl.feature_start2<="
                            . $db->quote( $slot_info->{$m_id}->[1] ) . ") ";
                    }
                    else {
                        $r_m_str .= ") ";
                    }

                    push @ref_map_strs, $r_m_str;
                }
                $where .= join( ' or ', @ref_map_strs ) . ") ";

                ### Add in considerations for feature and evidence types
                if (    $ignored_feature_type_accs
                    and @$ignored_feature_type_accs )
                {
                    $where .= " and cl.feature_type_acc1 not in ("
                        . join( ",",
                        map { $db->quote($_) }
                            sort @$ignored_feature_type_accs )
                        . ") ";
                    $where
                        .= " and ( cl.feature_type_acc1=cl.feature_type_acc2 "
                        . " or cl.feature_type_acc2 not in ("
                        . join( ",",
                        map { $db->quote($_) }
                            sort @$ignored_feature_type_accs )
                        . ") ) ";
                }

                if (   @$included_evidence_type_accs
                    or @$less_evidence_type_accs
                    or @$greater_evidence_type_accs )
                {
                    $from  .= ", cmap_correspondence_evidence ce ";
                    $where .= " and ce.feature_correspondence_id = "
                        . "cl.feature_correspondence_id ";
                    $where .= " and ( ";
                    my @join_array;
                    if (@$included_evidence_type_accs) {
                        push @join_array, " ce.evidence_type_acc in ("
                            . join( ",",
                            map { $db->quote($_) }
                                sort @$included_evidence_type_accs )
                            . ")";
                    }
                    foreach my $et_acc ( sort @$less_evidence_type_accs ) {
                        push @join_array,
                            " ( ce.evidence_type_acc = "
                            . $db->quote($et_acc) . " "
                            . " and ce.score <= "
                            . $db->quote( $evidence_type_score->{$et_acc} )
                            . " ) ";
                    }
                    foreach my $et_acc ( sort @$greater_evidence_type_accs ) {
                        push @join_array,
                            " ( ce.evidence_type_acc = "
                            . $db->quote($et_acc) . " "
                            . " and ce.score >= "
                            . $db->quote( $evidence_type_score->{$et_acc} )
                            . " ) ";
                    }
                    $where .= join( ' or ', @join_array ) . " ) ";
                }
                else {
                    $from  .= ", cmap_correspondence_evidence ce ";
                    $where .= " and ce.correspondence_evidence_id = -1 ";
                }

                # Get Map Sets
                if (   ( $corr_restrict < 0 and $map_sets and %{$map_sets} )
                    or ( not( $maps and %{$maps} ) ) )
                {
                    $use_corr_restriction = 1 if ($applied_min_corrs);
                    $from .= q[,
                      cmap_map_set ms ];
                    $where .= " and m.map_set_id=ms.map_set_id ";

                    #Map set acc
                    $acc_where .= "(ms.map_set_acc = "
                        . join( " or ms.map_set_acc = ",
                        map { $db->quote($_) } sort keys( %{$map_sets} ) )
                        . ")";
                }
                else {
                    $use_corr_restriction = 1 if ( $corr_restrict > 0 );
                    $acc_where .= ' or ' if ($acc_where);
                    $acc_where .= " m.map_acc in ("
                        . join( ",",
                        map { $db->quote($_) } sort keys( %{$maps} ) )
                        . ")";
                    foreach my $map_acc ( keys %{$maps} ) {
                        if (    defined( $maps->{$map_acc}{'start'} )
                            and defined( $maps->{$map_acc}{'stop'} ) )
                        {
                            $acc_where
                                .= qq[ and ( not (m.map_acc = ]
                                . $db->quote($map_acc) . q[)  ]
                                . " or (( cl.feature_start1>="
                                . $db->quote( $maps->{$map_acc}{'start'} )
                                . " and cl.feature_start1<="
                                . $db->quote( $maps->{$map_acc}{'stop'} )
                                . " ) or ( cl.feature_stop1 is not null and "
                                . "  cl.feature_start1<="
                                . $db->quote( $maps->{$map_acc}{'start'} )
                                . " and cl.feature_stop1>="
                                . $db->quote( $maps->{$map_acc}{'start'} )
                                . " ))) ";
                        }
                        elsif ( defined( $maps->{$map_acc}{'start'} ) ) {
                            $acc_where
                                .= qq[ and ( not (m.map_acc = ]
                                . $db->quote($map_acc) . q[)  ]
                                . " or (( cl.feature_start1>="
                                . $db->quote( $maps->{$map_acc}{'start'} )
                                . " ) or ( cl.feature_stop1 is not null "
                                . " and cl.feature_stop1>="
                                . $db->quote( $maps->{$map_acc}{'start'} )
                                . " ))) ";
                        }
                        elsif ( defined( $maps->{$map_acc}{'stop'} ) ) {
                            $acc_where
                                .= qq[ and ( not (m.map_acc = ]
                                . $db->quote($map_acc) . q[)  ]
                                . " or cl.feature_start1<="
                                . $db->quote( $maps->{$map_acc}{'stop'} )
                                . ") ";
                        }
                    }
                }
                if ($use_corr_restriction) {
                    $group_by_sql = q[ 
                        group by cl.map_id2,
                             m.map_start,
                             m.map_stop,
                             m.map_start,
                             m.map_stop,
                             m.map_acc
                        ];
                    $having
                        = " having count(cl.feature_correspondence_id) "
                        . ">="
                        . $db->quote($applied_min_corrs) . " ";
                }
            }
        }
        if ($where) {
            $where = " where $where and ( $acc_where )";
        }
        else {
            $where = " where $acc_where ";
        }
        $sql_str = "$sql_base $from $where $group_by_sql $having\n";

        # The min_correspondences sql code doesn't play nice with distinct
        if ($use_corr_restriction) {
            $sql_str =~ s/distinct//;
        }

        #print S#TDERR "SLOT_INFO SQL \n$sql_str\n";

        my $slot_results;

        unless ( $slot_results = $self->get_cached_results( 4, $sql_str ) ) {
            $slot_results = $db->selectall_arrayref( $sql_str, {}, () );
            $self->store_cached_results( 4, $sql_str, $slot_results );
        }
        return $self->error( 'Reference Maps not in database.  '
                . 'Please check to make sure that you are using valid map/map_set accessions'
        ) unless ( @$slot_results or $slot_no );

        # Add start and end values into slot_info
        if ( $maps and %{$maps} ) {
            foreach my $row (@$slot_results) {
                if ( defined( $maps->{ $row->[5] }{'start'} )
                    and $maps->{ $row->[5] }{'start'} != $row->[1] )
                {
                    $row->[1] = $maps->{ $row->[5] }{'start'};
                    ### If start is a feature, get the positions
                    ### and store in both places.
                    if ( not $row->[1] =~ /^$real_number_regex$/ ) {
                        $row->[1] = $self->feature_name_to_position(
                            feature_name => $row->[1],
                            map_id       => $row->[0],
                            return_start => 1,
                        ) || undef;
                        $maps->{ $row->[5] }{'start'} = $row->[1];
                    }
                }
                else {
                    $row->[1] = undef;
                }
                if ( defined( $maps->{ $row->[5] }{'stop'} )
                    and $maps->{ $row->[5] }{'stop'} != $row->[2] )
                {
                    $row->[2] = $maps->{ $row->[5] }{'stop'};
                    ### If stop is a feature, get the positions.
                    ### and store in both places.
                    if ( not $row->[2] =~ /^$real_number_regex$/ ) {
                        $row->[2] = $self->feature_name_to_position(
                            feature_name => $row->[2],
                            map_id       => $row->[0],
                            return_start => 0,
                        ) || undef;
                        $maps->{ $row->[5] }{'stop'} = $row->[2];
                    }
                }
                else {
                    $row->[2] = undef;
                }
                ###flip start and end if start>end
                ( $row->[1], $row->[2] ) = ( $row->[2], $row->[1] )
                    if (defined( $row->[1] )
                    and defined( $row->[2] )
                    and $row->[1] > $row->[2] );
            }
        }
        else {
            ###No Maps specified, make all start/stops undef
            foreach my $row (@$slot_results) {
                $row->[1] = undef;
                $row->[2] = undef;
            }
        }
        foreach my $row (@$slot_results) {
            if ( defined( $row->[1] ) and $row->[1] =~ /(.+)\.0+$/ ) {
                $row->[1] = $1;
            }
            if ( defined( $row->[2] ) and $row->[2] =~ /(.+)\.0+$/ ) {
                $row->[2] = $1;
            }
            if ( $row->[3] =~ /(.+)\.0+$/ ) {
                $row->[3] = $1;
            }
            if ( $row->[4] =~ /(.+)\.0+$/ ) {
                $row->[4] = $1;
            }
            my $magnification = 1;
            if ( defined( $maps->{ $row->[5] }{'mag'} ) ) {
                $magnification = $maps->{ $row->[5] }{'mag'};
            }

            $return_object->{$slot_no}{ $row->[0] } = [
                $row->[1], $row->[2],      $row->[3],
                $row->[4], $magnification, $row->[5]
            ];
        }
    }

    # If ever a slot has no maps, remove the slot.
    my $delete_pos = 0;
    my $delete_neg = 0;
    foreach my $slot_no ( sort orderOutFromZero keys %{$slots} ) {
        if ( scalar( keys( %{ $return_object->{$slot_no} } ) ) <= 0 ) {
            if ( $slot_no >= 0 ) {
                $delete_pos = 1;
            }
            if ( $slot_no <= 0 ) {
                $delete_neg = 1;
            }
        }
        if ( $slot_no >= 0 and $delete_pos ) {
            delete $return_object->{$slot_no};
            delete $slots->{$slot_no};
        }
        elsif ( $slot_no < 0 and $delete_neg ) {
            delete $return_object->{$slot_no};
            delete $slots->{$slot_no};
        }
    }

    return $return_object;
}

=pod

=head1 Species Methods

=cut 

#-----------------------------------------------
sub get_species {

=pod

=head2 get_species()

=over 4

=item * Description

Gets species information

=item * Adaptor Writing Info

=item * Required Input

=over 4

=back

=item * Optional Input

=over 4

=item - Species ID (species_id)

=item - Species Accession (species_acc)

=item - List of Species IDs (species_ids)

=item - List of Species Accessions (species_accs)

=item - Boolean: is this a relational map (is_relational_map)

Set to 1 or 0 to select based on the is_relational_map column.  Leave undefined
to ignore that column.

=item - Boolean: Is this enabled (is_enabled) 

Set to 1 or 0 to select based on the is_enabled column.  Leave undefined to
ignore that column.

=back

=item * Output

Array of Hashes:

  Keys:
    species_id,
    species_acc,
    species_common_name,
    species_full_name,
    display_order

=item * Cache Level (Not Used): 1

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object       => 0,
        no_validation     => 0,
        species_id        => 0,
        species_acc       => 0,
        species_ids       => 0,
        species_accs      => 0,
        is_relational_map => 0,
        is_enabled        => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $species_id        = $args{'species_id'};
    my $species_acc       = $args{'species_acc'};
    my $species_ids       = $args{'species_ids'} || [];
    my $species_accs      = $args{'species_accs'} || [];
    my $is_relational_map = $args{'is_relational_map'};
    my $is_enabled        = $args{'is_enabled'};
    my $db                = $self->db;
    my $return_object;
    my @identifiers = ();
    my $join_map_set
        = ( defined($is_relational_map) or defined($is_enabled) );

    my $select_sql    = "select ";
    my $distinct_sql  = '';
    my $select_values = q[
                 s.species_id,
                 s.species_acc,
                 s.species_common_name,
                 s.species_full_name,
                 s.display_order
    ];
    my $from_sql = q[
        from     cmap_species s
    ];
    my $where_sql = '';
    my $order_sql = q[
        order by s.display_order,
                 species_common_name
    ];

    if ($species_id) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " s.species_id = " . $db->quote($species_id) . " ";
    }
    elsif ($species_acc) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " s.species_acc = " . $db->quote($species_acc) . " ";
    }
    elsif (@$species_ids) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " s.species_id in ("
            . join( ", ", map { $db->quote($_) } sort @$species_ids ) . ") ";
    }
    elsif (@$species_accs) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " s.species_acc in ("
            . join( ", ", map { $db->quote($_) } sort @$species_accs ) . ") ";
    }

    if ($join_map_set) {

        # cmap_map_set needs to be joined
        $distinct_sql = ' distinct ';
        $from_sql  .= ", cmap_map_set ms ";
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " s.species_id=ms.species_id ";

        if ( defined($is_relational_map) ) {
            $where_sql .= " and ms.is_relational_map = "
                . $db->quote($is_relational_map) . " ";
        }
        if ( defined($is_enabled) ) {
            $where_sql
                .= " and ms.is_enabled = " . $db->quote($is_enabled) . " ";
        }
    }

    my $sql_str
        = $select_sql
        . $distinct_sql
        . $select_values
        . $from_sql
        . $where_sql
        . $order_sql;

    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} },
        @identifiers );

    return $return_object;
}

#-----------------------------------------------
sub get_species_acc {

=pod

=head2 get_species_acc()

=over 4

=item * Description

Given a map set get it's species accession.

=item * Adaptor Writing Info

=item * Required Input

=over 4

=item - Map Set Accession (map_set_acc)

=back

=item * Output

Species Accession

=item * Cache Level (Not Used): 1

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        map_set_acc   => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $map_set_acc = $args{'map_set_acc'};
    my $db          = $self->db;
    my $return_object;
    my $select_sql = " select s.species_acc ";
    my $from_sql   = qq[
        from   cmap_map_set ms,
               cmap_species s
    ];
    my $where_sql = qq[
        where ms.species_id=s.species_id
    ];

    if ($map_set_acc) {
        $where_sql
            .= " and ms.map_set_acc = " . $db->quote($map_set_acc) . " ";
    }
    else {
        return;
    }

    my $sql_str = $select_sql . $from_sql . $where_sql;

    $return_object = $db->selectrow_array( $sql_str, {} );

    return $return_object;
}

#-----------------------------------------------
sub insert_species {

=pod

=head2 insert_species()

=over 4

=item * Description

Insert a species into the database.

=item * Adaptor Writing Info

The required inputs are only the ones that the database requires.

If you don't want CMap to insert into your database, make this a dummy method.

=item * Input

=over 4

=item - Species Accession (species_acc)

=item - Species Common Name (species_common_name)

=item - Species Full Name (species_full_name)

=item - Display Order (display_order)

=back

=item * Output

Species id

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object         => 0,
        no_validation       => 0,
        species_acc         => 0,
        accession_id        => 0,
        species_common_name => 0,
        species_full_name   => 0,
        display_order       => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $species_acc = $args{'species_acc'} || $args{'accession_id'};
    my $species_common_name = $args{'species_common_name'} || q{};
    my $species_full_name   = $args{'species_full_name'}   || q{};
    my $display_order       = $args{'display_order'}       || 1;
    my $db                  = $self->db;
    my $species_id = $self->next_number( object_type => 'species', )
        or return $self->error('No next number for species ');
    $species_acc ||= $species_id;
    my @insert_args = (
        $species_id, $species_acc, $species_common_name, $species_full_name,
        $display_order
    );

    $db->do(
        qq[
        insert into cmap_species
        (species_id,species_acc,species_common_name,species_full_name,display_order )
         values ( ?,?,?,?,? )
        ],
        {},
        (@insert_args)
    );

    return $species_id;
}

#-----------------------------------------------
sub update_species {

=pod

=head2 update_species()

=over 4

=item * Description

Given the id and some attributes to modify, updates.

=item * Adaptor Writing Info

If you don't want CMap to update into your database, make this a dummy method.

=item * Required Input

=over 4

=item - Species ID (species_id)

=back

=item * Inputs To Update

=over 4

=item - Species Accession (species_acc)

=item - Species Common Name (species_common_name)

=item - Species Full Name (species_full_name)

=item - Display Order (display_order)

=back

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object         => 0,
        no_validation       => 0,
        species_id          => 0,
        object_id           => 0,
        species_acc         => 0,
        accession_id        => 0,
        species_common_name => 0,
        species_full_name   => 0,
        display_order       => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $species_id = $args{'species_id'} || $args{'object_id'} or return;
    my $species_acc = $args{'species_acc'} || $args{'accession_id'};
    my $species_common_name = $args{'species_common_name'};
    my $species_full_name   = $args{'species_full_name'};
    my $display_order       = $args{'display_order'};
    my $db                  = $self->db;

    my @update_args = ();
    my $update_sql  = qq[
        update cmap_species
    ];
    my $set_sql   = '';
    my $where_sql = " where species_id = ? ";    # ID

    if ($species_acc) {
        push @update_args, $species_acc;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " species_acc = ? ";
    }
    if ($species_common_name) {
        push @update_args, $species_common_name;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " species_common_name = ? ";
    }
    if ($species_full_name) {
        push @update_args, $species_full_name;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " species_full_name = ? ";
    }
    if ($display_order) {
        push @update_args, $display_order;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " display_order = ? ";
    }

    push @update_args, $species_id;

    my $sql_str = $update_sql . $set_sql . $where_sql;
    $db->do( $sql_str, {}, @update_args );

}

#-----------------------------------------------
sub delete_species {

=pod

=head2 delete_species()

=over 4

=item * Description

Given the id, delete this object.

=item * Adaptor Writing Info

If you don't want CMap to delete from your database, make this a dummy method.

=item * Requred Input

=over 4

=item - Species ID (species_id)

=back

=item * Output

1

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        species_id    => 1,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $db         = $self->db;
    my $species_id = $args{'species_id'}
        or return $self->error('No ID given for species to delete ');
    my @delete_args = ();
    my $delete_sql  = qq[
        delete from cmap_species
    ];
    my $where_sql = '';

    return unless ($species_id);

    if ($species_id) {
        push @delete_args, $species_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " species_id = ? ";
    }

    $delete_sql .= $where_sql;
    $db->do( $delete_sql, {}, (@delete_args) );

    return 1;
}

=pod

=head1 Map Set Methods

=cut 

#-----------------------------------------------
sub get_map_sets {

=pod

=head2 get_map_sets()

=over 4

=item * Description

Get information on map sets including species info.

=item * Adaptor Writing Info

=item * Requred Input

=over 4

=back

=item * Optional Input

=over 4

=item - Species ID (species_id)

=item - List of Species IDs (species_ids)

=item - Species Accession (species_acc)

=item - Map Set ID (map_set_id)

=item - List of Map Set IDs (map_set_ids)

=item - Map Set Accession (map_set_acc)

=item - List of Map Set Accessions (map_set_accs)

=item - Map Type Accession (map_type_acc)

=item - Boolean: is this a relational map (is_relational_map)

Set to 1 or 0 to select based on the is_relational_map column.  Leave undefined
to ignore that column.

=item - Boolean: Is this enabled (is_enabled) 

Set to 1 or 0 to select based on the is_enabled column.  Leave undefined to
ignore that column.

=item - Boolean count_maps (count_maps)

Add a map count to the return object

=back

=item * Output

Array of Hashes:

  Keys:
    map_set_id,
    map_set_acc,
    map_set_name,
    map_set_short_name,
    map_type_acc,
    published_on,
    is_enabled,
    is_relational_map,
    map_units,
    map_set_display_order,
    shape,
    color,
    width,
    species_id,
    species_acc,
    species_common_name,
    species_full_name,
    species_display_order,
    map_type,
    map_type_display_order,
    epoch_published_on,
    map_count (Only if $count_maps is specified)

=item * Cache Level : 1

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object       => 0,
        no_validation     => 0,
        species_id        => 0,
        species_ids       => 0,
        species_acc       => 0,
        map_set_id        => 0,
        map_set_ids       => 0,
        map_set_acc       => 0,
        map_set_accs      => 0,
        map_type_acc      => 0,
        map_type_accs     => 0,
        is_relational_map => 0,
        is_enabled        => 0,
        count_maps        => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $species_id        = $args{'species_id'};
    my $species_ids       = $args{'species_ids'} || [];
    my $species_acc       = $args{'species_acc'};
    my $map_set_id        = $args{'map_set_id'};
    my $map_set_ids       = $args{'map_set_ids'} || [];
    my $map_set_acc       = $args{'map_set_acc'};
    my $map_set_accs      = $args{'map_set_accs'} || [];
    my $map_type_acc      = $args{'map_type_acc'};
    my $map_type_accs     = $args{'map_type_accs'} || [];
    my $is_relational_map = $args{'is_relational_map'};
    my $is_enabled        = $args{'is_enabled'};
    my $count_maps        = $args{'count_maps'};
    my $db                = $self->db;
    my $map_type_data     = $self->map_type_data();
    my $return_object;

    my $select_sql = q[
        select  ms.map_set_id,
                ms.map_set_acc,
                ms.map_set_name,
                ms.map_set_short_name,
                ms.map_type_acc,
                ms.published_on,
                ms.is_enabled,
                ms.is_relational_map,
                ms.map_units,
                ms.display_order as map_set_display_order,
                ms.shape,
                ms.color,
                ms.width,
                s.species_id,
                s.species_acc,
                s.species_common_name,
                s.species_full_name,
                s.display_order as species_display_order
    ];
    my $from_sql = qq[
        from    cmap_species s,
                cmap_map_set ms
    ];
    my $where_sql = qq[
        where   ms.species_id=s.species_id
    ];
    my $group_by_sql = '';
    my $order_by_sql = '';

    if ($map_set_id) {
        $where_sql .= " and ms.map_set_id = " . $db->quote($map_set_id) . " ";
    }
    elsif (@$map_set_ids) {
        $where_sql .= " and ms.map_set_id in ("
            . join( ",", map { $db->quote($_) } sort @$map_set_ids ) . ") ";
    }
    elsif ($map_set_acc) {
        $where_sql
            .= " and ms.map_set_acc = " . $db->quote($map_set_acc) . " ";
    }
    elsif (@$map_set_accs) {
        $where_sql .= " and ms.map_set_acc in ("
            . join( ",", map { $db->quote($_) } sort @$map_set_accs ) . ") ";
    }
    if ($species_id) {
        $where_sql .= " and s.species_id= " . $db->quote($species_id) . " ";
    }
    elsif (@$species_ids) {
        $where_sql .= " and s.species_id in ("
            . join( ",", map { $db->quote($_) } sort @$species_ids ) . ") ";
    }
    elsif ( $species_acc and $species_acc ne '-1' ) {
        $where_sql .= " and s.species_acc= " . $db->quote($species_acc) . " ";
    }
    if ($map_type_acc) {
        $where_sql
            .= " and ms.map_type_acc = " . $db->quote($map_type_acc) . " ";
    }
    elsif (@$map_type_accs) {
        $where_sql .= " and ms.map_type_acc in ("
            . join( ",", map { $db->quote($_) } sort @$map_type_accs ) . ") ";
    }
    if ( defined($is_relational_map) ) {
        $where_sql .= " and ms.is_relational_map = "
            . $db->quote($is_relational_map) . " ";
    }
    if ( defined($is_enabled) and $is_enabled =~ /\d/ ) {
        $where_sql .= " and ms.is_enabled = " . $db->quote($is_enabled) . " ";
    }
    if ($count_maps) {
        $select_sql .= ", count(map.map_id) as map_count ";
        $from_sql   .= qq[
            left join   cmap_map map
            on ms.map_set_id=map.map_set_id
        ];
        $group_by_sql = qq[
            group by 
                ms.map_set_id,
                ms.map_set_acc,
                ms.map_set_name,
                ms.map_set_short_name,
                ms.map_type_acc,
                ms.published_on,
                ms.is_enabled,
                ms.is_relational_map,
                ms.map_units,
                ms.display_order,
                ms.shape,
                ms.color,
                ms.width,
                s.species_id,
                s.species_acc,
                s.species_common_name,
                s.species_full_name,
                s.display_order
        ];
    }

    my $sql_str
        = $select_sql
        . $from_sql
        . $where_sql
        . $group_by_sql
        . $order_by_sql;

    unless ( $return_object = $self->get_cached_results( 1, $sql_str ) ) {
        $return_object
            = $db->selectall_arrayref( $sql_str, { Columns => {} }, );

        foreach my $row (@$return_object) {
            $row->{'map_type'}
                = $map_type_data->{ $row->{'map_type_acc'} }{'map_type'};
            $row->{'map_type_display_order'}
                = $map_type_data->{ $row->{'map_type_acc'} }{'display_order'}
                || 0;
            $row->{'epoch_published_on'}
                = parsedate( $row->{'published_on'} );
        }

        $return_object = sort_selectall_arrayref(
            $return_object,            '#map_type_display_order',
            'map_type',                '#species_display_order',
            'species_common_name',     '#map_set_display_order',
            'epoch_published_on desc', 'map_set_short_name',
        );

        $self->store_cached_results( 1, $sql_str, $return_object );
    }

    return $return_object;
}

# --------------------------------------------------
sub get_map_sets_simple {

=pod

=head2 get_map_sets_simple()

=over 4

=item * Description

Get just the info from the map sets.  This is less data than
get_map_sets() provides and doesn't involve any table joins.

=item * Required Input

=over 4

=back

=item * Optional Input

=over 4

=item - Map Set ID (map_set_id)

=item - List of Map Set IDs (map_set_ids)

=item - Map Set Accession (map_set_acc)

=item - List of Map Set Accessions (map_set_accs)

=item - Map Type Accession (map_type_acc)

=item - Boolean: is this a relational map (is_relational_map)

Set to 1 or 0 to select based on the is_relational_map column.  Leave undefined
to ignore that column.

=item - Boolean: Is this enabled (is_enabled) 

Set to 1 or 0 to select based on the is_enabled column.  Leave undefined to
ignore that column.

=back

=item * Output

Array of Hashes:

  Keys:
    map_set_id
    map_set_acc
    map_set_name
    map_set_short_name
    map_type_acc
    species_id
    published_on
    is_enabled
    is_relational_map
    map_units
    map_set_display_order
    map_type
    map_type_display_order
    epoch_published_on

=item * Cache Level (Not Used): 1

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object       => 0,
        no_validation     => 0,
        map_set_id        => 0,
        map_set_ids       => 0,
        map_set_acc       => 0,
        map_set_accs      => 0,
        map_type_acc      => 0,
        is_relational_map => 0,
        is_enabled        => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $map_set_id        = $args{'map_set_id'};
    my $map_set_ids       = $args{'map_set_ids'} || [];
    my $map_set_acc       = $args{'map_set_acc'};
    my $map_set_accs      = $args{'map_set_accs'} || [];
    my $map_type_acc      = $args{'map_type_acc'};
    my $is_relational_map = $args{'is_relational_map'};
    my $is_enabled        = $args{'is_enabled'};
    my $db                = $self->db;
    my $map_type_data     = $self->map_type_data();
    my $return_object;

    my $sql_str = q[
        select  ms.map_set_id,
                ms.map_set_acc,
                ms.map_set_name,
                ms.map_set_short_name,
                ms.map_type_acc,
                ms.species_id,
                ms.published_on,
                ms.is_enabled,
                ms.is_relational_map,
                ms.map_units,
                ms.display_order as map_set_display_order
        from    cmap_map_set ms
    ];
    my $where_sql = '';

    if ($map_set_id) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " ms.map_set_id = " . $db->quote($map_set_id) . " ";
    }
    elsif (@$map_set_ids) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " ms.map_set_id in ("
            . join( ",", map { $db->quote($_) } sort @$map_set_ids ) . ") ";
    }
    elsif ($map_set_acc) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " ms.map_set_acc = " . $db->quote($map_set_acc) . " ";
    }
    elsif (@$map_set_accs) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " ms.map_set_acc in ("
            . join( ",", map { $db->quote($_) } sort @$map_set_accs ) . ") ";
    }
    if ($map_type_acc) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " ms.map_type_acc = " . $db->quote($map_type_acc) . " ";
    }
    if ( defined($is_relational_map) ) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " ms.is_relational_map = "
            . $db->quote($is_relational_map) . " ";
    }
    if ( defined($is_enabled) ) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " ms.is_enabled = " . $db->quote($is_enabled) . " ";
    }

    $sql_str .= $where_sql;

    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} }, );

    foreach my $row (@$return_object) {
        $row->{'map_type'}
            = $map_type_data->{ $row->{'map_type_acc'} }{'map_type'};
        $row->{'map_type_display_order'}
            = $map_type_data->{ $row->{'map_type_acc'} }{'display_order'};
        $row->{'epoch_published_on'} = parsedate( $row->{'published_on'} );
    }

    return $return_object;
}

#-----------------------------------------------
sub get_map_set_info_by_maps {

=pod

=head2 get_map_set_info_by_maps()

=over 4

=item * Description

Given a list of map_ids get map set info. 

=item * Required Input

=over 4

=back

=item * Optional Input

=over 4

=item - List of Map IDs (map_ids)

=back

=item * Output

Array of Hashes:

  Keys:
    map_set_id
    map_set_acc
    species_acc
    map_set_short_name
    species_common_name

=item * Cache Level (Not Used): 1

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        map_ids       => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $map_ids = $args{'map_ids'} || [];
    my $db = $self->db;
    my $return_object;
    my $sql_str = q[ 
        select distinct ms.map_set_id,
               ms.map_set_short_name,
               s.species_common_name,
               s.species_acc,
               ms.map_set_acc
        from   cmap_map_set ms,
               cmap_species s,
               cmap_map map 
        where  ms.species_id=s.species_id 
           and map.map_set_id=ms.map_set_id 
    ];
    if (@$map_ids) {

        # Only need to use one map id since all maps must
        # be from the same map set.
        $sql_str .= " and map.map_id = " . $db->quote( $map_ids->[0] ) . " ";
    }

    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} } );

    return $return_object;
}

#-----------------------------------------------
sub insert_map_set {

=pod

=head2 insert_map_set()

=over 4

Insert a map set into the database.

=item * Description

=item * Adaptor Writing Info

The required inputs are only the ones that the database requires.

If you don't want CMap to insert into your database, make this a dummy method.

=item * Input

=over 4

=item - Map Set Accession (map_set_acc)

=item - map_set_name (map_set_name)

=item - map_set_short_name (map_set_short_name)

=item - Map Type Accession (map_type_acc)

=item - Species ID (species_id)

=item - published_on (published_on)

=item - Display Order (display_order)

=item - Boolean: Is this enabled (is_enabled)

=item - shape (shape)

=item - width (width)

=item - color (color)

=item - map_units (map_units)

=item - Boolean: is this a relational map (is_relational_map)

=back

=item * Output

Map Set id

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object           => 0,
        no_validation         => 0,
        map_set_acc           => 0,
        accession_id          => 0,
        map_set_name          => 0,
        map_set_short_name    => 0,
        map_type_acc          => 0,
        map_type_aid          => 0,
        map_type_accession    => 0,
        species_id            => 0,
        published_on          => 0,
        display_order         => 0,
        map_set_display_order => 0,
        is_enabled            => 0,
        shape                 => 0,
        width                 => 0,
        color                 => 0,
        map_units             => 0,
        is_relational_map     => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $map_set_acc  = $args{'map_set_acc'}  || $args{'accession_id'};
    my $map_set_name = $args{'map_set_name'} || q{};
    my $map_set_short_name = $args{'map_set_short_name'} || q{};
    my $map_type_acc = $args{'map_type_acc'}
        || $args{'map_type_aid'}
        || $args{'map_type_accession'};
    my $species_id    = $args{'species_id'};
    my $published_on  = $args{'published_on'};
    my $display_order = $args{'display_order'};
    $display_order = $args{'map_set_display_order'}
        unless defined($display_order);
    $display_order = 1 unless defined($display_order);
    my $is_enabled = $args{'is_enabled'};
    $is_enabled = 1 unless ( defined($is_enabled) );
    my $shape             = $args{'shape'};
    my $width             = $args{'width'};
    my $color             = $args{'color'};
    my $map_units         = $args{'map_units'} || q{};
    my $is_relational_map = $args{'is_relational_map'} || 0;
    my $db                = $self->db;
    my $map_set_id        = $self->next_number( object_type => 'map_set', )
        or return $self->error('No next number for map_set ');
    $map_set_acc ||= $map_set_id;
    my @insert_args = (
        $map_set_id,         $map_set_acc,   $map_set_name,
        $map_set_short_name, $map_type_acc,  $species_id,
        $published_on,       $display_order, $is_enabled,
        $shape,              $width,         $color,
        $map_units,          $is_relational_map
    );

    $db->do(
        qq[
        insert into cmap_map_set
        (map_set_id,map_set_acc,map_set_name,map_set_short_name,map_type_acc,species_id,published_on,display_order,is_enabled,shape,width,color,map_units,is_relational_map )
         values ( ?,?,?,?,?,?,?,?,?,?,?,?,?,? )
        ],
        {},
        (@insert_args)
    );

    return $map_set_id;
}

#-----------------------------------------------
sub update_map_set {

=pod

=head2 update_map_set()

=over 4

=item * Description

Given the id and some attributes to modify, updates.

=item * Adaptor Writing Info

If you don't want CMap to update into your database, make this a dummy method.

=item * Required Input

=over 4

=item - Map Set ID (map_set_id)

=back

=item * Inputs To Update

=over 4

=item - Map Set Accession (map_set_acc)

=item - map_set_name (map_set_name)

=item - map_set_short_name (map_set_short_name)

=item - Map Type Accession (map_type_acc)

=item - Species ID (species_id)

=item - published_on (published_on)

=item - Display Order (display_order)

=item - Boolean: Is this enabled (is_enabled)

=item - shape (shape)

=item - width (width)

=item - color (color)

=item - map_units (map_units)

=item - Boolean: is this a relational map (is_relational_map)

Set to 1 or 0 to select based on the is_relational_map column.  Leave undefined
to ignore that column.

=back

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object           => 0,
        no_validation         => 0,
        map_set_id            => 0,
        object_id             => 0,
        map_set_acc           => 0,
        accession_id          => 0,
        map_set_name          => 0,
        map_set_short_name    => 0,
        map_type_acc          => 0,
        map_type_aid          => 0,
        map_type_accession    => 0,
        species_id            => 0,
        published_on          => 0,
        display_order         => 0,
        map_set_display_order => 0,
        is_enabled            => 0,
        shape                 => 0,
        width                 => 0,
        color                 => 0,
        map_units             => 0,
        is_relational_map     => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $map_set_id = $args{'map_set_id'} || $args{'object_id'}
        or return $self->error("No object id for update_map_sets");
    my $map_set_acc        = $args{'map_set_acc'} || $args{'accession_id'};
    my $map_set_name       = $args{'map_set_name'};
    my $map_set_short_name = $args{'map_set_short_name'};
    my $map_type_acc       = $args{'map_type_acc'}
        || $args{'map_type_aid'}
        || $args{'map_type_accession'};
    my $species_id    = $args{'species_id'};
    my $published_on  = $args{'published_on'};
    my $display_order = $args{'display_order'};
    $display_order = $args{'map_set_display_order'}
        unless defined($display_order);
    my $is_enabled        = $args{'is_enabled'};
    my $shape             = $args{'shape'};
    my $width             = $args{'width'};
    my $color             = $args{'color'};
    my $map_units         = $args{'map_units'};
    my $is_relational_map = $args{'is_relational_map'};
    my $db                = $self->db;

    my @update_args = ();
    my $update_sql  = qq[
        update cmap_map_set
    ];
    my $set_sql   = '';
    my $where_sql = " where map_set_id = ? ";    # ID

    if ($map_set_acc) {
        push @update_args, $map_set_acc;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " map_set_acc = ? ";
    }
    if ($map_set_name) {
        push @update_args, $map_set_name;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " map_set_name = ? ";
    }
    if ($map_set_short_name) {
        push @update_args, $map_set_short_name;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " map_set_short_name = ? ";
    }
    if ($map_type_acc) {
        push @update_args, $map_type_acc;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " map_type_acc = ? ";
    }
    if ($species_id) {
        push @update_args, $species_id;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " species_id = ? ";
    }
    if ($published_on) {
        push @update_args, $published_on;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " published_on = ? ";
    }
    if ($display_order) {
        push @update_args, $display_order;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " display_order = ? ";
    }
    if ( defined($is_enabled) ) {
        push @update_args, $is_enabled;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " is_enabled = ? ";
    }
    if ($shape) {
        push @update_args, $shape;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " shape = ? ";
    }
    if ($width) {
        push @update_args, $width;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " width = ? ";
    }
    if ($color) {
        push @update_args, $color;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " color = ? ";
    }
    if ($map_units) {
        push @update_args, $map_units;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " map_units = ? ";
    }
    if ( defined($is_relational_map) ) {
        push @update_args, $is_relational_map;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " is_relational_map = ? ";
    }

    push @update_args, $map_set_id;

    my $sql_str = $update_sql . $set_sql . $where_sql;
    $db->do( $sql_str, {}, @update_args );

}

#-----------------------------------------------
sub delete_map_set {

=pod

=head2 delete_map_set()

=over 4

=item * Description

Given the id, delete this object.

=item * Adaptor Writing Info

If you don't want CMap to delete from your database, make this a dummy method.

=item * Requred Input

=over 4

=item - Map Set ID (map_set_id)

=back

=item * Output

1

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        map_set_id    => 1,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $db         = $self->db;
    my $map_set_id = $args{'map_set_id'}
        or return $self->error('No ID given for map_set to delete ');
    my @delete_args = ();
    my $delete_sql  = qq[
        delete from cmap_map_set
    ];
    my $where_sql = '';

    return unless ($map_set_id);

    if ($map_set_id) {
        push @delete_args, $map_set_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " map_set_id = ? ";
    }

    $delete_sql .= $where_sql;
    $db->do( $delete_sql, {}, (@delete_args) );

    return 1;
}

=pod

=head1 Map Methods

=cut 

#-----------------------------------------------
sub get_maps {

=pod

=head2 get_maps()

=over 4

=item * Description

Get information on map sets including map set and species info.

=item * Required Input

=over 4

=back

=item * Optional Input

=over 4

=item - Map ID (map_id)

=item - List of Map IDs (map_ids)

=item - List of Map Accessions (map_accs)

=item - Map Set ID (map_set_id)

=item - Map Set Accession (map_set_acc)

=item - List of Map Set Accessions (map_set_accs)

=item - Map Name (map_name)

=item - Map Length (map_length)

=item - Map Type Accession (map_type_acc)

=item - Species Accession (species_acc)

=item - Boolean: is this a relational map (is_relational_map)

Set to 1 or 0 to select based on the is_relational_map column.  Leave undefined
to ignore that column.

=item - Boolean: Is this enabled (is_enabled) 

Set to 1 or 0 to select based on the is_enabled column.  Leave undefined to
ignore that column.

=item - Boolean count_features (count_features)

Add a feature count to the return object

=back

=item * Output

Array of Hashes:

  Keys:
    map_id,
    map_acc,
    map_name,
    map_start,
    map_stop,
    display_order,
    map_set_id,
    map_set_acc,
    map_set_name,
    map_set_short_name,
    published_on,
    shape,
    width,
    color,
    map_type_acc,
    map_units,
    is_relational_map,
    species_id,
    species_acc,
    species_common_name,
    species_full_name,
    map_type_display_order,
    map_type,
    epoch_published_on,
    default_shape
    default_color
    default_width
    feature_count (Only if $count_features is specified)

=item * Cache Level: 2

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object       => 0,
        no_validation     => 0,
        map_id            => 0,
        map_ids           => 0,
        map_acc           => 0,
        map_accs          => 0,
        map_set_id        => 0,
        map_set_acc       => 0,
        map_set_accs      => 0,
        map_name          => 0,
        map_length        => 0,
        map_type_acc      => 0,
        species_acc       => 0,
        is_relational_map => 0,
        is_enabled        => 0,
        count_features    => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $map_id            = $args{'map_id'};
    my $map_ids           = $args{'map_ids'} || [];
    my $map_acc           = $args{'map_acc'};
    my $map_accs          = $args{'map_accs'} || [];
    my $map_set_id        = $args{'map_set_id'};
    my $map_set_acc       = $args{'map_set_acc'};
    my $map_set_accs      = $args{'map_set_accs'} || [];
    my $map_name          = $args{'map_name'};
    my $map_length        = $args{'map_length'};
    my $map_type_acc      = $args{'map_type_acc'};
    my $species_acc       = $args{'species_acc'};
    my $is_relational_map = $args{'is_relational_map'};
    my $is_enabled        = $args{'is_enabled'};
    my $count_features    = $args{'count_features'};
    my $db                = $self->db;
    my $map_type_data     = $self->map_type_data();
    my $return_object;

    my $select_sql = q[
        select  map.map_id,
                map.map_acc,
                map.map_name,
                map.map_start,
                map.map_stop,
                map.display_order,
                ms.map_set_id,
                ms.map_set_acc,
                ms.map_set_name,
                ms.map_set_short_name,
                ms.published_on,
                ms.shape,
                ms.width,
                ms.color,
                ms.map_type_acc,
                ms.map_units,
                ms.is_relational_map,
                s.species_id,
                s.species_acc,
                s.species_common_name,
                s.species_full_name
    ];
    my $from_sql = q[
        from    cmap_map_set ms,
                cmap_species s,
                cmap_map map
    ];
    my $where_sql = q[
        where   map.map_set_id=ms.map_set_id
        and     ms.species_id=s.species_id
    ];
    my $group_by_sql = '';
    my $order_by_sql = '';

    if ($map_id) {
        $where_sql .= " and map.map_id = " . $db->quote($map_id) . " ";
    }
    elsif (@$map_ids) {
        $where_sql .= " and map.map_id in ("
            . join( ",", map { $db->quote($_) } sort @$map_ids ) . ") ";
    }
    if ($map_acc) {
        $where_sql .= " and map.map_acc = " . $db->quote($map_acc) . " ";
    }
    elsif (@$map_accs) {
        $where_sql .= " and map.map_acc in ("
            . join( q{,}, map { $db->quote($_) } sort @$map_accs ) . ") ";
    }
    if ($map_name) {
        $where_sql .= " and map.map_name=" . $db->quote($map_name) . " ";
    }
    if ($map_length) {
        $where_sql .= " and (map.map_stop - map.map_start + 1 = "
            . $db->quote($map_length) . ") ";
    }

    if ($map_set_id) {
        $where_sql .= " and ms.map_set_id = " . $db->quote($map_set_id) . " ";
    }
    elsif ($map_set_acc) {
        $where_sql
            .= " and ms.map_set_acc = " . $db->quote($map_set_acc) . " ";
    }
    elsif (@$map_set_accs) {
        $where_sql .= " and ms.map_set_acc in ("
            . join( ",", map { $db->quote($_) } sort @$map_set_accs ) . ") ";
    }

    if ($species_acc) {
        $where_sql .= q[ and s.species_acc=] . $db->quote($species_acc) . " ";
    }
    if ($map_type_acc) {
        $where_sql
            .= q[ and ms.map_type_acc=] . $db->quote($map_type_acc) . " ";
    }
    if ( defined($is_relational_map) ) {
        $where_sql .= " and ms.is_relational_map = "
            . $db->quote($is_relational_map) . " ";
    }
    if ( defined($is_enabled) ) {
        $where_sql .= " and ms.is_enabled = " . $db->quote($is_enabled) . " ";
    }

    if ($count_features) {
        $select_sql .= ", count(f.feature_id) as feature_count ";
        $from_sql   .= qq[
            left join   cmap_feature f
            on f.map_id=map.map_id
        ];
        $group_by_sql = qq[
            group by 
                map.map_id,
                map.map_acc,
                map.map_name,
                map.map_start,
                map.map_stop,
                map.display_order,
                ms.map_set_id,
                ms.map_set_acc,
                ms.map_set_name,
                ms.map_set_short_name,
                ms.published_on,
                ms.shape,
                ms.width,
                ms.color,
                ms.map_type_acc,
                ms.map_units,
                ms.is_relational_map,
                s.species_id,
                s.species_acc,
                s.species_common_name,
                s.species_full_name
        ];
    }
    $order_by_sql = ' order by map.display_order, map.map_name ';

    my $sql_str
        = $select_sql
        . $from_sql
        . $where_sql
        . $group_by_sql
        . $order_by_sql;

    unless ( $return_object = $self->get_cached_results( 2, $sql_str ) ) {
        $return_object
            = $db->selectall_arrayref( $sql_str, { Columns => {} } );

        foreach my $row ( @{$return_object} ) {
            $row->{'map_type'}
                = $map_type_data->{ $row->{'map_type_acc'} }{'map_type'};
            $row->{'map_type_display_order'}
                = $map_type_data->{ $row->{'map_type_acc'} }{'display_order'};
            $row->{'epoch_published_on'}
                = parsedate( $row->{'published_on'} );
            $row->{'default_shape'}
                = $map_type_data->{ $row->{'map_type_acc'} }{'shape'};
            $row->{'default_color'}
                = $map_type_data->{ $row->{'map_type_acc'} }{'color'};
            $row->{'default_width'}
                = $map_type_data->{ $row->{'map_type_acc'} }{'width'};
        }

        $self->store_cached_results( 2, $sql_str, $return_object );
    }
    return $return_object;
}

#-----------------------------------------------
sub get_maps_simple {

=pod

=head2 get_maps_simple()

=over 4

=item * Description

Get just the info from the maps.  This is less data than
get_maps() provides and doesn't involve any table joins.

=item * Required Input

=over 4

=back

=item * Optional Input

=over 4

=item - Map ID (map_id)

=item - Map Accession ID (map_acc)

=item - Map Set ID (map_set_id)

=back

=item * Output

Array of Hashes:

  Keys:
    map_id
    map_acc
    map_name
    display_order
    map_start
    map_stop
    map_set_id

=item * Cache Level (If Used): 2

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        map_id        => 0,
        map_acc       => 0,
        map_set_id    => 0,
    );
    validate( @_, \%validation_params );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $map_id     = $args{'map_id'};
    my $map_acc    = $args{'map_acc'};
    my $map_set_id = $args{'map_set_id'};
    my $db         = $self->db;
    my $return_object;
    my $sql_str = qq[
        select map_id,
               map_acc,
               map_name,
               display_order,
               map_start,
               map_stop,
               map_set_id
        from   cmap_map
    ];
    my $where_sql = '';

    if ($map_id) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " map_id = " . $db->quote($map_id) . " ";
    }
    elsif ($map_acc) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " map_acc = " . $db->quote($map_acc) . " ";
    }
    elsif ($map_set_id) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " map_set_id = " . $db->quote($map_set_id) . " ";
    }

    $sql_str .= $where_sql;

    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} } );

    return $return_object;
}

#-----------------------------------------------
sub get_maps_from_map_set {

=pod

=head2 get_maps_from_map_set()

=over 4

=item * Description

Given a map set accession, give a small amount of info about the maps in that
map set.

=item * Required Input

=over 4

=item - Map Set Accession (map_set_acc)

=back

=item * Output

Array of Hashes:

  Keys:
    map_acc
    map_id
    map_name
    map_start
    map_stop

=item * Cache Level (If Used): 2

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        map_set_acc   => 0,
        map_set_id    => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $map_set_acc = $args{'map_set_acc'};
    my $map_set_id  = $args{'map_set_id'};
    unless ( defined($map_set_acc) or defined($map_set_id) ) {
        die "No map set defined in get_maps_in_map_set()\n";
    }
    my $db = $self->db;
    my $return_object;
    my @identifiers;

    my $sql_str = q[
        select   map.map_acc,
                 map.map_id,
                 map.map_name,
                 map.map_start,
                 map.map_stop
        from     cmap_map map
    ];

    if ( defined($map_set_id) ) {
        $sql_str .= q[ 
            where    map.map_set_id = ?
        ];
        push @identifiers, $map_set_id;
    }
    if ( defined($map_set_acc) ) {
        $sql_str .= q[ 
               , cmap_map_set ms
        where    map.map_set_id=ms.map_set_id
        and      ms.map_set_acc=?
        ];
        push @identifiers, $map_set_acc;
    }
    $sql_str .= q[ 
        order by map.display_order,
                 map.map_name
    ];

    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} },
        @identifiers );

    return $return_object;
}

#-----------------------------------------------
sub get_map_search_info {

=pod

=head2 get_map_search_info()

=over 4

=item * Description

This is the method that drives the map search page.  Any new search features
will probably wind up here.

=item * Require Input

=over 4

=item - Map Set ID (map_set_id)

=back

=item * Optional Input

=over 4

=item - Map Name (map_name)

=item - min_correspondence_maps (min_correspondence_maps)

=item - Minimum number of correspondences (min_correspondences)

=back

=item * Output

Array of Hashes:

  Keys:
    map_acc
    map_name
    map_start
    map_stop
    map_id
    display_order
    cmap_count
    corr_count

=item * Cache Level (If Used): 4

Not Caching because the calling method will do that.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object             => 0,
        no_validation           => 0,
        map_set_id              => 1,
        map_name                => 0,
        min_correspondence_maps => 0,
        min_correspondences     => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $map_set_id = $args{'map_set_id'}
        or die "No Map Set Id passed to map search";
    my $map_name                = $args{'map_name'};
    my $min_correspondence_maps = $args{'min_correspondence_maps'};
    my $min_correspondences     = $args{'min_correspondences'};

    my $db = $self->db;
    my $return_object;

    my $sql_str = q[
        select  map.map_acc,
                map.map_name,
                map.map_start,
                map.map_stop,
                map.map_id,
                map.display_order,
                count(distinct(cl.map_id2)) as cmap_count,
                count(distinct(cl.feature_correspondence_id))
                    as corr_count
        from    cmap_map map
        Left join cmap_correspondence_lookup cl
                on map.map_id=cl.map_id1
        where    map.map_set_id=?
    ];
    if ($map_name) {
        $map_name =~ s/\*/%/g;
        my $comparison = $map_name =~ m/%/ ? 'like' : '=';
        if ( $map_name ne '%' ) {
            $sql_str .= " and map.map_name $comparison "
                . $db->quote($map_name) . " ";
        }
    }
    $sql_str .= q[
        group by map.map_acc,map.map_id, map.map_name,
            map.map_start,map.map_stop,map.display_order
    ];
    if ( $min_correspondence_maps and $min_correspondences ) {
        $sql_str
            .= " having count(distinct(cl.map_id2)) >="
            . $db->quote($min_correspondence_maps) . " "
            . " and count(distinct(cl.feature_correspondence_id)) >="
            . $db->quote($min_correspondences) . " ";
    }
    elsif ($min_correspondence_maps) {
        $sql_str .= " having count(distinct(cl.map_id2)) >="
            . $db->quote($min_correspondence_maps) . " ";
    }
    elsif ($min_correspondences) {
        $sql_str
            .= " having count(distinct(cl.feature_correspondence_id)) "
            . " >="
            . $db->quote($min_correspondences) . " ";
    }
    $return_object
        = $db->selectall_hashref( $sql_str, 'map_id', { Columns => {} },
        $map_set_id );

    return $return_object;
}

#-----------------------------------------------
sub insert_map {

=pod

=head2 insert_map()

=over 4

=item * Description

Insert a map into the database.

=item * Adaptor Writing Info

The required inputs are only the ones that the database requires.

If you don't want CMap to insert into your database, make this a dummy method.

=item * Input

=over 4

=item - map_acc (map_acc)

=item - Map Set ID (map_set_id)

=item - Map Name (map_name)

=item - Display Order (display_order)

=item - map_start (map_start)

=item - map_stop (map_stop)

=back

=item * Output

Map id

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object    => 0,
        no_validation  => 0,
        map_acc        => 0,
        accession_id   => 0,
        map_set_id     => 0,
        map_name       => 0,
        display_order  => 0,
        map_start      => 0,
        map_stop       => 0,
        start_position => 0,
        stop_position  => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $map_acc       = $args{'map_acc'} || $args{'accession_id'};
    my $map_set_id    = $args{'map_set_id'};
    my $map_name      = $args{'map_name'} || q{};
    my $display_order = $args{'display_order'} || 1;
    my $map_start     = $args{'map_start'};
    my $map_stop      = $args{'map_stop'};

    # Backwards compatibility
    $map_start = $args{'start_position'} unless defined($map_start);
    $map_stop  = $args{'stop_position'}  unless defined($map_stop);
    my $db = $self->db;
    my $map_id = $self->next_number( object_type => 'map', )
        or return $self->error('No next number for map');
    $map_acc ||= $map_id;
    my @insert_args = (
        $map_id, $map_acc, $map_set_id, $map_name, $display_order, $map_start,
        $map_stop
    );

    $db->do(
        qq[
        insert into cmap_map
        (map_id,map_acc,map_set_id,map_name,display_order,map_start,map_stop )
         values ( ?,?,?,?,?,?,? )
        ],
        {},
        (@insert_args)
    );

    return $map_id;
}

#-----------------------------------------------
sub update_map {

=pod

=head2 update_map()

=over 4

=item * Description

Given the id and some attributes to modify, updates.

=item * Adaptor Writing Info

If you don't want CMap to update into your database, make this a dummy method.

=item * Required Input

=over 4

=item - Map ID (map_id)

=back

=item * Inputs To Update

=over 4

=item - map_acc (map_acc)

=item - Map Set ID (map_set_id)

=item - Map Name (map_name)

=item - Display Order (display_order)

=item - map_start (map_start)

=item - map_stop (map_stop)

=back

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object    => 0,
        no_validation  => 0,
        map_id         => 0,
        object_id      => 0,
        map_acc        => 0,
        accession_id   => 0,
        map_set_id     => 0,
        map_name       => 0,
        display_order  => 0,
        map_start      => 0,
        map_stop       => 0,
        start_position => 0,
        stop_position  => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $map_id = $args{'map_id'} || $args{'object_id'} or return;
    my $map_acc = $args{'map_acc'} || $args{'accession_id'};
    my $map_set_id    = $args{'map_set_id'};
    my $map_name      = $args{'map_name'};
    my $display_order = $args{'display_order'};
    my $map_start     = $args{'map_start'};
    my $map_stop      = $args{'map_stop'};

    # Backwards compatibility
    $map_start = $args{'start_position'} unless defined($map_start);
    $map_stop  = $args{'stop_position'}  unless defined($map_stop);
    my $db = $self->db;
    my $return_object;

    my @update_args = ();
    my $update_sql  = qq[
        update cmap_map
    ];
    my $set_sql   = '';
    my $where_sql = " where map_id = ? ";    # ID

    if ($map_acc) {
        push @update_args, $map_acc;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " map_acc = ? ";
    }
    if ($map_set_id) {
        push @update_args, $map_set_id;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " map_set_id = ? ";
    }
    if ($map_name) {
        push @update_args, $map_name;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " map_name = ? ";
    }
    if ($display_order) {
        push @update_args, $display_order;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " display_order = ? ";
    }
    if ( defined($map_start) ) {
        push @update_args, $map_start;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " map_start = ? ";
    }
    if ( defined($map_stop) ) {
        push @update_args, $map_stop;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " map_stop = ? ";
    }

    push @update_args, $map_id;

    my $sql_str = $update_sql . $set_sql . $where_sql;
    $db->do( $sql_str, {}, @update_args );

}

#-----------------------------------------------
sub delete_map {

=pod

=head2 delete_map()

=over 4

=item * Description

Given the id, delete this object.

=item * Adaptor Writing Info

If you don't want CMap to delete from your database, make this a dummy method.

=item * Requred Input

=over 4

=item - Map ID (map_id)

=back

=item * Output

1

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        map_id        => 1,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $db     = $self->db;
    my $map_id = $args{'map_id'}
        or return $self->error('No ID given for map to delete ');
    my @delete_args = ();
    my $delete_sql  = qq[
        delete from cmap_map
    ];
    my $where_sql = '';

    return unless ($map_id);

    if ($map_id) {
        push @delete_args, $map_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " map_id = ? ";
    }

    $delete_sql .= $where_sql;
    $db->do( $delete_sql, {}, (@delete_args) );

    return 1;
}

#-----------------------------------------------
sub get_feature_id_bounds_on_map {

=pod

=head2 get_feature_id_bounds_on_map()

=over 4

=item * Description

Given a map_id give the highest and lowest feature_ids on the map.

=item * Required Input

=over 4

=item - Map ID (map_id)

=back

=item * Optional Input

=over 4

=back

=item * Output

Array of Hashes:

  Keys:
    map_id
    min_feature_id
    max_feature_id

=item * Cache Level (If Used): 3

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        map_id        => 1,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $map_id = $args{'map_id'};
    my $db     = $self->db;
    my $return_object;
    my $sql_str = qq[
        select  map_id,
                max(feature_id) as max_feature_id, 
                min(feature_id) as min_feature_id 
        from    cmap_feature
    ];
    my $where_sql = '';

    if ($map_id) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " map_id = " . $db->quote($map_id) . " ";
    }

    my $group_by_sql = " group by map_id ";
    $sql_str .= $where_sql . $group_by_sql;

    unless ( $return_object = $self->get_cached_results( 3, $sql_str ) ) {
        $return_object
            = $db->selectall_arrayref( $sql_str, { Columns => {} } );
        return {} unless $return_object;

        $self->store_cached_results( 4, $sql_str, $return_object );
    }

    return $return_object;
}

=pod

=head1 Feature Methods

=cut 

#-----------------------------------------------
sub get_features {

=pod

=head2 get_features()

=over 4

=item * Description

This method returns feature details.  At time of writing, this method is only
used in places methods that are only executed once per page view.  It is used
in places like the data_download, correspondence_detail_data and
feature_search_data.  Therefor, I'm not terribly worried about the time to
build the sql query (which increases with extra options).  I'm also not
concerned about the extra columns that are needed by some but not all of the
calling methods.

=item * Caveats

Identifiers that are more specific are used instead of more general ids.  For instance, if a feature_id and a map_id are specified, only the feature_id will be used because the map_id is a more broad search.

=item * Adaptor Writing Info

The aliases_get_rows is used (initially at least) for feature search.  It appends, to the results, feature information for aliases that match the feature_name value.  If there is no feature name supplied, it will repeat the feature info for each alias the identified features have.

=item * Required Input

=over 4

=back

=item * Optional Input

=over 4

=item - Feature ID (feature_id)

=item - Feature Accession (feature_acc)

=item - Feature Name (feature_name)

=item - Map ID (map_id)

=item - map_acc (map_acc)

=item - Map Set ID (map_set_id)

=item - List of Map Set IDs (map_set_ids)

=item - feature_start (feature_start)

=item - feature_stop (feature_stop)

=item - Direction (direction)

=item - Allowed feature types (feature_type_accs)

=item - Species ID (species_id)

=item - List of Species IDs (species_ids)

=item - List of Species Accessions (species_accs)

=item - Map Start and Map Stop (map_start,map_stop)

These must both be defined in order to to be used.  If defined the method will
return only features that overlap that region.

=item - Aliases get own rows (aliases_get_rows)

Value that dictates if aliases that match get there own rows.  This is mostly
usefull for feature_name searches.

=item - Don't get aliases (ignore_aliases)

Value that dictates if aliases are ignored.  The default is to get aliases.

=back

=item * Output

Array of Hashes:

  Keys:
    feature_id,
    feature_acc,
    feature_type_acc,
    feature_type,
    feature_name,
    feature_start,
    feature_stop,
    direction,
    map_id,
    is_landmark,
    map_acc,
    map_name,
    map_start,
    map_stop,
    map_set_id,
    map_set_acc,
    map_set_name,
    map_set_short_name,
    is_relational_map,
    map_type_acc,
    map_type,
    map_units,
    species_id,
    species_acc
    species_common_name,
    feature_type,
    default_rank,
    aliases - a list of aliases (Unless $aliases_get_rows 
                or $ignore_aliases are specified),


=item * Cache Level (If Used): 3

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object       => 0,
        no_validation     => 0,
        feature_id        => 0,
        feature_acc       => 0,
        feature_name      => 0,
        map_id            => 0,
        map_acc           => 0,
        map_set_id        => 0,
        map_set_ids       => 0,
        feature_start     => 0,
        feature_stop      => 0,
        direction         => 0,
        map_start         => 0,
        map_stop          => 0,
        feature_type_accs => 0,
        species_id        => 0,
        species_ids       => 0,
        species_accs      => 0,
        aliases_get_rows  => 0,
        ignore_aliases    => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $feature_id        = $args{'feature_id'};
    my $feature_acc       = $args{'feature_acc'};
    my $feature_name      = $args{'feature_name'};
    my $map_id            = $args{'map_id'};
    my $map_acc           = $args{'map_acc'};
    my $map_set_id        = $args{'map_set_id'};
    my $map_set_ids       = $args{'map_set_ids'} || [];
    my $feature_start     = $args{'feature_start'};
    my $feature_stop      = $args{'feature_stop'};
    my $direction         = $args{'direction'};
    my $map_start         = $args{'map_start'};
    my $map_stop          = $args{'map_stop'};
    my $feature_type_accs = $args{'feature_type_accs'} || [];
    my $species_id        = $args{'species_id'};
    my $species_ids       = $args{'species_ids'} || [];
    my $species_accs      = $args{'species_accs'} || [];
    my $aliases_get_rows  = $args{'aliases_get_rows'} || 0;
    my $ignore_aliases    = $args{'ignore_aliases'} || 0;

    $aliases_get_rows = 0 if ( $feature_name and $feature_name eq '%' );

    my $db                = $self->db;
    my $feature_type_data = $self->feature_type_data();
    my $map_type_data     = $self->map_type_data();
    my $return_object;
    my %alias_lookup;

    my @identifiers = ();    #holds the value of the feature_id or map_id, etc
    my $select_sql  = qq[
        select  f.feature_id,
                f.feature_acc,
                f.feature_type_acc,
                f.feature_name,
                f.feature_start,
                f.feature_stop,
                f.direction,
                f.map_id,
                f.is_landmark,
                map.map_acc,
                map.map_name,
                map.map_start as map_start,
                map.map_stop as map_stop,
                ms.map_set_id,
                ms.map_set_acc,
                ms.map_set_name,
                ms.map_set_short_name,
                ms.is_relational_map,
                ms.map_type_acc,
                ms.map_units,
                s.species_id,
                s.species_acc,
                s.species_common_name
    ];
    my $from_sql = qq[
        from    cmap_feature f,
                cmap_map map,
                cmap_map_set ms,
                cmap_species s
    ];
    my $where_sql = qq[
        where   f.map_id=map.map_id
        and     map.map_set_id=ms.map_set_id
        and     ms.species_id=s.species_id
    ];

    if ( $feature_type_accs and @$feature_type_accs ) {
        $where_sql
            .= " and f.feature_type_acc in ("
            . join( ",", map { $db->quote($_) } sort @$feature_type_accs )
            . ")";
    }

    if ( defined($feature_start) ) {
        push @identifiers, $feature_start;
        $where_sql .= " and f.feature_start = ? ";
    }
    if ( defined($feature_stop) ) {
        push @identifiers, $feature_stop;
        $where_sql .= " and f.feature_stop = ? ";

    }
    if ( defined($direction) ) {
        push @identifiers, $direction;
        $where_sql .= " and f.direction = ? ";
    }
    if ($species_id) {
        push @identifiers, $species_id;
        $where_sql .= " and s.species_id = ? ";

    }
    elsif ( $species_ids and @$species_ids ) {
        $where_sql .= " and s.species_id in ("
            . join( ",", map { $db->quote($_) } sort @$species_ids ) . ")";
    }
    elsif ( $species_accs and @$species_accs ) {
        $where_sql .= " and s.species_acc in ("
            . join( ",", map { $db->quote($_) } sort @$species_accs ) . ")";
    }

    # add the were clause for each possible identifier
    if ($feature_id) {
        push @identifiers, $feature_id;
        $where_sql .= " and f.feature_id = ? ";
    }
    elsif ($feature_acc) {
        my $comparison = $feature_acc =~ m/%/ ? 'like' : '=';
        if ( $feature_acc ne '%' ) {
            push @identifiers, $feature_acc;
            $where_sql .= " and f.feature_acc $comparison ? ";
        }
    }
    if ($map_id) {
        push @identifiers, $map_id;
        $where_sql .= " and map.map_id = ? ";
    }
    elsif ($map_acc) {
        push @identifiers, $map_acc;
        $where_sql .= " and map.map_acc = ? ";
    }
    elsif ($map_set_id) {
        push @identifiers, $map_set_id;
        $where_sql .= " and map.map_set_id = ? ";
    }
    elsif (@$map_set_ids) {
        $where_sql .= " and map.map_set_id in ("
            . join( ",", map { $db->quote($_) } sort @$map_set_ids ) . ")";
    }

    # I'm defining the alias sql so late so they can have a true copy
    # of the main sql.
    my $alias_from_sql = $from_sql . qq[,
                cmap_feature_alias fa
    ];
    my $alias_where_sql = $where_sql . qq[
        and     fa.feature_id=f.feature_id
    ];
    if ($feature_name) {
        my $comparison = $feature_name =~ m/%/ ? 'like' : '=';
        if ( $feature_name ne '%' ) {
            push @identifiers, uc $feature_name;
            $where_sql       .= " and upper(f.feature_name) $comparison ? ";
            $alias_where_sql .= " and upper(fa.alias) $comparison ? ";
        }
    }

    if ( defined($map_start) and defined($map_stop) ) {
        push @identifiers, ( $map_start, $map_stop, $map_start, $map_start );
        $where_sql .= qq[
            and      (
                ( f.feature_start>=? and f.feature_start<=? )
                or   (
                    f.feature_stop is not null and
                    f.feature_start<=? and
                    f.feature_stop>=?
                )
            )
        ];
    }

    my $sql_str = $select_sql . $from_sql . $where_sql;

    if ($aliases_get_rows) {
        $sql_str
            .= " UNION " . $select_sql . $alias_from_sql . $alias_where_sql;
        push @identifiers, @identifiers;
    }

    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} },
        @identifiers );

    if ( !$aliases_get_rows and !$ignore_aliases and @{$return_object} ) {
        my @feature_ids = map { $_->{'feature_id'} } @$return_object;
        my $aliases
            = $self->get_feature_aliases( feature_ids => \@feature_ids, );
        for my $alias (@$aliases) {
            push @{ $alias_lookup{ $alias->{'feature_id'} } },
                $alias->{'alias'};
        }

    }

    foreach my $row ( @{$return_object} ) {
        $row->{'feature_type'}
            = $feature_type_data->{ $row->{'feature_type_acc'} }
            {'feature_type'};
        $row->{'map_type'}
            = $map_type_data->{ $row->{'map_type_acc'} }{'map_type'};
        $row->{'default_rank'}
            = $feature_type_data->{ $row->{'feature_type_acc'} }
            {'default_rank'};

        #add Aliases
        if ( !$ignore_aliases ) {
            $row->{'aliases'} = $alias_lookup{ $row->{'feature_id'} } || [];
        }
    }
    return $return_object;
}

#-----------------------------------------------
sub get_features_simple {

=pod

=head2 get_features_simple()

=over 4

=item * Description

Get just the info from the features.  This is less data than
get_features() provides and doesn't involve any table joins.

=item * Required Input

=over 4

=back

=item * Optional Input

=over 4

=item - Map ID (map_id)

=item - Feature ID (feature_id)

=item - Feature Accession (feature_acc)

=item - Minimum Feature ID (min_feature_id)

=item - Maximum Feature ID (max_feature_id)

=item - Feature Name (feature_name)

=item - Feature Type Accession (feature_type_acc)

=item - List of Feature Type Accessions (feature_type_accs)

=item - List of Feature Type Accession to ignore (ignore_feature_type_accs)

=back

=item * Output

Array of Hashes:

  Keys:
    feature_id
    feature_acc
    map_id
    min_feature_id
    max_feature_id
    feature_name
    is_landmark
    feature_start
    feature_stop
    feature_type_acc
    default_rank
    direction

=item * Cache Level (If Used): 3

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object              => 0,
        no_validation            => 0,
        map_id                   => 0,
        feature_id               => 0,
        min_feature_id           => 0,
        max_feature_id           => 0,
        feature_acc              => 0,
        feature_name             => 0,
        feature_type_acc         => 0,
        feature_type_accs        => 0,
        ignore_feature_type_accs => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $map_id                   = $args{'map_id'};
    my $feature_id               = $args{'feature_id'};
    my $feature_acc              = $args{'feature_acc'};
    my $min_feature_id           = $args{'min_feature_id'};
    my $max_feature_id           = $args{'max_feature_id'};
    my $feature_name             = $args{'feature_name'};
    my $feature_type_acc         = $args{'feature_type_acc'};
    my $feature_type_accs        = $args{'feature_type_accs'} || [];
    my $ignore_feature_type_accs = $args{'ignore_feature_type_accs'} || [];
    my $db                       = $self->db;
    my $return_object;
    my $sql_str = qq[
         select feature_id,
               feature_acc,
               feature_name,
               map_id,
               is_landmark,
               feature_start,
               feature_stop,
               feature_type_acc,
               default_rank,
               direction
        from   cmap_feature
    ];
    my $where_sql = '';

    if ($feature_id) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " feature_id = " . $db->quote($feature_id) . " ";
    }
    elsif ($feature_acc) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " feature_acc = " . $db->quote($feature_acc) . " ";
    }
    if ($min_feature_id) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " feature_id >= " . $db->quote($min_feature_id) . " ";
    }
    if ($max_feature_id) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " feature_id <= " . $db->quote($max_feature_id) . " ";
    }
    if ($map_id) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " map_id = " . $db->quote($map_id) . " ";
    }
    if ($feature_name) {
        my $comparison = $feature_name =~ m/%/ ? 'like' : '=';
        if ( $feature_name ne '%' ) {
            $feature_name = uc $feature_name;
            $where_sql .= $where_sql ? " and " : " where ";
            $where_sql .= " upper(feature_name) $comparison "
                . $db->quote($feature_name) . " ";
        }
    }
    if ($feature_type_acc) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql
            .= " feature_type_acc = " . $db->quote($feature_type_acc) . " ";
    }
    elsif (@$feature_type_accs) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql
            .= " feature_type_acc in ("
            . join( ",", map { $db->quote($_) } sort @$feature_type_accs )
            . ") ";
    }
    if (@$ignore_feature_type_accs) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " feature_type_acc not in ("
            . join( ",",
            map { $db->quote($_) } sort @$ignore_feature_type_accs )
            . ") ";
    }

    $sql_str .= $where_sql;
    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} } );

    return $return_object;
}

#-----------------------------------------------
sub get_features_sub_maps_version {

=pod

=head2 get_features_sub_maps_version()

=over 4

=item * Description

Get just the info from the features taking into account sub-map information.

=item * Required Input

=over 4

=back

=item * Optional Input

=over 4

=item - Map ID (map_id)

=item - Feature Type Accession (feature_type_acc)

=item - List of Feature Type Accession to ignore (ignore_feature_type_accs)

=item - Return only sub maps (get_sub_maps)

=item - Return only features that are not sub maps (no_sub_maps)

=back

=item * Output

Array of Hashes:

  Keys:
    feature_id
    feature_acc
    feature_name
    is_landmark
    feature_start
    feature_stop
    feature_type_acc
    default_rank
    direction

=item * Cache Level (If Used): 3

Using Cache

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object              => 0,
        no_validation            => 0,
        map_id                   => 1,
        feature_type_acc         => 0,
        ignore_feature_type_accs => 0,
        get_sub_maps             => 0,
        no_sub_maps              => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $map_id                   = $args{'map_id'};
    my $feature_type_acc         = $args{'feature_type_acc'};
    my $ignore_feature_type_accs = $args{'ignore_feature_type_accs'} || [];
    my $get_sub_maps             = $args{'get_sub_maps'} || 0;
    my $no_sub_maps              = $args{'no_sub_maps'} || 0;
    my $db                       = $self->db;
    my $return_object;
    my $select_str = qq[
         select f.feature_id,
               f.feature_acc,
               f.feature_name,
               f.is_landmark,
               f.feature_start,
               f.feature_stop,
               f.feature_type_acc,
               f.default_rank,
               f.direction,
               map.map_set_id           
    ];
    my $from_str .= qq[
        from   cmap_map map, 
               cmap_feature f
    ];

    if ( $get_sub_maps or $no_sub_maps ) {
        $select_str .= q[, mtf.map_id as sub_map_id ];
        $from_str   .= q[ 
            LEFT JOIN cmap_map_to_feature mtf 
            on mtf.feature_id = f.feature_id
        ];
    }
    my $where_sql = ' where f.map_id = map.map_id ';

    if ($map_id) {
        $where_sql .= "and map.map_id = " . $db->quote($map_id) . " ";
    }
    if ($get_sub_maps) {
        $where_sql .= "and !isNull(mtf.map_id) ";
    }
    if ($no_sub_maps) {

        #$where_sql .= "and isNull(mtf.map_id) ";
    }
    if ($feature_type_acc) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql
            .= " f.feature_type_acc = " . $db->quote($feature_type_acc) . " ";
    }
    if (@$ignore_feature_type_accs) {
        $where_sql .= " and f.feature_type_acc not in ("
            . join( ",",
            map { $db->quote($_) } sort @$ignore_feature_type_accs )
            . ") ";
    }

    my $sql_str
        = $select_str
        . $from_str
        . $where_sql
        . " order by map_set_id, feature_start, feature_stop";

    unless ( $return_object = $self->get_cached_results( 3, $sql_str ) ) {
        $return_object
            = $db->selectall_arrayref( $sql_str, { Columns => {} } );
        return {} unless $return_object;

        $self->store_cached_results( 3, $sql_str, $return_object );
    }

    return $return_object;
}

#-----------------------------------------------
sub get_feature_bounds_on_map {

=pod

=head2 get_feature_bounds_on_map()

=over 4

=item * Description

Given a map id, give the bounds of where features lie.

=item * Required Input

=over 4

=item - Map ID (map_id)

=back

=item * Output

list ( $min_start, $max_start, $max_stop )

=item * Cache Level (If Used): 3

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        map_id        => 1,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $map_id = $args{'map_id'};
    my $db     = $self->db;

    my ( $min_start, $max_start, $max_stop ) = $db->selectrow_array(
        q[
            select   min(f.feature_start),
                     max(f.feature_start),
                     max(f.feature_stop)
            from     cmap_feature f
            where    f.map_id=?
            group by f.map_id
        ],
        {},
        ($map_id)
    );

    return ( $min_start, $max_start, $max_stop );
}

#-----------------------------------------------
sub get_features_for_correspondence_making {

=pod

=head2 get_features_for_correspondence_making()

=over 4

=item * Description

Get feature information for creating correspondences.

=item * Required Input

=over 4

=back

=item * Optional Input

=over 4

=item - List of Map Set IDs (map_set_ids)

=item - ignore_feature_type_accs (ignore_feature_type_accs)

=back

=item * Output

Array of Hashes:

  Keys:
    feature_id
    feature_name
    feature_type_acc

=item * Cache Level (If Used): 3

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object              => 0,
        no_validation            => 0,
        map_set_ids              => 0,
        ignore_feature_type_accs => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $map_set_ids              = $args{'map_set_ids'}              || [];
    my $ignore_feature_type_accs = $args{'ignore_feature_type_accs'} || [];
    my $db                       = $self->db;
    my $return_object;

    my $sql_str = q[
        select f.feature_id,
               f.feature_name,
               f.feature_type_acc
        from   cmap_feature f,
               cmap_map map
        where  f.map_id=map.map_id
    ];

    if (@$map_set_ids) {
        $sql_str .= " and map.map_set_id in ("
            . join( ",", map { $db->quote($_) } sort @$map_set_ids ) . ") ";
    }
    if (@$ignore_feature_type_accs) {
        $sql_str .= " and f.feature_type_acc not in ("
            . join( ",",
            map { $db->quote($_) } sort @$ignore_feature_type_accs )
            . ") ";
    }

    $return_object = $db->selectall_hashref( $sql_str, 'feature_id' );

    return $return_object;
}

#-----------------------------------------------
sub slot_data_features {

=pod

=head2 slot_data_features()

=over 4

=item * Description

This is a method specifically for Data->slot_data() to call, since it will be called multiple times in most map views.  It does only what Data->slot_data() needs it to do and nothing more. 

It takes into account the corr_only_feature_types, returning only those types with displayed correspondences. 

The way it works, is that it creates one sql query for those types that will always be displayed ($included_feature_type_accs) and a separate query for those types that need a correpsondence in order to be displayed ($corr_only_feature_type_accs).  Then it unions them together.

=item * Required Input

=over 4

=item - The "slot_info" object (slot_info)

 Structure:
    { 
      slot_no => {
        map_id => [ current_start, current_stop, ori_start, ori_stop, magnification ],
      }
    }

=item - Slot number (this_slot_no)

=back

=item * Optional Input

=over 4

=item - Map ID (map_id)

=item - Map Start (map_start)

=item - Map Stop (map_stop)

=item - Included Feature Type Accessions (included_feature_type_accs)

List of feature type accs that will be displayed even if they don't have
correspondences.

=item - Ignored Feature Type Accessions (ignored_feature_type_accs)

List of feature type accs that will not be displayed.

=item - Correspondence Only Feature Type Accessions (corr_only_feature_type_accs)

List of feature type accs that will be displayed ONLY if they have
correspondences.

=item - show_intraslot_corr (show_intraslot_corr)

Boolean value to check if intraslot correspondences count when deciding to
display a corr_only feature.

=back

=item * Output

Array of Hashes:

  Keys:
    feature_id,
    feature_acc,
    feature_name,
    is_landmark,
    feature_start,
    feature_stop,
    feature_type_acc,
    direction,
    map_id,
    map_acc,
    map_name,
    map_units,
    feature_type,
    default_rank,
    shape,
    color,
    drawing_lane,
    drawing_priority,

=item * Cache Level: 4

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object                 => 0,
        no_validation               => 0,
        slot_info                   => 1,
        this_slot_no                => 1,
        map_id                      => 0,
        map_start                   => 0,
        map_stop                    => 0,
        included_feature_type_accs  => 0,
        ignored_feature_type_accs   => 0,
        corr_only_feature_type_accs => 0,
        show_intraslot_corr         => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $slot_info    = $args{'slot_info'} or die "no slot info supplied.";
    my $map_id       = $args{'map_id'};
    my $map_start    = $args{'map_start'};
    my $map_stop     = $args{'map_stop'};
    my $this_slot_no = $args{'this_slot_no'};
    my $included_feature_type_accs = $args{'included_feature_type_accs'}
        || [];
    my $ignored_feature_type_accs = $args{'ignored_feature_type_accs'} || [];
    my $corr_only_feature_type_accs = $args{'corr_only_feature_type_accs'}
        || [];
    my $show_intraslot_corr = $args{'show_intraslot_corr'};

    my $db                = $self->db;
    my $feature_type_data = $self->feature_type_data();
    my $return_object;
    my $sql_str;

    my $select_sql = q[
        select   distinct  
                 f.feature_id,
                 f.feature_acc,
                 f.map_id,
                 f.feature_name,
                 f.is_landmark,
                 f.feature_start,
                 f.feature_stop,
                 f.feature_type_acc,
                 f.direction,
                 map.map_acc,
                 map.map_name,
                 ms.map_units
    ];
    my $from_sql = q[
        from     cmap_feature f,
                 cmap_map map,
                 cmap_map_set ms
    ];
    my $where_sql = q[
        where    f.map_id=] . $db->quote($map_id) . q[
        and      f.map_id=map.map_id
        and      map.map_set_id=ms.map_set_id
    ];

    # Handle Map Start and Stop
    if (my $start_stop_sql = $self->write_start_stop_sql(
            map_start    => $map_start,
            map_stop     => $map_stop,
            start_column => 'f.feature_start',
            stop_column  => 'f.feature_stop',
        )
        )
    {
        $where_sql .= " and $start_stop_sql ";
    }

    # Create the query that doesn't get any of the correspondence
    # only features.
    my $corr_free_sql = $select_sql . $from_sql . $where_sql;
    if (   @$corr_only_feature_type_accs
        or @$ignored_feature_type_accs )
    {
        if (@$included_feature_type_accs) {
            $corr_free_sql .= " and f.feature_type_acc in ("
                . join( ",",
                map { $db->quote($_) } sort @$included_feature_type_accs )
                . ")";
        }
        else {    #return nothing
            $corr_free_sql .= " and f.feature_type_acc = -1 ";
        }
    }

    # Create the query that gets the corr only features.
    my $with_corr_sql = '';
    if ((@$corr_only_feature_type_accs)
        and (  $show_intraslot_corr
            || $slot_info->{ $this_slot_no + 1 }
            || $slot_info->{ $this_slot_no - 1 } )
        )
    {
        $with_corr_sql = $select_sql . $from_sql . q[,
                  cmap_correspondence_lookup cl
                  ] . $where_sql . q[
                  and cl.feature_id1=f.feature_id
                  and cl.map_id1!=cl.map_id2
                ];
        if (   @$included_feature_type_accs
            or @$ignored_feature_type_accs )
        {
            $with_corr_sql .= " and f.feature_type_acc in ("
                . join( ",",
                map { $db->quote($_) } sort @$corr_only_feature_type_accs )
                . ") ";
        }
        $with_corr_sql .= $self->write_start_stop_sql_from_slot_info(
            slot_info_obj => {
                $slot_info->{ $this_slot_no + 1 }
                ? %{ $slot_info->{ $this_slot_no + 1 } }
                : (),
                $slot_info->{ $this_slot_no - 1 }
                ? %{ $slot_info->{ $this_slot_no - 1 } }
                : (),
                ( $show_intraslot_corr && $slot_info->{$this_slot_no} )
                ? %{ $slot_info->{$this_slot_no} }
                : (),
            },
            map_id_column => 'cl.map_id2',
            start_column  => 'cl.feature_start2',
            stop_column   => 'cl.feature_stop2',
        );
    }

    #
    # Decide what sql will be used
    #
    if ( @$corr_only_feature_type_accs and @$included_feature_type_accs ) {
        $sql_str = $corr_free_sql;

        # If $with_corr_sql is blank, that likely means that there
        # are no slots to have corrs with.
        $sql_str .= " UNION " . $with_corr_sql if ($with_corr_sql);
    }
    elsif (@$corr_only_feature_type_accs) {
        if ($with_corr_sql) {
            $sql_str = $with_corr_sql;
        }
        else {
            ###Return nothing because there are no maps to correspond with
            return [];
        }
    }
    elsif (@$included_feature_type_accs) {
        $sql_str = $corr_free_sql;
    }
    else {
        ###Return nothing because all features are ignored
        return [];
    }

    # Add order to help sorting later
    $sql_str .= " order by feature_start, feature_stop";

    unless ( $return_object = $self->get_cached_results( 4, $sql_str ) ) {

        $return_object
            = $db->selectall_arrayref( $sql_str, { Columns => {} } );
        return {} unless $return_object;

        foreach my $row ( @{$return_object} ) {
            my $feature_type_acc = $row->{'feature_type_acc'};
            $row->{$_} = $feature_type_data->{$feature_type_acc}{$_} for qw[
                feature_type default_rank shape color
                drawing_lane drawing_priority width
            ];
            if ( $feature_type_data->{$feature_type_acc}{'get_attributes'} ) {
                $row->{'attributes'} = $self->get_attributes(
                    object_type => 'feature',
                    object_id   => $row->{'feature_id'},
                );
            }
            if ( $feature_type_data->{$feature_type_acc}{'get_xrefs'} ) {
                $row->{'xrefs'} = $self->get_xrefs(
                    object_type => 'feature',
                    object_id   => $row->{'feature_id'},
                );
            }
        }

        $self->store_cached_results( 4, $sql_str, $return_object );
    }

    return $return_object;
}

#-----------------------------------------------
sub get_feature_count {

=pod

=head2 get_feature_count()

=over 4

=item * Description

=item * Adaptor Writing Info

=item * Required Input

=over 4

=back

=item * Optional Input

=over 4

=item - group_by_map_id (group_by_map_id)

=item - group_by_feature_type (group_by_feature_type)

=item - The "slot_info" object (this_slot_info)

 Structure:
    { 
      slot_no => {
        map_id => [ current_start, current_stop, ori_start, ori_stop, magnification ],
      }
    }

=item - List of Map IDs (map_ids)

=item - Map ID (map_id)

=item - Map Name (map_name)

=item - Map Set ID (map_set_id)

=back

=item * Output

Array of Hashes:

  Keys:
    feature_count
    map_id (only if $group_by_map_id)
    feature_type_acc (only if $group_by_feature_type)

=item * Cache Level (If Used): 

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object           => 0,
        no_validation         => 0,
        group_by_map_id       => 0,
        group_by_feature_type => 0,
        this_slot_info        => 0,
        map_ids               => 0,
        map_id                => 0,
        map_name              => 0,
        map_set_id            => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $group_by_map_id       = $args{'group_by_map_id'};
    my $group_by_feature_type = $args{'group_by_feature_type'};
    my $this_slot_info        = $args{'this_slot_info'};
    my $map_ids               = $args{'map_ids'} || [];
    my $map_id                = $args{'map_id'};
    my $map_name              = $args{'map_name'};
    my $map_set_id            = $args{'map_set_id'};
    my $db                    = $self->db;
    my $return_object;

    my $select_sql        = " select  count(f.feature_id) as feature_count ";
    my $from_sql          = " from cmap_feature f ";
    my $where_sql         = '';
    my $group_by_sql      = '';
    my $added_map_to_from = 0;

    if ($group_by_map_id) {
        $select_sql   .= ", f.map_id ";
        $group_by_sql .= $group_by_sql ? "," : " group by ";
        $group_by_sql .= " f.map_id ";
    }
    if ($group_by_feature_type) {
        $select_sql   .= ", f.feature_type_acc ";
        $group_by_sql .= $group_by_sql ? "," : " group by ";
        $group_by_sql .= " f.feature_type_acc ";
    }

    if ($map_id) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " f.map_id = " . $db->quote($map_id) . " ";
    }
    elsif (@$map_ids) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " f.map_id in ("
            . join( ",", map { $db->quote($_) } sort @$map_ids ) . ")";
    }
    elsif ($this_slot_info) {

        # Use start and stop info on maps if this_slot_info is given
        my @unrestricted_map_ids = ();
        my $unrestricted_sql     = '';
        my $restricted_sql       = '';
        foreach my $slot_map_id ( sort keys( %{$this_slot_info} ) ) {

            # $this_slot_info->{$slot_map_id}->[0] is start [1] is stop
            if (    defined( $this_slot_info->{$slot_map_id}->[0] )
                and defined( $this_slot_info->{$slot_map_id}->[1] ) )
            {
                $restricted_sql
                    .= " or (f.map_id="
                    . $db->quote($slot_map_id)
                    . " and (( f.feature_start>="
                    . $db->quote( $this_slot_info->{$slot_map_id}->[0] )
                    . " and f.feature_start<="
                    . $db->quote( $this_slot_info->{$slot_map_id}->[1] )
                    . " ) or ( f.feature_stop is not null and "
                    . "  f.feature_start<="
                    . $db->quote( $this_slot_info->{$slot_map_id}->[0] )
                    . " and f.feature_stop>="
                    . $db->quote( $this_slot_info->{$slot_map_id}->[0] )
                    . " )))";
            }
            elsif ( defined( $this_slot_info->{$slot_map_id}->[0] ) ) {
                $restricted_sql
                    .= " or (f.map_id="
                    . $db->quote($slot_map_id)
                    . " and (( f.feature_start>="
                    . $db->quote( $this_slot_info->{$slot_map_id}->[0] )
                    . " ) or ( f.feature_stop is not null "
                    . " and f.feature_stop>="
                    . $db->quote( $this_slot_info->{$slot_map_id}->[0] )
                    . " )))";
            }
            elsif ( defined( $this_slot_info->{$slot_map_id}->[1] ) ) {
                $restricted_sql
                    .= " or (f.map_id="
                    . $db->quote($slot_map_id)
                    . " and f.feature_start<="
                    . $db->quote( $this_slot_info->{$slot_map_id}->[1] )
                    . ") ";
            }
            else {
                push @unrestricted_map_ids, $slot_map_id;
            }
        }
        if (@unrestricted_map_ids) {
            $unrestricted_sql
                = " or f.map_id in ("
                . join( ",",
                map { $db->quote($_) } sort @unrestricted_map_ids )
                . ") ";
        }

        my $combined_sql = $restricted_sql . $unrestricted_sql;
        $combined_sql =~ s/^\s+or//;
        unless ($combined_sql) {
            return [];
        }
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " (" . $combined_sql . ")";
    }
    elsif ($map_set_id) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= q[
            map.map_set_id = ] . $db->quote($map_set_id) . '';
        unless ($added_map_to_from) {
            $from_sql  .= ", cmap_map map ";
            $where_sql .= qq[
                and map.map_id=f.map_id
            ];
            $added_map_to_from = 1;
        }
    }

    if ($map_name) {
        $map_name =~ s/\*/%/g;
        my $comparison = $map_name =~ m/%/ ? 'like' : '=';
        if ( $map_name ne '%' ) {
            $where_sql .= $where_sql ? " and " : " where ";
            $where_sql
                .= " map.map_name $comparison " . $db->quote($map_name) . " ";
            unless ($added_map_to_from) {
                $from_sql  .= ", cmap_map map ";
                $where_sql .= qq[
                    and map.map_id=f.map_id
                ];
                $added_map_to_from = 1;
            }
        }
    }

    my $sql_str = $select_sql . $from_sql . $where_sql . $group_by_sql;

    unless ( $return_object = $self->get_cached_results( 3, $sql_str ) ) {
        $return_object
            = $db->selectall_arrayref( $sql_str, { Columns => {} } );

        if ($group_by_feature_type) {
            my $feature_type_data = $self->feature_type_data();
            foreach my $row ( @{$return_object} ) {
                $row->{'feature_type'}
                    = $feature_type_data->{ $row->{'feature_type_acc'} }
                    {'feature_type'};
            }
        }

        $self->store_cached_results( 3, $sql_str, $return_object );
    }

    return $return_object;
}

#-----------------------------------------------
sub insert_feature {

=pod

=head2 insert_feature()

=over 4

Insert a feature into the database.

=item * Description

=item * Adaptor Writing Info

The required inputs are only the ones that the database requires.

If you don't want CMap to insert into your database, make this a dummy method.

=item * Input

=over 4

=item - Feature Accession (feature_acc)

=item - Map ID (map_id)

=item - Feature Type Accession (feature_type_acc)

=item - Feature Name (feature_name)

=item - is_landmark (is_landmark)

=item - feature_start (feature_start)

=item - feature_stop (feature_stop)

=item - default_rank (default_rank)

=item - Direction (direction)

=item - gclass (gclass)

=item - threshold (threshold)

=item - report feature index (report_feature_index)

When using the threshold, the feature ids are not reported.  Set
report_feature_index to 1 to recieve the index of the feature.  When the
features are actually inserted, this method will return an array of feature
ids.  Use the previously recieved index to find out what feature id was
created. 

Requiring this flag to use this feature is to keep from breaking old code.

=back

=item * Output

Feature id

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object            => 0,
        no_validation          => 0,
        feature_acc            => 0,
        accession_id           => 0,
        map_id                 => 0,
        feature_type_acc       => 0,
        feature_type_aid       => 0,
        feature_type_accession => 0,
        feature_name           => 0,
        is_landmark            => 0,
        feature_start          => 0,
        feature_stop           => 0,
        start_position         => 0,
        stop_position          => 0,
        default_rank           => 0,
        direction              => 0,
        gclass                 => 0,
        threshold              => 0,
        report_feature_index   => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $feature_acc      = $args{'feature_acc'} || $args{'accession_id'};
    my $map_id           = $args{'map_id'};
    my $feature_type_acc = $args{'feature_type_acc'}
        || $args{'feature_type_aid'}
        || $args{'feature_type_accession'};
    my $feature_name  = $args{'feature_name'}  || q{};
    my $is_landmark   = $args{'is_landmark'}   || 0;
    my $feature_start = $args{'feature_start'} || 0;
    my $feature_stop  = $args{'feature_stop'};

    # Backwards compatibility
    $feature_start = $args{'start_position'} unless defined($feature_start);
    $feature_stop  = $args{'stop_position'}  unless defined($feature_stop);
    $feature_stop  = $feature_start          unless defined($feature_stop);

    my $default_rank         = $args{'default_rank'}         || 1;
    my $direction            = $args{'direction'}            || 1;
    my $gclass               = $args{'gclass'};
    my $threshold            = $args{'threshold'}            || 0;
    my $report_feature_index = $args{'report_feature_index'} || 0;
    my $db                   = $self->db;

    $gclass = undef
        unless ( $self->config_data('gbrowse_compatible') );

    my $real_number_regex = $self->{'real_number_regex'};
    $feature_stop = $feature_start
        unless ( defined($feature_stop) );

    if (    defined($feature_stop)
        and defined($feature_start)
        and $feature_stop < $feature_start )
    {
        $direction = $direction * -1;
        ( $feature_stop, $feature_start ) = ( $feature_start, $feature_stop );
    }

    my $insertion_index = undef;
    if ($feature_type_acc) {
        my @insert_array = (
            $feature_acc,  $map_id,       $feature_type_acc,
            $feature_name, $is_landmark,  $feature_start,
            $feature_stop, $default_rank, $direction
        );
        push @insert_array, $gclass if ($gclass);
        push @{ $self->{'insert_features'} }, \@insert_array;
        $insertion_index = $#{ $self->{'insert_features'} };
    }

    if (    scalar( @{ $self->{'insert_features'} || [] } )
        and scalar( @{ $self->{'insert_features'} } ) >= $threshold )
    {
        my $no_features     = scalar( @{ $self->{'insert_features'} } );
        my $base_feature_id = $self->next_number(
            object_type => 'feature',
            requested   => scalar( @{ $self->{'insert_features'} } )
        ) or return $self->error('No next number for feature ');
        my $sth;
        if ($gclass) {
            $sth = $db->prepare(
                qq[
                    insert into cmap_feature
                    (
                        feature_id,
                        feature_acc,
                        map_id,
                        feature_type_acc,
                        feature_name,
                        is_landmark,
                        feature_start,
                        feature_stop,
                        default_rank,
                        direction,
                        gclass
                     )
                     values ( ?,?,?,?,?,?,?,?,?,?,? )
                    ]
            );
        }
        else {
            $sth = $db->prepare(
                qq[
                    insert into cmap_feature
                    (
                        feature_id,
                        feature_acc,
                        map_id,
                        feature_type_acc,
                        feature_name,
                        is_landmark,
                        feature_start,
                        feature_stop,
                        default_rank,
                        direction 
                     )
                     values ( ?,?,?,?,?,?,?,?,?,? )
                    ]
            );
        }
        my @feature_id_array;
        my $feature_id;
        for ( my $i = 0; $i < $no_features; $i++ ) {
            $feature_id = $base_feature_id + $i;
            $self->{'insert_features'}[$i][0] ||= $feature_id;
            $sth->execute( $feature_id, @{ $self->{'insert_features'}[$i] } );
            push @feature_id_array, $feature_id;
        }
        $self->{'insert_features'} = [];
        return $report_feature_index
            ? ( $insertion_index, \@feature_id_array )
            : $feature_id;
    }
    return $report_feature_index ? ( $insertion_index, undef ) : undef;
}

#-----------------------------------------------
sub update_feature {

=pod

=head2 update_feature()

=over 4

=item * Description

Given the id and some attributes to modify, updates.

=item * Adaptor Writing Info

If you don't want CMap to update into your database, make this a dummy method.

=item * Required Input

=over 4

=item - Feature ID (feature_id)

=back

=item * Inputs To Update

=over 4

=item - Feature Accession (feature_acc)

=item - Map ID (map_id)

=item - Feature Type Accession (feature_type_acc)

=item - Feature Name (feature_name)

=item - is_landmark (is_landmark)

=item - feature_start (feature_start)

=item - feature_stop (feature_stop)

=item - default_rank (default_rank)

=item - Direction (direction)

=back

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object            => 0,
        no_validation          => 0,
        feature_id             => 0,
        object_id              => 0,
        feature_acc            => 0,
        accession_id           => 0,
        map_id                 => 0,
        feature_type_acc       => 0,
        feature_type_aid       => 0,
        feature_type_accession => 0,
        feature_name           => 0,
        is_landmark            => 0,
        feature_start          => 0,
        feature_stop           => 0,
        start_position         => 0,
        stop_position          => 0,
        default_rank           => 0,
        direction              => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $feature_id  = $args{'feature_id'}  || $args{'object_id'} or return;
    my $feature_acc = $args{'feature_acc'} || $args{'accession_id'};
    my $map_id      = $args{'map_id'};
    my $feature_type_acc = $args{'feature_type_acc'}
        || $args{'feature_type_aid'}
        || $args{'feature_type_accession'};
    my $feature_name  = $args{'feature_name'};
    my $is_landmark   = $args{'is_landmark'};
    my $feature_start = $args{'feature_start'};
    my $feature_stop  = $args{'feature_stop'};

    # Backwards compatibility
    $feature_start = $args{'start_position'} unless defined($feature_start);
    $feature_stop  = $args{'stop_position'}  unless defined($feature_stop);
    my $default_rank = $args{'default_rank'};
    my $direction    = $args{'direction'};
    my $db           = $self->db;

    my $real_number_regex = $self->{'real_number_regex'};
    $feature_stop = $feature_start
        unless ( defined($feature_stop) );

    if (    defined($feature_stop)
        and defined($feature_start)
        and $feature_stop < $feature_start )
    {
        $direction = $direction * -1;
        ( $feature_stop, $feature_start ) = ( $feature_start, $feature_stop );
    }

    my @update_args = ();
    my $update_sql  = qq[
        update cmap_feature
    ];
    my $set_sql   = '';
    my $where_sql = " where feature_id = ? ";    # ID

    if ($feature_acc) {
        push @update_args, $feature_acc;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " feature_acc = ? ";
    }
    if ($map_id) {
        push @update_args, $map_id;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " map_id = ? ";
    }
    if ($feature_type_acc) {
        push @update_args, $feature_type_acc;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " feature_type_acc = ? ";
    }
    if ($feature_name) {
        push @update_args, $feature_name;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " feature_name = ? ";
    }
    if ( defined($is_landmark) ) {
        push @update_args, $is_landmark;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " is_landmark = ? ";
    }
    if ( defined($feature_start) ) {
        push @update_args, $feature_start;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " feature_start = ? ";
    }
    if ( defined($feature_stop) ) {
        push @update_args, $feature_stop;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " feature_stop = ? ";
    }
    if ( defined($default_rank) ) {
        push @update_args, $default_rank;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " default_rank = ? ";
    }
    if ($direction) {
        push @update_args, $direction;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " direction = ? ";
    }

    push @update_args, $feature_id;

    my $sql_str = $update_sql . $set_sql . $where_sql;
    $db->do( $sql_str, {}, @update_args );

    # Modify the any correspondences that might exist
    foreach my $params (
        [ 'map_id',           $map_id ],
        [ 'feature_type_acc', $feature_type_acc ],
        [ 'feature_start',    $feature_start ],
        [ 'feature_stop',     $feature_stop ],
        )
    {
        my $param_name  = $params->[0];
        my $param_value = $params->[1];
        if ( defined $param_value ) {
            foreach my $number ( 1, 2 ) {
                my $update_str = q[
                    update cmap_correspondence_lookup
                    set ] . $param_name . $number . q[ = ?
                    where feature_id] . $number . q[ = ?  ];
                $db->do( $update_str, {},
                    ( $param_value, $feature_id, $param_value, $feature_id, )
                );
            }
        }
    }
}

#-----------------------------------------------
sub delete_feature {

=pod

=head2 delete_feature()

=over 4

=item * Description

Given the id or a map id, delete the objects.

=item * Adaptor Writing Info

If you don't want CMap to delete from your database, make this a dummy method.

=item * Requred Input

=over 4

=back

=item * Requred At Least One Input

=over 4

=item - Feature ID (feature_id)

=item - Map ID (map_id)

=back

=item * Output

1

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        feature_id    => 0,
        map_id        => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $db          = $self->db;
    my $feature_id  = $args{'feature_id'};
    my $map_id      = $args{'map_id'};
    my @delete_args = ();
    my $delete_sql  = qq[
        delete from cmap_feature
    ];
    my $where_sql = '';

    return unless ( $feature_id or $map_id );

    if ($feature_id) {
        push @delete_args, $feature_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " feature_id = ? ";
    }
    if ($map_id) {
        push @delete_args, $map_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " map_id = ? ";
    }

    $delete_sql .= $where_sql;
    $db->do( $delete_sql, {}, (@delete_args) );

    return 1;
}

=pod

=head1 Feature Alias Methods

=cut 

#-----------------------------------------------
sub get_feature_aliases {

=pod

=head2 get_feature_aliases()

=over 4

=item * Description

Gets aliases for features identified by the identification fields.  One row per
alias.

=item * Adaptor Writing Info

If Map information is part of the input, then the map tables need to be brought into the query.

=item * Required Input

=over 4

=back

=item * Optional Input

=over 4

=item - Feature ID (feature_id)

=item - feature_alias_id (feature_alias_id)

=item - Minimum Feature ID (min_feature_id)

=item - Maximum Feature ID (max_feature_id)

=item - List of Feature IDs (feature_ids)

=item - Feature Accession (feature_acc)

=item - alias (alias)

=item - Map ID (map_id)

=item - map_acc (map_acc)

=item - Map Set ID (map_set_id)

=item - List of Map Set IDs (map_set_ids)

=item - ignore_feature_type_accs (ignore_feature_type_accs)

=back

=item * Output

Array of Hashes:

  Keys:
    feature_alias_id,
    alias,
    feature_id,
    min_feature_id,
    max_feature_id,
    feature_acc,
    feature_name,
    feature_type_acc


=item * Cache Level (Not Used): 3

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object              => 0,
        no_validation            => 0,
        feature_id               => 0,
        min_feature_id           => 0,
        max_feature_id           => 0,
        feature_alias_id         => 0,
        feature_ids              => 0,
        feature_acc              => 0,
        alias                    => 0,
        map_id                   => 0,
        map_acc                  => 0,
        map_set_id               => 0,
        map_set_ids              => 0,
        ignore_feature_type_accs => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $feature_id               = $args{'feature_id'};
    my $feature_alias_id         = $args{'feature_alias_id'};
    my $feature_ids              = $args{'feature_ids'} || [];
    my $feature_acc              = $args{'feature_acc'};
    my $min_feature_id           = $args{'min_feature_id'};
    my $max_feature_id           = $args{'max_feature_id'};
    my $alias                    = $args{'alias'};
    my $map_id                   = $args{'map_id'};
    my $map_acc                  = $args{'map_acc'};
    my $map_set_id               = $args{'map_set_id'};
    my $map_set_ids              = $args{'map_set_ids'} || [];
    my $ignore_feature_type_accs = $args{'ignore_feature_type_accs'} || [];
    my $db                       = $self->db;
    my $return_object;
    my @identifiers = ();

    my $select_sql = qq[
            select  fa.feature_alias_id,
                    fa.alias,
                    f.feature_id,
                    f.feature_acc,
                    f.feature_name,
                    f.feature_type_acc
    ];
    my $from_sql = qq[
            from    cmap_feature_alias fa,
                    cmap_feature f
    ];
    my $where_sql = qq[
            where   fa.feature_id=f.feature_id
    ];
    my $where_extra = '';
    my @feature_ids_sql_list;

    # add the were clause for each possible identifier
    if ($feature_alias_id) {
        push @identifiers, $feature_alias_id;
        $where_extra .= " and fa.feature_alias_id = ? ";
    }
    elsif (@$feature_ids) {
        my $group_size = 1000;
        my $i;
        for (
            $i = 0;
            $i + $group_size < $#{$feature_ids};
            $i += $group_size + 1
            )
        {
            push @feature_ids_sql_list, " and f.feature_id in ("
                . join( ",",
                map { $db->quote($_) }
                    sort @{$feature_ids}[ $i .. ( $group_size + $i ) ] )
                . ") ";
        }
        push @feature_ids_sql_list, " and f.feature_id in ("
            . join( ",",
            map { $db->quote($_) }
                sort @{$feature_ids}[ $i .. $#{$feature_ids} ] )
            . ") ";
    }
    elsif ($feature_id) {
        push @identifiers, $feature_id;
        $where_extra .= " and f.feature_id = ? ";
    }
    elsif ($feature_acc) {
        push @identifiers, $feature_acc;
        $where_extra .= " and f.feature_acc = ? ";
    }
    if ($min_feature_id) {
        push @identifiers, $min_feature_id;
        $where_extra .= " and f.feature_id >= ? ";
    }
    if ($max_feature_id) {
        push @identifiers, $max_feature_id;
        $where_extra .= " and f.feature_id <= ? ";
    }
    if ($alias) {
        my $comparison = $alias =~ m/%/ ? 'like' : '=';
        if ( $alias ne '%' ) {
            push @identifiers, uc $alias;
            $where_extra .= " and upper(fa.alias) $comparison ? ";
        }
    }

    if ($map_id) {
        push @identifiers, $map_id;
        $from_sql    .= ", cmap_map map ";
        $where_extra .= " and map.map_id = f.map_id and map.map_id = ? ";
    }
    elsif ($map_acc) {
        push @identifiers, $map_acc;
        $from_sql    .= ", cmap_map map ";
        $where_extra .= " and map.map_id = f.map_id and map.map_acc = ? ";
    }
    elsif ($map_set_id) {
        push @identifiers, $map_set_id;
        $from_sql    .= ", cmap_map map ";
        $where_extra .= " and map.map_id = f.map_id and map.map_set_id = ? ";
    }
    elsif (@$map_set_ids) {
        $from_sql .= ", cmap_map map ";
        $where_extra
            .= " and map.map_id = f.map_id "
            . " and map.map_set_id in ("
            . join( ",", map { $db->quote($_) } sort @$map_set_ids ) . ") ";
    }
    if (@$ignore_feature_type_accs) {
        $where_extra .= " and f.feature_type_acc not in ("
            . join( ",",
            map { $db->quote($_) } sort @$ignore_feature_type_accs )
            . ") ";
    }
    my $order_by_sql = qq[
            order by alias
    ];

    my $sql_str;

    if (@feature_ids_sql_list) {
        foreach my $f_id_sql (@feature_ids_sql_list) {
            $sql_str
                = $select_sql
                . $from_sql
                . $where_sql
                . $where_extra
                . $f_id_sql
                . $order_by_sql;
            my $tmp_return_object
                = $db->selectall_arrayref( $sql_str, { Columns => {} },
                @identifiers );
            push @$return_object, @$tmp_return_object;
        }
    }
    else {
        die "Alias query too large"
            . "cowardly refusing to run a killer query"
            . Dumper( caller() ) . "\n"
            unless $where_extra;
        $sql_str
            = $select_sql
            . $from_sql
            . $where_sql
            . $where_extra
            . $order_by_sql;
        $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} },
            @identifiers );
    }

    return $return_object;
}

#-----------------------------------------------
sub insert_feature_alias {

=pod

=head2 insert_feature_alias()

=over 4

=item * Description

Insert a feature alias into the database.

=item * Adaptor Writing Info

The required inputs are only the ones that the database requires.

If you don't want CMap to insert into your database, make this a dummy method.

=item * Input

=over 4

=item - Feature ID (feature_id)

=item - alias (alias)

=back

=item * Output

feature_alias_id

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        feature_id    => 1,
        alias         => 1,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $feature_id = $args{'feature_id'};
    my $alias      = $args{'alias'};
    my $db         = $self->db;

    # Check if alias already inserted
    my $feature_alias_id = $db->selectrow_array(
        qq[
            select feature_alias_id 
            from   cmap_feature_alias
            where  feature_id=?
            and    alias=?
        ],
        {},
        ( $feature_id, $alias )
    );

    if ( !$feature_alias_id ) {
        $feature_alias_id
            = $self->next_number( object_type => 'feature_alias', )
            or return $self->error('No next number for feature_alias ');

        $db->do(
            qq[
                insert 
                into   cmap_feature_alias 
                       (feature_alias_id,feature_id,alias )
                values ( ?,?,? )
            ],
            {},
            ( $feature_alias_id, $feature_id, $alias )
        );
    }

    return $feature_alias_id;
}

#-----------------------------------------------
sub update_feature_alias {

=pod

=head2 update_feature_alias()

=over 4

=item * Description

Given the id and some attributes to modify, updates.

=item * Adaptor Writing Info

If you don't want CMap to update into your database, make this a dummy method.

=item * Required Input

=over 4

=item - feature_alias_id (feature_alias_id)

=back

=item * Inputs To Update

=over 4

=item - alias (alias)

=back

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object      => 0,
        no_validation    => 0,
        feature_alias_id => 0,
        object_id        => 0,
        alias            => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $feature_alias_id = $args{'feature_alias_id'} || $args{'object_id'}
        or return;
    my $alias = $args{'alias'};
    my $db    = $self->db;

    my @update_args = ();
    my $update_sql  = qq[
        update cmap_feature_alias
    ];
    my $set_sql   = '';
    my $where_sql = " where feature_alias_id = ? ";    # ID

    if ($alias) {
        push @update_args, $alias;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " alias = ? ";
    }

    push @update_args, $feature_alias_id;

    my $sql_str = $update_sql . $set_sql . $where_sql;
    $db->do( $sql_str, {}, @update_args );

}

#-----------------------------------------------
sub delete_feature_alias {

=pod

=head2 delete_feature_alias()

=over 4

=item * Description

Given the id or a feature id, delete the objects.

=item * Adaptor Writing Info

If you don't want CMap to delete from your database, make this a dummy method.

=item * Input

=over 4

=back

=item * Requred At Least One Input

=over 4

=item - feature_alias_id (feature_alias_id)

=item - Feature ID (feature_id)

=back

=item * Output

1

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object      => 0,
        no_validation    => 0,
        feature_alias_id => 0,
        feature_id       => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $db               = $self->db;
    my $feature_alias_id = $args{'feature_alias_id'};
    my $feature_id       = $args{'feature_id'};
    my @delete_args      = ();
    my $delete_sql       = qq[
        delete from cmap_feature_alias
    ];
    my $where_sql = '';

    return unless ( $feature_alias_id or $feature_id );

    if ($feature_alias_id) {
        push @delete_args, $feature_alias_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " feature_alias_id = ? ";
    }
    if ($feature_id) {
        push @delete_args, $feature_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " feature_id = ? ";
    }

 # If only feature_alias_id was supplied, get feature_id so it can be returned
    unless ($feature_id) {

        my $feature_id_sql = qq[
            select feature_id
            from   cmap_feature_alias
            where feature_alias_id = $feature_alias_id
        ];
        $feature_id = $db->selectrow_array( $feature_id_sql, {}, () );
    }

    $delete_sql .= $where_sql;
    $db->do( $delete_sql, {}, (@delete_args) );

    return $feature_id;
}

=pod

=head1 Feature Correspondence Methods

=cut 

#-----------------------------------------------
sub get_feature_correspondences {

=pod

=head2 get_feature_correspondences()

=over 4

=item * Description

Get the correspondence information based on the accession id.

This is very similar to get_feature_correspondences_simple.

=item * Required Input

=over 4

=back

=item * Required At Least One Of These Input

=over 4

=item - Correspondence ID (feature_correspondence_id)

=item - Correspondence Accession (feature_correspondence_acc)

=back

=item * Output

Hash:

  Keys:
    feature_correspondence_id,
    feature_correspondence_acc,
    feature_id1,
    feature_id2,
    is_enabled

=item * Cache Level (Not Used): 4

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object                => 0,
        no_validation              => 0,
        feature_correspondence_id  => 0,
        feature_correspondence_acc => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $feature_correspondence_id  = $args{'feature_correspondence_id'};
    my $feature_correspondence_acc = $args{'feature_correspondence_acc'};
    my $db                         = $self->db;
    my $return_object;
    my @identifiers = ();

    my $sql_str = q[
      select feature_correspondence_id,
             feature_correspondence_acc,
             feature_id1,
             feature_id2,
             is_enabled
      from   cmap_feature_correspondence
      where 
    ];

    return {}
        unless ( $feature_correspondence_id or $feature_correspondence_acc );

    if ($feature_correspondence_id) {
        push @identifiers, $feature_correspondence_id;
        $sql_str .= " feature_correspondence_id = ? ";
    }
    elsif ($feature_correspondence_acc) {
        push @identifiers, $feature_correspondence_acc;
        $sql_str .= " feature_correspondence_acc = ? ";
    }

    $return_object = $db->selectrow_hashref( $sql_str, {}, @identifiers )
        or return $self->error("No record for correspondence ");

    return $return_object;
}

#-----------------------------------------------
sub get_feature_correspondence_details {

=pod

=head2 get_feature_correspondence_details()

=over 4

=item * Description

return many details about the correspondences of a feature.

=item * Adaptor Writing Info

If disregard_evidence_type is not true AND no evidence type info is given, return [].

=item * Required Input

=over 4

=back

=item * Optional Input

=over 4

=item - feature_correspondence_id (feature_correspondence_id)

=item - feature_id1 (feature_id1)

=item - feature_id2 (feature_id2)

=item - species_id2 (species_id2)

=item - species_acc2 (species_acc2)

=item - map_set_id2 (map_set_id2)

=item - map_set_acc2 (map_set_acc2)

=item - map_id1 (map_id1)

=item - map_id2 (map_id2)

=item - map_acc2 (map_acc2)

=item - disregard_evidence_type (disregard_evidence_type)

=item - Don't bother ordering the corrs (unordered)

=back

=item * Some of the following Required unless disregard_evidence_type is true

=over 4

=item - Included Evidence Types Accessions (included_evidence_type_accs)

=item - Ev. types that must be less than score (less_evidence_type_accs)

=item - Ev. types that must be greater than score (greater_evidence_type_accs)

=item - Scores for comparing to evidence types (evidence_type_score)

=back

=item * Output

Array of Hashes:

  Keys:
    feature_name2
    feature_id2
    feature_id2
    feature_acc1
    feature_acc2
    feature_start2
    feature_stop2
    feature_type_acc1
    feature_type_acc2
    map_id2
    map_acc2
    map_name2
    map_display_order2
    map_set_id2
    map_set_acc2
    map_set_short_name2
    ms_display_order2
    published_on2
    map_type_acc2
    map_units2
    species_id2
    species_acc2
    species_common_name2
    species_display_order2
    feature_correspondence_id
    feature_correspondence_acc
    is_enabled
    evidence_type_acc
    map_type2
    feature_type1
    feature_type2
    evidence_type

=item * Cache Level (Not Used): 4

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object                 => 0,
        no_validation               => 0,
        feature_correspondence_id   => 0,
        feature_id1                 => 0,
        feature_id2                 => 0,
        species_id2                 => 0,
        species_acc2                => 0,
        map_set_id2                 => 0,
        map_set_acc2                => 0,
        map_id1                     => 0,
        map_id2                     => 0,
        map_acc2                    => 0,
        included_evidence_type_accs => 0,
        less_evidence_type_accs     => 0,
        greater_evidence_type_accs  => 0,
        evidence_type_score         => 0,
        disregard_evidence_type     => 0,
        unordered                   => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $feature_correspondence_id   = $args{'feature_correspondence_id'};
    my $feature_id1                 = $args{'feature_id1'};
    my $feature_id2                 = $args{'feature_id2'};
    my $species_id2                 = $args{'species_id2'};
    my $species_acc2                = $args{'species_acc2'};
    my $map_set_id2                 = $args{'map_set_id2'};
    my $map_set_acc2                = $args{'map_set_acc2'};
    my $map_id1                     = $args{'map_id1'};
    my $map_id2                     = $args{'map_id2'};
    my $map_acc2                    = $args{'map_acc2'};
    my $unordered                   = $args{'unordered'};
    my $included_evidence_type_accs = $args{'included_evidence_type_accs'}
        || [];
    my $less_evidence_type_accs = $args{'less_evidence_type_accs'} || [];
    my $greater_evidence_type_accs = $args{'greater_evidence_type_accs'}
        || [];
    my $evidence_type_score     = $args{'evidence_type_score'}     || {};
    my $disregard_evidence_type = $args{'disregard_evidence_type'} || 0;
    my $db                      = $self->db;
    my $map_type_data           = $self->map_type_data();
    my $feature_type_data       = $self->feature_type_data();
    my $evidence_type_data      = $self->evidence_type_data();
    my $return_object;

    my $sql_str = q[
        select   f2.feature_name as feature_name2,
                 cl.feature_id1,
                 cl.feature_id2,
                 f1.feature_acc as feature_acc1,
                 f2.feature_acc as feature_acc2,
                 cl.feature_start2,
                 cl.feature_stop2,
                 f1.feature_type_acc as feature_type_acc1,
                 f2.feature_type_acc as feature_type_acc2,
                 map2.map_id as map_id2,
                 map2.map_acc as map_acc2,
                 map2.map_name as map_name2,
                 map2.display_order as map_display_order2,
                 ms2.map_set_id as map_set_id2,
                 ms2.map_set_acc as map_set_acc2,
                 ms2.map_set_short_name as map_set_short_name2,
                 ms2.display_order as ms_display_order2,
                 ms2.published_on as published_on2,
                 ms2.map_type_acc as map_type_acc2,
                 ms2.map_units as map_units2,
                 s2.species_id as species_id2,
                 s2.species_acc as species_acc2,
                 s2.species_common_name as species_common_name2,
                 s2.display_order as species_display_order2,
                 fc.feature_correspondence_id,
                 fc.feature_correspondence_acc,
                 fc.is_enabled,
                 ce.evidence_type_acc,
                 ce.score
        from     cmap_correspondence_lookup cl, 
                 cmap_feature_correspondence fc,
                 cmap_correspondence_evidence ce,
                 cmap_feature f1,
                 cmap_feature f2,
                 cmap_map map2,
                 cmap_map_set ms2,
                 cmap_species s2
        where    cl.feature_correspondence_id=fc.feature_correspondence_id
        and      fc.feature_correspondence_id=ce.feature_correspondence_id
        and      cl.feature_id1=f1.feature_id
        and      cl.feature_id2=f2.feature_id
        and      f2.map_id=map2.map_id
        and      map2.map_set_id=ms2.map_set_id
        and      ms2.is_enabled=1
        and      ms2.species_id=s2.species_id
    ];

    if ($feature_correspondence_id) {
        $sql_str .= " and cl.feature_correspondence_id="
            . $db->quote($feature_correspondence_id) . " ";
    }
    if ($feature_id1) {
        $sql_str .= " and cl.feature_id1=" . $db->quote($feature_id1) . " ";
    }
    if ($feature_id2) {
        $sql_str .= " and cl.feature_id2=" . $db->quote($feature_id2) . " ";
    }

    if ($map_id1) {
        $sql_str .= " and cl.map_id1=" . $db->quote($map_id1) . " ";
    }

    if ($map_id2) {
        $sql_str .= " and cl.map_id2=" . $db->quote($map_id2) . " ";
    }
    elsif ($map_acc2) {
        $sql_str .= " and map2.map_acc=" . $db->quote($map_acc2) . " ";
    }
    elsif ($map_set_id2) {
        $sql_str .= " and map2.map_set_id=" . $db->quote($map_set_id2) . " ";
    }
    elsif ($map_set_acc2) {
        $sql_str .= " and ms2.map_set_acc=" . $db->quote($map_set_acc2) . " ";
    }
    elsif ($species_id2) {
        $sql_str .= " and ms2.species_id=" . $db->quote($species_id2) . " ";
    }
    elsif ($species_acc2) {
        $sql_str .= " and s2.species_acc=" . $db->quote($species_acc2) . " ";
    }

    if (!$disregard_evidence_type
        and (  @$included_evidence_type_accs
            or @$less_evidence_type_accs
            or @$greater_evidence_type_accs )
        )
    {
        $sql_str .= " and ( ";
        my @join_array;
        if (@$included_evidence_type_accs) {
            push @join_array, " ce.evidence_type_acc in ("
                . join( ",",
                map { $db->quote($_) } sort @$included_evidence_type_accs )
                . ")";
        }
        foreach my $et_acc (@$less_evidence_type_accs) {
            push @join_array,
                " ( ce.evidence_type_acc = "
                . $db->quote($et_acc) . " "
                . " and ce.score <= "
                . $db->quote( $evidence_type_score->{$et_acc} ) . " ) ";
        }
        foreach my $et_acc (@$greater_evidence_type_accs) {
            push @join_array,
                " ( ce.evidence_type_acc = "
                . $db->quote($et_acc) . " "
                . " and ce.score >= "
                . $db->quote( $evidence_type_score->{$et_acc} ) . " ) ";
        }
        $sql_str .= join( ' or ', @join_array ) . " ) ";
    }
    elsif ( !$disregard_evidence_type ) {
        $sql_str .= " and ce.evidence_type_acc = '-1' ";
    }

    $sql_str .= q[
            order by s2.display_order, s2.species_common_name, 
            ms2.display_order, ms2.map_set_short_name, map2.display_order,
            map2.map_name, f2.feature_start, f2.feature_name, f2.feature_id,
            fc.feature_correspondence_id
    ] unless ($unordered);

    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} } );

    foreach my $row ( @{$return_object} ) {
        $row->{'map_type2'}
            = $map_type_data->{ $row->{'map_type_acc2'} }{'map_type'};
        $row->{'feature_type1'}
            = $feature_type_data->{ $row->{'feature_type_acc1'} }
            {'feature_type'};
        $row->{'feature_type2'}
            = $feature_type_data->{ $row->{'feature_type_acc2'} }
            {'feature_type'};
        $row->{'evidence_type'}
            = $evidence_type_data->{ $row->{'evidence_type_acc'} }
            {'evidence_type'};
    }
    return $return_object;
}

#-----------------------------------------------
sub get_feature_correspondences_simple {

=pod

=head2 get_feature_correspondences_simple()

=over 4

=item * Description

Get just the info from the correspondences.  This is less data than
get_correspondences() provides and doesn't involve any table joins.

=item * Required Input

=over 4

=back

=item * Optional Input

=over 4

=item - feature_correspondence_id (feature_correspondence_id)

=item - map_set_ids1 (map_set_ids1)

=item - map_set_ids2 (map_set_ids2)

=back

=item * Output

Array of Hashes:

  Keys:
    feature_correspondence_id
    feature_correspondence_acc
    is_enabled
    feature_acc1
    feature_acc2

=item * Cache Level (If Used): 4

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object               => 0,
        no_validation             => 0,
        feature_correspondence_id => 0,
        map_set_ids1              => 0,
        map_set_ids2              => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $feature_correspondence_id = $args{'feature_correspondence_id'};
    my $map_set_ids1              = $args{'map_set_ids1'} || [];
    my $map_set_ids2              = $args{'map_set_ids2'} || [];
    my $db                        = $self->db;
    my $return_object;

    my $sql_str = q[
        select fc.feature_correspondence_id,
               fc.feature_correspondence_acc,
               fc.is_enabled,
               f1.feature_acc as feature_acc1,
               f2.feature_acc as feature_acc2
        from    cmap_feature_correspondence fc,
                 cmap_feature f1,
                 cmap_feature f2,
                 cmap_map map1,
                 cmap_map map2
        where    fc.feature_id1=f1.feature_id
        and      fc.feature_id2=f2.feature_id
        and      f1.map_id=map1.map_id
        and      f2.map_id=map2.map_id
    ];

    if ($feature_correspondence_id) {
        $sql_str .= " and fc.feature_correspondence_id = "
            . $db->quote($feature_correspondence_id) . " ";
    }
    if (@$map_set_ids1) {
        $sql_str .= " and map1.map_set_id in ("
            . join( ",", map { $db->quote($_) } sort @$map_set_ids1 ) . ") ";
    }

    if (@$map_set_ids2) {
        $sql_str .= " and map2.map_set_id in ("
            . join( ",", map { $db->quote($_) } sort @$map_set_ids2 ) . ") ";
    }

    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} } );

    return $return_object;
}

#-----------------------------------------------
sub get_feature_correspondences_by_maps {

=pod

=head2 get_feature_correspondences_by_maps()

=over 4

Gets corr

=item * Description

Given a map and a set of reference maps, this will return the correspondences between the two.

=item * Adaptor Writing Info

If no evidence types are supplied in
included_evidence_type_accs,less_evidence_type_accs or
greater_evidence_type_accs assume that all are ignored and return empty hash.

If the $intraslot variable is set to one, compare the maps in the $ref_map_info
against each other, instead of against the map_id.

=item * Required Input

=over 4

=item - The "slot_info" of the reference maps (ref_map_info)

 Structure:
    {
      map_id => [ current_start, current_stop, ori_start, ori_stop, magnification ],
    }

=back

=item * Optional Input

=over 4

=item - Map id of the comparative map (map_id) 

Required if not intraslot

=item - Comp map Start (map_start)

=item - Comp map stop (map_stop)

=item - Included Evidence Types Accessions (included_evidence_type_accs)

=item - Ev. types that must be less than score (less_evidence_type_accs)

=item - Ev. types that must be greater than score (greater_evidence_type_accs)

=item - Scores for comparing to evidence types (evidence_type_score)

=item - Allowed feature types (feature_type_accs)

=item - Is intraslot? (intraslot)

Set to one to get correspondences between maps in the same slot.

=back

=item * Output

Array of Hashes:

  Keys:
    feature_id, 
    ref_feature_id,
    feature_correspondence_id,
    evidence_type_acc,
    evidence_type,
    line_color,
    line_type,
    evidence_rank,


=item * Cache Level: 4

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object                 => 0,
        no_validation               => 0,
        ref_map_info                => 1,
        map_id                      => 0,
        map_start                   => 0,
        map_stop                    => 0,
        included_evidence_type_accs => 0,
        less_evidence_type_accs     => 0,
        greater_evidence_type_accs  => 0,
        evidence_type_score         => 0,
        feature_type_accs           => 0,
        intraslot                   => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $map_id                      = $args{'map_id'};
    my $ref_map_info                = $args{'ref_map_info'} || {};
    my $map_start                   = $args{'map_start'};
    my $map_stop                    = $args{'map_stop'};
    my $included_evidence_type_accs = $args{'included_evidence_type_accs'}
        || [];
    my $less_evidence_type_accs = $args{'less_evidence_type_accs'} || [];
    my $greater_evidence_type_accs = $args{'greater_evidence_type_accs'}
        || [];
    my $evidence_type_score = $args{'evidence_type_score'} || {};
    my $feature_type_accs   = $args{'feature_type_accs'}   || [];
    my $intraslot           = $args{'intraslot'};
    my @identifiers         = ();

    unless ( $map_id or $intraslot ) {
        return $self->error(
            "No map_id in query for specific map's correspondences\n");
    }
    my $db                 = $self->db;
    my $evidence_type_data = $self->evidence_type_data();
    my $return_object;

    my $sql_str = qq[
        select   cl.feature_id1 as feature_id,
                 f2.feature_id as ref_feature_id, 
                 cl.feature_correspondence_id,
                 ce.evidence_type_acc
        from     cmap_feature f2, 
                 cmap_correspondence_lookup cl,
                 cmap_feature_correspondence fc,
                 cmap_correspondence_evidence ce
        where    cl.feature_correspondence_id=
                 fc.feature_correspondence_id
        and      fc.is_enabled=1
        and      fc.feature_correspondence_id=
                 ce.feature_correspondence_id
        and      cl.feature_id2=f2.feature_id
    ];
    if ( !$intraslot ) {
        $sql_str .= q[
            and      f2.map_id=?
        ];
        push @identifiers, $map_id;
    }

    if (my $start_stop_sql = $self->write_start_stop_sql(
            map_start    => $map_start,
            map_stop     => $map_stop,
            start_column => 'cl.feature_start2',
            stop_column  => 'cl.feature_stop2',
        )
        )
    {
        $sql_str .= " and $start_stop_sql ";
    }

    if (%$ref_map_info) {
        $sql_str .= $self->write_start_stop_sql_from_slot_info(
            slot_info_obj => $ref_map_info,
            map_id_column => 'cl.map_id1',
            start_column  => 'cl.feature_start1',
            stop_column   => 'cl.feature_stop1',
        );

        if ($intraslot) {
            $sql_str .= $self->write_start_stop_sql_from_slot_info(
                slot_info_obj => $ref_map_info,
                map_id_column => 'cl.map_id2',
                start_column  => 'cl.feature_start2',
                stop_column   => 'cl.feature_stop2',
            );

            # We don't want intramap corrs
            $sql_str .= ' and cl.map_id1 < cl.map_id2 ';
        }
    }

    if (   @$included_evidence_type_accs
        or @$less_evidence_type_accs
        or @$greater_evidence_type_accs )
    {
        $sql_str .= " and ( ";
        my @join_array;
        if (@$included_evidence_type_accs) {
            push @join_array, " ce.evidence_type_acc in ("
                . join( ",",
                map { $db->quote($_) } sort @$included_evidence_type_accs )
                . ")";
        }
        foreach my $et_acc (@$less_evidence_type_accs) {
            push @join_array,
                " ( ce.evidence_type_acc = "
                . $db->quote($et_acc) . " "
                . " and ce.score <= "
                . $db->quote( $evidence_type_score->{$et_acc} ) . " ) ";
        }
        foreach my $et_acc (@$greater_evidence_type_accs) {
            push @join_array,
                " ( ce.evidence_type_acc = "
                . $db->quote($et_acc) . " "
                . " and ce.score >= "
                . $db->quote( $evidence_type_score->{$et_acc} ) . " ) ";
        }
        $sql_str .= join( ' or ', @join_array ) . " ) ";
    }
    else {
        $sql_str .= " and ce.correspondence_evidence_id = -1 ";
    }

    if (@$feature_type_accs) {
        $sql_str
            .= " and cl.feature_type_acc1 in ("
            . join( ",", map { $db->quote($_) } sort @$feature_type_accs )
            . ")";
        $sql_str
            .= " and ( cl.feature_type_acc1=cl.feature_type_acc2 "
            . " or cl.feature_type_acc2 in ("
            . join( ",", map { $db->quote($_) } sort @$feature_type_accs )
            . ") )";
    }

    unless ( $return_object
        = $self->get_cached_results( 4, $sql_str . join( ",", @identifiers ) )
        )
    {

        if ($intraslot) {
            $return_object
                = $db->selectall_arrayref( $sql_str, { Columns => {} },
                @identifiers );
        }
        else {
            $return_object
                = $db->selectall_arrayref( $sql_str, { Columns => {} },
                @identifiers );
        }

        foreach my $row ( @{$return_object} ) {
            $row->{'evidence_rank'}
                = $evidence_type_data->{ $row->{'evidence_type_acc'} }
                {'rank'};
            $row->{'line_color'}
                = $evidence_type_data->{ $row->{'evidence_type_acc'} }
                {'color'}
                || $self->config_data('connecting_line_color')
                || DEFAULT->{'connecting_line_color'};
            $row->{'line_type'}
                = $evidence_type_data->{ $row->{'evidence_type_acc'} }
                {'line_type'}
                || $self->config_data('connecting_line_type')
                || DEFAULT->{'connecting_line_type'};
            $row->{'evidence_type'}
                = $evidence_type_data->{ $row->{'evidence_type_acc'} }
                {'evidence_type'};
        }
        $self->store_cached_results( 4, $sql_str . join( ",", @identifiers ),
            $return_object );
    }

    return $return_object;
}

#-----------------------------------------------
sub get_feature_correspondence_for_counting {

=pod

=head2 get_feature_correspondence_for_counting()

=over 4

=item * Description

This is a complicated little method.  It returns correspondence information
used when aggregating.  If $split_evidence_types then the evidence type
accessions are returned in order to split the counts, otherwise the
DEFAULT->{'aggregated_type_substitute'} is used as a place holder. 

=item * Adaptor Writing Info

There are two inputs that change the output.  

$split_evidence_types splits the results into the different evidence types,
otherwise they are all grouped together (with a place holder value
DEFAULT->{'aggregated_type_substitute'}).

=item * Required Input

=over 4

=item - The "slot_info" object (slot_info)

 Structure:
    { 
        map_id => [ current_start, current_stop, ori_start, ori_stop, magnification ],
    }

=item - The "slot_info" object (slot_info2)

 Structure:
    { 
        map_id => [ current_start, current_stop, ori_start, ori_stop, magnification ],
    }

=back

=item * Optional Input

=over 4

=item - split_evidence_types (split_evidence_types)

=item - show_intraslot_corr (show_intraslot_corr)

=item - Included Evidence Types Accessions (included_evidence_type_accs)

=item - Ignored Evidence Type Accessions (ignored_evidence_type_accs)

=item - Ev. types that must be less than score (less_evidence_type_accs)

=item - Ev. types that must be greater than score (greater_evidence_type_accs)

=item - Scores for comparing to evidence types (evidence_type_score)

=item - Feature Type Accessions to ignore (ignored_feature_type_accs)

=item - Allow intramap correspondences (allow_intramap)

=back

=item * Output

Array of Hashes:

  Keys:
    map_id1
    map_id2
    evidence_type_acc
    feature_start1
    feature_stop1
    feature_start2
    feature_stop2
    feature_id1
    feature_id2


=item * Cache Level: 4 

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object                 => 0,
        no_validation               => 0,
        slot_info                   => 1,
        slot_info2                  => 1,
        split_evidence_types        => 0,
        show_intraslot_corr         => 0,
        included_evidence_type_accs => 0,
        ignored_evidence_type_accs  => 0,
        less_evidence_type_accs     => 0,
        greater_evidence_type_accs  => 0,
        evidence_type_score         => 0,
        ignored_feature_type_accs   => 0,
        allow_intramap              => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $split_evidence_types        = $args{'split_evidence_types'};
    my $show_intraslot_corr         = $args{'show_intraslot_corr'};
    my $slot_info                   = $args{'slot_info'} || {};
    my $slot_info2                  = $args{'slot_info2'} || {};
    my $included_evidence_type_accs = $args{'included_evidence_type_accs'}
        || [];
    my $ignored_evidence_type_accs = $args{'ignored_evidence_type_accs'}
        || [];
    my $less_evidence_type_accs = $args{'less_evidence_type_accs'} || [];
    my $greater_evidence_type_accs = $args{'greater_evidence_type_accs'}
        || [];
    my $evidence_type_score       = $args{'evidence_type_score'}       || {};
    my $ignored_feature_type_accs = $args{'ignored_feature_type_accs'} || [];
    my $allow_intramap            = $args{'allow_intramap'}            || 0;
    my $db                        = $self->db;
    my $return_object;

    my $select_sql = qq[
        select   cl.map_id1,
                 cl.map_id2,
                 cl.feature_start1,
                 cl.feature_stop1,
                 cl.feature_start2,
                 cl.feature_stop2,
                 cl.feature_id1,
                 cl.feature_id2
    ];

    my $from_sql = qq[
        from     cmap_correspondence_lookup cl,
                 cmap_feature_correspondence fc,
                 cmap_correspondence_evidence ce
    ];
    my $where_sql = qq[
        where    cl.feature_correspondence_id=
                 fc.feature_correspondence_id
        and      fc.is_enabled=1
        and      fc.feature_correspondence_id=
                 ce.feature_correspondence_id
    ];
    if ( !$allow_intramap ) {
        $where_sql .= qq[ and cl.map_id1 != cl.map_id2 ];
    }
    else {

        # Eliminate duplicates
        $where_sql .= qq[ and cl.feature_id1 < cl.feature_id2 ];
    }

    my $order_by_sql = qq[
        order by cl.map_id1,
                 cl.map_id2,
                 ce.evidence_type_acc
    ];

    if ($split_evidence_types) {
        $select_sql .= ", ce.evidence_type_acc \n";
    }
    else {
        $select_sql
            .= ", '"
            . DEFAULT->{'aggregated_type_substitute'}
            . "' as evidence_type_acc \n ";
    }

    # Deal with slot_info
    my @unrestricted_map_ids = ();
    my $unrestricted_sql_1   = '';
    my $restricted_sql_1     = '';
    my $unrestricted_sql_2   = '';
    my $restricted_sql_2     = '';
    foreach my $slot_map_id ( sort keys( %{$slot_info} ) ) {
        my $this_start = $slot_info->{$slot_map_id}->[0];
        my $this_stop  = $slot_info->{$slot_map_id}->[1];

        if (    defined($this_start)
            and defined($this_stop) )
        {
            $restricted_sql_1
                .= " or (cl.map_id1="
                . $db->quote($slot_map_id)
                . " and (( cl.feature_start1>="
                . $db->quote($this_start)
                . " and cl.feature_start1<="
                . $db->quote($this_stop)
                . " ) or ( cl.feature_stop1 is not null and "
                . "  cl.feature_start1<="
                . $db->quote($this_start)
                . " and cl.feature_stop1>="
                . $db->quote($this_start) . " )))";
            if ($show_intraslot_corr) {
                $restricted_sql_2
                    .= " or (cl.map_id2="
                    . $db->quote($slot_map_id)
                    . " and (( cl.feature_start2>="
                    . $db->quote($this_start)
                    . " and cl.feature_start2<="
                    . $db->quote($this_stop)
                    . " ) or ( cl.feature_stop2 is not null and "
                    . "  cl.feature_start2<="
                    . $db->quote($this_start)
                    . " and cl.feature_stop2>="
                    . $db->quote($this_start) . " )))";
            }

        }
        elsif ( defined($this_start) ) {
            $restricted_sql_1
                .= " or (cl.map_id1="
                . $db->quote($slot_map_id)
                . " and (( cl.feature_start1>="
                . $db->quote($this_start)
                . " ) or ( cl.feature_stop1 is not null "
                . " and cl.feature_stop1>="
                . $db->quote($this_start) . " )))";
            if ($show_intraslot_corr) {
                $restricted_sql_2
                    .= " or (cl.map_id2="
                    . $db->quote($slot_map_id)
                    . " and (( cl.feature_start2>="
                    . $db->quote($this_start)
                    . " ) or ( cl.feature_stop2 is not null "
                    . " and cl.feature_stop2>="
                    . $db->quote($this_start) . " )))";
            }
        }
        elsif ( defined($this_stop) ) {
            $restricted_sql_1
                .= " or (cl.map_id1="
                . $db->quote($slot_map_id)
                . " and cl.feature_start1<="
                . $db->quote($this_stop) . ") ";
            if ($show_intraslot_corr) {
                $restricted_sql_2
                    .= " or (cl.map_id2="
                    . $db->quote($slot_map_id)
                    . " and cl.feature_start2<="
                    . $db->quote($this_stop) . ") ";
            }
        }
        else {
            push @unrestricted_map_ids, $slot_map_id;
        }
    }
    if (@unrestricted_map_ids) {
        $unrestricted_sql_1
            .= " or cl.map_id1 in ("
            . join( ",", map { $db->quote($_) } sort @unrestricted_map_ids )
            . ") ";
        if ($show_intraslot_corr) {
            $unrestricted_sql_2
                .= " or cl.map_id2 in ("
                . join( ",",
                map { $db->quote($_) } sort @unrestricted_map_ids )
                . ") ";
        }
    }
    my $combined_sql = $restricted_sql_1 . $unrestricted_sql_1;
    $combined_sql =~ s/^\s+or//;
    $where_sql .= " and (" . $combined_sql . ")";

    if (%$slot_info2) {

        # Include reference slot maps
        @unrestricted_map_ids = ();
        foreach my $slot_map_id ( sort keys( %{$slot_info2} ) ) {
            my $this_start = $slot_info2->{$slot_map_id}->[0];
            my $this_stop  = $slot_info2->{$slot_map_id}->[1];

            # $this_start is start [1] is stop
            if (    defined($this_start)
                and defined($this_stop) )
            {
                $restricted_sql_2
                    .= " or (cl.map_id2="
                    . $db->quote($slot_map_id)
                    . " and (( cl.feature_start2>="
                    . $db->quote($this_start)
                    . " and cl.feature_start2<="
                    . $db->quote($this_stop)
                    . " ) or ( cl.feature_stop2 is not null and "
                    . "  cl.feature_start2<="
                    . $db->quote($this_start)
                    . " and cl.feature_stop2>="
                    . $db->quote($this_start) . " )))";
            }
            elsif ( defined($this_start) ) {
                $restricted_sql_2
                    .= " or (cl.map_id2="
                    . $db->quote($slot_map_id)
                    . " and (( cl.feature_start2>="
                    . $db->quote($this_start)
                    . " ) or ( cl.feature_stop2 is not null "
                    . " and cl.feature_stop2>="
                    . $db->quote($this_start) . " )))";
            }
            elsif ( defined($this_stop) ) {
                $restricted_sql_2
                    .= " or (cl.map_id2="
                    . $db->quote($slot_map_id)
                    . " and cl.feature_start2<="
                    . $db->quote($this_stop) . ") ";
            }
            else {
                push @unrestricted_map_ids, $slot_map_id;
            }
        }
        if (@unrestricted_map_ids) {
            $unrestricted_sql_2
                .= " or cl.map_id2 in ("
                . join( ",",
                map { $db->quote($_) } sort @unrestricted_map_ids )
                . ") ";
        }
    }
    $combined_sql = $restricted_sql_2 . $unrestricted_sql_2;
    $combined_sql =~ s/^\s+or//;
    $where_sql .= " and (" . $combined_sql . ")";

    if (   @$included_evidence_type_accs
        or @$less_evidence_type_accs
        or @$greater_evidence_type_accs )
    {
        my @join_array;
        if (@$included_evidence_type_accs) {
            push @join_array, " ce.evidence_type_acc in ("
                . join( ",",
                map { $db->quote($_) } sort @$included_evidence_type_accs )
                . ")";
        }
        foreach my $et_acc ( sort @$less_evidence_type_accs ) {
            push @join_array,
                " ( ce.evidence_type_acc = "
                . $db->quote($et_acc) . " "
                . " and ce.score <= "
                . $db->quote( $evidence_type_score->{$et_acc} ) . " ) ";
        }
        foreach my $et_acc ( sort @$greater_evidence_type_accs ) {
            push @join_array,
                " ( ce.evidence_type_acc = "
                . $db->quote($et_acc) . " "
                . " and ce.score >= "
                . $db->quote( $evidence_type_score->{$et_acc} ) . " ) ";
        }
        $where_sql .= " and ( " . join( ' or ', @join_array ) . " ) ";
    }
    elsif (@$ignored_evidence_type_accs) {

        #all are ignored, return nothing
        return [];
    }

    my $sql_str = $select_sql . $from_sql . $where_sql . $order_by_sql;

    unless ( $return_object = $self->get_cached_results( 4, $sql_str ) ) {
        $return_object
            = $db->selectall_arrayref( $sql_str, { Columns => {} }, );
        $self->store_cached_results( 4, $sql_str, $return_object );
    }

    return $return_object;
}

#-----------------------------------------------
sub get_comparative_maps_with_count {

=pod

=head2 get_comparative_maps_with_count()

=over 4

=item * Description

Gets the comparative maps and includes a count of the number of features.

=item * Adaptor Writing Info

If $include_map1_data is true, then also include information about the starting
map (map1).

=item * Required Input

=over 4

=back

=item * Optional Input

=over 4

=item - Minimum number of correspondences (min_correspondences)

=item - The "slot_info" object (slot_info)

 Structure:
    { 
      slot_no => {
        map_id => [ current_start, current_stop, ori_start, ori_stop, magnification ],
      }
    }

=item - List of Map Accessions (map_accs)

=item - List of Map Accessions to Ignore (ignore_map_accs)

=item - Included Evidence Types Accessions (included_evidence_type_accs)

=item - Ignored Evidence Type Accessions (ignored_evidence_type_accs)

=item - Ev. types that must be less than score (less_evidence_type_accs)

=item - Ev. types that must be greater than score (greater_evidence_type_accs)

=item - Scores for comparing to evidence types (evidence_type_score)

=item - Feature Type Accessions to ignore (ignored_feature_type_accs)

=item - Boolean value include_map1_data (include_map1_data)

=item - Boolean value, restrict results to the same set (intraslot_only) 

If information about the starting map is desired, set include_map1_data to
true.

=back

=item * Output

Array of Hashes:

  Keys:
    no_corr
    map_id2
    map_acc2
    map_set_id2

If $include_map1_data also has

     map_id1
     map_acc1
     map_set_id1

=item * Cache Level: 4

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object                 => 0,
        no_validation               => 0,
        min_correspondences         => 0,
        slot_info                   => 0,
        map_accs                    => 0,
        ignore_map_accs             => 0,
        included_evidence_type_accs => 0,
        ignored_evidence_type_accs  => 0,
        less_evidence_type_accs     => 0,
        greater_evidence_type_accs  => 0,
        evidence_type_score         => 0,
        ignored_feature_type_accs   => 0,
        include_map1_data           => 0,
        intraslot_only              => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $min_correspondences         = $args{'min_correspondences'};
    my $slot_info                   = $args{'slot_info'} || {};
    my $map_accs                    = $args{'map_accs'} || [];
    my $ignore_map_accs             = $args{'ignore_map_accs'} || [];
    my $included_evidence_type_accs = $args{'included_evidence_type_accs'}
        || [];
    my $ignored_evidence_type_accs = $args{'ignored_evidence_type_accs'}
        || [];
    my $less_evidence_type_accs = $args{'less_evidence_type_accs'} || [];
    my $greater_evidence_type_accs = $args{'greater_evidence_type_accs'}
        || [];
    my $evidence_type_score       = $args{'evidence_type_score'}       || {};
    my $ignored_feature_type_accs = $args{'ignored_feature_type_accs'} || [];
    my $include_map1_data         = $args{'include_map1_data'};
    $include_map1_data = 1 unless ( defined $include_map1_data );
    my $intraslot_only = $args{'intraslot_only'} || 0;

    my $db = $self->db;
    my $return_object;

    # variable to include the map1 table if needed
    my $use_map1_table = 0;
    my $map1_from_sql  = ', cmap_map map1';
    my $map1_where_sql = ' and map1.map_id=cl.map_id1 ';

    my $select_sql = qq[
        select   count(distinct cl.feature_correspondence_id) as no_corr,
                 cl.map_id1,
                 cl.map_id2,
                 map2.map_acc as map_acc2,
                 map2.map_set_id as map_set_id2
    ];
    my $from_sql = qq[
        from     cmap_correspondence_lookup cl,
                 cmap_map map2
    ];
    my $where_sql = qq[
        where    cl.map_id1!=cl.map_id2
        and      map2.map_id=cl.map_id2
    ];
    my $group_by_sql = qq[
        group by cl.map_id2,
                 cl.map_id1,
                 map2.map_acc,
                 map2.map_set_id 
    ];

    if ($include_map1_data) {
        $use_map1_table = 1;
        $select_sql .= qq[
                 ,
                 map1.map_acc as map_acc1,
                 map1.map_set_id as map_set_id1
        ];
        $group_by_sql .= qq[
                 , cl.map_id1,
                 map1.map_acc,
                 map1.map_set_id
        ];
    }
    if ($intraslot_only) {
        $use_map1_table = 1;
        $where_sql .= " and map1.map_set_id = map2.map_set_id ";
    }

    my $having_sql = '';

    if (@$map_accs) {
        $use_map1_table = 1;
        $where_sql .= " and map1.map_acc in ("
            . join( ",", map { $db->quote($_) } sort @{$map_accs} ) . ") \n";
    }

    if (@$ignore_map_accs) {
        $where_sql
            .= " and map2.map_acc not in ("
            . join( ",", map { $db->quote($_) } sort @{$ignore_map_accs} )
            . ") ";
    }

    my @unrestricted_map_ids;
    my $restricted_sql   = '';
    my $unrestricted_sql = '';
    foreach my $ref_map_id ( sort keys( %{$slot_info} ) ) {
        my $ref_map_start = $slot_info->{$ref_map_id}[0];
        my $ref_map_stop  = $slot_info->{$ref_map_id}[1];
        if ( defined($ref_map_start) and defined($ref_map_stop) ) {
            $restricted_sql
                .= " or (cl.map_id1="
                . $db->quote($ref_map_id)
                . " and (( cl.feature_start1>="
                . $db->quote($ref_map_start)
                . " and cl.feature_start1<="
                . $db->quote($ref_map_stop)
                . " ) or ( cl.feature_stop1 is not null and "
                . "  cl.feature_start1<="
                . $db->quote($ref_map_start)
                . " and cl.feature_stop1>="
                . $db->quote($ref_map_start) . " )))";
        }
        elsif ( defined($ref_map_start) ) {
            $restricted_sql
                .= " or (cl.map_id1="
                . $db->quote($ref_map_id)
                . " and (( cl.feature_start1>="
                . $db->quote($ref_map_start)
                . " ) or ( cl.feature_stop1 is not null and "
                . " cl.feature_stop1>="
                . $db->quote($ref_map_start) . " )))";
        }
        elsif ( defined($ref_map_stop) ) {
            $restricted_sql
                .= " or (cl.map_id1="
                . $db->quote($ref_map_id)
                . " and cl.feature_start1<="
                . $db->quote($ref_map_stop) . ") ";
        }
        else {
            push @unrestricted_map_ids, $ref_map_id;
        }
    }
    if (@unrestricted_map_ids) {
        $unrestricted_sql
            = " or cl.map_id1 in ("
            . join( ",", map { $db->quote($_) } sort @unrestricted_map_ids )
            . ") ";
    }
    my $from_restriction = $restricted_sql . $unrestricted_sql;
    $from_restriction =~ s/^\s+or//;
    $where_sql .= " and (" . $from_restriction . ")"
        if $from_restriction;

    if (   ( @$ignored_evidence_type_accs and @$included_evidence_type_accs )
        or @$less_evidence_type_accs
        or @$greater_evidence_type_accs )
    {
        $from_sql .= q[, cmap_feature_correspondence fc
                        , cmap_correspondence_evidence ce];
        $where_sql .= q[
            and fc.feature_correspondence_id=ce.feature_correspondence_id
            and  ( ];
        my @join_array;
        if (@$included_evidence_type_accs) {
            push @join_array, " ce.evidence_type_acc in ("
                . join( ",",
                map { $db->quote($_) } sort @$included_evidence_type_accs )
                . ")";
        }
        foreach my $et_acc ( sort @$less_evidence_type_accs ) {
            push @join_array,
                " ( ce.evidence_type_acc = "
                . $db->quote($et_acc) . " "
                . " and ce.score <= "
                . $db->quote( $evidence_type_score->{$et_acc} ) . " ) ";
        }
        foreach my $et_acc ( sort @$greater_evidence_type_accs ) {
            push @join_array,
                " ( ce.evidence_type_acc = "
                . $db->quote($et_acc) . " "
                . " and ce.score >= "
                . $db->quote( $evidence_type_score->{$et_acc} ) . " ) ";
        }
        $where_sql .= join( ' or ', @join_array ) . " ) ";
    }
    elsif (@$ignored_evidence_type_accs) {

        #all are ignored, return nothing
        return [];
    }

    if (@$ignored_feature_type_accs) {
        $where_sql .= " and cl.feature_type_acc2 not in ("
            . join( ",",
            map { $db->quote($_) } sort @$ignored_feature_type_accs )
            . ") ";
        $where_sql
            .= " and ( cl.feature_type_acc1=cl.feature_type_acc2 "
            . " or cl.feature_type_acc1 not in ("
            . join( ",",
            map { $db->quote($_) } sort @$ignored_feature_type_accs )
            . ") )";
    }

    if ($min_correspondences) {
        $having_sql .= " having count(cl.feature_correspondence_id)>"
            . $db->quote($min_correspondences) . " ";
    }

    if ($use_map1_table) {
        $where_sql .= $map1_where_sql;
        $from_sql  .= $map1_from_sql;
    }

    my $sql_str
        = $select_sql . $from_sql . $where_sql . $group_by_sql . $having_sql;

    unless ( $return_object = $self->get_cached_results( 4, $sql_str ) ) {
        $return_object
            = $db->selectall_arrayref( $sql_str, { Columns => {} }, );
        $self->store_cached_results( 4, $sql_str, $return_object );
    }

    return $return_object;
}

#-----------------------------------------------
sub get_feature_correspondence_count_for_feature {

=pod

=head2 get_feature_correspondence_counts_for_feature()

=over 4

=item * Description

Return the number of correspondences that a feature has.

=item * Required Input

=over 4

=item - Feature ID (feature_id)

=back

=item * Output

Count

=item * Cache Level (Not Used): 4

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        feature_id    => 1,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $feature_id = $args{'feature_id'} or die "No feature id given";
    my $db = $self->db;
    my $return_object;

    my $sql_str = q[
        select count(fc.feature_correspondence_id)
        from   cmap_correspondence_lookup cl,
               cmap_feature_correspondence fc
        where  cl.feature_id1=?
        and    cl.feature_correspondence_id=
               fc.feature_correspondence_id
    ];

    $return_object = $db->selectrow_array( $sql_str, {}, $feature_id );

    return $return_object;
}

#-----------------------------------------------
sub insert_feature_correspondence {

=pod

=head2 insert_feature_correspondence()

=over 4

=item * Description

Insert a feature correspondence into the database.

=item * Adaptor Writing Info

The required inputs are only the ones that the database requires.

If you don't want CMap to insert into your database, make this a dummy method.

=item * Input

=over 4

=item - feature_id1 (feature_id1)

=item - feature_id2 (feature_id2)

=item - feature_acc1 (feature_acc1)

=item - feature_acc2 (feature_acc2)

=item - Boolean: Is this enabled (is_enabled)

=item - evidence_type_acc (evidence_type_acc)

=item - evidence (evidence)

=item - feature_correspondence_acc (feature_correspondence_acc)

=item - score (score)

=item - threshold (threshold)

=back

=item * Output

Feature Correspondence id

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object                => 0,
        no_validation              => 0,
        feature_id1                => 0,
        feature_id2                => 0,
        feature_acc1               => 0,
        feature_acc2               => 0,
        is_enabled                 => 0,
        evidence_type_acc          => 0,
        evidence_type_aid          => 0,
        evidence_type_accession    => 0,
        evidence                   => 0,
        correspondence_evidence    => 0,
        feature_correspondence_acc => 0,
        accession_id               => 0,
        score                      => 0,
        threshold                  => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $feature_id1  = $args{'feature_id1'};
    my $feature_id2  = $args{'feature_id2'};
    my $feature_acc1 = $args{'feature_acc1'};
    my $feature_acc2 = $args{'feature_acc2'};
    my $is_enabled   = $args{'is_enabled'};
    $is_enabled = 1 unless ( defined($is_enabled) );
    my $evidence_type_acc = $args{'evidence_type_acc'}
        || $args{'evidence_type_aid'}
        || $args{'evidence_type_accession'};
    my $evidence = $args{'evidence'}
        || $args{'correspondence_evidence'}
        || [];
    my $feature_correspondence_acc = $args{'feature_correspondence_acc'}
        || $args{'accession_id'};
    my $score = $args{'score'};

    my $threshold = $args{'threshold'} || 0;
    my $db = $self->db;

    if ( !$feature_id1 and $feature_acc1 ) {
        $feature_id1 = $self->acc_id_to_internal_id(
            acc_id      => $feature_acc1,
            object_type => 'feature',
        );
    }
    if ( !$feature_id2 and $feature_acc2 ) {
        $feature_id2 = $self->acc_id_to_internal_id(
            acc_id      => $feature_acc2,
            object_type => 'feature',
        );
    }

    if ($evidence_type_acc) {
        push @$evidence,
            {
            evidence_type_acc => $evidence_type_acc,
            score             => $score,
            };
    }

    if ($feature_id1) {
        push @{ $self->{'insert_correspondences'} },
            [
            $feature_correspondence_acc,
            $feature_id1, $feature_id2, $is_enabled, $evidence
            ];
    }

    my $base_corr_id;
    if ( scalar( @{ $self->{'insert_correspondences'} || [] } ) >= $threshold
        and scalar( @{ $self->{'insert_correspondences'} || [] } ) )
    {
        my $no_correspondences
            = scalar( @{ $self->{'insert_correspondences'} } );
        my $base_corr_id = $self->next_number(
            object_type => 'feature_correspondence',
            requested   => $no_correspondences,
        ) or die 'No next number for correspondence ';
        my $sth_fc = $db->prepare(
            qq[
                insert into cmap_feature_correspondence
                (
                    feature_correspondence_id,
                    feature_correspondence_acc,
                    feature_id1,
                    feature_id2,
                    is_enabled
                 )
                 values ( ?,?,?,?,? )
                ]
        );
        my $sth_cl = $db->prepare(
            qq[
                insert into cmap_correspondence_lookup
                (
                    feature_correspondence_id,
                    feature_id1,
                    feature_id2,
                    feature_start1,
                    feature_start2,
                    feature_stop1,
                    feature_stop2,
                    map_id1,
                    map_id2,
                    feature_type_acc1,
                    feature_type_acc2
                 )
                 values ( ?,?,?,?,?,?,?,?,?,?,? )
                ]
        );
        my ($corr_id,     $corr_acc,   $feature_id1,
            $feature_id2, $is_enabled, $evidences
        );
        for ( my $i = 0; $i < $no_correspondences; $i++ ) {
            my $corr_id = $base_corr_id + $i;
            ( $corr_acc, $feature_id1, $feature_id2, $is_enabled, $evidences )
                = @{ $self->{'insert_correspondences'}[$i] };
            $corr_acc ||= $corr_id;

            my $feature1
                = $self->get_features_simple( feature_id => $feature_id1, );
            $feature1 = $feature1->[0] if $feature1;
            my $feature2
                = $self->get_features_simple( feature_id => $feature_id2, );
            $feature2 = $feature2->[0] if $feature2;

            $sth_fc->execute(
                $corr_id,     $corr_acc, $feature_id1,
                $feature_id2, $is_enabled
            );

            $sth_cl->execute(
                $corr_id,
                $feature_id1,
                $feature_id2,
                $feature1->{'feature_start'},
                $feature2->{'feature_start'},
                $feature1->{'feature_stop'},
                $feature2->{'feature_stop'},
                $feature1->{'map_id'},
                $feature2->{'map_id'},
                $feature1->{'feature_type_acc'},
                $feature2->{'feature_type_acc'},

            );
            $sth_cl->execute(
                $corr_id,
                $feature_id2,
                $feature_id1,
                $feature2->{'feature_start'},
                $feature1->{'feature_start'},
                $feature2->{'feature_stop'},
                $feature1->{'feature_stop'},
                $feature2->{'map_id'},
                $feature1->{'map_id'},
                $feature2->{'feature_type_acc'},
                $feature1->{'feature_type_acc'},

            );

            # Deal with Evidence
            foreach my $evidence (@$evidences) {
                $self->insert_correspondence_evidence(
                    feature_correspondence_id => $corr_id,
                    evidence_type_acc => $evidence->{'evidence_type_acc'},
                    score             => $evidence->{'score'},
                );
            }
        }
        $self->{'insert_correspondences'} = [];
        return $base_corr_id + $no_correspondences - 1;
    }
    return undef;
}

#-----------------------------------------------
sub update_feature_correspondence {

=pod

=head2 update_feature_correspondence()

=over 4

=item * Description

Given the id and some attributes to modify, updates.

=item * Adaptor Writing Info

If you don't want CMap to update into your database, make this a dummy method.

=item * Required Input

=over 4

=item - feature_correspondence_id (feature_correspondence_id)

=back

=item * Inputs To Update

=over 4

=item - feature_correspondence_acc (feature_correspondence_acc)

=item - Boolean: Is this enabled (is_enabled)

=item - feature_id1 (feature_id1)

=item - feature_id2 (feature_id2)

=back

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object                => 0,
        no_validation              => 0,
        feature_correspondence_id  => 0,
        object_id                  => 0,
        feature_correspondence_acc => 0,
        accession_id               => 0,
        is_enabled                 => 0,
        feature_id1                => 0,
        feature_id2                => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $feature_correspondence_id = $args{'feature_correspondence_id'}
        || $args{'object_id'}
        or return;
    my $feature_correspondence_acc = $args{'feature_correspondence_acc'}
        || $args{'accession_id'};
    my $is_enabled  = $args{'is_enabled'};
    my $feature_id1 = $args{'feature_id1'};
    my $feature_id2 = $args{'feature_id2'};
    my $db          = $self->db;

    my @update_args = ();
    my $update_sql  = qq[
        update cmap_feature_correspondence
    ];
    my $set_sql   = '';
    my $where_sql = " where feature_correspondence_id = ? ";    # ID

    if ($feature_correspondence_acc) {
        push @update_args, $feature_correspondence_acc;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " feature_correspondence_acc = ? ";
    }
    if ($feature_id1) {
        push @update_args, $feature_id1;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " feature_id1 = ? ";
    }
    if ($feature_id2) {
        push @update_args, $feature_id2;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " feature_id2 = ? ";
    }
    if ( defined($is_enabled) ) {
        push @update_args, $is_enabled;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " is_enabled = ? ";
    }

    push @update_args, $feature_correspondence_id;

    my $sql_str = $update_sql . $set_sql . $where_sql;
    $db->do( $sql_str, {}, @update_args );

}

#-----------------------------------------------
sub delete_correspondence {

=pod

=head2 delete_correspondence()

=over 4

=item * Description

Given the id or a feature id, delete the objects.

=item * Adaptor Writing Info

If you don't want CMap to delete from your database, make this a dummy method.

=item * Input

=item * Requred At Least One Input

=over 4

=item - feature_correspondence_id (feature_correspondence_id)

=item - Feature ID (feature_id)

=back

=item * Output

1

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object               => 0,
        no_validation             => 0,
        feature_correspondence_id => 0,
        feature_id                => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $db                        = $self->db;
    my $feature_correspondence_id = $args{'feature_correspondence_id'};
    my $feature_id                = $args{'feature_id'};
    my @delete_args               = ();
    my $delete_sql_fc             = qq[
        delete from cmap_feature_correspondence
    ];
    my $delete_sql_cl = qq[
        delete from cmap_correspondence_lookup
    ];
    my $where_sql_fc = '';
    my $where_sql_cl = '';

    return unless ( $feature_correspondence_id or $feature_id );
    if ($feature_correspondence_id) {
        push @delete_args, $feature_correspondence_id;
        $where_sql_fc .= $where_sql_fc ? " and " : " where ";
        $where_sql_fc .= " feature_correspondence_id = ? ";
        $where_sql_cl .= $where_sql_cl ? " and " : " where ";
        $where_sql_cl .= " feature_correspondence_id = ? ";
    }
    if ($feature_id) {
        push @delete_args, $feature_id;
        push @delete_args, $feature_id;
        $where_sql_fc .= $where_sql_fc ? " and " : " where ";
        $where_sql_fc .= " ( feature_id1 = ? or feature_id2 = ?) ";
        $where_sql_cl .= $where_sql_cl ? " and " : " where ";
        $where_sql_cl .= " ( feature_id1 = ? or feature_id2 = ?) ";
    }

    $delete_sql_fc .= $where_sql_fc;
    $delete_sql_cl .= $where_sql_cl;
    $db->do( $delete_sql_fc, {}, (@delete_args) );
    $db->do( $delete_sql_cl, {}, (@delete_args) );

    return 1;
}

=pod

=head1 Correspondence Evidence Methods

=cut 

#-----------------------------------------------
sub get_correspondence_evidences {

=pod

=head2 get_correspondence_evidences()

=over 4

=item * Description

Get information about the correspondence evidences

=item * Adaptor Writing Info

=item * Optional Input

=over 4

=item - feature_correspondence_id (feature_correspondence_id)

=item - correspondence_evidence_id (correspondence_evidence_id)

=item - evidence_type_acc (evidence_type_acc)

=item - Order by clause (order_by)

=back

=item * Output

Array of Hashes:

  Keys:
    correspondence_evidence_id
    feature_correspondence_id
    correspondence_evidence_acc
    score
    evidence_type_acc
    rank
    evidence_type

=item * Cache Level (Not Used): 4

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object                => 0,
        no_validation              => 0,
        feature_correspondence_id  => 0,
        correspondence_evidence_id => 0,
        evidence_type_acc          => 0,
        order_by                   => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $feature_correspondence_id  = $args{'feature_correspondence_id'};
    my $correspondence_evidence_id = $args{'correspondence_evidence_id'};
    my $evidence_type_acc          = $args{'evidence_type_acc'};
    my $order_by                   = $args{'order_by'};
    die "Order by clause ($order_by) has SQL code in it\n"
        if ( has_sql_command($order_by) );
    my $db                 = $self->db;
    my $evidence_type_data = $self->evidence_type_data();
    my $return_object;

    my @identifiers = ();
    my $sql_str     = q[
        select   ce.correspondence_evidence_id,
                 ce.feature_correspondence_id,
                 ce.correspondence_evidence_acc,
                 ce.score,
                 ce.evidence_type_acc
        from     cmap_correspondence_evidence ce
    ];
    my $where_sql    = '';
    my $order_by_sql = '';

    if ($correspondence_evidence_id) {
        push @identifiers, $correspondence_evidence_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " ce.correspondence_evidence_id = ? ";
    }
    if ($evidence_type_acc) {
        push @identifiers, $evidence_type_acc;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " ce.evidence_type_acc = ? ";
    }
    if ($feature_correspondence_id) {
        push @identifiers, $feature_correspondence_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " ce.feature_correspondence_id = ? ";
    }
    if ($order_by) {
        $order_by_sql = " order by $order_by ";
    }

    $sql_str .= $where_sql;

    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} },
        @identifiers );

    foreach my $row ( @{$return_object} ) {
        $row->{'rank'}
            = $evidence_type_data->{ $row->{'evidence_type_acc'} }{'rank'};
        $row->{'evidence_type'}
            = $evidence_type_data->{ $row->{'evidence_type_acc'} }
            {'evidence_type'};
    }

    return $return_object;
}

#-----------------------------------------------
sub get_correspondence_evidences_simple {

=pod

=head2 get_correspondence_evidences_simple()

=over 4

=item * Description

Get information about evidences.  This "_simple" method is different from the others because it can take map set ids (which requires table joins) to determine which evidences to return.

=item * Optional Input

=over 4

=item - List of Map Set IDs (map_set_ids)

=back

=item * Output

Array of Hashes:

  Keys:
    correspondence_evidence_id
    correspondence_evidence_acc
    feature_correspondence_id
    evidence_type_acc
    score
    rank

=item * Cache Level (If Used): 4

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        map_set_ids   => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $map_set_ids        = $args{'map_set_ids'} || [];
    my $db                 = $self->db;
    my $evidence_type_data = $self->evidence_type_data();
    my $return_object;

    my $sql_str = q[
        select ce.correspondence_evidence_id,
                   ce.feature_correspondence_id,
                   ce.correspondence_evidence_acc,
                   ce.evidence_type_acc,
                   ce.score
            from   cmap_correspondence_evidence ce
    ];
    if (@$map_set_ids) {
        $sql_str .= q[
                 , cmap_feature_correspondence fc,
                   cmap_feature f1,
                   cmap_feature f2,
                   cmap_map map1,
                   cmap_map map2
            where  ce.feature_correspondence_id=fc.feature_correspondence_id
            and    fc.feature_id1=f1.feature_id
            and    f1.map_id=map1.map_id
            and    fc.feature_id2=f2.feature_id
            and    f2.map_id=map2.map_id
        ];
        $sql_str .= " and map1.map_set_id in ("
            . join( ",", map { $db->quote($_) } sort @$map_set_ids ) . ") ";
        $sql_str .= " and map2.map_set_id in ("
            . join( ",", map { $db->quote($_) } sort @$map_set_ids ) . ") ";
    }
    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} } );

    foreach my $row ( @{$return_object} ) {
        $row->{'rank'}
            = $evidence_type_data->{ $row->{'evidence_type_acc'} }{'rank'};
    }

    return $return_object;
}

#-----------------------------------------------
sub insert_correspondence_evidence {

=pod

=head2 insert_correspondence_evidence()

=over 4

=item * Description

Insert a correspondence evidence into the database.

=item * Adaptor Writing Info

The required inputs are only the ones that the database requires.

If you don't want CMap to insert into your database, make this a dummy method.

=item * Input

=over 4

=item - evidence_type_acc (evidence_type_acc)

=item - score (score)

=item - correspondence_evidence_acc (correspondence_evidence_acc)

=item - feature_correspondence_id (feature_correspondence_id)

=back

=item * Output

Correspondence Evidence id

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object                 => 0,
        no_validation               => 0,
        evidence_type_acc           => 0,
        evidence_type_aid           => 0,
        evidence_type_accession     => 0,
        score                       => 0,
        correspondence_evidence_acc => 0,
        accession_id                => 0,
        feature_correspondence_id   => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $evidence_type_acc = $args{'evidence_type_acc'}
        || $args{'evidence_type_aid'}
        || $args{'evidence_type_accession'}
        or return;
    my $score = $args{'score'};
    if ( defined($score) and $score eq '' ) {
        $score = undef;
    }
    my $correspondence_evidence_acc = $args{'correspondence_evidence_acc'}
        || $args{'accession_id'};
    my $feature_correspondence_id = $args{'feature_correspondence_id'};
    my $db                        = $self->db;
    my $evidence_type_data        = $self->evidence_type_data();
    my $return_object;
    my $corr_evidence_id
        = $self->next_number( object_type => 'correspondence_evidence', )
        or return $self->error('No next number for correspondence evidence');
    $correspondence_evidence_acc ||= $corr_evidence_id;
    my $rank = $self->evidence_type_data( $evidence_type_acc, 'rank' ) || 1;
    my @insert_args = (
        $corr_evidence_id, $correspondence_evidence_acc,
        $feature_correspondence_id, $evidence_type_acc, $score, $rank,
    );

    $db->do(
        qq[
            insert into   cmap_correspondence_evidence
                   ( correspondence_evidence_id,
                     correspondence_evidence_acc,
                     feature_correspondence_id,
                     evidence_type_acc,
                     score,
                     rank
                   )
            values ( ?, ?, ?, ?, ?, ? )
        ],
        {},
        (@insert_args)
    );

    return $corr_evidence_id;
}

#-----------------------------------------------
sub update_correspondence_evidence {

=pod

=head2 update_correspondence_evidence()

=over 4

=item * Description

Given the id and some attributes to modify, updates.

=item * Adaptor Writing Info

If you don't want CMap to update into your database, make this a dummy method.

=item * Required Input

=over 4

=item - correspondence_evidence_id (correspondence_evidence_id)

=back

=item * Inputs To Update

=over 4

=item - evidence_type_acc (evidence_type_acc)

=item - score (score)

=item - rank (rank)

=item - correspondence_evidence_acc (correspondence_evidence_acc)

=item - feature_correspondence_id (feature_correspondence_id)

=back

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object                 => 0,
        no_validation               => 0,
        correspondence_evidence_id  => 0,
        object_id                   => 0,
        evidence_type_acc           => 0,
        evidence_type_aid           => 0,
        evidence_type_accession     => 0,
        score                       => 0,
        rank                        => 0,
        correspondence_evidence_acc => 0,
        accession_id                => 0,
        feature_correspondence_id   => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $correspondence_evidence_id = $args{'correspondence_evidence_id'}
        || $args{'object_id'}
        or return;
    my $evidence_type_acc = $args{'evidence_type_acc'}
        || $args{'evidence_type_aid'}
        || $args{'evidence_type_accession'};
    my $score                       = $args{'score'};
    my $rank                        = $args{'rank'};
    my $correspondence_evidence_acc = $args{'correspondence_evidence_acc'}
        || $args{'accession_id'};
    my $feature_correspondence_id = $args{'feature_correspondence_id'};
    my $db                        = $self->db;
    my $evidence_type_data        = $self->evidence_type_data();
    my $return_object;

    my @update_args = ();
    my $update_sql  = qq[
        update cmap_correspondence_evidence
    ];
    my $set_sql   = '';
    my $where_sql = " where correspondence_evidence_id=? ";

    if ($evidence_type_acc) {
        push @update_args, $evidence_type_acc;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " evidence_type_acc = ? ";
    }
    if ($score) {
        push @update_args, $score;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " score = ? ";
    }
    if ($rank) {
        push @update_args, $rank;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " rank = ? ";
    }
    if ($feature_correspondence_id) {
        push @update_args, $feature_correspondence_id;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " feature_correspondence_id = ? ";
    }
    if ($correspondence_evidence_acc) {
        push @update_args, $correspondence_evidence_acc;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " correspondence_evidence_acc = ? ";
    }

    push @update_args, $correspondence_evidence_id;

    my $sql_str = $update_sql . $set_sql . $where_sql;
    $db->do( $sql_str, {}, @update_args );

}

#-----------------------------------------------
sub delete_evidence {

=pod

=head2 delete_evidence()

=over 4

=item * Description

Given the id or a feature correspondence id, delete the objects.

=item * Adaptor Writing Info

If you don't want CMap to delete from your database, make this a dummy method.

=item * Input

=over 4

=back

=item * Requred At Least One Input

=over 4

=item - correspondence_evidence_id (correspondence_evidence_id)

=item - feature_correspondence_id (feature_correspondence_id)

=back

=item * Output

1

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object                => 0,
        no_validation              => 0,
        correspondence_evidence_id => 0,
        feature_correspondence_id  => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $db                         = $self->db;
    my $correspondence_evidence_id = $args{'correspondence_evidence_id'};
    my $feature_correspondence_id  = $args{'feature_correspondence_id'};
    my @delete_args                = ();
    my $delete_sql                 = qq[
        delete from cmap_correspondence_evidence
    ];
    my $where_sql = '';

    return
        unless ( $correspondence_evidence_id or $feature_correspondence_id );

    if ($correspondence_evidence_id) {
        push @delete_args, $correspondence_evidence_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " correspondence_evidence_id = ? ";
    }
    if ($feature_correspondence_id) {
        push @delete_args, $feature_correspondence_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " feature_correspondence_id = ? ";
    }

    $delete_sql .= $where_sql;
    $db->do( $delete_sql, {}, (@delete_args) );

    return 1;
}

=pod

=head1 Attribute Methods

=cut 

#-----------------------------------------------
sub get_attributes {

=pod

=head2 get_attributes()

=over 4

=item * Description

Retrieves the attributes attached to a database object.

=item * Adaptor Writing Info

This will require conversion from object type to a table.

See the get_all flag.

=item * Required Input

=over 4

=back

=item * Optional Input

=over 4

=item - Object type such as feature or map_set (object_type)

=item - Object ID (object_id) 

=item - attribute_id (attribute_id)

=item - is_public (is_public)

=item - attribute_name (attribute_name)

=item - attribute_value (attribute_value)

=item - Order by clause (order_by)

=item - Get All Flag (get_all)

Boolean value.  If set to 1, return all without regard to whether object_id is
null.  Specifying an object_id overrides this.

=back

=item * Output

Array of Hashes:

  Keys:
    attribute_id,
    object_id,
    table_name,
    display_order,
    is_public,
    attribute_name,
    attribute_value
    object_type

=item * Cache Level (Not Used): 4

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object     => 0,
        no_validation   => 0,
        object_type     => 0,
        attribute_id    => 0,
        is_public       => 0,
        attribute_name  => 0,
        attribute_value => 0,
        object_id       => 0,
        order_by        => 0,
        get_all         => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $object_type = $args{'object_type'};
    die "Object type: $object_type not valid.  \n<br>"
        . "Method giving error: get_attributes<br>"
        . "Calling information:<pre>"
        . Dumper( caller() )
        . "</pre>\n"
        if ( $object_type and not $self->{'TABLE_NAMES'}->{$object_type} );
    my $attribute_id    = $args{'attribute_id'};
    my $is_public       = $args{'is_public'};
    my $attribute_name  = $args{'attribute_name'};
    my $attribute_value = $args{'attribute_value'};
    my $object_id       = $args{'object_id'};
    my $order_by        = $args{'order_by'};
    die "Order by clause ($order_by) has SQL code in it\n"
        if ( has_sql_command($order_by) );
    my $get_all = $args{'get_all'} || 0;
    my $db = $self->db;
    my $return_object;
    my $table_name;
    my @identifiers = ();

    unless ( $object_type || $attribute_id || $get_all ) {
        return $self->error('No object type or attribute_id');
    }

    if ($object_type) {
        $table_name = $self->{'TABLE_NAMES'}->{$object_type};
    }
    if ( !$order_by || $order_by eq 'display_order' ) {
        $order_by = 'display_order,attribute_name';
    }

    my $sql_str = qq[
        select   attribute_id,
                 object_id,
                 table_name,
                 display_order,
                 is_public,
                 attribute_name,
                 attribute_value
        from     cmap_attribute
    ];
    my $where_sql    = '';
    my $order_by_sql = '';
    if ($attribute_id) {
        push @identifiers, $attribute_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " attribute_id = ? ";
    }
    if ($attribute_name) {
        push @identifiers, $attribute_name;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " attribute_name = ? ";
    }
    if ($attribute_value) {
        push @identifiers, $attribute_value;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " attribute_value = ? ";
    }
    if ($table_name) {
        push @identifiers, $table_name;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " table_name = ? ";
    }

    if ($object_id) {
        push @identifiers, $object_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " object_id=? ";
    }
    elsif ( !$get_all ) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " object_id is not null ";
    }

    if ($order_by) {
        $order_by_sql .= " order by $order_by ";
    }

    $sql_str .= $where_sql . $order_by_sql;

    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} },
        @identifiers );

    foreach my $row (@$return_object) {
        $row->{'object_type'}
            = $self->{'OBJECT_TYPES'}->{ $row->{'table_name'} };
        delete( $row->{'table_name'} );
    }

    return $return_object;
}

#-----------------------------------------------
sub insert_attribute {

=pod

=head2 insert_attribute()

=over 4

=item * Description

Insert an attribute into the database.

=item * Adaptor Writing Info

The required inputs are only the ones that the database requires.

If you don't want CMap to insert into your database, make this a dummy method.

This will require conversion from object type to a table.

=item * Input

=over 4

=item - Display Order (display_order)

=item - Object type such as feature or map_set (object_type)

=item - is_public (is_public)

=item - attribute_name (attribute_name)

=item - attribute_value (attribute_value)

=item - Object ID (object_id)

=back

=item * Output

Attribute id

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object     => 0,
        no_validation   => 0,
        display_order   => 0,
        object_type     => 0,
        is_public       => 0,
        attribute_name  => 0,
        attribute_value => 0,
        object_id       => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $db = $self->db;
    my $attribute_id = $self->next_number( object_type => 'attribute', )
        or return $self->error('No next number for attribute ');
    my $display_order = $args{'display_order'} || 1;
    my $object_type = $args{'object_type'};
    die "Object type: $object_type not valid.  \n<br>"
        . "Method giving error: insert_attribute<br>"
        . "Calling information:<pre>"
        . Dumper( caller() )
        . "</pre>\n"
        if ( $object_type and not $self->{'TABLE_NAMES'}->{$object_type} );
    my $is_public      = $args{'is_public'}      || 1;
    my $attribute_name = $args{'attribute_name'} || q{};
    my $attribute_value
        = defined( $args{'attribute_value'} )
        ? $args{'attribute_value'}
        : q{};
    my $object_id   = $args{'object_id'};
    my $table_name  = $self->{'TABLE_NAMES'}->{$object_type} if $object_type;
    my @insert_args = (
        $attribute_id, $table_name, $object_id, $attribute_value,
        $attribute_name, $is_public, $display_order
    );

    unless ( defined($display_order) ) {
        $display_order = $db->selectrow_array(
            q[
                select max(display_order)
                from   cmap_attribute
                where  table_name=?
                and    object_id=?
            ],
            {},
            ( $table_name, $object_id )
        );
        $display_order++;
    }

    $db->do(
        qq[
        insert into cmap_attribute
        (attribute_id,table_name,object_id,attribute_value,attribute_name,is_public,display_order )
         values ( ?,?,?,?,?,?,? )
        ],
        {},
        (@insert_args)
    );

    return $attribute_id;
}

#-----------------------------------------------
sub update_attribute {

=pod

=head2 update_attribute()

=over 4

=item * Description

Given the id and some attributes to modify, updates.

=item * Adaptor Writing Info

This will require conversion from object type to a table.

If you don't want CMap to update into your database, make this a dummy method.

=item * Required Input

=over 4

=item - attribute_id (attribute_id)

=back

=item * Inputs To Update

=over 4

=item - Display Order (display_order)

=item - Object type such as feature or map_set (object_type)

=item - is_public (is_public)

=item - attribute_name (attribute_name)

=item - attribute_value (attribute_value)

=item - Object ID (object_id)

=back

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object     => 0,
        no_validation   => 0,
        attribute_id    => 1,
        display_order   => 0,
        object_type     => 0,
        is_public       => 0,
        attribute_name  => 0,
        attribute_value => 0,
        object_id       => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $attribute_id  = $args{'attribute_id'} or return;
    my $display_order = $args{'display_order'};
    my $object_type   = $args{'object_type'};
    die "Object type: $object_type not valid.  \n<br>"
        . "Method giving error: update_attribute<br>"
        . "Calling information:<pre>"
        . Dumper( caller() )
        . "</pre>\n"
        if ( $object_type and not $self->{'TABLE_NAMES'}->{$object_type} );
    my $is_public       = $args{'is_public'};
    my $attribute_name  = $args{'attribute_name'};
    my $attribute_value = $args{'attribute_value'};
    my $object_id       = $args{'object_id'};
    my $db              = $self->db;

    my $table_name;
    if ($object_type) {
        $table_name = $self->{'TABLE_NAMES'}->{$object_type};
    }

    my @update_args = ();
    my $update_sql  = qq[
        update cmap_attribute 
    ];
    my $set_sql   = '';
    my $where_sql = " where attribute_id = ? ";    # ID

    if ($display_order) {
        push @update_args, $display_order;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " display_order = ? ";
    }
    if ( defined($is_public) ) {
        push @update_args, $is_public;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " is_public = ? ";
    }
    if ($table_name) {
        push @update_args, $table_name;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " table_name = ? ";
    }
    if ($attribute_name) {
        push @update_args, $attribute_name;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " attribute_name = ? ";
    }
    if ($attribute_value) {
        push @update_args, $attribute_value;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " attribute_value = ? ";
    }
    if ($object_id) {
        push @update_args, $object_id;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " object_id = ? ";
    }

    push @update_args, $attribute_id;

    my $sql_str = $update_sql . $set_sql . $where_sql;
    $db->do( $sql_str, {}, @update_args );

}

#-----------------------------------------------
sub delete_attribute {

=pod

=head2 delete_attribute()

=over 4

=item * Description

Given the id, the object_type or the object_id, delete this object.

=item * Adaptor Writing Info

This will require conversion from object type to a table.

If you don't want CMap to delete from your database, make this a dummy method.

=item * Input

=over 4

=back

=item * Requred At Least One Input

=over 4

=item - attribute_id (attribute_id)

=item - Object type such as feature or map_set (object_type)

=item - Object ID (object_id)

=back

=item * Output

1

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        attribute_id  => 0,
        object_type   => 0,
        object_id     => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $db           = $self->db;
    my $attribute_id = $args{'attribute_id'};
    my $object_type  = $args{'object_type'};
    die "Object type: $object_type not valid.  \n<br>"
        . "Method giving error: delete_attribute<br>"
        . "Calling information:<pre>"
        . Dumper( caller() )
        . "</pre>\n"
        if ( $object_type and not $self->{'TABLE_NAMES'}->{$object_type} );
    my $object_id   = $args{'object_id'};
    my $table_name  = $self->{'TABLE_NAMES'}->{$object_type} if $object_type;
    my @delete_args = ();
    my $delete_sql  = qq[
        delete from cmap_attribute
    ];
    my $where_sql = '';

    return unless ( $object_id or $table_name or $attribute_id );

    if ($object_id) {
        push @delete_args, $object_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " object_id = ? ";
    }
    if ($table_name) {
        push @delete_args, $table_name;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " table_name = ? ";
    }
    if ($attribute_id) {
        push @delete_args, $attribute_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " attribute_id = ? ";
    }

    $delete_sql .= $where_sql;
    $db->do( $delete_sql, {}, (@delete_args) );

    return 1;
}

=pod

=head1 Xref Methods

=cut 

#-----------------------------------------------
sub get_xrefs {

=pod

=head2 get_xrefs()

=over 4

=item * Description

Retrieves the attributes attached to a database object.

=item * Adaptor Writing Info

This will require conversion from object type to a table.

=item * Required Input

=over 4

=back

=item * Optional Input

=over 4

=item - Object type such as feature or map_set (object_type)

=item - Object ID (object_id)

=item - xref_id (xref_id)

=item - xref_name (xref_name)

=item - xref_url (xref_url)

=item - Order by clause (order_by)

=back

=item * Output

Array of Hashes:

  Keys:
    xref_id
    object_id
    display_order
    xref_name
    xref_url
    object_type

=item * Cache Level (Not Used): 4

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        object_type   => 0,
        xref_id       => 0,
        xref_name     => 0,
        xref_url      => 0,
        object_id     => 0,
        order_by      => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $object_type = $args{'object_type'};
    die "Object type: $object_type not valid.  \n<br>"
        . "Method giving error: get_xrefs<br>"
        . "Calling information:<pre>"
        . Dumper( caller() )
        . "</pre>\n"
        if ( $object_type and not $self->{'TABLE_NAMES'}->{$object_type} );
    my $xref_id   = $args{'xref_id'};
    my $xref_name = $args{'xref_name'};
    my $xref_url  = $args{'xref_url'};
    my $object_id = $args{'object_id'};
    my $order_by  = $args{'order_by'};
    die "Order by clause ($order_by) has SQL code in it\n"
        if ( has_sql_command($order_by) );
    my $db = $self->db;
    my $return_object;
    my @identifiers = ();

    my $table_name;
    if ($object_type) {
        $table_name = $self->{'TABLE_NAMES'}->{$object_type};
    }
    if ( !$order_by || $order_by eq 'display_order' ) {
        $order_by = 'display_order,xref_name';
    }

    my $sql_str = qq[
        select   xref_id,
                 object_id,
                 table_name,
                 display_order,
                 xref_name,
                 xref_url
        from     cmap_xref
    ];
    my $where_sql    = '';
    my $order_by_sql = '';
    if ($table_name) {
        push @identifiers, $table_name;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " table_name = ? ";
    }

    if ($object_id) {
        push @identifiers, $object_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " object_id=? ";
    }
    if ($xref_id) {
        push @identifiers, $xref_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " xref_id=? ";
    }
    if ($xref_url) {
        push @identifiers, $xref_url;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " xref_url=? ";
    }
    if ($xref_name) {
        push @identifiers, $xref_name;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " xref_name=? ";
    }

    if ($order_by) {
        $order_by_sql .= " order by $order_by ";
    }

    $sql_str .= $where_sql . $order_by_sql;

    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} },
        @identifiers );

    foreach my $row (@$return_object) {
        $row->{'object_type'}
            = $self->{'OBJECT_TYPES'}->{ $row->{'table_name'} };
        delete( $row->{'table_name'} );
    }

    return $return_object;
}

#-----------------------------------------------
sub get_generic_xrefs {

=pod

=head2 get_generic_xrefs()

=over 4

=item * Description

Retrieves the attributes attached to all generic objects.  That means
attributes attached to all features and all maps, etc NOT any specific features or maps.

=item * Adaptor Writing Info

Your database may have a different way of handling references to the generic objects.

=item * Required Input

=over 4

=back

=item * Optional Input

=over 4

=item * object_type (object_type)
                                                                                                                             
=item * order_by (order_by)

=back

=item * Output

Array of Hashes:

  Keys:
    xref_id,
    object_type,
    display_order,
    xref_name,
    xref_url

=item * Cache Level (If Used): 4

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        object_type   => 0,
        order_by      => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $object_type = $args{'object_type'};
    die "Object type: $object_type not valid.  \n<br>"
        . "Method giving error: get_generic_xrefs<br>"
        . "Calling information:<pre>"
        . Dumper( caller() )
        . "</pre>\n"
        if ( $object_type and not $self->{'TABLE_NAMES'}->{$object_type} );
    my $order_by = $args{'order_by'};
    die "Order by clause ($order_by) has SQL code in it\n"
        if ( has_sql_command($order_by) );
    my $db = $self->db;
    my $return_object;

    my $sql_str = qq[
        select xref_id,
               table_name,
               display_order,
               xref_name,
               xref_url
        from   cmap_xref
        where  (object_id is null
        or     object_id=0)
    ];
    if ($object_type) {
        my $table_name = $self->{'TABLE_NAMES'}->{$object_type};
        $sql_str .= " and table_name = " . $db->quote($table_name) . " ";
    }

    if ($order_by) {
        $sql_str .= " order by $order_by ";
    }

    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} } );
    foreach my $row (@$return_object) {
        $row->{'object_type'}
            = $self->{'OBJECT_NAMES'}->{ $row->{'table_name'} };
        delete( $row->{'table_name'} );
    }

    return $return_object;
}

#-----------------------------------------------
sub insert_xref {

=pod

=head2 insert_xref()

=over 4

=item * Description

Insert an xref into the database.

=item * Adaptor Writing Info

This will require conversion from object type to a table.

The required inputs are only the ones that the database requires.

If you don't want CMap to insert into your database, make this a dummy method.

=item * Input

=over 4

=item - Display Order (display_order)

=item - Object type such as feature or map_set (object_type)

=item - xref_name (xref_name)

=item - xref_url (xref_url)

=item - Object ID (object_id)

=back

=item * Output

Xref id

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        display_order => 0,
        object_type   => 0,
        xref_name     => 0,
        xref_url      => 0,
        object_id     => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $db = $self->db;
    my $xref_id = $self->next_number( object_type => 'xref', )
        or return $self->error('No next number for xref ');
    my $display_order = $args{'display_order'} || 1;
    my $object_type = $args{'object_type'};
    die "Object type: $object_type not valid.  \n<br>"
        . "Method giving error: insert_xref<br>"
        . "Calling information:<pre>"
        . Dumper( caller() )
        . "</pre>\n"
        if ( $object_type and not $self->{'TABLE_NAMES'}->{$object_type} );
    my $xref_name = $args{'xref_name'} || q{};
    my $xref_url  = $args{'xref_url'}  || q{};
    my $object_id = $args{'object_id'};
    my $table_name = $self->{'TABLE_NAMES'}->{$object_type} if $object_type;

    unless ( defined($display_order) ) {
        $display_order = $db->selectrow_array(
            q[
                select max(display_order)
                from   cmap_xref
                where  table_name=?
                and    object_id=?
            ],
            {},
            ( $table_name, $object_id )
        );
        $display_order++;
    }
    my @insert_args = (
        $xref_id,  $table_name, $object_id,
        $xref_url, $xref_name,  $display_order
    );

    $db->do(
        qq[
        insert into cmap_xref
        (xref_id,table_name,object_id,xref_url,xref_name,display_order )
         values ( ?,?,?,?,?,? )
        ],
        {},
        (@insert_args)
    );

    return $xref_id;
}

#-----------------------------------------------
sub update_xref {

=pod

=head2 update_xref()

=over 4

=item * Description

Given the id and some attributes to modify, updates.

=item * Adaptor Writing Info

This will require conversion from object type to a table.

If you don't want CMap to update into your database, make this a dummy method.

=item * Required Input

=over 4

=item - xref_id (xref_id)

=back

=item * Inputs To Update

=over 4

=item - Display Order (display_order)

=item - Object type such as feature or map_set (object_type)

=item - xref_name (xref_name)

=item - xref_url (xref_url)

=item - Object ID (object_id)

=item - is_public (is_public)

=back

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        xref_id       => 1,
        display_order => 0,
        object_type   => 0,
        xref_name     => 0,
        xref_url      => 0,
        object_id     => 0,
        is_public     => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $xref_id       = $args{'xref_id'} or return;
    my $display_order = $args{'display_order'};
    my $object_type   = $args{'object_type'};
    die "Object type: $object_type not valid.  \n<br>"
        . "Method giving error: update_xref<br>"
        . "Calling information:<pre>"
        . Dumper( caller() )
        . "</pre>\n"
        if ( $object_type and not $self->{'TABLE_NAMES'}->{$object_type} );
    my $xref_name = $args{'xref_name'};
    my $xref_url  = $args{'xref_url'};
    my $object_id = $args{'object_id'};
    my $is_public = $args{'is_public'};
    my $db        = $self->db;

    my $table_name;
    if ($object_type) {
        $table_name = $self->{'TABLE_NAMES'}->{$object_type};
    }

    my @update_args = ();
    my $update_sql  = qq[
        update cmap_xref 
    ];
    my $set_sql   = '';
    my $where_sql = " where xref_id = ? ";    # ID

    if ($display_order) {
        push @update_args, $display_order;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " display_order = ? ";
    }
    if ( defined($is_public) ) {
        push @update_args, $is_public;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " is_public = ? ";
    }
    if ($table_name) {
        push @update_args, $table_name;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " table_name = ? ";
    }
    if ($xref_name) {
        push @update_args, $xref_name;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " xref_name = ? ";
    }
    if ($xref_url) {
        push @update_args, $xref_url;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " xref_url = ? ";
    }
    if ($object_id) {
        push @update_args, $object_id;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " object_id = ? ";
    }

    push @update_args, $xref_id;

    my $sql_str = $update_sql . $set_sql . $where_sql;
    $db->do( $sql_str, {}, @update_args );

}

#-----------------------------------------------
sub delete_xref {

=pod

=head2 delete_xref()

=over 4

=item * Description

Given the id, the object_type or the object_id, delete this object.

=item * Adaptor Writing Info

This will require conversion from object type to a table.

If you don't want CMap to delete from your database, make this a dummy method.

=item * Input

=over 4

=back

=item * Requred At Least One Input

=over 4

=item - xref_id (xref_id)

=item - Object type such as feature or map_set (object_type)

=item - Object ID (object_id)

=back

=item * Output

1

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        xref_id       => 0,
        object_type   => 0,
        object_id     => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $db          = $self->db;
    my $xref_id     = $args{'xref_id'};
    my $object_type = $args{'object_type'};
    die "Object type: $object_type not valid.  \n<br>"
        . "Method giving error: delete_xref<br>"
        . "Calling information:<pre>"
        . Dumper( caller() )
        . "</pre>\n"
        if ( $object_type and not $self->{'TABLE_NAMES'}->{$object_type} );
    my $object_id   = $args{'object_id'};
    my $table_name  = $self->{'TABLE_NAMES'}->{$object_type} if $object_type;
    my @delete_args = ();
    my $delete_sql  = qq[
        delete from cmap_xref
    ];
    my $where_sql = '';

    return unless ( $object_id or $table_name or $xref_id );

    if ($object_id) {
        push @delete_args, $object_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " object_id = ? ";
    }
    if ($table_name) {
        push @delete_args, $table_name;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " table_name = ? ";
    }
    if ($xref_id) {
        push @delete_args, $xref_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " xref_id = ? ";
    }

    $delete_sql .= $where_sql;
    $db->do( $delete_sql, {}, (@delete_args) );

    return 1;
}

=pod

=head1 map_to_feature Methods

=cut 

sub get_map_to_feature {&get_map_to_features}

#-----------------------------------------------
sub get_map_to_features {

=pod

=head2 get_map_to_features()

=over 4

=item * Description

Get the map_to_feature information into the database.

=item * Adaptor Writing Info

=item * Input

=over 4

=item - Map ID (map_id) 

=item - Map Accession (map_acc)

=item - Feature ID (feature_id)

=item - Feature Accession (feature_acc)

=back

=item * Output

Array of Hashes:

  Keys:
    map_id,
    map_acc,
    feature_id,
    feature_acc,

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        map_id        => 0,
        map_acc       => 0,
        feature_id    => 0,
        feature_acc   => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $db          = $self->db;
    my $map_id      = $args{'map_id'};
    my $feature_id  = $args{'feature_id'};
    my $map_acc     = $args{'map_acc'};
    my $feature_acc = $args{'feature_acc'};

    my @identifiers;
    my $select_sql = qq[
        select  mtf.map_id,
                mtf.map_acc,
                mtf.feature_id,
                mtf.feature_acc
    ];
    my $from_sql = qq[
        from    cmap_map_to_feature mtf
    ];
    my $where_sql = q{};

    my @where_list;
    if ( defined $map_id ) {
        push @where_list,  " map_id = ? ";
        push @identifiers, $map_id;
    }
    elsif ( defined $map_acc ) {
        push @where_list,  " map_acc = ? ";
        push @identifiers, $map_acc;
    }
    if ( defined $feature_id ) {
        push @where_list,  " feature_id = ? ";
        push @identifiers, $feature_id;
    }
    elsif ( defined $feature_acc ) {
        push @where_list,  " feature_acc = ? ";
        push @identifiers, $feature_acc;
    }

    if (@where_list) {
        $where_sql = ' where ' . join " and ", @where_list;
    }

    my $sql_str = $select_sql . $from_sql . $where_sql;

    my $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} },
        @identifiers );

    return $return_object;
}

#-----------------------------------------------
sub insert_map_to_feature {

=pod

=head2 insert_map_to_feature()

=over 4

=item * Description

Insert the map_to_feature information into the database.

=item * Adaptor Writing Info

The required inputs are only the ones that the database requires.

If you don't want CMap to insert into your database, make this a dummy method.

=item * Input

=over 4

=item - Map ID (map_id) (required unless map_acc is defined)

=item - Map Accession (map_acc)

=item - Feature ID (feature_id) (required unless feature_acc is defined)

=item - Feature Accession (feature_acc)

=back

=item * Output

1

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        map_id        => 0,
        map_acc       => 0,
        feature_id    => 0,
        feature_acc   => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $db          = $self->db;
    my $map_id      = $args{'map_id'};
    my $feature_id  = $args{'feature_id'};
    my $map_acc     = $args{'map_acc'};
    my $feature_acc = $args{'feature_acc'};

    if (   not( defined $map_acc or defined $map_id )
        or not( defined $feature_acc or defined $feature_id ) )
    {
        die "Missing map or feature in insert_map_to_feature";
    }

    if ( not defined $map_acc ) {
        $map_acc = $self->internal_id_to_acc_id(
            id          => $map_id,
            object_type => 'map',
        );
    }
    elsif ( not defined $map_id ) {
        $map_id = $self->acc_id_to_internal_id(
            acc_id      => $map_acc,
            object_type => 'map',
        );
    }

    if ( not defined $feature_acc ) {
        $feature_acc = $self->internal_id_to_acc_id(
            id          => $feature_id,
            object_type => 'feature',
        );
    }
    elsif ( not defined $feature_id ) {
        $feature_id = $self->acc_id_to_internal_id(
            acc_id      => $feature_acc,
            object_type => 'feature',
        );
    }

    unless (defined $map_acc
        and defined $map_id
        and defined $feature_acc
        and defined $feature_id )
    {
        die "Missing map or feature in insert_map_to_feature";
    }

    my @insert_args = ( $map_id, $map_acc, $feature_id, $feature_acc );

    $db->do(
        qq[
        insert into cmap_map_to_feature
        ( map_id, map_acc, feature_id, feature_acc )
         values ( ?,?,?,? )
        ],
        {},
        (@insert_args)
    );

    return 1;
}

#-----------------------------------------------
sub delete_map_to_feature {

=pod

=head2 delete_map_to_feature()

=over 4

=item * Description

Delete the rows that match all of the identifiers given.  Supplying just a
feature ID will delete all rows that have that feature ID.

=item * Adaptor Writing Info

If you don't want CMap to delete from your database, make this a dummy method.

=item * Input

=over 4

=item - Map ID (map_id)

=item - Map Accession (map_acc)

=item - Feature ID (feature_id)

=item - Feature Accession (feature_acc)


=back

=item * Output

1

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        map_id        => 0,
        map_acc       => 0,
        feature_id    => 0,
        feature_acc   => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $db          = $self->db;
    my $map_id      = $args{'map_id'};
    my $feature_id  = $args{'feature_id'};
    my $map_acc     = $args{'map_acc'};
    my $feature_acc = $args{'feature_acc'};
    unless ( $map_id or $feature_id or $map_acc or $feature_acc ) {
        return $self->error('No identifiers given to delete ');
    }
    my @delete_args = ();
    my $delete_sql  = qq[
        delete from cmap_map_to_feature
    ];
    my $where_sql = '';

    if ($map_id) {
        push @delete_args, $map_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " map_id = ? ";
    }
    if ($map_acc) {
        push @delete_args, $map_acc;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " map_acc = ? ";
    }
    if ($feature_id) {
        push @delete_args, $feature_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " feature_id = ? ";
    }
    if ($feature_acc) {
        push @delete_args, $feature_acc;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " feature_acc = ? ";
    }

    $delete_sql .= $where_sql;
    $db->do( $delete_sql, {}, (@delete_args) );

    return 1;
}

=pod

=head1 Commit Transaction Methods

=cut 

#-----------------------------------------------
sub get_transactions {

=pod

=head2 get_transactions()

=over 4

=item * Description

=item * Adaptor Writing Info

=item * Input

=over 4

=item - Transaction ID (transaction_id)

=back

=item * Output

Array of Hashes:

  Keys:
    transaction_id
    transaction_date

=item * Cache Level (If Used): 

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object    => 0,
        no_validation  => 0,
        transaction_id => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $transaction_id = $args{'commit_log_id'};

    my @identifiers;

    my $select_sql = qq[
        select  
        transaction_id,
        transaction_date
    ];
    my $from_sql = qq[
        from    cmap_transaction
    ];
    my $where_sql = qq[ ];
    my @where_terms;

    if ( defined($transaction_id) ) {
        push @identifiers, $transaction_id;
        push @where_terms, " transaction_id = ? ";
    }

    if (@where_terms) {
        $where_sql .= " where " . join( "\n and ", @where_terms );
    }

    my $sql_str = $select_sql . $from_sql . $where_sql;

    my $db = $self->db;
    my $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} },
        @identifiers );

    return $return_object;
}

#-----------------------------------------------
sub insert_transaction {

=pod

=head2 insert_transaction()

=over 4

=item * Description

Insert into the database.

=item * Adaptor Writing Info

The required inputs are only the ones that the database requires.

If you don't want CMap to insert into your database, make this a dummy method.

=item * No Inputs

=over 4

=back

=item * Output

transaction_id

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $time             = localtime();
    my $transaction_date = $time->strftime( $self->date_format );

    my $db = $self->db;
    my $transaction_id = $self->next_number( object_type => 'transaction', )
        or return $self->error('No next number for transaction ');
    my @insert_args = ( $transaction_id, $transaction_date, );

    $db->do(
        qq[
        insert into cmap_transaction
        (
            transaction_id,
            transaction_date
        )
         values ( ?,? )
        ],
        {},
        (@insert_args)
    );

    return $transaction_id;
}

#-----------------------------------------------
sub delete_transaction {

=pod

=head2 delete_transaction()

=over 4

=item * Description

Given the id, delete this object.

=item * Adaptor Writing Info

If you don't want CMap to delete from your database, make this a dummy method.

=item * Input

=over 4

=item - Transaction ID (transaction_id)

=back

=item * Output

1

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object    => 0,
        no_validation  => 0,
        transaction_id => 0,
    );

    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};
    my $transaction_id = $args{'transaction_id'};

    my $db          = $self->db;
    my @delete_args = ();
    my $delete_sql  = qq[
        delete from cmap_transaction
    ];
    my $where_sql = '';

    if ($transaction_id) {
        push @delete_args, $transaction_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " transaction_id = ? ";
    }

    return unless (@delete_args);

    $delete_sql .= $where_sql;
    $db->do( $delete_sql, {}, (@delete_args) );

    return 1;
}

=pod

=head1 Commit Log Methods

=cut 

#-----------------------------------------------
sub get_commit_logs {

=pod

=head2 get_commit_logs()

=over 4

=item * Description

=item * Adaptor Writing Info

=item * Input

=over 4

=item - Commit Log ID (commit_log_id)

=item - Transaction ID (transaction_id)

=item - Species ID (species_id)

=item - Species Accession (species_acc)

=item - Map Set ID (map_set_id)

=item - Map Set Accession (map_set_acc)

=item - Map ID (map_id)

=item - Map Accession (map_acc)

=item - Type of Commit (commit_type)

=back

=item * Output

Array of Hashes:

  Keys:
    commit_log_id
    transaction_id
    species_id
    species_acc
    map_set_id
    map_set_acc
    map_id
    map_acc
    commit_type
    commit_text
    commit_object
    commit_date

=item * Cache Level (If Used): 

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object    => 0,
        no_validation  => 0,
        species_acc    => 0,
        species_id     => 0,
        map_set_acc    => 0,
        map_set_id     => 0,
        map_acc        => 0,
        map_id         => 0,
        commit_type    => 0,
        commit_log_id  => 0,
        transaction_id => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $species_acc    = $args{'species_acc'};
    my $species_id     = $args{'species_id'};
    my $map_set_acc    = $args{'map_set_acc'};
    my $map_set_id     = $args{'map_set_id'};
    my $map_acc        = $args{'map_acc'};
    my $map_id         = $args{'map_id'};
    my $commit_type    = $args{'commit_type'};
    my $commit_log_id  = $args{'commit_log_id'};
    my $transaction_id = $args{'commit_log_id'};

    my @identifiers;

    my $select_sql = qq[
        select  
        commit_log_id,
        transaction_id,
        species_id,
        species_acc,
        map_set_id,
        map_set_acc,
        map_id,
        map_acc,
        commit_type,
        commit_text,
        commit_object
    ];
    my $from_sql = qq[
        from    cmap_commit_log
    ];
    my $where_sql = qq[ ];
    my @where_terms;

    if ( defined($commit_log_id) ) {
        push @identifiers, $commit_log_id;
        push @where_terms, " commit_log_id = ? ";
    }

    if ( defined($transaction_id) ) {
        push @identifiers, $transaction_id;
        push @where_terms, " transaction_id = ? ";
    }

    if ( defined($commit_type) ) {
        push @identifiers, $commit_type;
        push @where_terms, " commit_type = ? ";
    }

    if ( defined($species_id) ) {
        push @identifiers, $species_id;
        push @where_terms, " species_id = ? ";
    }
    elsif ( defined($species_acc) ) {
        push @identifiers, $species_acc;
        push @where_terms, " species_acc = ? ";
    }

    if ( defined($map_set_id) ) {
        push @identifiers, $map_set_id;
        push @where_terms, " map_set_id = ? ";
    }
    elsif ( defined($map_set_acc) ) {
        push @identifiers, $map_set_acc;
        push @where_terms, " map_set_acc = ? ";
    }

    if ( defined($map_id) ) {
        push @identifiers, $map_id;
        push @where_terms, " map_id = ? ";
    }
    elsif ( defined($map_acc) ) {
        push @identifiers, $map_acc;
        push @where_terms, " map_acc = ? ";
    }

    if (@where_terms) {
        $where_sql .= " where " . join( "\n and ", @where_terms );
    }

    my $sql_str = $select_sql . $from_sql . $where_sql;

    my $db = $self->db;
    my $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} },
        @identifiers );

    return $return_object;
}

#-----------------------------------------------
sub insert_commit_log {

=pod

=head2 insert_commit_log()

=over 4

=item * Description

Insert into the database.

=item * Adaptor Writing Info

The required inputs are only the ones that the database requires.

If you don't want CMap to insert into your database, make this a dummy method.

=item * Input

=over 4

=item - Commit Log ID (commit_log_id)

=item - Transaction ID (transaction_id)

=item - Species ID (species_id)

=item - Species Accession (species_acc)

=item - Map Set ID (map_set_id)

=item - Map Set Accession (map_set_acc)

=item - Map ID (map_id)

=item - Map Accession (map_acc)

=item - Type of Commit (commit_type)

=item - Commit Text (commit_text)

=item - Commit Object (commit_object)

=item - Date of Commit (commit_date)

=back

=item * Output

commit_log_id

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object    => 0,
        no_validation  => 0,
        transaction_id => 0,
        species_acc    => 0,
        species_id     => 0,
        map_set_acc    => 0,
        map_set_id     => 0,
        map_acc        => 0,
        map_id         => 0,
        commit_type    => 1,
        commit_text    => 1,
        commit_object  => 1,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};
    my $transaction_id = $args{'transaction_id'};
    my $species_acc    = $args{'species_acc'};
    my $species_id     = $args{'species_id'};
    my $map_set_acc    = $args{'map_set_acc'};
    my $map_set_id     = $args{'map_set_id'};
    my $map_acc        = $args{'map_acc'};
    my $map_id         = $args{'map_id'};
    my $commit_type    = $args{'commit_type'};
    my $commit_text    = $args{'commit_text'};
    my $commit_object  = $args{'commit_object'};
    my $time           = localtime();
    my $commit_date    = $time->strftime( $self->date_format );

    $transaction_id ||= $self->insert_transaction();

    my $db = $self->db;
    my $commit_log_id = $self->next_number( object_type => 'commit_log', )
        or return $self->error('No next number for commit_log ');
    my @insert_args = (
        $commit_log_id, $transaction_id, $species_id,    $species_acc,
        $map_set_id,    $map_set_acc,    $map_id,        $map_acc,
        $commit_type,   $commit_text,    $commit_object, $commit_date,
    );

    $db->do(
        qq[
        insert into cmap_commit_log
        (
            commit_log_id,
            transaction_id,
            species_id,
            species_acc,
            map_set_id,
            map_set_acc,
            map_id,
            map_acc,
            commit_type,
            commit_text,
            commit_object,
            commit_date
        )
         values ( ?,?,?,?,?,?,?,?,?,?,?,? )
        ],
        {},
        (@insert_args)
    );

    return $commit_log_id;
}

#-----------------------------------------------
sub delete_commit_log {

=pod

=head2 delete_commit_log()

=over 4

=item * Description

Given the id, delete this object.

=item * Adaptor Writing Info

If you don't want CMap to delete from your database, make this a dummy method.

=item * Input

=over 4

=item - Commit Log ID (commit_log_id)

=item - Transaction ID (transaction_id)

=item - Species ID (species_id)

=item - Map Set ID (map_set_id)

=item - Map ID (map_id)

=item - Type of Commit (commit_type)

=back

=item * Output

1

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object    => 0,
        no_validation  => 0,
        species_id     => 0,
        map_set_id     => 0,
        map_id         => 0,
        commit_type    => 0,
        commit_log_id  => 0,
        transaction_id => 0,
    );

    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};
    my $species_id     = $args{'species_id'};
    my $map_set_id     = $args{'map_set_id'};
    my $map_id         = $args{'map_id'};
    my $commit_type    = $args{'commit_type'};
    my $commit_log_id  = $args{'commit_log_id'};
    my $transaction_id = $args{'transaction_id'};

    my $db          = $self->db;
    my @delete_args = ();
    my $delete_sql  = qq[
        delete from cmap_commit_log
    ];
    my $where_sql = '';

    if ($species_id) {
        push @delete_args, $species_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " species_id = ? ";
    }
    if ($map_set_id) {
        push @delete_args, $map_set_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " map_set_id = ? ";
    }
    if ($map_id) {
        push @delete_args, $map_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " map_id = ? ";
    }
    if ($commit_log_id) {
        push @delete_args, $commit_log_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " commit_log_id = ? ";
    }
    if ($transaction_id) {
        push @delete_args, $transaction_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " transaction_id = ? ";
    }
    if ($commit_type) {
        push @delete_args, $commit_type;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " commit_type = ? ";
    }

    return unless (@delete_args);

    $delete_sql .= $where_sql;
    $db->do( $delete_sql, {}, (@delete_args) );

    return 1;
}

=pod

=head1 Object Type Methods

=cut 

#-----------------------------------------------
sub get_used_feature_types {

=pod

=head2 get_used_feature_types()

=over 4

=item * Description

Get feature type info for features that are actually used.

=item * Required Input

=over 4

=back

=item * Optional Input

=over 4

=item - List of Map IDs (map_ids)

=item - List of Map Set IDs (map_set_ids)

=item - List of feature types to check (included_feature_type_accs)

=back

=item * Output

Array of Hashes:

  Keys:
    feature_type_acc,
    feature_type,
    shape,
    color

=item * Cache Level: 3

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object                => 0,
        no_validation              => 0,
        map_ids                    => 0,
        map_set_ids                => 0,
        included_feature_type_accs => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $map_ids     = $args{'map_ids'}     || [];
    my $map_set_ids = $args{'map_set_ids'} || [];
    my $included_feature_type_accs = $args{'included_feature_type_accs'}
        || [];
    my $db                = $self->db;
    my $feature_type_data = $self->feature_type_data();
    my $return_object;

    my $sql_str = qq[
        select   distinct
                 f.feature_type_acc
        from     cmap_feature f
    ];
    my $where_sql = '';

    if (@$map_ids) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " f.map_id in ("
            . join( ",", map { $db->quote($_) } sort @$map_ids ) . ")";
    }
    if (@$map_set_ids) {
        $sql_str   .= ", cmap_map map ";
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " f.map_id = map.map_id ";
        $where_sql .= " and map.map_set_id in ("
            . join( ",", map { $db->quote($_) } sort @$map_set_ids ) . ")";
    }
    if (@$included_feature_type_accs) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " f.feature_type_acc in ("
            . join( ",",
            map { $db->quote($_) } sort @$included_feature_type_accs )
            . ") ";
    }

    $sql_str .= $where_sql;

    unless ( $return_object = $self->get_cached_results( 3, $sql_str ) ) {
        $return_object
            = $db->selectall_arrayref( $sql_str, { Columns => {} }, () );
        foreach my $row (@$return_object) {
            $row->{'feature_type'}
                = $feature_type_data->{ $row->{'feature_type_acc'} }
                {'feature_type'};
            $row->{'shape'}
                = $feature_type_data->{ $row->{'feature_type_acc'} }{'shape'};
            $row->{'color'}
                = $feature_type_data->{ $row->{'feature_type_acc'} }{'color'};
            $row->{'drawing_lane'}
                = $feature_type_data->{ $row->{'feature_type_acc'} }
                {'drawing_lane'};
        }
        $self->store_cached_results( 3, $sql_str, $return_object );
    }

    return $return_object;
}

#-----------------------------------------------
sub get_used_map_types {

=pod

=head2 get_used_map_types()

=over 4

=item * Description

Get map type info for map sets that are actually used.

=item * Adaptor Writing Info

=item * Required Input

=over 4

=back

=item * Optional Input

=over 4

=item - Boolean: is this a relational map (is_relational_map)

Set to 1 or 0 to select based on the is_relational_map column.  Leave undefined
to ignore that column.

=item - Boolean: Is this enabled (is_enabled) 

Set to 1 or 0 to select based on the is_enabled column.  Leave undefined to
ignore that column.

=back

=item * Output

Array of Hashes:

  Keys:
    map_type_acc
    map_type
    display_order

=item * Cache Level (Not Used): 3

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object       => 0,
        no_validation     => 0,
        is_relational_map => 0,
        is_enabled        => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $is_relational_map = $args{'is_relational_map'};
    my $is_enabled        = $args{'is_enabled'};
    my $db                = $self->db;
    my $map_type_data     = $self->map_type_data();
    my $return_object;

    my $sql_str = qq[
        select   distinct
                 ms.map_type_acc
        from     cmap_map_set ms
    ];
    my $where_sql = '';
    if ( defined($is_relational_map) ) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " ms.is_relational_map = "
            . $db->quote($is_relational_map) . " ";
    }
    if ( defined($is_enabled) ) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " ms.is_enabled = " . $db->quote($is_enabled) . " ";
    }

    $sql_str .= $where_sql;

    $return_object
        = $db->selectall_arrayref( $sql_str, { Columns => {} }, () );
    foreach my $row (@$return_object) {
        $row->{'map_type'}
            = $map_type_data->{ $row->{'map_type_acc'} }{'map_type'};
        $row->{'display_order'}
            = $map_type_data->{ $row->{'map_type_acc'} }{'display_order'};
    }

    return $return_object;
}

#-----------------------------------------------
sub get_map_type_acc {

=pod

=head2 get_map_type_acc()

=over 4

=item * Description

Given a map set get it's map type accession.

=item * Adaptor Writing Info

=item * Required Input

=over 4

=item - Map Set Accession (map_set_acc)

=back

=item * Output

Map Type Accession

=item * Cache Level (Not Used): 2

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        map_set_acc   => 1,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $map_set_acc = $args{'map_set_acc'};
    my $db          = $self->db;
    my $return_object;
    my $select_sql = " select ms.map_type_acc ";
    my $from_sql   = qq[
        from   cmap_map_set ms
    ];
    my $where_sql = '';

    if ($map_set_acc) {
        $where_sql
            .= " where ms.map_set_acc = " . $db->quote($map_set_acc) . " ";
    }
    else {
        return;
    }

    my $sql_str = $select_sql . $from_sql . $where_sql;

    $return_object = $db->selectrow_array( $sql_str, {} );

    return $return_object;
}

=pod

=head1 Matrix Methods

=cut 

#-----------------------------------------------
sub get_matrix_relationships {

=pod

=head2 get_matrix_relationships()

=over 4

=item * Description

Get Matrix data from the matrix table.

This method progressively gives more data depending on the input.  If a
map_set_acc is given, it will count based on individual maps of that map_set
and the results also include those map accessions.  If a link_map_set_acc is
also given it will count based on individual maps of both map sets and the
results include both map accessions. 

=item * Adaptor Writing Info

This method pulls data from the denormalized matrix table.  If you do not have
this table in your db, it might be slow.

=item * Required Input

=over 4

=back

=item * Optional Input

=over 4

=item - Map Set Accession (map_set_acc)

=item - Link Map Set Accession (link_map_set_acc)

=item - Species Accession (species_acc)

=item - Map Name (map_name)

=back

=item * Output

Array of Hashes:

  Keys:
    correspondences,
    map_count,
    reference_map_acc (Only if $map_set_acc is given),
    reference_map_set_acc,
    reference_species_acc,
    link_map_acc (Only if $map_set_acc and $link_map_set are given),
    link_map_set_acc,
    link_species_acc

Two of the keys are conditional to what the input is.

=item * Cache Level (Not Used): 

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object      => 0,
        no_validation    => 0,
        species_acc      => 0,
        map_name         => 0,
        map_set_acc      => 0,
        link_map_set_acc => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $species_acc      = $args{'species_acc'};
    my $map_name         = $args{'map_name'};
    my $map_set_acc      = $args{'map_set_acc'};
    my $link_map_set_acc = $args{'link_map_set_acc'};
    my $db               = $self->db;
    my $return_object;

    my $select_sql = qq[
        select   sum(cm.no_correspondences) as correspondences,
                 count(cm.link_map_acc) as map_count,
                 cm.reference_map_set_acc,
                 cm.reference_species_acc,
                 cm.link_map_set_acc,
                 cm.link_species_acc

    ];
    my $from_sql = qq[
        from     cmap_correspondence_matrix cm
    ];
    my $where_sql = '';
    my $group_by  = qq[
        group by cm.reference_map_set_acc,
                 cm.link_map_set_acc,
                 cm.reference_species_acc,
                 cm.link_species_acc
    ];

    if ( $map_set_acc and $link_map_set_acc ) {
        $select_sql .= qq[ 
            , cm.reference_map_acc
            , cm.link_map_acc
        ];
        $from_sql  .= ", cmap_map_set ms ";
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= q[
                cm.reference_map_set_acc=] . $db->quote($map_set_acc) . q[
            and cm.link_map_set_acc=] . $db->quote($link_map_set_acc) . q[
            and cm.reference_map_set_acc=ms.map_set_acc
            and ms.is_enabled=1
        ];
        $group_by .= ", cm.reference_map_acc, cm.link_map_acc ";
    }
    elsif ($map_set_acc) {
        $select_sql .= " , cm.reference_map_acc ";
        $from_sql   .= ", cmap_map_set ms ";
        $where_sql  .= $where_sql ? " and " : " where ";
        $where_sql  .= q[
                cm.reference_map_set_acc=] . $db->quote($map_set_acc) . q[
            and cm.reference_map_set_acc=ms.map_set_acc
        ];
        $group_by .= ", cm.reference_map_acc ";
    }

    if ($species_acc) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql
            .= " cm.reference_species_acc=" . $db->quote($species_acc) . " ";
    }
    if ($map_name) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " cm.reference_map_name=" . $db->quote($map_name) . " ";
    }
    my $sql_str = $select_sql . $from_sql . $where_sql . $group_by;

    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} } );

    return $return_object;
}

#-----------------------------------------------
sub reload_correspondence_matrix {

=pod

=head2 reload_correspondence_matrix()

=over 4

=item * Description

Reloads the correspondence matrix table

=item * Adaptor Writing Info

This method populates a denormalized matrix table.  If you do not have
this table in your db, it dummy up this method.

=item * Required Input

=over 4

=back

=back

=cut

    my $self              = shift;
    my %validation_params = ( cmap_object => 0, no_validation => 0, );
    my %args              = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $db = $self->db;

    #
    # Empty the table.
    #
    $db->do('delete from cmap_correspondence_matrix');

    #
    # Select all the reference maps.
    #
    my @reference_maps = @{
        $db->selectall_arrayref(
            q[
                select   map.map_id,
                         map.map_acc,
                         map.map_name,
                         ms.map_set_acc,
                         ms.map_set_short_name,
                         s.species_acc,
                         s.species_common_name
                from     cmap_map map,
                         cmap_map_set ms,
                         cmap_species s
                where    map.map_set_id=ms.map_set_id
                and      ms.is_relational_map=0
                and      ms.species_id=s.species_id
                order by map_set_short_name, map_name
            ],
            { Columns => {} }
        )
        };

    #
    # Go through each map and figure the number of correspondences.
    #
    my ( $i, $new_records ) = ( 0, 0 );    # counters
    for my $map (@reference_maps) {
        $i++;
        if ( $i % 50 == 0 ) {
            print(" $i\n");
        }
        else {
            print('#');
        }

        #
        # This gets the number of correspondences to each individual
        # map that can serve as a reference map.
        #
        my $map_correspondences = $db->selectall_arrayref(
            q[
                select   map.map_acc,
                         map.map_name,
                         ms.map_set_acc,
                         count(f2.feature_id) as no_correspondences,
                         ms.map_set_short_name,
                         s.species_acc,
                         s.species_common_name
                from     cmap_feature f1,
                         cmap_feature f2,
                         cmap_correspondence_lookup cl,
                         cmap_feature_correspondence fc,
                         cmap_map map,
                         cmap_map_set ms,
                         cmap_species s
                where    f1.map_id=?
                and      f1.feature_id=cl.feature_id1
                and      cl.feature_correspondence_id=
                         fc.feature_correspondence_id
                and      fc.is_enabled=1
                and      cl.feature_id2=f2.feature_id
                and      f2.map_id<>?
                and      f2.map_id=map.map_id
                and      map.map_set_id=ms.map_set_id
                and      ms.is_relational_map=0
                and      ms.species_id=s.species_id
                group by map.map_acc,
                         map.map_name,
                         ms.map_set_acc,
                         ms.map_set_short_name,
                         s.species_acc,
                         s.species_common_name
                order by map_set_short_name, map_name
            ],
            { Columns => {} },
            ( $map->{'map_id'}, $map->{'map_id'} )
        );

        #
        # This gets the number of correspondences to each whole
        # map set that cannot serve as a reference map.
        #
        my $map_set_correspondences = $db->selectall_arrayref(
            q[
                select   count(f2.feature_id) as no_correspondences,
                         ms.map_set_acc,
                         ms.map_set_short_name,
                         s.species_acc,
                         s.species_common_name
                from     cmap_feature f1,
                         cmap_feature f2,
                         cmap_correspondence_lookup cl,
                         cmap_feature_correspondence fc,
                         cmap_map map,
                         cmap_map_set ms,
                         cmap_species s
                where    f1.map_id=?
                and      f1.feature_id=cl.feature_id1
                and      cl.feature_id2=f2.feature_id
                and      cl.feature_correspondence_id=
                         fc.feature_correspondence_id
                and      fc.is_enabled=1
                and      f2.map_id=map.map_id
                and      map.map_set_id=ms.map_set_id
                and      ms.is_relational_map=1
                and      ms.species_id=s.species_id
                group by ms.map_set_acc,
                         ms.map_set_short_name,
                         s.species_acc,
                         s.species_common_name
                order by map_set_short_name
            ],
            { Columns => {} },
            ( $map->{'map_id'} )
        );

        for my $corr ( @$map_correspondences, @$map_set_correspondences ) {
            $db->do(
                q[
                    insert
                    into   cmap_correspondence_matrix
                           ( reference_map_acc,
                             reference_map_name,
                             reference_map_set_acc,
                             reference_species_acc,
                             link_map_acc,
                             link_map_name,
                             link_map_set_acc,
                             link_species_acc,
                             no_correspondences
                           )
                    values ( ?, ?, ?, ?, ?, ?, ?, ?, ? )
                ],
                {},
                (   $map->{'map_acc'},      $map->{'map_name'},
                    $map->{'map_set_acc'},  $map->{'species_acc'},
                    $corr->{'map_acc'},     $corr->{'map_name'},
                    $corr->{'map_set_acc'}, $corr->{'species_acc'},
                    $corr->{'no_correspondences'},
                )
            );

            $new_records++;
        }
    }
    return $new_records;
}

=pod

=head1 Duplicate Correspondence Methods

=cut 

#-----------------------------------------------
sub get_duplicate_correspondences {

=pod

=head2 get_duplicate_correspondences()

=over 4

=item * Description

Get duplicate correspondences from the database.  This method is used in order to delete them.

=item * Adaptor Writing Info

Again if you don't want CMap to mess with your db, make this a dummy method.

=item * Required Input

=over 4

=back

=item * Optional Input

=over 4

=item - Map Set ID (map_set_id)

=back

=item * Output

Array of Hashes:

  Keys:
    original_id
    duplicate_id

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        map_set_id    => 0,
        no_validation => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};
    my $map_set_id = $args{'map_set_id'};

    my $db = $self->db;

    my $select_sql = q[
        select min(b.feature_correspondence_id) as original_id,
               a.feature_correspondence_id as duplicate_id
    ];
    my $from_sql = q[
        from  cmap_correspondence_lookup a,
              cmap_correspondence_lookup b
    ];
    my $where_sql = q[
        where a.feature_id1<a.feature_id2
          and a.feature_id1=b.feature_id1
          and a.feature_id2=b.feature_id2
          and a.feature_correspondence_id > b.feature_correspondence_id
    ];
    my $group_by_sql = q[
        group by a.feature_correspondence_id
        ];

    if ($map_set_id) {
        $from_sql .= q[,
            cmap_map map
        ];
        $where_sql
            .= q[ and map.map_set_id = ]
            . $db->quote($map_set_id)
            . q[ and (
            a.map_id1 = map.map_id
            or a.map_id2 = map.map_id ) 
        ];
    }

    my $dup_sql = $select_sql . $from_sql . $where_sql . $group_by_sql;

    return $db->selectall_arrayref( $dup_sql, { Columns => {} } );

}

#-----------------------------------------------
sub get_duplicate_correspondences_hash {

=pod

=head2 get_duplicate_correspondences_hash()

=over 4

=item * Description

Get duplicate correspondences from the database.  This method is used in order to delete them.

=item * Adaptor Writing Info

Again if you don't want CMap to mess with your db, make this a dummy method.

=item * Required Input

=over 4

=back

=item * Optional Input

=over 4

=item - Map Set ID (map_set_id)

=back

=item * Output


=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        map_set_id    => 0,
        no_validation => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};
    my $map_set_id = $args{'map_set_id'};

    my $db = $self->db;

    my $select_sql = q[
        select  cl.feature_id1,
                cl.feature_id2,
                cl.feature_correspondence_id
    ];
    my $from_sql = q[
        from  cmap_correspondence_lookup cl
    ];
    my $where_sql = q[ where cl.feature_id1 < cl.feature_id2 ];

    if ($map_set_id) {
        $from_sql .= q[,
            cmap_map map
        ];
        $where_sql
            .= q[ and map.map_set_id = ]
            . $db->quote($map_set_id)
            . q[ and (
            cl.map_id1 = map.map_id
            or cl.map_id2 = map.map_id ) 
        ];
    }

    my $dup_sql = $select_sql . $from_sql . $where_sql;

    my $corrs = $db->selectall_arrayref( $dup_sql, { Columns => {} } );

    my $corr_hash = {};
    foreach my $corr ( @{ $corrs || [] } ) {
        push @{ $corr_hash->{ $corr->{'feature_id1'} }
                { $corr->{'feature_id2'} } },
            $corr->{'feature_correspondence_id'},;
    }

    return $corr_hash;
}

#-----------------------------------------------
sub get_moveable_evidence {

=pod

=head2 get_moveable_evidence()

=over 4

=item * Description

When deleting a duplicate correspondence, we want to make sure that we transfer
the unique evidences from the deleted corr to the remaining corr.  This method
finds the unique evidences that we want to move.

=item * Adaptor Writing Info

Again if you don't want CMap to mess with your db, make this a dummy method.

=item * Required Input

=over 4

=item - original_id (original_id)

=item - duplicate_id (duplicate_id)

=back

=item * Output

Array of correspondence_evidence_ids

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        original_id   => 1,
        duplicate_id  => 1,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $original_id  = $args{'original_id'};
    my $duplicate_id = $args{'duplicate_id'};
    my $db           = $self->db;
    my $return_object;

    my $evidence_move_sql = qq[
        select distinct ce1.correspondence_evidence_id
        from   cmap_correspondence_evidence ce1
        left join cmap_correspondence_evidence ce2
            on ce1.evidence_type_acc=ce2.evidence_type_acc
           and ce2.feature_correspondence_id=] . $db->quote($original_id) . q[
        where  ce1.feature_correspondence_id=]
        . $db->quote($duplicate_id) . q[
           and ce2.feature_correspondence_id is NULL
    ];
    $return_object = $db->selectcol_arrayref( $evidence_move_sql, {}, () );

    return $return_object;
}

#-----------------------------------------------
sub get_saved_links {

=pod

=head2 get_saved_links()

=over 4

=item * Description

=item * Adaptor Writing Info

=item * Input

=over 4

=back

=item * Output

Array of Hashes:

  Keys:

=item * Cache Level (If Used): 

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object         => 0,
        no_validation       => 0,
        saved_link_id       => 0,
        session_step_object => 0,
        saved_url           => 0,
        legacy_url          => 0,
        link_group          => 0,
        link_comment        => 0,
        link_title          => 0,
        last_access         => 0,
        hidden              => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $db = $self->db;
    my $return_object;

    my $sql_str = q[
        select saved_link_id,
               saved_on,
               last_access,
               session_step_object,
               saved_url,
               legacy_url,
               link_group,
               link_title,
               link_comment,
               hidden
        from cmap_saved_link
    ];
    my @where_list;
    my @identifiers = ();

    for my $column (
        qw[ saved_link_id saved_on session_step_object
        saved_url legacy_url link_group link_comment
        link_title last_access hidden]
        )
    {

        if ( defined( $args{$column} ) ) {
            push @identifiers, $args{$column};
            push @where_list,  " $column = ? ";
        }
    }

    if (@where_list) {
        $sql_str .= ' where ' . join " and ", @where_list;
    }

    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} },
        @identifiers );

    # if saved link was gotten by id, use update_saved_link to
    # update the last_accessed field.
    if ( $args{'saved_link_id'} and @{ $return_object || [] } ) {
        $self->update_saved_link( saved_link_id => $args{'saved_link_id'}, );
    }

    return $return_object;
}

#-----------------------------------------------
sub get_saved_link_groups {

=pod

=head2 get_saved_link_link_groups()

=over 4

=item * Description

=item * Adaptor Writing Info

=item * Input

=over 4

=back

=item * Output

Array of Hashes:

  Keys:

=item * Cache Level (If Used): 

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object         => 0,
        no_validation       => 0,
        saved_link_id       => 0,
        session_step_object => 0,
        saved_url           => 0,
        legacy_url          => 0,
        link_group          => 0,
        link_comment        => 0,
        link_title          => 0,
        last_access         => 0,
        hidden              => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $db = $self->db;
    my $return_object;

    my $sql_str = q[
        select 
               link_group,
               count(saved_link_id) as link_count
        from cmap_saved_link
    ];
    my @where_list;
    my @identifiers = ();

    for my $column (
        qw[ saved_link_id saved_on session_step_object
        saved_url legacy_url link_group link_comment
        link_title last_access hidden]
        )
    {

        if ( defined( $args{$column} ) ) {
            push @identifiers, $args{$column};
            push @where_list,  " $column = ? ";
        }
    }

    if (@where_list) {
        $sql_str .= ' where ' . join " and ", @where_list;
    }
    $sql_str .= ' group by link_group order by link_group ';

    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} },
        @identifiers );

    return $return_object;
}

#-----------------------------------------------
sub insert_saved_link {

=pod

=head2 insert_saved_link()

=over 4

=item * IMPORTANT NOTE

This method is overwritten in the Bio::GMOD::CMap::Data::Oracle module

=item * Description

Insert into the database.

=item * Adaptor Writing Info

The required inputs are only the ones that the database requires.

If you don't want CMap to insert into your database, make this a dummy method.

=item * Input

=over 4

=back

=item * Output

id

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object         => 0,
        no_validation       => 0,
        session_step_object => 0,
        saved_url           => 0,
        legacy_url          => 0,
        link_group          => 0,
        link_comment        => 0,
        link_title          => 0,
        last_access         => 0,
        hidden              => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $db                  = $self->db;
    my $session_step_object = $args{'session_step_object'};
    my $saved_url           = $args{'saved_url'};
    my $legacy_url          = $args{'legacy_url'};
    my $link_group          = $args{'link_group'};
    my $link_comment        = $args{'link_comment'};
    my $link_title          = $args{'link_title'};
    my $last_access         = $args{'last_access'};
    my $hidden              = $args{'hidden'} || 0;
    my $time                = localtime();
    my $saved_on            = $time->strftime( $self->date_format );
    unless ( defined $last_access ) {
        $last_access = $saved_on;
    }

    my $saved_link_id = $self->next_number( object_type => 'saved_link', )
        or return $self->error('No next number for saved_link ');
    $saved_url .= "saved_link_id=$saved_link_id;";

    my @insert_args = (
        $saved_link_id,       $saved_on,     $last_access,
        $session_step_object, $saved_url,    $legacy_url,
        $link_title,          $link_comment, $link_group,
        $hidden,
    );

    $db->do(
        qq[
        insert into cmap_saved_link
        (saved_link_id,  saved_on,     last_access,   session_step_object, 
         saved_url,      legacy_url,   link_title,    link_comment,
         link_group,     hidden  )
         values 
        ( ?,             ?,            ?,             ?, 
          ?,             ?,            ?,             ?,
          ?,             ? )
        ],
        {},
        (@insert_args)
    );

    return $saved_link_id;
}

#-----------------------------------------------
sub update_saved_link {

=pod

=head2 update_saved_link()

=over 4

=item * IMPORTANT NOTE

This method is overwritten in the Bio::GMOD::CMap::Data::Oracle module

=item * Description

Given the id and some attributes to modify, updates.

=item * Adaptor Writing Info

=item * Input

=over 4

=back

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object         => 0,
        no_validation       => 0,
        saved_link_id       => 1,
        session_step_object => 0,
        saved_url           => 0,
        legacy_url          => 0,
        link_group          => 0,
        link_comment        => 0,
        link_title          => 0,
        hidden              => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $db = $self->db;

    my @update_args = ();
    my $update_sql  = qq[
        update cmap_saved_link
    ];
    my @set_list;
    my $where_sql = " where saved_link_id = ? ";    # ID

    my $time = localtime();
    $args{'last_access'} = $time->strftime( $self->date_format );

    for my $column (
        qw[ session_step_object
        saved_url legacy_url link_group link_comment
        link_title last_access hidden]
        )
    {
        if ( defined( $args{$column} ) ) {
            push @update_args, $args{$column};
            push @set_list,    " $column = ? ";
        }
    }

    return unless @set_list;    # nothing to update

    my $set_sql = ' set ' . join( q{,}, @set_list ) . ' ';

    push @update_args, $args{'saved_link_id'};

    my $sql_str = $update_sql . $set_sql . $where_sql;
    $db->do( $sql_str, {}, @update_args );

}

=pod

=head1 Internal Methods

=cut 

# ----------------------------------------------------
sub next_number {

=pod

=head2 next_number()

=over 4

=item * Description

A generic routine for retrieving (and possibly setting) the next number for an
ID field in a table.  Given a table "foo," the expected ID field would be
"foo_id," but this isn't always the case.  Therefore, "id_field" tells us what
field to look at.  Basically, we look to see if there's an entry in the
"next_number" table.  If not we do a MAX on the ID field given (or
ascertained).  Either way, the "next_number" table gets told what the next
number will be (on the next call), and we pass back what is the next number
this time.

So why not just use "auto_increment" (MySQL) or a "sequence" (Oracle)?  Just to
make sure that this stays completely portable.  By coding all this in Perl, I
know that it will work with any database (that supports ANSI-SQL, that is).

=item * Adaptor Writing Info

This is only required for the original CMap database since it doesn't assume
that db has auto incrementing.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        object_type   => 1,
        requested     => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $db          = $self->db            or return;
    my $object_type = $args{'object_type'} or return;
    die "Object type: $object_type not valid.  \n<br>"
        . "Method giving error: next_number<br>"
        . "Calling information:<pre>"
        . Dumper( caller() )
        . "</pre>\n"
        unless ( $self->{'TABLE_NAMES'}->{$object_type} );
    my $no_requested = $args{'requested'} || 1;
    my $id_field     = $self->pk_name($object_type);
    my $table_name   = $self->{'TABLE_NAMES'}->{$object_type} if $object_type;

    my $next_number = $db->selectrow_array(
        q[
            select next_number
            from   cmap_next_number
            where  table_name=?
        ],
        {}, ($table_name)
    );

    unless ($next_number) {
        $next_number = $db->selectrow_array(
            qq[
                select max( $id_field )
                from   $table_name
            ]
        ) || 0;
        $next_number++;

        $db->do(
            q[
                insert
                into   cmap_next_number ( table_name, next_number )
                values ( ?, ? )
            ],
            {}, ( $table_name, $next_number + $no_requested )
        );
    }
    else {
        $db->do(
            q[
                update cmap_next_number
                set    next_number=?
                where  table_name=?
            ],
            {}, ( $next_number + $no_requested, $table_name )
        );
    }

    return $next_number;
}

#-----------------------------------------------
sub generic_get_data {

=pod

=head2 generic_get_data()

=over 4

=item * Description

The reason for this method is to safely allow the data retrieval methods to be
used from remote sources without opening up the data to correuption.

Calls the method passed to it and returns the results.  The method must start
with "get_".

=item * Adaptor Writing Info

This should be left alone.

=item * Required Input

=over 4

=item - Parameters (parameters)

These are the parameters to the method.

=item - Method Name (method_name)

This is the method to be run.  It must start with "get_"

=item - return_start (return_start)

=back

=item * Output

Returns the output of the method named in method_name.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        parameters  => 1,
        method_name => 1,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $method_name = $args{'method_name'} or return;
    my $parameters  = $args{'parameters'}  or return;
    return undef unless ( $method_name =~ /^get_/ );

    return undef unless ( ref $parameters eq 'HASH' );

    if ( $self->can($method_name) ) {
        return $self->$method_name(%$parameters);
    }

    return undef;
}

#-----------------------------------------------
sub feature_name_to_position {

=pod

=head2 feature_name_to_position()

=over 4

=item * Description

Turn a feature name into a position.  If return_start is true, it
returns the start.  If it is false, return a defined stop (or start if stop in
undef).

=item * Adaptor Writing Info

This is only used in get_slot_info().  An adaptor might find it useful even
still.

=item * Required Input

=over 4

=item - Feature Name (feature_name)

=item - Map ID (map_id)

=item - return_start (return_start)

=back

=item * Output

Start or stop of feature

=item * Cache Level (If Used): 3

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        feature_name  => 1,
        map_id        => 1,
        return_start  => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $feature_name = $args{'feature_name'} or return;
    my $map_id       = $args{'map_id'}       or return;
    my $return_start = $args{'return_start'};

    # REPLACE 33 YYY
    # Using get_feature_detail is a little overkill
    # but this method isn't used much and it makes for
    # simplified code.
    my $feature_array = $self->get_features(
        map_id           => $map_id,
        feature_name     => $feature_name,
        aliases_get_rows => 1,
    );
    unless ( $feature_array and @$feature_array ) {
        return undef;
    }

    my $start = $feature_array->[0]{'feature_start'};
    my $stop  = $feature_array->[0]{'feature_stop'};

    return
          $return_start ? $start
        : defined $stop ? $stop
        :                 $start;
}

#-----------------------------------------------
sub orderOutFromZero {

=pod

=head2 orderOutFromZero()

=over 4

=item * Description

Sorting method: Return the sort in this order (0,1,-1,-2,2,-3,3,)

=item * Adaptor Writing Info

This is probably going to be useful for any adaptor

=back

=cut

    return ( abs($a) cmp abs($b) );
}

#-----------------------------------------------
sub write_start_stop_sql_from_slot_info {

=pod

=head2 write_start_stop_sql_from_slot_info()

=over 4

=item * Description

This is a helper function to write start and stop queries given the slot_info
object.

=item * Adaptor Writing Info

=item * Input

=over 4

=back

=item * Output

String that has the sql in it.

=item * Cache Level (If Used): 

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        no_validation => 0,
        slot_info_obj => 1,
        map_id_column => 1,
        start_column  => 1,
        stop_column   => 1,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $slot_info_obj = $args{'slot_info_obj'} or return '';
    my $map_id_column = $args{'map_id_column'}
        or return $self->error(
        'No map_id column supplied for write_start_stop_sql()');
    my $start_column = $args{'start_column'}
        or return $self->error(
        'No start column supplied for write_start_stop_sql()');
    my $stop_column = $args{'stop_column'}
        or return $self->error(
        'No stop column supplied for write_start_stop_sql()');
    my $sql_str = "";

    my @map_id_strs;
    my $tmp_map_id_str;
    for my $map_id ( sort keys(%$slot_info_obj) ) {
        $tmp_map_id_str = " $map_id_column = $map_id ";
        if (my $start_stop_sql = $self->write_start_stop_sql(
                map_start    => $slot_info_obj->{$map_id}[0],
                map_stop     => $slot_info_obj->{$map_id}[1],
                start_column => $start_column,
                stop_column  => $stop_column,
            )
            )
        {
            $tmp_map_id_str .= " and $start_stop_sql ";
        }
        push @map_id_strs, " ( $tmp_map_id_str ) ";
    }
    if (@map_id_strs) {
        $sql_str .= " and ( " . join( ' or ', @map_id_strs ) . " ) ";
    }
    return $sql_str;
}

#-----------------------------------------------
sub write_start_stop_sql {

=pod

=head2 write_start_stop_sql()

=over 4

=item * Description

This is a helper function to write the sql that makes sure the map start and
stop of a corr are inside the displayed map area.

=item * Adaptor Writing Info

=item * Input

=over 4

=back

=item * Output

String that has the sql in it.

=item * Cache Level (If Used): 

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        no_validation => 0,
        start_column  => 1,
        stop_column   => 1,
        map_start     => 0,
        map_stop      => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};
    my $db = $self->db or return;

    my $map_start    = $args{'map_start'};
    my $map_stop     = $args{'map_stop'};
    my $start_column = $args{'start_column'}
        or return $self->error(
        'No start column supplied for write_start_stop_sql()');
    my $stop_column = $args{'stop_column'}
        or return $self->error(
        'No stop column supplied for write_start_stop_sql()');
    my $sql_str = "";

    if ( defined $map_start && defined $map_stop ) {
        $sql_str .= qq[
        (
        ( $start_column>=]
            . $db->quote($map_start)
            . qq[ and $start_column<=]
            . $db->quote($map_stop) . qq[ )
          or   (
            $stop_column is not null and
            $start_column<=]
            . $db->quote($map_start)
            . qq[ and $stop_column>=]
            . $db->quote($map_start) . qq[
            )
         )
         ];
    }
    elsif ( defined($map_start) ) {
        $sql_str
            .= " (( $start_column>="
            . $db->quote($map_start)
            . " ) or ( $stop_column is not null and "
            . " $stop_column>="
            . $db->quote($map_start) . " ))";
    }
    elsif ( defined($map_stop) ) {
        $sql_str .= " $start_column<=" . $db->quote($map_stop) . " ";
    }
    return $sql_str;
}

sub start_transaction {
    my $self = shift;
    my %args = @_;
    my $db   = $self->db;
    $db->{AutoCommit} = 0;

    return;
}

sub rollback_transaction {
    my $self = shift;
    my %args = @_;
    my $db   = $self->db;

    $db->rollback;
    $db->{AutoCommit} = 1;

    return;
}

sub commit_transaction {
    my $self = shift;
    my %args = @_;
    my $db   = $self->db;

    $db->commit;
    $db->{AutoCommit} = 1;

    return;
}

=pod

=head1 Method Stubs

=cut 

#-----------------------------------------------
sub stub {    #ZZZ

=pod

=head2 stub()

=over 4

=item * Description

=item * Adaptor Writing Info

=item * Input

=over 4

=item -

=back

=item * Output

Array of Hashes:

  Keys:

=item * Cache Level (If Used): 

Not using cache because this query is quicker.

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        x             => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $x  = $args{'x'};
    my $db = $self->db;
    my $return_object;

    return $return_object;
}

#-----------------------------------------------
sub insert_stub {    #ZZZ

=pod

=head2 insert_stub()

=over 4

=item * Description

Insert into the database.

=item * Adaptor Writing Info

The required inputs are only the ones that the database requires.

If you don't want CMap to insert into your database, make this a dummy method.

=item * Input

=over 4

=item -

=back

=item * Output

id

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        yy_acc        => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $db = $self->db;
    my $yy_id = $self->next_number( object_type => 'yy', )
        or return $self->error('No next number for yy ');
    my $yy_acc = $args{'yy_acc'} || $yy_id;
    my @insert_args = ( $yy_id, $yy_acc, );

    $db->do(
        qq[
        insert into cmap_yy
        (yy_id, yy_acc )
         values ( ?,?, )
        ],
        {},
        (@insert_args)
    );

    return $yy_id;
}

#-----------------------------------------------
sub update_stub {    #ZZZ

=pod

=head2 update_stub()

=over 4

=item * Description

Given the id and some attributes to modify, updates.

=item * Adaptor Writing Info

=item * Input

=over 4

=item -

=back

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        _id           => 0,
        x             => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $_id = $args{'_id'} or return;
    my $x   = $args{'x'};
    my $db  = $self->db;

    my @update_args = ();
    my $update_sql  = qq[
        update 
    ];
    my $set_sql   = '';
    my $where_sql = " where _id = ? ";    # ID

    if ($x) {
        push @update_args, $x;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " x = ? ";
    }

    push @update_args, $_id;

    my $sql_str = $update_sql . $set_sql . $where_sql;
    $db->do( $sql_str, {}, @update_args );

}

#-----------------------------------------------
sub delete_stub {    #ZZZ

=pod

=head2 delete_stub()

=over 4

=item * Description

Given the id, delete this object.

=item * Adaptor Writing Info

If you don't want CMap to delete from your database, make this a dummy method.

=item * Input

=over 4

=item -

=back

=item * Output

1

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object   => 0,
        no_validation => 0,
        yy_id         => 1,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $db    = $self->db;
    my $yy_id = $args{'yy_id'}
        or return $self->error('No ID given for yy to delete ');
    my @delete_args = ();
    my $delete_sql  = qq[
        delete from cmap_yy
    ];
    my $where_sql = '';

    return unless ($yy_id);
    if ($yy_id) {
        push @delete_args, $yy_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " yy_id = ? ";
    }

    $delete_sql .= $where_sql;
    $db->do( $delete_sql, {}, (@delete_args) );

    return 1;
}

1;

# ----------------------------------------------------
# He who desires but acts not, breeds pestilence.
# William Blake
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.
Ben Faga E<lt>faga@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-7 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

