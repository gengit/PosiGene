package Bio::GMOD::CMap::Drawer::Dotplot;

# vim: set ft=perl:

# $Id: Dotplot.pm,v 1.6 2008/06/27 20:50:30 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Drawer::Dotplot - draw maps 

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Drawer::Dotplot;
  my $drawer = Bio::GMOD::CMap::Drawer::Dotplot( ref_map_id => 12345 );
  $drawer->image_name;

=head1 DESCRIPTION

The Dot plot drawer. See Bio::GMOD::CMap::Drawer for more information.

=head1 Usage

The Dot plot drawer. See Bio::GMOD::CMap::Drawer 

    my $drawer = Bio::GMOD::CMap::Drawer::Dotplot->new(
        %options
    );

=head1 METHODS

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.6 $)[-1];

use Bio::GMOD::CMap::Utils qw[ commify ];
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Data;
use Data::Dumper;
use base 'Bio::GMOD::CMap::Drawer';

# ----------------------------------------------------
sub init {

=pod

=head2 init

Initializes the drawing object.

=cut

    my ( $self, $config ) = @_;

    $self->initialize_params($config);

    $self->dotplot_ps( $config->{'dotplot_ps'} );

    $self->data or return;

    unless ( $self->skip_drawing() ) {

        # Check to make sure the image dir isn't too full.
        return unless $self->img_dir_ok();

        my $gd_class = $self->image_type eq 'svg' ? 'GD::SVG' : 'GD';

        eval "use $gd_class";

        return $self->error(@$) if @$;

        $self->draw_dotplot() or return;
    }

    return $self;
}

# ----------------------------------------------------
sub draw_dotplot {

=pod

=head2 draw

Lays out the image and writes it to the file system, set the "image_name."

=cut

    my $self = shift;

    my $base_x = 0;
    my $base_y = 0;

    my $row_buffer    = 4;
    my $column_buffer = 4;
    my ( @drawing_data, @map_area_data );

    my $omit_all_area_boxes = ( $self->omit_area_boxes == 2 );

    my $ref_slot_no        = 0;
    my $right_comp_slot_no = 1;
    my $left_comp_slot_no  = -1;

    my $ref_slot_data        = $self->slot_data($ref_slot_no);
    my $right_comp_slot_data = $self->slot_data($right_comp_slot_no);
    my $left_comp_slot_data  = $self->slot_data($left_comp_slot_no);

    my @ref_map_ids = @{ $self->data_module()
            ->sorted_map_ids( $ref_slot_no, $ref_slot_data ) };
    my @right_comp_map_ids = @{ $self->data_module()
            ->sorted_map_ids( $right_comp_slot_no, $right_comp_slot_data ) };
    my @left_comp_map_ids = @{ $self->data_module()
            ->sorted_map_ids( $left_comp_slot_no, $left_comp_slot_data ) };

    # Remove any map ids that aren't going to be drawn.
    for ( my $i = 0; $i <= $#right_comp_map_ids; $i++ ) {
        my $map_id = $right_comp_map_ids[$i];
        unless (
            %{  $self->map_correspondences( $right_comp_slot_no, $map_id )
                    || {}
            }
            )
        {
            $self->map_not_displayed( $right_comp_slot_no, $map_id, 1 );
            splice( @right_comp_map_ids, $i, 1 );
            $i--;
        }
    }
    for ( my $i = 0; $i <= $#left_comp_map_ids; $i++ ) {
        my $map_id = $left_comp_map_ids[$i];
        unless (
            %{  $self->map_correspondences( $left_comp_slot_no, $map_id )
                    || {}
            }
            )
        {
            $self->map_not_displayed( $left_comp_slot_no, $map_id, 1 );
            splice( @left_comp_map_ids, $i, 1 );
            $i--;
        }
    }

    # If there aren't any comparative maps with corrs, give the user a msg and
    # quit
    unless ( @right_comp_map_ids or @left_comp_map_ids ) {
        $self->message(
                  "Can't display a dotplot without comparison maps with "
                . "correspondences to the reference maps.<BR>\n"
                . "Please add maps to the left or right of the reference maps."
        );
        $self->draw_image();
        return $self;
    }

    #get the pixels for each map
    my %map_pixels;
    foreach my $map_id (@ref_map_ids) {
        next if $map_pixels{$map_id};
        $map_pixels{$map_id} = $self->get_map_pixel_size(
            slot_no   => $ref_slot_no,
            slot_data => $ref_slot_data,
            map_id    => $map_id,
        );
    }
    foreach my $map_id (@right_comp_map_ids) {
        next if $map_pixels{$map_id};
        $map_pixels{$map_id} = $self->get_map_pixel_size(
            slot_no   => $right_comp_slot_no,
            slot_data => $right_comp_slot_data,
            map_id    => $map_id,
        );
    }
    foreach my $map_id (@left_comp_map_ids) {
        next if $map_pixels{$map_id};
        $map_pixels{$map_id} = $self->get_map_pixel_size(
            slot_no   => $left_comp_slot_no,
            slot_data => $left_comp_slot_data,
            map_id    => $map_id,
        );
    }

    my ( $max_x, $max_y ) = ( $base_x, $base_y );
    my ( $min_x, $min_y ) = ( $base_x, $base_y );

    # Draw the Dot Plots first.
    foreach my $ref_map_id (@ref_map_ids) {
        my $row_base_y = $max_y;
        $max_x = $base_x;
        foreach my $comp_map_id (@left_comp_map_ids) {
            ( $max_x, $max_y ) = $self->draw_map_dotplot(
                base_x         => $max_x,
                base_y         => $row_base_y,
                max_x          => $max_x,
                max_y          => $max_y,
                comp_slot_no   => $left_comp_slot_no,
                comp_map_id    => $comp_map_id,
                comp_slot_data => $left_comp_slot_data,
                comp_map_width => $map_pixels{$comp_map_id},
                ref_map_id     => $ref_map_id,
                ref_slot_data  => $ref_slot_data,
                ref_map_height => $map_pixels{$ref_map_id},
            );
            $max_x += $column_buffer;
        }
        foreach my $comp_map_id (@right_comp_map_ids) {
            ( $max_x, $max_y ) = $self->draw_map_dotplot(
                base_x         => $max_x,
                base_y         => $row_base_y,
                max_x          => $max_x,
                max_y          => $max_y,
                comp_slot_no   => $right_comp_slot_no,
                comp_map_id    => $comp_map_id,
                comp_slot_data => $right_comp_slot_data,
                comp_map_width => $map_pixels{$comp_map_id},
                ref_map_id     => $ref_map_id,
                ref_slot_data  => $ref_slot_data,
                ref_map_height => $map_pixels{$ref_map_id},
            );
            $max_x += $column_buffer;
        }
        $max_y += $row_buffer;
    }
    $self->draw_comp_labels(
        slot_base_y => $base_y - $row_buffer,
        slot_no     => $right_comp_slot_no,
        slot_data   => $right_comp_slot_data,
        map_ids     => \@right_comp_map_ids,
    );
    $self->draw_comp_labels(
        slot_base_y => $base_y - $row_buffer,
        slot_no     => $left_comp_slot_no,
        slot_data   => $left_comp_slot_data,
        map_ids     => \@left_comp_map_ids,
    );

    $self->draw_ref_labels(
        slot_base_x => $base_x - $column_buffer,
        slot_no     => $ref_slot_no,
        slot_data   => $ref_slot_data,
        map_ids     => \@ref_map_ids,
    );

    #
    # Move all the coordinates to positive numbers.
    #
    $self->adjust_frame;

    $self->draw_image();

    return $self;
}

# ----------------------------------------------------
sub get_map_pixel_size {

=pod

=head2 get_map_pixel_size

Get the pixel_size of each map

=cut

    my $self      = shift;
    my %args      = @_;
    my $slot_no   = $args{'slot_no'};
    my $slot_data = $args{'slot_data'};
    my $map_id    = $args{'map_id'};

    return $self->pixel_height();
}

# ----------------------------------------------------
sub dotplot_ps {

=pod

=head2 dotplot_ps

Get/set the dotplot pixel size

=cut

    my $self = shift;
    my $val  = shift;
    if ($val) {
        $self->{'dotplot_ps'} = $val;
    }
    unless ( defined $self->{'dotplot_ps'} ) {
        $self->{'dotplot_ps'} = $self->config_data('dotplot_ps')
            || DEFAULT->{'dotplot_ps'}
            || 1;
    }

    return $self->{'dotplot_ps'};
}

# ----------------------------------------------------
sub draw_comp_labels {

=pod

=head2 draw_comp_labels

Get the pixel_size of each map

=cut

    my $self        = shift;
    my %args        = @_;
    my $slot_base_y = $args{'slot_base_y'};
    my $slot_no     = $args{'slot_no'};
    my $slot_data   = $args{'slot_data'};
    my $map_ids     = $args{'map_ids'};

    my ( @drawing_data, @map_area_data );
    my $slot_min_y = $slot_base_y;

    my $font   = $self->regular_font;
    my $buffer = 4;
    return unless ( @{ $map_ids || [] } and %{ $slot_data || {} } );

    # Draw the Comp map titles
    my $map_base_y = $slot_min_y;
    $slot_min_y -= $buffer;
    foreach my $map_id ( @{ $map_ids || [] } ) {
        $slot_min_y = $self->draw_comp_map_labels(
            map_base_y => $map_base_y,
            min_y      => $slot_min_y,
            slot_no    => $slot_no,
            slot_data  => $slot_data,
            map_id     => $map_id,
        );
    }

    $slot_min_y -= $buffer;

    # Figure out the dimensions of this slot.
    # Use the first and last map in the slot.
    my ( $slot_min_x, $slot_max_x, );
    $slot_min_x = $self->{'comp_plot_bounds_x'}{ $map_ids->[0] }[0];
    $slot_max_x = $self->{'comp_plot_bounds_x'}{ $map_ids->[-1] }[1];
    my $slot_mid_x = int( ( $slot_min_x + $slot_max_x ) / 2 );

    # Since these will be printed in reverse order, start them in reverse
    # order.
    my @map_set_lines;
    push @map_set_lines,
        (
        $slot_data->{ $map_ids->[0] }{'map_set_name'},
        $slot_data->{ $map_ids->[0] }{'species_common_name'},
        );

    #
    # Place the titles.
    #
    for my $label (@map_set_lines) {
        my $length  = $font->width * length($label);
        my $label_x = $slot_mid_x - $length / 2;
        my $end     = $label_x + $length;
        my $label_y = $slot_min_y - $font->height();

        # Make sure it doesn't overlap the beginning
        if ( $label_x < $slot_min_x ) {
            my $offset = $slot_min_x - $label_x;
            $label_x += $offset;
            $end     += $offset;
        }

        push @drawing_data,
            [ STRING, $font, $label_x, $label_y, $label, 'black' ];

        $slot_min_y -= $font->height + $buffer;
    }

    $self->add_drawing(@drawing_data);
    $self->add_map_area(@map_area_data);

    return;
}

# ----------------------------------------------------
sub draw_ref_labels {

=pod

=head2 draw_ref_labels

Similar to draw_comp_labels but this works from the last line to the first as
to make sure there is space for all of the labels.

=cut

    my $self        = shift;
    my %args        = @_;
    my $slot_base_x = $args{'slot_base_x'};
    my $slot_no     = $args{'slot_no'};
    my $slot_data   = $args{'slot_data'} or return;
    my $map_ids     = $args{'map_ids'} or return;

    my ( @drawing_data, @map_area_data );
    my $slot_min_x = $slot_base_x;

    my $font   = $self->regular_font;
    my $buffer = 4;
    return unless ( @{ $map_ids || [] } and %{ $slot_data || {} } );

    # Start by drawing the ref map titles
    my $map_base_x = $slot_min_x;
    foreach my $map_id ( @{ $map_ids || [] } ) {
        $slot_min_x -= $buffer;
        $slot_min_x = $self->draw_ref_map_labels(
            map_base_x => $map_base_x,
            min_x      => $slot_min_x,
            slot_no    => $slot_no,
            slot_data  => $slot_data,
            map_id     => $map_id,
        );
    }

    # Figure out the dimensions of this slot.
    # Use the first and last map in the slot.
    my ( $slot_min_y, $slot_max_y, );
    $slot_min_y = $self->{'ref_plot_bounds_y'}{ $map_ids->[0] }[0];
    $slot_max_y = $self->{'ref_plot_bounds_y'}{ $map_ids->[-1] }[1];
    my $slot_mid_y = int( ( $slot_min_y + $slot_max_y ) / 2 );

    # Since these will be printed in reverse order, start them in reverse
    # order.
    my @map_set_lines;
    push @map_set_lines,
        (
        $slot_data->{ $map_ids->[0] }{'map_set_name'},
        $slot_data->{ $map_ids->[0] }{'species_common_name'},
        );

    #
    # Place the titles.
    #
    for my $label (@map_set_lines) {
        my $length  = $font->width * length($label);
        my $label_y = $slot_mid_y + $length / 2;
        my $end     = $label_y - $length;

        # Make sure it doesn't overlap the beginning
        if ( $label_y > $slot_max_y ) {
            my $offset = $slot_min_x - $label_y;
            $label_y += $offset;
            $end     += $offset;
        }
        my $label_x = $slot_min_x - $font->height();

        push @drawing_data,
            [ STRING_UP, $font, $label_x, $label_y, $label, 'black' ];

        $slot_min_x -= $font->height + $buffer;

    }

    $self->add_drawing(@drawing_data);
    $self->add_map_area(@map_area_data);

    return;
}

# ----------------------------------------------------
sub draw_comp_map_labels {

=pod

=head2 draw_comp_map_labels

Draw the header for a map

=cut

    my $self       = shift;
    my %args       = @_;
    my $map_base_y = $args{'map_base_y'};
    my $min_y      = $args{'min_y'};
    my $slot_no    = $args{'slot_no'};
    my $slot_data  = $args{'slot_data'} or return $min_y;
    my $map_id     = $args{'map_id'} or return $min_y;

    my $map_units = $slot_data->{$map_id}{'map_units'};

    my ( @drawing_data, @map_area_data );

    my $font   = $self->regular_font;
    my $buffer = 4;
    return $min_y unless ( %{ $slot_data || {} } );

    my $map_min_x = $self->{'comp_plot_bounds_x'}{$map_id}[0];
    my $map_max_x = $self->{'comp_plot_bounds_x'}{$map_id}[1];
    my $map_mid_x = int( ( $map_min_x + $map_max_x ) / 2 );

    my ( $start, $stop )
        = $self->data_module->getDisplayedStartStop( $slot_no, $map_id );
    my $start_stop_str
        = commify($start) . "-" . commify($stop) . " " . $map_units;

    # Since these will be printed in reverse order, start them in reverse
    # order.
    my @map_set_lines;
    push @map_set_lines,
        ( $start_stop_str, $slot_data->{$map_id}{'map_name'}, );

    #
    # Place the titles.
    #
    my $map_min_y = $map_base_y;
    for my $label (@map_set_lines) {
        my $length  = $font->width * length($label);
        my $label_x = $map_mid_x - $length / 2;
        my $end     = $label_x + $length;
        my $label_y = $map_min_y - $font->height();

        # Make sure it doesn't overlap the beginning
        if ( $label_x < $map_min_x ) {
            my $offset = $map_min_x - $label_x;
            $label_x += $offset;
            $end     += $offset;
        }

        push @drawing_data,
            [ STRING, $font, $label_x, $label_y, $label, 'black' ];

        $map_min_y -= $font->height + $buffer;
    }

    $self->add_drawing(@drawing_data);
    $self->add_map_area(@map_area_data);

    $min_y = $map_min_y if ( $min_y > $map_min_y );

    return $min_y;
}

# ----------------------------------------------------
sub draw_ref_map_labels {

=pod

=head2 draw_ref_map_labels

Draw the header for a reference map

=cut

    my $self       = shift;
    my %args       = @_;
    my $map_base_x = $args{'map_base_x'};
    my $min_x      = $args{'min_x'};
    my $slot_no    = $args{'slot_no'};
    my $slot_data  = $args{'slot_data'} or return $min_x;
    my $map_id     = $args{'map_id'} or return $min_x;

    my $map_units = $slot_data->{$map_id}{'map_units'};

    my ( @drawing_data, @map_area_data );

    my $font   = $self->regular_font;
    my $buffer = 4;
    return $min_x unless ( %{ $slot_data || {} } );

    my $map_min_y = $self->{'ref_plot_bounds_y'}{$map_id}[0];
    my $map_max_y = $self->{'ref_plot_bounds_y'}{$map_id}[1];
    my $map_mid_y = int( ( $map_min_y + $map_max_y ) / 2 );

    my ( $start, $stop )
        = $self->data_module->getDisplayedStartStop( $slot_no, $map_id );
    my $start_stop_str
        = commify($start) . "-" . commify($stop) . " " . $map_units;

    # Since these will be printed in reverse order, start them in reverse
    # order.
    my @map_set_lines;
    push @map_set_lines,
        ( $start_stop_str, $slot_data->{$map_id}{'map_name'}, );

    #
    # Place the titles.
    #
    my $map_min_x = $map_base_x;
    for my $label (@map_set_lines) {
        my $length  = $font->width * length($label);
        my $label_y = $map_mid_y + $length / 2;
        my $end     = $label_y - $length;
        my $label_x = $map_min_x - $font->height();

        # Make sure it doesn't overlap the beginning
        if ( $label_y < $map_min_y ) {
            my $offset = $map_min_y - $label_y;
            $label_y += $offset;
            $end     += $offset;
        }

        push @drawing_data,
            [ STRING_UP, $font, $label_x, $label_y, $label, 'black' ];

        $map_min_x -= $font->height + $buffer;
    }

    $self->add_drawing(@drawing_data);
    $self->add_map_area(@map_area_data);

    $min_x = $map_min_x if ( $min_x > $map_min_x );

    return $min_x;
}

# ----------------------------------------------------
sub draw_map_dotplot {

=pod

=head2 draw_map_dotplot

Draw the actual dotplot for each map

=cut

    my $self           = shift;
    my %args           = @_;
    my $plot_base_x    = $args{'base_x'};
    my $plot_base_y    = $args{'base_y'};
    my $max_x          = $args{'max_x'};
    my $max_y          = $args{'max_y'};
    my $comp_slot_no   = $args{'comp_slot_no'};
    my $comp_slot_data = $args{'comp_slot_data'} or return ( $max_x, $max_y );
    my $comp_map_id    = $args{'comp_map_id'} or return ( $max_x, $max_y );
    my $comp_map_width = $args{'comp_map_width'};
    my $ref_slot_data  = $args{'ref_slot_data'} or return ( $max_x, $max_y );
    my $ref_map_id     = $args{'ref_map_id'} or return ( $max_x, $max_y );
    my $ref_map_height = $args{'ref_map_height'};
    my $ref_slot_no    = 0;

    my ( @drawing_data, @map_area_data );

    my $min_x         = $plot_base_x;
    my $buffer        = 4;
    my $plot_max_x    = $plot_base_x;
    my $plot_max_y    = $plot_base_y;
    my $dotplot_width = $self->dotplot_ps();

    # Draw left side information here

    # Draw the actual plot
    my $graph_min_x = $plot_max_x;
    my $graph_min_y = $plot_max_y;
    my $graph_max_x = $graph_min_x + $comp_map_width;
    my $graph_max_y = $graph_min_y + $ref_map_height;

    $plot_max_x = $graph_max_x if ( $plot_max_x < $graph_max_x );
    $plot_max_y = $graph_max_y if ( $plot_max_y < $graph_max_y );

    push @drawing_data,
        [
        RECTANGLE,
        ( $graph_min_x, $graph_min_y, $graph_max_x, $graph_max_y, ), 'black'
        ];

    my $comp_to_ref_corrs_hash
        = $self->map_correspondences( $comp_slot_no, $comp_map_id ) || {};
    my $comp_to_ref_corrs_array = $comp_to_ref_corrs_hash->{$ref_map_id};
    if (    $comp_to_ref_corrs_array
        and %{ $ref_slot_data  || {} }
        and %{ $comp_slot_data || {} } )
    {

        my $graphable_area_min_x = $graph_min_x + 1;
        my $graphable_area_min_y = $graph_min_y + 1;
        my $graphable_area_max_x = $graph_max_x - 1;
        my $graphable_area_max_y = $graph_max_y - 1;
        my $graphable_area_height
            = $graphable_area_max_y - $graphable_area_min_y;

        my ( $ref_map_start, $ref_map_stop )
            = $self->data_module->getDisplayedStartStop( $ref_slot_no,
            $ref_map_id, );
        my ( $comp_map_start, $comp_map_stop )
            = $self->data_module->getDisplayedStartStop( $comp_slot_no,
            $comp_map_id, );

        my $ref_factor
            = ($graphable_area_height) / ( $ref_map_stop - $ref_map_start );
        my $comp_factor
            = ($comp_map_width) / ( $comp_map_stop - $comp_map_start );

        foreach my $comp_to_ref_corrs ( @{ $comp_to_ref_corrs_array || [] } )
        {
            foreach $comp_to_ref_corrs (
                @{ $comp_to_ref_corrs->{'map_corrs'} || [] } )
            {
                my $start_y
                    = (
                    $comp_to_ref_corrs->{'feature_start2'} - $ref_map_start )
                    * $ref_factor;
                my $start_x
                    = (
                    $comp_to_ref_corrs->{'feature_start1'} - $comp_map_start )
                    * $comp_factor;
                my $stop_y
                    = (
                    $comp_to_ref_corrs->{'feature_stop2'} - $ref_map_start )
                    * $ref_factor;
                my $stop_x
                    = (
                    $comp_to_ref_corrs->{'feature_stop1'} - $comp_map_start )
                    * $comp_factor;
                if ($dotplot_width) {
                    my @points = $self->bresenham_line(
                        x1 => int $graphable_area_min_x + $start_x,
                        y1 => int $graphable_area_max_y - $start_y,
                        x2 => int $graphable_area_min_x + $stop_x,
                        y2 => int $graphable_area_max_y - $stop_y,
                    );
                    foreach my $point (@points) {
                        my $x = $point->[0];
                        my $y = $point->[1];
                        push @drawing_data,
                            [
                            ARC, $x, $y, $dotplot_width, $dotplot_width, 0,
                            360, 'black'
                            ];
                        push @drawing_data, [ FILL, $x, $y, 'black' ];

                    }
                }
                else {
                    push @drawing_data,
                        [
                        LINE,
                        (   $graphable_area_min_x + $start_x,
                            $graphable_area_max_y - $start_y,
                            $graphable_area_min_x + $stop_x,
                            $graphable_area_max_y - $stop_y,
                        ),
                        'black',
                        ];
                }
            }
        }
    }

    # Draw Right side information here

    # Draw Bottom information here

    $max_x = $plot_max_x if ( $max_x < $plot_max_x );
    $max_y = $plot_max_y if ( $max_y < $plot_max_y );

    unless ( defined( $self->{'comp_plot_bounds_x'}{$comp_map_id} ) ) {
        $self->{'comp_plot_bounds_x'}{$comp_map_id}
            = [ $plot_base_x, $plot_max_x, ];
    }
    unless ( defined( $self->{'ref_plot_bounds_y'}{$ref_map_id} ) ) {
        $self->{'ref_plot_bounds_y'}{$ref_map_id}
            = [ $plot_base_y, $plot_max_y, ];
    }

    $self->add_drawing(@drawing_data);
    $self->add_map_area(@map_area_data);

    return ( $max_x, $max_y );
}

# ----------------------------------------------------
sub bresenham_line {

=pod

=head2 bresenham_line

Draws a bresenham line between two points.  Ported to perl from psuedocode at
http://en.wikipedia.org/wiki/Bresenham's_line_algorithm

=cut

    my ( $self, %args ) = @_;
    my $x1     = $args{'x1'};
    my $x2     = $args{'x2'};
    my $y1     = $args{'y1'};
    my $y2     = $args{'y2'};
    my @points = ();

    my $is_steep = abs( $y2 - $y1 ) > abs( $x2 - $x1 );
    if ($is_steep) {
        ( $y1, $x1 ) = ( $x1, $y1 );
        ( $y2, $x2 ) = ( $x2, $y2 );
    }
    if ( $x1 > $x2 ) {
        ( $x2, $x1 ) = ( $x1, $x2 );
        ( $y2, $y1 ) = ( $y1, $y2 );
    }
    my $deltax   = $x2 - $x1;
    my $deltay   = abs( $y2 - $y1 );
    my $error    = 0;
    my $deltaerr = $deltax ? ( $deltay / $deltax ) : 0;
    my $ystep;
    my $y = $y1;
    if ( $y1 < $y2 ) {
        $ystep = 1;
    }
    else {
        $ystep = -1;
    }
    for ( my $x = $x1; $x <= $x2; $x++ ) {
        if ($is_steep) {
            push @points, [ $y, $x ];
        }
        else {
            push @points, [ $x, $y ];
        }
        $error += $deltaerr;
        if ( $error >= 0.5 ) {
            $y += $ystep;
            $error -= 1.0;
        }
    }
    return @points;
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

Copyright (c) 2007 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

