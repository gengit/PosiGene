#!/usr/bin/perl
BEGIN{
	my @modules=("Bio::Align::AlignI","Bio::Align::Graphics","Bio::Align::Utilities","Bio::AlignIO","Bio::AlignIO::clustalw","Bio::AlignIO::fasta","Bio::AlignIO::phylip","Bio::LocatableSeq","Bio::Root::IO","Bio::SearchIO::blasttable","Bio::Seq","Bio::SeqFeature::Generic","Bio::SeqIO","Bio::SeqIO::fasta","Bio::SeqIO::genbank","Bio::SimpleAlign","Bio::Tree::Node","Bio::Tree::Tree","Bio::TreeIO","Bio::TreeIO::newick","Bio::TreeIO::tabtree","Cwd","File::Basename","File::Copy","File::Path","Getopt::Long","POSIX","Storable","threads","threads::shared","Thread::Queue");
	my $b=0;
	for my 	$arg(@ARGV){if($arg eq "-install_modules"){$b=1}}
	if($b){
		if(system("cpan -v &> /dev/null")!=0){print(STDERR "Could not find cpan. Check your perl installation!\n\n ");exit(1)}
		else{system("cpan ".join(" ",@modules));exit(0)}
	}
	else{
	#	#use lib "modules";
		my @modules_not_found;
		#for my $module("Cwd","File::Basename"){if(eval "require $module;"!=1){push(@modules_not_found,$module)}}
		#if (@modules_not_found!=0){modules_not_found(@modules_not_found)}	
		while (-l $0){$0=readlink($0)}
		my @path=split(/\/|\\/,$0);
		#print(join("/",@path[0..(@path-2)])."/modules\n");
		my $path=join("/",@path[0..(@path-2)])."/modules";
		if ($path eq "/modules"){$path="modules"}
		push (@INC,$path);
		#push (@INC,File::Basename::dirname(my_abs_path($0))."/modules");		
		if(eval "require threads;"!=1){print(STDERR "\nYour perl is not built to support threads. You have to build perl again using -Dusethreads.\n\n");exit(1);}
		#@INC=("modules",@INC);
		my @modules_not_found;
		for my $module(@modules){if (($module ne "Try::Tiny") && ($module ne "Bio::Align::Graphics") &&(eval "require $module;"!=1)){push(@modules_not_found,$module)}}
		if ((eval "require Try::Tiny;" ne "Try::Tiny") && (eval "require Try::Tiny;" ne 1)){push(@modules_not_found,"Try::Tiny")}
		if (@modules_not_found!=0){modules_not_found(@modules_not_found)}
		if ((eval "require Bio::Align::Graphics;")!=1){print(STDERR "Warning: LibGD or perl module GD is not installed. Alignment image output will not be possible. However, Jalview visualizations will still be created.\n\n")}
	}
	sub modules_not_found{
		my (@modules_not_found)=@_;
		print(STDERR "\nThe following needed modules were not found or have problems in the present perl-installation:\n\n");
		for my $module(@modules_not_found){print("$module\n")}
		print(STDERR "\n\n");
#		print(STDERR "The software should run fine if you have installed BioPerl as well as the Perl-packages GD (prerequisite of Bio::Align::Graphics) and Try::Tiny. If you have problems despite proper installations of these modules please contact us: asahm\@fli-leibniz.de.\n");
		exit(1);
	}
}



#for my $i (keys(%INC)){
#	print("$i: $INC{$i}\n");
#}
use strict;
use Getopt::Long;
use Cwd;
use File::Basename;
use Bio::TreeIO::newick;
use Bio::TreeIO::tabtree;
use Try::Tiny;
use Storable;
use Pod::Usage;

open (STDERR, ">/dev/null");#disable warnings, should be commented out when debugging 
no warnings;#disable warnings, should be commented out when debug

my $perl="perl";
my $bin_dir=File::Basename::dirname(my_abs_path($0))."/bin/";
my $parse_homologene=$bin_dir."parse_homologene2.pl";
my $add_a_public_non_homologene_species=$bin_dir."add_a_public_non_homologene_species_to_reference.pl";
my $RefAlignments=$bin_dir."RefAlignments_new.pl";
my $FindBestOrthologs=$bin_dir."FindBestOrthologs_Threads.pl";
my $createTreeFromAlignment=$bin_dir."createTreeFromAlignment.pl";
my $realign_with_prank=$bin_dir."realign_with_prank.pl";
my $CodeML_positive_selection=$bin_dir."CodeML_positive_selection.pl";
my $java="java";
my $jalview="jalview.jar";

my $help=0;
my $output_path="./";
my @gbks_part_of_homologene;
my @gbks_or_fas_not_part_of_homologene;#optional
my @gbks_or_fas_not_part_of_homologene_by_symbol;#optional
my @gbks_or_fas_not_part_of_homologene_by_reference;#optional
my $gbk_or_fa_not_part_of_homologene_reference="";#optional
my @selected_species;
my @target_species;
my $treeFile="";
my $showTree="";
my $viewFile="";
my $info=0;
my $mode="all";#optional
my $homologene=$bin_dir."homologene_106.data";#optional
my $threadNum=8;#optional
my $tested_branch_name="";#optional
my $use_prank=1;#optional
my $genetic_code=1;#optional
my $continue=0;#optional
my $info=0;
my $non_homologene_BLASTthreshold=1E-04;#optional
my $minPercOrthologIdentity="70.0";#optional
my $minPercOrthologIdentityAllPairwise="50.0";#optional
my $max_gblocks_input_aln_gap_percentage_hard="50.0";#optional
my $max_gblocks_input_aln_gap_percentage_soft="40.0";#optional
my $max_gblocks_input_anchor_seq_gap_percentage_hard="33.33";#optional
my $max_gblocks_input_anchor_seq_gap_percentage_soft="20.0";#optional
my $min_codeml_input_aln_length=60;#optional
my $min_codeml_input_aln_seq_num_soft=4;
my $min_codeml_input_aln_seq_num_hard=3;
my $createTreeAlignmentChunkSize=15000;

my $min_foreground_KaKs=0.85;
my $max_foreground_KaKs=150;
my @context_species=("auto");
my $min_outgroups=0;
my $BEB_significance_threshold=0.4;
my $min_BEBs=1;
my $BEB_excess_percentage=0.2;
my $BEB_if_excess_min=0.9;
my $flanking_region_size=2;

#@ARGV=("-o=/home/lakatos/asahm/enton/7_ant_species+5_outgroups/","-hs=/home/lakatos/asahm/enton/MRNA_public_data/Hymenoptera_and_outgroups/Drosophila_melanogaster_NCBI_mrna_RefSeq_15.09.2014.gbk,","-nhs=Nasonia vitripenis:/home/lakatos/asahm/enton/MRNA_public_data/Hymenoptera_and_outgroups/Nvit_OGSv1.2_rna.fa,Pediculus humanus:/home/lakatos/asahm/enton/MRNA_public_data/Hymenoptera_and_outgroups/Pediculus-humanus-USDA_TRANSCRIPTS_PhumU2.1.fa,Tribolium castaneum:/home/lakatos/asahm/enton/MRNA_public_data/Hymenoptera_and_outgroups/Tribolium_castaneum_CDS_Peptide_CDS.fa,Atta cephalotes:/home/lakatos/asahm/enton/MRNA_public_data/Hymenoptera_and_outgroups/acep.genome.OGS.1.2.maker.transcripts.fasta,Acromyrmex echinatior:/home/lakatos/asahm/enton/MRNA_public_data/Hymenoptera_and_outgroups/aech_OGSv3.8_transcript.fa,Apis mellifera:/home/lakatos/asahm/enton/MRNA_public_data/Hymenoptera_and_outgroups/amel_OGSv3.2_cds.fa,Camponotus floridanus:/home/lakatos/asahm/enton/MRNA_public_data/Hymenoptera_and_outgroups/cflo_OGSv3.3_transcript.fa,Harpegnathos saltator:/home/lakatos/asahm/enton/MRNA_public_data/Hymenoptera_and_outgroups/hsal_OGSv3.3_transcript.fa,Linepithema humile:/home/lakatos/asahm/enton/MRNA_public_data/Hymenoptera_and_outgroups/lhum.genome.OGS.1.2.maker.transcripts.fasta,Pogonomyrmex barbatus:/home/lakatos/asahm/enton/MRNA_public_data/Hymenoptera_and_outgroups/pbar_OGSv1.2_transcript.fa,Solenopsis invicta:/home/lakatos/asahm/enton/MRNA_public_data/Hymenoptera_and_outgroups/sinv_OGSv2.2.3_transcript.fa","-ss=\"Harpegnathos saltator\"" ,"-t=/home/lakatos/asahm/enton/7_ant_species+5_outgroups/tree.newick","-tn=64","-mode=positive_selection");#test
#@ARGV=("-o=/home/lakatos/asahm/enton/Tibetan_Antelope+9_species/","-hs=/home/lakatos/asahm/enton/MRNA_public_data/Homo_sapiens_NCBI_mrna_RefSeq_16.06.2014.gbk,/home/lakatos/asahm/enton/MRNA_public_data/Mus_musculus_NCBI_mrna_RefSeq_16.06.2014.gbk,/home/lakatos/asahm/enton/MRNA_public_data/Rattus_norvegicus_NCBI_mrna_RefSeq_16.06.2014.gbk,/home/lakatos/asahm/enton/MRNA_public_data/Bos_taurus_NCBI_mrna_RefSeq_16.06.2014.gbk,/home/lakatos/asahm/enton/MRNA_public_data/Canis_lupus_familiaris_NCBI_mrna_RefSeq_16.06.2014.gbk,/home/lakatos/asahm/enton/MRNA_public_data/Macaca_mulatta_NCBI_mrna_RefSeq_24.06.2014.gbk,/home/lakatos/asahm/enton/MRNA_public_data/Pan_troglodytes_NCBI_mrna_RefSeq_24.06.2014.gbk", "-nhs=/home/lakatos/asahm/enton/MRNA_public_data/Equus_caballus_NCBI_mrna_RefSeq_03.09.2014.gbk,/home/lakatos/asahm/enton/MRNA_public_data/Monodelphi_domestica_NCBI_mrna_RefSeq_03.09.2014.gbk,/home/lakatos/asahm/enton/MRNA_public_data/Pantholops_hodgsonii_NCBI_mrna_RefSeq_03.09.2014.gbk", "-ss=\"Pantholops hodgsonii\"" ,"-t=/home/lakatos/asahm/enton/Tibetan_Antelope+9_species/tree.newick","-tn=64","-mode=positive_selection","-bn=test_again");#test
#@ARGV=("-o=/home/lakatos/asahm/enton/Tibetan_Antelope+9_species_minIdent=80/","-hs=/home/lakatos/asahm/enton/MRNA_public_data/Homo_sapiens_NCBI_mrna_RefSeq_16.06.2014.gbk,/home/lakatos/asahm/enton/MRNA_public_data/Mus_musculus_NCBI_mrna_RefSeq_16.06.2014.gbk,/home/lakatos/asahm/enton/MRNA_public_data/Rattus_norvegicus_NCBI_mrna_RefSeq_16.06.2014.gbk,/home/lakatos/asahm/enton/MRNA_public_data/Bos_taurus_NCBI_mrna_RefSeq_16.06.2014.gbk,/home/lakatos/asahm/enton/MRNA_public_data/Canis_lupus_familiaris_NCBI_mrna_RefSeq_16.06.2014.gbk,/home/lakatos/asahm/enton/MRNA_public_data/Macaca_mulatta_NCBI_mrna_RefSeq_24.06.2014.gbk,/home/lakatos/asahm/enton/MRNA_public_data/Pan_troglodytes_NCBI_mrna_RefSeq_24.06.2014.gbk", "-nhs=/home/lakatos/asahm/enton/MRNA_public_data/Equus_caballus_NCBI_mrna_RefSeq_03.09.2014.gbk,/home/lakatos/asahm/enton/MRNA_public_data/Monodelphi_domestica_NCBI_mrna_RefSeq_03.09.2014.gbk,/home/lakatos/asahm/enton/MRNA_public_data/Pantholops_hodgsonii_NCBI_mrna_RefSeq_03.09.2014.gbk", "-ss=\"Pantholops hodgsonii\"" ,"-t=/home/lakatos/asahm/enton/Tibetan_Antelope+9_species/tree.newick","-tn=40","-minIdent=80","-continue");#test
#@ARGV=("-o=/home/lakatos/asahm/enton/Public_Hglaber+3Species/","-hs=/home/lakatos/asahm/enton/MRNA_public_data/Homo_sapiens_NCBI_mrna_RefSeq_16.06.2014.gbk,/home/lakatos/asahm/enton/MRNA_public_data/Mus_musculus_NCBI_mrna_RefSeq_16.06.2014.gbk,/home/lakatos/asahm/enton/MRNA_public_data/Rattus_norvegicus_NCBI_mrna_RefSeq_16.06.2014.gbk", "-nhs=/home/lakatos/asahm/enton/MRNA_public_data/Heterocephalus_glaber_NCBI_mrna_RefSeq_06.08.2014.gbk", "-ss=\"Heterocephalus glaber\"" ,"-t=/home/lakatos/asahm/enton/Public_Hglaber+3Species/tree.newick","-tn=40","-mode=positive_selection");#test
#@ARGV=("-o=/home/lakatos/asahm/Desktop/Test_positive_selection2/","-ss=Pantholops_hodgsonii","-mode=alignments","-tn=16");
#@ARGV=("-o=/home/lakatos/asahm/Desktop/Test_PublicHglaber+3_species3/","-ss=Heterocephalus_glaber","-mode=positive_selection","-tn=16","-t=/home/lakatos/asahm/Desktop/Test_PublicHglaber+3_species/my_tree2.newick");
#@ARGV=("-o=/home/lakatos/asahm/enton/Public_Hglaber+3Species_new_perc_ident/","-hs=/home/lakatos/asahm/enton/MRNA_public_data/Homo_sapiens_NCBI_mrna_RefSeq_16.06.2014.gbk,/home/lakatos/asahm/enton/MRNA_public_data/Mus_musculus_NCBI_mrna_RefSeq_16.06.2014.gbk,/home/lakatos/asahm/enton/MRNA_public_data/Rattus_norvegicus_NCBI_mrna_RefSeq_16.06.2014.gbk", "-nhs=/home/lakatos/asahm/enton/MRNA_public_data/Heterocephalus_glaber_NCBI_mrna_RefSeq_06.08.2014.gbk", "-ss=\"Heterocephalus glaber\"","-tn=64","-mode=positive_selection","-t=/misc/enton/data/asahm/Public_Hglaber+3Species_new_perc_ident/tree_selected_species_Heterocephalus_glaber.newick");


my $args=@ARGV;
if(!GetOptions("genetic_code=i" => \$genetic_code,"info=i" => \$info,"view=s" => \$viewFile,"show_tree=s" => \$showTree,"flank_size=i" => \$flanking_region_size,"context_species|cs=s" => \@context_species, "min_outgroups=i" => \$min_outgroups ,"min_site_signifance|min_BEB_siginifance=s" => \$BEB_significance_threshold,"min_site_num|min_BEB_num=i" => \$min_BEBs,"site_excess|BEB_excess=f" => \$BEB_excess_percentage,"site_if_excess_min|BEB_if_excess_min=f"=> \$BEB_if_excess_min,"max_KaKs|max_omega=f" => \$min_foreground_KaKs,"min_KaKs|min_omega=f" => \$min_foreground_KaKs, "help|h|?" => \$help, "output_dir|o=s" => \$output_path,"homologene_species|hs=s"=> \@gbks_part_of_homologene,"non_homologene_species|nhs=s"=> \@gbks_or_fas_not_part_of_homologene,"non_homologene_species_by_symbol|nhsbs=s"=>\@gbks_or_fas_not_part_of_homologene_by_symbol,"non_homologene_species_by_reference|nhsbr=s"=>\@gbks_or_fas_not_part_of_homologene_by_reference,"reference_species|rs|reference=s"=>\$gbk_or_fa_not_part_of_homologene_reference,"anchor_species|as|selected_species|ss=s" => \@selected_species,"t|tree_file=s" => \$treeFile, "suffix|branch_name|bn=s" => \$tested_branch_name,"mode|m=s" => \$mode, "homologene_file|hf=s"=> \$homologene,"thread_num|tn|cpus=i" => \$threadNum,"use_prank=i"=>\$use_prank,"continue|c" => \$continue, "blast_threshold=f"=> \$non_homologene_BLASTthreshold, "minIdent|min_ident=f" => \$minPercOrthologIdentity, "minPairsIdent|min_pairs_ident=f" => \$minPercOrthologIdentityAllPairwise,"max_aln_gaps_hard=f" =>\$max_gblocks_input_aln_gap_percentage_hard,"max_aln_gaps_soft=f" =>\$max_gblocks_input_aln_gap_percentage_soft,"max_anchor_gaps_hard=f" =>\$max_gblocks_input_anchor_seq_gap_percentage_hard,"max_anchor_gaps_soft=f" =>\$max_gblocks_input_anchor_seq_gap_percentage_soft,"min_aln_length=i" => \$min_codeml_input_aln_length, "min_seq_num_hard=i" => \$min_codeml_input_aln_seq_num_hard, "min_seq_num_soft=i" => \$min_codeml_input_aln_seq_num_soft, "target_species|ts=s" => \@target_species, "info" => \$info)){
	print($SIG{__WARN__});
	exit(1);
}


my $gbk_or_fa_not_part_of_homologene_reference_path="";
if ($gbk_or_fa_not_part_of_homologene_reference ne ""){
	if (int(split(":",$gbk_or_fa_not_part_of_homologene_reference))<2){
		$gbk_or_fa_not_part_of_homologene_reference_path=my_abs_path($gbk_or_fa_not_part_of_homologene_reference);
		$gbk_or_fa_not_part_of_homologene_reference=my_abs_path($gbk_or_fa_not_part_of_homologene_reference);
	}
	else{
		my @h=split(":",$gbk_or_fa_not_part_of_homologene_reference);
		$gbk_or_fa_not_part_of_homologene_reference=$h[0].":".my_abs_path($h[1]);
		$gbk_or_fa_not_part_of_homologene_reference_path=my_abs_path($h[1]);
	}
}

@gbks_part_of_homologene = split(/,/,join(',',@gbks_part_of_homologene));
for my $gbk_part_of_homologene (@gbks_part_of_homologene){$gbk_part_of_homologene=my_abs_path($gbk_part_of_homologene)}

@gbks_or_fas_not_part_of_homologene = split(/,/,join(',',@gbks_or_fas_not_part_of_homologene));
my $gbks_or_fas_not_part_of_homologene=scalar(@gbks_or_fas_not_part_of_homologene);
@gbks_or_fas_not_part_of_homologene_by_symbol = split(/,/,join(',',@gbks_or_fas_not_part_of_homologene_by_symbol));
my %gbks_or_fas_not_part_of_homologene_is_method_BLAST;
@gbks_or_fas_not_part_of_homologene_by_reference = split(/,/,join(',',@gbks_or_fas_not_part_of_homologene_by_reference));

for my $gbk_or_fa_not_part_of_homologene(@gbks_or_fas_not_part_of_homologene){
	if (int(split(":",$gbk_or_fa_not_part_of_homologene))<2){$gbk_or_fa_not_part_of_homologene=my_abs_path($gbk_or_fa_not_part_of_homologene);}
	else{
		my @h=split(":",$gbk_or_fa_not_part_of_homologene);
		$gbk_or_fa_not_part_of_homologene=$h[0].":".my_abs_path($h[1]);
	}
	$gbks_or_fas_not_part_of_homologene_is_method_BLAST{$gbk_or_fa_not_part_of_homologene}=1;
}

for my $gbk_or_fa_not_part_of_homologene(@gbks_or_fas_not_part_of_homologene_by_symbol){
	if (int(split(":",$gbk_or_fa_not_part_of_homologene))<2){$gbk_or_fa_not_part_of_homologene=my_abs_path($gbk_or_fa_not_part_of_homologene);}
	else{
		my @h=split(":",$gbk_or_fa_not_part_of_homologene);
		$gbk_or_fa_not_part_of_homologene=$h[0].":".my_abs_path($h[1]);
	}
	$gbks_or_fas_not_part_of_homologene_is_method_BLAST{$gbk_or_fa_not_part_of_homologene}=0;
}

for my $gbk_or_fa_not_part_of_homologene(@gbks_or_fas_not_part_of_homologene_by_reference){
	if (int(split(":",$gbk_or_fa_not_part_of_homologene))<2){$gbk_or_fa_not_part_of_homologene=my_abs_path($gbk_or_fa_not_part_of_homologene);}
	else{
		my @h=split(":",$gbk_or_fa_not_part_of_homologene);
		$gbk_or_fa_not_part_of_homologene=$h[0].":".my_abs_path($h[1]);
	}
	$gbks_or_fas_not_part_of_homologene_is_method_BLAST{$gbk_or_fa_not_part_of_homologene}=2;
}

push(@gbks_or_fas_not_part_of_homologene,@gbks_or_fas_not_part_of_homologene_by_symbol,@gbks_or_fas_not_part_of_homologene_by_reference);

@selected_species = split(/,/,join(',',@selected_species));
@target_species = split(/,/,join(',',@target_species));
@context_species = split(/,/,join(',',@context_species));
if(@context_species>1){@context_species=@context_species[1..$#context_species]}

$output_path=my_abs_path($output_path);

if ($treeFile ne ""){$treeFile=my_abs_path($treeFile);}

for my $species(@selected_species){$species=~s/ /_/g;}
for my $species(@target_species){$species=~s/ /_/g;}

if ((substr($output_path,length($output_path)-1,1) ne "/") && (substr($output_path,length($output_path)-1,1) ne "\\")){$output_path.="/";}
my $ortholog_assignments_dir=$output_path."ortholog_assignment/";
my $logs_dir=$output_path."logs/";
my $result_tables_dir=$output_path."result_tables/";
my $trees_dir=$output_path."trees/";
my $individual_results_dir=$output_path."individual_results/";

my $transcr_to_prot=$ortholog_assignments_dir."transcr_to_prot.hash";
my $prot_to_symbol=$ortholog_assignments_dir."prot_to_symbol.hash";
my $transcr_to_symbol=$ortholog_assignments_dir."transcr_to_symbol.hash";
my $progress=$output_path."progress";

$mode=lc($mode);
$mode=~s/ /_/g;
if ($mode eq "create_catalogue"){$mode="create_catalog"}
if ($help || ($args==0)){
	myprint("\nUsage (default mode):","b");
	myprint("perl ".my_abs_path($0)." -as=anchor_species_name -ts=list_of_target_species_names [(-hs && -nhs) || (-rs && -nhsbr) || (-nhsbs)] [optional arguments]\n");
	myprint("Obligatory arguments\n","b");
	myprint("-anchor_species|-as -> The NAME of your chosen anchor species. Must be part of the passed species set.\n");	
	myprint("-target_species|ts -> Comma separated NAME list of your chosen target species. Must be part of the passed species set.\n");
	myprint(" CDS input files\n","b");
	myprint("  HomoloGene based ortholog assignment\n","b");
	myprint("Each input file should contain all CDSs of exactly one species. Genbank files (*.gb,*.gbk) are passed listing simply the respective file path. Fasta files (*.fa, *.fas, *.fasta) are passed by species_name:path_to_fasta_file.\n");
	myprint("-homologene_species|-hs -> Comma separated list of paths to genbank files containing sequences of a species that is part of the HomoloGene database.\n");
	myprint("-non_homologene_species|-nhs -> Comma separated list of paths to genbank or fasta files with sequences of a species that is not part of the HomoloGene database.\n");
	myprint("  Reference based ortholog assignment\n","b");
	myprint("-reference_species|-rs -> Path to a genbank or fasta file with sequences of a species that shall be used as reference for ortholog assignment. The reference species will NOT be added to the analysis automatically. If you want it being  part of the analysis simply add it to the species list passed with the -nhsbr argument.\n");
	myprint("-non_homologene_species_by_reference|-nhsbr -> Comma separated list of paths to genbank or fasta files with sequences of a species that is not part of the HomoloGene database.\n");
	myprint(" Symbol based ortholog assignment\n","b");
	myprint("-non_homologene_species_by_symbol|-nhsbs -> Comma separated list of paths to genbank or fasta files with sequences of a species that is not part of the HomoloGene database.\n");
	myprint("\nOptional arguments\n","b");
	myprint(" Frequently used arguments\n","b");
	myprint("-output_dir|-o=./(default) -> Directory in that the program writes its results to.\n");
	myprint("-thread_num|-tn|-cpus=8(default) -> Number of threads that will be used.\n");
	myprint("-mode=all(default)|create_catalog|alignments|positive_selection|add_species|info|show_tree|view -> Specifies which steps will be performed by PosiGene.\n");
	myprint("-branch_name|-bn=\"\"(default) -> This argument prevents your results to be overwritten after testing additonal branches with mode=positive_selection. All new results will include the passed string in their respective file names.\n");
	myprint("-view -> The passed *.view file will be visualized. \n");	
	myprint("-show_tree -> The passed newick tree will be printed in tab-tree format.\n");		
	myprint("-info -> Prints summarized information about what has been done on the chosen output directory ( o) so far.\n");		
	myprint("-continue -> If the program was interrupted by some reason use the same arguments and -continue to proceed at the last accomplished step.\n");		
	myprint("-tree_file|-t -> Path to a file that contains an phylogenetic tree in Newick format. Obligatory for mode=positive_selection.\n");
	myprint(" Fine-tuning arguments\n","b");
	myprint("  mode=create_catalog","b");
	myprint("-homologene_file|-hf, -blast_threshold\n");
	myprint("  mode=alignments","b");
	myprint("-use_prank, -min_ident, -min_pairs_ident\n");
	myprint("  mode=positive_selection","b");
	myprint("-context_species|cs, -min_outgroups, -max_aln_gaps_soft, -max_aln_gaps_hard, -max_anchor_gaps_soft, -max_anchor_gaps_hard, -min_seq_num_soft, -min_seq_num_hard, -min_aln_length, -min_KaKs|min_omega, -max_KaKs|max_omega, -min_site_num, -min_site_signifance, -site_excess, -site_if_excess_min, -flank_size, -genetic_code\n");
	myprint("\nSee user guide for more detailed information.\n");
	exit(0);
}
if (($mode eq "view") || ($viewFile ne "")){
	if ($viewFile eq ""){print("You have to specify a *.view file with the parameter -view (-view=some_example.view)...\n");exit(1);}
	try{
		my %viewParams=%{Storable::retrieve($viewFile)};
		my $dir=File::Basename::dirname(my_abs_path($viewFile));
		my $codeml_dir=File::Basename::dirname($dir);
		if ((substr($dir,length($dir)-1,1) ne "/") && (substr($dir,length($dir)-1,1) ne "\\")){$dir.="/"}
		if ((substr($codeml_dir,length($codeml_dir)-1,1) ne "/") && (substr($codeml_dir,length($codeml_dir)-1,1) ne "\\")){$codeml_dir.="/"}
		#print($viewParams{"alignment"}."\n$dir\n$codeml_dir\n");
		if((exists($viewParams{"alignment"})) && (-e $dir.$viewParams{"alignment"}) && (exists($viewParams{"tree"})) && (-e $codeml_dir.$viewParams{"tree"}) && (exists($viewParams{"annotations"})) && (-e $dir.$viewParams{"annotation"}) && (exists($viewParams{"colour"})) && ($viewParams{"colour"}) ne ""){
			system("$java -Djava.ext.dirs=$bin_dir"."lib -jar $bin_dir$jalview -open $dir$viewParams{alignment} -tree $codeml_dir$viewParams{tree} -annotations $dir$viewParams{annotations} -colour $viewParams{colour}");
		}else{print("$viewFile was not found or is damaged.\n");exit(1)}
	}catch{print("$viewFile was not found or is damaged.\n");exit(1)};
	exit(0);
}
elsif (($mode eq "show_tree") || ($showTree ne "")){
	$treeFile=$showTree;
	my $tree = checkTree();
	print("\n\n");
	Bio::TreeIO->new(-fh => $STDOUT, -format => 'tabtree')->write_tree($tree);
	print("\n\n");
	exit(0);
}

if ($output_path eq ""){
	print("You have to specifiy an output directory path...\n");
	exit();
}

if (($mode ne "all") && ($mode ne "create_catalog") && ($mode ne "add_species") && ($mode ne "alignments") && ($mode ne "positive_selection") && ($mode ne "info") && ($mode ne "show_tree") && ($mode ne "view")){
	print("Unknown mode $mode!\n");
	exit(1);
} 

my $status=-1;
if ($continue || ($mode eq "info") || ($info)){
	if (!((-e $progress) && (-f $progress) && (-r $progress))){
		print("Could not open $output_path.progress. Use of \"continue\" on path $output_path not possible...\n");
		exit(1);
	}
	my $pipeline_status=Storable::retrieve($progress);
	my @status_strings=("HomoloGene based ortholog assignment","Best bidirectional BLAST based/user defined ortholog assignment","Alignment creation (all splice variants per gene)","Filtering and reduction to one splice variant per gene and species","Species tree creation","Realignment (one splice variant per gene and species)","Positive selection analysis");
	$status=show_pipeline_status($pipeline_status,$mode,$output_path,\@status_strings);
	if (($mode eq "info") || ($info)){exit(0)}
	if ($status==1){
		if (@gbks_or_fas_not_part_of_homologene>0){$status=2;}
		else{$status=3;}
	}elsif ($status==2){
		if (@gbks_or_fas_not_part_of_homologene > keys(%{$pipeline_status->{"add_a_public_non_homologene_species"}})){$status=2;}
		else {$status=3;}
	}elsif($status==4){
			if($treeFile eq ""){$status=5}
			else{$status=6}
	}elsif($status==5){
		if ($use_prank){$status=6}
		else {$status=7}
	}
	elsif ($status==7){$status=7}
	else{$status++}
	print("Continue with $status. \"$status_strings[$status-1]\"?(y/n)\n");
	my $answer=lc(substr(<STDIN>,0,1));
	if ($answer ne "y"){exit(0)}
	else{print("Continue with $status. \"$status_strings[$status-1]\"...\n")}
}

if (($mode eq "all") || ($mode eq "create_catalog") || ($mode eq "add_species")){
	if (!(($continue) && ($status>1)) && !($mode eq "add_species")){
		if (!((-e $homologene) && (-f $homologene) && (-r $homologene))){
			print("Could not open file \"$homologene\"...\n");
			exit(1);
		}
		if ((int(@gbks_part_of_homologene)+int(@gbks_or_fas_not_part_of_homologene)<3) && ($mode eq "all")){
			print("You have to specify at least three genbank (.gbk or .gb)/fasta (.fasta or .fa) files, each corresponding with different species, to make a meaningful analysis of positive selection...\n");
			exit(1);
		}
		
		
		if ((!defined(@gbks_part_of_homologene)) && ($gbks_or_fas_not_part_of_homologene>0)){
			print("You have to specify at least one genbank (.gbk or .gb) file with sequences of a species part of HomoloGene (parameter: homologene_species|hs)...\n");
			exit(1);
		}
		
		
		for my $gbk_path(@gbks_part_of_homologene){
			if (!((-e $gbk_path) && (-f $gbk_path) && (-r $gbk_path))){
				print ("Could not open file \"$gbk_path\"...\n");
				exit(1);
			}
		}
	}
	if (!(($continue) && ($status>2)) || ($mode eq "add_species")){
		if (!defined(@gbks_or_fas_not_part_of_homologene) && ($mode eq "add_species")){
			print("You have to specify at least one genbank (.gbk or .gb) or fasta file with sequences of one species...\n");
			exit(1);
		}		
		
		if ((@gbks_or_fas_not_part_of_homologene_by_reference>0) && ($gbk_or_fa_not_part_of_homologene_reference eq "")){
			print("You used the -nhsrb option. This means you try to construct ortholog groups based on a reference. Thus, you have to specify a genbank (.gbk or .gb)/fasta (.fasta or .fa) reference file (parameter: -reference_species|rs)...\n");
			exit(1);
		}
		
		if(($gbk_or_fa_not_part_of_homologene_reference ne "") && !(-e $gbk_or_fa_not_part_of_homologene_reference_path)){
			print("Could not open reference-file $gbk_or_fa_not_part_of_homologene_reference...\n");
			exit(1);
		}
		
		for my $gbk_or_fa_path(@gbks_or_fas_not_part_of_homologene){
			my $path;	
			if (int(split(":",$gbk_or_fa_path))>1){$path=(split(":",$gbk_or_fa_path))[1]}
			else{$path=$gbk_or_fa_path}		
			if (!((-e $path) && (-f $path) && (-r $path))){			
				print ("Could not open file \"$path\"...\n");
				exit(1);
			}
		}
	}
}
#if ($mode eq "add_species"){
#		if (!defined(@gbks_or_fas_not_part_of_homologene)){
#			print("You have to specify at least one genbank (.gbk or .gb) or fasta file with sequences of one species...\n");
#			exit(1);
#		}
#		for my $gbk_or_fa_path(@gbks_or_fas_not_part_of_homologene){
#			my $path;	
#			if (int(split(":",$gbk_or_fa_path))>1){$path=(split(":",$gbk_or_fa_path))[1]}
#			else{$path=$gbk_or_fa_path}			
#			if (!((-e $path) && (-f $path) && (-r $path))){			
#				print ("Could not open file \"$path\"...\n");
#				exit(1);
#			}
#		}
#}
if (($mode eq "all") || ($mode eq "alignments")){
	if (!(($continue) && ($status>6))){
		if (!defined(@selected_species)){
	 		print("You have to specifiy at least one anchor-species for alignments with one sequence per species (parameter: selected_species|ss)...\n");
	 		exit(1);
		}
		if (($use_prank) && ($treeFile ne "")){checkTree($treeFile);}
	}
}
if (($mode eq "all") || ($mode eq "positive_selection")){
	if (!defined(@selected_species)){
 		print("You have to specifiy at least one anchor-species (parameter: anchor_species|as)...\n");
 		exit(1);
	}
	if(($mode eq "positive_selection") || ($treeFile ne "")) {checkTree($treeFile);}
	if (($min_codeml_input_aln_seq_num_soft<3) || ($min_codeml_input_aln_seq_num_hard<3)){
		print("min_seq_num_hard and min_seq_num_soft cannot be lower than 3...\n");
		exit(1);
	}
}

if (!((-e $output_path) && (-d $output_path))) {File::Path->make_path($output_path)};
if (!((-e $output_path) && (-d $output_path) && (-w $output_path))) {
	print("Could not write to directory $output_path...\n");
	exit(1)
}

if (($mode eq "all") || ($mode eq "create_catalog") || ($mode eq "add_species")){
	if (!(($continue) && ($status>1))){
		my_mkdir($logs_dir,$ortholog_assignments_dir,$individual_results_dir);
		my $gbks_string="";
		for my $gbk_path(@gbks_part_of_homologene){$gbks_string.="\"$gbk_path\" ";}
		my $logFile=$logs_dir."parse_homologene.log";
		if (defined(@gbks_part_of_homologene)){my_system("\"$perl\" \"$parse_homologene\" \"$progress\" \"$individual_results_dir\" \"$ortholog_assignments_dir\" \"$homologene\" \"$transcr_to_prot\" \"$prot_to_symbol\" \"$transcr_to_symbol\" \"$logFile\" $gbks_string");}
	}
	if (!(($continue) && ($status>2)) || ($mode eq "add_species")){
		my $i=0;
		my $reference_transcr_to_symbol;
		if ($gbk_or_fa_not_part_of_homologene_reference ne ""){
			my_mkdir($logs_dir,$ortholog_assignments_dir);
			my $logFile=$logs_dir."add_a_public_non_homologene_species_to_reference_".File::Basename::basename($gbk_or_fa_not_part_of_homologene_reference).".log";
			$reference_transcr_to_symbol=$ortholog_assignments_dir."transcr_to_symbol_".File::Basename::basename($gbk_or_fa_not_part_of_homologene_reference);
			if (int(split(":",$gbk_or_fa_not_part_of_homologene_reference))>1){$logFile=$logs_dir."add_a_public_non_homologene_species_to_reference_".File::Basename::basename((split(":",$gbk_or_fa_not_part_of_homologene_reference))[1]).".log"}		
			my $makeReference=1;
			if ((contain($gbk_or_fa_not_part_of_homologene_reference,@gbks_or_fas_not_part_of_homologene_by_symbol)) || (contain($gbk_or_fa_not_part_of_homologene_reference,@gbks_or_fas_not_part_of_homologene_by_reference))){$makeReference=2}			
			my_system("\"$perl\" \"$add_a_public_non_homologene_species\" \"$gbk_or_fa_not_part_of_homologene_reference\" \"$progress\" \"$individual_results_dir\" \"$ortholog_assignments_dir\" $makeReference 0 $reference_transcr_to_symbol 0 $genetic_code \"$logFile\" $threadNum 0 0 \"reference-file\"");
		}
		for my $gbk_or_fa_path(@gbks_or_fas_not_part_of_homologene){
			my $reference=$ortholog_assignments_dir."all.fastp";
			my $current_transcr_to_symbol=$transcr_to_symbol;
			if($gbks_or_fas_not_part_of_homologene_is_method_BLAST{$gbk_or_fa_path}==2){
				$reference=$ortholog_assignments_dir.File::Basename::basename($gbk_or_fa_not_part_of_homologene_reference_path).".translation";
				$current_transcr_to_symbol=$reference_transcr_to_symbol;
			}
			my $logFile=$logs_dir."add_a_public_non_homologene_species_to_reference_".File::Basename::basename($gbk_or_fa_path).".log";
			if (int(split(":",$gbk_or_fa_path))>1){$logFile=$logs_dir."add_a_public_non_homologene_species_to_reference_".File::Basename::basename((split(":",$gbk_or_fa_path))[1]).".log"}		
			my_system("\"$perl\" \"$add_a_public_non_homologene_species\" \"$gbk_or_fa_path\" \"$progress\" \"$individual_results_dir\" \"$ortholog_assignments_dir\" 0 $reference $current_transcr_to_symbol $non_homologene_BLASTthreshold $genetic_code \"$logFile\" $threadNum 0 $gbks_or_fas_not_part_of_homologene_is_method_BLAST{$gbk_or_fa_path} \"species-file ".(++$i)."/".int(@gbks_or_fas_not_part_of_homologene)."\"");
		}
	}
}

#if ($mode eq "add_species"){
#	my $i=0;
#	for my $gbk_or_fa_path(@gbks_or_fas_not_part_of_homologene){
#		my $logFile;
#		if (int(split(":",$gbk_or_fa_path))>1){$logFile="add_a_public_non_homologene_species_to_reference_".File::Basename::basename((split(":",$gbk_or_fa_path))[1]).".log"}
#		else {$logFile="add_a_public_non_homologene_species_to_reference_".File::Basename::basename($gbk_or_fa_path).".log"}
#		my_system("\"$perl\" \"$add_a_public_non_homologene_species\" \"$gbk_or_fa_path\" \"$output_path\" \"$transcr_to_symbol\" $non_homologene_BLASTthreshold $genetic_code \"$logFile\" $threadNum 0 $gbks_or_fas_not_part_of_homologene_is_method_BLAST{$gbk_or_fa_path} \"species-file ".(++$i)."/".int(@gbks_or_fas_not_part_of_homologene)."\"");
#	}	
#}

my %treeFiles;
if (($mode eq "all") || ($mode eq "alignments")){
	my_mkdir($logs_dir,$trees_dir,$individual_results_dir);
	if (!(($continue) && ($status>3))){
		my $logFile=$logs_dir."RefAlignments.log";
		my_system("\"$perl\" \"$RefAlignments\" \"$progress\" \"$individual_results_dir\" $threadNum \"$logFile\"");
	}
	my $species_string="";
	my $concat_alns_string="";
	my %concat_alns;
	my $FindBestOrthologs_log_file=$logs_dir."FindBestOrthologs_";
	my $realign_with_prank_log_file=$logs_dir."realign_with_prank_";
	my $createTreeFromAlignment_log_file=$logs_dir."createTreeFromAlignment_";
	for my $species(@selected_species){
		$species_string.="$species,";
		$FindBestOrthologs_log_file.="$species+";
		$realign_with_prank_log_file.="$species+";
		$createTreeFromAlignment_log_file.="$species+";
		$concat_alns_string.=$trees_dir."selected_species_".$species."_concat_aln.fasta,";
		$concat_alns{$species}=$trees_dir."selected_species_".$species."_concat_aln.fasta";
		$treeFiles{$species}=$trees_dir."tree_anchor_species_$species.newick";
	}
	$FindBestOrthologs_log_file=substr($FindBestOrthologs_log_file,0,length($FindBestOrthologs_log_file)-1).".log";
	$realign_with_prank_log_file=substr($realign_with_prank_log_file,0,length($realign_with_prank_log_file)-1).".log";
	$createTreeFromAlignment_log_file=substr($createTreeFromAlignment_log_file,0,length($createTreeFromAlignment_log_file)-1).".log";
	$species_string=substr($species_string,0,length($species_string)-1);
	$concat_alns_string=substr($concat_alns_string,0,length($concat_alns_string)-1);
	
	if (!(($continue) && ($status>4))){
		my_system("\"$perl\" \"$FindBestOrthologs\" \"$progress\" \"$individual_results_dir\" $minPercOrthologIdentity $minPercOrthologIdentityAllPairwise $species_string $concat_alns_string \"$FindBestOrthologs_log_file\" $threadNum");
	}
	if (!(($continue) && ($status>5)) && ($treeFile eq "")){	
		for my $species(@selected_species){
			my_system("\"$perl\" \"$createTreeFromAlignment\" \"$progress\" \"$concat_alns{$species}\" \"$treeFiles{$species}\" $createTreeAlignmentChunkSize $threadNum \"$species\" \"$createTreeFromAlignment_log_file\" ");
		}
	}
	if ($use_prank && !(($continue) && ($status>6))){
		for my $species(@selected_species){
			my_system("\"$perl\" \"$realign_with_prank\" \"$progress\" \"$individual_results_dir\" $species \"$treeFile\" \"$realign_with_prank_log_file\" $threadNum");							
		}
	}	
}

my $finishedString="\n\n\nFINISHED positive selection analysis. Final results were written to ";
if (($mode eq "all") || ($mode eq "positive_selection")){
	my_mkdir($logs_dir,$trees_dir,$individual_results_dir,$result_tables_dir);
	for my $species(@selected_species){
		my $tested_branch_string="";
		if ($tested_branch_name ne ""){$tested_branch_string="_tested_branch=".$tested_branch_name}
		my $target_species=join(",",@target_species);
		my $context_species=join(",",@context_species);
		my $logFile=$logs_dir."CodeML_positive_selection_species=".$species.$tested_branch_string.".log";
		my $chi2_not_calculated_file=$logs_dir.$species.$tested_branch_string."_chi2NotCalculated.txt";
		my ($resultFile,$resultFile_worst_iso,$resultFile_best_iso,$resultFile_short)=($result_tables_dir.$species.$tested_branch_string."_results.tsv",$result_tables_dir.$species.$tested_branch_string."_results_worst_iso_per_gene.tsv",$result_tables_dir.$species.$tested_branch_string."_results_best_iso_per_gene.tsv",$result_tables_dir.$species.$tested_branch_string."_results_short.tsv");
		if($treeFile eq ""){$treeFile=$treeFiles{$species}}
		my_system("\"$perl\" \"$CodeML_positive_selection\" \"$progress\" \"$species\" \"$target_species\" \"$context_species\" $min_outgroups \"$treeFile\" \"$trees_dir\" \"$individual_results_dir\" $min_BEBs $BEB_significance_threshold $BEB_excess_percentage $BEB_if_excess_min $min_foreground_KaKs $max_foreground_KaKs $flanking_region_size $min_codeml_input_aln_seq_num_hard $min_codeml_input_aln_seq_num_soft $max_gblocks_input_aln_gap_percentage_hard $max_gblocks_input_aln_gap_percentage_soft $max_gblocks_input_anchor_seq_gap_percentage_hard $max_gblocks_input_anchor_seq_gap_percentage_soft $min_codeml_input_aln_length $use_prank $genetic_code \"$logFile\" \"$chi2_not_calculated_file\" \"$resultFile\" \"$resultFile_worst_iso\" \"$resultFile_best_iso\" \"$resultFile_short\" \"$tested_branch_name\" $threadNum");	
		$finishedString.=$resultFile_short.",";
	}	
	$finishedString=substr($finishedString,0,length($finishedString)-1);
	$finishedString=~s/"//g;
	print($finishedString."\n\n");
}

sub my_system{
	if (system($_[0])!=0){
		print ("An error has occured during execution...\n");
		print ("Try to run the program again and use the parameter \"-continue\" to start again from the last valid point of execution...\n");	
		exit(1);
	}
}

sub show_pipeline_status{
	my ($pipeline_status,$mode,$output_path,$status_strings)=@_;
	print("\nCurrent status of execution at $output_path:\n\n");
	my $status=0;
	if (($mode eq "all") || ($mode eq "create_catalog") || ($mode eq "add_species") || ($mode eq "alignments") || ($mode eq "positive_selection") || ($mode eq "info")){
		print("Create_Catalog:\n\n");
		if (defined($pipeline_status->{"parse_homologene"})){
			print ("\t1. $status_strings->[0]:\n");
			for my $species(keys(%{$pipeline_status->{"parse_homologene"}})){
					print("\t\t$species: Genes: ".$pipeline_status->{"parse_homologene"}{$species}{"genes"}."\tTranscripts: ".$pipeline_status->{"parse_homologene"}{$species}{"transcripts"}."\n");
			}
			print("\n");
			$status=1;
		}
		if (defined($pipeline_status->{"add_a_public_non_homologene_species"})){
			print ("\t2. $status_strings->[1]:\n");
			for my $species(keys(%{$pipeline_status->{"add_a_public_non_homologene_species"}})){
					print("\t\t$species: Genes: ".$pipeline_status->{"add_a_public_non_homologene_species"}{$species}{"genes"}."\tTranscripts: ".$pipeline_status->{"add_a_public_non_homologene_species"}{$species}{"transcripts"}."\tMethod: ".$pipeline_status->{"add_a_public_non_homologene_species"}{$species}{"method"}."\n");
			}
			$status=2;
			print("\n");
		}		
	}
	if (($mode eq "all") || ($mode eq "alignments") || ($mode eq "positive_selection") || ($mode eq "info")){
		print("Alignments:\n\n");
		if (defined($pipeline_status->{"RefAlignments_new"})){
			print("\t3. $status_strings->[2]:\n");
			print("\t\tGenes: ".$pipeline_status->{"RefAlignments_new"}."\n");
			$status=3;
			print("\n");
		}
		if (defined($pipeline_status->{"FindBestOrthologs_Threads"})){
			print("\t4. $status_strings->[3]:\n");
			for my $species(keys(%{$pipeline_status->{"FindBestOrthologs_Threads"}})){
				print("\t\tAnchor species: $species\t"."Genes: ".$pipeline_status->{"FindBestOrthologs_Threads"}{$species}{"genes"}."\t"."Transcripts (of anchor species): ".$pipeline_status->{"FindBestOrthologs_Threads"}{$species}{"alignments"}."\n");
			}
			$status=4;
			print("\n");
		}
		if (defined($pipeline_status->{"createTreeFromAlignment"})){
			print("\t5. $status_strings->[4]:\n");
			for my $species(keys(%{$pipeline_status->{"createTreeFromAlignment"}})){
				print("\t\t".File::Basename::basename($pipeline_status->{"createTreeFromAlignment"}{$species})."\tAnchor species: $species\n");
			}		
			$status=5;
			print("\n");
		}
		if (defined($pipeline_status->{"realign_with_prank"})){
			print("\t6. $status_strings->[5]:\n");
			for my $species(keys(%{$pipeline_status->{"realign_with_prank"}})){
				print("\t\tAnchor species: $species\t"."Genes: ".$pipeline_status->{"realign_with_prank"}{$species}{"genes"}."\t"."Transcripts (of anchor species): ".$pipeline_status->{"realign_with_prank"}{$species}{"alignments"}."\n");
			}
			$status=6;
			print("\n");			
		}
	}
	if (($mode eq "all") || ($mode eq "positive_selection") || ($mode eq "info")){
		print("Positive_selection:\n\n");
		if (defined($pipeline_status->{"CodeML_positive_selection"})){
			print("\t7. $status_strings->[6]:\n");
			for my $species(keys(%{$pipeline_status->{"CodeML_positive_selection"}})){
				for my $suffix(keys(%{$pipeline_status->{"CodeML_positive_selection"}{$species}})){
					print("\t\tAnchor species: $species\t"."Suffix/RunID: ".$suffix."\t"."Tree: ".File::Basename::basename($pipeline_status->{"CodeML_positive_selection"}{$species}{$suffix}{"tree"})."\t"."Target species: ".$pipeline_status->{"CodeML_positive_selection"}{$species}{$suffix}{"target_species"}."\n");
				}
			}
			$status=7;
			print("\n");			
		}		
	}
	print("\n\n\n");
	return $status;
}

sub checkTree{
	if ((!defined($treeFile)) || ($treeFile eq "")){
 		print("You have to specifiy a file with a tree in newick format (parameter: t|tree_file)...\n");
 		exit(1);
	}	
	if (!((-e $treeFile) && (-f $treeFile) && (-r $treeFile))){
 		print("Could not open tree \"$treeFile\"...\n");		
 		exit(1);		
	}
	my $tree; 
	try{
		$tree=Bio::TreeIO::newick->new(-file => $treeFile)->next_tree();
	}catch{
		print("$treeFile is not a tree in newick format...\n");
		exit(1);
	};
	return $tree;
}

sub contain{
	my ($e,@list)=@_;
	for my $x(@list){if($e eq $x){return 1}}
	return 0;
}

sub my_mkdir{
	for my $path(@_){
		if (!((-e $path) && (-d $path))){		
			if ((-e $path && !unlink($path)) || (!mkdir($path))){
				print("Could not create directory $path...\n");
				exit(1);
			}
		}
	}
}

sub my_abs_path{
	my $result=Cwd::abs_path($_[0]);
	if (($result eq "") || (!defined($result))){return $_[0]}
	else{return $result}
}

sub myprint{
	if (index(lc($_[1]),"b",0)!=-1){print(STDERR "\033[1m")}
	my $pos=0;
	my $oldspos=0;
	my $spos=0;
	while ($pos<length($_[0])){
		my $b=0;
		for ($spos=index($_[0]," ",$pos);($spos<$pos+80) && ($spos!=-1);$spos=index($_[0]," ",$spos+1)){$oldspos=$spos;$b=1}
		if((!$b) || (($b) && ($spos==-1) && ($pos+80>=length($_[0])))){$oldspos=$pos+80}
		print(substr($_[0],$pos,$oldspos-$pos)."\n");
		$pos=$oldspos+1;
	}
	if (index(lc($_[1]),"b",0)!=-1){print(STDERR "\033[0m")}
}
