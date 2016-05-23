package Bio::Das::Segment;

# $Id: Segment.pm,v 1.26 2010/06/29 19:42:48 lstein Exp $
use strict;
use Bio::Root::Root;
use Bio::Das::SegmentI;
use Bio::Das::Util 'rearrange';
use File::Basename 'basename';
use Data::Dumper 'Dumper';
use File::Spec;
use File::Path 'mkpath';
use vars qw(@ISA $VERSION);
@ISA = qw(Bio::Root::Root Bio::Das::SegmentI);

$VERSION = 0.91;

use overload '""' => 'asString';
*abs_ref   = *refseq = \&ref;
*abs_start = \&start;
*abs_end   = *stop   = \&end;
*abs_strand= \&strand;
*toString = \&asString;

use constant DEBUG=>0;

sub new {
  my $pack = shift;
  my ($ref,$start,$stop,$version,$das,$dsn) = @_;
  return bless {ref    =>$ref,
		start  =>$start,
		end    =>$stop,
		version=>$version,
		das    =>$das,
		dsn    =>$dsn,
	       },$pack;
}

sub das { shift->{das}    }
sub dsn {
  my $self = shift;
  $self->{dsn};
}
sub method { 'segment' }
sub source { 'das'     }
sub attributes { }

sub features {
  my $self = shift;

  my $das = $self->das;
  my $dsn = $self->dsn;
  my @args;
  unless (defined $_[0] && $_[0] =~ /^-/) {
    if (@_) {
      @args = (-types => \@_);
    } else {
      my $types       = $self->autotypes;
      my $categories  = $self->autocategories;
      push @args,(-types   => $types)      if $types;
      push @args,(-category=> $categories) if $categories;
    }
  } else {
    @args = @_;
  }
  return $das->features(@args,
			-dsn => $dsn,
			-segment=> [$self]);
}

sub get_seq_stream {
    my $self = shift;
    my @args = @_;
    return $self->features(@args,-iterator=>1);
}

sub source_tag {
  return shift()->dsn;
}

sub autotypes {
  my $self = shift;
  my $d  = $self->{autotypes};
  $self->{autotypes} = shift if @_;
  $d;
}

sub autocategories {
  my $self = shift;
  my $d  = $self->{autocategories};
  $self->{autocategories} = shift if @_;
  $d;
}

sub sequence {
  my $self = shift;
  my $das = $self->das;
  my $dsn = $self->dsn;
  return $das->sequence(@_,
		   -dsn    => $dsn,
		   -segment=> [$self->asString]);
}

sub dna {
  my $self = shift;
  my $das = $self->das;
  my $dsn = $self->dsn;
  return $das->dna(@_,
		   -dsn    => $dsn,
		   -segment=> [$self->asString]);
}

sub types {
  my $self = shift;
  my $das = $self->das or return;
  my $dsn = $self->dsn or return;
  return $das->types(@_,
		     -dsn    => $dsn,
		     -segment=> [$self->asString]);
}

sub ref      {
  my $self = shift;
  my $d    = $self->{ref};
  $self->{ref} = shift if @_;
  $d;
}
sub start      {
  my $self = shift;
  my $d    = $self->{start};
  $self->{start} = shift if @_;
  $d;
}
sub end      {
  my $self = shift;
  my $d    = $self->{end};
  $self->{end} = shift if @_;
  $d;
}
sub strand { 0 }
sub target {   }
sub score  {   }
sub merged_segments  {   }
sub length {
  my $self = shift;
  $self->end-$self->start+1;
}
sub version      {
  my $self = shift;
  my $d    = $self->{version};
  $self->{version} = shift if @_;
  $d;
}
sub size     {
  my $self = shift;
  my $d    = $self->{size};
  $self->{size} = shift if @_;
  $d ||= $self->end-$self->start+1;
  $d;
}
sub class      {
  my $self = shift;
  my $d    = $self->{class};
  $self->{class} = shift if @_;
  $d;
}
sub orientation {
  my $self = shift;
  my $d    = $self->{orientation};
  $self->{orientation} = shift if @_;
  $d;
}
sub subparts {
  my $self = shift;
  my $d    = $self->{subparts};
  $self->{subparts} = shift if @_;
  $d;
}
sub asString {
  my $self = shift;
  my $string = $self->{ref};
  return "global" unless $string;
  $string .= ":$self->{start}" if defined $self->{start};
  $string .= ",$self->{end}"   if defined $self->{end};
  $string;
}


## Added for gbrowse interface
sub factory {
  return shift->das;
}

## Added for gbrowse interface
sub name {
  my $self = shift;
  my $d = $self->{name};
  $self->{name} = shift if @_;
  $d || $self->toString();
}

sub display_name {
  shift->name;
}

## Added for gbrowse interface
sub info {
  my $self = shift;
  my $d = $self->{info};
  $self->{info} = shift if @_;
  return $d || "";
}

sub get_SeqFeatures { return }

## Added for gbrowse interface
sub seq_id {
  return shift->ref( @_ );
}

## Added for gbrowse interface
sub seq {
  return shift->dna( @_ );
}

# so that we can pass a whole segment to Bio::Graphics
sub type { 'Segment' }

sub mtime { 0 }

sub refs { }

# this is working
sub render {
  my $self = shift;
  my ($panel,$position_to_insert,$options,$max_bump,$max_label) = @_;

  $max_bump  = 50 unless defined $max_bump;
  $max_label = 50 unless defined $max_label;
  $options   = 0  unless defined $options;
  $panel->key_style('between') if $panel->key_style eq 'bottom'; # bottom key doesn't work with stylesheets

  my @COLORS = qw(cyan blue red yellow green wheat turquoise orange);

  # cache stylesheet
  my $stylesheet = $self->get_cached_stylesheet;

  my @override = $options && CORE::ref($options) eq 'HASH' ? %$options : ();
  my @new_tracks;

  my (%type_count,%tracks,%track_configs,$color);
  my @f = $self->features;
  for my $feature (@f) {

      warn "rendering $feature type = ",$feature->type," category = ",$feature->category if DEBUG;
      warn "subtypes = ",join ' ',map {$_->type} $feature->get_SeqFeatures if DEBUG;

    my $type      = $feature->type;
    my $track_key = $type;
    my $label     = $type->label || $type->method_label;
    $track_key   .= ": ".$label if $label;

    $type_count{$type}++;
    if (my $track = $tracks{$type}) {
      $track->add_feature($feature);
      next;
    }

    my @config = (
	-bgcolor    => $COLORS[$color++ % @COLORS],
	-label      => 1,
	-key        => $track_key,
	-stylesheet => $stylesheet,
	-glyph      => 'line',
	);


      eval {
	  if (defined($position_to_insert)) {
	      push @new_tracks,($tracks{$type} = 
				$panel->insert_track($position_to_insert++,$feature,@config));
	  } else {
	      push @new_tracks,($tracks{$type} = 
				$panel->add_track($feature,@config));
	  }
      };
      warn $@ if $@;
  }

  # reconfigure bumping, etc
  for my $type (keys %type_count) {
    my $type_count = $type_count{$type};
    my $do_bump    = defined $track_configs{$type}{-bump} ? $track_configs{$type}{-bump}
                                                          : $options == 0 ? $type_count <= $max_bump
							  : $options == 1 ? 0
							  : $options == 2 ? 1
							  : $options == 3 ? 1
							  : $options == 4 ? 2
							  : $options == 5 ? 2
							  : 0;

    my $maxed_out  = $type_count > $max_label;
    my $conf_label = defined $track_configs{$type}{-label} 
                             ? $track_configs{$type}{-label}
                             : 1;

    my $do_label   =   $options == 0 ? !$maxed_out && $conf_label
                     : $options == 3 ? 1
		     : $options == 5 ? 1
		     : 0;
    # warn "type = $type, label = $do_label, do_bump = $do_bump";

    my $track = $tracks{$type};

    my $factory = $track->factory;
    $factory->set_option(connector  => 'none') if !$do_bump;
    $factory->set_option(bump       => $do_bump);
    $factory->set_option(label      => $do_label);
  }
  my $track_count = keys %tracks;
  return wantarray ? ($track_count,$panel,\@new_tracks) : $track_count;
}

sub get_cached_stylesheet {
    my $self    = shift;
    my $tmpdir  = File::Spec->tmpdir;
    my $program = basename($0);
    my $user    = (getpwuid($>))[0];
    my $url     = $self->das->name.'/stylesheet';
    foreach ($program,$user,$url) {
	tr/a-zA-Z0-9_-/_/c;
    }

    my $dir  = File::Spec->catfile($tmpdir,"$program-$user");
    mkpath($dir) or die "$dir: $!" unless -d $dir;
    my $path = File::Spec->catfile($dir,$url);

    my $stylesheet;

    eval {

	# cache for 5 minutes
	my $mtime = (stat($path))[9];
	if ($mtime && ((time() - $mtime)/60) < 5.0) {
	    open my $f,'<',$path or die "$path: $!";
	    my $s;
	    $s .= $_ while <$f>;
	    close $f;
	    my $VAR1;
	    $stylesheet = eval "$s; \$VAR1";
	    warn $@ if $@;
	    utime undef,undef,$path;
	}
	
	else {
	    $stylesheet = $self->das->stylesheet;
	    my $d = Data::Dumper->new([$stylesheet]);
	    $d->Purity(1);
	    open my $f,">",$path or die "$path: $!";
	    print $f $d->Dump;
	    close $f;
	}
    
	return $stylesheet;
    };

    # something went wrong, so revert to non-cached behavior
    return $self->das->stylesheet;
}

1;

__END__

=head1 NAME

Bio::Das::Segment - Serial access to Bio::Das sequence "segments"

=head1 SYNOPSIS

   # SERIALIZED API
   my $das = Bio::Das->new(-server => 'http://www.wormbase.org/db/das',
                           -dsn    => 'elegans',
                           -aggregators => ['primary_transcript','clone']);
   my $segment  = $das->segment('Chr1');
   my @features = $segment->features;
   my $dna      = $segment->dna;

=head1 DESCRIPTION

The Bio::Das::Segment class is used to retrieve information about a
genomic segment from a DAS server. You may retrieve a list of
(optionally filtered) annotations on the segment, a summary of the
feature types available across the segment, or the segment's DNA
sequence.

=head2 OBJECT CREATION

Bio::Das::Segment objects are created by calling the segment() method
of a Bio::Das object created earlier.  See L<Bio::Das> for details.

=head2  OBJECT METHODS

Once created, a number of methods allow you to query the segment for
its features and/or DNA.

=over 4

=item $ref= $segment->ref

Return the reference point that establishes the coordinate system for
this segment, e.g. "chr1".

=item $start = $segment->start

Return the starting coordinate of this segment.

=item $end = $segment->end

Return the ending coordinate of this segment.

=item @features = $segment->features(@filter)

=item @features = $segment->features(-type=>$type,-category=>$category)

The features() method returns annotations across the length of the
segment.  Two forms of this method are recognized.  In the first form,
the B<@filter> argument contains a series of category names to
retrieve.  Each category may be further qualified by a regular
expression which will be used to filter features by their type ID.
Filters have the format "category:typeID", where the category and type
are separated by a colon.  The typeID and category names are treated
as an unanchored regular expression (but see the note below).  As a
special cse, you may use a type of "transcript" to fetch composite
transcript model objects (the union of exons, introns and cds
features).

Example 1: retrieve all the features in the "similarity" and
"experimental" categories:

  @features = $segment->features('similarity','experimental');

Example 2: retrieve all the similarity features of type EST_elegans
and EST_GENOME:

  @features = $segment->features('similarity:EST_elegans','similarity:EST_GENOME');

Example 3: retrieve all similarity features that have anything to do
with ESTs:

  @features = $segment->features('similarity:EST');

Example 4: retrieve all the transcripts and experimental data

  @genes = $segment->features('transcript','experimental')

In the second form, the type and categories are given as named
arguments.  You may use regular expressions for either typeID or
category.  It is also possible to pass an array reference for either
argument, in which case the DAS server will return the union of the
features.

Example 5: retrieve all the features in the "similarity" and
"experimental" categories:

  @features = $segment->features(-category=>['similarity','experimental']);

Example 6: retrieve all the similarity features of type EST_elegans
and EST_GENOME:

  @features = $segment->features(-category=>'similarity',
                                 -type    =>/^EST_(elegans|GENOME)$/
                                 );

=item $dna = $segment->dna

Return the DNA corresponding to the segment.  The return value is a
simple string, and not a Bio::Sequence object.  This method may return
undef when used with a DAS annotation server that does not maintain a
copy of the DNA.

=item @types = $segment->types

=item $count = $segment->types($type)

This methods summarizes the feature types available across this
segment.  The items in this list can be used as arguments to
features().

Called with no arguments, this method returns an array of
Das::Segment::Type objects.  See the manual page for details.  Called
with a TypeID, the method will return the number of instances of the
named type on the segment, or undef if the type is invalid.  Because
the list and count of types is cached, there is no penalty for
invoking this method several times.

=back


=head1 AUTHOR

Lincoln Stein <lstein@cshl.org>.

Copyright (c) 2003 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=head1 SEE ALSO

L<Bio::Das>

=cut
