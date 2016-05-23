package Bio::PrimerDesigner;

# $Id: PrimerDesigner.pm 25 2008-11-10 20:22:18Z kyclark $

=head1 NAME 

Bio::PrimerDesigner - Design PCR Primers using primer3 and epcr

=head1 SYNOPSIS

  use Bio::PrimerDesigner;

  my $pd = Bio::PrimerDesigner->new;

  #
  # Define the DNA sequence, etc.
  #
  my $dna   = "CGTGC...TTCGC";
  my $seqID = "sequence 1";

  #
  # Define design parameters (native primer3 syntax)
  #
  my %params = ( 
      PRIMER_NUM_RETURN   => 2,
      PRIMER_SEQUENCE_ID  => $seqID,
      SEQUENCE            => $dna,
      PRIMER_PRODUCT_SIZE => '500-600'
  );

  #
  # Or use input aliases
  #
  %param = ( 
      num                 => 2,
      id                  => $seqID,
      seq                 => $dna,
      sizerange           => '500-600'
  ); 

  #
  # Design primers
  #
  my $results = $pd->design( %params ) or die $pd->error;

  #
  # Make sure the design was successful
  #
  if ( !$results->left ) {
      die "No primers found\n", $results->raw_data;
  }

  #
  # Get results (single primer set)
  #
  my $left_primer  = $results->left;
  my $right_primer = $results->right;
  my $left_tm      = $results->lefttm;

  #
  # Get results (multiple primer sets)
  #
  my @left_primers  = $results->left(1..3);
  my @right_primers = $results->right(1..3);
  my @left_tms      = $results->lefttm(1..3);

=head1 DESCRIPTION

Bio::PrimerDesigner provides a low-level interface to the primer3 and
epcr binary executables and supplies methods to return the results.
Because primer3 and e-PCR are only available for Unix-like operating
systems, Bio::PrimerDesigner offers the ability to accessing the
primer3 binary via a remote server.  Local installations of primer3 or
e-PCR on Unix hosts are also supported.

=head1 METHODS

=cut

use strict;
use warnings;
use Bio::PrimerDesigner::primer3;
use Bio::PrimerDesigner::epcr;
use Readonly;

use base 'Class::Base';

Readonly my $EMPTY_STR => q{};
Readonly my %DEFAULT   => (
    method             => 'local',
    binary_path        => '/usr/local/bin',
    program            => 'primer3',
    url         
        => 'http://aceserver.biotech.ubc.ca/cgi-bin/primer_designer.cgi',
);
Readonly my %DESIGNER  => (
    primer3            => 'Bio::PrimerDesigner::primer3',
    epcr               => 'Bio::PrimerDesigner::epcr', 
);
Readonly our 
    $VERSION => '0.04'; # must break like this for Module::Build to find

# -------------------------------------------------------------------
sub init {
    my ( $self, $config ) = @_;

    for my $param ( qw[ program method url ] ) {
        $self->$param( $config->{ $param } ) or return;
    }

    if ($self->method eq 'local') {
        $self->binary_path( $config->{'binary_path'} ) or return;
    }

    my $loc = $self->method eq 'local' ? 'path' : 'url';
    $self->{ $loc } = $config->{'path'} || $config->{'url'} || $EMPTY_STR;
    return $self;
}

# -------------------------------------------------------------------
sub binary_path {

=pod

=head2 binary_path

Gets/sets path to the primer3 binary.

=cut

    my $self    = shift;

    if ( my $path = shift ) {
        if ( ! $self->os_is_unix ) {
            return $self->error("Cannot set binary_path on non-Unix-like OS");
        }
        else {
            if ( -e $path ) {
                $self->{'binary_path'} = $path;
            }
            else {
                $self->error(
                    "Can't find path to " . $self->program->binary_name .
                    ":\nPath '$path' does not exist"
                );
                return $EMPTY_STR;
            }
        }
    }

    unless ( defined $self->{'binary_path'} ) {
        $self->{'binary_path'} = 
            ( $self->os_is_unix ) ? $DEFAULT{'binary_path'} : $EMPTY_STR;
    }

    return $self->{'binary_path'};
}

# -------------------------------------------------------------------
sub design {

=pod

=head2 design

Makes the primer design or e-PCR request.  Returns an
Bio::PrimerDesigner::Result object.

=cut

    my $self     = shift;
    my %params   = @_ or $self->error("no design parameters");
    my $designer = $self->{'program'};
    my $method   = $self->method;
    my $loc      = $method eq 'local' ? $self->binary_path : $self->url;
    my $function = $designer =~ /primer3/ ? 'design' : 'run';
    
    my $result   = $designer->$function( $method, $loc, \%params )
                   or return $self->error( $designer->error );
    
    return $result;
}

# -------------------------------------------------------------------
sub epcr_example {

=head2 epcr_example

Run test e-PCR job.  Returns an Bio::PrimerDesigner::Results object.

=cut

    my $self = shift;
    my $epcr = Bio::PrimerDesigner::epcr->new;
    return $epcr->verify( 'remote', $DEFAULT{'url'} ) 
        || $self->error( $epcr->error );
}

# -------------------------------------------------------------------
sub list_aliases {

=pod

=head2 list_aliases

Lists aliases for primer3 input/output options

=cut

    my $self = shift;
    my $designer = $self->program or return $self->error;
    return $designer->list_aliases;
}

# -------------------------------------------------------------------
sub list_params {

=pod

=head2 list_params

Lists input options for primer3 or epcr, depending on the context

=cut

    my $self = shift;
    my $designer = $self->program or return $self->error;
    return $designer->list_params;
}

# -------------------------------------------------------------------
sub method {

=pod

=head2 method

Gets/sets method of accessing primer3 or epcr binaries.

=cut

    my $self    = shift;

    if ( my $arg = lc shift ) {
        return $self->error("Invalid argument for method: '$arg'")
            unless $arg eq 'local' || $arg eq 'remote';

        if ( !$self->os_is_unix && $arg eq 'local' ) {
            return $self->error("Local method doesn't work on Windows");
        }

        $self->{'method'} = $arg;
    }

    unless ( defined $self->{'method'} ) {
        $self->{'method'} = $self->os_is_unix ? $DEFAULT{'method'} : 'remote';
    }

    return $self->{'method'};
}

# -------------------------------------------------------------------
sub os_is_unix {

=pod

=head2 os_is_unix

Returns 1 if it looks like the operating system is a Unix variant, 
otherwise returns 0.

=cut

    my $self = shift;

    # technically, this should be 'os_is_not_windows'
    unless ( defined $self->{'os_is_unix'} ) {
        #$self->{'os_is_unix'} = ( $^O =~ /(n[iu]x|darwin)/ ) ? 1 : 0;
	$self->{'os_is_unix'} = ( $^O !~ /^MSWin/i ) ? 1 : 0;
    }

    return $self->{'os_is_unix'};
}

# -------------------------------------------------------------------
sub primer3_example {

=head2 primer3_example

Runs a sample design job for primers.  Returns an
Bio::PrimerDesigner::Results object.

=cut

    my $self = shift;
    my $pcr  = Bio::PrimerDesigner::primer3->new;
    return $pcr->example || $self->error( $pcr->error );
}

# -------------------------------------------------------------------
sub program {

=pod

=head2 program

Gets/sets which program to use.

=cut

    my $self    = shift;
    my $program = shift || $EMPTY_STR;
    my $reset   = 0; 

    if ( $program ) {
        return $self->error("Invalid argument for program: '$program'")
            unless $DESIGNER{ $program };
        $reset = 1;
    }

    if ( $reset || !defined $self->{'program'} ) {
        $program ||= $DEFAULT{'program'};
        my $class  = $DESIGNER{ $program };
        $self->{'program'} = $class->new or 
            return $self->error( $class->error );
    }

    return $self->{'program'};
}

# -------------------------------------------------------------------
sub run {

=pod

=head2 run

Alias to "design."

=cut
    my $self = shift;
    return $self->design( @_ );
}

# -------------------------------------------------------------------
sub url {

=pod

=head2 url

Gets/sets the URL for accessing the remote binaries.

=cut

    my $self = shift;
    my $url  = shift;

    if ( defined $url && $url eq $EMPTY_STR ) {
        $self->{'url'} = $EMPTY_STR;
    }
    elsif ( $url ) {
        $url = 'http://' . $url unless $url =~ m{https?://};
        $self->{'url'} = $url;
    }

    eval { require Bio::PrimerDesigner::Config };
    my $local_url = $EMPTY_STR;
    if ( !$@ ) {
        $local_url = $Bio::PrimerDesigner::Config->{'local_url'};
    }

    return $self->{'url'} || $local_url || $DEFAULT{'url'};
}

# -------------------------------------------------------------------
sub verify {                     
                     
=head2 verify

Tests local installations of primer3 or e-PCR to ensure that they are
working properly.

=cut

    my $self     = shift;
    my $designer = $self->{'program'};
    my $method   = $self->method;                     
    my $loc      = $method eq 'local' ? $self->binary_path : $self->url; 
    return $designer->verify( $method, $loc ) || 
        $self->error( $designer->error );
}

1;

# -------------------------------------------------------------------

=pod

=head1 AUTHORS

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

Bio::PrimerDesigner::primer3, Bio::PrimerDesigner::epcr.

=cut
