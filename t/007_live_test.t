#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dump qw( dump );
use Test::More;
use Test::Exception;

use Net::FreshBooks::API;
use Test::WWW::Mechanize;

plan -r 't/config.pl' && require('t/config.pl')
    ? ( tests => 21 )
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

$fb->delete_everything_from_this_test_account();

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
my $return_uri = 'http://www.google.com';

my $invoice = $fb->invoice(
    {   client_id  => $client->client_id,
        return_uri => $return_uri,

        # number    => time,
    }
);

ok $invoice, "got a new invoice";
ok !$invoice->invoice_id, "no invoice_id yet";

# add a line to the invoice
$invoice->add_line(
    {   name        => 'test line',
        description => 'this is the test line',
        unit_cost   => 100,
        quantity    => 4,
    }
);

# save the invoice
ok $invoice->create, "Create the invoice on FB";

# check that the invoice has not been sent
is $invoice->status, 'draft', "invoice status is 'draft'";

my $mech = Test::WWW::Mechanize->new;
$mech->get_ok( $invoice->links->client_view );
$mech->content_lacks( ' this is the test line ',
    "Invoice not available to client" );

# send the invoice so that it is available
ok $invoice->send_by_email, "Send the invoice";

# Check that the invoice is now viewable
is $invoice->status, 'sent', "invoice status is 'sent'";
$mech->get_ok( $invoice->links->client_view );
$mech->content_contains( 'this is the test line',
    "Invoice is now available to client" );

#diag("view invoice: " . $invoice->links->client_view);

throws_ok {
    $fb->payment->create(
        {   invoice_id => $invoice->invoice_id,
            client_id  => $client->client_id,
            amount     => ' 1.00 '
        }
    );
}
qr/Payment from credit cannot exceed available credit/, 'error msg parsed';

my $payment = $fb->payment;
$payment->error->die_on_server_error( 0 );

lives_ok {
    $payment->create(
        {   invoice_id => $invoice->invoice_id,
            client_id  => $client->client_id,
            amount     => ' 1.00 '
        }
    );
}
'does not die when die is disabled';

# can we get the invoice from the API?

my $retrieved = $fb->invoice->get( { invoice_id => $invoice->invoice_id } );
ok( $retrieved, "got an invoice back from freshbooks" );
cmp_ok( $retrieved->return_uri, 'eq', $return_uri,
    "return uri correctly set" );

#diag( dump $retrieve );

