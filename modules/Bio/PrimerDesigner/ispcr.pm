package Bio::PrimerDesigner::ispcr;

# $Id: ispcr.pm 9 2008-11-06 22:48:20Z kyclark $

=head1 NAME 

Bio::PrimerDesigner::ispcr - A class for accessing the isPcr (in-silico PCR)  binary

=head1 SYNOPSIS

  use Bio::PrimerDesigner::ispcr;

=head1 DESCRIPTION

A low-level interface to the isPcr program.  Uses supplied PCR primers,
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

=pod

=head2 run

Sets up the isPcr request for a single primer combination and returns
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
            # same-primer comparisons give two identical
            # results, we will ignore duplicates
            #
            for my $line (@pre_result) {
                push @result, $line unless ++$seen{$line} > 1;
            }
        }
    }
    else {
        @result = $self->request( @params );
    }
    
    # first element will be empty
    shift @result;

    my $out = Bio::PrimerDesigner::Result->new;
    
    $out->{1}->{'products'} = @result;
    $out->{1}->{'raw_output'} = join('','>',@result);
    
    my $count = 0;

    for (@result) {
        $count++;
	s/>//;
	my @lines = split "\n", $_;
        chomp @lines;

	my $idline = shift @lines;
	my ($location)  = split /\s+/, $idline;
        my ($start,$strand,$stop) = $location =~ /(\d+)([-+])(\d+)$/;
        my $size = abs($stop - $start);

        $out->{$count}->{'start'} = $start;
        $out->{$count}->{'stop'}  = $out->{$count}->{'end'} = $stop;
        $out->{$count}->{'size'}  = $size;
	$out->{$count}->{'amplicon'} = join '', @lines;
    }
 
    return $out;
}

# -------------------------------------------------------------------
sub request {

=pod

=head2 request

Assembles the config file and command-line arguments and sends
the request to the local binary or remote server.

=cut

    my $self = shift;
    my ($method, $loc, $args) = @_;
    my @data = ();
    $method ||= 'remote';
    
    if ( $method eq 'remote' ) {
        if ( ! defined $args->{'seq'} ) {
            $self->error(
                "A sequence must be supplied (not a file name) for remote ispcr"
            );
            return '';
        }

        my $cgi = Bio::PrimerDesigner::Remote->new;
        $cgi->{'program'}  = 'ispcr';
        $args->{'program'} = 'ispcr';
        
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
        # config file
        #
        my ( $temp_loc_fh, $temp_loc ) = tempfile;
        print $temp_loc_fh "isPCR_test\t$left\t$right\n";
        close $temp_loc_fh;
      
        #
        # sequence file (fasta format)
        #
        my ($seq_loc_fh, $seq_loc, $seq_file, $seq_temp);
        if ($seq) {
            ( $seq_loc_fh, $seq_loc ) = tempfile;
            $seq_temp = $seq_loc;
            print $seq_loc_fh ">test\n$seq\n";
            close $seq_loc_fh;
        }
        else {
            $seq_loc = $file or $self->error('No sequence file');
        }

        #
        # command-line arguments
        #
	my $params = '';
	for my $p (qw/tileSize stepSize maxSize minSize minPerfect minGood mask/) {
	    $params .= "-$p=$args->{$p}" if defined $args->{$p};
	}

        $loc       = catfile( $loc, $self->binary_name );
          
	local $/ = '>';
        open ISPCR, "$loc $seq_loc $temp_loc $params stdout |";
        @data = (<ISPCR>);
        close ISPCR;


        unlink $temp_loc;
        unlink $seq_temp if $seq_temp && -e $seq_temp;
    }

    return @data;
}

# -------------------------------------------------------------------
sub verify {

=pod

=head2 verify

Check to make that the isPCR binary is installed and functioning
properly.  Since ispcr returns nothing if no PCR product is found
in the sequence, we have to be able to distinguish between a valid,
undefined output from a functioning ispcr and an undefined output
for some other reason.  verify uses sham ispcr data that is known
to produce a PCR product.

=cut

    my $self            = shift;
    my ($method, $loc)  = @_ or $self->error('No verify parameters');
    my %param           = ();
    $param{'left'}      = 'TTGCGCATTTACGATTACGA';
    $param{'right'}     = 'ATGCTGTAATCGGCTGTCCT';
    $param{'seq'}       = 'GCAGCGAGTTGCGCATTTACGATTACGACATACGACACGA' .
                          'TTACAGACAGGACAGCCGATTACAGCATATCGACAGCAT';
    
    my $result = $self->run( $method, $loc, \%param );
    my $output = $result->raw_output || '';

    unless ( $output =~ />\S+\s+\S+\s+\S+\s+\S+/ ) {
        return $self->error("ispcr did not verify!");
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
    return 'isPcr';
}

# -------------------------------------------------------------------
sub list_aliases {

=pod

=head2 list_aliases

There are no aliases to list for ispcr.

=cut

    my $self = shift;
    return;
}

# -------------------------------------------------------------------
sub list_params {

=pod

=head2 list_params

Returns a list of ispcr configuration options.  Required ispcr input is
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
	    'tileSize (int) size of match that triggers alignment (default 11)',    
	    'stepSize (int) spacing between tiles (default 5)',
	    'maxSize  (int) max size of PCR product (default 4000)',
	    'minSize  (int) min size of PCR product (default 0)',
	    'minPerfect (int) min size of perfect match at 3 prime end of primer (default 15)',
	    'minGood   (int) min size where there must be 2 matches for each mismatch (default 15)',
	    'permute  (true) Try all primer combinations (l/r, l/l, r/r)',
	    'mask     (upper|lower) Mask out lower or upper-cased sequences'
	);
}

1;

# -------------------------------------------------------------------

=head1 AUTHOR

Copyright (C) 2003-2009 Sheldon McKay E<lt>mckays@cshl.edu<gt>,
                     Ken Y. Clark E<lt>kclark@cpan.orgE<gt>.

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
