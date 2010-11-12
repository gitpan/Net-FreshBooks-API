use strict;
use warnings;

package Net::FreshBooks::API::Role::CRUD;
BEGIN {
  $Net::FreshBooks::API::Role::CRUD::VERSION = '0.16';
}

use Moose::Role;
use Data::Dump qw( dump );

sub create {
    my $self   = shift;
    my $args   = shift;
    my $method = $self->method_string( 'create' );

    # add any additional argument to ourselves
    $self->$_( $args->{$_} ) for keys %$args;

    # create the arguments
    my %create_args = ();
    $create_args{$_} = $self->$_ for ( $self->field_names_rw );

    # remove arguments that have not been set (and so are undef)
    delete $create_args{$_}    #
        for grep { !defined $create_args{$_} }
        keys %create_args;

    my $res = $self->send_request(
        {   _method         => $method,
            $self->api_name => \%create_args,
        }
    );

    my $xpath  = '//response/' . $self->id_field;
    my $new_id = $res->findvalue( $xpath );

    return $self->get( { $self->id_field => $new_id } );
}

sub update {
    my $self   = shift;
    my $args   = shift;
    my $method = $self->method_string( 'update' );
    
    # process any fields passed directly to this method
    foreach my $field ( $self->field_names_rw ) {
        $self->$field( $args->{$field} ) if exists $args->{$field};
    }
    
    my %args = ();
    $args{$_} = $self->$_ for ( $self->field_names_rw, $self->id_field );

    $self->_fb->_log( debug => dump( \%args ) );

    my $res = $self->send_request(
        {   _method         => $method,
            $self->api_name => \%args,
        }
    );

    return $self;
}

sub get {
    my $self   = shift;
    my $args   = shift;
    my $method = $self->method_string( 'get' );

    my $res = $self->send_request(
        {   _method => $method,
            %$args,
        }
    );

    return $self->_fill_in_from_node( $res );
}

sub delete {    ## no critic
    ## use critic
    my $self = shift;

    my $method   = $self->method_string( 'delete' );
    my $id_field = $self->id_field;

    my $res = $self->send_request(
        {   _method   => $method,
            $id_field => $self->$id_field,
        }
    );

    return 1;
}


sub list {
    my $self = shift;
    my $args = shift || {};

    return Net::FreshBooks::API::Iterator->new(
        {   parent_object => $self,
            args          => $args,
        }
    );
}

sub get_all {

    my $self = shift;
    my $args = shift || {};

    # override any pagination
    $args->{per_page} = 100;

    my @all     = ();
    my $per_page = 100;
    my $page     = 1;

    while ( 1 ) {

        my @subset = ();
        $args->{page} = $page;
        my $iter = $self->list( $args );

        while ( my $obj = $iter->next ) {
            push @subset, $obj;
        }
        push @all, @subset;

        last if scalar @subset < $per_page;

        ++$page;
    }

    return \@all;

}



1;

__END__
=pod

=head1 NAME

Net::FreshBooks::API::Role::CRUD

=head1 VERSION

version 0.16

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

