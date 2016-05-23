package Bio::GMOD::Admin::Monitor::acedb;

# Monitor and restart acedb as needed

use strict;
use vars qw/@ISA/;
use Bio::GMOD::Admin::Monitor;
use Bio::GMOD::Util::Rearrange;

@ISA = qw/Bio::GMOD::Admin::Monitor/;

# Check that sgifaceserver is running on the provided port
sub check_status {
  my ($self,@p) = @_;

  my @ps = `ps -aux | grep sgifaceserver`;
  my $is_up;
  foreach (@ps) {
    $is_up++ if (/sgifaceserver\s\//);
  }
  
  $self->{testing}   = 'acedb';
  $self->{tested_at} = $self->fetch_date;
  my ($string,$status) = $self->set_status(-timing => 'initial',
					   -msg    => "Testing acedb/sgifaceserver",
					   -status => ($is_up) ? 'up' : 'down');
  return ($string,$status);
}

sub restart {
  my ($self,@p) = @_;
  my ($xinetd,$user,$pass) = rearrange([qw/XINETD USER PASS/],@p);
  $xinetd ||= '/etc/rc.d/init.d/xinetd';
  $user   ||= 'admin';
  $pass   ||= 'ace123';
  
  # Try restarting sgiface from least to most aggressive
  my $result = (system "/usr/local/acedb/bin/ace.pl -port 2005 -user $user -pass $pass -e 'shutdown now'");
  
  # Try restarting xinetd
  $result = system($xinetd,'reload');
  
  # Directly restart xinetd on some systems
  $result = system('killall -HUP xinetd') unless ($result == 0);
  
  # Try restarting via inetd
  $result = system('killall -HUP inetd') unless ($result == 0);
  
  my ($string,$status);
  if ($result != 0) {
    ($string,$status) = $self->set_status(-timing => 'final',
					  -msg    => "Restarting acedb/sgifaceserver/xinetd",
					  -status => 'failed');
  } else {
    ($string,$status) = $self->set_status(-timing => 'final',
					  -msg    => "Restarting acedb/sgifaceserver/xinetd",
					  -status => 'succeeded');
  }
  return ($string,$status);
}


1;


=pod

=head1 NAME

Bio::GMOD::Admin::Monitor::acedb - Monitor acedb/sgifaceserver

=head1 SYNOPSIS

Check that sgifaceserver is running

  use Bio::GMOD::Admin::Monitor::acedb;
  my $gmod  = Bio::GMOD::Admin::Monitor::acedb->new();
  $gmod->check_status();
  print "Testing acedb status at " . $gmod->tested_at . ": $status";

=head1 DESCRIPTION

Bio::GMOD::Admin::Monitor::acedb provides methods for monitoring and
restarting acedb/sgifaceserver as necessary.

=head1 PUBLIC METHODS

=over 4

=item $gmod->check_status()

Check the status of acedb on the localhost.  Note that because in most
installations, sgifaceserver is configured to run under xinetd/inetd.
If there has been a long period with no requests, sgifaceserver may
have timed out.

This method returns a two element list comprised of ($string,$status).
$string will contain a formatted string indicating the test, time, and
result; $status will be boolean true or false indicating the success
or failure of the test.

This method also populates the object with a variety of status
strings.  See the "ACCESSOR METHODS" section of Bio::GMOD::Admin::Monitor for
additional details.

=item $monitor->restart(@options);

Restart sgifaceserver using a variety of methods, starting from least
to most aggressive.

 Options:
 -user      These two options will be used to try and restart sgifaceserver
 -pass      using the ace.pl script (if installed on your system) (admin/ace123)

 -xinetd    full path to xinetd undet control of init.d
            (defaults to /etc/rc.d/init.d/xinetd if not provided)

The following attempts will be made to try and restart sgifaceserver:

  1. via ace.pl
  2. By reloading xinetd through inetd
  3. By sending xinetd a HUP
  4. By sending inetd a HUP

Note that restarting sgifaceserver can take some time depending on
your system!  Be patient!

This method returns a two element list comprised of ($string,$status).
$string will contain a formatted string indicating the test, time, and
result; $status will be boolean true or false indicating the success
or failure of the test.

Like check_status(), this method populates a number of status
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
