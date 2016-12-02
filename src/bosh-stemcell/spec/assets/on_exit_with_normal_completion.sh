#!/bin/bash

source $(dirname $0)/../../../stemcell_builder/lib/helpers.sh

add_on_exit "echo first on_exit action"
add_on_exit "echo second on_exit action"
add_on_exit "echo third on_exit action"
add_on_exit "echo fourth on_exit action"

echo "end of script"
