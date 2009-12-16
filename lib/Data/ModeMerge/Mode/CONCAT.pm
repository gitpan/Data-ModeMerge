package Data::ModeMerge::Mode::CONCAT;
our $VERSION = '0.15';
# ABSTRACT: Handler for Data::ModeMerge CONCAT merge mode


use Moose;
extends 'Data::ModeMerge::Mode::ADD';

sub name { 'CONCAT' }

sub precedence_level { 2 }

sub default_prefix { '.' }

sub default_prefix_re { qr/^\./ }

sub merge_SCALAR_SCALAR {
    my ($self, $key, $l, $r) = @_;
    ($key, ($l // "") . $r);
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
=pod

=head1 NAME

Data::ModeMerge::Mode::CONCAT - Handler for Data::ModeMerge CONCAT merge mode

=head1 VERSION

version 0.15

=head1 SYNOPSIS

    use Data::ModeMerge;

=head1 DESCRIPTION

This is the class to handle CONCAT merge mode.

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

