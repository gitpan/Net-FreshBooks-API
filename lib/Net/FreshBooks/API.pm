use strict;
use warnings;

package Net::FreshBooks::API;
BEGIN {
  $Net::FreshBooks::API::VERSION = '0.12';
}
use Moose;

use Carp qw( carp croak );
use Data::Dump qw( dump );
#use Devel::SimpleTrace;
use Net::FreshBooks::API::Client;
use Net::FreshBooks::API::Invoice;
use Net::FreshBooks::API::OAuth;
use Net::FreshBooks::API::Payment;
use Net::FreshBooks::API::Recurring;
use Path::Class;
use URI;

has 'account_name'       => ( is => 'rw' );
has 'auth_token'         => ( is => 'rw' );
has 'api_version'        => ( is => 'rw', default => 2.1 );
has 'auth_realm'         => ( is => 'rw', default => 'FreshBooks' );
has 'oauth'              => ( is => 'rw', lazy_build => 1 );
has 'ua'                 => ( is => 'rw', lazy_build => 1 );
has 'verbose'            => ( is => 'rw', default => 0 );

# oauth methods
has 'access_token'        => ( is => 'rw' );
has 'access_token_secret' => ( is => 'rw' );
has 'consumer_key'        => ( is => 'rw' );
has 'consumer_secret'     => ( is => 'rw' );

sub _log {    ## no critic
    
    my $self = shift;
    return if !$self->verbose;
    
    my ( $level, $message ) = @_;
    $message .= "\n" if $message !~ m{\n/z}x;
    carp "$level: $message";
    
    return;

}

sub ping {
    my $self = shift;
    eval { $self->client->list() };

    $self->_log( debug => $@ ? "ping failed: $@" : "ping succeeded" );
    return if $@;
    return 1;
}

sub service_url {
    my $self = shift;
    my $account_name = $self->account_name || $self->consumer_key;

    my $uri
        = URI->new( 'https://'
            . $account_name
            . '.freshbooks.com/api/'
            . $self->api_version
            . '/xml-in' );

    return $uri;
}

sub client {
    my $self = shift;
    my $args = shift || {};
    return Net::FreshBooks::API::Client->new( { _fb => $self, %$args } );
}

sub invoice {
    my $self = shift;
    my $args = shift || {};
    return Net::FreshBooks::API::Invoice->new( { _fb => $self, %$args } );
}

sub payment {
    my $self = shift;
    my $args = shift || {};
    return Net::FreshBooks::API::Payment->new( { _fb => $self, %$args } );
}

sub recurring {
    my $self = shift;
    my $args = shift || {};
    return Net::FreshBooks::API::Recurring->new( { _fb => $self, %$args } );
}

sub _build_ua {
    my $self = shift;

    my $class = ref( $self ) || $self;
    my $version = $Net::FreshBooks::API::VERSION || '0.00';

    my $ua = LWP::UserAgent->new(
        agent             => "$class (v$version)",
        protocols_allowed => ['https'],
        keep_alive        => 10,
    );

    $ua->credentials(    #
        $self->service_url->host_port,    # net loc
        $self->auth_realm,                # realm
        $self->auth_token,                # username
        ''                                # password (none - all in username)
    );

    $ua->credentials(                     #
        $self->service_url->host_port,    # net loc
        '',                               # realm (none)
        $self->auth_token,                # username
        ''                                # password (none - all in username)
    );

    return $ua;
}

sub delete_everything_from_this_test_account {

    my $self = shift;

    my $name = $self->account_name;
    croak(    "ERROR: account_name must end with 'test' to use"
            . " the method delete_everything_on_this_test_account"
            . " - your account name is '$name'" )
        if ( $name !~ m{ test \z }x && $name ne 'netfreshbooksapi' );

    my $delete_count = 0;

    # note: 'payments' can't be deleted
    my @names_to_delete = qw( invoice client );

    # clear out all existing clients etc on this account.
    foreach my $object_name ( @names_to_delete ) {
        my $objects_to_delete = $self->$object_name->list();
        while ( my $obj = $objects_to_delete->next ) {
            $obj->delete;
            $delete_count++;
        }
    }

    return $delete_count;
}

sub _build_oauth {

    my $self = shift;

    my %tokens = (
        consumer_key    => $self->consumer_key,
        consumer_secret => $self->consumer_secret,
    );

    if ( $self->access_token && $self->access_token_secret ) {
        $tokens{'access_token'}        = $self->access_token;
        $tokens{'access_token_secret'} = $self->access_token_secret;
    }

    my $oauth = Net::FreshBooks::API::OAuth->new( %tokens );

    return $oauth;

}

__PACKAGE__->meta->make_immutable();

1;

# ABSTRACT: Easy OO access to the FreshBooks.com API



__END__
=pod

=head1 NAME

Net::FreshBooks::API - Easy OO access to the FreshBooks.com API

=head1 VERSION

version 0.12

=head1 SYNOPSIS

    use Net::FreshBooks::API;

    # Authenticate with OAuth (recommended)
    my $fb = Net::FreshBooks::API->new(
        {   consumer_key        => $consumer_key,       # same as account_name
            consumer_secret     => $consumer_secret,
            access_token        => $access_token,
            access_token_secret => $access_token_secret,
        }
    );


    # Or, use auth_token and account_name supplied by FreshBooks
    my $fb = Net::FreshBooks::API->new(
        {   auth_token   => $auth_token,
            account_name => $account_name,
        }
    );
    
    # create a new client
    my $client = $fb->client->create(
        {   first_name   => 'Larry',
            last_name    => 'Wall',
            organization => 'Perl HQ',
            email        => 'larry@example.com',
        }
    );
    
    # we can now make changes to the client and save them
    $client->organization( 'Perl Foundation' );
    $client->update;
    
    # or more quickly
    $client->update( { organization => 'Perl Foundation', } );
    
    # create an invoice for this client
    my $invoice = $fb->invoice(
        {   client_id => $client->client_id,
            number    => '00001',
        }
    );
    
    # add a line to the invoice
    $invoice->add_line(
        {   name      => 'Hawaiian shirt consulting',
            unit_cost => 60,
            quantity  => 4,
        }
    );
    
    # save the invoice and then send it
    $invoice->create;
    $invoice->send_by_email;
    
    ############################################
    # create a recurring item
    ############################################
    
    use Net::FreshBooks::API;
    use Net::FreshBooks::API::InvoiceLine;
    use DateTime;
    
    # auth_token and account_name come from FreshBooks
    my $fb = Net::FreshBooks::API->new(
        {   auth_token   => $auth_token,
            account_name => $account_name,
        }
    );
    
    # find the first client returned
    my $client = $fb->client->list->next;
    
    # create a line item
    my $line = Net::FreshBooks::API::InvoiceLine->new(
        {   name         => "Widget",
            description  => "Net::FreshBooks::API Widget",
            unit_cost    => '1.99',
            quantity     => 1,
            tax1_name    => "GST",
            tax1_percent => 5,
        }
    );
    
    # create the recurring item
    my $recurring_item = $fb->recurring->create(
        {   client_id => $client->client_id,
            date      => DateTime->now->add( days => 2 )->ymd,    # YYYY-MM-DD
            frequency => 'monthly',
            lines     => [$line],
            notes     => 'Created by Net::FreshBooks::API',
        }
    );
    
    $recurring_item->po_number( 999 );
    $recurring_item->update;

See also L<Net::FreshBooks::API::Base> for other available methods, such as
create, update, get, list and delete.

=head1 DESCRIPTION

L<http://www.freshbooks.com> is a website that lets you create, send and
manage invoices. This module is an OO abstraction of their API that lets you
work with Clients, Invoices etc as if they were standard Perl objects.

Repository: L<http://github.com/oalders/net-freshbooks-api/tree/master>

=head2 OAUTH

OAuth is the recommended method of authentication, but it can take a few days
for FreshBooks to approve your OAuth application. In the meantime, you can get
started right away by using an auth_token.

Once your application has been approved, your consumer_key will be your
FreshBooks account name and your consumer_key_secret will be provided to you
by FreshBooks in your account. If you need to generate an access_token and
access_token_secret, you can so so by running the oauth.pl script in the
/examples directory which is included with this distribution.

=head1 METHODS

=head2 new

Create a new API object.

    my $fb = Net::FreshBooks::API->new(
        {   consumer_key        => $consumer_key,       # same as account_name
            consumer_secret     => $consumer_secret,
            access_token        => $access_token,
            access_token_secret => $access_token_secret,
        }
    );

=head2 client

Returns a L<Net::FreshBooks::API::Client> object.

=head2 invoice

Creates and returns a new L<Net::FreshBooks::API::Invoice> object.

=head2 payment

Creates and returns a new L<Net::FreshBooks::API::Payment> object.

=head2 recurring

Creates and returns a new L<Net::FreshBooks::API::Recurring> object.

=head2 ping

  my $bool = $fb->ping(  );

Ping the server with a trivial request to see if a connection can be made.
Returns true if the server is reachable and the authentication details are
valid.

=head2 service_url

  my $url = $fb->service_url(  );

Returns a L<URI> object that represents the service URL.

=head2 verbose

Setting verbose to a true value will allow you to inspect the XML which is
being sent to FreshBooks

=head2 ua

  my $ua = $fb->ua;

Return a LWP::UserAgent object to use when contacting the server.

=head2 delete_everything_from_this_test_account

    my $deletion_count
        = $fb->delete_everything_from_this_test_account();

Deletes all clients, invoices and payments from this account. This is
convenient when testing but potentially very dangerous. To prevent accidential
deletions this method has a very long name, and will croak if the account name
does not end with 'test'.

As a general rule it is best to put this at the B<start> of your test scripts
rather than at the end. This will let you inspect your account at the end of
the test script to see what is left behind.

=head1 OAUTH METHODS

=head2 consumer_key( $account_name )

Getter/setter method. Can also be passed to new(). Required when constructing
a new L<Net::FreshBooks::API::OAuth> object.

=head2 consumer_secret( $secret )

Getter/setter method. Can also be passed to new(). Required when constructing
a new L<Net::FreshBooks::API::OAuth> object.  The consumer_secret is
provided to you by FreshBooks.  You'll need to log in to your account to
access it.

=head2 access_token( $access_token )

Getter/setter method.  Can also be passed to new().  Optional for construction
of a new L<Net::FreshBooks::API::OAuth> object.

=head2 access_token_secret( $access_token_secret )

Getter/setter method.  Can also be passed to new().  Optional for construction
of a new L<Net::FreshBooks::API::OAuth> object.

=head2 oauth

Returns a L<Net::FreshBooks::API::OAuth> object. This is a subclass of
L<Net::OAuth::Simple> See L<Net::FreshBooks::API::OAuth> as well as the
scripts in the /examples folder of this distribution for use cases.

=head1 WARNING

This code is still under development - any and all patches most welcome.

The documentation is by no means complete. Feel free to look at the test files
for more examples of usage.

Up to this point, only clients, invoices and recurring items have been
implemented, but other functionality may be added as needed. If you need other
details, they should be very easy to add. Please get in touch.

=head1 AUTHOR CREDITS

Edmund von der Burg C<<evdb@ecclestoad.co.uk>> (Original Author)

Developed for HinuHinu L<http://www.hinuhinu.com/>.

Recurring item support by:

Olaf Alders olaf@raybec.com

Developed for Raybec Communications L<http://www.raybec.com>

=head1 SEE ALSO

L<WWW::FreshBooks::API> - an alternative interface to FreshBooks.

L<http://developers.freshbooks.com/overview/> the FreshBooks API documentation.

=head1 AUTHOR

Olaf Alders <olaf@wundercounter.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Edmund von der Burg & Olaf Alders.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

