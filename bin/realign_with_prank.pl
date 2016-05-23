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
use Bio::SeqIO::fasta;
use Cwd;
use File::Basename;
use Bio::TreeIO::newick;
use File::Path;
use Storable;

open (STDERR, ">/dev/null");#disable warnings, should be commented out when debugging 
#no warnings;#disable warnings, should be commented out when debug

my $bin_dir=File::Basename::dirname(Cwd::abs_path($0))."/";
my $prankPath=$bin_dir."prank";
my $number_amino_acids_for_shorter_prank_runtime=8000;
my ($progress,$individual_results_dir,$position_species,$treePath, $logFile,$threadNum)=@ARGV;
#my ($refPath,$position_species_string,$treePath,$logFile,$threadNum)=("/home/lakatos/asahm/Desktop/Test_positive_selection2/","Pantholops_hodgsonii","realign_with_prank.log",40);

#my ($refPath,$position_species_string,$logFile,$threadNum)=("/home/lakatos/asahm/Desktop/Reference_Test/","Fukomys anselli","realign_with_prank.log",10);
#my ($refPath,$position_species_string,$logFile,$threadNum)=("/home/lakatos/asahm/enton/Reference_7_3/","Fukomys anselli,Heterocephalus glaber","realign_with_prank.log",32);
#my ($refPath,$position_species_string,$logFile,$threadNum)=("/home/lakatos/asahm/Desktop/Reference_Test2/","Fukomys anselli,Heterocephalus glaber","realign_with_prank.log",30);
#my ($refPath,$position_species_string,$logFile,$threadNum)=("/home/lakatos/asahm/enton/Reference_7_2/","Homo sapiens","realign_with_prank.log",64);
#my ($refPath,$position_species_string,$treePath,$logFile,$threadNum)=("/home/lakatos/asahm/enton/Tibetan_Antelope+9_species_minIdent=80/","Pantholops_hodgsonii","/home/lakatos/asahm/enton/Tibetan_Antelope+9_species_minIdent=80/my_tree.newick","realign_with_prank.log",64);
#my ($refPath,$position_species_string,$treePath,$logFile,$threadNum)=("/home/lakatos/asahm/enton/Tibetan_Antelope+9_species_minIdent=80_small/","Pantholops_hodgsonii","/home/lakatos/asahm/enton/Tibetan_Antelope+9_species_minIdent=80_small/my_tree.newick","realign_with_prank.log",64);
#my ($refPath,$position_species_string,$treePath,$logFile,$threadNum)=("/home/lakatos/asahm/enton/Public_Hglaber+3Species_minIdent=80/","Heterocephalus_glaber","/home/lakatos/asahm/enton/Public_Hglaber+3Species_minIdent=80/my_tree.newick","realign_with_prank.log",64);

$position_species=~s/ /_/g;

my $genes:shared=0;
my $errors:shared=0;
my $errorString:shared="";
my @short_runtime_alns:shared;
my $alns_processed:shared=0;
my $alns_created:shared=0;
my @alns_not_created:shared;

my @threads;
my $queue=Thread::Queue->new();
for (my $i=0; $i<$threadNum; $i++){
	push (@threads,threads->create(\&prank_thread));	
	print ("Step 6/7, created ".($i+1)." threads\n");
}

#print ("Step 6/7, FINISHED starting threads...\n");

print("Step 6/7, reading directory content...\n");

opendir(REFDIR, $individual_results_dir);
my @refdir2 = readdir(REFDIR);
closedir(REFDIR);
my @refdir;
for my $e(@refdir2){
	if(-d $individual_results_dir.$e && !(($e eq ".") || ($e eq "..")) ){
		push(@refdir,$e);
	}
}


for my $geneName(@refdir)  {
	my $geneDirPath=$individual_results_dir.$geneName."/";
	if (-d $geneDirPath && ($geneName ne ".") &&($geneName ne "..")){
		print ("Step 6/7, processing gene ".++$genes."/".int(@refdir).": ".$geneName."...\n");		
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
						while($queue->pending()){sleep(5);print("Step 6/7, all $threadNum threads are busy...\n")}
						$queue->enqueue([$position_species_path,$f,\%cds,\%species,@x]);
						#prank_thread($position_species_path,$f,\%cds,\%species,@x);	
					}
				}		
			}
		}		
	}
}


$queue->end();
for (my $i=0; $i<@threads; $i++){
	$threads[$i]->join();		
	print ("Step 6/7, ".($i+1)."/".$threadNum." threads returned\n");	
}

open (LOGFILE, ">".$logFile); 
print(LOGFILE "Errors: $errors\n");
print(LOGFILE "Genes: $genes\n");
print(LOGFILE "Alignments processed: $alns_processed\n");
print(LOGFILE "Alignments created: $alns_created\n");
print(LOGFILE "Alignments which could not be created:\n\n");
for my $aln_not_created(@alns_not_created){print(LOGFILE "$aln_not_created\n")}
print(LOGFILE "Alignments which were processed with lesser number of iterations:\n\n");
for my $short_runtime_aln(@short_runtime_alns){print(LOGFILE "$short_runtime_aln\n")}
print(LOGFILE "Errors:\n\n");
print(LOGFILE $errorString."\n");
close (LOGFILE);
my $pipeline_status;
try{$pipeline_status=Storable::retrieve($progress);}catch{};
$pipeline_status->{"realign_with_prank"}{$position_species}={"genes" => $genes,"alignments"=>$alns_created};
Storable::store($pipeline_status,$progress);
print ("Step 6/7, FINISHED\n\n");
exit(0);


sub prank_thread{
	while (defined(my $args=$queue->dequeue())){
		my ($position_species_path,$f,$cds,$species,@x)=@{$args};
		##my ($position_species_path,$f,$cds,$species,@x)=@_;
		try{
			$alns_processed++;
			#print("Processing alignment ".$alns_processed.": $position_species_path$f...\n");		
			my $codeMLDir=($f=~/.fastp.clustalw"/)?$position_species_path.(split(".fastp.clustalw",$f))[0]."_codeml/":$position_species_path.(split(".aln",$f))[0]."_codeml/";
			if (-e $codeMLDir){thread_safe_rmtree($codeMLDir)}
			mkdir($codeMLDir);
			my $aln=Bio::AlignIO::fasta->new (-file => $position_species_path.$f)->next_aln();																	
			my $aln_length=getLongestSeqLength($aln);
			my $is_prank_short_run_time="";
			if ($aln_length>$number_amino_acids_for_shorter_prank_runtime){
				$is_prank_short_run_time=" -iterate=1";
				push(@short_runtime_alns,$position_species_path.$f);
			}
			#my $aln2=Bio::Align::Utilities::aa_to_dna_aln($aln,$cds);
			#$aln2->set_displayname_flat(1);
			my $prankDir=$codeMLDir."prank/";
			mkdir($prankDir);
			#my $subAlignmentPath=$prankDir.$f."_codon.fasta";
			#Bio::AlignIO::fasta->new (-file => ">".$subAlignmentPath)->write_aln($aln2);													
			#clear_alignment_of_gaps($subAlignmentPath,$subAlignmentPath.".gaps_removed");
			my $prank_input=$prankDir."prank_input.fasta";
			my $prank_input_fh=Bio::SeqIO::fasta->new(-file => ">$prank_input");
			$aln->set_displayname_flat(1);
			for my $seq($aln->each_seq){
				if(exists($cds->{$seq->id})){
					my $seq_string=$cds->{$seq->id}->seq;
					$seq_string=substr($seq_string,0,length($seq_string)-(length($seq_string)%3));
					$prank_input_fh->write_seq(Bio::Seq->new(-id=> $seq->id, -seq => $seq_string));
				}
			}
			
#			clear_alignment_of_gaps($subAlignmentPath,$prank_input);
##if (!(-e $subAlignmentPath.".prank.best.fas")){
			if ($treePath ne ""){
				my $tree_used=$prankDir."tree.newick";	
#				processTree($treePath,$tree_used,$species,$aln2);
				processTree($treePath,$tree_used,$species,$aln);	
#				system($prankPath." -d=\"".$subAlignmentPath.".gaps_removed\""." -o=\"".$subAlignmentPath.".prank\" -showall -codon -f=fasta -quiet".$is_prank_short_run_time." -t=$tree_used >/dev/null");	
				system($prankPath." -d=\"$prank_input\""." -o=\"$prankDir\prank\" -showall -codon -f=fasta -quiet".$is_prank_short_run_time." -t=$tree_used >/dev/null");	
#			} else {system($prankPath." -d=\"".$subAlignmentPath.".gaps_removed\""." -o=\"".$subAlignmentPath.".prank\" -showall -codon -f=fasta -quiet".$is_prank_short_run_time. " >/dev/null")}
			} else {system($prankPath." -d=\"$prank_input\""." -o=\"$prankDir\prank\" -showall -codon -f=fasta -quiet".$is_prank_short_run_time. " >/dev/null");}
##}			
#			if (-e $subAlignmentPath.".prank.best.fas"){$alns_created++}
			if (-e "$prankDir\prank.best.fas"){$alns_created++}
			else{push(@alns_not_created,$position_species_path.$f);}
		}catch{$errors++;$errorString.=$f.": ".$_."\n";}
	}
}

sub processTree{
	my ($input_tree_path,$output_tree_path, $species, $aln)=@_;
	my $tree=Bio::TreeIO::newick->new(-file => $input_tree_path)->next_tree();
	for my $node($tree->get_nodes){
		my $b=0;
		for my $seq ($aln->each_seq){
			if (exists($species->{$seq->id()})){
				my $speciesName=$species->{$seq->id()};
				if (($speciesName eq $node->id) || (($speciesName ." #1") eq $node->id) || (($speciesName ."#1") eq $node->id)) {
					$b=1;
					$node->id($seq->id());
				}
			}
		}
		if ($node->is_Leaf() && !$b){
			$tree->remove_Node($node);
			$tree->contract_linear_paths(1);
		}		
	}
	$tree->contract_linear_paths(1);
	Bio::TreeIO::newick->new(-file => ">".$output_tree_path)->write_tree($tree);
}

sub getLongestSeqLength{
	my ($aln)=@_;
	my $max=-1;
	for my $seq($aln->each_seq){
			my $s=$seq->seq();
		 	$s=~s/[-.]//g;
		 	#print($seq->id().": ".length($s)."\n");
		 	if(length($s)>$max){$max=length($s)};

	}
	return $max;
}




sub clear_alignment_of_gaps{
	my ($inPath,$outPath)=@_;
	open(my $in,$inPath);
	open(my $out,">".$outPath);
	my $i=0;
	while (my $l=<$in>){
		if (!($l=~/^>.*/)){
			$l=~s/[-.]//g;
			chomp($l);			
		}
		elsif($i>0){$l="\n".$l;}
		print($out $l);
		$i++;
	}
	close ($in);
	close($out);
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

#override Bio::AlignIO::fasta because of bug with length information in name, that occured in version 1.6.923 and made length info part of id. If the seq then is again written to disk, the length info is added a second time.  
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
