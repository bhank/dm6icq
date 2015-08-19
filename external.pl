#!perl -w

use strict;
use Digest::MD5 qw(md5_hex);
#use Games::Quakeworld::Query;
use Games::Quakeworld::QueryTest;
use Socket;

my $message;

{
        undef $/;
        $message = <STDIN>;
}

my $protocol = $ENV{'EVENT_NETWORK'};
my $id = $protocol eq 'icq' ? $ENV{'CONTACT_UIN'} : $ENV{'CONTACT_NICK'};

my $filename = md5_hex($protocol . $id);

my $dm6server = 'dm6.org';
my $cicqpath = 'c:/temp/cicq';
my $basepath = "$cicqpath/.dm6";
my $listpath = "$basepath/list";
my $listfile = $listpath . '/' . $filename;
my $notifypath = "$basepath/notified";
my $notifyfile = $notifypath . '/' . $filename;
my $playersfile = "$basepath/playercount.txt";

########

sub addtolist
{
        my $threshold = shift;

	$threshold = 1 if $threshold < 1;

        open(OUT,">$listfile") or die("Couldn't write to $listfile: $!");
        print OUT "$protocol\n";
        print OUT "$id\n";
        print OUT "$threshold";
        close OUT;

	my $contactdir;
	if($protocol eq 'icq')
	{
		$contactdir = $id;
	} elsif($protocol eq 'msn') {
		$contactdir = 'm' . $id;
	}
	mkdir "$cicqpath/$contactdir", 0700; # mkdir so the new contact will be picked up on restart, hopefully.

        #print "Added $protocol $id with threshold $threshold!";
	print "OK, I will let you know when $threshold or more players are on DM6.";
	# check players.txt... "actually, there are 3 on there now!"
	open(IN, "<$playersfile") or die("Couldn't read $playersfile: $!");
	my $playercount = <IN>;
	close IN;
	if($playercount > $threshold)
	{
		print "\nAs a matter of fact, there are $playercount players on now!";
		# touch notifyfile so they will get the game over notification
		open(OUT, ">$notifyfile") or die("Couldn't write $notifyfile: $!");
		print OUT "";
		close OUT;
	}
}

sub removefromlist
{
        unlink($listfile);
        #print "Removed you from the list.";
	print "OK, I will not bother you.";
	# get rid of any pending 'game over' notify
	unlink($notifyfile);
}

sub rcon
{
	my $command = shift;

	my($srcip, $srcport) = (inet_aton('0.0.0.0'), 0);
	my($dstip, $dstport) = (scalar(gethostbyname('wonko.gamespy.com')), 27500);
	my $proto = getprotobyname('udp');
	my $rconpassword = '1337';
	my $rconcommand = "rcon $rconpassword $command";
	my $udpmessage = ("\xff" x 4) . $rconcommand . "\x0a";

	socket(SOCKET, PF_INET, SOCK_DGRAM, $proto) || die "socket: $!";
	bind(SOCKET, pack_sockaddr_in($srcport, $srcip)) || die "bind: $!";
	send(SOCKET, $udpmessage, 0, pack_sockaddr_in($dstport, $dstip)) || die "send: $!";
}

########

my $timeout = 15; # seconds to let this run
$SIG{'ALRM'} = sub {
	print "Command timed out!";
        die "Alarm timeout after $timeout seconds";
};
alarm($timeout);

if($message =~ /^say (.*)$/)
{
	my $saymessage = "[$ENV{'CONTACT_NICK'}] $1";
	rcon("say $saymessage");
	print "Said '$saymessage' on the server.";
} elsif ($message =~ /(no|stop|remove|delete|unsub|quit|don't)/i) {
	removefromlist();
} elsif($message =~ /(add|start)/i) {
        my $threshold;
        if($message =~ /(\d{1,2})/) # limit to two digits to ignore huge numbers
        {
                $threshold = $1;
        } else {
                $threshold = 1;
        }
        addtolist($threshold);
} elsif ($message =~ /(status|settings)/i) {
	Games::Quakeworld::Query->new($dm6server)->dumpinfo;
	print "\nPlayers: " . Games::Quakeworld::Query->new($dm6server)->players ."\n";
} elsif ($message =~ /(who|current|play|online)/i) {
	print "Players currently online:\n";
	for (@{Games::Quakeworld::Query->new($dm6server)->{players}})
	{
		print $_->{"printablename"} . "\n";
	}
} elsif ($message =~ /(what|how|help|\?)/i) {
	print "You can ask me to add or remove you from my list of people to notify when there are players on DM6 (optionally specifying a number of players if you don't want to be bothered if there are less than that many), or you can ask me for the status of dm6's settings or who is currently playing. Or you can 'say something' to send a message to players on the server.";
} else {
	exit(0); # log it
}

exit(1); # don't log all this junk in centericq, I guess

