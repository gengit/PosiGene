package Bio::PrimerDesigner::Tables;

# $Id: Tables.pm 9 2008-11-06 22:48:20Z kyclark $

=pod

=head1 NAME 

Bio::PrimerDesigner::Table -- Draw HTML tables for PCR primer display

=head1 DESCRIPTION

Draws simple HTML tables to display Bio::PrimerDesigner PCR primer
design and e-PCR results for web applications.

=head1 METHODS

=cut

use strict;
use warnings;
use Readonly;

Readonly our 
    $VERSION => sprintf "%s", q$Revision: 24 $ =~ /(\d+)/;

use base 'Class::Base';

# -------------------------------------------------------------------
sub info_table {

=head2 info_table

Prints a two-column table for generic, key-value style annotations.
Expects to be passed the name of the gene/feature/etc. and a hash of
attributes. If there is an 'image' key, the value is assumed to be an
image URL, which is printed in a double-wide cell at the bottom of the
table.


  my $gene       = 'Abc-1';
  my %gene_info  = (
      Chromosome => I,
      Start      => 100450,
      Stop       => 102893,
      Strand     => '+'
  );

  my $page = Bio::PrimerDesigner::Tables->new;
  $page->info_table( $gene, %gene_info );

=cut

    my $self  = shift;
    my $name  = shift or return $self->error('No name argument');
    my %info  = @_ or return $self->error('No attributes');
    my $image = $info{'image'} || '';
    delete $info{'image'} if $image;
    my $table .= <<"    END";
    <table width=710 border=0 cellpadding=5>
    <tr>
    <th colspan=2 bgcolor=blue align="center">
    <font size=+2 color=white>$name Information</font>
    </th>
    </tr>
    END

    for my $key (sort keys %info) {
        next if $key eq 'other';
	
	my $ukey = ucfirst $key;
        
        $table .= <<"        END";
        <tr valign=top>
        <td width=20%>
        <b>$ukey</b>
        </td>
        <td>
        $info{$key}
        </td>
        </tr>
        END
    }
    
    my $other = $info{'other'};
    $table .= <<"    END" if $other;
    <tr valign=top>
    <td width=20%>
    <b>Other</b>
    </td>
    <td>
    $other
    </td>
    </tr>
    END
    
    $table .= $image ? "<tr><td colspan=2>$image</td></tr><table>"
                     : "</table>";
}

# -------------------------------------------------------------------
sub PCR_header {

=head2 PCR_header

Returns a generic header for the PCR primer table.  Does not expect
any argumments.

=cut

    my $self = shift;

    return "
    <table align=center width=710>
    <tr>
    <th bgcolor='#3333FF' align=center>
    <font color=white size=5>PCR Primers</font>
    </th>
    </tr>
    </table>
    "
}

# -------------------------------------------------------------------
sub PCR_set {

=head2 PCR_set

Returns the top row for the PCR primer table.  Expects the primer set
number as its only argument.

=cut

    my $self = shift;
    my $num  = shift || '';

    return "
    <table BORDER=0 WIDTH=710>
    <tr BGCOLOR='#3399FF'>
    <th bgcolor='#000066' align=center>
    <font color=white><b>Set $num</b></font>
    </th>
    <th>Primer</th>
    <th>Sequence</th>
    <th>Tm</th>
    <th ALIGN=CENTER>Coordinate</th>
    <th ALIGN=CENTER>Primer Pair Quality</th>
    </tr>
    ";
}    

# -------------------------------------------------------------------
sub PCR_row {

=head2 PCR_row

Returns table rows with PCR primer info.  Should be called once for
each primer pair.  Expects to be passed a hash containing the
Bio::PrimerDesigner::Result object and the primer set number and an
(optional) label.

  my $pcr_row =  PCR_row( 
      primers => $result_obj,
      setnum  => $set_number,
      label   => $label
  );

=cut

    my $self    = shift;
    my %primers = @_ or return $self->error('No arguments for PCR_row method');
    my $set     = $primers{'setnum'} || 1;
    my $label   = $primers{'label'}  || 1;
    my %args    = %{$primers{'primers'}{$set}};
    
    return "
    <tr>
    <td>$label</td>
    <td>Forward</td>
    <td>$args{'left'}</td>
    <td>$args{'tmleft'}</td>
    <td ALIGN=CENTER>$args{'startleft'}</td>
    <td>&nbsp;</td>
    </tr>
    <tr>
    <td>&nbsp;</td>
    <td>Reverse</td>
    <td>$args{'right'}</td>
    <td>$args{'tmright'}</td>
    <td ALIGN=CENTER>$args{'startright'}</td>
    <td ALIGN=CENTER>$args{'qual'}</td>
    </tr>
    ";
}

# -------------------------------------------------------------------
sub ePCR_row {

=head2 ePCR_row

Returns table rows summarizing e-PCR results.  Expects to be passed an
Bio::PrimerDesigner::Result e-PCR results object and an optional e-PCR label.

=cut

    my $self = shift;
    my $args = shift or return $self->error('No arguments for ePCR_row method');
    my %epcr = %$args;
    my $label = shift;
    my $num_prods = $epcr{1}{'products'};
    my $s = $num_prods > 1 ? 's' : '';
    $num_prods ||= 'No';
    my $sizes = '';

    for (1..$num_prods) {
        if ($_ == 1) {
            $sizes = "Size$s $epcr{$_}{'size'}"
        }
        elsif ($_ < $num_prods) {
            $sizes .= ", " . $epcr{$_}{'size'}
        }
        else {
            $sizes .= "and " . $epcr{$_}{'size'}
        }
    }
    $sizes .= " bp" if $num_prods ne 'No';
    my $row = "
    <tr BGCOLOR='#99FFFF'>
    <th colspan=6 align=left>
    <b>$label e-PCR Results:</b> 
    &nbsp;$num_prods product${s}
    &nbsp;&nbsp;
    $sizes
    </th>
    </tr>
    <tr><td>&nbsp;</td></tr>
";

    $row;
}

# -------------------------------------------------------------------
sub render {

=head2 render

Renders the image URL. Expects to be passed a hash of the map start
and stop, and other features to be mapped (i.e.
gene,forward_primer,reverse_primer, label,start and stop of each
feature, and gene strand).

  my $image =  $page->render( 
      start => $startleft,
      stop  => $startright,
      feat  => $features
  );

=cut

    my $self  = shift;
    my %draw  = @_ or return $self->error('No name argument');
    my $start = $draw{'start'} ||  0;
    my $stop  = $draw{'stop'}  ||  0;
    my $feat  = $draw{'feat'}  || '';

    (my $config = <<"END") =~ s/^\s+//gm;
    [general]
    bases  = $start-$stop
    height = 12

    [gene]
    glyph       = transcript2
    bgcolor     = cyan
    label       = 1
    description = 1
    height      = 7

    [forward_primer]
    glyph   = triangle
    bgcolor = blue
    orient  = E
    height  = 7
    label   = 1

    [reverse_primer]
    glyph   = triangle
    bgcolor = green
    orient  = W
    height  = 7
    label   = 1

    $feat
END

    $config =~ s/\n/@@/gm;
    $config =~ s/\s+/%20/g;

    $config = "<br><img src=\"http://elegans.bcgsc.bc.ca/".
            "perl/render?width=700;text=\'$config\'\">";
    return $config;	    
}

# -------------------------------------------------------------------
sub PCR_map {

=head2 PCR_map

Returns a 6 column wide table cell with the <IMG ...> info.
Will display the image of mapped primers in the browser when
passed the image URL.

=cut

    my $self = shift;
    my $image_url = shift || '';
    
    return "
    <tr>
    <td colspan=6>
    $image_url
    </td>
    </tr>
    <tr>
    <td colspan=6>&nbsp;</td>
    </tr>
    ";
}

1;

# -------------------------------------------------------------------

=pod

=head1 AUTHOR

Copyright (C) 2003-2009 Sheldon McKay E<lt>mckays@cshl.eduE<gt>.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; version 3 or any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301
USA.

=head1 SEE ALSO

Bio::PrimerDesigner::primer3, Bio::PrimerDesigner::epcr.

=cut
