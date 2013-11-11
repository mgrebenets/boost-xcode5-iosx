Build Boost Framework for iOS and OSX
=====
###### Using Xcode5 (armv7, armv7s, arm64, i386, x86_64)

### Boost Source
Script does not yet support downloading the source code, so you have to get it manually.

* [boost downloads](http://www.boost.org/users/download/)
* [1.53.0](https://sourceforge.net/projects/boost/files/boost/1.53.0/)
* [1.54.0](https://sourceforge.net/projects/boost/files/boost/1.54.0/)

The script is expecting `bz2` tarball.
Put the tarball in the same folder with `boost.sh`.

Make sure you keep the tarball name unchanged, so it is like `boost_1_53_0.tar.bz2`.

### Build
Use `boost.sh` to build boost framework.
Run `boost.sh -h` to get help message.

Modify `BOOST_LIBS` with list of libraries that you need.

Examples:

    # clean build version 1.53.0 for ios and osx with c++11
    ./boost.sh clean --with-c++11 -v 1.53.0

    # build version 1.54.0 for ios and osx without c++11, no clean
    ./boost.sh --version 1.54.0

## Notes and Changes
### Link Errors in Xcode 5
If you use libraries like `serialization` you might see link errors in Xcode 5 especially when the framework was built using `--with-c++11` flag.

You have to change your project or target build settings.

Under *Apple LLVM 5.0 - Language - C++* make the following changes

* *C++ Language Dialect* set to *C++11 [-std=c++11]*
* *C++ Standard Library* set to *libc++ (LLVM C++ standard library with C++11 support)*

### `ar` for Simulator Dev Tools
In Xcode 5 there's no `ar` excutable in `SIM_DEV_DIR` so using `/usr/bin/ar` instead.

## Why not Using Cocoapods?
I tried to use [cocoapods spec for boost](https://github.com/CocoaPods/Specs/tree/master/boost).
However, there's a number of things that made me to switch to using framework instead.
* It doesn't include all the subspecs you might need for development
* It takes really long time to update every time you run `pod update` or `pod install` (given that you have modified `Podfile`)
  * The tar-ball is downloaded (50+ mb)
  * The tag-ball is unpacked
* There's podspec for 1.51.0 only
* You can't use the Pod if you need libraries like `serialization`
  * `serialization` has to be linked as a library, it doesn't work like the rest of the boost libraries by just including hpp headers inline. It needs to be compiled for your target platform.

## References and Attribution
This repo is practially a fork of https://github.com/wuhao5/boost.
Only this one does not contain boost source code, thus is more lightweight.

The script mentioned above in it's turn is based on great work by Pete Goodliffe

* https://gitorious.org/boostoniphone
* http://goodliffe.blogspot.com.au/2010/09/building-boost-framework-for-ios-iphone.html
* http://goodliffe.blogspot.com.au/2009/12/boost-on-iphone.html

And lots of contributions by other people.
