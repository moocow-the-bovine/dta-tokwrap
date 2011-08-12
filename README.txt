NAME
    README for dta-tokwrap - programs, scripts, and perl modules for DTA XML
    corpus tokenization

DESCRIPTION
    This package contains various utilities for tokenization of DTA
    "base-format" XML documents. see "INSTALLATION" for requirements and
    installation instructions, see "USAGE" for a brief introduction to the
    high-level command-line interface, and see "TOOLS" for an overview of
    the individual tools included in this distribution.

INSTALLATION
  Requirements
   C Libraries
    expat
        tested version(s): 1.95.8

    libxml2
        tested version(s): 2.7.3

    libxslt
        tested version(s): 1.1.24

   Perl Modules
    See DTA-TokWrap/README.txt for a full list of required perl modules.

   Development Tools
    C compiler
        tested version(s): gcc v4.3.3 / linux

    GNU flex (development only)
        tested version(s): 2.5.33

        Only needed if you plan on making changes to the lexer sources.

    GNU autoconf (SVN only)
        tested version(s): 2.61

        Required for building from SVN sources.

    GNU automake (SVN only)
        tested version(s): 1.9.6

        Required for building from SVN sources.

  Building from SVN
    To build this package from SVN sources, you must first run the shell
    command:

     bash$ sh ./autoreconf.sh

    from the distribution root directory BEFORE running ./configure.
    Building from SVN sources requires additional development tools to
    present on the build system. Then, follow the instructions in "Building
    from Source".

  Building from Source
    To build and install the entire package, issue the following commands to
    the shell:

     bash$ cd dta-tokwrap-0.01   # (or wherever you unpacked this distribution)
     bash$ sh ./configure        # configure the package
     bash$ make                  # build the package
     bash$ make install          # install the package on your system

    More details on the top-level installation process can be found in the
    file INSTALL in the distribution root directory.

    More details on building and installing the DTA::TokWrap perl module
    included in this distribution can be found in the perlmodinstall(1)
    manpage.

USAGE
    The perl program dta-tokwrap.perl installed from the DTA-TokWrap/
    distribution subdirectory provides a flexible high-level command-line
    interface to the tokenization of DTA XML documents.

  Input Format
    The dta-tokwrap.perl script takes as its input DTA "base-format" XML
    files, which are simply (TEI-conformant) UTF-8 encoded XML files with
    one "<c>" element per character:

    *   the document MUST be encoded in UTF-8,

    *   all text nodes to be tokenized should be descendants of a "<c>"
        element which is itself a descendant of a "<text>" element (XPath
        "//text//c//text()"),

    *   the document should contain exactly one such "<c>" element for *each
        logical character* which may be passed to the tokenizer,

    *   no "<c>" element may be a descendant of another "<c>" element, and

    *   if stand-off annotations are desired (the default), each "c" element
        should have a valid "xml:id" attribute.

  Example: Tokenizing a single XML file
    Assume we wish to tokenize a single DTA "base-format" XML file doc1.xml.
    Issue the following command to the shell:

     bash$ dta-tokwrap.perl doc1.xml

    ... This will create the following output files:

    doc1.t.xml
        "Master" tokenizer output file encoding sentence boundaries, token
        boundaries, and tokenizer-provided token analyses. Source for
        various stand-off annotation formats. This format can also be passed
        directly to and from the DTA::CAB(3pm) analysis suite using the
        DTA::CAB::Format::XmlNative(3pm) formatter class.

    doc1.w.xml
        Stand-off XML file encoding token boundaries. Contains references to
        "//c/@xml:id" attributes of doc1.xml.

    doc1.s.xml
        Stand-off XML file encoding token boundaries. Contains references to
        "//w/@xml:id" attributes of doc1.w.xml.

    doc1.a.xml
        Stand-off XML file encoding tokenizer-provided token analyses.
        Contains references to "//w/@xml:id" attributes of doc1.w.xml.

  Example: Tokenizing multiple XML files
    Assume we wish to tokenize a corpus of three DTA "base-format" XML files
    doc1.xml, doc2.xml, and doc3.xml. This is as easy as:

     bash$ dta-tokwrap.perl doc1.xml doc2.xml doc3.xml

    For each input document specified on the command line, master output
    files and stand-off annotation files will be created.

    See "the dta-tokwrap.perl manpage" for more details.

  Example: Tracing execution progess
    Assume we wish to tokenize a large corpus of XML input files doc*.xml,
    and would like to have some feedback on the progress of the tokenization
    process. Try:

     bash$ dta-tokwrap.perl -verbose=1 doc*.xml

    or:

     bash$ dta-tokwrap.perl -verbose=2 doc*.xml

    or even:

     bash$ dta-tokwrap.perl -traceAll doc*.xml

TOOLS
    This section provides a brief overview of the individual tools included
    in the dta-tokwrap distribution.

  Perl Scripts & Programs
    The perl scripts and programs included with this distribution are
    installed by default in /usr/local/bin and/or wherever your perl
    installs scripts by default (e.g. in `perl -MConfig -e 'print
    $Config{installsitescript}'`).

    dta-tokwrap.perl
        Top-level wrapper script for document tokenization using the
        DTA::TokWrap perl API.

    dtatw-add-c.perl
        Script to insert "<c>" elements and/or "xml:id" attributes for such
        elements into an XML document which does not yet contain them.
        Guaranteed not to clobber any existing //c IDs.

        //c/@xml:id attributes are generated by a simple document-global
        counter ("c1", "c2", ..., "c65536").

        See "the dtatw-add-c.perl manpage" for more details.

    dtatw-cids2local.perl
        Script to convert "//c/@xml:id" attributes to page-local encoding.

        See "the dtatw-cids2local.perl manpage" for more details.

    dtatw-add-w.perl
        Script to splice "<w>" elements encoded from a stand-off (.t.xml,
        .u.xml, or .w.xml) XML file into a compatible (but not necessarily
        the *original*) "base-format" (.char.xml) file. Rather slow, and a
        tad too generous with partial word segments, due to strict adjacency
        and boundary criteria.

        See "the dtatw-add-w.perl manpage" for more details.

    dtatw-add-s.perl
        Script to splice "<s>" elements encoded from a stand-off (.t.xml,
        .u.xml, or .s.xml) XML file into a compatible word-spliced (.cw.xml)
        file as output by the "dtatw-add-w.perl" script. Rather slow, and a
        tad too generous with partial sentence segments, due to strict
        adjacency and boundary criteria.

        See "the dtatw-add-s.perl manpage" for more details.

    dtatw-splice.perl
        Script to splice generic standoff attributes and/or content into a
        base file; useful e.g. for merging flat DTA::CAB standoff analyses
        into TEI-structured *.cws.xml files.

        See "the dtatw-splice.perl manpage" for more details.

    dtatw-get-ddc-attrs.perl
        Script to insert DDC-relevant attributes extracted from a base file
        into a *.t.xml file, producing a pre-DDC XML format file (by
        convention *.ddc.t.xml, a subset of the *.t.xml format).

        See "the dtatw-get-ddc-attrs.perl manpage" for more details.

    dtatw-get-header.perl
        Simple script to extract a single header element from an XML file
        (e.g. for later inclusion in a DDC XML format file).

        See "the dtatw-get-header.perl manpage" for more details.

        See "the dtatw-get-header.perl manpage" for more details.

    dtatw-xml2ddc.perl
        Script to convert *.ddc.t.xml files and optional headers to DDC-XML
        format.

        See "the dtatw-xml2ddc.perl manpage" for more details.

    dtatw-t-check.perl
        Simple script to check consistency of tokenizer output (*.t) offset
        + length fields with input (*.txt) file.

    dtatw-rm-c.perl
        Script to remove "<c>" elements from an XML document. Regex hack,
        fast but not exceedingly robust, use with caution. See also
        "dtatw-rm-c.xsl"

    dtatw-rm-w.perl
        Fast regex hack to remove "<w>" elements from an XML document

    dtatw-rm-s.perl
        Fast regex hack to remove "<s>" elements from an XML document.

    dtatw-rm-lb.perl
        Script to remove "<lb>" (line-break) elements from an XML document,
        replacing them with newlines. Regex hack, fast but not robust, use
        with caution. See also "dtatw-rm-lb.xsl"

    dtatw-tt-dictapply.perl
        Script to apply a type-"dictionary" in one-word-per-line (.tt)
        format to a token corpus in one-word-per-line (.tt) format.
        Especially useful together with standard UNIX utilities such as cut,
        grep, sort, and uniq.

    dtatw-cabtt2xml.perl
        Script to convert DTA::CAB::Format::TT (one-word-per-line with
        variable analysis fields identified by conventional prefixes) files
        to expanded .t.xml format used by dta-tokwrap. The expanded format
        should be identical to that used by the DTA::CAB::Format::Xml class.
        See also dtatw-txml2tt.xsl.

    file-substr.perl
        Script to extract a portion of a file, specified by byte offset and
        length. Useful for debugging index files created by other tools.

  GNU make build system template
    The distribution directory make/ contains a "template" for using GNU
    make to organizing the conversion of large corpora with the dta-tokwrap
    utilities. This is useful because:

    *   make's intuitive, easy-to-read syntax provides a wonderful vehicle
        for user-defined configuration files, obviating the need to remember
        the names of all 64 (at last count)
        "dta-tokwrap.perl|/dta-tokwrap.perl" options,

    *   make is very good at tracking complex dependencies of the sort that
        exist between the various temporary files generated by the
        dta-tokwrap utilities,

    *   make jobs can be made "robust" simply by adding a "-k"
        ("--keep-going") to the command-line, and

    *   last but certainly not least, make has built-in support for
        parallelization of complex tasks by means of the "-j N" ("--jobs=N")
        option, allowing us to take advantage of multiprocessor systems.

    By default, the contents of the distribution make/ subdirectory are
    installed to /usr/local/share/dta-tokwrap/make/. See the comments at the
    top of make/User.mak for instructions.

  Perl Modules
    DTA::TokWrap
        Top-level tokenization-wrapper module, used by dta-tokwrap.perl.

    DTA::TokWrap::Document
        Object-oriented wrapper for documents to be processed.

    DTA::TokWrap::Processor
        Abstract base class for elementary document-processing operations.

    See the DTA::TokWrap::Intro(3pm) manpage for more details on included
    modules, APIs, calling conventions, etc.

  XSL stylesheets
    The XSL stylesheets included with this distribution are installed by
    default in /usr/local/share/dta-tokwrap/stylesheets.

    dtatw-add-lb.xsl
        Replaces newlines with "<lb/>" elements in input document.

    dtatw-assign-cids.xsl
        Assigns missing "//c/@xml:id" attributes using the XSL
        "generate-id()" function.

    dtatw-rm-c.xsl
        Removes "<c>" elements from the input document. Slow but robust.

    dtatw-rm-lb.xsl
        Replaces "<lb/>" elements with newlines.

    dtatw-txml2tt.xsl
        Converts "master" tokenized XML output format (*.t.xml) to
        TAB-separated one-word-per-line format (*.mr.t aka *.t aka *.tt aka
        "tt" aka "CSV" aka DTA::CAB::Format::TT aka "TnT" aka "TreeTagger"
        aka "vertical" aka "moot-native" aka ...). See the mootfiles(5)
        manpage for basic format details, and see the top of the XSL script
        for some influential transformation parameters.

  C Programs
    Several C programs are included with the distribution. These are used by
    the dta-tokwrap.perl script to perform various intermediate document
    processing operations, and should not need to be called by the user
    directly.

    Caveat Scriptor: The following programs are meant for internal use by
    the "DTA::TokWrap" modules only, and their names, calling conventions,
    and very presence is subject to change without notice.

    dtatw-mkindex
        Splits input document doc.xml into a "character index" doc.cx (CSV),
        a "structural index" doc.sx (XML), and a "text index" doc.tx (UTF-8
        text).

    dtatw-rm-namespaces
        Removes namespaces from any XML document by renaming ""xmlns""
        attributes to ""xmlns_"" and ""xmlns:*"" attributes to ""xmlns_*"".
        Useful because XSL's namespace handling is annoyingly slow and ugly.

    dtatw-tokenize-dummy
        Dummy "flex" tokenizer. Useful for testing.

    dtatw-txml2sxml
        Converts "master" tokenized XML output format (*.t.xml) to
        sentence-level stand-off XML format (*.s.xml).

    dtatw-txml2wxml
        Converts "master" tokenized XML output format (*.t.xml) to
        token-level stand-off XML format (*.w.xml).

    dtatw-txml2axml
        Converts "master" tokenized XML output format (*.t.xml) to
        token-analysis-level stand-off XML format (*.a.xml).

SEE ALSO
    perl(1).

AUTHOR
    Bryan Jurish <jurish@bbaw.de>

