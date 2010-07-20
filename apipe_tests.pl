#!/gsc/bin/perl

BEGIN {
    die "Please provide the snapshot path as the first arg. i.e. genome-#####/lib/perl" unless ($#ARGV == 0);
    unshift (@INC, $ARGV[0]);
}

use warnings;
use strict;
use Genome;

my $LOOP_SLEEP_MINS = 1;
my $TIMEOUT_HOURS = 30;

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

my $start_msg_body = "This is an initial notification. You will receive the results within 30 hours.\n";
$start_msg_body .= "Running tests on libraries at: " . $ARGV[0] . "\n";
$start_msg_body .= "Build ids started are:\n";
foreach my $build_id (@build_ids) {
    $start_msg_body .= $build_id . ": https://imp.gsc.wustl.edu/view/Genome/Model/Build/status.html?id=" . $build_id . "\n" ;
}

my $start_msg = MIME::Lite->new(From => sprintf('Model Build Test Runner <%s@genome.wustl.edu>', $ENV{'USER'}),
                                To => sprintf('%s@genome.wustl.edu', $ENV{'USER'}),
                                Subject => 'Build Tests Started',
                                Data => $start_msg_body,
               );
$start_msg->send();

my ($build, $event, $success, $failure, $other);
while (1) {
    ($success, $failure, $other) = (0,0,0);
    foreach my $build_id (@build_ids) {
        $build = UR::Context->current->reload("Genome::Model::Build", id=>$build_id);
        $event = UR::Context->current->reload("Genome::Model::Event", id=>$build_master_events{$build_id});
        #print "$build_id status is " . $event->event_status . "\n";
        if ($event->event_status =~ /Failed/) {
            $failure += 1;
        } elsif ($event->event_status =~ /Succeeded/) {
            $success += 1;
        } else {
            $other += 1;
        }
    }
    #print "Success: $success, Failure: $failure, Other: $other\n";
    if ($failure == 0 and $other == 0) { #success
        my $success_msg_body = "Success! all models build successfully";
        my $success_msg = MIME::Lite->new(From => sprintf('Model Build Test Runner <%s@genome.wustl.edu>', $ENV{'USER'}),
                                          To => sprintf('%s@genome.wustl.edu', $ENV{'USER'}),
                                          Subject => 'Build Tests Passed',
                                          Data => $success_msg_body,               
                          );
        $success_msg->send();
        exit 0;
    } elsif ($failure > 0) { # at least one build failed
        my $failure_msg_body = "Failure :(";
        my $failure_msg = MIME::Lite->new(From => sprintf('Model Build Test Runner <%s@genome.wustl.edu>', $ENV{'USER'}),
                                          To => sprintf('%s@genome.wustl.edu', $ENV{'USER'}),
                                          Subject => 'Build Tests Failed',
                                          Data => $failure_msg_body,
                          );
        $failure_msg->send();
        exit 1;
    }
    #print "\n\n";
    sleep 60*$LOOP_SLEEP_MINS;
}
