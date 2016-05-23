package Bio::GMOD::CMap::Apache::SpeciesViewer;

# vim: set ft=perl:

# $Id: SpeciesViewer.pm,v 1.10 2007/09/28 20:17:09 mwz444 Exp $

use strict;
use vars qw( $VERSION $PAGE_SIZE $MAX_PAGES $INTRO );
$VERSION = (qw$Revision: 1.10 $)[-1];

use Data::Pageset;
use Bio::GMOD::CMap::Apache;
use base 'Bio::GMOD::CMap::Apache';

use constant TEMPLATE => 'species_info.tmpl';

sub handler {

    #
    # Make a jazz noise here...
    #
    my ( $self, $apr ) = @_;
    $self->data_source( $apr->param('data_source') ) or return;

    my $page_no = $apr->param('page_no') || 1;
    my @species_accs =
      split( /,/, $apr->param('species_acc') || $apr->param('species_aid') );
    my $data_module = $self->data_module;
    my $data        =
      $data_module->species_viewer_data( species_accs => \@species_accs, )
      or return $self->error( $data_module->error );
    my $species = $data->{'species'};

    $PAGE_SIZE ||= $self->config_data('max_child_elements') || 0;
    $MAX_PAGES ||= $self->config_data('max_search_pages')   || 1;

    #
    # Slice the results up into pages suitable for web viewing.
    #
    my $pager = Data::Pageset->new(
        {
            total_entries    => scalar @$species,
            entries_per_page => $PAGE_SIZE,
            current_page     => $page_no,
            pages_per_set    => $MAX_PAGES,
        }
    );
    $species = [ $pager->splice($species) ] if @$species;

    for my $s (@$species) {
        $self->object_plugin( 'species_info', $s );
    }

    my $t = $self->template;
    for my $s (@$species) {
        for my $xref ( @{ $s->{'xrefs'} } ) {
            next
              if $xref->{'object_id'}
              && $xref->{'object_id'} != $s->{'species_id'};
            my $url;
            $t->process( \$xref->{'xref_url'}, { object => $s }, \$url );
            $xref->{'xref_url'} = $url;
        }
    }

    $INTRO ||= $self->config_data('species_info_intro') || '';

    my $html;
    $t->process(
        TEMPLATE,
        {   apr                 => $apr,
            page                => $self->page,
            stylesheet          => $self->stylesheet,
            data_sources        => $self->data_sources,
            species             => $species,
            all_species         => $data->{'all_species'},
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

Copyright (c) 2002-6 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

