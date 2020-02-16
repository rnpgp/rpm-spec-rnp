#!/bin/sh
set -ex

pushd $RPM_DIR/RPMS
primary_rpm=$(find . -name "$PRIMARY_RPM" -print -quit)
pkgver=$(rpm -qp --queryformat '%{VERSION}-%{RELEASE}' "$primary_rpm")
# we need a newish ruby for create-github-release.rb
yum -y -q install centos-release-scl
yum -y -q install rh-ruby25
# workaround for scl_source bug/limitation
set +eu
source scl_source enable rh-ruby25
set -eu
# release it
git clone --depth 1 https://github.com/riboseinc/create-github-release
pushd create-github-release
gem install bundler -v 1.16.4
bundle install
bundle exec ./create-github-release.rb \
    "rnpgp/rpm-spec-$PROJECT_NAME" \
    "$pkgver" \
    --name "$PROJECT_NAME $pkgver" \
    --release-notes "Automatically built in commit $(echo $GITHUB_SHA | cut -c 1-8)." \
    "$RPM_DIR"/RPMS/*.rpm \
    "$RPM_DIR"/SRPMS/*.src.rpm
popd
popd
