use strict;
use warnings;

package Net::FreshBooks::API::Error;
BEGIN {
  $Net::FreshBooks::API::Error::VERSION = '0.20';
}

use Moose;
use Carp qw( croak );
use namespace::autoclean;

has 'last_server_error' => ( is => 'rw' );
has 'die_on_server_error' => ( is => 'rw', default => 1 );

sub handle_server_error {
    
    my $self = shift;
    my $msg  = shift;
    
    if ( $self->die_on_server_error ) {
        croak $msg;
    }
    
    $self->last_server_error( $msg );
    
    return;
    
}

1;

# ABSTRACT: FreshBooks error handling (experimental)


__END__
=pod

=head1 NAME

Net::FreshBooks::API::Error - FreshBooks error handling (experimental)

=head1 VERSION

version 0.20

=head1 SYNOPSIS

This error handling module is experimental.  You should not rely on it to
exist in later releases.

=head2 handle_server_error

Croaks with an appropriate error message if die_on_server_error is true.
Otherwise the error is stored in ->last_server_error.

=head1 AUTHORS

=over 4

=item *

Edmund von der Burg <evdb@ecclestoad.co.uk>

=item *

Olaf Alders <olaf@wundercounter.com>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Edmund von der Burg & Olaf Alders.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
