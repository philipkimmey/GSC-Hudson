#!/bin/bash

CODE_STORAGE_BASE=~/.hudson_repos

##
# Make sure source is in correct location.
##
if [ -e $CODE_STORAGE_BASE/UR ] && [ -e $CODE_STORAGE_BASE/perl_modules ]; then
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
rm $WORKSPACE/UR -rvf
rm $WORKSPACE/perl_modules -rvf
rm $WORKSPACE/test_result -rvf

##
# update UR & copy
##
cd $CODE_STORAGE_BASE/UR
git pull origin master # update UR
cd $WORKSPACE
git clone $CODE_STORAGE_BASE/UR/.git UR # clone UR from local .UR directory
cd $WORKSPACE/UR

##
# Put UR version information in revision.txt
##
echo -n "UR " >> ~/.hudson/jobs/$JOB_NAME/builds/$BUILD_NUMBER/revision.txt
git show --oneline --summary | head -n1 | cut -d ' ' -f1 >> ~/.hudson/jobs/$JOB_NAME/builds/$BUILD_NUMBER/revision.txt

##
# update genome and copy
##
cd $CODE_STORAGE_BASE/perl_modules
svn cleanup
svn up
cp $CODE_STORAGE_BASE/perl_modules $WORKSPACE/ -Rv

##
# Put Genome version information in revision.txt
##
cd $WORKSPACE/perl_modules
echo -n "Genome " >> ~/.hudson/jobs/$JOB_NAME/builds/$BUILD_NUMBER/revision.txt
svn log | head -n2 | tail -n1 | cut -d ' ' -f1 >> ~/.hudson/jobs/$JOB_NAME/builds/$BUILD_NUMBER/revision.txt

##
# run actual tests
##
cd $WORKSPACE/perl_modules/Genome
# PERL_TEST_HARNESS_DUMP_TAP=$WORKSPACE/test_result PERL5LIB=$WORKSPACE/UR/lib:~/.perl_libs/:/gsc/scripts/lib/perl ur test run --recurse --lsf-params="-R 'select[type==LINUX64 && model!=Opteron250 && tmp>1000 && mem>4000] rusage[tmp=1000, mem=4000]'" --lsf --jobs=10 --junit
PERL_TEST_HARNESS_DUMP_TAP=$WORKSPACE/test_result PERL5LIB=$WORKSPACE/UR/lib:/gscuser/pkimmey/.perl_libs/:/gsc/scripts/lib/perl ur test run --recurse --junit
