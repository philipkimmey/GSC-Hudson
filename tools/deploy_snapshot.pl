

use Genome;

my $id = $ARGV[0] || die 'first argument should be hudson build that passed unit tests';

my $deploy_path = Genome::Config->deploy_path();
my $last_deploy_path = join('/', $deploy_path, 'last_genome_deploy');
my $snapshot_path = snapshot_path($id) || die "cant find snapshot for hudson build $id";
print "+ deploying from $snapshot_path to $deploy_path\n";

deploy_snapshot($id);

exit;




sub deploy_snapshot {

    my ($id) = @_;

    my $lock_name = 'deploy_snapshot';
    my $lock = Genome::Utility::FileSystem->lock_resource(
        resource_lock => $lock_name,
        max_try       => 0
    );
    die "cant deploy- lock file exists for $lock_name" if ! $lock;
    print "+ got the $lock_name lock\n";

    my @ns = Genome::Config->namespaces();
    my @files_and_dirs = files_and_dirs(@ns);

    copy_to_deploy_path(@files_and_dirs);

    rename_from_temp_names(@files_and_dirs);

    Genome::Utility::FileSystem->unlock_resource(resource_lock=>$lock);
    print "+ released the the $lock_name lock\n";
}

sub files_and_dirs {

    my (@ns) = @_;
    my @f;

    for my $ns (@ns) {
        push @f, $ns;
        push @f, "$ns.pm";
    }

    return @f;
}


sub from_and_to_pathnames {

    my ($ns) = @_;

    my $from = join('/', $snapshot_path, 'lib', 'perl', $ns);
    my $to = join('/', $deploy_path, $ns);

    return ($from, $to);
}

sub copy_to_deploy_path {

    my (@ns) = @_;

    for my $ns (@ns) {

        my ($from, $to) = from_and_to_pathnames($ns);
        $to .= '.tmp';     #  copying to .tmp to limit time spent in weird state

        my $cmd = "cp -r $from $to";
        print "+ $cmd\n";
        my $r = system($cmd);
        die "cp failed!" if $r;
    } 

    return 1;
}

sub rename_from_temp_names {

    my (@ns) = @_;

    # moves current files to Namespace.old and
    # moves new files from Namespace.tmp to Namespace
   
    for my $ns (@ns) {

        my ($from, $to) = from_and_to_pathnames($ns);

        my $cmd1 = "mv $to $last_deploy_path";
        print "+ $cmd1\n";
        my $r1 = system($cmd1); 
        die "failed to mv file to $last_deploy_path" if $r1;

        my $cmd2 = "mv $to.tmp $to";
        print "+ $cmd2\n";
        my $r2 = system($cmd2); 
        die "Shit! move failed! (old namespace files end with .old)" if $r2;

    } 

    return 1;
}

sub snapshot_path {
    
    my ($id) = @_;

    my @snapshot_paths = Genome::Config->snapshot_paths();
    my $subdir = snapshot_subdir($id);

    # checks models that've passed model tests, then unit tests only
    for my $snapshot_path (@snapshot_paths) {
        my $full_path = join('/', $snapshot_path, $subdir);
        if (-d $full_path) {
            return $full_path;
        }
    }
  
    my $paths = join("\n\t", @snapshot_paths); 
    die "Error: Couldnt find snapshot path for hudson build $id in:\n\t$paths\n"; 
}

sub snapshot_subdir {

    my ($id) = @_;

    return join ('-', 'genome', $id);
}



