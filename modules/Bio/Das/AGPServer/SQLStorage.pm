package Bio::Das::AGPServer::SQLStorage;

=head1 AUTHOR

Tony Cox <avc@sanger.ac.uk>.

Copyright (c) 2003 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use DBI;
use strict;
use vars qw($AUTOLOAD $DEBUG $CLONE_STATUS);

$Bio::Das::AGPServer::SQLStorage::DEBUG = 1;

# F = Finished         = HTGS_PHASE3                                                                             
# A = Almost finished  = HTGS_PHASE2 (Rare)                                                                      
# U = Unfinished       = HTGS_PHASE1 (Not ususally in AGPs, but can be.)                                         
# N = Gap in AGP - these lines have an optional qualifier (eg: CENTROMERE)
$Bio::Das::AGPServer::SQLStorage::CLONE_STATUS = {
                    'F' => "Finished/HTGS_PHASE3",
                    'A' => "Almost finished/HTGS_PHASE2",
                    'U' => "Unfinished/HTGS_PHASE1",
                    'N' => "Gap in AGP",
                };

#################################################################
## Init the options object
#################################################################
sub init {
    my $self = shift;
    die "SQLStorage::init - this method should be implmented by a sublass of SQLStorage!\n";       
}

#################################################################
sub create_agp_table {
     my ($self) = @_;

    my $dbh         = $self->db_handle();
    my $tablename   = $self->config()->tablename();
    my $dbname      = $self->config()->dbname();
    my $tmpdir      = $self->config()->tmpdir();
       
    my $query = qq(CREATE TABLE $tablename 
                        (chr CHAR(6),
                        chr_start INTEGER,
                        chr_end INTEGER,
                        ord INTEGER,
                        type CHAR(4),
                        embl_id CHAR(20),
                        embl_start INTEGER,
                        embl_end INTEGER,
                        embl_ori CHAR(4)
                        ));

    my $sth = $dbh->prepare($query);
    $sth->execute() or die $dbh->errstr();
    $sth->finish();
    
    if (lc($self->config()->backend()) eq "csv"){ 
        print STDERR "Created temporary CSV database table $tablename in $tmpdir\n" if ($Bio::Das::AGPServer::SQLStorage::DEBUG == 1);
    } else {
        print STDERR "Created temporary Mysql database table $tablename in $dbname\n" if ($Bio::Das::AGPServer::SQLStorage::DEBUG == 1);
    }   
}

########################################################################################
sub load_agp {

    my ($self,$parser) = @_;
    
    my $config      = $self->config();
    my $dbh         = $self->db_handle();
    my $tablename   = $config->tablename();
    
    while (my $f = $parser->next()){
        $dbh->do("INSERT INTO $tablename VALUES (?,?,?,?,?,?,?,?,?)", undef,
            $f->[0],
            $f->[1],
            $f->[2],
            $f->[3],
            $f->[4],
            $f->[5],
            $f->[6],
            $f->[7],
            $f->[8]
        ) if @{$f};

    }

}

########################################################################################
#<?xml version='1.0' standalone='no' ?>
#<!DOCTYPE DASDSN SYSTEM 'dasdsn.dtd' >
#<DASDSN>
#  <DSN>
#    <SOURCE id="ens1331cds" version="13">Ensembl 13.31 CDS</SOURCE>
#    <MAPMASTER>http://ecs3c.internal.ac.uk:8080/das/ensembl1331/</MAPMASTER>
#    <DESCRIPTION>Ensembl CDS</DESCRIPTION>
#  </DSN>
#</DASDSN>
########################################################################################
sub dsn {

    my ($self) = @_;

    my $dsn     = $self->config->dsn();
    my $dsnversion = $self->config->dsnversion() || 1;
    my $port    = $self->config->port();
    my $host    = $self->config->hostname();

    my $content .= $self->open_dasdsn();
    
    $content .=<<END;
  <DSN>
    <SOURCE id="$dsn" version="$dsnversion">$dsn</SOURCE>
    <MAPMASTER>http://$host:$port/das/$dsn/</MAPMASTER>
    <DESCRIPTION>AGP for $dsn</DESCRIPTION>
  </DSN>
END
;
    $content .= $self->close_dasdsn();

    return ($content);


}

########################################################################################
#<?xml version='1.0' standalone='no' ?>
#<!DOCTYPE DASDSN SYSTEM 'dasdsn.dtd' >
#<DASDSN>
#  <DSN>
#    <SOURCE id="ens1331cds" version="13">Ensembl 13.31 CDS</SOURCE>
#    <MAPMASTER>http://ecs3c.internal.ac.uk:8080/das/ensembl1331/</MAPMASTER>
#    <DESCRIPTION>Ensembl CDS</DESCRIPTION>
#  </DSN>
#</DASDSN>
#################################################################
sub open_dasdsn {

    my ($self) = @_;
    
    my $dsn     = $self->config->dsn();
    my $host    = $self->config->hostname();
    my $port    = $self->config->port();

    my $response .=<<END;
<?xml version="1.0" standalone="no"?>
<!DOCTYPE DASDSN SYSTEM 'http://www.biodas.org/dtd/dasdsn.dtd' >
<DASDSN>
END
;

    return($response);
}

#################################################################
sub close_dasdsn {

    my ($self) = @_;

    my $response .=<<END;
</DASDSN>
END
;

    return($response);

}

########################################################################################
#<?xml version='1.0' standalone='no' ?>
#<!DOCTYPE DASEP SYSTEM 'dasep.dtd' >
#<DASEP>
#  <ENTRY_POINTS href="http://ecs3c.internal.sanger.ac.uk:8080/das/ensembl1331/entry_points" version="13">
#    <SEGMENT id="12_NT_037834" size="180525" subparts="yes" />
#  </ENTRY_POINTS>
#</DASEP>
#################################################################
sub open_dasep {

    my ($self) = @_;
    
    my $dsn     = $self->config->dsn();
    my $host    = $self->config->hostname();
    my $port    = $self->config->port();

    my $response .=<<END;
<?xml version="1.0" standalone="no"?>
<!DOCTYPE DASEP SYSTEM "http://www.biodas.org/dtd/dasep.dtd">
<DASEP>
  <ENTRY_POINTS href="http://$host:$port/das/$dsn/entry_points" version="1.0">
END
;

    return($response);
}

#################################################################
sub close_dasep {

    my ($self) = @_;

    my $response .=<<END;
  </ENTRY_POINTS>
</DASEP>
END
;

    return($response);

}

#################################################################
#    <SEGMENT id="6" version="13" start="30010121" stop="31280281">
#      <FEATURE id="components/AC004201.1.1.43284" label="components/AC004201.1.1.43284">
#        <TYPE id="static_golden_path" reference="yes" subparts="no">static_golden_path</TYPE>
#        <METHOD id="ensembl">ensembl</METHOD>
#        <START>30094146</START>
#        <END>30125430</END>
#        <SCORE>-</SCORE>
#        <ORIENTATION>-</ORIENTATION>
#        <PHASE>-</PHASE>
#        <TARGET id="AC004201.1.1.43284" start="1" stop="31285" />
#      </FEATURE>
#    </SEGMENT>
#################################################################
sub open_dasgff {

    my ($self) = @_;
    
    my $dsn     = $self->config->dsn();
    my $host    = $self->config->hostname();
    my $port    = $self->config->port();

    my $response .=<<END;
<?xml version="1.0" standalone="yes"?>
<!DOCTYPE DASGFF SYSTEM "http://www.biodas.org/dtd/dasgff.dtd">
<DASGFF>
  <GFF version="1.01" href="http://$host:$port/das/$dsn/features">
END
;

    return($response);
}

#################################################################
sub close_dasgff {

    my ($self) = @_;

    my $response .=<<END;
  </GFF>
</DASGFF>
END
;

    return($response);

}

#################################################################
sub stylesheet {

    my ($self) = @_;
    
    ## bog-standard default stylesheet
    my $style =<<END;
<!DOCTYPE DASSTYLE SYSTEM "http://www.biodas.org/dtd/dasstyle.dtd">
<DASSTYLE>
<STYLESHEET version="1.0">
  <CATEGORY id="default">
     <TYPE id="default">
        <GLYPH>
           <BOX>
              <FGCOLOR>black</FGCOLOR>
              <FONT>sanserif</FONT>
              <BUMP>0</BUMP>
              <BGCOLOR>black</BGCOLOR>
           </BOX>
        </GLYPH>
     </TYPE>
  </CATEGORY>
</STYLESHEET>
</DASSTYLE>
END

    return($style);
}

#################################################################
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
