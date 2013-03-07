Grid Howto
==========
This howto is for CentOS based clusters. You can try the setup in VirtualBox as well, although you will lack BMC and IB features.

Install ansible on the local client. Ansible should be installed into `$HOME/ansible`:

    cd $HOME
    git clone git://github.com/ansible/ansible.git

Edit your `$HOME/.bashrc`:

    source $HOME/ansible/hacking/env-setup &> /dev/null

Run the source command:

    source $HOME/.bashrc

## Root servers
Install gridhowto:

    cd $HOME
    git clone git://github.com/hornos/gridhowto.git

Install at least 2 root servers for HA. Try to use multi-master setups and avoid heartbeat integration and floating addresses.

The following network topology is recommended for the cluster. The BMC network can be on the same interface as system (eth0). The system network is used to boot and provision the cluster.

    IF   Network  Address Range
    bmc  bmc      10.0.0.0/16
    eth0 system   10.1.0.0/16
    eth1 storage  10.2.0.0/16
    eth2 mpi      10.3.0.0/16
    ethX external ?

The network configuration is found in `network.yml`. Each network interface can be a bond. On high-performance systems storage and mpi is InfiniBand or other high-speed network. If you have less than 4 interfaces use alias networks. Note that

### Root servers in VirtualBox 
You can make a virtual infrastructure in VirtualBox. Create the following virtual networks:

    Network   VBox Net IPv4 Addr  Mask DHCP
    system    vboxnetN 10.1.1.254 16   off
    storage   vboxnetM 10.2.1.254 16   off
    mpi       intnet
    external  NAT/Bridged

Setup the virtual server to have 2TB of disk 4 network cards and network boot enabled.

## Primordial Installation
Space jockey is a very simple bootp tool. It does not compare with Cobbler or Xcat. Its main purpose is to boot and install minimal servers from your laptop, it is an entry point. Later on the root servers are used for large-scale cluster installation. You can configure root servers by ansible. In the 2nd stage Xcat or Cobbler is installed by a playbook and used to provision the compute cluster. For the primordial installation you need OS X, nginx and a dnsmasq server. To install the boot servers:

    brew install dnsmasq nginx

From now on all commands are relative to the `jockey` directory:

    cd $HOME/gridhowto/space

If you don't know which machine to boot you can check bootp requests from the root servers by:

    ./jockey dump IF

where IF is the interface to listen on eg. vboxnet0.

DNSmasq is an all-inclusive DNS/DHCP/BOOTP server. Its configuration is found in the `masq` file. Edit the `ROOT SERVER BOOTP` section is you want static assignment, eg:

    dhcp-host=08:00:27:14:68:75,10.1.1.1,infinite

The recommended way is to put an installation DVD in each server and leave the disk in the server. You can consider it as a rescue system which is always available. All you need now is to bootstrap the installer.

Create the `boot/centos6.3` directory and put `vmlinuz` and `initrd.img` from the CentOS install media. Edit the `kickstart` file to customize the installation, especially `NETWORK` and `HOSTNAME` section. Put `pxelinux.0, chain.c32` from the syslinux 4.X package into `boot`.

Set the address of the host machine (your laptop's corresponding interface), eg.:

    ./jockey host 10.1.1.254

Kickstart a MAC address with the installation, eg.:

    ./jockey kick 08:00:27:14:68:75

The `kick` command creates a kickstart file in `boot` and a pxelinux configuration in `boot/pxelinux.cfg`. It also generates a root password which you can use for the stage 2 provisioning. Edit kickstarts (`boot/*.ks` files) after kicked. Root passwords are in `*.pass` files.

Finish the preparatin by starting the boot servers (http, dnsmasq) each in a separate terminal:

    ./jockey http
    ./jockey boot

Boot servers listen on the IP you specified by the `host` command. The boot process should start now and the automatic installation continues. If finished change the boot order of the machine by:

    ./jockey local 08:00:27:14:68:75

This command changes the pxelinux to local boot. Switch IPMI to local boot for real servers.

### Install from URL
Mount install media and link to under `boot/centos6.3/repo`. Edit the kickstart file and change `cdrom` to:

    url --url http://10.1.1.254:8080/centos6.3/repo

### VNC-based Graphical Install
For headless installation use VNC. Edit the corresponding file in `boot/pxelinux.cfg` and set the following kernel parameters:

    APPEND vnc ...

VNC is started without password. Connect your VNC client to eg. `10.1.1.1:1`.

### Hardware Detection
For syslinux HW detection you need `boot/hdt.c32`

Switch to detection by:

    ./jockey detect 08:00:27:14:68:75 

### Firmware Upgrade with FreeDOS
This section is based on http://wiki.gentoo.org/wiki/BIOS_Update . You have to use a linux host to create the bootdisk image. You have to download freedos tools from ibiblio.org:

    dd if=/dev/zero of=freedos bs=1024 count=20480
    mkfs.msdos freedos
    unzip sys-freedos-linux.zip && ./sys-freedos.pl --disk=freedos
    mkdir $PWD/mnt; mount -o loop freedos /mnt

Copy the firmware upgrade files to `$PWD/mnt` and umount the disk. Put `memdisk` and `freedos` to `boot` directory and switch to firmware (and reboot the machine):

    ./jockey firmware 08:00:27:14:68:75

### Install ESXi 5.X
You have to use syslinux 4.X . Mount ESXi install media under `boot/esxi/repo`. Put `mboot.c32` from the install media into jockey's root directory. Kickstart the machine to boot ESXi installer:

    ./jockey esxi 08:00:27:14:68:75

Edit the kickstart file if you want to change the default settings.

### Other Mini-Linux Variants
You can boot Cirros and Tiny Linux as well. For CirrOS put `initrd.img` and `vmlinuz` into `boot/cirros`, for Tiny Linux put `core.gz` and `vmlinuz` into `boot/tiny`, and switch eg. to Tiny:

    ./jockey tiny 08:00:27:14:68:75

### Kickstart from scratch
A good starting point for a kickstart can be found in the EAL4 package:

    cd src
    wget ftp://ftp.pbone.net/mirror/ftp.redhat.com/pub/redhat/linux/eal/EAL4_RHEL5/DELL/RPMS/lspp-eal4-config-dell-1.0-1.el5.noarch.rpm
    rpm2cpio lspp-eal4-config-dell-1.0-1.el5.noarch.rpm | cpio -idmv

## IPMI Basics
If you happen to have real metal servers you need to deal with IPMI as well. Enterprise class machiens contain a small computer which you can use to remote control the machine. IPMI interfaces connect to the bmc network. Install ipmitools:

    brew install ipmitool

You can register IPMI users with different access levels. Connect to the remote machine with the default settings:

    ipmitool -I lanplus -U admin -P admin -H <BMC IP>

Get a remote remote console:

    xterm -e "ipmitool -I lanplus -U admin -P admin -H <BMC IP> sol activate"

Get sensor listing:

    ipmitool -I lanplus -U admin -P admin -H <BMC IP> sdr

### IPMI Management with Space Jockey
Setup IPMI adresses according to the network topology. Dip OS X into the IPMI LAN:

    sudo ifconfig en0 alias 10.0.1.254 255.255.0.0

Set the IPMI user and password:

    ./jockey ipmi user admin admin

Get a serial-over-lan console:

    ./jockey ipmi tool 10.0.1.1 sol active

Get the power status:

    ./jockey ipmi tool 10.0.1.1 chassis status
Reboot a machine:

    ./jockey ipmi tool 10.0.1.1 power reset

Force PXE boot on the next boot only:

    ./jockey ipmi tool 10.0.1.1 chassis bootdev pxe

Reboot the IPMI card:

    ./jockey ipmi tool 10.0.1.1 mc reset cold

Get sensor output:

    ./jockey ipmi tool 10.0.1.1 sdr list

Get the error log:

    ./jockey ipmi tool 10.0.1.1 sel elist

### The Parallel Genders Trick

## InfiniBand Basics
InfiniBand is a switched fabric communications link used in high-performance computing and enterprise data centers. If you need RDMA you need InfiniBand. You have to run the subnet manager (OpenSM) which assigns Local IDentifiers (LIDs) to each port connected to the InfiniBand fabric, and develops a routing table based off of the assigned LIDs.There are two types of SMs, software based and hardware based. Hardware based subnet managers are typically part of the firmware of the attached InfiniBand switch. Buy a switch with HW-based SM.



## Ansible Bootstrap
Ansible is used to further provision root servers on the stage 2 level. Stage 2 is responsible to reach the production ready state of the grid.

From now on all commands are relative to `$HOME/gridhowto`:

    cd $HOME/gridhowto

Edit `hosts` file:

    [root]
    root-01 ansible_ssh_host=10.1.1.1
    root-02 ansible_ssh_host=10.1.1.2

Check the connection:

    ansible root-01 -i hosts -m raw -a "hostname" -u root -k

The bootstrap playbook creates the admin wheel user:

    ssh-keygen -f keys/admin
    bin/play root-01 bootstrap.yml -k -u root
    bin/play root-02 bootstrap.yml -k -u root

Test the bootstrap:

    bin/admin root ping -k

By securing the server you lock out root. Only admin is allowed to login with keys:

    bin/play root secure.yml -k --sudo

Reboot or shutdown the machines by:

    bin/reboot root -k
    bin/shutdown root -k

Create a new LVM partition:

    bin/admin root run "lvcreate -l 30%FREE -n data vg_root" -k --sudo


## Basic Services
Root servers provide NTP for the cluster. If you have a very large cluster root servers talk only to satellite servers aka rack leaders. Root servers are stratum 2 time servers. Each root server broadcasts time to the system network with crypto enabled.

Basic services contain NTP, Rsyslog and DNSmasq hosts cache:

    bin/play root basic.yml -k --sudo

Root server names are cached in `/etc/hosts.d/root`. Put DNS cache files (hosts) in `/etc/hosts.d` and notify dnsmasq to reload.

### Enable Repositories and install basic packages
The first command enables the EPEL repository, the 2nd command installs node.js and Supervisor.

    bin/play root repo.yml -k --sudo
    bin/play root nodejs.yml -k --sudo

### Firewall

    bin/play root firewall.yml -k --sudo

## Tinc VPN

### Root Server VPN


### Tinc Over TOR

## Ganglia

## Cluster FS 1

### Glusterfs

### DRBD

## HA Mysql

## HA Slurm

## HA XCat

## Grid
### Globus
#### PKI
#### GSI-SSH
#### GridFTP
### GateONE