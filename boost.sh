#!/bin/bash

#===============================================================================
# Filename:  boost.sh
# Author:   Pete Goodliffe
# Copyright: (c) Copyright 2009 Pete Goodliffe
# Licence:   Please feel free to use this, with attribution
# Modified version
#===============================================================================
#
# Builds a Boost framework for the iPhone.
# Creates a set of universal libraries that can be used on an iPhone and in the
# iPhone simulator. Then creates a pseudo-framework to make using boost in Xcode
# less painful.
#
# To configure the script, define:
#   BOOST_LIBS:  which libraries to build
#   IPHONE_SDKVERSION: iPhone SDK version (e.g. 5.1)
#
# Then go get the source tar.bz of the boost you want to build, shove it in the
# same directory as this script, and run "./boost.sh". Grab a cuppa. And voila.
#===============================================================================

# Arguments
# download - not yet implemented
# clean
# --with-c++11 - Compile using Clang, std=c++11 and stdlib=libc++
# not yet implemented - build ios or osx only

DOWNLOAD=0
CLEAN=0
CPP11_FLAGS=""
VERSION=""
BUILD_IOS=1
BUILD_OSX=1

usage () {
    echo "Usage: ${0##*/} [clean] [-h|--help] [--with-c++11] -v|--version VERSION" 1>&2
    echo "Options:" 1>&2
    echo -e "\t-h, --help\t\t\t\tPrint complete usage." 1>&2
    echo -e "\tclean\t\t\tPerform clean build." 1>&2
    echo -e "\tdownload\t\t\tDownload tarball (if doesn't exist)." 1>&2
    echo -e "\t--with-c++11\t\t\t\tCompile using Clang, std=c++11 and stdlib=libc++." 1>&2
    echo -e "\t-v, --version VERSION\t\t\tVersion to build. Make sure you have boost_<VERSION>.tar.bz2 downloaded and ready." 1>&2
    exit 2
}

while [ "$1" != "" ]; do
    case $1 in
        --with-c++11 ) CPP11_FLAGS="-std=c++11 -stdlib=libc++"
                    ;;
        clean ) CLEAN=1
                    ;;
        download )  DOWNLOAD=1
                    ;;
        -v | --version ) shift
                        VERSION=$1
                        ;;
        -h | --help ) usage
                        exit
                        ;;
        * )   usage
                    exit 1
    esac
    # next arg
    shift
done

# Version is mandatory
[ -z $VERSION ] && usage

# : ${BOOST_LIBS:="graph random chrono thread signals filesystem regex system date_time"}
: ${BOOST_LIBS:="atomic chrono date_time exception filesystem graph graph_parallel iostreams locale mpi program_options python random regex serialization signals system test thread timer wave"}
#atomic chrono context coroutine date_time exception filesystem graph graph_parallel iostreams locale log math mpi program_options python random regex serialization signals system test thread timer wave
: ${IPHONE_SDKVERSION:=$(xcodebuild -showsdks | grep iphoneos | egrep "[[:digit:]]+\.[[:digit:]]+" -o | tail -1)}
: ${OSX_SDKVERSION:=10.8}
: ${XCODE_ROOT:=$(xcode-select -print-path)}
: ${EXTRA_CPPFLAGS:="-DBOOST_AC_USE_PTHREADS -DBOOST_SP_USE_PTHREADS $CPP11_FLAGS"}

# The EXTRA_CPPFLAGS definition works around a thread race issue in
# shared_ptr. I encountered this historically and have not verified that
# the fix is no longer required. Without using the posix thread primitives
# an invalid compare-and-swap ARM instruction (non-thread-safe) was used for the
# shared_ptr use count causing nasty and subtle bugs.
#
# Should perhaps also consider/use instead: -BOOST_SP_USE_PTHREADS

: ${TARBALLDIR:=$(pwd)}
: ${SRCDIR:=$(pwd)/src}
: ${IOSBUILDDIR:=$(pwd)/ios/build}
: ${OSXBUILDDIR:=$(pwd)/osx/build}
: ${PREFIXDIR:=$(pwd)/ios/prefix}
: ${IOSFRAMEWORKDIR:=$(pwd)/ios/framework}
: ${OSXFRAMEWORKDIR:=$(pwd)/osx/framework}
: ${COMPILER:="clang++"}

BOOST_SRC=$SRCDIR/boost
: ${BOOST_VERSION:=$VERSION}
BOOST_VERSION_SFX=${BOOST_VERSION//./_}

BOOST_TARBALL=$TARBALLDIR/boost_$BOOST_VERSION_SFX.tar.bz2
BOOST_SRC=$SRCDIR/boost_${BOOST_VERSION_SFX}

#===============================================================================

ARM_DEV_DIR=$XCODE_ROOT/Platforms/iPhoneOS.platform/Developer/usr/bin
SIM_DEV_DIR=$XCODE_ROOT/Platforms/iPhoneSimulator.platform/Developer/usr/bin

ARM_COMBINED_LIB=$IOSBUILDDIR/lib_boost_arm.a
SIM_COMBINED_LIB=$IOSBUILDDIR/lib_boost_x86.a

#===============================================================================


#===============================================================================
# Functions
#===============================================================================

abort()
{
    echo
    echo "Aborted: $@"
    exit 1
}

doneSection()
{
    echo
    echo "  ================================================================="
    echo "  Done"
    echo
}

#===============================================================================

cleanEverythingReadyToStart()
{
    echo Cleaning everything before we start to build...
    rm -rf iphone-build iphonesim-build osx-build
    rm -rf $BOOST_SRC
    rm -rf $IOSBUILDDIR
    rm -rf $OSXBUILDDIR
    rm -rf $PREFIXDIR
    rm -rf $IOSFRAMEWORKDIR/$FRAMEWORK_NAME.framework
    rm -rf $OSXFRAMEWORKDIR/$FRAMEWORK_NAME.framework
    doneSection
}

#===============================================================================
downloadBoost()
{
    if [ ! -s $BOOST_TARBALL ]; then
        echo Downloading boost $BOOST_TARBALL...
        curl -L -o $BOOST_TARBALL http://sourceforge.net/projects/boost/files/boost/$VERSION/$BOOST_TARBALL/download
    fi
    doneSection
}

#===============================================================================
unpackBoost()
{
    echo Unpacking boost into $SRCDIR...
    [ -d $SRCDIR ] || mkdir -p $SRCDIR
    [ -d $BOOST_SRC ] || ( cd $SRCDIR; tar xfj $BOOST_TARBALL )
    [ -d $BOOST_SRC ] && echo " ...unpacked as $BOOST_SRC"
    doneSection
}

#===============================================================================
restoreBoost()
{
    cp $BOOST_SRC/tools/build/v2/user-config.jam-bk $SRCDIR/tools/build/v2/user-config.jam
}

writeBjamUserConfig()
{
    echo Updating boost into $BOOST_SRC...

# armv6 version
# using darwin : ${IPHONE_SDKVERSION}~iphone
#   : $XCODE_ROOT/Toolchains/XcodeDefault.xctoolchain/usr/bin/$COMPILER -arch armv6 -arch armv7 -arch armv7s -fvisibility=hidden -fvisibility-inlines-hidden $EXTRA_CPPFLAGS
#   : <striper> <root>$XCODE_ROOT/Platforms/iPhoneOS.platform/Developer
#   : <architecture>arm <target-os>iphone
#   ;

    # use sed to cut stuff if it's already there to avoid duplicated entries
    sed -i.bak '/# BOOST/,$d' $BOOST_SRC/tools/build/v2/user-config.jam

    cp $BOOST_SRC/tools/build/v2/user-config.jam $BOOST_SRC/tools/build/v2/user-config.jam-bk
    cat >> $BOOST_SRC/tools/build/v2/user-config.jam <<EOF
# BOOST
using darwin : ${IPHONE_SDKVERSION}~iphone
   : $XCODE_ROOT/Toolchains/XcodeDefault.xctoolchain/usr/bin/$COMPILER -arch armv7 -arch armv7s -arch arm64 -fvisibility=hidden -fvisibility-inlines-hidden $EXTRA_CPPFLAGS
   : <striper> <root>$XCODE_ROOT/Platforms/iPhoneOS.platform/Developer
   : <architecture>arm <target-os>iphone
   ;
using darwin : ${IPHONE_SDKVERSION}~iphonesim
   : $XCODE_ROOT/Toolchains/XcodeDefault.xctoolchain/usr/bin/$COMPILER -arch i386 -fvisibility=hidden -fvisibility-inlines-hidden $EXTRA_CPPFLAGS
   : <striper> <root>$XCODE_ROOT/Platforms/iPhoneSimulator.platform/Developer
   : <architecture>x86 <target-os>iphone
   ;
EOF

    doneSection
}

#===============================================================================

inventMissingHeaders()
{
    # These files are missing in the ARM iPhoneOS SDK, but they are in the simulator.
    # They are supported on the device, so we copy them from x86 SDK to a staging area
    # to use them on ARM, too.
    echo "Invent missing headers"
    cp $XCODE_ROOT/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator${IPHONE_SDKVERSION}.sdk/usr/include/{crt_externs,bzlib}.h $BOOST_SRC
}

#===============================================================================

bootstrapBoost()
{
    cd $BOOST_SRC
    BOOST_LIBS_COMMA=$(echo $BOOST_LIBS | sed -e "s/ /,/g")
    echo "Bootstrapping (with libs $BOOST_LIBS_COMMA)"
    ./bootstrap.sh --with-libraries=$BOOST_LIBS_COMMA
    doneSection
}

#===============================================================================

buildBoost()
{
    cd $BOOST_SRC

    # Install this one so we can copy the includes for the frameworks...
    ./bjam -j16 --build-dir=iphone-build --stagedir=iphone-build/stage --prefix=$PREFIXDIR toolset=darwin architecture=arm target-os=iphone macosx-version=iphone-${IPHONE_SDKVERSION} define=_LITTLE_ENDIAN link=static stage
    ./bjam -j16 --build-dir=iphone-build --stagedir=iphone-build/stage --prefix=$PREFIXDIR toolset=darwin architecture=arm target-os=iphone macosx-version=iphone-${IPHONE_SDKVERSION} define=_LITTLE_ENDIAN link=static install

    # ./bjam -j16 --build-dir=iphone-build --stagedir=iphone-build/stage --prefix=$PREFIXDIR toolset=darwin-${IPHONE_SDKVERSION}~iphonesim architecture=arm target-os=iphone macosx-version=iphone-${IPHONE_SDKVERSION} define=_LITTLE_ENDIAN link=static stage
    # ./bjam -j16 --build-dir=iphone-build --stagedir=iphone-build/stage --prefix=$PREFIXDIR toolset=darwin-${IPHONE_SDKVERSION}~iphonesim architecture=arm target-os=iphone macosx-version=iphone-${IPHONE_SDKVERSION} define=_LITTLE_ENDIAN link=static install
    doneSection

    ./bjam -j16 --build-dir=iphonesim-build --stagedir=iphonesim-build/stage --toolset=darwin-${IPHONE_SDKVERSION}~iphonesim architecture=x86 target-os=iphone macosx-version=iphonesim-${IPHONE_SDKVERSION} link=static stage
    doneSection

    ./b2 -j16 --build-dir=osx-build --stagedir=osx-build/stage toolset=clang cxxflags="-std=c++11 -stdlib=libc++ -arch i386 -arch x86_64" linkflags="-stdlib=libc++" link=static threading=multi stage
    doneSection
}

#===============================================================================
unpackArchive()
{
    BUILDDIR=$1
    ARCH=$2
    NAME=$3

    echo "Unpacking $NAME from $BUILDDIR"

    mkdir -p $BUILDDIR/$ARCH/obj/$NAME
    #remove all trash in folder if exists
    rm $BUILDDIR/$ARCH/obj/$NAME/*.o
    rm $BUILDDIR/$ARCH/obj/$NAME/*.SYMDEF*

    (
        cd $BUILDDIR/$ARCH/obj/$NAME; ar -x ../../$NAME.a;
            for FILE in *.o; do
                NEW_FILE="${NAME}_${FILE}"
                mv $FILE $NEW_FILE
            done
    );
}

#===============================================================================

scrunchAllLibsTogetherInOneLibPerPlatform()
{
    cd $BOOST_SRC

    # mkdir -p $IOSBUILDDIR/armv6/obj
    mkdir -p $IOSBUILDDIR/armv7/obj
    mkdir -p $IOSBUILDDIR/armv7s/obj
    mkdir -p $IOSBUILDDIR/arm64/obj
    mkdir -p $IOSBUILDDIR/i386/obj

    mkdir -p $OSXBUILDDIR/i386/obj
    mkdir -p $OSXBUILDDIR/x86_64/obj

    ALL_LIBS=""

    echo Splitting all existing fat binaries...
    for NAME in $BOOST_LIBS; do
        LIB=libboost_$NAME
        ALL_LIBS="$ALL_LIBS $LIB"
        LIB_A=$LIB.a

        # $ARM_DEV_DIR/lipo "iphone-build/stage/lib/$LIB_A" -thin armv6 -o $IOSBUILDDIR/armv6/$LIB_A
        $ARM_DEV_DIR/lipo "iphone-build/stage/lib/$LIB_A" -thin armv7 -o $IOSBUILDDIR/armv7/$LIB_A
        $ARM_DEV_DIR/lipo "iphone-build/stage/lib/$LIB_A" -thin armv7s -o $IOSBUILDDIR/armv7s/$LIB_A
        $ARM_DEV_DIR/lipo "iphone-build/stage/lib/$LIB_A" -thin arm64 -o $IOSBUILDDIR/arm64/$LIB_A

        cp "iphonesim-build/stage/lib/$LIB_A" $IOSBUILDDIR/i386/

        $ARM_DEV_DIR/lipo "osx-build/stage/lib/$LIB_A" -thin i386 -o $OSXBUILDDIR/i386/$LIB_A
        $ARM_DEV_DIR/lipo "osx-build/stage/lib/$LIB_A" -thin x86_64 -o $OSXBUILDDIR/x86_64/$LIB_A
    done

    echo "Decomposing each architecture's .a files"
    for NAME in $ALL_LIBS; do
        echo "Decomposing ${NAME}.a..."
        unpackArchive $IOSBUILDDIR armv7 $NAME
        unpackArchive $IOSBUILDDIR armv7s $NAME
        unpackArchive $IOSBUILDDIR arm64 $NAME
        unpackArchive $IOSBUILDDIR i386 $NAME
        unpackArchive $OSXBUILDDIR i386 $NAME
        unpackArchive $OSXBUILDDIR x86_64 $NAME
    done

    echo "Linking each architecture into an uberlib ($ALL_LIBS => libboost.a )"
    ls $IOSBUILDDIR/*
    rm $IOSBUILDDIR/*/libboost.a
    ls $OSXBUILDDIR/*
    rm $OSXBUILDDIR/*/libboost.a
    for NAME in $ALL_LIBS; do
        # echo ...armv6
        # (cd $IOSBUILDDIR/armv6; $ARM_DEV_DIR/ar crus libboost.a obj/$NAME/*.o; )
        echo ...armv7
        (cd $IOSBUILDDIR/armv7; $ARM_DEV_DIR/ar crus libboost.a obj/$NAME/*.o; )
        echo ...armv7s
        (cd $IOSBUILDDIR/armv7s; $ARM_DEV_DIR/ar crus libboost.a obj/$NAME/*.o; )
        echo ...arm64
        (cd $IOSBUILDDIR/arm64; $ARM_DEV_DIR/ar crus libboost.a obj/$NAME/*.o; )
        echo ...i386
        (cd $IOSBUILDDIR/i386; ar crus libboost.a obj/$NAME/*.o; )

        echo ...osx-i386
        (cd $OSXBUILDDIR/i386; ar crus libboost.a obj/$NAME/*.o; )
        echo ...x86_64
        (cd $OSXBUILDDIR/x86_64; ar crus libboost.a obj/$NAME/*.o; )
done
}

#===============================================================================

# $1: Name of a boost library to lipoficate (technical term)
lipoficate()
{
    : ${1:?}
    NAME=$1
    echo lipoficate: $1

    mkdir -p $PREFIXDIR/lib
    $ARM_DEV_DIR/lipo -create $IOSBUILDDIR/*/libboost.a -o "$PREFIXDIR/lib/libboost_$NAME.a" || abort "Lipo $1 failed"
}

# This creates universal versions of each individual boost library
lipoAllBoostLibraries()
{
    for i in $BOOST_LIBS; do lipoficate $i; done;
    doneSection
}

#===============================================================================
buildFramework()
{
    : ${1:?}
    FRAMEWORKDIR=$1
    BUILDDIR=$2

    VERSION_TYPE=Alpha
    FRAMEWORK_NAME=boost
    FRAMEWORK_VERSION=A

    FRAMEWORK_CURRENT_VERSION=$BOOST_VERSION
    FRAMEWORK_COMPATIBILITY_VERSION=$BOOST_VERSION

    FRAMEWORK_BUNDLE=$FRAMEWORKDIR/$FRAMEWORK_NAME.framework
    echo "Framework: Building $FRAMEWORK_BUNDLE from $BUILDDIR..."

    rm -rf $FRAMEWORK_BUNDLE

    echo "Framework: Setting up directories..."
    mkdir -p $FRAMEWORK_BUNDLE
    mkdir -p $FRAMEWORK_BUNDLE/Versions
    mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION
    mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Resources
    mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Headers
    mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Documentation

    echo "Framework: Creating symlinks..."
    ln -s $FRAMEWORK_VERSION               $FRAMEWORK_BUNDLE/Versions/Current
    ln -s Versions/Current/Headers     $FRAMEWORK_BUNDLE/Headers
    ln -s Versions/Current/Resources       $FRAMEWORK_BUNDLE/Resources
    ln -s Versions/Current/Documentation   $FRAMEWORK_BUNDLE/Documentation
    ln -s Versions/Current/$FRAMEWORK_NAME $FRAMEWORK_BUNDLE/$FRAMEWORK_NAME

    FRAMEWORK_INSTALL_NAME=$FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/$FRAMEWORK_NAME

    echo "Lipoing library into $FRAMEWORK_INSTALL_NAME..."
    $ARM_DEV_DIR/lipo -create $BUILDDIR/*/libboost.a -o "$FRAMEWORK_INSTALL_NAME" || abort "Lipo $1 failed"

    echo "Framework: Copying includes..."
    cp -r $PREFIXDIR/include/boost/* $FRAMEWORK_BUNDLE/Headers/

    echo "Framework: Creating plist..."
    cat > $FRAMEWORK_BUNDLE/Resources/Info.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>English</string>
    <key>CFBundleExecutable</key>
    <string>${FRAMEWORK_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>org.boost</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleVersion</key>
    <string>${FRAMEWORK_CURRENT_VERSION}</string>
</dict>
</plist>
EOF
    doneSection
}

#===============================================================================
# Execution starts here
#===============================================================================

#BOOST_VERSION=`svn info $BOOST_SRC | grep URL | sed -e 's/^.*\/Boost_\([^\/]*\)/\1/'`
echo "BOOST_VERSION:     $BOOST_VERSION"
echo "BOOST_VERSION_SFX: $BOOST_VERSION_SFX"
echo "BOOST_LIBS:        $BOOST_LIBS"
echo "SRCDIR:            $SRCDIR"
echo "BOOST_SRC:         $BOOST_SRC"
echo "IOSBUILDDIR:       $IOSBUILDDIR"
echo "OSXBUILDDIR:       $OSXBUILDDIR"
echo "PREFIXDIR:         $PREFIXDIR"
echo "IOSFRAMEWORKDIR:   $IOSFRAMEWORKDIR"
echo "OSXFRAMEWORKDIR:   $OSXFRAMEWORKDIR"
echo "IPHONE_SDKVERSION: $IPHONE_SDKVERSION"
echo "XCODE_ROOT:        $XCODE_ROOT"
echo "COMPILER:          $COMPILER"
echo "CPP11_FLAGS:       $CPP11_FLAGS"
echo "CLEAN:             $CLEAN"
echo "BUILD_IOS:         $BUILD_IOS"
echo "BUILD_OSX:         $BUILD_OSX"
echo "CPP11_FLAGS:       $CPP11_FLAGS"
echo

[[ $DOWNLOAD -eq 1 ]] && downloadBoost
inventMissingHeaders
[[ $CLEAN -eq 1 ]] && cleanEverythingReadyToStart
unpackBoost
bootstrapBoost
writeBjamUserConfig
buildBoost
scrunchAllLibsTogetherInOneLibPerPlatform
# lipoAllBoostLibraries
[[ $BUILD_IOS -eq 1 ]] && buildFramework $IOSFRAMEWORKDIR $IOSBUILDDIR
[[ $BUILD_OSX -eq 1 ]] && buildFramework $OSXFRAMEWORKDIR $OSXBUILDDIR

# restoreBoost
echo "Completed successfully"

#===============================================================================
