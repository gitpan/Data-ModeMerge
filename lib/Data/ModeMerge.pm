package Data::ModeMerge;
our $VERSION = '0.13';


# ABSTRACT: Merge two nested data structures, with merging modes and options


use Moose;
use Data::ModeMerge::Config;
use Data::Dumper;
use Storable qw/freeze/;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(mode_merge);


sub mode_merge {
    my ($l, $r, $config_vars) = @_;
    my $mm = __PACKAGE__->new(config => $config_vars);
    $mm->merge($l, $r);
}



has config => (is => "rw");

has config_stack => (is => "rw");

# hash of modename => handler
has modes => (is => 'rw', default => sub { {} });

has combine_rules => (is => 'rw');

# merging process state
has path => (is => "rw", default => sub { [] });
has errors => (is => "rw", default => sub { [] });


sub _dump {
    my ($self, $var) = @_;
    Data::Dumper->new([$var])->Indent(0)->Terse(1)->Dump;
}

sub _in($$) {
    my ($self, $needle, $haystack) = @_;
    my $r1 = ref($needle);
    my $f1 = $r1 ? freeze($needle) : undef;
    for (@$haystack) {
        my $r2 = ref($_);
        next if $r1 xor $r2;
        return 1 if  $r2 && $f1 eq freeze($_);
        return 1 if !$r2 && $needle eq $_;
    }
    0;
}

sub BUILD {
    my ($self, $args) = @_;

    if ($self->config) {
        # some sanity checks
        my $is_hashref = ref($self->config) eq 'HASH';
        die "config must be a hashref or a Data::ModeMerge::Config" unless
            $is_hashref || UNIVERSAL::isa($self->config, "Data::ModeMerge::Config");
        $self->config(Data::ModeMerge::Config->new(%{ $self->config })) if $is_hashref;
    } else {
        $self->config(Data::ModeMerge::Config->new);
    }

    for (qw(NORMAL KEEP ADD CONCAT SUBTRACT DELETE)) {
	$self->register_mode($_);
    }

    if (!$self->combine_rules) {
        $self->combine_rules({
            # "left + right" => [which mode to use, which mode after merge]
            'ADD+ADD'            => ['ADD'     , 'ADD'   ],
            #'ADD+CONCAT'         => undef,
            'ADD+DELETE'         => ['DELETE'  , 'DELETE'],
            #'ADD+KEEP'           => undef,
            'ADD+NORMAL'         => ['NORMAL'  , 'NORMAL'],
            'ADD+SUBTRACT'       => ['SUBTRACT', 'ADD'   ],

            #'CONCAT+ADD'         => undef,
            'CONCAT+CONCAT'      => ['CONCAT'  , 'CONCAT'],
            'CONCAT+DELETE'      => ['DELETE'  , 'DELETE'],
            #'CONCAT+KEEP'        => undef,
            'CONCAT+NORMAL'      => ['NORMAL'  , 'NORMAL'],
            #'CONCAT+SUBTRACT'    => undef,

            'DELETE+ADD'         => ['NORMAL'  , 'ADD'     ],
            'DELETE+CONCAT'      => ['NORMAL'  , 'CONCAT'  ],
            'DELETE+DELETE'      => ['DELETE'  , 'DELETE'  ],
            'DELETE+KEEP'        => ['NORMAL'  , 'KEEP'    ],
            'DELETE+NORMAL'      => ['NORMAL'  , 'NORMAL'  ],
            'DELETE+SUBTRACT'    => ['NORMAL'  , 'SUBTRACT'],

            'KEEP+ADD'          => ['KEEP', 'KEEP'],
            'KEEP+CONCAT'       => ['KEEP', 'KEEP'],
            'KEEP+DELETE'       => ['KEEP', 'KEEP'],
            'KEEP+KEEP'         => ['KEEP', 'KEEP'],
            'KEEP+NORMAL'       => ['KEEP', 'KEEP'],
            'KEEP+SUBTRACT'     => ['KEEP', 'KEEP'],

            'NORMAL+ADD'        => ['ADD'     , 'NORMAL'],
            'NORMAL+CONCAT'     => ['CONCAT'  , 'NORMAL'],
            'NORMAL+DELETE'     => ['DELETE'  , 'NORMAL'],
            'NORMAL+KEEP'       => ['NORMAL'  , 'KEEP'  ],
            'NORMAL+NORMAL'     => ['NORMAL'  , 'NORMAL'],
            'NORMAL+SUBTRACT'   => ['SUBTRACT', 'NORMAL'],

            'SUBTRACT+ADD'      => ['SUBTRACT', 'SUBTRACT'],
            #'SUBTRACT+CONCAT'   => undef,
            'SUBTRACT+DELETE'   => ['DELETE'  , 'DELETE'  ],
            #'SUBTRACT+KEEP'     => undef,
            'SUBTRACT+NORMAL'   => ['NORMAL'  , 'NORMAL'  ],
            'SUBTRACT+SUBTRACT' => ['ADD'     , 'SUBTRACT'],
        });
    }
}


sub push_error {
    my ($self, $errmsg) = @_;
    push @{ $self->errors }, [[@{ $self->path }], $errmsg];
    return;
}


sub register_mode {
    my ($self, $name0) = @_;
    my $obj;
    if (ref($name0)) {
        my $obj = $name0;
    } elsif ($name0 =~ /^\w+(::\w+)+$/) {
        eval "require $name0; \$obj = new $name0";
        die "Can't load module $name0: $@" if $@;
    } elsif ($name0 =~ /^\w+$/) {
        my $modname = "Data::ModeMerge::Mode::$name0";
        eval "require $modname; \$obj = new $modname";
        die "Can't load module $modname: $@" if $@;
    } else {
        die "Invalid mode name $name0";
    }
    my $name = $obj->name;
    die "Mode $name already registered" if $self->modes->{$name};
    $obj->merger($self);
    $self->modes->{$name} = $obj;
}


sub check_prefix {
    my ($self, $hash_key) = @_;
    die "Hash key not a string" if ref($hash_key);
    my $dis = $self->config->disable_modes;
    if (defined($dis) && ref($dis) ne 'ARRAY') {
        $self->push_error("Invalid config value `disable_modes`: must be an array");
        return;
    }
    for my $mh (sort { $b->precedence_level <=> $a->precedence_level }
                grep { !$dis || !$self->_in($_->name, $dis) }
                values %{ $self->modes }) {
        if ($mh->check_prefix($hash_key)) {
            return $mh->name;
        }
    }
    return;
}


sub check_prefix_on_hash {
    my ($self, $hash) = @_;
    die "Not a hash" unless ref($hash) eq 'HASH';
    for (keys %$hash) {
	return 1 if $self->check_prefix($_);
    }
    0;
}


sub add_prefix {
    my ($self, $hash_key, $mode) = @_;
    die "Hash key not a string" if ref($hash_key);
    my $dis = $self->config->disable_modes;
    if (defined($dis) && ref($dis) ne 'ARRAY') {
        die "Invalid config value `disable_modes`: must be an array";
    }
    if ($dis && $self->_in($mode, $dis)) {
        $self->push_error("Can't add prefix for currently disabled mode `$mode`");
        return $hash_key;
    }
    my $mh = $self->modes->{$mode} or die "Unknown mode: $mode";
    $mh->add_prefix($hash_key);
}


sub remove_prefix {
    my ($self, $hash_key) = @_;
    die "Hash key not a string" if ref($hash_key);
    my $dis = $self->config->disable_modes;
    if (defined($dis) && ref($dis) ne 'ARRAY') {
        die "Invalid config value `disable_modes`: must be an array";
    }
    for my $mh (sort { $b->precedence_level <=> $a->precedence_level }
                grep { !$dis || !$self->_in($_->name, $dis) }
                values %{ $self->modes }) {
        if ($mh->check_prefix($hash_key)) {
            my $r = $mh->remove_prefix($hash_key);
            if (wantarray) { return ($r, $mh->name) }
            else           { return $r }
        }
    }
    if (wantarray) { return ($hash_key, $self->config->default_mode) }
    else           { return $hash_key }
}


sub remove_prefix_on_hash {
    my ($self, $hash) = @_;
    die "Not a hash" unless ref($hash) eq 'HASH';
    for (keys %$hash) {
	my $old = $_;
	$_ = $self->remove_prefix($_);
	next unless $old ne $_;
	die "Conflict when removing prefix on hash: $old -> $_ but $_ already exists"
	    if exists $hash->{$_};
	$hash->{$_} = $hash->{$old};
	delete $hash->{$old};
    }
    $hash;
}


sub save_config {
    my ($self) = @_;
    my %config = %{ $self->config() };
    push @{ $self->config_stack }, \%config;
}


sub restore_config {
    my ($self) = @_;
    my $config = pop @{ $self->config_stack };
    $self->config($config);
}


sub merge {
    my ($self, $l, $r) = @_;
    $self->config_stack([]);
    $self->path([]);
    $self->errors([]);
    my ($key, $res, $backup) = $self->_merge(undef, $l, $r);
    {
        success => !@{ $self->errors },
        error   => (@{ $self->errors } ?
                    join(", ",
                         map { sprintf("/%s: %s", join("/", @{ $_->[0] }), $_->[1]) }
                             @{ $self->errors }) : ''),
        result  => $res,
        backup  => $backup,
    };
}

sub _merge {
    my ($self, $key, $l, $r, $mode) = @_;
    my $c = $self->config;
    $mode //= $c->default_mode;

    my $mh = $self->modes->{$mode};
    die "Can't find handler for mode $mode" unless $mh;

    # determine which merge method we will call
    my $ra = ref($l);
    my $rb = ref($r);
    my $ta = $ra eq 'HASH' ? 'HASH' : $ra eq 'ARRAY' ? 'ARRAY' : !$ra ? 'SCALAR' : '';
    my $tb = $rb eq 'HASH' ? 'HASH' : $rb eq 'ARRAY' ? 'ARRAY' : !$rb ? 'SCALAR' : '';
    if (!$ta) { $self->push_error("Unknown type in left side: $ta"); return }
    if (!$tb) { $self->push_error("Unknown type in right side: $tb"); return }
    if (!$c->allow_create_array && $ta ne 'ARRAY' && $tb eq 'ARRAY') {
        $self->push_error("Not allowed to create array"); return;
    }
    if (!$c->allow_create_hash && $ta ne 'HASH' && $tb eq 'HASH') {
        $self->push_error("Not allowed to create hash"); return;
    }
    if (!$c->allow_destroy_array && $ta eq 'ARRAY' && $tb ne 'ARRAY') {
        $self->push_error("Not allowed to destroy array"); return;
    }
    if (!$c->allow_destroy_hash && $ta eq 'HASH' && $tb ne 'HASH') {
        $self->push_error("Not allowed to destroy hash"); return;
    }
    my $meth = "merge_${ta}_${tb}";
    if ($self->can($meth)) { $self->push_error("No merge method found for $ta + $tb (mode $mode)"); return }
    $mh->$meth($key, $l, $r);
}

# returns 1 if a is included in b (e.g. [user => "steven"] in included in [user
# => steven => "quota"], but [user => "rudi"] is not)
sub _path_is_included {
    my ($self, $p1, $p2) = @_;
    my $res = 1;
    for my $i (0..@$p1-1) {
        do { $res = 0; last } if !defined($p2->[$i]) || $p1->[$i] ne $p2->[$i];
    }
    #print "_path_is_included([".join(", ", @$p1)."], [".join(", ", @$p2)."])? $res\n";
    $res;
}


__PACKAGE__->meta->make_immutable;
1;

__END__
=pod

=head1 NAME

Data::ModeMerge - Merge two nested data structures, with merging modes and options

=head1 VERSION

version 0.13

=head1 SYNOPSIS

    use Data::ModeMerge;


    # OO interface

    my $mm = Data::ModeMerge->new();

    # setting config
    $mm->config->allow_destroy_hash(0);

    my $hash1 = { a=>1,    c=>1, d=>{  da =>[1]} };
    my $hash2 = { a=>2, "-c"=>2, d=>{"+da"=>[2]} };

    # doing merge
    my $res = $mm->merge($hash1, $hash2);

    die $res->{error} if $res->{error};
    print $res->{result}; # { a=>2, c=>-1, d => { da=>[1,2] } }


    # procedural interface

    # doing merge (with optional custom config)
    my $res = mode_merge($hash1, $hash2, {allow_destroy_hash=>0});

    die $res->{error} if $res->{error};
    print $res->{result}; # { a=>2, c=>-1, d => { da=>[1,2] } }

=head1 DESCRIPTION

There are already several modules on CPAN to do recursive data
structure merging, like L<Data::Merger> and
L<Hash::Merge>. C<Data::ModeMerge> differs in that it offers merging
"modes" and "options". It provides greater flexibility on what the
result of a merge between two data should/can be. This module may or
may not be what you need.

One application of this module is in handling configuration. Often
there are multiple levels of configuration, e.g. in your typical Unix
command-line program there are system-wide config file in /etc,
per-user config file under ~/, and command-line options. It's
convenient programatically to load each of those in a hash and then
merge system-wide hash with the per-user hash, and then merge the
result with the command-line hash to get the a single hash as the
final configuration. Your program can from there on deal with this
just one hash instead of three.

In a typical merging process between two hashes (left-side and
right-side), when there is a conflicting key, then the right-side key
will override the left-side. This is usually the desired behaviour in
our said program as the system-wide config is there to provide
defaults, and the per-user config (and the command-line arguments)
allow a user to override those defaults.

But suppose that the user wants to I<unset> a certain configuration
setting that is defined by the system-wide config? She can't do that
unless she edits the system-wide config (in which she might need admin
rights), or the program allows the user to disregard the system-wide
config. The latter is usually what's implemented by many Unix
programs, e.g. the C<-noconfig> command-line option in C<mplayer>. But
this has two drawbacks: a slightly added complexity in the program
(need to provide a special, extra comand-line option) and the user
loses all the default settings in the system-wide config. What she
needed in the first place was to just unset I<a single setting> (a
single key-value pair of the hash).

L<Data::ModeMerge> comes to the rescue. It provides a so-called
C<DELETE mode>.

 mode_merge({foo=>1, bar=>2}, {"!foo"=>undef, bar=>3, baz=>1});

will result ini:

 {bar=>3, baz=>1}

The C<!> prefix tells Data::ModeMerge to do a DELETE mode merging. So
the final result will lack the C<foo> key.

On the other hand, what if the system admin wants to I<protect> a
certain configuration setting from being overriden by the user or the
command-line? This is useful in a hosting or other retrictive
environment where we want to limit users' freedom to some levels. This
is possible via the KEEP mode merging.

 mode_merge({"^bar"=>2, "^baz"=>1}, {bar=>3, "!baz"=>0, quux=>7});

will result in:

 {bar=>2, baz=>1, quux=>7}

effectively protecting C<bar> and C<baz> from being
overriden/deleted/etc.

Aside from the two mentioned modes, there are also a few others
available by default: ADD (prefix C<+>), CONCAT (prefix C<.>),
SUBTRACT (prefix C<->), as well as the plain ol' NORMAL/override
(optional prefix C<*>).

You can add other modes by writing a mode handler module.

You can change the default prefixes for each mode if you want. You can
disable each mode individually.

You can default to always using a certain mode, like the NORMAL mode,
and ignore all the prefixes, in which case Data::ModeMerge will behave
like most other merge modules.

There are a few other options like whether or not the right side is
allowed a "change the structure" of the left side (e.g. replacing a
scalar with an array/hash, destroying an existing array/hash with
scalar), maximum length of scalar/array/hash, etc.

You can change default mode, prefixes, disable/enable modes, etc on a
per-hash basis using the so-called B<options key>. See the B<OPTIONS
KEY> section for more details.

=head1 MERGING PREFIXES AND YOUR DATA

Merging with this module means you need to be careful when your hash
keys might contain one of the mode prefixes characters by accident,
because it will trigger the wrong merge mode and moreover the prefix
characters will be B<stripped> from the final result (unless you
configure the module not to do so).

A rather common case is when you have regexes in your hash
keys. Regexes often begins with C<^>, which coincidentally is a prefix
for the KEEP mode. Or perhaps you have dot filenames as hash keys,
where it clashes with the CONCAT mode. Or perhaps shell wildcards,
where C<*> is also used as the prefix for NORMAL mode.

To avoid clashes, you can either:

=over 4

=item * exclude the keys using
C<exclude_merge>/C<include_merge>/C<exclude_parse>/C<include_parse>
config settings

=item * turn off some modes which you don't want via the
C<disable_modes> config

=item * change the prefix for that mode so that it doesn't clash with
your data via the C<NORMAL>, C<KEEP>, etc config

=item * disable prefix parsing altogether via setting C<parse_prefix>
config to 0

You can do this via the configuration, or on a per-hash basis, using
the options key.

=back

=head1 MERGING MODES

=head2 NORMAL (optional '*' prefix on left/right side)

 mode_merge({ a=>11, b=>12},  {b=>22, c=>23}); # {a=>11, b=>22, c=>23}
 mode_merge({*a=>11, b=>12}, {*b=>22, c=>23}); # {a=>11, b=>22, c=>23}

=head2 ADD ('+' prefix on the right side)

 mode_merge({i=>3}, {"+i"=>4, "+j"=>1}); # {i=>7, j=>1}
 mode_merge({a=>[1]}, {"+a"=>[2, 3]}); # {a=>[1, 2, 3]}

Additive merge on hashes will be treated like a normal merge.

=head2 CONCAT ('.' prefix on the right side)

 mode_merge({i=>3}, {".i"=>4, ".j"=>1}); # {i=>34, j=>1}

Concative merge on arrays will be treated like additive merge.

=head2 SUBTRACT ('-' prefix on the right side)

 mode_merge({i=>3}, {"-i"=>4}); # {i=>-1}
 mode_merge({a=>["a","b","c"]}, {"-a"=>["b"]}); # {a=>["a","c"]}

Subtractive merge on hashes is not defined.

=head2 DELETE ('!' prefix on the right side)

 mode_merge({x=>WHATEVER}, {"!x"=>WHATEVER}); # {}

=head2 KEEP ('^' prefix on the left/right side)

If you add '^' prefix on the left side, it will be protected from
being replaced/deleted/etc.

 mode_merge({'^x'=>WHATEVER1}, {"x"=>WHATEVER2}); # {x=>WHATEVER1}

For hashes, KEEP mode means that all keys on the left side will not be
replaced/modified/deleted, *but* you can still add more keys from the
right side hash.

 mode_merge({a=>1, b=>2, c=>3},
            {a=>4, '^c'=>1, d=>5},
            {default_mode=>'KEEP'});
            # {a=>1, b=>2, c=>3, d=>5}

Multiple prefixes on the right side is allowed, where the merging will
be done by precedence level (highest first):

 mode_merge({a=>[1,2]}, {'-a'=>[1], '+a'=>[10]}, {a=>3}); # error!

but not on the left side:

 mode_merge({a=>1, '^a'=>2}, {a=>3}); # error!

=head1 FUNCTIONS

=head2 mode_merge($l, $r[, $config_vars])

A non-OO wrapper for merge() method. Exported by default. See C<merge>
method for more details.

=head1 ATTRIBUTES

=head2 config

A hashref for config. See L<Data::ModeMerge::Config>.

=head1 METHODS

=head2 push_error($errmsg)

Used by mode handlers to push error when doing merge. End users
normally should not need this.

=head2 register_mode($name_or_package_or_obj)

Register a mode. Will die if mode with the same name already exists.

=head2 check_prefix($hash_key)

Check whether hash key has prefix for certain mode. Return the name of
the mode, or undef if no prefix is detected.

=head2 check_prefix_on_hash($hash)

This is like C<check_prefix> but performed on every key of the
specified hash. Return true if any of the key contain a merge prefix.

=head2 add_prefix($hash_key, $mode)

Return hash key with added prefix with specified mode. Log merge error
if mode is unknown or is disabled.

=head2 remove_prefix($hash_key)

Return hash key will any prefix removed.

=head2 remove_prefix_on_hash($hash)

This is like C<remove_prefix> but performed on every key of the
specified hash. Return the same hash but with prefixes removed.

=head2 save_config()

Called by mode handlers to save configuration before recursive
merge. This is because many configuration settings can be overriden by
options key.

=head2 restore_config()

Called by mode handlers to restore configuration saved by
save_config().

=head2 merge($l, $r)

Merge two nested data structures. Returns the result hash: {
success=>0|1, error=>'...', result=>..., backup=>... }. The 'error'
key is set to contain an error message if there is an error. The merge
result is in the 'result' key. The 'backup' key contains replaced
elements from the original hash/array.

=head1 CREATING AND USING YOUR OWN MODE

Let's say you want to add a mode named C<FOO>. It will have the prefix
'?'.

Create the mode handler class,
e.g. C<Data::ModeMerge::Mode::FOO>. It's probably best to subclass
from L<Data::ModeMerge::Mode::Base>. The class must implement name(),
precedence_level(), and
merge_{SCALAR,ARRAY,HASH}_{SCALAR,ARRAY,HASH}(). If you subclass from
Base, you'll only need to set prefix to '?' and prefix_re to qr/^\?/
in your BUILD, otherwise you'll need to implement your own
add_prefix() and remove_prefix(). See example in Base.pm and one of
the modes (e.g. NORMAL.pm).

To use the mode, register it:

 my $mm = Data::ModeMerge->new;
 $mm->register_mode('FOO');

This will require C<Data::ModeMerge::Mode::FOO>. After that, define
the operations against other modes:

 # if there's FOO on the left and NORMAL on the right, what mode
 # should the merge be done in (FOO), and what the mode should be
 # after the merge? (NORMAL)
 $mm->combine_rules->{"FOO+NORMAL"} = ["FOO", "NORMAL"];

 # we don't define FOO+ADD

 $mm->combine_rules->{"FOO+KEEP"} = ["KEEP", "KEEP"];

 # and so on

=head1 SEE ALSO

L<Data::ModeMerge::Config>

Other merging modules on CPAN: L<Data::Merger> (from Data-Utilities),
L<Hash::Merge>, L<Hash::Merge::Simple>

L<Data::Schema> and L<Config::Tree> (among others, two modules which
use Data::ModeMerge)

L<Data::PrefixMerge> is the old name for this module.

=head1 BUGS

Please report any bugs or feature requests to C<bug-data-modemerge
at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Data-ModeMerge>.  I
will be notified, and then you'll automatically be notified of
progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Data::ModeMerge

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Data-ModeMerge>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Data-ModeMerge>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Data-ModeMerge>

=item * Search CPAN

L<http://search.cpan.org/dist/Data-ModeMerge/>

=back

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

