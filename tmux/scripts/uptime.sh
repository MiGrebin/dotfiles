#!/bin/bash
uptime | sed 's/^[^,]*up *//; s/, *[0-9]* user.*//; s/ day.*, */d /; s/ hrs*/h/; s/ mins*/m/; s/ secs*/s/; s/\([0-9]\{1,2\}\):\([0-9]\{1,2\}\)/\1h \2m/'
