package Data::ModeMerge::Mode::DELETE;
our $VERSION = '0.18';
# ABSTRACT: Handler for Data::ModeMerge DELETE merge mode


use Moose;
extends 'Data::ModeMerge::Mode::Base';

sub name { 'DELETE' }

sub precedence_level { 1 }

sub default_prefix { '!' }

sub default_prefix_re { qr/^!/ }

# merge_left_only and merge_right_only are a bit different: they are
# called with $l only or $r only instead of both, and should return an
# extra argument $mode, i.e. ($key, $result, $backup, $is_circular,
# $mode)
sub merge_left_only {
    my ($self, $key, $l) = @_;
    return;
}

sub merge_right_only {
    my ($self, $key, $r) = @_;
    return;
}

sub merge_SCALAR_SCALAR {
    return;
}

sub merge_SCALAR_ARRAY {
    return;
}

sub merge_SCALAR_HASH {
    return;
}

sub merge_ARRAY_SCALAR {
    return;
}

sub merge_ARRAY_ARRAY {
    my ($self, $key, $l, $r) = @_;
    $self->merger->config->allow_destroy_array or
        $self->merger->push_error("Now allowed to destroy array via DELETE mode");
    return;
}

sub merge_ARRAY_HASH {
    return;
}

sub merge_HASH_SCALAR {
    return;
}

sub merge_HASH_ARRAY {
    return;
}

sub merge_HASH_HASH {
    my ($self, $key, $l, $r) = @_;
    $self->merger->config->allow_destroy_hash or
        $self->merger->push_error("Now allowed to destroy hash via DELETE mode");
    return;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
=pod

=head1 NAME

Data::ModeMerge::Mode::DELETE - Handler for Data::ModeMerge DELETE merge mode

=head1 VERSION

version 0.18

=head1 SYNOPSIS

    use Data::ModeMerge;

=head1 DESCRIPTION

This is the class to handle DELETE merge mode.

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

