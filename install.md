# Before inserting the micro SD into the pi, insert it into a Linux machine/VM with peripherals to 
#encrypt the root partition (mine is sda bc my micro SD card adapter plugs in to my Linux machine over USB.. something about UART happening there. 
#I coded USB transmission sofware circuits once I swear.
# MAKE SURE to ERASE the sd card/storage media and format as fat32, I use raspberry pi imager due to reliability of installs, balenaetcher is not
# consistently functional. THEN, you can install the OS with desktop GUI (this is important if your storage media/this process fails and you 
# find yourself coming back to the beginning of this guide, it seems initramfs really likes to hang around.
# to erase a /dev media file system, quickie way: wipefs -a <target device i.e. /dev/sda1>, robust, complete wipe: cat /dev/zero | [wcs](https://github.com/chasem151/hotspot/blob/master/wcs.c) > *target device*
sudo umount /dev/sda1 && sudo umount /dev/sda2
sudo fdisk /dev/sda
d
1
d
2
n
1
end-+7G
t
b
p
n
2
end-+20G
t
83
p
w
sudo e2fsck -f /dev/sda2 # forces sys to check that memory is contiguous
sudo resize2fs /dev/sda2 20G # I set 20GB bc of my 64GB total SD card, and bc we will clone the unencrypted data in slot 2 to slot 3 created in gparted (later problem)
parted /dev/sda resizepart 2 20G # verification of the resize of partition slot 2
gparted # use the unallocated space to create a new unallocated partition of equal size to the rootfs partition (likely in slot 2--mmcblk0p2), 
#make sure to save!@
sudo apt-get install cryptsetup lvm2 busybox rsync initramfs-tools gparted
sudo systemctl reboot
cryptsetup luksFormat --type=luks2 --sector-size=4096 -c xchacha12,aes-adiantum-plain64 -s 256 -h sha512 --use-urandom /dev/mmcblk0p3 
#I recommend setting a password
echo "password" | sudo cryptsetup luksOpen /dev/mmcblk0p3 cryptsetup - # piped these commands bc my rpi keeps dying 
# with the power draw of a light-up keyboard and dies every time over ssh before I could enter the set password
sudo mkfs.ext4 -L root /dev/mapper/cryptsetup # create new file system with root label, this will create symlink /dev/mapper/crypt as well
sudo mount /dev/mapper/cryptsetup /mnt # mount the partition to /mnt
sudo nano /mnt/config.txt
# uncomment/add safe_mode_gpio=4, max_usb_current=1, dtparam=act_led_trigger=heartbeat, dtparam=pwr_led_trigger=panic, disable_audio_dither=1
# dtparam=watchdog=on, dtparam=spi=on, dtparam=i2c_arm=off, enable_uart=0, start_x=0, boot_delay=100, dtoverlay=pi3-disable-bt ahhhh heres the UART
sudo blkid && sudo lsblk # check out the partition structure to see that it updates
sudo echo "initramfs initramfs.gz followkernel" >> /mnt/config.txt # add to EOF after [all]
sudo nano /mnt/cmdline.txt # edit the root=/ default value and separate cryptdevice= by a space on both sides.
root=/dev/mapper/crypt cryptdevice=/dev/mmcblk0p3:crypt ... # add/edit on the existing one contiguous line with one (1) space on all sides 
# to be unlocked at the root stage (root/resume devices or ones with explicit initramfs flag in /etc/crypttab)
sudoedit /etc/crypttab
"crypt	/dev/disk/by-uuid/5e8f28f3-bad1-47dd-b7be-5df77f2f1d82	 none	luks" # you should want to copy this spacing
sudoedit /etc/fstab # this file is VERY SENSITIVE (as is the one directly above).. be careful here or you might lose all your progress and 
# the rpi box will not boot/be recoverable without quantum cracking hashes if you type wrong.. make sure the spacing matches the existing symlinks/integers
# I chose to go with the default format and mark the path of the encrypted /dev/mapper directory created by PARTUUID="", 
# second row: default 12 spaces between /boot and vfat, and third row: 16 spaces between / and ext4, so I put 20 spaces between /dev/mapper and its /,
# which signifies a rootfs slot. I matched the rest of the existing spacing, with 5 spaces between file system type (vfat/ext4) and defaults,
# 3 spaces between defaults and the first integer, 8 spaces between the first and second integers.
# OR ignore my harebrained spacing calculations and just align everything vertically where it might not matter how many spaces btwn entries
# ^^ CHANGES: add root partition to point @the encrypted partition as the 4th row with data in the file (first set of chars is symlink UUID=UUID for
# dev/mapper/crypt, comment out old root partition so it can serve as a fallback if there are issues
# add "defaults, noatime" to end of the encrypted rootfs line before the integers.. still not sure what this does but its the default for the other rootfs
# use UUID="" gathered by "sudo blkid"to match the existing format for using PARTUUIDs, comment out existing root partition.
# DON'T USE ABSOLUTE PATH, USE UUID for /dev/mapper/crypt BC UUID IS ALSO A SYMLINK LIKE PARTUUID, while an absolute path is not the same.
# Also, at the bottom of the file:
tmpfs /var/tmp tmpfs nodev,nosuid,noatime 0 0 # these lines increase the lifespan of the SD card, something about swap/this functions as RAM/a buffer
tmpfs /tmp tmpfs defaults,noatime,nosuid 0 0
# CTRL+X+ENTER+ENTER
sudo echo "CRYPTSETUP=y" >> /etc/cryptsetup-initramfs/conf-hook # this file only starts existing when a device needs 
sudo mkinitramfs -o /mnt/initramfs.gz
sudo lsinitramfs /mnt/initramfs.gz | grep -P "sbin/[cryptsetup|resize2fs|fdisk|dumpe2fs|expect]" # no idea how this much piping is helpful, v verbose
sudo lsinitramfs /mnt/initramfs.gz | grep cryptsetup
# clone current sys to encrypted partition
sudo rsync -avhPHAXx --progress --exclude={/dev/*,/proc/*,/sys/*,/tmp/*,/run/*,/mnt/*,/media/*,/lost+found} / /mnt/
# now, we are done encrypting SSD/HDD! unmount the encrypted partition and reboot
# in the inintramfs prompt:
cryptsetup luksOpen /dev/mmcblk0p3 crypt # mount encrypted partition
exit # then exit the initramfs shell
# after boot:
sudo mkinitramfs -o /boot/initramfs.gz
# we can now delete the unencrypted partition!!
sudo fdisk /dev/mmcblk0
d
2
w
sudo sync
sudo reboot
# on your non Rpi preferably Linux/macos machine:
ssh-keygen -t rsa -b 4096 # set password on this (optional)
***REMOVED*** ./key.pub hostname@static_IP_of_rpi:~/ # ssh into the rpi box now..
mkdir -p .ssh
mv key.pub .ssh/ && cd .ssh
cat key.pub >> authorized_keys
sudo nano /etc/ssh/sshd_config
Port xx # highly recommend uncommenting this and changing the port # bc bots scrape the internet for devices @port ***REMOVED***, bots used to be 82% of web traffic
PermitRootLogin no
PubKeyAuthentication yes
AuthorizedKeysFile      .ssh/authorized_keys .ssh/authorized_keys2
PasswordAuthentication no # this one is named stupidly, it allows **** as you type passwords instead of displaying plain psk characters as text
ChallengeResponseAuthentication no
CTRL+X+ENTER+ENTER
sudo systemctl restart sshd
rm -rf key.pub
# end starter operations, insert the micro SD into the pi
sudo apt install hostapd dnsmasq
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo DEBIAN_FRONTEND=noninteractive apt install -y netfilter-persistent iptables-persistent
sudo echo "interface br0 \n
static ip_address=10.0.0.82/24 \n
static routers=10.0.0.1 \n
static domain_name_servers=127.0.0.1 \n" >> /etc/dhcpcd.conf

sudo echo "net.ipv4.tcp_syncookies=1 \n
	net.ipv4.ip_forward=1 \n" >> /etc/sysctl.d/
sudo sysctl -p /etc/sysctl.conf
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo netfilter-persistent save
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
sudo echo >> "interface=wlan0 \n
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h  \n 
domain=wlan \n
address=/gw.wlan/192.168.4.1 \n # alias for the router" >> .etc/dnsmasq.conf
sudo rfkill unblock wlan
sudo echo "interface=wlan0 \n
country_code=US \n
ssid= \n
hw_mode=a \n
channel=153 \n
macaddr_acl=0 \n
auth_algs=1 \n
ignore_broadcast_ssid=0 \n
wpa=2 \n
***REMOVED***= \n
wpa_key_mgmt=WPA-PSK \n
wpa_pairwise=TKIP \n
rsn_pairwise=CCMP" >> /etc/hostapd/hostapd.conf
sudo systemctl reboot
sudo usermod -aG group username
sudo echo "[NetDev] \n
Name=br0 \n
Kind=bridge \n" >> /etc/systemd/network/bridge-br0.netdev
sudo echo "[Match] \n
Name=eth0 \n
[Network] \n
Bridge=br0 \n" >> /etc/systemd/network/br0-member-eth0.network
sudo systemctl enable systemd-networkd
sudo echo "denyinterfaces wlan0 eth0 \n
interface br0 \n
sudo rfkill unblock wlan \n" >> /etc/dhcpcd.conf
sudo curl -L https://install.pivpn.io | bash # set dns to Google, I used duckdns.org which has a instructions on the site to setup 
#dynamic dns BEFORE running this command
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
sudo echo "DEFAULT_OUTPUT_POLICY="ACCEPT" \n
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
sudo iptables -t nat -A PREROUTING -d DYNAMIC_DNS_IP_via_curl_ipinfo.io/ip -p tcp --dport ***REMOVED*** -j DNAT --to-dest IP_in_/etc/openvpn/server.conf:***REMOVED***
sudo iptables -t nat -A POSTROUTING -d IP_in_/etc/openvpn/server.conf -p tcp --dport ***REMOVED*** -j SNAT --to-source IP_in_/etc/openvpn/server.conf
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
