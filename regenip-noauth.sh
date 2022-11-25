#!/bin/sh
random() {
	tr </dev/urandom -dc A-Za-z0-9 | head -c5
	echo
}

array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
gen64() {
    ip64() {
	    echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
		}
		    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
		    }

gen_3proxy() {
    cat <<EOF
daemon
maxconn 1000
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
stacksize 6000
flush
auth none
allow *
#allow admin
#admin -p25250
log /usr/local/etc/3proxy/logs/3proxy.log
logformat "- +_L%t.%. %N.%p %E %U %C:%c %R:%r %O %I %h %T"
archiver gz /usr/bin/gzip %F
#store the logs for 30 days
rotate 1
pidfile /usr/local/etc/3proxy/3proxy.pid


$(awk -F "/" '{print "proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 }' ${WORKDATA})
EOF
}

upload_proxy() {
    local PASS=$(random)
    zip --password $PASS proxy.zip proxy.txt
    URL=$(curl -s --upload-file proxy.zip https://transfer.sh/proxy.zip)
    echo "Server ip = ${IP4}. Exteranl sub for ip6 = ${IP6}"
    echo "Proxy is ready! Format IP:PORT:LOGIN:PASS"
    echo "Download zip archive from: ${URL}"
    echo "Password: ${PASS}"

}
gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "usr$(random)/pass$(random)/$IP4/$port/$(gen64 $IP6)"
    done
}

# gen_iptables() {
    # cat <<EOF
    # $(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
# EOF
# }

gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA})
EOF
}
#echo "installing apps"
#yum -y install gcc net-tools bsdtar zip >/dev/null

#install_3proxy

echo "working folder = /home/proxy-installer"
WORKDIR="/home/proxy-installer"
WORKDATA="${WORKDIR}/data.txt"
#mkdir $WORKDIR && cd $_
cd $WORKDIR

IP4=$(curl -4 -s ifconfig.co)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal ip = ${IP4}. Exteranl sub for ip6 = ${IP6}"

echo "How many proxy do you want to create? Example 500"
read COUNT

FIRST_PORT=30000
LAST_PORT=$(($FIRST_PORT + $COUNT))

echo "Delete old data"
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0
sudo systemctl restart NetworkManager
systemctl stop 3proxy
rm -rf $WORKDIR/data.txt
rm -rf $WORKDIR/proxy.txt
rm -rf $WORKDIR/proxy.zip
#rm -rf $WORKDIR/boot_iptables.sh
rm -rf $WORKDIR/boot_ifconfig.sh
rm -rf /usr/local/etc/3proxy/3proxy.cfg

echo "Generating new data"
gen_data >$WORKDIR/data.txt
#gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
#cp check_proxy.sh $WORKDIR/check_proxy.sh
chmod +x ${WORKDIR}/boot_*.sh /etc/rc.local

gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

bash /etc/rc.local

gen_proxy_file_for_user

echo "Starting 3proxy"
systemctl start 3proxy
echo "Stauts 3proxy"
systemctl status 3proxy
#upload_proxy
