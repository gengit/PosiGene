BEGIN{
	while (-l $0){$0=readlink($0)}
	my @path=split(/\/|\\/,$0);
	my $path=join("/",@path[0..(@path-2)])."/../modules";
	push (@INC,$path);
}

use strict;
use Bio::SeqIO::fasta;
use Getopt::Long;

my $fastaIN;
my $n;
my $out="";
my $rename=0;
my $k=0;
#open (STDERR, ">/dev/null");#disable warnings, should be commented out when debugging 

GetOptions("fasta|f=s" => \$fastaIN,"number|n=i" => \$n,"out|o=s" => \$out, "rename|r=i" => \$rename);

if ($out eq ""){$out=$fastaIN}
open(my $IN, $fastaIN);
my @seqs;
my $i=-1;
my $array_i=0;
while(my $l=<$IN>){	
	if($l=~m/^>/){
		$array_i=++$i % $n;
		if(($i % 10000)==1){print(STDERR "$i sequences read...\n")}	 
		$seqs[$array_i].=$l
	}
	else{$seqs[$array_i].=$l}
}
print(STDERR "$i sequences read.\nWrite output files...\n");
close($IN);
for (my $i=0; $i<$n; $i++){
	open(my $OUT,">$out.".($i+1));
	print($OUT $seqs[$i]);
	close($OUT);
}
print(STDERR "Complete.\n")

#$fastaIN=Bio::SeqIO::fasta->new(-file => $fastaIN);
#my @fastaOut;
#for (my $i=0;$i<$n;$i++){
#	push(@fastaOut,Bio::SeqIO::fasta->new(-file => ">".$out.".".($i+1)));
#}
#my @fastas;
#while (my $seq=$fastaIN->next_seq()){
#push(@fastas, $seq);
#}
#
#for (my $i=0; $i<@fastas; $i++){
#	if (($i % $n)==0){$k++;}
#	if ($rename){$fastas[$i]->id($k);}
#	#print($i."/".@fastas.": ".$fastas[$i]->id()."\n");
#	$fastaOut[$i % $n]->write_seq($fastas[$i]);
#}
#
##for (my $i=0; my $seq=$fastaIN->next_seq(); $i++){
##	print($i.": ".$seq->id()."\n");
##	$fastaOut[$i % $n]->write_seq($seq);
##}


