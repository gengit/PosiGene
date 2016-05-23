package Bio::Das::Request::Sequences;
# $Id: Sequences.pm,v 1.2 2005/08/24 16:04:47 lstein Exp $
# this module issues and parses the types command, with arguments -dsn, -segment, -categories, -enumerate

=head1 NAME

Bio::Das::Request::Sequences - The DAS "sequence" request

=head1 SYNOPSIS

 my @sequences            = $request->results;
 my $sequences            = $request->results;

 my $dsn                  = $request->dsn;
 my $das_command          = $request->command;
 my $successful           = $request->is_success;
 my $error_msg            = $request->error;
 my ($username,$password) = $request->auth;

=head1 DESCRIPTION

This is a subclass of L<Bio::Das::Request::Dnas> specialized for
the "sequence" command.  It is used to retrieve the sequence
corresponding to a set of segments on a set of DAS servers.

=over 4

=cut

use strict;
use Bio::Das::Segment;
use Bio::Das::Request::Dnas;
use Bio::Das::Util 'rearrange';

use vars '@ISA';
@ISA = 'Bio::Das::Request::Dnas';

sub command { 'sequence' }

sub t_DASSEQUENCE {
    my ($self, $attrs) = @_;
    if ($attrs) {
        $self->clear_results;
        $self->{tmp}{current_segment} =
            Bio::Das::Segment->new(
                $attrs->{id},
                $attrs->{start},
                $attrs->{stop},
                $attrs->{version}
            );
    } else {
        $self->{tmp}{current_sequence} =~ s/\s//g;
        $self->add_object(
            $self->{tmp}{current_segment},
            $self->{tmp}{current_sequence}
        );
        delete $self->{tmp};
    }
}

sub t_SEQUENCE {
    my ($self, $attrs) = @_;

    if ($attrs) {  # start of tag
        $self->{tmp}{current_sequence} = '';
    } else {
        my $sequence = $self->char_data;
        $self->{tmp}{current_sequence} .= $sequence;
    }
}

=head1 AUTHOR

Lincoln Stein <lstein@cshl.org>

Contributions from: Andreas Kahari <andreas.kahari@ebi.ac.uk>

Copyright (c) 2001 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=head1 SEE ALSO

L<Bio::Das::Request::Dnas>, L<Bio::Das::Request>,
L<Bio::Das::Segment>, L<Bio::Das::HTTP::Fetch>
L<Bio::Das::Source>, L<Bio::Das::Type>, L<Bio::Das::Stylesheet>
L<Bio::Das::RangeI>

=cut

1;
