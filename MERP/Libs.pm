package MERP::Libs;
use warnings;
use strict;

use Exporter qw(import);
our @EXPORT    = qw(looks_like_num looks_like_positive_num trim);
our @EXPORT_OK = qw(looks_like_num looks_like_positive_num trim);

sub looks_like_num {
	my $num = shift;
	return 1 if $num =~ /^[0-9]+$/;
}
sub looks_like_positive_num {
	my $num = shift;
	return 1 if looks_like_num( $num ) && $num >= 0;
}
sub trim {
	my $str = shift or return undef;
	$str =~ s/(^\s*|\s*$)//g;
	return $str;
}

1;
