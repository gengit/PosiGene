# Summary

PosiGene is a tool that (i) detects positively selected genes on genome-scale, 
(ii) allows analysis of specific evolutionary branches, (iii) can be used in 
arbitrary species contexts and (iv) offers visualization of the candidates. As 
data input the program requires only the coding sequences of your chosen species
set in fasta or genbank format. From them, orthologs, alignments and a 
phylogenetic tree are reconstructed to finally apply the branch-site test of 
positive selection. Filtering mechanisms are implemented to minimize the 
occurrence of false positives. PosiGene was tested on simulated as well as real
data to ensure the reliability of the predicted positively selected genes.

# Installation

After unpacking, no further installation steps are needed.

# Documentation

To learn how to use PosiGene please read the user guide that can be found under 
doc/user_guide.pdf.

# Test run

To test whether the package works please execute:
perl PosiGene.pl -o=test  -as=Harpegnathos_saltator  -tn=10  -rs=Acromyrmex_echinatior:test_data/Acromyrmex_echinatior_sample.fasta  -nhsbr=Acromyrmex_echinatior:test_data/Acromyrmex_echinatior_sample.fasta,Atta_cephalotes:test_data/Atta_cephalotes_sample.fasta,Camponotus_floridanus:test_data/Camponotus_floridanus_sample.fasta,Harpegnathos_saltator:test_data/Harpegnathos_saltator_sample.fasta,Linepithema_humile:test_data/Linepithema_humile_sample.fasta,Pogonomyrmex_barbatus:test_data/Pogonomyrmex_barbatus_sample.fasta,Solenopsis_invicta:test_data/Solenopsis_invicta_sample.fasta

It should be finished after some minutes, telling you where you can find a 
result table. If the program runs through and the produced result table equals 
that at test_data/Harpegnathos_saltator_results_short.tsv everything is fine.
