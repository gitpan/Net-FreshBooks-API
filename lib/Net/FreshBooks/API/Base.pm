package Net::FreshBooks::API::Base;
use base 'Class::Accessor::Fast';

use strict;
use warnings;

use Data::Dumper;
use Carp;
use Clone qw(clone);

use Net::FreshBooks::API::Iterator;

use XML::Simple qw( :strict );
use LWP::UserAgent;

my %plural_to_singular = (
    clients => 'client',
    nesteds => 'nested',    # for testing
    lines   => 'line',
);

__PACKAGE__->mk_accessors('_fb');

=head2 create

  my $new_object = $self->create( \%args );

Create a new object. Takes the arguments and use them to create a new entry at
the FreshBooks end. Once the object has been created a 'get' request is issued
to fetch the data back from freshboks and to populate the object.

=cut

sub create {
    my $self   = shift;
    my $args   = shift;
    my $method = $self->method_string('create');

    # add any additional argument to ourselves
    $self->$_( $args->{$_} ) for keys %$args;

    # create the arguments
    my %create_args = ();
    $create_args{$_} = $self->$_
        for ( $self->field_names_rw );

    my $res = $self->send_request(
        {   _method         => $method,
            $self->api_name => \%create_args,
        }
    );

    return $self->get( { $self->id_field => $res->{ $self->id_field } } );
}

=head2 update

  my $object = $object->update();

Update the object, saving any changes that have been made since the get.

=cut

sub update {
    my $self   = shift;
    my $method = $self->method_string('update');

    my %args = ();
    $args{$_} = $self->$_ for ( $self->field_names_rw, $self->id_field );

    my $res = $self->send_request(
        {   _method         => $method,
            $self->api_name => \%args,
        }
    );

    return $self;
}

=head2 get

  my $object = $self->get( \%args );

Fetches the object using the FreshBooks API.

=cut

sub get {
    my $self   = shift;
    my $args   = shift;
    my $method = $self->method_string('get');

    my $res = $self->send_request(
        {   _method => $method,
            %$args,
        }
    );

    # cleanup all the keys
    delete $self->{$_}    #
        for grep { !m/^_/ } keys %$self;

    my $fields_config = $self->fields;

    # copy across th e new values provided
    foreach my $key ( grep { !m/^_/ } keys %$res ) {
        my $val = $res->{$key};

        # check that this field is not a special one
        if ( my $made_of = $fields_config->{$key}{made_of} ) {

            if ( $fields_config->{$key}{presented_as} eq 'array' ) {
                $val ||= [];
                $self->{$key} = [ map { $made_of->new($_) } @$val ];
            } else {
                $self->{$key} = $val ? $made_of->new($val) : undef;
            }

        } else {
            $self->{$key} = $val;
        }
    }

    return $self;
}

=head2 list

  my $iterator = $self->list( $args );

Returns an iterator that represents the list fetched from the server. See L<Net::FreshBooks::API::Iterator> for details.

=cut

sub list {
    my $self = shift;
    my $args = shift || {};

    return Net::FreshBooks::API::Iterator->new(
        {   parent_object => $self,
            args          => $args,
        }
    );
}

=head2 delete

  my $result = $self->delete();

Delete the given object.

=cut

sub delete {
    my $self = shift;

    my $method   = $self->method_string('delete');
    my $id_field = $self->id_field;

    my $res = $self->send_request(
        {   _method   => $method,
            $id_field => $self->$id_field,
        }
    );

    return 1;
}

=head1 INTERNAL METHODS

=head2 send_request

  my $response_data = $self->send_request( $args );

Turn the args into xml, send it to FreshBooks, recieve back the XML and convertit back into a perl data structure.

=cut

sub send_request {
    my $self = shift;
    my $args = shift;

    my $create_xml  = $self->parameters_to_request_xml($args);
    my $return_xml  = $self->send_xml_to_freshbooks($create_xml);
    my $return_data = $self->response_xml_to_parameters($return_xml);

    return $return_data;
}

=head2 method_string

  my $method_string = $self->method_string( 'action' );

Returns a method string for this class - something like 'client.action'.

=cut

sub method_string {
    my $self   = shift;
    my $action = shift;

    return $self->api_name . '.' . $action;
}

=head2 api_name

  my $api_name = $self->api_name(  );

Returns the name that should be used in the API for this class.

=cut

sub api_name {
    my $self = shift;
    my $name = ref($self) || $self;
    $name =~ s{^.*::}{};
    return lc $name;
}

=head2 id_field

  my $id_field = $self->id_field(  );

Returns theh id field for this class.

=cut

sub id_field {
    my $self = shift;
    return $self->api_name . "_id";
}

=head2 field_names

  my @names = $self->field_names();

Return the names of all the fields.

=cut

sub field_names {
    my $self = shift;
    return sort keys %{ $self->fields };
}

=head2 field_names_rw

  my @names = $self->field_names();

Return the names of all the fields that are marked as read and write.

=cut

sub field_names_rw {
    my $self   = shift;
    my $fields = $self->fields;
    return sort
        grep { $fields->{$_}{mutable} }
        keys %$fields;
}

=head2 parameters_to_request_xml

  my $xml = $self->parameters_to_request_xml( \%parameters );

Takes the parameters given and turns them into the xml that should be sent to
the server. This has some smarts that works around the tedium of processing perl
datastructures -> XMl. In particular any key starting with an underscore becomes
an attribute. Any key pointing to an array is wrapped so that it appears
correctly in the XML.

=cut

sub parameters_to_request_xml {
    my $self       = shift;
    my $parameters = clone(shift);

    $self->_massage_contents($parameters);

    my $req = { request => $parameters, };

    my $xs = XML::Simple->new();
    return $xs->XMLout(    #
        $req,              #
        KeyAttr  => [],
        KeepRoot => 1,
        XMLDecl  => '<?xml version="1.0" encoding="utf-8"?>',
    );
}

sub _massage_contents {
    my $self = shift;
    my $in   = shift;

    foreach my $key ( sort keys %$in ) {
        my $val = $in->{$key};

        # make sure that anything starting with '_' becomes an attr
        if ( my ($new_key) = $key =~ m{^_(.*)$} ) {
            $in->{$new_key} = delete $in->{$key};
        }

        # pad out arrays
        elsif ( ref $val eq 'ARRAY' ) {

            # Find what the singular of the key is
            my $singular = $plural_to_singular{$key}
                || croak("Can't turn '$key' into singular");

            # massage all the entries in the array
            my @new_values = ();
            foreach my $entry (@$val) {
                $self->_massage_contents($entry);
                push @new_values, $entry;
            }

            # put the new massage values back onto the data structure
            $in->{$key} = { $singular => \@new_values };

        }

        # if it is a hash then run that hash through here
        elsif ( ref $val eq 'HASH' ) {
            $self->_massage_contents($val);
        }

        # If it is a simple scalar then just put it in an array so that
        # XML::Simple gives it it's own tag.
        elsif ( ref $val eq '' ) {
            $in->{$key} = [$val];
        }

        # Don't know what to do - croak.
        else {
            croak "Don't know how to deal with $key => $val";
        }
    }

    # warn Dumper($in);

    return 1;
}

=head2 response_xml_to_parameters

  my $params = $self->response_xml_to_parameters( $xml );

Take XML from FB and turn it into a datastructure that is easier to work with.

=cut

sub response_xml_to_parameters {
    my $self = shift;
    my $xml = shift || die "No XML passed in";

    my $xs  = XML::Simple->new();
    my $raw = $xs->XMLin(           #
        $xml,                       #
        KeyAttr    => [],
        ForceArray => 1,
        KeepRoot   => 1,
    );

    my $res = $raw->{response}[0];

    # die Dumper( $res );

    if ( $res->{status} ne 'ok' ) {
        my $error = join ', ', @{ $res->{error} || [] };
        croak "FreshBooks server returned error: '$error'";
    }

    $self->_unmassage_contents($res);

    return $res;
}

sub _unmassage_contents {
    my $self = shift;
    my $in   = shift;

    # get the field config
    my $field_config = $self->fields;

    # warn Dumper($in);

    foreach my $key ( sort keys %$in ) {
        my $val = $in->{$key};

        # values that are scalar were attributes and should get underscores
        if ( ref $val eq '' ) {
            $in->{"_$key"} = delete $in->{$key};
        }

        # values that are arrays with a single scalar entry
        elsif (ref $val eq 'ARRAY'
            && scalar(@$val) == 1
            && ref $val->[0] eq '' )
        {
            $in->{$key} = $val->[0];
        }

        # if the value is an array with a hash in then it contains a list and
        # attributes. Promote the attribute up a level and expand the list.
        elsif ($plural_to_singular{$key}
            && ref $val eq 'ARRAY'
            && scalar(@$val) == 1
            && ref $val->[0] eq 'HASH' )
        {
            my $hash = $val->[0];

            my @entries = ();

            foreach my $key ( sort keys %$hash ) {
                my $val = $hash->{$key};

                if ( ref $val eq '' ) {
                    $in->{"_$key"} = $hash->{$key};
                } elsif ( ref $val eq 'ARRAY' ) {
                    push @entries, @$val;
                } else {
                    croak "Error";
                }
            }

            $self->_unmassage_contents($_) for @entries;

            $in->{$key} = \@entries;

        }

        # if the value is an array with a hash in it but it is not a plural
        # word then it is a single item - promote all the key up a level.
        elsif (ref $val eq 'ARRAY'
            && scalar(@$val) == 1
            && ref $val->[0] eq 'HASH' )
        {
            my $array = delete $in->{$key};
            my $hash  = $array->[0];

            foreach my $key ( sort keys %$hash ) {
                my $val = $hash->{$key};

                if ( ref $val eq '' ) {
                    $in->{"_$key"} = $hash->{$key};
                } elsif ( ref $val eq 'ARRAY' ) {

                    if ( my $singular = $plural_to_singular{$key} ) {
                        my @entries = @{ $val->[0]{$singular} };
                        $self->_unmassage_contents($_) for @entries;
                        $in->{$key} = \@entries;
                    } elsif ( my $made_of = $field_config->{$key}{made_of} ) {
                        my $args = $val->[0];
                        $self->_unmassage_contents($args);
                        $in->{$key} = $made_of->new($args);
                    } else {
                        $in->{$key} = ref $val->[0] ? undef : $val->[0];
                    }
                } else {
                    croak "Error";
                }
            }
        }

        # error - should not get here
        else {
            warn Dumper($val);
            croak "Can't process $key => $val.";
        }
    }

    # warn Dumper($in);

    return 1;
}

=head2 send_xml_to_freshbooks

  my $returned_xml = $self->send_xml_to_freshbooks( $xml_to_send );

Sends the xml to the FreshBooks API and returns the XML content returned. This
is the lowest part and is encapsulated here so that it can be easily overridden
for testing.

=cut

sub send_xml_to_freshbooks {
    my $self        = shift;
    my $xml_to_send = shift;
    my $fb          = $self->_fb;
    my $ua          = $fb->ua;
    # my $log         = $fb->log;

    my $request = HTTP::Request->new(
        'POST',              # method
        $fb->service_url,    # url
        undef,               # header
        $xml_to_send         # content
    );

    # $log->info("Sending request to FreshBooks");
    # $log->debug( $request->content );

    my $response = $ua->request($request);

    # $log->info("Received response from FreshBooks");
    # $log->debug( $response->content );

    croak "Request failed: " . $response->status_line
        unless $response->is_success;

    return $response->content;
}

1;
