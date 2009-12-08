package Data::ModeMerge::Mode::Base;
our $VERSION = '0.13';


# ABSTRACT: Base class for Data::ModeMerge mode handler


use Moose;
use Storable qw/dclone/;


has merger => (is => 'rw');
has prefix => (is => 'rw');
has prefix_re => (is => 'rw');
has check_prefix_sub => (is => 'rw');
has add_prefix_sub => (is => 'rw');
has remove_prefix_sub => (is => 'rw');



sub name {
    die "Subclass must provide name()";
}


sub precedence_level {
    die "Subclass must provide precedence_level()";
}


sub default_prefix {
    die "Subclass must provide default_prefix()";
}


sub default_prefix_re {
    die "Subclass must provide default_prefix_re()";
}

sub BUILD {
    my ($self) = @_;
    $self->prefix($self->default_prefix);
    $self->prefix_re($self->default_prefix_re);
}


sub check_prefix {
    my ($self, $hash_key) = @_;
    if ($self->check_prefix_sub) {
        $self->check_prefix_sub->($hash_key);
    } else {
        $hash_key =~ $self->prefix_re;
    }
}


sub add_prefix {
    my ($self, $hash_key) = @_;
    if ($self->add_prefix_sub) {
        $self->add_prefix_sub->($hash_key);
    } else {
        $self->prefix . $hash_key;
    }
}


sub remove_prefix {
    my ($self, $hash_key) = @_;
    if ($self->remove_prefix_sub) {
        $self->remove_prefix_sub->($hash_key);
    } else {
        my $re = $self->prefix_re;
        $hash_key =~ s/$re//;
        $hash_key;
    }
}

sub merge_ARRAY_ARRAY {
    my ($self, $key, $l, $r) = @_;
    my $mm = $self->merger;
    my $c = $mm->config;
    return $self->merge_SCALAR_SCALAR($key, $l, $r) unless $c->recurse_array;
    return if $c->wanted_path && !$mm->_path_is_included($mm->path, $c->wanted_path);

    my @res;
    my @backup;
    my $la = @$l;
    my $lb = @$r;
    push @{ $mm->path }, -1;
    for my $i (0..($la > $lb ? $la : $lb)-1) {
        #print "DEBUG: merge_A_A: #$i: a->[$i]=".Data::Dumper->new([$l->[$i]])->Indent(0)->Terse(1)->Dump.", b->[$i]=".Data::Dumper->new([$r->[$i]])->Indent(0)->Terse(1)->Dump."\n";
        $mm->path->[-1] = $i;
        if ($i < $la && $i < $lb) {
            push @backup, $l->[$i];
            my ($newkey, $res2, $backup2) = $mm->_merge($i, $l->[$i], $r->[$i], $c->default_mode);
            last if @{ $mm->errors };
            push @res, $res2;# if defined($newkey); = we allow DELETE on array?
        } elsif ($i < $la) {
            push @res, $l->[$i];
        } else {
            push @res, $r->[$i];
        }
    }
    pop @{ $mm->path };
    ($key, \@res, \@backup);
}

# turn {[prefix]key => val, ...} into { key => [MODE, val], ...}, push
# error if there's conflicting key
sub _gen_left {
    my ($self, $l, $mode, $esub, $ep, $ip, $epr, $ipr) = @_;
    my $mm = $self->merger;
    my $c = $mm->config;

    #print "DEBUG: Entering _gen_left(".$mm->_dump($l).", $mode, ep=$ep, ip=$ip, epr=$epr, ipr=$ipr)\n";
    my $hl = {};
    if ($c->parse_prefix) {
        for (keys %$l) {
            my $do_parse = 1;
            $do_parse = 0 if $do_parse && $ep  &&  $mm->_in($_, $ep);
            $do_parse = 0 if $do_parse && $ip  && !$mm->_in($_, $ip);
            $do_parse = 0 if $do_parse && $epr &&  /$epr/;
            $do_parse = 0 if $do_parse && $ipr && !/$ipr/;

            if ($do_parse) {
                my $old = $_;
                my $m2;
                ($_, $m2) = $mm->remove_prefix($_);
                next if $esub && !$esub->($_);
                if ($old ne $_ && exists($l->{$_})) {
                    $mm->push_error("Conflict when removing prefix on left-side ".
                                    "hash key: $old -> $_ but $_ already exists");
                    return;
                }
                $hl->{$_} = [$m2, $l->{$old}];
            } else {
                $hl->{$_} = [$mode, $l->{$_}];
            }
        }
    } else {
        for (keys %$l) {
            next if $esub && !$esub->($_);
            $hl->{$_} = [$mode, $l->{$_}];
        }
    }
    $hl;
}

# turn {[prefix]key => val, ...} into { key => {MODE=>val, ...}, ...},
# push error if there's conflicting key+MODE
sub _gen_right {
    my ($self, $r, $mode, $esub, $ep, $ip, $epr, $ipr) = @_;
    my $mm = $self->merger;
    my $c = $mm->config;

    #print "DEBUG: Entering _gen_right(".$mm->_dump($r).", $mode, ep=$ep, ip=$ip, epr=$epr, ipr=$ipr)\n";
    my $hr = {};
    if ($c->parse_prefix) {
        for (keys %$r) {
            my $do_parse = 1;
            $do_parse = 0 if $do_parse && $ep  &&  $mm->_in($_, $ep);
            $do_parse = 0 if $do_parse && $ip  && !$mm->_in($_, $ip);
            $do_parse = 0 if $do_parse && $epr &&  /$epr/;
            $do_parse = 0 if $do_parse && $ipr && !/$ipr/;

            if ($do_parse) {
                my $old = $_;
                my $m2;
                ($_, $m2) = $mm->remove_prefix($_);
                next if $esub && !$esub->($_);
                if (exists $hr->{$_}{$m2}) {
                    $mm->push_error("Conflict when removing prefix on right-side ".
                                    "hash key: $old($m2) -> $_ ($m2) but $_ ($m2) ".
                                    "already exists");
                    return;
                }
                $hr->{$_}{$m2} = $r->{$old};
            } else {
                $hr->{$_} = {$mode => $r->{$_}};
            }
        }
    } else {
        for (keys %$r) {
            next if $esub && !$esub->($_);
            $hr->{$_} = {$mode => $r->{$_}}
        }
    }
    $hr;
}

# merge two hashes which have been prepared by _gen_left and
# _gen_right, will result in { key => [final_mode, val], ... }
sub _merge_gen {
    my ($self, $hl, $hr, $mode, $em, $im, $emr, $imr) = @_;
    my $mm = $self->merger;
    my $c = $mm->config;

    my $res = {};
    my $backup = {};

    my %k = map {$_=>1} keys(%$hl), keys(%$hr);
    push @{ $mm->path }, "";
  K:
    for my $k (keys %k) {
        my @o;
        $mm->path->[-1] = $k;
        my $do_merge = 1;
        $do_merge = 0 if $do_merge && $em  &&  $mm->_in($k, $em);
        $do_merge = 0 if $do_merge && $im  && !$mm->_in($k, $im);
        $do_merge = 0 if $do_merge && $emr && $k =~ /$emr/;
        $do_merge = 0 if $do_merge && $imr && $k !~ /$imr/;

        if (!$do_merge) {
            $res->{$k} = $hl->{$k} if $hl->{$k};
            next K;
        }

        $backup->{$k} = $hl->{$k}[1] if exists($hl->{$k}) && exists($hr->{$k});
        if (exists $hl->{$k}) {
            push @o, $hl->{$k};
        }
        if (exists $hr->{$k}) {
            my %m = map {$_=>$mm->modes->{$_}->precedence_level} keys %{ $hr->{$k} };
            #print "DEBUG: \\%m=".Data::Dumper->new([\%m])->Indent(0)->Terse(1)->Dump."\n";
            push @o, map { [$_, $hr->{$k}{$_}] } sort { $m{$b} <=> $m{$a} } keys %m;
        }
        my $final_mode;
        my $v;
        #print "DEBUG: k=$k, o=".Data::Dumper->new([\@o])->Indent(0)->Terse(1)->Dump."\n";
        for my $i (0..$#o) {
            if ($i == 0) {
                $final_mode = $o[$i][0];
                $v = $o[$i][1];
            } else {
                my $m = $mm->combine_rules->{"$final_mode+$o[$i][0]"}
                    or do {
                        $mm->push_error("Can't merge $final_mode + $o[$i][0]");
                        return;
                    };
                #print "DEBUG: merge $final_mode+$o[$i][0] = $m->[0], $m->[1]\n";
                my ($bakv, $newkey);
                ($newkey, $v, $bakv) = $mm->_merge($k, $v, $o[$i][1], $m->[0]);
                return if @{ $mm->errors };
                next K unless defined $newkey;
                $final_mode = $m->[1];
            }
        }
        $res->{$k} = [$final_mode, $v];
    }
    pop @{ $mm->path };
    ($res, $backup);
}

sub merge_HASH_HASH {
    my ($self, $key, $l, $r, $mode) = @_;
    my $mm = $self->merger;
    my $c = $mm->config;
    $mode //= $c->default_mode;
    #print "DEBUG: entering merge_H_H(".$mm->_dump($l).", ".$mm->_dump($r).", $mode)\n";

    return $self->merge_SCALAR_SCALAR($key, $l, $r) unless $c->recurse_hash;
    return if $c->wanted_path && !$mm->_path_is_included($mm->path, $c->wanted_path);

    # STEP 1. MERGE LEFT & RIGHT OPTIONS KEY
    my $config_replaced;
    my $ok = $c->options_key;
    {
        last unless defined $ok;

        my $okl = $self->_gen_left ($l, $mode, sub {$_[0] eq $ok});
        return if @{ $mm->errors };

        my $okr = $self->_gen_right($r, $mode, sub {$_[0] eq $ok});
        return if @{ $mm->errors };

        push @{ $mm->path }, $ok;
        my ($res, $backup);
        {
            local $c->{readd_prefix} = 0;
             ($res, $backup) = $self->_merge_gen($okl, $okr, $mode);
        }
        pop @{ $mm->path };
        return if @{ $mm->errors };

        #print "DEBUG: merge options key (".$mm->_dump($okl).", ".$mm->_dump($okr).") = ".$mm->_dump($res)."\n";

        $res = $res->{$ok} ? $res->{$ok}[1] : undef;
        if (defined($res) && ref($res) ne 'HASH') {
            $mm->push_error("Invalid options key after merge: value must be hash");
            return;
        }
        last unless keys %$res;
        my $c2 = dclone($c);
        for (keys %$res) {
            if ($c->allow_override) {
                my $re = $c->allow_override;
                if (!/$re/) {
                    $mm->push_error("Configuration in options key `$_` not allowed by allow_override $re");
                    return;
                }
            }
            if ($c->disallow_override) {
                my $re = $c->disallow_override;
                if (/$re/) {
                    $mm->push_error("Configuration in options key `$_` not allowed by disallow_override $re");
                    return;
                }
            }
            if ($mm->_in($_, $c->_config_config)) {
                $mm->push_error("Configuration not allowed in options key: $_");
                return;
            }
            if (!$mm->_in($_, $c->_config_ok)) {
                $mm->push_error("Unknown configuration in options key: $_");
                return;
            }
            $c2->$_($res->{$_});
        }
        $mm->save_config;
        $mm->config($c2);
        $config_replaced++;
        $c = $c2;
        #print "DEBUG: configuration now changed: ".$mm->_dump($c)."\n";
    }

    my $sp = $c->set_prefix;
    if (defined($sp) && ref($sp) ne 'HASH') {
        $mm->push_error("Invalid config value `set_prefix`: must be a hash");
        return;
    }
    for my $mh (values %{ $mm->modes }) {
        my $n = $mh->name;
        if ($sp && $sp->{$n}) {
            $mh->prefix($sp->{$n});
            my $re = quotemeta($sp->{$n});
            $mh->prefix_re(qr/^$re/);
        } else {
            $mh->prefix($mh->default_prefix);
            $mh->prefix_re($mh->default_prefix_re);
        }
    }

    my $ep = $c->exclude_parse;
    my $ip = $c->include_parse;
    if (defined($ep) && ref($ep) ne 'ARRAY') {
        $mm->push_error("Invalid config value `exclude_parse`: must be an array");
        return;
    }
    if (defined($ip) && ref($ip) ne 'ARRAY') {
        $mm->push_error("Invalid config value `include_parse`: must be an array");
        return;
    }

    my $epr = $c->exclude_parse_regex;
    my $ipr = $c->include_parse_regex;
    if (defined($epr)) {
        eval { $epr = qr/$epr/ };
        if ($@) {
            $mm->push_error("Invalid config value `exclude_parse_regex`: invalid regex: $@");
            return;
        }
    }
    if (defined($ipr)) {
        eval { $ipr = qr/$ipr/ };
        if ($@) {
            $mm->push_error("Invalid config value `include_parse_regex`: invalid regex: $@");
            return;
        }
    }

    # STEP 2. PREPARE LEFT HASH
    my $hl = $self->_gen_left ($l, $mode, sub {defined($ok) ? $_[0] ne $ok : 1}, $ep, $ip, $epr, $ipr);
    return if @{ $mm->errors };

    # STEP 3. PREPARE RIGHT HASH
    my $hr = $self->_gen_right($r, $mode, sub {defined($ok) ? $_[0] ne $ok : 1}, $ep, $ip, $epr, $ipr);
    return if @{ $mm->errors };

    #print "DEBUG: hl=".Data::Dumper->new([$hl])->Indent(0)->Terse(1)->Dump."\n";
    #print "DEBUG: hr=".Data::Dumper->new([$hr])->Indent(0)->Terse(1)->Dump."\n";

    my $em = $c->exclude_merge;
    my $im = $c->include_merge;
    if (defined($em) && ref($em) ne 'ARRAY') {
        $mm->push_error("Invalid config value `exclude_marge`: must be an array");
        return;
    }
    if (defined($im) && ref($im) ne 'ARRAY') {
        $mm->push_error("Invalid config value `include_merge`: must be an array");
        return;
    }

    my $emr = $c->exclude_merge_regex;
    my $imr = $c->include_merge_regex;
    if (defined($emr)) {
        eval { $emr = qr/$emr/ };
        if ($@) {
            $mm->push_error("Invalid config value `exclude_merge_regex`: invalid regex: $@");
            return;
        }
    }
    if (defined($imr)) {
        eval { $imr = qr/$imr/ };
        if ($@) {
            $mm->push_error("Invalid config value `include_merge_regex`: invalid regex: $@");
            return;
        }
    }

    # STEP 4. MERGE LEFT & RIGHT
    my ($res, $backup) = $self->_merge_gen($hl, $hr, $mode, $em, $im, $emr, $imr);
    return if @{ $mm->errors };

    #print "DEBUG: intermediate res(5) = ".Data::Dumper->new([$res])->Indent(0)->Terse(1)->Dump."\n";

    # STEP 5. TURN BACK {key=>[MODE=>val]}, ...} INTO {(prefix)key => val, ...}
    if ($c->readd_prefix) {
        for my $k (keys %$res) {
            my $m = $res->{$k}[0];
            if ($m eq $c->default_mode) {
                $res->{$k} = $res->{$k}[1];
            } else {
                my $kp = $mm->modes->{$m}->add_prefix($k);
                if (exists $res->{$kp}) {
                    $mm->push_error("BUG: conflict when re-adding prefix after merge: $kp");
                    return;
                }
                $res->{$kp} = $res->{$k}[1];
                delete $res->{$k};
            }
        }
    } else {
        $res->{$_} = $res->{$_}[1] for keys %$res;
    }

    $mm->restore_config if $config_replaced;

    #print "DEBUG: backup = ".Data::Dumper->new([$backup])->Indent(0)->Terse(1)->Dump."\n";
    #print "DEBUG: leaving merge_H_H, result = ".$mm->_dump($res)."\n";
    ($key, $res, $backup);
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
=pod

=head1 NAME

Data::ModeMerge::Mode::Base - Base class for Data::ModeMerge mode handler

=head1 VERSION

version 0.13

=head1 SYNOPSIS

    use Data::ModeMerge;

=head1 DESCRIPTION

This is the base class for mode type handlers.

=head1 ATTRIBUTES

=head1 METHODS

=head2 name

Return name of mode. Subclass must override this method.

=head2 precedence_level

Return precedence level, which is a number. The greater the number,
the higher the precedence. Subclass must override this method.

=head2 default_prefix

Return default prefix. Subclass must override this method.

=head2 default_prefix_re

Return default prefix regex. Subclass must override this method.

=head2 check_prefix($hash_key)

Return true if hash key has prefix for this mode.

=head2 add_prefix($hash_key)

Return hash key with added prefix of this mode.

=head2 remove_prefix($hash_key)

Return hash key with prefix of this mode prefix removed.

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

