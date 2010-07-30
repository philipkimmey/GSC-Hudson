package Defaults;

our $RSS_FEED_URL = 'http://hudson:8090/job/Genome/rssAll';
our $BUILD_PATH = '/gscuser/mjohnson/.hudson/jobs/Genome/builds';
our $SNAPSHOT_PATH = $ENV{HOME} . '/.snapshot';
our $GSCPAN = $ENV{GSCPAN} || 'svn+ssh://svn/srv/svn/gscpan';

our $UR_REPOSITORY = 'git://github.com/sakoht/UR.git';
our $WORKFLOW_REPOSITORY = 'ssh://git/srv/git/workflow.git';
our $GENOME_REPOSITORY = 'ssh://git/srv/git/genome.git';
