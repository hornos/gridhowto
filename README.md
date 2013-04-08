Grid Howto
==========
This howto is for CentOS based clusters. You can try the setup in VirtualBox as well, although you will lack BMC and IB features.

The following terminology is used: *client* is a remote or virtual machine you want ot provision, *host* is your machine (laptop) from which you provision and control the clients.

In the first step *root servers* are installed. Later on, root servers are used for large-scale cluster installation. We will use Space Jockey to provision root servers. Space Jockey is a very simple bootp tool, it does not compare with Cobbler or Xcat. Its main purpose is to boot and install root servers from your laptop. For this primordial installation you need OS X, nginx and dnsmasq.

Download the gridhowto:

    cd; git clone git://github.com/hornos/gridhowto.git

The following network topology is recommended. The BMC network can be on the same interface as system (eth0). The system network is used to boot and provision the cluster.

    IF   Network  Address Range
    bmc  bmc      10.0.0.0/16
    eth0 system   10.1.0.0/16
    eth1 storage  10.2.0.0/16
    eth2 mpi      10.3.0.0/16
    ethX external ?

The network configuration is found in `networks.yml`. Each network interface can be a bond. On high-performance systems storage and mpi is InfiniBand or other high-speed network. If you have less than 4 interfaces use alias networks. Separate external network form the others. An Example network topology (`networks.yml`) is:

    ---
    interfaces:
      bmc: 'eth0'
      system: 'eth0'
      storage: 'eth1'
      mpi: 'eth2'
      external: 'eth3'
      dhcp: 'eth3'
    networks:
      bmc: 10.0.0.0
      system: 10.1.0.0
      storage: 10.2.0.0
      mpi: 10.3.0.0
    masks:
      system: 255.255.0.0
    broadcasts:
      system: 10.1.255.255

### Root Servers in VirtualBox 
You can make a virtual infrastructure in VirtualBox. Create the following virtual networks:

    Network   VBox Net IPv4 Addr  Mask DHCP
    system    vboxnetN 10.1.1.254 16   off
    storage   vboxnetM 10.2.1.254 16   off
    mpi       intnet
    external  NAT/Bridged

Setup the virtual server to have 2TB of disk and 4 network cards as well as network boot enabled.

## Primordial Installation
Install boot servers on the host:

    brew install dnsmasq nginx

From now on all commands are relative to the `space` directory:

    cd $HOME/gridhowto/space

If you don't know which machine to boot you can check bootp requests from the root servers:

    ./jockey dump <INTERFACE>

where the last argument is the interface to listen on eg. vboxnet0.

The recommended way insert an installation DVD in each server and leave the disk in the drive. You can consider it as a rescue system.

Create the `boot/centos64` directory and put `vmlinuz` and `initrd.img` from the CentOS install media (`isolinux` directory). Edit the `kickstart.centos64` file if you want to customize the installatio (especially `NETWORK` and `HOSTNAME` section). Put `pxelinux.0, chain.c32` from the syslinux 4.X package into `boot`.

Set the address of the host machine (your laptop's corresponding interface). In this example 

    ./jockey host 10.1.1.254

or you can give an interface and let the script autodetect the host IP:

    ./jockey @host vboxnet5

Kickstart a MAC address with the CentOS installation:

    ./jockey centos64 08:00:27:14:68:75

You can use `-` instead of `:`. Letters are converted to lowercase.

The `centos64` command creates a kickstart file in `boot` and a pxelinux configuration in `boot/pxelinux.cfg`. It also generates a root password which you can use for the stage 2 provisioning. Edit kickstarts (`boot/*.ks` files) after kicked. Root passwords are in `*.pass` files. After you secured the install root user is not allowed to login remotely.

Finish the preparatin by starting the boot servers (http, dnsmasq) each in a separate terminal:

    ./jockey http
    ./jockey boot

Boot servers listen on the IP you specified by the `host` command. The boot process should start now and the automatic installation continues. If finished change the boot order of the machine by:

    ./jockey local 08:00:27:14:68:75

This command changes the pxelinux order to local boot. You can also switch to local boot by IPMI for real servers.

### Install from URL
Mount install media and link under `boot/centos64/repo`. Edit the kickstart file and change `cdrom` to:

    url --url http://10.1.1.254:8080/centos64/repo

Where the URL is the address of the nginx server running on the host.

### VNC-based Graphical Install
For headless installation use VNC. Edit the corresponding file in `boot/pxelinux.cfg` and set the following kernel parameters:

    APPEND vnc ...

VNC is started without password. Connect your VNC client to eg. `10.1.1.1:1`.

### Hardware Detection
For hardware detection you need to have the following files installed from syslinux:

    boot/hdt.c32

Switch to detection (and reboot the machine):

    ./jockey detect 08:00:27:14:68:75 

### Firmware Upgrade with FreeDOS
This section is based on http://wiki.gentoo.org/wiki/BIOS_Update . You have to use a Linux host to create the bootdisk image. You have to download freedos tools from ibiblio.org:

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

### Kali Linux
To perform a netinstall of Kali Linux:

    mkdir -p boot/kali
    pushd boot/kali
    curl http://repo.kali.org/kali/dists/kali/main/installer-amd64/current/images/netboot/netboot.tar.gz | tar xvzf -
    popd
    ./jockey kali 08:00:27:14:68:75

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
Install ansible on the host. Ansible should be installed into `$HOME/ansible`:

    cd $HOME
    git clone git://github.com/ansible/ansible.git

Edit your `$HOME/.bashrc`:

    source $HOME/ansible/hacking/env-setup &> /dev/null

Run the source command:

    source $HOME/.bashrc

Ansible is used to further provision root servers on the stage 2 level. Stage 2 is responsible to reach the production ready state of the grid.

From now on all commands are relative to `$HOME/gridhowto`:

    cd $HOME/gridhowto

Edit `hosts` file:

    [root]
    root-01 ansible_ssh_host=10.1.1.1
    root-02 ansible_ssh_host=10.1.1.2
    root-03 ansible_ssh_host=10.1.1.3

Check the connection:

    bin/ping root@root-01

The bootstrap playbook creates the admin wheel user. You have to bootstrap each machine separately since root passwords are different:

    ssh-keygen -f keys/admin
    pushd keys; ln -s admin root; popd
    bin/play root@root-01 bootstrap
    bin/play root@root-02 bootstrap
    bin/play root@root-03 bootstrap

The following operator shortcuts are used: `@` is `-k` and `@@` is `-k --sudo`.

Test the bootstrap:

    bin/ping admin@root

By securing the server you lock out root. Only admin is allowed to login with keys thereafter:

    bin/play @@root secure

Reboot or shutdown the machines by:

    bin/reboot @@root
    bin/shutdown @@root

Login by SSH:

    bin/ssh admin@root-01

Create a new LVM partition:

    bin/admin root run "lvcreate -l 30%FREE -n data vg_root" -k --sudo


## Basic Services
Root servers provide NTP for the cluster. If you have a very large cluster root servers talk only to satellite servers aka rack leaders. Root servers are stratum 2 time servers. Each root server broadcasts time to the system network with crypto enabled.

Install and setup basic services:

    bin/play @@root basic

Root server names are cached in `/etc/hosts.d/root`. Put DNS cache files (`/etc/hosts` like files) in `/etc/hosts.d/` and notify DNSmasq to restart. DHCP client overwrites `resolv.conf` so you have to set an interface specific conf in `etc/dhcp/` if you use DHCP (see above `networks.yml` how to specif the interface fo DHCP) Syslog-ng does cross-logging between root servers. If you use DHCP reboot the machines after the basic playbook to activate the local DNSmasq cache. Logging is done by syslog-ng on the system network.

The basic playbook contains the following inittab changes:

    tty1 - /var/log/messages
    tty2 - top by CPU
    tty3 - top by MEM
    tty4 - iostat
    tty5 - mpstat
    tty6 - gstat -a (Ganglia)
    tty7 - mingetty
    tty8 - mingetty (and X)

## Firewall
### Shorewall
Enable basic Shorewall firewall on the root servers:

    bin/play @@root shorewall

Note that emergency rules are defined in `etc/shorewall/rulestopped.j2`. Please check the `shorewall/interfaces.j2` template fiel aswell. On external services you can enable fail2ban:

    bin/play @@root fail2ban

At this point you should restart the root servers.

## Monitoring
### Ganglia
Ganglia is a scalable distributed monitoring system for high-performance computing systems such as clusters and Grids. It is based on a hierarchical design targeted at federations of clusters. You can think of it as a low-level cluster top. Ganglia is running with unicast addresses and root servers cross-monitor each other. Ganglia is a best effort monitor and you should use it to monitor as many things as possible.

    bin/play @@root ganglia

Ganglia's web intreface is at `http://root-0?/ganglia`.

The following monitors can be played:

    ganglia_diskfree
    ganglia_diskpart
    ganglia_entropy   - randomness
    ganglia_httpd     - apache
    ganglia_memcached - memcache
    ganglia_mongodb   - mongodb
    ganglia_mysql     - mysql
    ganglia_procstat  - basic service monitor
    ganglia_system    - cpu and memory statistics

### Webmin

    bin/play @@root webmin

### MariaDB with Galera
MariaDB with Galera is used for the cluster SQL service. The first root node (`root-01`) is the pseudo-master.

    bin/play @@root mariadb

Secure mysql on the first node:

    bin/play @@root-01 mariadb_secure

Install mysql tools:

    bin/play @@root mariadb_tools

The following tools are installed under `/root/bin`:

    wsrep_status - Galera wsrep status page
    mytop        - Mysql top (-p <PASSWORD>)
    mtop         - Mysql thread list (-p <PASSWORD>)
    innotop      - InnoDB statistics (-p <PASSWORD>)

You can access phpmyadmin on `http://root-0?/phpmyadmin`.

### Icinga
Install and setup Icinga:

    bin/play @@root icinga --extra-vars "schema=yes"

You can access icinga on `http://root-0?/icinga` with `icingaadmin/icingaadmin`. The new interface is on `http://root-0?/icinga-web` with `root/password`.

## Glusterfs
Glusterfs playbook creates a common directory (`/common`) on the root servers:

    bin/play @@root gluster --extra-vars "format=yes"

Login to the first server (`root-01`) and run:

    /root/gluster_bootstrap

Locally mount the common partion on all root servers:

    bin/play @@root glusterfs

### Graphite

    bin/play @@root memcache
    bin/play @@root rrdcache
    bin/play @@root graphite

## Elasticsearch & MongoDB & Graylog2
At first, you have to run with `format=yes` to create the mongodb partition under `/data/mongodb`.

    bin/play @@root rabbitmq
    bin/play @@root elasticsearch
    bin/play @@root mongodb --extra-vars "format=yes"
    bin/play @@root graylog2


## Ceph

## MariaDB with Galera

## Postgres XC

## HA Slurm

## HA XCat

  bin/play @@root-01 xcat


## Grid
### Globus
#### PKI
#### GSI-SSH
#### GridFTP
### GateONE
## Tinc VPN

### Root Server VPN

### Tinc Over TOR