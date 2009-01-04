#

package Net::FreshBooks::API;
use base 'Class::Accessor::Fast';

use strict;
use warnings;

our $VERSION = '0.01';

use Carp;
use URI;
use Data::Dumper;

# use Log::Log4perl;
# Log::Log4perl->easy_init('OFF')
#     unless Log::Log4perl->initialized();

__PACKAGE__->mk_accessors(qw(account_name auth_token api_version auth_realm));

use Net::FreshBooks::API::Client;
use Net::FreshBooks::API::Invoice;

=head1 NAME

Net::FreshBooks::API - easy OO access to the FreshBooks.com API

=head1 SYNOPSIS

    use Net::FreshBooks::API;

    # auth_token and account_name come from FreshBooks
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
    $client->organization('Perl Foundation');
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

=head1 WARNING

This code is still under development - any and all patches most welcome.

Especially lacking is the documentation - for now you'd better look at the test
file 't/live-test.t' for examples of usage.

Also I've only implemented the clients and invoices as they were all I needed.
If you need other details they should be very easy to add - please get in touch.

=head1 DESCRIPTION

L<FreshBooks.com> is a website that lets you create, send and manage invoices.
This module is an OO abstraction of their API that lets you work with Clients,
Invoices etc as if they were standard Perl objects.

=head1 METHODS

=head2 new

    my $fb = Net::FreshBooks::API->new(
        {   account_name => 'account_name',
            auth_token   => '123...def',
        }
    );

Create a new API object.

=cut

sub new {
    my $class = shift;
    my $args  = shift;

    croak "Need both an account_name and an auth_token"
        unless $args->{account_name} && $args->{auth_token};

    $args->{api_version} ||= 2.1;
    $args->{auth_realm}  ||= 'FreshBooks';

    return bless {%$args}, $class;
}

=head2 ping

  my $bool = $fb->ping(  );

Ping the server with a trivial request to see if a connection can be made.
Returns true if the server is reachable and the authentication details are
valid.

=cut

sub ping {
    my $self = shift;
    $self->client->list();
    return 1;
}

=head2 service_url

  my $url = $fb->service_url(  );

Returns a L<URI> object that represents the service URL.

=cut

sub service_url {
    my $self = shift;

    my $uri
        = URI->new( 'https://'
            . $self->account_name
            . '.freshbooks.com/api/'
            . $self->api_version
            . '/xml-in' );

    return $uri;
}

=head2 client, invoice

  my $client = $fb->client->create({...});

Accessor to the various objects in the API.

=cut

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

=head2 ua

  my $ua = $fb->ua;

Return a LWP::UserAgent object to use when contacting the server.

=cut

sub ua {
    my $self = shift;

    my $class = ref($self) || $self;
    my $version = $VERSION;

    my $ua = LWP::UserAgent->new(
        agent             => "$class (v$version)",
        protocols_allowed => ['https'],
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

# =head2 log
#
#   my $logger = $fb->log;
#
# docs...
#
# =cut
#
# my $LOGGER = undef;
#
# sub log {
#     my $self = shift;
#     local $Log::Log4perl::caller_depth = $Log::Log4perl::caller_depth + 1;
#     return $LOGGER ||= Log::Log4perl->get_logger;
# }

=head1 AUTHOR

Edmund von der Burg C<<evdb@ecclestoad.co.uk>>

Developed for HinuHinu L<http://www.hinuhinu.com/>.

=head1 LICENCE

Perl

=head1 SEE ALSO

L<WWW::FreshBooks::API> - an alternative interface to FreshBooks.

L<http://developers.freshbooks.com/overview/> the FreshBooks API documentation.

=cut

1;
