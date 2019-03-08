#!/bin/bash

rm -f libqhyccd-*.tar.gz
ln ../libqhyccd-*.tar.gz .
rel=`cut -d' ' -f3 < /etc/redhat-release`
fedpkg --release f$rel local
