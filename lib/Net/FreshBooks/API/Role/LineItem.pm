use strict;
use warnings;

package Net::FreshBooks::API::Role::LineItem;
BEGIN {
  $Net::FreshBooks::API::Role::LineItem::VERSION = '0.16';
}

use Moose::Role;
use Data::Dump qw( dump );
use Net::FreshBooks::API::InvoiceLine;

sub add_line {
    my $self      = shift;
    my $line_args = shift;

    push @{ $self->{lines} ||= [] },
        Net::FreshBooks::API::InvoiceLine->new($line_args);

    return 1;
}

1;

__END__
=pod

=head1 NAME

Net::FreshBooks::API::Role::LineItem

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

