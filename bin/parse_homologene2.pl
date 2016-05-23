BEGIN{
	while (-l $0){$0=readlink($0)}
	my @path=split(/\/|\\/,$0);
	my $path=join("/",@path[0..(@path-2)])."/../modules";
	push (@INC,$path);
}

use Bio::SeqIO;
use strict;
use Try::Tiny;
use Storable;;


open (STDERR, ">/dev/null");#disable warnings, should be commented out when debugging 
no warnings;#disable warnings, should be commented out when debug

my $bin_dir=File::Basename::dirname(Cwd::abs_path($0))."/";

my ($progress,$individual_results_dir,$ortholog_assignment_dir,$homologenePath,$transcr_to_prot,$prot_to_symbol,$transcr_to_symbol,$logFile, @paths)=@ARGV;
#my ($refPath, $homologenePath,$transcr_to_prot,$prot_to_symbol,$transcr_to_symbol,@paths)=("/misc/enton/data/asahm/Reference_7/","/misc/enton/data/asahm/MRNA_public_data/homologene_106.data","transcr_to_prot.hash","prot_to_symbol.hash","transcr_to_symbol.hash",#Mensch,Maus,Ratte,Schimpanse,Rhesus Affe,Kuh,Hund
#"/misc/enton/data/asahm/MRNA_public_data/Bos_taurus_NCBI_mrna_RefSeq_16.06.2014.gbk",
#"/misc/enton/data/asahm/MRNA_public_data/Canis_lupus_familiaris_NCBI_mrna_RefSeq_16.06.2014.gbk",
##"/misc/enton/data/asahm/MRNA_public_data/Cavia_porcellus_NCBI_mrna_RefSeq_16.06.2014.gbk", NOT IN HOMOLOGENE
##"/misc/enton/data/asahm/MRNA_public_data/Cricetulus_griseus_NCBI_mrna_RefSeq_16.06.2014.gbk", NOT IN HOMOLOGENE
#"/misc/enton/data/asahm/MRNA_public_data/Homo_sapiens_NCBI_mrna_RefSeq_16.06.2014.gbk",
#"/misc/enton/data/asahm/MRNA_public_data/Mus_musculus_NCBI_mrna_RefSeq_16.06.2014.gbk",
##"/misc/enton/data/asahm/MRNA_public_data/Ochotona_princeps_NCBI_mrna_RefSeq_16.06.2014.gbk", NOT IN HOMOLOGENE
##"/misc/enton/data/asahm/MRNA_public_data/Oryctolagus_cuniculus_NCBI_mrna_RefSeq_16.06.2014.gbk", NOT IN HOMOLOGENE
#"/misc/enton/data/asahm/MRNA_public_data/Rattus_norvegicus_NCBI_mrna_RefSeq_16.06.2014.gbk",
#"/misc/enton/data/asahm/MRNA_public_data/Macaca_mulatta_NCBI_mrna_RefSeq_24.06.2014.gbk",
#"/misc/enton/data/asahm/MRNA_public_data/Pan_troglodytes_NCBI_mrna_RefSeq_24.06.2014.gbk"
#);
#my ($refPath, $homologenePath,@paths)=("/home/lakatos/asahm/workspace2/Test/ReferenceTest4/","/misc/vulpix/data/asahm/homologene.data","/home/lakatos/asahm/workspace2/Test/ReferenceTest4/test.gbk");
#my ($refPath,$homologenePath,$transcr_to_prot,$prot_to_symbol,$transcr_to_symbol,@paths)=("/home/lakatos/asahm/enton/Public_Hglaber+3Species/","/home/lakatos/asahm/workspace2/Test/homologene_106.data","transcr_to_prot","prot_to_symbol","transcr_to_symbol","/home/lakatos/asahm/enton/MRNA_public_data/Homo_sapiens_NCBI_mrna_RefSeq_16.06.2014.gbk","/home/lakatos/asahm/enton/MRNA_public_data/Mus_musculus_NCBI_mrna_RefSeq_16.06.2014.gbk","/home/lakatos/asahm/enton/MRNA_public_data/Rattus_norvegicus_NCBI_mrna_RefSeq_16.06.2014.gbk");
#my ($refPath,$homologenePath,$transcr_to_prot,$prot_to_symbol,$transcr_to_symbol,@paths)=("/home/lakatos/asahm/enton/Public_Hglaber+3Species_test/","/home/lakatos/asahm/workspace2/Test/homologene_106.data","transcr_to_prot","prot_to_symbol","transcr_to_symbol","/home/lakatos/asahm/enton/MRNA_public_data/Homo_sapiens_NCBI_mrna_RefSeq_16.06.2014_test.gbk");
##if (!(-e $refPath && -d $refPath)) {File::Path->make_path($refPath)};


my @speciescodeSymbolSelectionOrder=(9606,10090,10116,9544,9598,9913,9615);

my %proteinIdToGroup;

my %groupToSpeciesToGeneName;#DataType: Hash: GroupNumber->(Hash: SpeciesCode->GeneName)
my %groupToSelectedSymbol;
my %selectedSymbolToGroup;

my %intraSpeciesGeneNameToSelectedSymbol;#Datatype: Hash:Species->(Hash:GeneName->Protein_Name_in_Homologene)
my $errors=0;
my %nameConflicts;
my $errString="";
my %count;
my $count=0;
my %transcripts_notInHomologene=0;
my %genes_notInHomologene=0;#Datatype: Hash:Species->(Hash:GeneName->Empty_String)
my $noReference=0;
my %geneSymbols;#Datatype: Hash:Species->(Hash:Genesymbol->EmptyString)
my %geneSymbolsTotal;
my %transcr_to_prot;
my %prot_to_symbol;
my %transcr_to_symbol;
my $makeblastdb_path=$bin_dir."makeblastdb";

print("Step 1/7, parse HomoloGene...\n");
open(HOMOLOGY, $homologenePath);
my @additional_homologene_species;
while(<HOMOLOGY>){
	my @zeile=split("\t",$_);
	$groupToSpeciesToGeneName{$zeile[0]}{$zeile[1]}=uc($zeile[3]);
	$proteinIdToGroup{(split(/[.]/,$zeile[5]))[0]}=$zeile[0];
	if ((!contains(\@speciescodeSymbolSelectionOrder,$zeile[1])) && (!contains(\@additional_homologene_species,$zeile[1]))){push(@additional_homologene_species,$zeile[1]);}	
}
sort{$a <=> $b} @additional_homologene_species;
push(@speciescodeSymbolSelectionOrder,@additional_homologene_species);

close (HOMOLOGY);

for my $group(keys(%groupToSpeciesToGeneName)){	
	for my $speciesCode(@speciescodeSymbolSelectionOrder){
		if (my $geneName=$groupToSpeciesToGeneName{$group}{$speciesCode}){
			if (my $g_first=$selectedSymbolToGroup{$geneName}){
				if (!exists($nameConflicts{$geneName})){$nameConflicts{$geneName}=$g_first}
				$nameConflicts{$geneName}.=",".$group;
				my @n=split(",",$nameConflicts{$geneName});
				$groupToSelectedSymbol{$group}=$geneName."_".@n;
				$selectedSymbolToGroup{$geneName."_".@n}=$group
			}
			else{
				$groupToSelectedSymbol{$group}=$geneName;			
				$selectedSymbolToGroup{$geneName}=$group;
				last;
			}
		}
	}
}

my $allGBK=Bio::SeqIO->new(-format => 'Genbank',-file => ">".$ortholog_assignment_dir."all.gbk");
my $allFasta=Bio::SeqIO->new(-format => 'Fasta',-file => ">".$ortholog_assignment_dir."all.fasta");
my $allFastp=Bio::SeqIO->new(-format => 'Fasta',-file => ">".$ortholog_assignment_dir."all.fastp");
my $allfastaCDS=Bio::SeqIO->new(-format => 'Fasta',-file => ">".$ortholog_assignment_dir."all.fasta_cds");

my $speciesFileNum=0;
for my $path(@paths){
	print("Step 1/7 (species-file ".++$speciesFileNum."/".int(@paths)."), read sequences from $path...\n");
	my @seqs;
	my $stream = Bio::SeqIO->new(-file => $path,-format => 'GenBank');
	my $i=0;
    while ( my $seq = $stream->next_seq() ) {
    	my $species=trim($seq->species()->binomial());
		$species=~s/ /_/g;
		my $geneName = uc(trim(getTag($seq,"gene","gene")));
		#print("Read ".(++$i).": $geneName from ".$path."\n");
		my $proteinName=(split(/[.]/,getTag($seq,"CDS","protein_id")))[0]; 
		if(my $protID=$proteinIdToGroup{$proteinName}){
			if (my $S=$groupToSelectedSymbol{$protID}){
				$intraSpeciesGeneNameToSelectedSymbol{$species}{$geneName}=$S;
			}else {$noReference++}
		} else{
			if (!defined($transcripts_notInHomologene{$species})){$transcripts_notInHomologene{$species}=0;}
			$transcripts_notInHomologene{$species}++;
		}
		push (@seqs,$seq);
		if (((int(@seqs)) % 500)==0){print("Step 1/7 (species-file ".$speciesFileNum."/".int(@paths)."), read ".int(@seqs)." sequences from $path\n");}		
    }		
	print("Step 1/7 (species-file ".$speciesFileNum."/".int(@paths)."), read ".int(@seqs)." sequences in total from $path\n\n");
	my $seqsProcessedNum=0;
	my $species="";
    for my $seq (@seqs) {
    	$species=trim($seq->species()->binomial());
		$species=~s/ /_/g;	   
	 	if ($seq->molecule() eq "mRNA"){
			my $geneName = uc(trim(getTag($seq,"gene","gene")));
			my $proteinName=(split(/[.]/,getTag($seq,"CDS","protein_id")))[0];
			if (my $h=$intraSpeciesGeneNameToSelectedSymbol{$species}{$geneName}){ 
				$geneName=$h;						 
				$transcr_to_prot{$seq->id}=$proteinName;
			 	$transcr_to_symbol{$seq->id}=$geneName;
			 	$prot_to_symbol{$proteinName}=$geneName; 	
				$geneSymbolsTotal{$geneName}="";
				$geneSymbols{$species}{$geneName}="";
				$geneName=~s/[\/ |\\&]/_/g;
				$geneName=~s/[()]//g;
				if (!(-e $individual_results_dir.$geneName && -d $individual_results_dir.$geneName)){
					mkdir ($individual_results_dir.$geneName);
				}

				if (!(-e $individual_results_dir.$geneName."/".$species && -d $individual_results_dir.$geneName."/".$species)){
					mkdir($individual_results_dir.$geneName."/".$species);
				}
				try{
					Bio::SeqIO->new(-format => 'Genbank',-file => ">".$individual_results_dir.$geneName."/".$species."/".trim($seq->accession_number().".gbk"))->write_seq($seq);
					$allGBK->write_seq($seq);
					Bio::SeqIO->new(-format => 'fasta',-file => ">".$individual_results_dir.$geneName."/".$species."/".trim($seq->accession_number().".fasta"))->write_seq($seq);
					$allFasta->write_seq($seq);
				 	for my $feat ($seq->get_SeqFeatures()){
						if ($feat->primary_tag eq "CDS"){
							my $spliced_seq=$feat->spliced_seq;
							my $transl=getTag($seq,"CDS","translation");
							my $translSeq=Bio::Seq->new(-id => $seq->display_id(), -seq => $transl);
							Bio::SeqIO::fasta->new(-file => ">".$individual_results_dir.$geneName."/".$species."/".trim($seq->accession_number()).".fastp")->write_seq($translSeq);
							$allFastp->write_seq($translSeq);
							Bio::SeqIO::fasta->new(-file => ">".$individual_results_dir.$geneName."/".$species."/".trim($seq->accession_number()).".fasta_cds")->write_seq($spliced_seq);
							$allfastaCDS->write_seq($spliced_seq);
						}
					}	
				}catch{$errors++;$errString.=$_."\n".$seq->accession_number()."\n\n"};
				if (!defined($count{$species})){$count{$species}=0;}
				$count{$species}++;
				$count++;
				#print ($species.":".$count{$species}."\n");
		 	} else {$genes_notInHomologene{$species}{$geneName}=""}
		}
		if (((++$seqsProcessedNum) % 500)==0){print("Step 1/7 (species-file ".$speciesFileNum."/".int(@paths)."), processed $seqsProcessedNum/".int(@seqs)." sequences from $path; added $count{$species} sequences and ".int(keys(%{$geneSymbols{$species}}))." genes\n");}		
	} 
	print("Step 1/7 (species-file ".$speciesFileNum."/".int(@paths)."), processed $seqsProcessedNum/".int(@seqs)." sequences in total from $path; added $count{$species} sequences and ".int(keys(%{$geneSymbols{$species}}))." genes in total\n\n"); 
}

Storable::store(\%transcr_to_prot,$transcr_to_prot);
Storable::store(\%prot_to_symbol,$prot_to_symbol);
Storable::store(\%transcr_to_symbol,$transcr_to_symbol);

my %pipeline_status;
open(RESULTS,">".$logFile);
for my $species(keys(%count)){
	print(RESULTS $species.":\n");
	print (RESULTS "\tNumber of transcripts which are not in HomoloGene: ".$transcripts_notInHomologene{$species}."\n");
	print (RESULTS "\tNumber of genes which are not in HomoloGene: ".keys(%{$genes_notInHomologene{$species}})."\n");
	print(RESULTS "\tFound mRNAs: ".$count{$species}."\n");
	print(RESULTS "\tFound genes: ".keys(%{$geneSymbols{$species}})."\n\n");
	$pipeline_status{"parse_homologene"}{$species}={"transcripts" => $count{$species}, "genes" => int(keys(%{$geneSymbols{$species}}))};
}
print(RESULTS "Number of transcripts in HomoloGene but without reference species: ".$noReference."\n");
print(RESULTS "Found genes total: ".keys(%geneSymbolsTotal)."\n");
print(RESULTS "Found mRNAs total: ".."\n");
print(RESULTS "Number of symbol assignment conflicts: ".keys(%nameConflicts)."\n");
print(RESULTS "Symbol assignment conflicts:\n");
for my $geneName(keys(%nameConflicts)){print(RESULTS $geneName.": ".$nameConflicts{$geneName}."\n")}
close(RESULTS);
system($makeblastdb_path." -in ".$ortholog_assignment_dir."all.fastp -dbtype prot >/dev/null");
Storable::store(\%pipeline_status,$progress);
print("Step 1/7, FINISHED\n\n");
exit(0);

sub getTag {
for my $feat ($_[0]->get_SeqFeatures()){
		if ($feat->primary_tag eq $_[1]){
			my @values = $feat->get_tag_values($_[2]);
			return $values[0];
		}
			
	}
}

sub trim($){
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

sub contains{
 	foreach my $elem (@{$_[0]}){if($elem eq $_[1]){return 1;}}
	return 0;
}

