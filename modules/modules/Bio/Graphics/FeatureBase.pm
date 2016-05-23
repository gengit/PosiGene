package Bio::Graphics::FeatureBase;

=head1 NAME

Bio::Graphics::FeatureBase - Compatibility module

=head1 SYNOPSIS

This module has been replaced by Bio::SeqFeature::Lite but exists
only for compatibility with legacy applications.

=cut

use strict;

use base 'Bio::SeqFeature::Lite';
1;

__END__

=head1 SEE ALSO

L<Bio::Graphics::Feature>, L<Bio::Graphics::FeatureFile>,
L<Bio::Graphics::Panel>,L<Bio::Graphics::Glyph>, L<GD>

=head1 AUTHOR

Lincoln Stein E<lt>lstein@cshl.orgE<gt>.

Copyright (c) 2006 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut
