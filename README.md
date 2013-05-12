Grid Howto
==========
This howto is for CentOS based clusters. You can try the setup in VirtualBox as well, although you will lack BMC and IB features.

The following terminology is used: *client* is a remote or virtual machine you want ot provision, *host* is your machine (laptop) from which you provision and control the clients.

In the first step *root servers* are installed. Later on, root servers are used for large-scale cluster installation. We will use Space Jockey to provision root servers. Space Jockey is a very simple bootp tool, it does not compare with Cobbler or Xcat. Its main purpose is to boot and install root servers from your laptop. For this primordial installation you need OS X, nginx and dnsmasq.

Download the gridhowto:

    cd; git clone git://github.com/hornos/gridhowto.git

The following network topology is recommended. The BMC network can be on the same interface as system (eth0). The system network is used to boot and provision the cluster.

    IF   Network  Address Range
    bmc  bmc      10.0.0.0/16 (eth0)
    eth0 system   10.1.0.0/16
    eth1 storage  10.2.0.0/16
    eth2 mpi      10.3.0.0/16
    ethX external ?

The network configuration is found in `networks.yml`. Each network interface can be a bond. On high-performance systems storage and mpi is InfiniBand or other high-speed network. If you have less than 4 interfaces use alias networks. Separate external network form the others. The simplified network topology contains only two interfaces (eth0, eth1). This is also a good model if you have InfiniBand (IB) since TCP/IP is not required for IB RDMA.

    IF   Network  Address Range
    bmc  bmc      10.0.0.0/16 (eth0)
    eth0 system   10.1.0.0/16
    eth1 external ?

and the `networks.yml` file:

    ---
    interfaces:
      bmc: 'eth0'
      system: 'eth0'
      external: 'eth1'
      dhcp: 'eth1'
    networks:
      bmc: 10.0.0.0
      system: 10.1.0.0
    masks:
      system: 255.255.0.0
    broadcasts:
      system: 10.1.255.255
    sysops:
      - 10.1.1.254
    master: root-01

The `sysops` contains remote OS X administrator machines. Leave chefs and knives alone in the kitchen!

### Root Servers in VirtualBox 
You can make a virtual infrastructure in VirtualBox. Create the following virtual networks:

    Network   VBox Net IPv4 Addr  Mask DHCP
    system    vboxnetN 10.1.1.254 16   off
    storage   vboxnetM 10.2.1.254 16   off
    mpi       intnet
    external  NAT/Bridged

Setup the virtual server to have 2TB of disk and 4 network cards as well as network boot enabled. In the restricted mode you need `system` and `external`.

## Primordial Installation
Space Jockey is a Cobbler like bootstrap mechanism designed for OS X users. The main goal is to provide an easy and simple tool for laptop-based installs. You should be able to install and configure a cluster grid from scratch with a MacBook. Leave vagrants alone as well!

Install boot servers on the host:

    brew install dnsmasq nginx

### VM Grinder
You can create a VM by the following command:

    bin/vm create <NAME>

### Space Jockey

Jockey has the following command structure:

    bin/jockey [@]CMD [@]ARGS

If you don't know which machine to boot you can check bootp requests from the root servers:

    bin/jockey dump <INTERFACE>

where the last argument is the interface to listen on eg. vboxnet0.

The recommended way insert an installation DVD in each server and leave the disk in the drive. You can consider it as a rescue system.

Create the `boot/centos64` directory and put `vmlinuz` and `initrd.img` from the CentOS install media (`isolinux` directory). Edit the `kickstart.centos64` file if you want to customize the installatio (especially `NETWORK` and `HOSTNAME` section). Put `pxelinux.0, chain.c32` from the syslinux 4.X package into `boot`.

Set the address of the host machine (your laptop's corresponding interface). In this example 

    bin/jockey host 10.1.1.254

or you can give an interface and let the script autodetect the host IP:

    bin/jockey @host vboxnet5

Kickstart a MAC address with the CentOS installation:

    bin/jockey centos64 08:00:27:14:68:75

You can use `-` instead of `:`. Letters are converted to lowercase.

The `centos64` command creates a kickstart file in `boot` and a pxelinux configuration in `boot/pxelinux.cfg`. It also generates a root password which you can use for the stage 2 provisioning. Edit kickstarts (`boot/*.ks` files) after kicked. Root passwords are in `*.pass` files. After you secured the install root user is not allowed to login remotely.

Finish the preparatin by starting the boot servers (http, dnsmasq) each in a separate terminal:

    bin/jockey http
    bin/jockey boot

Boot servers listen on the IP you specified by the `host` command. The boot process should start now and the automatic installation continues. If finished change the boot order of the machine by:

    bin/jockey local 08:00:27:14:68:75

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

    bin/jockey detect 08:00:27:14:68:75 

### Firmware Upgrade with FreeDOS
This section is based on http://wiki.gentoo.org/wiki/BIOS_Update . You have to use a Linux host to create the bootdisk image. You have to download freedos tools from ibiblio.org:

    dd if=/dev/zero of=freedos bs=1024 count=20480
    mkfs.msdos freedos
    unzip sys-freedos-linux.zip && ./sys-freedos.pl --disk=freedos
    mkdir $PWD/mnt; mount -o loop freedos /mnt

Copy the firmware upgrade files to `$PWD/mnt` and umount the disk. Put `memdisk` and `freedos` to `boot` directory and switch to firmware (and reboot the machine):

    bin/jockey firmware 08:00:27:14:68:75

### Install ESXi 5.X
You have to use syslinux 4.X . Mount ESXi install media under `boot/esxi/repo`. Put `mboot.c32` from the install media into jockey's root directory. Kickstart the machine to boot ESXi installer:

    bin/jockey esxi 08:00:27:14:68:75

or the name of the VM:

    bin/jockey esxi @<VM>

Edit the kickstart file if you want to change the default settings.

### Other Mini-Linux Variants
You can boot Cirros and Tiny Linux as well. For CirrOS put `initrd.img` and `vmlinuz` into `boot/cirros`, for Tiny Linux put `core.gz` and `vmlinuz` into `boot/tiny`, and switch eg. to Tiny:

    bin/jockey tiny 08:00:27:14:68:75

### Kali Linux
To perform a netinstall of Kali Linux:

    mkdir -p boot/kali
    pushd boot/kali
    curl http://repo.kali.org/kali/dists/kali/main/installer-amd64/current/images/netboot/netboot.tar.gz | tar xvzf -
    popd
    bin/jockey rawkali 08:00:27:14:68:75

If you want a kickstart based unattended install:

    bin/jockey kali 08:00:27:14:68:75

### Kickstart from scratch
A good starting point for a kickstart can be found in the EAL4 package:

    cd src
    wget ftp://ftp.pbone.net/mirror/ftp.redhat.com/pub/redhat/linux/eal/EAL4_RHEL5/DELL/RPMS/lspp-eal4-config-dell-1.0-1.el5.noarch.rpm
    rpm2cpio lspp-eal4-config-dell-1.0-1.el5.noarch.rpm | cpio -idmv

### Debian Linux
The installer pulls packages form the Internet. Download the latest netboot package:

    pushd boot
    rsync -avP ftp.us.debian.org::debian/dists/wheezy/main/installer-amd64/current/images/netboot/ ./wheezy
    popd

If you have more than one interface in the VM set the interface for the internet:

    echo "interface=eth1" >> .host

Set the machine for bootstrap:

    bin/jockey wheezy 08:00:27:14:68:75

Edit the actual kickstart and start the VM.

### Ubuntu Linux
Download the latest netboot package:

    pushd boot
    rsync -avP archive.ubuntu.com::ubuntu/dists/quantal/main/installer-amd64/current/images/netboot/ ./quantal
    popd

Set the machine for bootstrap:

    bin/jockey quantal 08:00:27:14:68:75

Edit the actual kickstart and start the VM.

### Create Coursera Ubuntu VM from scratch
Create a `hostonly` network wit the following parameters: `10.1.0.0/255.255.0.0`. The host machine is at `10.1.1.254`. The default IP for a guest is `10.1.1.1`. The 3rd command sets IP and hostname explicitly (`10.1.1.1` and `scicomp`).

    cd $HOME/gridhowto
    bin/vm create scicomp
    bin/jockey raring @scicomp 10.1.1.1 scicomp
    bin/jockey http
    bin/jockey boot
    bin/vm start scicomp
    (when finished)
    bin/vm off scicomp
    bin/vm boot scicomp disk
    bin/vm start @scicomp

Edit the `hosts` file and put the following section:

    [root]
    scicomp ansible_ssh_host=10.1.1.1

Check the root password that you need for the bootstrap process:

    bin/password @scicomp

Setup `sysop` key if you do not have one by:

    ssh-keygen -f keys/sysop
    pushd keys; ln -s sysop root; popd
    bin/play root@scicomp bootstrap

You need the follwing key as well for intra-cluster root logins (do not give password):

    ssh-keygen -f keys/nopass

Secure the installation and reboot

    bin/play @@scicomp secure

Finally, play the Coursera scicomp provision:

    bin/play @@scicomp coursera_scicomp

Login to the machine and kickstart:

    bin/ssh @@scicomp
    cd uwhpsc/lectures/lecture1
    make plots; firefox *.png

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
This is a blueprint of a HA *grid engine cluster*. It enables you rapid prototyping of fractal infrastructures. First, install Ansible on your host machine (VirtualBox host). The goal of the primordial installation is to provision the machines into an *initial ground state*. Ansible is responsible to advance the system to the *true ground state*. Subsequently, the system can excite itself into an *excited state* via *self-interaction*.

Every playbook is an *operator product* aka tasks evaluated in a row. In order to invert the product you have to change the order and *invert* each task individually:

    (AB)^-1 = B^-1 A^-1

By keeping this in mind it is pretty easy rollback or change a playbook. Playbooks are usually *Linux agnostic* and *holistic*.

Ansible should be installed in `$HOME/ansible`:

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

Check the ansible setup variables:

    bin/setup root@root-01

The bootstrap playbook creates the admin wheel user. You have to bootstrap each machine separately since root passwords are different:

    ssh-keygen -f keys/sysop
    pushd keys; ln -s sysop root; popd
    bin/play root@root-01 bootstrap
    bin/play root@root-02 bootstrap
    bin/play root@root-03 bootstrap

The following operator shortcuts are used: `@` is `-k` and `@@` is `-k --sudo`. On Debian like systems the `wheel` group is created.

Test the bootstrap:

    bin/ping @@root

Intra root server logins need a passwordless root key. This key is used only for and to the root servers. External root or passwordless login is not allowed. Generate the root key by:

    ssh-keygen -C "root" -f keys/nopass

The `ssh_server` playbook included in `secure` installs this key on the root server. You can reinstall the SSH key by:

    bin/play @@root ssh_server --tags key

By securing the server you lock out root. Only admin is allowed to login with keys thereafter:

    bin/play @@root secure

Reboot or shutdown the machines by:

    bin/reboot @@root
    bin/shutdown @@root

Login by SSH:

    bin/ssh admin@root-01

Create a new LVM partition:

    bin/admin root run "lvcreate -l 30%FREE -n data vg_root" -k --sudo

## Basic Setup
Root servers provide NTP for the cluster. If you have a very large cluster root servers talk only to satellite servers aka rack leaders. Root servers are stratum 2 time servers. Each root server broadcasts time to the system network with crypto enabled.

Set SELinux premissive mode and setup EPEL and rpmforge repositories for RedHat like systems:

    ./play @@root basic_redhat

or one by one:

    ./play @@root basic_selinux
    ./play @@root basic_repos

For Debian-based systems you have to skip these playbooks.

### Firewall
Play firewall-related scripts by:

    ./play @@root firewall

or one by one. Due to some IPset related bug Shorewall failes to start at first. Reboot the machines and rerun the `firewall` playbook.

Use IP sets everywhere and everytime and do not restart the firewall. Check templates in `etc/ipset.d` for ip lists. Enable IP sets and the Shorewall firewall:

    ./play @@root shorewall_ipset
    ./play @@root shorewall

Emergency rules are defined in `etc/shorewall/rutestopped.j2` and should contain an SSH access rule. UPNP client support is on by default.

#### IP Sets
The following lists are defines by default (ground state):

    blacklist  - always DROP
    whitelist  - allow some service on the external network
    root       - always ALLOW
    sysop      - allow some service on the system network
    friendlist - allow some service with timeout

The `friendlist` is populated by *interactions* via general purpose UPNP (GPUPNP). You can provide services for shared secret circles for a limited time.

#### Fail2ban
Fail2ban is protecting SSH by default.

    ./play @@root fail2ban

The system network is not banned.

#### GeoIP

    ./play @@root geoip

### Basic Services
You can run all the basic playbooks at once (takes several minutes):

    ./play @@root basic

or one by one. Setup basic services: DNSmasq, NTP, Syslog-ng:

    ./play @@root basic_services

If you use DHCP in order to enable the localhost DNS reboot the machine(s) now by `bin/reboot @@root`.

Install some packages:

    ./play @@root basic_packages
    ./play @@root basic_python

Install top-like apps:

    ./play @@root basic_tops

Install apache and setup status page:

    ./play @@root basic_httpd

Enable PHP system information:

    ./play @@root phpsysinfo

Install basic tools:

    ./play @@root basic_tools

You can we machine logs in on one multitail screen (on a node):

    bin/syslog

or check a node's top by:

    bin/systop root-03

Finally, the basic configuration:

    ./play @@root basic_config

and reboot:

    bin/reboot @@root

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

## Admin panels
### Webmin

    ./play @@root webmin

### Ajenti

    ./play @@root ajenti

## Globus
Install the certificate utilities and Globus on your mac:

    make globus_simple_ca globus_gsi_cert_utils

There is a hash mismatch between OpenSSL 0.9 and 1.X. Install newer OpenSSL on your mac. You can use the [NCE module/package manager](https://github.com/NIIF/nce). Load the Globus and the new OpenSSL environment:

    module load globus openssl

The Grid needs a PKI, which protects access and the communication. You can create as many CA as you like. It is advised to make many short-term flat CAs. Edit grid scripts as well as templates in `share/globus_simple_ca` if you want to change key parameters. Create a Root CA:

    bin/ca create <CA> [days] [email]

The new CA is created under the `ca/<ID>` directory. The CA certificate is installed under `ca/grid-security` to make requests easy. If you compile Globus with the old OpenSSL (system default) you have to use old-style subject hash. Create old CA hash by:

    bin/ca oldhash

Request & sign host certificates:

    bin/ca host <CA> <FQDN>
    bin/ca sign <CA> <FQDN>

Certs, private keys and requests are in `ca/<CA>/grid-security`. There is also a `ca/<CAHASH>` directory link for each CA. You have to use the `<CAHASH>` in the playbooks. Edit `globus_vars.yml` and set the default CA hash.

Create and sign the sysop cert:

    bin/ca user <CA> sysop "System Operator"
    bin/ca sign <CA> sysop

In order to use `sysop` as a default grid user you have to copy cert and key into the `keys` directory:

    bin/ca keys <CA> sysop

Create a pkcs12 version if you need for the browser (this command works in the `keys` directory):

    bin/ca p12 sysop

Test your user certificate:

    bin/ca verify rootca sysop

### Certificates
Install Globus on the root servers:

    ./play @@root globus

Install CA certificates, host key and host cert:

    ./play @@root globus_ca

Install the Gridmap file. Get the `sysop` DN and edit `globus_vars.yml`:

    bin/ca subject <CA> sysop
    ./play @@root globus_gridmap

### GSI SSH
This command starts GSI SSH on port 2222:

    ./play @@root globus_ssh

Test GSI SSH from OS X by `shf3` since it is the best CLI tool for SSH stuff. Check DNS resolution, client and host should resolv the root server names. Other users should be created by LDAP.

### Grid FTP

### Globus Online

### Apache with Globus cert
You can use the Globus PKI for Apache SSL (the default CA is used):

    bin/play @@root globus_httpd

### Ajenti with Globus cert

    bin/play @@root globus_ajenti

## SSH
### GateONE
### Mosh

## LDAP
auto home, limits

## Monitoring
Monitoring (Ganglia and PCP) can be played by:

    ./play @@root monitors

### Ganglia
Ganglia is a scalable distributed monitoring system for high-performance computing systems such as clusters and Grids. It is based on a hierarchical design targeted at federations of clusters. You can think of it as a low-level cluster top. Ganglia is running with unicast addresses and root servers cross-monitor each other. Ganglia is a best effort monitor and you should use it to monitor as many things as possible.

    ./play @@root ganglia

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

Install topcoat header temlpate:

    ./play @@root ganglia_topcoat

### SGI PCP
SGI's PCP is a very matured performance monitoring tool especially designed for high-performance systems. Install PCP by:

    ./play @@root pcp

PCP contains an automated reasoning deamon (`pmie`) which you can use to throw system exceptions caught by eg. Errbit or broadcasted via an MQ.

### Tops & Logs
The `basic_tools` playbook installs several small wrappers for simple cluster monitoring. The following commands are available:

    systop        - htop with node arg (eg. systop root-03)
    syslog        - Cluster logs
    httplog       - Apache logs
    netlog        - IPv4 connections and Shorewall logs
    kernlog       - Kernel and security
    auditlog      - Audit and security
    yumlog        - Yum and package realted logs
    slurmlog      - All Slurm on a node
    slurmdlog     - Slurm execute daemons
    slurmdbdlog   - HA Slurm database servers
    slurmctldlog  - HA Slurm controller servers
    galeralog     - HA Mysql wsrep

### Sensu
Install RabbitMQ and Redis

    ./play @@root rabbitmq
    ./play @@root redis

## Databases
### MariaDB with Galera
MariaDB with Galera is used for the cluster SQL service. The first root node (`root-01`) is the pseudo-master. Edit `networks.yml` to change master host.

    ./play @@root mariadb

Secure mysql (delete test database and set root password):

    ./play @@root mariadb_secure

Install mysql tools:

    ./play @@root mariadb_tools

The following tools are installed under `/root/bin`:

    wsrep_status - Galera wsrep status page
    mytop        - Mysql top (-p <PASSWORD>)
    mtop         - Mysql thread list (-p <PASSWORD>)
    innotop      - InnoDB statistics (-p <PASSWORD>)

You can access phpmyadmin on `http://root-0?/phpmyadmin`. The default user/pass is `root/root`.

When shit happens Galera state can be reset by:

    bin/play @@root-03 mariadb_reset

Enable Ganglia mysql monitor:

    bin/play @@root ganglia_mysql

### Icinga
Install and setup Icinga:

    bin/play @@root icinga --extra-vars "schema=yes"

You can access icinga on `http://root-0?/icinga` with `icingaadmin/icingaadmin`. The new interface is on `http://root-0?/icinga-web` with `root/password`. Parameters are in `icinga_vars.yml`.

## Messaging
### RabbitMQ Cluster

    bin/play @@root rabbitmq

Switch on Ganglia monitors for the local MQ:

    bin/play @@root ganglia_rabbitmq.yml

## Cluster Filesystems
### Bittorrent Sync
Sharing is caring, even among root servers:

    ./play btsync

### Gluster
Switch to the mainline kernel and reboot:

    ./play @@root kernel_ml

Glusterfs playbook creates a common directory (`/common`) on the root servers:

    ./play @@root gluster --extra-vars "format=yes"

Login to the first server (`root-01`) and run:

    /root/gluster_bootstrap

Locally mount the common partion on all root servers:

    ./play @@root glusterfs

If you have to replace a failed node eg. `root-03 (10.1.1.3)` check the peer uuid:

    grep 10.1.1.3 /var/lib/glusterd/peers/* | sed s/:.*// | sed s/.*\\///

Play the gluster_replace playbook with the uuid you get from the previous command:

    ./play @@root-03 gluster_replace --extra-vars "uuid=<UUID>"

and mount

    ./play @@root-03 glusterfs

Install SNMP and `gtop` for monitoring:

    ./play @@root snmp
    ./play @@root gluster_gtop

### Fraunhofer FS (FhGFS)

    ./play @@root fhgfs

### Ceph

    bin/play @@root ceph --extra-vars "format=yes"

Login to the first server (`root-01`) and run:

    /root/ceph_bootstrap

    service ceph -a start

Reformat everything and start over. Warning all data is lost:

    bin/play @@root ceph --extra-vars \"format=yes clean=yes umount=yes\"

and rerun bootstrap and start. Mount ceph by fuse:

    ceph-fuse -m $(hostname) /common

## Slurm
Slurm is a batch scheduler for the cluster with `low` `normal` and `high` queues. First you have to create a munge key to protect authentication:

    dd if=/dev/random bs=1 count=1024 > etc/munge/munge.key

Install and setup Slurm:

    ./play @@root slurm

The first root node is the master and the 2nd is the backup controller for `slurmctld` and `slurmdbd`. The common state directory is `/common/slurm`. Failover timeout is 60 s.

## Warewulf Cluster
Warewulf cluster manager is a simple yet powerful cluster provision toolkit. It support stateless installation of compute nodes. The `compute` PIset is defined in `networks.yml`. Install and setup Warewulf:

    ./play @@root warewulf

Install tools:

    ./play @@root warewulf_tools

Create provision directory on one of the root servers:

    wwmkchroot sl-6 /common/warewulf/chroots/sl-6

Edit the following files and set a root password in the `shadow` and `passwd` and create the VNFS image:

    wwvnfs --chroot /common/warewulf/chroots/sl-6

Later, if you want to rebuild the VNFS image:

    wwvnfs sl-6

Install the kernel:

    /root/bin/wwyum sl-6 install kernel

Bootstrap the kernel:

    wwbootstrap --chroot=/common/warewulf/chroots/sl-6 2.6.32-358.el6.x86_64

Provision a node:

    wwsh node new n0000 --netdev=eth0 --hwaddr=<MACADDR> -I 10.1.1.21 -G 10.1.1.254 --netmask=255.255.255.0
    wwsh provision set n0000 --bootstrap=2.6.32-358.el6.x86_64 --vnfs=sl-6

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

## Postgres XC

## HA XCat

  bin/play @@root-01 xcat

## VPN
### Tinc VPN

### SoftEther
### OpenVPN

## Gateway Howto
The *gateway* is Ubuntu-based home server, in particular a Zotac mini PC. You have to modify `space/.host` file to be able to inject machines on the local network, eg.:

    listen_addresses="192.168.1.192"
    router=192.168.1.1
    # for the kickstart
    http_listen="192.168.1.192:8080"

IP of your OS X is in the `listen_addresses` list.

Kickstart the gateway:

    bin/jockey gateway 08:00:27:fb:2f:1d

The installer initiates the network console and waits for an SSH login to continue. After reboot you have to run the following playbooks:

    ./play root@gateway bootstrap
    ./play @@gateway secure
    ./play @@gateway homewall
    ./play @@gateway basic_home
    ./play @@gateway ajenti_home
