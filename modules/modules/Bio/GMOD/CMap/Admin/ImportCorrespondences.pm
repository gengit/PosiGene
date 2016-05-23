package Bio::GMOD::CMap::Admin::ImportCorrespondences;

# vim: set ft=perl:

# $Id: ImportCorrespondences.pm,v 1.39 2008/01/28 21:33:13 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Admin::ImportCorrespondences - import correspondences

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Admin::ImportCorrespondences;
  my $importer = Bio::GMOD::CMap::Admin::ImportCorrespondences->new;
  $importer->import(
      fh       => $fh,
      log_fh   => $self->log_fh,
  ) or return $importer->error;

=head1 DESCRIPTION

This module encapsulates all the logic for importing features
correspondences.  Currently, only one format is acceptable, a
tab-delimited file containing the following fields:

    feature_name1 *
    feature_acc1
    feature_name2 *
    feature_acc2
    evidence *
    is_enabled

Only the starred fields are required.  The order of the fields is
unimportant, and the order of the names of the features is, too, as
reciprocal records will be created for each correspondences ("A=B" and
"B=A," etc.).  If the evidence doesn't exist, a prompt will ask to
create it.

The evidence should be specified as an evidence_type_acc.  An optional score can be included.  The score must be numerical but may be in scientific notation.  Only evidences with scores will be retrieved when using the "Less Than Score" or "Greater Than Score".  In other words, if a score is not specified, this correspondence will NEVER appear when a score cutoff is set.

The syntax for the evidence column is as follows

    evidence_type_acc[:score]
    examples: "name_based", "blast:1e-10", "hunch:92"

B<Note:> If the accession IDs are not present, both the "feature_name"
and "aliases" are checked. For every feature matching each of the two
feature names, a correspondence will be created.

=cut

use strict;
use vars qw( $VERSION %COLUMNS $LOG_FH );
$VERSION = (qw$Revision: 1.39 $)[-1];

use Data::Dumper;
use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Admin;
use Bio::GMOD::CMap::Constants;
use Text::RecordParser;
use base 'Bio::GMOD::CMap';
use Regexp::Common;

%COLUMNS = (
    feature_name1 => { is_required => 1, datatype => 'string' },
    feature_acc1  => { is_required => 0, datatype => 'string' },
    feature_name2 => { is_required => 1, datatype => 'string' },
    feature_acc2  => { is_required => 0, datatype => 'string' },
    evidence      => { is_required => 1, datatype => 'string' },
    is_enabled    => { is_required => 0, datatype => 'number' },
);

use constant FIELD_SEP => "\t";    # use tabs for field separator

use constant STRING_RE => qr{\S+}; #qr{^[\w\s.()-]+$};

use constant RE_LOOKUP => {
    string => STRING_RE,
    number => '^' . $RE{'num'}{'real'} . '$',
};

# ----------------------------------------------------
sub import {

=pod

=head2 import

=head3 For External Use

=over 4

=item * Description

Import tab-delimited file of correspondences.

=item * Usage

    $importer->import(
        fh => $fh,
        log_fh => $log_fh,
        allow_update => $allow_update,
    );

=item * Returns

1

=item * Fields

=over 4

=item - fh

File handle of the imput file.

=item - log_fh

File handle of the log file (default is STDOUT).

=item - allow_update 

If allow is set to 1, the database will be searched for duplicates 
which is slow.  Setting to 0 is recommended.

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $fh = $args{'fh'} or return $self->error('No file handle');
    my @map_set_ids = @{ $args{'map_set_ids'} || [] };
    my %map_set_ids = map { $_, 1 } @{ $args{'map_set_ids'} || [] };
    my $sql_object = $self->sql;
    $LOG_FH = $args{'log_fh'} || \*STDOUT;
    my $allow_update = $args{'allow_update'};
    my $admin        = Bio::GMOD::CMap::Admin->new(
        config      => $self->config,
        data_source => $self->data_source,
    );

    my %evidence_type_acc_exists;
    $self->Print("Importing feature correspondence data.\n");

    #
    # Make column names lowercase, convert spaces to underscores
    # (e.g., make "Feature Name" => "feature_name").
    #
    $self->Print("Checking headers.\n");
    my $parser = Text::RecordParser->new(
        fh              => $fh,
        field_separator => FIELD_SEP,
        header_filter   => sub { $_ = shift; s/\s+/_/g; lc $_ },
        field_filter    => sub { $_ = shift; s/^\s+|\s+$//g; $_ },
    );
    $parser->bind_header;

    for my $column_name ( $parser->field_list ) {
        if ( exists $COLUMNS{$column_name} ) {
            $self->Print("Column '$column_name' OK.\n");
        }
        else {
            return $self->error("Column name '$column_name' is not valid.");
        }
    }

    my @feature_name_fields = qw[
        species_common_name map_set_short_name map_name feature_name
    ];

    $self->Print("Parsing file...\n");
    my ( %feature_ids, %evidence_type_accs, $inserts, $total );
LINE:
    while ( my $record = $parser->fetchrow_hashref ) {
        for my $field_name ( $parser->field_list ) {
            my $field_attr = $COLUMNS{$field_name} or next;
            my $field_val  = $record->{$field_name};

            if ( $field_attr->{'is_required'}
                && ( !defined $field_val || $field_val eq '' ) )
            {
                return $self->error("Field '$field_name' is required");
            }

            my $datatype = $field_attr->{'datatype'} || '';
            if ( $datatype && defined $field_val && $field_val ne '' ) {
                if ( my $regex = RE_LOOKUP->{$datatype} ) {
                    return $self->error( "Value of '$field_name'  is wrong.  "
                            . "Expected $datatype and got '$field_val'." )
                        unless $field_val =~ $regex;
                }
            }
        }
        $total++;

        my ( @feature_ids1, @feature_ids2 );
        for my $i ( 1, 2 ) {
            my $field_name            = "feature_name$i";
            my $acc_field_name        = "feature_acc$i";
            my $legacy_acc_field_name = "feature_accession_id$i";
            my $feature_name          = $record->{$field_name} || '';
            my $feature_acc           = $record->{$acc_field_name}
                || $record->{$legacy_acc_field_name}
                || '';
            next unless $feature_name || $feature_acc;
            my $upper_name = uc $feature_name;
            my @feature_ids;

            if ($feature_acc) {
                my $features
                    = $sql_object->get_features( feature_acc => $feature_acc,
                    );
                if ( @{ $features || [] } ) {
                    push @feature_ids, $features->[0];
                }
                else {
                    print STDERR "$feature_acc is not a valid feature_acc\n";
                    next LINE;
                }
            }
            else {
                if ( defined $feature_ids{$upper_name} ) {
                    @feature_ids = @{ $feature_ids{$upper_name} } or next;
                }
            }

            unless (@feature_ids) {
                @feature_ids = @{
                    $sql_object->get_features(
                        feature_name => $upper_name,
                        map_set_ids  => \@map_set_ids,
                    )
                    };
            }

            if (@feature_ids) {
                $feature_ids{$upper_name} = \@feature_ids;

                if ( $i == 1 ) {
                    @feature_ids1 = @feature_ids;
                }
                else {
                    @feature_ids2 = @feature_ids;
                }
            }
            else {
                $feature_ids{$upper_name} = [];
                warn qq[Cannot find feature IDs for "$feature_name".\n];
                next LINE;
            }
        }

        if (%map_set_ids) {
            my @found_map_set_ids = map { $_->{'map_set_id'} } @feature_ids1,
                @feature_ids2;
            my $ok;
            for my $found (@found_map_set_ids) {
                $ok = 1, last if $map_set_ids{$found};
            }
            next LINE unless $ok;
        }

        next LINE unless @feature_ids1 && @feature_ids2;

        my @evidences = map { s/^\s+|\s+$//g; $_ }
            split /,/, $record->{'evidence'};
        my @evidence_type_accs;
        my $evidence_type_acc;
        my $score;
        for my $evidence (@evidences) {
            if ( $evidence =~ /(\S+):(\S+)/ ) {
                $evidence_type_acc = $1;
                $score             = $2;
            }
            else {
                $evidence_type_acc = $evidence;
                $score             = undef;
            }

            unless ( $evidence_type_acc_exists{$evidence_type_acc} ) {
                if ( $self->evidence_type_data($evidence_type_acc) ) {
                    $evidence_type_acc_exists{$evidence_type_acc} = 1;
                }
                else {
                    $self->Print( "Evidence type accession '"
                            . $evidence_type_acc
                            . "' doesn't exist.  "
                            . "Please add it to your configuration file.[<enter> to continue] "
                    );
                    chomp( my $answer = <STDIN> );
                    return;
                }
            }

            push @evidence_type_accs, [ $evidence_type_acc, $score ];
        }

        my $is_enabled = $record->{'is_enabled'};
        $is_enabled = 1 unless defined $is_enabled;

        for my $feature1 (@feature_ids1) {
            for my $feature2 (@feature_ids2) {
                if (%map_set_ids) {
                    next
                        unless $map_set_ids{ $feature1->{'map_set_id'} }
                        || $map_set_ids{ $feature2->{'map_set_id'} };
                }

                for my $evidence_type_acc_list (@evidence_type_accs) {
                    my ( $evidence_type_acc, $score )
                        = @$evidence_type_acc_list;
                    my $fc_id = $admin->feature_correspondence_create(
                        feature_id1       => $feature1->{'feature_id'},
                        feature_id2       => $feature2->{'feature_id'},
                        evidence_type_acc => $evidence_type_acc,
                        score             => $score,
                        allow_update      => $allow_update,
                        threshold         => 1000,
                        )
                        or return $self->error( $admin->error );
                }
            }
        }
    }

    my $fc_id = $admin->feature_correspondence_create();

    return 1;
}

sub Print {

=pod

=head2 Print

=head3 NOT For External Use

=over 4

=item * Description

Prints to log file

=item * Usage

    $importer->Print();

=item * Returns



=back

=cut

    my $self = shift;
    print $LOG_FH @_;
}

1;

# ----------------------------------------------------
# Prisons are built with stones of Law,
# Brothels with bricks of Religion.
# William Blake
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.
Ken Y. Clark E<lt>kclark@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-7 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

