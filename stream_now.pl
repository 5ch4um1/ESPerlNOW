#!/usr/bin/perl
use strict;
use warnings;
use Socket;
use Getopt::Long;
use IO::Handle; # Required for autoflush

# --- CONFIG & DEFAULTS ---
my $interface   = "wlp2s0mon"; 
my $packetsize_arg  = 10;
my $use_stdin   = 0;

GetOptions(
    'stdin'       => \$use_stdin,
    'packet_size|p=i'  => \$packetsize_arg,
) or die "Usage: $0 [--stdin] [-p packet_size]\n";

# Disable buffering for real-time streaming
STDOUT->autoflush(1);
STDIN->autoflush(1);


# 1. Setup Raw Socket
socket(my $sock, 17, 3, 0x0300) or die "Socket error: $!";
my $ifr = pack('a16 x16', $interface);
ioctl($sock, 0x8933, $ifr) or die "Interface $interface not found: $!";
my $if_index = unpack('x16 i', $ifr);
my $sockaddr = pack('S n i x12', 17, 0x0300, $if_index);
bind($sock, $sockaddr) or die "Bind error: $!";

print "[*] Interface: $interface\n";
print "[*] Mode:      " . ($use_stdin ? "STREAMING (STDIN)" : "SINGLE SHOT") . "\n";


# 2. Static Headers
my $target_mac = pack("H*", "ffffffffffff");
my $source_mac = pack("H*", "aabbccddeeff");
my $radiotap   = pack("H*", "00000c000480000002001800");
my $dot11_hdr  = pack("H*", "d0000000") . $target_mac . $source_mac . $target_mac . pack("H*", "0000");

# 3. Sending Loop
while (1) {
    my $payload = "";

    if ($use_stdin) {
        # read number of bytes defined by "-p packet_size"
        my $bytes_read = sysread(STDIN, $payload, $packetsize_arg);
        
        last if !defined($bytes_read) || $bytes_read == 0;
        
        # Pad if we got a partial read
        if ($bytes_read < $packetsize_arg) {
            $payload .= chr(0x00) x ($packetsize_arg - $bytes_read);
        }
    } else {
        for (1..$packetsize_arg) {
            $payload .= chr(0xAA) . chr(0xBB) . chr(0xCC);
        }
    }


    # 4. Construct the ESP-NOW "Envelope"
    my $action_header    = pack("H*", "7f18fe34");
    my $random_bytes     = pack("C*", int(rand(255)), int(rand(255)), int(rand(255)), int(rand(255)));
    my $element_id       = pack("H*", "DD");
    my $element_len      = pack("C", 5 + length($payload)); 
    my $esp_header_inner = pack("H*", "18fe340401");

    my $esp_now_data = $action_header . $random_bytes . $element_id . $element_len . $esp_header_inner . $payload;
    my $packet = $radiotap . $dot11_hdr . $esp_now_data;

    send($sock, $packet, 0);
    
    # Optional: Visual feedback so you know it's looping
    # print "."; 

    last unless $use_stdin;
}
