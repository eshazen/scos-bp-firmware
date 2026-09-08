#!/bin/bash
#
# power down MIRA
#
echo '$P@\' > /dev/ttyS0	# LED off
echo '$P@X' > /dev/ttyS0	# RST on
echo '$P@P' > /dev/ttyS0	# CLK off
echo '$P@@' > /dev/ttyS0	# Pwr off

