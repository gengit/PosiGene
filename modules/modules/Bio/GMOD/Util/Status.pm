package Bio::GMOD::Util::Status;

# This simple module doesn't do much of interest
# It provides several some methods for generating
# warnings and handling errors

use strict;
use Bio::GMOD::Util::Rearrange;

#########################################################
# Utilities
#########################################################
# This is appended to the messages log to signify to the application
# that the update process has ended
#sub end {
#  my $msg = shift;
#  print MESSAGES "__UPDATE_$msg" . "__\n";
#  logit('===========================================================',1);
#  logit("Updating complete: $msg");
#  logit('===========================================================',1);
#  close MESSAGES;
#}


sub logit {
  my ($self,@p) = @_;
  my ($msg,$die,$emphasis) = rearrange([qw/MSG DIE EMPHASIS/],@p);
  my $date = $self->fetch_date;
  $msg =~ s/\n$//;
  if ($emphasis) {
    print STDERR "$msg...\n";
    print STDERR '=' x (length "$msg...") . "\n" if $emphasis;
  } else {
    print STDERR "[$date] $msg...\n";
  }
  die if $die;
  # my $adaptor = $self->adaptor;
  # $self->gui_messages($msg) if $adaptor->gui_messages;
}


# For recording non-fatal errors
sub warning {
  my ($self,@p) = @_;
  my ($msg) = rearrange([qw/MSG/],@p);
  print STDERR "----> $msg\n";
}

sub test_for_error {
  my ($self,$result,$msg) = @_;
  if ($result != 0) {
    $self->logit(-msg => "----> $msg: failed, $!\n",
		 -die => 1,);
  } else {
    $self->logit(-msg => "$msg: succeeded");
  }
}

sub fetch_date {
  #  my $date = `date '+%Y %h %d (%a) at %H:%M'`;
  my $date = `date '+%Y %h %d %H:%M'`;
  chomp $date;
  return $date;
}


# DEPRECATED?
# The messages log is used to display brief messages
# above the progress meter of the application
sub gui_messages {
  my ($self,$msg) = @_;
  #  print MESSAGES "$msg...\n";
}



1;


__END__


=pod

=head1 NAME

Bio::GMOD::Util::Status - Message processing for Bio::GMOD

=head1 SYNPOSIS

None. See below.

=head1 DESCRIPTION

Bio::GMOD::Util::Status provides a variety of methods for processing
messages and handling errors throughout Bio::GMOD.

=head1 PUBLIC METHODS

=over 4

=item $self->logit(@options)

Log a message to STDERR. The message will be prefaced with the date
and time.

 Options:
 -msg  The message to log
 -die  Die after logging the message

=item $self->warning(@options)

Log a message to STDERR but with a small flag to set it off from other
messages.

 Options:
 -msg  The message to log

=item $self->test_for_error($result,$msg);

Test a return value for success, logging (and dying) a failure or
passing a warning if successful.

=item $self->fetch_date()

Return a formatted date string.

=item $self->status_string(@options);

Return a formatted string showing date, condition tested and result.
This function is used predominantly for monitoring the status of an
installation, generating a clean string for sending in emails,
logging, etc.

 eg:
 [22 Feb 2005 08:22:22] Restarting mysqld ............. [OK]

 Options:
 -timing   usually one of initial (status before test)
           or final (status after test)
 -msg      The actual test message
 -status   The status of the result (ie OK, Failed)

=item $self->set_status_flags($timing,$status);

Set various internal status flags of Bio::GMOD::Monitor::* objects.
These include "is_up", "is_down", "initial_status", "final_status" as
described for status_string above. See Bio::GMOD::Monitor for
additional details in who these flags are used to indicate the status
of particular servers or services.

=back

=head1 BUGS

None reported.

=head1 SEE ALSO

L<Bio::GMOD>

=head1 AUTHOR

Todd W. Harris E<lt>harris@cshl.eduE<gt>.

Copyright (c) 2003-2005 Cold Spring Harbor Laboratory.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
