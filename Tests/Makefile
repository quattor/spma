NAME = A
VERSION = 0

RPM_DIR = /usr/src/redhat/RPMS/i386

all: test

test: spm_test spma_test

spma_test: A B
	./run_tests

rpm:
	cd SPECS;rpm -ba spma-test-${NAME}-${VERSION}.spec

install:
	rpm -ivh ${RPM_DIR}/spma-test-${NAME}-${VERSION}-1.i386.rpm

clean:
	rpm -e spma-test-${NAME}-${VERSION}
	rm -f ${RPM_DIR}/spma-test-${NAME}-${VERSION}-1.i386.rpm

query:
	rpm -qa | grep -s spma-test;echo -n

spm_test:
	perl -w -I ./.. spmtests.pl

A:
	make NAME=A VERSION=0 rpm 
	make NAME=A VERSION=1 rpm 
	make NAME=A VERSION=2 rpm 
B:
	make NAME=B VERSION=0 rpm
	make NAME=B VERSION=1 rpm
	make name=B VERSION=2 rpm
