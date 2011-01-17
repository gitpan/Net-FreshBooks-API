
use strict;
use warnings;



use ExtUtils::MakeMaker 6.31;



my %WriteMakefileArgs = (
  'ABSTRACT' => 'Easy OO access to the FreshBooks.com API',
  'AUTHOR' => 'Edmund von der Burg <evdb@ecclestoad.co.uk>, Olaf Alders <olaf@wundercounter.com>',
  'BUILD_REQUIRES' => {
    'DateTime' => '0',
    'English' => '0',
    'File::Slurp' => '0',
    'Module::Build' => '0.3601',
    'Sub::Override' => '0',
    'Test::Exception' => '0',
    'Test::More' => '0',
    'Test::WWW::Mechanize' => '0',
    'Test::XML' => '0'
  },
  'CONFIGURE_REQUIRES' => {
    'ExtUtils::MakeMaker' => '6.31',
    'Module::Build' => '0.3601'
  },
  'DISTNAME' => 'Net-FreshBooks-API',
  'EXE_FILES' => [],
  'LICENSE' => 'perl',
  'NAME' => 'Net::FreshBooks::API',
  'PREREQ_PM' => {
    'B::Hooks::EndOfScope' => '0.09',
    'Carp' => '0',
    'Clone' => '0',
    'Data::Dump' => '0',
    'LWP::UserAgent' => '0',
    'Lingua::EN::Inflect' => '0',
    'Moose' => '0',
    'Moose::Role' => '0',
    'Net::OAuth::Simple' => '0',
    'Params::Validate' => '0',
    'Path::Class' => '0',
    'URI' => '0',
    'WWW::Mechanize' => '0',
    'XML::LibXML' => '0',
    'XML::Simple' => '0',
    'namespace::autoclean' => '0.11',
    'parent' => '0.224'
  },
  'VERSION' => '0.19',
  'test' => {
    'TESTS' => 't/*.t'
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



