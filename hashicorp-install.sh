#!/bin/sh
set -eu

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
        PACKAGE_VERSION="${PACKAGE_VERSION:-1.8.5}"
        ;;
    consul-esm)
        PACKAGE_VERSION="${PACKAGE_VERSION:-0.4.0}"
        ;;
    packer)
        PACKAGE_VERSION="${PACKAGE_VERSION:-1.6.5}"
        ;;
    terraform)
        PACKAGE_VERSION="${PACKAGE_VERSION:-0.13.5}"
        ;;
    vault)
        PACKAGE_VERSION="${PACKAGE_VERSION:-1.5.5}"
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

if [ ! -x /usr/bin/gpgv ]; then
    echo "Then gpgv utility is needed to verify $PACKAGE_ZIP." >> /dev/stderr
    exit 1
fi

if [ ! -x /usr/bin/unzip ]; then
    echo "Then unzip utility is needed to extract $PACKAGE_ZIP." >> /dev/stderr
    exit 1
fi

if [ -x /usr/bin/curl ]; then
    DOWNLOAD_COMMAND="curl -sSL -C - -O"
elif [ -x /usr/bin/wget ]; then
    DOWNLOAD_COMMAND="wget -c -q"
else
    echo "Either the curl or wget programs are required to download $PACKAGE_NAME." >> /dev/stderr
    exit 1
fi

# Check if desired version is already installed first.
if [ -x "$PACKAGE_BIN" ]; then
    PACKAGE_VERSION_OUT="$($PACKAGE_BIN --version)"
    if [ "$PACKAGE_NAME" = "packer" ]; then
        PACKAGE_CURRENT_VERSION="$PACKAGE_VERSION_OUT"
    elif [ "$PACKAGE_NAME" = "consul-esm" ]; then
        PACKAGE_CURRENT_VERSION="$(echo "$PACKAGE_VERSION_OUT" | tr -d v)"
    else
        PACKAGE_CURRENT_VERSION="$(echo "$PACKAGE_VERSION_OUT" | head -n 1 | awk '{ print $2 }' | tr -d v)"
    fi
    if [ "$PACKAGE_VERSION" = "$PACKAGE_CURRENT_VERSION" ]; then
        echo "$PACKAGE_NAME v$PACKAGE_VERSION is already installed."
        exit 0
    fi
fi

# Do all our file manipulation in temporary fs.
cd "$PACKAGE_TMP"

# Create Hashicorp GPG keyring from base64-encoded binary of the release
# key (91A6E7F85D05C65630BEF18951852D87348FFC4C).
if [ ! -f hashicorp.gpg ]; then
echo "mQENBFMORM0BCADBRyKO1MhCirazOSVwcfTr1xUxjPvfxD3hjUwHtjsOy/bT6p9fW2mRPfwnq2JB
5As+paL3UGDsSRDnK9KAxQb0NNF4+eVhr/EJ18s3wwXXDMjpIifqfIm2WyH3G+aRLTLPIpscUNKD
yxFOUbsmgXAmJ46Re1fn8uKxKRHbfa39aeuEYWFA3drdL1WoUngvED7f+RnKBK2G6ZEpO+LDovQk
19xGjiMTtPJrjMjZJ3QXqPvx5wcaKSZLr4lMTuoTI/ZXyZy5bD4tShiZz6KcyX27cD70q2iRcEZ0
poLKHyEIDAi3TM5kSwbbWBFd5RNPOR0qzrb/0p9ksKK48IIfH2FvABEBAAG0K0hhc2hpQ29ycCBT
ZWN1cml0eSA8c2VjdXJpdHlAaGFzaGljb3JwLmNvbT6JATgEEwECACIFAlMORM0CGwMGCwkIBwMC
BhUIAgkKCwQWAgMBAh4BAheAAAoJEFGFLYc0j/xMyWIIAIPhcVqiQ59nJc07gjUX0SWBJAxEG1lK
xfzS4Xp+57h2xxTpdotGQ1fZwsihaIqow337YHQI3q0iSqV534Ms+j/tU7X8sq11xFJIeEVG8PAS
RCwmryUwghFKPlHETQ8jJ+Y8+1asRydipsP3B/5Mjhqv/uOK+Vy3zAyIpyDOMtIpOVfjSpCplVRd
tSTFWBu9Em7j5I2HMn1wsJZnJgXKpybpibGiiTtmnFLOwibmprSu04rsnP4ncdC2XRD4wIjoyA+4
PKgX3sCOklEzKryWYBmLkJOMDdo52LttP3279s7XrkLEE7ia0fXa2c12EQ0f0DQ1tGUvyVEWWmJV
ccm5bq25AQ0EUw5EzQEIANaPUY04/g7AmYkOMjaCZ6iTp9hB5Rsj/4ee/ln9wArzRO9+3eejLWh5
3FoN1rO+su7tiXJA5YAzVy6tuolrqjM8DBztPxdLBbEi4V+j2tK0dATdBQBHEh3OJApO2UBtcjaZ
BT31zrG9K55D+CrcgIVEHAKY8Cb4kLBkb5wMskn+DrASKU0BNIV1qRsxfiUdQHZfSqtp004nrql1
lbFMLFEuiY8FZrkkQ9qduixomTT6f34/oiY+Jam3zCK7RDN/OjuWheIPGj/Qbx9JuNiwgX6yRj7O
E1tjUx6d8g9y0H1fmLJbb3WZZbuuGFnK6qrE3bGeY8+AWaJAZ37wpWh1p0cAEQEAAYkBHwQYAQIA
CQUCUw5EzQIbDAAKCRBRhS2HNI/8TJntCAClU7TOO/X053eKF1jqNW4A1qpxctVcz8eTcY8Om5O4
f6a/rfxfNFKn9Qyja/OG1xWNobETy7MiMXYjaa8uUx5iFy6kMVaP0BXJ59NLZjMARGw6lVTYDTIv
zqqqwLxgliSDfSnqUhubGwvykANPO+93BBx89MRGunNoYGXtPlhNFrAsB1VR8+EyKLv2HQtGCPSF
BhrjuzH3gxGibNDDdFQLxxuJWepJEK1UbTS4ms0NgZ2Uknqn1WRU1Ki7rE4sTy68iZtWpKQXZEJa
0IGnuI2sSINGcXCJoEIgXTMyCILo34Fa/C6VCm2WBgz9zZO8/rHIiQm1J5zqz0DrDwKBUM9C" | \
    base64 -d > hashicorp.gpg
fi

# Download Package files.
for package_file in "$PACKAGE_ZIP" "$PACKAGE_CHECKSUMS" "$PACKAGE_SIGNATURE"
do
    $DOWNLOAD_COMMAND "$PACKAGE_BASEURL/$package_file"
done

# GPG verify the signature for the SHA256SUMS file.
gpgv --keyring "$PACKAGE_TMP/hashicorp.gpg" "$PACKAGE_SIGNATURE" "$PACKAGE_CHECKSUMS"

# Verify checksums, but grep out all other lines in the checksum
# file except the desired package.
grep -e "[[:space:]]\\+$PACKAGE_ZIP\\>" "$PACKAGE_CHECKSUMS" | sha256sum -c

# Finally extract the zip file.
if [ "$(id -u)" -eq 0 ]; then
    unzip -o "$PACKAGE_ZIP" -d "$PACKAGE_PATH"
else
    sudo unzip -o "$PACKAGE_ZIP" -d "$PACKAGE_PATH"
fi

# Clean up.
rm -f "$PACKAGE_ZIP" "$PACKAGE_CHECKSUMS" "$PACKAGE_SIGNATURE"
