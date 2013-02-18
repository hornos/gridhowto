Grid Howto
==========
This howto is for CentOS based clusters. You can try the setup in VirtualBox as well, although you will lack BMC and IB features.

Install ansible on the local client. Ansible should be installed into `$HOME/ansible`:

    cd $HOME
    git://github.com/ansible/ansible.git

Edit your `$HOME/.bashrc`:

    source $HOME/ansible/hacking/env-setup &> /dev/null

Run the source command:

    source $HOME/.bashrc

## Root servers
Install at least 2 root servers for HA. Try to use multi-master setups and avoid string heartbeat integration and floating addresses. Try to use real distributed services.

Generate root password:

    cd $HOME/ansible/plays
    bin/passwd

The following network zones are recommended for the cluster. External interfaces or gateways connect cluster forming a grid. The BMC network can be on the same interface as system. Storage and MPI is usually on InfiniBand and utilize RDMA. The system network is used to boot and provision the cluster.

    IF   Network  Address Range
    bmc  bmc      10.0.0.0/16
    eth0 system   10.1.0.0/16
    eth1 storage  10.2.0.0/16
    eth2 mpi      10.3.0.0/16
    ethX external ?

This network configuration is in `network.yml`.

## Partitions
Use HW raid for physical volumes.

    LVM Label | Mount point
    -         | /boot
    vg_rootNN
      swap    | -
      tmp     | /tmp
      var     | /var
      log     | /var/log
      home    | /home
      root    | /
      opt     | /opt

## Ansible Bootstrap
Create and edit `$HOME/ansible/hosts`:

    [root]
    root-01 ansible_ssh_host=10.1.1.1
    root-02 ansible_ssh_host=10.1.1.2

Check the connection:

    ansible root -u root -m raw -a "hostname" -k

Play the bootstrap:

    cd $HOME/ansible/plays
    ssh-keygen -f keys/admin
    ansible-playbook root bootstrap.yml -k -i hosts

Test the bootstrap:

    ansible root -m ping -u admin --private-key=keys/admin -k -i hosts

This command has a shorthand notation. From now on this notation will be used.

    bin/admin root ping -k

Secure the Server:

    bin/play root secure.yml -k --sudo

## Basic Services
### Time Service (NTP)
Root servers provide NTP for the cluster. If you have a very large cluster root servers talk only to satellite servers aka rack leaders. Root servers are stratum 2 time servers. Each root server broadcasts time to the system network with crypto enabled.