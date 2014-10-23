use strict;
use warnings;

package Net::FreshBooks::API::Base;
BEGIN {
  $Net::FreshBooks::API::Base::VERSION = '0.17';
}

use Moose;
use Carp qw( carp croak );
use Clone qw(clone);
use Data::Dump qw( dump );

#use Devel::SimpleTrace;
use XML::LibXML ':libxml';
use XML::Simple;
use LWP::UserAgent;

use Net::FreshBooks::API::Iterator;

my %plural_to_singular = (
    clients  => 'client',
    invoices => 'invoice',
    lines    => 'line',
    payments => 'payment',
    nesteds  => 'nested',    # for testing
);

has '_fb' => ( is => 'rw' );
has '_sent_xml' => ( is => 'rw' );

sub new_from_node {
    my $class = shift;
    my $node  = shift;

    my $self = bless {}, $class;

    $self->_fill_in_from_node( $node );

    return $self;
}

sub copy {
    my $self  = shift;
    my $class = ref $self;
    return $class->new( { _fb => $self->_fb } );
}

sub _fill_in_from_node {
    my $self    = shift;
    my $in_node = shift;

    # parse it as a new node so that the matching is more reliable
    my $parser = XML::LibXML->new();
    my $node   = $parser->parse_string( $in_node->toString );

    # cleanup all the keys
    delete $self->{$_}    #
        for grep { !m/^_/x } keys %$self;

    my $fields_config = $self->_fields;

    # copy across the new values provided
    foreach my $key ( grep { !m/^_/x } keys %$fields_config ) {

        my $xpath .= sprintf "//%s/%s", $self->node_name, $key;

        # check that this field is not a special one
        if ( my $made_of = $fields_config->{$key}{made_of} ) {

            my ( $match ) = $node->findnodes( $xpath );

            # avoid this error: Can't call method "childNodes" on an undefined
            # value at /tmp/net-freshbooks-api/lib/Net/FreshBooks/API/Base.pm
            # line 174
            next if !$match;

            if ( $fields_config->{$key}{presented_as} eq 'array' ) {

                my @new_objects =    #
                    map { $made_of->new_from_node( $_ ) }    #
                    grep { $_->nodeType eq XML_ELEMENT_NODE }
                    $match->childNodes();

                $self->{$key} = \@new_objects;
            }
            else {
                $self->{$key}                                #
                    = $match                                 #
                    ? $made_of->new_from_node( $match )      #
                    : undef;
            }

        }
        else {
            my $val = $node->findvalue( $xpath );
            $self->{$key} = $val;
        }
    }

    return $self;

}

sub send_request {
    my $self = shift;
    my $args = shift;

    my $fb     = $self->_fb;
    my $method = $args->{_method};

    my %frequency_fix = %{ $self->_frequency_cleanup };

    my $pattern = join "|", keys %frequency_fix;

    $fb->_log( debug => "Sending request for $method" );

    my $request_xml = $self->parameters_to_request_xml( $args );

    $request_xml
        =~ s{<frequency>($pattern)</frequency>}{<frequency>$frequency_fix{$1}</frequency>}gxms;

    $fb->_log( debug => $request_xml );

    my $return_xml = $self->send_xml_to_freshbooks( $request_xml );

    $fb->_log( debug => $return_xml );
    $self->{'__return_xml'} = $return_xml;

    my $response_node = $self->response_xml_to_node( $return_xml );

    $fb->_log( debug => "Received response for $method" );

    #carp "sending request\n";

    return $response_node;
}

sub method_string {
    my $self   = shift;
    my $action = shift;

    return $self->api_name . '.' . $action;
}

sub api_name {
    my $self = shift;
    my $name = ref( $self ) || $self;
    $name =~ s{^.*::}{}x;
    return lc $name;
}

sub node_name {
    my $self = shift;
    return $self->api_name;
}

sub id_field {
    my $self = shift;
    return $self->api_name . "_id";
}

sub field_names {
    my $self  = shift;
    my @names = sort keys %{ $self->_fields };
    return @names;
}

sub field_names_rw {
    my $self   = shift;
    my $fields = $self->_fields;

    my @names = sort
        grep { $fields->{$_}{is} eq 'rw' }
        keys %$fields;

    return @names;
}

sub parameters_to_request_xml {
    my $self       = shift;
    my $parameters = clone( shift );

    my $dom = XML::LibXML::Document->new( '1.0', 'utf-8' );

    my $root = XML::LibXML::Element->new( 'request' );
    $dom->setDocumentElement( $root );

    $self->construct_element( $root, $parameters );

    return $dom->toString( 1 );
}

sub construct_element {
    my $self    = shift;
    my $element = shift;
    my $hashref = shift;

    foreach my $key ( sort keys %$hashref ) {
        my $val = $hashref->{$key};

        # avoid "Unknown currency" API error
        next if $key eq 'currency_code' && !$val;

        # line_id is returned, but not sent
        next if $key eq 'line_id';

        # keys starting with an underscore are attributes
        if ( my ( $attr_key ) = $key =~ m{ \A _ (.*) \z }x ) {
            $element->setAttribute( $attr_key, $val );
        }

        # scalar values are text nodes
        elsif ( ref $val eq '' ) {
            $element->appendTextChild( $key, $val );
        }

        # arrayrefs are groups of nested values
        elsif ( ref $val eq 'ARRAY' ) {

            my $singular_key = $plural_to_singular{$key}
                || croak "couldnot convert '$key' to singular";

            my $wrapper = XML::LibXML::Element->new( $key );
            $element->addChild( $wrapper );

            foreach my $entry_val ( @$val ) {
                my $entry_node = XML::LibXML::Element->new( $singular_key );
                $wrapper->addChild( $entry_node );
                $self->construct_element( $entry_node, $entry_val );
            }
        }
        elsif ( ref $val eq 'HASH' ) {
            my $wrapper = XML::LibXML::Element->new( $key );
            $element->addChild( $wrapper );

            $self->construct_element( $wrapper, $val );

        }

    }

    return;
}

sub response_xml_to_node {
    my $self = shift;
    my $xml = shift || croak "No XML passed in";

    # get rid of any namespaces that will prevent simple xpath expressions
    $xml =~ s{ \s+ xmlns=\S+ }{}xg;

    my $parser = XML::LibXML->new();
    my $dom    = $parser->parse_string( $xml );

    my $response        = $dom->documentElement();
    my $response_status = $response->getAttribute( 'status' );

    if ( $response_status ne 'ok' ) {
        my $msg = XMLin( $xml );
        croak "FreshBooks server returned error: '$msg->{'error'}'";
    }

    return $response;
}

sub send_xml_to_freshbooks {

    my $self        = shift;
    my $xml_to_send = shift;
    my $fb          = $self->_fb;
    my $ua          = $fb->ua;
    my $response    = undef;
    $self->_sent_xml( $xml_to_send );

    if ( $fb->auth_token ) {

        $fb->_log( debug => "Not using OAuth" );

        my $request = HTTP::Request->new(
            'POST',              # method
            $fb->service_url,    # url
            undef,               # header
            $xml_to_send         # content
        );
        $response = $ua->request( $request );

    }
    else {

        $fb->_log( debug => "using OAuth" );

        $response = $fb->oauth->restricted_request( $fb->service_url,
            $xml_to_send );

    }

    if ( !$response->is_success ) {
        croak "FreshBooks request failed: " . $response->status_line;
    }

    return $response->content;
}

# When FreshBooks returns info on recurring items, it does not return the same
# frequency values as the values it requests.  This method provides a lookup
# table to fix this issue.

sub _frequency_cleanup {

    my $self = shift;

    return {
        y    => 'yearly',
        w    => 'weekly',
        '2w' => '2 weeks',
        '4w' => '4 weeks',
        m    => 'monthly',
        '2m' => '2 months',
        '3m' => '3 months',
        '6m' => '6 months',
    };

}

__PACKAGE__->meta->make_immutable( inline_constructor => 1 );

1;


__END__
=pod

=head1 NAME

Net::FreshBooks::API::Base

=head1 VERSION

version 0.17

=head2 new_from_node

  my $new_object = $class->new_from_node( $node );

Create a new object from the node given.

=head2 copy

  my $new_object = $self->copy(  );

Returns a new object with the fb object set on it.

=head2 create

  my $new_object = $self->create( \%args );

Create a new object. Takes the arguments and use them to create a new entry at
the FreshBooks end. Once the object has been created a 'get' request is issued
to fetch the data back from freshboks and to populate the object.

=head2 update

  my $object = $object->update();

Update the object, saving any changes that have been made since the get.

=head2 get

  my $object = $self->get( \%args );

Fetches the object using the FreshBooks API.

=head2 list

  my $iterator = $self->list( $args );

Returns an iterator that represents the list fetched from the server.
See L<Net::FreshBooks::API::Iterator> for details.

=head2 delete

  my $result = $self->delete();

Delete the given object.

=head1 INTERNAL METHODS

=head2 send_request

  my $response_data = $self->send_request( $args );

Turn the args into xml, send it to FreshBooks, recieve back the XML and
convert it back into a perl data structure.

=head2 method_string

  my $method_string = $self->method_string( 'action' );

Returns a method string for this class - something like 'client.action'.

=head2 api_name

  my $api_name = $self->api_name(  );

Returns the name that should be used in the API for this class.

=head2 node_name

  my $node_name = $self->node_name(  );

Returns the name that should be used in the XML nodes for this class. Normally
this is the same as the C<api_name> but can be overridden if needed.

=head2 id_field

  my $id_field = $self->id_field(  );

Returns the id field for this class.

=head2 field_names

  my @names = $self->field_names();

Return the names of all the fields.

=head2 field_names_rw

  my @names = $self->field_names_rw();

Return the names of all the fields that are marked as read and write.

=head2 parameters_to_request_xml

  my $xml = $self->parameters_to_request_xml( \%parameters );

Takes the parameters given and turns them into the xml that should be sent to
the server. This has some smarts that works around the tedium of processing perl
datastructures -> XML. In particular any key starting with an underscore becomes
an attribute. Any key pointing to an array is wrapped so that it appears
correctly in the XML.

=head2 construct_element( $element, $hashref )

Requires an XML::LibXML::Element object, followed by a HASHREF of attributes,
text nodes, nested values or child elements or some combination thereof.

=head2 response_xml_to_node

  my $params = $self->response_xml_to_node( $xml );

Take XML from FB and turn it into a datastructure that is easier to work with.

=head2 send_xml_to_freshbooks

  my $returned_xml = $self->send_xml_to_freshbooks( $xml_to_send );

Sends the xml to the FreshBooks API and returns the XML content returned. This
is the lowest part and is encapsulated here so that it can be easily overridden
for testing.

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

