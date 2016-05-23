package Bio::GMOD::CMap::Admin::GBrowseLiason;

# vim: set ft=perl:

# $Id: GBrowseLiason.pm,v 1.13 2008/02/28 17:12:57 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Admin::GBrowseLiason - import alignments such as BLAST

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Admin::GBrowseLiason;
  my $liason = Bio::GMOD::CMap::Admin::GBrowseLiason->new;
  $liason->import(
    map_set_ids       => \@map_set_ids,
    feature_type_accs => \@feature_type_accs,
  ) or return $liason->error;

=head1 DESCRIPTION

This module encapsulates the logic for dealing with the 
GBrowse integration at the db level.

=cut

use strict;
use vars qw( $VERSION %COLUMNS $LOG_FH );
$VERSION = (qw$Revision: 1.13 $)[-1];

use Data::Dumper;
use Bio::GMOD::CMap;
use Bio::DB::GFF::Util::Binning;
use Bio::Graphics::Browser::Util qw[open_config];

use base 'Bio::GMOD::CMap';

# constants.

# this is the smallest bin (1 K)
use constant MIN_BIN => 1000;

# ----------------------------------------------

=pod

=head2 prepare_data_for_gbrowse

Given a list of map set ids and a list of feature type accessions,
this will add the "gbrowse_class" value in the config file for each
feature type, for all the features matching the map set ids and 
feature type accessions.

=cut

sub prepare_data_for_gbrowse {
    my ( $self, %args ) = @_;
    my $map_set_ids = $args{'map_set_ids'}
        or return $self->error('No map set ids');
    my $feature_type_accs = $args{'feature_type_accs'}
        or return $self->error('No feature type accs');
    my $db = $self->db;
    my %gclass_lookup;
    $LOG_FH = $args{'log_fh'} || \*STDOUT;
    print $LOG_FH "Preparing Data for GBrowse\n";
    my $admin      = $self->admin;
    my $sql_object = $self->sql;

    for ( my $i = 0; $i <= $#{$feature_type_accs}; $i++ ) {
        my $gclass = $self->feature_type_data( $feature_type_accs->[$i],
            'gbrowse_class' );
        if ($gclass) {
            $gclass_lookup{ $feature_type_accs->[$i] } = $gclass;
        }
        else {
            print $LOG_FH "Feature Type with acc "
                . $feature_type_accs->[$i]
                . " not eligible\n";
            print $LOG_FH
                "If you wish to prepare this feature type, add a gbrowse_class to it in the config file\n";
            splice @$feature_type_accs, $i, 1;
            $i--;
        }
    }
    return $self->error("No Map Sets to work on.\n")
        unless ( $map_set_ids and @$map_set_ids );
    return $self->error("No Feature Types to work on.\n")
        unless (%gclass_lookup);

    #
    # Make sure there is a "Map" feature for GBrowse
    #
    my $map_set_sql = qq[
        select  ms.map_type_acc,
                map.map_id,
                map.map_start,
                map.map_stop,
                map.map_name
        from    cmap_map_set ms,
                cmap_map map
        where   map.map_set_id=ms.map_set_id
            and ms.map_set_id in ( 
    ] . join( ',', @$map_set_ids ) . qq[ ) 
    ];

    my $map_feature_sql = qq[
        select  feature_id
        from    cmap_feature
        where   feature_type_acc= ?
            and map_id = ?
            and gclass = ?
    ];

    my $sth = $db->prepare($map_feature_sql);

    my $map_set_results
        = $db->selectall_arrayref( $map_set_sql, { Columns => {} }, );
    my %map_class_lookup;
    my $ft_acc = $self->config_data('gbrowse_default_map_feature_type_acc');
    return $self->error(
        "No gbrowse_default_map_feature_type_acc defined in config file.\n")
        unless ($ft_acc);
    foreach my $row (@$map_set_results) {
        unless ( $map_class_lookup{ $row->{'map_type_acc'} } ) {
            my $class = $self->map_type_data( $row->{'map_type_acc'},
                'gbrowse_map_class' );
            $class = $self->config_data('gbrowse_default_map_class')
                unless ($class);
            return $self->error(
                "No gbrowse_default_map_class defined in config file.\n")
                unless ($class);
            $map_class_lookup{ $row->{'map_type_acc'} } = $class;
        }
        $sth->execute( $ft_acc, $row->{'map_id'},
            $map_class_lookup{ $row->{'map_type_acc'} } );
        my $map_search = $sth->fetchrow_arrayref;
        unless ( $map_search and @$map_search ) {
            print $LOG_FH "Adding Map feature\n";
            $admin->feature_create(
                map_id       => $row->{'map_id'},
                feature_name => $self->create_fref_name( $row->{'map_name'} ),
                feature_start    => $row->{'feature_start'},
                feature_stop     => $row->{'feature_stop'},
                feature_type_acc => $ft_acc,
                gclass => $map_class_lookup{ $row->{'map_type_acc'} },
            );
        }
    }

    my $update_sql = qq[
        update cmap_feature, cmap_map
        set cmap_feature.gclass=? 
        where cmap_feature.feature_type_acc= ?
            and cmap_feature.map_id = cmap_map.map_id
            and cmap_map.map_set_id in ( 
    ] . join( ',', @$map_set_ids ) . qq[ ) 
    ];

    $sth = $db->prepare($update_sql);

    foreach my $ft_acc (@$feature_type_accs) {
        print $LOG_FH "Preparing Feature Type with accession $ft_acc\n";
        $sth->execute( $gclass_lookup{$ft_acc}, $ft_acc );
    }

    return 1;
}

# ----------------------------------------------

=pod

=head2 copy_data_into_gbrowse

Given a list of map set ids and an optional list of feature type accessions,
this will copy data from the CMap side of the db to the GBrowse side, allowing
it to be viewed in GBrowse.

=cut

sub copy_data_into_gbrowse {
    my ( $self, %args ) = @_;
    my $map_set_ids = $args{'map_set_ids'}
        or return $self->error('No map set ids');
    my $feature_type_accs = $args{'feature_type_accs'}
        or return $self->error('No feature type accs');
    my $db = $self->db;
    my %gclass_lookup;
    my %ftype_lookup;
    $LOG_FH = $args{'log_fh'} || \*STDOUT;

    print $LOG_FH "Handling Feature Types\n";

    # unless feature types are specified, get all of them.
    unless ( $feature_type_accs and @$feature_type_accs ) {
        my $feature_type_data = $self->feature_type_data();
        @$feature_type_accs = keys(%$feature_type_data);
    }

    # get the feature type acc that is used for the "Map feature"
    # and make sure that it is not in the list of feature types
    my $gbrowse_map_ft_acc
        = $self->config_data('gbrowse_default_map_feature_type_acc');

    @$feature_type_accs = grep !/$gbrowse_map_ft_acc/, @$feature_type_accs;

    # Remove feature types that don't have the proper attributes
    # specified in the config file.
    for ( my $i = 0; $i <= $#{$feature_type_accs}; $i++ ) {
        my $gclass = $self->feature_type_data( $feature_type_accs->[$i],
            'gbrowse_class' );
        my $ftype = $self->feature_type_data( $feature_type_accs->[$i],
            'gbrowse_ftype' );
        if ( $gclass and $ftype ) {
            $gclass_lookup{ $feature_type_accs->[$i] } = $gclass;
            $ftype_lookup{ $feature_type_accs->[$i] }  = $ftype;
        }
        else {
            print $LOG_FH $feature_type_accs->[$i]
                . " will Not be used because it does not have the following: \n";
            print $LOG_FH "gbrowse_class\n" unless $gclass;
            print $LOG_FH "gbrowse_ftype\n" unless $ftype;
            print $LOG_FH "\n";
            splice @$feature_type_accs, $i, 1;
            $i--;
        }
    }

    #Make sure we have something to work with
    return $self->error("No Map Sets to work on.\n")
        unless ( $map_set_ids and @$map_set_ids );
    return $self->error("No Feature Types to work on.\n")
        unless (%gclass_lookup);

    print $LOG_FH "Prepare data\n";

    # calling prepare_data_for_gbrowse since it's all written and everything
    $self->prepare_data_for_gbrowse(
        map_set_ids       => $map_set_ids,
        feature_type_accs => $feature_type_accs,
        )
        or do {
        print "Error: ", $self->error, "\n";
        return;
        };

    # Make sure there are all the required ftypes and get their ftypeids
    my %ftypeid_lookup;
    $self->find_or_create_ftype( \%ftypeid_lookup, values(%ftype_lookup) );

    # Get the data from CMap that is to be copied.
    # We will make the sql in a way that we don't get duplicate data.

    my $feature_sql = q[
        select  m.map_name,
                f.feature_id,
                f.feature_type_acc,
                f.feature_start,
                f.feature_stop,
                f.direction
        from    cmap_map m,
                cmap_feature f
        LEFT JOIN fdata 
        on      fdata.feature_id = f.feature_id
            and fdata.fstart = f.feature_start
            and fdata.fstop = f.feature_stop
        where   f.map_id=m.map_id
            and fdata.fid is NULL
            and m.map_set_id in ( 
    ] . join( ',', @$map_set_ids ) . qq[ ) 
            and f.feature_type_acc in ('
    ] . join( "','", @$feature_type_accs ) . qq[ ')
    ];
    my $map_feature_sql = qq[
        select  m.map_name,
                ms.map_type_acc,
                f.feature_id,
                f.feature_type_acc,
                f.feature_start,
                f.feature_stop,
                f.direction
        from    cmap_map m,
                cmap_map_set ms,
                cmap_feature f
        LEFT JOIN fdata 
        on      fdata.feature_id = f.feature_id
            and fdata.fstart = f.feature_start
            and fdata.fstop = f.feature_stop
        where   f.map_id=m.map_id
            and ms.map_set_id=m.map_set_id
            and fdata.fid is NULL
            and ms.map_set_id in ( 
    ] . join( ',', @$map_set_ids ) . qq[ ) 
            and f.feature_type_acc='$gbrowse_map_ft_acc'
    ];

    my $insert_data_sth = $db->prepare(
        q[
        insert into fdata 
        ( fref , fstart, fstop, fbin, ftypeid, fstrand, feature_id )
        values (?,?,?,?,?,?,?)
    ]
    );

    my ( $fref, $fstart, $fstop, $fbin, $ftypeid, $fstrand, $feature_id );

    # Insert the new features
    my $feature_results
        = $db->selectall_arrayref( $feature_sql, { Columns => {} }, );
    foreach my $row (@$feature_results) {
        $fref   = $self->create_fref_name( $row->{'map_name'} );
        $fstart = $row->{'feature_start'};
        $fstop  = $row->{'feature_stop'};
        $fbin   = bin( $fstart, $fstop, MIN_BIN );
        $ftypeid
            = $ftypeid_lookup{ $ftype_lookup{ $row->{'feature_type_acc'} } };
        $fstrand    = ( $row->{'feature_id'} > 0 ) ? '+' : '-';
        $feature_id = $row->{'feature_id'};

        $insert_data_sth->execute( $fref, $fstart, $fstop, $fbin, $ftypeid,
            $fstrand, $feature_id );
    }

    # Insert the new map features
    my $map_feature_results
        = $db->selectall_arrayref( $map_feature_sql, { Columns => {} }, );
    my %map_ftype_lookup;
    foreach my $row (@$map_feature_results) {

        # First get the maps ftype
        unless ( $map_ftype_lookup{ $row->{'map_type_acc'} } ) {
            my $ftype = $self->map_type_data( $row->{'map_type_acc'},
                'gbrowse_ftype' );
            if ($ftype) {
                $map_ftype_lookup{ $row->{'map_type_acc'} } = $ftype;
            }
            else {
                print $LOG_FH "Map Type with acc "
                    . $row->{'map_type_acc'}
                    . " not eligible\n";
                print $LOG_FH
                    "If you wish to prepare this map type, add a gbrowse_ftype to it in the config file\n";
                return $self->error( "Map Type Not Accepted: "
                        . $row->{'map_type_acc'}
                        . "\n" );
            }
        }

        # Next get the id of the ftype
        unless (
            $ftypeid_lookup{ $map_ftype_lookup{ $row->{'map_type_acc'} } } )
        {
            $self->find_or_create_ftype( \%ftypeid_lookup,
                $map_ftype_lookup{ $row->{'map_type_acc'} } );
        }

        $fref   = $self->create_fref_name( $row->{'map_name'} );
        $fstart = $row->{'feature_start'};
        $fstop  = $row->{'feature_stop'};
        $fbin   = bin( $fstart, $fstop, MIN_BIN );
        $ftypeid
            = $ftypeid_lookup{ $map_ftype_lookup{ $row->{'map_type_acc'} } };
        $fstrand    = '+';
        $feature_id = $row->{'feature_id'};

        $insert_data_sth->execute( $fref, $fstart, $fstop, $fbin, $ftypeid,
            $fstrand, $feature_id );
    }

    return 1;
}

# ----------------------------------------------

=pod

=head2 copy_data_into_cmap

Given a list of map set ids and an optional list of feature type accessions,
this will copy data from the CMap side of the db to the GBrowse side, allowing
it to be viewed in GBrowse.

=cut

sub copy_data_into_cmap {
    my ( $self, %args ) = @_;
    my $map_set_id = $args{'map_set_id'}
        or return $self->error('No map set ids');
    my $db = $self->db;
    my %fmethod_to_ft_acc;

    my $gbrowse_config_dir = $self->config_data('gbrowse_config_dir');
    return $self->error('No gbrowse_config_dir defined in config file')
        unless $gbrowse_config_dir;

    my $gbrowse_config = $self->config_data('gbrowse_config_file');
    return $self->error('No gbrowse_config_file defined in config file')
        unless $gbrowse_config;
    $gbrowse_config =~ s/\.conf$//;
    $gbrowse_config =~ s/^\d+\.//;

    my $main_gbconfig = open_config($gbrowse_config_dir);
    $main_gbconfig->source($gbrowse_config)
        or return $self->("Reading $gbrowse_config FAILED");
    my $gbconfig   = $main_gbconfig->config();
    my $track_info = $gbconfig->{'config'};

    my @labels = $gbconfig->labels();
    my $fmethod;

    # Build the connection between fmethod and ft_accs
    foreach my $label (@labels) {
        if ( $track_info->{$label}{'cmap_feature_type_acc'} ) {
            $fmethod = $track_info->{$label}{'feature'};
            $fmethod =~ s/:.+//;
            $fmethod_to_ft_acc{$fmethod}
                = $track_info->{$label}{'cmap_feature_type_acc'};
        }
    }

    my $data_sql = q[
        select
            m_group.feature_name as map_name,
            m_data.fstart as map_start,
            m_data.fstop as map_stop,
            f_group.feature_id,
            f_group.feature_acc,
            f_group.feature_name as feature_name,
            f_data.fstart as feature_start,
            f_data.fstop as feature_stop,
            f_data.fstrand as feature_strand,
            f_type.fmethod as feature_method
        from cmap_feature m_group,
            cmap_feature f_group,
            fdata m_data,
            fdata f_data,
            ftype f_type
        where
            m_data.feature_id=m_group.feature_id
            and (not f_group.map_id > 0)
            and f_data.fref=m_group.feature_name
            and f_data.feature_id=f_group.feature_id
            and f_data.ftypeid=f_type.ftypeid 
    ];
    $data_sql .= " and f_type.fmethod in ('"
        . join( "','", keys(%fmethod_to_ft_acc) ) . "')";
    $data_sql .= " order by m_group.feature_name ";

    my $feature_results
        = $db->selectall_arrayref( $data_sql, { Columns => {} }, );

    my $current_map_name;
    my $map_id;
    my $admin = $self->admin;
    my ( $direction, $ft_acc );
    my $map_count = 0;

    foreach my $row (@$feature_results) {
        unless ( defined $map_id and $current_map_name eq $row->{'map_name'} )
        {
            $map_count++;
            $current_map_name = $row->{'map_name'};
            $map_id           = $admin->map_create(
                map_name   => $row->{'map_name'},
                map_set_id => $map_set_id,
                map_start  => $row->{'map_start'},
                map_stop   => $row->{'map_stop'},
            );
        }
        $direction = 1;
        if ((   defined( $row->{'feature_strand'} )
                and $row->{'feature_strand'} eq '-'
            )
            or $row->{'feature_stop'} < $row->{'feature_start'}
            )
        {
            $direction = -1;
        }
        $ft_acc = $fmethod_to_ft_acc{ $row->{'feature_method'} };

        $sql_object->update_feature(
            map_id           => $map_id,
            feature_id       => $row->{'feature_id'},
            feature_name     => $row->{'feature_name'},
            feature_start    => $row->{'feature_start'},
            feature_stop     => $row->{'feature_stop'},
            feature_type_acc => $ft_acc,
            direction        => $direction,
        );
    }
    print "Copied "
        . scalar(@$feature_results)
        . " features on $map_count maps.\n";

    return 1;
}

# ----------------------------------------------

=pod

=head2 create_fref_name

This method gives a stable way to name the feature that represents a GBrowse
reference sequence.

=cut

sub create_fref_name {
    my $self     = shift;
    my $map_name = shift;

    return $map_name;
}

# ----------------------------------------------

=pod

=head2 find_or_create_ftype

Takes lookup hash and a list of ftype fmethods and fills the lookup hash with
the ftypeids with the fmethod as the key.

=cut

sub find_or_create_ftype {
    my $self       = shift;
    my $lookup     = shift;
    my @ftype_list = @_;
    my $db         = $self->db;

    my $sth = $db->prepare(
        q[
        select  ftypeid 
        from    ftype
        where   fmethod=?]
    );
    my $insert_type_sth = $db->prepare(
        q[
        insert into ftype 
        (fmethod,fsource) 
        values (?,'.')
    ]
    );

    foreach my $ftype (@ftype_list) {
        next if ( $lookup->{$ftype} );
        $sth->execute($ftype);
        my $ftype_result = $sth->fetchrow_hashref;
        if ( $ftype_result and %$ftype_result ) {
            $lookup->{$ftype} = $ftype_result->{'ftypeid'};
        }
        else {
            $insert_type_sth->execute($ftype);
            $sth->execute($ftype);
            my $ftype_result = $sth->fetchrow_hashref;
            if ( $ftype_result and %$ftype_result ) {
                $lookup->{$ftype} = $ftype_result->{'ftypeid'};
            }
            else {
                die
                    "Something terrible has happened and the ftype, $ftype did not insert\n";
            }
        }
    }
}

sub admin {
    my $self = shift;

    unless ( $self->{'admin'} ) {
        $self->{'admin'} = Bio::GMOD::CMap::Admin->new(
            config      => $self->config,
            data_source => $self->data_source,
        );
    }
    return $self->{'admin'};
}

1;

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.
Ken Y. Clark E<lt>kclark@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2005-7 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

