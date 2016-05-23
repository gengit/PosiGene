package Bio::GMOD::CMap::Admin::ManageLinks;

# vim: set ft=perl:

# $Id: ManageLinks.pm,v 1.12 2008/01/24 16:43:08 mwz444 Exp $

=pod

=head1 NAME

Bio::GMOD::CMap::Admin::ManageLinks - imports and drops links 

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Admin::ManageLinks;

  my $link_manager = Bio::GMOD::CMap::Admin::ManageLinks->new();
  $link_manager->import(
       data_source => $data_source,
  ) or print "Error: ", $link_manager->error, "\n";

=head1 DESCRIPTION

This module encapsulates the logic for handling imported links.

=cut

use strict;
use vars qw( $VERSION %DISPATCH %COLUMNS );
$VERSION = (qw$Revision: 1.12 $)[-1];

use Data::Dumper;
use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Constants;
use Text::RecordParser;
use Text::ParseWords 'parse_line';
use Cache::FileCache;
use Storable qw(nfreeze thaw);
use Regexp::Common;
use base 'Bio::GMOD::CMap';

use constant FIELD_SEP => "\t";      # use tabs for field separator
use constant STRING_RE => qr{\S+};
use constant RE_LOOKUP => {
    string => STRING_RE,
    number => '^' . $RE{'num'}{'real'} . '$',
};

use vars '$LOG_FH';

%COLUMNS = (
    map_name        => { is_required => 1, datatype => 'string' },
    map_start       => { is_required => 0, datatype => 'number' },
    map_stop        => { is_required => 0, datatype => 'number' },
    map_accesion_id => { is_required => 0, datatype => 'string' },
    link_name       => { is_required => 0, datatype => 'string' },
);

# ----------------------------------------------------

sub import_links {

=pod

=head2 import_links

=head3 For External Use

=over 4

=item * Description

Imports links from a tab-delimited file with the following fields:

    map_name (required)
    map_start
    map_stop
    map_accesion_id
    link_name

=item * Usage

    $link_manager->import_links(
        fh => $fh,
        log_fh => $log_fh,
        link_set_name => $link_set_name,
        map_set_id => $map_set_id,
    );

=item * Returns

1

=item * Fields

=over 4

=item - fh

File handle of the input file

=item - log_fh

File handle of the log file, defaults to STDOUT

=item - link_set_name

The name of the link set.  This is the name that the set is stored
under and is displayed when the accessing the links.

=item - map_set_id

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $sql_object    = $self->sql             or die 'No sql handle';
    my $map_set_id    = $args{'map_set_id'}    or die 'No map set id';
    my $link_set_name = $args{'link_set_name'} or die 'No link set name';
    my $fh            = $args{'fh'}            or die 'No file handle';

    $LOG_FH = $args{'log_fh'} || \*STDOUT;
    my @links;

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
    $parser->field_compute( 'feature_aliases',
        sub { [ parse_line( ',', 0, shift() ) ] } );
    $parser->bind_header;

    my %required =
      map { $_, 0 }
      grep { $COLUMNS{$_}{'is_required'} }
      keys %COLUMNS;

    for my $column_name ( $parser->field_list ) {
        if ( exists $COLUMNS{$column_name} ) {
            $self->Print("Column '$column_name' OK.\n");
            $required{$column_name} = 1 if defined $required{$column_name};
        }
        else {
            return $self->error("Column name '$column_name' is not valid.");
        }
    }

    if ( my @missing = grep { $required{$_} == 0 } keys %required ) {
        return $self->error(
            "Missing following required columns: " . join( ', ', @missing ) );
    }

    my $map_set_acc = $sql_object->internal_id_to_acc_id(
        object_type => 'map_set',
        id          => $map_set_id,
    );

    $self->Print("Parsing file...\n");
    my ( $last_map_name, $last_map_id ) = ( '', '' );
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

                    #
                    # The following line forces the string a numeric
                    # context where it's more likely to succeed in the
                    # regex.  This solves ".4" being bad according to
                    # the regex.
                    #
                    $field_val += 0 if $datatype eq 'number';
                    return $self->error( "Value of '$field_name' is wrong.  "
                          . "Expected $datatype and got '$field_val'." )
                      unless $field_val =~ $regex;
                }
            }
            elsif ( $datatype eq 'number' && $field_val eq '' ) {
                $field_val = undef;
            }
        }

        my $map_acc   = $record->{'map_accession_id'} || $record->{'map_acc'};
        my $map_name  = $record->{'map_name'};
        my $map_start = $record->{'map_start'};
        my $map_stop  = $record->{'map_stop'};
        my $link_name = $record->{'link_name'};

        unless ( defined($map_acc) ) {
            return $self->error("Must specify a map_acc or a map_name\n")
              unless ( defined($map_name) );

            my $temp_maps = $sql_object->get_maps(
                map_set_id  => $map_set_id,
                map_name    => $map_name,
            );

            return $self->error("$map_name was not in the dataset\n")
              unless ( $temp_maps and @$temp_maps );
            $map_acc = $temp_maps->[0]{'map_acc'};
        }
        unless ($link_name) {
            $link_name = $map_name ? $map_name : "map_acc:$map_acc";
            if (    defined($map_start)
                and defined($map_stop)
                and !( $map_start eq '' )
                and !( $map_stop  eq '' ) )
            {
                $link_name .= " from $map_start to $map_stop.";
            }
            elsif ( defined($map_start) and !( $map_start eq '' ) ) {
                $link_name .= " from $map_start to the end.";
            }
            elsif ( defined($map_stop) and !( $map_stop eq '' ) ) {
                $link_name .= " from the start to $map_stop.";
            }
        }

        my %ref_map_accs_hash;
        $ref_map_accs_hash{$map_acc} = ();
        my %temp_hash = (
            link_name       => $link_name,
            ref_map_set_acc => $map_set_acc,
            ref_map_accs    => \%ref_map_accs_hash,
            ref_map_start   => $map_start,
            ref_map_stop    => $map_stop,
            data_source     => $self->data_source,
        );
        push @links, \%temp_hash;
    }
    my %cache_params = ( 'namespace' => $self->get_link_name_space(), );
    my $cache        = new Cache::FileCache( \%cache_params );

    $cache->set( $link_set_name, nfreeze( \@links ) );
    $self->Print("Done\n");

    return 1;
}

# ----------------------------------------------------
sub delete_links {

=pod

=head2 delete_links

=head3 For External Use

=over 4

=item * Description

Delete a Link Set

=item * Usage

    $link_manager->delete_links(
        log_fh => $log_fh,
        link_set_name => $link_set_name,
    );

=item * Returns

1

=item * Fields

=over 4

=item - log_fh

File handle of the log file, defaults to STDOUT

=item - link_set_name

The name of the link set.  This is the name that the set is stored
under and is displayed when the accessing the links.

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $link_set_name = $args{'link_set_name'};
    $LOG_FH = $args{'log_fh'} || \*STDOUT;

    my %cache_params = ( 'namespace' => $self->get_link_name_space, );
    my $cache        = new Cache::FileCache( \%cache_params );

    $cache->remove($link_set_name);
    return 1;
}

# ----------------------------------------------------
sub list_set_names {

=pod

=head2 list_set_names

=head3 For External Use

=over 4

=item * Description

Lists all the link sets in the name space (the data_source)

=item * Usage

    $link_manager->list_set_names(
        log_fh => $log_fh,
    );

=item * Returns

Arrayref of link names

=item * Fields

=over 4

=item - log_fh

File handle of the log file, defaults to STDOUT

=back

=back

=cut

    my ( $self, %args ) = @_;
    $LOG_FH = $args{'log_fh'} || \*STDOUT;

    my %cache_params = ( 'namespace' => $self->get_link_name_space, );
    my $cache        = new Cache::FileCache( \%cache_params );

    return $cache->get_keys();
}

# ----------------------------------------------------
sub output_links {

=pod

=head2 output_links

=head3 For External Use

=over 4

=item * Description

Creates urls for each of the links stored and returns them in a list.

=item * Usage

    $link_manager->output_links(
        log_fh => $log_fh,
        link_set_name => $link_set_name,
    );

=item * Returns

A list of urls.

=item * Fields

=over 4

=item - log_fh

File handle of the log file, defaults to STDOUT

=item - link_set_name

The name of the link set.  This is the name that the set is stored
under and is displayed when the accessing the links.

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $link_set_name = $args{'link_set_name'} or return;
    $LOG_FH = $args{'log_fh'} || \*STDOUT;

    my %cache_params = ( 'namespace' => $self->get_link_name_space, );
    my $cache        = new Cache::FileCache( \%cache_params );

    my @links;
    my $link_data_set = thaw( $cache->get($link_set_name) );
    foreach my $link_data (@$link_data_set) {
        my %temp_array = (
            name => $link_data->{'link_name'},
            link => $self->create_viewer_link(%$link_data),
        );
        push @links, \%temp_array;
    }
    return @links;
}

# -------------------------------------------
sub Print {

=pod

=head2 Print

=head3 NOT For External Use

=over 4

=item * Description

Prints to the log file

=item * Usage

    $link_manager->Print();

=item * Returns



=back

=cut

    my $self = shift;
    print $LOG_FH @_;
}

1;

# ----------------------------------------------------
# Which way does your beard point tonight?
# Allen Ginsberg
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.
Ken Y. Clark E<lt>kclark@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2004-7 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

