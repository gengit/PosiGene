package Bio::Graphics::Glyph::smoothing;
use base 'Bio::Graphics::Glyph';

use strict;

use constant SMOOTHING  => 'mean';

sub my_options {
    {
	smoothing => [
	    ['none','mean','max','min'],
	    'none',
	     'Whether to smooth data values across a defined window.',
	     'Mean smoothing will run a rolling mean across the window.',
	     'Max smoothing will take the maximum value across the window,',
	     'and min smoothing will take the minimum value.'
	    ],
	smoothing_window => [
	    'integer',
	    undef,
	     'Size of the smoothing window. If not specified, the window',
             'will be taken to be 10% of the region under display.'
	    ],
    };
}


sub get_smoothing {
  my $self = shift;
  return 'none' if $self->smooth_window == 1;
  return $self->option('smoothing') or SMOOTHING;
}

sub smooth_window {
  my $self    = shift;

  my $smooth_window = $self->option('smoothing_window') 
                    || $self->option('smoothing window'); # drat!
  return $smooth_window if defined $smooth_window; 

  my $start = $self->smooth_start;
  my $end   = $self->smooth_end;

  $smooth_window = int (($end - $start)/(10*$self->width));
  $smooth_window = 1 unless $smooth_window > 2;
  return $smooth_window;
}

sub smooth_start {
  my $self = shift;
  my ($start) = sort {$b<=>$a} ($self->feature->start,$self->panel->start);
  return $start;
}

sub smooth_end {
  my $self = shift;
  my ($end) = sort {$a<=>$b} ($self->feature->end,$self->panel->end);
  return $end;
}

1;

