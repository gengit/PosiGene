BEGIN{
	while (-l $0){$0=readlink($0)}
	my @path=split(/\/|\\/,$0);
	my $path=join("/",@path[0..(@path-2)])."/../modules";
	push (@INC,$path);
}

use strict;
use warnings;
use threads;
use threads::shared;
use File::Basename;
use Cwd;

#this was orginally a part of add_a_public_non_homologene_species_to_reference.pl, it was sourced out to avoid large increase of used memory due to copying the content of each variable for each thread

my $bin_dir=File::Basename::dirname(Cwd::abs_path($0))."/";
my $blastp_path=$bin_dir."blastp";
my $perl_path="perl";
my $fastasplit_path=$bin_dir."fastasplit.pl";

open (STDERR, ">/dev/null");#disable warnings, should be commented out when debugging 
no warnings;#disable warnings, should be commented out when debug

my ($query,$db,$output,$threadNum,$additionalPrintingInfo)=@ARGV;
#print("BLAST $query VS $db -> $output...\n");
system("\"$perl_path\" \"$fastasplit_path\" -f=\"$query\" -o=\"$query\" -n=$threadNum");
my @blastThreads;
for (my $i=1; $i<=$threadNum; $i++){
	push(@blastThreads, threads->create(\&myBlastThread,$query.".".$i,$db,$output.".".$i));
	#sleep(0.1);
	print ($additionalPrintingInfo."created ".$i."/$threadNum BLAST-threads\n");		
}
#print ("Step 2/7, FINISHED starting Threads...\n");
my $x=0;
for my $thread(@blastThreads){
	$thread->join();	
	print ($additionalPrintingInfo.++$x."/$threadNum BLAST-threads returned\n");
}
#print("Finished BLAST $query VS $db -> $output...\n");
system("cat $output.* > $output");
print("Delete temporary files...\n");
for (my $i=1;$i<=$threadNum;$i++){
	unlink($query.".".$i);
	unlink($output.".".$i);
}
exit(0);

sub myBlastThread{
	my ($query,$db,$output)=@_;
	#print("\"".$blastp_path."\" -query \"".$query."\""." -db \"".$db."\" -max_target_seqs 1 -outfmt 6 > ".$output);
	system("\"".$blastp_path."\" -query \"".$query."\""." -db \"".$db."\" -max_target_seqs 1 -outfmt 6 > \"$output\"");
}