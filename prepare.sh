#!/bin/bash
set -ex

# shellcheck disable=SC1091
ls -la /usr/local/rpm-specs/
. /usr/local/rpm-specs/setup_env.sh

yum -y install bzip2-devel zlib-devel libcmocka-devel libstdc++-static \
	botan2-devel json-c-devel
ln -s /usr/bin/cmake3 /usr/bin/cmake
ln -s /usr/bin/cpack3 /usr/bin/cpack

rpmdev-setuptree
cd ~/rpmbuild/SOURCES/

# $SOURCE can be 'git' or whatever.
if [[ "${SOURCE}" = git ]]; then
	SOURCE_PATH=rnp${RNP_VERSION:+-${RNP_VERSION}}
	git clone https://github.com/rnpgp/rnp "${SOURCE_PATH}"
	cd ~/"rpmbuild/SOURCES/${SOURCE_PATH}"
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

	cd ~/"rpmbuild/SOURCES/rnp-${VERSION}"
fi

cmake -DBUILD_SHARED_LIBS=on -DBUILD_TESTING=off -DCPACK_GENERATOR=RPM .
cpack -G RPM --config ./CPackSourceConfig.cmake
make package

mv ./*.src.rpm ~/rpmbuild/SRPMS/
# mkdir -p ~/rpmbuild/RPMS/noarch/
# mv *.noarch.rpm ~/rpmbuild/RPMS/noarch/
mkdir -p ~/rpmbuild/RPMS/x86_64/
mv ./*.rpm ~/rpmbuild/RPMS/x86_64/

yum install -y ~/rpmbuild/RPMS/x86_64/*.rpm

# bash
