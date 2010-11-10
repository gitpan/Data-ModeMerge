
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  'build_requires' => {
    'Module::Build' => '0.3601'
  },
  'configure_requires' => {
    'Module::Build' => '0.3601'
  },
  'dist_abstract' => 'Merge two nested data structures, with merging modes and options',
  'dist_author' => [
    'Steven Haryanto <stevenharyanto@gmail.com>'
  ],
  'dist_name' => 'Data-ModeMerge',
  'dist_version' => '0.25',
  'license' => 'perl',
  'module_name' => 'Data::ModeMerge',
  'recommends' => {},
  'recursive_test_files' => 1,
  'requires' => {
    'Any::Moose' => '0',
    'Clone' => '0',
    'Clone::Any' => '0',
    'Mouse' => '0',
    'Test::Aggregate' => '0',
    'perl' => '5.010000'
  },
  'script_files' => []
);


my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
