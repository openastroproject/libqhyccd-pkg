# libqhyccd-pkg
Linux packaging scripts etc. for libqhyccd, the QHY camera SDK

A gzipped tar file created from all of QHY's Linux SDK files needs to be
created to start with.  The build-tar.pl script should do this if all
of the SDK files are in the same directory.

For .deb packages:

Run the build.sh script in the deb directory.  clean.sh cleans up the
build files and needs to be run before build.sh can be used again.

For .rpm packages:

Run the build.sh script in the rpm directory.
