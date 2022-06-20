# 1. create containers
docker run -it -d -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix -p 8181:8181 -p 8101:8101 -p 6653:6653 --privileged --cap-add NET_ADMIN --cap-add NET_BROADCAST --cap-add SYS_MODULE --name ONOS onosproject/onos:2.2.0
docker run -it -d --privileged --cap-add NET_ADMIN --cap-add NET_BROADCAST --cap-add SYS_MODULE --name Router ubuntu:16.04
docker run -it -d --privileged --cap-add NET_ADMIN --cap-add NET_BROADCAST --cap-add SYS_MODULE --name h1 ubuntu:16.04
docker run -it -d --privileged -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix --cap-add NET_ADMIN --cap-add NET_BROADCAST --cap-add SYS_MODULE --name Speaker johnny3644186/onos_vrouter
docker run -it -d --privileged --cap-add NET_ADMIN --cap-add NET_BROADCAST --cap-add SYS_MODULE --name OVS openshift/openvswitch

# 2. allow access
xhost +

# 3. install library
docker exec -it Speaker bash -c "apt-get update && apt-get install -y wireshark net-tools iproute2 iputils-ping"
docker exec -it OVS bash -c "yum upgrade && yum install -y net-tools"
docker exec -it Router bash -c "apt-get update && apt-get install -y net-tools iproute2 iputils-ping vim telnet quagga"
docker exec -it h1 bash -c "apt-get update && apt-get install -y net-tools iproute2 iputils-ping"
docker exec -it ONOS bash -c "apt-get update && apt-get install -y curl net-tools openssh-server iproute2 iputils-ping"


# 4. get each container PID, and set variables
ONOS_PID=$(docker inspect -f '{{.State.Pid}}' ONOS)
echo "ONOS_PID = ${ONOS_PID}" >> PID.txt
Router_PID=$(docker inspect -f '{{.State.Pid}}' Router)
echo "Router_PID = ${Router_PID}" >> PID.txt
h1_PID=$(docker inspect -f '{{.State.Pid}}' h1)
echo "h1_PID = ${h1_PID}" >> PID.txt
Speaker_PID=$(docker inspect -f '{{.State.Pid}}' Speaker)
echo "Speaker_PID = ${Speaker_PID}" >> PID.txt
OVS_PID=$(docker inspect -f '{{.State.Pid}}' OVS)


# 5. create soft link to net namespace with containers
mkdir -p /var/run/netns
ln -s /proc/$ONOS_PID/ns/net /var/run/netns/$ONOS_PID
ln -s /proc/$Router_PID/ns/net /var/run/netns/$Router_PID
ln -s /proc/$h1_PID/ns/net /var/run/netns/$h1_PID
ln -s /proc/$Speaker_PID/ns/net /var/run/netns/$Speaker_PID
ln -s /proc/$OVS_PID/ns/net /var/run/netns/$OVS_PID

# 6. create veth pairs and set veth ip
# Ovs <--> Router
ip link add vethRouterOvs type veth peer name vethOvsRouter
ip link set vethRouterOvs netns $Router_PID
ip link set vethOvsRouter netns $OVS_PID
docker exec -it Router bash -c "ip link set dev vethRouterOvs up"
docker exec -it OVS bash -c "ip link set dev vethOvsRouter up"
docker exec -it Router bash -c "ip address add 10.0.1.1/24 dev vethRouterOvs" # 測試3

# Ovs <--> Speaker
ip link add vethSpeakerOvs type veth peer name vethOvsSpeaker
ip link set vethSpeakerOvs netns $Speaker_PID
ip link set vethOvsSpeaker netns $OVS_PID
docker exec -it Speaker bash -c "ip link set dev vethSpeakerOvs address 00:00:00:00:00:01"
docker exec -it Speaker bash -c "ip link set dev vethSpeakerOvs up"
docker exec -it OVS bash -c "ip link set dev vethOvsSpeaker up"
docker exec -it Speaker bash -c "ip address add 10.0.1.3/24 dev vethSpeakerOvs" # 測試3


# ONOS <--> Speaker
ip link add vethSpeakerONOS type veth peer name vethONOSSpeaker
ip link set vethSpeakerONOS netns $Speaker_PID
ip link set vethONOSSpeaker netns $ONOS_PID
docker exec -it Speaker bash -c "ip link set dev vethSpeakerONOS up"
docker exec -it ONOS bash -c "ip link set dev vethONOSSpeaker up"
docker exec -it Speaker bash -c "ip address add 172.16.1.1/24 dev vethSpeakerONOS" # 測試3
docker exec -it ONOS bash -c "ip address add 172.16.1.2/24 dev vethONOSSpeaker" # 測試3


# ONOS <--> Ovs
ip link add vethOvsONOS type veth peer name vethONOSOvs
ip link set vethOvsONOS netns $OVS_PID
ip link set vethONOSOvs netns $ONOS_PID
docker exec -it OVS bash -c "ip link set dev vethOvsONOS up"
docker exec -it ONOS bash -c "ip link set dev vethONOSOvs up"
docker exec -it OVS bash -c "ip address add 172.18.1.1/24 dev vethOvsONOS" # 測試3
docker exec -it ONOS bash -c "ip address add 172.18.1.2/24 dev vethONOSOvs" # 測試3

# 7. create docker network br 
docker network create --subnet=192.168.0.0/24 --gateway=192.168.0.101 br

# 9. connect br and Router, connect br and h1
docker network connect --ip 192.168.0.254 br Router
docker network connect --ip 192.168.0.1 br h1
# docker inspect br

# 10. set h1 default route to Router
docker exec -it h1 bash -c "ip route del default && ip route add default via 192.168.0.254"

# 11. set ovs device id and port configuration
docker exec -it OVS bash -c "ovs-vsctl add-br ovsbr -- set bridge ovsbr other-config:datapath-id=00000000000000a1"
docker exec -it OVS bash -c "ovs-ofctl show ovsbr"
docker exec -it OVS bash -c "ovs-vsctl add-port ovsbr vethOvsRouter -- set interface vethOvsRouter ofport_request=1"
docker exec -it OVS bash -c "ovs-vsctl add-port ovsbr vethOvsSpeaker -- set interface vethOvsSpeaker ofport_request=2"
docker exec -it OVS bash -c "ovs-vsctl set-controller ovsbr tcp:172.18.1.2:6653"

# 12. copy zebra and bgpd conf files to Speaker container
docker cp zebra.conf Speaker:/etc/quagga/
docker cp bgpd_Speaker.conf Speaker:/etc/quagga/bgpd.conf

# 13. run zebra and bgpd service in Speaker container
docker exec -it Speaker bash -c "zebra -d -A 127.0.0.1 --retain"
docker exec -it Speaker bash -c "bgpd -d -A 127.0.0.1"
docker exec -it Speaker bash -c "netstat -tnlp"

# 14. modify Router quagga configuration setting
docker exec -it Router bash -c "sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf && sysctl -p"
docker exec -it Router bash -c "sed -i 's/zebra=no/zebra=yes/g' /etc/quagga/daemons"
docker exec -it Router bash -c "sed -i 's/bgpd=no/bgpd=yes/g' /etc/quagga/daemons"

# 15. copy zebra and bgpd conf files to Router container
docker cp zebra_Router.conf Router:/etc/quagga/zebra.conf
docker cp bgpd_Router.conf Router:/etc/quagga/bgpd.conf
docker exec -it Router bash -c "/etc/init.d/quagga restart"
docker exec -it Router bash -c "route"


# 以下手動補完
# docker exec -it ONOS bash -c "ssh -p 8101 karaf@localhost"
# app activate org.onosproject.openflow
# app activate vrouter

# curl -u onos:rocks -XPOST localhost:8181/onos/v1/network/configuration/ -H "Content-Type: application/json" -d @/home/gina/Gina/final-project/example/test.json -i
# curl -u onos:rocks -XGET localhost:8181/onos/v1/flows/of:00000000000000a1 -i
