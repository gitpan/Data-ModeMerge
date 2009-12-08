#!perl -T

use strict;
use warnings;
use Test::More tests => 31;

use lib './t';
require 'testlib.pm';

use Data::ModeMerge;

merge_fail({''=>1 }, {}, 'invalid type 1');
merge_fail({''=>[]}, {}, 'invalid type 2');
merge_fail({}, {''=>1 }, 'invalid type 3');
merge_fail({}, {''=>[]}, 'invalid type 4');
merge_fail({''=>{}}, {''=>1 }, 'invalid type 5');
merge_fail({''=>{}}, {''=>[]}, 'invalid type 6');

merge_fail ({''=>{x=>1}}, {''=>{}}, 'unknown config');
merge_fail ({''=>{wanted_path=>["x"]}}, {''=>{}}, 'allowed in merger config only: wanted_path');
merge_fail ({''=>{options_key=>"x"}}, {''=>{}}, 'allowed in merger config only: options_key');
merge_fail ({''=>{allow_override=>["x"]}}, {''=>{}}, 'allowed in merger config only: allow_override');
merge_fail ({''=>{disallow_override=>["x"]}}, {''=>{}}, 'allowed in merger config only: disallow_override');

mmerge_fail({''=>{allow_create_hash=>0 }}, {''=>{}}, {disallow_override=>qr/^allow_create/}, 'disallow_override 1');
mmerge_ok  ({''=>{allow_destroy_hash=>0}}, {''=>{}}, {disallow_override=>qr/^allow_create/}, 'disallow_override 2');

mmerge_fail({''=>{allow_destroy_hash=>0}}, {''=>{}}, {allow_override=>qr/^allow_create/}, 'allow_override 1');
mmerge_ok  ({''=>{allow_create_hash=>0 }}, {''=>{}}, {allow_override=>qr/^allow_create/}, 'allow_override 2');

mmerge_fail({''=>{allow_destroy_array=>0}}, {''=>{}}, {allow_override=>qr/^allow_create/, disallow_override=>qr/hash/}, 'allow_override+disallow_override 1');
mmerge_fail({''=>{allow_create_hash=>0  }}, {''=>{}}, {allow_override=>qr/^allow_create/, disallow_override=>qr/hash/}, 'allow_override+disallow_override 2');
mmerge_ok  ({''=>{allow_create_array=>0 }}, {''=>{}}, {allow_override=>qr/^allow_create/, disallow_override=>qr/hash/}, 'allow_override+disallow_override 3');

merge_fail({a=>1, b=>2, ''=>{exclude_merge_regex=>'(a' }}, {a=>10, b=>20}, 'invalid value 1');
merge_is  ({a=>1, b=>2, ''=>{exclude_merge_regex=>'(a)'}}, {a=>10, b=>20}, {a=>1, b=>20}, 'invalid value 2');

merge_is({a=>1, b=>2, ''=>{  exclude_merge_regex =>'a'}}, {a=>10, b=>20, ''=>{  exclude_merge_regex =>'b'}}, {a=>10, b=>2 }, 'merging 1');
merge_is({a=>1, b=>2, ''=>{"^exclude_merge_regex"=>'a'}}, {a=>10, b=>20, ''=>{  exclude_merge_regex =>'b'}}, {a=>1 , b=>20}, 'merging 2');
merge_is({a=>1, b=>2, ''=>{ "exclude_merge_regex"=>'a'}}, {a=>10, b=>20, ''=>{"!exclude_merge_regex"=>'b'}}, {a=>10, b=>20}, 'merging 3');

merge_fail({''=>{'+exclude_merge'=>'a'}},
           {''=>{'.exclude_merge'=>'a'}}, 'merging failed');

mmerge_is({a=>1, b=>2, ''=>{exclude_merge_regex =>'a'}          }, {a=>10, b=>20}, undef               , {a=>1 , b=>20       }, 'change ok 1');
mmerge_is({a=>1, b=>2, ''=>3, 'foo'=>{exclude_merge_regex =>'a'}}, {a=>10, b=>20}, {options_key=>'foo'}, {a=>1 , b=>20, ''=>3}, 'change ok 2');
mmerge_is({a=>1, b=>2, ''=>{exclude_merge_regex =>'a'}          }, {a=>10, b=>20}, {options_key=>undef}, {a=>10, b=>20, ''=>{exclude_merge_regex=>'a'}}, 'disable ok');

merge_ok({''=>{}}, {''=>{}}, 'valid 1');

my $h1 = { 'a'=> 1,  'c'=> 2,  'd'=> 3,  'k'=> 4,  'n'=> 5, 'n2'=> 5,  's'=> 6};
my $h2 = {'+a'=>10, '.c'=>20, '!d'=>30, '^k'=>40, '*n'=>50, 'n2'=>50, '-s'=>60};

merge_is ($h1                                   , $h2, {a=>11, c=>220, "^k"=>40, n=>50, n2=>50, s=>-54}, "ok none");
merge_is ({%$h1, ''=>{disable_modes=>[qw/ADD/]}}, $h2, {a=>1, '+a'=>10, c=>220, "^k"=>40, n=>50, n2=>50, s=>-54}, "ok disable_modes");
merge_is ({a=>{a2=>1}, ''=>{recurse_hash=>0}}   , {a=>{".a2"=>2}}, {a=>{".a2"=>2}}, "ok recurse_hash");
# XXX ok recurse_array, etc

# XXX recursive
