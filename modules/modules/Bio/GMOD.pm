package Bio::GMOD;

use strict;
use warnings;
use vars qw/@ISA $VERSION/;

use Bio::GMOD::Util::Status;
use Bio::GMOD::Util::Rearrange;

@ISA = qw/Bio::GMOD::Util::Status/;

$VERSION = '0.028';

sub new {
  my ($self,@p) = @_;
  my ($requested_mod,$class,$overrides) = rearrange([qw/MOD CLASS/],@p);

  # Establish a generic GMOD object. This is largely used
  # for situations when we want to work across all MODs.
  unless ($requested_mod) {
    my $this = bless {},$self;
    return $this;
  }

  my $mod  = ($self->supported_mods($requested_mod)) ? $requested_mod : 0;
  $mod = $self->species2mod($requested_mod)  unless $mod;
  $mod = $self->organism2mod($requested_mod) unless $mod;

  $self->logit(-msg => "The supplied mod $requested_mod is not a currently available MOD.",
	       -die => 1) unless $mod;

  my $adaptor_class = "Bio::GMOD::Adaptor::$mod";
  eval "require $adaptor_class" or $self->logit(-msg=>"Could not subclass $adaptor_class: $!",-die=>1);
  my $adaptor = $adaptor_class->new($overrides);
  my $name = $adaptor->name;
  my $this = {};

  # Establish generic subclassing for the various top level classes
  # This assumes that none of these subclasses will require their own new()
  my $subclass = "$self" . "::$name";
  if ($class) {  # Force a specific class
    bless $this,$class;
  } elsif ($name && eval "require $subclass" ) {
    bless $this,$subclass;
  } else {
    bless $this,$self;
  }

  $this->{adaptor} = $adaptor;
  $this->{mod}     = $mod;
  return $this;
}

sub species2mod {
  my ($self,$provided_species) = @_;
  my %species2mod = (
		     elegans      => 'WormBase',
		     briggsae     => 'WormBase',
		     remanei      => 'WormBase',
		     japonica     => 'WormBase',
		     melanogaster => 'FlyBase',
		     cerevisae    => 'SGD',
		     dictyostelium => 'DictyBase',
		    );
  return ($species2mod{$provided_species}) if defined $species2mod{$provided_species};

  # Maybe someone has used Genus species or G. species
  foreach my $species (keys %species2mod) {
    return $species2mod{$species} if ($provided_species =~ /$species/);
  }
  return 0;
}

sub organism2mod {
  my ($self,$organism) = @_;
  my %organism2mod = (
		      worm      => 'WormBase',
		      nematode  => 'WormBase',
		      fruitfly  => 'FlyBase',
		      fly       => 'FlyBase',
		      yeast     => 'SGD',
		      slime     => 'DictyBase',
		    );
  return ($organism2mod{$organism}) if defined $organism2mod{$organism};
  return 0;
}

# ACCESSORS
sub adaptor { return shift->{adaptor}; }
sub mod     { return shift->{mod};     }
sub biogmod_version { return $VERSION };



#### WORK IN PROGRESS!  HARD HATS REQUIRED! ####
## This is a stab at implementing a multi-MOD object
## within the current structure...
## It's not done yet...
sub new_alterantive {
  my ($self,@p) = @_;
  my ($mod,$class,$overrides) = rearrange([qw/MOD CLASS/],@p);

  # Establish a generic GMOD object. This is largely used
  # for situations when we want to work across all MODs.
  my $this = {};
  unless ($mod) {
    # Instantiate adaptors to all the MODs
    bless $this,$self;
    map { $this->instatiate_adaptor($_,$overrides) } $this->supported_mods();
    return $this;
  }

  # If more than a single MOD is supplied, let's assume that
  # the user wants to do comparative tasks between MODs.
  # Instatiate adaptors for all the requested MODs

  # If a single MOD is supplied, let's assume the task is something
  # that applies to a single MOD, like doing updates or archives.
  if (ref $mod) {
    map { $this->instatiate_adaptor($_,$overrides) } @$mod;
    $this = bless {},$self;
  } else {
    my $adaptor = $self->instatiate_adaptor($_,$overrides);
    my $name = $adaptor->name;

    # Establish generic subclassing for the various top level classes
    # This assumes that none of these subclasses will require their own new()
    my $subclass = "$self" . "::$name";
    if ($class) {  # Force a specific class (ooh, when is this used)?
      bless $this,$class;
    } elsif ($name && eval "require $subclass" ) {
      bless $this,$subclass;
    } else {
      bless $this,$self;
    }

    # For ease of access, store this primary MOD as adaptor
    $this->{adaptor} = $adaptor;
    $this->{mod} = $mod;
  }
  return $this;
}

# Instatiate a new adaptor if necessary;
# If not just return an old one.
sub instatiate_adaptor {
  my ($self,$requested_mod,$overrides) = @_;
  my $mod  = ($self->supported_mods($requested_mod)) ? $requested_mod : 0;
  $mod = $self->species2mod($requested_mod)  unless $mod;
  $mod = $self->organism2mod($requested_mod) unless $mod;
  my $adaptor = $self->adaptor($mod);
  unless ($adaptor) {
    $self->logit(-msg => "The supplied mod $_ is not a currently available MOD.",
		 -die => 1) unless $mod;
    my $adaptor_class = "Bio::GMOD::Adaptor::$mod";
    eval "require $adaptor_class" or $self->logit(-msg=>"Could not subclass $adaptor_class: $!",-die=>1);
    $adaptor = $adaptor_class->new($overrides);
    my $name = $adaptor->name;
    $self->{adaptors}->{$name} = $adaptor;
  }
  return $adaptor;
}

# Return a list of supported mods
# These should correspond to symbolic names that are used
# as module names
sub supported_mods {
  my ($self,$mod) = @_;
  my %mods = (
	      WormBase => 1,
	      FlyBase   => 1
	     );
  unless ($mod) {
    return [ keys %mods ];
  }
  return 1 if defined $mods{$mod};
  return 0;
}

############ END WORK IN PROGRESS ##############

1;

=pod

=head1 NAME

Bio::GMOD - Unified API for Model Organism Databases

=head1 SYNOPSIS

Check the installed version of a MOD

  use Bio::GMOD::Util::CheckVersions.pm
  my $mod     = Bio::GMOD::Util::CheckVersions->new(-mod=>'WormBase');
  my $version = $mod->live_version;

Update a MOD installation

  use Bio::GMOD::Update;
  my $mod = Bio::GMOD::Update->new(-mod=>'WormBase');
  $gmod->update();

Fetch a list of genes from a MOD

  use Bio::GMOD::Query;
  my $mod = Bio::GMOD::Query->new(-mod=>'WormBase');
  my @genes = $mod->fetch(-class=>'Gene',-name=>'unc-26');

=head1 DESCRIPTION

Bio::GMOD is a unified API for accessing various Model Organism
Databases.  It is a part of the Generic Model Organism Database
project, as well as distributed on CPAN.

MODs are highly curated resources of biological data. Although they
typically incorporate sequence data housed at community repositories
such as NCBI, they place this information within a framework of
biological fuction gelaned from the published literature of
experiments in model organisms.

Given the great proliferation of MODs, cross-site data mining
strategies have been difficult to implement.  Such strategies
typically require a familiarity with both the underlying data model
and the historical vocabulary of the model system.

Furthermore, the quickly-evolving nature of these projects have made
installing a MOD locally and keeping it up-to-date a delicate and
time-consuming experience.

Bio::GMOD aims to solve these problems by:

   1.  Enabling cross-MOD data mining through a unified API
   2.  Insulating programmatic end users from model changes
   3.  Making MODs easy to install
   4.  Making MODs easy to upgrade

=head1 PUBLIC METHODS

=over 4

=item Bio::GMOD->new(@options)

 Name          : new()
 Status        : public
 Required args : mod || organism || species
 Optional args : hash of system defaults to override
 Returns       : Bio::GMOD::* object as appropriate, with embedded
                 Bio::GMOD::Adaptor::* object

Bio::GMOD->new() is the generic factory new constructor for all of
Bio::GMOD.pm (with the exception of Bio::GMOD::Adaptor, discussed
elsewhere).  new() will create an object of the appropriate class,
including dynamic subclassing when necessary, as well as initializing
an appropriate default Bio::GMOD::Adaptor::* object.

 Options:
 -mod       The symbolic name of the MOD to use (WormBase, FlyBase, SGD, etc)
 -class     Force instantiation of a specific class (eg see Bio::GMOD::Monitor)

Any additional options, passed in the named parameter "-name => value"
style will automatically be considered to be default values specific
to the MOD adaptor of choice.  These values will be parsed and loaded
into the Bio::GMOD::Adaptor::"your_mod" object.  A corresponding accessor
method (ie $adaptor->name) will be generated.  See Bio::GMOD::Adaptor for
additional details.

if "--mod" is not specified, adaptors to all available MODs will be
instantiated.  Note that this probably does not make sense for classes
like Update::*.  It does provide a convenient mechanism to iteract
with all MODs without too much extra coding.  You can also specify a
subset of MODs.  Specifying a single MOD has special behavior fo use
in things like updates.

=item $self->species2mod($species);

 Name          : species2mod($species)
 Status        : public
 Required args : a species name
 Optional args : none
 Returns       : a MOD name as string

Provided with a single species, return the most appropriate MOD name.
Species can be in the form of "G. species", "Genus species", or simple
"species" for the lazy.

  eg:
  my $mod = $self->_species2mod('elegans');
  # $mod contains 'WormBase'

=item $self->organism2mod($organism)

 Name          : organism2mod($organism)
 Status        : public
 Required args : a general organism name
 Optional args : none
 Returns       : a MOD name as string

Like species2mod(), _organism2mod translates a general organism into
the most appropriate hosting MOD.

  eg:
  my $mod = $self->_organism2mod('nematode');
  # $mod contains 'WormBase'

=back

=head1 NOTES FOR DEVELOPERS

Bio::GMOD.pm uses a generically subclass-able architecture that lets
MOD developers support various features as needed or desired.  For
example, a developer may wish to override the default methods for
Update.pm by building a Bio::GMOD::Update::FlyBase package that
provides an update() method, as well as various supporting methods.

Currently, the only participating MOD is WormBase.  The author hopes
that this will change in the future!

=head1 BUGS

None reported.

=head1 SEE ALSO

L<Bio::GMOD::Update>, L<Bio::GMOD::Adaptor>

=head1 AUTHOR

Todd W. Harris E<lt>harris@cshl.orgE<gt>.

Copyright (c) 2003-2005 Cold Spring Harbor Laboratory.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 ACKNOWLEDGEMENTS

Much thanks to David Craig (dacraig@stanford.edu) for extensive alpha
testing.

=cut
