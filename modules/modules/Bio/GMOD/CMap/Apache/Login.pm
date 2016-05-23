package Bio::GMOD::CMap::Apache::Login;

# vim: set ft=perl:

# $Id: Login.pm,v 1.5 2007/10/19 14:36:34 mwz444 Exp $

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.5 $)[-1];

use strict;
use Digest::MD5 'md5';
use Bio::GMOD::CMap::Apache;
use base 'Bio::GMOD::CMap::Apache';

use constant TEMPLATE => 'login.tmpl';

sub init {
    my ( $self, $config ) = @_;
    $self->params( $config, qw[ apr redirect_url ] );
    return $self;
}

sub handler {
    my $self         = shift;
    my $apr          = shift || $self->apr;
    my $user         = $apr->param('user_name') || '';
    my $passwd       = $apr->param('password') || '';
    my $redirect_url = $apr->param('redirect_url')
        || $self->{'redirect_url'}
        || 'viewer';

    my ( $ok, $err ) = ( 0, '' );
    my $cookie;
    if ($user) {
        my $apr = $self->apr;
        my $cgi = CGI->new($redirect_url);
        my $ds  = $self->data_source( $cgi->param('data_source') ) or return;
        my $config  = $self->config or return;
        my $db_conf = $config->get_config('database');
        my $sekrit  = 'r1ce1sn2c3';

        if ( my $passwd_file = $db_conf->{'passwd_file'} ) {
            if ( -e $passwd_file ) {
                my $htpasswd = Apache::Htpasswd->new($passwd_file);
                if ( $htpasswd->htCheckPassword( $user, $passwd ) ) {
                    $ok     = 1;
                    $cookie = $apr->cookie(
                        -name  => 'CMAP_LOGIN',
                        -value => join( ':',
                            $user, $ds, md5( $user . $ds . $sekrit ) ),
                        -expires => '+24h',
                        -domain  => $self->config_data('cookie_domain') || '',
                        -path    => '/'
                    );
                }
                else {
                    $err = 'Invalid user name or password';
                }
            }
            else {
                $err = "Password file '$passwd_file' does not exist";
            }
        }
        else {
            $ok = 1;
        }
    }

    if ($ok) {
        print $apr->redirect( -uri => $redirect_url, -cookie => $cookie );
    }
    else {
        my $t = $self->template or return;
        my $html;
        $t->process(
            TEMPLATE,
            {   err_msg             => $err,
                redirect_url        => $redirect_url,
                apr                 => $self->apr,
                page                => $self->page,
                stylesheet          => $self->stylesheet,
                web_image_cache_dir => $self->web_image_cache_dir(),
                web_cmap_htdocs_dir => $self->web_cmap_htdocs_dir(),
            },
            \$html
        ) or return $self->error( $t->error );

        print $apr->header(
            -type   => 'text/html',
            -cookie => $self->cookie,
        ), $html;
    }

    return 1;
}

1;

# ----------------------------------------------------
# It is only those who have neither fired a shot
# nor heard the shrieks and groans of the wounded
# who cry aloud for blood, more vengeance,
# more desolation.  War is hell.
# William Tecumseh Sherman
# ----------------------------------------------------

=head1 NAME

Bio::GMOD::CMap::Apache::Login - show login form

=head1 DESCRIPTION

Shows a login form to authenticate datasource access.

=head1 SEE ALSO

Bio::GMOD::CMap::Apache.

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.
Ken Y. Clark E<lt>kclark@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2005-6 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut
