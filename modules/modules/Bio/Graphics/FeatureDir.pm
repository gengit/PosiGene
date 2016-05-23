package Bio::Graphics::FeatureDir;

=head1 NAME

Bio::Graphics::FeatureDir -- A directory of feature files and conf files

=head1 SYNOPSIS

 my $fd = Bio::Graphics::FeatureDir->new('/path/to/dir');
 $fd->add_file('tracks.conf');
 $fd->add_file('foo.gff3');
 $fd->add_file('foo.wig');
 $fd->add_fh(\*STDIN);
 
 my $option   = $fd->setting('EST' => 'bgcolor');
 my @features = $fd->get_features_by_name('M101');

=head1 DESCRIPTION

This class implements most of the methods of
Bio::Graphics::FeatureFile, but stores the data files and features in
a directory indexed by the Bio::DB::SeqFeature::Store::berkeleydb
adaptor. Therefore it is fast.

=head2 Methods

=over 4

=cut

use strict;
use warnings;
use base 'Bio::Graphics::FeatureFile';

use Bio::DB::SeqFeature::Store;
use File::Path;
use File::Spec;
use File::Basename 'basename';
use File::Temp 'tempdir','mktemp';
use Carp 'croak';

=item $fd = Bio::Graphics::FeatureDir->new('/path/to/dir');

=item $fd = Bio::Graphics::FeatureDir->new(-dir => '/path/to/dir');

Create a new FeatureDir, based in the indicated directory. In addition
to the -dir directory argument, it takes any of the options that can
be passed to Bio::Graphics::FeatureFile except for the -file and -text
arguments;

=cut

sub new {
    my $class = shift;
    my %args;
    if (@_ == 1) {
	%args = (-dir=>shift);
    } else {
	%args  = @_;
    }
    $args{-dir} ||= tempdir(CLEANUP=>1);
    delete $args{-file};
    delete $args{-text};

    my $self         = $class->SUPER::new(%args);
    $self->{dir}     = $args{-dir};
    $self->{verbose} = $args{-verbose};
    $self->_init_featuredb;
    $self->_init_conf;
    return $self;
}

=item $db->_init_featuredb

Internal method. Initializes the underlying feature database.

=cut

sub _init_featuredb {
    my $self = shift;
    my $dir  = $self->dir;
    my $needs_init = $self->_maybe_create_dir($dir);
    my $index = File::Spec->catfile($dir,"indexes");
    $needs_init++ unless -e $index;

    my @args = (-adaptor => 'berkeleydb',
		-dir     => $dir,
		-write   => 1,
	);
    push @args,(-create   => 1) if $needs_init;
    push @args,(-verbose  => 1) if $self->{verbose};

    $self->{db} = Bio::DB::SeqFeature::Store->new(@args)
	or die "Couldn't initialize database";
    return $self->{db};
}

=item $db->_init_conf

Internal method -- initialize the configuration file(s)

=cut

sub _init_conf {
    my $self        = shift;
    my $dir         = $self->dir;
    my $needs_init  = $self->_maybe_create_dir($dir);
    my $master_conf = File::Spec->catfile($dir,'indexes','master.conf');
    $needs_init++   unless -e $master_conf;
    if ($needs_init) {
	open my $fh,'>',$master_conf or die "$master_conf: $!";
	my $pack = __PACKAGE__;
	print $fh <<END;
[GENERAL]
description = Master configuration file created by $pack.

#include "../*.conf";
END
    close $fh;
    }
    $self->{conf} = Bio::Graphics::FeatureFile->new(-file=>$master_conf);
}

=item $created = $db->_maybe_create_dir($dir)

Create $dir and its parents if it doesn't exist. Return true if the directory
was created. Throws an exception on filesystem errors.

=cut

sub _maybe_create_dir {
    my $self = shift;
    my $dir  = shift || $self->{dir};
    unless (-e $dir && -d $dir) {
	mkpath($dir) or die "Couldn't create directory $dir: $!";
	return 1;
    }
    return;
}


=item $dir = $db->dir

Returns the base directory.

=cut

sub dir {shift->{dir}}

=item $conf = $db->conf

Returns the underlying Bio::Graphics::FeatureFile object

=cut

sub conf {shift->{conf}}

=back

=item $db = $db->db

Returns the underlying Bio::DB::SeqFeature::Store object

=cut

sub db {
    my $self = shift;
    return $self->{db} ||= Bio::DB::SeqFeature::Store->new(
	-adaptor => 'berkeleydb',
	-dir     => $self->dir,
	-write   => 1);
}

=item $db->add_file($file)

Add the file to the directory. Can add files of type .fa, .gff, .gff3,
.conf and .ff.

=cut

sub add_file {
    my $self = shift;
    my $file = shift;
    my $basename = basename $file;
    open my $fh,$file or croak "Couldn't open $file: $!";
    $self->add_fh($fh,$basename);
    close $fh;
}

=item $db->add_fh(\*FILEHANDLE [,'name'])

Add the contents of the indicated filehandle to repository.  Name is
optional; if provided it will be used as the base for all files
created.

=cut

sub add_fh {
    my $self       = shift;
    my ($fh,$name) = @_;
    $name   =~ s/\.\w+$//; # get rid of extensions
    $name ||=  mktemp('XXXXXXXX');

    # status == unknown
    #           config
    #           gff3
    #           gff2
    #           ff
    #           wiggle
    #           fasta
    my ($status,$new_status);
    my $dir = $self->dir;
    my %splitter;
    
    while (<$fh>) {
	# figure out transitions
	$new_status = /^\#\#gff-version\s+3/i ? 'gff3'
	             :/^\#\#gff/i             ? 'gff2'
	             : /^track/i              ? 'wig'
		     : /^\[(.+)\]/i             ? 'conf'
		     : /^>\w+/i               ? 'fa'
		     : /^reference/i          ? 'ff'
		     : undef;

	unless ($status || $new_status) {  # guess what it is
	    my @tokens = split /\s+/;
	    $new_status = 'gff3' if @tokens >= 9 && $tokens[8] =~ /=/;
	    $new_status = 'ff'   if $tokens[2] =~ /\d+(\.\.|-)\d+/;
	}

	

	if ($new_status) {
	    # this will create a new conf file for each section
	    if ($new_status eq 'conf') {
		$splitter{conf} = Bio::Graphics::FileSplitter->new(
		    File::Spec->catfile($dir,"${name}.$1.${new_status}"));
	    }
	    else {
		$splitter{$new_status} ||= Bio::Graphics::FileSplitter->new(
		    File::Spec->catfile($dir,"${name}.${new_status}"));
	    }

	    $status = $new_status;
	}

	next unless $splitter{$status};
	$splitter{$status}->write($_);
    }
    undef %splitter;
    $self->db->auto_reindex($dir);
    $self->_init_conf;
}

package Bio::Graphics::FileSplitter;

sub new {
    my $class = shift;
    my $path  = shift;
    open my $fh,'>',$path or die "Could not open $path for writing: $!";
    return bless {fh=>$fh},ref $class || $class;
}
sub write {
    my $self = shift;
    $self->{fh}->print($_) foreach @_;
}
sub DESTROY {
    my $fh = shift->{fh};
    close $fh if $fh;
}

=cut

=head1 SEE ALSO

L<Bio::Graphics::Feature>,
L<Bio::Graphics::FeatureFile>

=head1 AUTHOR

Lincoln Stein E<lt>lincoln.stein@gmail.comE<gt>.

Copyright (c) 2009 Ontario Institute for Cancer Research

This package and its accompanying libraries is free software; you can
redistribute it and/or modify it under the terms of the GPL (either
version 1, or at your option, any later version) or the Artistic
License 2.0.  Refer to LICENSE for the full license text. In addition,
please see DISCLAIMER.txt for disclaimers of warranty.

=cut


1;
