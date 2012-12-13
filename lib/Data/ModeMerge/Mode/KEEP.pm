package Data::ModeMerge::Mode::KEEP;

use 5.010;
use Moo;
extends 'Data::ModeMerge::Mode::Base';

our $VERSION = '0.29'; # VERSION

sub name { 'KEEP' }

sub precedence_level { 6 }

sub default_prefix { '^' }

sub default_prefix_re { qr/^\^/ }

sub merge_SCALAR_SCALAR {
    my ($self, $key, $l, $r) = @_;
    ($key, $l);
}

sub merge_SCALAR_ARRAY {
    my ($self, $key, $l, $r) = @_;
    ($key, $l);
}

sub merge_SCALAR_HASH {
    my ($self, $key, $l, $r) = @_;
    ($key, $l);
}

sub merge_ARRAY_SCALAR {
    my ($self, $key, $l, $r) = @_;
    ($key, $l);
}

sub merge_ARRAY_ARRAY {
    my ($self, $key, $l, $r) = @_;
    $self->SUPER::merge_ARRAY_ARRAY($key, $l, $r, 'KEEP');
};

sub merge_ARRAY_HASH {
    my ($self, $key, $l, $r) = @_;
    ($key, $l);
}

sub merge_HASH_SCALAR {
    my ($self, $key, $l, $r) = @_;
    ($key, $l);
}

sub merge_HASH_ARRAY {
    my ($self, $key, $l, $r) = @_;
    ($key, $l);
}

sub merge_HASH_HASH {
    my ($self, $key, $l, $r) = @_;
    $self->SUPER::merge_HASH_HASH($key, $l, $r, 'KEEP');
};

1;
# ABSTRACT: Handler for Data::ModeMerge KEEP merge mode



__END__
=pod

=head1 NAME

Data::ModeMerge::Mode::KEEP - Handler for Data::ModeMerge KEEP merge mode

=head1 VERSION

version 0.29

=head1 SYNOPSIS

 use Data::ModeMerge;

=head1 DESCRIPTION

This is the class to handle KEEP merge mode.

=for Pod::Coverage ^merge_.*

=head1 AUTHOR

Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

