
use strict;
use warnings;

use Test::More;
use File::Slurp;
use Data::Dumper;

my @tests = (
    {   name => 'client.create response',
        in   => read_file('t/test_data/client.create.res.xml') . '',
        out  => {
            _status   => 'ok',
            client_id => 13,
        },
    },

    {   name => 'client.list response',
        in   => read_file('t/test_data/client.list.res.xml') . '',
        out  => {
            _status => 'ok',

            _page     => 1,
            _per_page => 15,
            _pages    => 1,
            _total    => 2,

            clients => [
                {   client_id    => 13,
                    organization => 'ABC Corp',
                    username     => 'janedoe',
                    first_name   => 'Jane',
                    last_name    => 'Doe',
                    email        => 'janedoe@freshbooks.com',
                },
                {   client_id    => 14,
                    organization => 'ABC Corp2',
                    username     => 'janedoe2',
                    first_name   => 'Jane2',
                    last_name    => 'Doe2',
                    email        => 'janedoe2@freshbooks.com',
                },
            ],
        },
    },

    {   name => 'client.get response',
        in   => read_file('t/test_data/client.get.res.xml') . '',

        out => {
            _status => 'ok',

            client_id    => 13,
            first_name   => 'Jane',
            last_name    => 'Doe',
            organization => 'ABC Corp',
            email        => 'janedoe@freshbooks.com',
            username     => 'janedoe',
            work_phone   => '(555) 123-4567',
            home_phone   => '(555) 234-5678',
            mobile       => undef,
            fax          => undef,
            credit       => '123.45',
            notes        => undef,
            p_street1    => '123 Fake St.',
            p_street2    => 'Unit 555',
            p_city       => 'New York',
            p_state      => 'New York',
            p_country    => 'United States',
            p_code       => '553132',
            s_street1    => undef,
            s_street2    => undef,
            s_city       => undef,
            s_state      => undef,
            s_country    => undef,
            s_code       => undef,

            # deprecated
            url      => undef,
            auth_url => undef,

            links => bless(
                {   client_view =>
                        'https://sample.freshbooks.com/client/12345-1-98969',
                    view =>
                        'https://sample.freshbooks.com/client/12345-1-98969-z'
                },
                'Net::FreshBooks::API::Links'
            ),
        },
    },

);

plan tests => 1 + @tests;

my $class = 'Net::FreshBooks::API::Client';
use_ok $class;

foreach my $test (@tests) {
    my $params = $class->response_xml_to_parameters( $test->{in} );
    is_deeply( $params, $test->{out}, $test->{name} )
        or warn Dumper( { got => $params, wanted => $test->{out} } );
}
