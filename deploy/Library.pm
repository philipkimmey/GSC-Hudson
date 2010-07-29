package Library;

use UR;

sub snapshot_namespaces {
    my $recorded_hash;
    my $command;
    # create a nice path for working not likely to get blasted
    my $timestamp = UR::Time->now();
    $timestamp =~ s/\s/_/g;
    my $working_path = join('-', 'snapshot-working', $ENV{USER}, $timestamp);
    $working_path = '/tmp/' . $working_path;
    system "mkdir $working_path";
    my $snapshot_path = shift;
    if (-e $snapshot_path) { die "We don't want to destroy what you've got, so pass a non-existant target path."; }
    `mkdir $snapshot_path`;
    `mkdir $snapshot_path/lib`;
    `mkdir $snapshot_path/lib/perl`;
    my @repos = @_;
    my $recorded_hash;
    my $command;
    for my $repo (@repos) {
        $command = "cd $working_path; git clone " . $repo->{'repository_url'} . " " . $repo->{'repository_name'};
        `$command`;
        $command = "cd $working_path/" . $repo->{'repository_name'} . "; git show --pretty=oneline " . $repo->{'hash'} . " | tr -d '\n' | cut -d ' ' -f1";
        $recorded_hash = `$command`;
        chomp $recorded_hash; chomp $recorded_hash; chomp $recorded_hash;
        for my $ns ( @{ $repo->{'namespaces'} } ) {
            print "Beginning work on namespace $ns\n";
            $command = "cd $working_path/" . $repo->{'repository_name'} . "/" . $repo->{'library_path'} . "; git archive " . $repo->{'hash'} . " $ns | tar -x -C $snapshot_path/lib/perl";
            `$command`;
            $command = "cd $working_path/" . "/" . $repo->{'repository_name'} . "/" . $repo->{'library_path'} . "; git archive " . $repo->{'hash'} . " $ns.pm | tar -x -C $snapshot_path/lib/perl";
            `$command`;
        }
        # record hash in revisions.txt
        $command = 'echo "' . $repo->{'repository_name'} . ' ' . $recorded_hash . '" >> ' . $snapshot_path . "/revisions.txt";
        `$command`;
    }
    $command = "rm $working_path/ -rf";
    `$command`;
}

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

sub get_workflow_hash { return get_something_hash(shift, "workflow"); }

sub get_genome_hash { return get_something_hash(shift, "genome"); }

sub get_ur_hash { return get_something_hash(shift, "UR"); }

sub get_something_hash {
    my $build_number = shift;
    my $something_name = shift;
    my $revision_txt_path = $Defaults::BUILD_PATH . '/' . $build_number . '/revision.txt';
    open (revision_fh, $revision_txt_path);

    while (<revision_fh>) {
        if ( $_ =~ /$something_name/ ) {
            $_ =~ /$something_name\s(.+)/;
            return $1;
        }
    }
}
1;
