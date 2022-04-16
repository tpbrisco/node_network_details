#!/bin/bash
# print prometheus formatted network information
#
# requires a version of "ip" that supports the "--json" flag
# Install
set -euo pipefail

# default values
INTERFACES="*"

DEBUG=1
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
JQ=$(type -p jq)
if [ "$JQ" == '' ]; then
    err_log "\"jq\" is needed"
    exit 1
fi

DATE="$(date)"
dbg_log "$DATE"

# get interface information
function show_interface_data () {
    # print out data in a prometheus friendly way
    dbg_log "Showing data"
    echo "# HELP node_network_details A list of interfaces and IP addresses"
    echo "# TYPE node_network_details gauge"
    if [[ "$IPJSON" == 1 ]]; then
	$BINIP --json addr show | jq -Mr '.[] |.ifname as $ifname |.ifindex as $ifindex|.address as $macaddr |.addr_info[] | "node_network_details{ifname=\"\($ifname)\", macaddr=\"\($macaddr)\", addressfamily=\"\(.family)\", address=\"\(.local)\"} \($ifindex)"'
    else
	true
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
