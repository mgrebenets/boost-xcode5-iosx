Build Boost Framework for iOS & OSX
=====
###### Using Xcode5 (armv7, armv7s, arm64, i386, x86_64)

### Boost Source
Makefile on this branch does not download the tarball yet, so you will have to do it manually.

* [boost downloads](http://www.boost.org/users/download/)
* [1.53.0](https://sourceforge.net/projects/boost/files/boost/1.53.0/)
* [1.54.0](https://sourceforge.net/projects/boost/files/boost/1.54.0/)
* [1.55.0](https://sourceforge.net/projects/boost/files/boost/1.55.0/) - untested!

The script is expecting `bz2` tarball. Put the tarball in `archives` folder.

Make sure you keep the tarball name unchanged, so it is like `boost_1_53_0.tar.bz2`.

### Make

Build is done with `make` command.
Override `BOOST_VERSION` and `BOOST_LIBS` command to get customized builds.

    # build 1.54.0
    make -r BOOST_VERSION=1.54.0

    #build 1.55.0 with system and thread libraries only
    make -r BOOST_VERSION=1.55.0 BOOST_LIBS="system thread"

By default the script will build `date_time`, `exception`, `serialization` and `system`.

### Framework

The built framework will be located in a temp folder. It could be `tmp` in your home folder. Have a look at the log message to find out the exact location.

_There's a room for improvement here._

## Troubleshooting

### 3rd Party Dependencies
The Makefile cannot handle external dependencies yet.
For example, to build `locale` library, you will require to link against `icu` or `iconv` library.

Unfortunately you won't be able to do that yet. Neither with `Makefile` nor with `boost.sh` script.

If you have `cmake` skills and have the solution, please contribute.

### Undefined symbols link error
If you use libraries like `serialization` you might see link errors in Xcode 5 especially when the framework was built using `--with-c++11` flag.

    Undefined symbols for architecture i386:
    "std::__1::__vector_base_common<true>::__throw_length_error() const", referenced from:
    void std::__1::vector<boost::archive::detail::basic_iarchive_impl::cobject_id, std::__1::allocator<boost::archive::detail::basic_iarchive_impl::cobject_id> >::__push_back_slow_path<boost::archive::detail::basic_iarchive_impl::cobject_id>(boost::archive::detail::basic_iarchive_impl::cobject_id&&) in boost(libboost_serialization_basic_iarchive.o)

You have to change your project or target build settings.

Under *Apple LLVM 5.0 - Language - C++* make the following changes

* *C++ Language Dialect* set to *C++11 [-std=c++11]*
* *C++ Standard Library* set to *libc++ (LLVM C++ standard library with C++11 support)*

### Parse errors when including `boost/type_traits.hpp`
If you happen to include `<boost/type_traits.hpp>` header file, you may see compile errors like this

    Unexpected member name of ';' after declaration specifiers

To fix this problem, include the following line in your porject `***-Prefix.pch` file.

    #define __ASSERT_MACROS_DEFINE_VERSIONS_WITHOUT_UNDERSCORES 0

## Header-Only Libraries
Most of the boost libraries are header-only, meaning you only need to include header files to make them work.
However, there is a [list of libraries](http://www.boost.org/doc/libs/1_55_0/more/getting_started/unix-variants.html#header-only-libraries) that need to be built for your target platform.
Set `BOOST_LIBS` properly to get your customized build.

## Demo
Check out [this demo project](https://github.com/mgrebenets/boost-xcode5-demo) for some examples.

## Why not Using Cocoapods?
I tried to use [cocoapods spec for boost](https://github.com/CocoaPods/Specs/tree/master/boost).
However, there's a number of things that made me to switch to using framework instead.
* It doesn't include all the subspecs you might need for development
* It takes really long time to update every time you run `pod update` or `pod install` (given that you have modified `Podfile`)
  * The tarball is downloaded (50+ mb)
  * The tarball is unpacked
* There's podspec for 1.51.0 only
* You can't use the Pod if you need libraries like `serialization`
  * `serialization` has to be linked as a library, it doesn't work like the rest of the boost libraries by just including hpp headers inline. It needs to be compiled for your target platform.

## References and Attribution
This repo is practially a fork of https://github.com/wuhao5/boost.
Only this one does not contain boost source code, thus is more lightweight.

The Makefile kindly contributed by Richard Hodges (hodges.r@gmail.com).

The script mentioned above in it's turn is based on great work by Pete Goodliffe.

* https://gitorious.org/boostoniphone
* http://goodliffe.blogspot.com.au/2010/09/building-boost-framework-for-ios-iphone.html
* http://goodliffe.blogspot.com.au/2009/12/boost-on-iphone.html

And lots of contributions by other people.
