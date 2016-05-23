package Bio::GMOD::CMap::Apache::CorrespondenceMenu;

# vim: set ft=perl:

# $Id: CorrespondenceMenu.pm,v 1.6 2007/09/28 20:17:08 mwz444 Exp $

use strict;
use vars qw( $VERSION $INTRO $PAGE_SIZE $MAX_PAGES);
$VERSION = (qw$Revision: 1.6 $)[-1];

use Bio::GMOD::CMap::Apache;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Data;
use Bio::GMOD::CMap::Utils;
use Template;
use URI::Escape;
use Data::Dumper;

use base 'Bio::GMOD::CMap::Apache';
use constant TEMPLATE => 'correspondence_menu.tmpl';

# ----------------------------------------------------
sub handler {

    #
    my ( $self, $apr ) = @_;

    my $side = $apr->param('side') || '';
    $side = lc $side;
    unless ( $side eq 'right' or $side eq 'left' ) {
        return;
    }

    # zero out some irrelevant selections
    $apr->param( 'comp_map_set_' . $side,    undef );
    $apr->param( 'comparative_map_' . $side, undef );

    # parse the url
    my %url_options = Bio::GMOD::CMap::Utils->parse_url( $apr, $self )
        or return $self->error();

    my $corr_menu_min_corrs = $apr->param( 'corr_menu_min_corrs_' . $side )
        || 0;
    my $data = $self->data_module;

    my $html;

    my $form_data;

    unless ( $apr->param('start') ) {
        $form_data = $data->correspondence_form_data(
            slots                       => $url_options{'slots'},
            menu_min_corrs              => $corr_menu_min_corrs,
            url_feature_default_display =>
                $url_options{'url_feature_default_display'},
            included_feature_types  => $url_options{'feature_types'},
            ignored_feature_types   => $url_options{'ignored_feature_types'},
            corr_only_feature_types =>
                $url_options{'corr_only_feature_types'},
            ignored_evidence_types  => $url_options{'ignored_evidence_types'},
            included_evidence_types =>
                $url_options{'included_evidence_types'},
            less_evidence_types    => $url_options{'less_evidence_types'},
            greater_evidence_types => $url_options{'greater_evidence_types'},
            evidence_type_score    => $url_options{'evidence_type_score'},
            slot_min_corrs         => $url_options{'slot_min_corrs'},
            side                   => $side,
            )
            or return $self->error( $data->error );
    }
    my @slot_nos = sort { $a <=> $b } keys %{ $url_options{'slots'} };
    my $slot_no;
    if ( $side eq 'left' ) {
        $slot_no = $slot_nos[0] - 1;
    }
    else {
        $slot_no = $slot_nos[-1] + 1;
    }

    my $t = $self->template or return;
    $t->process(
        TEMPLATE,
        {   apr                 => $apr,
            form_data           => $form_data,
            side                => $side,
            slot_no             => $slot_no,
            corr_menu_min_corrs => $corr_menu_min_corrs,
            menu_bgcolor_tint   => $self->config_data('menu_bgcolor_tint')
                || DEFAULT->{'menu_bgcolor_tint'},
            menu_bgcolor => $self->config_data('menu_bgcolor')
                || DEFAULT->{'menu_bgcolor'},
            menu_ref_bgcolor_tint =>
                $self->config_data('menu_ref_bgcolor_tint')
                || DEFAULT->{'menu_ref_bgcolor_tint'},
            menu_ref_bgcolor => $self->config_data('menu_ref_bgcolor')
                || DEFAULT->{'menu_ref_bgcolor'},
            web_image_cache_dir => $self->web_image_cache_dir(),
            web_cmap_htdocs_dir => $self->web_cmap_htdocs_dir(),
        },
        \$html
        )
        or $html = $t->error;

    # Regular map viewing
    print $apr->header(
        -type   => 'text/html',
        -cookie => $self->cookie
    ), $html;

    return 1;
}

1;

# ----------------------------------------------------
# Prisons are built with stones of Law,
# Brothels with bricks of Religion.
# William Blake
# ----------------------------------------------------

=head1 NAME

Bio::GMOD::CMap::Apache::CorrespondenceMenu - comparative maps

=head1 SYNOPSIS

In httpd.conf:

  <Location /cmap/viewer>
      SetHandler  perl-script
      PerlHandler Bio::GMOD::CMap::Apache::CorrespondenceMenu->super
  </Location>

=head1 DESCRIPTION

This module is a mod_perl handler for displaying the menu for selecting
comparative maps.  select and display comparative maps.  It uses some
rudamentary AJAX to be loaded separately on the cmap_viewer page.  It inherits
from Bio::GMOD::CMap::Apache where all the error handling occurs.

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

