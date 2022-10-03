sudo apt install hostapd dnsmasq
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo DEBIAN_FRONTEND=noninteractive apt install -y netfilter-persistent iptables-persistent
sudo nano /etc/dhcpcd.conf
interface br0
static ip_address=10.0.0.82/24
static routers=10.0.0.1
static domain_name_servers=127.0.0.1
sudo nano /etc/sysctl.d/
	net.ipv4.tcp_syncookies=1
	net.ipv4.ip_forward=1
sudo sysctl -p /etc/sysctl.conf
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo netfilter-persistent save
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h # client DHCP addr
domain=wlan
address=/gw.wlan/192.168.4.1 # alias for the router
sudo rfkill unblock wlan
sudo nano /etc/hostapd/hostapd.conf
country_code=US
interface=wlan0
scan_ssid=1
ssid=bband        
hw_mode=g 
channel=7
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
***REMOVED***=***REMOVED***
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
sudo systemctl reboot
sudo usermod -aG group username
sudo nano /etc/systemd/network/bridge-br0.netdev
[NetDev]
Name=br0
Kind=bridge
sudo nano /etc/systemd/network/br0-member-eth0.network
[Match]
Name=eth0
[Network]
Bridge=br0
sudo systemctl enable systemd-networkd
sudo nano /etc/dhcpcd.conf
denyinterfaces wlan0 eth0
interface br0
sudo rfkill unblock wlan
sudo curl -L https://install.pivpn.io | bash
rename .ovpn to .conf
mv .conf to /etc/ovpn
edit /etc/default/openvpn to enable autostart
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
sudo nano /etc/default/ufw
DEFAULT_OUTPUT_POLICY="ACCEPT"
DEFAULT_FORWARD_POLICY="ACCEPT"
sudo ufw disable && sudo ufw enable
curl ipinfo.io/ip
sudo nano /etc/openvpn/server.conf 
sudo iptables -t nat -A PREROUTING -d 24.91.159.44 -p tcp --dport ***REMOVED*** -j DNAT --to-dest 10.8.95.0:***REMOVED***
sudo iptables -t nat -A POSTROUTING -d 10.8.95.0 -p tcp --dport ***REMOVED*** -j SNAT --to-source 10.8.95.0
sudo netfilter-persistent save
sudo netfilter-persistent reload
cd /etc/init.d/
#!/bin/sh
sudo iptables -t nat -A POSTROUTING -s 10.8.95.0/24 -o eth0 -j MASQUERADE //The>
sudo su -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
sudo chmod 755 /etc/init.d/firewall.sh
sudo chmod +x /etc/init.d/firewall.sh
sudo update-rc.d firewall.sh defaults
cd ~/ovpns
sudo nano ./hostname.ovpn
compress lz4 #
sudo cp ./hostname.ovpn ./hostname.ovpn.conf
sudo mv ./hostname.ovpn.conf /etc/ovpn/
