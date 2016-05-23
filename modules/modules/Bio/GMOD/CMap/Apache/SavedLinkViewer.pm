package Bio::GMOD::CMap::Apache::SavedLinkViewer;

# vim: set ft=perl:

# $Id: SavedLinkViewer.pm,v 1.16 2008/02/28 17:12:58 mwz444 Exp $

use strict;
use Data::Dumper;
use Template;
use Time::ParseDate;

use CGI;
use Bio::GMOD::CMap::Apache;
use Bio::GMOD::CMap::Admin::SavedLink;
use Bio::GMOD::CMap::Constants;

use base 'Bio::GMOD::CMap::Apache';

use vars qw( $VERSION $PAGE_SIZE $MAX_PAGES $INTRO );
use constant MULTI_VIEW_TEMPLATE => 'saved_links_viewer.tmpl';
use constant EDIT_TEMPLATE       => 'saved_link_edit.tmpl';
use constant SAVED_LINK_URI      => 'saved_links';

# ----------------------------------------------------
sub handler {

    #
    # Make a jazz noise here...
    #
    my ( $self, $apr ) = @_;

    $self->data_source( $apr->param('data_source') ) or return;

    my $action = $apr->param('action') || 'saved_links_viewer';
    my $return = eval { $self->$action() };
    return $self->error($@) if $@;
    return 1;
}

# ---------------------------------------------------
sub saved_links_viewer {
    my ( $self, %args ) = @_;
    my $apr = $self->apr;
    my $sql_object = $self->sql or return;

    my $page_no = $apr->param('page_no') || 1;
    my $selected_link_group = $apr->param('selected_link_group');

    # This is the value to see if we return hidden links
    # When it is undef, it will return all links but
    # when it is "0" it will return only non-hidden ones.
    my $hidden = $apr->param('display_hidden') ? undef : 0;

    # Create hash of link_groups
    my $link_group_counts_ref
        = $sql_object->get_saved_link_groups( hidden => $hidden, );

    my $pager;
    my $saved_links_ref;
    if ($selected_link_group) {

        # Get the Saved links
        $saved_links_ref = $sql_object->get_saved_links(
            link_group => $selected_link_group,
            hidden     => $hidden,
        );

        # Slice the results up into pages suitable for web viewing.
        $PAGE_SIZE ||= $self->config_data('max_child_elements') || 0;
        $MAX_PAGES ||= $self->config_data('max_search_pages')   || 1;
        $pager = Data::Pageset->new(
            {   total_entries    => scalar @$saved_links_ref,
                entries_per_page => $PAGE_SIZE,
                current_page     => $page_no,
                pages_per_set    => $MAX_PAGES,
            }
        );
        $saved_links_ref = [ $pager->splice($saved_links_ref) ]
            if @$saved_links_ref;
    }

    $INTRO ||= $self->config_data('saved_links_intro') || q{};

    my $html;
    my $t = $self->template;
    $t->process(
        MULTI_VIEW_TEMPLATE,
        {   apr                 => $apr,
            current_url         => "saved_links?" . $apr->query_string(),
            page                => $self->page,
            stylesheet          => $self->stylesheet,
            data_sources        => $self->data_sources,
            saved_links         => $saved_links_ref,
            link_group_counts   => $link_group_counts_ref,
            pager               => $pager,
            intro               => $INTRO,
            web_image_cache_dir => $self->web_image_cache_dir(),
            web_cmap_htdocs_dir => $self->web_cmap_htdocs_dir(),
        },
        \$html
    ) or $html = $t->error;

    print $apr->header( -type => 'text/html', -cookie => $self->cookie ),
        $html;
    return 1;
}

# ----------------------------------------------------
sub saved_link_create {
    my ( $self, %args ) = @_;
    my $current_apr = $self->apr;
    my $url_to_save = $current_apr->param('url_to_save')
        or die 'No url to save';
    my $url_to_apr = $url_to_save;

    # Strip off stuff that isn't the query string.
    $url_to_apr =~ s/.+?\?//;

    my $apr_to_save = new CGI($url_to_apr)
        or return $self->error("URL did not parse correctly.  $url_to_save");

    # GET USERNAME FROM COOKIE
    my $link_group = $current_apr->param('link_group')
        || DEFAULT->{'link_group'};

    # Use the url to create the parameters to pass to drawer.
    my %parsed_url_options
        = Bio::GMOD::CMap::Utils->parse_url( $apr_to_save, $self )
        or return $self->error();

    my ($link_front) = ( $url_to_save =~ m/.+\/(.+?)\?/ );
    my $saved_link_admin = Bio::GMOD::CMap::Admin::SavedLink->new(
        config      => $self->config,
        data_source => $self->data_source(),
    );
    my $saved_link_id = $saved_link_admin->create_saved_link(
        link_group         => $link_group,
        link_front         => $link_front,
        parsed_options_ref => \%parsed_url_options,
    );

    # After creating the link,
    # send everything over to saved_link_edit to handle
    # but first modify some values that it uses
    $current_apr->param( 'url_to_return_to', $url_to_save );
    $current_apr->param( 'saved_link_id',    $saved_link_id );

    return $self->saved_link_edit();
}

# ----------------------------------------------------
sub saved_link_edit {
    my ( $self, %args ) = @_;
    my $apr           = $self->apr;
    my $sql_object    = $self->sql or return;
    my $saved_link_id = $apr->param('saved_link_id')
        or die 'No feature saved_link id';
    my $url_to_return_to = $apr->param('url_to_return_to');

    my $saved_links
        = $sql_object->get_saved_links( saved_link_id => $saved_link_id, );
    my $saved_link;
    if ( @{ $saved_links || [] } ) {
        $saved_link = $saved_links->[0];
    }
    unless ( %{ $saved_link || {} } ) {
        return $self->error(
            "Failed getting saved link with id $saved_link_id\n");
    }

    my $html;
    my $t = $self->template or return;
    $t->process(
        EDIT_TEMPLATE,
        {   apr                 => $apr,
            page                => $self->page,
            stylesheet          => $self->stylesheet,
            data_sources        => $self->data_sources,
            saved_link          => $saved_link,
            url_to_return_to    => $url_to_return_to,
            web_image_cache_dir => $self->web_image_cache_dir(),
            web_cmap_htdocs_dir => $self->web_cmap_htdocs_dir(),
        },
        \$html
    ) or $html = $t->error;
    print $apr->header( -type => 'text/html', -cookie => $self->cookie ),
        $html;
    return 1;
}

# ----------------------------------------------------
sub saved_link_update {
    my ( $self, %args ) = @_;
    my $apr              = $self->apr;
    my $url_to_return_to = $apr->param('url_to_return_to');
    my $save_and_return  = $apr->param('save_and_return') || 0;

    my $saved_link_id = $apr->param('saved_link_id')
        or die 'No feature saved_link id';

    $self->sql->update_saved_link(
        saved_link_id => $saved_link_id,
        link_group    => $apr->param('link_group'),
        link_title    => $apr->param('link_title'),
        link_comment  => $apr->param('link_comment'),
        hidden        => $apr->param('hidden') || 0,
    );

    if ($save_and_return) {
        print $apr->redirect( $url_to_return_to, );
        return;
    }
    else {
        return $self->saved_link_edit();
    }
}

1;

# ----------------------------------------------------
# All wholsome food is caught without a net or a trap.
# William Blake
# ----------------------------------------------------

=head1 NAME

Bio::GMOD::CMap::Apache::SavedLinkViewer - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<perl>

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2005-6 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

