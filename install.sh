#!/bin/bash
# Before inserting the micro SD into the pi, insert it into a Linux machine/VM with peripherals to encrypt the root partition (mine is sda bc my micro SD card adapter plugs in to my Linux machine over USB.. something about UART? I coded USB transmission sofware circuits once I swear.
sudo umount /dev/sda1 && sudo umount /dev/sda2
sudo e2fsck -f /dev/sda2 # forces sys to check that memory is contiguous
sudo resize2fs /dev/sda1 20G # I set 20GB bc of my 64GB total SD card, and bc we will clone the unencrypted data in slot 2 to slot 3 created in gparted
parted /dev/sda resizepart 2 20G
gparted # use the unallocated space to create a new unallocated partition of equal size to the rootfs partition (likely in slot 2--mmcblk0p2), make sure to save!@
sudo apt-get install cryptsetup lvm2 busybox rsync initramfs-tools
sudo systemctl reboot
cryptsetup luksFormat --type=luks2 --sector-size=4096 -c xchacha12,aes-adiantum-plain64 -s 256 -h sha512 --use-urandom /dev/mmcblk0p3 # recommend setting a password
echo "password" | sudo cryptsetup luksOpen /dev/mmcblk0p3 mmcblk0p3 - # piped these commands bc my rpi keeps dying with the power draw of a light-up keyboard and dies every time over ssh before I could enter the set password
sudo mkfs.ext4 -L root /dev/mapper/mmcblk0p3 # create new file system with root label
sudo mount /dev/mapper/mmcblk0p3 /mnt # mount the partition to /mnt
sudo blkid && sudo lsblk # check out the partition structure to see that it updates
# ON LOCAL MACHINE
ssh-keygen -t rsa -b 4096 # set password on this (optional)
scp ./key.pub hostname@static_IP_of_rpi:~/ # ssh into the rpi box now..
mkdir -p .ssh
mv key.pub .ssh/ && cd .ssh
cat key.pub >> authorized_keys
sudo nano /etc/ssh/sshd_config
Port xx # I recommend uncommenting this and changing the port # bc bots scrape the internet for devices @port 22 first
PermitRootLogin no
PubKeyAuthentication yes
AuthorizedKeysFile      .ssh/authorized_keys .ssh/authorized_keys2
PasswordAuthentication no # this one is named stupidly, it allows **** as you type passwords instead of displaying plain psk characters as text
ChallengeResponseAuthentication no
CTRL+X+ENTER+ENTER
rm -rf key.pub
sudo systemctl restart sshd
# end starter operations, insert the micro SD into the pi
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
sudo cat "interface=wlan0 \n
country_code=US \n
ssid= \n
hw_mode=a \n
channel=153 \n
macaddr_acl=0 \n
auth_algs=1 \n
ignore_broadcast_ssid=0 \n
wpa=2 \n
wpa_passphrase= \n
wpa_key_mgmt=WPA-PSK \n
wpa_pairwise=TKIP \n
rsn_pairwise=CCMP" >> /etc/hostapd/hostapd.conf
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
sudo curl -L https://install.pivpn.io | bash # set dns to Google, I used duckdns.org which has a instructions on the site to setup dynamic dns BEFORE running this command
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
sudo ufw allow 51820
sudo ufw allow 22
sudo cat "DEFAULT_OUTPUT_POLICY="ACCEPT" \n
DEFAULT_FORWARD_POLICY="ACCEPT" \n" >> /etc/default/ufw
sudo ufw disable && sudo ufw enable
curl ipinfo.io/ip
sudo vi /etc/sysctl.d/routed-ap.conf
net.ipv4.ip_forward=1
sudo service openvpn start
sudo iptables -A FORWARD -i tun0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
$ sudo iptables -A FORWARD -i eth0 -o tun0 -j ACCEPT
sudo iptables -A FORWARD -i tun0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i wlan0 -o tun0 -j ACCEPT
sudo iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
sudo iptables -t nat -A PREROUTING -d DYNAMIC_DNS_IP_via_curl_ipinfo.io/ip -p tcp --dport 51820 -j DNAT --to-dest IP_in_/etc/openvpn/server.conf:51820
sudo iptables -t nat -A POSTROUTING -d IP_in_/etc/openvpn/server.conf -p tcp --dport 51820 -j SNAT --to-source IP_in_/etc/openvpn/server.conf
sudo netfilter-persistent save
sudo netfilter-persistent reload
cd /etc/init.d/
sudo nano ./firewall.sh
sudo iptables -t nat -A POSTROUTING -s IP_in_/etc/openvpn/server.conf/24 -o eth0 -j MASQUERADE
sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"
sudo su -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
sudo chmod 700 /etc/init.d/firewall.sh
sudo chmod +x /etc/init.d/firewall.sh
sudo update-rc.d firewall.sh defaults
cd ~/ovpns
sudo cat "compress lz4" >> ./hostname.ovpn
sudo cp ./hostname.ovpn ./hostname.ovpn.conf
sudo mv ./hostname.ovpn.conf /etc/ovpn/
sudo nano /etc/fstab
