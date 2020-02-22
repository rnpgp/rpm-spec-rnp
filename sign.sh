#!/bin/sh
set -ex

pushd $RPM_DIR
yum -y install rpmdevtools rpm-sign expect

# install rnp for signing
rpm --import https://github.com/riboseinc/yum/raw/master/ribose-packages.pub
curl -L https://github.com/riboseinc/yum/raw/master/ribose.repo > /etc/yum.repos.d/ribose.repo
yum -y install rnp
# set some macros
cat <<EOF >~/.rpmmacros
%_gpg_name $PACKAGER
%__gpg_check_password_cmd %{_bindir}/rnp \
    rnp --pass-fd 3 --userid "%{_gpg_name}" --sign --output=-
%__gpg_sign_cmd %{_bindir}/rnp \
    rnp --pass-fd 3 --userid "%{_gpg_name}" --sign --detach --output=%{__signature_filename} %{__plaintext_filename}
EOF
# remove gpg, just to make sure we're signing with rnp like we are expecting
rm $(rpm --eval '%{__gpg}')
rm -f /usr/bin/gpg /usr/bin/gpg2
# import the key and sign
rnpkeys --import "$SIGNING_KEY_PATH"
for pkg in RPMS/**/*.rpm SRPMS/*.src.rpm; do
    expect <<EOF
    spawn rpm --addsign "$pkg"
    expect -ex        "Enter pass phrase: "
    send -- "\r"
    expect eof
EOF
    # verification should fail since we haven't imported the public key
    ! rpmdev-checksig "$pkg"
    ! rpm --checksig "$pkg"
    # export + import to the rpm db
    public_key_path="$(mktemp --tmpdir signing-key-pub.gpg.XXXX)"
    rnpkeys --export-key "$PACKAGER" > "$public_key_path"
    rpm --import "$public_key_path"
    # verification should succeed at this point
    # rpmdev-checksig will fail if no signature is present (so it's a good additional check)
    rpmdev-checksig "$pkg"
    rpm --checksig "$pkg"
done
popd
