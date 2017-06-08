#!/usr/bin/env bash
set -e

work_dir=$(readlink -nf $(dirname $0))/openssl_fips
mkdir -p $work_dir

echo "Install openssl module"
cd $work_dir
wget http://openssl.org/source/openssl-fips-2.0.16.tar.gz
tar zxvf openssl-fips*.tar.gz
cd openssl-fips*
./config
make
make install
rc=$?
if [[ $rc -ne 0 ]]; then
	echo "openssl fips module installation failed with exit code $rc"
	exit $rc
else
	echo "openssl fips module installation is successful"
fi

echo "Install openssl"
cd $work_dir
wget https://www.openssl.org/source/openssl-1.0.2l.tar.gz
tar zxvf openssl-1*.tar.gz
cd openssl-1*
export FIPSDIR=/usr/local/ssl/fips-2.0
./config fips shared
make depend
make
make install
rc=$?
if [[ $rc -ne 0 ]]; then
	echo "openssl installation failed with exit code $rc"
	exit $rc
else
	echo "openssl installation is successful"
fi

# Replace with the new openssl
mv /usr/bin/openssl /usr/bin/openssl_101
mv /usr/bin/c_rehash /usr/bin/c_rehash_101
ln -s /usr/local/ssl/bin/openssl /usr/bin/openssl
ln -s /usr/local/ssl/bin/c_rehash /usr/bin/c_rehash

# Verify the version of openssl
/usr/local/ssl/bin/openssl version

# Clean up
cd /
rm -fr $work_dir
