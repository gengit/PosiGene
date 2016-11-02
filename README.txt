PosiGene is a software tool that (i) detects positively selected genes on 
genome-scale, (ii) allows analysis of specific evolutionary branches, (iii) can
be used in arbitrary species contexts and (iv) offers visualization of the 
candidates. PosiGene was tested on simulated as well as real data to ensure the 
reliability of the predicted positively selected genes. 

You do not need any further installation steps after unpacking.

To learn how to use PosiGene please read the user guide that can be found under 
doc/user_guide.pdf.

To test whether the package works please execute:
perl PosiGene.pl -o=test  -as=Harpegnathos_saltator  -tn=10  -rs=Acromyrmex_echinatior:test_data/Acromyrmex_echinatior_sample.fasta  -nhsbr=Acromyrmex_echinatior:test_data/Acromyrmex_echinatior_sample.fasta,Atta_cephalotes:test_data/Atta_cephalotes_sample.fasta,Camponotus_floridanus:test_data/Camponotus_floridanus_sample.fasta,Harpegnathos_saltator:test_data/Harpegnathos_saltator_sample.fasta,Linepithema_humile:test_data/Linepithema_humile_sample.fasta,Pogonomyrmex_barbatus:test_data/Pogonomyrmex_barbatus_sample.fasta,Solenopsis_invicta:test_data/Solenopsis_invicta_sample.fasta

It should be finished after some minutes, telling you where you can find a 
result table. If the program runs through and the produced result table equals 
that at test_data/Harpegnathos_saltator_results_short.tsv everything is fine.
