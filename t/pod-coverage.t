use strict;
use warnings;
use Test::More tests => 8;
use Pod::Coverage;
use Test::Pod::Coverage;

my $MM = "Data::ModeMerge";
pod_coverage_ok("Data::ModeMerge", { also_private => [ qr/^(BUILD)$/ ], }, $MM);

pod_coverage_ok("Data::ModeMerge", { also_private => [ qr/^(BUILD)$/ ], }, "${MM}::Config");

# XXX Mode::Base
for (qw(ADD CONCAT DELETE KEEP NORMAL SUBTRACT)) {
    pod_coverage_ok("Data::ModeMerge", { also_private => [ qr/^(BUILD|merge_[A-Z_].*)$/ ], }, "${MM}::Mode::$_");
}
