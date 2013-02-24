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

The following network topology is recommended for the cluster. The BMC network can be on the same interface as system (eth0). Storage and MPI is usually on InfiniBand for RDMA. The system network is used to boot and provision the cluster.

    IF   Network  Address Range
    bmc  bmc      10.0.0.0/16
    eth0 system   10.1.0.0/16
    eth1 storage  10.2.0.0/16
    eth2 mpi      10.3.0.0/16
    ethX external ?

The network configuration is found in `network.yml`.

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

    cd $HOME/gridhowto/jockey

If you don't know which machine to boot you can check bootp requests from the root servers by:

    ./control dump IF

where IF is the interface to listen on eg. vboxnet0.

DNSmasq is an all-inclusive DNS/DHCP/BOOTP server. Its configuration is found in the `masq` file. Edit the `ROOT SERVER BOOTP` section is you want static assignment, eg:

    dhcp-host=08:00:27:14:68:75,10.1.1.1,infinite

The recommended way is to put an installation DVD in each server and leave the disk in the server. You can consider it as a rescue system which is always available. All you need now is to bootstrap the installer.

Create the `boot/centos6.3` directory and put `vmlinuz` and `initrd.img` from the CentOS install media. Edit the `kickstart` file to customize the installation, especially `NETWORK` and `HOSTNAME` section. Put `pxelinux.0, ldlinux.c32, chain.c32` from the syslinux package into `boot`.

Set the address of the host machine (your laptop's corresponding interface), eg.:

    ./control host 10.1.1.254

Kickstart a MAC address with the installation, eg.:

    ./control kick 08:00:27:14:68:75

The `kick` command creates a kickstart file in `boot` and a pxelinux configuration in `boot/pxelinux.cfg`. It also generates a root password which you can use for the stage 2 provisioning. Edit kickstarts after kicked. Root passwords are in `*.pass` files.

Finish the preparatin by starting the boot servers (http, dnsmasq) each in a separate terminal:

    ./control http
    ./control boot

Boot servers listen on the IP you specified by the `host` command. The boot process should start now and the automatic installation continues. If finished change the boot order of the machine by:

    ./control local 08:00:27:14:68:75

This command changes the pxelinux to local boot. Switch IPMI to local boot for real servers.

### Install from URL
Mount install media and link to under `boot/centos6.3/repo`. Edit the kickstart file and change `cdrom` to:

    url --url http://10.1.1.254:8080/centos6.3/repo

### VNC-based Graphical Install
For headless installation use VNC. Edit the corresponding file in `boot/pxelinux.cfg` and set the following kernel parameters:

    APPEND vnc ...

VNC is started without password. Connect your VNC client to eg. `10.1.1.1:1`.

### Hardware Detection
For syslinux HW detection you need the following files:

    boot/hdt.c32
    boot/libcom32.c32
    boot/libgpl.c32
    boot/libmenu.c32
    boot/libutil.c32
    boot/hdt/pci.ids

Switch to detection by:

    ./control detect 08:00:27:14:68:75 

### Basic IPMI Management
Setup IPMI adresses according to the network topology. Dip OS X into the IPMI LAN:

    sudo ifconfig en0 alias 10.0.1.254 255.255.0.0

Set the IPMI user and password:

    ./control ipmi user admin admin

Get a serial-over-lan console:

    ./control ipmi tool 10.0.1.1 sol active

Get the power status:

    ./control ipmi tool 10.0.1.1 chassis status
Reboot a machine:

    ./control ipmi tool 10.0.1.1 power reset

Force PXE boot on the next boot only:

    ./control ipmi tool 10.0.1.1 chassis bootdev pxe

Reboot the IPMI card:

    ./control ipmi tool 10.0.1.1 mc reset cold

Get sensor output:

    ./control ipmi tool 10.0.1.1 sdr list

Get the error log:

    ./control ipmi tool 10.0.1.1 sel elist


### Kickstart from scratch
A good starting point for a kickstart can be found in the EAL4 package:

    cd src
    wget ftp://ftp.pbone.net/mirror/ftp.redhat.com/pub/redhat/linux/eal/EAL4_RHEL5/DELL/RPMS/lspp-eal4-config-dell-1.0-1.el5.noarch.rpm
    rpm2cpio lspp-eal4-config-dell-1.0-1.el5.noarch.rpm | cpio -idmv

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
### Time Service
Root servers provide NTP for the cluster. If you have a very large cluster root servers talk only to satellite servers aka rack leaders. Root servers are stratum 2 time servers. Each root server broadcasts time to the system network with crypto enabled.

Basic services contain NTP, Rsyslog and DNSmasq hosts cache:

    bin/play root basic.yml -k --sudo

Root server names are cached in `/etc/hosts.d/root`.

### Log Service

### Firewall

### Ganglia

### Glusterfs

### DRBD

### Mysql cluster
