
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  "build_requires" => {
    "DateTime" => 0,
    "English" => 0,
    "File::Slurp" => 0,
    "Module::Build" => "0.3601",
    "Sub::Override" => 0,
    "Test::Exception" => 0,
    "Test::More" => 0,
    "Test::Simple" => "0.98",
    "Test::WWW::Mechanize" => 0,
    "Test::XML" => 0
  },
  "configure_requires" => {
    "ExtUtils::MakeMaker" => "6.30",
    "Module::Build" => "0.3601"
  },
  "dist_abstract" => "Easy OO access to the FreshBooks.com API",
  "dist_author" => [
    "Edmund von der Burg <evdb\@ecclestoad.co.uk>",
    "Olaf Alders <olaf\@wundercounter.com>"
  ],
  "dist_name" => "Net-FreshBooks-API",
  "dist_version" => "0.23",
  "license" => "perl",
  "module_name" => "Net::FreshBooks::API",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
    "B::Hooks::EndOfScope" => "0.09",
    "Carp" => 0,
    "Clone" => 0,
    "Data::Dump" => 0,
    "LWP::Protocol::https" => 0,
    "LWP::UserAgent" => 0,
    "Lingua::EN::Inflect" => 0,
    "Moose" => 0,
    "Moose::Role" => 0,
    "Net::OAuth::Simple" => 0,
    "Params::Validate" => 0,
    "Path::Class" => 0,
    "Scalar::Util" => 0,
    "URI" => 0,
    "WWW::Mechanize" => 0,
    "XML::LibXML" => 0,
    "XML::Simple" => 0,
    "base" => 0,
    "namespace::autoclean" => "0.11",
    "parent" => "0.224",
    "strict" => 0,
    "warnings" => 0
  },
  "script_files" => []
);


my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
