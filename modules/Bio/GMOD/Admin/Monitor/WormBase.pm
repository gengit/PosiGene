package Bio::GMOD::Admin::Monitor::WormBase;

use strict;
use vars qw/@ISA/;
use Bio::GMOD::Admin::Monitor;
use Bio::GMOD::Admin::Monitor::mysqld;
use Bio::GMOD::Admin::Monitor::httpd;
use Bio::GMOD::Admin::Monitor::acedb;
use Bio::GMOD::Admin::Monitor::blat;

@ISA = qw/Bio::GMOD::Admin::Monitor/;

sub monitor {
  my ($self,@p) = @_;
  my ($apachectl,$test_url,
      $acepl,$acedb_user,$acedb_pass,
      $mysql_test_db,$mysql_initd,$mysqld_safe,

      = rearrange([qw/SITE USER PASS/],@p);

  my $adaptor = $self->adaptor;

  # httpd
  my $httpd = Bio::GMOD::Admin::Monitor::httpd->new();
  $httpd->check_status(-site => $test_url);
  $httpd->restart(-apachectl => $apachectl) if $httpd->is_down;

      # Mysqld
      my $mysqld = Bio::GMOD::Admin::Monitor::mysqld->new();
      $mysqld->check_status(-testdb => $mysql_test_db);
      $mysqld->restart(-mysqld_safe => $mysqld_safe,
		       -mysql_initd => $mysql_initd,
		       -testdb      => $mysql_test_db) if ($mysqld->is_down);

  # Acedb
  my $acedb = Bio::GMOD::Admin::Monitor::acedb->new();





  return ($mysqld,$httpd,$acedb);
}


# Restart all the various servers as necessary
sub restart_servers {
   my ($self,@p) = @_;

   # Restart blat
   my $blat   = Bio::GMOD::Admin::Monitor::blat->new();
   my ($blat_result,$blat_status) = $blat->restart();

   # restart acedb
   my $acedb  = Bio::GMOD::Admin::Monitor::acedb->new();
   my ($ace_result,$ace_status) = $acedb->restart();

   # httpd
   my $httpd  = Bio::GMOD::Admin::Monitor::httpd->new();
   my ($httpd_result,$httpd_status) = $httpd->restart();

   # mysqld
   my $mysqld = Bio::GMOD::Admin::Monitor::mysqld->new();
   my ($mysqld_result,$mysqld_status) = $mysqld->restart();
}




__END__


=pod

=head1 NAME

Bio::GMOD::Admin::Monitor::WormBase - WormBase monitoring utils

=head1 SYNOPSIS

  my $agent = Bio::GMOD::Admin::Monitor->new(-mod => 'WormBase');

=head1 DESCRIPTION

Bio::GMOD::Admin::Monitor::WormBase provides methods for WormBase
administrators to monitor their installation.  It provides a
convenient wrapper around several Bio::GMOD::Admin::Monitor:: utilities but
provides no other useful methods.

=head1 PUBLIC METHODS

=over 4

=item $agent->monitor(@options);

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


1;
