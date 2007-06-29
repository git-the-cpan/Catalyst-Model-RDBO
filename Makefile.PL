use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'Catalyst::Model::RDBO',
    VERSION_FROM => 'lib/Catalyst/Model/RDBO.pm',    # finds $VERSION
    PREREQ_PM    => {

        'Rose::DB::Object' => 0.01,

    },                                               # e.g., Module::Name => 1.1
    (
     $] >= 5.005
     ?    ## Add these new keywords supported since 5.005
       (
         ABSTRACT_FROM =>
           'lib/Catalyst/Model/RDBO.pm',    # retrieve abstract from module
         AUTHOR => 'Peter Karman <perl@peknet.com>'
       )
     : ()
    ),
);
