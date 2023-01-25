XCODE_DEVELOPER = $(shell xcode-select --print-path)
#used for selecting the sdk dir
IOS_PLATFORM ?= iPhoneOS

# Pick latest SDK in the directory
IOS_PLATFORM_DEVELOPER = ${XCODE_DEVELOPER}/Platforms/${IOS_PLATFORM}.platform/Developer
IOS_SDK = ${IOS_PLATFORM_DEVELOPER}/SDKs/$(shell ls ${IOS_PLATFORM_DEVELOPER}/SDKs | sort -r | head -n1)

all: lib/libspatialite.a
lib/libspatialite.a: build_arches
	mkdir -p lib
	mkdir -p include

	# Copy includes
	cp -R build/arm64-ios/include/geos include
	cp -R build/arm64-ios/include/spatialite include
	cp -R build/arm64-ios/include/*.h include

	# Make fat libraries for Simulator architectures 
	for file in build/arm64-sim/lib/*.a; \
		do name=`basename $$file .a`; \
		lipo -create \
			-arch arm64 build/arm64-sim/lib/$$name.a \
			-arch x86_64 build/x86_64/lib/$$name.a \
			-output lib/$$name.a \
		; \
		done;
	./make-framework
	
# Build separate architectures
# see https://www.innerfence.com/howto/apple-ios-devices-dates-versions-instruction-sets
build_arches:
	${MAKE} arch ARCH=x86_64 IOS_PLATFORM=iPhoneSimulator HOST=x86_64-apple-darwin TARGET=x86_64-apple-ios8.0-simulator ARCHDIR=x86_64
	${MAKE} arch ARCH=arm64 IOS_PLATFORM=iPhoneOS HOST=arm-apple-darwin TARGET=arm64-apple-ios8.0 ARCHDIR=arm64-ios
	${MAKE} arch ARCH=arm64 IOS_PLATFORM=iPhoneSimulator HOST=arm-apple-darwin TARGET=arm64-apple-ios8.0-simulator ARCHDIR=arm64-sim
	
PREFIX = ${CURDIR}/build/${ARCHDIR}
LIBDIR = ${PREFIX}/lib
BINDIR = ${PREFIX}/bin
INCLUDEDIR = ${PREFIX}/include
UTHASHDIR = ${CURDIR}/uthash

CXX = ${XCODE_DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++
CC = ${XCODE_DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang
CFLAGS =-target ${TARGET} -isysroot ${IOS_SDK} -I${IOS_SDK}/usr/include -I${INCLUDEDIR} -I${UTHASHDIR} -mios-version-min=8.0 -Os -fembed-bitcode
CXXFLAGS =-target ${TARGET} -stdlib=libc++ -std=c++11 -isysroot ${IOS_SDK} -I${IOS_SDK}/usr/include -I${INCLUDEDIR} -I${UTHASHDIR} -mios-version-min=8.0 -Os -fembed-bitcode
LDFLAGS =-stdlib=libc++ -isysroot ${IOS_SDK} -L${LIBDIR}
 -L${IOS_SDK}/usr/lib -arch ${ARCH} -mios-version-min=8.0

arch: ${LIBDIR}/libspatialite.a

${LIBDIR}/libspatialite.a: ${LIBDIR}/libsqlite3.a ${LIBDIR}/libproj.a ${LIBDIR}/libgeos.a ${LIBDIR}/rttopo.a ${CURDIR}/spatialite
	cd spatialite && env \
	CXX=${CXX} \
	CC=${CC} \
	CFLAGS="${CFLAGS}" \
	CXXFLAGS="${CXXFLAGS}" \
	LDFLAGS="${LDFLAGS} -liconv -lgeos -lgeos_c -lc++" ./configure --host=${HOST} --enable-freexl=no --enable-rttopo=yes --disable-examples \
	  --enable-libxml2=no --disable-freexl --disable-minizip --prefix=${PREFIX} --with-geosconfig=${BINDIR}/geos-config --disable-shared \
	  && make clean install-strip

${CURDIR}/spatialite:
	curl http://www.gaia-gis.it/gaia-sins/libspatialite-sources/libspatialite-5.0.1.tar.gz > spatialite.tar.gz
	tar -xzf spatialite.tar.gz
	rm spatialite.tar.gz
	mv libspatialite-5.0.1 spatialite
	./patch-spatialite
	./change-deployment-target spatialite

${CURDIR}/rttopo:
	git clone https://git.osgeo.org/gogs/rttopo/librttopo.git rttopo
	cd rttopo && ./autogen.sh
	./patch-rttopo
	./change-deployment-target rttopo

${LIBDIR}/rttopo.a: ${CURDIR}/rttopo
	cd rttopo && env \
	CXX=${CXX} \
	CC=${CC} \
	CFLAGS="${CFLAGS}" \
	CXXFLAGS="${CXXFLAGS}" \
	LDFLAGS="${LDFLAGS} -liconv -lgeos -lgeos_c -lc++" \
	./configure --host=${HOST} --prefix=${PREFIX} \
	    --disable-shared --with-geosconfig=${BINDIR}/geos-config && make clean install


${LIBDIR}/libproj.a: ${CURDIR}/proj
	cd proj && cmake \
	-DCMAKE_CXX_COMPILER="${CXX}" \
	-DCMAKE_C_COMPILER="${CC}" \
	-DCMAKE_C_FLAGS="${CFLAGS}" \
	-DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
	-DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}" \
	-DCMAKE_OSX_ARCHITECTURES=${ARCH} \
	-DCMAKE_OSX_SYSROOT:PATH="${IOS_SDK}" \
	-DBUILD_SHARED_LIBS=OFF \
	-DBUILD_APPS=OFF \
	-DBUILD_TESTING=OFF \
	-DENABLE_CURL=OFF \
	-DENABLE_TIFF=OFF \
	-DSQLITE3_INCLUDE_DIR=${INCLUDEDIR} \
	-DSQLITE3_LIBRARY=${LIBDIR}/libsqlite3.a \
	&& cmake --build . --target clean && cmake  --build . --config Release && cmake --install . --config Release

${CURDIR}/proj:
	curl -L http://download.osgeo.org/proj/proj-9.0.0.tar.gz > proj.tar.gz
	tar -xzf proj.tar.gz
	rm proj.tar.gz
	mv proj-9.0.0 proj

${LIBDIR}/libgeos.a: ${CURDIR}/geos
	cd geos && cmake \
	-DCMAKE_CXX_COMPILER="${CXX}" \
	-DCMAKE_C_COMPILER="${CC}" \
	-DCMAKE_C_FLAGS="${CFLAGS}" \
	-DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
	-DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}" \
	-DCMAKE_OSX_ARCHITECTURES=${ARCH} \
	-DCMAKE_OSX_SYSROOT:PATH="${IOS_SDK}" -DBUILD_GEOSOP:BOOL=OFF -DBUILD_SHARED_LIBS:BOOL=OFF -DBUILD_TESTING:BOOL=OFF \
	&& cmake --build . --target clean && cmake  --build . --config Release && cmake --install . --config Release

${CURDIR}/geos:
	curl http://download.osgeo.org/geos/geos-3.10.2.tar.bz2 > geos.tar.bz2
	tar -xzf geos.tar.bz2
	rm geos.tar.bz2
	mv geos-3.10.2 geos

${LIBDIR}/libsqlite3.a: ${CURDIR}/sqlite3
	cd sqlite3 && env LIBTOOL=${XCODE_DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/bin/libtool \
	CXX=${CXX} \
	CC=${CC} \
	CFLAGS="${CFLAGS} -DSQLITE_THREADSAFE=1 -DSQLITE_ENABLE_RTREE=1 -DSQLITE_ENABLE_FTS3=1 -DSQLITE_ENABLE_FTS3_PARENTHESIS=1" \
	CXXFLAGS="${CXXFLAGS} -DSQLITE_THREADSAFE=1 -DSQLITE_ENABLE_RTREE=1 -DSQLITE_ENABLE_FTS3=1 -DSQLITE_ENABLE_FTS3_PARENTHESIS=1" \
	LDFLAGS="-Wl,-arch -Wl,${ARCH} -arch_only ${ARCH} ${LDFLAGS}" \
	./configure --host=${HOST} --prefix=${PREFIX} --disable-shared \
	   --enable-dynamic-extensions --enable-static && make clean install-includeHEADERS install-libLTLIBRARIES

${CURDIR}/sqlite3:
	curl https://www.sqlite.org/2022/sqlite-autoconf-3380300.tar.gz > sqlite3.tar.gz
	tar xzvf sqlite3.tar.gz
	rm sqlite3.tar.gz
	mv sqlite-autoconf-3380300 sqlite3
	./change-deployment-target sqlite3
	touch sqlite3

clean:
	rm -rf build geos proj spatialite include lib rttopo sqlite3 LibSpatialite.xcframework
