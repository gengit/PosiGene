BEGIN{
	while (-l $0){$0=readlink($0)}
	my @path=split(/\/|\\/,$0);
	my $path=join("/",@path[0..(@path-2)])."/../modules";
	push (@INC,$path);
}


use strict;
use threads;
use threads::shared;
use Bio::AlignIO;
use Storable;
use Bio::SimpleAlign;
use POSIX;
require Bio::Align::Graphics;
use Bio::Coordinate::GeneMapper;
use Bio::Location::Simple;
use Bio::Range;
use Bio::SeqIO::genbank;
use Bio::LocatableSeq;
use File::Basename;
use Try::Tiny;

open (STDERR, ">/dev/null");#disable warnings, should be commented out when debugging 
no warnings;#disable warnings, should be commented out when debug

my $image_output_format="png";
my $error_string="";
my $wrap=100;
my $blocksize=10;
my $max_label_length=30;
my $codeml_analyzed_color="blue";
my $special_region_color="red";
my $intersection_color="DarkViolet";
my $jalview_not_significant_char=".";
my $jalview_significant_char="*";
my $jalview_codeml_input_icon="E";
my $jalview_functional_icon="H";
my $jalview_color_scheme_prot="white";
my $jalview_BEB_color_prot="zappo";
my $jalview_BEB_outline_color_prot="black";
my $jalview_color_scheme_nucl="white";
my $jalview_BEB_color_nucl="nucleotide";
my $jalview_BEB_outline_color_nucl="black";
my $jalview_BEB_vis_threshold_color="blue";

my ($do_image_output,$aln_path,$tree_path,$gbk_path,$parameterFile,$nucl_aln_path,$prot_aln_path,$jalview_out_path,$jalview_translation_out_path,$aln_translation_out_path,$out_path,$aln_translation_out_path_wrapped,$out_path_wrapped,$aln_translation_out_path_anno,$out_path_anno,$aln_translation_out_path_wrapped_anno,$out_path_wrapped_anno,$BEB_significance_threshold,$image_output_format,$log_file)=@ARGV;

try{
	my $parameter=Storable::retrieve($parameterFile);
	my @flanks=@{$parameter->{"flanks"}};
	my @BEBs=@{$parameter->{"BEBs"}};
	my @BEBs_jalview=@BEBs;
	push(@BEBs_jalview,@{$parameter->{"BEBs_not_significant"}},@{$parameter->{"excess_BEBs"}},@{$parameter->{"flank_BEBs"}});
	my %species_hash=%{$parameter->{"species_hash"}};
	my %species_to_mark=%{$parameter->{"species_to_mark"}};	
	drawAlignment($aln_path,\@BEBs,\@BEBs_jalview,\@flanks,\%species_hash,\%species_to_mark,$aln_translation_out_path,$out_path,$aln_translation_out_path_wrapped,$out_path_wrapped);
}catch{$error_string.=$_."\n"};

open(my $LOGFILE,">$log_file");
print($LOGFILE $error_string);
close($LOGFILE);
exit(0);

sub drawAlignment{
	my ($aln_path,$BEBs,$BEBs_jalview,$flanks,$species_hash,$species_to_mark,$aln_translation_out_path,$out_path,$aln_translation_out_path_wrapped,$out_path_wrapped)=@_;
	my $nucl_aln=Bio::AlignIO->new (-file => $aln_path ,-format => 'fasta')->next_aln();	
	my @marked_species_ids;
	for my $nucl($nucl_aln->each_seq){
		if (($species_hash) && (exists($species_hash->{$nucl->id()}))){
			my $b=exists($species_to_mark->{$species_hash->{$nucl->id()}});
			$species_hash->{$nucl->id()}=$species_hash->{$nucl->id()}."(".$nucl->id().")".($b?"*":"");	
			$nucl_aln->remove_seq($nucl);
			$nucl->id($species_hash->{$nucl->id()});
			$nucl_aln->add_seq($nucl);	
			if ($b){push(@marked_species_ids,$nucl->id())}			
		}	
	}	
	
#	my %candidates;
	
	my $prot_aln=nuclAln_to_protAln($nucl_aln,$species_hash);
	$prot_aln->set_displayname_flat();
	$nucl_aln->set_displayname_flat();
	Bio::AlignIO->new (-file => ">".$prot_aln_path,-format => 'fasta')->write_aln($prot_aln);
	Bio::AlignIO->new (-file => ">".$nucl_aln_path, -format => 'fasta')->write_aln($nucl_aln);	
	my @domain_start;
	my @domain_end;
	my @domain_color;
	my @dml_start;
	my @dml_end;
	my @dml_color;
	my %labels;
	my @domain_start_nucl;
	my @domain_end_nucl;
	my @domain_color_nucl;
	my @dml_start_nucl;
	my @dml_end_nucl;
	my @dml_color_nucl;
	my %labels_nucl;
	my @jalview_anno_functional_prot;#hash:Aln-Position->{"icon" => X, "tooltip" => Y,"label" =>Z}
	my @jalview_anno_codeml_input_prot;#hash:Aln-Position->{"icon" => X}
	my @jalview_anno_BEB_prot;#hash:Aln-Position->{"value" => X, "char" => Y}
	my %jalview_seq_group_BEB_prot;#hash:ID->{from:int,to:int,seqs:array of string}
	my @jalview_anno_functional_nucl;#hash:Aln-Position->{"icon" => X, "tooltip" => Y,"label" =>Z}
	my @jalview_anno_codeml_input_nucl;#hash:Aln-Position->{"icon" => X}
	my @jalview_anno_BEB_nucl;#hash:Aln-Position->{"value" => X, "char" => Y}
	my %jalview_seq_group_BEB_nucl;#hash:ID->{from:int,to:int,seqs:array of string,colour:string,outline_colour:string}
		
	for my $flank(@{$flanks}){
		#push (@domain_start,($flank->[0]+2)/3);
		#push (@domain_end,($flank->[1]+2)/3);
		#push (@domain_color,)
		push (@dml_start,($flank->[0]+2)/3);
		push (@dml_end,$flank->[1]/3);
		push (@dml_color,$codeml_analyzed_color);
		push (@dml_start_nucl,($flank->[0]));
		push (@dml_end_nucl,($flank->[1]));
		push (@dml_color_nucl,$codeml_analyzed_color);		
		if ($flank->[1]-$flank->[0]>($wrap*3)){#gleicht einen Bug in Bio::Align::Graphics aus, der Markierung "vergisst", wenn sie ohen Unterbrechung ueber ein ganzen Wrap-Block geht			
			for (my $pos=(($wrap*3)-($flank->[0] % ($wrap*3)))+$flank->[0]+1;$pos<=$flank->[1];$pos+=($wrap*3)){
				push (@dml_start,($pos-1)/3+1);
				push (@dml_end,$flank->[1]/3);
				push (@dml_color,$codeml_analyzed_color);
				push (@dml_start_nucl,($pos));
				push (@dml_end_nucl,($flank->[1]));
				push (@dml_color_nucl,$codeml_analyzed_color);			
			}		
		}
		for (my $i=$flank->[0]; $i<=$flank->[1];$i++){$jalview_anno_codeml_input_nucl[$i-1]={"icon" => $jalview_codeml_input_icon}}
		for (my $i=($flank->[0]+2)/3; $i<=$flank->[1]/3;$i++){$jalview_anno_codeml_input_prot[$i-1]={"icon" => $jalview_codeml_input_icon}}
	}
	for my $BEB(@$BEBs_jalview){
		$jalview_anno_BEB_nucl[$BEB->[9]-1]={"value" => $BEB->[1]*100,"char" => $jalview_not_significant_char,"tooltip"=>sprintf("%.2f", $BEB->[1]*100)."%"};
		$jalview_anno_BEB_nucl[$BEB->[9]+1-1]={"value" => $BEB->[1]*100,"char" => $jalview_not_significant_char,"tooltip"=>sprintf("%.2f", $BEB->[1]*100)."%"};
		$jalview_anno_BEB_nucl[$BEB->[9]+2-1]={"value" => $BEB->[1]*100,"char" => $jalview_not_significant_char,"tooltip"=>sprintf("%.2f", $BEB->[1]*100)."%"};
		$jalview_anno_BEB_prot[$BEB->[10]-1]={"value" => $BEB->[1]*100,"char" => $jalview_not_significant_char,"tooltip"=>sprintf("%.2f", $BEB->[1]*100)."%"};		
	}
	my $i=0;
	for my $BEB(sort{$a->[10]<=>$b->[10]}@{$BEBs}){
		my $domain_color="gradient".(ceil(($BEB->[1]*100-50)/2)+25);
		push (@domain_start,$BEB->[10]);
		push (@domain_end,$BEB->[10]);
		push (@domain_color,$domain_color);
		$labels{$BEB->[10]}=sprintf("%.2f", $BEB->[1]*100)."% ->";
		push (@domain_start_nucl,$BEB->[9]);
		push (@domain_end_nucl,$BEB->[9]+2);
		push (@domain_color_nucl,$domain_color);
		$labels_nucl{$BEB->[9]+1}=sprintf("%.2f", $BEB->[1]*100)."% ->";
		$jalview_anno_BEB_nucl[$BEB->[9]-1]={"value" => $BEB->[1]*100,"char" => $jalview_significant_char,"tooltip"=>sprintf("%.2f", $BEB->[1]*100)."%"};
		$jalview_anno_BEB_nucl[$BEB->[9]+1-1]={"value" => $BEB->[1]*100,"char" => $jalview_significant_char,"tooltip"=>sprintf("%.2f", $BEB->[1]*100)."%"};
		$jalview_anno_BEB_nucl[$BEB->[9]+2-1]={"value" => $BEB->[1]*100,"char" => $jalview_significant_char,"tooltip"=>sprintf("%.2f", $BEB->[1]*100)."%"};
		$jalview_anno_BEB_prot[$BEB->[10]-1]={"value" => $BEB->[1]*100,"char" => $jalview_significant_char,"tooltip"=>sprintf("%.2f", $BEB->[1]*100)."%"};
		$jalview_seq_group_BEB_nucl{"Positively selected site ".(++$i).": ".sprintf("%.2f", $BEB->[1]*100)."%"}={"from" => $BEB->[9],"to" => $BEB->[9]+2,"seqs" => \@marked_species_ids,"colour" => $jalview_BEB_color_nucl,"outline_colour" => $jalview_BEB_outline_color_nucl};
		$jalview_seq_group_BEB_prot{"Positively selected site $i: ".sprintf("%.2f", $BEB->[1]*100)."%"}={"from" => $BEB->[10],"to" => $BEB->[10],"seqs" => \@marked_species_ids,"colour" => $jalview_BEB_color_prot,"outline_colour" => $jalview_BEB_outline_color_prot};
		
	}
	
	my $max_numb_digits_prot=int(log($prot_aln->length)/log(10))+1;
	my $max_numb_digits_nucl=int(log($nucl_aln->length)/log(10))+1;	

	if ($do_image_output){
		my $print_align = new Bio::Align::Graphics( align => $prot_aln,	
			pad_bottom => 7,
			pad_left => 1,
			font => 5,
			dm_start => \@domain_start,
			dm_end => \@domain_end,
			dm_color => \@domain_color,
			dml_start => \@dml_start,
			dml_end => \@dml_end,
			dml_color => \@dml_color,
			labels => \%labels,	
			output => $aln_translation_out_path,
			out_format => $image_output_format,
			x_label => 1, y_label => 1,
			x_label_color => "black", y_label_color => "black",
			x_label_space => 5, block_space=>1,
			block_size =>$blocksize,
			wrap => $prot_aln->length()+1,
			p_color => 1
		);	
		$print_align->draw();
		my $print_align = new Bio::Align::Graphics( align => $prot_aln,	
			pad_bottom => 3+$max_numb_digits_prot+$max_label_length*9/15,
			pad_left => 1,
			font => 5,
			dm_start => \@domain_start,
			dm_end => \@domain_end,
			dm_color => \@domain_color,
			dml_start => \@dml_start,
			dml_end => \@dml_end,
			dml_color => \@dml_color,
			labels => \%labels,	
			output => $aln_translation_out_path_wrapped,
			out_format => $image_output_format,
			x_label => 1, y_label => 1,
			x_label_color => "black", y_label_color => "black",
			x_label_space => 5, block_space=>1,
			block_size =>$blocksize,
			wrap => $wrap,
			p_color => 1
		);
		$print_align->draw();
		my $print_align = new Bio::Align::Graphics( align => $nucl_aln,	
			pad_bottom => 7,
			pad_left => 1,
			font => 5,
			dm_start => \@domain_start_nucl,
			dm_end => \@domain_end_nucl,
			dm_color => \@domain_color_nucl,
			dml_start => \@dml_start_nucl,
			dml_end => \@dml_end_nucl,
			dml_color => \@dml_color_nucl,
			labels => \%labels_nucl,	
			output => $out_path,
			out_format => $image_output_format,
			x_label => 1, y_label => 1,
			x_label_color => "black", y_label_color => "black",
			x_label_space => 5, block_space=>1,
			block_size => $blocksize*3,
			wrap => $nucl_aln->length()+1,
		);
		$print_align->draw();
		my $print_align = new Bio::Align::Graphics( align => $nucl_aln,	
			pad_bottom => 3+$max_numb_digits_nucl+$max_label_length*9/15,
			pad_left => 1,
			font => 5,
			dm_start => \@domain_start_nucl,
			dm_end => \@domain_end_nucl,
			dm_color => \@domain_color_nucl,
			dml_start => \@dml_start_nucl,
			dml_end => \@dml_end_nucl,
			dml_color => \@dml_color_nucl,
			labels => \%labels_nucl,	
			output => $out_path_wrapped,
			out_format => $image_output_format,
			x_label => 1, y_label => 1,
			x_label_color => "black", y_label_color => "black",
			x_label_space => 5, block_space=>1,
			block_size => $blocksize*3,
			wrap => $wrap*3,
		);
		$print_align->draw();
	}
	my @anno_start_nucl; 
	my @anno_end_nucl;
	my @anno_start_prot; 
	my @anno_end_prot;
	my @anno_color;
	my @anno_start_nucl_extra; 
	my @anno_end_nucl_extra;
	my @anno_start_prot_extra; 
	my @anno_end_prot_extra;
	my @anno_color_extra;	
	my %exact_list_nucl;
	my %exact_list_prot;
	my @label_pos_nucl;
	my @label_pos_prot;

	if (-e $gbk_path){	
		my $position_seq= Bio::SeqIO::genbank->new(-file => $gbk_path)->next_seq();
		my $mRNA_to_cds;
		my $cds_feat;
		for my $feat ($position_seq->get_SeqFeatures()){	
			if ((lc($feat->primary_tag) eq "cds")){
				$cds_feat=$feat;
				$mRNA_to_cds=Bio::Coordinate::GeneMapper->new(-in => "chr",-out => "cds", -cds => $feat->location);
			}
		}
		
		my @jalview_label_pos_nucl;
		my @jalview_label_pos_prot;
			
		for my $feat ($position_seq->get_SeqFeatures()){
			if ((lc($feat->primary_tag) eq "misc_feature") && $feat->has_tag("experiment") && $feat->has_tag("note")){
				my @values = split("; ?",($feat->get_tag_values("note"))[0]);
				my $feat_contained=0;
				for my $loc($cds_feat->location->each_Location){if($loc->contains($feat)){$feat_contained=1}}
				if ((int(@values)>0) && ($feat_contained)){
					my $location_on_cds=$mRNA_to_cds->map($feat->location);
					$values[@values-1]=~s/^Region://;
					$values[@values-1]=~s/\s*$//;
					$values[@values-1]=~s/^\s*//;
							
					my $start_nucl=$nucl_aln->column_from_residue_number($species_hash->{$position_seq->id},$location_on_cds->start);
					my $end_nucl=$nucl_aln->column_from_residue_number($species_hash->{$position_seq->id},$location_on_cds->end);
					my $start_prot=$prot_aln->column_from_residue_number($species_hash->{$position_seq->id},int($location_on_cds->start/3-0.1+1));
					my $end_prot=$prot_aln->column_from_residue_number($species_hash->{$position_seq->id},int($location_on_cds->end/3-0.1+1));	
																				
					push (@anno_start_nucl,$start_nucl);
					push (@anno_end_nucl,$end_nucl);
					push (@anno_start_prot,$start_prot);
					push (@anno_end_prot,$end_prot);
					push (@anno_color,$special_region_color);

					if ($end_nucl-$start_nucl>($wrap*3)){#gleicht einen Bug in Bio::Align::Graphics aus, der Markierung "vergisst", wenn sie ohen Unterbrechung ueber ein ganzen Wrap-Block geht
						for (my $pos=(($wrap*3)-($start_nucl % ($wrap*3)))+$start_nucl+1;$pos<=$end_nucl;$pos+=($wrap*3)){
							push (@anno_start_prot_extra,($pos-1)/3+1);
							push (@anno_end_prot_extra,$end_nucl/3);
							push (@anno_start_nucl_extra,($pos));
							push (@anno_end_nucl_extra,($end_nucl));
							push (@anno_color_extra,$special_region_color);			
						}		
					}
					
					my $label_pos_nucl=int(($start_nucl+$end_nucl)/2);					
					my $i=0;
					for ($i=0; exists($labels_nucl{$label_pos_nucl+$i});$i*=-1){if($i<=0){$i-=1}}
					push(@label_pos_nucl,$label_pos_nucl+$i);
					if (($label_pos_nucl+$i<$start_nucl) || ($label_pos_nucl+$i>$end_nucl)){$exact_list_nucl{int(@label_pos_nucl)-1}=""}			
					$labels_nucl{$label_pos_nucl[@label_pos_nucl-1]}=label($values[@values-1]);
					
					my $label_pos_prot=int(($start_prot+$end_prot)/2);
					my $i=0;
					for ($i=0; exists($labels{$label_pos_prot+$i});$i*=-1){if($i<=0){$i-=1}}
					push(@label_pos_prot,$label_pos_prot+$i);
					if (($label_pos_prot+$i<$start_prot) || ($label_pos_prot+$i>$end_prot)){$exact_list_prot{int(@label_pos_prot)-1}=""}			
					$labels{$label_pos_prot[@label_pos_prot-1]}=label($values[@values-1]);
					
					if (exists($jalview_anno_functional_nucl[$label_pos_nucl[@label_pos_nucl-1]-1]{"label"})){$jalview_anno_functional_nucl[$label_pos_nucl[@label_pos_nucl-1]-1]{"label"}.=";".jalview_label($values[@values-1]);}
					else{$jalview_anno_functional_nucl[$label_pos_nucl[@label_pos_nucl-1]-1]{"label"}=jalview_label($values[@values-1]);}				
					for (my $i=$start_nucl; $i<=$end_nucl;$i++){
						$jalview_anno_functional_nucl[$i-1]{"icon"}=$jalview_functional_icon;
						if(exists($jalview_anno_functional_nucl[$i-1]{"tooltip"})){$jalview_anno_functional_nucl[$i-1]{"tooltip"}.=";".jalview_label($values[@values-1]);}
						else{$jalview_anno_functional_nucl[$i-1]{"tooltip"}=jalview_label($values[@values-1]);}
					}				
					if(exists($jalview_anno_functional_prot[$label_pos_prot[@label_pos_prot-1]-1]{"label"})){$jalview_anno_functional_prot[$label_pos_prot[@label_pos_prot-1]-1]{"label"}.=";".jalview_label($values[@values-1]);}
					else{$jalview_anno_functional_prot[$label_pos_prot[@label_pos_prot-1]-1]{"label"}=jalview_label($values[@values-1]);}
					for (my $i=$start_prot; $i<=$end_prot;$i++){
						$jalview_anno_functional_prot[$i-1]{"icon"}=$jalview_functional_icon;
						if(exists($jalview_anno_functional_prot[$i-1]{"tooltip"})){$jalview_anno_functional_prot[$i-1]{"tooltip"}.=";".jalview_label($values[@values-1])}
						else{$jalview_anno_functional_prot[$i-1]{"tooltip"}=jalview_label($values[@values-1])}
					}										
				} 
			}
		}					
	}

	my @intersect_start_nucl;
	my @intersect_end_nucl;
	my @intersect_start_prot;
	my @intersect_end_prot;
	my @intersect_color;

	
	for (my $i=0; $i<@anno_start_nucl; $i++){
		for (my $j=0; $j<@anno_start_nucl; $j++){
			if (($i!=$j) && ($anno_start_nucl[$j]<=$anno_end_nucl[$i]+1) && ($anno_start_nucl[$j]>=$anno_start_nucl[$i])){
				$exact_list_nucl{$i}="";
				$exact_list_nucl{$j}="";
				$exact_list_prot{$i}="";
				$exact_list_prot{$j}="";
			}
		}
		my $anno_range_nucl=Bio::Range->new(-start =>$anno_start_nucl[$i], -end=>$anno_end_nucl[$i]);
		my $anno_range_prot=Bio::Range->new(-start =>$anno_start_prot[$i], -end=>$anno_end_prot[$i]);
		for (my $j=0;$j<@dml_start_nucl;$j++){
			if (my $intersect=$anno_range_nucl->intersection(Bio::Range->new(-start => $dml_start_nucl[$j], -end => $dml_end_nucl[$j]))){
				push(@intersect_start_nucl,$intersect->start);
				push(@intersect_end_nucl,$intersect->end);
				push(@intersect_color,$intersection_color);
			}
			if (my $intersect=$anno_range_prot->intersection(Bio::Range->new(-start => $dml_start[$j], -end => $dml_end[$j]))){
				push(@intersect_start_prot,$intersect->start);
				push(@intersect_end_prot,$intersect->end);
				push(@intersect_color,$intersection_color);
			}			
		}
		
#		for my $BEB(@{$BEBs}){if($anno_range_nucl->contains(Bio::Range->new(-start => $BEB->[9], -end=>$BEB->[9]+2))){$candidates{$gbk_path}=""}}
	}
	
	my @intersect_start_nucl_extra;
	my @intersect_end_nucl_extra;
	my @intersect_start_prot_extra;
	my @intersect_end_prot_extra;
	my @intersect_color_extra;	
	
	for (my $i=0; $i<@intersect_start_nucl;$i++){
		my $start_nucl=$intersect_start_nucl[$i];
		my $end_nucl=$intersect_end_nucl[$i];
		if ($end_nucl-$start_nucl>($wrap*3)){#gleicht einen Bug in Bio::Align::Graphics aus, der Markierung "vergisst", wenn sie ohen Unterbrechung ueber ein ganzen Wrap-Block geht
			for (my $pos=(($wrap*3)-($start_nucl % ($wrap*3)))+$start_nucl+1;$pos<=$end_nucl;$pos+=($wrap*3)){
				push (@intersect_start_prot_extra,($pos-1)/3+1);
				push (@intersect_end_prot_extra,$end_nucl/3);
				push (@intersect_start_nucl_extra,($pos));
				push (@intersect_end_nucl_extra,($end_nucl));
				push (@intersect_color_extra,$intersection_color);			
			}		
		}		
	}
	
	for my $i(keys(%exact_list_nucl)){
		if ($anno_start_nucl[$i]!=$anno_end_nucl[$i]){$labels_nucl{
			$label_pos_nucl[$i]}=label($anno_start_nucl[$i]."-".$anno_end_nucl[$i].": ".$labels_nucl{$label_pos_nucl[$i]});
			$jalview_anno_functional_nucl[$label_pos_nucl[$i]-1]{"label"}=jalview_label($anno_start_nucl[$i]."-".$anno_end_nucl[$i].": ".$jalview_anno_functional_nucl[$label_pos_nucl[$i]-1]{"label"});
		}
		else{
			$labels_nucl{$label_pos_nucl[$i]}=label($anno_start_nucl[$i].": ".$labels_nucl{$label_pos_nucl[$i]},0,$max_label_length);
			$jalview_anno_functional_nucl[$label_pos_nucl[$i]-1]{"label"}=jalview_label($anno_start_nucl[$i].": ".$jalview_anno_functional_nucl[$label_pos_nucl[$i]-1]{"label"});

		}
	}	
	for my $i(keys(%exact_list_prot)){
		if ($anno_start_prot[$i]!=$anno_end_prot[$i]){
			$labels{$label_pos_prot[$i]}=label($anno_start_prot[$i]."-".$anno_end_prot[$i].": ".$labels{$label_pos_prot[$i]});
			$jalview_anno_functional_prot[$label_pos_prot[$i]-1]{"label"}=jalview_label($anno_start_prot[$i]."-".$anno_end_prot[$i].": ".$jalview_anno_functional_prot[$label_pos_prot[$i]-1]{"label"});			
		}
		else{
			$labels{$label_pos_prot[$i]}=label($anno_start_prot[$i].": ".$labels{$label_pos_prot[$i]});
			$jalview_anno_functional_prot[$label_pos_prot[$i]-1]{"label"}=jalview_label($anno_start_prot[$i].": ".$jalview_anno_functional_prot[$label_pos_prot[$i]-1]{"label"});
		
		}
	}		
	
	push (@dml_start_nucl,@anno_start_nucl,@anno_start_nucl_extra,@intersect_start_nucl,@intersect_start_nucl_extra);
	push (@dml_end_nucl,@anno_end_nucl,@anno_end_nucl_extra,@intersect_end_nucl,@intersect_end_nucl_extra);
	push (@dml_color_nucl,@anno_color,@anno_color_extra,@intersect_color,@intersect_color_extra);
	push (@dml_start,@anno_start_prot,@anno_start_prot_extra,@intersect_start_prot,@intersect_start_prot_extra);
	push (@dml_end,@anno_end_prot,@anno_end_prot_extra,@intersect_end_prot,@intersect_end_prot_extra);
	push (@dml_color,@anno_color,@anno_color_extra,@intersect_color,@intersect_color_extra);
		
	#for (my $i=0; $i<@dml_start; $i++){print("$dml_start[$i]-$dml_end[$i]: $dml_color[$i]\n")}
	if($do_image_output){
		my $print_align = new Bio::Align::Graphics( align => $prot_aln,	
			pad_bottom => 7,
			pad_left => 1,
			font => 5,
			dm_start => \@domain_start,
			dm_end => \@domain_end,
			dm_color => \@domain_color,
			dml_start => \@dml_start,
			dml_end => \@dml_end,
			dml_color => \@dml_color,
			labels => \%labels,	
			output => $aln_translation_out_path_anno,
			out_format => $image_output_format,
			x_label => 1, y_label => 1,
			x_label_color => "black", y_label_color => "black",
			x_label_space => 5, block_space=>1,
			block_size =>$blocksize,
			wrap => $prot_aln->length()+1,
			p_color => 1
		);	
		$print_align->draw();
		my $print_align = new Bio::Align::Graphics( align => $prot_aln,	
			pad_bottom => 3+$max_numb_digits_prot+$max_label_length*9/15,
			pad_left => 1,
			font => 5,
			dm_start => \@domain_start,
			dm_end => \@domain_end,
			dm_color => \@domain_color,
			dml_start => \@dml_start,
			dml_end => \@dml_end,
			dml_color => \@dml_color,
			labels => \%labels,	
			output => $aln_translation_out_path_wrapped_anno,
			out_format => $image_output_format,
			x_label => 1, y_label => 1,
			x_label_color => "black", y_label_color => "black",
			x_label_space => 5, block_space=>1,
			block_size =>$blocksize,
			wrap => $wrap,
			p_color => 1
		);
		$print_align->draw();
		my $print_align = new Bio::Align::Graphics( align => $nucl_aln,	
			pad_bottom => 7,
			pad_left => 1,
			font => 5,
			dm_start => \@domain_start_nucl,
			dm_end => \@domain_end_nucl,
			dm_color => \@domain_color_nucl,
			dml_start => \@dml_start_nucl,
			dml_end => \@dml_end_nucl,
			dml_color => \@dml_color_nucl,
			labels => \%labels_nucl,	
			output => $out_path_anno,
			out_format => $image_output_format,
			x_label => 1, y_label => 1,
			x_label_color => "black", y_label_color => "black",
			x_label_space => 5, block_space=>1,
			block_size => $blocksize*3,
			wrap => $nucl_aln->length()+1,
		);
		$print_align->draw();
		my $print_align = new Bio::Align::Graphics( align => $nucl_aln,	
			pad_bottom => 3+$max_numb_digits_nucl+$max_label_length*9/15,
			pad_left => 1,
			font => 5,
			dm_start => \@domain_start_nucl,
			dm_end => \@domain_end_nucl,
			dm_color => \@domain_color_nucl,
			dml_start => \@dml_start_nucl,
			dml_end => \@dml_end_nucl,
			dml_color => \@dml_color_nucl,
			labels => \%labels_nucl,	
			output => $out_path_wrapped_anno,
			out_format => $image_output_format,
			x_label => 1, y_label => 1,
			x_label_color => "black", y_label_color => "black",
			x_label_space => 5, block_space=>1,
			block_size => $blocksize*3,
			wrap => $wrap*3,
		);
		$print_align->draw();
	}
	jalview_out($jalview_out_path,$nucl_aln_path,$tree_path,{"Analyzed positions" => \@jalview_anno_codeml_input_nucl,"Experimentally proved functions" => \@jalview_anno_functional_nucl},{"Positive selection probability" => \@jalview_anno_BEB_nucl},{"Visualization threshold" => {"LINE_GRAPH" => "Positive selection probability","color" => $jalview_BEB_vis_threshold_color, "value" => $BEB_significance_threshold*100}},\%jalview_seq_group_BEB_nucl,$jalview_color_scheme_nucl);
	jalview_out($jalview_translation_out_path,$prot_aln_path,$tree_path,{"Analyzed positions" => \@jalview_anno_codeml_input_prot,"Experimentally proved functions" => \@jalview_anno_functional_prot},{"Positive selection probability" => \@jalview_anno_BEB_prot},{"Visualization threshold" => {"LINE_GRAPH" => "Positive selection probability","color" => $jalview_BEB_vis_threshold_color, "value" => $BEB_significance_threshold*100}},\%jalview_seq_group_BEB_prot,$jalview_color_scheme_prot);
	
#	open(CANDI,">>/home/lakatos/asahm/Desktop/test_vis/candidates.txt");
#	print(CANDI join("\n",keys(%candidates))."\n");
#	close(CANDI);
	
}

sub jalview_out{
	my ($out_path,$aln_path,$tree_path,$no_graph_annotations,$line_graph_annotations,$graphline_annotations,$seq_groups,$colour_scheme)=@_;
	my $annotation_path=$out_path.".annotations";
	open(my $ANNO,">$annotation_path");
	print($ANNO "JALVIEW_ANNOTATION\n\n\n");
	for my $name(keys(%$line_graph_annotations)){
		print($ANNO "LINE_GRAPH\t$name\t".line_graph_annotation($line_graph_annotations->{$name})."\n");
	}
	for my $name(keys(%$graphline_annotations)){
		print($ANNO "GRAPHLINE\t".$graphline_annotations->{$name}{"LINE_GRAPH"}."\t".$graphline_annotations->{$name}{"value"}."\t$name\t".$graphline_annotations->{$name}{"color"}."\n");
	}
	for my $name(keys(%$no_graph_annotations)){
		print($ANNO "NO_GRAPH\t$name\t".no_graph_annotation($no_graph_annotations->{$name})."\n");
		print($ANNO "ROWPROPERTIES\t$name\tcentrelabs=true\n");
	}
	for my $seq_group_name(keys(%$seq_groups)){
		#print($ANNO "SEQUENCE_GROUP\t$seq_group_name\t".$seq_groups->{$seq_group_name}{"from"}."\t".$seq_groups->{$seq_group_name}{"to"}."\t-1\t".join("\t",@{$seq_groups->{$seq_group_name}{"seqs"}})."\n");
		print($ANNO "SEQUENCE_GROUP\t$seq_group_name\t".$seq_groups->{$seq_group_name}{"from"}."\t".$seq_groups->{$seq_group_name}{"to"}."\t"."*"."\n");
		print($ANNO "PROPERTIES\t$seq_group_name\tcolour=".$seq_groups->{$seq_group_name}{"colour"}."\n");
		print($ANNO "PROPERTIES\t$seq_group_name\toutlineColour=".$seq_groups->{$seq_group_name}{"outline_colour"}."\n");
	}
	close($ANNO);
	Storable::store({"alignment" => File::Basename::basename($aln_path),"tree" => File::Basename::basename($tree_path),"annotations" => File::Basename::basename($annotation_path),"colour" => $colour_scheme},$out_path);
}

sub line_graph_annotation{
	my @annotation=@{$_[0]};
	for my $i(@annotation){
		if(defined($i)){
			if(defined($i->{"value"})){			
				if(defined($i->{"char"})){
					if(defined($i->{"tooltip"})){$i=$i->{"value"}.",".$i->{"char"}.",".$i->{"tooltip"};}
					else{$i=$i->{"value"}.",".$i->{"char"};}						
				}
				else{$i=$i->{"value"};}
			} else {$i=""}
		}
	}
	return join("|",@annotation);
}

sub no_graph_annotation{
	my @annotation=@{$_[0]};
	for my $i(@annotation){
		if(defined($i)){
			if((defined($i->{"icon"}) && (defined($i->{"label"})) && (defined($i->{"tooltip"})) )){$i=$i->{"icon"}.",".$i->{"tooltip"}.",".$i->{"label"}}
			elsif(defined($i->{"icon"}) && (defined($i->{"tooltip"}))){$i=$i->{"tooltip"}.",".$i->{"icon"}}
			elsif(defined($i->{"icon"}) && (defined($i->{"label"}))){$i=$i->{"icon"}.",".$i->{"label"}}
			elsif(defined($i->{"icon"})){$i=$i->{"icon"}}
			elsif(defined($i->{"label"})){$i=$i->{"label"}}
			elsif(defined($i->{"tooltip"})){$i=$i->{"tooltip"}}
			else {$i=""}
		}
	}
	return join("|",@annotation);
}

sub nuclAln_to_protAln{
	my ($aln,$species_hash)=@_;
	my $protAln=Bio::SimpleAlign->new();
	for my $nucl($aln->each_seq){
		my $nucl_seq=$nucl->translate();
		if (($species_hash) && (exists($species_hash->{$nucl_seq->id()}))){
			$nucl_seq->id($species_hash->{$nucl_seq->id()}."(".$nucl_seq->id().")");
		}		
		$protAln->add_seq($nucl_seq);
	}
	return $protAln;
}


sub FETCH{
my ($self, $index) = @_;
$self->_bound_check($index);
$self->{array}[$index];
}

sub jalview_label{
	$_[0]=~s/[|]/ /g;
	$_[0]=~s/[[]/{/g;
	$_[0]=~s/[]]/}/g;
	$_[0]=~s/,/;/g;
	return $_[0];
}

sub label{
	if (length($_[0])>$max_label_length){
		$_[0]=substr($_[0],0,$max_label_length);
		$_[0]=~s/...$/.../;
	}
	return $_[0];
}

#	my $print_align = new Bio::Align::Graphics( align => $prot_aln,	
#		pad_bottom => 7,
#		font => 5,
#		dm_start => \@domain_start,
#		dm_end => \@domain_end,
#		dm_color => \@domain_color,
#		dml_start => \@dml_start,
#		dml_end => \@dml_end,
#		dml_color => \@dml_color,
#		labels => \%labels,	
#		output => $aln_translation_out_path,
#		out_format => $image_output_format,
#		x_label => 1, y_label => 1,
#		x_label_space => 5, block_space=>1,
#		block_size =>$blocksize,
#		wrap => $prot_aln->length()+1,
#	);	
#	$print_align->draw();
#	my $print_align = new Bio::Align::Graphics( align => $prot_aln,	
#		pad_bottom => 12,
#		font => 5,
#		dm_start => \@domain_start,
#		dm_end => \@domain_end,
#		dm_color => \@domain_color,
#		dml_start => \@dml_start,
#		dml_end => \@dml_end,
#		dml_color => \@dml_color,
#		labels => \%labels,	
#		output => $aln_translation_out_path_wrapped,
#		out_format => $image_output_format,
#		x_label => 1, y_label => 1,
#		x_label_space => 5, block_space=>1,
#		block_size =>$blocksize,
#		wrap => $wrap,
#	);
#	$print_align->draw();
#	my $print_align = new Bio::Align::Graphics( align => $nucl_aln,	
#		pad_bottom => 7,
#		font => 5,
#		dm_start => \@domain_start_nucl,
#		dm_end => \@domain_end_nucl,
#		dm_color => \@domain_color_nucl,
#		dml_start => \@dml_start_nucl,
#		dml_end => \@dml_end_nucl,
#		dml_color => \@dml_color_nucl,
#		labels => \%labels_nucl,	
#		output => $out_path,
#		out_format => $image_output_format,
#		x_label => 1, y_label => 1,
#		x_label_space => 5, block_space=>1,
#		block_size => $blocksize*3,
#		wrap => $nucl_aln->length()+1,
#	);
#	$print_align->draw();
#	my $print_align = new Bio::Align::Graphics( align => $nucl_aln,	
#		pad_bottom => 12,
#		font => 5,
#		dm_start => \@domain_start_nucl,
#		dm_end => \@domain_end_nucl,
#		dm_color => \@domain_color_nucl,
#		dml_start => \@dml_start_nucl,
#		dml_end => \@dml_end_nucl,
#		dml_color => \@dml_color_nucl,
#		labels => \%labels_nucl,	
#		output => $out_path_wrapped,
#		out_format => $image_output_format,
#		x_label => 1, y_label => 1,
#		x_label_space => 5, block_space=>1,
#		block_size => $blocksize*3,
#		wrap => $wrap*3,
#	);
#	$print_align->draw();