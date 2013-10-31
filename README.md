Boost iOS/OSX compilation
=====

### C/CXX flags:
* -DBOOST_AC_USE_PTHREADS -DBOOST_SP_USE_PTHREADS -std=c++11
* -fvisibility=hidden -fvisibility-inlines-hidden
* -stdlib=libc++ -- GNU STL C++ lib

### Framework
* iOS universal build including: armv6/armv7/armv7s/i386 - needs latest XCode (4.6+)
* OSX universal build including: i386/x86_64

### Install
Run boost.sh on the project folder, it'll look for the Xcode by 'xcode-select' and pick up the latest iOS SDK by 'xcodebuild -showsdks'
Currently, only a subset of libraries will be compilied (BOOST_LIBS)

Two frameworks will be generated under the ios/framework and osx/framework. When using it, link against the framework.

A few set of settings are in the front.
