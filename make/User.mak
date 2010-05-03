##-*- Mode: Makefile -*-
##
## File: User.mak
## Author: Bryan Jurish <jurish@bbaw.de>
## Description:
##  + User configuration makefile for corpus preparation via dta-tokwrap 
## Usage:
##  + DO NOT edit this file (unless you *really* know what you're doing)
##  + Copy this file "User.mak" to a new file, e.g. "MyConfig.mak", and
##    edit the new file to suit your needs
##  + Call make with "config=MyConfig.mak" on the command line, e.g.:
##    $ make config=MyConfig.mak all
##  + ... you atta be in buttah ...
##======================================================================

##======================================================================
## Variables: Sources & Targets

## xmldir=XMLDIR
##  + source directory containing DTA "base-format" XML sources
##
## xml=XMLFILES
##  + list of all DTA "base-format" XML sources (default: all .chr.xml files in XMLDIR)

##-- release
#xmldir = ./release
#xml    = $(wildcard $(xmldir)/*.xml)
#xml    = $(wildcard $(xmldir)/*.chr.xml)
#xml    = $(wildcard $(xmldir)/*.aligned.xml)


##-- small test
xmldir = ./xmlsrc
xml    = $(wildcard $(xmldir)/*.xml)
#xml    = $(wildcard $(xmldir)/*.chr.xml)
#xml    = $(xmldir)/test-raw.xml
#xml    = $(xmldir)/ex2a.xml
#xml    = $(xmldir)/ex2.xml
#xml    = $(xmldir)/ex4.xml
#xml    = $(wildcard $(xmldir)/ex[345].xml)
#xml    = $(xmldir)/ex6a.xml

##-- others
#xmldir = ./xmlsrc
#xmldir = ../examples
#xmldir = ./don
#
#xml  = $(xmldir)/ex2a.xml
#xml  = $(xmldir)/ex2.xml
#xml = $(wildcard $(xmldir)/*.xml)
#xml = $(wildcard $(xmldir)/*.chr.xml) $(wildcard $(xmldir)/*.char.xml)
#xml = $(wildcard $(xmldir)/*.chr.xml)
#xml = $(xmldir)/berg_ostasienbotanik_1866_pb.chr.xml $(xmldir)/boeheim_waffenkunde_1890.chr.xml
#xml = $(xmldir)/berg_ostasienbotanik_1866_pb.chr.xml

## corpus=NAME
##  + unique name for this corpus
##  + for summaries
corpus = $(notdir $(xmldir))

##======================================================================
## Variables: dta-tokwrap.perl

##--------------------------------------------------------------
## Variables: dta-tokwrap.perl: behavior

## dummytok=YES_OR_NO_OR_EMPTY
##  + whether to use the dummy or the "real" tokenizer
##  + default uses "real" tokenizer if available, otherwise dummy
#dummytok = yes

## abbrevlex=FILENAME_OR_EMPTY
##  + abbreviation lexicon to use for "real" tokenizer
##  + empty string uses dta-tokwrap.perl default
#abbrevlex=/usr/local/share/dta-resources/dta_abbrevs.lex

## mwelex=FILENAME_OR_EMPTY
##  + multiword-expression lexicon to use for "real" tokenizer
##  + empty string uses dta-tokwrap.perl default
#mwelex=/usr/local/share/dta-resources/dta_mwe.lex

## TOKENIZER=PROG AND INITIAL ARGUMENTS
##  + if set, should be a command-line which takes an argument TXTFILE
##    and writing output to stdout
##  + if set, dta-tokwrap.perl will not be called for tokenization,
##    so 'dummytok' variable will have no effect
#TOKENIZER ?= $(PROG_DIR)dtatw-tokenize-dummy
#TOKENIZER ?= dwds_tomasotath --to --to-offset --to-abbrev-lex=/usr/local/share/dta-resources/dta_abbrevs.lex --to-mwe-lex=/usr/local/share/dta-resources/dta_mwe.lex

## TOKWRAP_ALL=YES_OR_NO (anything but "yes" works like "no")
##  + if true, dta-tokwrap.perl will be called for all possible actions
##  + otherwise, C utilities will be called directly whenever possible
#TOKWRAP_ALL = yes


##--------------------------------------------------------------
## Variables: dta-tokwrap.perl: verbosity & logging

## verbose=LEVEL_OR_EMPTY
##  + verbosity level for dta-tokwrap.perl
verbose = 0

## loglevel=LOGLEVEL_OR_EMPTY
##  + log level for dta-tokwrap.perl
##  + empty string to take dta-tokwrap.perl defaults
#loglevel = TRACE

## logfile=LOGFILE_OR_EMPTY_STRING
##  + log file for dta-tokwrap.perl
#logfile = dta-tokwrap.log

## stderr=YES_OR_NO_OR_EMPTY
##  + empty string uses dta-tokwrap.perl default
#stderr = yes
#stderr = no

## trace=YES_OR_NO_OR_EMPTY
##  + whether to log trace messages for dta-tokwrap.perl
#trace = yes

## profile=YES_OR_NO_OR_EMPTY
##  + whether to log profiling information for dta-tokwrap.perl
profile = no

## twopts=USER_TOKWRAP_OPTIONS
##  + additional options and/or overrides for dta-tokwrap.perl
#twopts=

##======================================================================
## Variables: in-place execution (use local development code, or don't)

## INPLACE=YES_OR_NO_OR_EMPTY
##  + set to "yes" to use local development code
##  + default depends on whether ../src/dtatw-mkindex.c exists
#inplace = no

##======================================================================
## Variables: archiving & distribution

## arc_want_sources=YES_OR_NO (anything but "yes" is treated as "no")
##  + whether to include sources $(xml) in archive
##  + regardless of where the sources originated, they will be stuck
##    in the top-level "sources" subdirectory of the archive
arc_want_sources = yes

## arc_gzip=GZIP_FLAGS_OR_EMPTY
##  + value of environment variable GZIP for archive run, e.g. '--fast', '--best', ...
##  + leave empty to use gzip defaults
#arc_gzip = --best

## arcdir=DIR
##  + .tar.gz archive output directory
arcdir  = .

## arcname=NAME
##  + .tar.gz archive basename
arcname = dta-tokwrap-$(notdir $(PWD)).$(shell date +"%Y-%m-%d").$(shell hostname -s)

## arcfile=FILE
##  + complete filename of .tar.gz archive
arcfile = $(arcdir)/$(arcname).tar.gz

##======================================================================
## Variables: installation

## install_to=DIR
##  + destination directory for install (default = ./installed)
#install_to = /home/dta/dta_tokenized_xml

## install_user=USER
## install_group=GROUP
## install_mode=FILEMODE
install_user  = dta
install_group = users
install_mode    = 0644
install_dirmode = 0755

## install_makefile
##  + install makefile(s) (default=yes)
#install_makefiles = yes

## install_sources
##  + install source XML files? (default=yes)
#install_sources = yes

## install_standoff
##  + install standoff XML files? (default=yes)
#install_standoff = yes

## install_cws_xml
##  + install .cws.xml files? (default=no)
install_cws_xml = yes

## install_cab_xml
##  + install .dta-cab.xml files? (default=yes)
#install_cab_xml = yes

## install_summaries
##  + install summary files? (default=no)
install_summaries = yes

## install_misc
##  + install misc tokwrap files? (default=no)
install_misc = yes

## install_cab_misc
##  + install misc .dta-cab.* files? (default=no)
install_cab_misc = yes

## install_extra_files=EXTRA_FILES
##  + extra files to install (default=none)
#install_extra_files =


##======================================================================
## Variables: DTA::CAB stuff
##  + note that by default, DTA::CAB analysis is now performed locally,
##    using the Unicruft transliterating analyzer only
##  + to get full "old-style" analyses from a DTA::CAB server, call
##    the 'dta-cab-xml-full' target; results will be in
##    BASE.dta-cab.xml.full

## cab_server=URL
##  + URL of DTA::CAB server to query for creating .dta-cab.xml files
cab_server   = http://services.dwds.de:8088
#cab_server   = http://localhost:8088

## cab_analyzer=NAME
##  + analyzer name for creation of .dta-cab.xml files
cab_analyzer = dta.cab.default

## cab_options=OPTIONS
##  + additional options for dta-cab-xmlrpc-client.perl
cab_options = -noprofile -verbose=info -ao do_eqpho=0 -ao do_eqrw=0
#cab_options = -verbose=info

##======================================================================
## Variables: XML checking stuff

## xml_wfcheck = COMMAND_PREFIX
##  + command prefix for checking XML well-formedness
##  + if given as empty string, will use xmlstarlet or xmllint (whichever is found first)
##  + command should be calleable as
##    $(COMMAND_PREFIX) FILE_LIST 2>&1 >$(ERROR_FILE)
#xml_wfcheck = xmllint --noout
#xml_wfcheck = xmlstarlet val -w -e
