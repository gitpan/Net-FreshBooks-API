use strict;
use warnings;

package Net::FreshBooks::API::InvoiceLine;
BEGIN {
  $Net::FreshBooks::API::InvoiceLine::VERSION = '0.11';
}
use Moose;
extends 'Net::FreshBooks::API::Base';

my $fields = _fields();
foreach my $method ( keys %{$fields} ) {
    has $method => (  is => $fields->{$method}->{mutable} ? 'rw' : 'ro' );
}

sub _fields {
    return {
        amount       => { mutable => 0, },
        name         => { mutable => 1, },
        description  => { mutable => 1, },
        unit_cost    => { mutable => 1, },
        quantity     => { mutable => 1, },
        tax1_name    => { mutable => 1, },
        tax2_name    => { mutable => 1, },
        tax1_percent => { mutable => 1, },
        tax2_percent => { mutable => 1, },
    };
}

sub node_name { return 'line' }

__PACKAGE__->meta->make_immutable();

1;

__END__
=pod

=head1 NAME

Net::FreshBooks::API::InvoiceLine

=head1 VERSION

version 0.11

=head1 AUTHOR

Olaf Alders <olaf@wundercounter.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Edmund von der Burg & Olaf Alders.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

