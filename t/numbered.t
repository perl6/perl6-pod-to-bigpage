use v6;
use Test;
use Pod::To::BigPage;

plan 1;

=begin pod

=for item1 :numbered
Visito

=for item2 :numbered
Veni

=for item2 :numbered
Vidi

=for item2 :numbered
Vici

=for item1 :numbered
Wisito

=for item2 :numbered
Weni

=for item2 :numbered
Widi

=for item2 :numbered
Wici

=end pod

put $=pod>>.&handle(part-number => 1);
