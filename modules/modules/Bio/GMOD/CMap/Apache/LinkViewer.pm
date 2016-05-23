package Bio::GMOD::CMap::Apache::LinkViewer;

# vim: set ft=perl:

use strict;
use vars qw( $VERSION $PAGE_SIZE $MAX_PAGES $INTRO );
$VERSION = (qw$Revision: 1.5 $)[-1];

use Data::Pageset;
use Bio::GMOD::CMap::Apache;
use Data::Dumper;
use base 'Bio::GMOD::CMap::Apache';

use constant TEMPLATE => 'link_viewer.tmpl';

sub handler {
    my ( $self, $apr ) = @_;
    $self->data_source( $apr->param('data_source') ) or return;

    my $page_no           = $apr->param('page_no') || 1;
    my $selected_link_set = $apr->param('selected_link_set');
    my $data_module       = $self->data_module;

    my $data =
      $data_module->link_viewer_data( selected_link_set => $selected_link_set )
      or return $self->error( $data_module->error );
    my $links     = $data->{'links'};
    my $link_sets = $data->{'link_sets'};

    $PAGE_SIZE ||= $self->config_data('max_child_elements') || 0;
    $MAX_PAGES ||= $self->config_data('max_search_pages')   || 1;

    #
    # Slice the results up into pages suitable for web viewing.
    #
    my $pager = Data::Pageset->new(
        {
            total_entries    => scalar @$links,
            entries_per_page => $PAGE_SIZE,
            current_page     => $page_no,
            pages_per_set    => $MAX_PAGES,
        }
    );
    $links = [ $pager->splice($links) ] if @$links;

    $INTRO ||= $self->config_data('link_info_intro') || '';

    my $html;
    my $t = $self->template;
    $t->process(
        TEMPLATE,
        {   apr                 => $apr,
            page                => $self->page,
            stylesheet          => $self->stylesheet,
            data_sources        => $self->data_sources,
            links               => $links,
            link_sets           => $link_sets,
            pager               => $pager,
            intro               => $INTRO,
            web_image_cache_dir => $self->web_image_cache_dir(),
            web_cmap_htdocs_dir => $self->web_cmap_htdocs_dir(),
        },
        \$html
        )
        or $html = $t->error;

    print $apr->header( -type => 'text/html', -cookie => $self->cookie ), $html;
    return 1;
}

1;

# ----------------------------------------------------
# Where man is not nature is barren.
# William Blake
# ----------------------------------------------------

=head1 NAME

Bio::GMOD::CMap::Apache::MapSetViewer - 
    show information on one or more map sets

=head1 SYNOPSIS

In httpd.conf:

  <Location /cmap/map_set_info>
      SetHandler  perl-script
      PerlHandler Bio::GMOD::CMap::Apache::MapSetViewer->super
  </Location>

=head1 DESCRIPTION

Show the information on one or more map sets (identified by map set accession
IDs, separated by commas) or all map sets.

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.
Ken Y. Clark E<lt>kclark@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2004-6 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

