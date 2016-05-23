package Bio::Das::AGPServer::Config;

=head1 AUTHOR

Tony Cox <avc@sanger.ac.uk>.

Copyright (c) 2003 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use vars qw($AUTOLOAD $DEBUG %OPT);
use Sys::Hostname;
use Getopt::Long;

$Bio::Das::AGPServer::Config::DEBUG = 1;
$Bio::Das::AGPServer::Config::VERSION = "1.0";

sub new {
  my ($class, @args) = @_;
  my $o = bless {}, $class;
  $o->init(@args);
  return $o;
}

#################################################################
## Init the options object
#################################################################
sub init {
    my $self = shift;
    my %args = @_;

    foreach my $k (keys %args){
        print STDERR "Setting $k = $args{$k}\n" if ($Bio::Das::AGPServer::Config::DEBUG);
        $self->$k($args{$k});
    }
    my ($dsn,$dsnversion,$agpfile,$agpdir,$tmpdir,$backend,$port,$password,$username,$dbhost,$dbname,$dbport,$usage);
     
    my $result = GetOptions(
                            'dsn:s'         =>  \$dsn,      # req
                            'dsnversion:i'  =>  \$dsnversion,      # req
                            'agpfile:s'     =>  \$agpfile,  # req
                            'agpdir:s'      =>  \$agpdir,
                            'tmpdir:s'      =>  \$tmpdir,
                            'port:i'        =>  \$port,
                            'backend:s'     =>  \$backend,
                            'dbhost:s'      =>  \$dbhost,
                            'dbname:s'      =>  \$dbname,
                            'username:s'    =>  \$username,
                            'password:s'    =>  \$password,
                            'dbport:i'      =>  \$dbport,
                            'help|h|?'      =>  \$usage,
                             );

    if ($usage){
        $self->usage();
        exit;
    }

    die "Cannot parse command line options: $result\n" unless ($result); 
    
    $self->die("You must provide a data source name using the '--dsn' option") unless $dsn;
    
    $tmpdir         ||= '/tmp';
    $backend        ||= 'CSV';
    $port           ||= 9999;
    
    if(lc($backend) eq 'mysql'){
        $self->die("You must provide a mysql server name using the '--dbhost' option") unless $dbhost;
        $self->die("You must provide a username using the '--username' option") unless $username;
        $self->die("You must provide a password using the '--password' option") unless $password;
        $dbport ||= 3306;
    }
    
    unless ($agpfile || $agpdir){
        $self->die("You must provide an AGP filename or directory containing an AGP file\nusing the '--agpfile or '--agpdir' options");
    }
    
    my $tablename     = "tmp_agp_" . $dsn;

    if ((lc($backend) eq 'csv') && (-e "$tmpdir/$tablename")){
        $dbname        = $dsn .  "_AGP";
        print STDERR "Removing temporary file: $tmpdir/$tablename\n" if ($Bio::Das::AGPServer::Config::DEBUG);
        unlink("$tmpdir/$tablename");
    }
      
    $self->dsn($dsn);
    $self->dsnversion($dsnversion);
    $self->agpfile($agpfile);
    $self->agpdir($agpdir);
    $self->tmpdir($tmpdir);
    $self->backend($backend);
    $self->port($port);
    $self->tablename($tablename);

    $self->hostname(Sys::Hostname::hostname());

    $self->dbname($dbname);
    $self->dbhost($dbhost);
    $self->dbport($dbport);
    $self->username($username);
    $self->password($password);

                                
    #my $caps =  join '; ',qw(   error-segment/1.0 unknown-segment/1.0 unknown-feature/1.0
	#				            feature-by-id/1.0 group-by-id/1.0 component/1.0 supercomponent/1.0
    #                            dna/1.0 features/1.0 stylesheet/1.0 types/1.0
    #                            entry_points/1.0 dsn/1.0 sequence/1.0
    #                            );
    
    my $caps =  join '; ',qw( features/1.0 entry_points/1.0 dsn/1.0 feature-by-id/1.0 stylesheet/1.0 );
    $self->das_capabilities($caps);
    $self->das_version('DAS/1.50');
    
}

######################################################################
sub usage {
    my ($self) = @_;

    print <<END;
    
    AGP DAS Server v${Bio::Das::AGPServer::Config::VERSION}
    Copyright (2003) Tony Cox <avc\@sanger.ac.uk>, Sanger Institute.
    
    Establishes a minimal DAS reference server driven from an AGP file.
    Capable of serving assembly information, entry_points, DSN info, features
    across a segment and features by ID. All other DAS commands are not 
    yet supported.By default the server will use a simple CSV textfile for 
    storing the data. While this is adequate for small AGP files if better 
    performance is needed then use the Mysql backend.
    
    Usage:
    
    ./agpserver --dsn <dsn>                 Name for this DAS datasource
                --dsnversion <int>          DSN version number (default = 1)
                --agpdir <./dirname>        Directory holding AGP file(s)
                        or
                --agpfile <filename>        Single AGP file
                --port <number>             DAS server port (default = 9999)
                --tmpdir <dirname>          Temporary directory (default = /tmp)
                [ --backend mysql           Use a mysql backend                  
                    --dbhost <host>         Mysql server hostname
                    --dbname <name>         Mysql database name
                    --username <user>       Mysql username (needs write access)
                    --password <password>   Mysql password
                    --dbport <port>         Mysql server port (default = 3306)
                ]

    eg:
                
    ./agpserver --dsn test 
                --agpdir ./TEST 
                --port 3000 
                --backend mysql 
                --dbhost mysql.myserver.org 
                --dbport 3307 
                --dbname agptest                
                --username fred 
                --password pants 
END


}

######################################################################
sub die {
    my ($self,$error) = @_;
    die qq($error\n);
}
######################################################################
sub AUTOLOAD {
    my $self = shift;
    my $var = $AUTOLOAD;
    my $arg  = shift; 

    local $^W = 0;
    $var =~ s/.*:://;
    if(defined $arg){
        $self->{$var} = $arg;
    }
    return $self->{$var};
}
######################################################################


1;
