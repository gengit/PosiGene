package Bio::PrimerDesigner::primer3;

# $Id: primer3.pm 9 2008-11-06 22:48:20Z kyclark $

=head1 NAME 

Bio::PrimerDesigner::primer3 - An class for accessing primer3

=head1 SYNOPSIS

  use Bio::PrimerDesigner::primer3;

=head1 METHODS

Methods are called using the simplifed alias for each primer3 result
or the raw primer3 BoulderIO key.  Use the raw_output method to view the
raw output.

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

Readonly our
    $REMOTE_URL => 'mckay.cshl.edu/cgi-bin/primer_designer.cgi';

use base 'Class::Base';


# -------------------------------------------------------------------
sub binary_name {

=pod

=head2 binary_name

Defines the binary's name on the system.

=cut

    my $self = shift;
    return 'primer3';
}

# -------------------------------------------------------------------
sub check_params {

=pod

=head2 check_params

Make sure we have required primer3 arguments.

=cut

    my ( $self, $args ) = @_;

    if ( 
        defined $args->{'PRIMER_LEFT_INPUT'} && 
        defined $args->{'PRIMER_RIGHT_INPUT'} 
    ) {
        return $self->error(
            "Number of sets must be set to 1 for defined primers"
        ) if $args->{'PRIMER_NUM_RETURN'} > 1;

        return $self->error("Sequence input is missing")
            unless defined $args->{'SEQUENCE'};
    }
    else {
        return $self->error("Required design paramaters are missing") unless
            defined $args->{'PRIMER_SEQUENCE_ID'} &&
            defined $args->{'SEQUENCE'} &&
            defined $args->{'PRIMER_PRODUCT_SIZE_RANGE'};
    } 

    return 1;
}

# -------------------------------------------------------------------
sub design {

=pod

=head2 design

Build the primer3 config file, run primer3, then parse the results.
Expects to be passed a hash of primer3 input options.  Returns an object
that can be used to call result methods.

=cut

    my ( $self, $method, $loc, $args ) = @_;

    return $self->error('No arguments for design method' ) unless $args;
    
    #
    # Unalias incoming parameters if required.
    #
    my %aliases = $self->list_aliases;
    my %lookup  = reverse %aliases;
    while ( my ( $k, $v ) = each %$args ) {
        next if exists $aliases{ $k };
        my $alias = $lookup{ $k } or return $self->error("No alias for '$k'");
        delete $args->{ $k };
        $args->{ $alias } = $v;
    }

    #
    # Check that everything required is present.
    #
    $self->check_params( $args ) or return $self->error;

    #
    # Send request to designer.
    #
    my @data = $self->request( $method, $loc, $args );
    
    #
    # abort on empty or undefined data array
    #
    return '' unless @data && @data > 1; 

    my $output = '';
    my $count  = 1;
    my $result = Bio::PrimerDesigner::Result->new;

    for ( @data ) {
        $output .= $_;# unless /^SEQUENCE=/;

        # save raw output into the results hash
        my ($key, $value) = /(.+)=(.+)/;
        $result->{$count}->{$key} = $value if $key && $value;

        # save aliased output
        $result->{$count}->{'qual'}       = $1 
	    if /R_PAIR_PENALT\S+=(\S+)/ || /R_PAIR_QUAL\S+=(\S+)/;
        $result->{$count}->{'left'}       = $1 
	    if /R_LEFT\S+SEQUENC\S+=(\S+)/;
        $result->{$count}->{'right'}      = $1 
	    if /R_RIGHT\S+SEQUENC\S+=(\S+)/;
        $result->{$count}->{'startleft'}  = $1 
	    if /R_LEFT_?\d*=(\d+),\d+/;
        $result->{$count}->{'startright'} = $1 
	    if /R_RIGHT_?\d*=(\d+),\d+/;
        $result->{$count}->{'lqual'}      = $1 
	    if /R_LEFT\S*_PENALT\S+=(\S+)/ || /R_LEFT\S*_QUAL\S+=(\S+)/;
        $result->{$count}->{'rqual'}      = $1 
	    if /R_RIGHT\S*_PENALT\S+=(\S+)/ || /R_RIGHT\S*_QUAL\S+=(\S+)/;
        $result->{$count}->{'leftgc'}     = int $1
            if /R_LEFT\S+GC_PERCEN\S+=(\S+)/;
        $result->{$count}->{'rightgc'}    = int $1
            if /R_RIGHT\S+GC_PERCEN\S+=(\S+)/;
        $result->{$count}->{'lselfany'}   = int $1
            if /R_LEFT\S+SELF_AN\S+=(\S+)/;
        $result->{$count}->{'rselfany'}   = int $1
            if /R_RIGHT\S+SELF_AN\S+=(\S+)/;
        $result->{$count}->{'lselfend'}   = int $1
            if /R_LEFT\S+SELF_EN\S+=(\S+)/;
        $result->{$count}->{'rselfend'}   = int $1
            if /R_RIGHT\S+SELF_EN\S+=(\S+)/;
        $result->{$count}->{'lendstab'}   = int $1
            if /R_LEFT\S+END_STABILIT\S+=(\S+)/;
        $result->{$count}->{'rendstab'}   = int $1
            if /R_RIGHT\S+END_STABILIT\S+=(\S+)/;
        $result->{$count}->{'pairendcomp'}= int $1
            if /R_PAIR\S+COMPL_EN\S+=(\S+)/;
        $result->{$count}->{'pairanycomp'}= int $1
            if /R_PAIR\S+COMPL_AN\S+=(\S+)/;
        $result->{$count}->{'hyb_oligo'}= lc $1
        if /PRIMER_INTERNAL_OLIGO_SEQUENC\S+=(\S+)/;
    
        #
        # round up Primer Tm's
        #
        $result->{$count}->{'hyb_tm'}= int (0.5 + $1)
            if /PRIMER_INTERNAL_OLIGO\S+TM=(\d+)/;  

        $result->{$count}->{'tmleft'}  = int (0.5 + $1)
            if (/^PRIMER_LEFT.*_TM=(\S+)/);

        $result->{$count}->{'tmright'} = int (0.5 + $1)
            if (/^PRIMER_RIGHT.*_TM=(\S+)/);

        #
        # product size key means that we are at the end of each primer set
        #
        $result->{$count}->{'prod'} = $1 and $count++
          if /^PRIMER_PRODUCT_SIZ\S+=(\S+)/ && !/RANGE/;
        
        #
        # abort if we encounter a primer3 error message
        #
        if (/PRIMER_ERROR/) {
            $self->error("Some sort of primer3 error:\n$output");
            return '';
        }
    }

    #
    # save the raw primer3 output (except for input sequence -- too big)
    #
    $result->{1}->{'raw_output'} = $output;
    
    return $result;
}


# -------------------------------------------------------------------
sub request {

=pod

=head2 request

Figures out where the primer3 binary resides and accesses it with a
list of parameters for designing primers.

=cut

    my ( $self, $method, $loc, $args ) = @_;
    $method ||= 'remote';

    my $config = '';
    while ( my ( $key, $value ) = each %$args ) {
        $config .= "$key=$value\n";
    }

    my @data = ();

    if ( $method eq 'remote' ) {
        my $cgi  = Bio::PrimerDesigner::Remote->new
            or return $self->error('could not make remote object');
        my $url  = $loc;
        $args->{'program'} = $self->binary_name;
        @data   = $cgi->CGI_request( $url, $args );
    }
    else { # "local"
        my $path        =  $loc;
        my $binary_name =  $self->binary_name or return;
        my $binary_path =  catfile( $path, $binary_name );
        return $self->error("Can't execute local binary '$binary_path'")
            unless -x $binary_path;

        my ( $tmp_fh, $tmp_file ) = tempfile;
        print $tmp_fh $config, "=\n";
        close $tmp_fh;
        
        # 
        # send the instructions to primer3 and get results
        #
        open RESULT_FILE, "$binary_path < $tmp_file |";
        @data = <RESULT_FILE>;
        close RESULT_FILE;
        unlink $tmp_file;
    }
    
    if ( $self->check_results( $method, @data ) ) {
        return @data;
    }
    else {
        return '';
    }
}     

# -------------------------------------------------------------------
sub check_results {

=pod

=head2 check_results

Verify the validity of the design results.

=cut

    my $self    = shift;
    my $method  = shift;
    my $results = join '', grep {defined} @_;

    my $thing   = $method eq 'remote' ? 'URL' : 'binary'; 
    my $problem = "Possible problem with the primer3 $thing";
    
    if ( $results =~ /SEQUENCE=/m ) {
        return 1;
    }
    else {
        return $self->error("Primer design failure:\n", $problem);
    }
}

# -------------------------------------------------------------------
sub list_aliases {

=pod

=head2 list_aliases

Prints a list of shorthand aliases for the primer3 BoulderIO
input format.  The full input/ouput options and the aliases can be
used interchangeably.

=cut

    my $self = shift;
    
    return (
        PRIMER_SEQUENCE_ID             => 'id',
        SEQUENCE                       => 'seq',
        INCLUDED_REGION                => 'inc',
        TARGET                         => 'target',
        EXCLUDED_REGION                => 'excluded',
        PRIMER_COMMENT                 => 'comment',
        PRIMER_SEQUENCE_QUALITY        => 'quality',
        PRIMER_LEFT_INPUT              => 'leftin',
        PRIMER_RIGHT_INPUT             => 'rightin',
        PRIMER_START_CODON_POSITION    => 'start_cod_pos',
        PRIMER_PICK_ANYWAY             => 'pickanyway',
        PRIMER_MISPRIMING_LIBRARY      => 'misprimelib',
        PRIMER_MAX_MISPRIMING          => 'maxmisprime',
        PRIMER_PAIR_MAX_MISPRIMING     => 'pairmaxmisprime',
        PRIMER_PRODUCT_MAX_TM          => 'prodmaxtm',
        PRIMER_PRODUCT_MIN_TM          => 'prodmintm',
        PRIMER_EXPLAIN_FLAG            => 'explain',
        PRIMER_PRODUCT_SIZE_RANGE      => 'sizerange',
        PRIMER_GC_CLAMP                => 'gcclamp',
        PRIMER_OPT_SIZE                => 'optpsize',
        PRIMER_INTERNAL_OLIGO_OPT_SIZE => 'hyb_opt_size',
        PRIMER_MIN_SIZE                => 'minpsize',
        PRIMER_MAX_SIZE                => 'maxpsize',
        PRIMER_OPT_TM                  => 'opttm',
        PRIMER_MIN_TM                  => 'mintm',
        PRIMER_MAX_TM                  => 'maxtm',
        PRIMER_MAX_DIFF_TM             => 'maxtmdiff',
        PRIMER_MIN_GC                  => 'mingc',
        PRIMER_OPT_GC_PERCENT          => 'optgc',
        PRIMER_MAX_GC                  => 'maxgc',
        PRIMER_SALT_CONC               => 'saltconc',
        PRIMER_DNA_CONC                => 'dnaconc',
        PRIMER_NUM_NS_ACCEPTED         => 'maxN',
        PRIMER_SELF_ANY                => 'selfany',
        PRIMER_SELF_END                => 'selfend',
        PRIMER_DEFAULT_PRODUCT         => 'sizerangelist',
        PRIMER_MAX_POLY_X              => 'maxpolyX',
        PRIMER_LIBERAL_BASE            => 'liberal',
        PRIMER_NUM_RETURN              => 'num',
        PRIMER_FIRST_BASE_INDEX        => '1stbaseindex',
        PRIMER_MAX_END_STABILITY       => 'maxendstab',
        PRIMER_PRODUCT_OPT_TM          => 'optprodtm',
        PRIMER_PRODUCT_OPT_SIZE        => 'optprodsize',
        PRIMER_WT_TM_GT                => 'wt_tm_gt',
        PRIMER_WT_TM_LT                => 'wt_tm_lt',
        PRIMER_WT_SIZE_LT              => 'wt_size_lt',
        PRIMER_WT_SIZE_GT              => 'wt_size_gt',
        PRIMER_WT_GC_PERCENT_LT        => 'wt_gc_lt',
        PRIMER_WT_GC_PERCENT_GT        => 'wt_gc_gt',
        PRIMER_WT_COMPL_ANY            => 'wt_comp_any',
        PRIMER_WT_COMPL_END            => 'wt_comp_end',
        PRIMER_WT_NUM_NS               => 'wt_numN',
        PRIMER_WT_REP_SIM              => 'wt_rep_sim',
        PRIMER_WT_SEQ_QUAL             => 'wt_seq_qual',
        PRIMER_WT_END_QUAL             => 'wt_end_qual',
        PRIMER_WT_END_STABILITY        => 'wt_end_stab',
        PRIMER_PAIR_WT_PR_PENALTY      => 'wt_pr_penalty',
        PRIMER_PAIR_WT_DIFF_TM         => 'wt_pr_tmdiff',
        PRIMER_PAIR_WT_COMPL_ANY       => 'wt_pr_comp_any',
        PRIMER_PAIR_WT_COMPL_END       => 'wt_pr_comp_end',
        PRIMER_PAIR_WT_PRODUCT_TM_LT   => 'wt_prodtm_lt',
        PRIMER_PAIR_WT_PRODUCT_TM_GT   => 'wt_prodtm_gt',
        PRIMER_PAIR_WT_PRODUCT_SIZE_GT => 'wt_prodsize_gt',
        PRIMER_PAIR_WT_PRODUCT_SIZE_LT => 'wt_prodsize_lt',
        PRIMER_PAIR_WT_REP_SIM         => 'wt_repsim',
        PRIMER_PICK_INTERNAL_OLIGO     => 'hyb_oligo',
        PRIMER_LEFT_EXPLAIN            => 'left_explain',
        PRIMER_RIGHT_EXPLAIN           => 'right_explain',
        PRIMER_PAIR_EXPLAIN            => 'pair_explain',
        PRIMER_INTERNAL_OLIGO_EXPLAIN  => 'hyb_explain',
        PRIMER_INTERNAL_OLIGO_MIN_SIZE => 'hyb_min_size',
        PRIMER_INTERNAL_OLIGO_MAX_SIZE => 'hyb_max_size',
    );
}

# -------------------------------------------------------------------
sub list_params {

=pod

=head2 list_params

Returns a list of primer3 configuration options.  primer3 will use
reasonable default options for most parameters.

=cut


    my $self = shift;

    return (
        'PRIMER_SEQUENCE_ID (string, optional)',
        'SEQUENCE (nucleotide sequence, REQUIRED)',
        'INCLUDED_REGION (interval, optional)',
        'TARGET (interval list, default empty)',
        'EXCLUDED_REGION (interval list, default empty)',
        'PRIMER_COMMENT (string, optional)',
        'PRIMER_SEQUENCE_QUALITY (quality list, default empty)',
        'PRIMER_LEFT_INPUT (nucleotide sequence, default empty)',
        'PRIMER_RIGHT_INPUT (nucleotide sequence, default empty)',
        'PRIMER_START_CODON_POSITION (int, default -1000000)',
        'PRIMER_PICK_ANYWAY (boolean, default 0)',
        'PRIMER_MISPRIMING_LIBRARY (string, optional)',
        'PRIMER_MAX_MISPRIMING (decimal,9999.99, default 12.00)',
        'PRIMER_PAIR_MAX_MISPRIMING (decimal,9999.99, default 24.00)',
        'PRIMER_PRODUCT_MAX_TM (float, default 1000000.0)',
        'PRIMER_PRODUCT_MIN_TM (float, default -1000000.0)',
        'PRIMER_EXPLAIN_FLAG (boolean, default 0)',
        'PRIMER_PRODUCT_SIZE_RANGE (size range list, default 100-300)',
        'PRIMER_GC_CLAMP (int, default 0)',
        'PRIMER_OPT_SIZE (int, default 20)',
        'PRIMER_MIN_SIZE (int, default 18)',
        'PRIMER_MAX_SIZE (int, default 27)',
        'PRIMER_OPT_TM (float, default 60.0C)',
        'PRIMER_MIN_TM (float, default 57.0C)',
        'PRIMER_MAX_TM (float, default 63.0C)',
        'PRIMER_MAX_DIFF_TM (float, default 100.0C)',
        'PRIMER_MIN_GC (float, default 20.0%)',
        'PRIMER_OPT_GC_PERCENT (float, default 50.0%)',
        'PRIMER_MAX_GC (float, default 80.0%)',
        'PRIMER_SALT_CONC (float, default 50.0 mM)',
        'PRIMER_DNA_CONC (float, default 50.0 nM)',
        'PRIMER_NUM_NS_ACCEPTED (int, default 0)',
        'PRIMER_SELF_ANY (decimal,9999.99, default 8.00)',
        'PRIMER_SELF_END (decimal 9999.99, default 3.00)',
        'PRIMER_DEFAULT_PRODUCT (size range list, default 100-300)',
        'PRIMER_MAX_POLY_X (int, default 5)',
        'PRIMER_LIBERAL_BASE (boolean, default 0)',
        'PRIMER_NUM_RETURN (int, default 5)',
        'PRIMER_FIRST_BASE_INDEX (int, default 0)',
        'PRIMER_MAX_END_STABILITY (float 999.9999, default 100.0)',
        'PRIMER_PRODUCT_OPT_TM (float, default 0.0)',
        'PRIMER_PRODUCT_OPT_SIZE (int, default 0)',
        '',
        '** PENALTY WEIGHTS **',
        '',
        'PRIMER_WT_TM_GT (float, default 1.0)',
        'PRIMER_WT_TM_LT (float, default 1.0)',
        'PRIMER_WT_SIZE_LT (float, default 1.0)',
        'PRIMER_WT_SIZE_GT (float, default 1.0)',
        'PRIMER_WT_GC_PERCENT_LT (float, default 1.0)',
        'PRIMER_WT_GC_PERCENT_GT (float, default 1.0)',
        'PRIMER_WT_COMPL_ANY (float, default 0.0)',
        'PRIMER_WT_COMPL_END (float, default 0.0)',
        'PRIMER_WT_NUM_NS (float, default 0.0)',
        'PRIMER_WT_REP_SIM (float, default 0.0)',
        'PRIMER_WT_SEQ_QUAL (float, default 0.0)',
        'PRIMER_WT_END_QUAL (float, default 0.0)',
        'PRIMER_WT_END_STABILITY (float, default 0.0)',
        'PRIMER_PAIR_WT_PR_PENALTY (float, default 1.0)',
        'PRIMER_PAIR_WT_DIFF_TM (float, default 0.0)',
        'PRIMER_PAIR_WT_COMPL_ANY (float, default 0.0)',
        'PRIMER_PAIR_WT_COMPL_END (float, default 0.0)',
        'PRIMER_PAIR_WT_PRODUCT_TM_LT (float, default 0.0)',
        'PRIMER_PAIR_WT_PRODUCT_TM_GT (float, default 0.0)',
        'PRIMER_PAIR_WT_PRODUCT_SIZE_GT (float, default 0.0)',
        'PRIMER_PAIR_WT_PRODUCT_SIZE_LT (float, default 0.0)',
        'PRIMER_PAIR_WT_REP_SIM (float, default 0.0)',
    );
}

# -------------------------------------------------------------------
sub example {

=pod

=head2 example

Runs a sample remote primer design job.  Returns an
Bio::PrimerDesigner::Result object.

=cut

    my $self       = shift;
    my $dna        = $self->_example_dna;
    my $length     =  length $dna;
    my $result     =  $self->design(
        'remote',
        $REMOTE_URL,
        { 
            num        => 1,
            seq        => $dna,
            sizerange  => '100-200',
            target     => '150,10',
            excluded   => '1,30 400,' . ($length - 401),
            id         => 'test_seq'
        }
    ) or return $self->error("Can't get remote server call to work");
    
    return $result; 
}

# -------------------------------------------------------------------
sub _example_dna {

=pod

=head2 _example_dna

Returns an example DNA sequence.

=cut

  my $self = shift;
  return 'cagagttaaagagaaaactgataattttttttccatctttctcctcacttgtgaataaac' .
         'taaacgcatttctgtggacgttccaagtgtaatatgagagttgttttcatttggaaatgc' .
         'gggaatatattgaatcttccattagatgttcaggaatatataaatacgttgtctgctctg' .
         'aaaattcacacggaaaatctaaaaattgtcaaattatagatttcattctcaaatgactat' .
         'ataacattttatttttgcaatttcttttcaattaggaaacatttcaaaaagctacgttgt' .
         'ttttcacattcaaaatgattactgtcggtgcgttcattttccgagtttttccaatttcac' .
         'gcttgctcttcttcgtaaaaaactcgtaatttagaaattgtgtctagatcaaaaaaaaaa' .
         'ttttctgagcaatcctgaatcaggcatgctctctaaacaactctcagatatctgagatat' .
         'gggaagcaaattttgagaccttactagttataaaaatcattaaaaatcaacgccgacagt' .
         'ttctcacagaaacttaaaccgaaaaatcccaacgaagacttcagctcttttttctttgaa';
}

1;

# -------------------------------------------------------------------

=pod

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

Bio::PrimerDesigner::epcr.

=cut
