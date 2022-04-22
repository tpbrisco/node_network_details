#!/bin/bash
# print prometheus formatted network information
#
# requires a version of "ip" that supports the "--json" flag
# Install
set -euo pipefail

# default values
INTERFACES="*"

DEBUG=0
# debug logging
function dbg_log () {
    if [ "$DEBUG" -eq 1 ]; then
	echo $@ >> /tmp/node_network_details-dbg.log
    fi
}

# error logging
function err_log () {
    echo $@ >> /tmp/node_network_details-err.log
}

#
dbg_log "Starting up " $(date)

# check utilities - e.g. versions of "ip" have different capabilities
set +e
ip --json addr show >/dev/null 2>&1
ip_ok=$?
set -e
if [ $ip_ok -eq 0 ]; then
    BINIP="ip"
    IPJSON=1
else
    err_log "\"ip\" does not support the --json flag"
    IPJSON=0
fi

set +e
JQ=$(type -p jq)
set -e
if [ "$JQ" == '' ]; then
    dbg_log "JQ not found, no output"
    IPJSON=0
fi

DATE="$(date)"
dbg_log "$DATE"

# get interface information the hard and fragile way
function show_ip_painfully() {
    ip -4  addr show | grep '^[1-9][0-9]*' -A1 > /tmp/ip4-interfaces.txt
    ip -6  addr show | grep '^[1-9][0-9]*' -A1 > /tmp/ip6-interfaces.txt
    cat /tmp/ip4-interfaces.txt /tmp/ip6-interfaces.txt > /tmp/ip-interfaces.txt
    while read -r line0 ;  do
	[ "$line0" == "--" ] && continue
	read -r line1
	read -r -a ifinfo <<< $(echo $line0 | awk -F: '{print $1 $2}')
	ifindex=${ifinfo[0]}
	ifdev=${ifinfo[1]%@*}
	read -r -a addrinfo <<< $(echo $line1 | awk '{print $1 " " $2}')
	iffamily=${addrinfo[0]}
	ifnetwork=${addrinfo[1]}
	ifaddress=${ifnetwork%/*}
	# get MAC address
	line2=$(ip link show dev "$ifdev" | tail -1)
	read -r -a macinfo <<< $(echo $line2 | awk '{print $2}')
	# print interface stats
	echo "node_network_details{device=\"$ifdev\", macaddr=\"$macinfo\", addressfamily=\"$iffamily\", address=\"$ifaddress\"} $ifindex"
    done < /tmp/ip-interfaces.txt
    rm -f /tmp/ip4-interfaces.txt /tmp/ip6-interfaces.txt /tmp/ip-interfaces.txt 
}

# get interface information
function show_interface_data () {
    # print out data in a prometheus friendly way
    dbg_log "Showing data"
    echo "# HELP node_network_details A list of interfaces and IP addresses (ip: $IPJSON)"
    echo "# TYPE node_network_details gauge"
    if [[ "$IPJSON" == 1 ]]; then
	$BINIP --json addr show | jq -Mr '.[] |.ifname as $ifname |.ifindex as $ifindex|.address as $macaddr |.addr_info[] | "node_network_details{device=\"\($ifname)\", macaddr=\"\($macaddr)\", addressfamily=\"\(.family)\", address=\"\(.local)\"} \($ifindex)"'
    else
	show_ip_painfully
    fi
}

show_interface_data > /tmp/node_net-$$.txt
LEN=$(cat /tmp/node_net-$$.txt | wc -c)

# send HTTP headers
echo -en "HTTP/1.1 200 OK\r\n"
echo -en "Content-Type: text/plain; charset=utf-8\r\n"
echo -en "Date: $DATE\r\n"
echo -en "Content-Length: $LEN\r\n"
echo -en "\r\n"
cat /tmp/node_net-$$.txt
rm -f /tmp/node_net-$$.txt
dbg_log "Sent $LEN bytes, exit 0"
exit 0
