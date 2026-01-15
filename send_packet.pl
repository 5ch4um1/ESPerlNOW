#!/usr/bin/perl
use strict;
use warnings;
use Socket;

# --- CONFIG ---
my $interface = "wlp2s0mon"; 

# 1. Setup Raw Socket
socket(my $sock, 17, 3, 0x0300) or die "Socket error: $!";
my $ifr = pack('a16 x16', $interface);
ioctl($sock, 0x8933, $ifr) or die "Interface $interface not found: $!";
my $if_index = unpack('x16 i', $ifr);
my $sockaddr = pack('S n i x12', 17, 0x0300, $if_index);
bind($sock, $sockaddr) or die "Bind error: $!";

print "[*] Connected to $interface (Index: $if_index)\n";

# 2. 802.11 Headers (Standard Action Frame)
my $target_mac = pack("H*", "ffffffffffff"); # Broadcast target 
my $source_mac = pack("H*", "aabbccddeeff"); # Your fake sender MAC
my $bssid      = pack("H*", "ffffffffffff"); 

my $radiotap   = pack("H*", "00000c000480000002001800");

# Frame Control: 0xD0 (Action Frame), Duration: 0
my $dot11_hdr  = pack("H*", "d0000000") . $target_mac . $source_mac . $bssid . pack("H*", "0000");

# 3. Construct the Payload 
my $payload = chr(0x01) . chr(0x02) . chr(0x03) . chr(0xa5) x 22;

# 4. Construct the ESP-NOW Specific Wrapper (The "Python Fix")
# Part A: Category (7F) + OUI (18 FE 34)
my $action_header = pack("H*", "7f18fe34");

# Part B: 4 Random Bytes 
my $random_bytes = pack("C*", int(rand(255)), int(rand(255)), int(rand(255)), int(rand(255)));

# Part C: Vendor Element Wrapper
# ID: 0xDD
# Len: 5 (for OUI+Type+Ver) + Length of your payload
my $element_id = pack("H*", "DD");
my $element_len = pack("C", 5 + length($payload)); 

# Part D: Inner OUI + Type (04) + Version (01)
my $esp_header_inner = pack("H*", "18fe340401");

# Assemble the ESP-NOW Data Segment
my $esp_now_data = $action_header . $random_bytes . $element_id . $element_len . $esp_header_inner . $payload;

# 5. Final Packet Assembly
my $packet = $radiotap . $dot11_hdr . $esp_now_data;

# Send
print "[*] Sending packet (" . length($packet) . " bytes)...\n";
send($sock, $packet, 0);
print "[*] Sent.\n";
