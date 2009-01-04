package Net::FreshBooks::API::Iterator;
use base 'Class::Accessor::Fast';

use strict;
use warnings;

use Net::FreshBooks::API::Base;
use Data::Dumper;
use Lingua::EN::Inflect qw( PL );

__PACKAGE__->mk_accessors(
    'parent_object',    # The object we are iterating for
    'args',             # args used in the search
    'total',            # The total number of results
    'pages',            # the number of result pages
    'items',            # a list of all items
    'current_index',    # which item we are currently on
);

=head2 new

    my $iterator = $class->new(
        {   parent_object => $parent_object,
            args         => {...},
        }
    );

Create a new iterator object. As part of creating the iterator a request is sent
to FreshBooks.

=cut

sub new {
    my $class = shift;
    my $self = bless shift, $class;

    my $request_args = {
        _method => $self->parent_object->method_string('list'),

        # defaults
        page     => 1,
        per_page => 15,

        %{ $self->args },
    };

    my $response_data = $self->parent_object->send_request($request_args);

    $self->pages( $response_data->{_pages} );
    $self->total( $response_data->{_total} );
    $self->items( $response_data->{ PL( $self->parent_object->api_name ) } );

    return $self;
}

=head2 next

  my $next_result = $iterator->next(  );

Returns the next item in the iterator.

=cut

sub next {
    my $self = shift;

    # work out what the current index should be
    my $current_index = $self->current_index;
    $current_index = defined($current_index) ? $current_index + 1 : 0;
    $self->current_index($current_index);

    # check that there is a next item
    # FIXME - add fetching the next page if needed here
    my $next_item = $self->items->[$current_index];
    return unless $next_item;

    my $id_field = $self->parent_object->id_field;

    return $self->parent_object->get(
        { $id_field => $next_item->{$id_field} } );
}

1;
