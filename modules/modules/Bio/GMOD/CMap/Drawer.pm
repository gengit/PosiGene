package Bio::GMOD::CMap::Drawer;

# vim: set ft=perl:

# $Id: Drawer.pm,v 1.147 2008/02/28 17:12:57 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Drawer - draw maps 

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Drawer;
  my $drawer = Bio::GMOD::CMap::Drawer( ref_map_id => 12345 );
  $drawer->image_name;

=head1 DESCRIPTION

The base map drawing module.

=head1 Usage

    my $drawer = Bio::GMOD::CMap::Drawer->new(
        slots => $slots,
        data_source => $data_source,
        apr => $apr,
        flip => $flip,
        highlight => $highlight,
        font_size => $font_size,
        image_size => $image_size,
        pixel_height => $pixel_height,
        image_type => $image_type,
        label_features => $label_features,
        included_feature_types  => $included_feature_types,
        corr_only_feature_types => $corr_only_feature_types,
        url_feature_default_display => $url_feature_default_display,
        included_evidence_types => $included_evidence_types,
        ignored_evidence_types  => $ignored_evidence_types,
        less_evidence_types     => $less_evidence_types,
        greater_evidence_types  => $greater_evidence_types,
        evidence_type_score     => $evidence_type_score,
        ignored_feature_types   => $ignored_feature_types,
        config => $config,
        left_min_corrs => $left_min_corrs,
        right_min_corrs => $right_min_corrs,
        general_min_corrs => $general_min_corrs,
        menu_min_corrs => $menu_min_corrs,
        slot_min_corrs => $slot_min_corrs,
        stack_slot => $stack_slot,
        collapse_features => $collapse_features,
        cache_dir => $cache_dir,
        map_view => $map_view,
        data_module => $data_module,
        aggregate => $aggregate,
        show_intraslot_corr => $show_intraslot_corr,
        split_agg_ev => $split_agg_ev,
        clean_view => $clean_view,
        hide_legend => $hide_legend,
        corrs_to_map => $corrs_to_map,
        scale_maps => $scale_maps,
        eliminate_orphans => $eliminate_orphans,
        stack_maps => $stack_maps,
        ref_map_order => $ref_map_order,
        comp_menu_order => $comp_menu_order,
        omit_area_boxes => $omit_area_boxes,
        session_id => $session_id,
        next_step => $next_step,
        refMenu => $refMenu,
        compMenu => $compMenu,
        optionMenu => $optionMenu,
        addOpMenu => $addOpMenu,
        dotplot => $dotplot,
        skip_drawing => $skip_drawing,
    );

=head2 Fields

=over 4

=item * slots

Slots is the only required field.

It is a hash reference with the information for the maps in each slot.

Breakdown of the data structure (variables represent changeable data):

=over 4

=item - $slot->{$slot_number}{'maps'} 

If there are individually selected maps, this is the hash where they 
are stored.  The map accession ids are the keys and a hash (described 
below) of info is the value.  Either 'maps' or 'map_sets' must be defined.

    $slot->{$slot_number}{'maps'}{$map_acc} = (
        'start' => $start || undef, # the start of the map to be displayed.  Can be undef.
        'stop'  => $stop  || undef, # the stop of the map to be displayed.  Can be undef.
        'mag'   => $mag   || undef, # the magnification of the map to be displayed.  Can be undef.
    ):

=item - $slot->{$slot_number}{'map_sets'} 

If a whole map set is to be displayed it is in this hash with the 
map set accession id as the key and undef as the value (this is saved 
for possible future developement).  Either 'maps' or 'map_sets' must 
be defined.

    $slot->{$slot_number}{'map_sets'}{$map_set_acc} = undef;

=item - $slot->{$slot_number}{'map_set_acc'}

This is the accession of the map set that the slot holds.  There can
be only one map set per slot and this is the map set accession.

    $slot->{$slot_number}{'map_set_acc'} = $map_set_acc;

=back

=item * data_source

The "data_source" parameter is a string of the name of the data source
to be used.  This information is found in the config file as the
"<database>" name field.

Defaults to the default database.

=item * apr

A CGI object that is mostly used to create the URL.

=item * flip

A string that denotes which maps are flipped.  The format is:

 $slot_no.'='.$map_acc

Multiple maps are separated by ':'.


=item * highlight

A string with the feature names to be highlighted separated by commas.

=item * font_size

String with the font size: large, medium or small.

=item * image_size

String with the image size: large, medium or small.

=item * pixel_height

String with the pixel_height of the reference map: positive integer

=item * image_type

String with the image type: png, gif, svg or jpeg.

=item * label_features

String with which labels should be displayed: all, landmarks or none.

=item * included_feature_types

An array reference that holds the feature type accessions that are 
included in the picture.

=item * corr_only_feature_types

An array reference that holds the feature type accessions that are 
included in the picture only if there is a correspondence.

=item * url_feature_default_display

This holds the default for how undefined feature types will be treated.  This
will override the value in the config file.

 0 = ignore
 1 = display only if has correspondence
 2 = display

=item * included_evidence_types

An array reference that holds the evidence type accessions that are 
used.

=item * ignored_evidence_types

An array reference that holds the evidence type accessions that are 
ignored.

=item * less_evidence_types

An array reference that holds the evidence type accessions that are used only if
their score is less than that of the score specified in evidence_type_score.

=item * greater_evidence_types

An array reference that holds the evidence type accessions that are used only if
their score is greater than that of the score specified in evidence_type_score.

=item * evidence_type_score

An hash reference that holds the score that evidence is measured against.

=item * ignored_feature_types

An array reference that holds the evidence type accessions that are 
included in the picture.

=item * config

A Bio::GMOD::CMap::Config object that can be passed to this module if
it has already been created.  Otherwise, Drawer will create it from 
the data_source.

=item * left_min_corrs

The minimum number of correspondences for the left most slot.

=item * right_min_corrs

The minimum number of correspondences for the right most slot.

=item * general_min_corrs

The minimum number of correspondences for the slots that aren't the right most
or the left most.

=item * menu_min_corrs

The minimum number of correspondences for the menu

=item * slot_min_corrs

The data structure that holds the  minimum number of correspondences for each slot

=item * stack_slot

The data structure that dicates if each slot is stacked

=item * collapse_features

Set to 1 to collaps overlapping features.

=item * cache_dir

Alternate location for the image file

=item * map_view

Either 'viewer' or 'details'.  This is only useful for links in the 
map area.  'viewer' is the default.

=item * data_module

A Bio::GMOD::CMap::Data object that can be passed to this module if
it has already been created.  Otherwise, Drawer will create it.

=item * aggregate

Set to 1 to aggregate the correspondences with one line.

Set to 2 to aggregate the correspondences with two lines.

=item * show_intraslot_corr

Set to 1 to diplsyed intraslot correspondences.

=item * split_agg_ev

Set to 1 to split correspondences with different evidence types.
Set to 0 to aggregate them all together.

=item * clean_view

Set to 1 to not have the control buttons displayed on the image.

=item * hide_legend

Set to 1 to not have the legend box displayed on the image.

=item * corrs_to_map

Set to 1 to have correspondence lines go to the map instead of the feature.

=item * scale_maps

Set to 1 scale the maps with the same unit.  Default is 1.

=item * eliminate_orphans

Set to 1 to remove maps that don't have any correspondences to a reference map.  Default is 0.

=item * stack_maps

Set to 1 stack the reference maps vertically.  Default is 0.

=item * ref_map_order

This is the string that dictates the order of the reference maps.  The format
is the list of map_accs in order, separated by commas 

=item * comp_menu_order

This is the string that dictates the order of the comparative maps in the menu.
Options are 'display_order' (order on the map display_order) and 'corrs' (order
on the number of correspondences).  'display_order' is the default.

=item * omit_area_boxes

Omit or set to 0 to render all the area boxes.  This gives full functionality
but can be a slow when there are a lot of features.

Set to 1 to omit the feature area boxes.  This will speed up render time while
leaving the navigation buttons intact.

Set to 2 to omit all of the area boxes.  This will make a non-clickable image.

=item * session_id

The session id.

=item * next_step

The session step that the new urls should use.

=item * refMenu

This is set to 1 if the Reference Menu is displayed.

=item * compMenu

This is set to 1 if the Comparison Menu is displayed.

=item * optionMenu

This is set to 1 if the Options Menu is displayed.

=item * addOpMenu

This is set to 1 if the Additional Options Menu is displayed.

=item * dotplot

This is set to 1 if a dotplot is to be drawn instead of the map view.

=item * skip_drawing

This is set to 1 if you don't want the drawer to actually do the drawing 

=back

=head1 METHODS

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.147 $)[-1];

use Bio::GMOD::CMap::Utils 'parse_words';
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Data;
use Bio::GMOD::CMap::Drawer::Map;
use Bio::GMOD::CMap::Drawer::Glyph;
use File::Basename;
use File::Temp 'tempfile';
use File::Path;
use Data::Dumper;
use base 'Bio::GMOD::CMap';

my @INIT_PARAMS = qw[
    apr                     flip                        slots
    highlight               font_size                   image_size
    image_type              label_features              included_feature_types
    corr_only_feature_types url_feature_default_display pixel_height
    included_evidence_types ignored_evidence_types      ignored_feature_types
    less_evidence_types     greater_evidence_types      evidence_type_score
    config                  data_source                 left_min_corrs
    right_min_corrs         general_min_corrs           menu_min_corrs
    slot_min_corrs          stack_slot                  collapse_features
    cache_dir               map_view                    data_module
    aggregate               show_intraslot_corr         clean_view
    scale_maps              stack_maps                  ref_map_order
    comp_menu_order         omit_area_boxes             split_agg_ev
    refMenu                 compMenu                    optionMenu
    addOpMenu               dotplot                     eliminate_orphans
    corrs_to_map            session_id                  next_step
    ignore_image_map_sanity skip_drawing                hide_legend
];

# ----------------------------------------------------
sub init {

=pod

=head2 init

Initializes the drawing object.

=cut

    my ( $self, $config ) = @_;

    $self->initialize_params($config);

    $self->data or return;

    unless ( $self->skip_drawing() ) {

        # Check to make sure the image dir isn't too full.
        return unless $self->img_dir_ok();

        my $gd_class = $self->image_type eq 'svg' ? 'GD::SVG' : 'GD';

        eval "use $gd_class";

        return $self->error(@$) if @$;

        $self->draw or return;
    }

    return $self;
}

# ----------------------------------------------------
sub initialize_params {

=pod

=head2 init

Initializes the passed parameters.

=cut

    my ( $self, $config ) = @_;

    for my $param (@INIT_PARAMS) {
        $self->$param( $config->{$param} );
    }

}

# ----------------------------------------
sub img_dir_ok {

=pod

=head2 img_dir_ok

Check the image directory

=cut

    my $self = shift;
    $self->{'data_module'} = shift if @_;

    if ( $self->check_img_dir_fullness() ) {
        if ( $self->clear_img_dir() ) {
            if ( $self->check_img_dir_fullness() ) {
                $self->error( "Error: Image directory '"
                        . $self->cache_dir . "' is "
                        . 'filled.  The maximum allowed is '
                        . $self->config_data('max_img_dir_fullness')
                        . '% filled . '
                        . " CMap was unable to purge enough space."
                        . " Please contact the site administrator for assistance."
                );
                return 0;
            }
        }
        else {
            $self->error( "Error: Image directory '"
                    . $self->cache_dir . "' is "
                    . 'filled.  The maximum allowed is '
                    . $self->config_data('max_img_dir_fullness')
                    . '% filled . '
                    . " CMap is not set to automatically purge this directory."
                    . " Please contact the site administrator for assistance."
            );
            return 0;
        }
    }
    if ( $self->check_img_dir_size() ) {
        if ( $self->clear_img_dir() ) {
            if ( $self->check_img_dir_size() ) {
                $self->error( "Error: Image directory '"
                        . $self->cache_dir
                        . "' filled.  "
                        . " The maximum size the directory can grow is "
                        . $self->config_data('max_img_dir_size')
                        . " bytes. "
                        . " CMap was unable to purge enough space."
                        . " Please contact the site administrator for assistance."
                );
                return 0;
            }
        }
        else {
            $self->error( "Error: Image directory '"
                    . $self->cache_dir
                    . "' filled.  "
                    . " The maximum size the directory can grow is "
                    . $self->config_data('max_img_dir_size')
                    . " bytes. "
                    . " CMap is not set to automatically purge this directory."
                    . " Please contact the site administrator for assistance."
            );
            return 0;
        }
    }

    return 1;
}

# ----------------------------------------
sub xdata_module {

=pod

=head2 data_module

Returns the CMap::Data object.

=cut

    my $self = shift;
    $self->{'data_module'} = shift if @_;
    unless ( $self->{'data_module'} ) {
        $self->{'data_module'} = $self->SUPER::data_module();
    }
    return $self->{'data_module'} || undef;
}

# ----------------------------------------------------
sub apr {

=pod

=head2 apr

Returns the Apache::Request object.

=cut

    my $self = shift;
    $self->{'apr'} = shift if @_;
    return $self->{'apr'} || undef;
}

# ----------------------------------------------------
sub skip_drawing {

=pod

=head2 skip_drawing

Returns the Apache::Request object.

=cut

    my $self = shift;
    $self->{'skip_drawing'} = shift if @_;
    return $self->{'skip_drawing'} || undef;
}

# ----------------------------------------------------
sub adjust_frame {

=pod

=head2 adjust_frame

If there's anything drawn in a negative X or Y region, move everything
so that it's positive.

=cut

    my ( $self, %args ) = @_;
    my ( $x_shift, $y_shift );

    if (%args) {
        $x_shift = $args{'x_shift'};
        $y_shift = $args{'y_shift'};
    }

    unless ( defined $x_shift && defined $y_shift ) {
        my $min_x = $self->min_x - 10;
        my $min_y = $self->min_y - 10;
        $x_shift = $min_x < 0 ? abs $min_x : 0;
        $y_shift = $min_y < 0 ? abs $min_y : 0;
    }

    for my $rec (
        map { @{ $self->{'drawing_data'}{$_} } }
        keys %{ $self->{'drawing_data'} }
        )
    {
        my $shape = $rec->[0];
        if ( $shape eq FILLED_POLY or $shape eq POLYGON ) {
            for (
                my $i = SHAPE_XY->{$shape}{'x'}[0];
                $i <= $#{$rec};
                $i += 2
                )
            {
                unless ( $rec->[$i] =~ m/^-?[\d.]+$/ ) {
                    last;
                }
                $rec->[$i]       += $x_shift;
                $rec->[ $i + 1 ] += $y_shift;
            }
        }
        else {
            for my $y_field ( @{ SHAPE_XY->{$shape}{'y'} } ) {
                $rec->[$y_field] += $y_shift;
            }
            for my $x_field ( @{ SHAPE_XY->{$shape}{'x'} } ) {
                $rec->[$x_field] += $x_shift;
            }
        }
    }

    if ( $args{'shift_feature_coords'} ) {
        for my $slot ( values %{ $self->{'feature_position'} } ) {
            for my $feature_pos ( values %{$slot} ) {
                $feature_pos->{'right'}[0] += $x_shift;
                $feature_pos->{'right'}[1] += $y_shift;
                $feature_pos->{'left'}[0]  += $x_shift;
                $feature_pos->{'left'}[1]  += $y_shift;
                $feature_pos->{'y1'}       += $y_shift;
                $feature_pos->{'y2'}       += $y_shift;
            }
        }
    }

    unless ( $args{'leave_map_areas'} ) {
        for my $rec ( @{ $self->{'image_map_data'} } ) {
            my @coords = @{ $rec->{'coords'} || [] } or next;
            $coords[$_] += $y_shift for ( 1, 3 );
            $coords[$_] += $x_shift for ( 0, 2 );
            $rec->{'coords'} = [ map {int} @coords ];
        }
    }

    unless ( $args{'leave_max_x_y'} ) {
        $self->{$_} += $x_shift for qw[ min_x max_x ];
        $self->{$_} += $y_shift for qw[ min_y max_y ];
    }

    return 1;
}

# ----------------------------------------------------
sub add_connection {

=pod

=head2 add_connection

Draws a line from one point to another.

=cut

    my ( $self, %args ) = @_;

    my $x1                = $args{'x1'};
    my $y1                = $args{'y1'};
    my $x2                = $args{'x2'};
    my $y2                = $args{'y2'};
    my $color             = $args{'line_color'};
    my $same_map          = $args{'same_map'};
    my $label_side        = $args{'label_side'};
    my $line_type         = $args{'line_type'};
    my $feature1_ys       = $args{'feature1_ys'};
    my $feature2_ys       = $args{'feature2_ys'};
    my $evidence_type_acc = $args{'evidence_type_acc'};

    my $layer = 0;      # bottom-most layer of image
    my @lines = ();
    my $line  = LINE;

    unless ( CORR_GLYPHS->{$line_type} ) {
        $line_type = 'direct';
    }

    if ( $line_type eq 'direct' ) {
        push @lines, [ $line, $x1, $y1, $x2, $y2, $color, $layer ];
    }
    elsif ( $line_type eq 'ribbon' ) {
        my $ribbon_color
            = $self->evidence_type_data( $evidence_type_acc, 'ribbon_color' )
            || $self->config_data('connecting_ribbon_color')
            || DEFAULT->{'connecting_ribbon_color'}
            || 'lightgrey';

        push @lines,
            [
            FILLED_POLY,       $x1,
            $feature1_ys->[1], $x1,
            $feature1_ys->[0], $x2,
            $feature2_ys->[0], $x2,
            $feature2_ys->[1], $x1,
            $feature1_ys->[1], $ribbon_color,
            -1,
            ];
        push @lines,
            [
            POLYGON,           $x1, $feature1_ys->[1], $x1,
            $feature1_ys->[0], $x2, $feature2_ys->[0], $x2,
            $feature2_ys->[1], $x1, $feature1_ys->[1], $color,
            $layer,
            ];
    }
    elsif ( $line_type eq 'indirect' ) {
        my $extention_length = 15;
        if ( $y1 == $y2 ) {
            push @lines, [ $line, $x1, $y1, $x2, $y2, $color ];
        }
        elsif ($same_map) {
            if ( $label_side eq RIGHT ) {
                push @lines,
                    [
                    $line, $x1, $y1, $x1 + $extention_length,
                    $y1, $color, $layer
                    ];
                push @lines,
                    [
                    $line, $x1 + $extention_length,
                    $y1,   $x2 + $extention_length,
                    $y2,   $color,
                    $layer
                    ];
                push @lines,
                    [
                    $line, $x2 + $extention_length,
                    $y2, $x2, $y2, $color, $layer
                    ];
            }
            else {
                push @lines,
                    [
                    $line, $x1, $y1, $x1 - $extention_length,
                    $y1, $color, $layer
                    ];
                push @lines,
                    [
                    $line, $x1 - $extention_length,
                    $y1,   $x2 - $extention_length,
                    $y2,   $color,
                    $layer
                    ];
                push @lines,
                    [
                    $line, $x2 - $extention_length,
                    $y2, $x2, $y2, $color, $layer
                    ];
            }
        }
        else {
            if ( $x1 < $x2 ) {
                push @lines,
                    [
                    $line, $x1, $y1, $x1 + $extention_length,
                    $y1, $color, $layer
                    ];
                push @lines,
                    [
                    $line, $x1 + $extention_length,
                    $y1,   $x2 - $extention_length,
                    $y2,   $color,
                    $layer
                    ];
                push @lines,
                    [
                    $line, $x2 - $extention_length,
                    $y2, $x2, $y2, $color, $layer
                    ];
            }
            else {
                push @lines,
                    [
                    $line, $x1, $y1, $x1 - $extention_length,
                    $y1, $color, $layer
                    ];
                push @lines,
                    [
                    $line, $x1 - $extention_length,
                    $y1,   $x2 + $extention_length,
                    $y2,   $color,
                    $layer
                    ];
                push @lines,
                    [
                    $line, $x2 + $extention_length,
                    $y2, $x2, $y2, $color, $layer
                    ];
            }
        }
    }

    return @lines;
}

# ----------------------------------------------------
sub add_drawing {

=pod

=head2 add_drawing

Accepts a list of attributes to describe how to draw an object.

=cut

    my $self = shift;
    my ( @records, @attr );
    if ( ref $_[0] eq 'ARRAY' ) {
        @records = @_;
    }
    else {
        push @records, [@_];
    }

    my ( @x, @y );
    for my $rec (@records) {
        if ( ref $_[0] eq 'ARRAY' ) {
            @attr = @{ shift() };
        }
        else {
            @attr = @_;
        }

        #
        # The last field should be a number specifying the layer.
        # If it's not, then push on the default layer of "1."
        #
        push @attr, 1 unless $attr[-1] =~ m/^-?\d+$/;

        #
        # Extract the X and Y positions in order to pass them to
        # min and max methods (to know how big the image should be).
        #
        my $shape       = $attr[0] or next;
        my $layer       = $attr[-1];
        my @x_locations = @{ SHAPE_XY->{$shape}{'x'} || [] } or next;
        my @y_locations = @{ SHAPE_XY->{$shape}{'y'} || [] } or next;

        if ( $shape eq FILLED_POLY or $shape eq POLYGON ) {
            for ( my $i = $x_locations[0]; $i <= $#attr; $i += 2 ) {
                unless ( $attr[$i] =~ m/^-?[\d.]+$/ ) {
                    last;
                }
                push @x, $attr[$i];
                push @y, $attr[ $i + 1 ];
            }
        }
        else {
            push @x, @attr[@x_locations];
            push @y, @attr[@y_locations];
        }

        if ( $shape eq STRING ) {
            my $font   = $attr[1];
            my $string = $attr[4];
            push @x,
                $attr[ $x_locations[0] ] + ( $font->width * length($string) );
            push @y, $attr[ $y_locations[0] ] - $font->height;
        }
        elsif ( $shape eq STRING_UP ) {
            my $font = $attr[1];
            push @x, $attr[ $x_locations[0] ] + $font->height;
        }

        push @{ $self->{'drawing_data'}{$layer} }, [@attr];
    }

    $self->min_x(@x);
    $self->max_x(@x);
    $self->min_y(@y);
    $self->max_y(@y);
}

# ----------------------------------------------------
sub add_map_area {

=pod

=head2 add_map_area

Accepts a list of coordinates and a URL for hyperlinking a map area.

=cut

    my $self = shift;

    if ( ref $_[0] eq 'HASH' ) {
        push @{ $self->{'image_map_data'} }, @_;
    }
    elsif ( ref $_[0] eq 'ARRAY' && @{ $_[0] } ) {
        push @{ $self->{'image_map_data'} }, $_ for @_;
    }
    else {
        push @{ $self->{'image_map_data'} }, {@_} if @_;
    }
}

# ----------------------------------------------------
sub collapse_features {

=pod

=head2 collapse_features

Gets/sets whether to collapse features.

=cut

    my $self = shift;
    my $arg  = shift;

    if ( defined $arg ) {
        $self->{'collapse_features'} = $arg;
    }

    return $self->{'collapse_features'} || 0;
}

# ----------------------------------------------------
sub comparative_map {

=pod

=head2 comparative_map

Gets/sets the comparative map.

=cut

    my $self = shift;
    if ( my $map = shift ) {
        my ( $field, $acc ) = split( /=/, $map )
            or $self->error(qq[Invalid input to comparative map "$map"]);
        $self->{'comparative_map'}{'field'} = $field;
        $self->{'comparative_map'}{'acc'}   = $acc;
    }

    return $self->{'comparative_map'};
}

# ----------------------------------------------------
sub correspondences_exist {

=pod

=head2 correspondence_exist

Returns whether or not there are any feature correspondences.

=cut

    my $self = shift;
    return %{ $self->{'data'}{'correspondences'} || {} } ? 1 : 0;
}

# ----------------------------------------------------
sub intraslot_correspondences_exist {

=pod

=head2 intraslot_correspondence_exist

Returns whether or not there are any intraslot correspondences.

=cut

    my $self = shift;
    return %{ $self->{'data'}{'intraslot_correspondences'} || {} } ? 1 : 0;
}

# ----------------------------------------------------
sub flip {

=pod

=head2 flip

Gets/sets which maps to flip.

=cut

    my $self = shift;
    if ( my $arg = shift ) {
        for my $s ( split /:/, $arg ) {
            my ( $slot_no, $map_acc ) = split /=/, $s or next;
            push @{ $self->{'flip'} },
                {
                slot_no => $slot_no,
                map_acc => $map_acc,
                };
        }
    }

    return $self->{'flip'} || [];
}

# ----------------------------------------------------
sub is_flipped {

=pod

=head2 flip

Boolean: is the map flipped

=cut

    my $self       = shift;
    my $slot_no    = shift;
    my $map_acc    = shift;
    my $flip_array = $self->flip();

    for ( my $i = 0; $i <= $#{$flip_array}; $i++ ) {
        if (    $flip_array->[$i]{'slot_no'} == $slot_no
            and $flip_array->[$i]{'map_acc'} eq $map_acc )
        {
            return 1;
        }
    }
    return 0;
}

# ----------------------------------------------------
sub set_map_flip {

=pod

=head2 set_map_flip

Sets the flip value of a map

=cut

    my $self       = shift;
    my $slot_no    = shift;
    my $map_acc    = shift;
    my $flip_value = shift;

    my $was_flipped = 0;
    my $flip_array  = $self->flip();

    for ( my $i = 0; $i <= $#{$flip_array}; $i++ ) {
        if (    $flip_array->[$i]{'slot_no'} == $slot_no
            and $flip_array->[$i]{'map_acc'} eq $map_acc )
        {
            $was_flipped = 1;
            unless ($flip_value) {

                # remove from flip array
                splice( @$flip_array, $i, 1 );
                $i--;
            }
        }
    }
    if ( $flip_value and not $was_flipped ) {
        push @{ $self->{'flip'} },
            {
            slot_no => $slot_no,
            map_acc => $map_acc,
            };
    }

    return;
}

# ----------------------------------------------------
sub get_completed_map {

=pod

=head2 get_completed_maps

Gets a completed map.

=cut

    my ( $self, $map_no ) = @_;
    return $self->{'completed_maps'}{$map_no};
}

# ----------------------------------------------------
sub included_evidence_types {

=pod

=head2 included_evidence_types

Gets/sets which evidence type (accession IDs) to include.

=cut

    my $self = shift;

    if ( my $arg = shift ) {
        $arg = [$arg] unless ( ref($arg) eq 'ARRAY' );
        $self->{'included_evidence_types'} = $arg;
    }
    $self->{'included_evidence_types'} = []
        unless $self->{'included_evidence_types'};

    return $self->{'included_evidence_types'};
}

# ----------------------------------------------------
sub ignored_evidence_types {

=pod

=head2 ignored_evidence_types

Gets/sets which evidence type (accession IDs) to ignore.

=cut

    my $self = shift;

    if ( my $arg = shift ) {
        $arg = [$arg] unless ( ref($arg) eq 'ARRAY' );
        $self->{'ignored_evidence_types'} = $arg;
    }
    $self->{'ignored_evidence_types'} = []
        unless $self->{'ignored_evidence_types'};

    return $self->{'ignored_evidence_types'};
}

# ----------------------------------------------------
sub less_evidence_types {

=pod

=head2 less_evidence_types

Gets/sets which evidence type (accession IDs) to measure against the scores.

=cut

    my $self = shift;

    if ( my $arg = shift ) {
        $arg = [$arg] unless ( ref($arg) eq 'ARRAY' );
        $self->{'less_evidence_types'} = $arg;
    }
    $self->{'less_evidence_types'} = []
        unless $self->{'less_evidence_types'};

    return $self->{'less_evidence_types'};
}

# ----------------------------------------------------
sub greater_evidence_types {

=pod

=head2 greater_evidence_types

Gets/sets which evidence type (accession IDs) to measure against the scores.

=cut

    my $self = shift;

    if ( my $arg = shift ) {
        $arg = [$arg] unless ( ref($arg) eq 'ARRAY' );
        $self->{'greater_evidence_types'} = $arg;
    }
    $self->{'greater_evidence_types'} = []
        unless $self->{'greater_evidence_types'};

    return $self->{'greater_evidence_types'};
}

# ----------------------------------------------------
sub evidence_type_score {

=pod

=head2 evidence_type_score

Gets/sets which evidence type scores 

=cut

    my $self = shift;

    if ( my $arg = shift ) {
        $self->{'evidence_type_score'} = $arg;
    }
    $self->{'evidence_type_score'} = {}
        unless $self->{'evidence_type_score'};

    return $self->{'evidence_type_score'};
}

# ----------------------------------------------------
sub included_feature_types {

=pod

=head2 included_feature_types

Gets/sets which feature type (accession IDs) to include.

=cut

    my $self = shift;

    if ( my $arg = shift ) {
        $arg = [$arg] unless ( ref($arg) eq 'ARRAY' );
        $self->{'included_feature_types'} = $arg;
    }
    $self->{'included_feature_types'} = []
        unless $self->{'included_feature_types'};

    return $self->{'included_feature_types'};
}

# ----------------------------------------------------
sub corr_only_feature_types {

=pod
                                                                                
=head2 corr_only_feature_types

Gets/sets which feature type (accession IDs) to corr_only.

=cut

    my $self = shift;

    if ( my $arg = shift ) {
        $arg = [$arg] unless ( ref($arg) eq 'ARRAY' );
        $self->{'corr_only_feature_types'} = $arg;
    }
    $self->{'corr_only_feature_types'} = []
        unless $self->{'corr_only_feature_types'};

    return $self->{'corr_only_feature_types'};
}

# ----------------------------------------------------
sub ignored_feature_types {

=pod
                                                                                
=head2 ignored_feature_types

Gets/sets which feature type (accession IDs) to ignore.

=cut

    my $self = shift;

    if ( my $arg = shift ) {
        $arg = [$arg] unless ( ref($arg) eq 'ARRAY' );
        $self->{'ignored_feature_types'} = $arg;
    }
    $self->{'ignored_feature_types'} = []
        unless $self->{'ignored_feature_types'};

    return $self->{'ignored_feature_types'};
}

# ----------------------------------------------------
sub set_completed_map {

=pod

=head2 set_completed_map

Sets a completed map.

=cut

    my ( $self, %args ) = @_;
    $self->{'completed_maps'}{ $args{'map_no'} } = $args{'map'};
}

# ----------------------------------------------------
sub drawing_data {

=pod

=head2 drawing_data

Returns the drawing data.

=cut

    my $self = shift;
    return map { @{ $self->{'drawing_data'}{$_} } }
        sort   { $a <=> $b }
        keys %{ $self->{'drawing_data'} };
}

# ----------------------------------------------------
sub draw {

=pod

=head2 draw

Lays out the image and writes it to the file system, set the "image_name."

=cut

    my $self = shift;

    my ( $min_y, $max_y, $min_x, $max_x );
    my $corrs_aggregated    = 0;
    my $slots_capped_max    = undef;
    my $slots_capped_min    = undef;
    my $omit_all_area_boxes = ( $self->omit_area_boxes == 2 );

    for my $slot_no ( $self->slot_numbers ) {

        # If there is nothing in one of the slots, don't show any slots
        #  after it.  That is the purpose of the slots_capped variables.
        next
            if ( defined($slots_capped_max)
            and $slots_capped_max < $slot_no );
        next
            if ( defined($slots_capped_min)
            and $slots_capped_min > $slot_no );
        my $data = $self->slot_data($slot_no)
            or return $self->error("No Data For Slot $slot_no\n");
        unless (%$data) {
            if ( $slot_no > 0 ) {
                $slots_capped_max = $slot_no;
            }
            elsif ( $slot_no < 0 ) {
                $slots_capped_min = $slot_no;

            }
            else {

                # slot is 0
                $slots_capped_max = $slot_no;
                $slots_capped_min = $slot_no;
            }
            next;
        }

        my $map = Bio::GMOD::CMap::Drawer::Map->new(
            drawer     => $self,
            slot_no    => $slot_no,
            maps       => $data,
            config     => $self->config(),
            aggregate  => $self->aggregate,
            clean_view => $self->clean_view,
            scale_maps => $self->scale_maps,
            stack_maps => $self->stack_maps,
        ) or return $self->error( Bio::GMOD::CMap::Drawer::Map->error );

        my ( $bounds, $corrs_aggregated_tmp ) = $map->layout
            or return $self->error( $map->error );
        $corrs_aggregated = $corrs_aggregated_tmp if $corrs_aggregated_tmp;
        $min_x = $bounds->[0] unless defined $min_x;
        $min_y = $bounds->[1] unless defined $min_y;
        $max_x = $bounds->[2] unless defined $max_x;
        $max_y = $bounds->[3] unless defined $max_y;
        $min_x = $bounds->[0] if $bounds->[0] < $min_x;
        $min_y = $bounds->[1] if $bounds->[1] < $min_y;
        $max_x = $bounds->[2] if $bounds->[2] > $max_x;
        $max_y = $bounds->[3] if $bounds->[3] > $max_y;

        $self->slot_sides(
            slot_no => $slot_no,
            left    => $bounds->[0],
            right   => $bounds->[2],
        );
        $self->min_x( ( $min_x, ) );
        $self->max_x( ( $max_x, ) );
        $self->min_y( ( $min_y, ) );
        $self->max_y( ( $max_y, ) );

        #
        # Draw feature correspondences to reference map.
        #

        for my $position_set (
            $self->feature_correspondence_positions( slot_no => $slot_no ) )
        {
            my @positions = @{ $position_set->{'positions'} || [] } or next;
            my $evidence_info = $self->feature_correspondence_evidence(
                $position_set->{'feature_id1'},
                $position_set->{'feature_id2'}
            );

            $self->add_drawing(
                $self->add_connection(
                    x1          => $positions[0],
                    y1          => $positions[1],
                    x2          => $positions[2],
                    y2          => $positions[3],
                    same_map    => $position_set->{'same_map'} || 0,
                    sabel_side  => $position_set->{'label_side'} || '',
                    feature1_ys => $position_set->{'feature1_ys'},
                    feature2_ys => $position_set->{'feature2_ys'},
                    evidence_type_acc =>
                        $evidence_info->{'evidence_type_acc'},
                    line_color => $evidence_info->{'line_color'}
                        || $self->config_data('connecting_line_color')
                        || DEFAULT->{'connecting_line_color'},
                    line_type => $evidence_info->{'line_type'}
                        || $self->config_data('connecting_line_type')
                        || DEFAULT->{'connecting_line_type'},
                )
            );
        }
    }

    # Add the slot title boxes
    # First find out the height of the tallest title box
    my $max_title_height = 0;
    for my $slot_no ( $self->slot_numbers ) {
        my $title_data = $self->slot_title( slot_no => $slot_no );
        my $height = $title_data->{'bounds'}[3] - $title_data->{'bounds'}[1];
        $max_title_height = $height if ( $max_title_height < $height );
    }
    my $title_top = $self->min_y - $max_title_height;
    $self->min_y($title_top);
    for my $slot_no ( $self->slot_numbers ) {
        my ( $left, $right ) = $self->slot_sides( slot_no => $slot_no );
        my $slot_center = ( ( $right + $left ) / 2 );
        my $title_data     = $self->slot_title( slot_no => $slot_no );
        my $bounds         = $title_data->{'bounds'};
        my $map_area_data  = $title_data->{'map_area_data'};
        my $drawing_data   = $title_data->{'drawing_data'};
        my $title_center_x = ( ( $bounds->[2] + $bounds->[0] ) / 2 );
        my $offset_x       = $slot_center - $title_center_x;
        my $offset_y       = $title_top - $bounds->[1];
        $self->offset_drawing_data(
            offset_x     => $offset_x,
            offset_y     => $offset_y,
            drawing_data => $drawing_data,
        );
        $self->add_drawing( @{$drawing_data} );
        $self->offset_map_area_data(
            offset_x      => $offset_x,
            offset_y      => $offset_y,
            map_area_data => $map_area_data,
        );
        $self->add_map_area( @{$map_area_data} );
    }

    #
    # Frame out the slots.
    #
    my $bg_color     = $self->config_data('slot_background_color');
    my $border_color = $self->config_data('slot_border_color');
    for my $slot_no ( $self->slot_numbers ) {
        my ( $left, $right ) = $self->slot_sides( slot_no => $slot_no );
        my @slot_bounds = ( $left, $self->min_y, $right, $max_y, );

        $self->add_drawing( FILLED_RECT, @slot_bounds, $bg_color,     -50 );
        $self->add_drawing( RECTANGLE,   @slot_bounds, $border_color, -40 );
    }

    my $font = $self->regular_font;
    unless ( $self->hide_legend() ) {
        ( $min_x, $max_x, $min_y, $max_y ) = $self->draw_legend(
            font                => $font,
            min_y               => $min_y,
            max_y               => $max_y,
            min_x               => $min_x,
            max_x               => $max_x,
            omit_all_area_boxes => $omit_all_area_boxes,
            corrs_aggregated    => $corrs_aggregated,
            bg_color            => $bg_color,
            border_color        => $border_color,
        );
    }

    my $watermark = 'CMap v' . $Bio::GMOD::CMap::VERSION;
    my $wm_x      = $max_x - $font->width * length($watermark) - 5;
    my $wm_y      = $max_y;
    $self->add_drawing( STRING, $font, $wm_x, $wm_y, $watermark, 'grey' );
    $self->add_map_area(
        coords => [
            $wm_x, $wm_y,
            $wm_x + $font->width * length($watermark),
            $wm_y + $font->height
        ],
        url => CMAP_URL,
        alt => 'GMOD-CMap website',
    ) unless ($omit_all_area_boxes);

    $max_y += $font->height;

    $self->max_x($max_x);
    $self->max_y($max_y);

    # Do the sanity check for area boxes
    unless ( $self->ignore_image_map_sanity ) {
        my $max_boxes = DEFAULT->{'max_image_map_objects'};
        my $config_max_image_map_objects
            = $self->config_data('max_image_map_objects');
        if ( defined($config_max_image_map_objects)
            and $config_max_image_map_objects =~ /^[\d,]+$/ )
        {
            $max_boxes = $config_max_image_map_objects;
        }

        if ( scalar( $self->image_map_data ) > $max_boxes ) {
            $self->{'image_map_data'} = ();
            $self->message(
                'WARNING:  There were too many clickable objects on this image to render in a timely manner and may break some browsers.  It is recommended that you limit the display of features in the Options Menu.  <BR>If you wish to ignore this and render the image buttons, you can select "Ignore Image Map Sanity Check" in the Additional Options Menu.'
            );
        }
    }

    #
    # Move all the coordinates to positive numbers.
    #
    $self->adjust_frame;

    $self->draw_image();

    return $self;
}

# ----------------------------------------------------
sub draw_legend {

=pod

=head2 draw

Lays out the legend.  Used in draw().

=cut

    my ( $self, %args ) = @_;

    my $min_x               = $args{'min_x'};
    my $max_x               = $args{'max_x'};
    my $min_y               = $args{'min_y'};
    my $max_y               = $args{'max_y'};
    my $font                = $args{'font'};
    my $omit_all_area_boxes = $args{'omit_all_area_boxes'};
    my $corrs_aggregated    = $args{'corrs_aggregated'};
    my $bg_color            = $args{'bg_color'};
    my $border_color        = $args{'border_color'};

    my @bounds = ( $min_x, $max_y + 10 );

    #
    # Add the legend
    #
    my $x = $min_x + 20;
    $max_y += 20;

    #
    # Add the legend for the feature types.
    #
    if ( my @feature_types = $self->feature_types_seen_first ) {
        my $string = 'Feature Types:';
        $self->add_drawing( STRING, $font, $x, $max_y, $string, 'black' );
        $max_y += $font->height + 10;
        my $end = $x + $font->width * length($string);
        $max_x = $end if $end > $max_x;

        my $corr_color = $self->config_data('feature_correspondence_color');
        my $ft_details_url = $self->config_data('feature_type_details_url');
        my $et_details_url = $self->config_data('evidence_type_details_url');

        if ( $corr_color && $self->correspondences_exist ) {
            push @feature_types,
                {
                seen  => 1,
                shape => '',
                color => $corr_color,
                feature_type =>
                    "Features in $corr_color have correspondences",
                correspondence_color => 1,
                };
        }

        for my $ft (@feature_types) {
            my $color
                = $ft->{'seen'}
                ? ( $ft->{'color'} || $self->config_data('feature_color') )
                : 'grey';
            my $label     = $ft->{'feature_type'} or next;
            my $feature_x = $x;
            my $feature_y = $max_y;
            my $label_x   = $feature_x;
            my $label_y;

            if ( $self->clean_view() and not $ft->{'seen'} ) {
                next;
            }

            if ( $ft->{'seen'} ) {

                # Displayed Features
                if ( $ft->{'shape'} eq 'line' ) {
                    $self->add_drawing( LINE, $feature_x, $feature_y,
                        $feature_x + 10,
                        $feature_y, $color );
                    $label_y = $feature_y;
                }
                else {
                    my @temp_drawing_data;
                    my $glyph = Bio::GMOD::CMap::Drawer::Glyph->new(
                        config      => $self->config,
                        data_source => $self->data_source,
                    );
                    my $feature_glyph = $ft->{'shape'};
                    $feature_glyph =~ s/-/_/g;
                    if ( $glyph->can($feature_glyph) ) {
                        $glyph->$feature_glyph(
                            drawing_data     => \@temp_drawing_data,
                            x_pos2           => $feature_x + 7,
                            x_pos1           => $feature_x + 3,
                            y_pos1           => $feature_y,
                            y_pos2           => $feature_y + 8,
                            color            => $color,
                            label_side       => RIGHT,
                            calling_obj      => $self,
                            drawer           => $self,
                            feature_type_acc => $ft->{'feature_type_acc'},
                        );
                        $self->add_drawing(@temp_drawing_data);
                    }
                    $label_y = $feature_y + 5;
                }
                $label_x += 15;
            }
            elsif ( !$omit_all_area_boxes ) {

                # Features that aren't being displayed
                my $box_x1   = $feature_x;
                my $box_x2   = $feature_x + $font->height - 1;
                my $box_midx = $feature_x + int( $font->height / 2 );
                my $box_midy = $feature_y - 1;
                my $box_y1   = $box_midy - int( $font->height / 2 ) + 1;
                my $box_y2   = $box_midy + int( $font->height / 2 ) - 1;

                # Cross Bars
                $self->add_drawing( LINE, $box_x1 + 2, $box_midy, $box_x2 - 2,
                    $box_midy, $color,
                );
                $self->add_drawing( LINE, $box_midx, $box_y1 + 2, $box_midx,
                    $box_y2 - 2, $color,
                );

                # Surrounding Box
                $self->add_drawing( LINE, $box_x1, $box_y1, $box_x2, $box_y1,
                    $color, );
                $self->add_drawing( LINE, $box_x1, $box_y1, $box_x1, $box_y2,
                    $color, );
                $self->add_drawing( LINE, $box_x2, $box_y1, $box_x2, $box_y2,
                    $color, );
                $self->add_drawing( LINE, $box_x1, $box_y2, $box_x2, $box_y2,
                    $color, );

                my $display_ft_url = $self->create_viewer_link(
                    $self->create_minimal_link_params(),
                    session_mod => "ft=" . $ft->{'feature_type_acc'} . "=2",
                );

                $self->add_map_area(
                    coords => [ $box_x1, $box_y1, $box_x2, $box_y2, ],
                    url    => $display_ft_url,
                    alt => "Display $label on the maps",
                );

                $label_y = $feature_y;
                $label_x += $font->height + 3;
            }
            else {
                $label_x += 15;
                $label_y = $feature_y;
            }

            my $ft_y = $label_y - $font->height / 2;
            $self->add_drawing( STRING, $font, $label_x, $ft_y, $label,
                $color );

            $self->add_map_area(
                coords => [
                    $label_x, $ft_y,
                    $label_x + $font->width * length($label),
                    $ft_y + $font->height,
                ],
                url => $ft_details_url . $ft->{'feature_type_acc'},
                alt => "Feature Type Details for $label",
                )
                unless ( $omit_all_area_boxes
                or $ft->{'correspondence_color'} );

            my $furthest_x = $label_x + $font->width * length($label) + 5;
            $max_x = $furthest_x if $furthest_x > $max_x;
            $max_y = $label_y + $font->height;
        }

        #
        # Evidence type legend.
        #
        if ( my @evidence_types = $self->correspondence_evidence_seen ) {
            $self->add_drawing( STRING, $font, $x, $max_y, 'Evidence Types:',
                'black' );
            $max_y += $font->height + 10;

            for my $et (@evidence_types) {
                my $color = $et->{'line_color'}
                    || $self->config_data('connecting_line_color');
                my $string
                    = ucfirst($color)
                    . ' line denotes '
                    . $et->{'evidence_type'};

                $self->add_drawing( STRING, $font, $x + 15, $max_y, $string,
                    $color );

                my $end = $x + 15 + $font->width * length($string) + 4;
                $max_x = $end if $end > $max_x;

                $self->add_map_area(
                    coords =>
                        [ $x + 15, $max_y, $end, $max_y + $font->height, ],
                    url => $et_details_url . $et->{'evidence_type_acc'},
                    alt => 'Evidence Type Details for '
                        . $et->{'evidence_type'},
                ) unless ($omit_all_area_boxes);

                $max_y += $font->height + 5;
            }
        }
        $max_y += 5;
    }

    if ($corrs_aggregated) {

        $self->add_drawing( STRING, $font, $x, $max_y,
            'Aggregated Correspondences Colors:', 'black' );
        $max_y += $font->height + 10;
        my $all_corr_colors = $self->aggregated_correspondence_colors;
        if ( $all_corr_colors and %$all_corr_colors ) {
            foreach my $evidence_type_acc ( keys(%$all_corr_colors) ) {
                my $corr_colors = $all_corr_colors->{$evidence_type_acc};
                my $default_color
                    = $self->default_aggregated_correspondence_color(
                    $evidence_type_acc);
                my $last_bound;
                if ( $evidence_type_acc ne
                    DEFAULT->{'aggregated_type_substitute'} )
                {
                    $self->add_drawing( STRING, $font, $x, $max_y,
                        $self->evidence_type_data(
                            $evidence_type_acc, 'evidence_type'
                        ),
                        'black'
                    );
                    $max_y += $font->height + 4;
                }
                elsif ( scalar( keys(%$all_corr_colors) ) > 1 ) {

                    # These are the default colors.
                    # They are not needed if the types are defined.
                    next;
                }
                foreach my $color_bound (
                    sort { $a <=> $b }
                    grep {$_} keys(%$corr_colors)
                    )
                {
                    $self->add_drawing(
                        STRING,
                        $font,
                        $x + 15,
                        $max_y,
                        $color_bound . ' or fewer correspondences',
                        $corr_colors->{$color_bound}
                    );
                    $max_y += $font->height + 4;
                    $last_bound = $color_bound;
                }
                $self->add_drawing( STRING, $font, $x + 15, $max_y,
                    'More than ' . $last_bound . ' correspondences',
                    $default_color );
                $max_y += $font->height + 6;
            }
        }
        else {
            my $default_color
                = $self->default_aggregated_correspondence_color;
            $self->add_drawing( STRING, $font, $x, $max_y,
                'All Aggregated Correspondences',
                $default_color );
            $max_y += $font->height + 4;

        }
        $max_y += $font->height;

    }

    #
    # Extra symbols.
    #
    my @buttons = (
        [ 'i'  => 'Map Set Info' ],
        [ '?'  => 'Map Details' ],
        [ 'M'  => 'Matrix View' ],
        [ 'L'  => 'Limit to One Map' ],
        [ 'X'  => 'Delete Map Set' ],
        [ 'x'  => 'Delete Map' ],
        [ 'F'  => 'Flip Map' ],
        [ 'UF' => 'Unflip Map' ],
        [ 'N'  => 'New Map View' ],
    );
    unless ( $self->clean_view() ) {
        $self->add_drawing( STRING, $font, $x, $max_y, 'Menu Symbols:',
            'black' );
        $max_y += $font->height + 10;

        for my $button (@buttons) {
            my ( $sym, $caption ) = @$button;
            $self->add_drawing( STRING, $font, $x + 3, $max_y + 2, $sym,
                'grey' );
            my $end = $x + ( $font->width * length($sym) ) + 4;

            $self->add_drawing( RECTANGLE, $x, $max_y, $end,
                $max_y + $font->height + 4, 'grey' );

            $self->add_drawing( STRING, $font, $end + 5, $max_y + 2, $caption,
                'black' );

            $max_y += $font->height + 10;
        }
    }

    push @bounds, ( $max_x, $max_y );

    $self->add_drawing( FILLED_RECT, @bounds, $bg_color,     -1 );
    $self->add_drawing( RECTANGLE,   @bounds, $border_color, -1 );

    return ( $min_x, $max_x, $min_y, $max_y );
}

# ----------------------------------------------------
sub draw_image {

=pod

=head2 draw_image

Do the actual drawing.

=cut

    my $self = shift;

    my @data       = $self->drawing_data;
    my $height     = $self->map_height;
    my $width      = $self->map_width;
    my $img_class  = $self->image_class;
    my $poly_class = $self->polygon_class;
    my $img        = $img_class->new( $width, $height );
    my %colors     = (
        (   map {
                $_,
                    $img->colorAllocate( map { hex $_ } @{ +COLORS->{$_} } )
                }
                keys %{ +COLORS }
        ),
        (   map {
                $_,
                    $img->colorAllocate( @{ $self->{'custom_colors'}{$_} } )
                }
                keys %{ $self->{'custom_colors'} }
        ),
    );
    $img->interlaced('true');
    $img->filledRectangle( 0, 0, $width, $height,
        $colors{ $self->config_data('background_color') } );

    #
    # Sort the drawing data by the layer (which is the last field).
    #
    for my $obj ( sort { $a->[-1] <=> $b->[-1] } @data ) {
        my $method = shift @$obj;
        my $layer  = pop @$obj;
        my @colors = pop @$obj;
        push @colors, pop @$obj if $method eq FILL_TO_BORDER;

        if ( $method eq FILLED_POLY or $method eq POLYGON ) {
            my $poly = $poly_class->new();
            for ( my $i = 0; $i <= $#{$obj}; $i += 2 ) {
                unless ( $obj->[$i] =~ m/^-?[\d.]+$/ ) {
                    last;
                }
                $poly->addPt( $obj->[$i], $obj->[ $i + 1 ] );
            }
            $img->$method( $poly, map { $colors{ lc $_ } } @colors );
        }
        else {
            $img->$method( @$obj, map { $colors{ lc $_ } } @colors );
        }
    }

    #
    # Add a black box around the whole #!.
    #
    $img->rectangle( 0, 0, $width - 1, $height - 1, $colors{'black'} );

    #
    # Write to a temporary file and remember it.
    #
    my $cache_dir = $self->cache_dir or return;
    my $image_type = $self->image_type;
    my $suffix = '.' . ( ( $image_type eq 'jpeg' ) ? 'jpg' : $image_type );
    my ( $fh, $filename )
        = tempfile( 'X' x 9, DIR => $cache_dir, SUFFIX => $suffix );
    print $fh $img->$image_type()
        || $self->warn("CMap image write failed: $!");
    $fh->close;
    $self->image_name($filename);

    return;
}

# ----------------------------------------------------
sub data {

=pod

=head2 data

Uses the Bio::GMOD::CMap::Data module to retreive the 
necessary data for drawing.

=cut

    my $self = shift;

    unless ( $self->{'data'} ) {
        my $data = $self->data_module or return;
        ( $self->{'data'}, $self->{'slots'} ) = $data->cmap_data(
            slots                       => $self->{'slots'},
            slot_min_corrs              => $self->slot_min_corrs,
            stack_slot                  => $self->stack_slot,
            eliminate_orphans           => $self->eliminate_orphans,
            included_feature_type_accs  => $self->included_feature_types,
            corr_only_feature_type_accs => $self->corr_only_feature_types,
            ignored_feature_type_accs   => $self->ignored_feature_types,
            url_feature_default_display => $self->url_feature_default_display,
            included_evidence_type_accs => $self->included_evidence_types,
            ignored_evidence_type_accs  => $self->ignored_evidence_types,
            less_evidence_type_accs     => $self->less_evidence_types,
            greater_evidence_type_accs  => $self->greater_evidence_types,
            evidence_type_score         => $self->evidence_type_score,
        ) or return $self->error( $data->error );

        return $self->error("Problem getting data") unless $self->{'data'};

        $self->modify_min_corrs( $self->{'slots'} );

        # Set the feature and evidence types for later use.
        $self->included_feature_types(
            $self->{'data'}{'included_feature_type_accs'} );
        $self->corr_only_feature_types(
            $self->{'data'}{'corr_only_feature_type_accs'} );
        $self->ignored_feature_types(
            $self->{'data'}{'ignored_feature_type_accs'} );
        $self->included_evidence_types(
            $self->{'data'}{'included_evidence_type_accs'} );
        $self->ignored_evidence_types(
            $self->{'data'}{'ignored_evidence_type_accs'} );
    }

    return $self->{'data'};
}

# ----------------------------------------------------
sub correspondence_evidence_seen {

=pod

=head2 correspondence_evidence_seen

Returns a distinct list of all the correspondence evidence types seen.

=cut

    my $self = shift;
    unless ( $self->{'correspondence_evidence_seen'} ) {
        my %types = map { $_->{'evidence_type'}, $_ }
            values %{ $self->{'data'}{'correspondence_evidence'} };

        $self->{'correspondence_evidence_seen'} = [
            map { $types{$_} }
                sort keys %types
        ];
    }

    return @{ $self->{'correspondence_evidence_seen'} || [] };
}

# ----------------------------------------------------
sub feature_correspondence_evidence {

=pod

=head2 feature_correspondence_evidence

Given a feature correspondence ID, returns supporting evidence.

=cut

    my ( $self, $fid1, $fid2 ) = @_;
    my $feature_correspondence_id
        = $self->{'data'}{'correspondences'}{$fid1}{$fid2}
        or return;

    return $self->{'data'}{'correspondence_evidence'}
        {$feature_correspondence_id};
}

# ----------------------------------------------------
sub intraslot_correspondence_evidence {

=pod

=head2 intraslot_correspondence_evidence

Given two feature ids, returns supporting evidence.

=cut

    my ( $self, $fid1, $fid2 ) = @_;
    my $intraslot_correspondence_id
        = $self->{'data'}{'intraslot_correspondences'}{$fid1}{$fid2}
        or return;

    return $self->{'data'}{'intraslot_correspondence_evidence'}
        {$intraslot_correspondence_id};
}

# ----------------------------------------------------
sub feature_types_seen_first {

=pod

=head2 feature_types_seen_first

Returns all the feature types on maps with the ones seen listed first

=cut

    my $self = shift;
    unless ( $self->{'feature_types'} ) {
        $self->{'feature_types'}
            = [ values %{ $self->{'data'}{'feature_types'} || {} } ];
    }

    return sort {
               $b->{'seen'} cmp $a->{'seen'}
            || ( $a->{'drawing_lane'} || 0 ) <=> ( $b->{'drawing_lane'} || 0 )
            || lc $a->{'feature_type'} cmp lc $b->{'feature_type'}
    } @{ $self->{'feature_types'} || [] };
}

# ----------------------------------------------------
sub feature_correspondences {

=pod

=head2 feature_correspondences

Returns the correspondences for a given feature id.

=cut

    my $self = shift;
    my @feature_ids = ref $_[0] eq 'ARRAY' ? @{ shift() } : ( shift() );
    return unless @feature_ids;

    return
        map { keys %{ $self->{'data'}{'correspondences'}{$_} || {} } }
        @feature_ids;
}

# ----------------------------------------------------
sub intraslot_correspondences {

=pod

=head2 intraslot_correspondences

Returns the correspondences for a given feature id.

=cut

    my $self = shift;
    my @feature_ids = ref $_[0] eq 'ARRAY' ? @{ shift() } : ( shift() );
    return unless @feature_ids;

    return map {
        keys %{ $self->{'data'}{'intraslot_correspondences'}{$_} || {} }
    } @feature_ids;
}

# ----------------------------------------------------
sub feature_correspondence_positions {

=pod

=head2 feature_correspondence_positions

Accepts a slot number and returns an array of arrayrefs denoting the positions
to connect corresponding features on two maps.

=cut

    my ( $self, %args ) = @_;
    my $slot_no     = $args{'slot_no'};
    my $ref_slot_no = $self->reference_slot_no($slot_no);
    my $ref_side    = $slot_no > 0 ? RIGHT : LEFT;
    my $cur_side    = $slot_no > 0 ? LEFT : RIGHT;

    # Return unless ref slot no is is defined and not ""
    unless ( defined($ref_slot_no) and ( $ref_slot_no or $ref_slot_no == 0 ) )
    {
        return ();
    }
    my @return = ();
    for my $f1 ( keys %{ $self->{'feature_position'}{$slot_no} } ) {
        my $self_label_side = $self->label_side($slot_no);

        my $f1_ys = [
            $self->{'feature_position'}{$slot_no}{$f1}{'y1'},
            $self->{'feature_position'}{$slot_no}{$f1}{'y2'}
        ];
        my @f1_pos
            = @{ $self->{'feature_position'}{$slot_no}{$f1}{$cur_side} || [] }
            or next;

        my @f1_self_pos
            = @{ $self->{'feature_position'}{$slot_no}{$f1}{$self_label_side}
                || [] }
            or next;
        for my $f2 ( $self->feature_correspondences($f1) ) {
            my @same_map = ();
            my $same_ys  = [];
            if ( $self->{'feature_position'}{$slot_no}{$f2} ) {
                @same_map = @{ $self->{'feature_position'}{$slot_no}{$f2}
                        {$self_label_side} || [] };
                $same_ys = [
                    $self->{'feature_position'}{$slot_no}{$f2}{'y1'},
                    $self->{'feature_position'}{$slot_no}{$f2}{'y2'}
                ];
            }

            my @ref_pos = ();
            my $ref_ys  = [];
            if ( defined( $self->{'feature_position'}{$ref_slot_no}{$f2} ) ) {
                @ref_pos = @{ $self->{'feature_position'}{$ref_slot_no}{$f2}
                        {$ref_side} || [] };
                $ref_ys = [
                    $self->{'feature_position'}{$ref_slot_no}{$f2}{'y1'},
                    $self->{'feature_position'}{$ref_slot_no}{$f2}{'y2'}
                ];
            }

            push @return,
                {
                feature_id1 => $f1,
                feature_id2 => $f2,
                positions   => [ @f1_self_pos, @same_map ],
                feature1_ys => $f1_ys,
                feature2_ys => $same_ys,
                same_map    => 1,
                label_side  => $self->label_side($slot_no),
                line_type   => 'direct',
                }
                if @same_map;

            push @return,
                {
                feature_id1 => $f1,
                feature_id2 => $f2,
                positions   => [ @f1_pos, @ref_pos ],
                feature1_ys => $f1_ys,
                feature2_ys => $ref_ys,
                line_type   => 'direct',
                }
                if @ref_pos;
        }
        for my $f2 ( $self->intraslot_correspondences($f1) ) {
            my @same_map = @{ $self->{'feature_position'}{$slot_no}{$f2}
                    {$self_label_side} || [] };
            my $same_ys = [
                $self->{'feature_position'}{$slot_no}{$f2}{'y1'},
                $self->{'feature_position'}{$slot_no}{$f2}{'y2'}
                ]
                if (@same_map);

            my @ref_pos
                = @{ $self->{'feature_position'}{$ref_slot_no}{$f2}{$ref_side}
                    || [] };
            my $ref_ys = [
                $self->{'feature_position'}{$ref_slot_no}{$f2}{'y1'},
                $self->{'feature_position'}{$ref_slot_no}{$f2}{'y2'}
                ]
                if (@ref_pos);

            push @return,
                {
                feature_id1 => $f1,
                feature_id2 => $f2,
                positions   => [ @f1_self_pos, @same_map ],
                feature1_ys => $f1_ys,
                feature2_ys => $same_ys,
                same_map    => 1,
                label_side  => $self->label_side($slot_no),
                line_type   => 'indirect',
                }
                if @same_map;

            push @return,
                {
                feature_id1 => $f1,
                feature_id2 => $f2,
                positions   => [ @f1_pos, @ref_pos ],
                feature1_ys => $f1_ys,
                feature2_ys => $ref_ys,
                line_type   => 'indirect',
                }
                if @ref_pos;
        }
    }

    return @return;
}

# ----------------------------------------------------
sub font_size {

=pod

=head2 font_size

Returns the font size.

=cut

    my $self      = shift;
    my $font_size = shift;

    if ( $font_size && defined VALID->{'font_size'}{$font_size} ) {
        $self->{'font_size'} = $font_size;
    }

    unless ( $self->{'font_size'} ) {
        $self->{'font_size'} = $self->config_data('font_size')
            || DEFAULT->{'font_size'};
    }

    return $self->{'font_size'};
}

# ----------------------------------------------------
sub has_correspondence {

=pod

=head2 has_correspondence

Returns whether or not a feature has a correspondence.

=cut

    my $self = shift;
    my $feature_id = shift or return;
    return defined $self->{'data'}{'correspondences'}{$feature_id}
        || defined $self->{'data'}{'intraslot_correspondences'}{$feature_id};
}

# ----------------------------------------------------
sub highlight {

=pod

=head2 highlight

Gets/sets the string of highlighted features.

=cut

    my $self = shift;
    $self->{'highlight'} = shift if @_;
    return $self->{'highlight'};
}

# ----------------------------------------------------
sub highlight_feature {

=pod

=head2 highlight_feature

Gets/sets the string of highlighted features.

=cut

    my ( $self, @ids ) = @_;
    return unless @ids;

    unless ( defined $self->{'highlight_hash'} ) {
        if ( my $highlight = $self->highlight ) {

            #
            # Remove leading and trailing whitespace, convert to uppercase.
            #
            $self->{'highlight_hash'} = { map { s/^\s+|\s+$//g; ( uc $_, 1 ) }
                    parse_words($highlight) };
        }
        else {

            #
            # Define it to nothing.
            #
            $self->{'highlight_hash'} = '';
        }
    }

    return 0 unless $self->{'highlight_hash'};

    for my $id (@ids) {
        return 1 if exists $self->{'highlight_hash'}{ uc $id };
    }

    return 0;
}

# ----------------------------------------------------
sub font_class {

=pod

=head2 font_class

Returns 'GD::SVG::Font' if $self->image_type returns 'svg'; otherwise 
'GD::Font.'

=cut

    my $self = shift;
    unless ( $self->{'font_class'} ) {
        $self->{'font_class'}
            = $self->image_type eq 'svg' ? 'GD::SVG::Font' : 'GD::Font';
    }
    return $self->{'font_class'};
}

# ----------------------------------------------------
sub image_class {

=pod

=head2 image_class

Returns 'GD::SVG' if $self->image_type returns 'svg'; otherwise 'GD.'

=cut

    my $self = shift;
    unless ( $self->{'image_class'} ) {
        $self->{'image_class'}
            = $self->image_type eq 'svg' ? 'GD::SVG::Image' : 'GD::Image';
    }
    return $self->{'image_class'};
}

# ----------------------------------------------------
sub polygon_class {

=pod

=head2 polygon_class

Returns 'GD::SVG::Polygon' if $self->image_type returns 'svg'; otherwise 'GD::Polygon'.

=cut

    my $self = shift;
    unless ( $self->{'polygon_class'} ) {
        $self->{'polygon_class'}
            = $self->image_type eq 'svg' ? 'GD::SVG::Polygon' : 'GD::Polygon';
    }
    return $self->{'polygon_class'};
}

# ----------------------------------------------------
sub image_map_data {

=pod

=head2 image_map_data

Returns an array of records with the "coords" and "url" for each image map
area.

=cut

    my $self = shift;
    return @{ $self->{'image_map_data'} || [] };
}

# ----------------------------------------------------
sub image_size {

=pod

=head2 image_size

Returns the set image size.

=cut

    my $self       = shift;
    my $image_size = shift;

    if ( $image_size && VALID->{'image_size'}{$image_size} ) {
        $self->{'image_size'} = $image_size;
    }

    unless ( defined $self->{'image_size'} ) {
        $self->{'image_size'} = $self->config_data('image_size')
            || DEFAULT->{'image_size'};
    }

    return $self->{'image_size'};
}

# ----------------------------------------------------
sub image_type {

=pod

=head2 image_type

Gets/sets the current image type.

=cut

    my $self       = shift;
    my $image_type = shift;

    if ( $image_type && VALID->{'image_type'}{$image_type} ) {
        $self->{'image_type'} = $image_type;
    }

    unless ( defined $self->{'image_type'} ) {
        $self->{'image_type'} = $self->config_data('image_type')
            || DEFAULT->{'image_type'};
    }

    return $self->{'image_type'};
}

# ----------------------------------------------------
sub image_name {

=pod

=head2 image_name

Gets/sets the current image name.

=cut

    my $self = shift;

    if ( my $path = shift ) {
        return $self->error(qq[Unable to read image file "$path"])
            unless -r $path;
        my $image_name = basename($path);
        $self->{'image_name'} = $image_name;
    }

    return $self->{'image_name'} || '';
}

# ----------------------------------------------------
sub label_side {

=pod

=head2 label_side

Returns the side to place the labels based on the map number.  The only
map this would really affect is the main reference map, and only then 
when there is only one comparative map:  When the comparative map is 
on the left, put the labels on the right of the main reference map;
otherwise, always put the labels of maps 1 and greater on the right
and everything else on the left.

=cut

    my ( $self, $slot_no ) = @_;

    unless (defined( $self->{'label_side'} )
        and defined( $self->{'label_side'}{$slot_no} ) )
    {
        my $side;
        if ( $slot_no == 0 && $self->total_no_slots == 2 ) {
            my $slot_data = $self->slot_data;
            $side = defined $slot_data->{-1} ? RIGHT : LEFT;
        }
        elsif ( $slot_no == 0 && $self->total_no_slots == 1 ) {
            $side = RIGHT;
        }
        elsif ( $slot_no == 0 ) {
            my $slot_data = $self->slot_data;
            $side = defined $slot_data->{1} ? LEFT : RIGHT;
        }
        elsif ( $slot_no > 0 ) {
            $side = RIGHT;
        }
        else {
            $side = LEFT;
        }

        $self->{'label_side'}{$slot_no} = $side;
    }

    return $self->{'label_side'}{$slot_no};
}

# ----------------------------------------------------
sub map_correspondences {

=pod

=head2 map_correspondences

Returns the correspondences from a slot no to its reference slot.

=cut

    my ( $self, $slot_no, $map_id ) = @_;
    if ( defined $slot_no && $map_id ) {
        return $self->{'data'}{'map_correspondences'}{$slot_no}{$map_id};
    }
    elsif ( defined $slot_no ) {
        return $self->{'data'}{'map_correspondences'}{$slot_no};
    }
    else {
        return {};
    }
}

# ----------------------------------------------------
sub map_not_displayed {

=pod

=head2 map_not_displayed

Stores and returns whether a map has been skipped in the drawing phase.

=cut

    my ( $self, $slot_no, $map_id, $value ) = @_;
    if ( defined $slot_no and defined $map_id and $value ) {
        $self->{'data'}{'map_not_displayed'}{$slot_no}{$map_id} = $value;
        return $self->{'data'}{'map_not_displayed'}{$slot_no}{$map_id};
    }
    if ( defined $slot_no && $map_id ) {
        return $self->{'data'}{'map_not_displayed'}{$slot_no}{$map_id};
    }
    elsif ( defined $slot_no ) {
        return $self->{'data'}{'map_not_displayed'}{$slot_no};
    }
    else {
        return {};
    }
}

# ----------------------------------------------------
sub map_height {

=pod

=head2 map_height

Gets/sets the output map image's height.

=cut

    my $self = shift;
    return $self->max_y + 10;
}

# ----------------------------------------------------
sub map_width {

=pod

=head2 map_width

Gets/sets the output map image's width.

=cut

    my $self = shift;
    return $self->max_x + 10;
}

# ----------------------------------------------------
sub map_view {

=pod

=head2 map_view

Gets/sets whether we're looking at the regular viewer or details.

=cut

    my $self = shift;
    $self->{'map_view'} = shift if @_;
    return $self->{'map_view'} || 'viewer';
}

# ----------------------------------------------------
sub left_min_corrs {

=pod

=head2 left_min_corrs

Gets/sets the minimum number of correspondences for the left most slot.

=cut

    my $self = shift;
    $self->{'left_min_corrs'} = shift if @_;
    return $self->{'left_min_corrs'} || 0;
}

# ----------------------------------------------------
sub right_min_corrs {

=pod

=head2 right_min_corrs

Gets/sets the minimum number of correspondences for the right most slot.

=cut

    my $self = shift;
    $self->{'right_min_corrs'} = shift if @_;
    return $self->{'right_min_corrs'} || 0;
}

# ----------------------------------------------------
sub general_min_corrs {

=pod

=head2 general_min_corrs

Gets/sets the minimum number of correspondences for the slots that are not the
right most of the left most.

Default: undef

=cut

    my $self = shift;
    $self->{'general_min_corrs'} = shift if @_;
    return $self->{'general_min_corrs'};
}

# ----------------------------------------------------
sub menu_min_corrs {

=pod

=head2 menu_min_corrs

Gets/sets the minimum number of correspondences for the slots that to be
displayed in the menu.

Default: undef

=cut

    my $self = shift;
    $self->{'menu_min_corrs'} = shift if @_;
    return $self->{'menu_min_corrs'};
}

# ----------------------------------------------------
sub slot_min_corrs {

=pod

=head2 slot_min_corrs

Gets/sets the object that holds the minimum number of correspondences for each
slot.

Default: undef

=cut

    my $self = shift;
    $self->{'slot_min_corrs'} = shift if @_;
    return $self->{'slot_min_corrs'};
}

# ----------------------------------------------------
sub stack_slot {

=pod

=head2 stack_slot

Gets/sets the object that dicates if a slot is stacked.

Default: undef

=cut

    my $self = shift;
    $self->{'stack_slot'} = shift if @_;
    return $self->{'stack_slot'};
}

# ----------------------------------------------------
sub label_features {

=pod

=head2 label_features

Gets/sets whether to show feature labels.

=cut

    my $self = shift;

    if ( my $arg = shift ) {
        $self->error(qq[Show feature labels input "$arg" invalid])
            unless VALID->{'label_features'}{$arg};
        $self->{'label_features'} = $arg;
    }

    return $self->{'label_features'} || '';
}

# ----------------------------------------------------
sub slot_numbers {

=pod

=head2 slot_numbers

Returns the slot numbers, 0 to positive, -1 to negative.

=cut

    my $self = shift;

    #unless ( $self->{'slot_numbers'} ) {
    my @slot_nos = keys %{ $self->{'slots'} };
    my @pos      = sort { $a <=> $b } grep { $_ >= 0 } @slot_nos;
    my @neg      = sort { $b <=> $a } grep { $_ < 0 } @slot_nos;

    $self->{'slot_numbers'} = [ @pos, @neg ];

    #}

    return @{ $self->{'slot_numbers'} };
}

# ----------------------------------------------------
sub slot_data {

=pod

=head2 slot_data

Returns the data for one or all slots.

=cut

    my $self = shift;
    my $data = $self->data;

    if ( defined( my $slot_no = shift ) ) {
        return
            exists $data->{'slot_data'}{$slot_no}
            ? $data->{'slot_data'}{$slot_no}
            : undef;
    }
    else {
        return $data->{'slot_data'};
    }
}

# ----------------------------------------------------
sub slot_sides {

=pod

=head2 slot_sides

Remembers the right and left bounds of a slot.

=cut

    my ( $self, %args ) = @_;
    my $slot_no = $args{'slot_no'} || 0;
    my $right   = $args{'right'};
    my $left    = $args{'left'};

    if ( defined $right && defined $left ) {
        $self->{'slot_sides'}{$slot_no} = [ $left, $right ];
    }

    return @{ $self->{'slot_sides'}{$slot_no} || [] };
}

# ----------------------------------------------------
sub slot_title {

=pod

=head2 slot_title

Set and retrieve the slot title.

=cut

    my $self    = shift;
    my %args    = @_;
    my $slot_no = $args{'slot_no'};
    if ( $args{'bounds'} ) {
        $self->{'slot_title'}{$slot_no}{'bounds'} = $args{'bounds'};
        $self->{'slot_title'}{$slot_no}{'drawing_data'}
            = $args{'drawing_data'};
        $self->{'slot_title'}{$slot_no}{'map_area_data'}
            = $args{'map_area_data'};
    }
    return $self->{'slot_title'}{$slot_no};
}

# ----------------------------------------------------
sub slots {

=pod

=head2 slots

Gets/sets what's in the "slots" (the maps in each position).
And Checks the slot bounds

=cut

    my $self = shift;
    if (@_) {
        $self->{'slots'} = shift;
    }

    return $self->{'slots'};
}

# ----------------------------------------------------
sub max_x {

=pod

=head2 max_x

Gets/sets the maximum x-coordinate.

=cut

    my $self = shift;

    if ( my @args = sort { $a <=> $b } @_ ) {
        $self->{'max_x'} = $args[-1] unless defined $self->{'max_x'};
        $self->{'max_x'} = $args[-1] if $args[-1] > $self->{'max_x'};
    }

    return $self->{'max_x'} || 0;
}

# ----------------------------------------------------
sub max_y {

=pod

=head2 max_y

Gets/sets the maximum x-coordinate.

=cut

    my $self = shift;

    if ( my @args = sort { $a <=> $b } @_ ) {
        $self->{'max_y'} = $args[-1] unless defined $self->{'max_y'};
        $self->{'max_y'} = $args[-1] if $args[-1] > $self->{'max_y'};
    }

    return $self->{'max_y'} || 0;
}

# ----------------------------------------------------
sub min_x {

=pod

=head2 min_x

Gets/sets the minimum x-coordinate.

=cut

    my $self = shift;

    if ( my @args = sort { $a <=> $b } @_ ) {
        $self->{'min_x'} = $args[0] unless defined $self->{'min_x'};
        $self->{'min_x'} = $args[0] if $args[0] < $self->{'min_x'};
    }

    return $self->{'min_x'} || 0;
}

# ----------------------------------------------------
sub min_y {

=pod

=head2 min_y

Gets/sets the minimum x-coordinate.

=cut

    my $self = shift;

    if ( my @args = sort { $a <=> $b } @_ ) {
        $self->{'min_y'} = $args[0] unless defined $self->{'min_y'};
        $self->{'min_y'} = $args[0] if $args[0] < $self->{'min_y'};
    }

    return $self->{'min_y'} || 0;
}

# ----------------------------------------------------
sub pixel_height {

=pod

=head2 pixel_height

Returns the pixel height of the image based upon the requested "image_size."

=cut

    my $self = shift;
    my $arg  = shift;

    if ($arg) {
        $self->{'pixel_height'} = $arg;
    }

    unless ( $self->{'pixel_height'} ) {
        my $image_size = $self->image_size;
        $self->{'pixel_height'} = VALID->{'image_size'}{$image_size}
            or $self->error("Can't figure out pixel height");
    }

    return $self->{'pixel_height'};
}

# ----------------------------------------------------
sub reference_slot_no {

=pod

=head2 reference_slot_no

Returns the reference slot number for a given slot number.

=cut

    my ( $self, $slot_no ) = @_;
    return unless defined $slot_no;

    my $ref_slot_no
        = $slot_no > 0 ? $slot_no - 1
        : $slot_no < 0 ? $slot_no + 1
        :                undef;
    return undef unless defined $ref_slot_no;

    my $slot_data = $self->slot_data;
    return defined $slot_data->{$ref_slot_no} ? $ref_slot_no : undef;
}

# ----------------------------------------------------
sub register_feature_type {

=pod

=head2 register_feature_type

Remembers a feature type.

=cut

    my ( $self, @feature_type_ids ) = @_;
    $self->{'data'}{'feature_types'}{$_}{'seen'} = 1 for @feature_type_ids;
}

# ----------------------------------------------------
sub register_feature_position {

=pod

=head2 register_feature_position

Remembers the feature position on a map.

=cut

    my ( $self, %args ) = @_;
    my $feature_id = $args{'feature_id'} or return;
    my $slot_no = $args{'slot_no'};
    return unless defined $slot_no;

    $self->{'feature_position'}{$slot_no}{$feature_id} = {
        left   => $args{'left'},
        right  => $args{'right'},
        y1     => $args{'y1'},
        y2     => $args{'y2'},
        tick_y => $args{'tick_y'},
        map_id => $args{'map_id'},
    };
}

# ----------------------------------------------------
sub register_map_coords {

=pod

=head2 register_map_coords

Returns the font for the "regular" stuff (feature labels, map names, etc.).

=cut

    my ($self, $slot_no, $map_id, $start, $stop,
        $x1,   $y1,      $x2,     $y2,    $is_flipped
    ) = @_;
    $self->{'map_coords'}{$slot_no}{$map_id} = {
        map_start  => $start,
        map_stop   => $stop,
        y1         => $y1,
        y2         => $y2,
        x1         => $x1,
        x2         => $x2,
        is_flipped => $is_flipped,
    };
}

# ----------------------------------------------------
sub reference_map_coords {

=pod

=head2 reference_map_coords

Returns top and bottom y coordinates of the reference map for a given 
slot and map id.

=cut

    my ( $self, $slot_no, $map_id ) = @_;

    #
    # The correspondence record contains the min and max start
    # positions from this slot to
    #
    if ( defined $slot_no && $map_id ) {
        return $self->{'map_coords'}{$slot_no}{$map_id};
    }
    else {
        return {};
    }
}

# ----------------------------------------------------
sub regular_font {

=pod

=head2 regular_font

Returns the font for the "regular" stuff (feature labels, map names, etc.).

=cut

    my $self = shift;
    unless ( $self->{'regular_font'} ) {
        my $font_size = $self->font_size;
        my $font_pkg  = $self->font_class or return;
        my %methods   = (
            small  => 'Tiny',
            medium => 'Small',
            large  => 'Large',
        );

        if ( my $font = $methods{$font_size} ) {
            $self->{'regular_font'} = $font_pkg->$font()
                or return $self->error(
                "Error creating font with package '$font_pkg'");
        }
        else {
            return $self->error(qq[No "regular" font for "$font_size"]);
        }
    }

    return $self->{'regular_font'};
}

# ----------------------------------------------------
sub tick_y_positions {

=pod

=head2 tick_y_positions

Returns the "tick_y" positions of the features IDs in a given slot.

=cut

    my ( $self, %args ) = @_;
    my $slot_no     = $args{'slot_no'};
    my $feature_ids = $args{'feature_ids'};

    return unless defined $slot_no && @$feature_ids;

    push @$feature_ids, $self->feature_correspondences($feature_ids);

    my @return = ();
    for my $feature_id (@$feature_ids) {
        push @return,
            $self->{'feature_position'}{$slot_no}{$feature_id}{'tick_y'}
            || ();
    }

    return @return;
}

# ----------------------------------------------------
sub total_no_slots {

=pod

=head2 total_no_slots

Returns the number of slots.

=cut

    my $self = shift;
    return scalar keys %{ $self->slot_data };
}

# ----------------------------------------------------
sub aggregated_correspondence_colors {

=pod

=head2 aggregated_correspondence_colors

Returns the correspondence colors specified in the config file for 
that evidence type.  Defaults to the 'aggregated_correspondence_colors'
that is defined in the main section.

=cut

    my $self              = shift;
    my $evidence_type_acc = shift;

    return $self->{'corr_colors'}
        unless ($evidence_type_acc);

    unless ($self->{'corr_colors'}
        and $self->{'corr_colors'}{$evidence_type_acc} )
    {
        unless (
            $self->{'corr_colors'}{$evidence_type_acc}
            = $self->evidence_type_data(
                $evidence_type_acc, 'aggregated_correspondence_colors'
            )
            )
        {
            $self->{'corr_colors'}{$evidence_type_acc}
                = $self->config_data('aggregated_correspondence_colors');
        }
    }

    return $self->{'corr_colors'}{$evidence_type_acc};
}

# ----------------------------------------------------
sub default_aggregated_correspondence_color {

=pod

=head2 default_aggregated_correspondence_color

Returns the correspondence colors specified as the default or 
the value in Constants.pm for aggregated_correspondence_color.

=cut

    my $self              = shift;
    my $evidence_type_acc = shift;

    $evidence_type_acc = DEFAULT->{'aggregated_type_substitute'}
        unless ($evidence_type_acc);

    unless ($self->{'default_corr_color'}
        and $self->{'default_corr_color'}{$evidence_type_acc} )
    {
        my $corr_colors
            = $self->aggregated_correspondence_colors($evidence_type_acc);
        if ( $corr_colors and %$corr_colors ) {
            $self->{'default_corr_color'}{$evidence_type_acc}
                = $corr_colors->{0};
        }
        unless ( $self->{'default_corr_color'}{$evidence_type_acc} ) {
            $self->{'default_corr_color'}{$evidence_type_acc}
                = DEFAULT->{'connecting_line_color'};
        }
    }

    return $self->{'default_corr_color'}{$evidence_type_acc};
}

# ----------------------------------------------------
sub aggregated_line_color {

=pod

=head2 aggregated_line_color

Given the evidence type and the number of correspondences, 
return the correct line color for the aggregated correspondences.

=cut

    my ( $self, %args ) = @_;
    my $evidence_type_acc = $args{'evidence_type_acc'};
    my $corr_no           = $args{'corr_no'};

    my $corr_colors
        = $self->aggregated_correspondence_colors($evidence_type_acc);
    my $line_color
        = $self->default_aggregated_correspondence_color($evidence_type_acc);
    foreach
        my $color_bound ( sort { $a <=> $b } grep {$_} keys(%$corr_colors) )
    {
        if ( $corr_no <= $color_bound ) {
            $line_color = $corr_colors->{$color_bound};
            last;
        }
    }
    return $line_color;
}

# ----------------------------------------

=pod

=head2 offset_drawing_data

Add the topper to the map.

=cut

sub offset_drawing_data {

    my ( $self, %args ) = @_;
    my $offset_x = $args{'offset_x'} || 0;
    my $offset_y = $args{'offset_y'} || 0;
    my $drawing_data = $args{'drawing_data'};

    for ( my $i = 0; $i <= $#{$drawing_data}; $i++ ) {
        if (   $drawing_data->[$i][0] eq STRING_UP
            or $drawing_data->[$i][0] eq STRING )
        {
            $drawing_data->[$i][2] += $offset_x;
            $drawing_data->[$i][3] += $offset_y;
        }
        elsif ($drawing_data->[$i][0] eq FILL
            or $drawing_data->[$i][0] eq ARC
            or $drawing_data->[$i][0] eq FILL_TO_BORDER )
        {
            $drawing_data->[$i][1] += $offset_x;
            $drawing_data->[$i][2] += $offset_y;
        }
        elsif ($drawing_data->[$i][0] eq LINE
            or $drawing_data->[$i][0] eq FILLED_RECT
            or $drawing_data->[$i][0] eq RECTANGLE )
        {
            $drawing_data->[$i][1] += $offset_x;
            $drawing_data->[$i][3] += $offset_x;
            $drawing_data->[$i][2] += $offset_y;
            $drawing_data->[$i][4] += $offset_y;
        }
        else {
            die $drawing_data->[$i][0]
                . " not caught in offset.  Inform developer\n";
        }
    }
}

# ----------------------------------------

=pod

=head2 offset_map_area_data

=cut

sub offset_map_area_data {

    my ( $self, %args ) = @_;
    my $offset_x = $args{'offset_x'} || 0;
    my $offset_y = $args{'offset_y'} || 0;
    my $map_area_data = $args{'map_area_data'};

    for ( my $i = 0; $i <= $#{$map_area_data}; $i++ ) {
        $map_area_data->[$i]{'coords'}[0] += $offset_x;
        $map_area_data->[$i]{'coords'}[2] += $offset_x;
        $map_area_data->[$i]{'coords'}[1] += $offset_y;
        $map_area_data->[$i]{'coords'}[3] += $offset_y;
    }
}

# -----------------------------------------
sub modify_min_corrs {

=pod

=head2 modify_min_corrs

Modify the left and right min_corrs to reflect the actual min corrs of the
outer slots.  This is to mainly to change the values when a slot is deleted and
the new outer slot has a different min_corrs value.

=cut

    my $self  = shift;
    my $slots = shift;

    # Modify the left and right min corrs
    my @slot_nos  = sort { $a <=> $b } keys(%$slots);
    my $max_right = $slot_nos[-1];
    my $max_left  = $slot_nos[0];

    $self->left_min_corrs( $slots->{$max_left}{'min_corrs'}   || 0 );
    $self->right_min_corrs( $slots->{$max_right}{'min_corrs'} || 0 );

}

sub create_minimal_link_params {

=pod

=head2 create_minimal_link_params

Creates only the link parameters for CMap->create_viewer_link() that are
absolutely needed.

=cut

    my ( $self, %args ) = @_;

    return (
        session_id  => $self->session_id(),
        data_source => $self->data_source(),
        next_step   => $self->next_step(),
    );
}

# ----------------------------------------------------
sub create_link_params {

=pod

=head2 create_link_params

Creates default link parameters for CMap->create_viewer_link()

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
    my $comp_menu_order             = $args{'comp_menu_order'};
    my $show_intraslot_corr         = $args{'show_intraslot_corr'};
    my $split_agg_ev                = $args{'split_agg_ev'};
    my $clean_view                  = $args{'clean_view'};
    my $hide_legend                 = $args{'hide_legend'};
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
    my $session_id                  = $args{'session_id'};
    my $next_step                   = $args{'next_step'};
    my $session_mod                 = $args{'session_mod'};
    my $new_session                 = $args{'new_session'};
    my $included_evidence_type_accs = $args{'included_evidence_type_accs'};
    my $ignored_evidence_type_accs  = $args{'ignored_evidence_type_accs'};
    my $less_evidence_type_accs     = $args{'less_evidence_type_accs'};
    my $greater_evidence_type_accs  = $args{'greater_evidence_type_accs'};
    my $evidence_type_score         = $args{'evidence_type_score'};
    my $data_source                 = $args{'data_source'};
    my $url                         = $args{'url'};
    my $refMenu                     = $args{'refMenu'};
    my $compMenu                    = $args{'compMenu'};
    my $optionMenu                  = $args{'optionMenu'};
    my $addOpMenu                   = $args{'addOpMenu'};
    my $dotplot                     = $args{'dotplot'};
    my $skip_map_info               = $args{'skip_map_info'};
    my $create_legacy_url           = $args{'create_legacy_url'};

    my $slots = $self->slots();

    unless ( defined($session_id) ) {
        $session_id = $self->session_id();
    }
    ### Required Fields that Drawer can't figure out.
    unless ( $skip_map_info
        or $create_legacy_url
        or $session_id
        or ( defined($ref_map_set_acc) and $new_session ) )
    {
        return;
    }

    # Only create this info if we are creating a full legacy url
    # that doesn't use sessions.
    if ($create_legacy_url) {
        unless ( defined($comparative_maps) ) {
            for my $slot_no ( keys %{$slots} ) {
                next unless ($slot_no);
                $comparative_maps->{$slot_no} = $slots->{$slot_no};
            }
        }
        unless ( defined($ref_map_accs) ) {
            $ref_map_accs = $slots->{0}{'maps'};
        }
    }

    ### Optional fields for finer control
    # I know that undeffing undefined variables is redundant
    # But they are nice placeholders.
    unless ( defined($prev_ref_species_acc) ) {
        $prev_ref_species_acc = undef;
    }
    unless ( defined($prev_ref_map_set_acc) ) {
        $prev_ref_map_set_acc = undef;
    }
    unless ( defined($ref_species_acc) ) {
        $ref_species_acc = undef;
    }
    unless ( defined($ref_map_start) ) {
        $ref_map_start = undef;
    }
    unless ( defined($ref_map_stop) ) {
        $ref_map_stop = undef;
    }
    unless ( defined($highlight) ) {
        $highlight = $self->highlight();
    }
    unless ( defined($font_size) ) {
        $font_size = $self->font_size();
    }
    unless ( defined($pixel_height) ) {
        $pixel_height = $self->pixel_height();
    }
    unless ( defined($image_type) ) {
        $image_type = $self->image_type();
    }
    unless ( defined($label_features) ) {
        $label_features = $self->label_features();
    }
    unless ( defined($collapse_features) ) {
        $collapse_features = $self->collapse_features();
    }
    unless ( defined($aggregate) ) {
        $aggregate = $self->aggregate();
    }
    unless ( defined($scale_maps) ) {
        $scale_maps = $self->scale_maps();
    }
    unless ( defined($stack_maps) ) {
        $stack_maps = $self->stack_maps();
    }
    unless ( defined($omit_area_boxes) ) {
        $omit_area_boxes = $self->omit_area_boxes();
    }
    unless ( defined($comp_menu_order) ) {
        $comp_menu_order = $self->comp_menu_order();
    }
    unless ( defined($ref_map_order) ) {
        $ref_map_order = $self->ref_map_order();
    }
    unless ( defined($show_intraslot_corr) ) {
        $show_intraslot_corr = $self->show_intraslot_corr();
    }
    unless ( defined($split_agg_ev) ) {
        $split_agg_ev = $self->split_agg_ev();
    }
    unless ( defined($clean_view) ) {
        $clean_view = $self->clean_view();
    }
    unless ( defined($hide_legend) ) {
        $hide_legend = $self->hide_legend();
    }
    unless ( defined($corrs_to_map) ) {
        $corrs_to_map = $self->corrs_to_map();
    }
    unless ( defined($ignore_image_map_sanity) ) {
        $ignore_image_map_sanity = $self->ignore_image_map_sanity();
    }
    unless ( defined($flip) ) {
        my @flips;
        for my $rec ( @{ $self->flip } ) {
            push @flips, $rec->{'slot_no'} . '%3d' . $rec->{'map_acc'};
        }
        $flip = join( ":", @flips );
    }
    unless ( defined($left_min_corrs) ) {
        $left_min_corrs = $self->left_min_corrs();
    }
    unless ( defined($right_min_corrs) ) {
        $right_min_corrs = $self->right_min_corrs();
    }
    unless ( defined($general_min_corrs) ) {
        $general_min_corrs = $self->general_min_corrs();
    }
    unless ( defined($menu_min_corrs) ) {
        $menu_min_corrs = $self->menu_min_corrs();
    }
    unless ( defined($slot_min_corrs) ) {
        $slot_min_corrs = $self->slot_min_corrs();
    }
    unless ( defined($stack_slot) ) {
        $stack_slot = $self->stack_slot();
    }
    unless ( defined($feature_type_accs) ) {
        $feature_type_accs = $self->included_feature_types();
    }
    unless ( defined($corr_only_feature_type_accs) ) {
        $corr_only_feature_type_accs = $self->corr_only_feature_types();
    }
    unless ( defined($url_feature_default_display) ) {
        $url_feature_default_display = $self->url_feature_default_display();
    }
    unless ( defined($ignored_feature_type_accs) ) {
        $ignored_feature_type_accs = $self->ignored_feature_types();
    }
    unless ( defined($ignored_evidence_type_accs) ) {
        $ignored_evidence_type_accs = $self->ignored_evidence_types();
    }
    unless ( defined($included_evidence_type_accs) ) {
        $included_evidence_type_accs = $self->included_evidence_types();
    }
    unless ( defined($less_evidence_type_accs) ) {
        $less_evidence_type_accs = $self->less_evidence_types();
    }
    unless ( defined($greater_evidence_type_accs) ) {
        $greater_evidence_type_accs = $self->greater_evidence_types();
    }
    unless ( defined($evidence_type_score) ) {
        $evidence_type_score = $self->evidence_type_score();
    }
    unless ( defined($data_source) ) {
        $data_source = $self->data_source();
    }
    unless ( defined($url) ) {
        $url = '';
    }
    unless ( defined($session_id) ) {
        $session_id = $self->session_id();
    }
    unless ( defined($next_step) ) {
        $next_step = $self->next_step();
    }
    unless ( defined($refMenu) ) {
        $refMenu = $self->refMenu();
    }
    unless ( defined($compMenu) ) {
        $compMenu = $self->compMenu();
    }
    unless ( defined($optionMenu) ) {
        $optionMenu = $self->optionMenu();
    }
    unless ( defined($addOpMenu) ) {
        $addOpMenu = $self->addOpMenu();
    }
    unless ( defined($dotplot) ) {
        $dotplot = $self->dotplot();
    }

    return (
        prev_ref_species_acc        => $prev_ref_species_acc,
        prev_ref_map_set_acc        => $prev_ref_map_set_acc,
        ref_species_acc             => $ref_species_acc,
        ref_map_set_acc             => $ref_map_set_acc,
        ref_map_start               => $ref_map_start,
        ref_map_stop                => $ref_map_stop,
        comparative_maps            => $comparative_maps,
        highlight                   => $highlight,
        font_size                   => $font_size,
        pixel_height                => $pixel_height,
        image_type                  => $image_type,
        label_features              => $label_features,
        collapse_features           => $collapse_features,
        aggregate                   => $aggregate,
        scale_maps                  => $scale_maps,
        stack_maps                  => $stack_maps,
        omit_area_boxes             => $omit_area_boxes,
        ref_map_order               => $ref_map_order,
        comp_menu_order             => $comp_menu_order,
        show_intraslot_corr         => $show_intraslot_corr,
        split_agg_ev                => $split_agg_ev,
        clean_view                  => $clean_view,
        hide_legend                 => $hide_legend,
        corrs_to_map                => $corrs_to_map,
        ignore_image_map_sanity     => $ignore_image_map_sanity,
        flip                        => $flip,
        left_min_corrs              => $left_min_corrs,
        right_min_corrs             => $right_min_corrs,
        general_min_corrs           => $general_min_corrs,
        menu_min_corrs              => $menu_min_corrs,
        slot_min_corrs              => $slot_min_corrs,
        stack_slot                  => $stack_slot,
        ref_map_accs                => $ref_map_accs,
        feature_type_accs           => $feature_type_accs,
        corr_only_feature_type_accs => $corr_only_feature_type_accs,
        ignored_feature_type_accs   => $ignored_feature_type_accs,
        url_feature_default_display => $url_feature_default_display,
        ignored_evidence_type_accs  => $ignored_evidence_type_accs,
        included_evidence_type_accs => $included_evidence_type_accs,
        less_evidence_type_accs     => $less_evidence_type_accs,
        greater_evidence_type_accs  => $greater_evidence_type_accs,
        evidence_type_score         => $evidence_type_score,
        data_source                 => $data_source,
        url                         => $url,
        session_id                  => $session_id,
        next_step                   => $next_step,
        refMenu                     => $refMenu,
        compMenu                    => $compMenu,
        optionMenu                  => $optionMenu,
        addOpMenu                   => $addOpMenu,
        dotplot                     => $dotplot,
        session_mod                 => $session_mod,
        new_session                 => $new_session,
        skip_map_info               => $skip_map_info,
    );
}

# ----------------------------------------------------
sub define_color {

=pod

=head2 message

Message to be printed out on top of the image.

=cut

    my $self = shift;
    my $rgb_array_ref = shift or return;

    my $color_key = join( '_', @{ $rgb_array_ref || [] } ) or return;
    $self->{'custom_colors'}{$color_key} = $rgb_array_ref;

    return $color_key;
}

# ----------------------------------------------------
sub message {

=pod

=head2 message

Message to be printed out on top of the image.

=cut

    my $self = shift;
    my $msg  = shift;

    if ($msg) {
        $self->{'message'} = $msg;
    }

    return $self->{'message'};
}

1;

# ----------------------------------------------------
# It is not all books that are as dull as their readers.
# Henry David Thoreau
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>, L<GD>, L<GD::SVG>.

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

