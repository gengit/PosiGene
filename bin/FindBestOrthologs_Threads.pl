BEGIN{
	while (-l $0){$0=readlink($0)}
	my @path=split(/\/|\\/,$0);
	my $path=join("/",@path[0..(@path-2)])."/../modules";
	push (@INC,$path);
}

use strict;
use threads;
use threads::shared;
use Try::Tiny;
use Bio::AlignIO;
use Bio::SimpleAlign;
#use Bio::Tools::Run::Alignment::Clustalw;
use Bio::Align::Utilities;
use Bio::SeqIO::fasta;
use File::Path;
use File::Basename;
use Storable;

open (STDERR, ">/dev/null");#disable warnings, should be commented out when debugging 
no warnings;#disable warnings, should be commented out when debug

#my $refPath="/misc/vulpix/data/asahm/Reference/";
#my $refPath="/misc/vulpix/data/asahm/positive_selection_kim_et_al_nature_test/";
#my $refPath="/home/lakatos/asahm/workspace2/Test/";
#my $refPath="/misc/vulpix/data/asahm/thyroid_positive_selection/";
#my $refPath="/misc/enton/data/asahm/Reference4/";
#my $refPath="/home/lakatos/asahm/enton/misc_analysis/thyroid/KaKs4/";
#my $refPath="/misc/enton/data/asahm/Reference_7_3/";
#my $refPath="/home/lakatos/asahm/Desktop/Reference_Test2/";
my ($progress,$individual_results_dir,$minPercIdentityDemanded,$minPercIdentityDemanded_all_vs_all,$species_of_interest_string,$concat_alns_string,$logFile,$threadNum)=@ARGV;
#my ($refPath,$species_of_interest_string,$logFile,$threadNum)=("/misc/enton/data/asahm/Reference_7_3/","Heterocephalus glaber,Fukomys anselli","FindBestOrthologs.log",64);
#my ($refPath,$species_of_interest_string,$logFile,$threadNum)=("/misc/enton/data/asahm/Reference_7_2/","Homo sapiens","FindBestOrthologs.log",70);
#my ($refPath,$species_of_interest_string,$logFile,$threadNum)=("/home/lakatos/asahm/Desktop/Reference_Test2/","Homo sapiens","FindBestOrthologs.log",70);
#my ($refPath,$minPercIdentityDemanded,$minPercIdentityDemanded_all_vs_all,$species_of_interest_string,$concat_alns_string,$logFile,$threadNum)=("/home/lakatos/asahm/Desktop/Test_positive_selection2/",75,60,"Pantholops_hodgsonii","selected_species_Pantholops_hodgsonii_concat_aln.fasta","FindBestOrthologs.log",16);
#my ($refPath,$minPercIdentityDemanded,$species_of_interest_string,$concat_alns_string,$logFile,$threadNum)=("/home/lakatos/asahm/enton/Tibetan_Antelope+9_species/",33.33,"Pantholops_hodgsonii","selected_species_Pantholops_hodgsonii_concat_aln.fasta","FindBestOrthologs.log",64);
#my ($refPath,$minPercIdentityDemanded,$species_of_interest_string,$concat_alns_string,$logFile,$threadNum)=("/home/lakatos/asahm/enton/Public_Hglaber+3Species/",33.33,"Heterocephalus_glaber","selected_species_Heterocephalus_glaber_concat_aln.fasta","FindBestOrthologs.log",48);
#my ($refPath,$minPercIdentityDemanded,$species_of_interest_string,$concat_alns_string,$logFile,$threadNum)=("/home/lakatos/asahm/enton/Public_Hglaber+3Species_minIdent=80/",80.00,"Heterocephalus_glaber","selected_species_Heterocephalus_glaber_concat_aln.fasta","FindBestOrthologs.log",48);
#my ($refPath,$minPercIdentityDemanded,$species_of_interest_string,$concat_alns_string,$logFile,$threadNum)=("/home/lakatos/asahm/enton/7_ant_species+5_outgroups/",33.33,"Harpegnathos_saltator","selected_species_Harpegnathos_saltator_concat_aln.fasta","FindBestOrthologs.log",48);


my @species_of_interest=split(",",$species_of_interest_string);
for my $species(@species_of_interest){$species=~s/ /_/g;}

my @concat_alns=split(",",$concat_alns_string);
for my $aln($concat_alns_string){$aln=~s/ /_/g;}
my %concat_alns;
for (my $i=0; $i<@species_of_interest; $i++){$concat_alns{$species_of_interest[$i]}=$concat_alns[$i]}

if (int(@concat_alns)!=int(@species_of_interest)){print("Number of selected species does not match number of alignment file names...");exit(1);}

my %numberOfCoveredSymbols:shared;#Datatype: Hash: Species_of_Interest_Name->(Hash:Species_name->Number(how many symbols are covered by that species))
my %numberOfCoveredAlignments:shared;#Datatype: Hash: Species_of_Interest_Name->(Hash:Species_name->Number(how many alignments are covered by that species))

my %minPercIdenityStatisticsSymbols:shared;#Datatype: Hash: Species_of_Interest_Name->(Hash:Species_name->(Hash:PercIdentityThreshold->Number(how many symbols are covered by that species)))
my %minPercIdenityStatisticsAlignments:shared;#Datatype: Hash: Species_of_Interest_Name->(Hash:Species_name->(Hash:PercIdentityThreshold->Number(how many alignments are covered by that species)))
my %speciesToSpeciesIdentSums:shared;#Datatype: Hash: Species_of_Interest_Name->(Hash: SpeciesA-SpeciesB(sorted lexicographically)->Sum_of_Identity)
my %speciesToSpeciesIdentSums_nucl:shared;#Datatype: Hash: Species_of_Interest_Name->(Hash: SpeciesA-SpeciesB(sorted lexicographically)->Sum_of_Identity)
my %speciesToSpeciesTotal:shared;#Datatype: Hash: Species_of_Interest_Name->(Hash: SpeciesA-SpeciesB(sorted lexicographically)->Total_Number_of_Comparisons)
my %longestOrthologNotMostIdentical:shared;#Datatype: Hash: Species_of_Interest_Name->(Array of [GeneSymbol,SelectedSpecies,SelectedSpecies_TranscriptName,TargetSpecies,TargetSpecies_Longest_TranscriptName,TargetSpecies_Longest_Length,TargetSpecies_Longest_Ident,TargetSpecies_MostIdent_TranscriptName,TargetSpecies_MostIdent_Length,TargetSpecies_MostIdent_Ident,Difference_of_Identity])
 
my $genes:shared=0; 
my %genes:shared;
my $alignments_created:shared=0;
my $errors:shared=0;
my $errorString:shared="";
my @threads;
print("Step 4/7, reading directory content...\n");
opendir(REFDIR, $individual_results_dir);
my @refdir2 = readdir(REFDIR);
closedir(REFDIR);
my @refdir;
for my $e(@refdir2){
	if(-d $individual_results_dir.$e && !(($e eq ".") || ($e eq "..")) ){
		push(@refdir,$e);
	}
}

my @dirsPerThread;
for (my $i=0; $i<@refdir;$i++){
	push(@{$dirsPerThread[$i % $threadNum]},$refdir[$i]);
}

for (my $i=0; $i<$threadNum; $i++){	
	#myThread(@{$dirsPerThread[$i]});
	push(@threads, threads->create(\&myThread,@{$dirsPerThread[$i]}));
	sleep(0.1);
	print ("Step 4/7, created ".($i+1)."/".$threadNum." threads\n");		
}
#print ("FINISHED starting Threads...\n");
my $x=0;
my %subalns_nucl;
for my $thread(@threads){
	my %subalns_part=%{$thread->join()};
	for my $species(keys(%subalns_part)){
		push(@{$subalns_nucl{$species}},@{$subalns_part{$species}});
	}
	print ("Step 4/7, ".++$x."/".$threadNum." threads returned\n");
}
print("Step 4/7, creating concatenated alignment...\n");
my %number_of_alns_with_all_species;

for my $species_of_interest(keys(%subalns_nucl)){$number_of_alns_with_all_species{$species_of_interest}=output_concat_aln($concat_alns{$species_of_interest},\@{$subalns_nucl{$species_of_interest}},int(keys(%{$minPercIdenityStatisticsSymbols{$species_of_interest}}))+1)}

open (LOGFILE, ">".$logFile);
print(LOGFILE "Errors total: ".$errors."\n"); 
print(LOGFILE "Alignments created: ".$alignments_created."\n"); 
print(LOGFILE $errorString."\n\n\n");
for my $species_of_interest(@species_of_interest){
	print(LOGFILE "Average protein identities:\n\n");	
	for my $speciesToSpeciesString(sort(keys(%{$speciesToSpeciesIdentSums{$species_of_interest}}))){
		print(LOGFILE  "$speciesToSpeciesString: ".($speciesToSpeciesIdentSums{$species_of_interest}{$speciesToSpeciesString}/$speciesToSpeciesTotal{$species_of_interest}{$speciesToSpeciesString})."%\n");
	}
	print(LOGFILE "\n\n\nAverage nucleotide identities:\n\n");	
	for my $speciesToSpeciesString(sort(keys(%{$speciesToSpeciesIdentSums_nucl{$species_of_interest}}))){
		print(LOGFILE  "$speciesToSpeciesString: ".($speciesToSpeciesIdentSums_nucl{$species_of_interest}{$speciesToSpeciesString}/$speciesToSpeciesTotal{$species_of_interest}{$speciesToSpeciesString})."%\n");
	}
	print(LOGFILE "\n\n\n");
	print(LOGFILE "Demanded minimal alignment identity:".$minPercIdentityDemanded."%\n");

	print(LOGFILE $species_of_interest.":\n\n");
	for my $species(keys(%{$numberOfCoveredSymbols{$species_of_interest}})){
		print(LOGFILE "\tCovered Symbols in ".$species.": ".$numberOfCoveredSymbols{$species_of_interest}{$species}."\n");
		print(LOGFILE "\tCovered Alignments in ".$species.": ".$numberOfCoveredAlignments{$species_of_interest}{$species}."\n");
		print(LOGFILE "\tHow many symbols and alignments would be covered in $species with a demanded minimal alignment identity of (pair identity condition not considered)...\n");	
		for my $i(sort({$a<=> $b} keys(%{$minPercIdenityStatisticsSymbols{$species_of_interest}{$species}}))){
			print(LOGFILE "\t\t$i%\tNumber Symbols:".$minPercIdenityStatisticsSymbols{$species_of_interest}{$species}{$i}."\tNumber Alignments:".$minPercIdenityStatisticsAlignments{$species_of_interest}{$species}{$i}."\n");
		}
		print(LOGFILE "\n");
	}
	print(LOGFILE "\n\n");
	print(LOGFILE "Number of alignments with all species included: ".$number_of_alns_with_all_species{$species_of_interest});
	print(LOGFILE "\n\n");
	print(LOGFILE"\nCases where longest orthologue of a species was not the most identical one:\n\n");
	if (exists($longestOrthologNotMostIdentical{$species_of_interest})){
		@{$longestOrthologNotMostIdentical{$species_of_interest}}=sort{$b->[10] <=> $a->[10]}@{$longestOrthologNotMostIdentical{$species_of_interest}};
		print(LOGFILE  "Gene_Symbol\tSelected_Species\tSelected_Species_Transcript_Name\tTarget_Species\tTarget_Species_Longest_Transcript_Name\tTarget_Species_Longest_Transcript_Length\tTarget_Species_Longest_Transcript_Identity\tTarget_Species_MostIdentical_Transcript_Name\tTarget_Species_MostIdentical_Transcript_Length\tTarget_Species_MostIdentical_Transcript_Identity\tIdentity_Difference\t\n");
		for my $case(@{$longestOrthologNotMostIdentical{$species_of_interest}}){
			for my $field_value(@{$case}){print(LOGFILE  "$field_value\t")}
			print(LOGFILE "\n");
		}
	}
}

close (LOGFILE);
my $pipeline_status;
try{$pipeline_status=Storable::retrieve($progress);}catch{};
for my $species(@species_of_interest){$pipeline_status->{"FindBestOrthologs_Threads"}{$species}={"genes" => $genes{$species},"alignments"=>$numberOfCoveredAlignments{$species}{$species} };}
Storable::store($pipeline_status,$progress);
print ("Step 4/7, FINISHED\n\n");
exit(0);

sub myThread{
	my %subalns_nucl;
	for my $geneName(@_)  {
		my $geneDirPath=$individual_results_dir.$geneName."/";
		if (-d $geneDirPath && ($geneName ne ".") &&($geneName ne "..")){
			print ("Step 4/7, processing gene ".++$genes."/".int(@refdir).": ".$geneName."...\n");			
			for my $species_of_interest(@species_of_interest){				
				++$genes{$species_of_interest};
				my %species;
				my @species;
				my %cds;
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
									if ((!contains(\@species,$speciesName)) && ($speciesName ne $species_of_interest)){push(@species,$speciesName);}
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
				my $aln;
				if (-e $geneDirPath."fastp.clustalw.aln" ){
					try{
						$aln=Bio::AlignIO->new (-file => $geneDirPath."fastp.clustalw.aln" ,-format => 'clustalW')->next_aln;
						#my $nucl_aln=Bio::Align::Utilities::aa_to_dna_aln($aln,\%cds);
						#Bio::AlignIO->new (-file => ">".$geneDirPath."fastp.clustalw.aln.backtranslated" ,-format => 'clustalW')->write_aln($nucl_aln); 				
						my %isSpeciesRepresentedinAnSubAlignment;
						my %isSpeciesRepresentedinAnSubAlignment2;
						for my $species_of_interest_seq($aln->each_seq){
							if($species{$species_of_interest_seq->display_id} eq $species_of_interest){
								if (-e $geneDirPath.$species_of_interest."/".$species_of_interest_seq->display_id.".fastp.clustalw.aln.with_best_of_other_species.aln"){unlink($geneDirPath.$species_of_interest."/".$species_of_interest_seq->display_id.".fastp.clustalw.aln.with_best_of_other_species.aln");}							
								if (-e $geneDirPath.$species_of_interest."/".$species_of_interest_seq->display_id.".fastp.clustalw.aln._with_best_of_other_species.aln"){unlink($geneDirPath.$species_of_interest."/".$species_of_interest_seq->display_id.".fastp.clustalw.aln._with_best_of_other_species.aln");}								
								if (-e $geneDirPath.$species_of_interest."/".$species_of_interest_seq->display_id."_codeml/"){thread_safe_rmtree($geneDirPath.$species_of_interest."/".$species_of_interest_seq->display_id."_codeml/",0,0)} 															
								my @seqNames;
								my @seqNames_all;#only needed for protein identity statistics
								my %identity_to_position_species;
								for my $speciesName (@species){
									my $bestName="";
									my $bestIdent=0;
									my $bestLength=0;
									my $longestName="";
									my $longestLength=0;
									my $longestIdent=0;
								
									for my $seq($aln->each_seq){
										if($species{$seq->display_id} eq $speciesName){
											my $pair_aln=select_by_name($aln,$species_of_interest_seq->display_id,$seq->display_id);
											remove_positions_with_gaps_in_all_seqs($pair_aln);
											#my $percIdent=$pair_aln->percentage_identity();
											my $percIdent;
											if ($species_of_interest_seq->length()>=$seq->length()){$percIdent=$pair_aln->overall_percentage_identity("long")} 
											else{$percIdent=$pair_aln->overall_percentage_identity("short");}											
											my $s=$seq->seq();
											$s=~s/[-.]//g;					
											if (($bestName eq "") || $percIdent>$bestIdent){
												$bestIdent=$percIdent;
												$bestName=$seq->display_id;
												$bestLength=length($s);
											}
											if (($longestName eq "") || length($s)>$longestLength){
												$longestLength=length($s);
												$longestName=$seq->display_id;	
												$longestIdent=$percIdent;									
											}
										}
									}
									if ($longestIdent==$bestIdent){$bestName=$longestName}#in case that multiple transcripts have same identity, longest transcript will be chosen 
									if ($bestName ne ""){push(@seqNames_all,$bestName)}
									if ($bestName ne $longestName){
										my $speciesOfInterestSeqName:shared=$species_of_interest_seq->display_id;
										if (!exists($longestOrthologNotMostIdentical{$species_of_interest})){$longestOrthologNotMostIdentical{$species_of_interest}=share(my @x)}
										my @x:shared=($geneName,$species_of_interest,$speciesOfInterestSeqName,$speciesName,$longestName,$longestLength,$longestIdent,$bestName,$bestLength,$bestIdent,$bestIdent-$longestIdent);
										push (@{$longestOrthologNotMostIdentical{$species_of_interest}},\@x);
									}
									for (my $i=0; $i<100; $i=$i+5){
										if (!exists($minPercIdenityStatisticsAlignments{$species_of_interest})){$minPercIdenityStatisticsAlignments{$species_of_interest}=share(my %x)}
										if (!exists($minPercIdenityStatisticsAlignments{$species_of_interest}{$speciesName})){$minPercIdenityStatisticsAlignments{$species_of_interest}{$speciesName}=share(my %x)}
										if (!exists($minPercIdenityStatisticsAlignments{$species_of_interest}{$speciesName}{$i})){$minPercIdenityStatisticsAlignments{$species_of_interest}{$speciesName}{$i}=0;}
											if($bestIdent>=$i){
												$minPercIdenityStatisticsAlignments{$species_of_interest}{$speciesName}{$i}++;
												$isSpeciesRepresentedinAnSubAlignment2{$speciesName}{$i}="";
											}									
									}
									if (($bestName ne "") && ($bestIdent>=$minPercIdentityDemanded)){ 
										push (@seqNames,$bestName);
										$identity_to_position_species{$bestName}=$bestIdent;
									}	
								}
								my %seqs_below_threshold;
								if (($#seqNames_all!=-1) && $aln->is_flush()){
									my $subaln=select_by_name($aln,$species_of_interest_seq->display_id,@seqNames_all);
									my $subaln_nucl=Bio::Align::Utilities::aa_to_dna_aln($subaln,\%cds);
									push (@{$subalns_nucl{$species_of_interest}},$subaln_nucl);
									remove_positions_with_gaps_in_all_seqs($subaln);
									my %species_combos_used;
									for my $seq($subaln_nucl->each_seq){
										$subaln_nucl->remove_seq($seq);
										$seq->id($species{$seq->display_id()});
										$subaln_nucl->add_seq($seq);
									}
									for my $seqA($subaln->each_seq){
										for my $seqB($subaln->each_seq){
											my $speciesA=$species{$seqA->display_id};
											my $speciesB=$species{$seqB->display_id};
											if (($speciesA ne "") && ($speciesB ne "") && ($speciesA ne $speciesB)){
												my @sorted_species=sort ($speciesA,$speciesB);
												my $sorted_species_string=$sorted_species[0]."-".$sorted_species[1];
												if (!exists($species_combos_used{$sorted_species_string})){
													$species_combos_used{$sorted_species_string}="";
													if (!exists($speciesToSpeciesIdentSums{$species_of_interest})){$speciesToSpeciesIdentSums{$species_of_interest}=share(my %x);$speciesToSpeciesIdentSums_nucl{$species_of_interest}=share(my %x);}
													if (!exists($speciesToSpeciesIdentSums{$species_of_interest}{$sorted_species_string})){$speciesToSpeciesIdentSums{$species_of_interest}{$sorted_species_string}=0;$speciesToSpeciesIdentSums_nucl{$species_of_interest}{$sorted_species_string}=0;}
													my $pair_aln=select_by_name($subaln,$seqA->display_id,$seqB->display_id);
													my $nucl_pair_aln=select_by_name($subaln_nucl,$species{$seqA->display_id},$species{$seqB->display_id});
													remove_positions_with_gaps_in_all_seqs($pair_aln);
													my $percIdent2:shared=$pair_aln->percentage_identity();
													my $percIdent=$pair_aln->overall_percentage_identity("long");
													my %seqNames=map {$_ => 1} (@seqNames);
													if (($seqA->display_id ne $species_of_interest_seq->display_id) && ($seqB->display_id ne $species_of_interest_seq->display_id) && ($percIdent<$minPercIdentityDemanded_all_vs_all) && (exists($seqNames{$seqA->display_id})) && ((exists($seqNames{$seqB->display_id})))){
														push(@{$seqs_below_threshold{$seqA->display_id}},$seqB->display_id);
														push(@{$seqs_below_threshold{$seqB->display_id}},$seqA->display_id);																												
													}
													$speciesToSpeciesIdentSums{$species_of_interest}{$sorted_species_string}+=$percIdent2;
													$speciesToSpeciesIdentSums_nucl{$species_of_interest}{$sorted_species_string}+=$nucl_pair_aln->percentage_identity();
													if (!exists($speciesToSpeciesTotal{$species_of_interest})){$speciesToSpeciesTotal{$species_of_interest}=share(my %x)}
													if (!exists($speciesToSpeciesTotal{$species_of_interest}{$sorted_species_string})){$speciesToSpeciesTotal{$species_of_interest}{$sorted_species_string}=0}
													$speciesToSpeciesTotal{$species_of_interest}{$sorted_species_string}++;
												} 										
											} 
										}
									}							
								}
								if (($#seqNames!=-1) && $aln->is_flush()){
									my $subaln=select_by_name($aln,$species_of_interest_seq->display_id,@seqNames);
									eliminateBadSeqs($subaln,\%seqs_below_threshold,\%identity_to_position_species);
									remove_positions_with_gaps_in_all_seqs($subaln);
									if (int($subaln->each_seq)>=3){
										if (!exists($numberOfCoveredAlignments{$species_of_interest})){$numberOfCoveredAlignments{$species_of_interest}=share(my %x)}
										for my $seq ($subaln->each_seq){
												my $speciesName=$species{$seq->display_id};
												if (!exists($numberOfCoveredAlignments{$species_of_interest}{$speciesName})){$numberOfCoveredAlignments{$species_of_interest}{$speciesName}=0;}
												$numberOfCoveredAlignments{$species_of_interest}{$speciesName}++;
												$isSpeciesRepresentedinAnSubAlignment{$speciesName}="";										
										}
										$alignments_created++;
#										Bio::AlignIO->new(-file => ">".$geneDirPath.$species_of_interest."/".$species_of_interest_seq->display_id.".fastp.clustalw.aln.with_best_of_other_species.aln",-format => 'fasta')->write_aln($subaln);
										Bio::AlignIO->new(-file => ">".$geneDirPath.$species_of_interest."/".$species_of_interest_seq->display_id.".aln",-format => 'fasta')->write_aln($subaln);
									}									
								}								
							}			
						}

						for my $speciesName(@species){
							if (exists($isSpeciesRepresentedinAnSubAlignment{$speciesName})){
								if (!exists($numberOfCoveredSymbols{$species_of_interest})){$numberOfCoveredSymbols{$species_of_interest}=share(my %x)}
								if (!exists($numberOfCoveredSymbols{$species_of_interest}{$speciesName})){$numberOfCoveredSymbols{$species_of_interest}{$speciesName}=0;}
								$numberOfCoveredSymbols{$species_of_interest}{$speciesName}++;
							}
							for (my $i=0; $i<100; $i=$i+5){
								if (!exists($minPercIdenityStatisticsSymbols{$species_of_interest})){$minPercIdenityStatisticsSymbols{$species_of_interest}=share(my %x)}
								if (!exists($minPercIdenityStatisticsSymbols{$species_of_interest}{$speciesName})){$minPercIdenityStatisticsSymbols{$species_of_interest}{$speciesName}=share(my %x)}					
								if (!exists($minPercIdenityStatisticsSymbols{$species_of_interest}{$speciesName}{$i})){$minPercIdenityStatisticsSymbols{$species_of_interest}{$speciesName}{$i}=0;}
								if (exists($isSpeciesRepresentedinAnSubAlignment2{$speciesName}{$i})){
									$minPercIdenityStatisticsSymbols{$species_of_interest}{$speciesName}{$i}++;						
								}
							}
						}
					} catch {$errors++;	$errorString.=$_[0]."\n".$geneDirPath."fastp.clustalw.aln"."\n\n\n\n";};	
				}
			}
		}
	}
	return \%subalns_nucl;
}

sub eliminateBadSeqs{
	my ($aln,$seqs_below_threshold,$identity_to_position_species)=@_;
	my @sorted_seq_ids=sort{int(@{$seqs_below_threshold->{$b}})<=>int(@{$seqs_below_threshold->{$a}}) or $identity_to_position_species->{$a}<=>$identity_to_position_species->{$b}}(keys(%{$seqs_below_threshold}));
	for (my $i=0;(exists($seqs_below_threshold->{$sorted_seq_ids[$i]})) && (int(@{$seqs_below_threshold->{$sorted_seq_ids[$i]}})>0); $i++){
		$aln->remove_seq($aln->get_seq_by_id($sorted_seq_ids[$i]));
		for (my $j=$i+1; $j<int(@sorted_seq_ids);$j++){			
			my $index;
			for ($index=0; ($index<int(@{$seqs_below_threshold->{$sorted_seq_ids[$j]}}) && ($seqs_below_threshold->{$sorted_seq_ids[$j]}[$index] ne $sorted_seq_ids[$i])); $index++){}
			splice(@{$seqs_below_threshold->{$sorted_seq_ids[$j]}},$index,1);
		}
	}
}


sub output_concat_aln{
	my ($out_file,$alns, $speciesNum)=@_;
	my @alns_for_bigaln;
	for my $aln(@{$alns}){
		if (int($aln->each_seq)==$speciesNum){push(@alns_for_bigaln,$aln)}
	}
	#my $bigaln=Bio::Align::Utilities::cat(@alns_for_bigaln);
	#$bigaln->set_displayname_flat(1);
	#Bio::AlignIO->new(-format => "fasta",-file => ">$out_file")->write_aln($bigaln);
	
	my %string_seqs;
	for my $aln(@alns_for_bigaln){
		for my $seq($aln->each_seq){
			$string_seqs{$seq->id}.=$seq->seq;
		}
	}
	open (my $ALN_OUT, ">$out_file");
	for my $seq_id(keys(%string_seqs)){
		print($ALN_OUT ">".$seq_id."\n");
		print($ALN_OUT $string_seqs{$seq_id}."\n");
	}
	return int(@alns_for_bigaln);
}

sub contains{
	foreach my $elem (@{$_[0]}){if($elem eq $_[1]){return 1;}}
	return 0;
}

sub select_by_name(){
my $aln=$_[0];
my @seqNames=@_[1..$#_];	
my @seqNums;
for (my $i=1; $i<=int($aln->each_seq);$i++){
	foreach my $seqName (@seqNames){	
		if ($seqName eq $aln->get_seq_by_pos($i)->display_id){push(@seqNums,$i);}
	}
}
return $aln->select_noncont(@seqNums);
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