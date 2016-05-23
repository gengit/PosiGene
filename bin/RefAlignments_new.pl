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
use Bio::AlignIO::clustalw;
use Bio::SimpleAlign;
use Bio::SeqIO::fasta;
#BEGIN {use File::Basename; $ENV{CLUSTALDIR} = File::Basename::dirname(Cwd::abs_path($0))."/" }
#use Bio::Tools::Run::Alignment::Clustalw;
use Bio::Seq;
use Bio::TreeIO;
use Storable;

#my $refPath="/misc/vulpix/data/asahm/Reference/";
#my $refPath="/misc/vulpix/data/asahm/positive_selection_kim_et_al_nature_test/";
#my $refPath="/home/lakatos/asahm/workspace2/Test/";
#my $refPath="/misc/vulpix/data/asahm/thyroid_positive_selection/";
#my $refPath="/misc/enton/data/asahm/Reference/";
#my $refPath="/misc/enton/data/asahm/Reference4/";
#my $refPath="/home/lakatos/asahm/workspace2/Test/Reference_Test3/";
#my $refPath="/home/lakatos/asahm/enton/misc_analysis/thyroid/KaKs/";
#my $refPath="/misc/enton/data/asahm/Reference_7_3/";
#my $refPath="/home/lakatos/asahm/Desktop/test/";

#open (STDERR, ">/dev/null");#disable warnings, should be commented out when debugging
no warnings;#disable warnings, should be commented out when debug
 
my ($progress,$individual_results_dir,$threadNum,$logFile)=@ARGV;
#my ($refPath,$threadNum)=("/misc/enton/data/asahm/Reference_7_3/",64);
#my ($refPath,$threadNum)=("/misc/enton/data/asahm/Reference_7_2/",70);
#my ($refPath,$threadNum,$logFile)=("/home/lakatos/asahm/Desktop/2_fish_test/",4,"RefAlignments.log");

my $clustalw=File::Basename::dirname(Cwd::abs_path($0))."/clustalw2";
#my @clustalw_params = ("gapext" => 0.10, "gapopen" => 10.0, "type" => "PROTEIN","matrix" => "Gonnet","quite" => 1, "verbose" => 0);
my $clustalw_params = ("-align -gapext=0.10 -gapopen=10.0 -type=PROTEIN -matrix=Gonnet -quiet");

#my %clustalw_params_nucl = ("gapext" => "2.0");


my $genes:shared=0;
my $errors:shared=0;
my $seqs:shared=0;
my $aligns:shared=0;
my $errorString:shared="";

my @threads;
print("Step 3/7, reading directory content...\n");
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
	print ("Step 3/7, created ".($i+1)."/".$threadNum." threads\n");		
}
#print ("FINISHED starting Threads...\n");
my $x=0;
for my $thread(@threads){
$thread->join();	
print ("Step 3/7, ".++$x."/".$threadNum." threads returned\n");
}
open (LOGFILE, ">".$logFile);
print(LOGFILE "Genes total: ".$genes."\n"."Seqs total: ".$seqs."\n"."Aligns total (2x this number for nucl and prot alignments): ".$aligns."\n"."Errors total: ".$errors."\n\n\n"); 
print(LOGFILE $errorString);
close (LOGFILE);
my $pipeline_status;
try{$pipeline_status=Storable::retrieve($progress);}catch{};
$pipeline_status->{"RefAlignments_new"}=$aligns;
Storable::store($pipeline_status,$progress);
print ("Step 3/7, FINISHED\n\n");
exit(0);

sub myThread{
for my $geneName(@_)  {
	my $geneDirPath=$individual_results_dir.$geneName."/";
	if (-d $geneDirPath && ($geneName ne ".") &&($geneName ne "..")){
		print ("Step 3/7, processing gene ".++$genes."/".int(@refdir).": ".$geneName."...\n");
		my @cds;
		my @nucl;
		my %species;
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
						if ($x[$#x] eq "fastp"){
							try{
								my $stream=Bio::SeqIO::fasta->new(-file => $dir.$f);
								my $seq=$stream->next_seq();
								push (@cds,$seq);								
								$species{$speciesName}=0;
							}catch{$errors++;$errorString.=$dir.$f.":\n".$_."\n\n";};							
						}
						if ($x[$#x] eq "fasta_cds"){
							try{
								my $stream=Bio::SeqIO::fasta->new(-file => $dir.$f);
								my $seq=$stream->next_seq();
								push (@nucl,$seq);								
								$species{$speciesName}=0;
							}catch{$errors++;$errorString.=$dir.$f.":\n".$_."\n\n";};							
						}
					}					
				}
			}		
		}
		try{
			if ((scalar(@cds)>1) && (scalar(@cds)<500)){
				#my $clustalw=Bio::Tools::Run::Alignment::Clustalw->new(@clustalw_params);
				#my $aln=$clustalw->align(\@cds);				
				#Bio::AlignIO::clustalw->new(-file => ">".$geneDirPath."fastp.clustalw.aln")->write_aln($aln);
				my $seqPath="$geneDirPath"."fastp";
				my $seqFile=Bio::SeqIO::fasta->new(-file => ">".$seqPath);
				for my $seq(@cds){$seqFile->write_seq($seq)}
				system("$clustalw -infile=$seqPath $clustalw_params -outfile=$geneDirPath"."fastp.clustalw.aln >/dev/null ");
				#$clustalw=Bio::Tools::Run::Alignment::Clustalw->new(%clustalw_params_nucl);
				#my $aln=$clustalw->align(\@nucl);
				#my $fasta_spliced_out=Bio::SeqIO::fasta->new(-file => ">".$geneDirPath."fasta_spliced.all");
				#for my $nucl(@nucl){$fasta_spliced_out->write_seq($nucl);}
				#Bio::AlignIO::clustalw->new(-file => ">".$geneDirPath."clustalw.aln")->write_aln($aln);
				#$seqs+=scalar(@cds);
				$aligns++;				
			}
		}catch{$errors++; $errorString.="Alignment ".$geneName.":\n".$_."\n\n";print("Error $geneName: $_\n\n")}
		
	}
}
}




sub contains{
	foreach my $elem (@{$_[0]}){if($elem eq $_[1]){return 1;}}
	return 0;
}

sub getTag {
for my $feat ($_[0]->get_SeqFeatures()){
		if ($feat->primary_tag eq $_[1]){
			my @values = $feat->get_tag_values($_[2]);
			return $values[0];
		}
			
	}
}
