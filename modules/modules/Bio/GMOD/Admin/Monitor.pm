package Bio::GMOD::Admin::Monitor;

use strict;
use vars qw/@ISA/;
use Bio::GMOD;
#use Bio::GMOD::Util::Email;
use Bio::GMOD::Util::Rearrange;

@ISA = qw/Bio::GMOD Bio::GMOD::Util::Email/;

# A simple generic new method - no need to reload a MOD adaptor
# since most monitoring options are site-specific
sub new {
  my ($class,@p) = @_;
  my ($mod) = rearrange([qw/MOD/],@p);
  if ($mod) {
    my $gmod = Bio::GMOD->new(-mod=>$mod,-class=>$class);
    return $gmod;
  } else {
    my $this   = bless {},$class;
    return $this;
  }
}

sub generate_report {
  my ($self,@p) = @_;
  my ($email_report,$log_report,$components,$email_to_ok,$email_to_warn,$email_from,$email_subject)
    = rearrange([qw/EMAIL_REPORT LOG_REPORT COMPONENTS EMAIL_TO_OK EMAIL_TO_WARN EMAIL_FROM EMAIL_SUBJECT/],@p);

  $email_report ||= 'none';
  $log_report   ||= 'all';

  my $date = $self->fetch_date;
  my $msg = <<END;
$email_subject
DATE: $date

END

  my $failed_flag;   # Track whether any of the tests failed
  foreach my $component (@$components) {
    $msg .= $component->initial_status_string. "\n";
    $msg .= $component->final_status_string . "\n" if ($component->final_status_string);
    $msg .= "\n";
    $failed_flag++ if $component->final_status_string;
  }

  unless ($email_report eq 'none') {
    my @to;
    push (@to,$email_to_ok) if $email_to_ok;
    push (@to,$email_to_warn) if $email_to_warn && $email_to_ok && ($email_to_warn ne $email_to_ok);

    unless ($email_report eq 'failures' && !$failed_flag) {
      #      Bio::GMOD::Util::Email->send_email(-to      => \@to,
      #					 -from    => $email_from,
      #				 -subject => $email_subject,
      #				 -content => $msg
      #				);
    }
  }
  print $msg;
}


# Generic accessors
sub status         { return shift->{status}; }
sub tested_at      { return shift->{tested_at}; }
sub testing        { return shift->{testing}; }

sub is_up          { return shift->{is_up};   }
sub is_down        { return shift->{is_down}  }

sub initial_status_string { return shift->{initial_status_string}; }
sub final_status_string   { return shift->{final_status_string}; }


# Create a formatted string - useful for emails and such
sub build_status_string {
  my ($self,@p) = @_;
  my ($timing,$msg) = rearrange([qw/TIMING MSG/],@p);
  my $status = $self->{$timing}->{status};

  my $MAX_LENGTH = 60;

  my $date = $self->fetch_date;
  # Pad the string with '.' up to MAX_LENGTH in length;
  my $string = sprintf("%-*s %*s [%s]",
		       (length $msg) + 1,$msg,
		       $MAX_LENGTH - ((length $msg) + 2),
		       ("." x ($MAX_LENGTH - ((length $msg) + 2))),
		       $status);
  my $full_string = "[$date] $string";
  $self->{$timing . "_status_string"} = $full_string;
  return $full_string;
}


# Status flags are used for testing various services like acedb,
# mysqld, httpd or whatever
sub set_status {
  my ($self,@p) = @_;
  my ($timing,$msg,$status) = rearrange([qw/TIMING MSG STATUS/],@p);
  # Timing is one of initial or final
  # Status is true or false if the service is available

  $self->{$timing}->{status} = $status;
  $self->{$timing}->{msg}    = $msg;

  # Set up some redundant flags, provided as a convenience
  if ($status eq 'up' || $status eq 'succeeded') {
    $self->{is_up}++;
    $self->{is_down} = undef;
  }

  my $string = $self->build_status_string(-timing=>$timing,-msg=>$msg);

  # Return a boolean for status for easy testing
  return ($string,$self->is_up ? 1 : 0);
}


__END__


=pod

=head1 NAME

Bio::GMOD::Admin::Monitor - Monitor the status of an installed MOD

=head1 SYNOPSIS

None.  See below.

=head1 DESCRIPTION

You will not normally work with Bio::GMOD::Admin::Monitor objects directly.
This parent class is intended to be subclassed by MOD developers who
wish to provide internal monitoring capabilities for administrators.

=head1 PUBLIC METHODS

=over 4

=item $monitor->generate_report(@options);

Generate a report for either emailing or logging as requested.

 Options:
 -components    An array reference of Bio::GMOD::Monitor::* objects tested
 -email_report  Conditions under which to send emails [none]
 -log_report    Conditions under which to log reports [all]
 -email_to_ok   Default email address to send reports
 -email_to_warn Supplemental address to send reports on failures
 -email_from    Who to send the email from
 -email_subject The subject of the email

The "-email_report" and "-log_report" options accept one of three
values: none, all, failures.  These correspond to conditions in which
to email or log the report.  For example, if --email_report is set to
"failures" then only monitor processes that generate a failure will
result in an email being generated.

Note that unless you specify set the email_report option to "none",
you will also need to pass email_to, email_from, and email_subject.

=item $monitor->"accessor"

Bio::GMOD::Admin::Monitor also offers a number of common accessors for
subclasses. Feel free to override these as necessary.

=item is_down, is_up

Returns true if the server/test is down/failed or is up/succeeded as
appropriate

=item status

Synonym for is_down and is_up. Contents will be one of up or down.

=item testing

Name of the service or test.

=item tested_at

Date and time the service was tested.

=item initial_status_string, final_status_string

These two methods return a human readable formatted string suitable
for display.  initial_status_string contains the results of the first
test of the service. final_status_string will only be populated if the
first test failed and some action was necessary to restore the
service.

=back

=head1 BUGS

None reported.

=head1 SEE ALSO

L<Bio::GMOD>

=head1 AUTHOR

Todd W. Harris E<lt>harris@cshl.orgE<gt>.

Copyright (c) 2003-2005 Cold Spring Harbor Laboratory.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut





1;
