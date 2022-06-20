#!/bin/bash
rm -rf /var/run/netns/*
docker rm -f ONOS OVS Speaker R1 R2 h1 h2 h3 h4
docker network rm br1 br2
rm -f /home/gina/Gina/final-project/PID.txt