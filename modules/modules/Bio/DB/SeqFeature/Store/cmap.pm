package Bio::DB::SeqFeature::Store::cmap;

# $Id: cmap.pm,v 1.7 2008/07/01 17:24:58 mwz444 Exp $

=head1 NAME

Bio::DB::SeqFeature::Store::cmap -- A CMap adaptor for importing data

=head1 SYNOPSIS

  use Bio::DB::SeqFeature::Store;

  # Open the sequence database
  my $db = Bio::DB::SeqFeature::Store->new(-adaptor => 'cmap',
                                            -data_source => 'CMAP_DATASOURCE',

  my $loader = Bio::DB::SeqFeature::Store::GFF3Loader->new(
    -store   => $store,
    -verbose => 1,
    -fast    => 0
  );

  $loader->load($file_name);

=head1 DESCRIPTION

Bio::DB::SeqFeature::Store::cmap is a partially implemented CMap adaptor for
Bio::DB::SeqFeature::Store. You will not create it directly, but instead use
Bio::DB::SeqFeature::Store-E<gt>new() to do so.

It is intended only to parse GFF3 files.

See L<Bio::DB::SeqFeature::Store> for complete usage instructions.

=head2 Using the Mysql adaptor

  Argument name       Description
  -------------       -----------

 -data_source      The CMap data source which is used to let CMap know which 
                   configuration file to use.

If successful, a new instance of
Bio::DB::SeqFeature::Store::cmap will be returned.


=head1 CMap GFF Specification

=head2 Description

The CMap GFF file format was created as a way to express an entire CMap
datasource in a simple, single file.  It is an extension of GFF3 and therefor
produces legal GFF3 for use with GBrowse or any other program that can read
GFF3.

This format should have the following advantages:

=over 4

=item * All data can be in a single file (or spread between multiple files)

=item * The import uses the API so data base structural changes won't affect it.

=item * GFF3 is a simple and well known standard making this an easier format to learn.

=back

CMap GFF introduces several new pragmas (lines that start with "##") to encode
information including species, map set and correspondences.  The order of these
pragmas are important as a map set will be added to the last defined species
and features will be added to maps in the last defined map set.

It's important to note that odd characters need to be URI escaped.  For
example, '=' becames '%3D'.

The GFF3 specification can be found here: http://song.sourceforge.net/gff3.shtml

=head2 Example

The following is an example CMap GFF file

 ##gff-version 3
 ##cmap-gff-version 1
 ##cmap_species  species_acc=rice08;species_full_name=Oriza sativa;species_common_name=Rice;display_order=1;
 ###
 ##cmap_map_set map_set_acc=MS1;map_set_name=testlong1;map_set_short_name=testshort1;map_type_acc=Seq;unit_modifier=1

 ##cmap_map map_acc=ms1_Contig1;map_name=Contig1;map_start=1;map_stop=8970;display_order=2;map_set_acc=MS1;
 ##sequence-region   Contig1 1   8970  
 Contig1	CMap	marker	1701	1701	.	+	.	ID=marker00001;Name=marker1;Alias=mymarker1
 Contig1	CMap	marker	1401	1401	.	+	.	ID=marker00002;Name=marker2;Alias=mymarker2;attribute=Description:This marker is really important
 Contig1	CMap	marker	7701	7701	.	+	.	ID=marker00003;Name=marker3;Alias=mymarker3;corr_by_id=marker00006 shared_marker

 ###
 ##cmap_map_set map_set_acc=MS2;map_set_name=testlong2;map_set_short_name=testshort2;map_type_acc=Seq;species_acc=rice08;unit_modifier=1
 ##cmap_map map_acc=ms2_Contig1;map_name=Contig1;map_start=1;map_stop=10000;display_order=2;map_set_acc=MS2;
 ##sequence-region   Contig1 1   10000  
 Contig1	CMap	marker	1801	1801	.	+	.	ID=marker00004;Name=marker1;Alias=mymarker1;corr_by_id=marker00001 shared_marker
 Contig1	CMap	marker	1601	1601	.	+	.	ID=marker00005;Name=marker2;Alias=mymarker2;xref=Google:http%3A%2F%2Fwww.google.com%2Fsearch%3Fq%3Dmarker2
 Contig1	CMap	marker	7601	7601	.	+	.	ID=marker00006;Name=marker3;Alias=mymarker3;corr_by_id=marker00003 shared_marker
 
 ##cmap_attribute  object_type=feature;feature_name=marker1;map_name=Contig1;map_set_acc=MS2;attribute_value=This is a cool marker%2C too.;attribute_name=Descrption
 ##cmap_attribute  object_type=feature;ID=marker00006;attribute_value=This is a cool marker%2C as well.;attribute_name=Descrption
 ##cmap_attribute  object_type=map;map_name=Contig1;map_set_acc=MS2;attribute_value=This is a map in the second map set.;attribute_name=Descrption

 ##cmap_xref  object_type=feature;feature_name=marker2;map_name=Contig1;map_set_acc=MS1;xref_url=http%3A%2F%2Fwww.google.com%2Fsearch%3Fq%3Dmarker2;xref_name=Google

 ##cmap_corr  evidence_type_acc=shared_marker;feature_name1=marker2;map_name1=Contig1;map_set_acc=MS1;ID2=marker00005

=head2 Species

=head3 Description

The ##cmap_species pragma sets the current species that will dictate which
species new map sets that follow are associated with.  If the species is not
already in the database and enough information is given, it will be created.

=head3 Definition

  ##cmap_species definition_string

The definition string is a list of key=value pairs separated by a semi-colon.
An example is "species_full_name=Oriza sativa;species_common_name=Rice;". 

=head3 Options

  species_acc* 
  species_common_name*+
  species_full_name*+
  display_order 

 + required for creation
 * used for identification of species already in the database

=head3 Examples

  # Full Species description
  ##cmap_species  species_acc=rice08;species_full_name=Oriza sativa;species_common_name=Rice;display_order=1; 

  # Just enough to create or find a species already in db
  ##cmap_species  species_full_name=Oriza sativa;species_common_name=Rice;

  # Find a species already in the db
  ##cmap_species  species_acc=rice08;
  ##cmap_species  species_full_name=Oriza sativa;

=head2 Map Set

=head3 Description

The ##cmap_map_set pragma sets the current map set that will dictate which map
set maps and features that follow are associated with.  This must be set before
importing any features or maps.  If the map set is not already in the database
and enough information is given, it will be created.

=head3 Definition

  ##cmap_map_set definition_string

The definition string is a list of key=value pairs separated by a semi-colon.
An example is "". 

=head3 Options

  map_set_name*+
  map_set_short_name*+
  map_type_acc*+
  map_set_acc
  display_order
  shape
  color
  width
  published_on
  is_relational_map
  species_acc#
  species_common_name#
  species_full_name#
  unit_modifier&


 + required for creation
 * used for identification of a map set already in the database
 # Species information is not required if the current species has been set by
   the ##cmap_species pragma (see above).  Otherwise, just enough information
   to identify the species is required.
 & See the Unit Modifier section below

=head3 Unit Modifier

The unit_modifier option is used to modify the start and stop positions of maps
and features.  Because GFF requires start and stops to be integers, when
creating a CMap GFF file, the values are devided by the unit_granularity.  

For instance, a feature start of 58.23 with a unit granularity of 0.01 will be
output as 5823.  The unit modifier (which is the same value as the unit
granularity) is used to return that value back to the original.

The unit_modifier is stored in the ##cmap_map_set pragma and will affect any
maps in that map set that immediately follow.

If no unit_modifier is specified, it will default to 1 (which leaves the values
as they are).

=head3 Examples

  # Enough create or set a map set if it has been preceded by a ##cmap_species pragma 
  ##cmap_map_set map_set_name=Sample Map Set;map_set_short_name=Sample;map_type_acc=Seq;map_set_acc=SampleMS1
  ##cmap_map_set map_set_name=Sample Map Set;map_set_short_name=Sample;map_type_acc=Seq;unit_modifier=1
  
  # Create or set map set and select species
  ##cmap_map_set map_set_name=Sample Map Set;map_set_short_name=Sample;map_type_acc=Seq;species_acc=rice08
  ##cmap_map_set map_set_name=Sample Map Set2;map_set_short_name=Sample2;map_type_acc=Genetic;species_common_name=Rice;unit_modifier=0.01

  # Find a Map Set already in the db
  ##cmap_map_set map_set_name=Sample Map Set;unit_modifier=1
  ##cmap_map_set map_set_acc=SampleMS1;unit_modifier=1

=head3 Important Note

When starting a new map set in the same file, you must use the "###" pragma
to clear the previous map sets features.  Otherwise the uncomputed features
will be lost or worse, placed on a map in the new map set.  In general it is
safest to place a "###" on the line above a new map set.

 ###
 ##cmap_map_set map_set_name=Sample Map Set;map_set_short_name=Sample;map_type_acc=Seq;

=head2 Map

=head3 Description

To create a map a current map set must be set by using the ##cmap_map_set
pragma (or specified in the ##cmap_map pragma described later).   

Use the ##sequence-region pragma to define a map which is defined in the GFF3
specification as "##sequence-region seqid start end".  The seqid will be used
as the map name and the map will be placed in the whateve the most recently
referenced map set.

To add more information such as map accession (map_acc), you can use the
##cmap_map pragma to create the map IN ADDITION TO the ##sequence-region (doing
so after will just be ignored).
  
A map must be either in the file or in the database to be referenced by a
feature;

=head3 Definition

  ##cmap_map definition_string

The definition string is a list of key=value pairs separated by a semi-colon.
An example is "". 

=head3 Options

  map_acc*
  map_name*+
  map_start*+
  map_stop*+
  display_order
  map_set_name#
  map_set_short_name#
  map_type_acc#
  map_set_acc#


 + required for creation
 * used for identification of a map set already in the database
 # Map set information is not required if the current map set has been set by
   the ##cmap_map_set pragma (see above).  Otherwise, just enough information
   to identify the map set is required.

=head3 Examples

  # Enough create or set a map if it has been preceded by a ##cmap_map_set pragma 
  ##cmap_map map_acc=Contig0001;map_name=Contig1;map_start=1;map_stop=4970;display_order=2;
  ##sequence-region   Contig1 1   4970    
  
  # Create or set map and select map set
  ##cmap_map map_acc=Contig0001;map_name=Contig1;map_start=1;map_stop=4970;display_order=2;map_set_acc=MS3;
  ##sequence-region   Contig1 1   4970    

  # Find a Map already in the db
  ##cmap_map map_acc=Contig0001;
  ##sequence-region   Contig1 1   4970    

  ##cmap_map map_name=Contig1;
  ##sequence-region   Contig1 1   4970    

=head2 Feature

=head3 Description

Features are described as GFF lines.

The map that the feature is on must be in the current map set which is set by
using the ##cmap_map_set pragma.

=head3 Definition

Tab delimited format where each line describes a feature.

For more information see the GFF specification located at
http://song.sourceforge.net/gff3.shtml. 

=head3 Columns

=over 4

=item 1 seqid 

Used as the map name.  The map name needs to be unique in the current map set.

=item 2 source

Unused in CMap.  Can be left as ".".

=item 3 type

Used for the feature type accession (feature_type_acc).  This value needs to be
defined in the CMap config file prior to trying to import it.  Unrecognized
feature types will be ignored.

=item 4 start

Start of the feature on the map.

=item 5 end

Start of the feature on the map.

=item 6 score

Unused in CMap.  Can be left as ".".

=item 7 strand

Strand of the feature.  Either set as "+" or "-".

=item 8 phase

Unused in CMap.  Can be left as ".".

=item 9 attributes

List of key value pairs separated by a semicolon.  See the next section for
further details.

=back

=head3 Attributes Recognized by CMap

The values of each tag must be URI encoded.

=over 4

=item * ID

This is a load ID.  It is only used to reference the feature within a single
file.  After a file is loaded, the load id is discarded, never to be heard from
again.

Example: ID=read00001

=item * Name

This is the feature name.

Example: Name=09H123.g1

=item * Alias

This is not needed but if the feature has one or more aliases, use the Alias
tag.

Example: Alias=My Favorite Feature

=item * corrs_by_id

This is a way to define a correspondence to a feature in the same file.  It uses
the load id (see the ID tag above) to identify which feature the correspondence
should be created with.  It also takes an evidence type accession
(evidence_type_acc) and an optional score.

Example: corrs_by_id=read00002 read_pair

Example: corrs_by_id=hsp00002 blast 1e-99

=item * attribute

This tag will store an attribute in the attribute table.  It is a name:value
pair separated by a colon.  The name cannot have a colon in it as the first
colon in the pair is assumed to be the separator.

Example: attribute=Description:This gene is totally rad.

=item * xref

This tag will store an xref in the xref table.  It is a name:url pair separated
by a colon.  The name cannot have a colon in it as the first colon in the pair
is assumed to be the separator.

Example: xref=Google:html://www.google.com/search?q=09H123.g1

=back

=head3 Examples

Contig2	.	read	1701	2580	.	+	.	ID=read00004;Name=09B023.b1;Alias=My Second Favorite Feature;corr_by_id=read00001 shared_clone;xref=Organism Map:http://www.gramene.com/viewer?ref_map_accs%3Dorcb0602h-ctg161;

=head2 Correspondence

=head3 Description

The ##cmap_correspondence pragma defines a correspondence between features that
are either already in the database or are defined in the current file.

=head3 Definition

  ##cmap_correspondence definition_string
  ##cmap_corr definition_string

The definition string is a list of key=value pairs separated by a semi-colon.
An example is "ID1=read0001;ID2=read0002;". 

=head3 Options

  evidence_type_acc+
  Unique identification of feature 1+
  Unique identification of feature 2+
  score

 + required for creation

Both features involved in the correspondence must be uniquely identified.  To
do this provide identification parameters for each feature.  See the section on
Object Identification With Parameters for more information about the
identification parameters.  

Parameters refering to one feature must end in a 1 and parameters refering to
the other must end in a 2.  For instance:

 feature_name1=SSR123;map_name1=Chr2;map_set_acc1=MS1;feature_name2=SSR123;map_name2=Chr4;map_set_acc2=MS2;

=head3 Important Note

If more than one feature matches the description of a feature, then the script
will die.

=head3 Example

  ##cmap_corr  evidence_type_acc=ANB;feature_name1=feature4;map_name1=Contig2;ID2=read00001;

=head2 Attribute

=head3 Description

The ##cmap_attribute pragma can allow creation of attributes for objects in
CMap.  Specifically, features, maps, map sets and species.

=head3 Definition

  ##cmap_attribute definition_string

The definition string is a list of key=value pairs separated by a semi-colon.
An example is "ID=read0001;attribute_name=Description;". 

=head3 Options

  object_type+
  attribute_name+
  attribute_value+
  Unique identification of CMap object+
  display_order
  is_public

 + required for creation

The object_type must be either "feature", "map", "map_set" or "species".

The unique identification of the CMap object is described in the section on
Object Identification With Parameters.

=head3 Examples

  # Feature attribute
  ##cmap_attribute  object_type=feature;feature_name=feature4;map_name=Contig2;map_set_acc=MS2;attribute_value=This is really my favorite feature;attribute_name=Descrption

  # Map attribute
  ##cmap_attribute  object_type=map;map_name=Contig2;map_set_acc=MS2;attribute_value=This map has my favorite feature;attribute_name=Descrption

=head3 Important Note

If more than one object matches the description, then the script will die.

Also, both the name and values of the attributes must be uri encoded.

=head2 Cross Reference (XRef)

=head3 Description

The ##cmap_xref pragma can allow creation of cross reference urls for objects
in CMap.  Specifically, features, maps, map sets and species.

=head3 Definition

  ##cmap_xref definition_string

The definition string is a list of key=value pairs separated by a semi-colon.
An example is "ID=read0001;xref_name=Google This Feature;". 

=head3 Options

  object_type+
  xref_name+
  xref_url+
  Unique identification of CMap object+
  display_order
  is_public

 + required for creation

The object_type must be either "feature", "map", "map_set" or "species".

The unique identification of the CMap object is described in the section on
Object Identification With Parameters.

=head3 Examples

  ##cmap_xref  object_type=feature;feature_name=marker2;map_name=Contig1;map_set_acc=MS1;xref_url=http%3A%2F%2Fwww.google.com%2Fsearch%3Fq%3Dmarker2;xref_name=Google

=head3 Important Notes

If more than one object matches the description, then the script will die.

Both the name and values of the xref must be uri encoded.

The name of the xref cannot contain a colon.  The first colon found is assumed
to be the separator.

=head2 Object Identification With Parameters

For some pragmas such as ##cmap_correspondence and ##cmap_attribute, identifying a specific feature is needed.  In that case, parameters can be supplied to identify a feature, map, map set or species.

For instance to identify a feature, a feature_name can be specified.  The search can be narrowed to a particular map using the map parameters, such as map_name.  The map can further defined as belonging to a specific map set.  See the following example:

  feature_name=SSR123;map_name=Chr1;map_set_name=Sample Map Set;species_acc=rice08

Note 1: To refer to the load ID of a feature within the same file, use the ID tag.

Note 2: For identifying features to use in correspondences, use the same tags but with a 1 or 2 after each.  For instance, the feature name would be refered to as feature_name1 or feature_name2.

=over 4 

=item * Feature

  feature_acc
  feature_name
  feature_type_acc
  ID

=item * Map

  map_acc
  map_name

=item * Map Set

  map_set_name
  map_set_acc
  map_set_short_name
  map_type_acc

=item * Species

  species_acc
  species_common_name
  species_full_name

=back

=head1 Developer Notes To Self

Add in unit_granularity

=head1 Other Notes

Attributes and Xrefs defined by the feature GFF line don't have display order
or is_public.  

The ##cmap_attributes and ##cmap_xref pragmas cannot handle correspondence
attributes.  To do that, it would have to be attached to a
##cmap_correspondence pragma which has not been implemented.

=head1 Methods

=cut

use strict;

use Data::Dumper;
use URI::Escape;
use base 'Bio::DB::SeqFeature::Store';
use Bio::DB::GFF::Util::Rearrange 'rearrange';
use constant DEBUG              => 0;
use constant TMP_DB_STARTING_ID => 1;
use Bio::GMOD::CMap::Admin;
use Bio::GMOD::CMap::Config;
use DB_File;
use Storable qw(nfreeze thaw);

# ----------------------------------------------------

=pod

=head2 init()

object initialization

=cut

sub init {
    my $self = shift;

    my ( $data_source, $config_dir, $map_set_acc, $cmap_gff_version,
        $insert_threshold, )
        = rearrange(
        [   [qw(DATASOURCE DATA_SOURCE )], [qw(CONFIG_DIR CONFIGDIR )],
            [qw(MAP_SET_ACC MS_ACC )],     [qw(CMAP_GFF_VERSION)],
            [qw(INSERT_THRESHOLD)],
        ],
        @_
        );

    my $cmap_admin = $self->cmap_admin(
        data_source => $data_source,
        config_dir  => $config_dir,
    );

    $self->cmap_gff_version($cmap_gff_version);
    $insert_threshold = 1000 if ( not defined $insert_threshold );
    $self->insert_threshold($insert_threshold);

    # Get the maps that are part of the map set for future use and get other
    # useful information
    $self->store_map_set_data( map_set_acc => $map_set_acc, );
}

# ----------------------------------------------------

=pod

=head2 cmap_admin()

Get or initiate the CMap::Admin object

=cut

sub cmap_admin {

    my $self = shift;
    my %args = @_;

    unless ( $self->{'cmap_admin'} ) {
        my $data_source = $args{'data_source'};
        my $config_dir  = $args{'config_dir'};
        my $config      = undef;
        if ($config_dir) {
            $config
                = Bio::GMOD::CMap::Config->new( config_dir => $config_dir, );
        }

        my $cmap_admin = $self->{'cmap_admin'} = Bio::GMOD::CMap::Admin->new(
            data_source => $data_source,
            config      => $config,
        );

        # Make sure the data source supplied is the one used
        if ($data_source) {
            unless ( $cmap_admin->data_source() eq $data_source ) {
                die "Data source $data_source is not available."
                    . $cmap_admin->error;
            }
        }
    }

    return $self->{'cmap_admin'};
}

# ----------------------------------------------------

=pod

=head2 load_to_cmap_ids()

Sets or retrieves the load id to a set of CMap ids.  The cmap_id is likely to
be a feature_id.

=cut

sub load_to_cmap_ids {

    my $self    = shift;
    my %args    = @_;
    my $load_id = $args{'load_id'};
    my $cmap_id = $args{'cmap_id'};

    if ( $load_id and $cmap_id ) {
        push @{ $self->{'load_to_cmap_ids'}{$load_id} }, $cmap_id;
    }
    elsif ($load_id) {
        return $self->{'load_to_cmap_ids'}{$load_id};
    }

    return $self->{'load_to_cmap_ids'};
}

# ----------------------------------------------------

=pod

=head2 store_map_set_data()

Gets the maps that belong to the map set and stores them for later retrieval.
Store other useful information

=cut

sub store_map_set_data {

    my $self        = shift;
    my %args        = @_;
    my $map_set_acc = $args{'map_set_acc'};
    my $map_set_id  = $args{'map_set_id'};

    return unless ( $map_set_acc or $map_set_id );
    my $cmap_admin = $self->cmap_admin();

    my $map_set_data_array = $cmap_admin->sql->get_map_sets_simple(
        map_set_acc => $map_set_acc,
        map_set_id  => $map_set_id,
    );

    die "Map Set with accession, $map_set_acc does not exist.\n"
        unless ( @{ $map_set_data_array || [] } );
    my $map_set_data = $map_set_data_array->[0];

    $map_set_id  = $map_set_data->{'map_set_id'};
    $map_set_acc = $map_set_data->{'map_set_id'};

    my $maps_data = $cmap_admin->sql->get_maps( map_set_id => $map_set_id );

    my %stored_map_data = ();
    my %map_acc_to_name = ();
    foreach my $map_data ( @{ $maps_data || [] } ) {
        $stored_map_data{ $map_data->{'map_name'} } = $map_data;
        $map_acc_to_name{ $map_data->{'map_acc'} }  = $map_data->{'map_name'};
    }

    $self->{'current_map_set_id'}   = $map_set_id;
    $self->{'current_map_type_acc'} = $map_set_data->{'map_type_acc'};
    $self->{'stored_map_data'}      = \%stored_map_data;
    $self->{'map_acc_to_name'}      = \%map_acc_to_name;
    $self->{'current_map_set_data'} = $map_set_data;
    $self->set_current_unit_modifier( $self->{'unit_modifier'}{$map_set_id}
            || 1 );

    return;
}

# ----------------------------------------------------

=pod

=head2 add_map_data()

Adds a map to the stored_map_data.

=cut

sub add_map_data {

    my $self = shift;
    my $map_id = shift or return;

    my $cmap_admin = $self->cmap_admin();

    my $maps_data = $cmap_admin->sql->get_maps( map_id => $map_id );

    foreach my $map_data ( @{ $maps_data || [] } ) {
        $self->{'stored_map_data'}{ $map_data->{'map_name'} } = $map_data;
    }

    return;
}

# ----------------------------------------------------

=pod
    
=head2 get_map_data()

Gets the map data for a map that belong to the current map set.

=cut

sub get_map_data {

    my $self = shift;
    my $map_name = shift or return;

    return $self->{'stored_map_data'}{$map_name};
}

# ----------------------------------------------------

=pod

=head2 cmap_gff_version()

=cut

sub cmap_gff_version {
    my $self        = shift;
    my $new_version = shift;
    if ($new_version) {
        $self->{'cmap_gff_version'} = $new_version;
    }
    return $self->{'cmap_gff_version'};
}

# ----------------------------------------------------

=pod

=head2 insert_threshold()

=cut

sub insert_threshold {
    my $self          = shift;
    my $new_threshold = shift;
    if ($new_threshold) {
        $self->{'insert_threshold'} = $new_threshold;
    }
    return $self->{'insert_threshold'};
}

# ----------------------------------------------------

=pod

=head2 current_unit_modifier()

Return the current unit modifier for the current map set

=cut

sub current_unit_modifier {
    my $self = shift;
    return $self->{'current_unit_modifier'} || 1;
}

# ----------------------------------------------------

=pod

=head2 set_current_unit_modifier()

=cut

sub set_current_unit_modifier {
    my $self = shift;
    my $val  = shift;
    $self->{'current_unit_modifier'} = $val || 1;
}

# ----------------------------------------------------

=pod

=head2 get_or_create_species_from_description_line()

=cut

sub get_or_create_species_from_description_line {
    my $self = shift;
    my $desc_str = shift or return;

    my @insertion_species_params = qw(
        species_acc
        species_common_name
        species_full_name
        display_order
    );

    # species_acc is checked separately
    my @identifying_species_params = qw(
        species_acc
        species_common_name
        species_full_name
    );
    my @required_species_params = qw(
        species_common_name
        species_full_name
    );

    my $cmap_admin = $self->cmap_admin();
    my $sql_object = $cmap_admin->sql();

    my %params = $self->_split_description_string($desc_str);
    return unless %params;

    # First check if there is a species already in the db.
    if ( $params{'species_acc'} ) {

        my $species_id = $sql_object->acc_id_to_internal_id(
            acc_id      => $params{'species_acc'},
            object_type => 'species',
        );

        if ($species_id) {
            return $species_id;
        }
    }

    # CMap doesn't have a search on species name so we'll have to search them
    # all.  There shouldn't be too many species so this probably won't be a
    # problem.
    my $species_array = $sql_object->get_species();

SPECIES:
    foreach my $species ( @{ $species_array || [] } ) {
        foreach my $param (@identifying_species_params) {
            if ( defined $params{$param} ) {
                next SPECIES unless ( $species->{$param} eq $params{$param} );
            }
        }

        # There were no conflicts, so this species is the one for which we are
        # looking
        return $species->{'species_id'};
    }

    # Didn't find one, so now create it.

    # First check to make sure we have enough info to create it
    foreach my $param (@required_species_params) {
        die "Missing $param to create species in line $desc_str\n"
            unless ( defined $params{$param} );
    }

    # Create Args for creation
    my %args;
    foreach my $param (@insertion_species_params) {
        next unless ( defined $params{$param} );
        $args{$param} = $params{$param};
    }

    return $cmap_admin->species_create(%args);
}

# ----------------------------------------------------

=pod

=head2 sub get_or_create_map_set_from_description_line()

=cut

sub get_or_create_map_set_from_description_line {
    my $self = shift;
    my $desc_str = shift or return;

    my $map_set_id;

    # species_id will be added into the param list by this method
    my @insertion_map_set_params = qw(
        map_set_name
        map_set_short_name
        species_id
        map_type_acc
        map_set_acc
        display_order
        shape
        color
        width
        published_on
        is_relational_map
    );

    # map_set_acc is checked separately
    my @identifying_map_set_params = qw(
        species_id
        map_set_name
        map_set_short_name
        map_type_acc
    );
    my @required_map_set_params = qw(
        species_id
        map_set_name
        map_set_short_name
        map_type_acc
    );

    my $cmap_admin = $self->cmap_admin();
    my $sql_object = $cmap_admin->sql();

    my %params = $self->_split_description_string($desc_str);
    return unless %params;

    # First check if there is a map_set already in the db.

    # Check the map_set_acc
    if ( $params{'map_set_acc'} ) {

        $map_set_id = $sql_object->acc_id_to_internal_id(
            acc_id      => $params{'map_set_acc'},
            object_type => 'map_set',
        );

    }

    unless ($map_set_id) {
        if ( $desc_str =~ /species/ ) {
            $params{'species_id'}
                = $self->get_or_create_species_from_description_line(
                $desc_str);
        }
        elsif ( $self->{'current_species_id'} ) {
            $params{'species_id'} = $self->{'current_species_id'};
        }

        # CMap doesn't have a search on map_set name so we'll have to search
        # them all.  There shouldn't be too many map_set so this probably won't
        # be a problem.
        my $map_set_array = $sql_object->get_map_sets();

    MAP_SET:
        foreach my $map_set ( @{ $map_set_array || [] } ) {
            foreach my $param (@identifying_map_set_params) {
                if ( defined $params{$param} ) {
                    next MAP_SET
                        unless ( $map_set->{$param} eq $params{$param} );
                }
            }

        # There were no conflicts, so this map_set is the one for which we are
        # looking
            $map_set_id = $map_set->{'map_set_id'};
            last;
        }
    }

    # If didn't find one, so now create it.
    unless ($map_set_id) {

        unless ( $params{'species_id'} ) {
            $params{'species_id'} = $self->{'current_species_id'};
        }

        # First check to make sure we have enough info to create it
        foreach my $param (@required_map_set_params) {
            die "Missing $param to create map_set in line $desc_str\n"
                unless ( defined $params{$param} );
        }

        # Create Args for creation
        my %args;
        foreach my $param (@insertion_map_set_params) {
            next unless ( defined $params{$param} );
            $args{$param} = $params{$param};
        }

        $map_set_id = $cmap_admin->map_set_create(%args);
    }

    # Set Map Set options
    if ($map_set_id) {
        $self->{'unit_modifier'}{$map_set_id} = $params{'unit_modifier'} || 1;
    }

    return $map_set_id;
}

# ----------------------------------------------------

=pod

=head2 get_or_create_map_from_description_line()

=cut

sub get_or_create_map_from_description_line {
    my $self = shift;
    my $desc_str = shift or return;

    # map_set_id will be added into the param list by this method
    my @insertion_map_params = qw(
        map_acc
        map_set_id
        map_name
        map_start
        map_stop
        display_order
    );
    my @update_map_params = qw(
        map_acc
        map_name
        map_start
        map_stop
        display_order
    );

    # map_acc is checked separately
    my @identifying_map_params = qw(
        map_set_id
        map_name
    );
    my @required_map_params = qw(
        map_set_id
        map_name
        map_start
        map_stop
    );

    my $cmap_admin = $self->cmap_admin();
    my $sql_object = $cmap_admin->sql();

    my %params = $self->_split_description_string($desc_str);
    return unless %params;

    # First check if there is a map already in the db.
    if ( $params{'map_acc'} ) {

        my $map_name = $self->{'map_acc_to_name'}{ $params{'map_acc'} };

        if ($map_name) {
            my $map_data = $self->get_map_data($map_name);
            $self->update_map(
                update_params => \@update_map_params,
                map_data      => $map_data,
                params        => \%params,
            );
            return $map_data->{'map_id'};
        }
    }

    if ( $desc_str =~ /map_set/ ) {
        my $map_set_id
            = $self->get_or_create_map_set_from_description_line($desc_str);
        $self->set_map_set_as_current( $map_set_id, $desc_str );
        $params{'map_set_id'} = $map_set_id;
    }
    elsif ( $self->{'current_map_set_id'} ) {
        $params{'map_set_id'} = $self->{'current_map_set_id'};
    }

    # CMap does have a search on all the identifying parameters so we'll just
    # use the db query.

    my %find_args;
    foreach my $param (@identifying_map_params) {
        next unless ( defined $params{$param} );
        $find_args{$param} = $params{$param};
    }
    my $map_results = $sql_object->get_maps(%find_args);
    if (@$map_results) {
        return $map_results->[0]{'map_id'};
    }

    # Didn't find one, so now create it.

    # First check to make sure we have enough info to create it
    foreach my $param (@required_map_params) {
        die "Missing $param to create map in line $desc_str\n"
            unless ( defined $params{$param} );
    }

    # Create Args for creation
    my %create_args;
    foreach my $param (@insertion_map_params) {
        next unless ( defined $params{$param} );
        $create_args{$param} = $params{$param};
    }

    my $unit_modifier = $self->current_unit_modifier();
    $create_args{'map_start'} *= $unit_modifier;
    $create_args{'map_stop'}  *= $unit_modifier;

    my $map_id = $cmap_admin->sql()->insert_map(%create_args);
    $self->add_map_data($map_id);

    return $map_id;
}

# ----------------------------------------------------

=pod

=head2 find_feature_ids_from_params()

return undef if no params for this object are provided

return [] if params are provided but no objects are found

return the ids of the found objects

=cut

sub find_feature_ids_from_params {
    my $self = shift;
    my $params = shift or return;

    if ( $params->{'feature_id'} ) {
        return [ $params->{'feature_id'} ];
    }

    if ( $params->{'ID'} ) {
        if ( my $feature_ids
            = $self->load_to_cmap_ids( load_id => $params->{'ID'}, ) )
        {
            return $feature_ids;
        }
    }

    my $sql_object = $self->cmap_admin()->sql();
    my %args;
    my @identifying_feature_params = qw(
        feature_acc
        feature_name
        feature_type_acc
    );

    foreach my $param (@identifying_feature_params) {
        if ( defined( $params->{$param} ) ) {
            $args{$param} = $params->{$param};
        }
    }
    return undef unless (%args);

    my $map_ids = $self->find_map_ids_from_params($params);
    if ( $map_ids and not @$map_ids ) {
        return [];
    }
    my $feature_data;
    if ( scalar @{ $map_ids || [] } > 1 ) {
        foreach my $map_id (@$map_ids) {
            $args{'map_id'} = $map_id;
            push @{$feature_data},
                @{ $sql_object->get_features_simple(%args) || [] };
        }
    }
    else {
        if ( scalar @{ $map_ids || [] } == 1 ) {
            $args{'map_id'} = $map_ids->[0];
        }
        $feature_data = $sql_object->get_features_simple(%args);
    }

    return [ map { $_->{'feature_id'} } @{ $feature_data || [] } ];
}

# ----------------------------------------------------

=pod

=head2 find_map_ids_from_params()

return undef if no params for this object are provided

return [] if params are provided but no objects are found

return the ids of the found objects

=cut

sub find_map_ids_from_params {
    my $self = shift;
    my $params = shift or return;

    if ( $params->{'map_id'} ) {
        return [ $params->{'map_id'} ];
    }

    my $sql_object = $self->cmap_admin()->sql();
    my %args;
    my @identifying_map_params = qw(
        map_acc
        map_name
    );

    foreach my $param (@identifying_map_params) {
        if ( defined( $params->{$param} ) ) {
            $args{$param} = $params->{$param};
        }
    }
    return undef unless (%args);

    my $map_set_ids = $self->find_map_set_ids_from_params($params);
    if ( $map_set_ids and not @$map_set_ids ) {
        return [];
    }
    my $map_data;
    if ( scalar @{ $map_set_ids || [] } > 1 ) {
        foreach my $map_set_id (@$map_set_ids) {
            $args{'map_set_id'} = $map_set_id;
            push @{$map_data}, @{ $sql_object->get_maps(%args) || [] };
        }
    }
    else {
        if ( scalar @{ $map_set_ids || [] } == 1 ) {
            $args{'map_set_id'} = $map_set_ids->[0];
        }
        $map_data = $sql_object->get_maps(%args);
    }

    return [ map { $_->{'map_id'} } @{ $map_data || [] } ];
}

# ----------------------------------------------------

=pod

=head2 find_map_set_ids_from_params()

return undef if no params for this object are provided

return [] if params are provided but no objects are found

return the ids of the found objects

=cut

sub find_map_set_ids_from_params {
    my $self = shift;
    my $params = shift or return;

    my $sql_object = $self->cmap_admin()->sql();
    my %args;
    my @identifying_map_set_params = qw(
        map_set_name
        map_set_acc
        map_set_short_name
        map_type_acc
    );

    my $found_id = 0;
    foreach my $param (@identifying_map_set_params) {
        if ( defined( $params->{$param} ) ) {
            $found_id = 1;
            last;
        }
    }
    return undef unless ($found_id);

    my $species_ids = $self->find_species_ids_from_params($params);
    if ( $species_ids and not @$species_ids ) {
        return [];
    }

    my $map_set_data;
    foreach my $species_id ( @{ $species_ids || [] } ) {
        push @{ $args{'species_ids'} }, $species_id;
    }

    my $map_set_array = $sql_object->get_map_sets();

    my @return_ids;
MAP_SET:
    foreach my $map_set ( @{ $map_set_array || [] } ) {
        foreach my $param (@identifying_map_set_params) {
            if ( defined $params->{$param} ) {
                next MAP_SET
                    unless ( $map_set->{$param} eq $params->{$param} );
            }
        }

        # There were no conflicts, so this map_set is the one for which we are
        # looking
        push @return_ids, $map_set->{'map_set_id'};
    }

    return \@return_ids;
}

# ----------------------------------------------------

=pod

=head2 find_species_ids_from_params()

return undef if no params for this object are provided

return [] if params are provided but no objects are found

return the ids of the found objects

=cut

sub find_species_ids_from_params {
    my $self = shift;
    my $params = shift or return;

    my $sql_object                 = $self->cmap_admin()->sql();
    my @identifying_species_params = qw(
        species_acc
        species_common_name
        species_full_name
    );

    my $found_id = 0;
    foreach my $param (@identifying_species_params) {
        if ( defined( $params->{$param} ) ) {
            $found_id = 1;
            last;
        }
    }

    return undef unless ($found_id);
    my $species_data;
    $species_data = $sql_object->get_species();
    my @return_ids;

SPECIES:
    foreach my $species ( @{ $species_data || [] } ) {
        foreach my $param (@identifying_species_params) {
            if ( defined $params->{$param} ) {
                next SPECIES
                    unless ( $species->{$param} eq $params->{$param} );
            }
        }

        # There were no conflicts, so this species is what we are looking for.
        push @return_ids, $species->{'species_id'};
    }

    return \@return_ids;
}

# ----------------------------------------------------

=pod

=head2 add_meta_attribute()

=cut

sub add_meta_attribute {
    my $self = shift;
    my $desc_str = shift or return;

    my %params = $self->_split_description_string($desc_str);
    return unless %params;
    $params{'desc_str'} = $desc_str;

    $self->save_attr( \%params );
    return;
}

# ----------------------------------------------------

=pod

=head2 add_meta_xref()

=cut

sub add_meta_xref {
    my $self = shift;
    my $desc_str = shift or return;

    my %params = $self->_split_description_string($desc_str);
    return unless %params;
    $params{'desc_str'} = $desc_str;

    $self->save_xref( \%params );
    return;
}

# ----------------------------------------------------

=pod

=head2 add_meta_corr()

=cut

sub add_meta_corr {
    my $self = shift;
    my $desc_str = shift or return;

    my %params = $self->_split_description_string($desc_str);
    return unless %params;
    $params{'desc_str'} = $desc_str;

    $self->save_corr( \%params );

    return;
}

# ----------------------------------------------------

=pod

=head2 finish_loading_features()

=cut

sub finish_loading_features {
    my $self = shift;

    my $sql_object = $self->cmap_admin->sql();
    my ( $feature_insertion_index, $feature_id_array, )
        = $sql_object->insert_feature(
        threshold            => 0,
        report_feature_index => 1,
        );

    if ( @{ $feature_id_array || [] } ) {
        $self->load_feature_auxilary_info($feature_id_array);
    }

    return;
}

# ----------------------------------------------------

=pod

=head2 load_corrs_from_tmp_db()

=cut

sub load_corrs_from_tmp_db {
    my $self = shift;

    my $sql_object = $self->cmap_admin->sql();

    my $tmp_db      = $self->corr_tmp_db();
    my $corr_end_id = $tmp_db->{'.next_id'} - 1;
    foreach my $id ( TMP_DB_STARTING_ID .. $corr_end_id ) {
        my $corr_params = thaw( $tmp_db->{$id} );

        my $evidence_type_acc = $corr_params->{'evidence_type_acc'}
            or die "No evidence_type_specified for correspondence: "
            . $corr_params->{'desc_str'} . "\n";
        my $score = $corr_params->{'score'};

        my %feature1_params;
        my %feature2_params;
        foreach my $param ( keys %{ $corr_params || {} } ) {
            if ( $param =~ /^(\S+)1/ ) {
                $feature1_params{$1} = $corr_params->{$param};
            }
            elsif ( $param =~ /^(\S+)2/ ) {
                $feature2_params{$1} = $corr_params->{$param};
            }
        }

        my $feature_ids1
            = $self->find_feature_ids_from_params( \%feature1_params );
        my $feature_ids2
            = $self->find_feature_ids_from_params( \%feature2_params );

        unless ( scalar @{ $feature_ids1 || [] } == 1 ) {
            die "Feature 1 failed to find a single feature: "
                . $corr_params->{'desc_str'} . "\n";
        }
        unless ( scalar @{ $feature_ids2 || [] } == 1 ) {
            die "Feature 2 failed to find a single feature: "
                . $corr_params->{'desc_str'} . "\n";
        }
        my $feature_id1 = $feature_ids1->[0];
        my $feature_id2 = $feature_ids2->[0];

        my $corr_key1
            = $feature_id1 . "_" . $feature_id2 . "_" . $evidence_type_acc;
        my $corr_key2
            = $feature_id2 . "_" . $feature_id1 . "_" . $evidence_type_acc;
        next
            if ( $self->{'inserted_corrs'}{$corr_key1}
            or $self->{'inserted_corrs'}{$corr_key2} );
        $self->{'inserted_corrs'}{$corr_key1} = 1;
        $self->{'inserted_corrs'}{$corr_key2} = 1;
        $sql_object->insert_feature_correspondence(
            feature_id1       => $feature_id1,
            feature_id2       => $feature_id2,
            evidence_type_acc => $evidence_type_acc,
            score             => $score,
            threshold         => $self->insert_threshold(),
        );
    }
    $sql_object->insert_feature_correspondence( threshold => 0, );

    return;
}

sub load_attrs_from_tmp_db {
    my $self = shift;

    my $sql_object = $self->cmap_admin->sql();

    my $tmp_db      = $self->attr_tmp_db();
    my $attr_end_id = $tmp_db->{'.next_id'} - 1;
    foreach my $id ( TMP_DB_STARTING_ID .. $attr_end_id ) {
        my $attr_params = thaw( $tmp_db->{$id} );

        my $object_type = $attr_params->{'object_type'};
        my $object_id   = undef;
        if ( not $object_type ) {
        }
        elsif ( $object_type eq 'feature' ) {
            my $feature_ids
                = $self->find_feature_ids_from_params($attr_params);
            if ( not defined $feature_ids ) {

                # Generic attribute for all features
                $object_id = undef;
            }
            elsif ( scalar @$feature_ids > 1 ) {
                die "Found Multiple feature matching the description: "
                    . $attr_params->{'desc_str'} . "\n";
            }
            elsif (@$feature_ids) {
                $object_id = $feature_ids->[0];
            }
            else {
                die "Did not Find a feature matching the description: "
                    . $attr_params->{'desc_str'} . "\n";
            }
        }
        elsif ( $object_type eq 'map' ) {
            my $map_ids = $self->find_map_ids_from_params($attr_params);
            if ( not defined $map_ids ) {

                # Generic attribute for all maps
                $object_id = undef;
            }
            elsif ( scalar @$map_ids > 1 ) {
                die "Found Multiple map matching the description: "
                    . $attr_params->{'desc_str'} . "\n";
            }
            elsif (@$map_ids) {
                $object_id = $map_ids->[0];
            }
            else {
                die "Did not Find a map matching the description: "
                    . $attr_params->{'desc_str'} . "\n";
            }
        }
        elsif ( $object_type eq 'map_set' ) {
            my $map_set_ids
                = $self->find_map_set_ids_from_params($attr_params);
            if ( not defined $map_set_ids ) {

                # Generic attribute for all map_sets
                $object_id = undef;
            }
            elsif ( scalar @$map_set_ids > 1 ) {
                die "Found Multiple map_set matching the description: "
                    . $attr_params->{'desc_str'} . "\n";
            }
            elsif (@$map_set_ids) {
                $object_id = $map_set_ids->[0];
            }
            else {
                die "Did not Find a map_set matching the description: "
                    . $attr_params->{'desc_str'} . "\n";
            }
        }
        elsif ( $object_type eq 'species' ) {
            my $species_ids
                = $self->find_species_ids_from_params($attr_params);
            if ( not defined $species_ids ) {

                # Generic attribute for all speciess
                $object_id = undef;
            }
            elsif ( scalar @$species_ids > 1 ) {
                die "Found Multiple species matching the description: "
                    . $attr_params->{'desc_str'} . "\n";
            }
            elsif (@$species_ids) {
                $object_id = $species_ids->[0];
            }
            else {
                die "Did not Find a species matching the description: "
                    . $attr_params->{'desc_str'} . "\n";
            }
        }
        else {
            die "Object: $object_type is not allowed: "
                . $attr_params->{'desc_str'} . "\n";
        }

        unless ($object_id) {
            die "Did not find a $object_type matching the description: "
                . $attr_params->{'desc_str'} . "\n";
        }

        my @insertion_params = qw(
            object_type
            attribute_name
            attribute_value
            display_order
            is_public
        );

        # Create Args for creation
        my %insert_args;
        foreach my $param (@insertion_params) {
            next unless ( defined $attr_params->{$param} );
            $insert_args{$param} = $attr_params->{$param};
        }
        $insert_args{'object_id'} = $object_id if ($object_id);

        $sql_object->insert_attribute(%insert_args);

    }

    return;
}

sub load_xrefs_from_tmp_db {
    my $self = shift;

    my $sql_object = $self->cmap_admin->sql();

    my $tmp_db      = $self->xref_tmp_db();
    my $xref_end_id = $tmp_db->{'.next_id'} - 1;
    foreach my $id ( TMP_DB_STARTING_ID .. $xref_end_id ) {
        my $xref_params = thaw( $tmp_db->{$id} );

        my $object_type = $xref_params->{'object_type'};
        my $object_id   = undef;
        if ( not $object_type ) {
        }
        elsif ( $object_type eq 'feature' ) {
            my $feature_ids
                = $self->find_feature_ids_from_params($xref_params);
            if ( not defined $feature_ids ) {

                # Generic xref for all features
                $object_id = undef;
            }
            elsif ( scalar @$feature_ids > 1 ) {
                die "Found Multiple feature matching the description: "
                    . $xref_params->{'desc_str'} . "\n";
            }
            elsif (@$feature_ids) {
                $object_id = $feature_ids->[0];
            }
            else {
                die "Did not Find a feature matching the description: "
                    . $xref_params->{'desc_str'} . "\n";
            }
        }
        elsif ( $object_type eq 'map' ) {
            my $map_ids = $self->find_map_ids_from_params($xref_params);
            if ( not defined $map_ids ) {

                # Generic xref for all maps
                $object_id = undef;
            }
            elsif ( scalar @$map_ids > 1 ) {
                die "Found Multiple map matching the description: "
                    . $xref_params->{'desc_str'} . "\n";
            }
            elsif (@$map_ids) {
                $object_id = $map_ids->[0];
            }
            else {
                die "Did not Find a map matching the description: "
                    . $xref_params->{'desc_str'} . "\n";
            }
        }
        elsif ( $object_type eq 'map_set' ) {
            my $map_set_ids
                = $self->find_map_set_ids_from_params($xref_params);
            if ( not defined $map_set_ids ) {

                # Generic xref for all map_sets
                $object_id = undef;
            }
            elsif ( scalar @$map_set_ids > 1 ) {
                die "Found Multiple map_set matching the description: "
                    . $xref_params->{'desc_str'} . "\n";
            }
            elsif (@$map_set_ids) {
                $object_id = $map_set_ids->[0];
            }
            else {
                die "Did not Find a map_set matching the description: "
                    . $xref_params->{'desc_str'} . "\n";
            }
        }
        elsif ( $object_type eq 'species' ) {
            my $species_ids
                = $self->find_species_ids_from_params($xref_params);
            if ( not defined $species_ids ) {

                # Generic xref for all speciess
                $object_id = undef;
            }
            elsif ( scalar @$species_ids > 1 ) {
                die "Found Multiple species matching the description: "
                    . $xref_params->{'desc_str'} . "\n";
            }
            elsif (@$species_ids) {
                $object_id = $species_ids->[0];
            }
            else {
                die "Did not Find a species matching the description: "
                    . $xref_params->{'desc_str'} . "\n";
            }
        }
        else {
            die "Object: $object_type is not allowed: "
                . $xref_params->{'desc_str'} . "\n";
        }

        unless ($object_id) {
            die "Did not find a $object_type matching the description: "
                . $xref_params->{'desc_str'} . "\n";
        }

        my @insertion_params = qw(
            object_type
            xref_name
            xref_url
            display_order
            is_public
        );

        # Create Args for creation
        my %insert_args;
        foreach my $param (@insertion_params) {
            next unless ( defined $xref_params->{$param} );
            $insert_args{$param} = $xref_params->{$param};
        }
        $insert_args{'object_id'} = $object_id if ($object_id);

        $sql_object->insert_xref(%insert_args);
    }

    return;
}

# ----------------------------------------------------

=pod

=head2 update_map()

=cut

sub update_map {
    my $self          = shift;
    my %args          = @_;
    my $update_params = $args{'update_params'};
    my $map_data      = $args{'map_data'};
    my $params        = $args{'params'};

    my $need_update = 0;
    foreach my $param ( @{ $update_params || [] } ) {
        if ( $params->{$param} ne $map_data->{$param} ) {
            $need_update = 1;
            last;
        }
    }

    if ($need_update) {
        my $sql_object = $self->cmap_admin->sql();

        # Update Args for creation
        my %update_args;
        foreach my $param (@$update_params) {
            next unless ( defined $params->{$param} );
            $update_args{$param} = $params->{$param};
        }

        $sql_object->update_map(
            map_id => $map_data->{'map_id'},
            %update_args
        );
    }

}

# ----------------------------------------------------

=pod

=head2 set_map_set_as_current()

=cut

sub set_map_set_as_current {
    my $self = shift;
    my $map_set_id = shift or return;
    $self->store_map_set_data( map_set_id => $map_set_id, );

    return 1;
}

# ----------------------------------------------------

=pod

=head2 _split_description_string()

=cut

sub _split_description_string {
    my $self = shift;
    my $desc_str = shift or return;
    my %return_hash;

    foreach my $fragment ( split( /;/, $desc_str ) ) {
        next unless ( $fragment =~ /\S/ );
        if ( $fragment =~ /(.+?)=(.+)/ ) {
            $return_hash{ uri_unescape($1) } = uri_unescape($2);
        }
        else {
            $self->throw(
                "Failed to recognize description fragment $fragment.");
        }
    }
    return %return_hash;
}

sub writeable { shift->{writeable} }

sub can_store_parentage {1}

sub table_definitions { }

###
# default settings -- will create and populate meta table if needed
#
sub default_settings {

    #my $self = shift;
    #$self->maybe_create_meta();
    #$self->SUPER::default_settings;
    #$self->autoindex(1);
    #$self->dumpdir( File::Spec->tmpdir );
}

###
# get/set directory for bulk load tables
#
sub dumpdir {
    my $self = shift;
    my $d    = $self->{dumpdir};
    $self->{dumpdir} = abs_path(shift) if @_;
    $d;
}

###
# find a path that corresponds to a dump table
#
sub dump_path { }

###
# make a filehandle (writeable) that corresponds to a dump table
#
sub dump_filehandle { }

###
# find the next ID for a feature (used only during bulk loading)
#
sub next_id { }

###
# find the maximum ID for a feature (used only during bulk loading)
#
sub max_id { }

###
# wipe database clean and reinstall schema
#
sub _init_database { }

sub maybe_create_meta { }

sub init_tmp_database { }

###
# use temporary tables
#
sub is_temp { }

# ----------------------------------------------------

=pod

=head2 _store()

=cut

sub _store {
    my $self = shift;

    # special case for bulk updates
    #return $self->_dump_store(@_) if $self->{bulk_update_in_progress};

    my $indexed = shift;
    my $count   = 0;

    eval {
        for my $obj (@_)
        {
            $self->replace( $obj, $indexed );

            #$self->_update_indexes($obj) if $indexed && $autoindex;
            $count++;
        }
    };
    return $count;

}

# ----------------------------------------------------

=pod

=head2 handle_unrecognized_meta()

# Handle any cmap specific meta lines

=cut

sub handle_unrecognized_meta {
    my $self        = shift;
    my $instruction = shift;

    if ( $instruction =~ /^cmap_map_set\s+(.+)/ ) {
        my $map_set_id
            = $self->get_or_create_map_set_from_description_line($1);
        $self->set_map_set_as_current( $map_set_id, $instruction );
    }
    elsif ( $instruction =~ /^cmap_map\s+(.+)/ ) {
        $self->{'current_map_id'}
            = $self->get_or_create_map_from_description_line($1);
    }
    elsif ( $instruction =~ /^cmap_species\s+(.+)/ ) {
        $self->{'current_species_id'}
            = $self->get_or_create_species_from_description_line($1);
    }
    elsif ( $instruction =~ /^cmap_attribute\s+(.+)/ ) {
        $self->add_meta_attribute($1);
    }
    elsif ( $instruction =~ /^cmap_xref\s+(.+)/ ) {
        $self->add_meta_xref($1);
    }
    elsif ( $instruction =~ /^cmap_corr\S*\s+(.+)/ ) {
        $self->add_meta_corr($1);
    }

    #elsif ($instruction =~/^/){
    #}
    elsif ( $instruction =~ /^cmap-gff-version\s+(\S+)/ ) {
        my $version = $1;
        $self->cmap_gff_version($version);
    }

}

# ----------------------------------------------------

=pod

=head2 commit()

=cut

sub commit {
    my $self = shift;
    $self->finish_loading_features();
    $self->load_corrs_from_tmp_db();
    $self->load_attrs_from_tmp_db();
    $self->load_xrefs_from_tmp_db();
    $self->delete_tmp_databases();
}

# we memoize this in order to avoid making zillions of calls
sub autoindex { }

sub _start_bulk_update { }

sub _finish_bulk_update { }

###
# Add a subparts to a feature. Both feature and all subparts must already be in database.
#
sub _add_SeqFeature { }

sub _fetch_SeqFeatures { }

###
# get primary sequence between start and end
#
sub _fetch_sequence { }

sub _offset_boundary { }

###
# Fetch a Bio::SeqFeatureI from database using its primary_id
#
sub _fetch { }

###
# Efficiently fetch a series of IDs from the database
# Can pass an array or an array ref
#
sub _fetch_many { }

sub _features { }

sub _name_sql { }

sub _search_attributes { }

sub _match_sql { }

sub _from_table_sql { }

sub _attributes_sql { }

sub subfeature_types_are_indexed     {1}
sub subfeature_locations_are_indexed {1}

sub _types_sql { }

sub _location_sql { }

###
# force reindexing
#
sub reindex { }

sub optimize { }

sub all_tables { }

sub index_tables { }

sub _firstid { }

sub _nextid { }

sub _existsid { }

sub _deleteid { }

sub _clearall { }

sub _featurecount { }

sub _seq_ids { }

sub setting { }

###
# Replace Bio::SeqFeatureI into database.
#
# ----------------------------------------------------

=pod

=head2 replace()

=cut

sub replace {
    my $self   = shift;
    my $object = shift;

    my $id = $object->primary_id;

    if ($id) {

        # Do update
    }
    else {

        my $feature_type_acc = $object->primary_tag();
        if (   $feature_type_acc eq 'region'
            or $feature_type_acc eq $self->{'current_map_type_acc'} )
        {
            return $self->handle_map($object);
        }
        elsif ( $self->cmap_admin()->feature_type_data($feature_type_acc) ) {
            return $self->handle_feature($object);
        }
    }

}

# ----------------------------------------------------

=pod

=head2 handle_map()

=cut

sub handle_map {
    my $self   = shift;
    my $object = shift;

    my $map_name = $object->ref();
    my $map_id;
    if ( my $map_data = $self->get_map_data($map_name) ) {
        $map_id = $map_data->{'map_id'};

    }
    else {
        my $unit_modifier = $self->current_unit_modifier();
        $map_id = $self->cmap_admin()->map_create(
            map_name   => $map_name,
            map_set_id => $self->{'current_map_set_id'},
            map_start  => $object->start * $unit_modifier,
            map_stop   => $object->stop * $unit_modifier,
        );

        $self->add_map_data($map_id);

    }

    unless ($map_id) {
        die "FAILED TO INSERT MAP: $map_name\n";
    }

    $self->{'current_map_id'} = $map_id;

    return $map_id;
}

# ----------------------------------------------------

=pod

=head2 handle_feature()

=cut

sub handle_feature {
    my $self   = shift;
    my $object = shift;

    my $cmap_admin = $self->cmap_admin();

    my %handled_attributes = (
        Alias       => 1,
        load_id     => 1,
        corrs_by_id => 1,
        xref        => 1,
        attribute   => 1,
    );

    my $map_name = $object->ref();
    my $map_id;
    if ( my $map_data = $self->get_map_data($map_name) ) {
        $map_id = $map_data->{'map_id'};
    }
    else {
        $self->throw("$map_name is not a map in this set\n");
        return;
    }

    my $unit_modifier    = $self->current_unit_modifier();
    my $feature_name     = $object->name;
    my $feature_start    = $object->start * $unit_modifier;
    my $feature_stop     = $object->stop * $unit_modifier;
    my $direction        = $object->strand;
    my $feature_type_acc = $object->primary_tag();

    $feature_name
        ||= $feature_type_acc . "_" . $feature_start . "_" . $feature_stop;

    my ( $feature_insertion_index, $feature_id_array, )
        = $cmap_admin->sql()->insert_feature(
        map_id               => $map_id,
        feature_name         => $feature_name,
        feature_start        => $feature_start,
        feature_stop         => $feature_stop,
        feature_type_acc     => $feature_type_acc,
        direction            => $direction,
        gclass               => $feature_type_acc,
        threshold            => $self->insert_threshold(),
        report_feature_index => 1,
        );

    # Save the attributes for later when the feature has a proper feature_id
    $self->{'saved_feature_info'}{$feature_insertion_index}
        = { $object->attributes() };

    if ( @{ $feature_id_array || [] } ) {
        $self->load_feature_auxilary_info($feature_id_array);
    }
}

sub load_feature_auxilary_info {
    my $self             = shift;
    my $feature_id_array = shift;

    for (
        my $feature_insertion_index = 0;
        $feature_insertion_index <= $#{ $feature_id_array || [] };
        $feature_insertion_index++
        )
    {
        my $attributes
            = $self->{'saved_feature_info'}{$feature_insertion_index};
        my $feature_id = $feature_id_array->[$feature_insertion_index];

        my $load_ids = $attributes->{'load_id'};

        foreach my $load_id ( @{ $load_ids || [] } ) {
            $self->load_to_cmap_ids(
                load_id => $load_id,
                cmap_id => $feature_id
            );
        }

        # Alias
        $self->handle_aliases( $feature_id, $attributes, );

        # Correspondences
        $self->handle_correspondences_by_id( $feature_id,
            $attributes->{'corr_by_id'} );

        # Attributes
        $self->handle_feature_attributes( $feature_id,
            $attributes->{'attribute'},
        );

        # Xrefs
        $self->handle_feature_xrefs( $feature_id, $attributes->{'xref'}, );
    }

    #$object->primary_id($feature_id);
}

# ----------------------------------------------------

=pod

=head2 handle_feature_attributes()

=cut

sub handle_feature_attributes {
    my $self           = shift;
    my $feature_id     = shift;
    my $attribute_list = shift || return;

    my $sql_object = $self->cmap_admin()->sql();
    foreach my $attribute_str ( @{ $attribute_list || [] } ) {
        my ( $name, $value )
            = map { uri_unescape($_) } split( /:/, $attribute_str, 2 );
        $sql_object->insert_attribute(
            object_id       => $feature_id,
            object_type     => 'feature',
            attribute_name  => $name,
            attribute_value => $value,
        );
    }

    return;
}

# ----------------------------------------------------

=pod

=head2 handle_feature_xrefs()

=cut

sub handle_feature_xrefs {
    my $self       = shift;
    my $feature_id = shift;
    my $xref_list  = shift || return;

    my $sql_object = $self->cmap_admin()->sql();
    foreach my $xref_str ( @{ $xref_list || [] } ) {
        my ( $name, $value )
            = map { uri_unescape($_) } split( /:/, $xref_str, 2 );
        $sql_object->insert_xref(
            object_id   => $feature_id,
            object_type => 'feature',
            xref_name   => $name,
            xref_url    => $value,
        );
    }

    return;
}

# --------------------------------------------------

=pod

=head2 handle_aliases()

=cut

sub handle_aliases {
    my $self       = shift;
    my $feature_id = shift;
    my $attributes = shift;

    my $aliases  = $attributes->{'Alias'};
    my $load_ids = $attributes->{'load_id'};

    my $cmap_admin = $self->cmap_admin();
ALIAS:
    foreach my $alias ( @{ $aliases || [] } ) {
        foreach my $load_id ( @{ $load_ids || [] } ) {
            next ALIAS if ( $load_id eq $alias );
        }
        $cmap_admin->feature_alias_create(
            feature_id => $feature_id,
            alias      => $alias,
        );
    }

    return;
}

# ----------------------------------------------------

=pod

=head2 handle_correspondence_by_id()

=cut

sub handle_correspondences_by_id {
    my $self         = shift;
    my $feature_id1  = shift;
    my $corr_strings = shift;

CORR:
    foreach my $corr_str ( @{ $corr_strings || [] } ) {
        my ( $load_id, $evidence_type_acc, $score )
            = split( /\s/, $corr_str );
        my %params;
        $params{'feature_id1'}       = $feature_id1;
        $params{'ID2'}               = $load_id;
        $params{'evidence_type_acc'} = $evidence_type_acc;
        $params{'score'}             = $score;
        $params{'desc_str'}          = $corr_str;

        $self->save_corr( \%params );
    }

    return;
}

# ----------------------------------------------------

=pod

=head2 qualify_tmp_db_name ()

=cut

sub qualify_tmp_db_name {
    my $self = shift;
    my $file = shift;
    unless ( $self->{'tmp_dir'} ) {
        $self->{'tmp_dir'} = File::Spec->tmpdir;
    }

    return $self->{'tmp_dir'} . '/' . $file;
}

sub corr_tmp_db_file_name {
    my $self = shift;
    return $self->qualify_tmp_db_name('corr_tmp_db.bdb');
}

sub attr_tmp_db_file_name {
    my $self = shift;
    return $self->qualify_tmp_db_name('attr_tmp_db.bdb');
}

sub xref_tmp_db_file_name {
    my $self = shift;
    return $self->qualify_tmp_db_name('xref_tmp_db.bdb');
}

sub corr_tmp_db {
    my $self = shift;
    unless ( $self->{'corr_tmp_db'} ) {
        $self->{'corr_tmp_db'}
            = $self->create_tmp_db( $self->corr_tmp_db_file_name() );
    }

    return $self->{'corr_tmp_db'};
}

sub attr_tmp_db {
    my $self = shift;
    unless ( $self->{'attr_tmp_db'} ) {
        $self->{'attr_tmp_db'}
            = $self->create_tmp_db( $self->attr_tmp_db_file_name() );
    }

    return $self->{'attr_tmp_db'};
}

sub xref_tmp_db {
    my $self = shift;
    unless ( $self->{'xref_tmp_db'} ) {
        $self->{'xref_tmp_db'}
            = $self->create_tmp_db( $self->xref_tmp_db_file_name() );
    }

    return $self->{'xref_tmp_db'};
}

sub create_tmp_db {
    my $self    = shift;
    my $db_file = shift;

    my %db;
    my $result
        = tie( %db, 'DB_File', $db_file, O_RDWR | O_CREAT, 0666, $DB_HASH );
    unless ($result) {
        $self->throw( "Couldn't tie: " . $db_file . " $!" );
    }
    %db = ();
    $db{'.next_id'} = TMP_DB_STARTING_ID;

    return \%db;
}

sub delete_tmp_databases {
    my $self = shift;

    unlink $self->corr_tmp_db_file_name() if ( $self->{'corr_tmp_db'} );
    unlink $self->attr_tmp_db_file_name() if ( $self->{'attr_tmp_db'} );
    unlink $self->xref_tmp_db_file_name() if ( $self->{'xref_tmp_db'} );

    return;
}

sub save_corr {
    my $self   = shift;
    my $params = shift;
    my $tmp_db = $self->corr_tmp_db();

    my $id = $tmp_db->{'.next_id'}++;
    $tmp_db->{$id} = nfreeze($params);

    return;
}

sub save_attr {
    my $self   = shift;
    my $params = shift;
    my $tmp_db = $self->attr_tmp_db();

    my $id = $tmp_db->{'.next_id'}++;
    $tmp_db->{$id} = nfreeze($params);

    return;
}

sub save_xref {
    my $self   = shift;
    my $params = shift;
    my $tmp_db = $self->xref_tmp_db();

    my $id = $tmp_db->{'.next_id'}++;
    $tmp_db->{$id} = nfreeze($params);

    return;
}

###
# Insert one Bio::SeqFeatureI into database. primary_id must be undef
#
sub insert { }

###
# Insert a bit of DNA or protein into the database
#
sub _insert_sequence { }

###
# This subroutine flags the given primary ID for later reindexing
#
sub flag_for_indexing { }

###
# Update indexes for given object
#
sub _update_indexes { }

sub _update_name_index { }

sub _update_attribute_index { }

sub _genericid { }

sub _typeid { }

sub _locationid { }

sub _attributeid { }

sub _get_location_and_bin { }

sub get_bin { }

sub bin_where { }

sub _delete_index { }

# given a statement handler that is expected to return rows of (id,object)
# unthaw each object and return a list of 'em
sub _sth2objs { }

# given a statement handler that is expected to return rows of (id,object)
# unthaw each object and return a list of 'em
sub _sth2obj { }

sub _prepare { }

####################################################################################################
# SQL Fragment generators
####################################################################################################

###
# special-purpose store for bulk loading - write to a file rather than to the db
#
sub _dump_store { }

sub _dump_add_SeqFeature { }

sub _dump_update_name_index { }

sub _dump_update_attribute_index { }

sub time {
    return Time::HiRes::time() if Time::HiRes->can('time');
    return time();
}

sub DESTROY { }

1;

=pod

=head1 SEE ALSO

L<Bio::DB::SeqFeature::Store>.
L<Bio::DB::SeqFeature::Store::GFF3Loader>.

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.
Modified from Bio::DB::SeqFeature::Store::DBI::mysql

=head1 COPYRIGHT

Copyright (c) 2008 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut
