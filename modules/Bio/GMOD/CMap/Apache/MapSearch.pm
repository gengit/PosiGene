package Bio::GMOD::CMap::Apache::MapSearch;

# vim: set ft=perl:

use strict;
use vars qw( $VERSION $INTRO );
$VERSION = (qw$Revision: 1.8 $)[-1];

use Bio::GMOD::CMap::Apache;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Data;
use Template;
use Data::Dumper;

use base 'Bio::GMOD::CMap::Apache';
use constant TEMPLATE => 'map_search.tmpl';

# ----------------------------------------------------
sub handler {

    #
    # Main entry point.  Decides whether we forked and whether to
    # read session data.  Calls "show_form."
    #
    my ( $self, $apr ) = @_;
    my $ref_species_acc = $apr->param('ref_species_acc')
      || $apr->param('ref_species_aid')
      || '';
    my $prev_ref_species_acc = $apr->param('prev_ref_species_acc')
      || $apr->param('prev_ref_species_aid')
      || '';
    my $ref_map_set_acc = $apr->param('ref_map_set_acc')
      || $apr->param('ref_map_set_aid')
      || '';
    my $min_correspondence_maps = $apr->param('min_correspondence_maps') || 0;
    my $name_search             = $apr->param('name_search')             || '';
    my $order_by                = $apr->param('order_by')                || '';
    my $page_no                 = $apr->param('page_no')                 || 1;

    $INTRO ||= $self->config_data( 'map_viewer_intro', $self->data_source )
      || '';

    if ( $prev_ref_species_acc
        && ( $prev_ref_species_acc ne $ref_species_acc ) )
    {
        $ref_map_set_acc = '';
    }

    #
    # Take the feature types either from the query string (first
    # choice, splitting the string on commas) or from the POSTed
    # form <select>.
    #
    my @ref_map_accs;
    if ( $apr->param('ref_map_acc') || $apr->param('ref_map_aid') ) {
        @ref_map_accs =
          split( /,/,
            $apr->param('ref_map_acc') || $apr->param('ref_map_aid') );
    }
    elsif ( $apr->param('ref_map_accs') ) {
        @ref_map_accs = ( $apr->param('ref_map_accs') );
    }

    #
    # Set the data source.
    #
    $self->data_source( $apr->param('data_source') ) or return;

    my ( $ref_field, $ref_value );
    if ( grep { /^-1$/ } @ref_map_accs ) {
        $ref_field = 'map_set_acc';
        $ref_value = $ref_map_set_acc;
    }
    else {
        $ref_field = 'map_acc';
        $ref_value = \@ref_map_accs;
    }

    my %slots = (
        0 => {
            field       => $ref_field,
            acc         => $ref_value,
            start       => '',
            stop        => '',
            map_set_acc => $ref_map_set_acc,
        },
    );

    #
    # Get the data for the form.
    #
    my $data      = $self->data_module;
    my $form_data = $data->cmap_map_search_data(
        slots                   => \%slots,
        min_correspondence_maps => $min_correspondence_maps,
        ref_species_acc         => $ref_species_acc,
        name_search             => $name_search,
        order_by                => $order_by,
        page_no                 => $page_no
      )
      or return $self->error( $data->error );

    #
    # The start and stop may have had to be moved as there
    # were too few or too many features in the selected region.
    #
    $apr->param( ref_species_acc => $form_data->{'ref_species_acc'} );
    $apr->param( ref_map_set_acc => $form_data->{'ref_map_set_acc'} );

    my $html;
    my $t = $self->template or return;
    $t->process(
        TEMPLATE,
        {   apr                     => $apr,
            form_data               => $form_data,
            name_search             => $name_search,
            cur_order_by            => $order_by,
            min_correspondence_maps => $min_correspondence_maps,
            page                    => $self->page,
            intro                   => $INTRO,
            data_source             => $self->data_source,
            data_sources            => $self->data_sources,
            title                   => 'Map Search',
            stylesheet              => $self->stylesheet,
            pager                   => $form_data->{'pager'},
            web_image_cache_dir     => $self->web_image_cache_dir(),
            web_cmap_htdocs_dir     => $self->web_cmap_htdocs_dir(),
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

Bio::GMOD::CMap::Apache::MapSearch - map_search page to view comparative maps

=head1 SYNOPSIS

In httpd.conf:

  <Location /cmap/map_search>
      SetHandler  perl-script
      PerlHandler Bio::GMOD::CMap::Apache::MapSearch->super
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
Ken Y. Clark E<lt>kclark@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-6 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

