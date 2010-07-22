#!/gsc/bin/perl

use strict;
use warnings;

use LWP::Simple;
use Getopt::Long;

#############
# 1. Get RSS feed to see if anything has passed today
# 2. If so, get SVN and Git versions of Genome and UR
# 3. Copy the relevant folders into the SNAPSHOT_PATH.
# 4. Run UR's test runner to generate relevant sqlite dbs
# 5. Deploy to /gsc/scripts/opt
# 6. Deploy to /gsc/scripts/lib/perl
#############
my $RSS_FEED_URL = 'http://linus262:8080/job/Genome/rssAll';
my $BUILD_PATH = '/gscuser/pkimmey/.hudson/jobs/Genome/builds';
my $SNAPSHOT_PATH = '/gscuser/pkimmey/.snapshot'; # path to snapshots dir. Eventually will move stuff to opt
my $GSCPAN = $ENV{GSCPAN} || 'svn+ssh://svn/srv/svn/gscpan'; #

my $UR_REPOSITORY = 'git://github.com/sakoht/UR.git';
my $WORKFLOW_REPOSITORY = 'ssh://git/srv/git/workflow.git';
my $GENOME_REPOSITORY = 'ssh://git/srv/git/genome.git';

####
# Parse Hudson's build status RSS feed and return the most recent successful build from today.
#
# Yes I am using Regexs to parse Xml. See:
# http://stackoverflow.com/questions/1732348/regex-match-open-tags-except-xhtml-self-contained-tags/1732454#1732454
####
sub check_for_new_build { # returns new build number or 0 if none.
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $mon = ($mon+1); # mon is 0 indexed by default.

    my $rss_feed = get('http://linus262:8080/job/Genome/rssAll');

    my @entries = ($rss_feed =~ /<entry>(.+?)<\/entry>/g);

    foreach (@entries) {
        $_ =~ /<published>\d{4}-(\d+)-(\d+)T.+<\/published>/; # $1 is month, $2 is day
        if ($1 == ($mon) && $2 == $mday) { # this build is from today.
            $_ =~ /<title>Genome #(\d+)\s\((\w+)\)<\/title>/;
            if ($2 eq "SUCCESS") {
                return $1;
            }
        }
    }
    return 0;
}

#######
# Takes the build number and returns the svn revision number, parsed from the build directory revision.txt file.
#######
sub get_genome_svn_rev {
    my $build_number = shift;
    
    my $revision_txt_path = $BUILD_PATH . '/' . $build_number . '/revision.txt';

    open (revision_fh, $revision_txt_path);
    
    while (<revision_fh>) {
        if ( $_ =~ /Genome/ ) {
            $_ =~ /Genome\sr(\d+)/;
            return $1;
        }
    }
}

#######
# Takes the build number and returns the UR revision hash, parsed from the build directory revision.txt file.
#######
sub get_ur_git_hash {
    my $build_number = shift;

    my $revision_txt_path = $BUILD_PATH . '/' . $build_number . '/revision.txt';
    
    open (revision_fh, $revision_txt_path);

    while (<revision_fh>) {
        if ( $_ =~ /UR/ ) {
            $_ =~ /UR\s(.+)/;
            return $1;
        }
    }
}

# Begin actual script run. We will eventually provide command line options for versions.
# -b is for recent builds. -g is for genome rev. -u is for ur hash.

if ($#ARGV == -1) { # no args. print usage message.
    print "USAGE: perl deploy_script.pl [--deploy] [--live] AND [--recent] OR [--build] OR [--genome and --ur]\n";
    print "OPTIONS:\n";
    print "   --deploy        \tDeploy to /gsc/scripts/opt after local snapshot\n";
    print "   --live          \tDeploy to /gsc/script/lib/perl after local snapshot\n";
    print "\n\n";    
    print "   --recent        \tUse the most recent successful Hudson build.\n\n";
    print "\tOR\n\n";
    print "   --build   {number}\tUse Genome and UR versions used in build number {number}.\n\n";
    print "\tOR\n\n";
    print "   --genome  {hash}\tUse genome from Git hash (hash).\n";
    print "   --ur      {hash}\tUse UR from Git hash (hash).\n";
    print "   --workflow {hash}\tUse workflow from Git hash (hash).\n";
    exit;
}
my ($genome_hash, $ur_hash, $workflow_hash, $new_build_number, $recent, $deploy, $live);

GetOptions (
    "recent" => \$recent,
    "deploy" => \$deploy,
    "live" => \$live,
    "build=i" => \$new_build_number,
    "genome=s" => \$genome_hash,
    "ur=s" => \$ur_hash,
    "workflow=s" => \$workflow_hash
);

if ( defined $genome_hash and defined $ur_hash and defined $workflow_hash ) {
    print "Genome and UR revisions declared. Snapshotting from these:\n";
    print "Genome hash: " . $genome_hash . "\n";
    print "UR hash: " . $ur_hash . "\n";
    print "Workflow hash: " . $workflow_hash . "\n";
} else {
    if ( defined $recent ) {
        $new_build_number = check_for_new_build;

        unless ( $new_build_number != 0 and defined $new_build_number ) {
            die "No passing recent build found.";
        }

        print "Recent build found: #" . $new_build_number . "\n";

    } elsif ( defined $new_build_number ) {
        print "Build number specified: " . $new_build_number . "\n";
    } else {
        die "You must either specify a build number, use the --recent flag, or provide genome and ur rev #s.";
    }

    $genome_hash = get_genome_svn_rev($new_build_number);

    print "Genome hash" . $genome_hash . "\n";

    $ur_hash = get_ur_git_hash($new_build_number);

    print "UR Hash: " . $ur_hash . "\n";

    $workflow_hash = get_workflow_hash($new_build_number);
}

unless (defined $genome_hash && $genome_hash ne '' && defined $ur_hash && $ur_hash ne '' && defined $workflow_hash && $workflow_hash ne '')
{
    die "Some needed variable is not set.\n";
}

my $snapshot_path = "$SNAPSHOT_PATH/genome-testing";
my $working_path = "$SNAPSHOT_PATH/working-testing";

if (-e ($snapshot_path) ) { die "Snapshot dir exists at $snapshot_path\n"; }

`mkdir $snapshot_path`;
`mkdir $working_path`;

# get perl_modules folders
#my @ns;
#@ns = (qw/Workflow MGAP PAP Genome BAP Bio GAP/);
#for my $ns (@ns) {
#    print "Beginning work on namespace $ns\n";
#    `svn export -r $svn_rev $GSCPAN/perl_modules/trunk/$ns $snapshot_path/lib/perl/$ns`;
#    my $svn_cat_value = `svn cat -r $svn_rev $GSCPAN/perl_modules/trunk/$ns.pm`;
#    # TODO: add check that the svn catted file actually exists.
#    `svn cat -r $svn_rev $GSCPAN/perl_modules/trunk/$ns.pm > $snapshot_path/lib/perl/$ns.pm`;
#}
#@ns = ();
# Get UR folders
#for my $ns (@ns) {
#    print "Beginning work on namespace $ns\n";
#    `cd ~/UR/; git archive $ur_rev lib/$ns lib/$ns.pm | tar -x -C $working_path/`;
#    `mv $working_path/lib/$ns $working_path/lib/$ns.pm $snapshot_path/lib/perl/`;
#}
# first we're going to clone all the stuff we want into our working path.

`mkdir $snapshot_path/lib; mkdir $snapshot_path/lib/perl`;
my @ns;
##
# Do UR work
##
`cd $working_path; git clone $UR_REPOSITORY UR`;
@ns = (qw/Command UR/);
for my $ns (@ns) {
    print "Beginning work on namespace $ns\n";
    `cd $working_path/UR/lib; git archive $ur_hash $ns | tar -x -C $snapshot_path/lib/perl`;
    `cd $working_path/UR/lib; git archive $ur_hash $ns.pm | tar -x -C $snapshot_path/lib/perl`;
}
# cleanup after UR related stuff
`rm $working_path/UR -rf`;

##
# Do workflow work
##

`cd $working_path; git clone $WORKFLOW_REPOSITORY workflow`;
@ns = (qw/Workflow/);
for my $ns (@ns) {
    print "Beginning work on namespace $ns\n";
    `cd $working_path/workflow/lib; git archive $workflow_hash $ns.pm | tar -x -C $snapshot_path/lib/perl`;
    `cd $working_path/workflow/lib; git archive $workflow_hash $ns.pm | tar -x -C $snapshot_path/lib/perl`;
}
`rm $working_path/workflow -rf`;

##
# Do genome work
##
`cd $working_path; git clone $GENOME_REPOSITORY genome`;
@ns = (qw/BAP Bio EGAP GAP Genome MGAP PAP/);
for my $ns (@ns) {
    print "Beginning work on namespace $ns\n";
    `cd $working_path/genome/lib/perl; git archive $genome_hash $ns | tar -x -C $snapshot_path/lib/perl`;
    `cd $working_path/genome/lib/perl; git archive $genome_hash $ns.pm | tar -x -C $snapshot_path/lib/perl`;
}
`rm $working_path/genome -rf`;

# move UR tests into place
#`cd ~/UR/; git archive $ur_rev t | tar -x -C $working_path/`;
#`mv $working_path/t $snapshot_path/lib/perl/UR/`;

# working_path directory no longer needed.
print "Removing $working_path\n";

`rmdir $working_path`;

# restore sqlite dump files
my @dump_files = `find $snapshot_path -iname *sqlite3-dump`;
for my $sqlite_dump (@dump_files) {
    my $sqlite_db = $sqlite_dump;
    chomp $sqlite_db;
    $sqlite_db =~ s/-dump//;
    if (-e $sqlite_db) {
        warn "SQlite database $sqlite_db already exists.";
    } else {
        `sqlite3 $sqlite_db < $sqlite_dump`;
    }
    unless (-e $sqlite_db) {
        die "Failed to reconstitute $sqlite_dump as $sqlite_db!";
    }
}

print "Finished copying to local machine. Snapshot available at ";

#`cd $snapshot_path/lib/perl/UR; ur test use;`; # run tests which will generate the proper sqlite databases

# TODO Move UR /t/ dir and run tests properly to generate databases. (not needed anymore?)
# TODO also chmod +x /gsc/scripts/lib/perl/Genome/Model/Command/Services/WebApp/Main.psgi

if ( defined $deploy ) {
    `scp -pqr $snapshot_path linus1:/gsc/scripts/opt/genome-$genome_hash-testing`; # deploy to /gsc/scripts/opt if used the --deploy flag
    print "Finished copying to remote server. Snapshot available at /gsc/scripts/opt/genome-$genome_hash-testing\n";
}