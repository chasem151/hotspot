#!/bin/bash
sudo apt install hostapd dnsmasq
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo DEBIAN_FRONTEND=noninteractive apt install -y netfilter-persistent iptables-persistent
sudo cat "interface br0 \n
static ip_address=10.0.0.82/24 \n
static routers=10.0.0.1 \n
static domain_name_servers=127.0.0.1 \n" >> /etc/dhcpcd.conf

sudo cat "net.ipv4.tcp_syncookies=1 \n
	net.ipv4.ip_forward=1 \n" >> /etc/sysctl.d/
sudo sysctl -p /etc/sysctl.conf
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo netfilter-persistent save
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
sudo cat >> "interface=wlan0 \n
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h  \n 
domain=wlan \n
address=/gw.wlan/192.168.4.1 \n # alias for the router" >> .etc/dnsmasq.conf
sudo rfkill unblock wlan
sudo cat "country_code=US \n
interface=wlan0 \n
scan_ssid=1 \n
ssid=bband \n        
hw_mode=g \n
channel=7 \n
macaddr_acl=0 \n
auth_algs=1 \n
ignore_broadcast_ssid=0 \n
wpa=2 \n
***REMOVED***=***REMOVED*** \n
wpa_key_mgmt=WPA-PSK \n
wpa_pairwise=TKIP \n
rsn_pairwise=CCMP \n" >> /etc/hostapd/hostapd.conf
sudo systemctl reboot
sudo usermod -aG group username
sudo cat "[NetDev] \n
Name=br0 \n
Kind=bridge \n" >> /etc/systemd/network/bridge-br0.netdev
sudo cat "[Match] \n
Name=eth0 \n
[Network] \n
Bridge=br0 \n" >> /etc/systemd/network/br0-member-eth0.network
sudo systemctl enable systemd-networkd
sudo cat "denyinterfaces wlan0 eth0 \n
interface br0 \n
sudo rfkill unblock wlan \n" >> /etc/dhcpcd.conf
sudo curl -L https://install.pivpn.io | bash
sudo ufw reset
sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -t nat -X
sudo iptables -t mangle -F
sudo iptables -t mangle -X
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -L
sudo ufw default deny incoming
sudo ufw allow ssh
sudo ufw enable
sudo ufw status verbose
sudo ufw allow ***REMOVED***
sudo ufw allow ***REMOVED***
sudo cat "DEFAULT_OUTPUT_POLICY="ACCEPT" \n
DEFAULT_FORWARD_POLICY="ACCEPT" \n" >> /etc/default/ufw
sudo ufw disable && sudo ufw enable
curl ipinfo.io/ip
sudo nano /etc/openvpn/server.conf 
sudo iptables -t nat -A PREROUTING -d 24.91..... -p tcp --dport ***REMOVED*** -j DNAT --to-dest 10.8...:***REMOVED***
sudo iptables -t nat -A POSTROUTING -d 10.8... -p tcp --dport ***REMOVED*** -j SNAT --to-source 10.8...
sudo netfilter-persistent save
sudo netfilter-persistent reload
cd /etc/init.d/
sudo nano ./firewall.sh
sudo iptables -t nat -A POSTROUTING -s 10..../24 -o eth0 -j MASQUERADE //The>
sudo su -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
sudo chmod 755 /etc/init.d/firewall.sh
sudo chmod +x /etc/init.d/firewall.sh
sudo update-rc.d firewall.sh defaults
cd ~/ovpns
sudo cat "compress lz4" >> ./hostname.ovpn
sudo cp ./hostname.ovpn ./hostname.ovpn.conf
sudo mv ./hostname.ovpn.conf /etc/ovpn/
