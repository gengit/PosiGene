package Bio::Das::AGPServer::Parser;

=head1 AUTHOR

Tony Cox <avc@sanger.ac.uk>.

Copyright (c) 2003 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use vars qw($AUTOLOAD $DEBUG $GAPCOUNT);

$Bio::DAS::AGPServer::Parser::DEBUG = 1;

$GAPCOUNT = 0;

#################################################################
sub new {
  my ($class, @args) = @_;
  my $o = bless {}, $class;
  $o->init(@args);
  return $o;
}

#################################################################
## Init the options object
#################################################################
sub init {
    my ($self, $file) = @_;

    die "Parser did not receive a valid AGP file name\n" unless ($file);
    
    open(AGP, "$file") or die "Cannot open AGP file: $! \n";
    
    $self->_fh(\*AGP);
    
    
}

#################################################################
#chrX    1078599 1238991 17      F       AL683870.15     1       160393  +
#chrX    1238992 1282076 18      F       AL691415.17     1       43085   +
#chrX    1282077 1469902 19      F       AL683807.22     1       187826  +
#chrX    1469903 1587199 20      F       AL672040.10     1       117297  +
#chrX    1587200 1648631 21      F       BX004859.8      2001    63432   +
#chrX    1648632 1748631 22      N       100000  clone   no
#chrX    1748632 1798631 23      N       50000   clone   no      #Unfinished_sequence
#chrX    1798632 1853969 24      A       BX119919.4      1       55338   -
#chrX    1853970 2034664 25      F       AC079176.15     1       180695  -
#################################################################
sub next {
    my ($self) = @_;

    die qq(Cannot call next() without a valid file handle!\n) unless($self->_fh());
    my $in = $self->_fh();
    my $sep = '\s+';

    my $next = <$in>;
    return(undef) unless $next;

    chomp $next;
    my @fields  = split("$sep", $next); 
    $fields[0] =~ s/chr//i;

    ## We do a bit of data munging here. Set the orientation always to be "+"
    ## and the clone start/end to be the length of the gap. We should be able to
    ## treat it like a normal clone now...
    
    # F = Finished         = HTGS_PHASE3                                                                             
    # A = Almost finsished = HTGS_PHASE2 (Rare)                                                                      
    # U = Unfinished       = HTGS_PHASE1 (Not ususally in AGPs, but can be.)                                         
    # N = Gap in AGP - these lines have an optional qualifier (eg: CENTROMERE)
                                       
    if ($fields[4] eq "N"){
        $fields[6] = 1;
        $fields[7] = $fields[5];
        $fields[5] = "GAP_$fields[0]_${GAPCOUNT}_$fields[5]";
        $fields[8] = "+";
        $GAPCOUNT++;
    }
    return(\@fields);

}
 
######################################################################
sub AUTOLOAD {
    my $self = shift;
    my $var = $AUTOLOAD;
    my $arg  = shift; 

    local $^W = 0;
    $var =~ s/.*:://;
    if(defined $arg){
        $self->{$var} = $arg;
    }
    return $self->{$var};
}
######################################################################

DESTROY {
    my $self = shift;

    if ($self->_fh()){
        close($self->_fh());
    }   
}

1;
