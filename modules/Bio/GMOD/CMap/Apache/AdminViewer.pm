package Bio::GMOD::CMap::Apache::AdminViewer;

# vim: set ft=perl:

# $Id: AdminViewer.pm,v 1.97 2007/09/28 20:17:08 mwz444 Exp $

use strict;
use Data::Dumper;
use Data::Pageset;
use Template;
use Time::Piece;
use Time::ParseDate;
use Text::ParseWords 'parse_line';

use Bio::GMOD::CMap::Apache;
use Bio::GMOD::CMap::Admin;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Utils;
use Regexp::Common;

use base 'Bio::GMOD::CMap::Apache';

use constant ADMIN_HOME_URI => 'admin';

use vars qw(
    $VERSION $COLORS $MAP_SHAPES $FEATURE_SHAPES $WIDTHS $LINE_STYLES
    $MAX_PAGES $PAGE_SIZE
);

$COLORS         = [ sort keys %{ +COLORS } ];
$FEATURE_SHAPES = [
    qw(
        box dumbbell line span up-arrow down-arrow double-arrow filled-box
        in-triangle out-triangle
        )
];
$MAP_SHAPES = [qw( box dumbbell I-beam )];
$WIDTHS     = [ 1 .. 10 ];
$VERSION    = (qw$Revision: 1.97 $)[-1];

use constant ADMIN_TEMPLATE => {
    admin_home                => 'admin_home.tmpl',
    attribute_create          => 'admin_attribute_create.tmpl',
    attribute_edit            => 'admin_attribute_edit.tmpl',
    confirm_delete            => 'admin_confirm_delete.tmpl',
    corr_evidence_create      => 'admin_corr_evidence_create.tmpl',
    corr_evidence_edit        => 'admin_corr_evidence_edit.tmpl',
    corr_evidence_types_view  => 'admin_corr_evidence_types_view.tmpl',
    corr_evidence_type_create => 'admin_corr_evidence_type_create.tmpl',
    corr_evidence_type_edit   => 'admin_corr_evidence_type_edit.tmpl',
    corr_evidence_type_view   => 'admin_corr_evidence_type_view.tmpl',
    colors_view               => 'admin_colors_view.tmpl',
    error                     => 'admin_error.tmpl',
    feature_alias_create      => 'admin_feature_alias_create.tmpl',
    feature_alias_edit        => 'admin_feature_alias_edit.tmpl',
    feature_alias_view        => 'admin_feature_alias_view.tmpl',
    feature_corr_create       => 'admin_feature_corr_create.tmpl',
    feature_corr_view         => 'admin_feature_corr_view.tmpl',
    feature_corr_edit         => 'admin_feature_corr_edit.tmpl',
    feature_edit              => 'admin_feature_edit.tmpl',
    feature_create            => 'admin_feature_create.tmpl',
    feature_view              => 'admin_feature_view.tmpl',
    feature_search            => 'admin_feature_search.tmpl',
    feature_types_view        => 'admin_feature_types_view.tmpl',
    feature_type_create       => 'admin_feature_type_create.tmpl',
    feature_type_edit         => 'admin_feature_type_edit.tmpl',
    feature_type_view         => 'admin_feature_type_view.tmpl',
    map_create                => 'admin_map_create.tmpl',
    map_edit                  => 'admin_map_edit.tmpl',
    map_view                  => 'admin_map_view.tmpl',
    map_sets_view             => 'admin_map_sets_view.tmpl',
    map_set_create            => 'admin_map_set_create.tmpl',
    map_set_edit              => 'admin_map_set_edit.tmpl',
    map_set_view              => 'admin_map_set_view.tmpl',
    map_type_edit             => 'admin_map_type_edit.tmpl',
    map_type_create           => 'admin_map_type_create.tmpl',
    map_type_view             => 'admin_map_type_view.tmpl',
    map_types_view            => 'admin_map_types_view.tmpl',
    species_edit              => 'admin_species_edit.tmpl',
    species_create            => 'admin_species_create.tmpl',
    species_view              => 'admin_species_view.tmpl',
    species_view_one          => 'admin_species_view_one.tmpl',
    xref_create               => 'admin_xref_create.tmpl',
    xref_edit                 => 'admin_xref_edit.tmpl',
    xrefs_view                => 'admin_xrefs_view.tmpl',
};

use constant ADMIN_XREF_OBJECTS => [
    {   object_type => 'feature',
        object_name => 'Feature',
        name_field  => 'feature_name',
    },
    {   object_type => 'feature_alias',
        object_name => 'Feature Alias',
        name_field  => 'alias',
    },
    {   object_type => 'feature_correspondence',
        object_name => 'Feature Correspondence',
        name_field  => 'feature_correspondence_acc',
    },
    {   object_type => 'map',
        object_name => 'Map',
        name_field  => 'map_name',
    },
    {   object_type => 'map_set',
        object_name => 'Map Set',
        name_field  => 'map_set_short_name',
    },
    {   object_type => 'species',
        object_name => 'Species',
        name_field  => 'species_common_name',
    },
];

my %XREF_OBJ_LOOKUP
    = map { $_->{'object_type'}, $_ } @{ +ADMIN_XREF_OBJECTS };

# ----------------------------------------------------
sub handler {

    #
    # Make a jazz noise here...
    #
    my ( $self, $apr ) = @_;

    $self->data_source( $apr->param('data_source') ) or return;

    $PAGE_SIZE ||= $self->config_data('max_child_elements') || 0;
    $MAX_PAGES ||= $self->config_data('max_search_pages')   || 1;

    my $action = $apr->param('action') || 'admin_home';
    my $return = eval { $self->$action() };
    return $self->error($@) if $@;
    return 1;
}

# ----------------------------------------------------
sub admin {

    #
    # Returns the "admin" object.
    #
    my $self = shift;
    unless ( defined $self->{'admin'} ) {
        $self->{'admin'} = Bio::GMOD::CMap::Admin->new(
            data_source => $self->data_source,
            config      => $self->config,
        );
    }
    return $self->{'admin'};
}

# ----------------------------------------------------
sub admin_home {
    my $self = shift;
    my $apr  = $self->apr;
    return $self->process_template( ADMIN_TEMPLATE->{'admin_home'},
        { apr => $self->apr } );
}

# ----------------------------------------------------
sub attribute_create {
    my ( $self, %args ) = @_;
    my $apr         = $self->apr;
    my $object_id   = $apr->param('object_id') or die 'No object id';
    my $object_type = $apr->param('object_type') or die 'No object name';
    my $pk_name     = $object_type . '_id';

    return $self->process_template(
        ADMIN_TEMPLATE->{'attribute_create'},
        {   apr         => $apr,
            errors      => $args{'errors'},
            object_type => $object_type,
            pk_name     => $pk_name,
            object_id   => $object_id,
        }
    );
}

# ----------------------------------------------------
sub attribute_edit {
    my ( $self, %args ) = @_;
    my $apr          = $self->apr;
    my $sql_object   = $self->sql or return;
    my $attribute_id = $apr->param('attribute_id')
        or die 'No feature attribute id';

    my $attributes
        = $sql_object->get_attributes( attribute_id => $attribute_id, );
    my $attribute = $attributes->[0];

    my $object_id   = $attribute->{'object_id'};
    my $object_type = $attribute->{'object_type'};
    my $pk_name     = $object_type;
    $pk_name .= '_id';

    unless ( $apr->param('return_action') ) {
        $apr->param( 'return_action', "${object_type}_view" );
    }

    return $self->process_template(
        ADMIN_TEMPLATE->{'attribute_edit'},
        {   apr         => $apr,
            attribute   => $attribute,
            pk_name     => $pk_name,
            object_type => $object_type,
        }
    );
}

# ----------------------------------------------------
sub attribute_insert {
    my ( $self, %args ) = @_;
    my $apr       = $self->apr;
    my $admin     = $self->admin or return;
    my @errors    = ();
    my $object_id = $apr->param('object_id')
        or push @errors, 'No object id';
    my $object_type = $apr->param('object_type')
        or push @errors, 'No object type';
    my $pk_name = $apr->param('pk_name')
        or push @errors, 'No PK name';
    my $ret_action = $apr->param('return_action') || "${object_type}_view";
    my $attribute_name = $apr->param('attribute_name')
        or push @errors, 'No attribute name';
    my $attribute_value = $apr->param('attribute_value')
        or push @errors, 'No attribute value';
    my $display_order = $apr->param('display_order') || 0;
    my $is_public     = $apr->param('is_public');

    $admin->set_attributes(
        object_id   => $object_id,
        object_type => $object_type,
        attributes  => [
            {   name          => $attribute_name,
                value         => $attribute_value,
                display_order => $display_order,
                is_public     => $is_public,
            },
        ],
        )
        or return $self->error( $admin->error );
    $admin->purge_cache(1);

    return $self->redirect_home(
        ADMIN_HOME_URI . "?action=$ret_action;$pk_name=$object_id" );
}

# ----------------------------------------------------
sub attribute_update {
    my ( $self, %args ) = @_;
    my $apr          = $self->apr;
    my $admin        = $self->admin or return;
    my @errors       = ();
    my $attribute_id = $apr->param('attribute_id')
        or push @errors, 'No attribute id';
    my $attribute_name = $apr->param('attribute_name')
        or push @errors, 'No attribute name';
    my $attribute_value = $apr->param('attribute_value')
        or push @errors, 'No attribute value';
    my $pk_name = $apr->param('pk_name')
        or push @errors, 'No PK name';
    my $object_id = $apr->param('object_id')
        or push @errors, 'No object id';
    my $object_type = $apr->param('object_type')
        or push @errors, 'No object type';
    my $display_order = $apr->param('display_order') || 0;
    my $ret_action    = $apr->param('return_action') || "${object_type}_view";
    my $is_public     = $apr->param('is_public');

    return $self->attribute_edit(
        apr    => $apr,
        errors => \@errors,
        )
        if @errors;

    $admin->set_attributes(
        object_id   => $object_id,
        object_type => $object_type,
        attributes  => [
            {   attribute_id  => $attribute_id,
                name          => $attribute_name,
                value         => $attribute_value,
                is_public     => $is_public,
                display_order => $display_order,
            },
        ],
        )
        or return $self->error( $admin->error );

    $admin->purge_cache(1);
    return $self->redirect_home(
        ADMIN_HOME_URI . "?action=$ret_action;$pk_name=$object_id" );
}

# ----------------------------------------------------
sub confirm_delete {
    my $self        = shift;
    my $apr         = $self->apr;
    my $sql_object  = $self->sql;
    my $entity_type = $apr->param('entity_type') or die 'No entity type';
    my $entity_id   = $apr->param('entity_id') or die 'No entity id';
    my $entity_name = $apr->param('entity_name') || '';

    unless ($entity_name) {
        $entity_name = $sql_object->get_object_name(
            object_id   => $entity_id,
            object_type => $entity_type,
        );
    }

    my $pk_name   = $sql_object->pk_name($entity_type);
    my $object_id = $entity_id;

    return $self->process_template(
        ADMIN_TEMPLATE->{'confirm_delete'},
        {   apr           => $apr,
            return_action => $apr->param('return_action') || '',
            pk_name       => $pk_name,
            object_id     => $object_id,
            entity        => {
                id   => $entity_id,
                name => $entity_name,
                type => $entity_type,
            },
        }
    );
}

# ----------------------------------------------------
sub colors_view {
    my $self       = shift;
    my $apr        = $self->apr;
    my $color_name = lc $apr->param('color_name') || '';
    my $page_no    = $apr->param('page_no') || 1;
    my ( @colors, @errors );

    #
    # Find a particular color (or all matching if there's a splat).
    #
    if ($color_name) {
        my $orig_color_name = $color_name;
        if ( $color_name =~ s/\*//g ) {
            for my $color ( grep {/$color_name/} @$COLORS ) {
                push @colors,
                    {
                    name => $color,
                    hex  => join( '', @{ +COLORS->{$color} } ),
                    };
            }
            @errors = ("No colors in palette match '$orig_color_name'")
                unless @colors;
        }
        elsif ( exists COLORS->{$color_name} ) {
            @colors = (
                {   name => $color_name,
                    hex  => join( '', @{ +COLORS->{$color_name} } ),
                }
            );
        }
        else {
            @colors = ();
            @errors = ("Color '$color_name' isn't in the palette");
        }
    }
    else {
        @colors
            = map { { name => $_, hex => join( '', @{ +COLORS->{$_} } ) } }
            sort keys %{ +COLORS };
    }

    my $pager = Data::Pageset->new(
        {   total_entries    => scalar @colors,
            entries_per_page => $PAGE_SIZE,
            current_page     => $page_no,
            pages_per_set    => $MAX_PAGES,
        }
    );
    @colors = $pager->splice( \@colors );

    return $self->process_template(
        ADMIN_TEMPLATE->{'colors_view'},
        {   apr    => $self->apr,
            colors => \@colors,
            pager  => $pager,
            errors => \@errors,
        }
    );
}

# ----------------------------------------------------
sub corr_evidence_type_create {
    return 0;
    ###Do this in Config
}

# ----------------------------------------------------
sub corr_evidence_type_insert {
    return 0;
    ###Do this in config
}

# ----------------------------------------------------
sub corr_evidence_type_edit {
    my ( $self, %args ) = @_;
    return 0;

    #Do this in Config file

}

# ----------------------------------------------------
sub corr_evidence_type_update {
    my ( $self, %args ) = @_;
    return 0;

    #Do this in Config file
}

# ----------------------------------------------------
sub corr_evidence_type_view {
    my ( $self, %args ) = @_;
    my $apr                        = $self->apr;
    my $incoming_evidence_type_acc = $apr->param('evidence_type_acc')
        || $apr->param('evidence_type_aid')
        or return $self->error('No evidence type');

    my $evidence_type = $self->evidence_type_data($incoming_evidence_type_acc)
        or return $self->error(
        "No evidence type accession '$incoming_evidence_type_acc'");

    return $self->process_template(
        ADMIN_TEMPLATE->{'corr_evidence_type_view'},
        { evidence_type => $evidence_type, }
    );
}

# ----------------------------------------------------
sub corr_evidence_types_view {
    my $self     = shift;
    my $apr      = $self->apr;
    my $order_by = $apr->param('order_by') || 'rank,evidence_type_acc';
    my $page_no  = $apr->param('page_no') || 1;

    my @evidence_type_accs = keys( %{ $self->config_data('evidence_type') } );
    my $evidence_types_hash;
    foreach my $type_acc (@evidence_type_accs) {
        $evidence_types_hash->{$type_acc}
            = $self->evidence_type_data($type_acc)
            or return $self->error("No evidence type accession '$type_acc'");
    }

    my $evidence_types;
    foreach my $type_acc ( keys( %{$evidence_types_hash} ) ) {
        $evidence_types_hash->{$type_acc}{'evidence_type_acc'} = $type_acc;
        push @$evidence_types, $evidence_types_hash->{$type_acc};
    }

    # Sort object using the Utils method sort_selectall_arrayref
    $evidence_types = sort_selectall_arrayref( $evidence_types,
        $self->_split_order_by_for_sort($order_by) );

    my $pager = Data::Pageset->new(
        {   total_entries    => scalar @$evidence_types,
            entries_per_page => $PAGE_SIZE,
            current_page     => $page_no,
            pages_per_set    => $MAX_PAGES,
        }
    );
    $evidence_types
        = @$evidence_types ? [ $pager->splice($evidence_types) ] : [];

    return $self->process_template(
        ADMIN_TEMPLATE->{'corr_evidence_types_view'},
        {   evidence_types => $evidence_types,
            pager          => $pager,
        }
    );
}

# ----------------------------------------------------
sub entity_delete {
    my $self          = shift;
    my $sql_object    = $self->sql or return $self->error;
    my $apr           = $self->apr;
    my $admin         = $self->admin;
    my $entity_type   = $apr->param('entity_type') or die 'No entity type';
    my $entity_id     = $apr->param('entity_id') or die 'No entity ID';
    my $return_action = $apr->param('return_action') || '';
    my $pk_name       = $sql_object->pk_name($entity_type);
    my $uri_args      = $return_action
        && $pk_name
        && $entity_id ? "?action=$return_action;$pk_name=$entity_id" : '';

    #
    # Map Set
    #
    if ( $entity_type eq 'map_set' ) {
        $admin->map_set_delete( map_set_id => $entity_id )
            or return $self->error( $admin->error );
        $uri_args ||= '?action=map_sets_view';
        $admin->purge_cache(1);
    }

    #
    # Species
    #
    elsif ( $entity_type eq 'species' ) {
        $admin->species_delete( species_id => $entity_id )
            or return $self->error( $admin->error );
        $uri_args ||= '?action=species_view';
        $admin->purge_cache(1);
    }

    #
    # Feature Correspondence
    #
    elsif ( $entity_type eq 'feature_correspondence' ) {
        $admin->feature_correspondence_delete(
            feature_correspondence_id => $entity_id )
            or return $self->error( $admin->error );
        $admin->purge_cache(4);
    }

    #
    # Attribute
    #
    elsif ( $entity_type eq 'attribute' ) {
        my $attribute_id = $apr->param('entity_id');
        my $attributes
            = $sql_object->get_attributes( attribute_id => $attribute_id, );
        my $attribute   = $attributes->[0];
        my $object_id   = $attribute->{'object_id'};
        my $object_type = $attribute->{'object_type'};
        my $pk_name     = $sql_object->pk_name($object_type);
        my $ret_action  = $apr->param('return_action')
            || "${object_type}_view";
        $uri_args = "?action=$ret_action;$pk_name=$object_id";

        $sql_object->delete_attribute( attribute_id => $attribute_id, );
    }

    #
    # Feature
    #
    elsif ( $entity_type eq 'feature' ) {
        my $map_id = $admin->feature_delete( feature_id => $entity_id )
            or return $self->error( $admin->error );
        $uri_args ||= "?action=map_view;map_id=$map_id";
        $admin->purge_cache(3);
    }

    #
    # Feature Alias
    #
    elsif ( $entity_type eq 'feature_alias' ) {
        my $feature_id = $sql_object->delete_feature_alias(
            feature_alias_id => $entity_id, );
        $uri_args = "?action=feature_view;feature_id=$feature_id";
    }

    #
    # Map
    #
    elsif ( $entity_type eq 'map' ) {
        my $map_set_id = $admin->map_delete( map_id => $entity_id )
            or return $self->error( $admin->error );
        $uri_args = "?action=map_set_view;map_set_id=$map_set_id";
        $admin->purge_cache(2);
    }

    #
    # Correspondence evidence
    #
    elsif ( $entity_type eq 'correspondence_evidence' ) {
        my $feature_corr_id = $admin->correspondence_evidence_delete(
            correspondence_evidence_id => $entity_id )
            or return $self->error( $admin->error );

        $uri_args
            = "?action=feature_corr_view;feature_correspondence_id=$feature_corr_id";
        $admin->purge_cache(4);
    }

    #
    # Cross-Reference
    #
    elsif ( $entity_type eq 'xref' ) {
        my $xrefs       = $sql_object->get_xrefs( xref_id => $entity_id, );
        my $xref        = $xrefs->[0];
        my $object_id   = $xref->{'object_id'};
        my $object_type = $xref->{'object_type'};
        my $pk_name     = $sql_object->pk_name($object_type);

        if ( $return_action && $pk_name && $object_id ) {
            $uri_args = "?action=$return_action;$pk_name=$object_id";
        }
        else {
            $uri_args = '?action=xrefs_view';
        }

        $sql_object->delete_xref( xref_id => $xref->{'xref_id'}, );
    }

    #
    # Unknown
    #
    else {
        return $self->error(
            "You are not allowed to delete entities of type '$entity_type.'");
    }

    $self->admin->attribute_delete( $entity_type, $entity_id );
    $self->admin->xref_delete( $entity_type, $entity_id );

    return $self->redirect_home( ADMIN_HOME_URI . $uri_args );
}

# ----------------------------------------------------
sub error_template {
    my $self = shift;
    return ADMIN_TEMPLATE->{'error'};
}

# ----------------------------------------------------
sub map_create {
    my ( $self, %args ) = @_;
    my $sql_object = $self->sql or return $self->error;
    my $apr        = $self->apr;
    my $map_set_id = $apr->param('map_set_id') or die 'No map set id';

    my $map_sets = $sql_object->get_map_sets( map_set_id => $map_set_id, );
    return $self->error("No map set for ID '$map_set_id'")
        unless ( $map_sets and @$map_sets );
    my $map_set = $map_sets->[0];
    return $self->process_template(
        ADMIN_TEMPLATE->{'map_create'},
        {   apr     => $apr,
            map_set => $map_set,
            errors  => $args{'errors'},
        }
    );
}

# ----------------------------------------------------
sub map_edit {
    my ( $self, %args ) = @_;
    my $errors     = $args{'errors'};
    my $sql_object = $self->sql or return $self->error;
    my $apr        = $self->apr;
    my $map_id     = $apr->param('map_id');
    my $maps       = $sql_object->get_maps( map_id => $map_id, );
    return $self->error("No map for ID '$map_id'")
        unless ( $maps and @$maps );
    my $map = $maps->[0];

    return $self->process_template(
        ADMIN_TEMPLATE->{'map_edit'},
        {   map    => $map,
            errors => $errors,
        }
    );
}

# ----------------------------------------------------
sub map_insert {
    my $self   = shift;
    my $admin  = $self->admin;
    my $apr    = $self->apr;
    my $map_id = $admin->map_create(
        map_acc => $apr->param('map_acc') || $apr->param('map_aid') || '',
        display_order => $apr->param('display_order') || 1,
        map_name      => $apr->param('map_name')      || '',
        map_set_id    => $apr->param('map_set_id')    || 0,
        map_start => defined $apr->param('map_start')
        ? $apr->param('map_start')
        : undef,
        map_stop => defined $apr->param('map_stop') ? $apr->param('map_stop')
        : undef,
        )
        or return $self->map_create( errors => $admin->error );

    $admin->purge_cache(2);
    return $self->redirect_home(
        ADMIN_HOME_URI . "?action=map_view;map_id=$map_id" );
}

# ----------------------------------------------------
sub map_view {
    my $self             = shift;
    my $sql_object       = $self->sql or return $self->error;
    my $apr              = $self->apr;
    my $map_id           = $apr->param('map_id') or die 'No map id';
    my $feature_type_acc = $apr->param('feature_type_acc')
        || $apr->param('feature_type_aid')
        || 0;
    my $page_no      = $apr->param('page_no')      || 1;
    my $att_order_by = $apr->param('att_order_by') || q{};

    my $maps = $sql_object->get_maps( map_id => $map_id, );
    return $self->error("No map for ID '$map_id'")
        unless ( $maps and @$maps );
    my $map = $maps->[0];

    $map->{'attributes'} = $sql_object->get_attributes(
        object_type => 'map',
        object_id   => $map_id,
    );

    # Sort object using the Utils method sort_selectall_arrayref
    $map->{'attributes'} = sort_selectall_arrayref( $map->{'attributes'},
        $self->_split_order_by_for_sort($att_order_by) );

    $map->{'xrefs'} = $sql_object->get_xrefs(
        object_type => 'map',
        object_id   => $map_id,
    );

    # Sort object using the Utils method sort_selectall_arrayref
    $map->{'xrefs'} = sort_selectall_arrayref( $map->{'xrefs'},
        $self->_split_order_by_for_sort($att_order_by) );

    my $features = $sql_object->get_features_simple(
        map_id           => $map_id,
        feature_type_acc => $feature_type_acc,
    );
    my $feature_type_data = $self->feature_type_data();
    foreach my $row ( @{$features} ) {
        $row->{'feature_type'}
            = $feature_type_data->{ $row->{'feature_type_acc'} }
            {'feature_type'};
    }

    #
    # Slice the results up into pages suitable for web viewing.
    #
    my $pager = Data::Pageset->new(
        {   total_entries    => scalar @$features,
            entries_per_page => $PAGE_SIZE,
            current_page     => $page_no,
            pages_per_set    => $MAX_PAGES,
        }
    );
    $map->{'features'} = @$features ? [ $pager->splice($features) ] : [];

    my @feature_ids = map { $_->{'feature_id'} } @{ $map->{'features'} };
    if (@feature_ids) {
        my $aliases
            = $sql_object->get_feature_aliases( feature_ids => \@feature_ids,
            );

        my %aliases;
        for my $alias (@$aliases) {
            push @{ $aliases{ $alias->{'feature_id'} } }, $alias->{'alias'};
        }

        for my $f (@$features) {
            $f->{'aliases'} = [ sort { lc $a cmp lc $b }
                    @{ $aliases{ $f->{'feature_id'} } || [] } ];
        }
    }

    for my $feature ( @{ $map->{'features'} } ) {
        $feature->{'no_correspondences'}
            = $sql_object->get_feature_correspondence_count_for_feature(
            feature_id => $feature->{'feature_id'}, );
    }

    my $feature_type_accs_array
        = $sql_object->get_used_feature_types( map_ids => [ $map_id, ], );
    my @feature_type_accs =
        map { $_->{'feature_type_acc'} } @$feature_type_accs_array;
    my %feature_type_name_lookup;
    foreach my $ft_acc (@feature_type_accs) {
        $feature_type_name_lookup{$ft_acc}
            = $self->config_data('feature_type')->{$ft_acc}{'feature_type'};
    }

    return $self->process_template(
        ADMIN_TEMPLATE->{'map_view'},
        {   apr                      => $apr,
            map                      => $map,
            feature_type_accs        => \@feature_type_accs,
            feature_type_name_lookup => \%feature_type_name_lookup,
            pager                    => $pager,
        }
    );
}

# ----------------------------------------------------
sub map_update {
    my $self       = shift;
    my $sql_object = $self->sql or return $self->error;
    my $apr        = $self->apr;
    my @errors     = ();
    my $map_id     = $apr->param('map_id')
        or push @errors, 'No map id';
    return $self->map_edit( errors => \@errors ) if @errors;
    my $admin = $self->admin or return;

    $sql_object->update_map(
        map_id        => $map_id,
        map_acc       => $apr->param('map_acc') || $apr->param('map_aid'),
        display_order => $apr->param('display_order'),
        map_name      => $apr->param('map_name'),
        map_start     => $apr->param('map_start'),
        map_stop      => $apr->param('map_stop'),
    );

    $admin->purge_cache(2);
    return $self->redirect_home(
        ADMIN_HOME_URI . "?action=map_view;map_id=$map_id" );
}

# ----------------------------------------------------
sub feature_alias_create {
    my ( $self, %args ) = @_;
    my $apr        = $self->apr;
    my $feature_id = $apr->param('feature_id') or die 'No feature ID';
    my $sql_object = $self->sql;
    my $features   = $sql_object->get_features( feature_id => $feature_id, );
    return $self->error("No feature for ID '$feature_id'")
        unless ( $features and @$features );
    my $feature = $features->[0];

    return $self->process_template(
        ADMIN_TEMPLATE->{'feature_alias_create'},
        {   apr     => $apr,
            feature => $feature,
            errors  => $args{'errors'},
        }
    );
}

# ----------------------------------------------------
sub feature_alias_edit {
    my ( $self, %args ) = @_;
    my $sql_object       = $self->sql;
    my $apr              = $self->apr;
    my $feature_alias_id = $apr->param('feature_alias_id')
        or die 'No feature alias id';

    my $sqp_object = $self->sql;
    my $aliases    = $sql_object->get_feature_aliases(
        feature_alias_id => $feature_alias_id, );
    my $alias = $aliases->[0];

    return $self->process_template(
        ADMIN_TEMPLATE->{'feature_alias_edit'},
        {   apr    => $apr,
            alias  => $alias,
            errors => $args{'errors'},
        }
    );
}

# ----------------------------------------------------
sub feature_alias_insert {
    my $self       = shift;
    my $apr        = $self->apr;
    my $admin      = $self->admin;
    my $feature_id = $apr->param('feature_id') || 0;

    $admin->feature_alias_create(
        feature_id => $feature_id,
        alias      => $apr->param('alias') || '',
        )
        or return $self->feature_alias_create( errors => [ $admin->error ] );
    $admin->purge_cache(3);

    return $self->redirect_home(
        ADMIN_HOME_URI . "?action=feature_view;feature_id=$feature_id" );
}

# ----------------------------------------------------
sub feature_alias_update {
    my $self             = shift;
    my $apr              = $self->apr;
    my $feature_alias_id = $apr->param('feature_alias_id')
        or die 'No feature alias id';
    my $alias      = $apr->param('alias') or die 'No alias';
    my $sql_object = $self->sql;

    my $admin = $self->admin or return;
    $sql_object->update_feature_alias(
        feature_alias_id => $feature_alias_id,
        alias            => $apr->param('alias'),
    );

    $admin->purge_cache(3);
    return $self->redirect_home( ADMIN_HOME_URI
            . "?action=feature_alias_view;feature_alias_id=$feature_alias_id"
    );
}

# ----------------------------------------------------
sub feature_alias_view {
    my $self             = shift;
    my $apr              = $self->apr;
    my $feature_alias_id = $apr->param('feature_alias_id')
        or die 'No feature alias id';

    my $sql_object = $self->sql;
    my $aliases    = $sql_object->get_feature_aliases(
        feature_alias_id => $feature_alias_id, );
    my $alias = $aliases->[0];

    $alias->{'attributes'} = $sql_object->get_attributes(
        object_type => 'feature_alias',
        object_id   => $feature_alias_id,
    );

    $alias->{'xrefs'} = $sql_object->get_xrefs(
        object_type => 'feature_alias',
        object_id   => $feature_alias_id,
    );

    return $self->process_template(
        ADMIN_TEMPLATE->{'feature_alias_view'},
        {   apr   => $apr,
            alias => $alias,
        }
    );
}

# ----------------------------------------------------
sub feature_create {
    my ( $self, %args ) = @_;
    my $sql_object = $self->sql or return $self->error;
    my $apr        = $self->apr;
    my $map_id     = $apr->param('map_id') or die 'No map id';

    my $maps = $sql_object->get_maps( map_id => $map_id, );
    return $self->error("No map for ID '$map_id'")
        unless ( $maps and @$maps );
    my $map = $maps->[0];

    my @feature_type_accs = keys( %{ $self->feature_type_data() } );
    my %feature_type_name_lookup;
    foreach my $ft_acc (@feature_type_accs) {
        $feature_type_name_lookup{$ft_acc}
            = $self->config_data('feature_type')->{$ft_acc}{'feature_type'};
    }
    return $self->process_template(
        ADMIN_TEMPLATE->{'feature_create'},
        {   apr                      => $apr,
            map                      => $map,
            feature_type_accs        => \@feature_type_accs,
            feature_type_name_lookup => \%feature_type_name_lookup,
            errors                   => $args{'errors'},
        }
    );
}

# ----------------------------------------------------
sub feature_edit {
    my ( $self, %args ) = @_;
    my $sql_object = $self->sql or return $self->error;
    my $apr        = $self->apr;
    my $feature_id = $apr->param('feature_id') or die 'No feature id';

    my $features = $sql_object->get_features( feature_id => $feature_id, );
    return $self->error("No feature for ID '$feature_id'")
        unless ( $features and @$features );
    my $feature = $features->[0];

    my @feature_type_accs = keys( %{ $self->feature_type_data() } );

    my %feature_type_name_lookup;
    foreach my $ft_acc (@feature_type_accs) {
        $feature_type_name_lookup{$ft_acc}
            = $self->config_data('feature_type')->{$ft_acc}{'feature_type'};
    }
    return $self->process_template(
        ADMIN_TEMPLATE->{'feature_edit'},
        {   feature                  => $feature,
            feature_type_accs        => \@feature_type_accs,
            errors                   => $args{'errors'},
            feature_type_name_lookup => \%feature_type_name_lookup,
        },
    );
}

# ----------------------------------------------------
sub feature_insert {
    my $self       = shift;
    my $admin      = $self->admin;
    my $apr        = $self->apr;
    my $map_id     = $apr->param('map_id') || 0;
    my $feature_id = $admin->feature_create(
        map_id      => $map_id,
        feature_acc => $apr->param('feature_acc')
            || $apr->param('feature_aid')
            || '',
        feature_name => $apr->param('feature_name') || '',
        feature_type_acc => $apr->param('feature_type_acc')
            || $apr->param('feature_type_aid')
            || 0,
        is_landmark   => $apr->param('is_landmark')   || 0,
        direction     => $apr->param('direction')     || 0,
        feature_start => $apr->param('feature_start') || 0,
        feature_stop  => $apr->param('feature_stop')
        )
        or return $self->feature_create( errors => $admin->error );
    $self->admin()->validate_update_map_start_stop($map_id);
    $admin->purge_cache(3);

    return $self->redirect_home(
        ADMIN_HOME_URI . '?action=map_view;map_id=' . $apr->param('map_id') );
}

# ----------------------------------------------------
sub feature_update {
    my $self       = shift;
    my @errors     = ();
    my $sql_object = $self->sql or return $self->error;
    my $apr        = $self->apr;
    my $feature_id = $apr->param('feature_id')
        or push @errors, 'No feature id';

    return $self->feature_edit( errors => \@errors ) if @errors;
    my $admin = $self->admin or return;

    $sql_object->update_feature(
        feature_id  => $feature_id,
        feature_acc => $apr->param('feature_acc')
            || $apr->param('feature_aid'),
        feature_name     => $apr->param('feature_name'),
        feature_type_acc => $apr->param('feature_type_acc')
            || $apr->param('feature_type_aid'),
        is_landmark   => $apr->param('is_landmark'),
        direction     => $apr->param('direction'),
        feature_start => $apr->param('feature_start'),
        feature_stop  => $apr->param('feature_stop'),
    );

    $admin->purge_cache(3);
    return $self->redirect_home(
        ADMIN_HOME_URI . "?action=feature_view;feature_id=$feature_id" );
}

# ----------------------------------------------------
sub feature_view {
    my $self         = shift;
    my $sql_object   = $self->sql;
    my $apr          = $self->apr;
    my $feature_id   = $apr->param('feature_id') or die 'No feature id';
    my $order_by     = $apr->param('order_by') || '';
    my $att_order_by = $apr->param('att_order_by') || q{};

    my $features = $sql_object->get_features( feature_id => $feature_id, );
    return $self->error("No feature for ID '$feature_id'")
        unless ( $features and @$features );
    my $feature = $features->[0];

    $feature->{'aliases'}
        = $sql_object->get_feature_aliases( feature_id => $feature_id, );
    $feature->{'attributes'} = $sql_object->get_attributes(
        object_type => 'feature',
        object_id   => $feature_id,
    );

    # Sort object using the Utils method sort_selectall_arrayref
    $feature->{'attributes'}
        = sort_selectall_arrayref( $feature->{'attributes'},
        $self->_split_order_by_for_sort($att_order_by) );

    $feature->{'xrefs'} = $sql_object->get_xrefs(
        object_type => 'feature',
        object_id   => $feature_id,
    );

    # Sort object using the Utils method sort_selectall_arrayref
    $feature->{'xrefs'} = sort_selectall_arrayref( $feature->{'xrefs'},
        $self->_split_order_by_for_sort($att_order_by) );

    my $correspondences = $sql_object->get_feature_correspondence_details(
        feature_id1             => $feature_id,
        disregard_evidence_type => 1,
    );

    for my $corr (@$correspondences) {
        $corr->{'evidence'} = $sql_object->get_correspondence_evidences(
            feature_correspondence_id => $corr->{'feature_correspondence_id'},
        );

        $corr->{'aliases2'} = [
            map { $_->{'alias'} } @{
                $sql_object->get_feature_aliases(
                    feature_id => $corr->{'feature_id2'},
                )
                }
        ];
    }

    $feature->{'correspondences'} = $correspondences;

    return $self->process_template( ADMIN_TEMPLATE->{'feature_view'},
        { feature => $feature } );
}

# ----------------------------------------------------
sub feature_search {
    my $self              = shift;
    my $apr               = $self->apr;
    my $admin             = $self->admin;
    my $page_no           = $apr->param('page_no') || 1;
    my @species_ids       = ( $apr->param('species_id') || () );
    my @feature_type_accs = ( $apr->param('feature_type_acc')
            || $apr->param('feature_type_aid')
            || () );
    my $sql_object = $self->sql or die "SQL object not found\n";

    my @all_feature_type_accs =
        keys( %{ $self->config_data('feature_type') } );
    my %feature_type_name_lookup;
    foreach my $ft_acc (@all_feature_type_accs) {
        $feature_type_name_lookup{$ft_acc}
            = $self->config_data('feature_type')->{$ft_acc}{'feature_type'};
    }

    my $params = {
        apr                      => $apr,
        species                  => $sql_object->get_species(),
        feature_type_accs        => \@all_feature_type_accs,
        species_lookup           => { map { $_, 1 } @species_ids },
        feature_type_acc_lookup  => { map { $_, 1 } @feature_type_accs },
        feature_type_name_lookup => \%feature_type_name_lookup,
    };

    #
    # If given a feature to search for ...
    #
    if ( my $feature_name = $apr->param('feature_name') ) {

        #xxx
        my $result = $admin->feature_search(
            feature_name => $feature_name,
            search_field => $apr->param('search_field') || '',
            map_acc => $apr->param('map_acc') || $apr->param('map_aid') || 0,
            species_ids       => \@species_ids,
            feature_type_accs => \@feature_type_accs,
            order_by          => $apr->param('order_by') || '',
            entries_per_page  => $PAGE_SIZE,
            current_page      => $page_no,
            pages_per_set     => $MAX_PAGES,
        );

        $params->{'pager'}    = $result->{'pager'};
        $params->{'features'} = $result->{'results'};
    }

    return $self->process_template( ADMIN_TEMPLATE->{'feature_search'},
        $params );
}

# ----------------------------------------------------
sub feature_corr_create {
    my ( $self, %args ) = @_;
    my $sql_object    = $self->sql or return $self->error;
    my $apr           = $self->apr;
    my $feature_id1   = $apr->param('feature_id1') or die 'No feature id';
    my $feature_id2   = $apr->param('feature_id2') || 0;
    my $feature2_name = $apr->param('feature2_name') || '';
    my $species_id    = $apr->param('species_id') || 0;

    my $feature_array
        = $sql_object->get_features( feature_id => $feature_id1, );
    return $self->error("No feature for ID '$feature_id1'")
        unless ( $feature_array and @$feature_array );
    my $feature1 = $feature_array->[0];

    my $feature2;
    if ($feature_id2) {
        $feature_array
            = $sql_object->get_features( feature_id => $feature_id2, );
        return $self->error("No feature for ID '$feature_id2'")
            unless ( $feature_array and @$feature_array );
        $feature2 = $feature_array->[0];
    }

    my $feature2_choices;
    if ($feature2_name) {
        $feature2_name =~ s/\*/%/g;
        $feature2_name =~ s/['"]//g;    #'
        $feature2_choices = $sql_object->get_features(
            feature_name => $feature2_name,
            species_id   => $species_id,
        );
    }

    my $species = $sql_object->get_species();

    my @evidence_type_accs =
        keys( %{ $self->config_data('evidence_type') } );
    my $evidence_types;
    foreach my $type_acc (@evidence_type_accs) {
        my $et = $self->evidence_type_data($type_acc)
            or return $self->error("No evidence type accession '$type_acc'");
        $et->{'evidence_type_acc'} = $type_acc;
        push @$evidence_types, $et;
    }

    return $self->process_template(
        ADMIN_TEMPLATE->{'feature_corr_create'},
        {   apr              => $apr,
            feature1         => $feature1,
            feature2         => $feature2,
            feature2_choices => $feature2_choices,
            species          => $species,
            evidence_types   => $evidence_types,
            errors           => $args{'errors'},
        },
    );
}

# ----------------------------------------------------
sub feature_corr_insert {
    my $self        = shift;
    my @errors      = ();
    my $admin       = $self->admin or return;
    my $apr         = $self->apr;
    my $feature_id1 = $apr->param('feature_id1')
        or die 'No feature id1';
    my $feature_id2 = $apr->param('feature_id2')
        or die 'No feature id2';
    my $feature_correspondence_acc = $apr->param('feature_correspondence_acc')
        || $apr->param('feature_correspondence_aid')
        || '';
    my $is_enabled = $apr->param('is_enabled') || 0;
    my $evidence_type_acc = $apr->param('evidence_type_acc')
        || $apr->param('evidence_type_aid')
        or push @errors, 'Please select an evidence type';

    push @errors,
        "Can't create a circular correspondence (feature IDs are the same)"
        if $feature_id1 == $feature_id2;

    return $self->feature_corr_create( errors => \@errors ) if @errors;

    my $feature_correspondence_id = $admin->feature_correspondence_create(
        feature_id1                => $feature_id1,
        feature_id2                => $feature_id2,
        evidence_type_acc          => $evidence_type_acc,
        feature_correspondence_acc => $feature_correspondence_acc,
        is_enabled                 => $is_enabled
    );
    $admin->purge_cache(4);

    if ( $feature_correspondence_id < 0 ) {
        my $sql_object = $self->sql or return;
        my $feature_correspondences
            = $sql_object->get_feature_correspondence_details(
            feature_id1             => $feature_id1,
            feature_id2             => $feature_id2,
            disregard_evidence_type => 1,
            );
        if (@$feature_correspondences) {
            $feature_correspondence_id
                = $feature_correspondences->[0] {'feature_correspondence_id'};
        }
    }

    return $self->redirect_home( ADMIN_HOME_URI
            . '?action=feature_corr_view;'
            . "feature_correspondence_id=$feature_correspondence_id" );
}

# ----------------------------------------------------
sub feature_corr_edit {
    my $self                      = shift;
    my $sql_object                = $self->sql or return $self->error;
    my $apr                       = $self->apr;
    my $feature_correspondence_id = $apr->param('feature_correspondence_id')
        or return $self->error('No feature correspondence id');

    my $corrs = $sql_object->get_feature_correspondences_simple(
        feature_correspondence_id => $feature_correspondence_id, );
    return $self->error(
        "No correspondence for ID '$feature_correspondence_id,'")
        unless ( $corrs and @$corrs );
    my $corr = $corrs->[0];

    return $self->process_template( ADMIN_TEMPLATE->{'feature_corr_edit'},
        { corr => $corr } );
}

# ----------------------------------------------------
sub feature_corr_update {
    my $self                      = shift;
    my $sql_object                = $self->sql or return $self->error;
    my $apr                       = $self->apr;
    my $feature_correspondence_id = $apr->param('feature_correspondence_id')
        or return $self->error('No feature correspondence id');
    my $admin = $self->admin or return;

    $sql_object->update_feature_correspondence(
        feature_correspondence_id  => $feature_correspondence_id,
        feature_correspondence_acc =>
            $apr->param('feature_correspondence_acc')
            || $apr->param('feature_correspondence_aid'),
        is_enabled => $apr->param('is_enabled'),
    );

    $admin->purge_cache(4);
    return $self->redirect_home( ADMIN_HOME_URI
            . '?action=feature_corr_view;'
            . "feature_correspondence_id=$feature_correspondence_id" );
}

# ----------------------------------------------------
sub feature_corr_view {
    my $self       = shift;
    my $sql_object = $self->sql or return $self->error;
    my $apr        = $self->apr;
    my $order_by   = $apr->param('order_by')
        || 'evidence_type_acc';
    my $feature_correspondence_id = $apr->param('feature_correspondence_id')
        or return $self->error('No feature correspondence id');
    my $att_order_by = $apr->param('att_order_by') || q{};

    my $corr = $sql_object->get_feature_correspondences(
        feature_correspondence_id => $feature_correspondence_id, )
        or return $sql_object->error();

    $corr->{'attributes'} = $sql_object->get_attributes(
        object_type => 'feature_correspondence',
        object_id   => $feature_correspondence_id,
    );

    # Sort object using the Utils method sort_selectall_arrayref
    $corr->{'attributes'} = sort_selectall_arrayref( $corr->{'attributes'},
        $self->_split_order_by_for_sort($att_order_by) );

    $corr->{'xrefs'} = $sql_object->get_xrefs(
        object_type => 'feature_correspondence',
        object_id   => $feature_correspondence_id,
    );

    # Sort object using the Utils method sort_selectall_arrayref
    $corr->{'xrefs'} = sort_selectall_arrayref( $corr->{'xrefs'},
        $self->_split_order_by_for_sort($att_order_by) );

    my $feature1
        = $sql_object->get_features( feature_id => $corr->{'feature_id1'}, );
    $feature1 = $feature1->[0] if $feature1;

    my $feature2
        = $sql_object->get_features( feature_id => $corr->{'feature_id2'}, );
    $feature2 = $feature2->[0] if $feature2;

    $corr->{'evidence'} = $sql_object->get_correspondence_evidences(
        feature_correspondence_id => $feature_correspondence_id, );

    # Sort object using the Utils method sort_selectall_arrayref
    $corr->{'evidence'} = sort_selectall_arrayref( $corr->{'evidence'},
        $self->_split_order_by_for_sort($order_by) );

    return $self->process_template(
        ADMIN_TEMPLATE->{'feature_corr_view'},
        {   corr     => $corr,
            feature1 => $feature1,
            feature2 => $feature2,
        }
    );
}

# ----------------------------------------------------
sub corr_evidence_create {
    my ( $self, %args ) = @_;
    my $sql_object                = $self->sql or return $self->error;
    my $apr                       = $self->apr;
    my $feature_correspondence_id = $apr->param('feature_correspondence_id')
        or return $self->error('No feature correspondence id');

    my $correspondences = $sql_object->get_feature_correspondence_details(
        feature_correspondence_id => $feature_correspondence_id,
        disregard_evidence_type   => 1,
    );
    return $self->error(
        "No feature correspondence for ID '$feature_correspondence_id'")
        unless (@$correspondences);
    my $corr = $correspondences->[0];

    my @evidence_type_accs =
        keys( %{ $self->config_data('evidence_type') } );
    my $evidence_types;
    foreach my $type_acc (@evidence_type_accs) {
        push @$evidence_types, $self->evidence_type_data($type_acc)
            or return $self->error("No evidence type accession '$type_acc'");
    }

    return $self->process_template(
        ADMIN_TEMPLATE->{'corr_evidence_create'},
        {   corr           => $corr,
            evidence_types => $evidence_types,
            errors         => $args{'errors'},
        }
    );
}

# ----------------------------------------------------
sub corr_evidence_edit {
    my ( $self, %args ) = @_;
    my $sql_object                 = $self->sql;
    my $apr                        = $self->apr;
    my $correspondence_evidence_id = $apr->param('correspondence_evidence_id')
        or die 'No correspondence evidence id';

    my $evidences = $sql_object->get_correspondence_evidences(
        correspondence_evidence_id => $correspondence_evidence_id, );
    return $self->error(
        "No feature evidnece for ID '$correspondence_evidence_id'")
        unless (@$evidences);
    my $evidence = $evidences->[0];

    my @evidence_type_accs =
        keys( %{ $self->config_data('evidence_type') } );
    my $evidence_types;
    foreach my $type_acc (@evidence_type_accs) {
        push @$evidence_types, $self->evidence_type_data($type_acc)
            or return $self->error("No evidence type accession '$type_acc'");
    }

    return $self->process_template(
        ADMIN_TEMPLATE->{'corr_evidence_edit'},
        {   evidence       => $evidence,
            evidence_types => $evidence_types,
            errors         => $args{'errors'},
        }
    );
}

# ----------------------------------------------------
sub corr_evidence_insert {
    my $self                      = shift;
    my @errors                    = ();
    my $sql_object                = $self->sql or return $self->error;
    my $apr                       = $self->apr;
    my $feature_correspondence_id = $apr->param('feature_correspondence_id')
        or push @errors, 'No feature correspondence id';
    my $evidence_type_acc = $apr->param('evidence_type_acc')
        || $apr->param('evidence_type_aid')
        or push @errors, 'No evidence type';
    my $score = $apr->param('score');
    $score = '' unless ( defined $score );

    $sql_object->insert_correspondence_evidence(
        evidence_type_acc           => $evidence_type_acc,
        feature_correspondence_id   => $feature_correspondence_id,
        correspondence_evidence_acc =>
            $apr->param('correspondence_evidence_acc')
            || $apr->param('correspondence_evidence_aid')
            || '',
        score => $score,
    );

    return $self->redirect_home( ADMIN_HOME_URI
            . '?action=feature_corr_view;'
            . "feature_correspondence_id=$feature_correspondence_id" );
}

# ----------------------------------------------------
sub corr_evidence_update {
    my $self                       = shift;
    my @errors                     = ();
    my $sql_object                 = $self->sql or return $self->error;
    my $apr                        = $self->apr;
    my $correspondence_evidence_id = $apr->param('correspondence_evidence_id')
        or push @errors, 'No correspondence evidence id';

    my $feature_correspondence_id = $apr->param('feature_correspondence_id');
    return $self->corr_evidence_edit( errors => \@errors ) if @errors;
    my $admin = $self->admin or return;
    my $rank = $apr->param('rank') || 1;
    my $score = $apr->param('score');
    $score = '' unless ( defined $score );

    $sql_object->update_correspondence_evidence(
        correspondence_evidence_id => $correspondence_evidence_id,
        evidence_type_acc          => $apr->param('evidence_type_acc')
            || $apr->param('evidence_type_aid'),
        feature_correspondence_id   => $feature_correspondence_id,
        correspondence_evidence_acc =>
            $apr->param('correspondence_evidence_acc')
            || $apr->param('correspondence_evidence_aid'),
        score => $score,
        rank  => $rank,
    );

    $admin->purge_cache(4);
    return $self->redirect_home( ADMIN_HOME_URI
            . '?action=feature_corr_view;'
            . "feature_correspondence_id=$feature_correspondence_id" );
}

# ----------------------------------------------------
sub feature_type_create {
    return 0;
    ###Do this in Config
}

# ----------------------------------------------------
sub feature_type_edit {
    ###Do this in config file
    return 0;
    my ( $self, %args ) = @_;
}

# ----------------------------------------------------
sub feature_type_insert {
    ###Do this in config file
    return 0;
}

# ----------------------------------------------------
sub feature_type_update {
    my ( $self, %args ) = @_;
    return 0;

    #Do this in Config file
}

# ----------------------------------------------------
sub feature_type_view {
    my ( $self, %args ) = @_;
    my $apr                       = $self->apr;
    my $incoming_feature_type_acc = $apr->param('feature_type_acc')
        || $apr->param('feature_type_aid')
        or die 'No feature type id';
    my $feature_type = $self->feature_type_data($incoming_feature_type_acc)
        or return $self->error(
        "No feature type for accession '$incoming_feature_type_acc'");

    return $self->process_template(
        ADMIN_TEMPLATE->{'feature_type_view'},
        { feature_type => $feature_type, }
    );
}

# ----------------------------------------------------
sub feature_types_view {
    my $self     = shift;
    my $apr      = $self->apr;
    my $order_by = $apr->param('order_by') || 'feature_type_acc';
    my $page_no  = $apr->param('page_no') || 1;

    my @feature_type_accs =
        keys( %{ $self->config_data('feature_type') } );
    my $feature_types_hash;
    foreach my $type_acc (@feature_type_accs) {
        $feature_types_hash->{$type_acc} = $self->feature_type_data($type_acc)
            or return $self->error("No feature type accession '$type_acc'");
    }

    my $feature_types;
    foreach my $type_acc ( keys( %{$feature_types_hash} ) ) {
        $feature_types_hash->{$type_acc}{'feature_type_acc'} = $type_acc;
        push @$feature_types, $feature_types_hash->{$type_acc};
    }

    # Sort object using the Utils method sort_selectall_arrayref
    $feature_types = sort_selectall_arrayref( $feature_types,
        $self->_split_order_by_for_sort($order_by) );

    #
    # Slice the results up into pages suitable for web viewing.
    #
    my $pager = Data::Pageset->new(
        {   total_entries    => scalar @$feature_types,
            entries_per_page => $PAGE_SIZE,
            current_page     => $page_no,
            pages_per_set    => $MAX_PAGES,
        }
    );
    $feature_types
        = @$feature_types ? [ $pager->splice($feature_types) ] : [];

    return $self->process_template(
        ADMIN_TEMPLATE->{'feature_types_view'},
        {   feature_types => $feature_types,
            pager         => $pager,
        }
    );
}

# ----------------------------------------------------
sub map_sets_view {
    my $self         = shift;
    my $sql_object   = $self->sql;
    my $apr          = $self->apr;
    my $map_type_acc = $apr->param('map_type_acc')
        || $apr->param('map_type_aid')
        || '';
    my $species_id = $apr->param('species_id') || '';
    my $is_enabled = $apr->param('is_enabled');
    my $page_no    = $apr->param('page_no') || 1;
    my $order_by   = $apr->param('order_by') || '';

    if ($order_by) {
        $order_by .= ',map_set_short_name'
            unless $order_by eq 'map_set_short_name';
    }
    else {
        $order_by = 'ms.display_order, map_type_acc, '
            . 's.display_order, s.species_common_name, '
            . 'ms.display_order, ms.published_on desc, ms.map_set_short_name';
    }

    my $map_sets = $sql_object->get_map_sets(
        map_type_acc => $map_type_acc,
        species_id   => $species_id,
        is_enabled   => $is_enabled,
        count_maps   => 1,
    );

    # Sort object using the Utils method sort_selectall_arrayref
    $map_sets = sort_selectall_arrayref( $map_sets,
        $self->_split_order_by_for_sort($order_by) );

    #
    # Slice the results up into pages suitable for web viewing.
    #
    my $pager = Data::Pageset->new(
        {   total_entries    => scalar @$map_sets,
            entries_per_page => $PAGE_SIZE,
            current_page     => $page_no,
            pages_per_set    => $MAX_PAGES,
        }
    );
    $map_sets = @$map_sets ? [ $pager->splice($map_sets) ] : [];

    my $specie = $sql_object->get_species();
    my $map_types;
    my $index = 0;
    foreach my $map_type_acc ( keys( %{ $self->map_type_data() } ) ) {
        $map_types->[$index]->{'map_type_acc'} = $map_type_acc;
        $map_types->[$index]->{'map_type'}
            = $self->map_type_data( $map_type_acc, 'map_type' );
        $index++;
    }

    return $self->process_template(
        ADMIN_TEMPLATE->{'map_sets_view'},
        {   apr       => $apr,
            specie    => $specie,
            map_types => $map_types,
            map_sets  => $map_sets,
            pager     => $pager,
        }
    );
}

# ----------------------------------------------------
sub map_set_create {
    my ( $self, %args ) = @_;
    my $errors     = $args{'errors'};
    my $sql_object = $self->sql or return $self->error;
    my $apr        = $self->apr;

    my $specie = $sql_object->get_species();

    return $self->error(
        'Please <a href="admin?action=species_create">create species</a> '
            . 'before creating map sets.' )
        unless @$specie;

    my @map_type_accs = keys( %{ $self->map_type_data() } );

    return $self->error( 'Please create map types in your configuration file '
            . 'before creating map sets.' )
        unless @map_type_accs;

    my %map_type_name_lookup;
    foreach my $ft_acc (@map_type_accs) {
        $map_type_name_lookup{$ft_acc}
            = $self->config_data('map_type')->{$ft_acc}{'map_type'};
    }
    return $self->process_template(
        ADMIN_TEMPLATE->{'map_set_create'},
        {   apr                  => $apr,
            errors               => $errors,
            specie               => $specie,
            map_type_accs        => \@map_type_accs,
            colors               => $COLORS,
            shapes               => $MAP_SHAPES,
            widths               => $WIDTHS,
            map_type_name_lookup => \%map_type_name_lookup,
        }
    );
}

# ----------------------------------------------------
sub map_set_edit {
    my ( $self, %args ) = @_;
    my $errors       = $args{'errors'};
    my $sql_object   = $self->sql;
    my $apr          = $self->apr;
    my $map_set_id   = $apr->param('map_set_id') or die 'No map set ID';
    my $att_order_by = $apr->param('att_order_by') || q{};

    my $map_sets = $sql_object->get_map_sets( map_set_id => $map_set_id, );
    return $self->error("No map set for ID '$map_set_id'")
        unless ( $map_sets and @$map_sets );
    my $map_set = $map_sets->[0];

    $map_set->{'attributes'} = $sql_object->get_attributes(
        object_type => 'map_set',
        object_id   => $map_set_id,
    );

    # Sort object using the Utils method sort_selectall_arrayref
    $map_set->{'attributes'}
        = sort_selectall_arrayref( $map_set->{'attributes'},
        $self->_split_order_by_for_sort($att_order_by) );

    my $specie = $sql_object->get_species();

    my @map_type_accs = keys( %{ $self->config_data('map_type') } );
    my %map_type_name_lookup;
    my %map_type_unit_lookup;
    foreach my $ft_acc (@map_type_accs) {
        $map_type_name_lookup{$ft_acc}
            = $self->config_data('map_type')->{$ft_acc}{'map_type'};
        $map_type_unit_lookup{$ft_acc}
            = $self->config_data('map_type')->{$ft_acc}{'map_units'};
    }

    return $self->process_template(
        ADMIN_TEMPLATE->{'map_set_edit'},
        {   map_set              => $map_set,
            specie               => $specie,
            map_type_accs        => \@map_type_accs,
            map_type_name_lookup => \%map_type_name_lookup,
            map_type_unit_lookup => \%map_type_unit_lookup,
            colors               => $COLORS,
            shapes               => $MAP_SHAPES,
            widths               => $WIDTHS,
            errors               => $errors,
        }
    );
}

# ----------------------------------------------------
sub map_set_insert {
    my $self       = shift;
    my $apr        = $self->apr;
    my $admin      = $self->admin;
    my $map_set_id = $admin->map_set_create(
        map_set_name       => $apr->param('map_set_name')       || '',
        map_set_short_name => $apr->param('map_set_short_name') || '',
        species_id         => $apr->param('species_id')         || '',
        map_type_acc       => $apr->param('map_type_acc')
            || $apr->param('map_type_aid')
            || '',
        map_set_acc => $apr->param('map_set_acc')
            || $apr->param('map_set_aid')
            || '',
        display_order     => $apr->param('display_order')     || 1,
        is_relational_map => $apr->param('is_relational_map') || 0,
        shape             => $apr->param('shape')             || '',
        color             => $apr->param('color')             || '',
        width             => $apr->param('width')             || 0,
        published_on      => $apr->param('published_on')      || 'today',
        )
        or return $self->map_set_create( errors => $admin->error );

    $admin->purge_cache(1);
    return $self->redirect_home(
        ADMIN_HOME_URI . "?action=map_set_view;map_set_id=$map_set_id",
    );
}

# ----------------------------------------------------
sub map_set_view {
    my $self         = shift;
    my $sql_object   = $self->sql;
    my $apr          = $self->apr;
    my $map_set_id   = $apr->param('map_set_id') or die 'No map set id';
    my $order_by     = $apr->param('order_by') || 'display_order,map_name';
    my $page_no      = $apr->param('page_no') || 1;
    my $att_order_by = $apr->param('att_order_by') || q{};

    my $map_sets = $sql_object->get_map_sets( map_set_id => $map_set_id, );
    return $self->error("No map set for ID '$map_set_id'")
        unless ( $map_sets and @$map_sets );
    my $map_set = $map_sets->[0];
    $map_set->{'object_id'}  = $map_set_id;
    $map_set->{'attributes'} = $sql_object->get_attributes(
        object_type => 'map_set',
        object_id   => $map_set_id,
    );

    # Sort object using the Utils method sort_selectall_arrayref
    $map_set->{'attributes'}
        = sort_selectall_arrayref( $map_set->{'attributes'},
        $self->_split_order_by_for_sort($att_order_by) );

    $map_set->{'xrefs'} = $sql_object->get_xrefs(
        object_type => 'map_set',
        object_id   => $map_set_id,
    );

    # Sort object using the Utils method sort_selectall_arrayref
    $map_set->{'xrefs'} = sort_selectall_arrayref( $map_set->{'xrefs'},
        $self->_split_order_by_for_sort($att_order_by) );

    my $maps = $sql_object->get_maps(
        map_set_id     => $map_set_id,
        count_features => 1,
    );

    # Sort object using the Utils method sort_selectall_arrayref
    $maps = sort_selectall_arrayref( $maps,
        $self->_split_order_by_for_sort($order_by) );

    #
    # Slice the results up into pages suitable for web viewing.
    #
    my $pager = Data::Pageset->new(
        {   total_entries    => scalar @$maps,
            entries_per_page => $PAGE_SIZE,
            current_page     => $page_no,
            pages_per_set    => $MAX_PAGES,
        }
    );

    $map_set->{'maps'} = @{ $maps || [] } ? [ $pager->splice($maps) ] : [];
    $apr->param( order_by => $order_by );

    return $self->process_template(
        ADMIN_TEMPLATE->{'map_set_view'},
        {   apr     => $apr,
            map_set => $map_set,
            pager   => $pager,
        }
    );
}

# ----------------------------------------------------
sub map_set_update {
    my $self         = shift;
    my $sql_object   = $self->sql;
    my $apr          = $self->apr;
    my @errors       = ();
    my $map_set_id   = $apr->param('map_set_id') || 0;
    my $map_type_acc = $apr->param('map_type_acc')
        || $apr->param('map_type_aid');

    my $published_on = $apr->param('published_on') || 'today';

    if ($published_on) {
        {
            my $pub_date = parsedate( $published_on, VALIDATE => 1 )
                or do {
                push @errors, "Publication date '$published_on' is not valid";
                last;
                };
            my $t = localtime($pub_date);
            $published_on = $t->strftime( $sql_object->date_format );
        }
    }

    return $self->map_set_edit( errors => \@errors ) if @errors;
    my $admin = $self->admin or return;

    $sql_object->update_map_set(
        map_set_id  => $map_set_id,
        map_set_acc => $apr->param('map_set_acc')
            || $apr->param('map_set_aid'),
        map_set_name       => $apr->param('map_set_name'),
        map_set_short_name => $apr->param('map_set_short_name'),
        species_id         => $apr->param('species_id'),
        map_type_acc       => $map_type_acc,
        is_relational_map  => $apr->param('is_relational_map'),
        is_enabled         => $apr->param('is_enabled'),
        display_order      => $apr->param('display_order'),
        shape              => $apr->param('shape'),
        color              => $apr->param('color'),
        width              => $apr->param('width'),
        map_units          =>
            $self->config_data('map_type')->{$map_type_acc}{'map_units'},
        published_on => $published_on,
    );
    $admin->purge_cache(1);

    return $self->redirect_home(
        ADMIN_HOME_URI . "?action=map_set_view;map_set_id=$map_set_id",
    );
}

# ----------------------------------------------------
sub redirect_home {
    my ( $self, $uri ) = @_;
    my $apr = $self->apr;
    print $apr->redirect($uri);
    return 1;
}

# ----------------------------------------------------
sub map_type_create {
    return 0;
    ###Do this in Config
}

# ----------------------------------------------------
sub map_type_edit {
    my ( $self, %args ) = @_;
    return 0;

    #Do this in Config file
}

# ----------------------------------------------------
sub map_type_insert {
    my ( $self, %args ) = @_;
    return 0;

    #Do this in Config file

}

# ----------------------------------------------------
sub map_type_update {
    my ( $self, %args ) = @_;
    return 0;

    #Do this in Config file
}

# ----------------------------------------------------
sub map_type_view {
    my ( $self, %args ) = @_;
    my $apr                   = $self->apr;
    my $incoming_map_type_acc = $apr->param('map_type_acc')
        || $apr->param('map_type_aid')
        or die 'No map type ID';
    my $map_type = $self->map_type_data($incoming_map_type_acc)
        or return $self->error(
        "No map type for accession '$incoming_map_type_acc'");

    return $self->process_template( ADMIN_TEMPLATE->{'map_type_view'},
        { map_type => $map_type, } );
}

# ----------------------------------------------------
sub map_types_view {
    my $self     = shift;
    my $apr      = $self->apr;
    my $order_by = $apr->param('order_by')
        || 'display_order,map_type_acc';
    my $page_no = $apr->param('page_no') || 1;

    my @map_type_accs = keys( %{ $self->config_data('map_type') } );
    my $map_types_hash;
    foreach my $type_acc (@map_type_accs) {
        $map_types_hash->{$type_acc} = $self->map_type_data($type_acc)
            or return $self->error("No map type accession '$type_acc'");
    }
    my $map_types;
    foreach my $type_acc ( keys( %{$map_types_hash} ) ) {
        $map_types_hash->{$type_acc}{'map_type_acc'} = $type_acc;
        push @$map_types, $map_types_hash->{$type_acc};
    }

    # Sort object using the Utils method sort_selectall_arrayref
    $map_types = sort_selectall_arrayref( $map_types,
        $self->_split_order_by_for_sort($order_by) );

    my $pager = Data::Pageset->new(
        {   total_entries    => scalar @$map_types,
            entries_per_page => $PAGE_SIZE,
            current_page     => $page_no,
            pages_per_set    => $MAX_PAGES,
        }
    );
    $map_types = @$map_types ? [ $pager->splice($map_types) ] : [];

    return $self->process_template(
        ADMIN_TEMPLATE->{'map_types_view'},
        {   map_types => $map_types,
            pager     => $pager,
        }
    );
}

# ----------------------------------------------------
sub process_template {
    my ( $self, $template, $params ) = @_;

    $params->{'stylesheet'}          = $self->stylesheet;
    $params->{'data_source'}         = $self->data_source;
    $params->{'data_sources'}        = $self->data_sources;
    $params->{'web_image_cache_dir'} = $self->web_image_cache_dir();
    $params->{'web_cmap_htdocs_dir'} = $self->web_cmap_htdocs_dir();

    my $output;
    my $t = $self->template or return;
    $t->process( $template, $params, \$output ) or $output = $t->error;

    my $apr = $self->apr;
    print $apr->header(
        -type   => 'text/html',
        -cookie => $self->cookie
    ), $output;
    return 1;
}

# ----------------------------------------------------
sub species_create {
    my ( $self, %args ) = @_;
    return $self->process_template(
        ADMIN_TEMPLATE->{'species_create'},
        {   apr    => $self->apr,
            errors => $args{'errors'},
        }
    );
}

# ----------------------------------------------------
sub species_edit {
    my ( $self, %args ) = @_;
    my $sql_object = $self->sql;
    my $apr        = $self->apr;
    my $species_id = $apr->param('species_id') or die 'No species_id';

    my $species_array = $sql_object->get_species( species_id => $species_id );
    return $self->error("No species for ID '$species_id'")
        unless ( $species_array and @$species_array );
    my $species = $species_array->[0];

    return $self->process_template(
        ADMIN_TEMPLATE->{'species_edit'},
        {   species => $species,
            errors  => $args{'errors'},
        }
    );
}

# ----------------------------------------------------
sub species_insert {
    my $self  = shift;
    my $apr   = $self->apr;
    my $admin = $self->admin;

    $admin->species_create(
        species_acc => $apr->param('species_acc')
            || $apr->param('species_aid')
            || '',
        species_common_name => $apr->param('species_common_name') || '',
        species_full_name   => $apr->param('species_full_name')   || '',
        display_order       => $apr->param('display_order')       || '',
        )
        or return $self->species_create( errors => $admin->error );
    $admin->purge_cache(1);

    return $self->redirect_home( ADMIN_HOME_URI . '?action=species_view' );
}

# ----------------------------------------------------
sub species_update {
    my $self       = shift;
    my @errors     = ();
    my $sql_object = $self->sql;
    my $apr        = $self->apr;
    my $species_id = $apr->param('species_id')
        or push @errors, 'No species id';

    return $self->species_edit( errors => \@errors ) if @errors;
    my $admin = $self->admin or return;

    $sql_object->update_species(
        species_id  => $species_id,
        species_acc => $apr->param('species_acc')
            || $apr->param('species_aid'),
        species_common_name => $apr->param('species_common_name'),
        species_full_name   => $apr->param('species_full_name'),
        display_order       => $apr->param('display_order'),
    );

    $admin->purge_cache(1);
    return $self->redirect_home( ADMIN_HOME_URI . '?action=species_view' );
}

# ----------------------------------------------------
sub species_view {
    my $self       = shift;
    my $sql_object = $self->sql;
    my $apr        = $self->apr;
    my $species_id = $apr->param('species_id') || 0;
    my $order_by   = $apr->param('order_by')
        || 'display_order,species_common_name';
    my $page_no      = $apr->param('page_no')      || 1;
    my $att_order_by = $apr->param('att_order_by') || q{};

    if ($species_id) {
        my $species_array
            = $sql_object->get_species( species_id => $species_id, );
        return $self->error("No species for ID '$species_id'")
            unless ( $species_array and @$species_array );
        my $species = $species_array->[0];

        $species->{'attributes'} = $sql_object->get_attributes(
            object_type => 'species',
            object_id   => $species_id,
        );

        # Sort object using the Utils method sort_selectall_arrayref
        $species->{'attributes'}
            = sort_selectall_arrayref( $species->{'attributes'},
            $self->_split_order_by_for_sort($att_order_by) );

        $species->{'xrefs'} = $sql_object->get_xrefs(
            object_type => 'species',
            object_id   => $species_id,
        );

        # Sort object using the Utils method sort_selectall_arrayref
        $species->{'xrefs'} = sort_selectall_arrayref( $species->{'xrefs'},
            $self->_split_order_by_for_sort($att_order_by) );

        return $self->process_template( ADMIN_TEMPLATE->{'species_view_one'},
            { species => $species, } );
    }
    else {
        my $species = $sql_object->get_species();

        # Sort object using the Utils method sort_selectall_arrayref
        $species = sort_selectall_arrayref( $species,
            $self->_split_order_by_for_sort($order_by) );

        my $pager = Data::Pageset->new(
            {   total_entries    => scalar @$species,
                entries_per_page => $PAGE_SIZE,
                current_page     => $page_no,
                pages_per_set    => $MAX_PAGES,
            }
        );
        $species = @$species ? [ $pager->splice($species) ] : [];
        return $self->process_template(
            ADMIN_TEMPLATE->{'species_view'},
            {   species => $species,
                pager   => $pager,
            }
        );
    }
}

# ----------------------------------------------------
sub xref_create {
    my ( $self, %args ) = @_;
    my $apr = $self->apr or return;
    my $object_type = $apr->param('object_type') || '';
    my $object_id   = $apr->param('object_id')   || 0;
    my %db_object;
    my $sql_object = $self->sql;

    if ( $object_type && $object_id ) {
        $db_object{'name'} = $sql_object->get_object_name(
            object_id   => $object_id,
            object_type => $object_type,
        );
        my $obj = $XREF_OBJ_LOOKUP{$object_type};
        $db_object{'object_name'} = $obj->{'object_name'};
        $db_object{'object_type'} = $object_type;
    }

    return $self->process_template(
        ADMIN_TEMPLATE->{'xref_create'},
        {   apr          => $self->apr,
            errors       => $args{'errors'},
            xref_objects => ADMIN_XREF_OBJECTS,
            object_type  => $object_type,
            object_id    => $object_id,
            db_object    => \%db_object,
        }
    );
}

# ----------------------------------------------------
sub xref_edit {
    my ( $self, %args ) = @_;
    my $apr        = $self->apr;
    my $xref_id    = $apr->param('xref_id') or die 'No xref id';
    my $admin      = $self->admin;
    my $sql_object = $self->sql or return $self->error;
    my $xrefs      = $sql_object->get_xrefs( xref_id => $xref_id, );
    my $xref       = $xrefs->[0];
    return $self->error("No database cross-reference for ID '$xref_id'")
        unless $xref;

    my $object_type = $xref->{'object_type'} || '';
    my $object_id   = $xref->{'object_id'}   || '';
    my %db_object;

    if ( $object_type && $object_id ) {
        $db_object{'name'} = $sql_object->get_object_name(
            object_id   => $object_id,
            object_type => $object_type,
        );
        my $obj = $XREF_OBJ_LOOKUP{$object_type};
        $db_object{'object_name'} = $obj->{'object_name'};
        $db_object{'object_type'} = $object_type;
    }

    return $self->process_template(
        ADMIN_TEMPLATE->{'xref_edit'},
        {   apr          => $self->apr,
            errors       => $args{'errors'},
            xref         => $xref,
            xref_objects => ADMIN_XREF_OBJECTS,
            object_type  => $object_type,
            object_id    => $object_id,
            db_object    => \%db_object,
        }
    );
}

# ----------------------------------------------------
sub xref_insert {
    my $self          = shift;
    my $apr           = $self->apr;
    my $admin         = $self->admin;
    my $pk_name       = $apr->param('pk_name') || '';
    my $return_action = $apr->param('return_action') || '';
    my $object_id     = $apr->param('object_id') || 0;

    $admin->xref_create(
        object_id     => $object_id,
        object_type   => $apr->param('object_type') || '',
        xref_name     => $apr->param('xref_name') || '',
        xref_url      => $apr->param('xref_url') || '',
        display_order => $apr->param('display_order') || '',
        )
        or return $self->xref_create( errors => $admin->error );

    $admin->purge_cache(1);
    my $action =
           $return_action
        && $pk_name
        && $object_id
        ? "$return_action;$pk_name=$object_id"
        : 'xrefs_view';

    return $self->redirect_home( ADMIN_HOME_URI . "?action=$action" );
}

# ----------------------------------------------------
sub xref_update {
    my $self          = shift;
    my $sql_object    = $self->sql or return $self->error;
    my $apr           = $self->apr;
    my $admin         = $self->admin;
    my @errors        = ();
    my $xref_id       = $apr->param('xref_id') or die 'No xref id';
    my $object_id     = $apr->param('object_id') || undef;
    my $return_action = $apr->param('return_action') || '';
    my $display_order = $apr->param('display_order');
    my $object_type   = $apr->param('object_type')
        or push @errors, 'No object type';
    my $name = $apr->param('xref_name')
        or push @errors, 'No xref name';
    my $url = $apr->param('xref_url')
        or push @errors, 'No URL';

    return $self->xref_edit( errors => \@errors ) if @errors;

    $admin->set_xrefs(
        object_id   => $object_id,
        object_type => $object_type,
        xrefs       => [
            {   xref_id       => $xref_id,
                name          => $name,
                url           => $url,
                display_order => $display_order,
            },
        ],
        )
        or return $self->error( $admin->error );

    $admin->purge_cache(1);
    my $pk_name  = $sql_object->pk_name($object_type);
    my $uri_args =
           $return_action
        && $pk_name
        && $object_id
        ? "action=$return_action;$pk_name=$object_id"
        : 'action=xrefs_view';

    return $self->redirect_home( ADMIN_HOME_URI . "?$uri_args" );
}

# ----------------------------------------------------
sub xrefs_view {
    my $self         = shift;
    my $sql_object   = $self->sql or return $self->error;
    my $admin        = $self->admin;
    my $apr          = $self->apr;
    my $order_by     = $apr->param('order_by') || 'display_order';
    my $generic_only = $apr->param('generic_only') || 0;
    my $object_type  = $apr->param('object_type') || '';
    my $page_no      = $apr->param('page_no') || 1;

    my $refs;
    if ($generic_only) {
        $refs
            = $sql_object->get_generic_xrefs( object_type => $object_type, );
    }
    else {
        $refs = $sql_object->get_xrefs( object_type => $object_type, );
    }

    # Sort object using the Utils method sort_selectall_arrayref
    $refs = sort_selectall_arrayref( $refs,
        $self->_split_order_by_for_sort($order_by) );

    my $pager = Data::Pageset->new(
        {   total_entries    => scalar @$refs,
            entries_per_page => $PAGE_SIZE,
            current_page     => $page_no,
            pages_per_set    => $MAX_PAGES,
        }
    );
    $refs = @$refs ? [ $pager->splice($refs) ] : [];
    for my $ref (@$refs) {
        my $object_id = $ref->{'object_id'};
        if ( $ref->{'object_id'} ) {
            $ref->{'actual_object_name'} = $sql_object->get_object_name(
                object_id   => $ref->{'object_id'},
                object_type => $ref->{'object_type'},
            );
        }
        my $obj = $XREF_OBJ_LOOKUP{$object_type};
        $ref->{'db_object_name'} = $obj->{'object_name'};
    }

    return $self->process_template(
        ADMIN_TEMPLATE->{'xrefs_view'},
        {   apr        => $apr,
            xrefs      => $refs,
            pager      => $pager,
            db_objects => ADMIN_XREF_OBJECTS,
        }
    );
}

# ---------------------------------------------------
# Prepare the order string for sort_selectall_arrayref
# This serves the purpose of collecting all of the numeric
# field modifications in one place.
sub _split_order_by_for_sort {
    my $self      = shift;
    my $order_str = shift or return ();

    # Numeric fields should have a # in front of them
    for my $numeric_column (
        qw[
        rank      map_count \w*display_order
        \w+_start \w+_stop   ]
        )
    {
        $order_str =~ s/($numeric_column)/#$1/g;
    }

    # in case of duplicate "#"s
    $order_str =~ s/##/#/g;

    # split on commas and remove excess white space
    return split( /\s*,\s*/, $order_str );
}

1;

# ----------------------------------------------------
# All wholsome food is caught without a net or a trap.
# William Blake
# ----------------------------------------------------

=head1 NAME

Bio::GMOD::CMap::Apache::AdminViewer - curate comparative map data

=head1 SYNOPSIS

In httpd.conf:

  <Location /maps/admin>
      AuthType     Basic
      AuthName     "Map Curation"
      AuthUserFile /usr/local/apache/passwd/passwords
      Require      valid-user
      SetHandler   perl-script
      PerlHandler  Bio::GMOD::CMap::Admin
  </Location>

=head1 DESCRIPTION

This module is intended to provide a basic, web-based frontend for the
curation of the data for comparative maps.  As this time, it's fairly
limited to allowing the creation of new map sets, editing/deleting of
existing sets, and importing of data.  However, there are a couple
of scripts that must be run whenever new maps are imported (or
corrected) -- namely one that updates feature correspondences and one
that updates the precomputed "feature" table.  Currently,
these must be run by hand.

It is strongly recommended that this <Location> include at least basic
authentication.  This will require you to read up on the "htpasswd"
program.  Essentially, you should be able to run:

  # htpasswd -c /path/to/passwd/file

This will "create" (-c) the file given as the last argument, so don't
use this if the file already exists.  You will be prompted for a user
name and password to save into that file.  After you've created this
file and edited your server's configuration file, restart Apache.

=head1 SEE ALSO

L<perl>, htpasswd.

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

