#!/bin/bash
set -o errexit

losetup -d ${1}
