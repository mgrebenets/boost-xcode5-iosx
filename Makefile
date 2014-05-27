# Makefile
# make boost framework, utilizing boost.sh

# ---
# Commands
ECHO = echo
RMRF = rm -rf

# ---
# Xcode
XCODE_DEVELOPER = $(shell xcode-select --print-path)
XCODE_BIN = ${XCODE_DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/bin

#---
# Platforms and SDKs
IOS_PLATFORM_PATH = $(shell xcrun --sdk iphoneos --show-sdk-platform-path)
IOS_SDK_PATH = $(shell xcrun --sdk iphoneos --show-sdk-path)

IOS_SIM_PLATFORM_PATH = $(shell xcrun --sdk iphonesimulator --show-sdk-platform-path)
IOS_SIM_SDK_PATH = $(shell xcrun --sdk iphonesimulator --show-sdk-path)

IOS_SDK_VERSION = $(shell xcodebuild -showsdks | grep iphoneos | egrep "[[:digit:]]+\.[[:digit:]]+" -o | tail -1))
OSX_SDK_VERSIOn = $(shell xcodebuild -showsdks | grep macosx | egrep "[[:digit:]]+\.[[:digit:]]+" -o | tail -1))

# ---
# Libraries to Build
# Override when calling make to build different set of libraries
BOOST_LIBS = "serialization thread system"




# ---
# Clean
clan:
	@$(ECHO) "Cleaning up..."
	# TODO: add rm -rf for each important piece
# ---
# Help
help:
	@$(ECHO) "--> This is just a stub, not yet implemented. <--"
	@$(ECHO) "Targets:"
	@$(ECHO) "TODO:\t\t\t- <TODO>"
	@$(ECHO) "help\t\t\t- display this message"