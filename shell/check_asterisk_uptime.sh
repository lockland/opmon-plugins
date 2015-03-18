#!/bin/bash
sudo /usr/sbin/asterisk -crx "core show uptime" | grep -i system 
[ $? -ne 0 ] && echo "CRITICAL: Asterisk nao retornou uptime" && exit 2 || exit 0

