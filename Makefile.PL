
use strict;
use warnings;

 BEGIN { require 5.010000; } 

use ExtUtils::MakeMaker;

WriteMakefile(
  DISTNAME  => 'Data-ModeMerge',
  NAME      => 'Data::ModeMerge',
  AUTHOR    => "Steven\ Haryanto\ \<stevenharyanto\@gmail\.com\>",
  ABSTRACT  => "Merge\ two\ nested\ data\ structures\,\ with\ merging\ modes\ and\ options",
  VERSION   => '0.20',
  EXE_FILES => [ qw() ],
  (eval { ExtUtils::MakeMaker->VERSION(6.31) } ? (LICENSE => 'perl') : ()),
  PREREQ_PM    => {
    "Test::More" => '0',
    "Pod::Coverage" => '0.18',
    "Regexp::Copy" => '0',
    "Test::Pod::Coverage" => '1.08',
    "Test::Aggregate" => '0',
    "Storable" => '0',
    "Moose" => '0',
  },
  test => {TESTS => 't/*.t'}
);

