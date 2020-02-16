#!/bin/sh
set -ex
# See https://github.com/rnpgp/rnp/blob/master/doc/PACKAGING.md

: "${OUTPUT_DIR:=~/rpmbuild}"

echo "OUTPUT_DIR=$OUTPUT_DIR"

# shellcheck disable=SC1091
. ~/rpm-specs/setup_env.sh

# build_cmake_package() {
#   local readonly package_name="${1}"
#
#   rpmdev-setuptree
#   yes | cp -a /usr/local/${package-name}/* ~/rpmbuild/SOURCES
#
#   # spectool -g -R ${spec_dest}
#   rpmbuild --define "_topdir <path_to_build_dir>" --rebuild <SRPM_file_name>
#   rpmbuild ${RPMBUILD_FLAGS:--v -ba} ${spec_dest} || \
#     {
#       echo "rpmbuild failed." >&2;
#       [ $CI ] && exit 1
#       if [ "$(launched_from)" != "bash" ]; then
#         echo "Now yielding control to bash." >&2 && \
#         exec bash
#       fi
#     }
# }

yum -y install cmake3 make g++ rpmdevtools jq bzip2-devel zlib-devel libcmocka-devel libstdc++-static \
	botan2-devel json-c-devel

if [ ! -f /usr/bin/cmake ]; then
  ln -s /usr/bin/cmake3 /usr/bin/cmake
fi

if [ ! -f /usr/bin/cpack ]; then
  ln -s /usr/bin/cpack3 /usr/bin/cpack
fi

rpmdev-setuptree
pushd ~/rpmbuild/SOURCES/

# $SOURCE can be 'git' or whatever.
if [[ "${SOURCE}" = git ]]; then
	SOURCE_PATH=rnp${VERSION:+-${VERSION}}
	git clone https://github.com/rnpgp/rnp "${SOURCE_PATH}"
	pushd ~/"rpmbuild/SOURCES/${SOURCE_PATH}"
  if [ -z "$VERSION" ]; then
    VERSION="$(git tag -l --sort=-v:refname | head -1 | cut -c 2-)"
  fi
  git fetch
  git checkout "${VERSION}"
else
	# $VERSION is only for downloading the package archive from a URL.
  if [ -z "$VERSION" ]; then
    release_data=$(curl -s -X GET                       \
      -H "Content-Type: application/json"               \
      -H "Accept: application/json"                     \
      https://api.github.com/repos/rnpgp/rnp/tags   \
      | jq .[0]
    )
    VERSION=$(echo "$release_data" | jq -r .name | cut -c 2-)
  fi

	curl -LO "https://github.com/rnpgp/rnp/archive/v${VERSION}.tar.gz"
	tar -xzf "v${VERSION}.tar.gz"

	pushd ~/"rpmbuild/SOURCES/rnp-${VERSION}"
fi

cmake -DBUILD_SHARED_LIBS=on -DBUILD_TESTING=off -DCPACK_GENERATOR=RPM .
cpack -G RPM --config ./CPackSourceConfig.cmake
make package

if [ ! -d $OUTPUT_DIR ]; then
  mkdir $OUTPUT_DIR
fi

mkdir $OUTPUT_DIR/SRPMS
mkdir $OUTPUT_DIR/RPMS

mv ./*.src.rpm $OUTPUT_DIR/SRPMS/
mv ./*.rpm $OUTPUT_DIR/RPMS/

yum install -y $OUTPUT_DIR/RPMS/*.rpm

popd
popd
