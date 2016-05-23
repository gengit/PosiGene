package Bio::Das::AGPServer::SQLStorage::CSV::DB;

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
$Bio::Das::AGPServer::SQLStorage::CSV::DB::DEBUG = 1;

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
    my $tmpdir      = $config->tmpdir();
    
    if (-e "$tmpdir/$tablename"){
        unlink("$tmpdir/$tablename");
        print STDERR "Removed $tmpdir/$tablename\n" if ($Bio::Das::AGPServer::SQLStorage::CSV::DB::DEBUG == 1);
    }
    
    my $dbh = DBI->connect("DBI:CSV:f_dir=$tmpdir") or die $DBI::errstr;
    $self->db_handle($dbh);
    
    $dbh->{'csv_tables'}->{$tablename} = { 'col_names' => [   "chr",
                                                        "chr_start",
                                                        "chr_end",
                                                        "ord","type",
                                                        "embl_id",
                                                        "embl_start",
                                                        "embl_end",
                                                        "embl_ori"
                                                     ]
                                   };

    $self->create_agp_table(); # done by base class

    if ($config->agpdir()){
        my $dir = $config->agpdir();
        opendir(DIR, "$dir") or die "Cannot open AGP directory: $!\n";
        my @agpfiles = grep /.*\.agp$/i, readdir DIR;
        foreach my $file (@agpfiles){
            print STDERR "Loading AGP data file: $file\n" if ($Bio::Das::AGPServer::SQLStorage::CSV::DB::DEBUG == 1);
            my $parser = Bio::Das::AGPServer::Parser->new("$dir/$file");
            $self->load_agp($parser);   # done by base class
        }
    } elsif ($config->agpfile()) {        
        print STDERR "Loading AGP data file: ", $config->agpfile(), "\n" if ($Bio::Das::AGPServer::SQLStorage::CSV::DB::DEBUG == 1);
        my $parser = Bio::Das::AGPServer::Parser->new($config->agpfile());
        $self->load_agp($parser);   # done by base class
    } else {
        die "Cannot parse AGP data!\n";
    }

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

    my $query = qq(SELECT DISTINCT chr from $table);
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my %CHR = ();
    while (my $row = $sth->fetchrow_hashref()){
        $CHR{$row->{'chr'}} = 0;
    }

    foreach my $key (keys %CHR){ 
        next if ($key =~ /CHR/); # skip first row of table (column names)
        my $query = qq(SELECT MAX(chr_end) from $table where chr = '$key');
        my $sth = $dbh->prepare($query);
        $sth->execute();
        while (my ($length) = $sth->fetchrow_array()){
            $content .= qq(    <SEGMENT id="$key" size="$length" subparts="yes" />\n);
        }
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

    my $query = qq(SELECT * from $table where chr = ? AND chr_start < ? AND chr_end > ? ORDER by chr_start);
    my $sth = $dbh->prepare($query);
    foreach my $segment(@{$segment_list}){
    
        my ($chr,$rest) = split(":",$segment);
        my ($start,$end) = split(",",$rest);
        $response .= qq(    <SEGMENT id="$chr" version="1" start="$start" stop="$end">\n);
        $sth->execute($chr,$end,$start);

        while (my $row = $sth->fetchrow_hashref()){
            my $type = $row->{'type'};
            my $id   = $row->{'embl_id'};
            my $es   = $row->{'embl_start'};
            my $ee   = $row->{'embl_end'};
            my $cs   = $row->{'chr_start'};
            my $ce   = $row->{'chr_end'};
            my $eo   = $row->{'embl_ori'};

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
