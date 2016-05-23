BEGIN{
	while (-l $0){$0=readlink($0)}
	my @path=split(/\/|\\/,$0);
	my $path=join("/",@path[0..(@path-2)])."/../modules";
	push (@INC,$path);
}

use strict;
use File::Basename;
use Cwd;
use File::Copy;
my $bin_dir=File::Basename::dirname(Cwd::abs_path($0))."/";
my $dnapars=$bin_dir."dnapars";
open (STDOUT, ">/dev/null");
my ($dir,$treefile)=@ARGV;
sleep(0.5);
open(my $OUT ,"|- ") || exec ("cd \"$dir\";$dnapars");
sleep(0.5);
if (defined($treefile)){
	File::Copy::copy($treefile,$dir."intree");
	print($OUT "U\n");
}
print($OUT "Y\n");
close($OUT);
exit(0);