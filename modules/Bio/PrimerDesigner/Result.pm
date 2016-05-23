package Bio::PrimerDesigner::Result;

# $Id: Result.pm 14 2008-11-07 02:40:49Z kyclark $

=head1 NAME 

Bio::PrimerDesigner::Result - a class for handling primer 
design or validation results

=head1 SYNOPSIS

  use Bio::PrimerDesigner;
 
  #  
  # primer3  
  #  
  my $primer3_obj = Bio::PrimerDesigner->new( program => 'primer3 );  
  my $result = $primer3_obj->design( %hash_of_options );
  my $left_primer = $result->left;  
  my @left_primers = $result->left(1..$num_primers);  
 
  #
  # e-PCR -- first make a hash of options from primer3 results
  # then run e-PCR
  #
  my $epcr_obj = Bio::PrimerDesigner->new( program => 'primer3 );
  my $epcr_result = $epcr_obj->design( %hash_of_options );
  my $num_products = $epcr_result->products; 
 
  #
  # one product
  #
  my $first_prod_size = $epcr_result->size;
  my $first_prod_start = $epcr_result->start;
  my $first_prod_stop = $epcr_result->start;  
 
  #
  # more than one product
  #
  my @pcr_product_sizes = ();
  for (1..$num_products) {
      push @pcr_product_sizes, $epcr_result->size;   
  }     

=head1 DESCRIPTION

 Bio::PrimerDesigner::Result will autogenerate result access methods
 for for Native Boulder IO keys and Bio::PrimerDesigner keys for
 primer3, e-PCR, isPcr and ipcress.

=head1 METHODS

=cut

use strict;
use warnings;
use Readonly;

Readonly our 
    $VERSION => sprintf "%s", q$Revision: 24 $ =~ /(\d+)/;

use base 'Class::Base';

Readonly my @AUTO_FIELDS => qw(
    ***PRIMER3_KEYS*** 
    PRIMER_LEFT_EXPLAIN PRIMER_RIGHT_EXPLAIN PRIMER_PAIR_EXPLAIN
    PRIMER_INTERNAL_OLIGO_EXPLAIN left_explain right_explain
    hyb_oligo_explain hyb_oligo lselfend PRIMER_LEFT rendstab 
    PRIMER_LEFT_SEQUENCE prod SEQUENCE TARGET PRIMER_RIGHT_END_STABILITY 
    right lselfany PRIMER_RIGHT_GC_PERCENT left PRIMER_PRODUCT_SIZE_RANGE 
    PRIMER_PAIR_COMPL_END raw_output lendstab PRIMER_INTERNAL_OLIGO_TM 
    hyb_tm PRIMER_RIGHT_SEQUENCE PRIMER_PRODUCT_SIZE PRIMER_PAIR_COMPL_ANY 
    leftgc PRIMER_LEFT_SELF_END rightgc rqual qual PRIMER_PAIR_PENALTY 
    PRIMER_LEFT_SELF_ANY PRIMER_SEQUENCE_ID PRIMER_LEFT_TM PRIMER_RIGHT_TM
    tmright PRIMER_RIGHT startright tmleft pairendcomp PRIMER_RIGHT_SELF_END
    PRIMER_LEFT_GC_PERCENT rselfend PRIMER_LEFT_PENALTY PRIMER_RIGHT_PENALTY
    EXCLUDED_REGION PRIMER_LEFT_END_STABILITY PRIMER_NUM_RETURN 
    PRIMER_RIGHT_SELF_ANY rselfany pairanycomp lqual startleft
    ***other keys*** 
    products size start stop end amplicon strand
);

# -------------------------------------------------------------------
sub init {
    my ( $self, $config ) = @_;

    $self->params( $config, 'data' );

    for my $sub_name ( @AUTO_FIELDS ) {
        next if $sub_name =~ /^\*/;

        no strict 'refs';
        *{ $sub_name } = sub {
            my $self    = shift;
            my @nums    = @_;
            $nums[0]  ||= 1;
            my @result  = map { $self->{$_}->{$sub_name} } @nums;
            return @result > 1 ? @result : $result[0];
        }
    }

    return $self;
}

# -------------------------------------------------------------------
sub keys {

=pod

=head2 keys

 This handles result method calls made via the
 Bio::PrimerDesigner::Result object.  Returns either a scalar or list
 depending on the on the arguments:

  ------------------+------------------------
   Args passed      |  Returns
  ------------------+------------------------
   none                scalar value for set 1
   numeric n           scalar value for set n
   numeric list 1..n   list with n elements

 The aliased output methods (below) return a string when called in a 
 scalar context and a list when called in a list context.  The native 
 primer3 (Boulder IO) keys can also be used.  There are also e-PCR,
 isPcr and ipcress specific methods

B<Primer3 keys>

=over 4

=item * left        -- left primer sequence

=item * right       -- right primer sequence

=item * hyb_oligo   -- internal oligo sequence

=item * startleft   -- left primer 5' sequence coordinate

=item * startright  -- right primer 5' sequence coordinate

=item * tmleft      -- left primer tm

=item * tmright     -- right primer tm

=item * qual        -- primer pair penalty (Q value)

=item * lqual       -- left primer penalty

=item * rqual       -- right primer penalty

=item * leftgc      -- left primer % gc

=item * rightgc     -- right primer % gc

=item * lselfany    -- left primer self-complementarity (any)

=item * lselfend    -- left primer self-complementarity (end)

=item * rselfany    -- right primer self-complementarity (any)

=item * rselfend    -- right primer self-complementarity (end)         

=item * pairanycomp -- primer pair complementarity (any)

=item * pairendcomp -- primer pair complementarity (end)

=item * lendstab    -- left primer end stability

=item * rendstab    -- right primer end stability

=item * amplicon    -- amplified PCR product

=back

B<Other keys>

=over 4

=item * products    -- number of PCR products

=item * size        -- product size

=item * start       -- product start coordinate

=item * stop        -- product stop coordinate

=item * end         -- synonymous with stop

=item * strand      -- strand of product relative to the ref. sequence (isPCR, ipcress)

=item * amplicon    -- returns the PCR product (isPCR only)

=back

=cut

    my $self = shift;
    return $self->error('method not implemented');
}

1;

# -------------------------------------------------------------------

=pod

=head1 AUTHOR

Copyright (c) 2003-2009 Sheldon McKay E<lt>mckays@cshl.eduE<gt>,
Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>.

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

Bio::PrimerDesigner.

=cut
