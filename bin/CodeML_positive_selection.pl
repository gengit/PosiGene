BEGIN{
	while (-l $0){$0=readlink($0)}
	my @path=split(/\/|\\/,$0);
	my $path=join("/",@path[0..(@path-2)])."/../modules";
	push (@INC,$path);
}

use strict;
use threads;
use threads::shared;
use Thread::Queue;
use Try::Tiny;
use Bio::AlignIO::fasta;
use Bio::SimpleAlign;
use Bio::Align::Utilities;
use Bio::SeqIO;
use Bio::Align::AlignI;
use Bio::Seq;
use Bio::LocatableSeq;
use Bio::Tree::Node;
use Bio::Tree::Tree;
use Bio::TreeIO;
#use Bio::Tools::Phylo::PAML::ModelResult;
#use Bio::Tools::Phylo::PAML;
use File::Copy;
use File::Path;
use Cwd;
use Bio::AlignIO::phylip;
use File::Basename;
use POSIX;
use Storable;
use Bio::Root::IO;
use Bio::AlignIO::clustalw;

#my $refPath="/misc/vulpix/data/asahm/Reference/";
#my $refPath="/home/lakatos/asahm/workspace2/Test/";
#my $refPath="/misc/vulpix/data/asahm/positive_selection_kim_et_al_nature_test/";
#my $refPath="/misc/vulpix/data/asahm/thyroid_positive_selection/";
#my $refPath="/misc/enton/data/asahm/Reference/";
#my $refPath="/misc/enton/data/asahm/Reference3/";
my $bin_dir=File::Basename::dirname(Cwd::abs_path($0))."/";
my $perl="perl";
my $GBlocks=$bin_dir."Gblocks";
my $codemlPath=$bin_dir."codeml";
my $chi2Path=$bin_dir."chi2";
#my $RScriptPath="Rscript";
my $drawAlignment=$bin_dir."drawAlignment.pl";
#my $q_value_calc_script_path=$bin_dir."CodeML_positive_selection_Q_Value_calc.R";
my $GBlocks_params=" -t=c -b4=30";
my $image_output_format="png";
my ($progress,$position_species,$target_species_string,$context_species_string,$min_outgroups,$treeFile,$trees_dir,$individual_results_dir,$min_BEBs,$BEB_significance_threshold,$BEB_excess_percentage,$BEB_if_excess_min,$min_foreground_KaKs,$max_foreground_KaKs,$flanking_region_size, $min_seq_num_hard, $min_seq_num_soft, $max_gap_percentage_aln_hard,$max_gap_percentage_aln_soft,$max_gap_percentage_position_seq_hard,$max_gap_percentage_position_seq_soft,$min_filtered_aln_length, $use_prank_aln, $genetic_code, $logFile, $chi2not_calculated ,$results, $results_worst_iso, $results_best_iso, $results_short, $branchinfo, $threadNum)=@ARGV;
my %codeml_params_M2_H0=('model' => 2, "NSsites" => 2, "fix_omega" => 1, "omega" => 1, "Small_Diff"    => 0.45e-6, "runmode" => 0, "verbose" => 1, "noisy" => 9, "seqtype" => 1, "CodonFreq" => 2 , "ndata" => 1,"clock" => 0, "icode" => $genetic_code-1, "Mgene" => 0, "fix_kappa" => 0,"kappa" => 2, "getSE" => 0, "RateAncestor" => 0, "cleandata" => 1, "fix_blength" => 1, "aaDist" => 0);
my %codeml_params_M2_HA=('model' => 2, "NSsites" => 2, "fix_omega" => 0, "omega" => 1, "Small_Diff"    => 0.45e-6, "runmode" => 0, "verbose" => 1, "noisy" => 9, "seqtype" => 1, "CodonFreq" => 2 , "ndata" => 1,"clock" => 0, "icode" => $genetic_code-1, "Mgene" => 0, "fix_kappa" => 0,"kappa" => 2, "getSE" => 0, "RateAncestor" => 0, "cleandata" => 1, "fix_blength" => 1, "aaDist" => 0);
open (STDERR, ">/dev/null");#disable warnings, should be commented out when debugging 
no warnings;#disable warnings, should be commented out when debug

#my ($position_species,$treeFile,$refPath, $max_gap_percentage, $use_prank_aln, $logFile, $chi2not_calculated ,$results, $branchinfo, $threadNum)=("Pantholops_hodgsonii","/home/lakatos/asahm/Desktop/Test_positive_selection2/my_tree2.newick","/home/lakatos/asahm/Desktop/Test_positive_selection2/",0,1,"Pantholops_hodgsonii_selection.log","Pantholops_hodgsonii_chi2NotCalculated.hash","Pantholops_hodgsonii_results.tsv","",16);
#my ($position_species,$treeFile,$refPath, $max_gap_percentage, $use_prank_aln, $logFile, $chi2not_calculated ,$results, $branchinfo, $threadNum)=("Heterocephalus_glaber","/home/lakatos/asahm/Desktop/Reference_Test4/tree.newick","/home/lakatos/asahm/Desktop/Reference_Test4/",0,1,"Hglaber_positive_selection.log","Hglaber_chi2NotCalculated.hash","Hglaber_results.hash","",25);
#my ($position_species,$treeString,$refPath, $max_gap_percentage, $use_prank_aln, $logFile, $chi2not_calculated ,$results, $branchinfo, $threadNum)=("Fukomys anselli","((\"Homo sapiens\",\"Canis lupus\"),((\"Rattus norvegicus\",\"Mus musculus\"),(\"Thryonomys swinderianus\",(\"Heterocephalus glaber\",(\"Heliophobius argenteocinereus\",\"Fukomys anselli #1\")))));","/home/lakatos/asahm/workspace2/Test/ReferenceTest4/",0,0,"Fanselli_positive_selection.log","Fanselli_chi2NotCalculated.hash","Fanselli_results.hash","",64);
#my ($position_species,$treeFile,$refPath, $max_gap_percentage, $use_prank_aln, $logFile, $chi2not_calculated ,$results, $branchinfo, $threadNum)=("Pantholops_hodgsonii","/home/lakatos/asahm/enton/Tibetan_Antelope+9_species/my_tree.newick","/home/lakatos/asahm/enton/Tibetan_Antelope+9_species/",0,1,"Pantholops_hodgsonii_tested_branch=my_tree_selection.log","Pantholops_hodgsonii_tested_branch=my_tree_chi2NotCalculated.hash","Pantholops_hodgsonii_tested_branch=my_tree_results.tsv","tested_branch=my_tree",64);
#my ($position_species,$treeFile,$refPath, $max_gap_percentage, $use_prank_aln, $logFile, $chi2not_calculated ,$results, $branchinfo, $threadNum)=("Pantholops_hodgsonii","/home/lakatos/asahm/enton/Tibetan_Antelope+9_species_minIdent=80_small/my_tree.newick","/home/lakatos/asahm/enton/Tibetan_Antelope+9_species_minIdent=80_small/",0,1,"Pantholops_hodgsonii_tested_branch=my_tree_selection.log","Pantholops_hodgsonii_tested_branch=my_tree_chi2NotCalculated.hash","Pantholops_hodgsonii_tested_branch=my_tree_results.tsv","tested_branch=my_tree",32);
#my ($position_species,$treeFile,$refPath, $max_gap_percentage, $use_prank_aln, $logFile, $chi2not_calculated ,$results, $branchinfo, $threadNum)=("Heterocephalus_glaber","/home/lakatos/asahm/enton/Public_Hglaber+3Species/my_tree.newick","/home/lakatos/asahm/enton/Public_Hglaber+3Species/",0,1,"Heterocephalus_glaber_tested_branch=my_tree_positive_selection.log","Heterocephalus_glaber_tested_branch=my_tree_chi2NotCalculated.txt","Heterocephalus_glaber_tested_branch=my_tree_results.tsv","tested_branch=my_tree",48);
#my ($position_species,$treeFile,$refPath, $max_gap_percentage, $use_prank_aln, $logFile, $chi2not_calculated ,$results, $branchinfo, $threadNum)=("Heterocephalus_glaber","/home/lakatos/asahm/enton/Public_Hglaber+3Species/my_tree2.newick","/home/lakatos/asahm/enton/Public_Hglaber+3Species/",0,1,"Heterocephalus_glaber_tested_branch=my_tree2_positive_selection.log","Heterocephalus_glaber_tested_branch=my_tree2_chi2NotCalculated.txt","Heterocephalus_glaber_tested_branch=my_tree2_results.tsv","tested_branch=my_tree2",48);
#my ($position_species,$treeFile,$refPath, $max_gap_percentage, $use_prank_aln, $logFile, $chi2not_calculated ,$results, $branchinfo, $threadNum)=("Heterocephalus_glaber","/home/lakatos/asahm/Desktop/Test_PublicHglaber+3_species3/tree_selected_species_Heterocephalus_glaber.newick","/home/lakatos/asahm/Desktop/Test_PublicHglaber+3_species3/",0,1,"Heterocephalus_glaber_tested_branch=my_tree2_positive_selection.log","Heterocephalus_glaber_tested_branch=my_tree2_chi2NotCalculated.txt","Heterocephalus_glaber_tested_branch=my_tree2_results.tsv","",10);
#my ($position_species,$treeFile,$refPath, $max_gap_percentage, $use_prank_aln, $logFile, $chi2not_calculated ,$results, $branchinfo, $threadNum)=("Heterocephalus_glaber","/home/lakatos/asahm/Desktop/Kim_Test/tree_selected_species_Heterocephalus_glaber.newick","/home/lakatos/asahm/Desktop/Kim_Test/",0,1,"Heterocephalus_glaber_positive_selection.log","Heterocephalus_glaber_chi2NotCalculated.txt","Heterocephalus_glaber_results.tsv","",10);
#my ($position_species,$treeFile,$refPath, $max_gap_percentage, $use_prank_aln, $logFile, $chi2not_calculated ,$results, $branchinfo, $threadNum)=("Harpegnathos_saltator","/home/lakatos/asahm/Desktop/Ant_test/test.newick","/home/lakatos/asahm/Desktop/Ant_test/",0,1,"test.log","test_chi2NotCalculated.txt","test_results.tsv","",10);


if ($branchinfo ne ""){$branchinfo="_".$branchinfo;}
$position_species=~s/ /_/g;
my @target_species=split(",",$target_species_string);
for my $species(@target_species){$species=~s/ /_/g}
my @context_species=split(",",$context_species_string);
for my $species(@context_species){$species=~s/ /_/g}
my ($main_tree_path,$main_tree)=getMainTree($treeFile,@target_species);
@context_species=context_species($main_tree_path,\@context_species);
my %target_species=map{$_ => ""}@target_species;
my %tested_species=%{mark_tested_species($main_tree)};;
my $do_image_output=(eval "require Bio::Align::Graphics;");


my $errors:shared=0;
my $errorString:shared="";
my $alns_processed:shared=0;
my $max_BEBs:shared=0;


my %dfdif:shared;
my %DFdifnot1:shared;
my %chi2NotCalculated:shared;
my @drawAlignmentParams:shared;

my @threads;
my $queue=Thread::Queue->new();
for (my $i=0; $i<$threadNum; $i++){
	push (@threads,threads->create(\&myThread));	
	print ("Step 7/7, created ".($i+1)."/".$threadNum." threads\n");
}
#print ("Step 7/7, finished starting threads...\n");


print("Step 7/7, reading directory content...\n");
opendir(REFDIR, $individual_results_dir);
my @refdir2 = readdir(REFDIR);
closedir(REFDIR);
my @refdir;
for my $e(@refdir2){
	if(-d $individual_results_dir.$e && !(($e eq ".") || ($e eq "..")) ){
		push(@refdir,$e);
	}
}

my $genes=0;
for my $geneName(@refdir)  {
	my $geneDirPath=$individual_results_dir.$geneName."/";
	if (-d $geneDirPath && ($geneName ne ".") &&($geneName ne "..")){
		print ("Step 7/7, processing gene ".++$genes."/".int(@refdir).": ".$geneName."...\n");	
		my %species;
		my %cds;			
		my $position_species_path=$geneDirPath.$position_species."/";
		if (-e  $position_species_path && -d $position_species_path){
			opendir(GENEDIR, $geneDirPath);
			my @geneDir=readdir(GENEDIR);
			closedir(GENEDIR);
			for my $speciesName(@geneDir){
				my $dir=$geneDirPath.$speciesName."/";
				if (-d $dir && ($speciesName ne ".") &&($speciesName ne "..")){
					opendir(DIR, $dir);
					my @d = readdir(DIR);
					closedir(DIR);
					for my $f(@d){	
						if (-e $dir.$f && !(-d $dir.$f)){
							my @x=split(/[.]/,$f);
							if (($x[$#x] eq "fasta_spliced") || ($x[$#x] eq "fasta_cds")){
								$species{(File::Basename::fileparse($f, qr/\.[^.]*/))[0]}=$speciesName;
								try{
									my $stream = Bio::SeqIO->new(-file => $dir.$f,-format => 'fasta');
   							 		if ( my $seq = $stream->next_seq()) {	   
 										$cds{(File::Basename::fileparse($f, qr/\.[^.]*/))[0]}= $seq;
									}					 		
								}catch{$errors++; $errorString.="SeqIOError:".$dir.$f.":".$_."\n"};
							}
						}					
					}
				}		
			}
			opendir(DIR, $position_species_path);
			my @d=readdir(DIR);
			closedir(DIR);
			for my $f(@d){
				if (-e $position_species_path.$f && !(-d $position_species_path.$f)){
					my @x=split(/[.]/,$f);
#					if ((($x[$#x-1] eq "_with_best_of_other_species") || ($x[$#x-1] eq "with_best_of_other_species")) && ($x[$#x-2] eq "aln") && ($x[$#x] eq "aln")){
					if ($x[$#x] eq "aln"){
						while($queue->pending()){sleep(5);print("Step 7/7, all $threadNum threads are busy...\n")}
						#myThread($position_species_path,$f,\%cds,\%species,$geneDirPath,@x);						
						$queue->enqueue([$position_species_path,$f,\%cds,\%species,$geneDirPath,@x]);	
					}
				}					
			}	
		}
	}
}
$queue->end();
my $x=0;
my %results;
for my $thread(@threads){
my %results_part;
%results_part=%{$thread->join()};

for my $key(keys(%results_part)){$results{$key}=$results_part{$key}}	
print ("Step 7/7, ".++$x."/".$threadNum." threads returned\n");
}

open (LOGFILE, ">".$logFile); 
print(LOGFILE "Errors: $errors\n");
print(LOGFILE "Genes: $genes\n");
print(LOGFILE "Alignments processed: $alns_processed\n");
print(LOGFILE "How often was Difference DoF1-DoF0 ne 1: ".scalar(keys(%DFdifnot1))."\n");
print(LOGFILE "How often p-value could not be calculated with chi2: ".scalar(keys(%chi2NotCalculated))."\n\n\n");
print(LOGFILE $errorString."\n");
close (LOGFILE);
output_hash_as_text(\%chi2NotCalculated,$chi2not_calculated);



output_results_as_text_sorted(multiple_test_correction(\%results),$results);
output_results_as_text_sorted(multiple_test_correction(filter_for_iso_with_highest_p(\%results)),$results_worst_iso);
output_results_as_text_sorted(multiple_test_correction(filter_for_iso_with_lowest_p(\%results)),$results_best_iso);
short_output_results_as_text_sorted(multiple_test_correction(\%results),$results_short);




my $pipeline_status;
try{$pipeline_status=Storable::retrieve($progress);}catch{};
if($branchinfo eq ""){$branchinfo="(Default/None)"}
#$pipeline_status->{"CodeML_positive_selection"}={};
#$pipeline_status->{"CodeML_positive_selection"}{$position_species}={};
$pipeline_status->{"CodeML_positive_selection"}{$position_species}{$branchinfo}={"tree" => $main_tree_path, "target_species" => join(", ",@target_species)};
Storable::store($pipeline_status,$progress);
print ("Step 7/7, FINISHED\n\n");
close (STDERR);
exit(0);

sub myThread{	
	my %results=();
	while (defined(my $args=$queue->dequeue())){
		my ($position_species_path,$f,$cds,$species_hash,$geneDirPath,@x)=@{$args}; 
		##my ($position_species_path,$f,$cds,$species_hash,$geneDirPath,@x)=@_; 
		my $result_name=($f=~/.fastp.clustalw"/)?(split(".fastp.clustalw",$f))[0]:(split(".aln",$f))[0];		
		try{			
			##print("Processing alignment ".$alns_processed++.": $f...\n");
			my $codeMLDir=$position_species_path.$result_name."_codeml/";
			mkdir($codeMLDir);
			my $aln=Bio::AlignIO::fasta->new (-file => $position_species_path.$f)->next_aln();						
			if (scalar($aln->each_seq())>1){						
				my $aln2=Bio::Align::Utilities::aa_to_dna_aln($aln,$cds);	
				my $tree=$main_tree->clone();
				
				my @nodes=$tree->get_nodes();
				for my $seq($aln2->each_seq){
					my $b=0;
	    			map {my $id=$_->id; $id=~s/ //g; $id=~s/[#].(0-9)*//g;if ($species_hash->{$seq->id} eq $id){$b=1}} @nodes;
	    			if (!$b){$aln2->remove_seq($seq)}
				}
										
#				Bio::AlignIO::fasta->new (-file => ">".$codeMLDir.$f."_codon.fasta" )->write_aln($aln2);													
				Bio::AlignIO::fasta->new (-file => ">".$codeMLDir."codon_aln.fasta" )->write_aln($aln2);													
				
				my $aln_path;
				select("");
				if ($use_prank_aln){$aln_path=(-e $codeMLDir."prank/".$f."_codon.fasta.prank.best.fas")?"prank/".$f."_codon.fasta.prank.best.fas":"prank/prank.best.fas";}
				else {$aln_path=(-e $codeMLDir.$f."_codon.fasta")?$f."_codon.fasta":"codon_aln.fasta";}
				my $aln_prep=Bio::AlignIO::fasta->new (-file => $codeMLDir.$aln_path)->next_aln();
								
				my $position_seq_prep="";
				for my $seq($aln_prep->each_seq){if($species_hash->{$seq->id} eq $position_species){$position_seq_prep=$seq->seq};}
				$position_seq_prep=~s/-//g;
				prepare_aln($aln_prep);									
				Bio::AlignIO::fasta->new (-file => ">".$codeMLDir.$aln_path.".prepared")->write_aln($aln_prep);
				system("cd \"".$codeMLDir."\";".$GBlocks." \"".$aln_path.".prepared"."\"".$GBlocks_params." -b2=".int($aln_prep->each_seq). " >/dev/null");
				select(STDOUT);
				my $aln3=Bio::AlignIO::fasta->new (-file => $codeMLDir.$aln_path.".prepared-gb" )->next_aln();
				my @usedSpecies;		
				for my $seq($aln3->each_seq()){
	    			$aln3->remove_seq($seq);
	    			my $species=$species_hash->{$seq->id};
	    			$seq->{verbose}=0;
	    			$seq->id($species);	 
	    			push(@usedSpecies,"\"".$species."\"");
	    			$aln3->add_seq($seq);	    			  							
				}
				my @help;
				$results{$position_species_path.$result_name}=\@help;
				push(@{$results{$position_species_path.$result_name}},scalar(@usedSpecies),join(",",sort(@usedSpecies)));
				my $aln3_path=$codeMLDir.$aln_path.".prepared-gb-renamed";				
				Bio::AlignIO->new (-file => ">".$aln3_path ,-format => 'phylip',-interleaved => 0,'-idlength' => (25>($aln3->maxdisplayname_length()))?25:$aln3->maxdisplayname_length() +1)->write_aln($aln3);	
				
#				print("Aln gap percentage: ".($aln3->length/$aln_prep->length)."\t".(1-$max_gap_percentage_aln_hard/100)."\n");
#				print("Anchor gap percentage: ".($aln3->length/length($position_seq_prep))."\t".(1-$max_gap_percentage_position_seq_hard/100)."\n");
#				print("Flush: ".$aln3->is_flush."\n");
#				print("Seqs:".scalar($aln3->each_seq)."\t".$min_seq_num_hard."\n");
#				print("Length:\t".$aln3->length()."\t".$min_filtered_aln_length."\n");
				
				
				if ((scalar($aln3->each_seq)>=$min_seq_num_hard) && ($aln3->length()>=$min_filtered_aln_length) && ($aln3->is_flush) && (($aln3->length/$aln_prep->length)>=(1-$max_gap_percentage_aln_hard/100)) && ($position_seq_prep ne "") && (($aln3->length/length($position_seq_prep)>=(1-$max_gap_percentage_position_seq_hard/100)))){
					my $all_target_species_present=1;
					my $all_context_species_present=1;
					my $outgroups=0;
					my %species_not_present;
					for my $node($tree->get_nodes()){
						my $b=0;
						my $id=$node->id;
						$id=~s/ //g;
						$id=~s/#\d*$//;
						for my $seq ($aln3->each_seq()){
							##if (($seq->display_id eq $node->id) || (($seq->display_id." #1") eq $node->id) || (($seq->display_id."#1") eq $node->id)) {
							if ($seq->display_id eq $id) {
								$b=1;
							}
						}
						if (($node->is_Leaf()) && ($b) && (!exists($tested_species{$id}))){$outgroups++}
						if ($node->is_Leaf() && !$b){
							if (exists($target_species{$node->id})){$all_target_species_present=0;last;}
							$species_not_present{$node->id}="";
							#if (exists($context_species{$node->id})){$all_context_species_present=0;}																					
							$tree->remove_Node($node);
							my_contract_linear_paths($tree,1);
						}
					}
					make_tree_unrooted($tree);
					$all_context_species_present=check_context_species(\%species_not_present,\@context_species);					
					#if (!$all_context_species_present){open(XXX, ">test_x_context");print(XXX "$aln3_path\t$usedSpeciesString\n");close(XXX)}										
					if (is_tree_marked($tree) && $all_target_species_present && ((find_nodes($tree,\@target_species)<2) || ($tree->get_lca(find_nodes($tree,\@target_species))) ne $tree->get_root_node)){
						my $treeFile=$codeMLDir.$result_name."_tree".$branchinfo.".newick";
						Bio::TreeIO->new('-format' => 'newick','-file'   => ">".$treeFile)->write_tree($tree);	
						
						####$tree=new Bio::TreeIO('-format' => 'newick','-file'   => $codeMLDir.$result_name."_tree".$branchinfo.".newick")->next_tree();
						#my $codeml=Bio::Tools::Run::Phylo::PAML::Codeml->new(-alignment => $aln3,-tree => $tree, -params => \%codeml_params_M2_H0);								
						##print("codeml M2:H0 ".$position_species_path.$f."\n");
						##my $h=$aln3->clone();
						##$codeml->prepare();
						##File::Copy::move($codeml->{"_tmpdir"}."/codeml.ctl","/home/lakatos/asahm/Desktop/test_ctl/".$result_name."ctl");
						##$aln3=$h;
						##	
						###print("TempDir: ".$codeml->{"_tmpdir"}."\n");								
						##system("cd \"".$codeml->{"_tmpdir"}."\";".$codemlPath." ".$codeml->{"_tmpdir"}."/codeml.ctl >\"".$codeMLDir.$result_name."_M2_H0".$branchinfo.".mlc_errorstring\"");
						##File::Copy::move($codeml->{"_tmpdir"}."/mlc",$codeMLDir.$result_name."_M2_H0".$branchinfo.".mlc");
						##File::Copy::move($codeml->{"_tmpdir"}."/rst",$codeMLDir.$result_name."_M2_H0".$branchinfo.".rst");				
						##thread_safe_rmtree($codeml->{"_tmpdir"});				
						##my $codeml=Bio::Tools::Run::Phylo::PAML::Codeml->new(-alignment => $aln3,-tree => $tree, -params => \%codeml_params_M2_HA);
						###print("codeml M2:HA ".$position_species_path.$f."\n");
						##my $h=$aln3->clone();
						##$codeml->prepare();
						##$aln3=$h;
						####print("TempDir: ".$codeml->{"_tmpdir"}."\n");
						##system("cd \"".$codeml->{"_tmpdir"}."\";".$codemlPath." ".$codeml->{"_tmpdir"}."/codeml.ctl >\"".$codeMLDir.$result_name."_M2_HA".$branchinfo.".mlc_errorstring\"");
						##File::Copy::move($codeml->{"_tmpdir"}."/mlc",$codeMLDir.$result_name."_M2_HA".$branchinfo.".mlc");
						##File::Copy::move($codeml->{"_tmpdir"}."/rst",$codeMLDir.$result_name."_M2_HA".$branchinfo.".rst");
						##thread_safe_rmtree($codeml->{"_tmpdir"});
												
#my $h=$branchinfo;
#$branchinfo="";						

						my $H0_prefix=$codeMLDir."M2_H0".$branchinfo;
						my $HA_prefix=$codeMLDir."M2_HA".$branchinfo;
						codeml($aln3_path,$treeFile,$H0_prefix,\%codeml_params_M2_H0);
						codeml($aln3_path,$treeFile,$HA_prefix,\%codeml_params_M2_HA);						

						my $chi2=chi2($H0_prefix.".mlc",$HA_prefix.".mlc",$codeMLDir.$result_name,$codeMLDir.$result_name.$branchinfo.".chi2");												
						push(@{$results{$position_species_path.$result_name}},$chi2,$result_name);
						my @flanks=readFlanksFromGblocksHtm($codeMLDir.$aln_path.".prepared-gb.htm");
						##my $BEBs=getSignificantBEB($codeMLDir.$result_name."_M2_HA.rst",\@flanks,$species_hash,$aln, $geneDirPath."fastp.clustalw.aln",$aln2,$codeMLDir.$aln_path);
						my $BEBs=getBEBs($HA_prefix.".rst",\@flanks,$species_hash,$aln, $geneDirPath."fastp.clustalw.aln",$aln2,$aln_prep);																										
						my $corrected_chi2=$chi2;
						my ($BEBs,$BEBs_not_significant)=BEBs_significant($BEBs,$BEB_significance_threshold);												
						my ($BEBs,$excess_BEBs)=filterForBEBExcess($BEBs,$BEB_excess_percentage,$BEB_if_excess_min,$aln3);												
						my $correction_code=0;
						my ($BEBs,$flank_BEBs,$corrected_chi2)=filterFlankBEBs($BEBs,\@flanks,$flanking_region_size,$aln_prep->length,$chi2);
						if (@{$flank_BEBs}>0){$correction_code=1}

						if (@{$BEBs}>$max_BEBs){$max_BEBs=@{$BEBs};}
						push(@{$results{$position_species_path.$result_name}},$BEBs);													
						##print("Chi2 ".$position_species_path.$f.": ".$chi2."\n");	
						my $extraStats_H0=readMlcStats($H0_prefix.".mlc");
						my $extraStats_HA=readMlcStats($HA_prefix.".mlc");
						push(@{$results{$position_species_path.$result_name}},$extraStats_HA,$extraStats_H0);							
#$branchinfo=$h;
						my ($nucl_aln_path,$prot_aln_path,$nucl_jalview_path,$prot_jalview_path,$prot_aln_image_path,$nucl_aln_image_path,$prot_aln_image_path_interleaved,$nucl_aln_image_path_interleaved,$prot_aln_image_path_anno,$nucl_aln_image_path_anno,$prot_aln_image_path_interleaved_anno,$nucl_aln_image_path_interleaved_anno,$drawParameterFile,$draw_log)=($codeMLDir.$aln_path.$branchinfo.".renamed",$codeMLDir.$aln_path.$branchinfo.".translation",$codeMLDir.$aln_path.$branchinfo.".view",$codeMLDir.$aln_path.$branchinfo.".translation.view",$codeMLDir.$aln_path.$branchinfo.".translation.".$image_output_format,$codeMLDir.$aln_path.$branchinfo.".".$image_output_format,$codeMLDir.$aln_path.$branchinfo.".translation.interleaved.".$image_output_format,$codeMLDir.$aln_path.$branchinfo.".interleaved.".$image_output_format,$codeMLDir.$aln_path.$branchinfo.".translation.annotated.".$image_output_format,$codeMLDir.$aln_path.$branchinfo.".annotated.".$image_output_format,$codeMLDir.$aln_path.$branchinfo.".translation.interleaved.annotated.".$image_output_format,$codeMLDir.$aln_path.$branchinfo.".interleaved.annotated.".$image_output_format,$codeMLDir.$aln_path.$branchinfo.".draw_parameter",$codeMLDir.$aln_path.$branchinfo.".draw_log");												
						if ($do_image_output==0){for my $a ($prot_aln_image_path,$nucl_aln_image_path,$prot_aln_image_path_interleaved,$nucl_aln_image_path_interleaved,$prot_aln_image_path_anno,$nucl_aln_image_path_anno,$prot_aln_image_path_interleaved_anno,$nucl_aln_image_path_interleaved_anno){$a="LibGD or perl module GD not installed"}}
						drawAlignment($do_image_output,$species_hash,$tree,$treeFile,$codeMLDir.$aln_path,$position_species_path.$result_name.".gbk",$BEBs,$BEBs_not_significant,$excess_BEBs,$flank_BEBs ,\@flanks,$species_hash,$nucl_aln_path,$prot_aln_path,$nucl_jalview_path,$prot_jalview_path,$prot_aln_image_path,$nucl_aln_image_path,$prot_aln_image_path_interleaved,$nucl_aln_image_path_interleaved,$prot_aln_image_path_anno,$nucl_aln_image_path_anno,$prot_aln_image_path_interleaved_anno,$nucl_aln_image_path_interleaved_anno,$drawParameterFile,$draw_log);										
						push(@{$results{$position_species_path.$result_name}},$prot_aln_image_path_interleaved_anno,$nucl_aln_image_path_interleaved_anno,$prot_aln_image_path_interleaved,$nucl_aln_image_path_interleaved,$prot_aln_image_path_anno,$nucl_aln_image_path_anno,$prot_aln_image_path,$nucl_aln_image_path,$nucl_jalview_path,$prot_jalview_path);	
						
#						open(TEST,">>test.txt");
#						print(TEST "$f\n");
#						print(TEST "Omega Foreground:". $extraStats_HA->{"omega_foreground"}."\t".$min_foreground_KaKs."\t"."$max_foreground_KaKs"."\n");
#						print(TEST "Omega background:".$extraStats_H0->{"omega_background"}."\n");
#						print(TEST "Seq num:".int($aln3->each_seq)."\t".$min_seq_num_soft."\n");
#						print(TEST "BEBs:".int(@{$BEBs})."\t".(int(@{$BEBs})/($aln3->length/3))."\t".$BEB_excess_percentage."\n");
#						print(TEST "Aln gap percentage: ".($aln3->length/$aln_prep->length)."\t".(1-$max_gap_percentage_aln_soft/100)."\n");
#						print(TEST "Anchor gap percentage: ".($aln3->length/length($position_seq_prep))."\t".(1-$max_gap_percentage_position_seq_soft/100)."\n");
#						print(TEST "Context species:".$all_context_species_present."\n");
#						print(TEST "1.".(($extraStats_HA->{"omega_foreground"}<$min_foreground_KaKs)?"Yes\n":"No\n"));
#						print(TEST "2.".(($extraStats_HA->{"omega_foreground"}>=$max_foreground_KaKs)?"Yes\n":"No\n"));
#						print(TEST "3.".(($extraStats_HA->{"omega_background"}>1)?"Yes\n":"No\n"));
#						print(TEST "4.".(($extraStats_HA->{"omega_background"}>($extraStats_HA->{"omega_foreground"}))?"Yes\n":"No\n"));
#						print(TEST "5.".(($extraStats_H0->{"omega_background"}>1)?"Yes\n":"No\n"));
#						print(TEST "6.".(($extraStats_H0->{"omega_background"}>($extraStats_H0->{"omega_foreground"}))?"Yes\n":"No\n"));
#						print(TEST "7.".((int($aln3->each_seq)<$min_seq_num_soft)?"Yes\n":"No\n"));
#						print(TEST "8.".((int(@{$BEBs})<1)?"Yes\n":"No\n"));
#						print(TEST "9.".((int(@{$BEBs})/($aln3->length/3)>=$BEB_excess_percentage)?"Yes\n":"No\n"));
#						print(TEST "10.".(($aln3->length/$aln_prep->length)<(1-$max_gap_percentage_aln_soft/100)?"Yes\n":"No\n"));
#						print(TEST "11.".(($aln3->length/length($position_seq_prep))<(1-$max_gap_percentage_position_seq_soft/100)?"Yes\n":"No\n"));
#						print(TEST "12.".((!$all_context_species_present)?"Yes\n":"No\n")."\n");
#						print(TEST "\n\n\n");
#						close(TEST);
			
						my @filters=(($extraStats_HA->{"omega_foreground"}<$min_foreground_KaKs)  , ($extraStats_HA->{"omega_foreground"}>=$max_foreground_KaKs) , ($extraStats_HA->{"omega_background"}>1) , ($extraStats_HA->{"omega_background"}>($extraStats_HA->{"omega_foreground"})) , ($extraStats_H0->{"omega_background"}>1) , ($extraStats_H0->{"omega_background"}>($extraStats_H0->{"omega_foreground"})) , (int($aln3->each_seq)<$min_seq_num_soft) , (int(@{$BEBs})<1) , (int(@{$BEBs})/($aln3->length/3)>=$BEB_excess_percentage) , (($aln3->length/$aln_prep->length)<(1-$max_gap_percentage_aln_soft/100)) , (($aln3->length/length($position_seq_prep))<(1-$max_gap_percentage_position_seq_soft/100)) , (!$all_context_species_present),($min_outgroups>$outgroups));
						for (my $i=1; $i<=@filters; $i++){if($filters[$i-1]){$correction_code+=2**$i}}
						##if (($extraStats_HA->{"omega_foreground"}<$min_foreground_KaKs)  || ($extraStats_HA->{"omega_foreground"}>=$max_foreground_KaKs) || ($extraStats_HA->{"omega_background"}>1) || ($extraStats_HA->{"omega_background"}>($extraStats_HA->{"omega_foreground"})) || ($extraStats_H0->{"omega_background"}>1) || ($extraStats_H0->{"omega_background"}>($extraStats_H0->{"omega_foreground"})) || (int($aln3->each_seq)<$min_seq_num_soft) || (int(@{$BEBs})<1) || (int(@{$BEBs})/($aln3->length/3)>=$BEB_excess_percentage) || (($aln3->length/$aln_prep->length)<(1-$max_gap_percentage_aln_soft/100)) || (($aln3->length/length($position_seq_prep))<(1-$max_gap_percentage_position_seq_soft/100)) || (!$all_context_species_present)){$corrected_chi2=1}
						if($correction_code>1){$corrected_chi2="NA"}
						push(@{$results{$position_species_path.$result_name}},$correction_code,$corrected_chi2);
					} else {$chi2NotCalculated{$position_species_path.$result_name}=1;$results{$position_species_path.$result_name}=undef}
				} else {$chi2NotCalculated{$position_species_path.$result_name}=1;$results{$position_species_path.$result_name}=undef}						
			} else {$chi2NotCalculated{$position_species_path.$result_name}=1;}
		}catch{$errors++;$errorString.=$position_species_path.$f.": ".$_."\n";print("Error ".$position_species_path.$f.": ".$_."\n");$results{$position_species_path.$result_name}=undef};	
	}
	return \%results;
}


sub codeml{
	my($alnFile,$treeFile,$prefix,$params)=@_;
	my $tempdir=new Bio::Root::IO->tempdir(CLEANUP=>0)."/";
	open(my $CTL, ">".$tempdir."ctl");
	print($CTL "seqfile = aln\n");
	File::Copy::copy($alnFile,$tempdir."aln");
	print($CTL "treefile = tree\n");
	File::Copy::copy($treeFile,$tempdir."tree");
	print($CTL "outfile = mlc\n");
	for my $key(keys(%$params)){print($CTL "$key = ".$params->{$key}."\n")}
	close($CTL);	
	system("cd $tempdir; $codemlPath ctl > $prefix.mlc_errorstring");
	File::Copy::move("$tempdir"."mlc",$prefix.".mlc");
	File::Copy::move("$tempdir"."rst",$prefix.".rst");
	thread_safe_rmtree($tempdir);
}

sub BEBs_significant{
	my ($BEBs,$BEB_significance_threshold)=@_;
	my @new_BEBs;
	my @filtered_BEBs;	
	for my $BEB(@$BEBs){
		if($BEB->[1]>=$BEB_significance_threshold){push(@new_BEBs,$BEB);}
		else{push(@filtered_BEBs,$BEB)}
	}
	return(\@new_BEBs,\@filtered_BEBs);
}

sub filterFlankBEBs{
	my($BEBs,$gblocks_flanks,$my_flanking_region_size,$aln_length,$pvalue)=@_;
	my @new_BEBs;
	my @filtered_BEBs;
	my $product=1;
	for my $BEB(@$BEBs){
		my $b=1;
		for my $flank(@$gblocks_flanks){
			if((($flank->[0]<=$BEB->[9]) && ($flank->[0]+$my_flanking_region_size*3-1>=$BEB->[9]) && ($flank->[0]!=1)) || (($flank->[1]>=$BEB->[9]) && ($flank->[1]-$my_flanking_region_size*3+1<=$BEB->[9]) && ($flank->[1]!=$aln_length))){$b=0; last}
		}
		if($b){push(@new_BEBs,$BEB);}
		else{$BEB->[1]=0;push(@filtered_BEBs,$BEB)}
		$product*=(1-$BEB->[1]);
	}
	if(@new_BEBs==0){$pvalue=0}
	elsif(int(@new_BEBs)<int(@$BEBs)){$pvalue=$pvalue/$product;if($pvalue>1){$pvalue=1}}	
	return (\@new_BEBs,\@filtered_BEBs,$pvalue);
}

sub filterForBEBExcess{
	my ($BEBs,$BEB_excess_percentage,$BEB_if_excess_min,$aln)=@_;
	my @filtered_BEBs;
	if (int(@{$BEBs})/($aln->length/3)>=$BEB_excess_percentage){
		my @new_BEBs;		
		for my $BEB(@$BEBs){
			if ($BEB->[1]>=$BEB_if_excess_min){push(@new_BEBs,$BEB)}
			else{$BEB->[1]=0;push(@filtered_BEBs,$BEB)}
		}
		$BEBs=\@new_BEBs;
	}
	return ($BEBs,\@filtered_BEBs);
}

sub is_tree_marked{
	my ($tree)=@_;
	for my $node($tree->get_nodes()){
		my $s=$node->id;
		if ($s=~m/#1/){return 1}
	}
	return 0;
}

sub readMlcStats{
	my ($infile)=@_;
	open (my $IN, $infile);
	my %stats;
	my @proportion;
	my @foreground;
	my @background;
	while (my $line=<$IN>){
		if ($line=~m/^kappa \(ts\/tv\) =  /){
			my $kappa=(split("=",$line))[1];
			$kappa=~s/[ \n]//g;
			$stats{"kappa"}=$kappa;
		}
		elsif($line=~m/^proportion/){
			@proportion=(split(" ",$line))[1..4];
		}
		elsif($line=~m/^foreground w/){
			@foreground=(split(" ",$line))[2..5];
		}
		elsif($line=~m/^background w/){
			@background=(split(" ",$line))[2..5];		
		}
	}
	if ((int(@proportion)==4) && (int(@foreground)==4) && (int(@background)==4)){
		$stats{"omega_background"}=0;
		$stats{"omega_foreground"}=0;		
		for my $i(0,1,2,3){
			$stats{"omega_background"}+=$proportion[$i]*$background[$i];
			$stats{"omega_foreground"}+=$proportion[$i]*$foreground[$i];				
		}		
	}else{
		$stats{"omega_background"}="";
		$stats{"omega_foreground"}="";
	}
	
	close($IN);
	return \%stats;
}

sub drawAlignment{
	my ($do_image_output,$species_hash,$tree,$treePath,$aln_path,$position_seq_gbk_path,$BEBs,$BEBs_not_significant,$excess_BEBs,$flank_BEBs,$flanks,$species_hash,$nucl_aln_path,$prot_aln_path,$nucl_jalview_out_path,$prot_jalview_out_path,$aln_translation_out_path,$out_path,$aln_translation_out_path_interleaved,$out_path_interleaved,$aln_translation_out_path_anno,$out_path_anno,$aln_translation_out_path_interleaved_anno,$out_path_interleaved_anno,$parameterFile,$draw_log)=@_;
	my $species_hash2;
	for my $key(keys(%{$species_hash})){$species_hash2->{$key}=$species_hash->{$key}}
	my $species_to_mark=mark_tested_species($tree);
	my %parameter=("BEBs" => $BEBs,"BEBs_not_significant" => $BEBs_not_significant, "excess_BEBs" =>$excess_BEBs,"flank_BEBs" => $flank_BEBs,"flanks" => $flanks, "species_hash" => $species_hash2,"species_to_mark" => $species_to_mark);
	Storable::store(\%parameter,$parameterFile);
	system("\"$perl\" \"$drawAlignment\" \"$do_image_output\" \"$aln_path\" \"$treePath\" \"$position_seq_gbk_path\" \"$parameterFile\" \"$nucl_aln_path\" \"$prot_aln_path\" \"$nucl_jalview_out_path\" \"$prot_jalview_out_path\" \"$aln_translation_out_path\" \"$out_path\" \"$aln_translation_out_path_interleaved\" \"$out_path_interleaved\" \"$aln_translation_out_path_anno\" \"$out_path_anno\" \"$aln_translation_out_path_interleaved_anno\" \"$out_path_interleaved_anno\" $BEB_significance_threshold $image_output_format \"$draw_log\"");
	#unlink($parameterFile);
}

sub mark_tested_species{
	my ($tree)=@_;
	my $marked_node="";
	my %species_to_mark;
	for my $node($tree->get_nodes()){
		my $s=$node->id;
		if ($s=~m/#1/){$marked_node=$node}
	}
	if ($marked_node ne ""){
		my @nodes=get_all_terminal_descendents($marked_node);
		my @ids=map{my $id=$_->id; $id=~s/[# 0-9]//g; $id} @nodes;
		for my $id(@ids){$species_to_mark{$id}=""}
	}
	return \%species_to_mark;
}

sub get_all_terminal_descendents{
	my ($node)=@_;
	if ($node->is_Leaf){return $node}
	else{return map{get_all_terminal_descendents($_)} $node->each_Descendent}
}

sub readFlanksFromGblocksHtm{
	my ($htm)=@_;
	open(my $f,$htm);
	my @flanks;
	while(my $line=<$f>){
		chomp($line);
		if ($line=~s/^Flanks: //){
			$line=~s/[\[\]]//g;
			@flanks=split(" ",$line);
		}
	}	
	close($f);
	my @ret;
	for (my $i=0; $i<@flanks; $i=$i+2){
		my @flank=($flanks[$i],$flanks[$i+1]);
		push(@ret,\@flank);
	}
	return @ret;
}

sub output_hash_as_text{
	my ($hash, $output)=@_;
	open (OUT, ">".$output);
	for my $key (keys(%$hash)){
		print(OUT "$key"."\t".$hash->{$key}."\n");
	}
	close(OUT);
}

sub output_results_as_text_sorted{
	my ($hash, $output)=@_;
	open (OUT, ">".$output);
	print(OUT "Transcript\tBonferroni\tFDR\tP-Value\tP-Value raw\tPath\tNumber of species included\tSpecies included\tJalview protein alignment\tJalview nucleotide alignment\tAnnotated protein alignment (interleaved)\tAnnotated nucleotide alignment (interleaved)\tProtein Alignment (interleaved)\tNucleotide alignment (interleaved)\tAnnotated protein alignment (sequential)\tAnnotated nucleotide alignment (sequential)\tProtein Alignment (sequential)\tNucleotide alignment (sequential)\tHA foreground omega\tHA background omega\tHA kappa\tH0 foreground omega\tH0 background omega\tH0 kappa\tCorrection code\tNumber of Sites under positive Selection");
	for (my $i=1; $i<=$max_BEBs;$i++){
		if($i==1){
			if ($use_prank_aln){print(OUT "\tSite under positve Selection $i(1. Probability to be under positive selection;2. Position in amino acid sequence of anchor species;3. Position in nucleotide sequence of anchor species;4.Position in main protein alignment:fastp.clustalw.aln;5. Position in protein clustal subalignment: .aln;6. Position in to codon backtranslated clustal subalignment: Codon_aln.fasta; 7. Position in prank alignment (protein); 8. Position in prank alignment (codon): prank.best.fas; 9. Position in PAML-ready prank alignment: prank.best.fas.prepared-gb; 10. Amino acid in anchor species;11. Codon in anchor species)");}
			else{print(OUT "\tSite under positve Selection $i(1. Probability to be under positive selection;2. Position in amino acid sequence of anchor species;3. Position in nucleotide sequence of anchor species;4.Position in main protein alignment:fastp.clustalw.aln;5. Position in protein subalignment:with_best_of_other_species.aln;6. Position in to nucleotide backtranslated sub-alignment:with_best_of_other_species.aln_codon.fasta;7. Position in backtranslated and PAML-ready processed sub-alignment:with_best_of_other_species.aln_codon.fasta-gb_codeml_prepared;8. Amino acid in anchor species;9. Codon in anchor species)");}
		}else {print(OUT "\tSite under positve Selection $i");}
	}
	print(OUT "\n");
	foreach my $key (sort { ((($hash->{$a}->[18] eq "NA") || ($hash->{$b}->[18] eq "NA"))?$hash->{$a}->[18] cmp $hash->{$b}->[18]:$hash->{$a}->[18] <=> $hash->{$b}->[18]) or ($hash->{$a}->[2] <=> $hash->{$b}->[2]) } keys (%$hash)) {
  		try{
	  		print(OUT $hash->{$key}->[3]."\t".$hash->{$key}->[19]."\t".$hash->{$key}->[20]."\t".$hash->{$key}->[18]."\t".$hash->{$key}->[2]."\t\""."$key"."\"\t".$hash->{$key}->[0]."\t".$hash->{$key}->[1]."\t\"".$hash->{$key}->[16]."\"\t\"".$hash->{$key}->[15]."\"\t\"".$hash->{$key}->[7]."\"\t\"".$hash->{$key}->[8]."\"\t\"".$hash->{$key}->[9]."\"\t\"".$hash->{$key}->[10]."\"\t\"".$hash->{$key}->[11]."\"\t\"".$hash->{$key}->[12]."\"\t\"".$hash->{$key}->[13]."\"\t\"".$hash->{$key}->[14]."\"\t".$hash->{$key}->[5]->{"omega_foreground"}."\t".$hash->{$key}->[5]->{"omega_background"}."\t".$hash->{$key}->[6]->{"kappa"}."\t".$hash->{$key}->[6]->{"omega_foreground"}."\t".$hash->{$key}->[6]->{"omega_background"}."\t".$hash->{$key}->[6]->{"kappa"}."\t".$hash->{$key}->[17]."\t");
			if (defined($hash->{$key}->[4])) {
				 print(OUT int(@{$hash->{$key}->[4]}));		
		  		for my $BEB(@{$hash->{$key}->[4]}){
		  			if ($use_prank_aln){print(OUT "\t1. ".$BEB->[1].";2. ".$BEB->[6].";3. ".$BEB->[7].";4. ".$BEB->[8].";5. ".$BEB->[2].";6. ".$BEB->[3].";7. ".$BEB->[10].";8. ".$BEB->[9].";9. ".$BEB->[0].";10. ".$BEB->[4].";11. ".$BEB->[5]);}
		  			else{print(OUT "\t1. ".$BEB->[1].";2. ".$BEB->[6].";3. ".$BEB->[7].";4. ".$BEB->[8].";5. ".$BEB->[2].";6. ".$BEB->[3].";7. ".$BEB->[0].";8. ".$BEB->[4].";9. ".$BEB->[5]);}
		  		}
			}
		}catch{$errorString.="Could not output line for ".$key."\n";};
	  	print(OUT "\n");

	}
	close(OUT);
}


sub short_output_results_as_text_sorted{
	my ($hash, $output)=@_;
	open (OUT, ">".$output);
	print(OUT "Gene\tTranscript\tFDR\tP-Value\tNumber of species included\tNumber of Sites under positive Selection\tJalview protein alignment\tProtein Alignment (interleaved)");
	print(OUT "\n");
	foreach my $key (sort { ((($hash->{$a}->[18] eq "NA") || ($hash->{$b}->[18] eq "NA"))?$hash->{$a}->[18] cmp $hash->{$b}->[18]:$hash->{$a}->[18] <=> $hash->{$b}->[18]) or ($hash->{$a}->[2] <=> $hash->{$b}->[2]) } keys (%$hash)) {
  		try{
  			my $gene=File::Basename::basename(File::Basename::dirname(File::Basename::dirname($key)));  			
	  		print(OUT $gene."\t".$hash->{$key}->[3]."\t".$hash->{$key}->[20]."\t".$hash->{$key}->[18]."\t".$hash->{$key}->[0]."\t".(defined($hash->{$key}->[4])?int(@{$hash->{$key}->[4]}):"-")."\t\"".$hash->{$key}->[16]."\"\t\"".$hash->{$key}->[7]."\"\t");
		}catch{$errorString.="Could not output line for ".$key."\n";};
	  	print(OUT "\n");

	}
	close(OUT);
}

sub filter_for_iso_with_highest_p{
	my ($results)=@_;
	my %ret;
	my %genes;
	for my $key (sort {($results->{$b}->[18] <=> $results->{$a}->[18]) || ($results->{$b}->[2] <=> $results->{$a}->[2]) } keys (%$results)) {
		my @folders=split("/",$key);
		if ((int(@folders)>2) && (!exists($genes{$folders[$#folders-2]}))){
			$genes{$folders[$#folders-2]}="";
			$ret{$key}=$results->{$key}
		}
	}
	return \%ret;
}

sub filter_for_iso_with_lowest_p{
	my ($results)=@_;
	my %ret;
	my %genes;
	for my $key (sort {((($results->{$a}->[18] eq "NA") || ($results->{$b}->[18] eq "NA"))?$results->{$a}->[18] cmp $results->{$b}->[18]:$results->{$a}->[18] <=> $results->{$b}->[18]) || ($results->{$a}->[2] <=> $results->{$b}->[2]) } keys (%$results)) {
		my @folders=split("/",$key);
		if ((int(@folders)>2) && (!exists($genes{$folders[$#folders-2]}))){
			$genes{$folders[$#folders-2]}="";
			$ret{$key}=$results->{$key}
		}		
	}
	return \%ret;	
}

sub get_lnL{
	my ($filePath)=@_;
	my ( $num_param, $loglikelihood );
	open (my $IN, $filePath);
	while (my $line=<$IN>){
		if ($line=~/^\s*lnL\(.+np\:\s*(\d+)\)\:\s+(\S+)/) {
             ( $num_param, $loglikelihood )= ( $1, $2 );
        }
	}
	close($IN);
	return ($num_param, $loglikelihood);
}

sub chi2{
	my $p;
	my ($a0,$a1,$id_path,$out_path)=@_;
	try{			
#	my $parser0=Bio::Tools::Phylo::PAML->new(-file => $a0);
#	my $parser1=Bio::Tools::Phylo::PAML->new(-file => $a1);
#	my $a0_result=$parser0->next_result();
#	my $a1_result=$parser1->next_result();
#	my $tree0=$a0_result->next_tree();
#	my $tree1=$a1_result->next_tree();
#	my $Lnl0=$tree0->score();
#	my $Lnl1=$tree1->score();
	my ($DoF0,$Lnl0)=get_lnL($a0);
	my ($DoF1,$Lnl1)=get_lnL($a1);
	my $LRT=2*($Lnl1-$Lnl0);
	if ($LRT<0) {$p=1}
	else{	
		#my $DoF0=(split(":",$tree0->id))[1];
		#my $DoF1=(split(":",$tree1->id))[1];
		my $df_dif=$DoF1-$DoF0;		
		$dfdif{$id_path}=$df_dif;
		if ($df_dif!=1){$DFdifnot1{$id_path}=0;}
		system("$chi2Path ".$df_dif." ".$LRT." >\"".$out_path."\"");	
		open(CHI2, $out_path);
		while(my $line=<CHI2>){
			my @split_line=split(" = ",$line);
			if (scalar(@split_line)==4){
				$p=trim($split_line[3]);
			}
		}
		close(CHI2);
		if (!defined($p)){$chi2NotCalculated{$id_path}=0;}
	}	
	} catch{$errorString.="chi2_error:".$id_path.":".$_."\n\n";$errors++;$chi2NotCalculated{$id_path}=0;};
	return $p;
}

sub prepare_aln{
	my ($aln)=@_;
	my %pseqs;
	for my $seq($aln->each_seq()){$pseqs{$seq->id}=$seq->translate(-codontable_id => $genetic_code)->seq()}		
	for my $seq($aln->each_seq()){
    	$aln->remove_seq($seq);
		my $pseq=$pseqs{$seq->id};
		my @newSeq=split(//,$seq->seq());
		my $stop_pos=0;
		for ($stop_pos=my_index($pseq,$stop_pos,"*","X");($stop_pos!=-1) && ($stop_pos<length($pseq));$stop_pos=my_index($pseq,$stop_pos,"*","X")){			
			my $is_removable_pos=1;
			for my $seq_id(keys(%pseqs)){
				if ($seq_id ne $seq->id){
					 my $c=substr($pseqs{$seq_id},$stop_pos,1);
					 if ($c eq "-"){$is_removable_pos=0}
				}
			}
			if ($is_removable_pos){@newSeq[3*$stop_pos..3*$stop_pos+2]=("-","-","-");}
			$stop_pos++;
		}
		$seq=Bio::LocatableSeq->new(-id => $seq->id(), -seq => join ("",@newSeq), -start => $seq->start(), -end => $seq->end());
    	$pseqs{$seq->id}=$seq->translate(-codontable_id => $genetic_code)->seq;
    	$seq->{verbose}=0;
    	$aln->add_seq($seq);  								
	}
	##remove_positions_with_gaps_in_all_seqs($aln_prep);	
}

sub my_index{
	my ($str,$position,@substrs)=@_;
	my $smallest=-1;
	for my $substr(@substrs){
		my $current=index($str,$substr,$position);
		if (($current<$smallest) || ($smallest==-1)){$smallest=$current}
	}
	return $smallest;
}

sub trim($){
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}


sub getBEBs{
	my ($rst,$flanks,$species_hash,$sub_aln,$main_aln_path,$sub_aln_transl_to_nucl,$gblocks_input_aln)=@_;
	my $position_seq_id;
	my $position_gblocks_input_aln_seq;
	#my $gblocks_input_aln;
	#if ($use_prank_aln){$gblocks_input_aln=Bio::AlignIO->new (-file => $path_to_prank_codon_aln ,-format => 'fasta')->next_aln();}
	#else {$gblocks_input_aln=$sub_aln_transl_to_nucl;}
	for my $seq($gblocks_input_aln->each_seq()){		
		if ($species_hash->{$seq->id()} eq $position_species){$position_gblocks_input_aln_seq=$seq;$position_seq_id=$seq->id();}
	}
	my $sub_aln_position_seq;
	for my $seq($sub_aln->each_seq()){		
		if ($species_hash->{$seq->id()} eq $position_species){$sub_aln_position_seq=$seq;}
	}		 
	open(my $f,$rst);
	my $read_mode_on=0;
	my @ret;
	while(my $line=<$f>){		
		chomp($line);
		if ($line eq "Bayes Empirical Bayes (BEB) probabilities for 4 classes (class)"){$read_mode_on=1;}
		elsif($read_mode_on==1){
			if ($line=~/\( [1234]\)$/){
				my @l=split(" ",$line);
				my @help=($l[0]*3-2,$l[4]+$l[5]);
				push(@ret,\@help);
			}
		}
	}
	close($f);
	sort{$b->[1] <=> $a->[1]} @ret;	
	my $main_aln=-1;
	if (-e $main_aln_path){$main_aln=Bio::AlignIO::clustalw->new (-file => $main_aln_path)->next_aln();}	
	for my $BEB_pos(@ret){
		my $processed_codon_alignment_pos=$BEB_pos->[0]+2;
		for my $flank(@{$flanks}){
			my $bases_in_flank=$flank->[1]-$flank->[0]+1;
			if ($processed_codon_alignment_pos<=$bases_in_flank){
				my $gblocks_input_aln_pos=$flank->[0]+$processed_codon_alignment_pos-3;
				my $gblocks_input_aln_translated_pos=($gblocks_input_aln_pos+2)/3;
				my $codon_under_positive_selection=substr($position_gblocks_input_aln_seq->seq,$gblocks_input_aln_pos-1,3);
				
				my $position_gblocks_input_aln_seq_till_pos=substr($position_gblocks_input_aln_seq->seq,0,$gblocks_input_aln_pos);
				my $number_of_gaps=$position_gblocks_input_aln_seq_till_pos=~tr/-//;				
				my $nucl_seq_pos=$gblocks_input_aln_pos-$number_of_gaps;
				my $seq_pos=($nucl_seq_pos+2)/3;
	
				my $sub_aln_pos=$sub_aln->column_from_residue_number($position_seq_id,$seq_pos);
						
				my $amino_acid_under_positive_selection=substr($sub_aln_position_seq->seq,$sub_aln_pos-1,1);
				my $backtranslated_sub_aln_pos=$sub_aln_transl_to_nucl->column_from_residue_number($position_seq_id,$nucl_seq_pos);

				my $main_aln_pos=-1;
				if ($main_aln){$main_aln_pos=$main_aln->column_from_residue_number($position_seq_id,$seq_pos);}
				push(@{$BEB_pos},$sub_aln_pos,$backtranslated_sub_aln_pos,$amino_acid_under_positive_selection,$codon_under_positive_selection,$seq_pos,$nucl_seq_pos,$main_aln_pos,$gblocks_input_aln_pos,$gblocks_input_aln_translated_pos);
				last;
			}
			else{$processed_codon_alignment_pos=$processed_codon_alignment_pos-$bases_in_flank}
		}
	}
	return \@ret;
	
}

sub check_context_species{
	my ($species_not_present,$context_species)=@_;
	for my $species_group(@$context_species){
		my $b=0;
		for my $species(@$species_group){
			if(!(exists($species_not_present->{$species}))){$b=1} 
		}
		if(!$b){return 0}
	}
	return 1;
}

sub context_species{
	my ($treeFile,$context_species)=@_;
	my @ret;
	if ((int(@context_species)==1) && ($context_species[0] eq "auto")){
		my $tree=Bio::TreeIO->new('-format' => 'newick','-file'   => $treeFile)->next_tree();
		for my $marked_node($tree->get_nodes){
			if($marked_node->id=~/#1$/){
				for my $descendent($marked_node->ancestor->each_Descendent){
					if ($descendent ne $marked_node){
						push(@ret,[get_all_leafs_ids($descendent)])
					}
				}				
			}
		}		
	} else{for my $species(@$context_species){push(@ret,[$species]);}}
	return @ret;
}

sub get_all_leafs_ids{
	my ($node)=@_;
	if ($node->is_Leaf){return $node->id}
	else{
		my @ret;
		for my $descendent($node->each_Descendent){push(@ret,get_all_leafs_ids($descendent))}
		return @ret;
	}
}

sub getMainTree{
	my ($treeFile,@target_species)=@_;
	my $main_tree=Bio::TreeIO->new('-format' => 'newick','-file'   => $treeFile)->next_tree();
	make_tree_unrooted($main_tree);
	my $tested_branch_string="";
	if ($branchinfo ne ""){$tested_branch_string="$branchinfo"};
	my $main_tree_path=$trees_dir."CodeML_tree$tested_branch_string\_anchor_species=$position_species.newick";
	my $raute1_counts=0;
	my %species_in;
	for my $node($main_tree->get_nodes()){
		my $s=$node->id();
		$s=~s/ /_/g;
		$s=~s/_*#/#/g;
		if ($s=~/#/){
			if ($s=~/#1$/){$raute1_counts++}
			else {print("Only #1 marks are allowed...\n");exit(1);}
		}
		$node->id($s);
		if ($node->is_Leaf){$species_in{$node->id}=""}
	}
	if ($raute1_counts>1){print("Only one #1 mark is allowed...\n");exit(1);}
	elsif ($raute1_counts==0){
		if (@target_species==0){push(@target_species,$position_species)}
		my @target_species_not_found;
		for my $species(@target_species){if(!exists($species_in{$species})){push(@target_species_not_found,$species)}}
		if (@target_species_not_found>0){print("The following species named as target species could not be found in the species tree: ".join(", ",@target_species_not_found)."...\n");	exit(1);}	
		my @context_species_not_found;		
		if(!((@context_species==1) && ($context_species[0] eq "auto"))){
			for my $species(@context_species){if(!exists($species_in{$species}) ){push(@context_species_not_found,$species)}}
		}
		if (@context_species_not_found>0){print("The following species named as context species could not be found in the species tree: ".join(", ",@context_species_not_found)."...\n");	exit(1);}
		$main_tree=mark_branch($main_tree,@target_species);			
	}	
	Bio::TreeIO->new('-format' => 'newick','-file'   => ">".$main_tree_path)->write_tree($main_tree);
	return ($main_tree_path,$main_tree);
}

sub mark_branch{
	my ($tree,@target_leafs)=@_;
	my @target_nodes=find_nodes($tree,\@target_leafs,1);
	my $lca = (@target_nodes==1)?$target_nodes[0]:$tree->get_lca(-nodes => \@target_nodes);
	#if($tree->get_root_node()->each_Descendent()<3){	
		my @internal_nodes;
		for my $node($tree->get_nodes){if(($node ne $tree->get_root_node) && !($node->is_Leaf)){push(@internal_nodes,$node)}}
		for (my $i=0; ($i<@internal_nodes) && ($lca eq $tree->get_root_node);$lca=$tree->get_lca(-nodes => \@target_nodes)){	
			$tree->reroot($internal_nodes[$i++]);
			my_contract_linear_paths($tree,1);
		}
		my_contract_linear_paths($tree,1);
	#}
	if($lca eq $tree->get_root_node){				
		print("The set of target species you specified leads to the last common ancestor of all species in the tree. If you really want to test this branch for positive selection you have to add outgroup species to the data set with \"add_species\" and to use \"alignment\" again...\n");
		exit(1);
	}	
	else{$lca->id($lca->id."#1")}
	return $tree;
}

sub find_nodes{
	my ($tree,$targets,$check_nodes)=@_;
	my @target_nodes;
	for my $target(@$targets){
		my @nodes=$tree->find_node(-id => $target);
		if($check_nodes && (@nodes>1)){print($target."occurs multiple times in the tree...\n");exit(1);}
		push(@target_nodes,@nodes);
	}
	return @target_nodes;		
}

sub remove_positions_with_gaps_in_all_seqs{
	my $aln=$_[0];
	my %seqs;
	my %seqs_new;
	for my $seq($aln->each_seq){
		my @x=split("",$seq->seq);
		$seqs{$seq->id()}=\@x;
		$seqs_new{$seq->id()}="";
	}
	for (my $i=0; $i<$aln->length();$i++){
		my $b=0;
		for my $seqID(keys(%seqs)){
			if (($seqs{$seqID}->[$i] ne ".") && ($seqs{$seqID}->[$i] ne "-")){$b=1}
		}
		if ($b){
			for my $seqID(keys(%seqs)){
				$seqs_new{$seqID}.=$seqs{$seqID}->[$i];
			}
		}
	}
	for my $seq($aln->each_seq){
		$aln->remove_seq($seq);
		my $new_seq=Bio::LocatableSeq->new( -seq => $seqs_new{$seq->id()},-id => $seq->id());
		$aln->add_seq($new_seq);
	}	
}

sub make_tree_unrooted{
	my ($tree)=@_;
	my $root=$tree->get_root_node();
	my @children=$root->each_Descendent();
	if (int(@children)<3){
		for my $child(@children){
			if ((!$child->is_Leaf) && (!($child->id()=~/#1/))){
				my $ret=$tree->reroot($child);
				my_contract_linear_paths($tree,1);
				return $ret;
			}
		}
	} else {return 1}
	return 0;
}

sub my_contract_linear_paths{
	my ($self,$reroot)=@_;
    my @remove;
    my $i=0;
    foreach my $node ($self->get_nodes) {
        if ($node->ancestor && $node->each_Descendent == 1) {
        	my $id=$node->id(++$i);
            push(@remove, $id);
        }
    }
    $self->splice(-remove_id => \@remove,-preserve_lengths => 1) if @remove;
    if ($reroot) {
        my $root = $self->get_root_node;
        my @descs = $root->each_Descendent;
        if (@descs == 1) {
            my $new_root = shift(@descs);
            $self->set_root_node($new_root);
        }
    }
    $self->get_root_node->ancestor(undef);
}

sub thread_safe_rmtree{
	if (int(@_)>1){for my $arg(@_){thread_safe_rmtree($arg)}}
	else{
		my ($path)=@_;
		if (-e $path){
			if (-d $path){
		 		if (substr($path,length($path)-1,1) ne "/"){$path.="/"}
		 		opendir(my $dir, $path);
		 		my @files=readdir($dir);
		 		close($dir);
		 		for my $file(@files){
		 			if (($file ne "..") && ($file ne ".")){	
		 				if (-d $path.$file){thread_safe_rmtree($path.$file);}
		 				else {unlink ($path.$file)}
		 			}
		 		}
		 		rmdir($path);
			}else{unlink($path)}			
		}
	}
}

sub multiple_test_correction{
	my ($result)=@_;
	for my $key(keys(%{$result})){
		if ((!defined($result->{$key})) || (!defined($result->{$key}->[2]))){
			delete($result->{$key});
		}
	}
	my @ps;
	my @ids=keys(%$result);
	for my $id(@ids){push(@ps,$result->{$id}->[18])}
	my @bonferronis=bonferroni(@ps);
	my @fdrs=fdr(@ps);
	for (my $i=0; $i<@ids;$i++){
		$result->{$ids[$i]}->[19]=$bonferronis[$i];
		$result->{$ids[$i]}->[20]=$fdrs[$i];
		##push(@{$result->{$ids[$i]}},$bonferronis[$i],$fdrs[$i])		
	}
	return $result;
}

sub fdr{
	my @qs;
	my ($ps_ordered,$orig_pos)=selection_sort_decreasing(@_);
	my $max=1;
	my @qs;
	my $l=@_;
	my $i=@_;
	for my $p(@$ps_ordered){
		if ($p ne "NA"){
			my $q=min($p*($l/$i),1,$max);
			$max=$q;
			push (@qs,$q);
		} else {
			$l--;
			push(@qs,"NA");
		}
		$i--;
	} 
	my @qs_ret;
	for (my $i=0; $i<@_; $i++){$qs_ret[$orig_pos->[$i]]=$qs[$i]}
	return @qs_ret; 
}

sub selection_sort_decreasing{
	my @list=@_;
	my @indices;
	for (my $i=0; $i<@list;$i++){$indices[$i]=$i} 
	for (my $i=0; $i<(@list-1);$i++){
		my $max=$i;
		for (my $j=$i+1; $j<@list;$j++){
			if (($list[$max] ne "NA") && (($list[$j] eq "NA") || ($list[$j]>$list[$max]))){$max=$j}
		}
		my $h=$list[$i];
		$list[$i]=$list[$max];
		$list[$max]=$h;
		my $h=$indices[$i];
		$indices[$i]=$indices[$max];
		$indices[$max]=$h;
	}
	return(\@list,\@indices);
}

sub bonferroni{
	my @qs;
	my $l=0;
	for my $p(@_){if($p ne "NA"){$l++}}
	for my $p(@_){
		if ($p eq "NA") {push(@qs,"NA")}
		else {push(@qs,min(1,$l*$p))}
	}
	return @qs;
}

sub min{
	my $min=undef;
	for my $i(@_){
		if (!(defined($min)) || ($i<$min)){$min=$i}
	}
	return $min;
}

#override Bio::AlignIO::fasta::next_aln because of bug with length information in name, that occured in version 1.6.923 and made length info part of id. If the seq then is again written to disk, the length info is added a second time.  
sub Bio::AlignIO::fasta::next_aln{
    my $self = shift;
    my ($width) = $self->_rearrange( [qw(WIDTH)], @_ );
    $self->width( $width || 60 );

    my ($start, $end,      $name,     $seqname, $seq,  $seqchar,
        $entry, $tempname, $tempdesc, %align,   $desc, $maxlen
    );
    my $aln = Bio::SimpleAlign->new();

    while ( defined( $entry = $self->_readline ) ) {
        chomp $entry;
        if ( $entry =~ s/^>\s*(\S+)\s*// ) {
            $tempname = $1;
            chomp($entry);
            $tempdesc = $entry;
            if ( defined $name ) {
		    	$seqchar =~ s/\s//g;
				# put away last name and sequence
		    	if ( $name =~ /(\S+)\/(\d+)-(\d+)/ ) {
					$seqname = $1;
					$start = $2;
					$end = $3;
		    	} else {
					$seqname = $name;
					$start = 1;
					$end = $self->_get_len($seqchar);
		    	}
                $seq     = Bio::LocatableSeq->new(
                    -seq         => $seqchar,
                    -display_id  => $seqname,
                    -description => $desc,
                    -start       => $start,
                    -end         => $end,
                    -alphabet    => $self->alphabet,
                );
                $aln->add_seq($seq);
                $self->debug("Reading $seqname\n");
            }
            $desc    = $tempdesc;
            $name    = $tempname;
            $desc    = $entry;
            $seqchar = "";
            next;
        }

        # removed redundant symbol validation
        # this is already done in Bio::PrimarySeq
        $seqchar .= $entry;
    }

    #  Next two lines are to silence warnings that
    #  otherwise occur at EOF when using <$fh>
    $name    = "" if ( !defined $name );
    $seqchar = "" if ( !defined $seqchar );
    $seqchar =~ s/\s//g;

    #  Put away last name and sequence
    if ( $name =~ /(\S+)\/(\d+)-(\d+)$/ ) {
        $seqname = $1;
        $start   = $2;
        $end     = $3;
    }
    else {
        $seqname = $name;
        $start   = 1;
        $end     = $self->_get_len($seqchar);
    }

    # This logic now also reads empty lines at the
    # end of the file. Skip this is seqchar and seqname is null
    unless ( length($seqchar) == 0 && length($seqname) == 0 ) {
        $seq = Bio::LocatableSeq->new(
            -seq         => $seqchar,
            -display_id  => $seqname,
            -description => $desc,
            -start       => $start,
            -end         => $end,
            -alphabet    => $self->alphabet,
        );
        $aln->add_seq($seq);
        $self->debug("Reading $seqname\n");
    }
    my $alnlen = $aln->length;
    foreach my $seq ( $aln->each_seq ) {
        if ( $seq->length < $alnlen ) {
            my ($diff) = ( $alnlen - $seq->length );
            $seq->seq( $seq->seq() . "-" x $diff );
        }
    }

    # no sequences means empty alignment (possible EOF)
    return $aln if $aln->num_sequences;
}
