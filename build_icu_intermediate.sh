#!/bin/bash
exit_with_message() {
  echo "$1"
  echo "Press Enter to continue"
  read -n 1
  exit "${2:-1}"
}

[ -z "$ICU_INSTALL_DIR" ] && exit_with_message "Error: ICU_INSTALL_DIR environment variable is not set."

#dirs
BUILD_DIR="$ICU_INSTALL_DIR/build"
ICU_SRC_DIR="$ICU_INSTALL_DIR/source"

#cd to icu install dir
cd "$ICU_INSTALL_DIR" ||  exit_with_message "cannot cd to $ICU_INSTALL_DIR";


# Setup directories
ICU_INTERMEDIATE_OS_BUILD_DIR="$BUILD_DIR/intermediate_osx"

# Handle 'clean' parameter
if [ "$1" == "clean" ]; then
  echo "Performing cleanup..."
  rm -rf "$ICU_INTERMEDIATE_OS_BUILD_DIR" || exit_with_message "Cannot delete $ICU_INTERMEDIATE_OS_BUILD_DIR"
  exit 0
fi

# Build the intermediate build if neded 
if [[ ! -d "$ICU_INTERMEDIATE_OS_BUILD_DIR" ]]; then
    mkdir -p "$ICU_INTERMEDIATE_OS_BUILD_DIR"
    cd "$ICU_INTERMEDIATE_OS_BUILD_DIR" || exit_with_message "cannot cd to $ICU_INTERMEDIATE_OS_BUILD_DIR"
    "${ICU_SRC_DIR}/./runConfigureICU" MacOSX \
        --prefix="$ICU_INTERMEDIATE_OS_BUILD_DIR" \
        --enable-static \
        --enable-shared=no \
        --enable-extras=no \
        --enable-strict=no \
        --enable-icuio=no \
        --enable-layout=no \
        --enable-layoutex=no \
        --enable-tools=yes \
        --enable-tests=no \
        --enable-samples=no \
        --enable-dyload=no &&
        make

else 
  echo "skipping intermediate build because $ICU_INTERMEDIATE_OS_BUILD_DIR exists"
fi

