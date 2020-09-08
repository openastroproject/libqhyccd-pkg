#!/usr/bin/perl
#
# build-tar.pl
#
# Copyright 2019,2020
#   James Fidell (james@openastroproject.org)
#
# License:
#
# This file is part of the Open Astro Project.
#
# The Open Astro Project is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# The Open Astro Project is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with the Open Astro Project.  If not, see
# <http://www.gnu.org/licenses/>.
#

use strict;
use diagnostics;

my $searchDir = ".";
my $buildDir = "./build";

my $verbose = 0;
my $skipMismatches = 1;

if ( !defined( $ARGV[0] )) {
	print "usage: $0 <version> [<real-version>]\n";
	print "  where <version> is 'YY.M.D' from the tar file name\n\n";
	print "  and <real-version> is 'YY.M.D' from the library version, if required\n\n";
	exit ( -1 );
}

if ( -d $buildDir ) {
	die "$buildDir already exists";
}

mkdir $buildDir || die "Can't create directory $buildDir: $!";

my $ver = $ARGV[0];
my $realVersion = '';
if ( defined ( $ARGV[1])) {
	$realVersion = $ARGV[1];
}

opendir ( my $dirHandle, $searchDir ) ||
	die "Can't open directory for read: $!";
my @tarFiles = grep {
	/sdk_.*_${ver}\.tgz$/ && -f "$searchDir/$_"
} readdir ( $dirHandle );
closedir $dirHandle;

if ( @tarFiles < 1 ) {
	die "No matching files found in $searchDir";
}

chdir $buildDir || die "Can't change to directory $buildDir: $!";

my $version = $realVersion;
my $newVersion;
foreach ( @tarFiles ) {
  my $tarFile = $_;
	print "processing tar file: $tarFile\n" if ( $verbose );
	my $topDir = substr $tarFile, 0, -4;
	my $arch = '';
	if ( substr ( $topDir, 0, 12 ) eq 'sdk_linux64_' ) {
		$arch = 'x64';
	} elsif ( substr ( $topDir, 0, 12 ) eq 'sdk_linux32_' ) {
		$arch = 'x86';
	} elsif ( substr ( $topDir, 0, 10 ) eq 'sdk_Arm64_' ) {
		$arch = 'aarch64';
	} elsif ( substr ( $topDir, 0, 10 ) eq 'sdk_arm32_' ) {
		$arch = 'armhf';
	}
	if ( $arch eq '' ) {
		die "Don't recognise architecture for $topDir";
	}
	print "architecture = $arch\n" if ( $verbose );
	my $cmd = "tar zxvf ../$tarFile";
  my @files = split /\n/, `$cmd`;
	my @matches = grep { /\/libqhyccd.so\.\d+\.\d+\.\d+$/ } @files;
	if ( @matches < 1 ) {
		die "No matching file found for .../libqhyccd.so\\.\\d+\\.\\d+\\.\\d+";
	}
	( $newVersion ) = $matches[0] =~ /\/libqhyccd.so\.(\d+\.\d+\.\d+)$/;
	if ( !defined ( $newVersion )) {
		die "Error matching version string from '${matches[0]}'";
	}
	print "Library version appears to be $newVersion\n";
	if ( $version eq '' ) {
		print "Setting version to $newVersion\n";
		$version = $newVersion;
	} else {
		if ( $realVersion eq '' && $newVersion ne $version ) {
			print "Version $newVersion doesn't match $version already seen\n";
			if ( $newVersion ge $version ) {
				$version = $newVersion;
			} else {
				die "Halting on version mismatch";
			}
		}
	}
	foreach ( @files ) {
		my $fullname = $_;
		if ( -d $fullname ) {
			# print "skipping directory $fullname\n" if ( $verbose );
			next;
		}
    if ( -f $fullname || -l $fullname ) {
			# strip off the dir name
			my $filename = $fullname;
			$filename =~ s!^(\./)?$topDir/!!;
			my ( $dirname, $basename );
			if ( $filename =~ m!/! ) {
				( $dirname, $basename ) = $filename =~ /^(.*)\/(.*)$/;
			} else {
				$dirname = '';
				$basename = $filename;
			}
			if ( $dirname eq 'usr/local/cmake_modules' ||
					$dirname =~ m!^usr/local/testapp! ||
					$dirname =~ m!^usr/local/riffa_linux_driver! ||
					$dirname eq 'usr/local/include' ||
					$dirname eq 'usr/local/doc' ||
					$dirname eq 'lib/firmware/qhy' ||
					$dirname eq 'lib/udev/rules.d' ||
					$dirname eq 'usr/local/udev' ||
					$dirname eq 'etc/udev/rules.d' ) {
				$dirname = "libqhyccd-$version/$dirname";
				if ( -f "$dirname/$basename" ) {
					my $same = system ( "cmp -s $fullname $dirname/$basename" );
					if ( $same != 0 ) {
						if ( $skipMismatches ) {
							print "$fullname is not the same in all architectures\n";
							next;
						} else {
							die "$fullname is not the same in all architectures";
						}
					}
				}
				if ( ! -d $dirname ) {
					print "making directory $dirname\n" if ( $verbose );
					system ( "mkdir -p $dirname" ) == 0 or
							die "Can't mkdir -p $dirname: $!";
				}
				print "moving $fullname to $dirname/$basename\n" if ( $verbose );
				rename $fullname, "$dirname/$basename" ||
						die "Can't mv $fullname to $dirname/$basename: $!";
				next;
			}
			# ignore <something>.sh scripts
			if ( substr ( $basename, -3, 3 ) eq '.sh' ) {
				print "ignoring script file $fullname\n" if ( $verbose );
				next;
			}
			if ( $dirname eq 'usr/local/lib' ||
					$dirname eq 'sbin' ) {
				$dirname = "libqhyccd-$version/$dirname/$arch";
				if ( ! -d $dirname ) {
					print "making directory $dirname\n" if ( $verbose );
					system ( "mkdir -p $dirname" ) == 0 or
							die "Can't mkdir -p $dirname: $!";
				}
				print "moving $fullname to $dirname/$basename\n" if ( $verbose );
				rename $fullname, "$dirname/$basename" ||
						die "Can't mv $fullname to $dirname/$basename: $!";
				next;
			}
			print "Don't know what to do with $fullname\n";
		}
	}
}

print "Now copy over any missing firmware files and run:\n";
print "  cd $buildDir\n";
print "  tar zcf ../libqhyccd-$version.tar.gz ./libqhyccd-$version\n";
