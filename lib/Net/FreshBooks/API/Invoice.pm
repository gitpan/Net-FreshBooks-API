use strict;
use warnings;

package Net::FreshBooks::API::Invoice;

use Moose;
extends 'Net::FreshBooks::API::Base';

use Net::FreshBooks::API::InvoiceLine;
use Net::FreshBooks::API::Links;

my $fields = _fields();
foreach my $method ( keys %{$fields} ) {
    has $method => (  is => $fields->{$method}->{mutable} ? 'rw' : 'ro' );
}

sub _fields {
    return {
        invoice_id => { mutable => 0, },
        client_id  => { mutable => 1, },

        number             => { mutable => 1, },
        amount             => { mutable => 0, },
        amount_outstanding => { mutable => 0, },
        status             => { mutable => 1, },
        date               => { mutable => 1, },
        po_number          => { mutable => 1, },
        discount           => { mutable => 1, },
        notes              => { mutable => 1, },
        terms              => { mutable => 1, },
        currency_code      => { mutable => 1, },
        folder             => { mutable => 1, },
        language           => { mutable => 1, },
        return_uri         => { mutable => 1, },
        updated            => { mutable => 0, },

        links => {
            mutable      => 0,
            made_of      => 'Net::FreshBooks::API::Links',
            presented_as => 'single',
        },

        recurring_id => { mutable => 0, },

        organization => { mutable => 1, },
        first_name   => { mutable => 1, },
        last_name    => { mutable => 1, },
        p_street1    => { mutable => 1, },
        p_street2    => { mutable => 1, },
        p_city       => { mutable => 1, },
        p_state      => { mutable => 1, },
        p_country    => { mutable => 1, },
        p_code       => { mutable => 1, },
        vat_name     => { mutable => 1, },
        vat_number   => { mutable => 1, },

        lines => {
            mutable      => 1,
            made_of      => 'Net::FreshBooks::API::InvoiceLine',
            presented_as => 'array',
        },
    };
}

sub add_line {
    my $self      = shift;
    my $line_args = shift;

    push @{ $self->{lines} ||= [] },
        Net::FreshBooks::API::InvoiceLine->new($line_args);

    return 1;
}

sub send_by_email {
    my $self = shift;
    return $self->_send_using('sendByEmail');
}

sub send_by_snail_mail {
    my $self = shift;
    return $self->_send_using('sendBySnailMail');
}

sub _send_using {
    my $self = shift;
    my $how  = shift;

    my $method   = $self->method_string($how);
    my $id_field = $self->id_field;

    my $res = $self->send_request(
        {   _method   => $method,
            $id_field => $self->$id_field,
        }
    );

    # refetch the invoice so that the flags are updated.
    $self->get( { invoice_id => $self->invoice_id } );

    return 1;
}

__PACKAGE__->meta->make_immutable();

1;


__END__
=pod

=head1 NAME

Net::FreshBooks::API::Invoice

=head1 VERSION

version 0.13

=head1 SYNOPSIS

    my $fb = Net::FreshBooks::API->new({ ... });
    my $invoice = $fb->invoice;

=head2 create

Create an invoice in the FreshBooks system.

my $invoice = $fb->invoice->create({...});

=head2 add_line

Create a new L<Net::FreshBooks::API::InvoiceLine> object and add it to the end
of the list of lines

    my $bool = $invoice->add_line(
        {   name         => "Yard Work",          # (Optional)
            description  => "Mowed the lawn.",    # (Optional)
            unit_cost    => 10,                   # Default is 0
            quantity     => 4,                    # Default is 0
            tax1_name    => "GST",                # (Optional)
            tax2_name    => "PST",                # (Optional)
            tax1_percent => 8,                    # (Optional)
            tax2_percent => 6,                    # (Optional)
        }
    );

=head2 send_by_email

Send the invoice by email.

  my $result = $invoice->send_by_email();

=head2 send_by_snail_mail

Send the invoice by snail mail.

  my $result = $invoice->send_by_snail_mail();

=head2 update

Please see client->update for an example of how to use this method.

=head2 get

    my $invoice = $fb->invoice->get({ invoice_id => $invoice_id });

=head2 delete

    my $invoice = $fb->invoice->get({ invoice_id => $invoice_id });
    $invoice->delete;

=head2 links

Returns a L<Net::FreshBooks::API::Links> object, which returns FreshBooks
URLs.

    print "send this url to client: " . $invoice->links->client_view;

=head2 list

Returns a L<Net::FreshBooks::API::Iterator> object.

    # list unpaid invoices
    my $invoices = $fb->invoice->list({ status => 'unpaid' });

    while ( my $invoice = $invoices->list ) {
        print $invoice->invoice_id, "\n";
    }

=head2 lines

Returns an ARRAYREF of Net::FreshBooks::API::InvoiceLine objects

    foreach my $line ( @{ $invoice->lines } ) {
        print $line->amount, "\n";
    }

=head1 DESCRIPTION

This class gives you object to FreshBooks invoice information.
L<Net::FreshBooks::API> will construct this object for you.

=head1 AUTHORS

=over 4

=item *

Edmund von der Burg <evdb@ecclestoad.co.uk>

=item *

Olaf Alders <olaf@wundercounter.com>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Edmund von der Burg & Olaf Alders.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

