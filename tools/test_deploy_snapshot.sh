#!/bin/bash

# this "test" copies a snapshot to /tmp
# GENOME_DEV_MODE = 1 (see Genome::Config)

exit; # do you know what you're doing?

BASE_DIR="/gscuser/jlolofie/tmp/deploy"

HUDSON_BUILD=$1

    if [ -z $HUDSON_BUILD ]
    then 
        echo "first argument should be a hudson build id"
        exit
    fi


echo "unpacking the fake stuff to /tmp"

cd /tmp
tar -xvvf $BASE_DIR/deploy_snapshot.tar.gz


echo "executing deploy_snapshot"

GENOME_DEV_MODE=1 perl -I /gscuser/jlolofie/dev/git/genome/lib/perl/ $BASE_DIR/deploy_snapshot.pl $HUDSON_BUILD




