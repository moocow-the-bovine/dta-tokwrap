    README for dta-tokwrap - programs, scripts, and perl modules for DTA XML
    corpus tokenization

DESCRIPTION
    This package contains various utilities for tokenization of DTA
    "base-format" XML documents. See "REQUIREMENTS" for a list of package
    requirements, see "INSTALLATION" for installation instructions, see
    "USAGE" for a brief introduction to the high-level command-line
    interface, and see "TOOLS" for an overview of the individual tools
    included in this distribution.

REQUIREMENTS
  C Libraries
    expat           Tested version 1.95.8

    libxml2         Tested version 2.7.3

    libxslt         Tested version 1.1.24

  Perl Modules
    Cwd             Tested version 3.2501

    Encode          Tested version 2.23

    Env::Path       Tested version 0.18

    File::Basename  Tested version 2.76

    Getopt::Long    Tested version 2.37

    Pod::Usage      Tested version 1.35

    Time::HiRes     Tested version 1.9711

    XML::LibXML     Tested version 1.66

    XML::LibXSLT    Tested version 1.66

    XML::Parser     Tested version 2.36

  Development Tools
    C compiler      Tested gcc version 4.3.3 on linux.

    GNU flex        Tested version 2.5.33

    GNU autoconf (optional)
                    Required for building from SVN sources.

    GNU automake (optional)
                    Required for building from SVN sources.

INSTALLATION
    To build and install the entire package, issue the following commands to
    the shell:

     bash$ cd dta-tokwrap-0.01   # (or wherever you unpacked this distribution)
     bash$ ./configure           # configure the package
     bash$ make                  # build the package
     bash$ make install          # install the package on your system

    More details on the top-level installation process can be found in
    <file:INSTALL> in the distribution root directory.

    More details on building and installing the DTA::TokWrap perl module
    included in this distribution can be found in perlmodinstall.

SEE ALSO
    perl(1).

AUTHOR
    Bryan Jurish <jurish@bbaw.de>

