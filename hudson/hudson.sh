#!/bin/bash

if [ -n "${HUDSON_PROJECT_PATH+x}" ]; then
    echo "HUDSON_PROJECT_PATH set, continuing"
else
    echo "HUDSON_PROJECT_PATH not set. Exiting."
    exit
fi

if [ -n "${CODE_STORAGE_BASE+x}" ]; then
    echo "CODE_STORAGE_BASE is set, continuing"
else
    echo "CODE_STORAGE_BASE not set. Exiting."
    exit
fi

##
# Make sure source is in correct location.
##
if [ -e $CODE_STORAGE_BASE/UR ] && [ -e $CODE_STORAGE_BASE/genome ]; then
	echo "$CODE_STORAGE_BASE/{UR, perl_modules} folders exists. Assuming it is valid."
else
	echo "$CODE_STORAGE_BASE/UR folders do not all exist. Please run 'make install'. Exiting."
	exit
fi

##
# clean out existing folder
##
if [ -n "${WORKSPACE+x}" ]; then
	echo "WORKSPACE env variable is set. You are running in Hudson."
else
	echo "WORKSPACE env variable not set. Run in Hudson. Exiting."
	exit
fi
#rm $WORKSPACE/UR -rvf
#rm $WORKSPACE/perl_modules -rvf
#rm $WORKSPACE/test_result -rvf
rm $WORKSPACE/* -rf
##
# update UR & copy
##
cd $CODE_STORAGE_BASE/UR
/gsc/bin/git reset --hard
/gsc/bin/git pull origin master # update UR
cd $CODE_STORAGE_BASE/workflow
/gsc/bin/git reset --hard
/gsc/bin/git pull origin master
cd $CODE_STORAGE_BASE/genome
/gsc/bin/git reset --hard
/gsc/bin/git pull origin master
cd $WORKSPACE

/gsc/bin/git clone $CODE_STORAGE_BASE/UR/.git UR # clone UR from local .UR directory
cd $WORKSPACE/UR

##
# Put UR version information in revision.txt
##
echo -n "UR " >> $HUDSON_PROJECT_PATH/$JOB_NAME/builds/$BUILD_NUMBER/revision.txt
/gsc/bin/git show --oneline --summary | head -n1 | cut -d ' ' -f1 >> $HUDSON_PROJECT_PATH/$JOB_NAME/builds/$BUILD_NUMBER/revision.txt

##
# copy genome
##
cd $WORKSPACE
/gsc/bin/git clone $CODE_STORAGE_BASE/genome/.git genome

##
# put genome version information in revision.txt
##
cd $WORKSPACE/genome
echo -n "genome " >> $HUDSON_PROJECT_PATH/$JOB_NAME/builds/$BUILD_NUMBER/revision.txt
/gsc/bin/git show --oneline --summary | head -n1 | cut -d ' ' -f1 >> $HUDSON_PROJECT_PATH/$JOB_NAME/builds/$BUILD_NUMBER/revision.txt

##
# copy workflow
##
cd $WORKSPACE
/gsc/bin/git clone $CODE_STORAGE_BASE/workflow/.git workflow

##
# put workflow information in revision.txt
##
cd $WORKSPACE/workflow
echo -n "workflow " >> $HUDSON_PROJECT_PATH/$JOB_NAME/builds/$BUILD_NUMBER/revision.txt
/gsc/bin/git show --oneline --summary | head -n1 | cut -d ' ' -f1 >> $HUDSON_PROJECT_PATH/$JOB_NAME/builds/$BUILD_NUMBER/revision.txt


##
# run actual tests
##
cd $WORKSPACE/genome/lib/perl/Genome/
export PERL_TEST_HARNESS_DUMP_TAP=$WORKSPACE/test_result
export PERL5LIB=$WORKSPACE/UR/lib:$WORKSPACE/genome/lib/perl:$WORKSPACE/workflow/lib/perl:/gsc/lib/perl5/site_perl/5.8.3/i686-linux/:/gsc/lib/perl5/site_perl/5.8.3/:/gsc/lib/perl5/5.8.7/
/gsc/scripts/sbin/gsc-cron $WORKSPACE/UR/bin/ur test run --recurse --junit --lsf --jobs=5
