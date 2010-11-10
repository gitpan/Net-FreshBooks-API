use strict;
use warnings;

package Net::FreshBooks::API::Role::SendBy;
BEGIN {
  $Net::FreshBooks::API::Role::SendBy::VERSION = '0.15';
}

use Moose::Role;
use Data::Dump qw( dump );

sub send_by_email {
    my $self = shift;
    return $self->_send_using( 'sendByEmail' );
}

sub send_by_snail_mail {
    my $self = shift;
    return $self->_send_using( 'sendBySnailMail' );
}

sub _send_using {
    my $self = shift;
    my $how  = shift;

    my $method   = $self->method_string( $how );
    my $id_field = $self->id_field;

    my $res = $self->send_request(
        {   _method   => $method,
            $id_field => $self->$id_field,
        }
    );

    # refetch the estimate so that the flags are updated.
    $self->get( { $id_field => $self->$id_field } );

    return 1;
}

1;

__END__
=pod

=head1 NAME

Net::FreshBooks::API::Role::SendBy

=head1 VERSION

version 0.15

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

