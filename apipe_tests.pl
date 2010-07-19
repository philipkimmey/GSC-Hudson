#!/gsc/bin/perl

BEGIN {
    die "Please provide the snapshot path as the first arg. i.e. genome-#####/lib/perl" unless ($#ARGV == 0);
    unshift (@INC, $ARGV[0]);
}

use warnings;
use strict;
use Genome;

my @model_ids = ("2857581024", "2859885434");
my @build_ids = ();

foreach my $model_id (@model_ids) {
    my $command = Genome::Model::Build::Command::Start->create(
        model_identifier => $model_id,
        force => 1,
    );
    $command->execute;
    UR::Context->commit;
    push(@build_ids, $command->build->build_id);
}

my %build_master_events = ();
foreach my $build_id (@build_ids) {
    my $build_object = Genome::Model::Build->get(id=>$build_id);
    $build_master_events{$build_id} = $build_object->the_master_event->id;
}

my ($build, $event);
while (1) {
    foreach my $build_id (@build_ids) {
        $build = UR::Context->current->reload("Genome::Model::Build", id=>$build_id);
        $event = UR::Context->current->reload("Genome::Model::Event", id=>$build_master_events{$build_id});
        print "$build_id status is " . $event->event_status . "\n";
    }
    print "\n\n";
    sleep 20;
}
