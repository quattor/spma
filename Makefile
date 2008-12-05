####################################################################
# Distribution Makefile
####################################################################

.PHONY: configure install clean

all: configure man
#
# BTDIR needs to point to the location of the build tools
#
BTDIR := quattor-build-tools
#
#
_btincl   := $(shell ls $(BTDIR)/quattor-buildtools.mk 2>/dev/null || \
             echo quattor-buildtools.mk)
include $(_btincl)

####################################################################
# Configure
####################################################################



SOURCE = ${COMP}.pl

CERN_CC_SOURCES = spma.notd spma_ncm.notd spma_wrapper.sh \
                  spma_ncm_wrapper.sh


SPM_NAMES = LocalList Op Package PackageListFile \
	                         Packager Policy RPMPkgr SysVPkgr

SPM_SOURCES = $(addsuffix .pm,${SPM_NAMES})

SPM_MANUALS = ${foreach f,${SPM_NAMES},doc/man3/${f}.3pm }

SPM    = $(addprefix SPM/,${SPM_SOURCES})

CERN_CC = $(addprefix CERN-CC/,${CERN_CC_SOURCES})

TESTS = $(addprefix Tests/,Makefile $(addprefix SPECS/,spma-test-A-0.spec \
	spma-test-A-1.spec spma-test-A-2.spec spma-test-B-0.spec \
	spma-test-B-1.spec spma-test-B-2.spec) run_tests run_tests_1 \
	run_tests_2 run_tests_3 spmtests.pl)


configure: $(SOURCE) $(SPM) $(CERN_CC) spma.conf man

man:	 docs

doc/man3/%.3pm: SPM/%.pm
	@rm -f $@
	@pod2man $(_podopt) $< > $@
	@gzip -f $@

doc/man1/%.1: %.pl
	@rm -f $@
	@pod2man $(_podopt) $< > $@
	@gzip -f $@

install: configure install_source install_doc

install_source: 
	@mkdir -p $(PREFIX)/$(QTTR_BIN)
	@mkdir -p $(PREFIX)/$(QTTR_SBIN)
	@mkdir -p $(PREFIX)/$(QTTR_ETC)/not.d
	@mkdir -p $(PREFIX)/$(QTTR_DOC)
	@mkdir -p $(PREFIX)/$(QTTR_VAR)/spma-cache
	@mkdir -p $(PREFIX)/$(QTTR_LOCKD)
	@$(COPY) -f $(SOURCE) $(PREFIX)/$(QTTR_BIN)/$(COMP)
	@$(COPY) -f -a CERN-CC/spma_ncm_wrapper.sh $(PREFIX)/$(QTTR_SBIN)
	@$(COPY) -f -a CERN-CC/spma_wrapper.sh $(PREFIX)/$(QTTR_SBIN)
	@$(COPY) -f -a CERN-CC/spma.notd $(PREFIX)/$(QTTR_ETC)/not.d/spma
	@$(COPY) -f -a CERN-CC/spma_ncm.notd $(PREFIX)/$(QTTR_ETC)/not.d/spma_ncm
	@mkdir -p $(PREFIX)/$(QTTR_PERLLIB)/SPM
	@$(COPY) -f ${SPM} $(PREFIX)/$(QTTR_PERLLIB)/SPM
	@mkdir -p $(PREFIX)/$(QTTR_ROTATED)
	@$(COPY) -f -a spma.conf $(PREFIX)/$(QTTR_ETC)
	@$(COPY) -f -a spma.logrotate $(PREFIX)/$(QTTR_ROTATED)/spma

install_doc:
	@mkdir -p $(PREFIX)/$(QTTR_MAN)/man1
	@$(COPY) -f doc/man1/${COMP}.1.gz $(PREFIX)/$(QTTR_MAN)/man1
	@mkdir -p $(PREFIX)/$(QTTR_MAN)/man3
	@${foreach f,${SPM_NAMES},$(COPY) -f doc/man3/${f}.3pm.gz $(PREFIX)/$(QTTR_MAN)/man3/SPM::${f}.3pm.gz;}
	@${foreach f,README MAINTAINER ChangeLog spma.conf, $(COPY) -f ${f} $(PREFIX)/$(QTTR_DOC);}


docs: docdir doc/man1/${COMP}.1 ${SPM_MANUALS}

docdir:
	@mkdir -p doc/man1
	@mkdir -p doc/man3

clean::
	@echo cleaning $(NAME) files ...
	@rm -rf $(SOURCE) $(SPM) $(CERN_CC) spma.conf doc/

