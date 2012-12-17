#!/bin/bash

[ -e /etc/nospma ] && exit

if [ "$1" = "spma_ncm" ]
then
   shift
   [ "$NOTD_EXEC_TODO" != 'boot' ] && perl -e 'sleep rand 360'
fi

if [ "$1x" = "x" ] ; then
   args="--all" ;
else
   args=$* ;
fi

# run SPMA NCM component, SPMA and then NCM (for grub and the selected component)
#
/usr/sbin/ccm-fetch >>/var/log/ccm-fetch.log && \
/usr/sbin/ncm-ncd --configure spma && \
/usr/bin/spma && \
/usr/sbin/ncm-ncd --configure grub && \
/usr/sbin/ncm-ncd --configure $args




