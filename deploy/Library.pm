
sub create_snapshot {
    my @options = @_;
    print $options=>genome . "\n";


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

#######
# Takes the build number and returns the svn revision number, parsed from the build directory revision.txt file.
#######
sub get_genome_svn_rev {
    my $build_number = shift;
    
    my $revision_txt_path = $Defaults::BUILD_PATH . '/' . $build_number . '/revision.txt';

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

    my $revision_txt_path = $Defaults::BUILD_PATH . '/' . $build_number . '/revision.txt';
    
    open (revision_fh, $revision_txt_path);

    while (<revision_fh>) {
        if ( $_ =~ /UR/ ) {
            $_ =~ /UR\s(.+)/;
            return $1;
        }
    }
}
1;
