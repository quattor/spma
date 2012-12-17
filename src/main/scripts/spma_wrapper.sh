#!/bin/bash


[ -e /etc/nospma ] && exit

if [ "$1" = "spma" ]
then
   shift
   [ "$NOTD_EXEC_TODO" != 'boot' ] && perl -e 'sleep rand 360'
fi

# run fetch, ncm-spma, SPMA, ncm-grub
#

/usr/sbin/ccm-fetch >>/var/log/ccm-fetch.log && \
/usr/sbin/ncm-ncd --configure spma && \
/usr/bin/spma $* && \
/usr/sbin/ncm-ncd --configure grub $*


