package Bio::Das::AGPServer::SQLStorage::MySQL::DB;

=head1 AUTHOR

Tony Cox <avc@sanger.ac.uk>.

Copyright (c) 2003 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use Bio::Das::AGPServer::Parser;
use vars qw($AUTOLOAD $DEBUG @ISA);
$Bio::Das::AGPServer::SQLStorage::MySQL::DB::DEBUG = 1;

@ISA = ("Bio::Das::AGPServer::SQLStorage");

                
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
     my ($self,$config) = @_;
     $self->config($config);
    
    my $tablename   = $config->tablename();
    
    #dbi:DriverName:database=database_name;host=hostname;port=port

    my $data_source = "dbi:mysql:database=" . $config->dbname() . ";host=" . $config->dbhost() . ";port=" . $config->dbport();
    warn "Connecting to $data_source\n";
    my $dbh = DBI->connect($data_source, $config->username(), $config->password()) or die $DBI::errstr;
    $self->db_handle($dbh);
    
    $self->drop_agp_table();
    $self->create_agp_table(); # done by base class

    if ($config->agpdir()){
        my $dir = $config->agpdir();
        opendir(DIR, "$dir") or die "Cannot open AGP directory: $!\n";
        my @agpfiles = grep /.*\.agp$/i, readdir DIR;
        foreach my $file (@agpfiles){
            print STDERR "Loading AGP file: $file\n" if ($Bio::Das::AGPServer::SQLStorage::MySQL::DB::DEBUG == 1);
            my $parser = Bio::Das::AGPServer::Parser->new("$dir/$file");
            $self->load_agp($parser);
        }
    } elsif ($config->agpfile()) {        
        print STDERR "Loading AGP file: ", $config->agpfile(), "\n" if ($Bio::Das::AGPServer::SQLStorage::MySQL::DB::DEBUG == 1);
        my $parser = Bio::Das::AGPServer::Parser->new($config->agpfile());
        $self->load_agp($parser);
    } else {
        die "Cannot parse AGP data!\n";
    }
    
}

#################################################################
sub drop_agp_table {
     my ($self) = @_;

    my $dbh         = $self->db_handle();
    my $tablename   = $self->config()->tablename();
       
    my $query = qq(DROP TABLE IF EXISTS $tablename);

    my $sth = $dbh->prepare($query);
    $sth->execute() or die $dbh->errstr();
    $sth->finish();
    print STDERR "Removed temporary table $tablename\n" if ($Bio::Das::AGPServer::SQLStorage::DEBUG == 1);
    
}

########################################################################################
sub entry_points {

    my ($self) = @_;
    
    my $dbh     = $self->db_handle();
    my $host    = $self->config->hostname();
    my $port    = $self->config->port();
    my $dsn     = $self->config->dsn();
    my $table   = $self->config->tablename();

    my $content .= $self->open_dasep();

    my $query = qq(SELECT chr, MAX(chr_end) from $table GROUP by chr);
    my $sth = $dbh->prepare($query);
    $sth->execute();
    while (my ($chr,$length) = $sth->fetchrow_array()){
        $content .= qq(    <SEGMENT id="$chr" size="$length" subparts="yes" />\n);
    }

    $content .= $self->close_dasep();

return ($content);
}

#################################################################
sub feature_by_id {
    my ($self,$feature_list) = @_;

    my $dbh     = $self->db_handle();
    my $table   = $self->config->tablename();
    my $dsn     = $self->config->dsn();
    my $host    = $self->config->hostname();
    my $port    = $self->config->port();

    my $response = "";

    foreach my $feature (@{$feature_list}){
    
        my $query = qq(SELECT type,chr,embl_id,embl_start,embl_end,chr_start,chr_end,embl_ori from $table where embl_id LIKE '%$feature%');
        
        my $sth = $dbh->prepare($query);
        $sth->execute();

        while( my ($type,$chr,$eid,$es,$ee,$cs,$ce,$eo) = $sth->fetchrow_array()){
            
            my $status = "clone_status:$type:" . $Bio::Das::AGPServer::SQLStorage::CLONE_STATUS->{$type};
        
            $response .=  qq(    <SEGMENT id="$chr" version="1" start="$cs" stop="$ce">\n);
            $response .=  qq(      <FEATURE id="components/$eid" label="components/$eid">\n);
            $response .=  qq(        <TYPE id="static_golden_path" reference="yes" subparts="no">static_golden_path</TYPE>\n);
            $response .=  qq(        <METHOD id="agp-clone">agp-clone</METHOD>\n);
            $response .=  qq(        <START>$cs</START>\n);
            $response .=  qq(        <END>$ce</END>\n);
            $response .=  qq(        <SCORE>-</SCORE>\n);
            $response .=  qq(        <ORIENTATION>$eo</ORIENTATION>\n);
            $response .=  qq(        <PHASE>-</PHASE>\n);
            $response .=  qq(        <NOTE>$status</NOTE>\n);
            $response .=  qq(        <TARGET id="$eid" start="$es" stop="$ee" />\n);
            $response .=  qq(      </FEATURE>\n);
            $response .=  qq(    </SEGMENT>\n);
        }
    }
    
    return($response);
}

#################################################################
sub features {
    my ($self,$segment_list) = @_;
    
    my $dbh     = $self->db_handle();
    my $table   = $self->config->tablename();
    my $dsn     = $self->config->dsn();
    my $host    = $self->config->hostname();
    my $port    = $self->config->port();

    my $response = "";

    my $query = qq(SELECT type,embl_id,embl_start,embl_end,chr_start,chr_end,embl_ori from $table where chr = ? AND chr_start < ? AND chr_end > ? ORDER by chr_start);
    my $sth = $dbh->prepare($query);

    foreach my $segment (@{$segment_list}){
    
        my ($chr,$rest) = split(":",$segment);
        my ($start,$end) = split(",",$rest);
        $response .= qq(    <SEGMENT id="$chr" version="1" start="$start" stop="$end">\n);
        $sth->execute($chr,$end,$start);

        while (my ($type,$id,$es,$ee,$cs,$ce,$eo) = $sth->fetchrow_array()){

            my $status = "clone_status:$type:" . $Bio::Das::AGPServer::SQLStorage::CLONE_STATUS->{$type};
        
            $response .=  qq(      <FEATURE id="components/$id" label="components/$id">\n);
            $response .=  qq(        <TYPE id="static_golden_path" reference="yes" subparts="no">static_golden_path</TYPE>\n);
            $response .=  qq(        <METHOD id="agp-clone">agp-clone</METHOD>\n);
            $response .=  qq(        <START>$cs</START>\n);
            $response .=  qq(        <END>$ce</END>\n);
            $response .=  qq(        <SCORE>-</SCORE>\n);
            $response .=  qq(        <ORIENTATION>$eo</ORIENTATION>\n);
            $response .=  qq(        <PHASE>-</PHASE>\n);
            $response .=  qq(        <NOTE>$status</NOTE>\n);
            $response .=  qq(        <TARGET id="$id" start="$es" stop="$ee" />\n);
            $response .=  qq(      </FEATURE>\n);

        }
        $response .= "    </SEGMENT>\n";

    }
        
    $sth->finish();
    return($response);

}

1;
