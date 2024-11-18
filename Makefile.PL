use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Sluice',
    VERSION_FROM     => 'lib/Sluice.pm',
    ABSTRACT         => 'Access log summariser for the command line',
    AUTHOR           => 'Provokke',
    LICENSE          => 'mit',
    MIN_PERL_VERSION => '5.016',
    EXE_FILES        => ['bin/sluice'],
    PREREQ_PM        => {
        'Getopt::Long' => 0,
        'JSON::PP'     => 0,
    },
    TEST_REQUIRES => {
        'Test::More' => '0.98',
    },
);
