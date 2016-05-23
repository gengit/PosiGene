package Bio::GMOD::CMap::Apache::FeatureViewer;

# vim: set ft=perl:

# $Id: FeatureViewer.pm,v 1.17 2007/09/28 20:17:08 mwz444 Exp $

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.17 $)[-1];

use Bio::GMOD::CMap::Apache;
use Bio::GMOD::CMap::Data;
use base 'Bio::GMOD::CMap::Apache';
use Data::Dumper;

use constant TEMPLATE => 'feature_detail.tmpl';

sub handler {

    #
    # Make a jazz noise here...
    #
    my ( $self, $apr ) = @_;
    my $feature_acc = $apr->param('feature_acc') || $apr->param('feature_aid')
      or die 'No accession id';

    $self->data_source( $apr->param('data_source') ) or return $self->error();
    my $data = $self->data_module;
    my $feature = $data->feature_detail_data( feature_acc => $feature_acc )
      or return $self->error( $data->error );

    $self->object_plugin( 'feature', $feature );

    #
    # Make the subs in the URL.
    #
    my $t = $self->template or return;
    my $html;
    $t->process(
        TEMPLATE,
        {   apr                 => $self->apr,
            feature             => $feature,
            page                => $self->page,
            stylesheet          => $self->stylesheet,
            web_image_cache_dir => $self->web_image_cache_dir(),
            web_cmap_htdocs_dir => $self->web_cmap_htdocs_dir(),
        },
        \$html
        )
        or return $self->error( $t->error );

    print $apr->header( -type => 'text/html', -cookie => $self->cookie ), $html;
    return 1;
}

1;

# ----------------------------------------------------
# Streets that follow like a tedious argument
# Of insidious intent
# To lead you to an overwhelming question...
# T. S. Eliot
# ----------------------------------------------------

=head1 NAME

Bio::GMOD::CMap::Apache::FeatureViewer - view feature details

=head1 SYNOPSIS

In httpd.conf:

  <Location /cmap/feature>
      SetHandler  perl-script
      PerlHandler Bio::GMOD::CMap::Apache::FeatureViewer->super
  </Location>

=head1 DESCRIPTION

This module is a mod_perl handler for displaying the details of a
feature.  It inherits from Bio::GMOD::CMap::Apache where all the error
handling occurs (which is why I can just "die" here).

=head1 SEE ALSO

L<perl>, Bio::GMOD::CMap::Apache.

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

