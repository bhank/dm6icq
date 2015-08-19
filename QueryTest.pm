#!/usr/bin/perl -w

# Quakeworld Server Query 0.0.1 
#
# A simple class for querying quakeworld servers.
# Quite simple to use; see the perlpod documentation for more info.

# Copyright (c) 2003 Antoine Kalmbach. All rights reserved.
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
# (Licensed under the Perl Artistic License, if you didn't get it)

package Games::Quakeworld::Query;

require 5.001;

use strict;
use IO::Socket;

use vars qw($VERSION);

$VERSION = "0.35";

# Here's the different values for the server. These should be quite up to date, but who knows
# if the server software changes.

our @vars = qw(teamplay map maxclients hostname admin spawn maxvip_spectators *version
              *qwe_version watervis samelevel deathmatch url *gamedir timelimit maxspectators *progs);

# Command to be sent to the server
my $cmd = "\377\377\377\377status\x00";

# Game maps. Use if you want cool map names :)
my %maps = ( start => "Introduction",
    e1m1 => "The Slipgate Complex",
    e1m2 => "Castle of the Damned",
    e1m3 => "The Necropolis",
    e1m4 => "The Grisly Grotto",
    e1m5 => "Gloom Keep",
    e1m6 => "The Door to Chthon",
    cthon => "The House of Chthon", # boss of episode one
    e2m1 => "The Installation",
    e2m2 => "The Ogre Citadel",
    e2m3 => "Crypt of Decacy",
    e2m4 => "The Ebon Fortress",
    e2m5 => "The Wizard's Manse",
    e2m6 => "The Dismal Oubliette",
    e3m1 => "Termination Central",
    e3m2 => "The Vaults of Zin",
    e3m3 => "The Tomb of Terror",
    e3m4 => "Satan's Dark Delight",
    e3m5 => "Wind tunnels",
    e3m6 => "Chambers of Torment",
    e4m1 => "The Sewage System",
    e4m2 => "The Tower of Despair",
    e4m3 => "The Elder God's Shrine",
    e4m4 => "The Palace of Hate",
    e4m5 => "Hell's Atrium",
    e4m6 => "The Pain Maze",
    e4m7 => "Azure Agony",
    end => "Shub-Niggurath's Pit", # the final boss
    # Some deathmatch maps
    dm1 => "The Place of Two Deaths",
    dm2 => "Claustrophobopolis",
    dm3 => "The Abandoned Place",
    dm4 => "The Bad Place", # my favourite :)
    dm5 => "The Cistern",
    dm6 => "The Dark Zone",
    ztndm1 => "Smile, it gets worse",
    ztndm2 => "Show No Mercy",
    ztndm3 => "Blood Run", 
    ztndm4 => "The Steeler",
    ztndm5 => "Painkiller",
    ztndm6 => "The Vomitorium",
    endif => "#endif",
);

# shirt and pants colors, from http://www.gamers.org/pub/archives/quake/periodic/qfaq-p3
my @colors = (
	"",
    "White",
    "Brown",
    "Sky Blue",
    "Olive Green",
    "Red",
    "Gold",
    "Salmon",
    "Lavender",
    "Purple",
    "Tan",
    "Forest Green",
    "Yellow",
    "Blue",
);

# mappings from "fun names" to printable characters
my @sys_char_map = (
    "\0", '#', '#', '#', '#', '.', '#', '#',
    '#', chr(9), chr(10), '#', ' ', chr(13), '.', '.',
    '[', ']', '0', '1', '2', '3', '4', '5',
    '6', '7', '8', '9', '.', '<', '=', '>',
    ' ', '!', '"', '#', '$', '%', '&', "'",
    '(', ')', '*', '+', ',', '-', '.', '/',
    '0', '1', '2', '3', '4', '5', '6', '7',
    '8', '9', ':', ';', '<', '=', '>', '?',
    '@', 'A', 'B', 'C', 'D', 'E', 'F', 'G',
    'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O',
    'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W',
    'X', 'Y', 'Z', '[', '\\', ']', '^', '_',
    '`', 'a', 'b', 'c', 'd', 'e', 'f', 'g',
    'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o',
    'p', 'q', 'r', 's', 't', 'u', 'v', 'w',
    'x', 'y', 'z', '{', '|', '}', '~', '<',

    '<', '=', '>', '#', '#', '.', '#', '#',
    '#', '#', ' ', '#', ' ', '>', '.', '.',
    '[', ']', '0', '1', '2', '3', '4', '5',
    '6', '7', '8', '9', '.', '<', '=', '>',
    ' ', '!', '"', '#', '$', '%', '&', "'",
    '(', ')', '*', '+', ',', '-', '.', '/',
    '0', '1', '2', '3', '4', '5', '6', '7',
    '8', '9', ':', ';', '<', '=', '>', '?',
    '@', 'A', 'B', 'C', 'D', 'E', 'F', 'G',
    'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O',
    'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W',
    'X', 'Y', 'Z', '[', '\\', ']', '^', '_',
    '`', 'a', 'b', 'c', 'd', 'e', 'f', 'g',
    'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o',
    'p', 'q', 'r', 's', 't', 'u', 'v', 'w',
    'x', 'y', 'z', '{', '|', '}', '~', '<'
);

######################################################################## CONSTRUCTOR #####
# Returns a hash with the server info. 
# Somekind of a usage: my $QWS = ...->new(...); %info = $QWS->getinfo(); print %info{map}.
# Look for the values in the list above.

sub new { 
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    $self->{server} = shift;
    $self->{port} = shift || 27500;
    $self->{info} = {};
    $self->{players} = undef;
	$self->{failed} = undef;
    bless $self, $class;
    $self->_init($self->{server}, $self->{port});
	if ($self->{failed}) {
		return undef;
	}
    return $self;
}


# Looks up the server and puts the values in the hash info.
sub _init {
    my $self = shift;
    my $server = shift;
    my $port = shift;

    my ($buffer, $recvd, $players, $info, @data, $key);

    # Create the socket
    my $sock = IO::Socket::INET->new(Proto => "udp", 
                                     PeerAddr => $server, 
                                     PeerPort => $port, 
									 Timeout => 5,) 
     or $self->{failed} = 1;
   
	# oops!
	return undef if $self->{failed};

	$sock->autoflush(1);

    # send some stuff
    $sock->syswrite($cmd, length($cmd)) or $self->{failed} = 1;
    $recvd = $sock->sysread($buffer, 9000) or $self->{failed} = 1;
    $buffer =~ s/\337//g; # strip the weird charachters

	
    my ($sinfo, @playerdata) = split("\n", $buffer); # from \n starts the players.
    @data = split("\\\\", $sinfo); # \\ is the delimiter
    shift(@data); # shift some crap from the beginning

	@{$self->{players}} = ();
    #pop(@playerdata); # throw away the last line, which is junk. But it's not junk in the new quakeforge version!
    for (@playerdata)
    {
    	if(/^(\d+) (\d+) (\d+) (\d+) "(.*?)" "(.*?)" (\d+) (\d+)$/)
    	{
    		push @{$self->{players}}, {
    			"userid" => $1,
    			"frags" => $2,
    			"time" => $3,
    			"ping" => $4,
    			"name" => $5,
    			"printablename" => unfunname($5),
    			"skin" => $6,
    			"shirt" => $7,
    			"pants" => $8
    		};
    	}
    }

    # set up the info
	$key = 0;
    foreach my $value (@data) {
        foreach my $param (@vars) {
            if ($value eq $param) {
                $self->{info}{$param} = $data[$key+1]; 
            }
        }
        $key++;
    }
}

# Returns the info, in a hash. OBSOLETED!
sub getinfo { 
	my $self = shift;
	if (defined($self->{info})) {
		return $self->{info};
	}
	else { 
		return undef;
	}
}
 

# Just print the values
sub dumpinfo {
    my $self = shift;
    while (my ($p, $v) = each(%{$self->{info}})) {
        print $p." => ".$v."\n";
    }
}

# Returns %info{shift}
sub get {
	my $self = shift;
	my $what = shift;
	return $self->{info}{$what};
}

# Returns the long name of a map
sub map_long {
    my $self = shift;
	return undef if !defined($self->{info}{map});
    foreach my $map (keys %maps) {
        if ($map eq $self->{info}{map}) {
            return $maps{$map};
        }
    }
    return undef;
}

# Returns the name of a color
sub color_name {
	my $self = shift;
	my $color = shift;
	
	return $colors[$color];
}	

sub players { 
    my $self = shift;
    
    if(wantarray)
    {
    	return @{$self->{players}};
    } else {
    	return scalar @{$self->{players}};
    }
}

sub unfunname {
	my $name = shift;
	$name =~ s/(.)/$sys_char_map[ord($1)]/ge;
	return $name;
}

__END__

=head1 NAME

Games::Quakeworld::Query - A class for querying QuakeWorld servers

=head1 SYNOPSIS

    use Games::Quakeworld::Query;

    my $QWQ = Games::Quakeworld::Query->new("quake.server.com", "27500");
    my %info = $QWQ->getinfo(); # obsoleted, use $qwq->get("") instead
    print "Server uses map: ".$qwq->get("map")."\n";

=head1 DESCRIPTION

Hello, this is Games::Quakeworld::Query, a perl module.
It is a class made for querying Quakeworld (Quake 1) game servers
and getting their informations, that is map name, players, hostname and etc.

=head1 OVERVIEW

This module is made for querying Quakeworld servers. With this package you can
easily query Quakeworld servers and get their information. This might come
in hand if you are a Quake 1 player and i.e. like to use this in a CGI
application and check the server with it before you go there.

I wrote this because I needed it; I am planning to implement it in a IRC bot
and later write a nice CGI script for it. At the moment I use it in a IRC bot,
powered by Net::IRC ;).

=head1 CONSTRUCTOR

=item new (HOST [, PORT])

Instances a query to B<HOST> at the port B<PORT>. If B<PORT> is omitted,
the default port 27500 is used. If it succeeds, it returns $self, or in a 
case of error it returns undef.

=head1 METHODS

Here are the module methods in an alphabetical order.

=item dumpinfo

Loops trough the server info and prints out something like "var = value".

=item getinfo

B<OBSOLETED - use get("var") instead!>
Returns a hash containing the server information, i.e. %hash = ...->getinfo();
print %hash{map}. See the beginning of the source of this module to see the 
available informations.

=item get (SOMETHING)

Returns B<SOMETHING> from the server info. That is, $map = get("map");
Returns undef in case of failure.

=item map_long

Returns a long name of the current map. See the %maps hash in the beginning of
the source of this module. 

=item players

Returns an array containing a hash for each player on the server. The hash keys
are: userid, frags, time, ping, name, printablename, skin, shirt, pants.

=item color_name (COLORNUMBER)

Returns the name of the shirt or pants color number B<COLORNUMBER>.

=item unfunname (NAME)

Returns a printable version of a "fun name".

=head1 TODO

Player search and a class for it, and lots of more.
This is just the beginning of the end :)

=head1 BUGS

If you report any bugs in my code, please e-mail me.

=head1 AUTHORS

Antoine Kalmbach <anzu@mbnet.fi>

=head1 COPYRIGHT

Copyright (c) 2003 Antoine Kalmbach. All rights reserved.
This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.



