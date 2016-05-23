package Bio::GMOD::CMap::Admin::SavedLink;

# vim: set ft=perl:

# $Id: SavedLink.pm,v 1.7 2008/02/28 17:12:57 mwz444 Exp $

use strict;
use warnings;
use Data::Dumper;
use Data::Stag qw(:all);
use Time::ParseDate;

use Bio::GMOD::CMap::Admin;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Drawer;
use Storable qw(nfreeze thaw);

use base 'Bio::GMOD::CMap::Admin';

sub create_saved_link {
    my ( $self, %args ) = @_;
    my $parsed_options_ref = $args{'parsed_options_ref'};
    my $link_group         = $args{'link_group'};
    my $link_front         = $args{'link_front'};
    my $link_title         = $args{'link_title'};
    my $link_comment       = $args{'link_comment'};

    # Remove the session info to get keep create_session_step from overwriting
    delete $parsed_options_ref->{'session'};
    delete $parsed_options_ref->{'session_id'};
    delete $parsed_options_ref->{'step'};
    delete $parsed_options_ref->{'next_step'};

    # Create the drawer object to use it's link creation abilities
    # Note the config object is already set in parsed_options_ref
    my $drawer = Bio::GMOD::CMap::Drawer->new(
        skip_drawing => 1,
        %$parsed_options_ref,
        )
        or return $self->error( Bio::GMOD::CMap::Drawer->error );

    # Drawer went through some work (inadvertantly), we may as well take
    # advantage of that.
    $parsed_options_ref->{'slots'} = $drawer->{'slots'};

    # Created the URLs.
    # Not the saved_link_id will be added to the saved url in the insert call
    my $saved_url = $link_front;
    $saved_url .= $self->create_viewer_link(
        $drawer->create_minimal_link_params(),
        cmap_viewer_link_debug => 1,
        skip_map_info          => 1
    );
    my $legacy_url = $link_front;
    $legacy_url .= $self->create_viewer_link(
        $drawer->create_link_params(
            new_session       => 1,
            create_legacy_url => 1,
            ref_map_set_acc   => $parsed_options_ref->{'ref_map_set_acc'},
        )
    );

    # Get the session Step object that will be stored in the db.
    my $session_step_object
        = Bio::GMOD::CMap::Utils->create_session_step($parsed_options_ref)
        or return $self->error('Problem creating the new session step.');

    my $saved_link_id = $self->sql->insert_saved_link(
        saved_url           => $saved_url,
        legacy_url          => $legacy_url,
        session_step_object => nfreeze($session_step_object),
        link_group          => $link_group,
        link_title          => $link_title,
        link_comment        => $link_comment,
    );
    return $saved_link_id;
}

sub read_saved_links_file {
    my ( $self, %args ) = @_;
    my $file_name  = $args{'file_name'};
    my $link_front = $args{'link_front'} || 'viewer';
    my $link_group = $args{'link_group'} || DEFAULT->{'link_group'};
    print "Importing links from $file_name\n";

    my $stag_object = stag_parse( '-file' => $file_name, 'xml' );

VIEW:
    for my $view_params ( stag_find( $stag_object, 'cmap_view' ) ) {
        next VIEW unless $view_params;
        my %parsed_options;

        # get title
        my $link_title         = $view_params->find('title');
        my $current_link_group = $view_params->find('group') || $link_group;
        my $link_comment       = $view_params->find('comment');

        # Deal with each slot
        my $slots;
    SLOT:
        for my $slot_params ( stag_find( $view_params, 'slot' ) ) {
            my $slot_num = $slot_params->find('number');
            unless ( defined $slot_num ) {
                print STDERR qq[Slot object needs a 'number' parameter.\n];
                next VIEW;
            }
            $slots->{$slot_num} = _create_slot($slot_params);
        }
        unless ( $slots->{0} ) {
            print STDERR qq[No reference slot (slot 0) defined.\n];
            next VIEW;
        }

        $parsed_options{'slots'} = $slots;

        my $options_params = $view_params->get('menu_options');
        if ($options_params) {
        OPTION:
            for my $option ( $options_params->children() ) {
                my $tag = $option->element();
                $parsed_options{$tag} = $option->find($tag);
            }
        }

        my $saved_link_id = $self->create_saved_link(
            link_group         => $current_link_group,
            link_front         => $link_front,
            link_title         => $link_title,
            link_comment       => $link_comment,
            parsed_options_ref => \%parsed_options,
        );

    }
    return 1;
}

sub _create_slot {
    my $slot_params = shift;

    my %slot;

    $slot{'map_set_acc'} = $slot_params->find('map_set_acc');

    # Get Maps info
    for my $map_params ( $slot_params->get('map') ) {
        my $map_acc = $map_params->find('map_acc');
        $slot{'maps'}{$map_acc} = {
            start => $map_params->sget('map_start'),
            stop  => $map_params->sget('map_stop'),
            mag   => $map_params->sget('map_magnification') || 1,
        };
    }

    #Get Map Set info
    for my $map_set_params ( $slot_params->get('map_set') ) {
        my $map_set_acc = $map_set_params->find('map_set_acc');
        $slot{'map_sets'}{$map_set_acc} = ();
    }
    return \%slot;
}

1;

# ----------------------------------------------------
# All wholsome food is caught without a net or a trap.
# William Blake
# ----------------------------------------------------

=head1 NAME

Bio::GMOD::CMap::Admin::SavedLink - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<perl>

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

