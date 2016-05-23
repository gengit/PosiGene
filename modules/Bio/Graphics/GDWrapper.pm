package Bio::Graphics::GDWrapper;

use base 'GD::Image';
use Memoize 'memoize';
use Carp 'cluck';
memoize('_match_font');

my $DefaultFont;

#from http://reeddesign.co.uk/test/points-pixels.html
my %Pixel2Point = (
    8 => 6,
    9 => 7,
    10 => 7.5,
    11 => 8,
    12 => 9,
    13 => 10,
    14 => 10.5,
    15 =>11,
    16 => 12,
    17 => 13,
    18 => 13.5,
    19 => 14,
    20 => 14.5,
    21 => 15,
    22 => 16,
    23 => 17,
    24 => 18,
    25 => 19,
    26 => 20
    );
my $GdInit;

sub new {
    my $self = shift;
    my ($gd,$default_font) = @_;
    $DefaultFont = $default_font unless $default_font eq '1';
    $gd->useFontConfig(1);
    return bless $gd,ref $self || $self;
}

sub default_font { return $DefaultFont || 'Arial' }

# print with a truetype string
sub string {
    my $self = shift;
    my ($font,$x,$y,$string,$color) = @_;
    return $self->SUPER::string(@_) if $self->isa('GD::SVG');
    my $fontface   = $self->_match_font($font);
#     warn "$font => $fontface";
    my ($fontsize) = $fontface =~ /-(\d+)/;
    $self->stringFT($color,$fontface,$fontsize,0,$x,$y+$fontsize+1,$string);
}

sub string_width {
    my $self = shift;
    my ($font,$string) = @_;
    my $fontface = $self->_match_font($font);
    my ($fontsize) = $fontface =~ /-([\d.]+)/;
    my @bounds   = GD::Image->stringFT(0,$fontface,$fontsize,0,0,0,$string);
    return abs($bounds[2]-$bounds[0]);
}

sub string_height {
    my $self = shift;
    my ($font,$string) = @_;
    my $fontface = $self->_match_font($font);
    my ($fontsize) = $fontface =~ /-(\d+)/;
    my @bounds   = GD::Image->stringFT(0,$fontface,$fontsize,0,0,0,$string);
    return abs($bounds[5]-$bounds[3]);
}

# find a truetype match for a built-in font
sub _match_font {
    my $self = shift;
    my $font = shift;
    return $font unless ref $font && $font->isa('GD::Font');

    # work around older versions of GD that require useFontConfig to be called from a GD::Image instance
    $GdInit++ || eval{GD::Image->useFontConfig(1)} || GD::Image->new(10,10)->useFontConfig(1);

    my $fh     = $font->height-1;
    my $height = $Pixel2Point{$fh} || $fh;
    my $style  = $font eq GD->gdMediumBoldFont ? 'bold'
	        :$font eq GD->gdGiantFont      ? 'bold'
                :'normal';
    my $ttfont = $self->default_font;
    return "$ttfont-$height:$style";
}

1;
