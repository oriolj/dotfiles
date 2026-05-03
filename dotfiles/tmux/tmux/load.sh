#!/bin/sh
awk '{print $3}' /proc/loadavg
