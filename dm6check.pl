#!/usr/bin/perl -w

# In order to send to people, they need to be on the contact list.
# I can't add them without restarting centericq.
# However, they will be on the contact list temporarily after sending their add message.
# So I'll just mkdir to add them then, and it will be picked up on restart.
# Plus they would still be there on restart if I didn't read their messages manually.
# 20040213 last mod
# 20040716 disabling msn sorta
# 20040928 reenabling msn onlineage after upgrading centericq
# 20041109 investigating "Use of uninitialized value in numeric gt (>)" on 72 ... it's sometimes writing out a blank file! Disk was full... checking close's return value caught it.
# 20050104 changing to use my modified QueryTest module to be consistent with the other script. Plus the new quakeforge server version is returning -1 for players with the original module. We'll have to see if it's correct when there actually are players on...
# 20050107 old queued messages are now deleted, so they don't show up later
# 20050124 having turboing problems with icq... disabled auto-online thing
# 20050409 porting to windows... adding cicq path... alarm doesn't work... removing find which doesn't work anyway

use Digest::MD5 qw(md5_hex);
use Games::Quakeworld::QueryTest;

my $dm6server = 'dm6.org';
my $cicqpath = 'c:/docume~1/adam/cicq';
my $cicqbin = "$cicqpath/centericq.exe";
my $basepath = "$cicqpath/.dm6";
my $listpath = "$basepath/list";
my $notifypath = "$basepath/notified";
my $playersfile = "$basepath/playercount.txt";

my ($oldplayers, $newplayers);

sub sendmessage
{
	my($protocol, $id, $message) = @_;
	open(CI, "|$cicqbin -b $cicqpath -s msg -p $protocol -t $id") or die("Couldn't run centericq to send message: $!");
	print CI $message;
	close CI;
}

$timeout = 15; # seconds to let this run
$SIG{'ALRM'} = sub {
	die "Alarm timeout after $timeout seconds";
};
alarm($timeout); # alarm doesn't seem to interrupt network operations... I wonder if read instead of sysread would help

open(IN, "<$playersfile") or die("Couldn't open $playersfile: $!");
$oldplayers = <IN>;
close IN;

print "Got blank oldplayers\n" if $oldplayers eq '';

if($q = Games::Quakeworld::Query->new($dm6server))
{
	$newplayers = $q->players;
	die("Query for players got [$newplayers]") unless $newplayers =~ /^\d+$/;
} else {
	die "Failed to query dm6";
}

open(OUT, ">$playersfile") or die("Couldn't open $playersfile for write: $!");
print(OUT "$newplayers") or die("Couldn't write '$newplayers' to $playersfile: $!");
close(OUT) or die("Couldn't close $playersfile: $!");

die("Empty players file $playersfile (should contain '$newplayers')") if -s $playersfile == 0;

opendir(DIR, $listpath) or die("Can't open dir $listpath: $!");
my @files = grep { -f "$listpath/$_" } readdir(DIR);
closedir DIR;

# delete queued messages older than five minutes
# TODO: move the path into a variable
#my $cleaned = `find /home/dm6/.centericq/ -type f -depth 2 -name offline ! -mmin -5 -print -delete`;
#print "Cleaned up: $cleaned\n" if $cleaned;

# make sure we are online...
system("$cicqbin -b $cicqpath -S o -p msn");
# if you try too often, icq says you are "turboing"
system("$cicqbin -b $cicqpath -S o -p icq") if rand(30) > 29;

for $file (@files)
{
	my($protocol, $id, $threshold);
	open(IN, "<$listpath/$file") or die("Couldn't read $file: $!");
	chomp($protocol = <IN>);
	chomp($id = <IN>);
	chomp($threshold = <IN>);
	close IN;

	my $filename = md5_hex($protocol . $id);
	my $listfile = $listpath . '/' . $filename;
	my $notifyfile = $notifypath . '/' . $filename;

	if(($threshold > $oldplayers) and ($threshold <= $newplayers))
	{
		# send message
		#sendmessage($protocol, $id, "$newplayers player" . (($newplayers == 1) ? '' : 's') . " on DM6!\n(up from $oldplayers, passing your threshold of $threshold)");
		sendmessage($protocol, $id, "Game On!\n($oldplayers -> $newplayers, passing your threshold of $threshold)");
		open(OUT, ">$notifyfile") or die("Couldn't write $notifyfile: $!");
		print OUT "";
		close OUT;
	} elsif(($oldplayers > 0) and ($newplayers == 0)) {
		# send game-over message, even though people with high thresholds didn't get notified that there was a game going on at all... doh
		#sendmessage($protocol, $id, "Game Over on DM6.");
		# to be smarter, we will only notify people who got notifications of the game.
		unlink("$notifypath/$file") and sendmessage($protocol, $id, "Game Over.");
	}
}

