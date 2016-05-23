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
use Bio::AlignIO::fasta;
use Bio::AlignIO::phylip;
use Bio::SeqIO::fasta;
use File::Basename;
use Bio::Root::IO;
use Bio::SimpleAlign;
use Bio::TreeIO::newick;
use Cwd;
use File::Path;
use File::Copy;
use Bio::Seq;
use Bio::LocatableSeq;
use Bio::SimpleAlign;
use Try::Tiny;
use Storable;

#open (STDERR, ">/dev/null");#disable warnings, should be commented out when debugging 
no warnings;#disable warnings, should be commented out when debug

my $perl="perl";
my $bin_dir=File::Basename::dirname(Cwd::abs_path($0))."/";
my $dnapars=$bin_dir."dnapars.pl";
my $consense=$bin_dir."consense";
my $GBlocks=$bin_dir."Gblocks";
my $GBlocks_params=" -t=d -p=n";
my $Gblocks_slice_size=1000000;

my ($progress,$aln_file,$out_tree_file,$chunksize,$thread_num,$selected_species,$logFile)=@ARGV;
#my ($refPath,$aln_file,$out_tree_file,$chunksize,$thread_num,$selected_species)=("/home/lakatos/asahm/Desktop/Test_positive_selection2/","selected_species_Pantholops_hodgsonii_concat_aln.fasta","my_tree2.newick",1000,10,"");
#my ($refPath,$aln_file,$out_tree_file,$chunksize,$thread_num,$selected_species)=("/home/lakatos/asahm/enton/Tibetan_Antelope+9_species/","selected_species_Pantholops_hodgsonii_concat_aln.fasta","my_tree3.newick",3000,64,"");
#my ($refPath,$aln_file,$out_tree_file,$chunksize,$thread_num,$selected_species)=("/home/lakatos/asahm/enton/Public_Hglaber+3Species/","selected_species_Heterocephalus_glaber_concat_aln.fasta","my_tree2.newick",3000,48,"");
#my ($refPath,$aln_file,$out_tree_file,$chunksize,$thread_num,$selected_species)=("/home/lakatos/asahm/enton/7_ant_species+5_outgroups/","selected_species_Harpegnathos_saltator_concat_aln.fasta","my_tree.newick",3000,64,"");

my $out_tree_file_all=$out_tree_file.".all";
my $out_tree_file_all_h=$out_tree_file.".all.h";
my $out_tree_file_all_consensus=$out_tree_file.".all.consensus";
my $out_tree_file_all_consensus_h=$out_tree_file.".all.consensus.h";

my @threads;

my $queue=Thread::Queue->new();
#print("Step 5/7 (1/2), create prepare alignemtns threads...\n");
for (my $i=0; $i<$thread_num; $i++){
	push (@threads,threads->create(\&prepare_aln_thread));	
	print ("Step 5/7 (1/2), created ".($i+1)."/".$thread_num." prepare-alignment-threads\n");
}
#print ("FINISHED starting Prepare Alignment Threads...\n");
my $aln_gb_length;
my $aln_gb_removed_path=$aln_file."-gb-matches_removed";
{
	print("Step 5/7 (1/2), reading concatenated alignment...\n");
	my ($aln,$aln_length)=read_aln_fasta($aln_file);
	$aln_gb_length=prepare_aln($aln,$aln_length,$aln_gb_removed_path,$aln_file."-gb");
	if (($aln_length<=0) || ($aln_gb_length<=0)){print("Not enough sequence data to calculate a phylogenetic tree. You can still run mode positive_selection when you provide a tree by yourself (option -t)!\n\n");exit(1);}
	$aln=undef;
}
#print("Step 5/7 (2/2), create calculate tree threads...\n");
@threads=();
$queue=Thread::Queue->new();
for (my $i=0; $i<$thread_num; $i++){
	push (@threads,threads->create(\&calcTree_thread));	
	print ("Step 5/7 (2/2), created ".($i+1)."/".$thread_num." calculate-tree-threads\n");
}
#print ("FINISHED starting Calculate Tree Threads...\n");
my $aln_matches_removed=Bio::AlignIO::fasta->new(-file =>$aln_gb_removed_path, -verbose => -1)->next_aln();

my ($aln_safe, $ref_name)=$aln_matches_removed->set_displayname_safe();

my $aln_safe_length=$aln_safe->length();
my $aln_safe=simpleAln_to_myAln($aln_safe);



my @coords;
for (my $start=1; $start<=$aln_safe_length; $start+=$chunksize){	
	my $end=$start+$chunksize-1;
	if ($end>$aln_safe_length){$end=$aln_safe_length}
	push(@coords,[$start,$end]);		
}

my @coordsNumPerThread;
my $coordsNumPerThreadBase=int(int(@coords)/$thread_num);
for (my $i=0; $i<$thread_num;$i++){push(@coordsNumPerThread,$coordsNumPerThreadBase)};
my $left=int(@coords)-$coordsNumPerThreadBase*$thread_num;
for (my $i=0; $i<$left;$i++){++$coordsNumPerThread[$i]};

print("Step 5/7 (2/2), start jackknifing...\n");
my $lastcoord=-1;
my $i=0;
for my $coordNumPerThread(@coordsNumPerThread){
	if ($coordNumPerThread>0){
		my $firstcoord+=$lastcoord+1;
		$lastcoord=$firstcoord+$coordNumPerThread-1;
		my $start=$coords[$firstcoord]->[0];
		my $end=$coords[$lastcoord]->[1];
		my ($big_slice,$big_slice_length)=slice($aln_safe,$start,$end);
		##my ($big_slice,$big_slice_length)=($aln_safe->slice($start,$end),$end-$start+1);
		while($queue->pending()){sleep(5);print("Step 5/7 (2/2), all $thread_num threads are busy...\n")}
		print("Step 5/7 (2/2), preparing alignment part ".++$i."/".@coordsNumPerThread.": $start-$end...\n");
		$queue->enqueue([$big_slice,$big_slice_length,$i]);
	}
}

$queue->end();
my $treeStrings="";
my $x=0;
for my $thread(@threads){
	$treeStrings.=$thread->join();	
	print ("Step 5/7 (2/2), ".++$x."/".int($thread_num)." calculate-tree-threads returned\n");
}
open (my $TREE_ALL_OUT, ">".$out_tree_file_all_h);
print($TREE_ALL_OUT $treeStrings);
close($TREE_ALL_OUT);

##commented out, because Bio::TreeIO::newick cannot deal with square brackets that are placed sometimes by phylip at the end of a tree to indicate its weight 
#my $all_trees=Bio::TreeIO::newick->new(-file => $out_tree_file_all_h);
#my $all_trees_out=Bio::TreeIO::newick->new(-file => ">".$out_tree_file_all);
#while (my $tree=$all_trees->next_tree()){
#	for my $nd ($tree->get_nodes()){if ($nd->is_Leaf) {$nd->id($ref_name->{$nd->id_output});}}
#	$all_trees_out->write_tree($tree);
#}


print("Step 5/7, calculating consensus tree...\n");
calcConsensusTree($out_tree_file_all_h,$out_tree_file_all_consensus,$out_tree_file_all_consensus_h,$ref_name);
print("Step 5/7, calculating distances of consensus...\n");
my ($tree,$supportTree,$trees_equal_consensus,$trees_total)=consensus_branch_lengths($out_tree_file_all_consensus_h,$out_tree_file_all_h);
##my $tree=calcTree(myAln_to_simpleAln($aln_safe),$out_tree_file_all_consensus_h);
for my $nd ($tree->get_nodes()){
	$nd->branch_length($nd->branch_length*($aln_matches_removed->length()/$aln_gb_length));
	if ($nd->is_Leaf) {$nd->id($ref_name->{$nd->id_output});}
}
#print($tree->total_branch_length()."\n");
#make_tree_unrooted($tree);
Bio::TreeIO::newick->new(-file => ">".$out_tree_file, -verbose => -1)->write_tree($tree);
open (LOGFILE, ">".$logFile);
print(LOGFILE "Jackknifing trees total: ".$trees_total."\n");
print(LOGFILE "Trees matching consensus perfectly: ".$trees_equal_consensus."\n\n");
print(LOGFILE "Support tree:\n\n");
for my $nd ($supportTree->get_nodes()){
	if ($nd->is_Leaf) {$nd->id($ref_name->{$nd->id_output});}
}
Bio::TreeIO::newick->new(-fh => \*LOGFILE)->write_tree($supportTree);
close(LOGFILE);
my $pipeline_status;
try{$pipeline_status=Storable::retrieve($progress);}catch{};
$pipeline_status->{"createTreeFromAlignment"}{$selected_species}=$out_tree_file;
Storable::store($pipeline_status,$progress);
print ("Step 5/7, FINISHED\n\n");
exit(0);

sub prepare_aln_thread{
	my $aln_gb_length=0;
	
	while (defined(my $args=$queue->dequeue())){
		my ($big_slice,$big_slice_length,$tempdir,$aln_file,$index)=@{$args};
		for (my $start=1; $start<=$big_slice_length; $start+=$Gblocks_slice_size){	
			my $end=$start+$Gblocks_slice_size-1;
			if ($end>$big_slice_length){$end=$big_slice_length}
			my ($aln,$aln_length)=slice($big_slice,$start,$end);		
			write_aln_fasta($aln,$tempdir.$aln_file.$index);
			system("cd \"".$tempdir."\";".$GBlocks." \"".$aln_file.$index."\"".$GBlocks_params. ">/dev/null");				
			my ($aln_gb,$length)=read_aln_fasta($tempdir.$aln_file.$index."-gb");			
			##write_aln_fasta($aln_gb,$refPath.$aln_file.$index."-gb");			
			$aln_gb_length+=$length;
			#print("Remove matches $aln_file$index...\n");
			remove_columns($aln_gb,$length,$tempdir.$aln_file.($index++)."-gb-matches_removed");
		}		
	}
	return $aln_gb_length;
}

sub calcTree_thread{
	my $treeString="";	
	while (defined(my $args=$queue->dequeue())){
		my ($big_slice,$big_slice_length,$num)=@{$args};
		for (my $start=1; $start<=$big_slice_length; $start+=$chunksize){	
			my $end=$start+$chunksize-1;
			if ($end>$big_slice_length){$end=$big_slice_length}
			my ($aln,$aln_length)=slice($big_slice,$start,$end);
			#my $aln=$big_slice->slice($start,$end);
			my $tempdir=new Bio::Root::IO->tempdir(CLEANUP=>0)."/";
			Bio::AlignIO::phylip->new (-file => ">".$tempdir."infile", -verbose => -1)->write_aln(myAln_to_simpleAln($aln));
			#Bio::AlignIO::phylip->new (-file => ">".$tempdir."infile")->write_aln($aln);
			#Bio::AlignIO::phylip->new (-file => ">".$refPath."infile.".$num)->write_aln($aln);
			system("\"$perl\" \"$dnapars\" \"$tempdir\"");
			open (my $IN, $tempdir."outtree");		
			while (my $l=<$IN>){$treeString.=$l;}
			close ($IN);
			thread_safe_rmtree($tempdir);
		}
	}
	return $treeString;
}


sub remove_columns{
	my ($in_aln,$in_aln_length,$out_aln_path,)=@_;
	my %seqs_out;
	my %seqs=%{$in_aln};
	if (int(keys(%seqs))>0){
		for (my $i=0; $i<$in_aln_length;$i++){					
			#if(($i % 10000)==0 ){print("$out_aln_path:$i\n");}						
			my $b=0;
			my $c="";
			my %cs;
			for my $seq_id(keys(%seqs)){
				my $c2=substr($seqs{$seq_id},$i,1);
				if ($c eq ""){$c=$c2}
				elsif ($c ne $c2){$b=1;}
				$cs{$seq_id}=$c2;
			}
			if ($b){
				for my $seq_id(keys(%cs)){$seqs_out{$seq_id}.=$cs{$seq_id}}
			}
		}
	}		
	write_aln_fasta(\%seqs_out,$out_aln_path);
}

sub calcTree{
	my ($aln,$treefile)=@_;	
	my $tempdir=new Bio::Root::IO->tempdir(CLEANUP=>0)."/";
	Bio::AlignIO::phylip->new (-file => ">".$tempdir."infile", -verbose => -1)->write_aln($aln);
	system("\"$perl\" \"$dnapars\" \"$tempdir\" \"$treefile\" ");
	open (my $IN, $tempdir."outtree");
	open(my $OUT, ">".$tempdir."outtree2");
	my $i=0;
	while (my $l=<$IN>){
		if ($l!~m/^\d+$/){print($OUT $l);}
	}
	close($IN);
	close($OUT);
	my $tree=Bio::TreeIO::newick->new(-file => $tempdir."outtree2",-verbose=>-1)->next_tree();
	thread_safe_rmtree($tempdir);
	return $tree;
}

sub calcConsensusTree{
	my ($infile,$outfile,$outfile_h,$ref_name)=@_;
	open(OUTCOPY, ">&STDOUT");
	open (STDOUT, ">/dev/null");
	my $tempdir=new Bio::Root::IO->tempdir(CLEANUP=>0)."/";
	File::Copy::copy($infile,$tempdir."intree");
	sleep(0.5);
	open(my $OUT ,"|- ") || exec ("cd \"$tempdir\";$consense");
	sleep(0.5);
	print($OUT "Y\n");
	close($OUT);
	my $tree=Bio::TreeIO::newick->new(-file => $tempdir."outtree", -verbose=>-1)->next_tree();
	for my $nd ($tree->get_nodes()){
		if ($nd->is_Leaf) {$nd->id($ref_name->{$nd->id_output});}
	}
	Bio::TreeIO::newick->new(-file => ">".$outfile, -verbose => -1)->write_tree($tree);
	open (my $IN, $tempdir."outtree");
	open (my $OUT, ">".$outfile_h);
	while (my $l=<$IN>){print($OUT $l);}
	close($IN);
	close($OUT);
	close(STDOUT);
	open(STDOUT, ">&OUTCOPY");
	
	thread_safe_rmtree($tempdir);		
}



sub prepare_aln{
	my ($aln,$aln_length,$out_aln_path_gb_removed,$out_aln_path_gb)=@_;
	my $tempdir=new Bio::Root::IO->tempdir(CLEANUP=>0)."/";	
	my @coords;
	for (my $start=1; $start<=$aln_length; $start+=$Gblocks_slice_size){	
		my $end=$start+$Gblocks_slice_size-1;
		if ($end>$aln_length){$end=$aln_length}
		push(@coords,[$start,$end]);			
	}
	
	my @coordsNumPerThread;
	my $coordsNumPerThreadBase=int(int(@coords)/$thread_num);
	for (my $i=0; $i<$thread_num;$i++){push(@coordsNumPerThread,$coordsNumPerThreadBase)};	
	my $left=int(@coords)-$coordsNumPerThreadBase*$thread_num;
	for (my $i=0; $i<$left;$i++){++$coordsNumPerThread[$i]};
	
	my $lastcoord=-1;
	my $i=0;
	for my $coordNumPerThread(@coordsNumPerThread){
		if ($coordNumPerThread>0){
			my $firstcoord+=$lastcoord+1;
			$lastcoord=$firstcoord+$coordNumPerThread-1;
			my $start=$coords[$firstcoord]->[0];
			my $end=$coords[$lastcoord]->[1];	
			my ($big_slice,$big_slice_length)=slice($aln,$start,$end);		
			while($queue->pending()){sleep(5);print("Step 5/7 (1/2), all $thread_num threads are busy...\n")}
			print("Step 5/7 (1/2), preparing alignment part ".++$i."/".@coordsNumPerThread.": $start-$end...\n");
			$queue->enqueue([$big_slice,$big_slice_length,$tempdir,"aln.fasta.",$firstcoord]);	
		}		
	}
	$queue->end();
	my $x=0;
	my $aln_gb_length;
	#print("Waiting for threads to return...\n");
	for my $thread(@threads){
		$aln_gb_length+=$thread->join();	
		print ("Step 5/7 (1/2), ".++$x."/".int($thread_num)." prepare-alignment-threads returned\n");
	}
	print("Step 5/7 (1/2), concatenating prepared alignment parts...\n");
	my %string_seqs_gb_removed;
	my %string_seqs_gb;
	for (my $i=0; $i<=$lastcoord;$i++){
		my $aln_part=Bio::SeqIO::fasta->new(-file => $tempdir."aln.fasta.".$i."-gb-matches_removed", -verbose => -1);
		while (my $seq=$aln_part->next_seq()){$string_seqs_gb_removed{$seq->id()}.=$seq->seq;}	
		my $aln_part=Bio::SeqIO::fasta->new(-file => $tempdir."aln.fasta.".$i."-gb", -verbose => -1);
		while (my $seq=$aln_part->next_seq()){$string_seqs_gb{$seq->id()}.=$seq->seq;}			
	}
	rmtree($tempdir);
	write_aln_fasta(\%string_seqs_gb_removed,$out_aln_path_gb_removed);
	
	#write_aln_fasta(\%string_seqs_gb,$out_aln_path_gb_removed);
	
	write_aln_fasta(\%string_seqs_gb,$out_aln_path_gb);
	return $aln_gb_length;	
}

sub slice{
	my ($aln,$start,$end)=@_;
	my %out;
	my $length=$end-$start+1;
	for my $seq_id(keys(%{$aln})){
		$out{$seq_id}=substr($aln->{$seq_id},$start-1,$length);
	}
	return (\%out,$length);
}

sub read_aln_fasta{
	my ($aln_path)=@_;
	my $aln_in=Bio::SeqIO::fasta->new(-file=> $aln_path , -verbose => -1);
	my %aln;
	my $length=-1;
	while (my $seq=$aln_in->next_seq()){
		$aln{$seq->id()}=$seq->seq;
		if ($length==-1){$length=$seq->length()}
	}
	return (\%aln,$length);
}

sub write_aln_fasta{
	my ($aln,$out_aln_path)=@_;
	open (my $ALN_OUT, ">$out_aln_path");
	for my $seq_id(keys(%{$aln})){
		print($ALN_OUT ">".$seq_id."\n");
		print($ALN_OUT $aln->{$seq_id}."\n");
	}	
}

sub simpleAln_to_myAln{
	my ($aln_in)=@_;
	my %aln;
	for my $seq($aln_in->each_seq){$aln{$seq->id}=$seq->seq}
	return \%aln;
}

sub myAln_to_simpleAln{
	my ($aln_in)=@_;
	my $aln=Bio::SimpleAlign->new();
	for my $seq_id(sort(keys(%{$aln_in}))){
		my $seq=Bio::LocatableSeq->new(-id => $seq_id, -seq => $aln_in->{$seq_id}, -start => 1, -end => length($aln_in->{$seq_id}), -verbose => -1);
		$aln->add_seq($seq);
	}
	return $aln;
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

sub make_tree_unrooted{
	my ($tree)=@_;
	my $root=$tree->get_root_node();
	my @children=$root->each_Descendent();
	if (int(@children)<3){
		for my $child(@children){
			if (!$child->is_Leaf){
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
            $self->set_root_node($new_root);;
        }
    }
    $self->get_root_node->ancestor(undef);
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


sub consensus_branch_lengths{
	my ($consensusTreePath,$allTreesPath)=@_;
	my $consensus_tree=Bio::TreeIO::newick->new(-file => $consensusTreePath)->next_tree();
	make_tree_unrooted($consensus_tree);
	my %leafs_under_node_consensus;
	for my $node($consensus_tree->get_nodes){
		my @leafs=sort(map{$_->id}(grep{$_->is_Leaf}($node->get_all_Descendents,$node)));
		$leafs_under_node_consensus{$node->internal_id}=\@leafs;
	}
	my @all_leafs=@{$leafs_under_node_consensus{$consensus_tree->get_root_node->internal_id}};
	my $all_trees=Bio::TreeIO::newick->new(-file => $allTreesPath);
	
	my %branch_length_sums;
	my %branch_support;
	my $trees_equal_consensus=0;
	my $trees_total;
	while(my ($tree,$weight)=my_next_tree($all_trees)){
		my $b=1;
		$trees_total+=$weight;
		for my $node($tree->get_nodes){
			my @leafs_under_cur_node=sort(map{$_->id}(grep{$_->is_Leaf}($node->get_all_Descendents,$node)));
			my $consensus_node_id=find_consensus_node(\@leafs_under_cur_node,\%leafs_under_node_consensus,\@all_leafs);
			if(defined($consensus_node_id)){
				if (!exists($branch_length_sums{$consensus_node_id})){$branch_length_sums{$consensus_node_id}=0}
				$branch_length_sums{$consensus_node_id}+=$node->branch_length*$weight;
				if (!exists($branch_support{$consensus_node_id})){$branch_support{$consensus_node_id}=0}
				$branch_support{$consensus_node_id}+=$weight;
			}
			else{$b=0;}
		}
		if($b){$trees_equal_consensus+=$weight;}
	}
	for my $node($consensus_tree->get_nodes){
		$node->branch_length($branch_length_sums{$node->internal_id}/$branch_support{$node->internal_id});		
	} 
	my $support_tree=$consensus_tree->clone();
	for my $node($support_tree->get_nodes){
		$node->branch_length($branch_support{$node->internal_id});		
	} 	
	return ($consensus_tree,$support_tree,$trees_equal_consensus,$trees_total);
}

sub find_consensus_node{
	my @cur_leafs=@{$_[0]};my %leafs_under_node_consensus=%{$_[1]};my @all_leafs=@{$_[2]};
	for my $consensus_node_id(keys(%leafs_under_node_consensus)){
		my @consensus_node_leafs=@{$leafs_under_node_consensus{$consensus_node_id}};		
		my $matches=0;
		for (my $i=0; $i<@consensus_node_leafs; $i++){	
			for (my $j=0; $j<@cur_leafs; $j++){				
				if($consensus_node_leafs[$i] eq @cur_leafs[$j]){$matches++}
			}
		}
		if ((($matches==@cur_leafs) && ($matches==@consensus_node_leafs)) || (($matches==0) && ((scalar(@cur_leafs)+scalar(@consensus_node_leafs)==scalar(@all_leafs))))){
			return $consensus_node_id;
		}

	}	
	return undef;
}

sub my_next_tree {
    my ($self) = @_;
    local $/ = ";\n";
    return unless $_ = $self->_readline;

    s/[\r\n]//gs;
    my $score;
    my $despace = sub { my $dirty = shift; $dirty =~ s/\s+//gs; return $dirty };
    my $dequote = sub {
        my $dirty = shift;
        $dirty =~ s/^"?\s*(.+?)\s*"?$/$1/;
        return $dirty;
    };
s/([^"]*)(".+?")([^"]*)/$despace->($1) . $dequote->($2) . $despace->($3)/egsx;

#    if (s/^\s*\[([^\]]+)\]//) {
#        my $match = $1;
#        $match =~ s/\s//g;
#        $match =~ s/lh\=//;
#        if ( $match =~ /([-\d\.+]+)/ ) {
#            $score = $1;
#        }
#    }
    
    my $weight=1;
    if(s/\[(.*)\]//){$weight=$1;}
    
    $self->_eventHandler->start_document;

    # Call the parse_newick method as defined in NewickParser.pm
    $self->parse_newick($_);

    my $tree = $self->_eventHandler->end_document;

    # Add the tree score afterwards if it exists.
    if (defined $tree) {
      $tree->score($score);
      return ($tree,$weight);
    }
}