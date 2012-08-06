#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

if [ -z "${TW_LOCAL_PASSPHRASE:-}" ]; then
    echo "No tripwire passphrase for local key - skipping tripwire setup!"
else
    echo "Found tripwire passphrase"

    tw_dir=$chroot/etc/tripwire

    # clean up default stuff
    rm -f $tw_dir/*

    #
    # generate keys if needed, then copy to chroot
    #
    site_key="$dir/assets/site.key"
    local_key="$dir/assets/local.key"

    if [ ! -f $site_key ]; then
        twadmin -m G \
            --site-passphrase ${TW_SITE_PASSPHRASE} \
            --site-keyfile $site_key
    fi

    if [ ! -f $local_key ]; then
        twadmin -m G \
            --local-passphrase ${TW_LOCAL_PASSPHRASE} \
            --local-keyfile $local_key
    fi

    cp $dir/assets/site.key $tw_dir
    cp $dir/assets/local.key $tw_dir

    # generate tw.cfg or reuse an existing one
    if [ -f $dir/assets/tw.cfg ]; then
        cp $dir/assets/tw.cfg $tw_dir
    else
        cp $dir/assets/twcfg.txt $tw_dir
        run_in_bosh_chroot $chroot "
            twadmin --create-cfgfile -S /etc/tripwire/site.key --site-passphrase ${TW_SITE_PASSPHRASE} /etc/tripwire/twcfg.txt
        "
        cp $tw_dir/tw.cfg $dir/assets
        rm $tw_dir/twcfg.txt
    fi

    # generate tw.pol or reuse an existing one
    if [ -f $dir/assets/tw.pol ]; then
        cp $dir/assets/tw.pol $tw_dir
    else
        cp $dir/assets/twpol.txt $tw_dir
        run_in_bosh_chroot $chroot "
            twadmin --create-polfile -S /etc/tripwire/site.key --site-passphrase ${TW_SITE_PASSPHRASE} /etc/tripwire/twpol.txt
        "
        cp $tw_dir/tw.pol $dir/assets
        rm $tw_dir/twpol.txt
    fi

    # create an empty db file so tripwire doesn't generate a warning about
    # the missing file
    tw_db=$chroot/var/lib/tripwire/db.twd
    touch $tw_db

    # generate the tripwire database
    run_in_bosh_chroot $chroot "
        tripwire --init --local-passphrase $TW_LOCAL_PASSPHRASE
    "

    mkdir -p $work/stemcell
    cp $tw_db $work/stemcell/tripwire.db

fi
