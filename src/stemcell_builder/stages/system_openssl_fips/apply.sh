#!/usr/bin/env bash

set -e -x

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

cp -a $assets_dir/install.sh $chroot/tmp
run_in_chroot $chroot "
chmod +x /tmp/install.sh
/tmp/install.sh
rm -f /tmp/install.sh
"

