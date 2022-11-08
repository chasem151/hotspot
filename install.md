# Before inserting the micro SD into the pi, insert it into a Linux machine/VM with peripherals to 
encrypt the root partition (mine is sda bc my micro SD card adapter plugs in to my Linux machine over USB.. something about UART happening there. 
I coded USB transmission sofware circuits once I swear.
# MAKE SURE to ERASE the sd card/storage media and format as fat32, I use raspberry pi imager due to reliability of installs, balenaetcher is not
# consistently functional. THEN, you can install the OS with desktop GUI (this is important if your storage media/this process fails and you 
# find yourself coming back to the beginning of this guide, it seems initramfs really likes to hang around.
# to erase a /dev media file system, quickie way: wipefs -a <target device i.e. /dev/sda1>, robust, complete wipe: cat /dev/zero | [wcs](https://github.com/chasem151/hotspot/blob/master/wcs.c) > *target device*
```
# this phase of preparation involves connecting the micro SD/drive to a UNIX-capable system for flashing.
# I chose to encrypt the root partition, but you do not have to. The hotspot commands are probably more useful.
sudo su # run if any commands have the error response of improper permissions (even when prefacing cmds with sudo)
sudo umount /dev/sda2 # target root partition, unmount it to edit its size/start & endpoints
sudo cfdisk /dev/sda # resize root partition sda2 to roughly 1/3 of the total space on disk, write, quit
gparted # open application, make a new partition (sda3 over USB, mmcblk0p3 on Rpi 3B+ after booting into it)
# let /dev/sda3 be unformatted by selecting "New" on the larger free "unallocated" block, 
# edit it to have the same size as the original rootfs part, which in my case is /dev/sda2 (1/3 of total SSD/HDD memory)
sudo e2fsck -f /dev/sda2 # force checking for contiguous blks, should print that its clean
sudo resize2fs /dev/sda2 sizeinG # ensure resize to new size set in cfdisk, specify the size as a float value then G for Gb, M for Mb.. etc.
# now, eject disk in the file navigator UI, insert into SBC, boot SBC
sudo apt-get install cryptsetup lvm2 busybox rsync initramfs-tools gparted # dependecy programs for encrypting root partiton
sudo apt-get update && sudo apt-get full-upgrade # little better and more low-level than apt itself, creates symlinks to these programs for you!
sudo systemctl reboot # ensure all programs are loaded, if a cmd does not work, try executing "which programname", if the program
# is installed, it will show a path to /sbin or something of the sort assuming symlinks are properly generated. If any commands do not 
# run as intended, try "sudo su && dpkg --configure -a" to reset/update the package cache when apt-get update or apt-get upgrade fail.
cryptsetup luksFormat --type=luks2 --sector-size=4096 -c xchacha12,aes-adiantum-plain64 -s 256 -h sha512 --use-urandom /dev/mmcblk0p3 
# I strongly recommend setting a password, this will format the newly created unallocated partition to be encrypted
# WARNING: this will persistently make the given partition encrypted, even if you delete the partition via sudo su && cat /dev/zero | ./wcs > # #/dev/mmcblk0p3, which should erase all of the previous file system & data in theory. even sudo su && cat /dev/zero > partitiontoerase doesn't change
# future partitions on this target device media partition from being encrypted, so definitely remember the password );)
echo "password" | sudo cryptsetup luksOpen /dev/mmcblk0p3 crypt - 
# piped these commands bc my rpi keeps dying with the power draw of either ssh (ethernet on) or ethernet on and keyboard connected to pi on
# with the power draw of a light-up keyboard and dies every time over ssh before I could enter the set password
sudo mkfs.ext4 -L root /dev/mapper/crypt # if this kills your SBC/makes it reboot, try: mke2fs -t ext4 -c dev/mapper/parition
# create new file system with root label, this will create symlink /dev/mapper/crypt as well
sudo mount /dev/mapper/crypt /mnt 
# mount the partition to /mnt
sudo nano /mnt/config.txt
# uncomment/add safe_mode_gpio=4, max_usb_current=1, dtparam=act_led_trigger=heartbeat, dtparam=pwr_led_trigger=panic, disable_audio_dither=1
# dtparam=watchdog=on, dtparam=spi=on, dtparam=i2c_arm=off, enable_uart=0, start_x=0, boot_delay=100, dtoverlay=pi3-disable-bt ahhhh heres the UART
sudo blkid && sudo lsblk # you should copy the UUID for the newly encrypted partition from blkid's output. absolute path /dev/mapper/name is untested.
# check out the partition structure to see that it updates
sudo echo "initramfs initramfs.gz followkernel" >> /mnt/config.txt 
# add ^ to EOF after [all]
sudoedit /mnt/cmdline.txt # edit the root=/ default value and separate each edit by a space on both sides between the other parameters.
root=/dev/mapper/crypt cryptdevice=/dev/mmcblk0p3:crypt  # NOTE: crypt being used over and over is from my renaming of the luksOpen partition step
# add/edit on the existing one contiguous line with one (1) space on all sides 
# to be unlocked at the root stage (root/resume devices or ones with explicit initramfs flag in /etc/crypttab)
sudoedit /etc/crypttab # sudoedit being used for security and reliability when dealing with hypersensitive files
"crypt	/dev/disk/by-uuid/5e8f28f3-bad1-47dd-b7be-5df77f2f1d82	 none	luks" 
# you probably want to copy this ^ spacing, I cross-referenced it from a few sources.
sudoedit /etc/fstab 
# this file is VERY SENSITIVE (as is the one directly above).. be careful here or you might lose all your progress and 
# the SBC UNIX box will not boot/be recoverable without cracking hashes if you type wrong.. make sure the spacing matches the existing symlinks/integers
# I chose to go with the default format and mark the path of the encrypted /dev/mapper directory by PARTUUID="", 
# second row: default 12 spaces between /boot and vfat, and third row: 16 spaces between / and ext4, so I put 20 spaces between /dev/mapper and its /,
# which signifies a rootfs slot. I matched the rest of the existing spacing, with 5 spaces between file system type (vfat/ext4) and defaults,
# 3 spaces between defaults and the first integer, 8 spaces between the first and second integers.
# OR ignore my harebrained spacing calculations and just align everything vertically where it might not matter how many spaces btwn entries.. untested
# ^^ CHANGES: add root partition to point @the encrypted partition as the 4th row with data in the file (first set of chars is symlink UUID=UUID for
# dev/mapper/crypt, comment out old root partition (line 3) so it can serve as a fallback if there are issues
# add "defaults, noatime" to end of the encrypted rootfs line before the integers.. still not sure what this does but its the default for a rootfs part
# use UUID="" gathered by "sudo blkid"to match the existing format for using PARTUUIDs, comment out existing root partition.
# DON'T USE ABSOLUTE PATH, USE UUID for /dev/mapper/crypt BC UUID IS ALSO A SYMLINK LIKE PARTUUID, while an absolute path is not the same.
# Also, at the bottom of the file:
tmpfs /var/tmp tmpfs nodev,nosuid,noatime 0 0 # these 2 lines increase the lifespan of the SD card, something about swap/RAM/a buffer/cache friendliness
tmpfs /tmp tmpfs defaults,noatime,nosuid 0 0
sudo echo "CRYPTSETUP=y" >> /etc/cryptsetup-initramfs/conf-hook # this file only starts existing when a device needs 
sudo mkinitramfs -o /mnt/initramfs.gz # creation
sudo lsinitramfs /mnt/initramfs.gz | grep -P "sbin/[cryptsetup|resize2fs|fdisk|dumpe2fs|expect]" # no idea how this much piping is helpful, v verbose
sudo lsinitramfs /mnt/initramfs.gz | grep cryptsetup # clone current sys to encrypted partition
sudo rsync -avhPHAXx --progress --exclude={/dev/*,/proc/*,/sys/*,/tmp/*,/run/*,/mnt/*,/media/*,/lost+found} / /mnt/ # now, we are done encrypting disk, unmount the encrypted partition and reboot!
sudo umount /dev/mmcblk0p3 && sudo reboot
# in the inintramfs prompt mid-boot:
cryptsetup luksOpen /dev/mmcblk0p3 crypt # again, crypt here is whatever you decide to name luksOpen, mount encrypted partition
exit # then exit the initramfs shell
sudo mkinitramfs -o /boot/initramfs.gz # after boot, we can now delete the unencrypted partition!!
sudo cfdisk /dev/mmcblk0 # delete mmcblk0p2 entirely, ADVANCED: change the start/end of the encrypted partition to the closest being block/partition 1+1
sudo sync && sudo reboot
# My secure and obfuscated ssh logon parameters..
# execute on your non SBC preferably Linux/MacOS machine:
ssh-keygen -t rsa -b 4096 # set password on this (optional)
***REMOVED*** ./key.pub hostname@static_IP_of_rpi:~/ # ssh into the rpi box now.. cd ~ or cd $HOME to be where secure copy places this public key file
mkdir -p .ssh # create .ssh directory, make parent directory as needed.
mv key.pub .ssh/ && cd .ssh
cat key.pub >> authorized_keys # obfuscate the storage of the key file on the server
rm -rf key.pub # delete og
sudo nano /etc/ssh/sshd_config # all edited & uncommented parameters are as follows:
Port xx # highly recommend uncommenting this and changing the port, bots scan the Internet for devices @port ***REMOVED***, bots used to be 82% of web traffic
PermitRootLogin no # nobody can elevate to root
PubKeyAuthentication yes
AuthorizedKeysFile      .ssh/authorized_keys .ssh/authorized_keys2 # leave as default, should just need to be uncommented
PasswordAuthentication no # this param has a dumb name, prints **.. while typing passwords instead of displaying plain psk characters as text
ChallengeResponseAuthentication no # last change/uncommented line sequentially, write quit then
sudo systemctl restart sshd

# Now, time for the hotspot guide.
sudo apt install hostapd dnsmasq
sudo systemctl unmask hostapd # hostapd is tricky, needs this &
sudo systemctl enable hostapd
sudo DEBIAN_FRONTEND=noninteractive apt install -y netfilter-persistent iptables-persistent
sudo echo $'interface br0\nstatic ip_address=10.0.0.82/24\nstatic routers=10.0.0.1\nstatic domain_name_servers=127.0.0.1\n' > /etc/dhcpcd.conf
sudo echo $'net.ipv4.tcp_syncookies=1\nnet.ipv4.ip_forward=1\n' > /etc/sysctl.d/
sudo sysctl -p /etc/sysctl.conf
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo netfilter-persistent save # persistent iptables parameters stored for usage during/after/before every reboot
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
sudo echo $'interface=wlan0 \ndhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h\ndomain=wlan\naddress=/gw.wlan/192.168.4.1\n' > .etc/dnsmasq.conf
# alias for the router
sudo rfkill unblock wlan
sudo echo $"interface=wlan0\ncountry_code=US\nssid=\nhw_mode=a\nchannel=153\nmacaddr_acl=0\nauth_algs=1\nignore_broadcast_ssid=0\nwpa=2\n***REMOVED***=\nwpa_key_mgmt=WPA-PSK\nwpa_pairwise=TKIP\nrsn_pairwise=CCMP' > /etc/hostapd/hostapd.conf
sudo systemctl reboot
sudo usermod -aG group username # I set the new group netdev for a superuser
sudo echo $'[NetDev]\nName=br0\nKind=bridge\n' > /etc/systemd/network/bridge-br0.netdev
sudo echo $'[Match]\nName=eth0\n[Network]\nBridge=br0\n' > /etc/systemd/network/br0-member-eth0.network
sudo systemctl enable systemd-networkd
sudo echo $'denyinterfaces wlan0 eth0\ninterface br0\n' > /etc/dhcpcd.conf
sudo curl -L https://install.pivpn.io | bash 
# set dns to Google, I used duckdns.org which has a instructions on the site to setup dynamic dns BEFORE running this curl command to encrypt the bridge
sudo ufw reset
sudo iptables -F && sudo iptables -X
sudo iptables -t nat -F && sudo iptables -t nat -X
sudo iptables -t mangle -F && sudo iptables -t mangle -X
sudo iptables -P INPUT ACCEPT && sudo iptables -P FORWARD ACCEPT && sudo iptables -P OUTPUT ACCEPT
sudo iptables -L
sudo ufw default deny incoming
sudo ufw allow ssh
sudo ufw enable && sudo ufw status verbose # should not crash, even on a headless setup due to the past cmd
sudo ufw allow vpn_port_number && sudo ufw allow ssh_port_no # port number selected during VPN install, and during ssh config, respectively
sudo echo $'DEFAULT_OUTPUT_POLICY="ACCEPT"\nDEFAULT_FORWARD_POLICY="ACCEPT"\n' > /etc/default/ufw # already did this in iptables, repeat for firewall to double-down
sudo ufw disable && sudo ufw enable # restart firewall
sudo echo $'net.ipv4.ip_forward=1' > etc/sysctl.d/routed-ap.conf
sudo cat /etc/sysctl.d/routed-ap.conf # ensure ipv4 is fwded, such that one can connect to the vpn bridge from anywhere
sudo service openvpn start # all ready
sudo iptables -A FORWARD -i tun0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT && sudo iptables -A FORWARD -i eth0 -o tun0 -j ACCEPT
sudo iptables -A FORWARD -i tun0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT && sudo iptables -A FORWARD -i wlan0 -o tun0 -j ACCEPT
sudo iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
sudo iptables -t nat -A PREROUTING -d DYNAMIC_DNS_IP -p tcp --dport ***REMOVED*** -j DNAT --to-dest /etc/openvpn/server.conf's_ip_addr:vpn_port_number
sudo iptables -t nat -A POSTROUTING -d /etc/openvpn/server.conf's_ip_addr -p tcp --dport ***REMOVED*** -j SNAT --to-source etc/openvpn/server.conf's_ip_addr
sudo netfilter-persistent save && sudo netfilter-persistent reload # refresh settings to be present during/after every next boot
cd /etc/init.d/ && sudo nano ./firewall.sh # triple down on firewall settings being present
sudo iptables -t nat -A POSTROUTING -s /etc/openvpn/server.conf's_ip_addr/24 -o eth0 -j MASQUERADE
sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward" # double set ipv4 packets to be fwded for sanity
sudo chmod +x /etc/init.d/firewall.sh && sudo chmod 700 /etc/init.d/firewall.sh # add script to be executable by owner, group, & others, but then disables access from other users, while issuing user/members of the superuser group still should have access (untested for members of superuser grp)
sudo update-rc.d firewall.sh defaults # enable script to config third mode of firewall @boot time.
cd ~/ovpns
sudo echo $'compress lz4' > ./hostname.ovpn
sudo cp ./hostname.ovpn ./hostname.ovpn.conf
sudo mv ./hostname.ovpn.conf /etc/ovpn/
# If you would like to securely copy the VPN for usage on any Wi-Fi which does not block port fwding, use secure copy onto a separate machine than the SBC configured during this guide. For MacOS, use the hostname displayed before the @ symbol in terminal, and the iP from Preferences
cd ~/ovpns && ***REMOVED*** ./hostname.ovpn hostname_of_machine_to_use_VPN@its_iP:~/ # places it in home directory, might need to run 
"ls -al" if the file does not show when just executing "ls"
```
