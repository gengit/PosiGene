package Bio::GMOD::Util::Rearrange;


use strict;
require Exporter;
use vars qw(@ISA @EXPORT @EXPORT_OK);
@ISA = 'Exporter';
@EXPORT_OK = qw(rearrange);
@EXPORT = qw(rearrange);

# default export
sub rearrange {
    my($order,@param) = @_;
    return unless @param;
    my %param;

    if (ref $param[0] eq 'HASH') {
      %param = %{$param[0]};
    } else {
      # Named parameter must begin with hyphen
      return @param unless (defined($param[0]) && substr($param[0],0,1) eq '-');

      my $i;
      for ($i=0;$i<@param;$i+=2) {
        $param[$i]=~s/^\-//;     # get rid of initial - if present
        $param[$i]=~tr/a-z/A-Z/; # parameters are upper case
      }

      %param = @param;                # convert into associative array
    }

    my(@return_array);

    local($^W) = 0;
    my($key)='';
    foreach $key (@$order) {
        my($value);
        if (ref($key) eq 'ARRAY') {
            foreach (@$key) {
                last if defined($value);
                $value = $param{$_};
                delete $param{$_};
            }
        } else {
            $value = $param{$key};
            delete $param{$key};
        }
        push(@return_array,$value);
    }
    push (@return_array,{%param}) if %param;
    return @return_array;
}


__END__

=pod

=head1 NAME

Bio::GMOD::Util::Rearrange - Named parameter processing

=head1 SYNPOSIS

  my ($var1,$var2) = rearrange([qw/VAR1 VAR2],@p)

=head1 DESCRIPTION

Bio::GMOD::Util::Rearrange provides the exported rearrange() function.
It is used throughout Bio::GMOD to process named parameters.  It is
almost essentially lifted in its entirety from Lincoln Stein's CGI.pm.

=head1 BUGS

None reported.

=head1 SEE ALSO

L<Bio::GMOD>

=head1 AUTHOR

Lincoln D. Stein E<lt>stein@cshl.eduE<gt>.
Todd W. Harris E<lt>harris@cshl.eduE<gt>.

Copyright (c) 2003-2005 Cold Spring Harbor Laboratory.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


1;
