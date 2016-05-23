package Bio::GMOD::Admin::Monitor::httpd;

# Monitor and restart httpd as needed

use strict;
use vars qw/@ISA/;
use Bio::GMOD::Admin::Monitor;
use Bio::GMOD::Util::Rearrange;
use LWP::UserAgent;

@ISA = qw/Bio::GMOD::Admin::Monitor/;

# Here, we'll check the status of httpd by actually checking to see
# that the website is up.
sub check_status {
  my ($self,@p) = @_;
  my ($site) = rearrange([qw/SITE/],@p);

  unless ($site) {
    my $adaptor = $self->adaptor;
    $site = $adaptor->live_url;
  }

  $self->{testing}   = 'httpd';
  $self->{tested_at} = $self->fetch_date;

  my $ua     = LWP::UserAgent->new();
  $ua->agent('Bio::GMOD::Admin::Monitor');
  my $request = HTTP::Request->new('GET',$site);
  my $response = $ua->request($request);
  my ($string,$status) = $self->set_status(-timing => 'initial',
					   -msg    => "Testing httpd at $site",
					   -status => ($response->is_success) ? 'up' : 'down');
  return ($string,$status);
}


# NOTE!  The "final" status is really just whether or not the command
# succeeded, not whether the service has been restored!
sub restart {
  my ($self,@p) = @_;
  my ($apachectl) = rearrange([qw/APACHECTL/],@p);
  $apachectl ||= '/usr/local/apache/bin/apachectl';
  my $result = system($apachectl,'restart');
  my ($string,$status);
  if ($result != 0) {
    ($string,$status) = $self->set_status(-timing => 'final',
					  -msg    => "Restarting httpd",
					  -status => 'failed');
  } else {
    ($string,$status) = $self->set_status(-timing => 'final',
					  -msg    => "Restarting httpd",
					  -status => 'succeeded');
  }
  return ($string,$status);
}


1;


=pod

=head1 NAME

Bio::GMOD::Admin::Monitor::httpd - Monitor httpd

=head1 SYNOPSIS

Check that httpd is running at a specific site

  use Bio::GMOD::Admin::Monitor::httpd;
  my $gmod  = Bio::GMOD::Admin::Monitor::httpd->new(-mod=>'WormBase');
  my ($result,$status) $gmod->check_status(-site => 'http://www.flybase.org');
  print "Testing FlyBase status at " . $gmod->tested_at . ": $result";

=head1 DESCRIPTION

Bio::GMOD::Admin::Monitor::httpd provides methods for monitoring and
restarting httpd as necessary at a MOD.

=head1 PUBLIC METHODS

=over 4

=item $gmod->check_status(-site => SITE)

Check the status of httpd at a specified site.  This is done by
fetching the top level URL, assuming that if it can be retrieved that
httpd is up.

This method returns a two element list comprised of ($string,$status).
$string will contain a formatted string indicating the test, time, and
result; $status will be boolean true or false indicating the success
or failure of the test.

This method also populates the object with a variety of status
strings.  See the "ACCESSOR METHODS" section of Bio::GMOD::Admin::Monitor for
additional details.

If SITE is not provided, the URL for the live site (fetched from the
adaptor for the appropriate MOD) will be used:

  my $monitor = Bio::GMOD::Admin::Monitor::httpd->new(-mod=>'WormBase');
  $monitor->check_status();   # Checks the status of http://www.wormbase.org/

Note that you must specify the -mod option to new in order for this to
work correctly.

=item $monitor->restart(-apachectl => APACHECTL);

Restart httpd using the apachectl script. If not provided as an
option, assumes that apachectl resides at
/usr/local/apache/bin/apachectl.

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
