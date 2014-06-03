# Makefile
# Make BOOST Framework for IOS and MACOSX
# (c) Richard Hodges 2014 hodges.r@gmail.com
# You may freely copy and distribute this source code provided you include the copyright message
# and acknowledge all previous works
# based on execllent work by Maksym Grebenets i4niac@i4napps.com https://github.com/mgrebenets/boost-xcode5-iosx
# based on excellent work by Pete Goodliffe https://gitorious.org/boostoniphone
# many thanks to these and others for doing the groundwork and inspiring me to waste 2 days of my life on this :-)

# ----------------------------------------------------
# INPUTS - Variables that we expect to come from Xcode
# ----------------------------------------------------
# @param PROJECT_DIR is where the project file is located
# @param PROJECT_TEMP_DIR is a temporary directory which can be used for building
# @param BUILD_ROOT where each framework should be created
# @param PROJECT_DERIVED_FILE_DIR is where the boost sources will be unpacked. Created sourcefiles

PROJECT_DIR ?= $(shell pwd)
PROJECT_TEMP_DIR ?= $(HOME)/tmp/boost-iosx-build
BUILD_ROOT ?= $(HOME)/tmp/boost-iosx-product
PROJECT_DERIVED_FILE_DIR ?= $(PROJECT_TEMP_DIR)/derived
PROJECT_PROGRESS_DIR = $(PROJECT_TEMP_DIR)/progress

# ---------------------------------------------------------------
# INPUTS - Variables that we expect to be set on the command line
# ---------------------------------------------------------------
BOOST_VERSION ?= 1.54.0
#BOOST_LIBS ?= atomic chrono date_time exception filesystem graph graph_parallel iostreams locale mpi program_options python random regex serialization signals system test thread timer wave
BOOST_LIBS ?= date_time exception serialization system

#important paths
SIMULATOR_SDK_PATH = $(shell xcrun --sdk iphonesimulator --show-sdk-path)

COMPILER=clang++
IPHONE_SDKVERSION = $(shell xcodebuild -showsdks | grep iphoneos | egrep "[[:digit:]]+\.[[:digit:]]+" -o | tail -1)
OSX_SDKVERSION = $(shell xcodebuild -showsdks | grep macosx | egrep "[[:digit:]]+\.[[:digit:]]+" -o | tail -1)
#OSX_SDKVERSION = 10.8
XCODE_ROOT = $(shell xcode-select -print-path)
CXX_FLAGS = -std=c++11 -stdlib=libc++
CXX_LINK_FLAGS = -stdlib=libc++
EXTRA_CPPFLAGS = -DBOOST_AC_USE_PTHREADS -DBOOST_SP_USE_PTHREADS $(CXX_FLAGS)

# --------
# conversion functions
# --------

noop=
space = $(noop) $(noop)
comma = $(noop),$(noop)

BOOST_VERSION ?= 1.54.0
BOOST_ARCHIVE_DIR = $(PROJECT_DIR)/archives
BOOST_SRC_BASE = boost_$(subst .,_,$(BOOST_VERSION))
BOOST_ARCHIVE_FILE = $(BOOST_SRC_BASE).tar.bz2
BOOST_SRC = $(PROJECT_TEMP_DIR)/$(BOOST_SRC_BASE)

.PHONY: all
all : ios-framework macosx-framework

# --------------
# unpack tarball
# --------------
UNPACK_FLAG = $(PROJECT_PROGRESS_DIR)/unpacked-$(BOOST_VERSION)

$(UNPACK_FLAG) : $(BOOST_ARCHIVE_DIR)/$(BOOST_ARCHIVE_FILE)
	mkdir -p $(PROJECT_PROGRESS_DIR)
	mkdir -p $(PROJECT_TEMP_DIR)
	tar -C $(PROJECT_TEMP_DIR) -xjf $(BOOST_ARCHIVE_DIR)/$(BOOST_ARCHIVE_FILE)
	echo `date -ju` > $(UNPACK_FLAG)

.PHONY : unpack rm_sources
unpack : $(UNPACK_FLAG)

rm_sources :
	rm -rf $(BOOST_SRC)
	rm -f $(UNPACK_FLAG)

# --------
# invent missing headers
# --------

$(BOOST_SRC)/crt_externs.h : $(UNPACK_FLAG) $(SIMULATOR_SDK_PATH)/usr/include/crt_externs.h
	cp `xcrun --sdk iphonesimulator --show-sdk-path`/usr/include/crt_externs.h $(BOOST_SRC)

$(BOOST_SRC)/bzlib.h : $(UNPACK_FLAG) $(SIMULATOR_SDK_PATH)/usr/include/bzlib.h
	cp `xcrun --sdk iphonesimulator --show-sdk-path`/usr/include/bzlib.h $(BOOST_SRC)

INVENTED_HEADERS = $(BOOST_SRC)/bzlib.h $(BOOST_SRC)/crt_externs.h

.PHONY : invent_headers remove_invented_headers
invent_headers : $(INVENTED_HEADERS)

remove_invented_headers :
	rm -f $(INVENTED_HEADERS)

# --------
# bootstrap
# --------

BOOTSTRAP_FLAG = $(PROJECT_PROGRESS_DIR)/bootstrapped-$(BOOST_VERSION)
MACOSX_PREFIX_DIR = $(PROJECT_TEMP_DIR)/$(BOOST_VERSION)/macosx-prefix

$(BOOTSTRAP_FLAG) : $(INVENTED_HEADERS)
	cd $(BOOST_SRC) && ./bootstrap.sh --with-libraries=$(subst $(space),$(comma),$(BOOST_LIBS)) --prefix=$(MACOSX_PREFIX_DIR)
	echo `date -ju` > $(BOOTSTRAP_FLAG)
    
.PHONY : bootstrap
bootstrap : $(BOOTSTRAP_FLAG)

# modify user config in tools/build/v2/user_config.jam

BOOST_USER_CONFIG = $(BOOST_SRC)/tools/build/v2/user-config.jam

IPHONE_OS_PLATFORM_PATH = $(shell xcrun --sdk iphoneos --show-sdk-platform-path)
ARM_DEV_DIR = $(IPHONE_OS_PLATFORM_PATH)/Developer/usr/bin

IPHONE_SIMULATOR_PLATFORM_PATH = $(shell xcrun --sdk iphonesimulator --show-sdk-platform-path)
SIM_DEV_DIR = $(IPHONE_SIMULATOR_PLATFORM_PATH)/Developer/usr/bin

$(BOOST_USER_CONFIG) : $(BOOTSTRAP_FLAG)
	echo Updating boost into $(BOOST_SRC)...
	cp $@ $@-bk
	sed -i.bak '/# BOOST/,$$d' $@
	echo "# BOOST" >>$@
	echo "using darwin : $(IPHONE_SDKVERSION)~iphone" >>$@
	echo "   : $(XCODE_ROOT)/Toolchains/XcodeDefault.xctoolchain/usr/bin/$(COMPILER) -arch armv7 -arch armv7s -arch arm64 -fvisibility=hidden -fvisibility-inlines-hidden $(EXTRA_CPPFLAGS)" >> $@
	echo "   : <striper> <root>$(IPHONE_OS_PLATFORM_PATH)/Developer" >> $@
	echo "   : <architecture>arm <target-os>iphone" >> $@
	echo "   ;" >> $@
	echo "using darwin : $(IPHONE_SDKVERSION)~iphonesim" >> $@
	echo "   : $(XCODE_ROOT)/Toolchains/XcodeDefault.xctoolchain/usr/bin/$(COMPILER) -arch i386 -arch x86_64 -fvisibility=hidden -fvisibility-inlines-hidden $(EXTRA_CPPFLAGS)" >> $@
	echo "   : <striper> <root>$(IPHONE_SIMULATOR_PLATFORM_PATH)/Developer" >> $@
	echo "   : <architecture>x86 <target-os>iphone" >> $@
	echo "   ;" >> $@

.PHONY : user-config
user-config : $(BOOST_USER_CONFIG)

# --------------------
# build iphone version
# --------------------

BUILD_IOS_FLAG = $(PROJECT_PROGRESS_DIR)/built-ios-$(BOOST_VERSION)
IPHONE_BUILD_DIR = $(PROJECT_TEMP_DIR)/$(BOOST_VERSION)/iphone-build
IPHONE_STAGE_DIR = $(PROJECT_TEMP_DIR)/$(BOOST_VERSION)/iphone-stage
IPHONE_PREFIXDIR = $(PROJECT_TEMP_DIR)/$(BOOST_VERSION)/iphone-prefix
IPHONESIM_BUILD_DIR = $(PROJECT_TEMP_DIR)/$(BOOST_VERSION)/iphonesim-build
IPHONESIM_STAGE_DIR = $(PROJECT_TEMP_DIR)/iphonesim-stage

CORES = $(shell sysctl hw.ncpu | awk '{print $$2}')

$(BUILD_IOS_FLAG) : $(BOOST_USER_CONFIG)
	cd $(BOOST_SRC) && ./bjam -j$(CORES) --build-dir=$(IPHONE_BUILD_DIR) --stagedir=$(IPHONE_STAGE_DIR) --prefix=$(IPHONE_PREFIXDIR) toolset=darwin architecture=arm target-os=iphone macosx-version=iphone-$(IPHONE_SDKVERSION) define=_LITTLE_ENDIAN link=static stage
	cd $(BOOST_SRC) && ./bjam -j$(CORES) --build-dir=$(IPHONE_BUILD_DIR) --stagedir=$(IPHONE_STAGE_DIR) --prefix=$(IPHONE_PREFIXDIR) toolset=darwin architecture=arm target-os=iphone macosx-version=iphone-$(IPHONE_SDKVERSION) define=_LITTLE_ENDIAN link=static install
	cd $(BOOST_SRC) && ./bjam -j$(CORES) --build-dir=$(IPHONESIM_BUILD_DIR) --stagedir=$(IPHONESIM_STAGE_DIR) --toolset=darwin-$(IPHONE_SDKVERSION)~iphonesim architecture=x86 target-os=iphone macosx-version=iphonesim-$(IPHONE_SDKVERSION) link=static stage
	echo `date -ju` > $(BUILD_IOS_FLAG)

.PHONY : iphone-build iphone-clean
iphone-build : $(BUILD_IOS_FLAG)

iphone-clean :
	cd $(BOOST_SRC) && ./bjam --build-dir=$(IPHONE_BUILD_DIR) --stagedir=$(IPHONE_STAGE_DIR) --prefix=$(IPHONE_PREFIXDIR) toolset=darwin architecture=arm target-os=iphone macosx-version=iphone-$(IPHONE_SDKVERSION) define=_LITTLE_ENDIAN link=static clean
	cd $(BOOST_SRC) && ./bjam --build-dir=$(IPHONESIM_BUILD_DIR) --stagedir=$(IPHONESIM_STAGE_DIR) --toolset=darwin-$(IPHONE_SDKVERSION)~iphonesim architecture=x86 target-os=iphone macosx-version=iphonesim-$(IPHONE_SDKVERSION) link=static clean
	rm -f $(BUILD_IOS_FLAG)

# ---------------
# ios unified lib
# ---------------

ARM_ARCHITECTURES = armv7 armv7s arm64
SIM_ARCHITECTURES = i386 x86_64
IOS_ARCHITECTURES = $(ARM_ARCHITECTURES) $(SIM_ARCHITECTURES)
IOS_UNIFIED_LIB = $(PROJECT_TEMP_DIR)/$(BOOST_VERSION)/iphone-unified
IOS_LIBBOOST_DIR = $(PROJECT_TEMP_DIR)/$(BOOST_VERSION)/osx
IOS_LIBBOOST_NAME = boost
IOS_LIBBOOST = $(IOS_LIBBOOST_DIR)/lib$(IOS_LIBBOOST_NAME).a


# param 1 is the build dir
# param 2 is the architecture
# param 3 is the library base name
# param 4 is the unified library

unpackArchive = echo "Unpacking $(3) from $(1)" ; \
mkdir -p $(1)/$(2)/obj/$(3) ; \
rm -f $(1)/$(2)/obj/$(3)/*.o ; \
rm -f $(1)/$(2)/obj/$(3)/*.SYMDEF* ; \
( \
  cd $(1)/$(2)/obj/$(3); ar -x $(4) ; \
  for FILE in *.o; do \
    mv $$FILE $(3)_$$FILE ; \
  done \
);

$(IOS_LIBBOOST) : $(BUILD_IOS_FLAG)
# make the unified lib folder
	$(foreach arch,$(IOS_ARCHITECTURES),mkdir -p $(IOS_UNIFIED_LIB)/$(arch)/obj ;)
# extract each architecture's individual lib
	$(foreach lib,$(BOOST_LIBS), $(foreach arch,$(ARM_ARCHITECTURES),$(ARM_DEV_DIR)/lipo "$(IPHONE_STAGE_DIR)/lib/libboost_$(lib).a" -thin $(arch) -o $(IOS_UNIFIED_LIB)/$(arch)/libboost_$(lib).a ; ))
	$(foreach lib,$(BOOST_LIBS), $(foreach arch,$(SIM_ARCHITECTURES),$(ARM_DEV_DIR)/lipo "$(IPHONESIM_STAGE_DIR)/lib/libboost_$(lib).a" -thin $(arch) -o $(IOS_UNIFIED_LIB)/$(arch)/libboost_$(lib).a ; ))
# extract object files from each architecture's lib, renamed with the libname as a prefix to avoid clashes later on
	$(foreach lib,$(BOOST_LIBS), $(foreach arch,$(ARM_ARCHITECTURES),$(call unpackArchive,$(IPHONE_BUILD_DIR),$(arch),$(lib),$(IOS_UNIFIED_LIB)/$(arch)/libboost_$(lib).a) ))
	$(foreach lib,$(BOOST_LIBS), $(foreach arch,$(SIM_ARCHITECTURES),$(call unpackArchive,$(IPHONESIM_BUILD_DIR),$(arch),$(lib),$(IOS_UNIFIED_LIB)/$(arch)/libboost_$(lib).a) ))
# build one library containing all files
	rm -f $(IPHONE_BUILD_DIR)/*/libboost.a
	-$(foreach lib,$(BOOST_LIBS), $(foreach arch,$(ARM_ARCHITECTURES),(cd $(IPHONE_BUILD_DIR)/$(arch); $(ARM_DEV_DIR)/ar crus libboost.a obj/$(lib)/*.o);))
	rm -f $(IPHONESIM_BUILD_DIR)/*/libboost.a
	$(foreach lib,$(BOOST_LIBS), $(foreach arch,$(SIM_ARCHITECTURES),(cd $(IPHONESIM_BUILD_DIR)/$(arch); ar crus libboost.a obj/$(lib)/*.o);))
# use lipo to build one ios library
	mkdir -p $(IOS_LIBBOOST_DIR)
	$(ARM_DEV_DIR)/lipo -create $(foreach arch,$(ARM_ARCHITECTURES),$(IPHONE_BUILD_DIR)/$(arch)/libboost.a) $(foreach arch,$(SIM_ARCHITECTURES),$(IPHONESIM_BUILD_DIR)/$(arch)/libboost.a) -o $(IOS_LIBBOOST)

.PHONY : ios-unified-lib
ios-unified-lib : $(IOS_LIBBOOST)

# -------------
# IOS Framework
# -------------

VERSION_TYPE = Alpha
FRAMEWORK_VERSION = A
FRAMEWORK_CURRENT_VERSION = $(BOOST_VERSION)
FRAMEWORK_COMPATIBILITY_VERSION = $(BOOST_VERSION)

IOS_FRAMEWORK_NAME = boost
IOS_BUNDLE_DIR = $(BUILD_ROOT)/ios/boost-$(BOOST_VERSION)/$(IOS_FRAMEWORK_NAME).framework

FRAMEWORK_IOS_FLAG = $(PROJECT_PROGRESS_DIR)/framework-ios-$(BOOST_VERSION)

$(FRAMEWORK_IOS_FLAG) : $(IOS_LIBBOOST)
	echo "Framework: Building $(IOS_BUNDLE_DIR) from $(IOS_LIBBOOST)"
	rm -rf $(IOS_BUNDLE_DIR)
	mkdir -p $(IOS_BUNDLE_DIR)/Versions
	mkdir -p $(IOS_BUNDLE_DIR)/Versions/$(FRAMEWORK_VERSION)/Resources
	mkdir -p $(IOS_BUNDLE_DIR)/Versions/$(FRAMEWORK_VERSION)/Headers
	mkdir -p $(IOS_BUNDLE_DIR)/Versions/$(FRAMEWORK_VERSION)/Documentation
	ln -s $(FRAMEWORK_VERSION)               $(IOS_BUNDLE_DIR)/Versions/Current
	ln -s Versions/Current/Headers     		$(IOS_BUNDLE_DIR)/Headers
	ln -s Versions/Current/Resources       $(IOS_BUNDLE_DIR)/Resources
	ln -s Versions/Current/Documentation   $(IOS_BUNDLE_DIR)/Documentation
	ln -s Versions/Current/$(IOS_FRAMEWORK_NAME) $(IOS_BUNDLE_DIR)/$(IOS_FRAMEWORK_NAME)
	cp $(IOS_LIBBOOST) $(IOS_BUNDLE_DIR)/Versions/$(FRAMEWORK_VERSION)/$(IOS_FRAMEWORK_NAME)
	cp -R $(IPHONE_PREFIXDIR)/include/boost/ $(IOS_BUNDLE_DIR)/Headers/
	echo '<?xml version="1.0" encoding="UTF-8"?>' > $(IOS_BUNDLE_DIR)/Resources/Info.plist
	echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> $(IOS_BUNDLE_DIR)/Resources/Info.plist
	echo '<plist version="1.0">' >> $(IOS_BUNDLE_DIR)/Resources/Info.plist
	echo '<dict>' >> $(IOS_BUNDLE_DIR)/Resources/Info.plist
	echo '    <key>CFBundleDevelopmentRegion</key>' >> $(IOS_BUNDLE_DIR)/Resources/Info.plist
	echo '    <string>English</string>' >> $(IOS_BUNDLE_DIR)/Resources/Info.plist
	echo '    <key>CFBundleExecutable</key>' >> $(IOS_BUNDLE_DIR)/Resources/Info.plist
	echo '    <string>$(IOS_FRAMEWORK_NAME)</string>' >> $(IOS_BUNDLE_DIR)/Resources/Info.plist
	echo '    <key>CFBundleIdentifier</key>' >> $(IOS_BUNDLE_DIR)/Resources/Info.plist
	echo '    <string>org.boost</string>' >> $(IOS_BUNDLE_DIR)/Resources/Info.plist
	echo '    <key>CFBundleInfoDictionaryVersion</key>' >> $(IOS_BUNDLE_DIR)/Resources/Info.plist
	echo '    <string>6.0</string>' >> $(IOS_BUNDLE_DIR)/Resources/Info.plist
	echo '    <key>CFBundlePackageType</key>' >> $(IOS_BUNDLE_DIR)/Resources/Info.plist
	echo '    <string>FMWK</string>' >> $(IOS_BUNDLE_DIR)/Resources/Info.plist
	echo '    <key>CFBundleSignature</key>' >> $(IOS_BUNDLE_DIR)/Resources/Info.plist
	echo '    <string>????</string>' >> $(IOS_BUNDLE_DIR)/Resources/Info.plist
	echo '    <key>CFBundleVersion</key>' >> $(IOS_BUNDLE_DIR)/Resources/Info.plist
	echo '    <string>$(FRAMEWORK_CURRENT_VERSION)</string>' >> $(IOS_BUNDLE_DIR)/Resources/Info.plist
	echo '</dict>' >> $(IOS_BUNDLE_DIR)/Resources/Info.plist
	echo '</plist>' >> $(IOS_BUNDLE_DIR)/Resources/Info.plist
	echo `date -ju` > $(FRAMEWORK_IOS_FLAG)
	echo $(IOS_BUNDLE_DIR) >> $(FRAMEWORK_IOS_FLAG)

.PHONY : ios-framework
ios-framework : $(FRAMEWORK_IOS_FLAG)


# ---------
# osx build
# ---------

BUILD_MACOSX_FLAG = $(PROJECT_PROGRESS_DIR)/built-macosx-$(BOOST_VERSION)
MACOSX_BUILD_DIR = $(PROJECT_TEMP_DIR)/$(BOOST_VERSION)/macosx-build
MACOSX_STAGE_DIR = $(PROJECT_TEMP_DIR)/$(BOOST_VERSION)/macosx-stage

$(BUILD_MACOSX_FLAG) : $(BOOST_USER_CONFIG)
	cd $(BOOST_SRC) && ./b2 -j$(CORES) --build-dir=$(MACOSX_BUILD_DIR) --stagedir=$(MACOSX_STAGE_DIR) --prefixdir=$(MACOSX_PREFIX_DIR) toolset=clang cxxflags="-arch i386 -arch x86_64 $(CXX_FLAGS)" linkflags="$(CXX_LINK_FLAGS)" link=static threading=multi stage install
	echo `date -ju` > $(BUILD_MACOSX_FLAG)

.PHONY: macosx-build macosx-clean
macosx-build : $(BUILD_MACOSX_FLAG)

macosx-clean :
	cd $(BOOST_SRC) && ./b2 -j$(CORES) --build-dir=$(MACOSX_BUILD_DIR) --stagedir=$(MACOSX_STAGE_DIR) --prefixdir=$(MACOSX_PREFIX_DIR) toolset=clang cxxflags="-arch i386 -arch x86_64 $(CXX_FLAGS)" linkflags="$(CXX_LINK_FLAGS)" link=static threading=multi clean
	rm -f $(BUILD_OSX_FLAG)
    


# ------------------
# macosx unified lib
# ------------------

MACOSX_ARCHITECTURES = i386 x86_64
MACOSX_UNIFIED_LIB = $(PROJECT_TEMP_DIR)/$(BOOST_VERSION)/macosx-unified
MACOSX_LIBBOOST_DIR = $(PROJECT_TEMP_DIR)/$(BOOST_VERSION)/macosx
MACOSX_LIBBOOST_NAME = boost
MACOSX_LIBBOOST = $(MACOSX_LIBBOOST_DIR)/lib$(IOS_LIBBOOST_NAME).a

$(MACOSX_LIBBOOST) : $(BUILD_MACOSX_FLAG)
# make the unified lib folder
	$(foreach arch,$(MACOSX_ARCHITECTURES),mkdir -p $(MACOSX_UNIFIED_LIB)/$(arch)/obj ;)
# extract each architecture's individual lib
	$(foreach lib,$(BOOST_LIBS), $(foreach arch,$(MACOSX_ARCHITECTURES),$(ARM_DEV_DIR)/lipo "$(MACOSX_STAGE_DIR)/lib/libboost_$(lib).a" -thin $(arch) -o $(MACOSX_UNIFIED_LIB)/$(arch)/libboost_$(lib).a ; ))
# extract object files from each architecture's lib, renamed with the libname as a prefix to avoid clashes later on
	$(foreach lib,$(BOOST_LIBS), $(foreach arch,$(MACOSX_ARCHITECTURES),$(call unpackArchive,$(MACOSX_BUILD_DIR),$(arch),$(lib),$(MACOSX_UNIFIED_LIB)/$(arch)/libboost_$(lib).a) ))
# build one library containing all files
	-rm -f $(MACOSX_BUILD_DIR)/*/libboost.a
	-$(foreach lib,$(BOOST_LIBS), $(foreach arch,$(MACOSX_ARCHITECTURES),(cd $(MACOSX_BUILD_DIR)/$(arch); $(ARM_DEV_DIR)/ar crus libboost.a obj/$(lib)/*.o);))
# use lipo to build one macosx library
	mkdir -p $(MACOSX_LIBBOOST_DIR)
	$(ARM_DEV_DIR)/lipo -create $(foreach arch,$(MACOSX_ARCHITECTURES),$(MACOSX_BUILD_DIR)/$(arch)/libboost.a) -o $(MACOSX_LIBBOOST)

.PHONY : macosx-unified-lib
macosx-unified-lib : $(MACOSX_LIBBOOST)


# ----------------
# MACOSX Framework
# ----------------

MACOSX_FRAMEWORK_NAME = boost
MACOSX_BUNDLE_DIR = $(BUILD_ROOT)/macosx/boost-$(BOOST_VERSION)/$(MACOSX_FRAMEWORK_NAME).framework

FRAMEWORK_MACOSX_FLAG = $(PROJECT_PROGRESS_DIR)/framework-macosx-$(BOOST_VERSION)

$(FRAMEWORK_MACOSX_FLAG) : $(MACOSX_LIBBOOST)
	echo "Framework: Building $(MACOSX_BUNDLE_DIR) from $(MACOSX_LIBBOOST)"
	rm -rf $(MACOSX_BUNDLE_DIR)
	mkdir -p $(MACOSX_BUNDLE_DIR)/Versions
	mkdir -p $(MACOSX_BUNDLE_DIR)/Versions/$(FRAMEWORK_VERSION)/Resources
	mkdir -p $(MACOSX_BUNDLE_DIR)/Versions/$(FRAMEWORK_VERSION)/Headers
	mkdir -p $(MACOSX_BUNDLE_DIR)/Versions/$(FRAMEWORK_VERSION)/Documentation
	ln -s $(FRAMEWORK_VERSION)               $(MACOSX_BUNDLE_DIR)/Versions/Current
	ln -s Versions/Current/Headers     		$(MACOSX_BUNDLE_DIR)/Headers
	ln -s Versions/Current/Resources       $(MACOSX_BUNDLE_DIR)/Resources
	ln -s Versions/Current/Documentation   $(MACOSX_BUNDLE_DIR)/Documentation
	ln -s Versions/Current/$(MACOSX_FRAMEWORK_NAME) $(MACOSX_BUNDLE_DIR)/$(MACOSX_FRAMEWORK_NAME)
	cp $(MACOSX_LIBBOOST) $(MACOSX_BUNDLE_DIR)/Versions/$(FRAMEWORK_VERSION)/$(MACOSX_FRAMEWORK_NAME)
	cp -R $(MACOSX_PREFIX_DIR)/include/boost/ $(MACOSX_BUNDLE_DIR)/Headers/
	echo '<?xml version="1.0" encoding="UTF-8"?>' > $(MACOSX_BUNDLE_DIR)/Resources/Info.plist
	echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> $(MACOSX_BUNDLE_DIR)/Resources/Info.plist
	echo '<plist version="1.0">' >> $(MACOSX_BUNDLE_DIR)/Resources/Info.plist
	echo '<dict>' >> $(MACOSX_BUNDLE_DIR)/Resources/Info.plist
	echo '    <key>CFBundleDevelopmentRegion</key>' >> $(MACOSX_BUNDLE_DIR)/Resources/Info.plist
	echo '    <string>English</string>' >> $(MACOSX_BUNDLE_DIR)/Resources/Info.plist
	echo '    <key>CFBundleExecutable</key>' >> $(MACOSX_BUNDLE_DIR)/Resources/Info.plist
	echo '    <string>$(MACOSX_FRAMEWORK_NAME)</string>' >> $(MACOSX_BUNDLE_DIR)/Resources/Info.plist
	echo '    <key>CFBundleIdentifier</key>' >> $(MACOSX_BUNDLE_DIR)/Resources/Info.plist
	echo '    <string>org.boost</string>' >> $(MACOSX_BUNDLE_DIR)/Resources/Info.plist
	echo '    <key>CFBundleInfoDictionaryVersion</key>' >> $(MACOSX_BUNDLE_DIR)/Resources/Info.plist
	echo '    <string>6.0</string>' >> $(MACOSX_BUNDLE_DIR)/Resources/Info.plist
	echo '    <key>CFBundlePackageType</key>' >> $(MACOSX_BUNDLE_DIR)/Resources/Info.plist
	echo '    <string>FMWK</string>' >> $(MACOSX_BUNDLE_DIR)/Resources/Info.plist
	echo '    <key>CFBundleSignature</key>' >> $(MACOSX_BUNDLE_DIR)/Resources/Info.plist
	echo '    <string>????</string>' >> $(MACOSX_BUNDLE_DIR)/Resources/Info.plist
	echo '    <key>CFBundleVersion</key>' >> $(MACOSX_BUNDLE_DIR)/Resources/Info.plist
	echo '    <string>$(FRAMEWORK_CURRENT_VERSION)</string>' >> $(MACOSX_BUNDLE_DIR)/Resources/Info.plist
	echo '</dict>' >> $(MACOSX_BUNDLE_DIR)/Resources/Info.plist
	echo '</plist>' >> $(MACOSX_BUNDLE_DIR)/Resources/Info.plist
	echo `date -ju` > $(FRAMEWORK_MACOSX_FLAG)
	echo $(MACOSX_BUNDLE_DIR) >> $(FRAMEWORK_MACOSX_FLAG)


.PHONY : macosx-framework
macosx-framework : $(FRAMEWORK_MACOSX_FLAG)

.PHONY: clean
clean:
	-rm -rf $(PROJECT_TEMP_DIR)
	-rm -rf $(IOS_BUNDLE_DIR)
	-rm -rf $(MACOSX_BUNDLE_DIR)

