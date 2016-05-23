package Bio::GMOD::CMap::Apache;

# vim: set ft=perl:

# $Id: Apache.pm,v 1.43 2008/06/02 13:05:50 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Apache - generic handler for cmap object viewers

=head1 SYNOPSIS

In your new derive "FooViewer.pm":

  package Bio::GMOD::CMap::Apache::FooViewer;
  use Bio::GMOD::CMap::Apache;
  use base 'Bio::GMOD::CMap::Apache';

  sub handler {
      my ( $self, $apr ) = @_;
      $apr->content_type('text/html');
      $apr->send_http_header;
      $apr->print('Yo');
      return OK; 
  }

  1;

In httpd.conf:

  <Location /foo>
      SetHandler  perl-script
      PerlHandler Bio::GMOD::CMap::Apache::FooViewer->super
  </Location>

=head1 DESCRIPTION

The base class for all other Apache "viewer" handlers.  Basically,
this wraps up the error handling and takes care of caching the
Template Toolkit and (optionally) the "page" objects.  Derived classes
can call "$self->template" for the template and just "die" at will as
this class will catch errors and display them correctly.

=head1 METHODS

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.43 $)[-1];

use CGI;
use Apache::Htpasswd;
use Data::Dumper;
use Digest::MD5 'md5';
use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Apache::AdminViewer;
use Bio::GMOD::CMap::Apache::CorrespondenceMenu;
use Bio::GMOD::CMap::Apache::CorrespondenceViewer;
use Bio::GMOD::CMap::Apache::DataDownloader;
use Bio::GMOD::CMap::Apache::EvidenceTypeViewer;
use Bio::GMOD::CMap::Apache::FeatureViewer;
use Bio::GMOD::CMap::Apache::FeatureAliasViewer;
use Bio::GMOD::CMap::Apache::FeatureSearch;
use Bio::GMOD::CMap::Apache::FeatureTypeViewer;
use Bio::GMOD::CMap::Apache::HelpViewer;
use Bio::GMOD::CMap::Apache::Index;
use Bio::GMOD::CMap::Apache::Login;
use Bio::GMOD::CMap::Apache::MapSetViewer;
use Bio::GMOD::CMap::Apache::MapTypeViewer;
use Bio::GMOD::CMap::Apache::MapViewer;
use Bio::GMOD::CMap::Apache::MapSearch;
use Bio::GMOD::CMap::Apache::SavedLinkViewer;
use Bio::GMOD::CMap::Apache::SpiderViewer;
use Bio::GMOD::CMap::Apache::LinkViewer;
use Bio::GMOD::CMap::Apache::MatrixViewer;
use Bio::GMOD::CMap::Apache::SpeciesViewer;
use Bio::GMOD::CMap::Apache::ViewFeatureOnMap;
use Bio::GMOD::CMap::Apache::Remote;
use Bio::GMOD::CMap::Apache::CMap3D;

use base 'Bio::GMOD::CMap';

#
# The template for formatting user error messages.
#
use constant ERROR_TEMPLATE => 'error.tmpl';

use constant DISPATCH => {
    admin               => __PACKAGE__ . '::AdminViewer',
    correspondence      => __PACKAGE__ . '::CorrespondenceViewer',
    corr_menu           => __PACKAGE__ . '::CorrespondenceMenu',
    evidence_type_info  => __PACKAGE__ . '::EvidenceTypeViewer',
    feature             => __PACKAGE__ . '::FeatureViewer',
    feature_alias       => __PACKAGE__ . '::FeatureAliasViewer',
    feature_search      => __PACKAGE__ . '::FeatureSearch',
    feature_type_info   => __PACKAGE__ . '::FeatureTypeViewer',
    download_data       => __PACKAGE__ . '::DataDownloader',
    help                => __PACKAGE__ . '::HelpViewer',
    index               => __PACKAGE__ . '::Index',
    login               => __PACKAGE__ . '::Login',
    map_details         => __PACKAGE__ . '::MapViewer',
    map_set_info        => __PACKAGE__ . '::MapSetViewer',
    map_type_info       => __PACKAGE__ . '::MapTypeViewer',
    matrix              => __PACKAGE__ . '::MatrixViewer',
    saved_link          => __PACKAGE__ . '::SavedLinkViewer', # legacy
    saved_links         => __PACKAGE__ . '::SavedLinkViewer',
    species_info        => __PACKAGE__ . '::SpeciesViewer',
    view_feature_on_map => __PACKAGE__ . '::ViewFeatureOnMap',
    remote              => __PACKAGE__ . '::Remote',
    cmap3d              => __PACKAGE__ . '::CMap3D',
    viewer              => __PACKAGE__ . '::MapViewer',
    map_search          => __PACKAGE__ . '::MapSearch',
    spider              => __PACKAGE__ . '::SpiderViewer',
    link_viewer         => __PACKAGE__ . '::LinkViewer',
};

use constant FIELD_SEP  => '=';
use constant RECORD_SEP => ';';

# ----------------------------------------------------
sub init {

=pod

=head2 init

Initializes the object.

=cut

    my ( $self, $config ) = @_;
    $self->params( $config, qw[ apr config_dir ] );
    $self->config();
    if ( my $apr = $self->apr ) {
        $self->data_source( $apr->param('data_source') );
    }
    return $self;
}

# ----------------------------------------------------
sub handler {

=pod

=head2 handler

This is the generic entry point for all Apache handlers.  Here we make sure
that we have our globally cached objects, then we pass off the actual work of
the handler to the derived class's "handler" method.

=cut

    my %args      = @_;
    my $apr       = CGI->new;
    my $path_info = $apr->path_info || '';
    if ($path_info) {
        $path_info =~ s{^/(cmap/)?}{};    # kill superfluous stuff
    }

    $path_info = DEFAULT->{'path_info'} unless exists DISPATCH->{$path_info};
    my $class = DISPATCH->{$path_info};
    my $module = $class->new( apr => $apr, %args );
    my $status;

    eval {
        $module->read_cookie;
        $module->write_cookie;

        unless ( $path_info =~ /^(login|admin)$/ ) {
            unless ( $module->check_datasource_credentials ) {
                $class  = DISPATCH->{'login'};
                $module = $class->new(
                    apr          => $apr,
                    redirect_url => $apr->url( -path => 1, -query => 1 ),
                    %args,
                );
            }
        }

        $status = $module->handler($apr);
    };

    if ( my $e = $@ || $module->error ) {
        my $html;
        eval {
            if ( my $t = $module->template )
            {
                $t->process(
                    $module->error_template,
                    {   error               => $e,
                        apr                 => $module->apr,
                        page                => $module->page,
                        stylesheet          => $module->stylesheet,
                        data_sources        => $module->data_sources,
                        web_image_cache_dir => $module->web_image_cache_dir(),
                        web_cmap_htdocs_dir => $module->web_cmap_htdocs_dir(),
                    },
                    \$html
                    )
                    or $html = $e . '<br>' . $t->error;
            }
            else {
                $html = $e;
            }
        };

        print $apr->header('text/html'), $html || $e;
    }

    return 1;
}

# ----------------------------------------------------
sub apr {

=pod

=head2 apr

Returns the Apache::Request object.

=cut

    my $self = shift;
    return $self->{'apr'};
}

# ----------------------------------------------------
sub check_datasource_credentials {

=pod

=head2 check_datasource_credentials

See if we need to prompt for user/pass for the given datasource.

=cut

    my $self    = shift;
    my $apr     = $self->apr;
    my $ds      = $self->data_source( $apr->param('data_source') ) or return;
    my $config  = $self->config or return;
    my $db_conf = $config->get_config('database');

    if ( my $passwd_file = $db_conf->{'passwd_file'} ) {
        if ( my $cookie = $apr->cookie('CMAP_LOGIN') ) {
            my $sekrit = 'r1ce1sn2c3';
            my ( $user, $ds2, $auth ) = split( /:/, $cookie );
            return $ds                          eq $ds2
                && md5( $user . $ds . $sekrit ) eq $auth;
        }
        else {
            return 0;
        }
    }
    else {
        return 1;
    }
}

# ----------------------------------------------------
sub cookie {

=pod

=head2 cookie

Get/set the cookie.

=cut

    my $self = shift;

    $self->{'cookie'} = shift if @_;

    return $self->{'cookie'};
}

# ----------------------------------------------------
sub error_template {

=pod

=head2 error_template

Returns the correct template to use in formatting errors.

=cut

    my $self = shift;
    return ERROR_TEMPLATE;
}

# ----------------------------------------------------
sub page {

=pod

=head2 page

Returns the "page" object.  In the original Gramene project
(http://www.gramene.org/), there is a Perl object that handles
inserting appropriate page headers and footers.  This object can be
passed into the templates to print out these elements as necessary.

If you wish to have something like this, I'm sure you can glean the
basic ideas from Lincoln's "GramenePage.pm" module.  Then define the
"page_object" in your cmap.conf.  Otherwise, just don't worry about 
it, and this method will never return anything.

=cut

    my $self = shift;

    unless ( defined $self->{'page'} ) {
        my $page_object = $self->config_data('page_object');
        if ( $page_object && $ENV{'MOD_PERL'} ) {
            eval "require Apache";
            unless ($@) {
                my $r = Apache->request;
                if ( !defined $INC{$page_object} ) {
                    ( my $pm = $page_object ) =~ s/::/\//g;
                    eval { require "$pm.pm"; };
                    die $@ if $@;
                }
                $self->{'page'} = $page_object->new($r)
                    or return $self->error(
                    qq[Error creating page object ("$page_object")]);
            }
        }
        else {
            $self->{'page'} = '';    # define it to nothing
        }
    }

    return $self->{'page'};
}

# ----------------------------------------------------
sub stylesheet {

=pod

=head2 stylesheet

Return any defined stylesheet.

=cut

    my $self = shift;

    unless ( defined $self->{'stylesheet'} ) {
        $self->{'stylesheet'} = $self->config_data('stylesheet') || '';
    }

    return $self->{'stylesheet'};
}

# ----------------------------------------------------
sub read_cookie {

=pod

=head2 read_cookie

Get the current preferences and any existing cookie.  Always take
current settings over cookie settings.  

=cut

    my $self                  = shift;
    my $apr                   = $self->apr;
    my @preference_fields     = @{ +PREFERENCE_FIELDS };
    my @req_preference_fields = @{ +REQUIRED_PREFERENCE_FIELDS };
    my $cookie_name = $self->config_data('user_pref_cookie_name') || '';
    my %preferences = ();

    #
    # Fetch and read the cookie.
    #
    my $cookie_string = $apr->cookie($cookie_name);
    my @cookie_fields = split RECORD_SEP, $cookie_string;

    foreach (@cookie_fields) {
        my ( $name, $value ) = split FIELD_SEP;
        $preferences{$name} = $value if $value;
    }

    #
    # This updates the preferences with whatever is in the latest request from
    # the user.  If the preference isn't defined in this request, then we'll
    # leave whatever's there.  If nothing is defined, then we'll set it with
    # the default value.
    #
    # If this references a session or a saved link, then that will have the
    # information in it, so we don't want to use a cookie.
    unless ( $apr->param('session_id') or $apr->param('saved_link_id') ) {
        for my $pref (@preference_fields) {
            my $value =
                  defined $apr->param($pref)  ? $apr->param($pref)
                : defined $preferences{$pref} ? $preferences{$pref}
                : $self->config_data($pref) || '';

            $apr->param( $pref, $value );
        }
    }
    for my $req_pref (@req_preference_fields) {
        my $value =
              defined $apr->param($req_pref)  ? $apr->param($req_pref)
            : defined $preferences{$req_pref} ? $preferences{$req_pref}
            : $self->config_data($req_pref) || '';

        $apr->param( $req_pref, $value );
    }

    return 1;
}

# ----------------------------------------------------
sub write_cookie {

=pod

=head2 write_cookie

End by always setting cookie with current settings.

=cut

    my $self                  = shift;
    my $apr                   = $self->apr;
    my @preference_fields     = @{ +PREFERENCE_FIELDS };
    my @req_preference_fields = @{ +REQUIRED_PREFERENCE_FIELDS };
    my $cookie_name = $self->config_data('user_pref_cookie_name') || '';
    my %preferences = ();

    #
    # This updates the preferences with whatever is in the latest
    # request from the user.
    #
    for my $pref ( @preference_fields, @req_preference_fields ) {
        next unless ( defined $apr->param($pref) );
        $preferences{$pref} = $apr->param($pref);
    }

    #
    # Set a new cookie with the latest preferences.
    #
    my $cookie_domain = $self->config_data('cookie_domain') || '';
    my $cookie_value = join( RECORD_SEP,
        map { join( FIELD_SEP, $_, $preferences{$_} ) } @preference_fields,
        @req_preference_fields );

    $self->cookie(
        $apr->cookie(
            -name    => $cookie_name,
            -value   => $cookie_value,
            -expires => '+1y',
            -domain  => $cookie_domain,
            -path    => '/'
        )
    );

    return 1;
}

1;

# ----------------------------------------------------
# If the fool would persist in his folly
# He would become wise.
# William Blake
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.
Ken Y. Clark E<lt>kclark@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-7 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

