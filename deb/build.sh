#!/bin/bash

export DEBEMAIL=james@openastroproject.org
export DEBFULLNAME="James Fidell"

version=`cat version`

srcdir=libqhyccd-$version
debdir=debian
debsrc=$debdir/source
quiltconf=$HOME/.quiltrc-dpkg

debversion=`cat /etc/debian_version`
case $debversion in
  jessie/sid)
    compatversion=9
    ;;
  stretch/sid)
    compatversion=9
    ;;
  *)
    compatversion=10
    ;;
esac
echo $compatversion > debfiles/compat

rm -fr debfiles/patches
mkdir debfiles/patches
cp ../patches/*.patch debfiles/patches

tar zxf ../libqhyccd-$version.tar.gz
cd $srcdir
YFLAG=-y
dh_make -v | fgrep -q '1998-2011'
if [ $? -eq 0 ]
then
  YFLAG=''
fi
dh_make $YFLAG -l -f ../../libqhyccd-$version.tar.gz

sed -e "s/@@COMPAT@@/$compatversion/" < ../debfiles/control > $debdir/control
cp ../debfiles/copyright $debdir
cp ../debfiles/changelog $debdir
cp ../debfiles/compat $debdir
cp ../debfiles/watch $debdir
cp ../debfiles/libqhyccd.dirs $debdir
cp ../debfiles/libqhyccd.install $debdir
cp ../debfiles/libqhyccd.symbols $debdir
cp ../debfiles/libqhyccd.triggers $debdir
cp ../debfiles/libqhyccd-dev.dirs $debdir
cp ../debfiles/libqhyccd-dev.install $debdir
cp ../debfiles/libqhyccd-dev.examples $debdir
cp ../debfiles/qhy-firmware.dirs $debdir
cp ../debfiles/qhy-firmware.install $debdir

sed -e '/^.*[ |]configure./a\
	udevadm control --reload-rules || true' < $debdir/postinst.ex > $debdir/postinst
chmod +x $debdir/postinst
sed -e '/^.*[ |]remove./a\
	udevadm control --reload-rules || true' < $debdir/postrm.ex > $debdir/postrm
chmod +x $debdir/postrm
echo "3.0 (quilt)" > $debsrc/format

sed -e "s/DEBVERSION/$version/g" < ../debfiles/rules.overrides >> $debdir/rules

rm $debdir/README.Debian
rm $debdir/README.source
rm $debdir/libqhyccd1.*
rm $debdir/*.[Ee][Xx]


export QUILT_PATCHES="debian/patches"
export QUILT_PATCH_OPTS="--reject-format=unified"
export QUILT_DIFF_ARGS="-p ab --no-timestamps --no-index --color=auto"
export QUILT_REFRESH_ARGS="-p ab --no-timestamps --no-index"
mkdir -p $QUILT_PATCHES

for p in `ls -1 ../debfiles/patches`
do
  quilt --quiltrc=$quiltconf new $p
  for f in `egrep '^\+\+\+' ../debfiles/patches/$p | awk '{ print $2; }'`
  do
    quilt --quiltrc=$quiltconf add $f
  done
  patch -p0 < ../debfiles/patches/$p
	if [ $? -ne 0 ]; then
		echo "exiting..."
		exit 1
	fi
  quilt --quiltrc=$quiltconf refresh
done

dpkg-buildpackage -us -uc
if [ $? -ne 0 ]; then
	echo "exiting..."
	exit 1
fi

echo "Now run:"
echo
echo "    lintian -i -I --show-overrides libqhyccd_$version-1_amd64.changes"
