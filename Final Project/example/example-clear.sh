rm -rf /var/run/netns/*
docker rm -f Router ONOS h1 OVS Speaker
docker network rm br
rm -f /home/gina/Gina/final-project/example/PID.txt