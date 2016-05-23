package Bio::GMOD::Util::Mirror;

use strict;
use vars qw/@ISA/;
use Carp;
use Net::FTP;
use File::Path;
use Bio::GMOD;
use Bio::GMOD::Util::Rearrange;

@ISA = qw/Bio::GMOD/;

# options:
# host  -- ftp host
# path  -- ftp path
# localpath -- localpath
# verbose -- verbose listing
# user  -- username
# pass  -- password
# passive -- use passive FTP
sub new {
  my ($class,@p) = @_;
  my ($host,$path,$localpath,$verbose,$user,$pass,$passive,$hash)
    = rearrange([qw/HOST PATH LOCALPATH VERBOSE USER PASS PASSIVE HASH/],@p);
  croak "Usage: Mirror->new(\$host:/path)" unless $host && $path;
  if ($host =~ /(.+):(.+)/) {
    ($host,$path) = ($1,$2);
  }
  $path ||= '/';
  $user ||= 'anonymous';
  $pass ||= "$user\@localhost.localdomain";
  
  my %transfer_opts;
  $transfer_opts{Passive} = 1 if $passive;
  $transfer_opts{Timeout} = 600;
  my $ftp = Net::FTP->new($host,%transfer_opts) || croak "Can't connect: $@\n";
  $ftp->login($user,$pass) || croak "Can't login: ",$ftp->message;
  $ftp->binary;
  $ftp->hash(1) if $hash;
  my %opts = (host  => $host,
	      path   => $path,
	      localpath => $localpath,
	      verbose   => $verbose,
	      user      => $user,
	      pass      => $pass,
	      passive   => $passive,
	      ftp       => $ftp);
  return bless { %opts },$class;
}

sub path {
  # return shift->{path};}
  my $p = $_[0]->{path};
  $_[0]->{path} = $_[1] if defined $_[1];
  $p;
}

sub ftp  {
  # return shift->{ftp}; }
  my $p = $_[0]->{ftp};
  $_[0]->{ftp} = $_[1] if defined $_[1];
  $p;
}

sub verbose {
  # return shift->{verbose}; }
  my $p = $_[0]->{verbose};
  $_[0]->{verbose} = $_[1] if defined $_[1];
  $p;
}

# top-level entry point for mirroring.
sub mirror {
  my $self = shift;
  $self->path(shift) if @_;
  my $path = $self->path;
  
  my $cd;
  if ($self->{localpath}) {
    chomp($cd = `pwd`);
    chdir($self->{localpath}) or croak "can't chdir to $self->{localpath}: $!";
  }

  my $type = $self->find_type($self->path) or croak "top level file/directory not found";
  my ($prefix,$leaf) = $path =~ m!^(.*?)([^/]+)/?$!;
  $self->ftp->cwd($prefix) if $prefix;

  my $ok;
  if ($type eq '-') {  # ordinary file
    $ok = $self->get_file($leaf);
  } elsif ($type eq 'd') {  # directory
    $ok = $self->get_dir($leaf);
  } else {
    carp "Can't parse file type for $leaf\n";
    return;
  }
  
  chdir $cd if $cd;
  $ok;
}

# mirror a file
sub get_file {
  my $self = shift;
  my ($path,$mode) = @_;
  my $ftp = $self->ftp;
  
  my $rtime = $ftp->mdtm($path);
  my $rsize = $ftp->size($path);
  $mode = ($self->parse_listing($ftp->dir($path)))[2] unless defined $mode;
  
  my ($lsize,$ltime) = stat($path) ? (stat(_))[7,9] : (0,0);
  if ( defined($rtime) and defined($rsize) 
       and ($ltime >= $rtime) 
       and ($lsize == $rsize) ) {
    $self->warning(-msg => "Getting file $path: not newer than local copy.") if $self->verbose;
    return 1;
  }

  $self->logit(-msg => "Downloading file $path");
  $ftp->get($path) or ($self->warning(-msg=>$ftp->message) and return);
  chmod $mode,$path if $mode;
}

# mirror a directory, recursively
sub get_dir {
  my $self = shift;
  my ($path,$mode) = @_;
  
  my $localpath = $path;
  -d $localpath or mkpath $localpath or carp "mkpath failed: $!" && return;
  chdir $localpath                   or carp "can't chdir to $localpath: $!" && return;
  $mode = 0755 if ($mode == 365); # Kludge-can't mirror non-writable directories
  chmod $mode,'.' if $mode;
  
  my $ftp = $self->ftp;
  
  my $cwd = $ftp->pwd                or carp("can't pwd: ",$ftp->message) && return;
  $ftp->cwd($path)                   or carp("can't cwd: ",$ftp->message) && return;
  
  $self->logit(-msg => "Downloading directory $path") if $self->verbose;

  foreach ($ftp->dir) {
    next unless my ($type,$name,$mode) = $self->parse_listing($_);
    next if $name =~ /^(\.|\.\.)$/;  # skip . and ..
    $self->get_dir ($name,$mode)    if $type eq 'd';
    $self->get_file($name,$mode)    if $type eq '-';
    $self->make_link($name)         if $type eq 'l';
  }
  
  $ftp->cwd($cwd)     or carp("can't cwd: ",$ftp->message) && return;
  chdir '..';
}

# subroutine to determine whether a path is a directory or a file
sub find_type {
  my $self = shift;
  my $path = shift;
  
  my $ftp = $self->ftp;
  my $pwd = $ftp->pwd;
  my $type = '-';  # assume plain file
  if ($ftp->cwd($path)) {
    $ftp->cwd($pwd);
    $type = 'd';
  }
  return $type;
}

# Attempt to mirror a link.  Only works on relative targets.
sub make_link {
  my $self = shift;
  my $entry = shift;
  
  my ($link,$target) = split /\s+->\s+/,$entry;
  return if $target =~ m!^/!;
  $self->logit(-msg => "Symlinking $link -> $target") if $self->verbose;
  return symlink $target,$link;
}

# parse directory listings 
# -rw-r--r--   1 root     root          312 Aug  1  1994 welcome.msg
sub parse_listing {
  my $self = shift;
  my $listing = shift;
  return unless my ($type,$mode,$name) =
    
    $listing =~ /^([a-z-])([a-z-]{9})  # -rw-r--r--
      \s+\d*                # 1
	(?:\s+\w+){2}         # root root
  \s+\d+                # 312
    \s+\w+\s+\d+\s+[\d:]+ # Aug 1 1994
      \s+(.+)               # welcome.msg
	$/x;           
  return ($type,$name,$self->filemode($mode));
}

# turn symbolic modes into octal
sub filemode {
  my $self = shift;
  my $symbolic = shift;
  
  my (@modes) = $symbolic =~ /(...)(...)(...)$/g;
  my $result;
  my $multiplier = 1;
  
  while (my $mode = pop @modes) {
    my $m = 0;
    $m += 1 if $mode =~ /[xsS]/;
    $m += 2 if $mode =~ /w/;
    $m += 4 if $mode =~ /r/;
    $result += $m * $multiplier if $m > 0;
    $multiplier *= 8;
  }
  $result;
}

__END__


=pod

=head1 NAME

Bio::GMOD::Util::Mirror - File and directory mirroring

=head1 SYNPOSIS

   my $mirror = Bio::GMOD::Util::Mirror->new(@opts);
   $mirror->mirror($path);

=head1 DESCRIPTION

Bio::GMOD::Util::Mirror is used to fetch files and directories in
order to keep a MOD installation up-to-date.

=head1 PRIVATE METHODS

=over 4

=item $mirror = Bio::GMOD::Util::Mirror->new(@opts);

Create a new Bio::GMOD::Util::Mirror object.

 Options:
 -host  Fully qualified hostname, minus protcol
 -path  Remote path or file to mirror
 -localpath  Local path to mirror into
 -user  FTP user if neeeded (defaults to anonymous)
 -pass  FTP pass if neeeded (defaults to anonymous@localhost)
 -passive Whether to use passive transfers
 -hash  FTP hashing algorithm

=item $mirror->mirror($path)

Mirror the $file or $path.  If $path is not provided, the path will be
culled from the object itself provided during object construction.

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

1;
