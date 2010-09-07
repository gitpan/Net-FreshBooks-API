use strict;
use warnings;

package Net::FreshBooks::API::Payment;
BEGIN {
  $Net::FreshBooks::API::Payment::VERSION = '0.11';
}

use Moose;
extends 'Net::FreshBooks::API::Base';

use Net::FreshBooks::API::Links;

my $fields = _fields();
foreach my $method ( keys %{$fields} ) {
    has $method => (  is => $fields->{$method}->{mutable} ? 'rw' : 'ro' );
}

sub _fields {
    return {
        payment_id => { mutable => 0, },
        client_id  => { mutable => 1, },
        invoice_id => { mutable => 1, },

        date   => { mutable => 1, },
        amount => { mutable => 1, },
        type   => { mutable => 1, },
        notes  => { mutable => 1, },
    };
}

__PACKAGE__->meta->make_immutable();

1;


__END__
=pod

=head1 NAME

Net::FreshBooks::API::Payment

=head1 VERSION

version 0.11

=head1 SYNOPSIS

    my $fb = Net::FreshBooks::API->new({ ... });
    my $payment = $fb->payment;

=head2 payment->create

Create a new payment in the FreshBooks system

    my $payment = $fb->payment->create({...});

=head2 payment->update

Please see client->update for an example of how to use this method.

=head2 payment->get

    my $payment = $fb->payment->get({ payment_id => $payment_id });

=head2 payment->delete

    my $payment = $fb->payment->get({ payment_id => $payment_id });
    $payment->delete;

=head2 payment->list

Returns a L<Net::FreshBooks::API::Iterator> object.

    my $payments = $fb->payment->list;
    while ( my $payment = $payments->list ) {
        print $payment->payment_id, "\n";
    }

=head1 DESCRIPTION

This class gives you object to FreshBooks payment information.
L<Net::FreshBooks::API> will construct this object for you.

=head1 AUTHOR

Olaf Alders <olaf@wundercounter.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Edmund von der Burg & Olaf Alders.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

