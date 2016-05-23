package Bio::GMOD::CMap::Apache::SpiderViewer;

# vim: set ft=perl:

use strict;
use vars qw( $VERSION $INTRO );
$VERSION = (qw$Revision: 1.6 $)[-1];

use Bio::GMOD::CMap::Apache;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Data;
use Template;
use Data::Dumper;

use base 'Bio::GMOD::CMap::Apache';
use constant TEMPLATE => 'spider_viewer.tmpl';

# ----------------------------------------------------
sub handler {

    #
    # Main entry point.  Decides whether we forked and whether to
    # read session data.  Calls "show_form."
    #
    my ( $self, $apr ) = @_;
    my $map_acc = $apr->param('map_acc') || $apr->param('map_aid') || '';
    my $degrees_to_crawl = $apr->param('degrees_to_crawl') || 0;
    my $min_corrs        = $apr->param('min_corrs')        || 0;

    $INTRO ||= $self->config_data( 'spider_viewer_intro', $self->data_source )
      || '';

    #
    # Set the data source.
    #
    $self->data_source( $apr->param('data_source') ) or return;

    #
    # Get the links
    #
    my $data      = $self->data_module;
    my $link_info = $data->cmap_spider_links(
        map_acc          => $map_acc,
        degrees_to_crawl => $degrees_to_crawl,
        min_corrs        => $min_corrs,
      )
      or return $self->error( $data->error );

    my $html;
    my $t = $self->template or return;
    $t->process(
        TEMPLATE,
        {   apr                 => $apr,
            map_acc             => $map_acc,
            degrees_to_crawl    => $degrees_to_crawl,
            min_corrs           => $min_corrs,
            link_info           => $link_info,
            intro               => $INTRO,
            data_source         => $self->data_source,
            data_sources        => $self->data_sources,
            title               => 'Welcome to CMap Spider',
            stylesheet          => $self->stylesheet,
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
# Prisons are built with stones of Law,
# Brothels with bricks of Religion.
# William Blake
# ----------------------------------------------------

=head1 NAME

Bio::GMOD::CMap::Apache::SpiderViewer - spider page to view comparative maps

=head1 SYNOPSIS

In httpd.conf:

  <Location /cmap/spider>
      SetHandler  perl-script
      PerlHandler Bio::GMOD::CMap::Apache::SpiderViewer->super
  </Location>

=head1 DESCRIPTION

This module is a mod_perl handler for directing the user to 
comparative maps.  It inherits from
Bio::GMOD::CMap::Apache where all the error handling occurs.

Added forking to allow creation of really large maps.  Stole most of
the implementation from Randal Schwartz:

    http://www.stonehenge.com/merlyn/LinuxMag/col39.html

=head1 SEE ALSO

L<perl>, L<Template>.

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2004-6 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

