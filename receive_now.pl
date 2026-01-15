#!/usr/bin/perl
use strict;
use warnings;
use Socket;
use Getopt::Long;
use IO::Handle;

# --- CONFIG & ARGUMENTS ---
my $interface = "wlp2s0mon";
my $human     = 0;
my $verbose   = 0;
my $file      = "";
my $plain_xxd = 0;

GetOptions(
    'interface|i=s' => \$interface,
    'human|h'       => \$human,
    'verbose|v'     => \$verbose,
    'file|f=s'      => \$file,
    'plain|p'       => \$plain_xxd,
) or die "Usage: $0 [-i interface] [-h] [-v] [-p] [-f filename]\n";

# Open file if specified
my $fh;
if ($file) {
    open($fh, '>>', $file) or die "Could not open file $file: $!";
    $fh->autoflush(1);
}

# 1. Setup Raw Socket (0x0003 for x86)
socket(my $sock, 17, 2, 0x0003) or die "Socket error: $!";
my $ifr = pack('a16 x16', $interface);
ioctl($sock, 0x8933, $ifr) or die "Interface error: $!";
my $if_index = unpack('x16 i', $ifr);
bind($sock, pack('S n i x12', 17, 0x0003, $if_index)) or die "Bind error: $!";

print STDERR "[*] Listening on $interface...\n";

while (1) {
    my $packet;
    recv($sock, $packet, 4096, 0) or next;
    
    # Search for Espressif OUI (7f 18 fe 34)
    my $pos = index($packet, pack("H*", "7f18fe34"));
    if ($pos != -1) {
        my $len_byte = unpack("C", substr($packet, $pos + 9, 1));
        my $data_len = $len_byte - 5;
        my $payload  = substr($packet, $pos + 15, $data_len);

        # 1. Handle Binary Logging (-f)
        if ($fh) {
            syswrite($fh, $payload);
        }

        # 2. Build Output String
        my $output = "";

        # Add Timestamp if Verbose (-v)
        if ($verbose) {
            my ($s,$m,$h) = localtime();
            $output .= sprintf("[%02d:%02d:%02d] ", $h, $m, $s);
        }

        if ($plain_xxd) {
            # Plain hexdump like xxd (-p)
            $output .= unpack("H*", $payload);
        }
        elsif ($human) {
            # Human readable string (-h)
            $output .= $payload;
        }
        else {
            # Default: Hex chars (0x42 0x63...)
            $output .= join(" ", map { sprintf("0x%02x", $_) } unpack("C*", $payload));
        }

        print $output . "\n";
    }
}
