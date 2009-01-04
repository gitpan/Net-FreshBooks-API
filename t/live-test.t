#!/usr/bin/perl -w

use strict;
use Test::More;

# BEGIN {
#     use Log::Log4perl;
#     Log::Log4perl::init('t/log4perl.conf');
# }

use Net::FreshBooks::API;
use Test::WWW::Mechanize;

plan -r 't/config.pl' && require('t/config.pl')
    ? ( tests => 15 )
    : ( skip_all => "Need test connection details in t/config.pl"
        . " - see t/config_sample.pl for details" );

my $test_email = FBTest->get('test_email') || die;

# create the FB object
my $fb = Net::FreshBooks::API->new(
    {   auth_token   => FBTest->get('auth_token'),
        account_name => FBTest->get('account_name'),
    }
);
ok $fb, "created the FB object";

# clear out all existing clients etc on this account.
my $clients_to_delete = $fb->client->list();
while ( my $c = $clients_to_delete->next ) {
    diag "Deleting pre-existing client: " . $c->username;
    $c->delete;
}

# create a new client
my $client = $fb->client->create(
    {   first_name   => 'Jack',
        last_name    => 'Test',
        organization => 'Test Corp',
        email        => $test_email,
    }
);
ok $client, "Created a new client";

# check that the client exists
{
    my $retrieved_client
        = $fb->client->list( { email => $test_email, } )->next;
    is $retrieved_client->client_id, $client->client_id,
        "Client has been stored on FB";
}

# update the client - check that the changes stick
isnt $client->organization, 'foobar', 'organization is not foobar';
$client->organization('foobar');
is $client->organization, 'foobar', 'organization is foobar';
ok $client->update, "update the client";
{
    my $retrieved_client
        = $fb->client->get( { client_id => $client->client_id, } );
    is $retrieved_client->organization, 'foobar',
        "Client has been updated on FB";
}

# create an invoice for this client
my $invoice = $fb->invoice(
    {   client_id => $client->client_id,
        number    => time,
    }
);

ok $invoice, "got a new invoice";
ok !$invoice->invoice_id, "no invoice_id yet";

# add a line to the invoice
$invoice->add_line(
    {   name      => 'test line',
        unit_cost => 100,
        quantity  => 4,
    }
);

# save the invoice
ok $invoice->create, "Create the invoice on FB";

# check that the invoice has not been sent
my $mech = Test::WWW::Mechanize->new;
$mech->get_ok( $invoice->links->client_view );
$mech->content_contains( 'Invoice not available',
    "Invoice not available to client" );

# send the invoice so that it is available
ok $invoice->send_by_email, "Send the invoice";

# Check that the invoice is now viewable
$mech->get_ok( $invoice->links->client_view );
$mech->content_lacks( 'Invoice not available',
    "Invoice is now available to client" );
