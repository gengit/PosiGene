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
use Bio::SeqIO::genbank;
use Bio::SeqIO::fasta;
use Storable;
use Bio::SeqFeature::Generic;
use Bio::SearchIO::blasttable;
use Bio::Seq;
use File::Basename;


my $bin_dir=File::Basename::dirname(Cwd::abs_path($0))."/";
my $makeblastdb_path=$bin_dir."makeblastdb";
my $perl_path="perl";
my $BlastP_path=$bin_dir."BlastP.pl";

#open (STDERR, ">/dev/null");#disable warnings, should be commented out when debugging 
no warnings;#disable warnings, shouldgenbank (.gb, .gbk) or fasta (.fasta,.fa) format be commented out when debug

#my ($gbk_or_fa_File, $refPath,$trans_to_symbol_file, $blastResultPathNonHomologeneVsRef,$blastResultPathRefVsNonHomologene,$BLASTthreshold,$logFile,$threadNum,$reUseExistingBLASTResults)=("/home/lakatos/asahm/enton/MRNA_public_data/Cavia_porcellus_NCBI_mrna_RefSeq_16.06.2014.gbk","/home/lakatos/asahm/enton/Reference_6_2/","transcr_to_symbol.hash","Cavia_porcellus_NCBI_mrna_RefSeq_16.06.2014.gbk.translation.fa_VS_all.fastp.blast_result","all.fastp_VS_Cavia_porcellus_NCBI_mrna_RefSeq_16.06.2014.gbk.translation.fa.blast_result","1-e04","add_a_public_non_homologene_species_to_reference_Cavia_porcellus.log",50,1);
my ($gbk_or_fa_File, $progress,$individual_results_dir,$ortholog_assignment_dir, $makeReference,$reference, $trans_to_symbol_file, $BLASTthreshold,$genetic_code,$logFile,$threadNum,$reUseExistingBLASTResults,$by_blast,$speciesProgressString)=@ARGV;
#my ($gbk_or_fa_File, $refPath,$trans_to_symbol_file, $BLASTthreshold,$logFile,$threadNum,$reUseExistingBLASTResults)=("/home/lakatos/asahm/enton/MRNA_public_data/Cavia_porcellus_NCBI_mrna_RefSeq_16.06.2014.gbk","/home/lakatos/asahm/Desktop/Reference_Test3/","transcr_to_symbol.hash","1-e04","add_a_public_non_homologene_species_to_reference_Cavia_porcellus.log",50,1);

my @symbolsPerThread;#Datatype: Array(Hash: Ref_Symbol->Array:Bio::Seq(Isoform_of_that_Gene))
my $notStartWithM:shared=0;
my $earlyStops:shared=0;
my $noStop:shared=0;
my $goodSeqs:shared=0;
my $createdSeqs:shared=0;
my @symbol_not_found:shared;
my $speciesName:shared;
my $allSeqNum=0;

my %blastResultNonHomologeneVsRef;
my %blastResultRefVsNonHomologene;
my %bestBidirectionalHitSeqs;

my $input_file_path;
my $is_input_gbk;
$gbk_or_fa_File=~/.*\.(.*)$/;
my $file_ext=$1;
if ((int(split(":",$gbk_or_fa_File))>1) || (($makeReference>0) && (($file_ext eq "fasta") || ($file_ext eq "fa") || ($file_ext eq "fas")) )){
	($speciesName,$input_file_path)=split(":",$gbk_or_fa_File);
	$is_input_gbk=0;
} else{
	$input_file_path=$gbk_or_fa_File;
	$is_input_gbk=1;
}
my $protein_file=$ortholog_assignment_dir.File::Basename::basename($input_file_path).".translation";
my @help;
if ($is_input_gbk){@help=read_gbk($input_file_path,$protein_file);}
else {@help=read_fasta($input_file_path,$protein_file,$speciesName);}
my %IntraSpeciesGeneNameToAllItsIsos=%{$help[0]};
my %IsoNameToIntraSpeciesGeneName=%{$help[1]};



##Storable::store(\%IntraSpeciesGeneNameToAllItsIsos,"test1");
##Storable::store(\%IsoNameToIntraSpeciesGeneName,"test2");
	
#my %IntraSpeciesGeneNameToAllItsIsos=%{Storable::retrieve("test1")};
#my %IsoNameToIntraSpeciesGeneName=%{Storable::retrieve("test2")};;
if ($makeReference){
	Storable::store(\%IsoNameToIntraSpeciesGeneName,$trans_to_symbol_file);
	system("\"".$makeblastdb_path."\" -in \"".$protein_file."\" -dbtype prot >/dev/null");
}
if((!$by_blast) && ($makeReference!=1)){$allSeqNum=int(keys(%IsoNameToIntraSpeciesGeneName));myThread(\%IntraSpeciesGeneNameToAllItsIsos);}	
elsif($makeReference==0){
	#create BLAST Results
	print("Step 2/7 ($speciesProgressString), BLAST sequences of non-HomoloGene-species VS those of all used HomoloGene-species...\n");
	if (!( ($reUseExistingBLASTResults) && (-e $protein_file.".pin") && (-e $protein_file.".phr") && (-e $protein_file.".psq"))) {system("\"".$makeblastdb_path."\" -in \"".$protein_file."\" -dbtype prot >/dev/null");}
	my $blastResultPathNonHomologeneVsRef=$protein_file."_VS_".File::Basename::basename($reference);
	if (!((-e $blastResultPathNonHomologeneVsRef) && ($reUseExistingBLASTResults))){
		system("\"$perl_path\" \"$BlastP_path\" \"$protein_file\" \"$reference\" "."\"$blastResultPathNonHomologeneVsRef\" $threadNum \"Step 2/7  ($speciesProgressString, BLAST 1/2), \"");
	}
	print("Step 2/7 ($speciesProgressString), BLAST sequences of all used HomoloGene-species VS those of the non-HomoloGene-species...\n");
	my $blastResultPathRefVsNonHomologene="$reference\_VS_".File::Basename::basename($protein_file);
	if (!((-e $blastResultPathRefVsNonHomologene) && ($reUseExistingBLASTResults))){
		system("\"$perl_path\" \"$BlastP_path\" \"$reference\" "."\"$protein_file\" \"$blastResultPathRefVsNonHomologene\" $threadNum \"Step 2/7  ($speciesProgressString, BLAST 2/2), \"");
	}
			
		
	#read BLAST Results
	print("Step 2/7 ($speciesProgressString), read BLAST Results...\n");
	%blastResultNonHomologeneVsRef=%{filterBLASTResult($blastResultPathNonHomologeneVsRef)};
	%blastResultRefVsNonHomologene=%{filterBLASTResult($blastResultPathRefVsNonHomologene)};
		
	##Storable::store(\%blastResultNonHomologeneVsRef,"test3");
	##Storable::store(\%blastResultRefVsNonHomologene,"test4");
		
	##my %blastResultNonHomologeneVsRef=%{Storable::retrieve("test3")};
	##my %blastResultRefVsNonHomologene=%{Storable::retrieve("test4")};
		
	#parse $transcr_to_symbol
	print("Step 2/7 ($speciesProgressString), retrieve assignment of HomoloGene sequences to gene symbols...\n");
	my %transcr_to_symbol=%{Storable::retrieve($trans_to_symbol_file)};
	my %symbol_to_transcr;#Datatype: Hash: GeneSymbol->Array:Bio::Seq(Isoform_of_that_Gene)
	while (my ($transcript,$symbol)=each(%transcr_to_symbol)){
		#print("$transcript->$symbol\n");
		push(@{$symbol_to_transcr{$symbol}},$transcript);
	}
		
	##Storable::store(\%symbol_to_transcr,"test5");
	##my %symbol_to_transcr=%{Storable::retrieve("test5")};
		
	#find best Hit of Isos of each Gene in NonHomologeneVsRef
	print("Step 2/7 ($speciesProgressString), find best hit of all splice-variants per non-HomoloGene-gene in used HomoloGene-species-sequences...\n");
	my %bestHits_NonHomologeneVsRef;
	for my $IntraSpeciesGeneName(keys(%IntraSpeciesGeneNameToAllItsIsos)){
		my $bestHit=0;
		for my $iso(@{$IntraSpeciesGeneNameToAllItsIsos{$IntraSpeciesGeneName}}){
			if (my $hit= $blastResultNonHomologeneVsRef{$iso->display_id}){
				if (($bestHit==0) || ($hit->significance<$bestHit)){
					$bestHit=$hit;
				}
			}
		}
		if ($bestHit){
			$bestHits_NonHomologeneVsRef{$IntraSpeciesGeneName}=$bestHit->name();
		}
	}
		
	##Storable::store(\%bestHits_NonHomologeneVsRef,"test6");
	##my %bestHits_NonHomologeneVsRef=%{Storable::retrieve("test6")};
		
		
	#find best Hit of ortholog seqs and isos of those seqs in each GeneSymbol in Ref
	print("Step 2/7 ($speciesProgressString), find best hit of all splice-variants per HomoloGene-gene in Non-HomoloGene-sequences...\n");	
	my %bestHits_RefVsNonHomologene;
	for my $symbol(keys(%symbol_to_transcr)){
		my $bestHit=0;
		for my $transcriptName(@{$symbol_to_transcr{$symbol}}){
			if (my $hit= $blastResultRefVsNonHomologene{$transcriptName}){
				if (($bestHit==0) || ($hit->significance<$bestHit)){
					$bestHit=$hit;
				}
			}
		}	
		if ($bestHit){
			$bestHits_RefVsNonHomologene{$symbol}=$bestHit->name();
		}
	}
		
	##Storable::store(\%bestHits_RefVsNonHomologene,"test7");
	##my %bestHits_RefVsNonHomologene=%{Storable::retrieve("test7")};
			
	#get best bidirectionalHit Sequences
	print("Step 2/7 ($speciesProgressString), get best-bidirectional-hit-sequences...\n");
	%bestBidirectionalHitSeqs;##Datatype: Hash: Ref_Symbol->Array:Bio::Seq(Isoform_of_that_Gene)
	for my $IntraSpeciesGeneName(keys(%bestHits_NonHomologeneVsRef)){
		my $symbol=$transcr_to_symbol{$bestHits_NonHomologeneVsRef{$IntraSpeciesGeneName}};
		#print($symbol."\n");
		if ($IntraSpeciesGeneName eq $IsoNameToIntraSpeciesGeneName{$bestHits_RefVsNonHomologene{$symbol}} ){
			$bestBidirectionalHitSeqs{$symbol}=$IntraSpeciesGeneNameToAllItsIsos{$IntraSpeciesGeneName};
			$allSeqNum+=int(@{$IntraSpeciesGeneNameToAllItsIsos{$IntraSpeciesGeneName}});
		}
	}
		
	##Storable::store(\%bestBidirectionalHitSeqs,"test8");
	##my %bestBidirectionalHitSeqs=%{Storable::retrieve("test8")};
		
		
	myThread(\%bestBidirectionalHitSeqs);
	##threads are not used anmyore because speed up is minimal, because method only writes to the file system. This output is restricted by other things than number of cpus. But memory consumption is big, when the data structure with the seqs is copied for all threads. 	
	##my @symbols=keys(%bestBidirectionalHitSeqs);
	##for (my $i=0; $i<@symbols;$i++){
	##	$symbolsPerThread[$i % $threadNum]{$symbols[$i]}=$bestBidirectionalHitSeqs{$symbols[$i]};
	##}
	##my @threads;
	##for (my $i=0; $i<@symbolsPerThread; $i++){	
	##	#myThread($symbolsPerThread[$i]);
	##	push(@threads, threads->create(\&myThread,$symbolsPerThread[$i]));
	##	#sleep(0.1);
	##	print ("Started ".($i+1)." Threads...\n");		
	##}
	##print ("FINISHED starting Threads...\n");
	##my $x=0;
	##for my $thread(@threads){
	##$thread->join();	
	##print ("Waited for ".++$x." Threads...\n");
	##}
}
if ($makeReference!=1){
	my $method_string;
	if ($by_blast==0){$method_string="By Symbol"}
	elsif ($by_blast==1){$method_string="By BLAST (HomoloGene)"}
	elsif ($by_blast==2){$method_string="By BLAST (".File::Basename::basename($protein_file).")"}
	open(OUT, ">".$logFile);
	print(OUT "Method to assign ortholog-groups: $method_string\n");
	if ($by_blast) {print(OUT "Best bidrectional found gene symbols: ".keys(%bestBidirectionalHitSeqs)."\n");}
	print(OUT "Created seqs in these gene symbols: ".$createdSeqs."\n");
	if ($by_blast) {print(OUT "Number of significant seq hits (isoform level) from non homologene to reference: ".keys(%blastResultNonHomologeneVsRef)."\n");}
	if ($by_blast) {print(OUT "Number of significant seq hits (isoform level) from reference to query: ".keys(%blastResultRefVsNonHomologene)."\n");}
	print(OUT "Seqs with translation does not start with ATG(M): ".$notStartWithM."\n");
	print(OUT "Seqs with translation have no stop-codon: ".$noStop."\n");
	print(OUT "Seqs with translation with to early stop-codon: ".$earlyStops."\n");
	print(OUT "Seqs with non of the three previous named mistakes: ".$goodSeqs."\n");
	print(OUT "Seqs which could not be assigned because they lacked a symbol: ".join(",",@symbol_not_found)."\n");
	close(OUT);
	my $pipeline_status;
	try{$pipeline_status=Storable::retrieve($progress);}catch{};
	$pipeline_status->{"add_a_public_non_homologene_species"}{$speciesName}={"transcripts" => $createdSeqs,"genes"=> $by_blast?int(keys(%bestBidirectionalHitSeqs)):int(keys(%IntraSpeciesGeneNameToAllItsIsos)),"method"=>$method_string};
	Storable::store($pipeline_status,$progress);
}
print("Step 2/7 ($speciesProgressString), FINISHED\n\n");
exit(0);


sub myThread{
	my %bestBidirectionalHitSeqs=%{$_[0]};
	my $i=0;
	for my $symbol(keys(%bestBidirectionalHitSeqs)){
		++$i;
		for my $seq (@{$bestBidirectionalHitSeqs{$symbol}}) {
			if ($symbol eq ""){push(@symbol_not_found,$seq->display_id());}
			else{
				#print("Seq ".++$createdSeqs.": ".$symbol." ".$seq->id()."\n");
				my $CDS="";
				my $translation="";
				for my $feat ($seq->get_SeqFeatures()){
					if ($feat->primary_tag eq "CDS"){
						$CDS=$feat->spliced_seq();
						if ($feat->has_tag("translation")){$translation=($feat->get_tag_values("translation"))[0];}
					}
				}
				if ($is_input_gbk) {$speciesName=trim($seq->species()->binomial());}
				$symbol=~s/[\/ |\\&]/_/g;
				$symbol=~s/[()]//g;
				if (!(-e $individual_results_dir.$symbol."/" && -d $individual_results_dir.$symbol."/")){
					mkdir ($individual_results_dir.$symbol."/");
				}				
				$speciesName=~s/ /_/g;
				my $speciesPath=$individual_results_dir.$symbol."/".$speciesName."/";
				if (!(-e $speciesPath && -d $speciesPath)){
					mkdir ($speciesPath);
				}
				##print("Translation: ".$translation."\n");
				$translation=Bio::Seq->new(-id => $seq->id(), -seq => $translation);
				$CDS=Bio::Seq->new(-id => $seq->id(), -seq => $CDS->seq());
				##print("CDS: ".$CDS->seq()."\n");
				##print("Complete: ".$seq->seq()."\n");
				#print("Path: ".$speciesPath.$seq->id()."\n\n");
				Bio::SeqIO::fasta->new(-file => ">".$speciesPath.$seq->id().".fasta")->write_seq($seq);
				Bio::SeqIO::fasta->new(-file => ">".$speciesPath.$seq->id().".fasta_cds")->write_seq($CDS);
				Bio::SeqIO::fasta->new(-file => ">".$speciesPath.$seq->id().".fastp")->write_seq($translation);
				Bio::SeqIO::genbank->new(-file => ">".$speciesPath.$seq->id().".gbk")->write_seq($seq);
				if (((++$createdSeqs) % 500)==0){print("Step 2/7 ($speciesProgressString), added $createdSeqs/$allSeqNum sequences ($i/".int(keys(%bestBidirectionalHitSeqs))." genes)\n");}
				my $b=1;
				if (index($translation->seq, "M")!=0) {$notStartWithM++; $b=0;};
				if (index($translation->seq, "*")==-1) {$noStop++; $b=0;}
				elsif (index($translation->seq,"*")<length($translation->seq)-1) {$earlyStops++;$b=0};
				$goodSeqs+=$b;		
			}
		}
	}
	print("Step 2/7 ($speciesProgressString), added $createdSeqs/$allSeqNum sequences ($i/".int(keys(%bestBidirectionalHitSeqs))." genes) in total\n");
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

sub filterBLASTResult{
	my $blastTablePath=$_[0];
	my %result;
	my $blastTable=Bio::SearchIO::blasttable->new(-file => $blastTablePath, -best => 1);
	while (my $result=$blastTable->next_result()){
		while( my $hit = $result->next_hit ) {
			if ( $hit->significance()<=$BLASTthreshold){
				$result{$result->query_name()}=$hit;
			}					
		}
	}
	return \%result;
}


sub read_gbk{
my ($path,$outpath)=@_;
	my $stream = Bio::SeqIO::genbank->new(-file => $path);
	my $translationsOut=Bio::SeqIO::fasta->new(-file => ">$outpath");
	my $i=0;
	my %IntraSpeciesGeneNameToAllItsIsos;#Datatype: Hash: GeneName->Array:Bio::Seq(Isoform_of_that_Gene)
	my %IsoNameToIntraSpeciesGeneName;
	print("Step 2/7 ($speciesProgressString), read sequences from $path...\n");
	while ( my $seq = $stream->next_seq() ) {		
		my $geneName = uc(trim(getTag($seq,"gene","gene")));		
		if (!defined($geneName) || ($geneName eq "")){$geneName = uc(trim(getTag($seq,"mRNA","gene")));}
		
		if (((++$i) % 500)==0){print("Step 2/7 ($speciesProgressString), read ".$i." sequences from $path\n");}			
		#print("Read ".(++$i).": $geneName from ".$path."\n");
		push(@{$IntraSpeciesGeneNameToAllItsIsos{$geneName}},$seq);
		$IsoNameToIntraSpeciesGeneName{$seq->id()}=$geneName;
		my $translation_seq=getTag($seq,"CDS","translation");
		if (defined($translation_seq)){
			my $translation=Bio::Seq->new(-id => $seq->display_id(), -seq => $translation_seq);
			$translationsOut->write_seq($translation);			
		}	
	}
	print("Step 2/7 ($speciesProgressString), read ".$i." sequences in total from $path\n");
	return (\%IntraSpeciesGeneNameToAllItsIsos,\%IsoNameToIntraSpeciesGeneName);
}	

sub read_fasta{
my ($path,$outpath,$speciesName)=@_;
	my $stream = Bio::SeqIO::fasta->new(-file => $path);
	my $translationsOut=Bio::SeqIO::fasta->new(-file => ">$outpath");
	my $i=0;
	my %IntraSpeciesGeneNameToAllItsIsos;#Datatype: Hash: GeneName->Array:Bio::Seq(Isoform_of_that_Gene)
	my %IsoNameToIntraSpeciesGeneName;
	print("Step 2/7 ($speciesProgressString), read sequences from $path...\n");
	while ( my $seq = $stream->next_seq() ) {		
		if (((++$i) % 500)==0){print("Step 2/7 ($speciesProgressString), read ".$i." sequences from $path\n");}	
		#print("Read ".(++$i).": ".$seq->id()." from ".$path."\n");
		
		my $geneName=$seq->id;
		my @h=split("[|]",$seq->id);
		if (int(@h)>1){
			$h[0]=~s/ //g;
			$h[1]=~s/ //g;
			$seq->id($h[0]);
			$geneName=$h[1];
		}
		
		my $h=$seq->seq;
		$h=~s/[^A|T|G|C|a|t|g|c|N]/n/g;
		$seq->seq($h);
		
		$seq->desc($speciesName."(".$geneName.", predicted mRNA)");
		$seq->accession_number($seq->id);
		$seq->alphabet("dna");
		my $cds=Bio::SeqFeature::Generic->new(-start => 1, -end => length($seq->seq),-primary_tag => "CDS");
		$cds->add_tag_value("gene",$geneName);
		$cds->add_tag_value("translation",$seq->translate(-codontable_id => $genetic_code)->seq);		
		my $source=Bio::SeqFeature::Generic->new(-start => 1, -end => length($seq->seq),-primary_tag => "source");
		$source->add_tag_value("organism",$speciesName);
		$source->add_tag_value("mol_type","DNA");
		my $gene=Bio::SeqFeature::Generic->new(-start => 1, -end => length($seq->seq),-primary_tag => "gene");
		$gene->add_tag_value("gene",$geneName);
		$seq->add_SeqFeature($source);
		$seq->add_SeqFeature($gene);
		$seq->add_SeqFeature($cds);
		
		push(@{$IntraSpeciesGeneNameToAllItsIsos{$geneName}},$seq);
		$IsoNameToIntraSpeciesGeneName{$seq->id()}=$geneName;
		$translationsOut->write_seq($seq->translate(-codontable_id => $genetic_code));				
	}
	print("Step 2/7 ($speciesProgressString), read ".$i." sequences in total from $path\n");
	return (\%IntraSpeciesGeneNameToAllItsIsos,\%IsoNameToIntraSpeciesGeneName);
}

sub getTag {
for my $feat ($_[0]->get_SeqFeatures()){
		if (($feat->primary_tag eq $_[1]) && ($feat->has_tag($_[2]))){
			my @values = $feat->get_tag_values($_[2]);
			return $values[0];
		}
			
	}
	return undef;
}