export PS4='+ $(date "+%H:%M:%S") [${BASH_SOURCE##*/}:${LINENO}] '
set -x

mac="02:24:df:93:8c:02"

sudo ifconfig en0 down

sleep 2
sudo /sbin/ifconfig en0 ether "$mac"

sleep 2

sudo ifconfig en0 up

sleep 2

printf "Current MAC Address"
ifconfig en0 | grep ether