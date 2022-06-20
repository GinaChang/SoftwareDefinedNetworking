#!/bin/bash

# 1. create containers
# ONOS
docker run -it -d -e DISPLAY=$DISPLAY \
-v /tmp/.X11-unix:/tmp/.X11-unix -p 8181:8181 -p 8101:8101 \
-p 6653:6653 --privileged --cap-add NET_ADMIN \
--cap-add NET_BROADCAST --cap-add SYS_MODULE \
--name ONOS onosproject/onos:2.2.0
# Speaker
docker run -it -d --privileged -e DISPLAY=$DISPLAY \
-v /tmp/.X11-unix:/tmp/.X11-unix --cap-add NET_ADMIN \
--cap-add NET_BROADCAST --cap-add SYS_MODULE \
--name Speaker johnny3644186/onos_vrouter
# OVS
docker run -it -d --privileged --cap-add NET_ADMIN \
--cap-add NET_BROADCAST --cap-add SYS_MODULE \
--name OVS openshift/openvswitch
# R1
docker run -it -d --privileged --cap-add NET_ADMIN \
--cap-add NET_BROADCAST --cap-add SYS_MODULE \
--name R1 ubuntu:16.04
# R2
docker run -it -d --privileged --cap-add NET_ADMIN \
--cap-add NET_BROADCAST --cap-add SYS_MODULE \
--name R2 ubuntu:16.04
# h1
docker run -it -d --privileged --cap-add NET_ADMIN \
--cap-add NET_BROADCAST --cap-add SYS_MODULE \
--name h1 ubuntu:16.04
# h2
docker run -it -d --privileged --cap-add NET_ADMIN \
--cap-add NET_BROADCAST --cap-add SYS_MODULE \
--name h2 ubuntu:16.04
# h3
docker run -it -d --privileged --cap-add NET_ADMIN \
--cap-add NET_BROADCAST --cap-add SYS_MODULE \
--name h3 ubuntu:16.04
# h4
docker run -it -d --privileged --cap-add NET_ADMIN \
--cap-add NET_BROADCAST --cap-add SYS_MODULE \
--name h4 ubuntu:16.04

# 2. allow access
xhost +

# 3. install library
docker exec -it ONOS bash -c "apt-get update && apt-get install -y curl net-tools openssh-server iproute2 iputils-ping"
docker exec -it Speaker bash -c "apt-get update && apt-get install -y net-tools iproute2 iputils-ping"
docker exec -it OVS bash -c "yum update && yum -yq install net-tools"
docker exec -it R1 bash -c "apt-get update && apt-get install -y net-tools iproute2 iputils-ping vim telnet quagga"
docker exec -it R2 bash -c "apt-get update && apt-get install -y net-tools iproute2 iputils-ping vim telnet quagga"
docker exec -it h1 bash -c "apt-get update && apt-get install -y net-tools iproute2 iputils-ping"
docker exec -it h2 bash -c "apt-get update && apt-get install -y net-tools iproute2 iputils-ping"
docker exec -it h3 bash -c "apt-get update && apt-get install -y net-tools iproute2 iputils-ping"
docker exec -it h4 bash -c "apt-get update && apt-get install -y net-tools iproute2 iputils-ping"

# 4. get each container PID, and set variables
# ONOS
ONOS_PID=$(docker inspect -f '{{.State.Pid}}' ONOS)
echo "ONOS_PID = ${ONOS_PID}" >> PID.txt
# Speaker
Speaker_PID=$(docker inspect -f '{{.State.Pid}}' Speaker)
echo "Speaker_PID = ${Speaker_PID}" >> PID.txt
# OVS
OVS_PID=$(docker inspect -f '{{.State.Pid}}' OVS)
echo "OVS_PID = ${OVS_PID}" >> PID.txt
# R1
R1_PID=$(docker inspect -f '{{.State.Pid}}' R1)
echo "R1_PID = ${R1_PID}" >> PID.txt
# R2
R2_PID=$(docker inspect -f '{{.State.Pid}}' R2)
echo "R2_PID = ${R2_PID}" >> PID.txt
# h1
h1_PID=$(docker inspect -f '{{.State.Pid}}' h1)
echo "h1_PID = ${h1_PID}" >> PID.txt
# h2
h2_PID=$(docker inspect -f '{{.State.Pid}}' h2)
echo "h2_PID = ${h2_PID}" >> PID.txt
# h3
h3_PID=$(docker inspect -f '{{.State.Pid}}' h3)
echo "h3_PID = ${h3_PID}" >> PID.txt
# h4
h4_PID=$(docker inspect -f '{{.State.Pid}}' h4)
echo "h4_PID = ${h4_PID}" >> PID.txt

# 5. create soft link to net namespace with containers
mkdir -p /var/run/netns
ln -s /proc/$ONOS_PID/ns/net /var/run/netns/$ONOS_PID
ln -s /proc/$Speaker_PID/ns/net /var/run/netns/$Speaker_PID
ln -s /proc/$OVS_PID/ns/net /var/run/netns/$OVS_PID
ln -s /proc/$R1_PID/ns/net /var/run/netns/$R1_PID
ln -s /proc/$R2_PID/ns/net /var/run/netns/$R2_PID
ln -s /proc/$h1_PID/ns/net /var/run/netns/$h1_PID
ln -s /proc/$h2_PID/ns/net /var/run/netns/$h2_PID
ln -s /proc/$h3_PID/ns/net /var/run/netns/$h3_PID
ln -s /proc/$h4_PID/ns/net /var/run/netns/$h4_PID

# 6. create veth pairs and set veth ip
# ONOS <--> Speaker
ip link add vethSpeakerONOS type veth peer name vethONOSSpeaker
ip link set vethSpeakerONOS netns $Speaker_PID
ip link set vethONOSSpeaker netns $ONOS_PID
docker exec -it Speaker bash -c "ip link set dev vethSpeakerONOS up"
docker exec -it ONOS bash -c "ip link set dev vethONOSSpeaker up"
docker exec -it Speaker bash -c "ip address add 172.16.1.1/24 dev vethSpeakerONOS"
docker exec -it ONOS bash -c "ip address add 172.16.1.2/24 dev vethONOSSpeaker"

# Ovs <--> Speaker
ip link add vethSpeakerOvs type veth peer name vethOvsSpeaker
ip link set vethSpeakerOvs netns $Speaker_PID
ip link set vethOvsSpeaker netns $OVS_PID
docker exec -it Speaker bash -c "ip link set dev vethSpeakerOvs address 00:00:00:00:00:01"
docker exec -it Speaker bash -c "ip link set dev vethSpeakerOvs up"
docker exec -it OVS bash -c "ip link set dev vethOvsSpeaker up"
docker exec -it Speaker bash -c "ip address add 10.0.10.101/24 dev vethSpeakerOvs"
docker exec -it Speaker bash -c "ip address add 10.0.20.101/24 dev vethSpeakerOvs"

# ONOS <--> Ovs
ip link add vethOvsONOS type veth peer name vethONOSOvs
ip link set vethOvsONOS netns $OVS_PID
ip link set vethONOSOvs netns $ONOS_PID
docker exec -it OVS bash -c "ip link set dev vethOvsONOS up"
docker exec -it ONOS bash -c "ip link set dev vethONOSOvs up"
docker exec -it OVS bash -c "ip address add 172.18.1.1/24 dev vethOvsONOS"
docker exec -it ONOS bash -c "ip address add 172.18.1.2/24 dev vethONOSOvs"

# Ovs <--> R1
ip link add vethR1Ovs type veth peer name vethOvsR1
ip link set vethR1Ovs netns $R1_PID
ip link set vethOvsR1 netns $OVS_PID
docker exec -it R1 bash -c "ip link set dev vethR1Ovs up"
docker exec -it OVS bash -c "ip link set dev vethOvsR1 up"
docker exec -it R1 bash -c "ip address add 10.0.10.1/24 dev vethR1Ovs"

# Ovs <--> R2
ip link add vethR2Ovs type veth peer name vethOvsR2
ip link set vethR2Ovs netns $R2_PID
ip link set vethOvsR2 netns $OVS_PID
docker exec -it R2 bash -c "ip link set dev vethR2Ovs up"
docker exec -it OVS bash -c "ip link set dev vethOvsR2 up"
docker exec -it R2 bash -c "ip address add 10.0.20.1/24 dev vethR2Ovs"

# 7. create docker network br 
docker network create --subnet=172.16.10.0/24 --gateway=172.16.10.101 br1
docker network create --subnet=192.168.20.0/24 --gateway=192.168.20.101 br2

# 8. connect br1 and R1, connect br1 and h1, connect br1 and h2
docker network connect --ip 172.16.10.254 br1 R1
docker network connect --ip 172.16.10.1 br1 h1
docker network connect --ip 172.16.10.2 br1 h2

# 9. connect br2 and R2, connect br2 and h3, connect br2 and h4
docker network connect --ip 192.168.20.254 br2 R2
docker network connect --ip 192.168.20.1 br2 h3
docker network connect --ip 192.168.20.2 br2 h4

# 10. set default route to Router
docker exec -it h1 bash -c "ip route del default && ip route add default via 172.16.10.254"
docker exec -it h2 bash -c "ip route del default && ip route add default via 172.16.10.254"
docker exec -it h3 bash -c "ip route del default && ip route add default via 192.168.20.254"
docker exec -it h4 bash -c "ip route del default && ip route add default via 192.168.20.254"

# 11. set ovs device id and port configuration
docker exec -it OVS bash -c "ovs-vsctl add-br ovsbr -- set bridge ovsbr other-config:datapath-id=00000000000000a1"
docker exec -it OVS bash -c "ovs-ofctl show ovsbr"
docker exec -it OVS bash -c "ovs-vsctl add-port ovsbr vethOvsR2 -- set interface vethOvsR2 ofport_request=1"
docker exec -it OVS bash -c "ovs-vsctl add-port ovsbr vethOvsSpeaker -- set interface vethOvsSpeaker ofport_request=2"
docker exec -it OVS bash -c "ovs-vsctl add-port ovsbr vethOvsR1 -- set interface vethOvsR1 ofport_request=3"
docker exec -it OVS bash -c "ovs-vsctl set-controller ovsbr tcp:172.18.1.2:6653"

# 12. copy zebra and bgpd conf files to Speaker container
docker cp Speaker_zebra.conf Speaker:/etc/quagga/zebra.conf
docker cp Speaker_bgpd.conf Speaker:/etc/quagga/bgpd.conf

# 13. run zebra and bgpd service in Speaker container
docker exec -it Speaker bash -c "zebra -d -A 127.0.0.1 --retain"
docker exec -it Speaker bash -c "bgpd -d -A 127.0.0.1"
docker exec -it Speaker bash -c "netstat -tnlp"

# 14. modify R1,R2 quagga configuration setting
docker exec -it R1 bash -c "sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf && sysctl -p"
docker exec -it R1 bash -c "sed -i 's/zebra=no/zebra=yes/g' /etc/quagga/daemons"
docker exec -it R1 bash -c "sed -i 's/bgpd=no/bgpd=yes/g' /etc/quagga/daemons"
docker exec -it R2 bash -c "sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf && sysctl -p"
docker exec -it R2 bash -c "sed -i 's/zebra=no/zebra=yes/g' /etc/quagga/daemons"
docker exec -it R2 bash -c "sed -i 's/bgpd=no/bgpd=yes/g' /etc/quagga/daemons"

# 15. copy zebra and bgpd conf files to R1, R2 containers
docker cp R1_zebra.conf R1:/etc/quagga/zebra.conf
docker cp R2_zebra.conf R2:/etc/quagga/zebra.conf
docker cp R1_bgpd.conf R1:/etc/quagga/bgpd.conf
docker cp R2_bgpd.conf R2:/etc/quagga/bgpd.conf
docker exec -it R1 bash -c "/etc/init.d/quagga restart"
docker exec -it R1 bash -c "route"
docker exec -it R2 bash -c "/etc/init.d/quagga restart"
docker exec -it R2 bash -c "route"


# 以下手動補完
# docker exec -it ONOS bash -c "ssh -p 8101 karaf@localhost"
# app activate org.onosproject.openflow
# app activate vrouter

# curl -u onos:rocks -XPOST localhost:8181/onos/v1/network/configuration/ -H "Content-Type: application/json" -d @/home/gina/Gina/final-project/final.json -i
# curl -u onos:rocks -XGET localhost:8181/onos/v1/flows/of:00000000000000a1 -i
