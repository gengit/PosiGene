package Bio::Graphics::Layout;

# shamelessly stolen from Mitch Skinner's JBrowse package and ported to perl.
# Original copyright here
#Copyright (c) 2007-2010 The Evolutionary Software Foundation
#
#Created by Mitchell Skinner <mitch_skinner@berkeley.edu>
#
#This package and its accompanying libraries are free software; you can
#redistribute it and/or modify it under the terms of the LGPL (either
#version 2.1, or at your option, any later version) or the Artistic
#License 2.0.  Refer to LICENSE for the full license text.

use strict;

# /*
#  * Code for laying out rectangles, given that layout is also happening
#  * in adjacent blocks at the same time
#  *
#  * This code does a lot of linear searching; n should be low enough that
#  * it's not a problem but if it turns out to be, some of it can be changed to
#  * binary searching without too much work.  Another possibility is to merge
#  * contour spans and give up some packing closeness in exchange for speed
#  * (the code already merges spans that have the same x-coord and are vertically
#  * contiguous).
#  */

sub new {
    my $class = shift;
    my ($leftBound, $rightBound) = @_;
    my $self = bless {},ref $class || $class;
    $self->{leftBound}  = $leftBound;
    $self->{rightBound} = $rightBound;
    # a Layout contains a left contour and a right contour;
    # the area between the contours is allocated, and the
    # area outside the contours is free.
    $self->{leftContour}  = Bio::Graphics::Layout::Contour->new();
    $self->{rightContour} = Bio::Graphics::Layout::Contour->new();
    $self->{seen} = {};
    $self->{leftOverlaps}  = [];
    $self->{rightOverlaps} = [];
    $self->{totalHeight}   = 0;
    return $self;
}

sub totalHeight {shift->{totalHeight}}

sub addRect {
    my $self = shift;
    my ($id,$left,$right,$height) = @_;

    if (defined $self->{seen}{$id}) {return $self->{seen}{$id}};
    
    # for each contour, we test the fit on the near side of the given rect,
    my $leftFit  = $self->tryLeftFit($left, $right, $height, 0);
    my $rightFit = $self->tryRightFit($left, $right, $height, 0);

    my $top;

    # and insert the far side from the side we tested
    # (we want to make sure the near side fits, but we want to extend
    #  the contour to cover the far side)
    if ($leftFit->{top} < $rightFit->{top}) {
        $top = $leftFit->{top};
        $self->{leftContour}->insertFit($leftFit->{fit}, $self->{rightBound} - $left,
					$top, $height);
        $self->{rightContour}->unionWith($right - $self->{leftBound}, $top, $height);
    } else {
        $top = $rightFit->{top};
        $self->{rightContour}->insertFit($rightFit->{fit}, $right - $self->{leftBound},
					 $top, $height);
        $self->{leftContour}->unionWith($self->{rightBound} - $left, $top, $height);
    }

    my $existing = {id      => $id, 
		   left    => $left, 
		   right   => $right,
		   top     => $top, 
		   height  => $height};
    $self->{seen}{$id} = $top;
    if ($left <= $self->{leftBound}) {
        push(@{$self->{leftOverlaps}},$existing);
        if ($self->{leftLayout}) {
	    $self->{leftLayout}->addExisting($existing);
	}
    }
    if ($right >= $self->{rightBound}) {
        push(@{$self->{rightOverlaps}},$existing);
        if ($self->{rightLayout}) {
	    $self->{rightLayout}->addExisting($existing);
	}
    }
    $self->{seen}{$id}   = $top;
    $self->{totalHeight} = Bio::Graphics::Math::max($self->{totalHeight}, $top + $height);
    return $top;
}

# this method is called by the block to the left to see if a given fit works
# in this layout
# takes: proposed rectangle
# returns: {top: value that makes the rectangle fit in this layout,
#           fit: "fit" for passing to insertFit}
sub tryLeftFit {
    my $self = shift;
    my ($left,$right,$height,$top) = @_;

    my ($fit, $nextFit);
    my $curTop = $top;

    while (1) {
        # check if the rectangle fits at curTop
        $fit = $self->{leftContour}->getFit($self->{rightBound} - $right, $height, $curTop);
        $curTop = Bio::Graphics::Math::max($self->{leftContour}->getNextTop($fit), $curTop);
        # if the rectangle extends onto the next block to the right;
        if ($self->{rightLayout} && ($right >= $self->{rightBound})) {
            # check if the rectangle fits into that block at this position
            $nextFit = $self->{rightLayout}->tryLeftFit($left, $right, $height, $curTop);
            # if not, nextTop will be the next y-value where the rectangle
            # fits into that block
            if ($nextFit->{top} > $curTop) {
                # in that case, try again to see if that y-value works
                $curTop = $nextFit->{top};
		next;
            }
        }
	last;
    }
    return {top=> $curTop, fit=> $fit};
}

# this method is called by the block to the right to see if a given fit works
# in this layout
# takes: proposed rectangle
# returns: {top: value that makes the rectangle fit in this layout,
#           fit: "fit" for passing to insertFit}
sub tryRightFit {
    my $self = shift;
    my ($left,$right,$height,$top) = @_;
    
    my ($fit, $nextFit);
    my $curTop = $top;

    while (1) {
        # check if the rectangle fits at curTop
        $fit = $self->{rightContour}->getFit($left - $self->{leftBound}, $height, $curTop);
        $curTop = Bio::Graphics::Math::max($self->{rightContour}->getNextTop($fit), $curTop);
        # if the rectangle extends onto the next block to the left;
        if ($self->{leftLayout} && ($left <= $self->{leftBound})) {
            # check if the rectangle fits into that block at this position
            $nextFit = $self->{leftLayout}->tryRightFit($left, $right, $height, $curTop);
            # if not, nextTop will be the next y-value where the rectangle
            # fits into that block
            if ($nextFit->{top} > $curTop) {
                # in that case, try again to see if that y-value works
                $curTop = $nextFit->{top};
                next;
            }
        }
	last
    }
    return {top => $curTop, fit => $fit};
}

sub hasSeen {
    my $self = shift;
    my $id   = shift;
    return defined $self->{seen}{$id};
}

sub setLeftLayout {
    my $self = shift;
    my $left = shift;

    for (my $i = 0; $i < @{$self->{leftOverlaps}}; $i++) {
        $left->addExisting($self->{leftOverlaps}[$i]);
    }

    $self->{leftLayout} = $left;
};

sub setRightLayout {
    my $self = shift;
    my $right = shift;

    for (my $i = 0; $i < @{$self->{rightOverlaps}}; $i++) {
        $right->addExisting($self->{rightOverlaps}[$i]);
    }
    $self->{rightLayout} = $right;
};

sub cleanup {
    my $self = shift;
    undef $self->{leftLayout};
    undef $self->{rightLayout};
};

# expects an {id, left, right, height, top} object
sub addExisting {
    my $self = shift;
    my $existing = shift;

    if (defined $self->{seen}[$existing->{id}]) {return};
    $self->{seen}{$existing->{id}} = $existing->{top};

    $self->{totalHeight} =
        Bio::Graphics::Math::max($self->{totalHeight}, $existing->{top} + $existing->{height});
    
    if ($existing->{left} <= $self->{leftBound}) {
        push(@{$self->{leftOverlaps}},$existing);
        if ($self->{leftLayout}) {
	    $self->{leftLayout}->addExisting($existing);
	}
    }
    if ($existing->{right} >= $self->{rightBound}) {
        push(@{$self->{rightOverlaps}},$existing);
        if ($self->{rightLayout}) {
	    $self->{rightLayout}->addExisting($existing);
	}
    }

    $self->{leftContour}->unionWith($self->{rightBound} - $existing->left,
				    $existing->{top},
				    $existing->{height});
    $self->rightContour->unionWith($existing->{right} - $self->{leftBound},
				   $existing->{top},
				   $existing->{height});
}

package Bio::Graphics::Layout::Contour;
use constant INF => 1<<16;

sub new {
    my $class = shift;
    my $top   = shift;

    # /*
    #  * A contour is described by a set of vertical lines of varying heights,
    #  * like this:
    #  *                         |
    #  *                         |
    #  *               |
    #  *                   |
    #  *                   |
    #  *                   |
    #  *
    #  * The contour is the union of the rectangles ending on the right side
    #  * at those lines, and extending leftward toward negative infinity.
    #  *
    #  * <=======================|
    #  * <=======================|
    #  * <==========|
    #  * <=================|
    #  * <=================|
    #  * <=================|
    #  *
    #  * x -->
    #  *
    #  * As we add new vertical spans, the contour expands, either downward
    #  * or in the direction of increasing x.
    #  */
    # // takes: top, a number indicating where the first span of the contour
    # // will go

    $top ||= 0;

    # // spans is an array of {top, x, height} objects representing
    # // the boundaries of the contour
    # // they're always sorted by top
    return bless {spans => 
		      [
		       {top=> $top,
			x  => INF,
			height => 0}
		      ]
    },ref $class || $class;
}

sub spans {shift->{spans}}

# // finds a space in the contour into which the given span fits
# // (i.e., the given span has higher x than the contour over its vertical span)
# // returns an ojbect {above, count}; above is the index of the last span above
# // where the given span will fit, count is the number of spans being
# // replaced by the given span
sub getFit {
    my $self = shift;
    my ($x,$height,$minTop) = @_;
    
    my ($aboveBottom, $curSpan);
    my $above = 0;
    my $spans = $self->spans;

    if ($minTop) {
        # set above = (index of the first span that starts below minTop)
        for (; $spans->[$above]{top} < $minTop; $above++) {
            if ($above >= (@$spans - 1)) {
                return {above=> @$spans - 1, count=> 0};
	    }
        }
    }

    # slide down the contour
    my $count;
  ABOVE: 
    for (; $above < @$spans; $above++) {
        $aboveBottom = $spans->[$above]{top} + $spans->[$above]{height};
        for ($count = 1; $above + $count < @$spans; $count++) {
            $curSpan = $spans->[$above + $count];
            if (($aboveBottom + $height) <= $curSpan->{top}) {
                # the given span fits between span[above] and
                # curSpan, keeping curSpan
                return {above=> $above, count=> $count - 1};
            }
            if ($curSpan->{x} > $x) {
                # the span at [above + count] overlaps the given span,
                # so we continue down the contour
                next ABOVE;
            }
            if (($curSpan->{x} <= $x) &&
                (($aboveBottom + $height) < ($curSpan->{top} + $curSpan->{height}))) {
                # the given span partially covers curSpan, and
                # will overlap it, so we keep curSpan
                return {above=> $above, count=> $count - 1};
            }
        }
        # the given span fits below span[above], replacing any
        # lower spans in the contour
        return {above=> $above, count => $count - 1};
    }
    # the given span fits at the end of the contour, replacing no spans
    return {above => $above, count => 0};
}

# add the given span to this contour where it fits, as given
# by getFit
sub insertFit {
    my $self = shift;
    my ($fit,$x,$top,$height) = @_;

    my $spans = $self->spans;

    # if the previous span and the current span have the same x-coord,
    # and are vertically contiguous, merge them.
    my $prevSpan = $spans->[$fit->{above}];
    if ((abs($prevSpan->{x} - $x) < 1)
        && (abs(($prevSpan->{top} + $prevSpan->{height}) - $top) < 1) ) {
        $prevSpan->{height} = ($top + $height) - $prevSpan->{top};
        # a bit of slop here is conservative if we take the max
        # (means things might get laid out slightly farther apart
        # than they would otherwise)
        $prevSpan->{x} = Bio::Graphics::Math::max($prevSpan->{x}, $x);
        splice(@$spans,$fit->{above} + 1, $fit->{count});
    } else {
        splice(@$spans,$fit->{above} + 1, $fit->{count},
                          {
                              top    => $top,
                              x      => $x,
                              height => $height
                          });
    }
}

# add the given span to this contour at the given location, if
# it would extend the contour
sub unionWith {
    my $self = shift;
    my ($x,$top,$height) = @_;
    
    my ($startBottom, $startIndex, $endIndex, $startSpan, $endSpan);
    my $bottom = $top + $height;
    my $spans = $self->spans;

  START: 
    for ($startIndex = 0; $startIndex < @$spans; $startIndex++) {
        $startSpan = $spans->[$startIndex];
        $startBottom = $startSpan->{top} + $startSpan->{height};
        if ($startSpan->{top} > $top) {
            # the given span extends above an existing span
            $endIndex = $startIndex;
            last START;
        }
        if ($startBottom > $top) {
            # if startSpan covers (at least some of) the given span,
            if ($startSpan->{x} >= $x) {
                my $covered = $startBottom - $top;
                # we don't have to worry about the covered area any more
                $top    += $covered;
                $height -= $covered;
                # if we've eaten up the whole span, then it's submerged
                # and we don't have to do anything
                if ($top >= $bottom) { return };
                next;
            } else {
                # find the first span not covered by the given span
                for ($endIndex = $startIndex;
                     $endIndex < @$spans;
                     $endIndex++) {
                    $endSpan = $spans->[$endIndex];
                    # if endSpan extends below or to the right
                    # of the given span, then we need to keep it
                    if ((($endSpan->{top} + $endSpan->{height}) > $bottom)
                        || $endSpan->{x} > $x) {
                        last START;
                    }
                }
                last START;
            }
        }
    }

    # if the previous span and the current span have the same x-coord,
    # and are vertically contiguous, merge them.
    my $prevSpan = $spans->[$startIndex - 1];
    if ((abs($prevSpan->{x} - $x) < 1)
        && (abs(($prevSpan->{top} + $prevSpan->{height}) - $top) < 1) ) {
        $prevSpan->{height} = ($top + $height) - $prevSpan->{top};
        $prevSpan->{x} = Bio::Graphics::Math::max($prevSpan->{x}, $x);
        splice(@$spans,$startIndex, $endIndex - $startIndex);
    } else {
        splice(@$spans,$startIndex, $endIndex - $startIndex,
                          {
                              top    => $top,
                              x      => $x,
                              height => $height
                          });
    }
}

# returns the top of the to-be-added span that fits into "fit"
# (as returned by getFit)
sub getNextTop {
    my $self = shift;
    my $fit  = shift;
    return $self->spans->[$fit->{above}]{top} + $self->spans->[$fit->{above}]{height};
};

package Bio::Graphics::Math;

sub max {$_[0] > $_[1] ? $_[0] : $_[1]}



1;
