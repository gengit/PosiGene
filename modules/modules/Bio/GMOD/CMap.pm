package Bio::GMOD::CMap;

# vim: set ft=perl:

# $Id: CMap.pm,v 1.127 2008/07/01 16:24:07 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap.pm - base object for comparative maps

=head1 SYNOPSIS

  package Bio::GMOD::CMap::Foo;
  use Bio::GMOD::CMap;
  use base 'Bio::GMOD::CMap';

  sub foo { print "foo\n" }

  1;

=head1 DESCRIPTION

This is the base class for all the comparative maps modules.  It is
itself based on Andy Wardley's Class::Base module.

=head1 METHODS

=cut

use strict;
use vars '$VERSION';
$VERSION = '1.01';

use Data::Dumper;
use Class::Base;
use Config::General;
use Bio::GMOD::CMap::Data;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Config;

use Cache::SizeAwareFileCache;
use URI::Escape;
use DBI;
use File::Path;
use Filesys::DfPortable;
use File::Spec::Functions qw( abs2rel rootdir );
use Storable qw(nfreeze thaw);
use Template;

use base 'Class::Base';

# ----------------------------------------------------
sub init {
    my ( $self, $config ) = @_;
    $self->config( $config->{'config'} );
    $self->data_source( $config->{'data_source'} ) or return;
    return $self;
}

###########################################

=pod

=head2 Accessor Methods

These are methods that create and store variables.

=cut

# ----------------------------------------------------
sub cache_dir {

=pod

=head3 cache_dir

Returns the cache directory.

=cut

    my $self          = shift;
    my $new_cache_dir = shift;
    my $config        = $self->config or return;

    if ( defined($new_cache_dir) ) {
        $self->{'cache_dir'} = $new_cache_dir;
    }
    unless ( defined $self->{'cache_dir'} ) {
        unless ( $self->{'config'} ) {
            die "no configuration information\n";
        }

        my $cache_dir = $config->get_config('cache_dir')
            or return $self->error(
            'No cache directory defined in "' . GLOBAL_CONFIG_FILE . '"' );

        unless ( -d $cache_dir ) {
            eval { mkpath( $cache_dir, 0, 0700 ) };
            if ( my $err = $@ ) {
                return $self->error(
                    "Cache directory '$cache_dir' can't be created: $err");
            }
        }

        $self->{'cache_dir'} = $cache_dir;
    }

    return $self->{'cache_dir'};
}

# ----------------------------------------------------

=pod

=head3 config

Returns configuration object.

=cut

sub config {

    my $self      = shift;
    my $newConfig = shift;
    if ($newConfig) {
        $self->{'config'} = $newConfig;
    }
    unless ( defined $self->{'config'} ) {
        $self->{'config'}
            = Bio::GMOD::CMap::Config->new(
            config_dir => $self->{'config_dir'} )
            or return Bio::GMOD::CMap::Config->error;
    }

    return $self->{'config'};
}

# ----------------------------------------------------
sub config_data {

=pod

=head3 config_data

Access configuration.

=cut

    my $self = shift;
    my $config = $self->config or return;
    $config->get_config(@_);
}

# ----------------------------------------------------
sub object_plugin {

=pod

=head3 object_plugin

Allow for object plugin stuff.

=cut

    my ( $self, $obj_type, $object ) = @_;
    my $plugin_info = $self->config_data('object_plugin') or return;
    my $xref_sub    = $plugin_info->{$obj_type}           or return;

    if ( $xref_sub =~ /^\s*sub\s*{/ ) {
        $xref_sub = eval $xref_sub;
    }
    elsif ( $xref_sub =~ /\w+::\w+/ ) {
        $xref_sub = \&{$xref_sub};
    }

    return unless ref $xref_sub eq 'CODE';

    no strict 'refs';
    $xref_sub->($object);
}

# ----------------------------------------------------
sub map_type_data {

=pod

=head3 map_type_data

Return data from config about map type 

=cut

    my $self         = shift;
    my $map_type_acc = shift;
    my $attribute    = shift;
    my $config       = $self->config or return;

    if ($attribute) {
        unless ( defined $config->get_config('map_type')->{$map_type_acc} ) {
            return undef;
        }
        return $config->get_config('map_type')->{$map_type_acc}{$attribute};
    }
    elsif ($map_type_acc) {
        return $config->get_config('map_type')->{$map_type_acc};
    }
    else {
        return $config->get_config('map_type');
    }
}

# ----------------------------------------------------
sub feature_type_data {

=pod

=head3 feature_type_data

Return data from config about feature type 

=cut

    my $self             = shift;
    my $feature_type_acc = shift;
    my $attribute        = shift;
    my $config           = $self->config or return;

    if ($attribute) {
        unless (
            defined $config->get_config('feature_type')->{$feature_type_acc} )
        {
            return undef;
        }
        return $config->get_config('feature_type')->{$feature_type_acc}
            ->{$attribute};
    }
    elsif ($feature_type_acc) {
        return $config->get_config('feature_type')->{$feature_type_acc};
    }
    else {
        return $config->get_config('feature_type');
    }
}

# ----------------------------------------------------
sub evidence_type_data {

=pod

=head3 evidence_type_data

Return data from config about evidence type 

=cut

    my $self              = shift;
    my $evidence_type_acc = shift;
    my $attribute         = shift;
    my $config            = $self->config or return;

    if ($attribute) {
        unless (
            defined $config->get_config('evidence_type')
            ->{$evidence_type_acc} )
        {
            return undef;
        }
        return $config->get_config('evidence_type')->{$evidence_type_acc}
            ->{$attribute};
    }
    elsif ($evidence_type_acc) {
        return $config->get_config('evidence_type')->{$evidence_type_acc};
    }
    else {
        return $config->get_config('evidence_type');
    }
}

# ----------------------------------------------------
sub data_source {

=pod

=head3 data_source

Basically a front for set_config()

=cut

    my $self   = shift;
    my $arg    = shift || '';
    my $config = $self->config or return;

    #
    # If passed a new data source, force a reconnect.
    # This may slow things down.
    #
    if ($arg) {
        $config->set_config($arg)
            or return $self->error(
            "Couldn't set data source to '$arg': " . $config->error );
        $self->{'data_source'} = $config->get_config('database')->{'name'};
        if ( $arg ne $self->{'data_source'} ) {
            warn(     "Requested Datasource, '$arg', Not Available.  Using '"
                    . $self->{'data_source'}
                    . "'\n" );
        }
        if ( defined $self->{'db'} ) {
            my $db = $self->db;
            $db->disconnect;
            $self->{'db'} = undef;
        }
        if ( defined $self->{'sql_module'} ) {
            $self->{'sql_module'} = undef;
        }
    }

    unless ( $self->{'data_source'} ) {
        $self->{'data_source'} = $config->get_config('database')->{'name'};
    }

    return $self->{'data_source'} || '';
}

# ----------------------------------------------------
sub data_sources {

=pod

=head3 data_sources

Returns all the data souces defined in the configuration files.

=cut

    my $self = shift;
    my $config = $self->config or return;

    unless ( defined $self->{'data_sources'} ) {
        my @data_sources_result;

        $self->data_source() unless ( $self->{'data_source'} );

        my $ok = 0;

        if ( my $current = $self->{'data_source'} ) {
            foreach my $config_name ( @{ $config->get_config_names } ) {
                my $source = $config->get_config( 'database', $config_name );
                if ( $current && $source->{'name'} eq $current ) {
                    $source->{'is_current'} = 1;
                    $ok = 1;
                }
                else {
                    $source->{'is_current'} = 0;
                }

                $data_sources_result[ ++$#data_sources_result ] = $source;
            }
        }

        die "No database defined as default\n" unless ($ok);

        $self->{'data_sources'}
            = [ sort { $a->{'name'} cmp $b->{'name'} } @data_sources_result ];

    }

    if ( @{ $self->{'data_sources'} } ) {
        return $self->{'data_sources'};
    }
    else {
        return $self->error("Can't determine data sources (undefined?)");
    }
}

# ----------------------------------------------------
sub db {

=pod

=head3 db

Returns a database handle.  This is the only way into the database.

=cut

    my $self    = shift;
    my $db_name = shift || $self->data_source();
    my $config  = $self->config or return;
    return unless $db_name;

    unless ( defined $self->{'db'} ) {
        my $config = $config->get_config('database')
            or
            return $self->error('No database configuration options defined');

        unless ( ref $config eq 'HASH' ) {
            return $self->error( 'DB config not a hash.  '
                    . 'You may have more than one "database" specified in the config file'
            );
        }

        return $self->error("Couldn't determine database info")
            unless defined $config;

        my $datasource = $config->{'datasource'}
            or $self->error('No database source defined');
        my $user = $config->{'user'}
            or $self->error('No database user defined');
        my $password = $config->{'password'} || '';
        my $options = {
            AutoCommit       => 1,
            FetchHashKeyName => 'NAME_lc',
            LongReadLen      => 3000,
            LongTruncOk      => 1,
            RaiseError       => 1,
        };

        eval {
            $self->{'db'}
                = DBI->connect( $datasource, $user, $password, $options );
        };

        if ( $@ || !defined $self->{'db'} ) {
            my $error = $@ || $DBI::errstr;
            return $self->error(
                "Can't connect to data source '$db_name': $error");
        }
    }

    return $self->{'db'};
}

# ----------------------------------------------------
sub aggregate {

=pod

=head3 aggregate

Returns the boolean aggregate variable.  This determines 
if the correspondences are aggregated or individually depicted.

The default is 1.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'aggregate'} = $val if defined $val;
    $self->{'aggregate'} = $self->config_data('aggregate_correspondences')
        || 1
        unless defined $self->{'aggregate'};
    return $self->{'aggregate'};
}

# ----------------------------------------------------
sub show_intraslot_corr {

=pod

=head3 show_intraslot_corr

Returns the boolean show_intraslot_corr variable.  This determines 
if the intraslot correspondences are displayed.

The default is 1.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'show_intraslot_corr'} = $val if defined $val;
    $self->{'show_intraslot_corr'}
        = $self->config_data('show_intraslot_correspondences')
        unless defined $self->{'show_intraslot_corr'};
    $self->{'show_intraslot_corr'} = 0
        unless defined $self->{'show_intraslot_corr'};
    return $self->{'show_intraslot_corr'};
}

# ----------------------------------------------------
sub split_agg_ev {

=pod

=head3 split_agg_ev

Returns the boolean split_agg_ev variable.  This determines 
if the correspondences of different evidence types will be 
aggregated together or split.

The default is 1.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'split_agg_ev'} = $val if defined $val;
    $self->{'split_agg_ev'} = $self->config_data('split_agg_evespondences')
        unless defined $self->{'split_agg_ev'};
    $self->{'split_agg_ev'} = 0
        unless defined $self->{'split_agg_ev'};
    return $self->{'split_agg_ev'};
}

# ----------------------------------------------------
sub clean_view {

=pod

=head3 clean_view

Returns the boolean clean_view variable.  This determines 
if there will be control buttons on the map.

The default is 0.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'clean_view'} = $val if defined $val;
    $self->{'clean_view'} = $self->config_data('clean_view')
        unless defined $self->{'clean_view'};
    $self->{'clean_view'} = 0
        unless defined $self->{'clean_view'};
    return $self->{'clean_view'};
}

# ----------------------------------------------------
sub hide_legend {

=pod

=head3 hide_legend

Returns the boolean hide_legend variable.  This determines 
if there will be a legend on the image;

The default is 0.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'hide_legend'} = $val if defined $val;
    $self->{'hide_legend'} = $self->config_data('hide_legend')
        unless defined $self->{'hide_legend'};
    $self->{'hide_legend'} = 0
        unless defined $self->{'hide_legend'};
    return $self->{'hide_legend'};
}

# ----------------------------------------------------
sub corrs_to_map {

=pod

=head3 corrs_to_map

Returns the boolean corrs_to_map variable.  If set to 1, the corr lines will be
drawn to the maps instead of to the features.

The default is 0.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'corrs_to_map'} = $val if defined $val;
    $self->{'corrs_to_map'} = $self->config_data('corrs_to_map')
        unless defined $self->{'corrs_to_map'};
    $self->{'corrs_to_map'} = DEFAULT->{'corrs_to_map'}
        unless defined $self->{'corrs_to_map'};
    return $self->{'corrs_to_map'};
}

# ----------------------------------------------------
sub scale_maps {

=pod

=head3 scale_maps

Returns the boolean scale_maps variable.  This determines 
if the maps are drawn to scale 

The default is 1.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'scale_maps'} = $val if defined $val;
    $self->{'scale_maps'} = $self->config_data('scale_maps')
        unless defined $self->{'scale_maps'};
    $self->{'scale_maps'} = 1
        unless defined $self->{'scale_maps'};
    return $self->{'scale_maps'};
}

# ----------------------------------------------------
sub eliminate_orphans {

=pod

=head3 eliminate_orphans

Returns the boolean eliminate_orphans variable.  This determines 
if maps that don't have corresponences are removed.

This is not a persistent value, so it does not need to check the config.

The default is 0.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'eliminate_orphans'} = $val if defined $val;

    $self->{'eliminate_orphans'} = 0
        unless defined $self->{'eliminate_orphans'};
    return $self->{'eliminate_orphans'};
}

# ----------------------------------------------------
sub unit_granularity {

=pod

=head3 unit_granularity

Given a map type accession
Returns the unit granularity

=cut

    my $self         = shift;
    my $map_type_acc = shift;

    unless ( $self->{'unit_granularity'}{$map_type_acc} ) {
        $self->{'unit_granularity'}{$map_type_acc}
            = $self->map_type_data( $map_type_acc, 'unit_granularity' )
            || DEFAULT->{'unit_granularity'};
    }

    return $self->{'unit_granularity'}{$map_type_acc};
}

# ----------------------------------------------------
sub ignore_image_map_sanity {

=pod

=head3 ignore_image_map_sanity

A sanity check on the size of the image map (number of objects) is performed
unless this is selected.

Default: 0

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'ignore_image_map_sanity'} = $val if defined $val;
    $self->{'ignore_image_map_sanity'}
        = $self->config_data('ignore_image_map_sanity')
        unless defined $self->{'ignore_image_map_sanity'};
    $self->{'ignore_image_map_sanity'} = 0
        unless defined $self->{'ignore_image_map_sanity'};
    return $self->{'ignore_image_map_sanity'};
}

# ----------------------------------------------------
sub url_feature_default_display {

=pod

=head3 url_feature_default_display

Gets/sets which the url_feature_default_display

=cut

    my $self = shift;
    my $arg  = shift;

    if ( defined($arg) ) {
        if ( $arg =~ /^\d$/ ) {
            $self->{'url_feature_default_display'} = $arg;
        }
        else {
            $self->{'url_feature_default_display'} = undef;
        }
    }

    return $self->{'url_feature_default_display'};
}

# ----------------------------------------------------
sub stack_maps {

=pod

=head3 stack_maps

Returns the boolean stack_maps variable.  This determines 
if the reference maps are staced vertically.

The default is 0.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'stack_maps'} = $val if defined $val;
    $self->{'stack_maps'} = $self->config_data('stack_maps')
        unless defined $self->{'stack_maps'};
    $self->{'stack_maps'} = 0
        unless defined $self->{'stack_maps'};
    return $self->{'stack_maps'};
}

# ----------------------------------------------------
sub ref_map_order {

=pod

=head3 ref_map_order

Returns the string that describes the order of the ref maps. 

The default is ''.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'ref_map_order'} = $val if defined $val;
    $self->{'ref_map_order'} = '' unless defined $self->{'ref_map_order'};
    return $self->{'ref_map_order'};
}

# ----------------------------------------------------
sub comp_menu_order {

=pod

=head3 comp_menu_order

Returns the string that determins how the comparison map menu is ordered. 

The default is ''.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'comp_menu_order'} = $val if defined $val;
    $self->{'comp_menu_order'} = $self->config_data('comp_menu_order') || ''
        unless defined $self->{'comp_menu_order'};
    return $self->{'comp_menu_order'};
}

# ----------------------------------------------------
sub data_module {

=pod

=head3 data

Returns a handle to the data module.

=cut

    my $self = shift;

    $self->{'data_module'} = shift if @_;

    unless ( $self->{'data_module'} ) {
        $self->{'data_module'} = Bio::GMOD::CMap::Data->new(
            data_source         => $self->data_source,
            config              => $self->config,
            aggregate           => $self->aggregate,
            show_intraslot_corr => $self->show_intraslot_corr,
            split_agg_ev        => $self->split_agg_ev,
            ref_map_order       => $self->ref_map_order,
            comp_menu_order     => $self->comp_menu_order,
        ) or $self->error( Bio::GMOD::CMap::Data->error );
    }

    return $self->{'data_module'};
}

# ----------------------------------------------------
sub omit_area_boxes {

=pod

=head3 omit_area_boxes

Returns the omit_area_boxes variable.  This determines 
which area boxes are rendered.

0 renders all of the area boxes.  This gives the most functionality but can be
slow if there are a lot of features.

1 omits the feature area boxes but displays the navigation buttons.  This can
speed things up while leaving navigation abilities

2 omits all area boxes, leaving just an image.

The default is 0.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'omit_area_boxes'} = $val if defined $val;
    $self->{'omit_area_boxes'} = $self->config_data('omit_area_boxes') || 0
        unless $self->{'omit_area_boxes'};
    if ( $self->{'omit_area_boxes'} == 2 ) {
        $self->clean_view(1);
    }
    return $self->{'omit_area_boxes'};
}

# ----------------------------------------------------
sub refMenu {

=pod

=head3 refMenu

Returns the boolean refMenu variable.  This determines if the Reference Menu is
displayed.

The default is 0.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'refMenu'} = $val if defined $val;
    $self->{'refMenu'} ||= 0;
    return $self->{'refMenu'};
}

# ----------------------------------------------------
sub compMenu {

=pod

=head3 compMenu

Returns the boolean compMenu variable.  This determines if the Comparison Menu
is displayed.

The default is 0.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'compMenu'} = $val if defined $val;
    $self->{'compMenu'} ||= 0;
    return $self->{'compMenu'};
}

# ----------------------------------------------------
sub optionMenu {

=pod

=head3 optionMenu

Returns the boolean optionMenu variable.  This determines if the Options Menu
is displayed.

The default is 0.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'optionMenu'} = $val if defined $val;
    $self->{'optionMenu'} ||= 0;
    return $self->{'optionMenu'};
}

# ----------------------------------------------------
sub addOpMenu {

=pod

=head3 addOpMenu

Returns the boolean addOpMenu variable.  This determines if the Additional
Options Menu is displayed.

The default is 0.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'addOpMenu'} = $val if defined $val;
    $self->{'addOpMenu'} ||= 0;
    return $self->{'addOpMenu'};
}

# ----------------------------------------------------
sub dotplot {

=pod

=head3 dotplot

Returns the boolean dotplot variable.  This determines if the view will be displayed as a dotplot.

The default is 0.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'dotplot'} = $val if defined $val;
    $self->{'dotplot'} ||= 0;
    return $self->{'dotplot'};
}

# ----------------------------------------------------
sub get_multiple_xrefs {

=pod

=head3 get_multiple_xrefs

Given a table name and some objects, get the cross-references.

=cut

    my ( $self, %args ) = @_;
    my $object_type = $args{'object_type'} or return;
    my $objects     = $args{'objects'};
    my $sql_object  = $self->sql or return;

    return unless @{ $objects || [] };

    my $xrefs = $sql_object->get_xrefs( object_type => $object_type, );

    my ( %xref_specific, @xref_generic );
    for my $xref (@$xrefs) {
        if ( $xref->{'object_id'} ) {
            push @{ $xref_specific{ $xref->{'object_id'} } }, $xref;
        }
        else {
            push @xref_generic, $xref;
        }
    }

    my $t = $self->template;
    for my $o (@$objects) {
        for my $attr ( @{ $o->{'attributes'} || [] } ) {
            my $attr_val  = $attr->{'attribute_value'}   or next;
            my $attr_name = lc $attr->{'attribute_name'} or next;
            $attr_name =~ tr/ /_/s;
            push @{ $o->{'attribute'}{$attr_name} },
                $attr->{'attribute_value'};
        }

        my @xrefs = @{ $xref_specific{ $o->{'object_id'} } || [] };
        push @xrefs, @xref_generic;

        my @processed;
        for my $xref (@xrefs) {
            my $url;
            $t->process( \$xref->{'xref_url'}, { object => $o }, \$url );

            push @processed,
                {
                xref_name => $xref->{'xref_name'},
                xref_url  => $_,
                }
                for map { $_ || () } split /\s+/, $url;
        }

        $o->{'xrefs'} = \@processed;
    }
}

# ----------------------------------------------------
sub session_id {

=pod

=head3 session_id

Sets and returns the session_id.

The default is ''.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'session_id'} = $val if defined $val;
    return $self->{'session_id'};
}

# ----------------------------------------------------
sub next_step {

=pod

=head3 next_step

Sets and returns the session next_step.

The default is ''.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'next_step'} = $val if defined $val;
    return $self->{'next_step'};
}

# ----------------------------------------------------
sub get_link_name_space {

=pod

=head3 get_link_name_space

This is a consistant way of naming the link name space

=cut

    my $self = shift;
    return 'imported_links_' . $self->data_source;
}

# ----------------------------------------------------
sub cache_level_name {

=pod

=head3 cache_level_name

This is a consistant way of naming the cache levels. 

If a datasource name is given use it, otherwise use the current config

=cut

    my $self            = shift;
    my $level           = shift;
    my $datasource_name = shift;
    return $self->error(
        "Cache Level: $level should not be higher than " . CACHE_LEVELS )
        unless ( $level <= CACHE_LEVELS );

    my $name;
    if ($datasource_name) {
        $name = $self->config_data( 'database', $datasource_name, )->{'name'},

    }
    else {
        $name = $self->config_data('database')->{'name'},;
    }

    return $name . "_L" . $level;
}

# ----------------------------------------------------
sub web_image_cache_dir {

=pod

=head3 web_image_cache_dir

Get the image cache directory using the web document root

=cut

    my $self = shift;

    unless ( $self->{'web_image_cache_dir'} ) {
        my $image_cache_dir   = $self->config_data('cache_dir');
        my $web_document_root = $self->config_data('web_document_root_dir');
        if ($web_document_root) {
            $image_cache_dir
                = rootdir() . abs2rel( $image_cache_dir, $web_document_root );
        }
        else {

            # This is kinda cludgy but it should work if the web_document_root
            # isn't defined in the config file.
            $image_cache_dir =~ s{.+htdocs}{};
            $image_cache_dir =~ s{.+www}{};
            $image_cache_dir =~ s{.+html}{};
        }
        $self->{'web_image_cache_dir'} = $image_cache_dir;
    }
    return $self->{'web_image_cache_dir'};

}

# ----------------------------------------------------
sub additional_buttons {

=pod

=head3 additional_buttons

Read additional buttons from the config file and return the javascript.

Example configurations:

    <button>
        text Remove Clean View
        <if>
            clean_view 1
        </if>
        <set>
            clean_view 0
        </set>
    </button>

    <button>
        text Set Clean View
        <if_not>
            clean_view 1
        </if_not>
        <set>
            clean_view 1
        </set>
    </button>

    <button>
        text Remove Marker
        <if>
            display_feature_type marker
        </if>
        <set>
            ft_marker 0
        </set>
    </button>

=cut

    my ( $self, %args ) = @_;
    my $parsed_url_options        = $args{'parsed_url_options'};
    my $form_data                 = $args{'form_data'};
    my $display_feature_types     = $args{'display_feature_types'} || {};
    my $corr_only_feature_types   = $args{'corr_only_feature_types'} || {};
    my $ignored_feature_types     = $args{'ignored_feature_types'} || {};
    my $evidence_type_menu_select = $args{'evidence_type_menu_select'} || {};

    my @button_data;
    my $additional_buttons = $self->config_data('additional_buttons');
    return unless ($additional_buttons);
    if ( ref $additional_buttons->{'button'} ne 'ARRAY' ) {
        $additional_buttons->{'button'} = [ $additional_buttons->{'button'} ];
    }

    my %radio_button = (
        label_features          => 1,
        collapse_features       => 1,
        aggregate               => 1,
        corrs_to_map            => 1,
        show_intraslot_corr     => 1,
        split_agg_ev            => 1,
        phrb                    => 1,
        font_size               => 1,
        image_type              => 1,
        clean_view              => 1,
        hide_legend             => 1,
        scale_maps              => 1,
        omit_area_boxes         => 1,
        comp_menu_order         => 1,
        ignore_image_map_sanity => 1,
    );

    # Special cases: ft_* and evidence_type_*

    my %check_boxes = ( stack_maps => 1, );

    # Special Cases: stack_slot_*, map_flip_*

    my %hidden_or_text = (
        pixel_height      => 1,
        highlight         => 1,
        dotplot           => 1,
        eliminate_orphans => 1,
        mapMenu           => 1,
        featureMenu       => 1,
        corrMenu          => 1,
        displayMenu       => 1,
        advancedMenu      => 1,
    );

BUTTON:
    foreach my $button ( @{ $additional_buttons->{'button'} || [] } ) {
        next BUTTON
            unless $self->check_parameters(
            values_hash               => $button->{'if'},
            parsed_url_options        => $parsed_url_options,
            form_data                 => $form_data,
            display_feature_types     => $display_feature_types,
            corr_only_feature_types   => $corr_only_feature_types,
            ignored_feature_types     => $ignored_feature_types,
            evidence_type_menu_select => $evidence_type_menu_select,
            check_for_true            => 1,
            );
        next BUTTON
            unless $self->check_parameters(
            values_hash               => $button->{'if_not'},
            parsed_url_options        => $parsed_url_options,
            form_data                 => $form_data,
            display_feature_types     => $display_feature_types,
            corr_only_feature_types   => $corr_only_feature_types,
            ignored_feature_types     => $ignored_feature_types,
            evidence_type_menu_select => $evidence_type_menu_select,
            check_for_true            => 0,
            );
        my $js = '';
        foreach my $param ( keys %{ $button->{'set'} || {} } ) {
            next unless ( $param =~ /^\S+/ );
            my $value = $button->{'set'}{$param};
            if (   $radio_button{$param}
                or $param =~ /^ft_/
                or $param =~ /^evidence_type_/ )
            {
                $js
                    .= "check_radio_for_additional_buttons("
                    . "document.comparative_map_form."
                    . $param . ","
                    . $value . ");";
            }
            elsif ($check_boxes{$param}
                or $param =~ /^stack_slot_/
                or $param =~ /^map_flip_/ )
            {
                if ($value) {
                    $js
                        .= "document.comparative_map_form." 
                        . $param
                        . ".checked=true;";
                }
                else {
                    $js
                        .= "document.comparative_map_form." 
                        . $param
                        . ".checked=false;";
                }
            }
            elsif ( $hidden_or_text{$param} ) {
                $js
                    .= "document.comparative_map_form." 
                    . $param
                    . ".value='"
                    . $button->{'set'}{$param} . "';";
            }
        }
        push @button_data, { text => $button->{'text'}, javascript => $js, };
    }

    return \@button_data;

}

# ----------------------------------------------------
sub check_parameters {

=pod

=head3 check_parameters

Check to see if all these form values are set to true.

=cut

    my ( $self, %args ) = @_;
    my $values_hash               = $args{'values_hash'} || {};
    my $parsed_url_options        = $args{'parsed_url_options'};
    my $form_data                 = $args{'form_data'};
    my $display_feature_types     = $args{'display_feature_types'} || {};
    my $corr_only_feature_types   = $args{'corr_only_feature_types'} || {};
    my $ignored_feature_types     = $args{'ignored_feature_types'} || {};
    my $evidence_type_menu_select = $args{'evidence_type_menu_select'} || {};
    my $check_for_true            = $args{'check_for_true'} || 0;
    my $slots                     = $parsed_url_options->{'slots'};

    # Boolean
    my %boolean_params = (
        highlight               => 1,
        collapse_features       => 1,
        scale_maps              => 1,
        stack_maps              => 1,
        omit_area_boxes         => 1,
        show_intraslot_corr     => 1,
        split_agg_ev            => 1,
        clean_view              => 1,
        corrs_to_map            => 1,
        ignore_image_map_sanity => 1,
        dotplot                 => 1,
    );

    # Strings
    my %string_params = (
        prev_ref_species_acc => 1,
        prev_ref_map_set_acc => 1,
        ref_species_acc      => 1,
        ref_map_set_acc      => 1,
        image_type           => 1,
        label_features       => 1,
        aggregate            => 1,
        comp_menu_order      => 1,
        data_source          => 1,
        ref_map_start        => 1,
        ref_map_stop         => 1,
        font_size            => 1,
        pixel_height         => 1,
    );

    #Special Slot parameters
    my %slot_params = ( stack_slot => 'stack_slot', );

    #Special Evidence Type
    my %evidence_type_params = (
        included_evidence_type => 1,
        ignored_evidence_type  => 1,
        less_evidence_type     => 1,
        greater_evidence_type  => 1,
    );
    my %evidence_type_codes = (
        ignored_evidence_type  => 0,
        included_evidence_type => 1,
        less_evidence_type     => 2,
        greater_evidence_type  => 3,
    );

    #Special Feature Types
    my %feature_type_params = (
        display_feature_type   => 1,
        corr_only_feature_type => 1,
        ignored_feature_type   => 1,
    );
    my %feature_type_hashes = (
        display_feature_type   => $display_feature_types,
        corr_only_feature_type => $corr_only_feature_types,
        ignored_feature_type   => $ignored_feature_types,
    );

    # GET TO
    #evidence_type_score

    # Leave out:
    # session_id, next_step, new_session, slot_min_corrs, ref_map_accs,
    # ref_map_order, left_min_corrs, right_min_corrs, general_min_corrs
    # menu_min_corrs, url_feature_default_display, refMenu, compMenu,
    # optionMenu, addOpMenu, flip,

PARAM:
    foreach my $param ( keys %{$values_hash} ) {

        # Boolean
        if ( $boolean_params{$param} ) {
            if (( $values_hash->{$param} and $parsed_url_options->{$param} )
                or (    not $values_hash->{$param}
                    and not $parsed_url_options->{$param} )
                )
            {

                # Check Succeeded
                return 0 unless ($check_for_true);
            }
            else {

                # Check failed
                return 0 if ($check_for_true);
            }
        }

        # String
        elsif ( $string_params{$param} ) {
            if ( $values_hash->{$param} eq $parsed_url_options->{$param} ) {

                # Check Succeeded
                return 0 unless ($check_for_true);
            }
            else {

                # Check failed
                return 0 if ($check_for_true);
            }
        }
        elsif ( $param eq 'map_set_acc' or $param eq 'species_acc' ) {
            if ( grep { $values_hash->{$param} eq $_->{'map_set_acc'} }
                @{ $form_data->{'slot_info'} || [] } )
            {

                # Check Succeeded
                return 0 unless ($check_for_true);
            }
            else {

                # Check failed
                return 0 if ($check_for_true);
            }
        }
        elsif ( $param eq 'map_acc' ) {
            if ( grep { ( $_->{'maps'}{ $values_hash->{$param} } ) ? 1 : () }
                @{ $form_data->{'slot_info'} || [] } )
            {

                # Check Succeeded
                return 0 unless ($check_for_true);
            }
            else {

                # Check failed
                return 0 if ($check_for_true);
            }
        }

        #Special Slot parameters
        #elsif ( $slot_params{$param} ) {
        #unless ( $values_hash->{$param} eq $parsed_url_options->{$param} )
        #{
        #return 0;
        #}
        #}

        #Special Evidence Type
        # ignored_evidence_type ANB
        elsif ( $evidence_type_params{$param} ) {
            my $evidence_type = $values_hash->{$param};
            if ( $evidence_type_codes{$param} eq
                $evidence_type_menu_select->{$evidence_type} )
            {

                # Check Succeeded
                return 0 unless ($check_for_true);
            }
            else {

                # Check failed
                return 0 if ($check_for_true);

               # If we are checking for failed (and we are if we have gotten
               # to this point), it also has to have been an option, otherwise
               # how can we savor it's defeat.
                if ( defined( $evidence_type_menu_select->{$evidence_type} ) )
                {
                    return 0;
                }

            }
        }

        #Special Feature Type
        # ignored_feature_type read
        elsif ( $feature_type_params{$param} ) {
            my $feature_type = $values_hash->{$param};
            if ( $feature_type_hashes{$param}->{$feature_type} ) {

                # Check Succeeded
                return 0 unless ($check_for_true);
            }
            else {

                # Check failed
                return 0 if ($check_for_true);

               # If we are checking for failed (and we are if we have gotten
               # to this point), it also has to have been an option, otherwise
               # how can we savor it's defeat.
                foreach my $key (%feature_type_hashes) {
                    if ( $feature_type_hashes{$key}->{$feature_type} ) {
                        next PARAM;    # Found it
                    }
                }
                return 0;              # This feature type is not an option
            }
        }
    }

    return 1;
}

# ----------------------------------------------------
sub web_cmap_htdocs_dir {

=pod

=head3 web_cmap_htdocs_dir

Get the htdocs directory using the web document root

=cut

    my $self = shift;

    unless ( $self->{'web_cmap_htdocs_dir'} ) {
        my $cmap_htdocs_dir   = $self->config_data('web_cmap_htdocs_dir');
        my $web_document_root = $self->config_data('web_document_root_dir');
        if ($web_document_root) {
            $cmap_htdocs_dir
                = rootdir() . abs2rel( $cmap_htdocs_dir, $web_document_root );
        }
        else {

            # This is kinda cludgy but it should work if the web_document_root
            # isn't defined in the config file.
            $cmap_htdocs_dir =~ s{.+htdocs}{};
            $cmap_htdocs_dir =~ s{.+www}{};
            $cmap_htdocs_dir =~ s{.+html}{};
        }
        $self->{'web_cmap_htdocs_dir'} = $cmap_htdocs_dir;
    }
    return $self->{'web_cmap_htdocs_dir'};

}

# ----------------------------------------------------
sub template {

=pod

=head3 template

Returns a Template Toolkit object.

=cut

    my $self = shift;
    my $config = $self->config or return;

    unless ( $self->{'template'} ) {
        my $cache_dir = $self->cache_dir or return;
        my $template_dir = $config->get_config('template_dir')
            or return $self->error(
            'No template directory defined in "' . GLOBAL_CONFIG_FILE . '"' );
        return $self->error(
            "Template directory '$template_dir' doesn't exist")
            unless -d $template_dir;

        $self->{'template'} = Template->new(
            COMPILE_EXT  => '.ttc',
            COMPILE_DIR  => $cache_dir,
            INCLUDE_PATH => $template_dir,
            FILTERS      => {
                dump => sub { Dumper( shift() ) },
                nbsp => sub { my $s = shift; $s =~ s{\s+}{\&nbsp;}g; $s },
                commify => \&Bio::GMOD::CMap::Utils::commify,
            },
            )
            or $self->error(
            "Couldn't create Template object: " . Template->error() );
    }

    return $self->{'template'};
}

# ----------------------------------------------------
sub sql {

=pod

=head3 sql

Returns the correct SQL module driver for the RDBMS we're using.

=cut

    my $self      = shift;
    my $db_driver = lc shift;

    unless ( defined $self->{'sql_module'} ) {
        my $db = $self->db
            or die "Can't access database: " . $self->error() . "\n";
        $db_driver = lc $db->{'Driver'}->{'Name'} || '';
        $db_driver = DEFAULT->{'sql_driver_module'}
            unless VALID->{'sql_driver_module'}{$db_driver};
        my $sql_module = VALID->{'sql_driver_module'}{$db_driver};

        eval "require $sql_module"
            or die qq[Unable to require SQL module "$sql_module": $@];

        # IF YOU ARE GETTING A BIZZARE WARNING:
        # It might be that the $sql_module has errors in it
        #  aren't being reported.  This might manifest as "$self->sql"
        #  returning nothing or as "cannot find method new".
        my $data_source = $self->data_source();
        $self->{'sql_module'} = $sql_module->new(
            config      => $self->config,
            data_source => $data_source,
        );
        die "Could not initialize the database accession module.\n"
            unless ( $self->{'sql_module'} );
    }

    return $self->{'sql_module'};
}

# ----------------------------------------------------
sub check_img_dir_fullness {

=pod

=head3 check_img_dir_fullness

Check the image directories fullness (as a percent).  Compare it to the
max_img_dir_fullness in the conf dir.  If it is full, return 1.

=cut

    my $self = shift;
    return 0 unless ( $self->config_data('max_img_dir_fullness') );

    my $cache_dir = $self->cache_dir or return;
    my $ref = dfportable($cache_dir);
    if ( $ref->{'per'} > $self->config_data('max_img_dir_fullness') ) {
        return 1;
    }

    return 0;
}

# ----------------------------------------------------
sub check_img_dir_size {

=pod

=head3 check_img_dir_size

Check the image directories size (as a percent).  Compare it to the
max_img_dir_size in the conf dir.  If it is full, return 1.

=cut

    my $self = shift;
    return 0 unless ( $self->config_data('max_img_dir_size') );

    my $cache_dir = $self->cache_dir or return;
    my $size = 0;
    foreach my $file ( glob("$cache_dir/*") ) {
        next unless -f $file;
        $size += -s $file;
    }
    if ( $size > $self->config_data('max_img_dir_size') ) {
        return 1;
    }

    return 0;
}

# ----------------------------------------------------
sub clear_img_dir {

=pod

=head3 clear_img_dir

Clears the image directory of files.  (It will not touch directories.)

=cut

    my $self = shift;
    my $cache_dir = $self->cache_dir or return;

    return 0 unless ( $self->config_data('purge_img_dir_when_full') );

    my $delete_age = $self->config_data('file_age_to_purge');

    unless ( defined($delete_age) and $delete_age =~ /^\d+$/ ) {
        if ( $delete_age =~ /\d+/ ) {
            $self->warn( "file_age_to_purge not correctly defined.  "
                    . "Using the default" );
        }
        $delete_age = DEFAULT->{'file_age_to_purge'} || 300;
    }
    my $time_now = time;
    foreach my $file ( glob("$cache_dir/*") ) {
        my @stat_results = stat $file;
        my $diff_time    = $time_now - $stat_results[8];
        unlink $file if ( -f $file and $diff_time >= $delete_age );
    }
    return 1;
}

###########################################

=pod

=head2 Other Methods

Methods that do things tother than store variables.

=cut

# ----------------------------------------------------
sub DESTROY {

=pod

=head3 DESTROY

Object clean-up when destroyed by Perl.

=cut

    my $self = shift;
    $self->db->disconnect if defined $self->{'db'};
    return 1;
}

# ----------------------------------------------------
sub warn {

=pod

=head3 warn

Provides a simple way to print messages to STDERR.

=cut

    my $self = shift;
    print STDERR @_;
}

# ----------------------------------------------------
sub create_viewer_link {

=pod

=head3 create_viewer_link

Given information about the link, creates a url to cmap_viewer.

=cut

    my ( $self, %args ) = @_;
    my $prev_ref_species_acc        = $args{'prev_ref_species_acc'};
    my $prev_ref_map_set_acc        = $args{'prev_ref_map_set_acc'};
    my $ref_species_acc             = $args{'ref_species_acc'};
    my $ref_map_set_acc             = $args{'ref_map_set_acc'};
    my $ref_map_start               = $args{'ref_map_start'};
    my $ref_map_stop                = $args{'ref_map_stop'};
    my $comparative_maps            = $args{'comparative_maps'};
    my $highlight                   = $args{'highlight'};
    my $font_size                   = $args{'font_size'};
    my $pixel_height                = $args{'pixel_height'};
    my $image_type                  = $args{'image_type'};
    my $label_features              = $args{'label_features'};
    my $collapse_features           = $args{'collapse_features'};
    my $aggregate                   = $args{'aggregate'};
    my $scale_maps                  = $args{'scale_maps'};
    my $stack_maps                  = $args{'stack_maps'};
    my $omit_area_boxes             = $args{'omit_area_boxes'};
    my $ref_map_order               = $args{'ref_map_order'};
    my $show_intraslot_corr         = $args{'show_intraslot_corr'};
    my $split_agg_ev                = $args{'split_agg_ev'};
    my $clean_view                  = $args{'clean_view'};
    my $hide_legend                 = $args{'hide_legend'};
    my $comp_menu_order             = $args{'comp_menu_order'};
    my $corrs_to_map                = $args{'corrs_to_map'};
    my $ignore_image_map_sanity     = $args{'ignore_image_map_sanity'};
    my $flip                        = $args{'flip'};
    my $left_min_corrs              = $args{'left_min_corrs'};
    my $right_min_corrs             = $args{'right_min_corrs'};
    my $general_min_corrs           = $args{'general_min_corrs'};
    my $menu_min_corrs              = $args{'menu_min_corrs'};
    my $slot_min_corrs              = $args{'slot_min_corrs'};
    my $stack_slot                  = $args{'stack_slot'};
    my $ref_map_accs                = $args{'ref_map_accs'};
    my $feature_type_accs           = $args{'feature_type_accs'};
    my $corr_only_feature_type_accs = $args{'corr_only_feature_type_accs'};
    my $ignored_feature_type_accs   = $args{'ignored_feature_type_accs'};
    my $url_feature_default_display = $args{'url_feature_default_display'};
    my $included_evidence_type_accs = $args{'included_evidence_type_accs'};
    my $ignored_evidence_type_accs  = $args{'ignored_evidence_type_accs'};
    my $less_evidence_type_accs     = $args{'less_evidence_type_accs'};
    my $greater_evidence_type_accs  = $args{'greater_evidence_type_accs'};
    my $evidence_type_score         = $args{'evidence_type_score'};
    my $data_source                 = $args{'data_source'};
    my $refMenu                     = $args{'refMenu'};
    my $compMenu                    = $args{'compMenu'};
    my $optionMenu                  = $args{'optionMenu'};
    my $addOpMenu                   = $args{'addOpMenu'};
    my $dotplot                     = $args{'dotplot'};
    my $session_id                  = $args{'session_id'};
    my $next_step                   = $args{'next_step'};
    my $new_session                 = $args{'new_session'} || 0;
    my $session_mod                 = $args{'session_mod'};
    my $skip_map_info               = $args{'skip_map_info'} || 0;
    my $url                         = $args{'base_url'} || 'viewer?';
    $url .= '?' unless $url =~ /\?$/;
    my $cmap_viewer_link_debug = $args{'cmap_viewer_link_debug'};

    #print S#TDERR "\n" if ($cmap_viewer_link_debug);
    #print S#TDERR Dumper()."\n" if ($cmap_viewer_link_debug);
    ###Required Fields
    unless (
        (      defined($ref_map_set_acc)
            or defined($ref_map_accs)
            or defined($session_id)
            or $skip_map_info
        )
        and defined($data_source)
        )
    {
        return '';
    }
    $url .= "data_source=$data_source;";

    if ( $session_id and !$new_session and !$skip_map_info ) {
        $url .= "session_id=$session_id;";
        $url .= "step=$next_step;"
            if ( defined($next_step) and $next_step ne '' );
        $url .= "session_mod=$session_mod;"
            if ( defined($session_mod) and $session_mod ne '' );
    }
    elsif ( !$skip_map_info ) {
        $url .= "ref_map_set_acc=$ref_map_set_acc;"
            if ( defined($ref_map_set_acc) and $ref_map_set_acc ne '' );
        $url .= "ref_species_acc=$ref_species_acc;"
            if ( defined($ref_species_acc) and $ref_species_acc ne '' );
        $url .= "prev_ref_species_acc=$prev_ref_species_acc;"
            if ( defined($prev_ref_species_acc)
            and $prev_ref_species_acc ne '' );
        $url .= "prev_ref_map_set_acc=$prev_ref_map_set_acc;"
            if ( defined($prev_ref_map_set_acc)
            and $prev_ref_map_set_acc ne '' );

        if ( $ref_map_accs and %$ref_map_accs ) {
            my @ref_strs;
            foreach my $ref_map_acc ( keys(%$ref_map_accs) ) {
                if (defined( $ref_map_accs->{$ref_map_acc}{'start'} )
                    or defined(
                               $ref_map_accs->{$ref_map_acc}{'stop'}
                            or $ref_map_accs->{$ref_map_acc}{'magnify'}
                    )
                    )
                {
                    my $start
                        = defined( $ref_map_accs->{$ref_map_acc}{'start'} )
                        ? $ref_map_accs->{$ref_map_acc}{'start'}
                        : '';
                    my $stop
                        = defined( $ref_map_accs->{$ref_map_acc}{'stop'} )
                        ? $ref_map_accs->{$ref_map_acc}{'stop'}
                        : '';
                    my $mag
                        = defined( $ref_map_accs->{$ref_map_acc}{'magnify'} )
                        ? $ref_map_accs->{$ref_map_acc}{'magnify'}
                        : 1;
                    push @ref_strs,
                        $ref_map_acc . '[' 
                        . $start . '*' 
                        . $stop . 'x' 
                        . $mag . ']';
                }
                else {
                    push @ref_strs, $ref_map_acc;
                }
            }
            $url .= "ref_map_accs=" . join( ',', @ref_strs ) . ";";
        }
        if ( $comparative_maps and %$comparative_maps ) {
            my @strs;
            foreach my $slot_no ( keys(%$comparative_maps) ) {
                my $map = $comparative_maps->{$slot_no};
                for my $field (qw[ maps map_sets ]) {
                    next unless ( defined( $map->{$field} ) );
                    foreach my $acc ( keys %{ $map->{$field} } ) {
                        if ( $field eq 'maps' ) {
                            my $start
                                = defined( $map->{$field}{$acc}{'start'} )
                                ? $map->{$field}{$acc}{'start'}
                                : '';
                            my $stop
                                = defined( $map->{$field}{$acc}{'stop'} )
                                ? $map->{$field}{$acc}{'stop'}
                                : '';
                            my $mag
                                = defined( $map->{$field}{$acc}{'mag'} )
                                ? $map->{$field}{$acc}{'mag'}
                                : 1;
                            push @strs,
                                $slot_no
                                . '%3dmap_acc%3d'
                                . $acc . '['
                                . $start . '*'
                                . $stop . 'x'
                                . $mag . ']';

                        }
                        else {
                            push @strs, $slot_no . '%3dmap_set_acc%3d' . $acc;
                        }
                    }
                }
            }

            $url .= "comparative_maps=" . join( ':', @strs ) . ";";
        }
    }
    ### optional
    $url .= "ref_map_start=$ref_map_start;"
        if ( defined($ref_map_start) and $ref_map_start ne '' );
    $url .= "ref_map_stop=$ref_map_stop;"
        if ( defined($ref_map_stop) and $ref_map_stop ne '' );
    $url .= "highlight=" . uri_escape($highlight) . ";"
        if ( defined($highlight) and $highlight ne '' );
    $url .= "font_size=$font_size;"
        if ( defined($font_size) and $font_size ne '' );
    $url .= "pixel_height=$pixel_height;"
        if ( defined($pixel_height) and $pixel_height ne '' );
    $url .= "image_type=$image_type;"
        if ( defined($image_type) and $image_type ne '' );
    $url .= "label_features=$label_features;"
        if ( defined($label_features) and $label_features ne '' );
    $url .= "collapse_features=$collapse_features;"
        if ( defined($collapse_features) and $collapse_features ne '' );
    $url .= "aggregate=$aggregate;"
        if ( defined($aggregate) and $aggregate ne '' );
    $url .= "scale_maps=$scale_maps;"
        if ( defined($scale_maps) and $scale_maps ne '' );
    $url .= "stack_maps=$stack_maps;"
        if ( defined($stack_maps) and $stack_maps ne '' );
    $url .= "omit_area_boxes=$omit_area_boxes;"
        if ( defined($omit_area_boxes) and $omit_area_boxes ne '' );
    $url .= "ref_map_order=$ref_map_order;"
        if ( defined($ref_map_order) and $ref_map_order ne '' );
    $url .= "split_agg_ev=$split_agg_ev;"
        if ( defined($split_agg_ev) and $split_agg_ev ne '' );
    $url .= "clean_view=$clean_view;"
        if ( defined($clean_view) and $clean_view ne '' );
    $url .= "hide_legend=$hide_legend;"
        if ( defined($hide_legend) and $hide_legend ne '' );
    $url .= "comp_menu_order=$comp_menu_order;"
        if ( defined($comp_menu_order) and $comp_menu_order ne '' );
    $url .= "corrs_to_map=$corrs_to_map;"
        if ( defined($corrs_to_map) and $corrs_to_map ne '' );
    $url .= "ignore_image_map_sanity=$ignore_image_map_sanity;"
        if $ignore_image_map_sanity;
    $url .= "flip=$flip;"
        if ( defined($flip) );
    $url .= "left_min_corrs=$left_min_corrs;"
        if ( defined($left_min_corrs) and $left_min_corrs ne '' );
    $url .= "right_min_corrs=$right_min_corrs;"
        if ( defined($right_min_corrs) and $right_min_corrs ne '' );
    $url .= "general_min_corrs=$general_min_corrs;"
        if ( defined($general_min_corrs) and $general_min_corrs ne '' );
    $url .= "menu_min_corrs=$menu_min_corrs;"
        if ( defined($menu_min_corrs) and $menu_min_corrs ne '' );
    $url .= "refMenu=$refMenu;"
        if ( defined($refMenu) and $refMenu ne '' );
    $url .= "compMenu=$compMenu;"
        if ( defined($compMenu) and $compMenu ne '' );
    $url .= "optionMenu=$optionMenu;"
        if ( defined($optionMenu) and $optionMenu ne '' );
    $url .= "addOpMenu=$addOpMenu;"
        if ( defined($addOpMenu) and $addOpMenu ne '' );
    $url .= "dotplot=$dotplot;"
        if ($dotplot);

    #multi

    #Don't print the feature types if they are already the default
    my $config_feature_default_display
        = $self->config_data('feature_default_display');
    my $combined_feature_default_display = -1;
    if ( defined($url_feature_default_display) ) {
        $combined_feature_default_display = $url_feature_default_display;
    }
    elsif ( defined($config_feature_default_display)
        and $config_feature_default_display ne '' )
    {
        $combined_feature_default_display = 2
            if ( $config_feature_default_display eq 'display' );
        $combined_feature_default_display = 1
            if ( $config_feature_default_display eq 'corr_only' );
        $combined_feature_default_display = 0
            if ( $config_feature_default_display eq 'ignore' );
    }

    unless ( $combined_feature_default_display == 2 ) {
        foreach my $acc (@$feature_type_accs) {
            $url .= "ft_" . $acc . "=2;";
        }
    }
    unless ( $combined_feature_default_display == 1 ) {
        foreach my $acc (@$corr_only_feature_type_accs) {
            $url .= "ft_" . $acc . "=1;";
        }
    }
    unless ( $combined_feature_default_display == 0 ) {
        foreach my $acc (@$ignored_feature_type_accs) {
            $url .= "ft_" . $acc . "=0;";
        }
    }
    $url .= "ft_DEFAULT=$url_feature_default_display;"
        if ( defined($url_feature_default_display)
        and $url_feature_default_display ne '' );
    foreach my $acc (@$included_evidence_type_accs) {
        $url .= "et_" . $acc . "=1;";
    }
    foreach my $acc (@$ignored_evidence_type_accs) {
        $url .= "et_" . $acc . "=0;";
    }
    foreach my $acc (@$less_evidence_type_accs) {
        $url .= "et_" . $acc . "=2;";
    }
    foreach my $acc (@$greater_evidence_type_accs) {
        $url .= "et_" . $acc . "=3;";
    }
    foreach my $acc ( keys(%$evidence_type_score) ) {
        $url .= "ets_" . $acc . "=" . $evidence_type_score->{$acc} . ";";
    }

    if ( %{ $slot_min_corrs || {} } ) {
        foreach my $slot_no ( keys %{$slot_min_corrs} ) {
            if ( $slot_min_corrs->{$slot_no} ) {
                $url .= "slot_min_corrs_" . $slot_no . "=1;";
            }
        }
    }
    if ( %{ $stack_slot || {} } ) {
        foreach my $slot_no ( keys %{$stack_slot} ) {
            if ( $stack_slot->{$slot_no} ) {
                $url .= "stack_slot_" . $slot_no . "=1;";
            }
        }
    }

    return $url;
}

###########################################

=pod

=head2 Query Caching

Query results (and subsequent manipulations) are cached 
in a Cache::SizeAwareFileCache file.

There are four levels of caching.  This is so that if some part of 
the database is changed, the whole chache does not have to be purged.
Only the cache level and the levels above it need to be cached.

Level 1: Species or Map Sets.
Level 2: Maps
Level 3: Features
Level 4: Correspondences

For example if features are added, then Level 3 and 4 need to be purged.
If a new Map is added, Levels 2,3 and 4 need to be purged.

=cut

# ----------------------------------------------------
sub get_cached_results {
    my $self        = shift;
    my $cache_level = shift;
    my $query       = shift;

    $cache_level = 1 unless $cache_level;
    my $cache_name = "L" . $cache_level . "_cache";

    #print S#TDERR "GET: $cache_level $cache_name\n";

    unless ( $self->{$cache_name} ) {
        $self->{$cache_name} = $self->init_cache($cache_level)
            or return;
    }

    # can only check for disabled cache after init_cache is called.
    return undef if ( $self->{'disable_cache'} );

    return undef unless ($query);
    return thaw( $self->{$cache_name}->get($query) );
}

sub store_cached_results {
    my $self        = shift;
    my $cache_level = shift;
    my $query       = shift;
    my $object      = shift;
    $cache_level = 1 unless $cache_level;
    my $cache_name = "L" . $cache_level . "_cache";

    #print S#TDERR "STORE: $cache_level $cache_name\n";

    unless ( $self->{$cache_name} ) {
        $self->{$cache_name} = $self->init_cache($cache_level)
            or return;
    }

    # can only check for disabled cache after init_cache is called.
    return undef if ( $self->{'disable_cache'} );

    $self->{$cache_name}->set( $query, nfreeze($object) );
}

sub init_cache {
    my $self        = shift;
    my $cache_level = shift;

    # We need to read from the config file if the cache is diabled.
    $self->{'disable_cache'} = $self->config_data('disable_cache');

    my $namespace = $self->cache_level_name($cache_level);
    return unless ($namespace);

    my %cache_params = (
        'namespace'          => $namespace,
        'default_expires_in' => 1_209_600,    # 2 weeks
    );

    my $cache = new Cache::SizeAwareFileCache( \%cache_params );

    return $cache;
}

sub control_cache_size {

    my $self = shift;

    my $cache_limit;
    if ( defined $self->config_data('max_query_cache_size')
        and $self->config_data('max_query_cache_size') ne q{} )
    {
        $cache_limit = $self->config_data('max_query_cache_size') + 0;
    }
    else {
        $cache_limit = DEFAULT->{'max_query_cache_size'} || 0;
    }

    # return unless cache_limit is a positive number
    return unless ( $cache_limit > 0 );

CACHE_LEVEL:
    for my $cache_level ( 1 .. 5 ) {
        my $cache_name = "L" . $cache_level . "_cache";
        unless ( $self->{$cache_name} ) {
            $self->{$cache_name} = $self->init_cache($cache_level)
                or next CACHE_LEVEL;
        }
        $self->{$cache_name}->purge();
        $self->{$cache_name}->limit_size($cache_limit);

    }
    return;
}

1;

# ----------------------------------------------------
# To create a little flower is the labour of ages.
# William Blake
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>, L<Class::Base>.

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

