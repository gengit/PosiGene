package Bio::GMOD::Admin::Monitor::mysqld;

# Monitor and restart mysqld as necessary
use strict;
use vars qw/@ISA/;
use Bio::GMOD::Admin::Monitor;
use Bio::GMOD::Util::Rearrange;
use DBI;

@ISA = qw/Bio::GMOD::Admin::Monitor/;

sub check_status {
  my ($self,@p) = @_;
  my ($testdb) = rearrange([qw/TESTDB/],@p);
  $testdb ||= 'test';

  $self->{testing}   = 'mysqld';
  $self->{tested_at} = $self->fetch_date;

  my $db = DBI->connect("dbi:mysql:$testdb",'nobody');
  $self->set_status(-timing => 'initial',
		    -msg    => 'Testing mysqld',
		    -status => ($db) ? 'up' : 'down');
}


sub restart {
  my ($self,@p) = @_;
  my ($mysqld,$initd,$testdb) = rearrange([qw/MYSQLD_SAFE MYSQL_INITD TESTDB/],@p);
  my $flag;
  if ($initd && -e $initd) {
    system("$initd condrestart");
    $flag++;
  }

  if ($mysqld && -e $mysqld && !$flag) {
    # Make sure that we aren't already running...
    $self->check_status();
    if ($self->is_down) {
      system("$mysqld --user=mysql &");
    }
  }

  $testdb ||= 'test';
  my $db = DBI->connect("dbi:mysql:$testdb",'nobody');
  my ($string,$status) = $self->set_status(-timing => 'final',
					   -msg    => "Restarting mysqld via " . ($mysqld ? $mysqld : $initd),
					   -status => ($db) ? 'succeeded' : 'failed');
}


1;



=pod

=head1 NAME

Bio::GMOD::Admin::Monitor::mysqld - Monitor mysqld

=head1 SYNOPSIS

Check that mysqld is running

  use Bio::GMOD::Admin::Monitor::mysqld;
  my $monitor  = Bio::GMOD::Admin::Monitor::mysqld->new();
  $monitor->check_status(-site => 'http://www.flybase.org');

# Typical values for initd systems might be something like:
#$INITD = '/etc/rc.d/init.d/mysqld';

# For non-init systems
#$MYSQLD = '/usr/local/mysql/bin/mysqld_safe';
#$MYSQLD = '/usr/bin/safe_mysqld';


=head1 DESCRIPTION

Bio::GMOD::Admin::Monitor::httpd provides methods for monitoring and
restarting httpd as necessary at a MOD.

=head1 PUBLIC METHODS

=over 4

=item $gmod->check_status(-site => SITE)

Check the status of httpd at a specified site.  This is done by
fetching the top level URL, assuming that if it can be retrieved that
httpd is up.  Returns true if the provided site is up, false if it is
down.

This method also populates the object with a variety of status
strings.  See the "ACCESSOR METHODS" section of Bio::GMOD::Admin::Monitor for
additional details.

If SITE is not provided, the URL for the live site (fetched from the
adaptor for the appropriate MOD) will be used:

  my $monitor = Bio::GMOD::Admin::Monitor::httpd->new(-mod=>'WormBase');
  $monitor->check_status();   # Checks the status of http://www.wormbase.org/

=item $monitor->restart(-apachectl => APACHECTL);

Restart httpd using the apachectl script. If not provided as an
option, assumes that apachectl resides at
/usr/local/apache/bin/apachectl.

Returns true if httpd is successfully restarted; otherwise returns
false.  Like check_status(), this method populates a number of status
fields in the object.  See the "ACCESSOR METHODS" section of
Bio::GMOD::Admin::Monitor for additional details.

=back

=head1 BUGS

None reported.

=head1 SEE ALSO

L<Bio::GMOD>, L<Bio::GMOD::Admin::Monitor>

=head1 AUTHOR

Todd W. Harris E<lt>harris@cshl.orgE<gt>.

Copyright (c) 2003-2005 Cold Spring Harbor Laboratory.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
