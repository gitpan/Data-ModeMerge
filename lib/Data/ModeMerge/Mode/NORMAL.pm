package Data::ModeMerge::Mode::NORMAL;
our $VERSION = '0.23';
# ABSTRACT: Handler for Data::ModeMerge NORMAL merge mode


use Any::Moose;
extends 'Data::ModeMerge::Mode::Base';

sub name { 'NORMAL' }

sub precedence_level { 5 }

sub default_prefix { '*' }

sub default_prefix_re { qr/^\*/ }

sub merge_SCALAR_SCALAR {
    my ($self, $key, $l, $r) = @_;
    ($key, $r);
}

sub merge_SCALAR_ARRAY {
    my ($self, $key, $l, $r) = @_;
    ($key, $r);
}

sub merge_SCALAR_HASH {
    my ($self, $key, $l, $r) = @_;
    ($key, $r);
}

sub merge_SCALAR_CODE {
    my ($self, $key, $l, $r) = @_;
    ($key, $r);
}

sub merge_ARRAY_SCALAR {
    my ($self, $key, $l, $r) = @_;
    ($key, $r);
}

sub merge_ARRAY_HASH {
    my ($self, $key, $l, $r) = @_;
    ($key, $r);
}

sub merge_ARRAY_CODE {
    my ($self, $key, $l, $r) = @_;
    ($key, $r);
}

sub merge_HASH_SCALAR {
    my ($self, $key, $l, $r) = @_;
    ($key, $r);
}

sub merge_HASH_ARRAY {
    my ($self, $key, $l, $r) = @_;
    ($key, $r);
}

sub merge_HASH_CODE {
    my ($self, $key, $l, $r) = @_;
    ($key, $r);
}

sub merge_CODE_SCALAR {
    my ($self, $key, $l, $r) = @_;
    ($key, $r);
}

sub merge_CODE_ARRAY {
    my ($self, $key, $l, $r) = @_;
    ($key, $r);
}

sub merge_CODE_HASH {
    my ($self, $key, $l, $r) = @_;
    ($key, $r);
}

sub merge_CODE_CODE {
    my ($self, $key, $l, $r) = @_;
    ($key, $r);
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;
1;

__END__
=pod

=head1 NAME

Data::ModeMerge::Mode::NORMAL - Handler for Data::ModeMerge NORMAL merge mode

=head1 VERSION

version 0.23

=head1 SYNOPSIS

    use Data::ModeMerge;

=head1 DESCRIPTION

This is the class to handle NORMAL merge mode.

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

