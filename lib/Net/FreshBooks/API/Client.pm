use strict;
use warnings;

package Net::FreshBooks::API::Client;
BEGIN {
  $Net::FreshBooks::API::Client::VERSION = '0.15';
}

use Moose;
extends 'Net::FreshBooks::API::Base';
with 'Net::FreshBooks::API::Role::CRUD';

has $_ => ( is => _fields()->{$_}->{is} ) for sort keys %{ _fields() };

sub _fields {
    return {
        client_id     => { is => 'ro' },
        currency_code => { is => 'rw' },
        first_name    => { is => 'rw' },
        last_name     => { is => 'rw' },
        language      => { is => 'rw' },
        notes         => { is => 'rw' },
        organization  => { is => 'rw' },
        p_city        => { is => 'rw' },
        p_code        => { is => 'rw' },
        p_country     => { is => 'rw' },
        p_state       => { is => 'rw' },
        p_street1     => { is => 'rw' },
        p_street2     => { is => 'rw' },
        vat_name      => { is => 'rw' },
        vat_number    => { is => 'rw' },

        # custom fields
        credit     => { is => 'ro' },
        email      => { is => 'rw' },
        fax        => { is => 'rw' },
        home_phone => { is => 'rw' },
        links      => {
            is           => 'ro',
            made_of      => 'Net::FreshBooks::API::Links',
            presented_as => 'single',
        },
        mobile     => { is => 'rw' },
        password   => { is => 'rw' },
        s_city     => { is => 'rw' },
        s_code     => { is => 'rw' },
        s_country  => { is => 'rw' },
        s_state    => { is => 'rw' },
        s_street1  => { is => 'rw' },
        s_street2  => { is => 'rw' },
        username   => { is => 'rw' },
        work_phone => { is => 'rw' },

        #folder     => { is => 'rw' },

    };
}

__PACKAGE__->meta->make_immutable();

1;


__END__
=pod

=head1 NAME

Net::FreshBooks::API::Client

=head1 VERSION

version 0.15

=head1 SYNOPSIS

    my $fb = Net::FreshBooks::API->new({ ... });
    my $client = $fb->client;

=head2 create

    # create a new client
    my $client = $fb->client->create(
        {   first_name   => 'Larry',
            last_name    => 'Wall',
            organization => 'Perl HQ',
            email        => 'larry@example.com',
        }
    );

Once you have a client object, you may set any of the mutable fields by
calling the appropriate method on the object:

    $client->first_name( 'Lawrence' );
    $client->last_name( 'Wahl' );

These changes will not be reflected in your FreshBooks account until you call
the update() method, which is described below.

=head2 update

    # take the client object created above
    # we can now make changes to the client and save them
    $client->organization('Perl Foundation');
    $client->update;

    # or more quickly
    $client->update( { organization => 'Perl Foundation', } );

=head2 get

    # fetch a client based on a FreshBooks client_id
    my $client = $fb->client->get({ client_id => $client_id });

=head2 delete

    # fetch a client and then delete it
    my $client = $fb->client->get({ client_id => $client_id });
    $client->delete;

=head2 links

Returns a L<Net::FreshBooks::API::Links> object, which returns FreshBooks
URLs.

    print "Client view: " . $fb->client->links->client_view;

=head2 list

Returns n L<Net::FreshBooks::API::Iterator> object. Currently,
all list() functionality defaults to 15 items per page.

    #list all active clients
    my $clients = $fb->client->list();

    print $clients->total . " active clients\n";
    print $clients->pages . " pages of results\n";

    while ( my $client = $clients->next ) {
        print join( "\t", $client->client_id, $client->first_name, $client->last_name ) . "\n";
    }

To override the default pagination:

    my $clients = $fb->client->list({ page => 2, per_page => 35 });

=head1 DESCRIPTION

This class gives you object to FreshBooks client information.
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

