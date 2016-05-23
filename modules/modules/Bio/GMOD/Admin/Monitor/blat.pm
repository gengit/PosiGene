package Bio::GMOD::Admin::Monitor::blat;

# Monitor and restart blat as necessary

use strict;
use vars qw/@ISA/;
use Bio::GMOD::Admin::Monitor;
use Bio::GMOD::Util::Rearrange;
use DBI;

@ISA = qw/Bio::GMOD::Admin::Monitor/;


use strict;

use constant BLAT_SERVER      => '/usr/local/blat/bin/gfServer';
use constant DAEMON_PATH      => '/etc/rc.d/init.d/blat_server';
use constant ALTERNATIVE_PATH => '/usr/local/wormbase/util/admin/blat_server.initd';

my $result = `/usr/local/blat/bin/gfClient localhost 2003 /usr/local/wormbase/blat stdin stdout -nohead < /usr/local/wormbase/blat/test.fa`;
unless ($result) { # can't connect
  warn scalar(localtime),": can't connect to blat server, restarting\n";
  my $result;
  if (-e DAEMON_PATH) {
    $result = system (DAEMON_PATH,'condrestart');
  } else {
    $result = system(ALTERNATIVE_PATH);
  }
  ($result ==0 ) or warn "Restarting the blat server failed: $!\n";
}



/usr/local/blat/bin/gfServer start localhost 2003 /usr/local/wormbase/blat/*.nib & > /dev/null 2>&1
/usr/local/blat/bin/gfServer start localhost 2004 /usr/local/wormbase/blat/briggsae/files/*.nib & > /dev/null 2>&1




sub new {
  my $class = shift;
  my $this   = bless {},$class;
  return $this;
}

sub check_status {
  my ($self,@p) = @_;
  my ($testdb) = rearrange([qw/TESTDB/],@p);
  $testdb ||= 'test';

  $self->{testing}   = 'mysqld';
  $self->{tested_at} = $self->fetch_date;

  my $db = DBI->connect("dbi:mysql:$testdb",'nobody');

  # Populate some redundant tags
  if ($db) {
    $self->set_status_flags('initial','up');
    $self->status_string(-timing => 'initial',
			 -msg    => 'Testing mysqld',
			 -status => 'UP');
  } else {
    $self->set_status_flags('initial','down');
    $self->status_string(-timing => 'initial',
			 -msg    => 'Testing mysqld',
			 -status => 'DOWN');
  }
}



sub restart {
  my ($self,@p) = @_;
  my ($mysqld,$initd,$testdb) = rearrange([qw/MYSQLD INITD TESTDB/],@p);
  if (-e $mysqld) {
    system("$mysqld --user=mysql &")
  } elsif (-e $initd) {
    system("$initd condrestart");
  } else {}

  $testdb ||= 'test';
  my $db = DBI->connect("dbi:mysql:$testdb",'nobody');

  if ($db) {
    $self->set_status_flags('final','up');
    $self->status_string(-timing => 'final',
			 -msg    => "Restarting mysqld via $initd",
			 -status => 'SUCCEEDED');
  } else {
    $self->set_status_flags('final','down');
    $self->status_string(-timing => 'final',
			 -msg    => "Restarting mysqld via $mysqld",
			 -status => 'FAILED');
  }
}





1;



=pod

=head1 NAME

Bio::GMOD::Admin::Monitor::blat - Monitor a BLAT server

=head1 SYNOPSIS

Check the installed version of a MOD

  use Bio::GMOD::Util::CheckVersions.pm
  my $gmod    = Bio::GMOD::Util::CheckVersions->new(-mod=>'WormBase');
  my $version = $gmod->live_version;

Update a MOD installation

  use Bio::GMOD::Update;
  my $gmod = Bio::GMOD::Update->new(-mod=>'WormBase');
  $gmod->update();

Build archives of MOD releases (coming soon...)

Do some common datamining tasks (coming soon...)

=head1 DESCRIPTION

Bio::GMOD is a unified API for accessing various Model Organism Databases.
It is a part of the Generic Model Organism Database project, as well
as distributed on CPAN.

MODs are highly curated resources of biological knowledge. MODs
typically incorporate the typical information found at common
community sites such as NCBI.  However, they greatly extend this
information, placing it within a framework of experimental and
published observations of biological function gleaned from experiments
in model organisms.

Given the great proliferation of MODs, cross-site data mining
strategies have been difficult to implement.  Furthermore, the
quickly-evolving nature of these projects have made installing a MOD
locally and keeping it up-to-date a delicate and time-consuming
experience.

Bio::GMOD aims to solve these problems by:

   1.  Making MODs easy to install
   2.  Making MODs easy to upgrade
   3.  Enabling cross-MOD data mining through a unified API
   4.  Insulating programmatic end users from model changes

=head1 NOTES FOR DEVELOPERS

Bio::GMOD.pm uses a generically subclass-able architecture that lets
MOD developers support various features as needed or desired.  For
example, a developer may wish to override the default methods for
Update.pm by building a Bio::GMOD::Update::FlyBase package that
provides an update() method, as well as various supporting methods.

Currently, the only participating MOD is WormBase.  The authors hope
that this will change in the future!

=head1 PUBLIC METHODS

=over 4
