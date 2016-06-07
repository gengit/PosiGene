Basically, you do not need any further installation steps after unpacking to run
the program.

However, we additionally provide at our website sequence packages of several 
species that cover a large evolutionary distance and can improve PosiGene's 
ortholog assignment: http://genome.leibniz-fli.de/software/PosiGene/

To learn how to use PosiGene to scan for positively selected genes please read 
the user guide you find under doc/User_Guide.pdf.

To test whether the package works execute:
perl PosiGene.pl -o=test  -as=Harpegnathos_saltator  -tn=10  -rs=Acromyrmex_echinatior:test_data/Acromyrmex_echinatior_sample.fasta  -nhsbr=Acromyrmex_echinatior:test_data/Acromyrmex_echinatior_sample.fasta,Atta_cephalotes:test_data/Atta_cephalotes_sample.fasta,Camponotus_floridanus:test_data/Camponotus_floridanus_sample.fasta,Harpegnathos_saltator:test_data/Harpegnathos_saltator_sample.fasta,Linepithema_humile:test_data/Linepithema_humile_sample.fasta,Pogonomyrmex_barbatus:test_data/Pogonomyrmex_barbatus_sample.fasta,Solenopsis_invicta:test_data/Solenopsis_invicta_sample.fasta

It should be finshed after some minutes, telling you where you can find a result
table. If that happens and the result table is filled with values 
everything is fine.

