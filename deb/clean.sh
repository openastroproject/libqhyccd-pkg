#!/bin/bash

version=`cat version`

rm -fr libqhyccd-$version
rm -f *buildinfo
rm -f *changes
rm -f *.ddeb
rm -f *.dsc
rm -f *.orig.tar.gz
rm -f *.debian.tar.xz
rm -f debfiles/compat
rm -f debfiles/patches/*

if [ "$1" == "--all" ]
then
	rm -f *.deb
fi
