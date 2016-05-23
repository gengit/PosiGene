package Bio::Graphics::Glyph::point_glyph;

use strict;
use base qw(Bio::Graphics::Glyph::generic);

sub box {
  my $self = shift;
  my @result = $self->SUPER::box();
  return @result unless $self->option('point') && $result[2]-$result[0] < 3;
  my $h   = $self->option('height')/2;
  my $mid = int(($result[2]+$result[0])/2);
  $result[0] = $mid-$h-1;  # fudge a little to make it easier to click on
  $result[2] = $mid+$h+1;
  return @result;
}

1;
