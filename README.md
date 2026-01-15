# ESPerlNOW
Like ESPythoNOW, but in Perl.
Send a packet:
```
~$ sudo perl send_packet.pl
[*] Connected to wlp2s0mon (Index: 4)
[*] Sending packet (76 bytes)...
[*] Sent.
```
Received payload:
```
I (22506) DEBUG: Seen packet from: aa:bb:cc. Len: 25
RX[25]: 01 02 03 A5 A5 A5 A5 A5 A5 A5 A5 A5 A5 A5 A5 A5 A5 A5 A5 A5 A5 A5 A5 A5 A5
```
