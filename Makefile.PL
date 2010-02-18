
use strict;
use warnings;

 BEGIN { require 5.010000; } 

use ExtUtils::MakeMaker;

WriteMakefile(
  DISTNAME  => 'Data-ModeMerge',
  NAME      => 'Data::ModeMerge',
  AUTHOR    => "Steven\ Haryanto\ \<stevenharyanto\@gmail\.com\>",
  ABSTRACT  => "Merge\ two\ nested\ data\ structures\,\ with\ merging\ modes\ and\ options",
  VERSION   => '0.23',
  EXE_FILES => [ qw() ],
  (eval { ExtUtils::MakeMaker->VERSION(6.31) } ? (LICENSE => 'perl') : ()),
  PREREQ_PM    => {
    "Pod::Coverage" => '0.18',
    "Test::Pod::Coverage" => '1.08',
    "Test::Aggregate" => '0',
    "Test::More" => '0',
    "Mouse" => '0',
    "Any::Moose" => '0',
    "Clone" => '0',
  },
  test => {TESTS => 't/*.t'}
);

