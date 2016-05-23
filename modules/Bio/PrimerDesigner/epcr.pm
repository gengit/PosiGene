package Bio::PrimerDesigner::epcr;

# $Id: epcr.pm 9 2008-11-06 22:48:20Z kyclark $

=head1 NAME 

Bio::PrimerDesigner::epcr - A class for accessing the epcr binary

=head1 SYNOPSIS

  use Bio::PrimerDesigner::epcr;

=head1 DESCRIPTION

A low-level interface to the e-PCR binary.  Uses supplied PCR primers,
DNA sequence and stringency parameters to predict both expected 
and unexpected PCR products.  

=head1 METHODS

=cut

use strict;
use warnings;
use File::Spec::Functions 'catfile';
use File::Temp 'tempfile';
use Bio::PrimerDesigner::Remote;
use Bio::PrimerDesigner::Result;
use Readonly;

Readonly our 
    $VERSION => sprintf "%s", q$Revision: 24 $ =~ /(\d+)/;

use base 'Class::Base';

# -------------------------------------------------------------------
sub run {

=head2 run

Sets up the e-PCR request for a single primer combination and returns 
an Bio::PrimerDesigner::Result object

If the permute flag is true, all three possible primer combinations 
will be tested (ie: forward + reverse, forward + forward, reverse + reverse) 

=cut

    my $self    = shift;
    my @result  = (); 
    my @params  = @_ or return $self->error("No arguments for run method");
    my $args    = $_[2];
    my $permute = $args->{'permute'} ? 1 : 0;
    my $left    = $args->{'left'}  or $self->error("No left primer");
    my $right   = $args->{'right'} or $self->error("No right primer");
    
    $args->{'permute'} = 0;
    
    if ( $permute ) {
        for my $combo ( 1 .. 3 ) {
            my %seen = ();
            local $args->{'right'} = $left  if $combo == 2;
            local $args->{'left'}  = $right if $combo == 3;
            $params[2] = $args;
            my @pre_result = $self->request(@params);

            #
            # e-pcr quirk, same-primer comparisons give two identical
            # results, we will ignore duplicates
            #
            for my $line (@pre_result) {
                push @result, $line unless $seen{$line};
                $seen{$line} = 1 if !$seen{$line};
            }
        }
    }
    else {
        @result = $self->request( @params );
    }
    
    my $out = Bio::PrimerDesigner::Result->new;

    $out->{1}->{'products'} = @result;
    $out->{1}->{'raw_output'} = join '', grep {defined} @result;
    my $count = 0;

    for (@result) {
        $count++;
        next unless $_ && /\.\./;
        my ($start, $stop) = /(\d+)\.\.(\d+)/;
        my $size = abs($stop - $start);
        $out->{$count}->{'start'} = $start - 1;
        $out->{$count}->{'stop'}  = $out->{$count}->{'end'} = $stop - 1;
        $out->{$count}->{'size'}  = $size;
    }
 
    return $out;
}

# -------------------------------------------------------------------
sub request {

=head2 request

Assembles the e-PCR config file and command-line arguments and send
the e-PCR request to the local e-PCR binary or remote server.

=cut

    my $self = shift;
    my ($method, $loc, $args) = @_;
    my @data = ();
    $method ||= 'remote';
    
    if ( $method eq 'remote' ) {
        if ( ! defined $args->{'seq'} ) {
            $self->error(
                "A sequence must be supplied (not a file name) for remote epcr"
            );
            return '';
        }

        my $cgi = Bio::PrimerDesigner::Remote->new;
        $cgi->{'program'}  = 'e-PCR';
        $args->{'program'} = 'e-PCR';
        
        @data = $cgi->CGI_request( $loc, $args );
    }
    elsif ( $method eq 'local') { # run ePCR locally
        #
        # required parameters
        #
        my $left       = uc $args->{'left'}  || $self->error("no left primer");
        my $right      = uc $args->{'right'} || $self->error("no right primer");
        my $seq        = $args->{'seq'}      || '';
        my $file       = $args->{'seqfile'}  || '';
        $self->error("No sequence supplied") unless $seq || $file;

        #
        # optional parameters
        #
        my $prod_size    = $args->{'prod_size'} || 2000;
        my $margin       = $args->{'margin'}    || 2000;
        my $word_size    = $args->{'word_size'} || 7;
        my $num_mismatch = $args->{'mismatch'}  || 2;
  
        #
        # e-PCR config file
        #
        my ( $temp_loc_fh, $temp_loc ) = tempfile;
        print $temp_loc_fh "ePCR_test\t$left\t$right\t$prod_size\t\n";
        close $temp_loc_fh;
      
        #
        # e-PCR sequence file (fasta format)
        #
        my ($seq_loc_fh, $seq_loc, $seq_file, $seq_temp);
        if ($seq) {
            ( $seq_loc_fh, $seq_loc ) = tempfile;
            $seq_temp = $seq_loc;
            print $seq_loc_fh ">Test sequence\n$seq\n";
            close $seq_loc_fh;
        }
        else {
            $seq_loc = $file or $self->error('No sequence file');
        }

        #
        # e-PCR command-line arguments
        #
        my $params = "$temp_loc $seq_loc ";
        $params   .= "M=$margin W=$word_size N=$num_mismatch";
        $loc       = catfile( $loc, $self->binary_name );
          
        # 
        # run e-PCR
        #
        open EPCR, "$loc $params |";
        @data = <EPCR>;
        close EPCR;

        unlink $temp_loc;
        unlink $seq_temp if $seq_temp && -e $seq_temp;
    }

    return @data;
}

# -------------------------------------------------------------------
sub verify {

=head2 verify

Check to make that the e-PCR binary is installed and functioning
properly.  Since e-PCR returns nothing if no PCR product is found
in the sequence, we have to be able to distinguish between a valid,
undefined output from a functioning e-PCR and an undefined output
for some other reason.  verify uses sham e-PCR data that is known 
to produce a PCR product.  

=cut

    my $self            = shift;
    my ($method, $loc)  = @_ or $self->error('No verify parameters');
    my %param           = ();
    $param{'left'}      = 'TTGCGCATTTACGATTACGA';
    $param{'right'}     = 'ATGCTGTAATCGGCTGTCCT';
    $param{'seq'}       = 'GCAGCGAGTTGCGCATTTACGATTACGACATACGACACGA' .
                          'TTACAGACAGGACAGCCGATTACAGCATATCGACAGCAT';
    $param{'prod_size'} = 70;
    $param{'margin'}    = 20;
    
    my $result = $self->run( $method, $loc, \%param );
    my $output = $result->raw_output || '';

    unless ( $output =~ /\d+\.\.\d+/ ) {
        return $self->error("e-PCR did not verify!");
    }
    else {
        return $result;
    }
}

# -------------------------------------------------------------------
sub binary_name {

=pod

=head2 binary_name

Defines the binary's name on the system.

=cut

    my $self = shift;
    return 'e-PCR';
}

# -------------------------------------------------------------------
sub list_aliases {

=pod

=head2 list_aliases

There are no aliases to list for epcr.

=cut

    my $self = shift;
    return;
}

# -------------------------------------------------------------------
sub list_params {

=pod

=head2 list_params

Returns a list of e-PCR configuration options.  Required e-PCR input is
a sequence string or file and the left and right primers.  Default values
will be used for the remaining options if none are supplied.


=cut

    my $self = shift;

    return (
        'REQUIRED:',
        'seq      (string) Raw DNA sequence to search for PCR products',
        'OR',
        'seqfile (string) Fasta file to search for PCR products',
        '',
        'left     (string) Left primer sequence',
        'right    (string) Right primer sequence',
        '', 'OPTIONAL:',            
        'word_size (int; default 7)    The size of the perfect match at 3\' end',
        'mismatch  (int; default 2)    Allowed number of mismatches',
        'prod_size (int; default 2000) Expected PCR product size',
        'margin    (int; default 2000) Allowed size variation',
        'permute   (true) Try all primer combinations (l/r, l/l, r/r)'
	);
}

1;

# -------------------------------------------------------------------

=head1 AUTHOR

Copyright (C) 2003-2009 Sheldon McKay E<lt>mckays@cshl.eduE<gt>,
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

Bio::PrimerDesigner::primer3.

=cut
