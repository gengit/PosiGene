package Bio::GMOD::CMap::Data::Oracle;

# vim: set ft=perl:

# $Id: Oracle.pm,v 1.8 2008/02/12 22:13:09 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Data::Oracle - Oracle module

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Data::Oracle;
  blah blah blah

=head1 DESCRIPTION

Blah blah blah.

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.8 $)[-1];

use DBD::Oracle qw(:ora_types);
use Bio::GMOD::CMap::Data::Generic;
use base 'Bio::GMOD::CMap::Data::Generic';

# ----------------------------------------------------
sub set_date_format {

=pod

=head2 set_date_format

The SQL for setting the proper date format.

=cut

    my $self = shift;

    $self->db->do(
        q[ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS']);

    return 1;
}

# ----------------------------------------------------
sub date_format {

=pod

=head2 date_format

The strftime string for date format.

=cut

    my $self = shift;
    return '%d-%b-%y';
}

#-----------------------------------------------
sub insert_saved_link {

=pod

=head2 insert_saved_link()

=over 4

=item * IMPORTANT NOTE

This method is overwrites the parent method because Oracle needs blobs to be
specifically noted when inserting.

The oracle specific modifications were submitted by Baohua Wang.

=item * Description

Insert into the database.

=item * Adaptor Writing Info

The required inputs are only the ones that the database requires.

If you don't want CMap to insert into your database, make this a dummy method.

=item * Input

=over 4

=back

=item * Output

id

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object         => 0,
        no_validation       => 0,
        session_step_object => 0,
        saved_url           => 0,
        legacy_url          => 0,
        link_group          => 0,
        link_comment        => 0,
        link_title          => 0,
        last_access         => 0,
        hidden              => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $db                  = $self->db;
    my $session_step_object = $args{'session_step_object'};
    my $saved_url           = $args{'saved_url'};
    my $legacy_url          = $args{'legacy_url'};
    my $link_group          = $args{'link_group'};
    my $link_comment        = $args{'link_comment'};
    my $link_title          = $args{'link_title'};
    my $last_access         = $args{'last_access'};
    my $hidden              = $args{'hidden'} || 0;
    my $time                = localtime();
    my $saved_on            = $time->strftime( $self->date_format );
    unless ( defined $last_access ) {
        $last_access = $saved_on;
    }

    my $saved_link_id = $self->next_number( object_type => 'saved_link', )
        or return $self->error('No next number for saved_link ');
    $saved_url .= "saved_link_id=$saved_link_id;";

    my @insert_args = (
        $saved_link_id,       $saved_on,     $last_access,
        $session_step_object, $saved_url,    $legacy_url,
        $link_title,          $link_comment, $link_group,
        $hidden,
    );

    my $ins_sth = $db->prepare(
        qq[
        insert into cmap_saved_link
        (saved_link_id,  saved_on,     last_access,   session_step_object, 
         saved_url,      legacy_url,   link_title,    link_comment,
         link_group,     hidden  )
         values 
        ( ?,             ?,            ?,             ?, 
          ?,             ?,            ?,             ?,
          ?,             ? )
        ],
    );

    for ( my $i = 0; $i <= $#insert_args; $i++ ) {
        my %attr = ( $i == 3 ) ? ( ora_type => ORA_BLOB ) : ();
        $ins_sth->bind_param( $i + 1, $insert_args[$i], \%attr );
    }

    $ins_sth->execute;

    return $saved_link_id;
}

#-----------------------------------------------
sub update_saved_link {

=pod

=head2 update_saved_link()

=over 4

=item * IMPORTANT NOTE

This method is overwrites the parent method because Oracle needs blobs to be
specifically noted when inserting.

The oracle specific modifications were submitted by Baohua Wang.

=item * Description

Given the id and some attributes to modify, updates.

=item * Adaptor Writing Info

=item * Input

=over 4

=back

=back

=cut

    my $self              = shift;
    my %validation_params = (
        cmap_object         => 0,
        no_validation       => 0,
        saved_link_id       => 1,
        session_step_object => 0,
        saved_url           => 0,
        legacy_url          => 0,
        link_group          => 0,
        link_comment        => 0,
        link_title          => 0,
        hidden              => 0,
    );
    my %args = @_;
    validate( @_, \%validation_params ) unless $args{'no_validation'};

    my $db = $self->db;

    my @update_args = ();
    my $update_sql  = qq[
        update cmap_saved_link
    ];
    my @set_list;
    my $where_sql = " where saved_link_id = ? ";    # ID

    my $time = localtime();
    $args{'last_access'} = $time->strftime( $self->date_format );

    my @column_is_blob;
    for my $column (
        qw[ session_step_object
        saved_url legacy_url link_group link_comment
        link_title last_access hidden]
        )
    {
        if ( defined( $args{$column} ) ) {
            push @update_args, $args{$column};
            push @set_list,    " $column = ? ";
            push @column_is_blob,
                ( ( $column eq 'session_step_object' ) ? 1 : 0 );
        }
    }

    return unless @set_list;    # nothing to update

    my $set_sql = ' set ' . join( q{,}, @set_list ) . ' ';

    push @update_args,    $args{'saved_link_id'};
    push @column_is_blob, 0;

    my $sql_str = $update_sql . $set_sql . $where_sql;
    my $up_sth  = $db->prepare($sql_str);
    $db->do( $sql_str, {}, @update_args );

    for ( my $i = 0; $i <= $#update_args; $i++ ) {
        my %attr = ( $column_is_blob[$i] ) ? ( ora_type => ORA_BLOB ) : ();
        $up_sth->bind_param( $i + 1, $update_args[$i], \%attr );
    }

    $up_sth->execute;

}

1;

# ----------------------------------------------------
# I should not talk so much about myself
# if there were anybody whom I knew as well.
# Henry David Thoreau
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-8 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut
