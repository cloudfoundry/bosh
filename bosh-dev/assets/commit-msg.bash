#!/bin/bash

commit=$1

if grep -q "www.pivotaltracker.com" $commit; then
	exit 0
fi

TMP_FILE=`mktemp /tmp/config.XXXXXXXXXX`
sed -r "s/\[#([0-9]+)\]/[#\1](http:\/\/www.pivotaltracker.com\/story\/show\/\1)/" $commit > $TMP_FILE
mv $TMP_FILE $commit