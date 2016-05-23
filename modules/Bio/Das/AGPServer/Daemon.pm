package Bio::Das::AGPServer::Daemon;

=head1 AUTHOR

Tony Cox <avc@sanger.ac.uk>.

Copyright (c) 2003 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use HTTP::Daemon;
use HTTP::Status;
use HTTP::Response;
use Data::Dumper;
use Compress::Zlib;
use CGI;

use vars qw($AUTOLOAD $DEBUG @ISA);
$Bio::Das::AGPServer::SQLStorage::CSV::DB::DEBUG = 1;

#@ISA = ("HTTP::Daemon");


sub new {
  my ($class, $config) = @_;
  my $o = bless {}, $class;
  $o->init($config);
  return $o;
}

#################################################################
## Init the options object
#################################################################
sub init {
    my ($self,$db) = @_;
    $self->_das_storage($db);

}

#################################################################
sub handle {
    my ($self) = @_;

    my $storage = $self->_das_storage();
    my $config  = $self->_das_storage->config();
    my $host    = $config->hostname();
    my $dsn     = $config->dsn();
    my $port    = $config->port();
        
    my $d = new HTTP::Daemon (
                      LocalAddr => $host,
                      LocalPort => $port,
                    ) or die "Cannot start daemon: $!\n";

    $self->log("Please contact me at this URL: " . $d->url . "das/dsn/{command}");
    
    $SIG{'CHLD'} = 'IGNORE'; # Reap our forked processes immediately

    while (my $c = $d->accept) {
        local $^W = 0;

        ################## FORK #######################
        my $pid;
        if ($pid = fork){
            # I am the parent
            next;
        } elsif (defined $pid) {
           # I am the child 
           $self->log("Child process $$ born...");
        } else {
            die "Nasty forking error: $!\n";
        }
        ###############################################

        while (my $req = $c->get_request()) {
            
            my $url = $req->uri();
            my $q;
            
            ## process the parameters
            if ($req->method() eq 'GET'){
                $q = new CGI($url->query());
            } elsif ($req->method() eq 'POST'){
                $q = new CGI($req->{'_content'});
            }
            
            $self->use_gzip(-1); # the default

            my $path = $url->path();
            $self->log("Request: $path");
            $path =~ /das\/(.*?)\/.*/;
            my $dsn = $1;

            $req->scan(
                sub {
                    my ($h,$v) = @_;
                    $self->log("  header: $h --> $v");
                }
            ) if ($Bio::Das::AGPServer::SQLStorage::CSV::DB::DEBUG == 1);


            if ($req->header('Accept-Encoding') && ($req->header('Accept-Encoding')=~ /gzip/) ){
                $self->use_gzip(1);
                $self->log("  compressing content [client understands gzip content]");
            }
            
            if ($req->method() eq 'GET' || $req->method() eq 'POST') {

                my $res = HTTP::Response->new();
                my $content = "";
                
                ## unrecognised DSN ##
                if  ($config->dsn() ne $dsn){   
                    $c->send_error("401","Bad data source");
                    $c->close;
                    $self->log("Child process $$ exit [Bad data source]");
                    exit; # VERY IMPORTANT - reap the child process!
                 }   

                ## unimplemented commands ##
                foreach (qw(dna types component supercomponent sequence)) {
                    if ($path eq "/das/$dsn/$_"){
                        $c->send_error("501","Unimplemented feature");
                        $c->close;
                        $self->log("Child process $$ exit [Unimplemented feature]");
                        exit; # VERY IMPORTANT - reap the child process!
                    }               
                }
                
                if ($path eq "/das/$dsn/features"){
                    $content .= $self->do_feature_request($res,$q);
                } elsif  ($path eq "/das/$dsn/dsn"){   
                    $content .= $self->do_dsn_request($res);
                } elsif  ($path eq "/das/$dsn/entry_points"){   
                     $content .= $self->do_entry_points_request($res);
                } elsif  ($path eq "/das/$dsn/stylesheet"){   
                     $content .= $self->do_stylesheet_request($res);
                } else{
                    ## unrecognised commands ##
                    $c->send_error("400","Bad command");
                    $c->close;
                    $self->log("Child process $$ exit [Bad command]");
                    exit; # VERY IMPORTANT - reap the child process!
                }
                
                if( ($self->use_gzip() == 1) && (length($content) > 10000) ){
                    $content = $self->gzip_content($content);
                    $res->content_encoding('gzip') if $content;
                    $self->use_gzip(0)
                }
                
                $res->content_length(length($content));
                $res->content($content);
                $c->send_response($res);

            } else {
                $c->send_error(RC_FORBIDDEN);
            }
            
            $c->close;
            $self->log("Child process $$ normal exit.");
            exit; # VERY IMPORTANT - reap the child process!
        }
        
        $c->close;
        undef($c);
    }
    
}

#################################################################
sub do_feature_request {
    my ($self,$res,$q) = @_;

    my $storage = $self->_das_storage();
    my $content = "";
    
    $content .= $storage->open_dasgff();

    ## segment requests
    my @segs = $q->param('segment');
    foreach my $segment (@segs){
        $self->log("  segment ===> $segment");
    }
    $content .= $storage->features(\@segs);

    ## features
    my @fids = $q->param('feature_id');
    foreach my $f (@fids){
        $self->log("  feature ===> $f");
    }
    $content .= $storage->feature_by_id(\@fids);


    $content .= $storage->close_dasgff();
    $res = $self->ok_header($res);
 
    return($content);          
}

#################################################################
sub do_dsn_request {
    my ($self,$res) = @_;

    my $storage = $self->_das_storage();
    my $content = $storage->dsn();
    $res = $self->ok_header($res);
                    
    return($content);          
}

#################################################################
sub do_entry_points_request {
    my ($self,$res) = @_;

    my $storage = $self->_das_storage();
    my $content = $storage->entry_points();
    $res = $self->ok_header($res);
                    
    return($content);          
}

#################################################################
sub do_stylesheet_request {
    my ($self,$res) = @_;

    my $storage = $self->_das_storage();
    my $content = $storage->stylesheet();
    $res = $self->ok_header($res);
                    
    return($content);          
}

#################################################################
sub ok_header {
    my ($self,$response) = @_;

    my $config  = $self->_das_storage->config();
    
    $response->header('Content-Type'        => 'text/plain');
    $response->header('X_DAS_Version'       => $config->das_version());
    $response->header('X_DAS_Status'        => '200 OK');
    $response->header('X_DAS_Capabilities'  => $config->das_capabilities());
    
    return($response);
}

#################################################################
sub error_header {
    my ($self,$response,$code) = @_;

    my $config  = $self->_das_storage->config();
    
    $response->header('Content-Type'        => 'text/plain');
    $response->header('X_DAS_Version'       => $config->das_version());
    $response->header('X_DAS_Status'        => $code);
    $response->header('X_DAS_Capabilities'  => $config->das_capabilities());
    
    return($response);
}

#################################################################
sub gzip_content {
    my ($self,$content) = @_;
    if($content && $self->use_gzip()){
        my $d = Compress::Zlib::memGzip($content);
        if ($d) {
            return($d);
        } else {
            warn ("Content compression failed: $!\n");
            return(undef);
        }
    } else {
        warn ("Inconsistent request for gzip content\n");
    }
    
}
#################################################################
sub use_gzip {
    my ($self,$var) = @_;
    if($var){
        $self->{'use_gzip'} = $var;
        #warn ("setting use_gzip to: $var\n");
        return($self->{'use_gzip'});
    } else {
        return($self->{'use_gzip'});
    }
}
#################################################################
sub _das_storage {
    my ($self,$db) = @_;
    if($db){
        $self->{'_das_storage'} = $db;
    } else {
        return($self->{'_das_storage'});
    }
}
#################################################################
sub log {
    my ($self,@messages) = @_;
    foreach my $m (@messages){
        print STDERR "$m\n";
    }

}
#################################################################










