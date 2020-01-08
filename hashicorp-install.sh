#!/bin/bash
set -euo pipefail

LSB_DIST="$(. /etc/os-release && echo "$ID")"

# What Hashicorp package are we installing today?
PACKAGE_NAME="${1:-}"

# Allow overrides from environment for:
#  * PACKAGE_ARCH
#  * PACKAGE_BASEURL
#  * PACKAGE_PATH
#  * PACKAGE_TMP
#  * PACKAGE_VERSION
PACKAGE_ARCH="${PACKAGE_ARCH:-amd64}"
case "$PACKAGE_NAME" in
    consul)
        PACKAGE_VERSION="${PACKAGE_VERSION:-1.6.2}"
        ;;
    packer)
        PACKAGE_VERSION="${PACKAGE_VERSION:-1.4.5}"
        ;;
    terraform)
        PACKAGE_VERSION="${PACKAGE_VERSION:-0.12.17}"
        ;;
    *)
        if [ -n "$PACKAGE_NAME" ]; then
            echo "Unknown Hashicorp package: $PACKAGE_NAME" >> /dev/stderr
        else
            echo "Must provide name of Hashicorp package: consul, packer, or terraform." >> /dev/stderr
        fi
        exit 1
        ;;
esac
PACKAGE_BASEURL="${PACKAGE_BASEURL:-https://releases.hashicorp.com/$PACKAGE_NAME/$PACKAGE_VERSION}"
PACKAGE_PATH="${PACKAGE_PATH:-/usr/local/bin}"
PACKAGE_BIN="${PACKAGE_PATH}/${PACKAGE_NAME}"
PACKAGE_ZIP="${PACKAGE_NAME}_${PACKAGE_VERSION}_linux_${PACKAGE_ARCH}.zip"
PACKAGE_CHECKSUMS="${PACKAGE_NAME}_${PACKAGE_VERSION}_SHA256SUMS"
PACKAGE_SIGNATURE="${PACKAGE_CHECKSUMS}.sig"
PACKAGE_TMP="${PACKAGE_TMP:-/var/tmp}"

if [ ! -x /usr/bin/gpg ]; then
    echo "Then gpg utility is needed to verify $PACKAGE_ZIP." >> /dev/stderr
    exit 1
fi

if [ ! -x /usr/bin/unzip ]; then
    echo "Then unzip utility is needed to extract $PACKAGE_ZIP." >> /dev/stderr
    exit 1
fi

# Check if desired version is already installed first.
if [ -x "$PACKAGE_BIN" ]; then
    PACKAGE_VERSION_OUT="$($PACKAGE_BIN --version)"
    if [ "$PACKAGE_NAME" == "packer" ]; then
        PACKAGE_CURRENT_VERSION="$PACKAGE_VERSION_OUT"
    else
        PACKAGE_CURRENT_VERSION="$(echo "$PACKAGE_VERSION_OUT" | head -n 1 | awk '{ print $2 }' | tr -d v)"
    fi
    if [ "$PACKAGE_VERSION" == "$PACKAGE_CURRENT_VERSION" ]; then
        echo "$PACKAGE_NAME v$PACKAGE_VERSION is already installed."
        exit 0
    fi
fi

# Do all our file manipulation in temporary fs.
pushd "$PACKAGE_TMP"

if [ ! -d "$PACKAGE_TMP/.gnupg-hashicorp" ]; then
    mkdir -m 0700 "$PACKAGE_TMP/.gnupg-hashicorp"
fi

# Import Hashicorp key.
if ! gpg --homedir "$PACKAGE_TMP/.gnupg-hashicorp" --list-public-keys --with-colons | \
        awk -F: '{ print $5 }' | \
        grep -q -e '\<51852D87348FFC4C\>'; then
    cat > hashicorp.key <<EOF
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v1

mQENBFMORM0BCADBRyKO1MhCirazOSVwcfTr1xUxjPvfxD3hjUwHtjsOy/bT6p9f
W2mRPfwnq2JB5As+paL3UGDsSRDnK9KAxQb0NNF4+eVhr/EJ18s3wwXXDMjpIifq
fIm2WyH3G+aRLTLPIpscUNKDyxFOUbsmgXAmJ46Re1fn8uKxKRHbfa39aeuEYWFA
3drdL1WoUngvED7f+RnKBK2G6ZEpO+LDovQk19xGjiMTtPJrjMjZJ3QXqPvx5wca
KSZLr4lMTuoTI/ZXyZy5bD4tShiZz6KcyX27cD70q2iRcEZ0poLKHyEIDAi3TM5k
SwbbWBFd5RNPOR0qzrb/0p9ksKK48IIfH2FvABEBAAG0K0hhc2hpQ29ycCBTZWN1
cml0eSA8c2VjdXJpdHlAaGFzaGljb3JwLmNvbT6JATgEEwECACIFAlMORM0CGwMG
CwkIBwMCBhUIAgkKCwQWAgMBAh4BAheAAAoJEFGFLYc0j/xMyWIIAIPhcVqiQ59n
Jc07gjUX0SWBJAxEG1lKxfzS4Xp+57h2xxTpdotGQ1fZwsihaIqow337YHQI3q0i
SqV534Ms+j/tU7X8sq11xFJIeEVG8PASRCwmryUwghFKPlHETQ8jJ+Y8+1asRydi
psP3B/5Mjhqv/uOK+Vy3zAyIpyDOMtIpOVfjSpCplVRdtSTFWBu9Em7j5I2HMn1w
sJZnJgXKpybpibGiiTtmnFLOwibmprSu04rsnP4ncdC2XRD4wIjoyA+4PKgX3sCO
klEzKryWYBmLkJOMDdo52LttP3279s7XrkLEE7ia0fXa2c12EQ0f0DQ1tGUvyVEW
WmJVccm5bq25AQ0EUw5EzQEIANaPUY04/g7AmYkOMjaCZ6iTp9hB5Rsj/4ee/ln9
wArzRO9+3eejLWh53FoN1rO+su7tiXJA5YAzVy6tuolrqjM8DBztPxdLBbEi4V+j
2tK0dATdBQBHEh3OJApO2UBtcjaZBT31zrG9K55D+CrcgIVEHAKY8Cb4kLBkb5wM
skn+DrASKU0BNIV1qRsxfiUdQHZfSqtp004nrql1lbFMLFEuiY8FZrkkQ9qduixo
mTT6f34/oiY+Jam3zCK7RDN/OjuWheIPGj/Qbx9JuNiwgX6yRj7OE1tjUx6d8g9y
0H1fmLJbb3WZZbuuGFnK6qrE3bGeY8+AWaJAZ37wpWh1p0cAEQEAAYkBHwQYAQIA
CQUCUw5EzQIbDAAKCRBRhS2HNI/8TJntCAClU7TOO/X053eKF1jqNW4A1qpxctVc
z8eTcY8Om5O4f6a/rfxfNFKn9Qyja/OG1xWNobETy7MiMXYjaa8uUx5iFy6kMVaP
0BXJ59NLZjMARGw6lVTYDTIvzqqqwLxgliSDfSnqUhubGwvykANPO+93BBx89MRG
unNoYGXtPlhNFrAsB1VR8+EyKLv2HQtGCPSFBhrjuzH3gxGibNDDdFQLxxuJWepJ
EK1UbTS4ms0NgZ2Uknqn1WRU1Ki7rE4sTy68iZtWpKQXZEJa0IGnuI2sSINGcXCJ
oEIgXTMyCILo34Fa/C6VCm2WBgz9zZO8/rHIiQm1J5zqz0DrDwKBUM9C
=LYpS
-----END PGP PUBLIC KEY BLOCK-----
EOF
    gpg --homedir "$PACKAGE_TMP/.gnupg-hashicorp" --import < hashicorp.key
    rm hashicorp.key
fi

if [ "$LSB_DIST" == 'centos' ] || [ "$LSB_DIST" == 'fedora' ] || [ "$LSB_DIST" == 'rhel' ]; then
    DOWNLOAD_COMMAND="curl -sSL -O"
elif [ "$LSB_DIST" == 'debian' ] || [ "$LSB_DIST" == 'ubuntu' ]; then
    DOWNLOAD_COMMAND="wget -nv -L"
else
    echo "Do not know how to install $PACKAGE_NAME on $LSB_DIST."
    exit 1
fi

# Download Package files.
for package_file in "$PACKAGE_ZIP" "$PACKAGE_CHECKSUMS" "$PACKAGE_SIGNATURE"
do
    $DOWNLOAD_COMMAND "$PACKAGE_BASEURL/$package_file"
done

# GPG verify the signature for the SHA256SUMS file.
gpg --homedir "$PACKAGE_TMP/.gnupg-hashicorp"  --verify "$PACKAGE_SIGNATURE"

# Verify checksums, but grep out all other lines in the checksum
# file except the desired package.
sha256sum -c <(grep -e "[[:space:]]\\+$PACKAGE_ZIP\\>" "$PACKAGE_CHECKSUMS")

# Finally extract the zip file.
if [ "$EUID" -eq 0 ]; then
    unzip -o "$PACKAGE_ZIP" -d "$PACKAGE_PATH"
else
    sudo unzip -o "$PACKAGE_ZIP" -d "$PACKAGE_PATH"
fi

# Clean up.
rm -f "$PACKAGE_ZIP" "$PACKAGE_CHECKSUMS" "$PACKAGE_SIGNATURE"
popd
