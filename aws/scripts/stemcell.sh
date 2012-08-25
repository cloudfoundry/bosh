#!/bin/bash
#
# script to pull down the stemcell and unpack it
#
set -e

# if run over ssh non-interactive this needs to be included
. $HOME/.bash_profile

STEMCELL="micro-bosh-stemcell-aws-0.6.4.tgz"
if [ ! -f $STEMCELL ]
then
    bosh download public stemcell $STEMCELL
    mkdir stemcell
    cd stemcell
    tar xzf ../$STEMCELL
fi
