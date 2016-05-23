package Bio::GMOD::CMap::Utils;

# vim: set ft=perl:

# $Id: Utils.pm,v 1.92 2008/06/27 20:50:29 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Utils - generalized utilities

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Utils;

=head1 DESCRIPTION

This module contains a couple of general-purpose routines, all of
which are exported by default.

=head1 EXPORTED SUBROUTINES

=cut 

use strict;
use Algorithm::Numerical::Sample 'sample';
use Bit::Vector;
use Data::Dumper;
use Bio::GMOD::CMap::Constants;
use Regexp::Common;
use CGI::Session;
use Storable qw( nfreeze thaw );
use POSIX;
use Digest::MD5 qw(md5 md5_hex);
use Clone qw(clone);
require Exporter;
use vars
    qw( $VERSION @EXPORT @EXPORT_OK @SESSION_PARAMS %SESSION_PARAM_DEFAULT_OF);
$VERSION = (qw$Revision: 1.92 $)[-1];

@SESSION_PARAMS = qw[
    prev_ref_species_acc     prev_ref_map_set_acc
    ref_species_acc          ref_map_set_acc
    comparative_maps         highlight
    font_size                pixel_height
    image_type               label_features
    link_group               flip
    session_mod              page_no
    menu_min_corrs           collapse_features
    aggregate                dotplot
    show_intraslot_corr      split_agg_ev
    clean_view               corrs_to_map
    ignore_image_map_sanity  hide_legend
    scale_maps               stack_maps
    comp_menu_order          ref_map_order
    prev_ref_map_order       omit_area_boxes
    action                   mapMenu
    featureMenu              corrMenu
    displayMenu              advancedMenu
    general_min_corrs        slot_min_corrs
    included_feature_types   url_feature_default_display
    corr_only_feature_types  ignored_feature_types
    included_evidence_types  ignored_evidence_types
    less_evidence_types      greater_evidence_types
    evidence_type_score      stack_slot
    dotplot_ps
];

# Not saving these because they should be stored in slots by now.
#    comparative_map_right    comparative_map_left
#    comp_map_set_right       comp_map_set_left
# Not saving because it is unneccessary
#    session_id               saved_link_id
#    step

%SESSION_PARAM_DEFAULT_OF = (
    'comparative_maps' => q{},
    'highlight'        => q{},
    'font_size'        => q{},
    'pixel_height'     => q{},
    'image_type'       => q{},
    'label_features'   => q{},
    'link_group'       => q{},
    'flip'             => q{},
    'dotplot'          => 0,
    'dotplot_ps'       => 1,
    'session_mod'      => q{},
    'page_no'          => 1,
    'action'           => 'view',
    'step'             => 0,
);

use base 'Exporter';

my @subs = qw[
    commify
    presentable_number
    presentable_number_per
    extract_numbers
    even_label_distribution
    label_distribution
    parse_words
    simple_column_distribution
    fake_selectall_arrayref
    sort_selectall_arrayref
    parse_url
    create_session_step
    longest_run
    round_to_granularity
    has_sql_command
];
@EXPORT_OK = @subs;
@EXPORT    = @subs;

# ----------------------------------------------------
sub extract_numbers {

=pod

=head2 extract_numbers

Returns only the number portion at the beginning of a string.

=cut

    my $arg = shift;
    $arg =~ s/[^\d]//g;
    return $arg;
}

# ----------------------------------------------------
sub commify {

=pod

=head2 commify

Turns "12345" into "12,345"

=cut

    my $number = shift;
    1 while $number =~ s/^(-?\d+)(\d{3})/$1,$2/;
    return $number;
}

# ----------------------------------------------------
sub even_label_distribution {

=pod

=head2 even_label_distribution

Simply space (a sample of) the labels evenly in the given vertical space.

Given:

  labels: a hashref of arrayrefs, the keys of the hashref being one of
    "highlights" - highlighted features, all will be taken
    "correspondences" - features with correspondences
    "normal" - all other features

  map_height: the pixel height of the map (the bounds in which 
    labels can be drawn

  buffer: the space between labels (optional, default = "2")

  start_y: the starting Y value from which to start assigning labels Y values

  font_height: how many pixels tall the label font is

Basically, we just divide the total vertical pixel space available 
(map_height) by the number of labels we want to place and decide how many 
will fit.  For each of the keys of the "labels" hashref, we try to add
as many labels as will fit.  As space becomes limited, we start taking an
even sampling of the available labels.  Once we've selected all the labels
that will fit, we sort them (if needed) by "feature_start," figure out the
gaps to put b/w the labels, and then space them evenly from top to bottom
using the gap interval.

Special thanks to Noel Yap for suggesting this strategy.

=cut

    my %args        = @_;
    my $labels      = $args{'labels'};
    my $map_height  = $args{'map_height'} || 0;
    my $buffer      = $args{'buffer'} || 2;
    my $start_y     = $args{'start_y'} || 0;
    my $font_height = $args{'font_height'} || 0;
    $font_height += $buffer;
    my @accepted = @{ $labels->{'highlights'} || [] };   # take all highlights
    my $no_added = @accepted ? 1 : 0;

    for my $priority (qw/ correspondences normal /) {

        #
        # See if there's enough room available for all the labels;
        # if not, just take an even sampling.
        #
        my $no_accepted = scalar @accepted;
        my $no_present  = scalar @{ $labels->{$priority} || [] } or next;
        my $available   = $map_height - ( $no_accepted * $font_height );
        last if $available < $font_height;

        my $no_possible = int( $available / $font_height );
        if ( $no_present > $no_possible ) {
            my $skip_val = int( $no_present / $no_possible );
            if ( $skip_val > 1 ) {
                for ( my $i = 0; $i < $no_present; $i += $skip_val ) {
                    push @accepted, $labels->{$priority}[$i];
                }
            }
            else {
                my @sample = sample(
                    set         => [ 0 .. $no_present - 1 ],
                    sample_size => $no_possible,
                );
                push @accepted, @{ $labels->{$priority} }[@sample];
            }
        }
        else {
            push @accepted, @{ $labels->{$priority} };
        }

        $no_added++;
    }

    my $no_accepted = scalar @accepted;
    my $no_possible = int( $map_height / $font_height );

    #
    # If there's only one label, put it right next to the one feature.
    #
    if ( $no_accepted == 1 ) {
        my $label = $accepted[0];
        $label->{'y'} = $label->{'target'};
    }

    #
    # If we took fewer than was possible, try to sort them nicely.
    #
    elsif ( $no_accepted > 1 && $no_accepted <= ( $no_possible * .5 ) ) {
        @accepted = map { $_->[0] }
            sort { $a->[1] <=> $b->[1] || $b->[2] <=> $a->[2] }
            map { [ $_, $_->{'target'}, $_->{'feature'}{'column'} ] }
            @accepted;

        my $bin_size  = 2;
        my $half_font = $font_height / 2;
        my $no_bins   = sprintf( "%d", $map_height / $bin_size );
        my $bins      = Bit::Vector->new($no_bins);

        my $i = 1;
        for my $label (@accepted) {
            my $target  = $label->{'target'};
            my $low_bin = sprintf( "%d",
                ( $target - $start_y - $half_font ) / $bin_size );
            my $high_bin = sprintf( "%d",
                ( $target - $start_y + $half_font ) / $bin_size );

            if ( $low_bin < 0 ) {
                my $diff = 0 - $low_bin;
                $low_bin  += $diff;
                $high_bin += $diff;
            }

            my ( $hmin, $hmax ) = $bins->Interval_Scan_inc($low_bin);
            my ( $lmin, $lmax, $next_lmin, $next_lmax );
            if ( $low_bin > 0 ) {
                ( $lmin, $lmax ) = $bins->Interval_Scan_dec( $low_bin - 1 );

                if ( $lmin && $lmin > 1 && $lmax == $low_bin - 1 ) {
                    ( $next_lmin, $next_lmax )
                        = $bins->Interval_Scan_dec( $lmin - 1 );
                }
            }

            my $bin_span      = $high_bin - $low_bin;
            my $bins_occupied = $bin_span + 1;

            my ( $gap_below, $gap_above, $diff_to_gap_below,
                $diff_to_gap_above );

            # nothing below and enough open space
            if ( !defined $lmax && $low_bin - $bin_span > 1 ) {
                $gap_below         = $low_bin - 1;
                $diff_to_gap_below = $bin_span;
            }

            # something below but enough space b/w it and this
            elsif ( defined $lmax && $low_bin - $lmax > $bin_span ) {
                $gap_below         = $low_bin - $lmax;
                $diff_to_gap_below = $bins_occupied;
            }

            # something immediately below but enough space in next gap
            elsif (defined $lmax
                && $lmax == $low_bin - 1
                && defined $next_lmax
                && $lmin - $next_lmax >= $bins_occupied )
            {
                $gap_below         = $lmin - $next_lmax;
                $diff_to_gap_below = ( $low_bin - $lmin ) + $bins_occupied;
            }

            # something below and enough space beyond it w/o going past 0
            elsif (!defined $next_lmax
                && defined $lmin
                && $lmin - $bin_span > 0 )
            {
                $gap_below         = $lmin;
                $diff_to_gap_below = $low_bin - $lmin + $bins_occupied;
            }

            # nothing above and space w/in the bins
            if ( !defined $hmin && $high_bin + $bin_span < $no_bins ) {
                $gap_above         = $no_bins - $low_bin;
                $diff_to_gap_above = 0;
            }

            # inside an occupied bin but space just above it
            elsif (defined $hmax
                && $hmax <= $high_bin
                && $hmax + 1 + $bin_span < $no_bins )
            {
                $gap_above         = $no_bins - $hmax;
                $diff_to_gap_above = ( $hmax - $low_bin ) + 1;
            }

            # collision but space afterwards
            elsif ( defined $hmax && $hmax + $bin_span < $no_bins ) {
                $gap_above = $no_bins - ( $hmax + 1 );
                $diff_to_gap_above = ( $hmax + 1 ) - $low_bin;
            }

            my $below_open = $gap_below >= $bins_occupied;
            my $above_open = $gap_above >= $bins_occupied;
            my $closer_gap
                = $diff_to_gap_below == $diff_to_gap_above ? 'neither'
                : defined $diff_to_gap_below
                && ( $diff_to_gap_below < $diff_to_gap_above ) ? 'below'
                :                                                'above';

            my $diff = 0;
            if ( !defined $hmin ) {
                ;    # do nothing
            }
            elsif (
                $below_open
                && ( $closer_gap =~ /^(neither|below)$/
                    || !$above_open )
                )
            {
                $low_bin  -= $diff_to_gap_below;
                $high_bin -= $diff_to_gap_below;
                $diff = -( $bin_size * $diff_to_gap_below );
            }
            else {
                $diff_to_gap_above ||= ( $hmax - $low_bin ) + 1;
                $low_bin  += $diff_to_gap_above;
                $high_bin += $diff_to_gap_above;
                $diff = $bin_size * $diff_to_gap_above;
            }

            if ( defined $low_bin && defined $high_bin ) {
                if ( $high_bin >= $bins->Size ) {
                    my $cur  = $bins->Size;
                    my $diff = ( $high_bin - $cur ) + 1;
                    $bins->Resize( $cur + $diff );
                }
                $bins->Interval_Fill( $low_bin, $high_bin );
            }

            $label->{'y'} = $target + $diff;
            $i++;
        }

        #
        # Double-check to see if any look out of place.  To do this,
        # sort the labels by their "y" position and then see if the
        # "targets" are in ascending order.  If we find a pair where
        # this is not the case, then switch the "y" positions until
        # they're in ascending order.  It's necessary to make multiple
        # passes, so keep doing it until they're all determined to be
        # OK.
        #
        my $ok = 0;
        while ( !$ok ) {
            $ok = 1;
            @accepted = map { $_->[0] }
                sort { $a->[1] <=> $b->[1] }
                map { [ $_, $_->{'y'} ] } @accepted;

            my $last_target = $accepted[0]->{'target'};
            $i = 0;
            for my $label (@accepted) {
                my $this_target = $label->{'target'};
                if ( $this_target < $last_target ) {
                    $ok = 0;
                    my $j    = $i;
                    my $this = $accepted[ $j - 1 ];    # back up
                    my $next = $accepted[$j];          # start switching here

                    while ($this->{'target'} > $next->{'target'}
                        && $this->{'y'} < $next->{'y'} )
                    {
                        ( $this->{'y'}, $next->{'y'} )
                            = ( $next->{'y'}, $this->{'y'} );
                        $next = $accepted[ ++$j ];
                    }
                }

                $last_target = $this_target;
                $i++;
            }
        }
    }

    #
    # If we used all available space, just space evenly.
    #
    else {

        #
        # Figure the gap to evenly space the labels in the space.
        #
        @accepted = map { $_->[0] }
            sort { $a->[1] <=> $b->[1] || $a->[2] <=> $b->[2] }
            map { [ $_, $_->{'target'}, $_->{'feature'}{'column'} ] }
            @accepted;

        my $gap = $map_height / ( $no_accepted - 1 );
        my $i = 0;
        for my $label (@accepted) {
            $label->{'y'} = sprintf( "%.2f", $start_y + ( $gap * $i++ ) );
        }
    }

    return \@accepted;
}

# ----------------------------------------------------
sub label_distribution {

=pod

=head2 label_distribution

Given a reference to an array containing labels, figure out where a new
label can be inserted.

=cut

    my %args       = @_;
    my $labels     = $args{'labels'};
    my $accepted   = $args{'accepted'};
    my $buffer     = $args{'buffer'} || 2;
    my $direction  = $args{'direction'} || NORTH;    # NORTH or SOUTH?
    my $row_height = $args{'row_height'} || 1;       # how tall a row is
    my $used       = $args{'used'} || [];
    my $reverse    = $direction eq NORTH ? -1 : 1;
    my @used = sort { $reverse * ( $a->[0] <=> $b->[0] ) } @$used;

    for my $label ( @{ $labels || [] } ) {
        my $max_distance = $label->{'has_corr'}       ? 15 : 10;
        my $can_skip     = $label->{'is_highlighted'} ? 0  : 1;
        my $target = $label->{'target'} || 0;        # desired location
        my $top    = $target;
        my $bottom = $target + $row_height;
        my $ok = 1;    # assume innocent until proven guilty

    SEGMENT:
        for my $i ( 0 .. $#used ) {
            my $segment = $used[$i] or next;
            my ( $north, $south ) = @$segment;
            next if $south + $buffer <= $top;   # segment is above our target.
            next
                if $north - $buffer >= $bottom; # segment is below our target.

            #
            # If there's some overlap, see if it will fit above or below.
            #
            if (   ( $north - $buffer <= $bottom )
                || ( $south + $buffer >= $top ) )
            {
                $ok = 0;    # now we're guilty until we can prove innocence

                #
                # Figure out the current frame.
                #
                my $prev_segment = $i > 0      ? $used[ $i - 1 ] : undef;
                my $next_segment = $i < $#used ? $used[ $i + 1 ] : undef;
                my $ftop
                    = $direction eq NORTH
                    ? defined $next_segment->[1]
                        ? $next_segment->[1]
                        : undef
                    : $south;
                my $fbottom
                    = $direction eq NORTH ? $north
                    : defined $next_segment->[0] ? $next_segment->[0]
                    :                              undef;

                #
                # Check if we can fit the label into the frame.
                #
                if (   defined $ftop
                    && defined $fbottom
                    && $fbottom - $ftop < $bottom - $top )
                {
                    next SEGMENT;
                }

                #
                # See if moving the label to the frame would move it too far.
                #
                my $diff
                    = $direction eq NORTH
                    ? $fbottom - $bottom - $buffer
                    : $ftop - $top + $buffer;
                if ( ( abs $diff > $max_distance ) && $can_skip ) {
                    next SEGMENT;
                }
                $_ += $diff for $top, $bottom;

                #
                # See if it will fit.  Same as two above?
                #
                if ((      defined $ftop
                        && defined $fbottom
                        && $top - $buffer >= $ftop
                        && $bottom + $buffer <= $fbottom
                    )
                    || ( defined $ftop    && $top - $buffer >= $ftop )
                    || ( defined $fbottom && $bottom + $buffer <= $fbottom )
                    )
                {
                    $ok = 1;
                    last;
                }

                next SEGMENT if !$ok and !$can_skip;
                last;
            }
            else {
                $ok = 1;
            }
        }

        #
        # If nothing was found but we can't skip, then move the
        # label to just beyond the last segment.
        #
        if ( !$ok and !$can_skip ) {
            my ( $last_top, $last_bottom ) = @{ $used[-1] };
            if ( $direction eq NORTH ) {
                $bottom = $last_top - $buffer;
                $top    = $bottom - $row_height;
            }
            else {
                $top    = $last_bottom + $buffer;
                $bottom = $top + $row_height;
            }
            $ok = 1;
        }

        #
        # If there are no rows, we didn't find a collision, or we didn't
        # move the label too far to make it fit, then record where this one
        # went and return the new location.
        #
        if ( !@used || $ok ) {
            push @used, [ $top, $bottom ];
            $label->{'y'} = $top;
            push @$accepted, $label;
        }
    }

    return \@used;
    return 1;
}

# ----------------------------------------------------
sub parse_words {

    #
    # Stole this from String::ParseWords::parse by Christian Gilmore
    # (CPAN ID: CGILMORE), modified to split on commas or spaces.  Allows
    # quoted phrases within a string to count as a "word," e.g.:
    #
    # "Foo bar" baz
    #
    # Becomes:
    #
    # Foo bar
    # baz
    #
    my $string    = shift;
    my @words     = ();
    my $inquote   = 0;
    my $length    = length($string);
    my $nextquote = 0;
    my $nextspace = 0;
    my $pos       = 0;

    # shrink whitespace sets to just a single space
    $string =~ s/\s+/ /g;

    # Extract words from list
    while ( $pos < $length ) {
        $nextquote = index( $string, '"', $pos );
        $nextspace = index( $string, ' ', $pos );
        $nextspace = $length if $nextspace < 0;
        $nextquote = $length if $nextquote < 0;

        if ($inquote) {
            push( @words, substr( $string, $pos, $nextquote - $pos ) );
            $pos     = $nextquote + 2;
            $inquote = 0;
        }
        elsif ( $nextspace < $nextquote ) {
            push @words, split /[,\s+]/,
                substr( $string, $pos, $nextspace - $pos );
            $pos = $nextspace + 1;
        }
        elsif ( $nextspace == $length && $nextquote == $length ) {

            # End of the line
            push @words, map { s/^\s+|\s+$//g; $_ }
                split /,/, substr( $string, $pos, $nextspace - $pos );
            $pos = $nextspace;
        }
        else {
            $inquote = 1;
            $pos     = $nextquote + 1;
        }
    }

    push( @words, $string ) unless scalar(@words);

    return @words;
}

# ----------------------------------------------------

=pod

=head2 simple_column_distribution

Assumes that items will fit into just one column.

=cut 

sub simple_column_distribution {
    my %args = @_;
    my $columns = $args{'columns'} || [];    # arrayref of columns on horizontal
    my $map_height = $args{'map_height'};     # in pixels
    my $low        = $args{'low'};            # lowest pixel value occuppied
    my $high       = $args{'high'};           # highest pixel value occuppied
    my $buffer     = $args{'buffer'} || 2;    # min pixel distance b/w items
    my $selected;                             # the column number returned

    $map_height = int($map_height);
    $low        = int($low);
    $high       = int($high);

    if ( $low > $high ) {
        ( $low, $high ) = ( $high, $low );
    }

    #
    # Calculate the effect of the buffer.
    #
    my ( $scan_low, $scan_high ) = ( $low, $high );

    if ( $low - $buffer >= 0 ) {
        $scan_low -= $buffer;
    }

    if ( $high + $buffer <= $map_height ) {
        $scan_high += $buffer;
    }

    $map_height += $buffer;

    # Check if this is going to crash and give a useful output
    if ( $low < 0 or $high > $map_height ) {
        print STDERR
            "Item is out of distribution range.  This is a fatal error.\n";
        print STDERR "Low: $low, High: $high \n";
        print STDERR "Max: $map_height\n";
        print STDERR Dumper( caller() ) . "\n";
        exit;
    }

    if ( scalar @$columns == 0 ) {
        my $col = Bit::Vector->new($map_height);
        $col->Interval_Fill( $low, $high );
        push @$columns, $col;
        $selected = 0;
    }
    else {
        for my $i ( 0 .. $#{$columns} ) {
            my $col = $columns->[$i];
            my ( $min, $max ) = $col->Interval_Scan_inc($scan_low);
            if ( !defined $min || $min > $scan_high ) {
                $col->Interval_Fill( $low, $high );
                $selected = $i;
                last;
            }
        }

        unless ( defined $selected ) {
            my $col = Bit::Vector->new($map_height);
            $col->Interval_Fill( $low, $high );
            push @$columns, $col;
            $selected = $#{$columns};
        }
    }

    return $selected;
}

# ----------------------------------------------------
sub fake_selectall_arrayref {

=pod

=head2 fake_selectall_arrayref

takes a hash of hashes and makes it look like return from 
the DBI selectall_arrayref()

=cut 

    my $self    = shift;
    my $hashref = shift;
    my @columns = @_;
    my $i       = 0;
    my @return_array;
    my %column_name;
    foreach my $column (@columns) {
        if ( $column =~ /(\S+)\s+as\s+(\S+)/ ) {
            $column = $1;
            $column_name{$1} = $2;
        }
        else {
            $column_name{$column} = $column;
        }
    }
    for my $key ( keys(%$hashref) ) {
        %{ $return_array[$i] }
            = map { $column_name{$_} => $hashref->{$key}->{$_} } @columns;
        $i++;
    }
    @return_array
        = sort { $a->{ $columns[0] } cmp $b->{ $columns[0] } } @return_array;
    return \@return_array;
}

# ----------------------------------------------------

=pod

=head2 sort_selectall_arrayref

give array ref of a hash and a list of keys and it will sort 
based on the list of keys.  Add a '#' to the front of a key 
to make it use '<=>' instead of 'cmp'.

=cut 

sub sort_selectall_arrayref {
    my $arrayref = shift;
    my @columns  = @_;
    my @return   = sort {
        for ( my $i = 0; $i <= $#columns; $i++ )
        {
            my $col = $columns[$i];
            my $dir = 1;
            if ( $col =~ /^(\S+)\s+(\S+)/ ) {
                $col = $1;
                $dir = -1 if ( $2 eq ( uc 'DESC' ) );
            }
            if ( $col =~ /^#(\S+)/ ) {
                $col = $1;
                if ( $dir * ( $a->{$col} <=> $b->{$col} ) ) {
                    return $dir * ( $a->{$col} <=> $b->{$col} );
                }
            }
            else {
                if ( $dir * ( $a->{$col} cmp $b->{$col} ) ) {
                    return $dir * ( $a->{$col} cmp $b->{$col} );
                }
            }
        }
        return 0;
    } @$arrayref;

    return \@return;
}

# ----------------------------------------------------

=pod

=head2 has_sql_command

Returns true if a string has an sql command in it.

=cut 

sub has_sql_command {
    my $str = shift or return 0;

    if ( $str =~ /(SELECT|UPDATE|DELETE|INSERT|MERGE|UNION)/i ) {
        return 1;
    }
    return 0;

}

# --------------------------
# calculate_units() was swiped from Lincoln Steins
# Bio::Graphics::Glyph::arrow which is distributed
# with Bioperl
# Modified slightly
sub calculate_units {
    my ($length) = @_;
    return q{G} if $length >= 1e9;
    return q{M} if $length >= 1e6;
    return q{K} if $length >= 1e3;
    return q{}  if $length >= 1;
    return q{c} if $length >= 1e-2;
    return q{m} if $length >= 1e-3;
    return q{u} if $length >= 1e-6;
    return q{n} if $length >= 1e-9;
    return q{p};
}

# ----------------------------------------------------
sub presentable_number {

=pod
                                                                                
=head2 presentable_number 

Takes a number and makes it pretty. 
example: 10000 becomes 10K

=cut

    my $num = shift;
    my $sig_digits = shift || 2;
    return unless defined($num);
    my $num_str;

    # the "q{}." is to fix a rounding error in perl
    my $scale = $num ? int( q{} . ( log( abs($num) ) / log(10) ) ) : 0;
    my $rounding_power = $scale - $sig_digits + 1;
    my $rounded_temp   = int( ( $num / ( 10**$rounding_power ) ) + .5 );
    my $printable_num  = $rounded_temp /
        ( 10**( ( $scale - ( $scale % 3 ) ) - $rounding_power ) );
    my $unit = calculate_units( 10**( $scale - ( $scale % 3 ) ) );
    $num_str = $printable_num . " " . $unit;

    return $num_str;
}

# ----------------------------------------------------
sub presentable_number_per {

=pod
                                                                                
=head2 presentable_number_per 

Takes a number and makes it pretty. 
example: .001 becomes "1/K"

=cut

    my $num = shift;
    my $num_str;

    return "0/unit" unless $num;

    # the "q{}." is to fix a rounding error in perl
    my $scale = $num ? int( q{} . ( log( abs($num) ) / log(10) ) ) : 0;
    my $denom_power = $scale - ( $scale % 3 );

    my $printable_num = $num ? $num / ( 10**$denom_power ) : 0;
    $printable_num = sprintf( "%.2f", $printable_num ) if $printable_num;

    my $unit = calculate_units( 10**( -1 * $denom_power ) );
    $num_str
        = $unit
        ? $printable_num . "/" . $unit
        : $printable_num . "/unit";
    return $num_str;
}

# ----------------------------------------------------
sub round_to_granularity {

=pod
                                                                                
=head2 round_to_granularity 

Rounds a number to the unit granularity.

The unit granularity defines the granularity of map units.  It is the smallest
value that a unit value can be different from the next value.  For example, the
granularity of a base pair is 1.  Some data will have a certain number of
signifigant digits for example data in cenitMorgans might have granularity of
0.01.

example: 12.345 with a granularity of 0.1 becomes 12.3 

example: 12.375 with a granularity of 0.1 becomes 12.4 

=cut

    my $num = shift;
    my $granularity = shift || DEFAULT->{'unit_granularity'};

    unless ( $granularity =~ /^0*\.?0*10*$/ ) {
        print STDERR "Granularity, $granularity is not right.\n";
        return $num;
    }

    my $multiplication_factor = 1 / $granularity;

    my $return_val = int( ( $num * $multiplication_factor ) + .5 ) /
        $multiplication_factor;

    return $return_val;
}

# ----------------------------------------------------
sub longest_run {

=pod

=head2 longest_run 

Written by Lincoln Stein

Return score and longest run for a run of objects in an array ref.

=cut

    my ( $arrayref, $scoresub ) = @_;

    my @score = [ 0, [] ];    # array ref containing [score,[subsequence]]
    for ( my $i = 0; $i < @$arrayref; $i++ ) {
        push @score, _longest_run_score( $arrayref, \@score, $i, $scoresub );
    }
    my ( $best_score, $subseq ) = @{ $score[-1] };
    for ( my $i = 0; $i < @score - 1; $i++ ) {
        if ( $score[$i][0] > $best_score ) {
            $best_score = $score[$i][0];
            $subseq     = $score[$i][1];
        }
    }
    return ( $best_score, [ map { $arrayref->[$_] } @$subseq ] );
}

# ----------------------------------------------------
sub _longest_run_score {

=pod

=head2 _longest_run_score

Written by Lincoln Stein

Used by longest_run

=cut

    my ( $arrayref, $scores, $position, $scoresub ) = @_;

    # find longest subsequence that this position extends
    my $max_score = 0;
    my $max_subseq;
    for my $subpart (@$scores) {
        my $sub_score = $subpart->[0];
        my $sub_seq   = $subpart->[1];

        # boundary condition; empty $sub_seq;
        unless (@$sub_seq) {
            $max_score  = 0;
            $max_subseq = $sub_seq;
            next;
        }

        my $score = $scoresub->(
            $arrayref->[ $sub_seq->[-1] ],
            $arrayref->[$position]
        );
        if ($score) {
            my $new_score = $sub_score + $score;
            if ( $new_score > $max_score ) {
                $max_score  = $new_score;
                $max_subseq = $sub_seq;
            }
        }
    }
    return [
        $max_score || 0,
        [ defined $max_subseq ? @$max_subseq : (), $position ]
    ];
}

# ----------------------------------------------------
sub _parse_map_info {

    # parses the map info
    my $acc       = shift;
    my $highlight = shift;

    my ( $start, $stop, $magnification ) = ( undef, undef, 1 );

    # following matches map_id[1*200] and map_id[1*200x2]
    if ( $acc =~ m/^(.+)\[(.*)\*(.*?)(?:x([\d\.]*)|)\]$/ ) {
        $acc = $1;
        ( $start, $stop ) = ( $2, $3 );
        $magnification = $4 if $4;
        ( $start, $stop ) = ( undef, undef ) if ( $start == $stop );
        $start = undef unless ( $start =~ /\S/ );
        $stop  = undef unless ( $stop  =~ /\S/ );
        my $start_stop_feature = 0;
        my @highlight_array;
        push @highlight_array, $highlight if $highlight;

        if ( $start !~ /^$RE{'num'}{'real'}$/ ) {
            push @highlight_array, $start if $start;
            $start_stop_feature = 1;
        }

        if ( $stop !~ /^$RE{'num'}{'real'}$/ ) {
            push @highlight_array, $stop if $stop;
            $start_stop_feature = 1;
        }
        $highlight = join( ',', @highlight_array );

        if (    !$start_stop_feature
            and defined($start)
            and defined($stop)
            and $stop < $start )
        {
            ( $start, $stop ) = ( $stop, $start );
        }
    }

    return ( $acc, $start, $stop, $magnification, $highlight );
}

# ----------------------------------------------------
sub _modify_params {

    # Modify the slots object using a data from the url
    my $slots                  = shift;
    my $parsed_url_options_ref = shift;
    my $mod_str                = shift;
    my $map_menu_data_ref      = shift;

    _modify_params_using_mod_str( $slots, $parsed_url_options_ref, $mod_str );
    _modify_slots_using_map_menu_data( $slots, $map_menu_data_ref );

}

# ----------------------------------------------------
sub _modify_slots_using_map_menu_data {

    # Modify the slots object using a modification string
    my $slots         = shift;
    my $map_menu_data = shift;

    my @data_names = qw( start stop mag );

    foreach my $slot_no ( keys %{ $map_menu_data || {} } ) {
        next
            unless ( $slots->{$slot_no}
            and %{ $slots->{$slot_no}{'maps'} || {} } );
        foreach my $map_acc ( keys %{ $map_menu_data->{$slot_no} || {} } ) {
            next unless ( %{ $slots->{$slot_no}{'maps'}{$map_acc} || {} } );
            foreach my $data_name (@data_names) {
                $slots->{$slot_no}{'maps'}{$map_acc}{$data_name}
                    = $map_menu_data->{$slot_no}{$map_acc}{$data_name};
            }
        }
    }

    return;
}

# ----------------------------------------------------
sub _modify_params_using_mod_str {

    # Modify the slots object using a modification string
    my $slots                  = shift;
    my $parsed_url_options_ref = shift;
    my $mod_str                = shift;
    my @mod_cmds               = split( /:/, $mod_str );

    foreach my $mod_cmd (@mod_cmds) {
        my @mod_array = split( /=/, $mod_cmd );
        next unless (@mod_array);

        if ( $mod_array[0] eq 'start' ) {
            next unless ( scalar(@mod_array) == 4 );
            my $slot_no = $mod_array[1];
            my $map_acc = $mod_array[2];
            my $start   = $mod_array[3];
            if (    $slots->{$slot_no}
                and $slots->{$slot_no}{'maps'}{$map_acc} )
            {
                $slots->{$slot_no}{'maps'}{$map_acc}{'start'} = $start;
            }
        }
        elsif ( $mod_array[0] eq 'stop' ) {
            next unless ( scalar(@mod_array) == 4 );
            my $slot_no = $mod_array[1];
            my $map_acc = $mod_array[2];
            my $stop    = $mod_array[3];
            if (    $slots->{$slot_no}
                and $slots->{$slot_no}{'maps'}{$map_acc} )
            {
                $slots->{$slot_no}{'maps'}{$map_acc}{'stop'} = $stop;
            }
        }
        elsif ( $mod_array[0] eq 'mag' ) {
            next unless ( scalar(@mod_array) == 4 );
            my $slot_no = $mod_array[1];
            my $map_acc = $mod_array[2];
            my $mag     = $mod_array[3];
            if (    $slots->{$slot_no}
                and $slots->{$slot_no}{'maps'}{$map_acc} )
            {
                $slots->{$slot_no}{'maps'}{$map_acc}{'mag'} = $mag;
            }
        }
        elsif ( $mod_array[0] eq 'reset' ) {
            next unless ( scalar(@mod_array) == 3 );
            my $slot_no = $mod_array[1];
            my $map_acc = $mod_array[2];
            if (    $slots->{$slot_no}
                and $slots->{$slot_no}{'maps'}{$map_acc} )
            {
                $slots->{$slot_no}{'maps'}{$map_acc}{'start'} = undef;
                $slots->{$slot_no}{'maps'}{$map_acc}{'stop'}  = undef;
                $slots->{$slot_no}{'maps'}{$map_acc}{'mag'}   = 1;
            }
        }
        elsif ( $mod_array[0] eq 'del' ) {
            if ( scalar(@mod_array) == 3 ) {
                my $slot_no = $mod_array[1];
                my $map_acc = $mod_array[2];
                if (    $slots->{$slot_no}
                    and $slots->{$slot_no}{'maps'}{$map_acc} )
                {
                    delete $slots->{$slot_no}{'maps'}{$map_acc};

                    # If deleting last map, remove the whole thing
                    unless ( $slots->{$slot_no}{'maps'} ) {
                        $slots->{$slot_no}{'map_sets'} = {};
                    }
                }
            }
            elsif ( scalar(@mod_array) == 2 ) {
                my $slot_no = $mod_array[1];
                if ( $slots->{$slot_no} ) {
                    $slots->{$slot_no} = {};
                }
            }
        }
        elsif ( $mod_array[0] eq 'limit' ) {
            next unless ( scalar(@mod_array) == 3 );
            my $slot_no = $mod_array[1];
            my $map_acc = $mod_array[2];
            if (    $slots->{$slot_no}
                and $slots->{$slot_no}{'maps'}{$map_acc} )
            {
                foreach my $other_map_acc (
                    keys( %{ $slots->{$slot_no}{'maps'} } ) )
                {
                    next if ( $other_map_acc eq $map_acc );
                    delete $slots->{$slot_no}{'maps'}{$other_map_acc};
                }
            }
        }
        elsif ( $mod_array[0] eq 'ft' ) {
            next unless ( scalar(@mod_array) == 3 );
            my $feature_type_acc = $mod_array[1];
            my $value            = $mod_array[2];

            # Remove this value from all lists
            #  Then add it back to the correct one
            # Clone these values so they don't clobber the session

            @{ $parsed_url_options_ref->{'corr_only_feature_types'} }
                = grep { $_ ne $feature_type_acc }
                @{ clone(
                    $parsed_url_options_ref->{'corr_only_feature_types'} ) };
            @{ $parsed_url_options_ref->{'included_feature_types'} }
                = grep { $_ ne $feature_type_acc }
                @{ clone(
                    $parsed_url_options_ref->{'included_feature_types'} ) };
            @{ $parsed_url_options_ref->{'ignored_feature_types'} }
                = grep { $_ ne $feature_type_acc }
                @{ clone( $parsed_url_options_ref->{'ignored_feature_types'} )
                };

            if ( $value == 0 ) {
                push @{ $parsed_url_options_ref->{'ignored_feature_types'} },
                    $feature_type_acc;
            }
            elsif ( $value == 1 ) {
                push
                    @{ $parsed_url_options_ref->{'corr_only_feature_types'} },
                    $feature_type_acc;
            }
            elsif ( $value == 2 ) {
                push @{ $parsed_url_options_ref->{'included_feature_types'} },
                    $feature_type_acc;
            }

        }

    }

    # If ever a slot has no maps, remove the slot.
    my $delete_pos = 0;
    my $delete_neg = 0;
    foreach my $slot_no ( sort _order_out_from_zero keys %{$slots} ) {
        unless (
            (   $slots->{$slot_no}{'maps'} and %{ $slots->{$slot_no}{'maps'} }
            )
            or ( $slots->{$slot_no}{'mapsets'}
                and %{ $slots->{$slot_no}{'map_sets'} } )
            )
        {
            if ( $slot_no >= 0 ) {
                $delete_pos = 1;
            }
            if ( $slot_no <= 0 ) {
                $delete_neg = 1;
            }
        }
        if ( $slot_no >= 0 and $delete_pos ) {
            delete $slots->{$slot_no};
        }
        elsif ( $slot_no < 0 and $delete_neg ) {
            delete $slots->{$slot_no};
        }
    }
    return;
}

# ----------------------------------------------------
sub _parse_session_step {

    # Modify the slots object using a modification string
    my %args                   = @_;
    my $session_step           = $args{'session_step'};
    my $apr                    = $args{'apr'};
    my $slots_ref              = $args{'slots_ref'};
    my $parsed_url_options_ref = $args{'parsed_url_options_ref'};
    my $ref_map_accs_ref       = $args{'ref_map_accs_ref'};

    my %param_specified = map { $_ => 1 } $apr->param();

    # if this was submitted through a button
    # then use all of the menu parameters
    # otherwise check against the session
    unless ( $apr->param('sub') or $apr->param('use_menu') ) {
        for my $param (@SESSION_PARAMS) {
            unless ( $param_specified{$param} ) {
                $parsed_url_options_ref->{$param} = $session_step->{$param};
                $apr->param( $param, $session_step->{$param} )
                    if ( ref $session_step->{$param} eq '' );
            }
        }
    }

    # Clone slots so we don't clobber the old session step
    %{$slots_ref} = %{ clone( $session_step->{'slots'} ) };

    # Apply Session Modifications to slots_ref
    _modify_params(
        $slots_ref, $parsed_url_options_ref,
        $parsed_url_options_ref->{'session_mod'},
        $parsed_url_options_ref->{'map_menu_data'}
    ) if ( !$parsed_url_options_ref->{'reusing_step'} );

    @$ref_map_accs_ref = keys( %{ $slots_ref->{0}->{'maps'} } );
    $apr->param( 'ref_map_accs', join( ":", @{ $ref_map_accs_ref || () } ) );

    return 1;
}

sub _order_out_from_zero {
    ###Return the sort in this order (0,1,-1,-2,2,-3,3,)
    return ( abs($a) cmp abs($b) );
}

# ----------------------------------------------------
sub _get_options_from_url {

    my %args                = @_;
    my $apr                 = $args{'apr'};
    my $calling_cmap_object = $args{'calling_cmap_object'};

    my %parsed_url_options;

    # First deal with special params (backwards compat and other)
    $parsed_url_options{'prev_ref_species_acc'}
        = $apr->param('prev_ref_species_acc')
        || $apr->param('prev_ref_species_aid')
        || q{};
    $parsed_url_options{'prev_ref_map_set_acc'}
        = $apr->param('prev_ref_map_set_acc')
        || $apr->param('prev_ref_map_set_aid')
        || q{};
    $parsed_url_options{'ref_species_acc'} = $apr->param('ref_species_acc')
        || $apr->param('ref_species_aid')
        || $calling_cmap_object->config_data('default_species_acc')
        || q{};
    $parsed_url_options{'ref_map_set_acc'} = $apr->param('ref_map_set_acc')
        || $apr->param('ref_map_set_aid')
        || q{};
    @{ $parsed_url_options{'comparative_map_right'} }
        = $apr->param('comparative_map_right');
    @{ $parsed_url_options{'comparative_map_left'} }
        = $apr->param('comparative_map_left');
    $parsed_url_options{'url_for_saving'}
        = $apr->url( -relative => 1, -query => 1 );

    # Deal with parameters that don't default to anything
    # These are important for when 0 is a valid value
    for my $param (
        qw [
        comparative_maps         highlight           font_size
        pixel_height             image_type          label_features
        link_group               flip                session_mod
        page_no                  action              step
        left_min_corrs           corr_menu_min_corrs_left
        right_min_corrs          corr_menu_min_corrs_right
        menu_min_corrs           dotplot
        ref_map_start            ref_map_stop        comp_map_set_right
        comp_map_set_left        collapse_features   aggregate
        show_intraslot_corr      split_agg_ev        hide_legend
        clean_view               corrs_to_map        reuse_step
        ignore_image_map_sanity  scale_maps          stack_maps
        comp_menu_order          ref_map_order       prev_ref_map_order
        omit_area_boxes          mapMenu             featureMenu
        corrMenu                 displayMenu         advancedMenu
        session_id               saved_link_id       general_min_corrs
        ignore_comp_maps         eliminate_orphans   dotplot_ps
        ]
        )
    {
        $parsed_url_options{$param} = $apr->param($param);
    }

    # LEGACY
    # Check for depricated min_correspondences value
    # Basically general_min_corrs is a new way to address
    # the min_correspondences legacy while keeping the option
    # for this feature open in the future.
    $parsed_url_options{'general_min_corrs'}
        = $apr->param('min_correspondences')
        unless defined( $parsed_url_options{'general_min_corrs'} );

    if ( $parsed_url_options{'general_min_corrs'} ) {
        unless ( defined( $parsed_url_options{'left_min_corrs'} ) ) {
            $parsed_url_options{'left_min_corrs'}
                = $parsed_url_options{'general_min_corrs'};
        }
        unless ( defined( $parsed_url_options{'right_min_corrs'} ) ) {
            $parsed_url_options{'right_min_corrs'}
                = $parsed_url_options{'general_min_corrs'};
        }
        unless ( defined( $parsed_url_options{'menu_min_corrs'} ) ) {
            $parsed_url_options{'menu_min_corrs'}
                = $parsed_url_options{'general_min_corrs'};
        }
    }

    $parsed_url_options{'path_info'} = $apr->path_info || q{};
    if ( $parsed_url_options{'path_info'} ) {
        $parsed_url_options{'path_info'}
            =~ s{^/(cmap/)?}{};    # kill superfluous stuff
    }

    if ( $apr->param('comparative_map') ) {
        (   $parsed_url_options{'comparative_map_field'},
            $parsed_url_options{'comparative_map_field_acc'}
        ) = split( /=/, $apr->param('comparative_map') );
    }

    # Get feature type and evidence type info
    $parsed_url_options{'included_feature_types'}      = undef;    # array
    $parsed_url_options{'url_feature_default_display'} = undef;
    $parsed_url_options{'corr_only_feature_types'}     = undef;    # array
    $parsed_url_options{'ignored_feature_types'}       = undef;    # array
    $parsed_url_options{'included_evidence_types'}     = undef;    # array
    $parsed_url_options{'ignored_evidence_types'}      = undef;    # array
    $parsed_url_options{'less_evidence_types'}         = undef;    # array
    $parsed_url_options{'greater_evidence_types'}      = undef;    # array
    $parsed_url_options{'evidence_type_score'}         = undef;    # hash

    foreach my $param ( $apr->param ) {
        if ( $param =~ /^ft_(\S+)/ or $param =~ /^feature_type_(\S+)/ ) {
            my $ft  = $1;
            my $val = $apr->param($param);

            # Handle the "default" specified on the initial selection page
            # write value to url_feature_default_display so that it acts
            # like the ft_DEFAULT
            if ( $ft eq 'FRONT_PAGE_DEFAULT' ) {
                if ( $val =~ /^\d$/ ) {
                    $parsed_url_options{'url_feature_default_display'} = $val;
                }
                else {
                    $parsed_url_options{'url_feature_default_display'}
                        = undef;
                }
                next;
            }

            # This dictates how unspecified feature types are treated
            if ( $ft eq 'DEFAULT' ) {
                if ( $val =~ /^\d$/ ) {
                    $parsed_url_options{'url_feature_default_display'} = $val;
                }
                else {
                    $parsed_url_options{'url_feature_default_display'}
                        = undef;
                }
                next;
            }
            if ( $val == 0 ) {
                push @{ $parsed_url_options{'ignored_feature_types'} }, $ft;
            }
            elsif ( $val == 1 ) {
                push @{ $parsed_url_options{'corr_only_feature_types'} }, $ft;
            }
            elsif ( $val == 2 ) {
                push @{ $parsed_url_options{'included_feature_types'} }, $ft;
            }
        }
        elsif ( $param =~ /^et_(\S+)/ or $param =~ /^evidence_type_(\S+)/ ) {
            my $et  = $1;
            my $val = $apr->param($param);
            if ( $val == 0 ) {
                push @{ $parsed_url_options{'ignored_evidence_types'} }, $et;
            }
            elsif ( $val == 1 ) {
                push @{ $parsed_url_options{'included_evidence_types'} }, $et;
            }
            elsif ( $val == 2 ) {
                push @{ $parsed_url_options{'less_evidence_types'} }, $et;
            }
            elsif ( $val == 3 ) {
                push @{ $parsed_url_options{'greater_evidence_types'} }, $et;
            }
        }
        elsif ( $param =~ /^ets_(\S+)/ ) {
            my $et  = $1;
            my $val = $apr->param($param);
            $parsed_url_options{'evidence_type_score'}->{$et} = $val;
        }
        elsif ( $param =~ /^slot_min_corrs_([-\d]+)/ ) {
            my $slot_no = $1;
            my $val     = $apr->param($param);
            $parsed_url_options{'slot_min_corrs'}->{$slot_no} = $val;
        }
        elsif ( $param =~ /^stack_slot_([-\d]+)/ ) {
            my $slot_no = $1;
            my $val     = $apr->param($param);
            $parsed_url_options{'stack_slot'}->{$slot_no} = $val;
        }
        elsif ( $param =~ /^map_start_([-\d]+)_(\S+)/ ) {
            my $slot_no = $1;
            my $map_acc = $2;
            my $val     = $apr->param($param);
            $parsed_url_options{'map_menu_data'}->{$slot_no}{$map_acc}{start}
                = $val;
        }
        elsif ( $param =~ /^map_stop_([-\d]+)_(\S+)/ ) {
            my $slot_no = $1;
            my $map_acc = $2;
            my $val     = $apr->param($param);
            $parsed_url_options{'map_menu_data'}->{$slot_no}{$map_acc}{stop}
                = $val;
        }
        elsif ( $param =~ /^map_mag_([-\d]+)_(\S+)/ ) {
            my $slot_no = $1;
            my $map_acc = $2;
            my $val     = $apr->param($param);
            $parsed_url_options{'map_menu_data'}->{$slot_no}{$map_acc}{mag}
                = $val;
        }
        elsif ( $param =~ /^map_in_menu_([-\d]+)_(\S+)/ ) {

            # This param tells us to look for check boxes for this map and
            # allows us to deferenciate between unchecked and no check box
            my $slot_no          = $1;
            my $map_acc          = $2;
            my $slot_and_map_str = qq{$slot_no=$map_acc};
            if ( $apr->param( 'map_flip_' . $slot_no . '_' . $map_acc ) ) {
                unless ( $parsed_url_options{'flip'}
                    =~ /(^|:) $slot_and_map_str ($|:)/x )
                {
                    $parsed_url_options{'flip'} = join( ":",
                        $parsed_url_options{'flip'},
                        $slot_and_map_str );
                }
            }
            else {
                if ( $parsed_url_options{'flip'}
                    =~ s/(^|:) $slot_and_map_str ($|:)/$1$2/x )
                {
                    $parsed_url_options{'flip'} =~ s/::/:/x;
                }
            }
        }
    }

    return %parsed_url_options;
}

# ----------------------------------------------------
sub _default_params_if_needed {

    my $parsed_url_options_ref = shift;

    # cycle through the parameters with defaults
    # replace undefined values
    for my $param ( keys %SESSION_PARAM_DEFAULT_OF ) {
        unless ( defined $parsed_url_options_ref->{$param} ) {
            $parsed_url_options_ref->{$param}
                = $SESSION_PARAM_DEFAULT_OF{$param};
        }
    }

    return;
}

# ----------------------------------------------------
sub _create_ref_map_accs {

    my %args = @_;
    my $apr  = $args{'apr'};

    my @ref_map_accs;
    if ( $apr->param('ref_map_accs') or $apr->param('ref_map_aids') ) {
        foreach my $acc ( $apr->param('ref_map_accs'),
            $apr->param('ref_map_aids') )
        {

            # Remove start and stop if they are the same
            while ( $acc =~ s/(.+\[)(\d+)\*\2(\D.*)/$1*$3/ ) { }
            push @ref_map_accs, split( /[:,]/, $acc );
        }
    }

    #
    # Catch old argument, handle nicely.
    #
    if ( $apr->param('ref_map_acc') || $apr->param('ref_map_aid') ) {
        push @ref_map_accs,
            $apr->param('ref_map_acc') || $apr->param('ref_map_aid');
    }

    if ( scalar(@ref_map_accs) ) {
        $apr->param( 'ref_map_accs', join( ":", @ref_map_accs ) );
    }

    return @ref_map_accs;
}

# ----------------------------------------------------
sub _get_or_create_session {

    # if a session id is given, get the session, otherwise
    # create a new session.

    my %args                   = @_;
    my $parsed_url_options_ref = $args{'parsed_url_options_ref'};
    my $calling_cmap_object    = $args{'calling_cmap_object'};
    my $session_dir = $calling_cmap_object->config_data('session_dir')
        || DEFAULT->{'session_dir'};

    if ( $parsed_url_options_ref->{'session_id'} ) {

        #handle the sessions
        $parsed_url_options_ref->{'session'} = new CGI::Session(
            "driver:File",
            $parsed_url_options_ref->{'session_id'},
            { Directory => $session_dir }
        );
        unless ( $parsed_url_options_ref->{'session_data_object'}
            = $parsed_url_options_ref->{'session'}->param('object') )
        {

            # invalid session_id
            $calling_cmap_object->error( 'Invalid session_id: '
                    . $parsed_url_options_ref->{'session_id'} );
            return ();
        }
    }
    else {
        $parsed_url_options_ref->{'session'}
            = new CGI::Session( "driver:File", undef,
            { Directory => $session_dir } );
        $parsed_url_options_ref->{'session_id'}
            = $parsed_url_options_ref->{'session'}->id();
        $parsed_url_options_ref->{'step'} = 0;
        $parsed_url_options_ref->{'next_step'}
            = $parsed_url_options_ref->{'step'} + 1;
        $parsed_url_options_ref->{'session'}->expire('+2w')
            ;    #expires in two weeks
    }

    return 1;
}

# ----------------------------------------------------
sub parse_url {

    my ( $self, $apr, $calling_cmap_object ) = @_;

    # Parse the options
    my %parsed_url_options = _get_options_from_url(
        apr                 => $apr,
        calling_cmap_object => $calling_cmap_object,
    );

    # Create @ref_map_accs
    my @ref_map_accs;

    # Create or get session
    # if a session id is given, get the session, otherwise
    # create a new session.
    unless (
        _get_or_create_session(
            parsed_url_options_ref => \%parsed_url_options,
            calling_cmap_object    => $calling_cmap_object
        )
        )
    {
        return ();    # the error will already have been set
    }

    my %slots;
    $parsed_url_options{'reusing_step'} = 0;

    # Deal with saved session
    if ( defined( $parsed_url_options{'session_data_object'} ) ) {
        unless ( $parsed_url_options{'step'} ) {
            $parsed_url_options{'step'}
                = $#{ $parsed_url_options{'session_data_object'} } + 1;
        }

        my $prev_step = $parsed_url_options{'step'} - 1;
        $parsed_url_options{'next_step'} = $parsed_url_options{'step'} + 1;
        my $step_hash;

        # Check to see if we can just reuse an old session.
        # When debugging it is usefull to add " and 0" to this if statement
        # to stop it from reusing old sessions.

        # Make a md5 hash key from the menu
        $parsed_url_options{'session_menu_hash'}
            = md5( Dumper( $parsed_url_options{'map_menu_data'} )
                . $parsed_url_options{'session_mod'} );
        if ($parsed_url_options{'session_data_object'}
            ->[ $parsed_url_options{'step'} ]
            and $parsed_url_options{'session_data_object'}
            ->[ $parsed_url_options{'step'} ]{'session_menu_hash'}
            and ( $parsed_url_options{'session_data_object'}
                ->[ $parsed_url_options{'step'} ]{'session_menu_hash'} eq
                $parsed_url_options{'session_menu_hash'}
                or $parsed_url_options{'reuse_step'} )
            )
        {
            $step_hash = $parsed_url_options{'session_data_object'}
                ->[ $parsed_url_options{'step'} ];

            $parsed_url_options{'reusing_step'} = 1;
        }
        else {
            $step_hash
                = $parsed_url_options{'session_data_object'}->[$prev_step];
        }
        if ( defined($step_hash) ) {
            _parse_session_step(
                session_step           => $step_hash,
                apr                    => $apr,
                slots_ref              => \%slots,
                parsed_url_options_ref => \%parsed_url_options,
                ref_map_accs_ref       => \@ref_map_accs,
            ) or return $calling_cmap_object->error();

        }
        else {

            # invalid step
            $calling_cmap_object->error(
                'Invalid session step: ' . $parsed_url_options{'step'} );
            return ();
        }
    }

    # Deal with saved_link_id
    elsif ( $parsed_url_options{'saved_link_id'} ) {

        # Get the saved link from the db
        my $saved_links = $calling_cmap_object->sql->get_saved_links(
            saved_link_id => $parsed_url_options{'saved_link_id'}, );
        my $saved_link;
        if ( @{ $saved_links || [] } ) {
            $saved_link = $saved_links->[0];
        }
        else {
            return $calling_cmap_object->error(
                "Invalid Saved Link ID: $parsed_url_options{'saved_link_id'}\n"
            );
        }

        # Extract the session step
        my $session_step = $saved_link->{'session_step_object'}
            or return $calling_cmap_object->error(
            "Saved Link ID, $parsed_url_options{'saved_link_id'}, does not have a valid session object.\n"
            );
        $session_step = thaw($session_step);

        _parse_session_step(
            session_step           => $session_step,
            apr                    => $apr,
            slots_ref              => \%slots,
            parsed_url_options_ref => \%parsed_url_options,
            ref_map_accs_ref       => \@ref_map_accs,
        ) or return $calling_cmap_object->error();
    }

    # Now find any params that need defaults but weren't in the url or the
    # session object
    _default_params_if_needed( \%parsed_url_options );

    # Set the UFDD or get the default UFDD in none is supplied
    $apr->param(
        'ft_DEFAULT',
        $calling_cmap_object->url_feature_default_display(
            $parsed_url_options{'url_feature_default_display'}
        )
    );
    $apr->param( 'feature_type_DEFAULT',  undef );
    $apr->param( 'ft_FRONT_PAGE_DEFAULT', undef );

  # reset the some params only if you want the code to be able to change them.
  # otherwise, simply initialize a value.
    for my $param (
        qw[
        aggregate       show_intraslot_corr
        split_agg_ev    clean_view           hide_legend
        scale_maps      stack_maps           omit_area_boxes
        comp_menu_order ]
        )
    {
        $parsed_url_options{$param}
            = $calling_cmap_object->$param( $parsed_url_options{$param} );
        $apr->param( $param, $parsed_url_options{$param} );
    }

    # Deal with straight url (no session or saved link)
    # If %slots was not found with a session or a saved link
    # then create it from the url
    unless (%slots) {

        @ref_map_accs = _create_ref_map_accs( apr => $apr );

        # Build %ref_maps
        my %ref_maps;
        my %ref_map_sets = ();
        foreach my $ref_map_acc (@ref_map_accs) {
            next if $ref_map_acc eq '-1';
            my ( $start, $stop, $magnification ) = ( undef, undef, 1 );
            (   $ref_map_acc, $start, $stop, $magnification,
                $parsed_url_options{'highlight'}
                )
                = _parse_map_info( $ref_map_acc,
                $parsed_url_options{'highlight'} );
            $ref_maps{$ref_map_acc}
                = { start => $start, stop => $stop, mag => $magnification };
        }

       # If "All" was selected (signified by '-1') then create the ref_map_set
       # reference
        if ( grep {/^-1$/} @ref_map_accs ) {
            $ref_map_sets{ $parsed_url_options{'ref_map_set_acc'} } = ();
        }

        # Only included for legacy urls
        # Deal with modified ref map
        # map info specified in this param trumps 'ref_map_accs' info
        if ( $apr->param('modified_ref_map') ) {
            my $ref_map_acc = $apr->param('modified_ref_map');

            # remove duplicate start and end
            while ( $ref_map_acc =~ s/(.+\[)(\d+)\*\2(\D.*)/$1*$3/ ) { }
            $apr->param( 'modified_ref_map', $ref_map_acc );

            my ( $start, $stop, $magnification ) = ( undef, undef, 1 );
            (   $ref_map_acc, $start, $stop, $magnification,
                $parsed_url_options{'highlight'}
                )
                = _parse_map_info( $ref_map_acc,
                $parsed_url_options{'highlight'} );
            $ref_maps{$ref_map_acc}
                = { start => $start, stop => $stop, mag => $magnification };

            # Add the modified version into the comparative_maps param
            my $found = 0;
            for ( my $i = 0; $i <= $#ref_map_accs; $i++ ) {
                my $old_map_acc = $ref_map_accs[$i];
                $old_map_acc =~ s/^(.*)\[.*/$1/;
                if ( $old_map_acc eq $ref_map_acc ) {
                    $ref_map_accs[$i] = $apr->param('modified_ref_map');
                    $found = 1;
                    last;
                }
            }
            push @ref_map_accs, $apr->param('modified_ref_map') if !$found;
            $apr->param( 'ref_map_accs', join( ":", @ref_map_accs ) );
        }

        %slots = (
            0 => {
                map_set_acc => $parsed_url_options{'ref_map_set_acc'},
                map_sets    => \%ref_map_sets,
                maps        => \%ref_maps,
            }
        );

        #
        # Add in previous maps.
        #
        # Remove start and stop if they are the same
        while ( $parsed_url_options{'comparative_maps'}
            =~ s/(.+\[)(\d+)\*\2(\D.*)/$1*$3/ )
        {
        }

        for my $cmap ( split( /:/, $parsed_url_options{'comparative_maps'} ) )
        {
            my ( $slot_no, $field, $map_acc ) = split( /=/, $cmap ) or next;
            my ( $start, $stop, $magnification );
            foreach my $acc ( split /,/, $map_acc ) {
                (   $acc, $start, $stop, $magnification,
                    $parsed_url_options{'highlight'}
                    )
                    = _parse_map_info( $acc,
                    $parsed_url_options{'highlight'} );
                if ( $field eq 'map_acc' or $field eq 'map_aid' ) {
                    $slots{$slot_no}{'maps'}{$acc} = {
                        start => $start,
                        stop  => $stop,
                        mag   => $magnification,
                    };
                }
                elsif ( $field eq 'map_set_acc' or $field eq 'map_set_aid' ) {
                    unless ( defined( $slots{$slot_no}{'map_sets'}{$acc} ) ) {
                        $slots{$slot_no}{'map_sets'}{$acc} = ();
                    }
                }
            }
        }

        # Deal with modified comp map
        # map info specified in this param trumps comparative_maps info
        if ( $apr->param('modified_comp_map') ) {
            my $comp_map = $apr->param('modified_comp_map');

            # remove duplicate start and end
            while ( $comp_map =~ s/(.+\[)(\d+)\*\2(\D.*)/$1*$3/ ) { }
            $apr->param( 'modified_comp_map', $comp_map );

            my ( $slot_no, $field, $acc ) = split( /=/, $comp_map ) or next;
            my ( $start, $stop, $magnification ) = ( undef, undef, 1 );
            (   $acc, $start, $stop, $magnification,
                $parsed_url_options{'highlight'}
            ) = _parse_map_info( $acc, $parsed_url_options{'highlight'} );
            if ( $field eq 'map_acc' or $field eq 'map_aid' ) {
                $slots{$slot_no}->{'maps'}{$acc} = {
                    start => $start,
                    stop  => $stop,
                    mag   => $magnification,
                };
            }
            elsif ( $field eq 'map_set_acc' or $field eq 'map_set_aid' ) {
                unless ( defined( $slots{$slot_no}->{'map_sets'}{$acc} ) ) {
                    $slots{$slot_no}->{'map_sets'}{$acc} = ();
                }
            }

            # Add the modified version into the comparative_maps param
            my @cmaps = split( /:/, $parsed_url_options{'comparative_maps'} );
            my $found = 0;
            for ( my $i = 0; $i <= $#cmaps; $i++ ) {
                my ( $c_slot_no, $c_field, $c_acc ) = split( /=/, $cmaps[$i] )
                    or next;
                $acc =~ s/^(.*)\[.*/$1/;
                if (    ( $c_slot_no eq $slot_no )
                    and ( $c_field eq $field )
                    and ( $c_acc   eq $acc ) )
                {
                    $cmaps[$i] = $comp_map;
                    $found = 1;
                    last;
                }
            }
            push @cmaps, $comp_map if ( !$found );
        }
    }

    # If this was submitted by a button, clear the modified map fields.
    # They are no longer needed.
    if ( $apr->param('sub') ) {
        $apr->param( 'modified_ref_map',  q{} );
        $apr->param( 'modified_comp_map', q{} );
    }

    # Get collapse_features unless it's defined
    unless ( defined( $parsed_url_options{'collapse_features'} )
        and $parsed_url_options{'collapse_features'} ne q{} )
    {
        $parsed_url_options{'collapse_features'}
            = $calling_cmap_object->config_data('collapse_features');
        $apr->param( 'collapse_features',
            $parsed_url_options{'collapse_features'} );
    }

    # figure out the ref_map_order
    #use the previous order if new order is not defined.
    $calling_cmap_object->ref_map_order(
        defined( $parsed_url_options{'ref_map_order'} )
        ? $parsed_url_options{'ref_map_order'}
        : $parsed_url_options{'prev_ref_map_order'}
    );

    #
    # Set the data source.
    #
    $calling_cmap_object->data_source( $apr->param('data_source') ) or return;
    $apr->param( 'data_source', $calling_cmap_object->data_source );

    # If the ref species is different than before, then we need to start fresh
    if (   $parsed_url_options{'prev_ref_species_acc'}
        && $parsed_url_options{'prev_ref_species_acc'} ne
        $parsed_url_options{'ref_species_acc'} )
    {
        $parsed_url_options{'ref_map_set_acc'} = q{};
    }

    # If the ref map_set is different than before, then we also need to start
    # fresh
    if (   $parsed_url_options{'prev_ref_map_set_acc'}
        && $parsed_url_options{'prev_ref_map_set_acc'} ne
        $parsed_url_options{'ref_map_set_acc'} )
    {
        @ref_map_accs                                = ();
        $parsed_url_options{'ref_map_start'}         = undef;
        $parsed_url_options{'ref_map_stop'}          = undef;
        $parsed_url_options{'comparative_maps'}      = undef;
        $parsed_url_options{'comparative_map_right'} = [];
        $parsed_url_options{'comparative_map_left'}  = [];
    }
    if ( $parsed_url_options{'ref_map_start'} eq '' ) {
        $parsed_url_options{'ref_map_start'} = undef;
    }
    if ( $parsed_url_options{'ref_map_stop'} eq '' ) {
        $parsed_url_options{'ref_map_stop'} = undef;
    }

    # If ref_map_start/stop are defined and there is only one ref map
    # use those values and then wipe them from the params.
    if (    scalar keys( %{ $slots{0}->{'maps'} } ) == 1
        and scalar(@ref_map_accs) == 1 )
    {
        (   $parsed_url_options{'ref_map_start'},
            $parsed_url_options{'ref_map_stop'}
            )
            = (
            $parsed_url_options{'ref_map_stop'},
            $parsed_url_options{'ref_map_start'}
            )
            if (defined( $parsed_url_options{'ref_map_start'} )
            and defined( $parsed_url_options{'ref_map_stop'} )
            and $parsed_url_options{'ref_map_start'}
            > $parsed_url_options{'ref_map_stop'} );
        if ( defined( $parsed_url_options{'ref_map_start'} )
            and $parsed_url_options{'ref_map_start'} ne q{} )
        {
            $slots{0}->{'maps'}{ $ref_map_accs[0] }{'start'}
                = $parsed_url_options{'ref_map_start'};
        }
        if ( defined( $parsed_url_options{'ref_map_stop'} )
            and $parsed_url_options{'ref_map_stop'} ne q{} )
        {
            $slots{0}->{'maps'}{ $ref_map_accs[0] }{'stop'}
                = $parsed_url_options{'ref_map_stop'};
        }
    }
    $apr->delete( 'ref_map_start', 'ref_map_stop', );

    # Build %slot_min_corrs
    my %slot_min_corrs;
    my @slot_nos  = sort { $a <=> $b } keys %slots;
    my $max_right = $slot_nos[-1];
    my $max_left  = $slot_nos[0];

    # general_min_corrs is now legacy
    if ( $parsed_url_options{'general_min_corrs'} ) {
        foreach my $slot_no (@slot_nos) {
            $slot_min_corrs{$slot_no}
                = $parsed_url_options{'general_min_corrs'};
        }
    }

    foreach my $slot_no (@slot_nos) {
        if ( defined( $parsed_url_options{'slot_min_corrs'}->{$slot_no} )
            and $parsed_url_options{'slot_min_corrs'}->{$slot_no} =~ /^\d+$/ )
        {
            $slot_min_corrs{$slot_no}
                = $parsed_url_options{'slot_min_corrs'}->{$slot_no};
        }
        elsif ( not defined $slot_min_corrs{$slot_no} ) {
            $slot_min_corrs{$slot_no} = $slots{$slot_no}->{'min_corrs'} || 0;
        }
        $apr->param( 'slot_min_corrs_' . $slot_no,
            $slot_min_corrs{$slot_no} );
    }

    # LEGACY set the left and the right slots' min corr
    $slot_min_corrs{$max_left} = $parsed_url_options{'left_min_corrs'}
        if $parsed_url_options{'left_min_corrs'};
    $slot_min_corrs{$max_right} = $parsed_url_options{'right_min_corrs'}
        if $parsed_url_options{'right_min_corrs'};

    unless ( $parsed_url_options{'ignore_comp_maps'}
        or $parsed_url_options{'reusing_step'} )
    {

        #
        # Add in our next chosen maps.
        #
        for my $side ( ( RIGHT, LEFT ) ) {
            my $slot_no = $side eq RIGHT ? $max_right + 1 : $max_left - 1;
            my $cmap
                = $side eq RIGHT
                ? $parsed_url_options{'comparative_map_right'}
                : $parsed_url_options{'comparative_map_left'};
            my $cmap_set_acc
                = $side eq RIGHT
                ? $parsed_url_options{'comp_map_set_right'}
                : $parsed_url_options{'comp_map_set_left'};
            if ( @{ $cmap || [] } ) {
                if ( grep {/^-1$/} @$cmap ) {
                    unless (
                        defined(
                            $slots{$slot_no}->{'map_sets'}{$cmap_set_acc}
                        )
                        )
                    {
                        $slots{$slot_no}->{'map_sets'}{$cmap_set_acc} = ();
                    }
                }
                else {
                    foreach my $map_acc (@$cmap) {
                        my ( $start, $stop, $magnification );
                        (   $map_acc, $start, $stop, $magnification,
                            $parsed_url_options{'highlight'}
                            )
                            = _parse_map_info( $map_acc,
                            $parsed_url_options{'highlight'} );

                        $slots{$slot_no}{'maps'}{$map_acc} = {
                            start => $start,
                            stop  => $stop,
                            mag   => $magnification,
                        };
                    }
                }

                # Set this slots min corrs
                $slot_min_corrs{$slot_no}
                    = $parsed_url_options{ 'corr_menu_min_corrs_'
                        . lc $side };

            }
        }
    }

    $parsed_url_options{'slots'}          = \%slots;
    $parsed_url_options{'slot_min_corrs'} = \%slot_min_corrs;
    $parsed_url_options{'ref_map_accs'}   = \@ref_map_accs;

    $parsed_url_options{'data_source'} = $calling_cmap_object->data_source;
    $parsed_url_options{'config'}      = $calling_cmap_object->config;
    $parsed_url_options{'data_module'} = $calling_cmap_object->data_module;
    $parsed_url_options{'ref_map_order'}
        = $calling_cmap_object->ref_map_order;

    return %parsed_url_options;
}

# ----------------------------------------------------
# Creates a session step and adds it to the session data object
# which is stored int the parsed_url_options ref.
# Returns the step object.
sub create_session_step {

    my ( $self, $parsed_url_options_ref, ) = @_;
    my $step_object = {
        slots             => $parsed_url_options_ref->{'slots'},
        ref_species_acc   => $parsed_url_options_ref->{'ref_species_acc'},
        ref_map_set_acc   => $parsed_url_options_ref->{'ref_map_set_acc'},
        session_mod       => $parsed_url_options_ref->{'session_mod'},
        session_menu_hash => $parsed_url_options_ref->{'session_menu_hash'},
    };

    for my $param (@SESSION_PARAMS) {
        $step_object->{$param} = $parsed_url_options_ref->{$param},;
    }

    if (    $parsed_url_options_ref->{'session_data_object'}
        and $parsed_url_options_ref->{'step'} )
    {

        # Add to current session object
        $parsed_url_options_ref->{'session_data_object'}
            ->[ $parsed_url_options_ref->{'step'} ] = $step_object;

        # Trim off later steps if this step is in the middle
        # (via the back button).
        if ( $#{ $parsed_url_options_ref->{'session_data_object'} }
            > $parsed_url_options_ref->{'step'} )
        {
            splice( @{ $parsed_url_options_ref->{'session_data_object'} },
                $parsed_url_options_ref->{'step'} + 1 );
        }
    }
    else {

        # new session object
        $parsed_url_options_ref->{'session_data_object'} = [$step_object];
    }

    if ( defined $parsed_url_options_ref->{'session'} ) {
        $parsed_url_options_ref->{'session'}->param( 'object',
            $parsed_url_options_ref->{'session_data_object'} );
    }

    return $step_object;
}

1;

# ----------------------------------------------------
# I have never yet met a man who was quite awake.
# How could I have looked him in the face?
# Henry David Thoreau
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

