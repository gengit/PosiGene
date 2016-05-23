package Bio::GMOD::CMap::Drawer::Map;

# vim: set ft=perl:

# $Id: Map.pm,v 1.212 2008/02/28 17:12:58 mwz444 Exp $

=pod

=head1 NAME

Bio::GMOD::CMap::Drawer::Map - draw a map

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Drawer::Map;

=head1 DESCRIPTION

You will never directly use this module.

=head1 METHODS

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.212 $)[-1];

use URI::Escape;
use Data::Dumper;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Utils qw[
    even_label_distribution
    simple_column_distribution
    commify
    presentable_number
    longest_run
];
use Bio::GMOD::CMap::Drawer::Glyph;
use base 'Bio::GMOD::CMap';

my @INIT_FIELDS = qw[ drawer base_x base_y slot_no maps config aggregate
    clean_view scale_maps stack_maps ];

my %SHAPE = (
    'default'  => 'draw_box',
    'box'      => 'draw_box',
    'dumbbell' => 'draw_dumbbell',
    'I-beam'   => 'draw_i_beam',
);

BEGIN {

    #
    # Create automatic accessor methods.
    #
    my @AUTO_FIELDS = qw[
        map_set_id map_set_acc map_type map_acc species_id
        map_id species_common_name map_units map_name map_set_name
        map_type_id is_relational_map begin end species_acc map_type_acc
        map_set_short_name
    ];

    foreach my $sub_name (@AUTO_FIELDS) {
        no strict 'refs';
        unless ( defined &$sub_name ) {
            *{$sub_name} = sub {
                my $self   = shift;
                my $map_id = shift;
                return $self->{'maps'}{$map_id}{$sub_name};
            };
        }
    }
}

# ----------------------------------------------------
sub init {
    my ( $self, $config ) = @_;
    $self->params( $config, @INIT_FIELDS );
    return $self;
}

# ----------------------------------------------------
sub base_x {

=pod

=head2 base_x

Figure out where right-to-left this map belongs.

=cut

    my $self    = shift;
    my $slot_no = $self->slot_no;
    my $drawer  = $self->drawer;
    my $buffer  = 15;

    my $base_x;
    if ( $slot_no < 0
        || ( $slot_no == 0 && $drawer->label_side($slot_no) eq LEFT ) )
    {
        $base_x = $drawer->min_x - $buffer;
    }
    else {
        $base_x = $drawer->max_x + $buffer;
    }

    return $base_x;
}

# ----------------------------------------------------
sub base_y {

=pod

=head2 base_y

Return the base y coordinate.

=cut

    my $self = shift;
    return $self->{'base_y'} || 0;
}

# ----------------------------------------------------
sub map_color {

=pod

=head2 color

Returns the color of the map.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map($map_id);
    return $map->{'color'}
        || $map->{'default_color'}
        || $self->config_data('map_color');
}

# ----------------------------------------------------
sub drawer {

=pod

=head2 drawer

Returns the Bio::GMOD::CMap::Drawer object.

=cut

    my $self = shift;
    return $self->{'drawer'};
}

# ----------------------------------------------------
sub draw_box {

=pod

=head2 draw_box

Draws the map as a "box" (a filled-in rectangle).  Return the bounds of the
box.

=cut

    my ( $self, %args ) = @_;
    my $drawing_data  = $args{'drawing_data'};
    my $map_area_data = $args{'map_area_data'};
    my $map_coords    = $args{'map_coords'};
    my $drawer        = $args{'drawer'} || $self->drawer
        or $self->error('No drawer');
    my ( $x1, $y1, $y2 ) = @{ $args{'coords'} || [] }
        or $self->error('No coordinates');
    my $map_id              = $args{'map_id'};
    my $map_acc             = $self->map_acc($map_id);
    my $is_compressed       = $args{'is_compressed'};
    my $is_flipped          = $args{'is_flipped'};
    my $slot_no             = $args{'slot_no'};
    my $color               = $self->map_color($map_id);
    my $width               = $self->map_width($map_id);
    my $x2                  = $x1 + $width;
    my $x_mid               = $x1 + ( $width / 2 );
    my @coords              = ( $x1, $y1, $x2, $y2 );
    my $omit_all_area_boxes = ( $drawer->omit_area_boxes >= 2 );
    $map_coords->[0] = $x1 if ( $map_coords->[0] > $x1 );
    $map_coords->[2] = $x2 if ( $map_coords->[2] < $x2 );

    my $truncated = $drawer->data_module->truncatedMap( $slot_no, $map_id );
    if (   ( $truncated >= 2 and $is_flipped )
        or ( ( $truncated == 1 or $truncated == 3 ) and not $is_flipped ) )
    {
        $self->draw_truncation_arrows(
            is_up         => 1,
            map_coords    => $map_coords,
            coords        => \@coords,
            drawer        => $drawer,
            map_area_data => $map_area_data,
            drawing_data  => $drawing_data,
            is_flipped    => $is_flipped,
            map_id        => $map_id,
            map_acc       => $map_acc,
            slot_no       => $slot_no,
        );
    }

    push @$drawing_data, [ FILLED_RECT, @$map_coords, $color ];
    push @$drawing_data, [ RECTANGLE,   @$map_coords, 'black' ];
    unless ($omit_all_area_boxes) {
        my $map     = $self->map($map_id);
        my $buttons = $self->create_buttons(
            map_id     => $map_id,
            drawer     => $drawer,
            slot_no    => $slot_no,
            is_flipped => $is_flipped,
            buttons    => [ 'map_detail', ],
        );
        my $url  = $buttons->[0]{'url'};
        my $alt  = $buttons->[0]{'alt'};
        my $code = '';
        eval $self->map_type_data( $map->{'map_type_acc'}, 'area_code' );
        push @{$map_area_data},
            {
            coords => [
                $map_coords->[0], $map_coords->[1],
                $map_coords->[2], $map_coords->[3]
            ],
            url  => $url,
            alt  => $alt,
            code => $code,
            };
    }

    if (   ( $truncated >= 2 and not $is_flipped )
        or ( ( $truncated == 1 or $truncated == 3 ) and $is_flipped ) )
    {
        $self->draw_truncation_arrows(
            is_up         => 0,
            map_coords    => $map_coords,
            coords        => \@coords,
            drawer        => $drawer,
            map_area_data => $map_area_data,
            drawing_data  => $drawing_data,
            is_flipped    => $is_flipped,
            map_id        => $map_id,
            map_acc       => $map_acc,
            slot_no       => $slot_no,
        );
    }

    if ( my $map_units = $args{'map_units'} ) {
        $self->draw_map_bottom(
            map_id        => $map_id,
            slot_no       => $slot_no,
            map_x1        => $map_coords->[0],
            map_x2        => $map_coords->[2],
            map_y2        => $map_coords->[3],
            drawer        => $drawer,
            drawing_data  => $drawing_data,
            map_area_data => $map_area_data,
            map_units     => $map_units,
            is_compressed => $is_compressed,
            bounds        => \@coords,
        );
    }

    return ( \@coords, $map_coords );
}

# ----------------------------------------------------
sub draw_dumbbell {

=pod

=head2 draw_dumbbell

Draws the map as a "dumbbell" (a line with circles on the ends).  Return the
bounds of the image.

=cut

    my ( $self, %args ) = @_;
    my $drawing_data  = $args{'drawing_data'};
    my $map_area_data = $args{'map_area_data'};
    my $map_coords    = $args{'map_coords'};
    my $drawer        = $args{'drawer'} || $self->drawer
        or $self->error('No drawer');
    my ( $x1, $y1, $y2 ) = @{ $args{'coords'} || [] }
        or $self->error('No coordinates');
    my $map_id              = $args{'map_id'};
    my $is_compressed       = $args{'is_compressed'};
    my $is_flipped          = $args{'is_flipped'};
    my $slot_no             = $args{'slot_no'};
    my $map_acc             = $self->map_acc($map_id);
    my $color               = $self->map_color($map_id);
    my $width               = $self->map_width($map_id);
    my $x2                  = $x1 + $width;
    my $mid_x               = $x1 + $width / 2;
    my $arc_width           = $width + 6;
    my $omit_all_area_boxes = ( $drawer->omit_area_boxes >= 2 );

    my $drew_bells = 0;
    my @coords = ( $x1, $y1, $x2, $y2 );
    $map_coords->[0] = $x1 if ( $map_coords->[0] > $x1 );
    $map_coords->[2] = $x2 if ( $map_coords->[2] < $x2 );
    my $truncated = $drawer->data_module->truncatedMap( $slot_no, $map_id );
    if (   ( $truncated >= 2 and $is_flipped )
        or ( ( $truncated == 1 or $truncated == 3 ) and not $is_flipped ) )
    {
        $self->draw_truncation_arrows(
            is_up         => 1,
            map_coords    => $map_coords,
            coords        => \@coords,
            drawer        => $drawer,
            map_area_data => $map_area_data,
            drawing_data  => $drawing_data,
            is_flipped    => $is_flipped,
            map_id        => $map_id,
            map_acc       => $map_acc,
            slot_no       => $slot_no,
        );
    }
    else {
        push @$drawing_data,
            [
            ARC,        $mid_x, $map_coords->[1], $arc_width,
            $arc_width, 0,      360,              $color
            ];
        push @$drawing_data,
            [ FILL_TO_BORDER, $mid_x, $map_coords->[1], $color, $color ];
        $drew_bells = 1;
    }
    if (   ( $truncated >= 2 and not $is_flipped )
        or ( ( $truncated == 1 or $truncated == 3 ) and $is_flipped ) )
    {
        $self->draw_truncation_arrows(
            is_up         => 0,
            map_coords    => $map_coords,
            coords        => \@coords,
            drawer        => $drawer,
            map_area_data => $map_area_data,
            drawing_data  => $drawing_data,
            is_flipped    => $is_flipped,
            map_id        => $map_id,
            map_acc       => $map_acc,
            slot_no       => $slot_no,
        );
    }
    else {
        push @$drawing_data,
            [
            ARC,        $mid_x, $map_coords->[3], $arc_width,
            $arc_width, 0,      360,              $color
            ];
        push @$drawing_data,
            [ FILL_TO_BORDER, $mid_x, $map_coords->[3], $color, $color ];
        $drew_bells = 1;
    }
    push @$drawing_data,
        [
        FILLED_RECT,      $map_coords->[0], $map_coords->[1],
        $map_coords->[2], $map_coords->[3], $color
        ];

    unless ($omit_all_area_boxes) {
        my $map     = $self->map($map_id);
        my $buttons = $self->create_buttons(
            map_id     => $map_id,
            drawer     => $drawer,
            slot_no    => $slot_no,
            is_flipped => $is_flipped,
            buttons    => [ 'map_detail', ],
        );
        my $url  = $buttons->[0]{'url'};
        my $alt  = $buttons->[0]{'alt'};
        my $code = '';
        eval $self->map_type_data( $map->{'map_type_acc'}, 'area_code' );
        push @{$map_area_data},
            {
            coords => [
                $map_coords->[0], $map_coords->[1],
                $map_coords->[2], $map_coords->[3]
            ],
            url  => $url,
            alt  => $alt,
            code => $code,
            };
    }

    if ( my $map_units = $args{'map_units'} ) {
        $self->draw_map_bottom(
            map_id        => $map_id,
            slot_no       => $slot_no,
            map_x1        => $map_coords->[0],
            map_x2        => $map_coords->[2],
            map_y2        => $map_coords->[3],
            drawer        => $drawer,
            drawing_data  => $drawing_data,
            map_area_data => $map_area_data,
            map_units     => $map_units,
            is_compressed => $is_compressed,
            bounds        => \@coords,
        );
    }
    if ($drew_bells) {
        $coords[0] = $mid_x - $arc_width / 2
            if ( $coords[0] > $mid_x - $arc_width / 2 );
        $coords[1] = $map_coords->[1] - $arc_width / 2
            if ( $coords[1] > $map_coords->[1] - $arc_width / 2 );
        $coords[2] = $mid_x + $arc_width / 2
            if ( $coords[2] < $mid_x + $arc_width / 2 );
        $coords[3] = $map_coords->[3] + $arc_width / 2
            if ( $coords[3] < $map_coords->[3] + $arc_width / 2 );
    }
    return ( \@coords, $map_coords );
}

# ----------------------------------------------------
sub draw_i_beam {

=pod

=head2 draw_i_beam

Draws the map as an "I-beam."  Return the bounds of the image.

=cut

    my ( $self, %args ) = @_;
    my $drawing_data  = $args{'drawing_data'};
    my $map_area_data = $args{'map_area_data'};
    my $map_coords    = $args{'map_coords'};
    my $drawer        = $args{'drawer'} || $self->drawer
        or $self->error('No drawer');
    my ( $x1, $y1, $y2 ) = @{ $args{'coords'} || [] }
        or $self->error('No coordinates');
    my $map_id              = $args{'map_id'};
    my $is_compressed       = $args{'is_compressed'};
    my $is_flipped          = $args{'is_flipped'};
    my $slot_no             = $args{'slot_no'};
    my $map_acc             = $self->map_acc($map_id);
    my $omit_all_area_boxes = ( $drawer->omit_area_boxes >= 2 );
    my $color               = $self->map_color($map_id);
    my $width               = $self->map_width($map_id);
    my $x2                  = $x1 + $width;
    my $x                   = $x1 + $width / 2;

    my @coords = ( $x1, $y1, $x2, $y2 );
    $map_coords->[0] = $x1 if ( $map_coords->[0] > $x1 );
    $map_coords->[2] = $x2 if ( $map_coords->[2] < $x2 );
    my $truncated = $drawer->data_module->truncatedMap( $slot_no, $map_id );
    if (   ( $truncated >= 2 and $is_flipped )
        or ( ( $truncated == 1 or $truncated == 3 ) and not $is_flipped ) )
    {
        $self->draw_truncation_arrows(
            is_up         => 1,
            map_coords    => $map_coords,
            coords        => \@coords,
            drawer        => $drawer,
            map_area_data => $map_area_data,
            drawing_data  => $drawing_data,
            is_flipped    => $is_flipped,
            map_id        => $map_id,
            map_acc       => $map_acc,
            slot_no       => $slot_no,
        );
    }
    else {
        push @$drawing_data,
            [
            LINE,             $map_coords->[0], $map_coords->[1],
            $map_coords->[2], $map_coords->[1], $color
            ];
    }
    if (   ( $truncated >= 2 and not $is_flipped )
        or ( ( $truncated == 1 or $truncated == 3 ) and $is_flipped ) )
    {
        $self->draw_truncation_arrows(
            is_up         => 0,
            map_coords    => $map_coords,
            coords        => \@coords,
            drawer        => $drawer,
            map_area_data => $map_area_data,
            drawing_data  => $drawing_data,
            is_flipped    => $is_flipped,
            map_id        => $map_id,
            map_acc       => $map_acc,
            slot_no       => $slot_no,
        );
    }
    else {
        push @$drawing_data,
            [
            LINE,             $map_coords->[0], $map_coords->[3],
            $map_coords->[2], $map_coords->[3], $color
            ];
    }
    push @$drawing_data,
        [ LINE, $x, $map_coords->[1], $x, $map_coords->[3], $color ];
    unless ($omit_all_area_boxes) {
        my $map     = $self->map($map_id);
        my $buttons = $self->create_buttons(
            map_id     => $map_id,
            drawer     => $drawer,
            slot_no    => $slot_no,
            is_flipped => $is_flipped,
            buttons    => [ 'map_detail', ],
        );
        my $url  = $buttons->[0]{'url'};
        my $alt  = $buttons->[0]{'alt'};
        my $code = '';
        eval $self->map_type_data( $map->{'map_type_acc'}, 'area_code' );
        push @{$map_area_data},
            {
            coords => [ $x, $map_coords->[1], $x, $map_coords->[3] ],
            url    => $url,
            alt    => $alt,
            code   => $code,
            };
    }
    if ( my $map_units = $args{'map_units'} ) {
        $self->draw_map_bottom(
            map_id        => $map_id,
            slot_no       => $slot_no,
            map_x1        => $map_coords->[0],
            map_x2        => $map_coords->[2],
            map_y2        => $map_coords->[3],
            drawer        => $drawer,
            drawing_data  => $drawing_data,
            map_area_data => $map_area_data,
            map_units     => $map_units,
            is_compressed => $is_compressed,
            bounds        => \@coords,
        );
    }

    return ( \@coords, $map_coords );
}

# ----------------------------------------------------
sub draw_stackable_box {

=pod

=head2 stackable_draw_box

Draws the map as a "box" (a filled-in rectangle).  In such a way as to allow
for this map to be stacked on others.  Return the bounds of the box.

=cut

    my ( $self, %args ) = @_;
    my $drawing_data  = $args{'drawing_data'};
    my $map_area_data = $args{'map_area_data'};
    my $map_coords    = $args{'map_coords'};
    my $drawer        = $args{'drawer'} || $self->drawer
        or $self->error('No drawer');
    my ( $x1, $y1, $y2 ) = @{ $args{'coords'} || [] }
        or $self->error('No coordinates');
    my $map_id              = $args{'map_id'};
    my $map_acc             = $self->map_acc($map_id);
    my $is_compressed       = $args{'is_compressed'};
    my $is_flipped          = $args{'is_flipped'};
    my $slot_no             = $args{'slot_no'};
    my $color1              = $self->map_color($map_id);
    my $width               = $self->map_width($map_id);
    my $x2                  = $x1 + $width;
    my $x_mid               = $x1 + ( $width / 2 );
    my @coords              = ( $x1, $y1, $x2, $y2 );
    my $omit_all_area_boxes = ( $drawer->omit_area_boxes >= 2 );
    $map_coords->[0] = $x1 if ( $map_coords->[0] > $x1 );
    $map_coords->[2] = $x2 if ( $map_coords->[2] < $x2 );
    my $color2 = 'black';

    my $color;
    if ( $self->{'oscillating_map_color_bool'} ) {
        $self->{'oscillating_map_color_bool'} = 0;
        $color = $color2;
    }
    else {
        $color = $color1;
        $self->{'oscillating_map_color_bool'} = 1;
    }

    push @$drawing_data, [ FILLED_RECT, @$map_coords, $color ];

    #push @$drawing_data, [ RECTANGLE,   @$map_coords, 'black' ];
    unless ($omit_all_area_boxes) {
        my $map     = $self->map($map_id);
        my $buttons = $self->create_buttons(
            map_id     => $map_id,
            drawer     => $drawer,
            slot_no    => $slot_no,
            is_flipped => $is_flipped,
            buttons    => [ 'map_detail', ],
        );
        my $url  = $buttons->[0]{'url'};
        my $alt  = $buttons->[0]{'alt'};
        my $code = '';
        eval $self->map_type_data( $map->{'map_type_acc'}, 'area_code' );
        push @{$map_area_data},
            {
            coords => [
                $map_coords->[0], $map_coords->[1],
                $map_coords->[2], $map_coords->[3]
            ],
            url  => $url,
            alt  => $alt,
            code => $code,
            };
    }

    return ( \@coords, $map_coords );
}

# ----------------------------------------------------
sub draw_map_bottom {

=pod

=head2 draw_map_bottom

draws the information to be placed at the bottom of the map
such as the units.

=cut

    my ( $self, %args ) = @_;
    my $map_id        = $args{'map_id'};
    my $slot_no       = $args{'slot_no'};
    my $x1            = $args{'map_x1'};
    my $x2            = $args{'map_x2'};
    my $y2            = $args{'map_y2'};
    my $drawer        = $args{'drawer'};
    my $drawing_data  = $args{'drawing_data'};
    my $map_area_data = $args{'map_area_data'};
    my $map_units     = $args{'map_units'};
    my $bounds        = $args{'bounds'};
    my $top_buf       = 12;
    my $buf           = 2;
    my $font          = $drawer->regular_font;
    my $is_compressed = $args{'is_compressed'};
    my $y             = $y2 + $top_buf;
    my $x_mid         = $x1 + ( ( $x2 - $x1 ) / 2 );
    my $magnification
        = $drawer->data_module->magnification( $slot_no, $map_id );
    my $slot_info           = $drawer->data_module->slot_info->{$slot_no};
    my $omit_all_area_boxes = ( $drawer->omit_area_boxes >= 2 );
    my $start_pos
        = defined( $slot_info->{$map_id}->[0] )
        ? $slot_info->{$map_id}->[0]
        : "''";
    my $stop_pos
        = defined( $slot_info->{$map_id}->[1] )
        ? $slot_info->{$map_id}->[1]
        : "''";
    my $x;
    my $code;
    my $map_acc = $self->map_acc($map_id);

    unless ( $self->clean_view ) {
        ###Full size button if needed
        if (   $drawer->data_module->truncatedMap( $slot_no, $map_id )
            or $magnification != 1 )
        {
            my $full_str = "Reset Map";
            $x = $x_mid - ( ( $font->width * length($full_str) ) / 2 );
            push @$drawing_data, [ STRING, $font, $x, $y, $full_str, 'grey' ];
            my $reset_url = $self->create_viewer_link(
                $drawer->create_minimal_link_params(),
                session_mod => "reset=$slot_no=$map_acc",
            );
            $code = qq[
                onMouseOver="window.status='Make map original size';return true" 
                ];
            push @$map_area_data,
                {
                coords => [
                    $x, $y,
                    $x + ( $font->width * length($full_str) ),
                    $y + $font->height,
                ],
                url  => $reset_url,
                alt  => 'Make map original size',
                code => $code,
                }
                unless ($omit_all_area_boxes);
            $y += $font->height + $buf;
            $bounds->[0] = $x
                if ( $bounds->[0] < $x );
            $bounds->[2] = $x + ( $font->width * length($full_str) )
                if (
                $bounds->[2] < $x + ( $font->width * length($full_str) ) );
            $bounds->[3] = $y + $font->height
                if ( $bounds->[3] < $y + $font->height );

        }

        unless ($is_compressed) {
            ###Scale buttons
            my $mag_plus_val
                = $magnification <= 1
                ? $magnification * 2
                : $magnification * 2;
            my $mag_minus_val
                = $magnification <= 1
                ? $magnification / 2
                : $magnification / 2;
            my $mag_plus_str  = "+";
            my $mag_minus_str = "-";
            my $mag_mid_str   = " Mag ";
            $x = $x_mid - (
                (   $font->width * length(
                        $mag_minus_str . $mag_plus_str . $mag_mid_str
                    )
                ) / 2
            );

            # Minus side
            my $mag_minus_url
                = $self->create_viewer_link(
                $drawer->create_minimal_link_params(),
                session_mod => "mag=$slot_no=$map_acc=$mag_minus_val", );
            push @$drawing_data,
                [ STRING, $font, $x, $y, $mag_minus_str, 'grey' ];
            $code = qq[
            onMouseOver="window.status='Magnify by $mag_minus_val times original size';return true" 
            ];
            push @$map_area_data,
                {
                coords => [
                    $x, $y,
                    $x + ( $font->width * length($mag_minus_str) ),
                    $y + $font->height
                ],
                url  => $mag_minus_url,
                alt  => 'Magnification',
                code => $code,
                }
                unless ($omit_all_area_boxes);
            $bounds->[0] = $x
                if ( $bounds->[0] > $x );
            $bounds->[3] = $y + $font->height
                if ( $bounds->[3] < $y + $font->height );
            $x += ( $font->width * length($mag_minus_str) );

            # Middle
            push @$drawing_data,
                [ STRING, $font, $x, $y, $mag_mid_str, 'grey' ];
            $code = qq[
            onMouseOver="window.status='Current Magnification: $magnification times original size';return true" 
            ];
            push @$map_area_data,
                {
                coords => [
                    $x, $y,
                    $x + ( $font->width * length($mag_mid_str) ),
                    $y + $font->height
                ],
                url  => '',
                alt  => 'Current Magnification: ' . $magnification . ' times',
                code => $code,
                }
                unless ($omit_all_area_boxes);
            $x += ( $font->width * length($mag_mid_str) );

            # Plus Side
            my $mag_plus_url
                = $self->create_viewer_link(
                $drawer->create_minimal_link_params(),
                session_mod => "mag=$slot_no=$map_acc=$mag_plus_val", );
            push @$drawing_data,
                [ STRING, $font, $x, $y, $mag_plus_str, 'grey' ];
            $code = qq[
            onMouseOver="window.status='Magnify by $mag_plus_val times original size';return true" 
            ];
            push @$map_area_data,
                {
                coords => [
                    $x, $y,
                    $x + ( $font->width * length($mag_plus_str) ),
                    $y + $font->height
                ],
                url  => $mag_plus_url,
                alt  => 'Magnification',
                code => $code,
                }
                unless ($omit_all_area_boxes);
            $bounds->[2] = $x + ( $font->width * length($mag_plus_str) )
                if ( $bounds->[2]
                < $x + ( $font->width * length($mag_plus_str) ) );
            $y += $font->height + $buf;
        }
    }

    ###Start and stop
    my ( $start, $stop )
        = $drawer->data_module->getDisplayedStartStop( $slot_no, $map_id );
    my $start_str = commify($start) . "-" . commify($stop) . " " . $map_units;
    $x = $x_mid - ( ( $font->width * length($start_str) ) / 2 );
    push @$drawing_data, [ STRING, $font, $x, $y, $start_str, 'grey' ];
    $y += $font->height + $buf;
    $bounds->[0] = $x
        if ( $bounds->[0] > $x );
    $bounds->[2] = $x + ( $font->width * length($start_str) )
        if ( $bounds->[2] < $x + ( $font->width * length($start_str) ) );
    $bounds->[3] = $y
        if ( $bounds->[3] < $y );
    ###Map Length
    #    my $map_length =$self->map_length($map_id);
    #    my $size_str    = presentable_number($map_length,3).$map_units;
    #    $x    = $x_mid -
    #      ( ( $font->width * length($size_str) ) / 2 );
    #    push @$drawing_data, [ STRING, $font, $x, $y, $size_str, 'grey' ];
    #    $y2 = $font->height +$y+$buf;
}

# ----------------------------------------------------
sub draw_truncation_arrows {

=pod
                                                                                                                             
=head2 draw_truncation_arrows

Draws the truncation arrows

=cut

    my $self          = shift;
    my %args          = @_;
    my $is_up         = $args{'is_up'};
    my $map_coords    = $args{'map_coords'};
    my $coords        = $args{'coords'};
    my $drawer        = $args{'drawer'};
    my $map_area_data = $args{'map_area_data'};
    my $drawing_data  = $args{'drawing_data'};
    my $is_flipped    = $args{'is_flipped'};
    my $map_id        = $args{'map_id'};
    my $map_acc       = $args{'map_acc'};
    my $slot_no       = $args{'slot_no'};

    my $omit_all_area_boxes = ( $drawer->omit_area_boxes >= 2 );

    my $trunc_color      = 'grey';
    my $trunc_half_width = 6;
    my $trunc_height     = 8;
    my $trunc_line_width = 4;
    my $trunc_buf        = 2;
    my $x_mid
        = $map_coords->[0] + ( ( $map_coords->[2] - $map_coords->[0] ) / 2 );

    if ($is_up) {

        # Move rest of map down.
        $map_coords->[1] += $trunc_height + $trunc_buf;
        $map_coords->[3] += $trunc_height + $trunc_buf;
        $coords->[3]     += $trunc_height + $trunc_buf;

        # Down Arrow signifying that this has been truncated.
        my $y_base = $map_coords->[1] - $trunc_buf;
        push @$drawing_data,
            [
            LINE, $x_mid - $trunc_half_width,
            $y_base, $x_mid - ( $trunc_half_width - $trunc_line_width ),
            $y_base, $trunc_color
            ];
        push @$drawing_data,
            [
            LINE, $x_mid - $trunc_half_width,
            $y_base, $x_mid, $y_base - $trunc_height, $trunc_color
            ];
        push @$drawing_data,
            [
            LINE, $x_mid,
            $y_base - $trunc_height,
            $x_mid + $trunc_half_width,
            $y_base, $trunc_color
            ];
        push @$drawing_data,
            [
            LINE, $x_mid + $trunc_half_width,
            $y_base, $x_mid + ( $trunc_half_width - $trunc_line_width ),
            $y_base, $trunc_color
            ];
        push @$drawing_data,
            [
            LINE,
            $x_mid + ( $trunc_half_width - $trunc_line_width ),
            $y_base,
            $x_mid,
            $y_base - ( $trunc_height - $trunc_line_width ),
            $trunc_color
            ];
        push @$drawing_data,
            [
            LINE,
            $x_mid - ( $trunc_half_width - $trunc_line_width ),
            $y_base,
            $x_mid,
            $y_base - ( $trunc_height - $trunc_line_width ),
            $trunc_color
            ];
        push @$drawing_data,
            [ FILL, $x_mid, $y_base - $trunc_height + 1, $trunc_color ];

        # Create the link
        my ( $scroll_start, $scroll_stop, $scroll_mag )
            = $drawer->data_module->scroll_data( $slot_no, $map_id,
            $is_flipped, 'UP' );
        my $scroll_up_url = $self->create_viewer_link(
            $drawer->create_minimal_link_params(),
            session_mod => "start=$slot_no=$map_acc=$scroll_start:"
                . "stop=$slot_no=$map_acc=$scroll_stop",
        );
        my $code = qq[ 
            onMouseOver="window.status='Scroll up';return true" 
            ];
        push @$map_area_data,
            {
            coords => [
                $x_mid - $trunc_half_width,
                $y_base - $trunc_height,
                $x_mid + $trunc_half_width,
                $y_base
            ],
            url  => $scroll_up_url,
            alt  => 'Scroll',
            code => $code,
            }
            unless ($omit_all_area_boxes);
    }
    else {

        # Down Arrow signifying that this has been truncated.
        my $y_base = $map_coords->[3] + $trunc_buf;
        push @$drawing_data,
            [
            LINE, $x_mid - $trunc_half_width,
            $y_base, $x_mid - ( $trunc_half_width - $trunc_line_width ),
            $y_base, $trunc_color
            ];
        push @$drawing_data,
            [
            LINE, $x_mid - $trunc_half_width,
            $y_base, $x_mid, $y_base + $trunc_height, $trunc_color
            ];
        push @$drawing_data,
            [
            LINE, $x_mid,
            $y_base + $trunc_height,
            $x_mid + $trunc_half_width,
            $y_base, $trunc_color
            ];
        push @$drawing_data,
            [
            LINE, $x_mid + $trunc_half_width,
            $y_base, $x_mid + ( $trunc_half_width - $trunc_line_width ),
            $y_base, $trunc_color
            ];
        push @$drawing_data,
            [
            LINE,
            $x_mid + ( $trunc_half_width - $trunc_line_width ),
            $y_base,
            $x_mid,
            $y_base + ( $trunc_height - $trunc_line_width ),
            $trunc_color
            ];
        push @$drawing_data,
            [
            LINE,
            $x_mid - ( $trunc_half_width - $trunc_line_width ),
            $y_base,
            $x_mid,
            $y_base + ( $trunc_height - $trunc_line_width ),
            $trunc_color
            ];
        push @$drawing_data,
            [ FILL, $x_mid, $y_base + $trunc_height - 1, $trunc_color ];

        # Create the link
        my ( $scroll_start, $scroll_stop, $scroll_mag )
            = $drawer->data_module->scroll_data( $slot_no, $map_id,
            $is_flipped, 'DOWN' );
        my $scroll_down_url = $self->create_viewer_link(
            $drawer->create_minimal_link_params(),
            session_mod => "start=$slot_no=$map_acc=$scroll_start:"
                . "stop=$slot_no=$map_acc=$scroll_stop",
        );
        my $code = qq[ 
            onMouseOver="window.status='Scroll down';return true" 
            ];
        push @$map_area_data,
            {
            coords => [
                $x_mid - $trunc_half_width,
                $y_base,
                $x_mid + $trunc_half_width,
                $y_base + $trunc_height
            ],
            url  => $scroll_down_url,
            alt  => 'Scroll',
            code => $code,
            }
            unless ($omit_all_area_boxes);
    }
}

# ----------------------------------------------------
sub create_slot_title {

=pod

=head2 create_slot_title

Creates the slot title.

=cut

    my $self    = shift;
    my %args    = @_;
    my $lines   = $args{'lines'} || [];
    my $buttons = $args{'buttons'} || [];
    my $font    = $args{'font'};
    my $drawer  = $args{'drawer'};
    my $min_y   = 0;
    my $left_x  = 0;
    my $right_x = 0;
    my $buffer  = 4;
    my $mid_x   = 0;
    my $top_y
        = $min_y - ( ( scalar @$lines ) * ( $font->height + $buffer ) ) - 4;
    $top_y -= ( $font->height + $buffer ) if ( scalar @$buttons );
    my $leftmost            = $mid_x;
    my $rightmost           = $mid_x;
    my $omit_all_area_boxes = ( $drawer->omit_area_boxes >= 2 );

    #
    # Place the titles.
    #
    my ( @drawing_data, @map_area_data );
    my $y = $top_y;
    for my $label (@$lines) {
        my $len     = $font->width * length($label);
        my $label_x = $mid_x - $len / 2;
        my $end     = $label_x + $len;

        push @drawing_data, [ STRING, $font, $label_x, $y, $label, 'black' ];

        $y += $font->height + $buffer;
        $leftmost  = $label_x if $label_x < $leftmost;
        $rightmost = $end     if $end > $rightmost;
    }

    #
    # Figure out how much room left-to-right the buttons will take.
    #
    my $buttons_width = 0;
    if ( scalar @$buttons ) {
        for my $button (@$buttons) {
            $buttons_width += $font->width * length( $button->{'label'} );
        }
        $buttons_width += 6 * ( scalar @$buttons - 1 );

        #
        # Place the buttons.
        #
        my $label_x = $mid_x - $buttons_width / 2;
        my $sep_x   = $label_x;
        my $sep_y   = $y;
        $y += 6;

        for my $button (@$buttons) {
            my $len = $font->width * length( $button->{'label'} );
            my $end = $label_x + $len;
            my @area
                = ( $label_x - 3, $y - 2, $end + 1, $y + $font->height + 2 );
            push @drawing_data,
                [ STRING, $font, $label_x, $y, $button->{'label'}, 'grey' ],
                [ RECTANGLE, @area, 'grey' ],;

            $leftmost  = $label_x if $label_x < $leftmost;
            $rightmost = $end     if $end > $rightmost;
            $label_x += $len + 6;

            push @map_area_data,
                {
                coords => \@area,
                url    => $button->{'url'},
                alt    => $button->{'alt'},
                }
                unless ($omit_all_area_boxes);
        }

        push @drawing_data,
            [ LINE, $sep_x, $sep_y, $label_x - 6, $sep_y, 'grey' ];

        $leftmost -= $buffer;
        $rightmost += $buffer;
    }

    #
    # Enclose the whole area in black-edged white box.
    #
    my @bounds = (
        $leftmost - $buffer,
        $top_y - $buffer,
        $rightmost + $buffer,
        $min_y + $buffer,
    );

    push @drawing_data, [
        FILLED_RECT, @bounds, 'white', 0    # bottom-most layer
    ];

    push @drawing_data, [ RECTANGLE, @bounds, 'black' ];

    return (
        bounds        => \@bounds,
        drawing_data  => \@drawing_data,
        map_area_data => \@map_area_data
    );
}

# ----------------------------------------------------
sub features {

=pod

=head2 features

Returns all the features on the map.  Features are stored in raw format as 
a hashref keyed on feature_id.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map($map_id);

    unless ( defined $map->{'feature_store'} ) {

        # The features are already sorted by start and stop.
        # All we need to do now is break them apart by lane and priority
        my %sorting_hash;
        for my $row ( @{ $map->{'features'} } ) {
            push @{ $sorting_hash{ $row->{'drawing_lane'} }
                    ->{ $row->{'drawing_priority'} } }, $row;
        }
        foreach my $lane ( sort { $a <=> $b } keys(%sorting_hash) ) {
            foreach my $priority (
                sort { $a <=> $b }
                keys( %{ $sorting_hash{$lane} } )
                )
            {
                push @{ $map->{'feature_store'}{$lane} },
                    @{ $sorting_hash{$lane}->{$priority} };
            }
        }
    }

    return $map->{'feature_store'};
}

# ----------------------------------------------------
sub no_features {

=pod

=head2 no_features

Returns the number features on the map.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map($map_id);
    return $map->{'no_features'};
}

# ----------------------------------------------------
sub shape {

=pod

=head2 shape

Returns a string describing how to draw the map.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map($map_id);
    my $shape  = $map->{'shape'} || $map->{'default_shape'} || '';
    $shape = 'default' unless defined $SHAPE{$shape};
    return $shape;
}

# ----------------------------------------------------
sub layout {

=pod

=head2 layout

Lays out the map.

Variable Info:

  $map_drawing_data{$map_id} holds the un-offset drawing data for each map;
  $map_area_data{$map_id} holds the un-offset area data for each map;
  $map_placement_data{$map_id} holds the boundary and map_coords for each map.
    {'bounds'} holds the boundary data for the whole thing, labels, toppers,
               footers, everything that needs to avoid collision.
    {'map_coords'} holds the coords of just the map (ie the box/dumbell/I-beam)
  $features_with_corr_by_map_id{$map_id};

=cut

    my $self       = shift;
    my $base_y     = $self->base_y;
    my $slot_no    = $self->slot_no;
    my $drawer     = $self->drawer;
    my $label_side = $drawer->label_side($slot_no);
    my $reg_font   = $drawer->regular_font
        or return $self->error( $drawer->error );
    my $slots       = $drawer->slots;
    my @map_ids     = $self->map_ids;
    my $font_width  = $reg_font->width;
    my $font_height = $reg_font->height;
    my $no_of_maps  = scalar @map_ids;

    # if more than one map in slot, compress all
    my $is_compressed  = $self->is_compressed($slot_no);
    my $stack_rel_maps = $self->is_stacked($slot_no);
    my $label_features = $drawer->label_features;
    my $config         = $self->config or return;

    # Remove any map ids that aren't going to be drawn.
    for ( my $i = 0; $i <= $#map_ids; $i++ ) {
        my $map_id = $map_ids[$i];
        if ($stack_rel_maps) {
            unless (
                %{ $drawer->map_correspondences( $slot_no, $map_id ) || {} } )
            {
                $drawer->map_not_displayed( $slot_no, $map_id, 1 );
                splice( @map_ids, $i, 1 );
                $i--;
            }
        }
    }

    #
    # The title is often the widest thing we'll draw, so we need
    # to figure out which is the longest and take half its length
    # into account when deciding where to start with the map(s).
    #
    my @config_map_titles = $config->get_config('map_titles');
    my $longest           = 0;
    for my $map_id (@map_ids) {
        for my $length (
            map { length $self->$_($map_id) if ( $self->can($_) ) }
            @config_map_titles )
        {
            $length ||= 0;
            $longest = $length if $length > $longest;
        }
    }
    my $half_title_length = ( $font_width * $longest ) / 2 + 10;
    my $slot_buffer       = 10;

    #
    # These are for drawing the map titles last if this is a relational map.
    #
    my ($top_y,
        $bottom_y,
        $slot_min_y,           # northernmost coord for the slot
        $slot_max_y,           # southernmost coord for the slot
        $slot_min_x,           # easternmost coord for the slot
        $slot_max_x,           # westernmost coord for the slot
        @map_titles,           # the titles to put above - for relational maps
        $map_set_acc,          # the map set acc. ID - for relational maps
        %feature_type_accs,    # the distinct feature type IDs
    );

    #
    # Some common things we'll need later on.
    #
    my $connecting_line_color = $drawer->config_data('connecting_line_color');
    my $feature_highlight_fg_color
        = $drawer->config_data('feature_highlight_fg_color');
    my $feature_highlight_bg_color
        = $drawer->config_data('feature_highlight_bg_color');

    my ($last_map_x);
    my $last_map_y = $base_y;
    my $show_labels
        = $is_compressed ? 0
        : $label_features eq 'none' ? 0
        :                             1;

    # Show ticks unless the maps are stacked or compressed
    my $show_ticks = !( $stack_rel_maps || $is_compressed );
    my $slot_title_buffer = 2;

    my $base_x = $self->base_x;

    my $slot_type_title = $slot_no ? "Comparative" : "Reference";

    # Create the Slot Title Box
    # We do this first to make sure that the slot is wide enough
    my @lines = (
        $slot_type_title,
        (   map { $self->$_( $map_ids[0] ) if ( $self->can($_) ) }
                grep !/map_name/,
            @config_map_titles
        )
    );
    my %slot_title_info = $self->create_slot_title(
        drawer  => $drawer,
        lines   => \@lines,
        buttons => $self->create_buttons(
            map_id  => $map_ids[0],
            drawer  => $drawer,
            slot_no => $slot_no,
            buttons => [ 'map_set_info', 'set_matrix', 'delete', ],
        ),
        font => $reg_font,
    );
    my $slot_title_width
        = $slot_title_info{'bounds'}->[2] 
        - $slot_title_info{'bounds'}->[0]
        + ( $slot_title_buffer * 2 );
    $drawer->slot_title(
        slot_no => $slot_no,
        %slot_title_info,
    );

    #    $slot_no == 0 ? $self->base_x
    #  : $slot_no > 0  ? $self->base_x + $half_title_length + 10
    #  : $self->base_x - $half_title_length - 20;

    my @map_columns = ();

    # Variable info:
    #
    my $y_buffer    = 4;    # buffer between maps in the y direction
    my $lane_buffer = 4;    # buffer between maps in the x direction
    my %map_drawing_data;
    my %map_area_data;
    my %map_placement_data;
    my %map_aggregate_corr;
    my %features_with_corr_by_map_id;
    my %flipped_maps;
    my $last_map_id;

    # If stacking maps,
    my $stacking_units_per_pixel = 0;
    my $stacked_max_y            = undef;
    if ($stack_rel_maps) {

        # Find the units to pixels ratio.
        my $total_map_units = 0;
        for my $map_id (@map_ids) {
            if (%{ $drawer->map_correspondences( $slot_no, $map_id ) || {} } )
            {
                $total_map_units += $self->map_length($map_id);
            }
        }
        $stacking_units_per_pixel
            = $total_map_units / $drawer->pixel_height();

        # order map ids by placement
        @map_ids = $self->order_map_ids_based_on_corrs(
            drawer  => $drawer,
            map_ids => \@map_ids,
            slot_no => $slot_no,
        );

    }

MAP:
    for my $map_id (@map_ids) {
        my $map_width = $self->map_width($map_id);
        my $max_x;

      # must create these arrays otherwise they don't get passed by reference.
        $map_drawing_data{$map_id} = [];
        $map_area_data{$map_id}    = [];

        my $actual_map_length = $self->map_length($map_id);
        my $map_length = $actual_map_length || 1;

        #
        # Find out if it flipped
        #
        my $is_flipped
            = $drawer->is_flipped( $slot_no, $self->map_acc($map_id) );
        $flipped_maps{$map_id} = $is_flipped;

        my $features = $self->features($map_id);

        #
        # The map.
        #

        # Get the desired map height.
        my $pixel_height;
        if ($stack_rel_maps) {
            $pixel_height
                = int( $map_length / $stacking_units_per_pixel ) + 1;
        }
        else {
            $pixel_height = $self->get_map_height(
                drawer        => $drawer,
                slot_no       => $slot_no,
                map_id        => $map_id,
                is_compressed => $is_compressed,
            );
        }

        # Place the map vertically in the slot
        my ( $placed_y1, $placed_y2, $capped );
        (   $placed_y1, $placed_y2,     $pixel_height,
            $capped,    $stacked_max_y, $is_flipped,
            )
            = $self->place_map_y(
            drawer             => $drawer,
            slot_no            => $slot_no,
            map_id             => $map_id,
            is_compressed      => $is_compressed,
            pixel_height       => $pixel_height,
            is_flipped         => $is_flipped,
            flipped_maps_ref   => \%flipped_maps,
            y_buffer           => $y_buffer,
            last_map_id        => $last_map_id,
            stacked_max_y      => $stacked_max_y,
            stack_rel_maps     => $stack_rel_maps,
            map_aggregate_corr => \%map_aggregate_corr,
            map_placement_data => \%map_placement_data,
            );

        # If the map wasn't placed, go to the next map
        # Mark the map as not displayed (I'm doing this in two places because
        # I've become paranoid in my old age.
        unless ( defined $placed_y1 ) {
            $drawer->map_not_displayed( $slot_no, $map_id, 1 );
            next MAP;
        }

        $map_placement_data{$map_id}{'bounds'}
            = [ 0, $placed_y1, 0, $placed_y2 ];
        $map_placement_data{$map_id}{'map_coords'}
            = [ 0, $placed_y1, 0, $placed_y2 ];

        # Add the topper
        $self->add_topper(
            drawer             => $drawer,
            slot_no            => $slot_no,
            map_id             => $map_id,
            is_compressed      => $is_compressed,
            map_drawing_data   => \%map_drawing_data,
            map_area_data      => \%map_area_data,
            map_placement_data => \%map_placement_data,
            is_flipped         => $is_flipped,
        ) unless ($stack_rel_maps);

        # Draw the actual Map
        my $mid_x         = 0;
        my $draw_sub_name = $SHAPE{ $self->shape($map_id) };
        $draw_sub_name = 'draw_stackable_box' if ($stack_rel_maps);
        my ( $bounds, $map_coords ) = $self->$draw_sub_name(
            map_id        => $map_id,
            slot_no       => $slot_no,
            map_units     => $self->map_units($map_id),
            drawer        => $drawer,
            is_compressed => $is_compressed,
            is_flipped    => $is_flipped,
            coords        => [
                $mid_x,
                $map_placement_data{$map_id}{'map_coords'}[1],
                $map_placement_data{$map_id}{'map_coords'}[3],
            ],
            map_coords    => $map_placement_data{$map_id}{'map_coords'},
            drawing_data  => $map_drawing_data{$map_id},
            map_area_data => $map_area_data{$map_id},
        );
        $map_placement_data{$map_id}{'bounds'}[0] = $bounds->[0]
            if ( $map_placement_data{$map_id}{'bounds'}[0] > $bounds->[0] );
        $map_placement_data{$map_id}{'bounds'}[1] = $bounds->[1]
            if ( $map_placement_data{$map_id}{'bounds'}[1] > $bounds->[1] );
        $map_placement_data{$map_id}{'bounds'}[2] = $bounds->[2]
            if ( $map_placement_data{$map_id}{'bounds'}[2] < $bounds->[2] );
        $map_placement_data{$map_id}{'bounds'}[3] = $bounds->[3]
            if ( $map_placement_data{$map_id}{'bounds'}[3] < $bounds->[3] );

        # Add an asterisk if the map was capped
        $self->add_capped_mark(
            drawer             => $drawer,
            map_id             => $map_id,
            drawing_data       => $map_drawing_data{$map_id},
            map_area_data      => $map_area_data{$map_id},
            capped             => $capped,
            map_placement_data => \%map_placement_data,
        );

        my $map_name = $self->map_name($map_id);
        if ( $drawer->highlight_feature($map_name) ) {
            push @{ $map_drawing_data{$map_id} },
                [
                RECTANGLE,
                @{ $map_placement_data{$map_id}{'map_coords'} },
                $feature_highlight_fg_color
                ];

            push @{ $map_drawing_data{$map_id} },
                [
                FILLED_RECT, @{ $map_placement_data{$map_id}{'map_coords'} },
                $feature_highlight_bg_color, 0
                ];
        }

        # Tick marks.
        if ($show_ticks) {
            $self->add_tick_marks(
                map_coords    => $map_placement_data{$map_id}{'map_coords'},
                bounds        => $map_placement_data{$map_id}{'bounds'},
                drawer        => $drawer,
                map_id        => $map_id,
                slot_no       => $slot_no,
                drawing_data  => $map_drawing_data{$map_id},
                map_area_data => $map_area_data{$map_id},
                pixel_height  => $pixel_height,
                is_flipped    => $is_flipped,
                actual_map_length => $actual_map_length,
                map_length        => $map_length,
            );
        }

        #
        # Features.
        #
        my $min_y = $map_placement_data{$map_id}{'map_coords'}[1]
            ;                      # remembers the northermost position
        my %lanes;                 # associate priority with a lane
        my %features_with_corr;    # features w/correspondences
        my ( $leftmostf, $rightmostf );    # furthest features

        my $map_base_x = $map_placement_data{$map_id}{'map_coords'}[0];
        my $map_start  = $self->map_start($map_id);

        for my $lane ( sort { $a <=> $b } keys %$features ) {
            my %even_labels;               # holds label coordinates
             #my ( @north_labels, @south_labels );    # holds label coordinates
            my $lane_features = $features->{$lane};
            my $prev_label_y;    # the y value of previous label
            my @fcolumns = ();   # for feature east-to-west

            #
            # Use the "drawing_lane" to determine where to draw the feature.
            #
            unless ( exists $lanes{$lane} ) {
                $lanes{$lane} = {
                    order    => ( scalar keys %lanes ) + 1,
                    furthest => $label_side eq RIGHT
                    ? $rightmostf
                    : $leftmostf,
                };

                my $lane = $lanes{$lane};
                $map_base_x
                    = $lane->{'furthest'}
                    ? $label_side eq RIGHT
                        ? $lane->{'furthest'} + 2
                        : $lane->{'furthest'} - ( $map_width + 4 )
                    : $map_base_x;
            }

            # If the labels aren't going to fit, don't deal with the ones
            # that are on collapsed features.
            my $label_collapsed_features = 1;
            my $magic_label_height_ratio = 3;
            if ($drawer->label_features eq 'none'
                or ( ( $pixel_height * $magic_label_height_ratio ) /
                    $font_height ) < ( scalar(@$lane_features) )
                )
            {
                $label_collapsed_features = 0;
            }
            my %drawn_glyphs;
            for my $feature (@$lane_features) {
                ########################################
                my $coords;
                my $color;
                my $label_y;
                my $has_corr
                    = $drawer->has_correspondence( $feature->{'feature_id'} );
                my $is_highlighted = $drawer->highlight_feature(
                    $feature->{'feature_name'},
                    @{ $feature->{'aliases'} || [] },
                    $feature->{'feature_acc'},
                );

                my $glyph_drawn = 0;

                (   $leftmostf, $rightmostf, $coords,
                    $color,     $label_y,    $glyph_drawn
                    )
                    = $self->add_feature_to_map(
                    base_x => $map_base_x,
                    map_base_y =>
                        $map_placement_data{$map_id}{'map_coords'}[1],
                    drawer            => $drawer,
                    feature           => $feature,
                    map_id            => $map_id,
                    slot_no           => $slot_no,
                    drawing_data      => $map_drawing_data{$map_id},
                    map_area_data     => $map_area_data{$map_id},
                    fcolumns          => \@fcolumns,
                    pixel_height      => $pixel_height,
                    is_flipped        => $is_flipped,
                    map_length        => $map_length,
                    leftmostf         => $leftmostf,
                    rightmostf        => $rightmostf,
                    drawn_glyphs      => \%drawn_glyphs,
                    feature_type_accs => \%feature_type_accs,
                    map_start         => $map_start,
                    map_width         => $map_width,
                    has_corr          => $has_corr,
                    is_highlighted    => $is_highlighted,
                    );
                $self->add_to_features_with_corr(
                    coords             => $coords,
                    feature            => $feature,
                    features_with_corr => \%features_with_corr,
                    has_corr           => $has_corr,
                    map_id             => $map_id,
                    slot_no            => $slot_no,
                    is_flipped         => $is_flipped,
                );

                if ( $label_collapsed_features or $glyph_drawn ) {
                    $self->collect_labels_to_display(
                        color          => $color,
                        coords         => $coords,
                        drawer         => $drawer,
                        even_labels    => \%even_labels,
                        feature        => $feature,
                        has_corr       => $has_corr,
                        is_highlighted => $is_highlighted,
                        label_y        => $label_y,
                        map_base_y =>
                            $map_placement_data{$map_id}{'map_coords'}[1],
                        show_labels => $show_labels,
                    );
                }
                ########################################
            }

            #
            # We have to wait until all the features for the lane are
            # drawn before placing the labels.
            ##############################################
            my $min_x = 0;
            (   $map_base_x, $leftmostf, $rightmostf, $max_x, $min_x, $top_y,
                $bottom_y, $min_y
                )
                = $self->add_labels_to_map(
                base_x       => $map_base_x,
                base_y       => $map_placement_data{$map_id}{'map_coords'}[1],
                even_labels  => \%even_labels,
                drawer       => $drawer,
                rightmostf   => $rightmostf,
                leftmostf    => $leftmostf,
                map_id       => $map_id,
                slot_no      => $slot_no,
                drawing_data => $map_drawing_data{$map_id},
                map_area_data      => $map_area_data{$map_id},
                features_with_corr => \%features_with_corr,
                stack_rel_maps     => $stack_rel_maps,
                min_x        => $map_placement_data{$map_id}{'bounds'}[0],
                top_y        => $map_placement_data{$map_id}{'bounds'}[1],
                max_x        => $map_placement_data{$map_id}{'bounds'}[2],
                bottom_y     => $map_placement_data{$map_id}{'bounds'}[3],
                min_y        => $map_placement_data{$map_id}{'bounds'}[1],
                pixel_height => $pixel_height,
                );
            $map_placement_data{$map_id}{'bounds'}[0] = $min_x
                if ( $map_placement_data{$map_id}{'bounds'}[0] > $min_x );
            $map_placement_data{$map_id}{'bounds'}[2] = $max_x
                if ( $map_placement_data{$map_id}{'bounds'}[2] < $max_x );

            # If stacking maps, we don't care about the features hanging over
            unless ($stack_rel_maps) {
                $map_placement_data{$map_id}{'bounds'}[1] = $top_y
                    if ( $map_placement_data{$map_id}{'bounds'}[1] > $top_y );
                $map_placement_data{$map_id}{'bounds'}[1] = $min_y
                    if ( $map_placement_data{$map_id}{'bounds'}[1] > $min_y );
                $map_placement_data{$map_id}{'bounds'}[3] = $bottom_y
                    if (
                    $map_placement_data{$map_id}{'bounds'}[3] < $bottom_y );
            }

            ##############################################
            $lanes{$lane}{'furthest'}
                = $label_side eq RIGHT ? $rightmostf : $leftmostf;
            $map_placement_data{$map_id}{'bounds'}[0] = $leftmostf
                if ( $map_placement_data{$map_id}{'bounds'}[0] > $leftmostf );
            $map_placement_data{$map_id}{'bounds'}[2] = $rightmostf
                if (
                $map_placement_data{$map_id}{'bounds'}[2] < $rightmostf );
        }

        $features_with_corr_by_map_id{$map_id} = \%features_with_corr;

        my ($min_x);

        $slot_min_y = $map_placement_data{$map_id}{'bounds'}[1]
            if (
            not $stack_rel_maps
            and ( not defined $slot_max_y
                or $map_placement_data{$map_id}{'bounds'}[1] < $slot_min_y )
            );
        $slot_max_y = $map_placement_data{$map_id}{'bounds'}[3]
            if ( not defined $slot_max_y
            or $map_placement_data{$map_id}{'bounds'}[3] > $slot_max_y );

        $last_map_id = $map_id;
    }

    # place each map in a lane and find the width of each lane
    my %map_lane;
    my @lane_width;
    my @map_colunms;
    my $ref_map_order_hash
        = $slot_no == 0 ? $drawer->data_module->ref_map_order_hash() : undef;
    for my $map_id (
        sort {
            $map_placement_data{$a}{'bounds'}[1]
                <=> $map_placement_data{$b}{'bounds'}[1]
        } @map_ids
        )
    {

        # Decide which lane this map should be in
        if (    ( not $self->stack_maps() )
            and $ref_map_order_hash
            and $ref_map_order_hash->{$map_id} )
        {
            $map_lane{$map_id} = $ref_map_order_hash->{$map_id} - 1;
        }
        else {
            if (@map_columns) {
                for my $i ( 0 .. $#map_columns ) {
                    if ( $map_columns[$i]
                        < $map_placement_data{$map_id}{'bounds'}[1] )
                    {
                        $map_lane{$map_id} = $i;
                        last;
                    }
                }
            }
            else {
                $map_lane{$map_id} = 0;
            }
        }

        # If it doesn't fit in any of the others, make new lane
        $map_lane{$map_id} = scalar @map_columns
            unless defined $map_lane{$map_id};

        # This map is now the lowest value in the lane
        # change the map_columns value appropriately
        $map_columns[ $map_lane{$map_id} ]
            = $map_placement_data{$map_id}{'bounds'}[3];
        $map_columns[ $map_lane{$map_id} ] += $y_buffer
            unless ($stack_rel_maps);

        # Set the lane width if this map is wider than any previous
        if (not defined( $lane_width[ $map_lane{$map_id} ] )
            or $lane_width[ $map_lane{$map_id} ] < (
                      $map_placement_data{$map_id}{'bounds'}[2]
                    - $map_placement_data{$map_id}{'bounds'}[0]
            )
            )
        {
            $lane_width[ $map_lane{$map_id} ]
                = $map_placement_data{$map_id}{'bounds'}[2]
                - $map_placement_data{$map_id}{'bounds'}[0];
        }
    }

    my @lane_base_x;
    if ( $slot_no < 0
        || ( $slot_no == 0 && $drawer->label_side($slot_no) eq LEFT ) )
    {
        $lane_base_x[0] = $base_x - $lane_width[0] - $slot_buffer;

        # maps are placed from right to left
        for my $i ( 1 .. $#map_columns ) {
            $lane_base_x[$i]
                = $lane_base_x[ $i - 1 ] - $lane_width[$i] - $lane_buffer;
        }
        $slot_max_x = $base_x;
        $slot_min_x = $lane_base_x[-1] - $slot_buffer;
        $slot_min_x = $base_x - $slot_title_width
            if ( $slot_min_x > ( $base_x - $slot_title_width ) );
    }
    else {
        $lane_base_x[0] = $base_x + $slot_buffer;

        # maps are placed from left to right
        for my $i ( 1 .. $#map_columns ) {
            $lane_base_x[$i]
                = $lane_base_x[ $i - 1 ] 
                + $lane_width[ $i - 1 ]
                + $lane_buffer;
        }
        $slot_min_x = $base_x;
        $slot_max_x = $lane_base_x[-1] + $lane_width[-1] + $slot_buffer;
        $slot_max_x = ( $base_x + $slot_title_width )
            if ( $slot_max_x < ( $base_x + $slot_title_width ) );
    }

    my $corrs_to_map = $drawer->corrs_to_map();

    # Offset all of the coords accordingly
    for my $map_id (@map_ids) {
        my $offset = $lane_base_x[ $map_lane{$map_id} ]
            - $map_placement_data{$map_id}{'bounds'}[0];

        $drawer->offset_drawing_data(
            drawing_data => $map_drawing_data{$map_id},
            offset_x     => $offset,
        );
        $drawer->offset_map_area_data(
            map_area_data => $map_area_data{$map_id},
            offset_x      => $offset,
        );
        for my $key ( keys( %{ $features_with_corr_by_map_id{$map_id} } ) ) {
            $features_with_corr_by_map_id{$map_id}{$key}{'left'}[0]
                += $offset;
            $features_with_corr_by_map_id{$map_id}{$key}{'right'}[0]
                += $offset;
        }

        $map_placement_data{$map_id}{'map_coords'}[0] += $offset;
        $map_placement_data{$map_id}{'map_coords'}[2] += $offset;
        $map_placement_data{$map_id}{'bounds'}[0]     += $offset;
        $map_placement_data{$map_id}{'bounds'}[2]     += $offset;

        # If the corr lines are supposed to go to the map.
        if ($corrs_to_map) {
            for my $key (
                keys( %{ $features_with_corr_by_map_id{$map_id} } ) )
            {
                $features_with_corr_by_map_id{$map_id}{$key}{'left'}[0]
                    = $map_placement_data{$map_id}{'map_coords'}[0];
                $features_with_corr_by_map_id{$map_id}{$key}{'right'}[0]
                    = $map_placement_data{$map_id}{'map_coords'}[2];
            }
        }

        $drawer->add_drawing( @{ $map_drawing_data{$map_id} } );
        $drawer->add_map_area( @{ $map_area_data{$map_id} } );

        # Register all the features that have correspondences.
        $drawer->register_feature_position(%$_)
            for values %{ $features_with_corr_by_map_id{$map_id} };

        my $map_start = $self->map_start($map_id);
        my $map_stop  = $self->map_stop($map_id);

        $drawer->register_map_coords( $slot_no, $map_id, $map_start,
            $map_stop, @{ $map_placement_data{$map_id}{'map_coords'} },
            $flipped_maps{$map_id}, );

    }

    #Make aggregated correspondences
    my $corrs_aggregated = 0;
    if ($is_compressed
        or (    $slot_no
            and $self->is_compressed( $drawer->reference_slot_no($slot_no) ) )
        )
    {
        for my $map_id (@map_ids) {
            $corrs_aggregated = 1
                if ( $map_aggregate_corr{$map_id}
                and @{ $map_aggregate_corr{$map_id} } );
            my @drawing_data = ();
            my $map_length   = $self->map_length($map_id);
            for my $ref_connect ( @{ $map_aggregate_corr{$map_id} } ) {
                my $map_coords = $map_placement_data{$map_id}{'map_coords'};
                my $line_color = $drawer->aggregated_line_color(
                    corr_no           => $ref_connect->[2],
                    evidence_type_acc => $ref_connect->[4],
                );

                my $this_map_x
                    = $label_side eq RIGHT
                    ? $map_coords->[0] - 4
                    : $map_coords->[2] + 4;
                my $this_map_x2
                    = $label_side eq RIGHT
                    ? $map_coords->[0]
                    : $map_coords->[2];
                my $this_map_y
                    = $flipped_maps{$map_id}
                    ? ( ( 1 - ( $ref_connect->[3] / $map_length ) )
                    * ( $map_coords->[3] - $map_coords->[1] ) )
                    + $map_coords->[1]
                    : ( ( $ref_connect->[3] / $map_length )
                    * ( $map_coords->[3] - $map_coords->[1] ) )
                    + $map_coords->[1];
                push @drawing_data,
                    [
                    LINE,              $ref_connect->[0],
                    $ref_connect->[1], $this_map_x,
                    $this_map_y,       $line_color,
                    0
                    ];

                # Make Anchor T
                push @drawing_data,
                    [
                    LINE,            $this_map_x,
                    $this_map_y - 1, $this_map_x,
                    $this_map_y + 1, 'black',
                    10
                    ];
                push @drawing_data,
                    [
                    LINE,        $this_map_x, $this_map_y, $this_map_x2,
                    $this_map_y, 'black',     10
                    ];

            }
            $drawer->add_drawing(@drawing_data) if ( scalar(@drawing_data) );
        }

        # Draw intraslot aggregated corrs.
        if ( $drawer->show_intraslot_corr ) {

            # Use Correspondences to figure out where to put this vertically.
            my ( $min_ref_y, $max_ref_y );
            for ( my $i = 0; $i <= $#map_ids; $i++ ) {
                my @drawing_data = ();
                my $map_id1      = $map_ids[$i];
                my $corrs
                    = $drawer->map_correspondences( $slot_no, $map_id1 );
                for ( my $j = $i + 1; $j <= $#map_ids; $j++ ) {
                    my $map_id2   = $map_ids[$j];
                    my $all_corrs = $corrs->{$map_id2};
                    next unless defined($all_corrs);
                    my $drawing_offset = 0;
                    foreach my $corr (@$all_corrs) {
                        my $evidence_type_acc = $corrs->{'evidence_type_acc'};

                        #
                        # Get the information about the map placement.
                        #
                        my $map1_pos
                            = $drawer->reference_map_coords( $slot_no,
                            $map_id1 );
                        my $map2_pos
                            = $drawer->reference_map_coords( $slot_no,
                            $map_id2 );

                        # average of corr on map1
                        my $avg_mid1
                            = defined( $corr->{'avg_mid1'} )
                            ? $corr->{'avg_mid1'}
                            : $corr->{'start_avg1'};

                        # average of corr on map 2
                        my $avg_mid2
                            = defined( $corr->{'avg_mid2'} )
                            ? $corr->{'avg_mid2'}
                            : $corr->{'start_avg2'};

                        my $map1_pixel_len
                            = $map1_pos->{'y2'} - $map1_pos->{'y1'};
                        my $map2_pixel_len
                            = $map2_pos->{'y2'} - $map2_pos->{'y1'};
                        my $map1_unit_len = $map1_pos->{'map_stop'}
                            - $map1_pos->{'map_start'};
                        my $map2_unit_len = $map2_pos->{'map_stop'}
                            - $map2_pos->{'map_start'};

                        # Set the avg location of the corr on the ref map
                        my $map1_mid_y
                            = $map1_pos->{'is_flipped'}
                            ? (
                            $map1_pos->{'y2'} - (
                                ( $avg_mid1 - $map1_pos->{'map_start'} ) /
                                    $map1_unit_len
                                ) * $map1_pixel_len
                            )
                            : (
                            $map1_pos->{'y1'} + (
                                ( $avg_mid1 - $map1_pos->{'map_start'} ) /
                                    $map1_unit_len
                                ) * $map1_pixel_len
                            );
                        my $map2_mid_y
                            = $map2_pos->{'is_flipped'}
                            ? (
                            $map2_pos->{'y2'} - (
                                ( $avg_mid2 - $map2_pos->{'map_start'} ) /
                                    $map2_unit_len
                                ) * $map2_pixel_len
                            )
                            : (
                            $map2_pos->{'y1'} + (
                                ( $avg_mid2 - $map2_pos->{'map_start'} ) /
                                    $map2_unit_len
                                ) * $map2_pixel_len
                            );
                        my $map1_y1
                            = $map1_pos->{'is_flipped'}
                            ? (
                            $map1_pos->{'y2'} - (
                                (         $corr->{'min_start1'}
                                        - $map1_pos->{'map_start'}
                                ) / $map1_unit_len
                                ) * $map1_pixel_len
                            )
                            : (
                            $map1_pos->{'y1'} + (
                                (         $corr->{'min_start1'}
                                        - $map1_pos->{'map_start'}
                                ) / $map1_unit_len
                                ) * $map1_pixel_len
                            );
                        my $map2_y1
                            = $map2_pos->{'is_flipped'}
                            ? (
                            $map2_pos->{'y2'} - (
                                (         $corr->{'min_start2'}
                                        - $map2_pos->{'map_start'}
                                ) / $map2_unit_len
                                ) * $map2_pixel_len
                            )
                            : (
                            $map2_pos->{'y1'} + (
                                (         $corr->{'min_start2'}
                                        - $map2_pos->{'map_start'}
                                ) / $map2_unit_len
                                ) * $map2_pixel_len
                            );
                        my $map1_y2
                            = $map1_pos->{'is_flipped'}
                            ? $map1_pos->{'y2'} + (
                            (         $corr->{'max_start1'}
                                    - $map1_pos->{'map_start'}
                            ) / $map1_unit_len
                            ) * $map1_pixel_len
                            : $map1_pos->{'y1'} + (
                            (         $corr->{'max_start1'}
                                    - $map1_pos->{'map_start'}
                            ) / $map1_unit_len
                            ) * $map1_pixel_len;

                        my $map2_y2
                            = $map2_pos->{'is_flipped'}
                            ? $map2_pos->{'y2'} + (
                            (         $corr->{'max_start2'}
                                    - $map2_pos->{'map_start'}
                            ) / $map2_unit_len
                            ) * $map2_pixel_len
                            : $map2_pos->{'y1'} + (
                            (         $corr->{'max_start2'}
                                    - $map2_pos->{'map_start'}
                            ) / $map2_unit_len
                            ) * $map2_pixel_len;

                        my $line_cushion = 10;
                        my $map1_coords
                            = $map_placement_data{$map_id1}{'map_coords'};
                        my $map2_coords
                            = $map_placement_data{$map_id2}{'map_coords'};
                        my $left_side = my $map1_x
                            = $label_side eq LEFT
                            ? $map1_coords->[0] - $drawing_offset
                            : $map1_coords->[2] + $drawing_offset;
                        my $map2_x
                            = $label_side eq LEFT
                            ? $map2_coords->[0]
                            : $map2_coords->[2];
                        my $map1_x2
                            = $label_side eq LEFT
                            ? $map1_x - $line_cushion
                            : $map1_x + $line_cushion;
                        my $map2_x2
                            = $label_side eq LEFT
                            ? $map2_x - ( $line_cushion * 3 )
                            : $map2_x + ( $line_cushion * 3 );
                        my $line_color = $drawer->aggregated_line_color(
                            corr_no           => $corr->{'no_corr'},
                            evidence_type_acc => $evidence_type_acc,
                        );

                        # add aggregate correspondences to ref_connections
                        if ( $self->aggregate <=> 2 ) {

                            # Single line to avg corr
                            push @drawing_data,
                                [
                                LINE,        $map1_x,
                                $map1_mid_y, $map1_x2,
                                $map1_mid_y, $line_color,
                                0
                                ];
                            push @drawing_data,
                                [
                                LINE,        $map1_x2,
                                $map1_mid_y, $map2_x2,
                                $map2_mid_y, $line_color,
                                0
                                ];
                            push @drawing_data,
                                [
                                LINE,        $map2_x2,
                                $map2_mid_y, $map2_x,
                                $map2_mid_y, $line_color,
                                0
                                ];
                        }
                        else {

                            # first of double line
                            push @drawing_data,
                                [
                                LINE,     $map1_x,
                                $map1_y1, $map1_x2,
                                $map1_y1, $line_color,
                                0
                                ];
                            push @drawing_data,
                                [
                                LINE,     $map1_x2,
                                $map1_y1, $map2_x2,
                                $map2_y1, $line_color,
                                0
                                ];
                            push @drawing_data,
                                [
                                LINE,     $map2_x2,
                                $map2_y1, $map2_x,
                                $map2_y1, $line_color,
                                0
                                ];

                            # Second line
                            push @drawing_data,
                                [
                                LINE,     $map1_x,
                                $map1_y2, $map1_x2,
                                $map1_y2, $line_color,
                                0
                                ];
                            push @drawing_data,
                                [
                                LINE,     $map1_x2,
                                $map1_y2, $map2_x2,
                                $map2_y2, $line_color,
                                0
                                ];
                            push @drawing_data,
                                [
                                LINE,     $map2_x2,
                                $map2_y2, $map2_x,
                                $map2_y2, $line_color,
                                0
                                ];
                        }
                        $drawing_offset++;
                    }
                }
                $drawer->add_drawing(@drawing_data)
                    if ( scalar(@drawing_data) );
            }
        }
    }

    #
    # Register the feature types we saw.
    #
    $drawer->register_feature_type( keys %feature_type_accs );

    #
    # Background color
    #
    return [ $slot_min_x, $slot_min_y - $slot_buffer,
        $slot_max_x, $slot_max_y, ],
        $corrs_aggregated;
}

# ----------------------------------------

=pod

=head2 get_map_height

gets the desired map height after scaling.

=cut

sub get_map_height {

    my ( $self, %args ) = @_;
    my $drawer        = $args{'drawer'};
    my $slot_no       = $args{'slot_no'};
    my $map_id        = $args{'map_id'};
    my $is_compressed = $args{'is_compressed'};

    my $min_map_pixel_height = $drawer->config_data('min_map_pixel_height');
    my $pixel_height         = $drawer->pixel_height();
    if ( $is_compressed and $slot_no != 0 ) {
        $pixel_height = $min_map_pixel_height;
    }
    elsif ( $self->scale_maps
        and $self->config_data('scalable')
        and $self->config_data('scalable')->{ $self->map_units($map_id) }
        and $drawer->{'data'}{'ref_unit_size'}{ $self->map_units($map_id) } )
    {
        $pixel_height
            = ( $self->map_stop($map_id) - $self->map_start($map_id) )
            * ( $drawer->pixel_height() /
                $drawer->{'data'}{'ref_unit_size'}
                { $self->map_units($map_id) } );

    }

    $pixel_height = $min_map_pixel_height
        if ( $pixel_height < $min_map_pixel_height );
    $pixel_height = $pixel_height
        * $drawer->data_module->magnification( $slot_no, $map_id );

    return $pixel_height;
}

# ----------------------------------------

=pod

=head2 place_map_y

Takes the height, returns the vertical boundaries of the map 
(not counting toppers and footers). 
This will take into account where the correspondences are on the 
reference maps and any capping that needs to be done.

=cut

sub place_map_y {

    my ( $self, %args ) = @_;
    my $drawer             = $args{'drawer'};
    my $slot_no            = $args{'slot_no'};
    my $map_id             = $args{'map_id'};
    my $is_compressed      = $args{'is_compressed'};
    my $pixel_height       = $args{'pixel_height'};
    my $map_aggregate_corr = $args{'map_aggregate_corr'};
    my $map_placement_data = $args{'map_placement_data'};
    my $is_flipped         = $args{'is_flipped'};
    my $flipped_maps_ref   = $args{'flipped_maps_ref'};
    my $stacked_max_y      = $args{'stacked_max_y'};
    my $stack_rel_maps     = $args{'stack_rel_maps'};
    my $y_buffer           = $args{'y_buffer'};
    my $last_map_id        = $args{'last_map_id'};

    my ( $return_y1, $return_y2 );

    my $map_name        = $self->map_name($map_id);
    my $ref_slot_no     = $drawer->reference_slot_no($slot_no);
    my $base_y          = $self->base_y;
    my $boundary_factor = 0.5;
    my $capped          = 0;

    my $top_boundary_offset
        = ( ( $drawer->pixel_height() ) * $boundary_factor );
    my $top_boundary = $base_y - $top_boundary_offset;
    my $bottom_boundary_offset
        = ( ( $drawer->pixel_height() ) * $boundary_factor );
    my $bottom_boundary
        = ( $drawer->pixel_height() ) + $base_y + $bottom_boundary_offset;

    #
    # If drawing compressed maps in the first slot, then draw them
    # in "display_order," else we'll try to line them up.
    #
    my ( $this_map_y, $this_map_x ) = ( 0, 0 );

    $return_y1 = $this_map_y;
    $return_y2 = $this_map_y + $pixel_height;
    if ( defined $ref_slot_no ) {

        my $ref_slot_info = $drawer->data_module->slot_info->{$ref_slot_no};

        # Use Correspondences to figure out where to put this vertically.
        my $ref_corrs = $drawer->map_correspondences( $slot_no, $map_id );

        # Make the maps disappear if they don't have corrs or if their ref map
        # doesn't have corrs
        if ($stack_rel_maps) {
            my $ref_map_displayed = 0;
            for my $ref_map_id ( sort keys( %{ $ref_corrs || {} } ) ) {
                unless (
                    $drawer->map_not_displayed( $ref_slot_no, $ref_map_id ) )
                {
                    $ref_map_displayed = 1;
                }
            }
            unless ($ref_map_displayed) {
                $drawer->map_not_displayed( $slot_no, $map_id, 1 );
                return undef;
            }
        }

        my ( $min_ref_y, $max_ref_y );
        my $placed = 0;

        if ($stack_rel_maps) {

            # This places the map in based on the stacking order
            my $map_unit_len = $self->map_length($map_id);
            unless ( defined $stacked_max_y ) {

                # make room for three lines
                my $reg_font = $drawer->regular_font
                    or return $self->error( $drawer->error );
                my $font_height = $reg_font->height;
                $stacked_max_y = $base_y + ( $font_height * 3 );
            }
            $min_ref_y       = $stacked_max_y;
            $max_ref_y       = $min_ref_y + $pixel_height;
            $top_boundary    = $min_ref_y;
            $bottom_boundary = $max_ref_y;
            $stacked_max_y   = $max_ref_y + 1;
            $placed          = 1;
        }
        my $first_ref_map = 1;
        for my $ref_map_id ( sort keys(%$ref_slot_info) ) {

            my $all_ref_corrs = $ref_corrs->{$ref_map_id};
            next unless defined($all_ref_corrs);

            if ($first_ref_map) {
                if ($stack_rel_maps) {

                    my $ref_slot_data = $drawer->slot_data($ref_slot_no);
                    my $ref_map_acc
                        = $ref_slot_data->{$ref_map_id}{'map_acc'};

                    # Flip the map if the corrs are reversed
                    my @sorted_corrs = sort {
                        (   (   $a->{'feature_start1'} + $a->{'feature_stop1'}
                            ) / 2
                            ) <=> (
                            (   $b->{'feature_start1'} + $b->{'feature_stop1'}
                            ) / 2
                            )
                    } @{ $all_ref_corrs->[0]{'map_corrs'} || [] };
                    my $inc_stack_sub = sub {
                        return (
                            (   (         $_[0]->{'feature_start2'}
                                        + $_[0]->{'feature_stop2'}
                                ) / 2
                            ) < (
                                (         $_[1]->{'feature_start2'}
                                        + $_[1]->{'feature_stop2'}
                                ) / 2
                            )
                        );
                    };
                    my ( $inc_score, undef )
                        = longest_run( \@sorted_corrs, $inc_stack_sub );
                    my $dec_stack_sub = sub {
                        return (
                            (   (         $_[0]->{'feature_start2'}
                                        + $_[0]->{'feature_stop2'}
                                ) / 2
                            ) > (
                                (         $_[1]->{'feature_start2'}
                                        + $_[1]->{'feature_stop2'}
                                ) / 2
                            )
                        );
                    };
                    my ( $dec_score, undef )
                        = longest_run( \@sorted_corrs, $dec_stack_sub );

                    my $ref_is_flipped
                        = $drawer->is_flipped( $ref_slot_no, $ref_map_acc );

                    if (   ( $inc_score > $dec_score and !$ref_is_flipped )
                        or ( $inc_score < $dec_score and $ref_is_flipped ) )
                    {
                        $drawer->set_map_flip( $slot_no,
                            $self->map_acc($map_id), 0 );
                        $flipped_maps_ref->{$map_id} = 0;
                        $is_flipped = 0;
                    }
                    else {
                        $drawer->set_map_flip( $slot_no,
                            $self->map_acc($map_id), 1 );
                        $flipped_maps_ref->{$map_id} = 1;
                        $is_flipped = 1;
                    }

                }
                $first_ref_map = 0;
            }

            # help offset the lines when aggregating multiple evidence types
            my $drawing_offset = 0;
            foreach my $ref_corr (@$all_ref_corrs) {

                #
                # Get the information about the reference map.
                #
                my $ref_pos = $drawer->reference_map_coords( $ref_slot_no,
                    $ref_corr->{'map_id2'} );

                # If this is not a ref map, skip
                next unless ($ref_pos);

                my $evidence_type_acc = $ref_corr->{'evidence_type_acc'};

                # average of corr on ref map
                my $ref_avg_mid = $ref_corr->{'avg_mid2'};

                # average of corr on current map
                my $avg_mid = $ref_corr->{'avg_mid1'};

                my $ref_map_pixel_len = $ref_pos->{'y2'} - $ref_pos->{'y1'};
                my $ref_map_unit_len
                    = $ref_pos->{'map_stop'} - $ref_pos->{'map_start'};

                # Set the avg location of the corr on the ref map
                my $ref_map_mid_y
                    = $ref_pos->{'is_flipped'}
                    ? (
                    $ref_pos->{'y2'} - (
                        ( $ref_avg_mid - $ref_pos->{'map_start'} ) /
                            $ref_map_unit_len
                        ) * $ref_map_pixel_len
                    )
                    : (
                    $ref_pos->{'y1'} + (
                        ( $ref_avg_mid - $ref_pos->{'map_start'} ) /
                            $ref_map_unit_len
                        ) * $ref_map_pixel_len
                    );
                my $ref_map_y1
                    = $ref_pos->{'is_flipped'}
                    ? (
                    $ref_pos->{'y2'} - (
                        (         $ref_corr->{'min_position2'}
                                - $ref_pos->{'map_start'}
                        ) / $ref_map_unit_len
                        ) * $ref_map_pixel_len
                    )
                    : (
                    $ref_pos->{'y1'} + (
                        (         $ref_corr->{'min_position2'}
                                - $ref_pos->{'map_start'}
                        ) / $ref_map_unit_len
                        ) * $ref_map_pixel_len
                    );
                my $ref_map_y2
                    = $ref_pos->{'is_flipped'}
                    ? $ref_pos->{'y2'} + (
                    (   $ref_corr->{'max_position2'} - $ref_pos->{'map_start'}
                    ) / $ref_map_unit_len
                    ) * $ref_map_pixel_len
                    : $ref_pos->{'y1'} + (
                    (   $ref_corr->{'max_position2'} - $ref_pos->{'map_start'}
                    ) / $ref_map_unit_len
                    ) * $ref_map_pixel_len;

                my $ref_map_x
                    = ( $slot_no > 0 )
                    ? ( $ref_pos->{'x2'} + $drawing_offset )
                    : ( $ref_pos->{'x1'} - $drawing_offset );

                # add aggregate correspondences to ref_connections
                if ( $self->aggregate <=> 2 ) {

                    # Single line to avg corr
                    push @{ $map_aggregate_corr->{$map_id} },
                        [
                        $ref_map_x,
                        $ref_map_mid_y,
                        $ref_corr->{'no_corr'},
                        ( $avg_mid - $self->map_start($map_id) ),
                        $evidence_type_acc,
                        ];
                }
                else {
                    my $this_agg_y1 = ( $ref_corr->{'min_position1'}
                            - $self->map_start($map_id) );
                    my $this_agg_y2 = ( $ref_corr->{'max_position1'}
                            - $self->map_start($map_id) );
                    ( $this_agg_y1, $this_agg_y2 )
                        = ( $this_agg_y2, $this_agg_y1 )
                        if ($is_flipped);
                    ( $ref_map_y1, $ref_map_y2 )
                        = ( $ref_map_y2, $ref_map_y1 )
                        if ( $ref_map_y1 > $ref_map_y2 );

                    # V showing span of corrs
                    push @{ $map_aggregate_corr->{$map_id} },
                        [
                        $ref_map_x,             $ref_map_y1,
                        $ref_corr->{'no_corr'}, $this_agg_y1,
                        $evidence_type_acc,
                        ];
                    push @{ $map_aggregate_corr->{$map_id} },
                        [
                        $ref_map_x,             $ref_map_y2,
                        $ref_corr->{'no_corr'}, $this_agg_y2,
                        $evidence_type_acc,
                        ];
                }

                #
                # Center map around ref_map_mid_y
                #
                if ( not $placed ) {

                  # This places the map in relation to the first reference map
                    my $map_unit_len = $self->map_length($map_id);
                    my $map_start    = $self->map_start($map_id);
                    my $rstart = ( $avg_mid - $map_start ) / $map_unit_len;
                    $min_ref_y = $ref_map_mid_y - ( $pixel_height * $rstart );
                    $max_ref_y = $ref_map_mid_y
                        + ( $pixel_height * ( 1 - $rstart ) );
                    $top_boundary = $ref_pos->{'y1'} - $top_boundary_offset;
                    $bottom_boundary
                        = $ref_pos->{'y2'} + $bottom_boundary_offset;
                    $placed = 1;
                }
                $drawing_offset += 5;
            }
        }

        unless (%$ref_corrs) {

            #$pixel_height = $drawer->config_data('min_map_pixel_height');
            $min_ref_y = $base_y;
            $max_ref_y = $min_ref_y + $pixel_height;
        }

        $return_y1 = $min_ref_y;
        $return_y2 = $max_ref_y;
        my $temp_hash = $self->enforce_boundaries(
            return_y1       => $return_y1,
            return_y2       => $return_y2,
            top_boundary    => $top_boundary,
            bottom_boundary => $bottom_boundary,
            pixel_height    => $pixel_height,
        );
        $return_y1    = $temp_hash->{'return_y1'};
        $return_y2    = $temp_hash->{'return_y2'};
        $pixel_height = $temp_hash->{'pixel_height'};
        $capped       = $temp_hash->{'capped'};
    }
    else {

        # Ref map
        my $next_to_last_map
            = ( defined($last_map_id)
                and
                $drawer->data_module->ref_maps_equal( $last_map_id, $map_id )
            )
            ? 1
            : 0;
        my $stack_maps = $self->stack_maps ? 1 : 0;
        if ( $stack_maps + $next_to_last_map == 1 ) {

            # either stacked or next to
            # Stack this ref map below the last.

          # Find the lowest point of the last map and place this map below it.
            if ( defined($last_map_id) ) {
                $return_y1 = $map_placement_data->{$last_map_id}{'bounds'}[3]
                    + $y_buffer + 1;
            }
            else {
                $return_y1 = $base_y;
            }
            $return_y2 = $return_y1 + $pixel_height;

        }
        else {

            # This ref map goes next to the last map
            if ( $next_to_last_map and defined($last_map_id) ) {
                $return_y1 = $map_placement_data->{$last_map_id}{'bounds'}[1];
            }
            else {
                $return_y1 = $base_y;
            }
            $return_y2 = $return_y1 + $pixel_height;
        }
    }

    return (
        $return_y1, $return_y2,     $pixel_height,
        $capped,    $stacked_max_y, $is_flipped
    );
}

# ----------------------------------------

=pod

=head2 add_topper

Add the topper to the map.

The toppers are lacc down starting from the top.  The map coords and the bottom
boundary are moved down at the end based on the height of the toppers.

=cut

sub add_topper {

    my ( $self, %args ) = @_;
    my $drawer             = $args{'drawer'};
    my $slot_no            = $args{'slot_no'};
    my $map_id             = $args{'map_id'};
    my $is_compressed      = $args{'is_compressed'};
    my $map_drawing_data   = $args{'map_drawing_data'};
    my $map_placement_data = $args{'map_placement_data'};
    my $map_area_data      = $args{'map_area_data'};
    my $is_flipped         = $args{'is_flipped'};
    my $map_width          = $self->map_width($map_id);

    my $no_features = $self->no_features($map_id);
    my $map_name    = $self->map_name($map_id);
    my $reg_font    = $drawer->regular_font
        or return $self->error( $drawer->error );
    my $font_width          = $reg_font->width;
    my $font_height         = $reg_font->height;
    my $omit_all_area_boxes = ( $drawer->omit_area_boxes >= 2 );

    my $base_x        = $map_placement_data->{$map_id}{'map_coords'}[0];
    my $base_y        = $map_placement_data->{$map_id}{'bounds'}[1];
    my $current_min_y = $base_y;
    my $mid_x         = $base_x + ( $map_width / 2 );

    # The idea is to start at the bottom of the topper
    # and work our way up.  This keeps the map from
    # being nudged downward.

    #
    # Add Buttons
    #

    my $buttons = $self->create_buttons(
        map_id     => $map_id,
        drawer     => $drawer,
        slot_no    => $slot_no,
        is_flipped => $is_flipped,
        buttons    => [
            'map_detail', 'map_matrix', 'flip', 'new_view',
            'map_limit',  'map_delete'
        ],
    );
    if ( scalar(@$buttons) ) {
        my $button_y_buffer = 4;
        my $button_x_buffer = 6;
        my $button_height
            = ( scalar @$buttons )
            ? $font_height + ( $button_y_buffer * 2 )
            : 0;

        #
        # Figure out how much room left-to-right the buttons will take.
        #
        my $buttons_width = 0;
        for my $button (@$buttons) {
            $buttons_width += $font_width * length( $button->{'label'} );
        }
        $buttons_width += $button_x_buffer * ( scalar @$buttons - 1 );

        #
        # Place the buttons.
        #
        $current_min_y -= $button_height;
        my $button_y = $current_min_y;
        my $label_x  = $base_x - $buttons_width / 2;

        for my $button (@$buttons) {
            my $len  = $font_width * length( $button->{'label'} );
            my $end  = $label_x + $len;
            my @area = (
                $label_x - 3,
                $button_y - ( $button_y_buffer / 2 ),
                $end + 1, $button_y + $font_height + ( $button_y_buffer / 2 )
            );
            push @{ $map_drawing_data->{$map_id} },
                [
                STRING,             $reg_font,
                $label_x,           $button_y,
                $button->{'label'}, 'grey'
                ],
                [ RECTANGLE, @area, 'grey' ],;

            $map_placement_data->{$map_id}{'bounds'}[0]
                = $label_x - ( $button_x_buffer / 2 )
                if ( $map_placement_data->{$map_id}{'bounds'}[0]
                > $label_x - ( $button_x_buffer / 2 ) );
            $map_placement_data->{$map_id}{'bounds'}[2]
                = $end + ( $button_x_buffer / 2 )
                if ( $map_placement_data->{$map_id}{'bounds'}[2]
                < $end + ( $button_x_buffer / 2 ) );
            $label_x += $len + $button_x_buffer;

            push @{ $map_area_data->{$map_id} },
                {
                coords => \@area,
                url    => $button->{'url'},
                alt    => $button->{'alt'},
                }
                unless ($omit_all_area_boxes);
        }
    }

    #
    # Indicate total number of features on the map.
    #
    my @map_toppers = ($map_name);
    push @map_toppers, "[$no_features]"
        if ( defined($no_features) and not $self->clean_view );

    # Add toppers.

    for ( my $i = $#map_toppers; $i >= 0; $i-- ) {
        my $topper = $map_toppers[$i];
        my $f_x1   = $mid_x - ( ( length($topper) * $font_width ) / 2 );
        my $f_x2   = $f_x1 + ( length($topper) * $font_width );

        $current_min_y -= ( $font_height + 4 );
        my $topper_y = $current_min_y;

        my @topper_bounds = (
            $f_x1, $topper_y, $f_x2,
            $topper_y + ( $font_height * ( scalar @map_toppers - $i ) ) - 4
        );
        my $map             = $self->map($map_id);
        my $map_details_url = DEFAULT->{'map_details_url'};
        unless ($omit_all_area_boxes) {
            my $buttons = $self->create_buttons(
                map_id     => $map_id,
                drawer     => $drawer,
                slot_no    => $slot_no,
                is_flipped => $is_flipped,
                buttons    => [ 'map_detail', ],
            );
            my $url  = $buttons->[0]{'url'};
            my $alt  = $buttons->[0]{'alt'};
            my $code = '';
            eval $self->map_type_data( $map->{'map_type_acc'}, 'area_code' );
            push @{ $map_area_data->{$map_id} },
                {
                coords => \@topper_bounds,
                url    => $url,
                alt    => $alt,
                code   => $code,
                };
        }

        $map_placement_data->{$map_id}{'bounds'}[0] = $f_x1
            if ( $map_placement_data->{$map_id}{'bounds'}[0] > $f_x1 );
        $map_placement_data->{$map_id}{'bounds'}[2] = $f_x2
            if ( $map_placement_data->{$map_id}{'bounds'}[2] < $f_x2 );

        push @{ $map_drawing_data->{$map_id} },
            [ STRING, $reg_font, $f_x1, $topper_y, $topper, 'black' ];
    }

    # If this is the reference slot, move map down by the height of the topper
    # because the reference maps can be moved about vertically.  This makes
    # sure that if they are stacked vertically, the topper doesn't cause an
    # overlap (and make the maps off set).
    if ( $slot_no == 0 ) {
        my $topper_offset = 1 + $base_y - $current_min_y;
        $drawer->offset_drawing_data(
            offset_y     => $topper_offset,
            drawing_data => $map_drawing_data->{$map_id},
        );
        $drawer->offset_map_area_data(
            offset_y      => $topper_offset,
            map_area_data => $map_area_data->{$map_id},
        );
        $map_placement_data->{$map_id}{'map_coords'}[1] += $topper_offset;
        $map_placement_data->{$map_id}{'map_coords'}[3] += $topper_offset;
    }
    else {

        # Other slots, just need their top reset
        $map_placement_data->{$map_id}{'bounds'}[1] = $current_min_y
            if (
            $map_placement_data->{$map_id}{'bounds'}[1] > $current_min_y );
    }
}

# ----------------------------------------

=pod

=head2 add_capped_mark

Add astrisks to the map if it was capped

=cut

sub add_capped_mark {

    my ( $self, %args ) = @_;
    my $drawer             = $args{'drawer'};
    my $map_id             = $args{'map_id'};
    my $map_area_data      = $args{'map_area_data'};
    my $drawing_data       = $args{'drawing_data'};
    my $capped             = $args{'capped'};
    my $map_placement_data = $args{'map_placement_data'};

    my $omit_all_area_boxes = ( $drawer->omit_area_boxes >= 2 );
    my $reg_font            = $drawer->regular_font
        or return $self->error( $drawer->error );
    my $font_width  = $reg_font->width;
    my $font_height = $reg_font->height;
    my $map_coords  = $map_placement_data->{$map_id}{'map_coords'};
    if ( $capped == 1 or $capped == 3 ) {    #top capped
                                             # Draw asterisk
        my ( $x1, $y1, $x2, $y2 ) = (
            $map_coords->[2] + 2,
            $map_coords->[1],
            $map_coords->[2] + 2 + $font_width,
            $map_coords->[1] + $font_height
        );
        push @$drawing_data, [ STRING, $reg_font, $x1, $y1, '*', 'red' ];

        # add map over to identify what it means
        push @$map_area_data,
            {
            coords => [ $x1, $y1, $x2, $y2 ],
            url    => '',
            alt    => 'Size Capped',
            }
            unless ($omit_all_area_boxes);
        $map_placement_data->{$map_id}{'bounds'}[2] = $x2
            if ( $map_placement_data->{$map_id}{'bounds'}[2] < $x2 );
    }
    if ( $capped >= 2 ) {    #bottom capped
                             # Draw asterisk
        my ( $x1, $y1, $x2, $y2 ) = (
            $map_coords->[2] + 2,
            $map_coords->[3] - $font_height,
            $map_coords->[2] + 2 + $font_width,
            $map_coords->[3]
        );
        push @$drawing_data, [ STRING, $reg_font, $x1, $y1, '*', 'red' ];

        # add map over to identify what it means
        push @$map_area_data,
            {
            coords => [ $x1, $y1, $x2, $y2 ],
            url    => '',
            alt    => 'Size Capped',
            }
            unless ($omit_all_area_boxes);
        $map_placement_data->{$map_id}{'bounds'}[2] = $x2
            if ( $map_placement_data->{$map_id}{'bounds'}[2] < $x2 );
    }
}

# ----------------------------------------------------------
sub enforce_boundaries {

    #
    # enforce the boundaries of maps
    #
    my ( $self, %args ) = @_;
    my $return_y1       = $args{'return_y1'};
    my $return_y2       = $args{'return_y2'};
    my $top_boundary    = $args{'top_boundary'};
    my $bottom_boundary = $args{'bottom_boundary'};
    my $capped          = 0;
    my $pixel_height    = $args{'pixel_height'};

    if ( $return_y1 < $top_boundary ) {
        $capped = 1;
        $pixel_height -= ( $top_boundary - $return_y1 );
        $return_y1 = $top_boundary;
    }
    if ( $return_y2 > $bottom_boundary ) {
        $capped += 2;
        $pixel_height -= $return_y2 - $bottom_boundary;
        $return_y2 = $bottom_boundary;
    }
    return {
        return_y1    => $return_y1,
        return_y2    => $return_y2,
        pixel_height => $pixel_height,
        capped       => $capped,
    };
}

# ---------------------------------------------------
sub add_tick_marks {

    my ( $self, %args ) = @_;
    my $map_coords        = $args{'map_coords'};
    my $bounds            = $args{'bounds'};
    my $drawer            = $args{'drawer'};
    my $map_id            = $args{'map_id'};
    my $slot_no           = $args{'slot_no'};
    my $drawing_data      = $args{'drawing_data'};
    my $map_area_data     = $args{'map_area_data'};
    my $pixel_height      = $args{'pixel_height'};
    my $is_flipped        = $args{'is_flipped'};
    my $map_start         = $self->map_start($map_id);
    my $actual_map_length = $args{'actual_map_length'};
    my $map_length        = $args{'map_length'};
    my $map_width         = $self->map_width($map_id);
    my $map_acc           = $self->map_acc($map_id);

    my $omit_all_area_boxes = ( $drawer->omit_area_boxes >= 2 );
    my $label_side          = $drawer->label_side($slot_no);
    my $reg_font            = $drawer->regular_font
        or return $self->error( $drawer->error );
    my $font_width  = $reg_font->width;
    my $font_height = $reg_font->height;
    my $base_x      = $map_coords->[0];
    my $clean_view  = $self->clean_view;

    my $array_ref = $self->tick_mark_interval( $map_id, $pixel_height );
    my ( $interval, $map_scale ) = @$array_ref;
    my $no_intervals = int( $actual_map_length / $interval );
    my $interval_start = int( $map_start / ( 10**( $map_scale - 1 ) ) )
        * ( 10**( $map_scale - 1 ) );
    my $tick_overhang = $clean_view ? 8 : 15;
    my @intervals = map { int( $interval_start + ( $_ * $interval ) ) }
        1 .. $no_intervals;
    my $min_tick_distance = $self->config_data('min_tick_distance') || 40;
    my $last_tick_rel_pos = undef;

    for my $tick_pos (@intervals) {
        my $rel_position = ( $tick_pos - $map_start ) / $map_length;

        # If there isn't enough space, skip this one.
        if (defined($last_tick_rel_pos)
            and ( ( $rel_position * $pixel_height )
                - ( $last_tick_rel_pos * $pixel_height )
                < $min_tick_distance )
            )
        {
            next;
        }

        $last_tick_rel_pos = $rel_position;

        my $y_pos
            = $is_flipped
            ? $map_coords->[3] - ( $pixel_height * $rel_position )
            : $map_coords->[1] + ( $pixel_height * $rel_position );

        my $tick_start
            = $label_side eq RIGHT
            ? $base_x - $tick_overhang
            : $base_x;

        my $tick_stop
            = $label_side eq RIGHT
            ? $base_x + $map_width
            : $base_x + $map_width + $tick_overhang;

        push @$drawing_data,
            [ LINE, $tick_start, $y_pos, $tick_stop, $y_pos, 'grey' ];

        unless ($clean_view) {

            # If not clean view, show the crop arrows.
            my $clip_arrow_color   = 'grey';
            my $clip_arrow_width   = 6;
            my $clip_arrow_y1_down = $y_pos + 2;
            my $clip_arrow_y1_up   = $y_pos - 2;
            my $clip_arrow_y2_down = $clip_arrow_y1_down + 3;
            my $clip_arrow_y2_up   = $clip_arrow_y1_up - 3;
            my $clip_arrow_y3_down = $clip_arrow_y2_down + 5;
            my $clip_arrow_y3_up   = $clip_arrow_y2_up - 5;
            my $clip_arrow_x1
                = $label_side eq LEFT
                ? $tick_stop - $clip_arrow_width
                : $tick_start;
            my $clip_arrow_x2   = $clip_arrow_x1 + $clip_arrow_width;
            my $clip_arrow_xmid = ( $clip_arrow_x1 + $clip_arrow_x2 ) / 2;

            # First line across
            push @$drawing_data,
                [
                LINE,           $clip_arrow_x1,      $clip_arrow_y1_down,
                $clip_arrow_x2, $clip_arrow_y1_down, $clip_arrow_color
                ];
            push @$drawing_data,
                [
                LINE,           $clip_arrow_x1,    $clip_arrow_y1_up,
                $clip_arrow_x2, $clip_arrow_y1_up, $clip_arrow_color
                ];

            # line to arrow
            push @$drawing_data,
                [
                LINE,             $clip_arrow_xmid,    $clip_arrow_y1_down,
                $clip_arrow_xmid, $clip_arrow_y2_down, $clip_arrow_color
                ];
            push @$drawing_data,
                [
                LINE,             $clip_arrow_xmid,  $clip_arrow_y1_up,
                $clip_arrow_xmid, $clip_arrow_y2_up, $clip_arrow_color
                ];

            # base of arrow
            push @$drawing_data,
                [
                LINE,           $clip_arrow_x1,      $clip_arrow_y2_down,
                $clip_arrow_x2, $clip_arrow_y2_down, $clip_arrow_color
                ];
            push @$drawing_data,
                [
                LINE,           $clip_arrow_x1,    $clip_arrow_y2_up,
                $clip_arrow_x2, $clip_arrow_y2_up, $clip_arrow_color
                ];

            # left side of arrow
            push @$drawing_data,
                [
                LINE,             $clip_arrow_x1,      $clip_arrow_y2_down,
                $clip_arrow_xmid, $clip_arrow_y3_down, $clip_arrow_color
                ];
            push @$drawing_data,
                [
                LINE,             $clip_arrow_x1,    $clip_arrow_y2_up,
                $clip_arrow_xmid, $clip_arrow_y3_up, $clip_arrow_color
                ];

            # right side of arrow
            push @$drawing_data,
                [
                LINE,             $clip_arrow_x2,      $clip_arrow_y2_down,
                $clip_arrow_xmid, $clip_arrow_y3_down, $clip_arrow_color
                ];
            push @$drawing_data,
                [
                LINE,             $clip_arrow_x2,    $clip_arrow_y2_up,
                $clip_arrow_xmid, $clip_arrow_y3_up, $clip_arrow_color
                ];

            # fill arrows
            push @$drawing_data,
                [
                FILL,                    $clip_arrow_xmid,
                $clip_arrow_y2_down + 1, $clip_arrow_color
                ];
            push @$drawing_data,
                [
                FILL,                  $clip_arrow_xmid,
                $clip_arrow_y2_up - 1, $clip_arrow_color
                ];
            my $down_command = $is_flipped ? '1' : '0';
            my $up_command   = $is_flipped ? '0' : '1';
            my $slot_info = $drawer->data_module->slot_info->{$slot_no};

            # The crop buttons just need to have the value of the current
            # $tick_pos.  All they do then is specify if that value is
            # the start or stop.  This is reversed for a flipped map.
            my ( $up_session_mod_str, $down_session_mod_str );
            my $session_mod_info_str = "=$slot_no=$map_acc=$tick_pos";
            if ($is_flipped) {
                $up_session_mod_str   = 'start' . $session_mod_info_str;
                $down_session_mod_str = 'stop' . $session_mod_info_str;
            }
            else {
                $up_session_mod_str   = 'stop' . $session_mod_info_str;
                $down_session_mod_str = 'start' . $session_mod_info_str;
            }
            my $magnification
                = defined( $slot_info->{$map_id}->[4] )
                ? $slot_info->{$map_id}->[4]
                : "'1'";

            my $crop_down_url = $self->create_viewer_link(
                $drawer->create_minimal_link_params(),
                session_mod => $down_session_mod_str,
            );
            my $crop_up_url = $self->create_viewer_link(
                $drawer->create_minimal_link_params(),
                session_mod => $up_session_mod_str,
            );
            my $down_code = qq[ 
                onMouseOver="window.status='crop down';return true" 
                ];
            my $up_code = qq[
                onMouseOver="window.status='crop up';return true" 
                ];
            push @$map_area_data,
                {
                coords => [
                    $clip_arrow_x1, $clip_arrow_y1_down,
                    $clip_arrow_x2, $clip_arrow_y3_down
                ],
                url  => $crop_down_url,
                alt  => 'Show only from here down',
                code => $down_code,
                }
                unless ($omit_all_area_boxes);
            push @$map_area_data,
                {
                coords => [
                    $clip_arrow_x1, $clip_arrow_y3_up,
                    $clip_arrow_x2, $clip_arrow_y1_up
                ],
                url  => $crop_up_url,
                alt  => 'Show only from here up',
                code => $up_code,
                }
                unless ($omit_all_area_boxes);
        }
        my $label_x
            = $label_side eq RIGHT
            ? $tick_start - $font_height - 2
            : $tick_stop + 2;

        #
        # Figure out how many signifigant figures the number needs by
        # going down to the $interval size.
        #
        my $sig_figs
            = $tick_pos
            ? int( '' . ( log( abs($tick_pos) ) / log(10) ) )
            - int( '' . ( log( abs($interval) ) / log(10) ) ) + 1
            : 1;
        my $tick_pos_str = presentable_number( $tick_pos, $sig_figs );
        my $label_y = $y_pos + ( $font_width * length($tick_pos_str) ) / 2;

        push @$drawing_data,
            [
            STRING_UP,     $reg_font, $label_x, $label_y,
            $tick_pos_str, 'grey'
            ];

        my $right = $label_x + $font_height;
        $bounds->[0] = $label_x if $label_x < $bounds->[0];
        $bounds->[2] = $right   if $right > $bounds->[2];
    }
}

# ---------------------------------------------------
sub add_feature_to_map {

    my ( $self, %args ) = @_;
    my $base_x            = $args{'base_x'};
    my $map_base_y        = $args{'map_base_y'};
    my $drawer            = $args{'drawer'};
    my $feature           = $args{'feature'};
    my $map_id            = $args{'map_id'};
    my $slot_no           = $args{'slot_no'};
    my $drawing_data      = $args{'drawing_data'};
    my $map_area_data     = $args{'map_area_data'};
    my $pixel_height      = $args{'pixel_height'};
    my $is_flipped        = $args{'is_flipped'};
    my $map_length        = $args{'map_length'};
    my $rightmostf        = $args{'rightmostf'};
    my $leftmostf         = $args{'leftmostf'};
    my $fcolumns          = $args{'fcolumns'};
    my $feature_type_accs = $args{'feature_type_accs'};
    my $drawn_glyphs      = $args{'drawn_glyphs'};
    my $map_start         = $args{'map_start'};
    my $map_width         = $args{'map_width'};
    my $has_corr          = $args{'has_corr'};
    my $is_highlighted    = $args{'is_highlighted'};

    # We are only going to do the things we must before
    # we check to see if this has feature is to be collapsed.
    my $collapse_features = $drawer->collapse_features;

    my $fstart        = $feature->{'feature_start'} || 0;
    my $feature_shape = $feature->{'shape'}         || LINE;
    my $shape_is_triangle = $feature_shape =~ /triangle$/;
    my $fstop = $shape_is_triangle ? undef : $feature->{'feature_stop'};
    $fstop = undef if $fstop < $fstart;

    my $rstart = ( $fstart - $map_start ) / $map_length;
    $rstart = $rstart > 1 ? 1 : $rstart < 0 ? 0 : $rstart;
    my $rstop
        = defined $fstop
        ? ( $fstop - $map_start ) / $map_length
        : undef;
    if ( defined $rstop ) {
        $rstop = $rstop > 1 ? 1 : $rstop < 0 ? 0 : $rstop;
    }

    my $y_pos1
        = $is_flipped
        ? $map_base_y + $pixel_height - ( $pixel_height * $rstart )
        : $map_base_y + ( $pixel_height * $rstart );

    my $y_pos2
        = defined $rstop
        ? $is_flipped
            ? $map_base_y + $pixel_height - ( $pixel_height * $rstop )
            : $map_base_y + ( $pixel_height * $rstop )
        : $y_pos1;

    if ( $is_flipped && defined $y_pos2 ) {
        ( $y_pos2, $y_pos1 ) = ( $y_pos1, $y_pos2 );
    }
    $y_pos2 = $y_pos1 unless defined $y_pos2 && $y_pos2 > $y_pos1;

    if ( $shape_is_triangle || $y_pos2 <= $y_pos1 ) {
        $feature->{'midpoint'} = $fstart;
        $feature->{'mid_y'}    = $y_pos1;
    }
    else {
        $feature->{'midpoint'}
            = ( $fstop > $fstart ) ? ( $fstart + $fstop ) / 2 : $fstart;
        $feature->{'mid_y'} = ( $y_pos1 + $y_pos2 ) / 2;
    }

    my $color
        = $has_corr
        ? $drawer->config_data('feature_correspondence_color') || ''
        : '';
    $color ||= $feature->{'color'}
        || $drawer->config_data('feature_color');
    my @coords = ();
    my $label_y;
    my $label = $feature->{'feature_name'};

    # Execute code written in the config file that can modify the feature
    eval $self->feature_type_data( $feature->{'feature_type_acc'},
        'feature_modification_code' );

    #
    # Here we try to reduce the redundant drawing of glyphs.
    # However, if a feature has a correspondence, we want to
    # make sure to draw it so it will show up highlighted.
    #
    my $glyph_key
        = int($y_pos1)
        . $feature_shape
        . int($y_pos2) . '_'
        . $has_corr . '_'
        . $feature->{'direction'} . '_'
        . $is_highlighted . '_'
        . $color;
    my $draw_this = 1;
    if ( $collapse_features and $drawn_glyphs->{$glyph_key} ) {
        $draw_this = 0;
    }

    # save this value for export
    my $glyph_drawn = $draw_this;
    if ($draw_this) {
        my $omit_area_boxes = $drawer->omit_area_boxes;
        my $reg_font        = $drawer->regular_font
            or return $self->error( $drawer->error );
        my $font_width          = $reg_font->width;
        my $font_height         = $reg_font->height;
        my $label_side          = $drawer->label_side($slot_no);
        my $feature_details_url = DEFAULT->{'feature_details_url'};

        if ( $shape_is_triangle || $y_pos2 <= $y_pos1 ) {
            $label_y = $y_pos1 - $font_height / 2;
        }
        else {
            $label_y
                = ( $y_pos1 + ( $y_pos2 - $y_pos1 ) / 2 ) - $font_height / 2;
        }

        my $tick_overhang = 2;
        my $tick_start    = $base_x - $tick_overhang;
        my $tick_stop     = $base_x + $map_width + $tick_overhang;

        my (@temp_drawing_data);
        if ( $feature_shape eq LINE ) {
            $y_pos1 = ( $y_pos1 + $y_pos2 ) / 2;
            push @temp_drawing_data,
                [ LINE, $tick_start, $y_pos1, $tick_stop, $y_pos1, $color ];

            @coords = ( $tick_start, $y_pos1, $tick_stop, $y_pos1 );
        }
        else {

            my $buffer = 2;
            my $column_index;
            my $glyph = Bio::GMOD::CMap::Drawer::Glyph->new(
                config      => $self->config(),
                data_source => $self->data_source(),
            );
            my $feature_glyph = $feature_shape;
            $feature_glyph =~ s/-/_/g;
            if ( $glyph->can($feature_glyph) ) {
                if ( not $glyph->allow_glyph_overlap($feature_glyph) ) {
                    my $adjusted_low  = $y_pos1 - $map_base_y;
                    my $adjusted_high = $y_pos2 - $map_base_y;
                    $column_index = simple_column_distribution(
                        low        => $adjusted_low,
                        high       => $adjusted_high,
                        columns    => $fcolumns,
                        map_height => $pixel_height,
                        buffer     => $buffer,
                    );
                }
                else {
                    $column_index = 0;
                }

                $feature->{'column'} = $column_index;
                my $offset = ( $column_index + 1 ) * 7;
                my $vert_line_x1
                    = $label_side eq RIGHT ? $tick_start : $tick_stop;
                my $vert_line_x2
                    = $label_side eq RIGHT
                    ? $tick_stop + $offset
                    : $tick_start - $offset;

                ###DEBUGING
                #push @temp_drawing_data,
                #[ LINE, $vert_line_x1, $y_pos1,
                #    $vert_line_x2, $y_pos2, 'blue', ];

                @coords = @{
                    $glyph->$feature_glyph(
                        drawing_data     => \@temp_drawing_data,
                        x_pos2           => $vert_line_x2,
                        x_pos1           => $vert_line_x1,
                        y_pos1           => $y_pos1,
                        y_pos2           => $y_pos2,
                        color            => $color,
                        is_flipped       => $is_flipped,
                        direction        => $feature->{'direction'},
                        name             => $feature->{'feature_name'},
                        label_side       => $label_side,
                        calling_obj      => $self,
                        feature          => $feature,
                        drawer           => $drawer,
                        feature_type_acc => $feature->{'feature_type_acc'},
                    )
                    };
                if ( !$omit_area_boxes and @coords ) {
                    my $code = '';
                    my $url
                        = $feature_details_url . $feature->{'feature_acc'};
                    my $alt
                        = 'Feature Details: '
                        . $feature->{'feature_name'} . ' ['
                        . $feature->{'feature_acc'} . ']';
                    eval $self->feature_type_data(
                        $feature->{'feature_type_acc'}, 'area_code' );
                    push @$map_area_data,
                        {
                        coords => \@coords,
                        url    => $url,
                        alt    => $alt,
                        code   => $code,
                        };
                }
            }
            else {
                return $self->error("Can't draw shape '$feature_glyph'");
            }

        }

        push @$drawing_data, @temp_drawing_data;

        #
        # Register that we saw this type of feature.
        #
        $feature_type_accs->{ $feature->{'feature_type_acc'} } = 1;

        ####
        my ( $left_side, $right_side );
        my $buffer = 2;
        $left_side  = $coords[0] - $buffer;
        $right_side = $coords[2] + $buffer;
        $leftmostf  = $left_side unless defined $leftmostf;
        $rightmostf = $right_side unless defined $rightmostf;
        $leftmostf  = $left_side if $left_side < $leftmostf;
        $rightmostf = $right_side if $right_side > $rightmostf;

        ###Save the corrds and label_y so if there is another
        ### that's collapsed it can use those for its own label
        $drawn_glyphs->{$glyph_key} = [ \@coords, $label_y ];
    }
    else {
        ###Collapsed feature still needs coorect labeling info
        @coords  = @{ $drawn_glyphs->{$glyph_key}->[0] };
        $label_y = $drawn_glyphs->{$glyph_key}->[1];
    }
    return ( $leftmostf, $rightmostf, \@coords, $color, $label_y,
        $glyph_drawn );
}

# ----------------------------------------------------
sub add_to_features_with_corr {

    my ( $self, %args ) = @_;

    my $coords             = $args{'coords'};
    my $feature            = $args{'feature'};
    my $features_with_corr = $args{'features_with_corr'};
    my $has_corr           = $args{'has_corr'}, my $map_id = $args{'map_id'};
    my $slot_no            = $args{'slot_no'};
    my $is_flipped         = $args{'is_flipped'};

    if ($has_corr) {
        my $mid_feature
            = $coords->[1] + ( ( $coords->[3] - $coords->[1] ) / 2 );
        my $y1 = $coords->[1];
        my $y2 = $coords->[3];
        if ($feature->{'direction'}
            and (  ( $feature->{'direction'} < 0 and !$is_flipped )
                or ( $feature->{'direction'} > 0 and $is_flipped ) )
            )
        {
            ( $y1, $y2 ) = ( $y2, $y1 );
        }

        $features_with_corr->{ $feature->{'feature_id'} } = {
            feature_id => $feature->{'feature_id'},
            slot_no    => $slot_no,
            map_id     => $map_id,
            left       => [ $coords->[0], $mid_feature ],
            right      => [ $coords->[2], $mid_feature ],
            y1         => $y1,
            y2         => $y2,
            tick_y     => $mid_feature,
        };
    }
}

# ----------------------------------------------------
sub collect_labels_to_display {

    my ( $self, %args ) = @_;

    my $color          = $args{'color'};
    my $coords         = $args{'coords'};
    my $drawer         = $args{'drawer'};
    my $even_labels    = $args{'even_labels'};
    my $feature        = $args{'feature'};
    my $has_corr       = $args{'has_corr'};
    my $is_highlighted = $args{'is_highlighted'};
    my $label_y        = $args{'label_y'};
    my $map_base_y     = $args{'map_base_y'};
    my $show_labels    = $args{'show_labels'};

    my $label = $feature->{'feature_name'};

    if ($show_labels
        && (   $has_corr
            || $drawer->label_features eq 'all'
            || $is_highlighted
            || (   $drawer->label_features eq 'landmarks'
                && $feature->{'is_landmark'} )
        )
        )
    {

        my $even_label_key
            = $is_highlighted ? 'highlights'
            : $has_corr       ? 'correspondences'
            :                   'normal';
        push @{ $even_labels->{$even_label_key} },
            {
            feature        => $feature,
            text           => $label,
            target         => $label_y,
            map_base_y     => $map_base_y,
            color          => $color,
            is_highlighted => $is_highlighted,
            feature_coords => $coords,
            has_corr       => $has_corr,
            };
    }

}

# ----------------------------------------------------
sub add_labels_to_map {

    # Labels moving north
    # must be reverse sorted by start position;  moving south,
    # they should be in ascending order.
    #
    my ( $self, %args ) = @_;

    my $base_x      = $args{'base_x'};
    my $base_y      = $args{'base_y'};
    my $even_labels = $args{'even_labels'};

    my $drawer             = $args{'drawer'};
    my $rightmostf         = $args{'rightmostf'};
    my $leftmostf          = $args{'leftmostf'};
    my $map_id             = $args{'map_id'};
    my $slot_no            = $args{'slot_no'};
    my $drawing_data       = $args{'drawing_data'};
    my $map_area_data      = $args{'map_area_data'};
    my $features_with_corr = $args{'features_with_corr'};
    my $max_x              = $args{'max_x'};
    my $min_x              = $args{'min_x'};
    my $top_y              = $args{'top_y'};
    my $bottom_y           = $args{'bottom_y'};
    my $min_y              = $args{'min_y'};
    my $pixel_height       = $args{'pixel_height'};
    my $stack_rel_maps     = $args{'stack_rel_maps'};

    my $omit_area_boxes = $drawer->omit_area_boxes();
    my $label_side      = $drawer->label_side($slot_no);
    my $reg_font        = $drawer->regular_font
        or return $self->error( $drawer->error );
    my $font_width  = $reg_font->width;
    my $font_height = $reg_font->height;
    my $feature_highlight_fg_color
        = $drawer->config_data('feature_highlight_fg_color');
    my $feature_highlight_bg_color
        = $drawer->config_data('feature_highlight_bg_color');
    my $feature_details_url = DEFAULT->{'feature_details_url'};

    #my @accepted_labels;    # the labels we keep
    my $buffer = 2;    # the space between things

    my $accepted_labels = even_label_distribution(
        labels     => $even_labels,
        map_height => $stack_rel_maps
        ? $pixel_height - $font_height
        : $pixel_height,
        font_height => $font_height,
        start_y     => $base_y,
    );
    my $label_offset = 20;
    $base_x
        = $label_side eq RIGHT
        ? $rightmostf > $base_x
            ? $rightmostf
            : $base_x
        : $leftmostf < $base_x ? $leftmostf
        :                        $base_x;

    for my $label (@$accepted_labels) {
        my $text      = $label->{'text'};
        my $feature   = $label->{'feature'};
        my $label_y   = $label->{'y'};
        my $label_len = $font_width * length($text);
        my $label_x
            = $label_side eq RIGHT
            ? $base_x + $label_offset
            : $base_x - ( $label_offset + $label_len );
        my $label_end = $label_x + $label_len;
        my $color     = $label->{'color'};

        push @$drawing_data,
            [ STRING, $reg_font, $label_x, $label_y, $text, $color ];

        my @label_bounds = (
            $label_x - $buffer,
            $label_y,
            $label_end + $buffer,
            $label_y + $font_height,
        );

        $leftmostf = $label_bounds[0] if $label_bounds[0] < $leftmostf;
        $rightmostf = $label_bounds[2]
            if $label_bounds[2] > $rightmostf;

        #
        # Highlighting.
        #
        if ( $label->{'is_highlighted'} ) {
            push @$drawing_data,
                [ RECTANGLE, @label_bounds, $feature_highlight_fg_color ];

            push @$drawing_data,
                [ FILLED_RECT, @label_bounds, $feature_highlight_bg_color,
                0 ];
        }

        my $code = '';
        my $url  = $feature_details_url . $feature->{'feature_acc'};
        my $alt
            = 'Feature Details: '
            . $feature->{'feature_name'} . ' ['
            . $feature->{'feature_acc'} . ']';
        eval $self->feature_type_data( $feature->{'feature_type_acc'},
            'area_code' );
        push @$map_area_data,
            {
            coords => \@label_bounds,
            url    => $url,
            alt    => $alt,
            code   => $code,
            }
            unless ($omit_area_boxes);

        $min_x    = $label_bounds[0] if $label_bounds[0] < $min_x;
        $top_y    = $label_bounds[1] if $label_bounds[1] < $top_y;
        $max_x    = $label_bounds[2] if $label_bounds[2] > $max_x;
        $bottom_y = $label_bounds[3] if $label_bounds[3] > $bottom_y;
        $min_y    = $label_y         if $label_y < $min_y;

        #
        # Now connect the label to the middle of the feature.
        #
        my @coords = @{ $label->{'feature_coords'} || [] };
        my $label_connect_x1
            = $label_side eq RIGHT
            ? $coords[2]
            : $label_end + $buffer;

        my $label_connect_y1
            = $label_side eq RIGHT
            ? $feature->{'mid_y'}
            : $label_y + $font_height / 2;

        my $label_connect_x2
            = $label_side eq RIGHT
            ? $label_x - $buffer
            : $coords[0];

        my $label_connect_y2
            = $label_side eq RIGHT
            ? $label_y + $font_height / 2
            : $feature->{'mid_y'};

        #
        # Back the connection off.
        #
        if ( $feature->{'shape'} eq LINE ) {
            if ( $label_side eq RIGHT ) {
                $label_connect_x1 += $buffer;
            }
            else {
                $label_connect_x2 -= $buffer;
            }
        }

        push @{$drawing_data}, $drawer->add_connection(
            x1       => $label_connect_x1,
            y1       => $label_connect_y1,
            x2       => $label_connect_x2,
            y2       => $label_connect_y2,
            same_map => 0,

            #label_side  => $position_set->{'label_side'} || '',
            line_type   => 'direct',
            feature1_ys => [ $label_connect_y1, $label_connect_y1 ],
            feature2_ys => [ $label_connect_y2, $label_connect_y2 ],
            line_color  => 'black',
        );

        #
        # If the feature got a label, then update the right
        # or left connection points for linking up to
        # corresponding features.
        #
        if ( defined $features_with_corr->{ $feature->{'feature_id'} } ) {
            if ( $label_side eq RIGHT ) {
                $features_with_corr->{ $feature->{'feature_id'} }{'right'} = [
                    $label_bounds[2],
                    (   $label_bounds[1]
                            + ( $label_bounds[3] - $label_bounds[1] ) / 2
                    )
                ];
            }
            else {
                $features_with_corr->{ $feature->{'feature_id'} }{'left'} = [
                    $label_bounds[0],
                    (   $label_bounds[1]
                            + ( $label_bounds[3] - $label_bounds[1] ) / 2
                    )
                ];
            }
        }
    }

    $min_x = $leftmostf  if $leftmostf < $min_x;
    $max_x = $rightmostf if $rightmostf > $max_x;

    return ( $base_x, $leftmostf, $rightmostf, $max_x, $min_x, $top_y,
        $bottom_y, $min_y );

}

# ----------------------------------------------------
sub map_ids {

=pod

=head2 map_ids

Returns the all the map IDs sorted 

=cut

    my $self    = shift;
    my $slot_no = $self->slot_no;
    my $drawer  = $self->drawer;

    return @{ $drawer->data_module->sorted_map_ids($slot_no) || [] };
}

# ----------------------------------------------------
sub map {

=pod

=head2 map

Returns one map.

=cut

    my $self = shift;
    my $map_id = shift or return;
    return $self->{'maps'}{$map_id};
}

# ----------------------------------------------------
sub maps {

=pod

=head2 maps

Gets/sets all the maps.

=cut

    my $self = shift;
    $self->{'maps'} = shift if @_;
    return $self->{'maps'};
}

# ----------------------------------------------------
sub map_length {

=pod

=head2 map_length

Returns the map's length (stop - start).

=cut

    my $self = shift;
    my $map_id = shift or return;

    return $self->map_stop($map_id) - $self->map_start($map_id);
}

# ----------------------------------------------------
sub map_width {

=pod

=head2 map_width

Returns a string describing how to draw the map.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map($map_id);
    return $map->{'width'}
        || $map->{'default_width'}
        || $self->config_data('map_width');
}

# ----------------------------------------------------
sub real_map_length {

=pod

=head2 real_map_length

Returns the entiry map's length.

=cut

    my $self = shift;
    my $map_id = shift or return;
    return $self->real_map_stop($map_id) - $self->real_map_start($map_id);
}

# ----------------------------------------------------
sub real_map_start {

=pod

=head2 real_map_start

Returns a map's start position.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map($map_id);
    return $map->{'map_start'};
}

# ----------------------------------------------------
sub real_map_stop {

=pod

=head2 real_map_stop

Returns a map's stop position.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map($map_id);
    return $map->{'map_stop'};
}

# ----------------------------------------------------
sub slot_no {

=pod

=head2 slot_no

Returns the slot number.

=cut

    my $self = shift;
    return $self->{'slot_no'};
}

# ----------------------------------------------------
sub map_start {

=pod

=head2 map_start

Returns a map's start position for the range selected.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map($map_id);
    return $map->{'map_start'};
}

# ----------------------------------------------------
sub map_stop {

=pod

=head2 map_stop

Returns a map's stop position for the range selected.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map($map_id);
    return $map->{'map_stop'};
}

# ----------------------------------------------------
sub tick_mark_interval {

=pod

=head2 tick_mark_interval

Returns the map's tick mark interval.

=cut

    my $self         = shift;
    my $map_id       = shift or return;
    my $pixel_height = shift or return;
    my $map          = $self->map($map_id);

    unless ( defined $map->{'tick_mark_interval'} ) {
        my $map_length = $self->map_stop($map_id) - $self->map_start($map_id);

        # If map length == 0, set scale to 1
        # Contributed by David Shibeci
        if ($map_length) {
            my $map_scale = int( log( abs($map_length) ) / log(10) );
            push @{ $map->{'tick_mark_interval'} },
                ( 10**( $map_scale - 1 ), $map_scale );
        }
        else {

            # default tick_mark_interval for maps of length 0
            push @{ $map->{'tick_mark_interval'} }, ( 1, 1 );
        }
    }

    return $map->{'tick_mark_interval'};
}

# ---------------------------------------------------
sub create_buttons {

=pod

=head2 create_button

Returns button definitions in an arrayref.

Returns empty arrayref if clean_view is true.

Button options:

 map_set_info
 map_detail
 set_matrix
 map_matrix
 map_delete
 map_limit
 delete
 flip
 new_view

=cut

    my ( $self, %args ) = @_;
    my $map_id        = $args{'map_id'};
    my $drawer        = $args{'drawer'};
    my $slot_no       = $args{'slot_no'};
    my $is_flipped    = $args{'is_flipped'};
    my $buttons_array = $args{'buttons'};

    return [] if $self->clean_view;

    my %requested_buttons;
    foreach my $button (@$buttons_array) {
        $requested_buttons{$button} = 1;
    }

    # Specify the base urls
    my $map_viewer_url   = 'viewer';
    my $map_details_url  = 'map_details';
    my $map_set_info_url = 'map_set_info';

    my @map_buttons;
    my %this_map_info;

    my $slots = $drawer->slots;

    #
    # Buttons
    #

    my $ref_map = $slots->{0} or next;
    my $ref_map_accs_hash = $ref_map->{'maps'};

    #
    # Map Set Info
    #
    if ( $requested_buttons{'map_set_info'} ) {
        @map_buttons = (
            {   url => $map_set_info_url
                    . '?map_set_acc='
                    . $self->map_set_acc($map_id)
                    . ';data_source='
                    . $drawer->data_source,
                alt   => 'Map Set Info',
                label => 'i',
            }
        );
    }

    #
    # Map details button.
    #
    if ( $requested_buttons{'map_detail'} ) {
        my $slots = $drawer->slots;

        my %detail_maps;
        for my $side (qw[ left right ]) {
            my $next_slot_no = $side eq 'left' ? $slot_no - 1 : $slot_no + 1;
            my $new_slot_no  = $side eq 'left' ? -1           : 1;
            $detail_maps{$new_slot_no} = $slots->{$next_slot_no};
        }

        unless (%this_map_info) {
            $this_map_info{ $self->map_acc($map_id) } = {
                start => $self->map_start($map_id),
                stop  => $self->map_stop($map_id),
                mag =>
                    $drawer->data_module->magnification( $slot_no, $map_id ),
            };
        }

        my $details_url = $self->create_viewer_link(
            $drawer->create_minimal_link_params(),
            ref_map_set_acc  => $self->map_set_acc($map_id),
            ref_map_accs     => \%this_map_info,
            ref_map_order    => '',
            comparative_maps => \%detail_maps,
            base_url         => $map_details_url,
            new_session      => 1,
        );

        push @map_buttons,
            {
            label => '?',
            url   => $details_url,
            alt   => 'Map Details: ' . $self->map_name($map_id),
            },
            ;
    }

    #
    # Matrix buttons
    #
    if ( $requested_buttons{'set_matrix'} ) {
        push @map_buttons,
            {
            label => 'M',
            url   => 'matrix?&show_matrix=1'
                . '&link_map_set_acc='
                . $self->map_set_acc($map_id),
            alt => 'View In Matrix'
            };
    }
    if ( $requested_buttons{'map_matrix'} ) {
        push @map_buttons,
            {
            label => 'M',
            url   => 'matrix?map_type_acc='
                . $self->map_type_acc($map_id)
                . '&species_acc='
                . $self->species_acc($map_id)
                . '&map_set_acc='
                . $self->map_set_acc($map_id)
                . '&map_name='
                . $self->map_name($map_id)
                . '&show_matrix=1',
            alt => 'View In Matrix'
            };
    }

    #
    # Map Set Delete button.
    # will only create if not slot 0
    #
    if ( $requested_buttons{'delete'} ) {
        if ( $slot_no != 0 ) {
            my $delete_url = $self->create_viewer_link(
                $drawer->create_minimal_link_params(),
                base_url    => $map_viewer_url,
                session_mod => "del=$slot_no",
            );

            push @map_buttons,
                {
                label => 'X',
                url   => $delete_url,
                alt   => 'Delete Map Set',
                };
        }
    }

    #
    # Map Delete button.
    # will only create if not slot 0
    #
    if ( $requested_buttons{'map_delete'} ) {
        my $slot_info = $drawer->data_module->slot_info->{$slot_no};
        if ( $slot_info and scalar( keys(%$slot_info) ) > 1 ) {
            my $map_delete_url = $self->create_viewer_link(
                $drawer->create_minimal_link_params(),
                base_url    => $map_viewer_url,
                session_mod => "del=$slot_no=" . $self->map_acc($map_id),
            );

            push @map_buttons,
                {
                label => 'x',
                url   => $map_delete_url,
                alt   => 'Delete Map',
                };
        }
    }

    #
    # Map Limit button.
    # will only create if slot has more than one map in it
    #
    if ( $requested_buttons{'map_limit'} ) {
        my $slot_info = $drawer->data_module->slot_info->{$slot_no};
        if ( $slot_info and scalar( keys(%$slot_info) ) > 1 ) {
            my $map_limit_url = $self->create_viewer_link(
                $drawer->create_minimal_link_params(),
                base_url    => $map_viewer_url,
                session_mod => "limit=$slot_no=" . $self->map_acc($map_id),
            );

            push @map_buttons,
                {
                label => 'L',
                url   => $map_limit_url,
                alt   => 'Limit to this Map',
                };
        }
    }

    #
    # Flip button.
    #
    if ( $requested_buttons{'flip'} ) {
        my @flipping_flips;
        my $acc_id = $self->map_acc($map_id);
        for my $rec ( @{ $drawer->flip } ) {
            unless ( $rec->{'slot_no'} == $slot_no
                && $rec->{'map_acc'} eq $acc_id )
            {
                push @flipping_flips,
                    $rec->{'slot_no'} . '%3d' . $rec->{'map_acc'};
            }
        }
        push @flipping_flips, "$slot_no%3d$acc_id" unless $is_flipped;
        my $flipping_flip_str = q{} . join( ":", @flipping_flips );

        my $flip_url = $self->create_viewer_link(
            $drawer->create_minimal_link_params(),
            flip     => $flipping_flip_str,
            base_url => $map_viewer_url,
        );

        my $flip_label = 'F';
        my $flip_alt   = 'Flip Map';
        if ($is_flipped) {
            $flip_label = 'UF';
            $flip_alt   = 'Unflip Map';
        }
        push @map_buttons,
            {
            label => $flip_label,
            url   => $flip_url,
            alt   => $flip_alt,
            };
    }

    #
    # New View button.
    #
    if ( $requested_buttons{'new_view'} ) {
        unless (%this_map_info) {
            $this_map_info{ $self->map_acc($map_id) } = {
                start => $self->map_start($map_id),
                stop  => $self->map_stop($map_id),
                mag =>
                    $drawer->data_module->magnification( $slot_no, $map_id ),
            };
        }

        my $new_url = $self->create_viewer_link(
            $drawer->create_minimal_link_params(),
            ref_map_set_acc => $self->map_set_acc($map_id),
            ref_map_accs    => \%this_map_info,
            ref_map_order   => '',
            base_url        => $map_viewer_url,
            new_session     => 1,
        );

        push @map_buttons,
            {
            label => 'N',
            url   => $new_url,
            alt   => 'New Map View',
            };
    }
    return \@map_buttons;
}

# ----------------------------------------------------
sub is_compressed {

=pod

=head2 is_compressed

Uses Data.pm to figure out if a map is compressed.

=cut

    my $self    = shift;
    my $slot_no = shift;
    my $drawer  = $self->drawer;

    return $drawer->data_module->compress_maps($slot_no);
}

# ----------------------------------------------------
sub is_stacked {

=pod

=head2 is_stacked

Uses Data.pm to figure out if a map is stacked.

=cut

    my $self    = shift;
    my $slot_no = shift;
    my $drawer  = $self->drawer;

    my $stack_slot_hash = $drawer->stack_slot();
    my @map_ids         = $self->map_ids;
    return (    $slot_no
            and %{ $stack_slot_hash || {} }
            and $stack_slot_hash->{$slot_no}
            and scalar(@map_ids) > 1 );

}

#-----------------------------------------------
sub order_map_ids_based_on_corrs {

=pod

=head2 order_maps_based_on_corrs()

=over 4

=item * Description

Return the map_ids in order

=back

=cut

    my ( $self, %args ) = @_;
    my $drawer      = $args{'drawer'};
    my $map_ids     = $args{'map_ids'} or return ();
    my $slot_no     = $args{'slot_no'} or return ();
    my $ref_slot_no = $drawer->reference_slot_no($slot_no);

    my %map_positions;
MAP_ID:
    foreach my $map_id ( @{ $map_ids || [] } ) {
        my $ref_corrs = $drawer->map_correspondences( $slot_no, $map_id );
    REF_MAP_ID:
        for my $ref_map_id ( sort keys(%$ref_corrs) ) {
            my $all_ref_corrs = $ref_corrs->{$ref_map_id};
            my $position_sum  = 1;
        REF_CORR:
            foreach my $ref_corr (@$all_ref_corrs) {

                #
                # Get the information about the reference map.
                #
                my $ref_pos = $drawer->reference_map_coords( $ref_slot_no,
                    $ref_corr->{'map_id2'} );

                # If this is not a ref map, skip
                next unless ($ref_pos);

                # average of corr on ref map
                my $ref_avg_mid = $ref_corr->{'avg_mid2'};

                my $ref_map_pixel_len = $ref_pos->{'y2'} - $ref_pos->{'y1'};
                my $ref_map_unit_len
                    = $ref_pos->{'map_stop'} - $ref_pos->{'map_start'};

                # Set the avg location of the corr on the ref map
                my $ref_map_mid_y
                    = $ref_pos->{'is_flipped'}
                    ? (
                    $ref_pos->{'y2'} - (
                        ( $ref_avg_mid - $ref_pos->{'map_start'} ) /
                            $ref_map_unit_len
                        ) * $ref_map_pixel_len
                    )
                    : (
                    $ref_pos->{'y1'} + (
                        ( $ref_avg_mid - $ref_pos->{'map_start'} ) /
                            $ref_map_unit_len
                        ) * $ref_map_pixel_len
                    );
                $map_positions{$map_id} = $ref_map_mid_y;
                next MAP_ID;
            }
        }
    }

    return
        sort { $map_positions{$a} <=> $map_positions{$b} }
        @{ $map_ids || [] };
}

# ----------------------------------------------------
sub DESTROY {

=pod

=head2 DESTROY

Break cyclical links.

=cut

    my $self = shift;
    $self->{'drawer'} = undef;
}

1;

# ----------------------------------------------------
# The hours of folly are measur'd by the clock,
# but of wisdom: no clock can measure.
# William Blake
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-7 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

