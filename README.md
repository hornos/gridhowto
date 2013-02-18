Grid Howto
==========
## Root servers
Generate root password:

    curl "https://www.random.org/strings/?num=1&len=16&digits=on&unique=off&&rnd=new&format=plain" | \
    awk '{print(substr($0,1,4))"-"(substr($0,5,4))"-"(substr($0,9,4))"-"(substr($0,13,4))}'


The following network zones are recommended for the cluster. External interfaces or gateways connect cluster forming a grid.

    IF   Network  Address Range
    bmc  bmc      10.0.0.0/16
    eth0 system   10.1.0.0/16
    eth1 storage  10.2.0.0/16
    eth2 mpi      10.3.0.0/16
    ethX external ?

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

### Install ansible on the local client

Ansible should be installed into `$HOME/ansible`:

    cd $HOME
    git://github.com/ansible/ansible.git

Edit your `$HOME/.bashrc`:

    source $HOME/ansible/hacking/env-setup &> /dev/null
    export ANSIBLE_HOSTS=$ANSIBLE_HOME/hosts

Run the source command:

    source $HOME/.bashrc

Create and edit `$HOME/ansible/hosts`:

    [root_servers]
    root-01:22 ansible_ssh_host=10.1.1.1

Check the connection:

    ansible root_servers -u root -m raw -a "hostname" -k

Play the bootstrap:

    cd $HOME/ansible
    ansible-playbook root_servers plays/bootstrap.yml

Test the Administrator Account:

    ansible root_servers -m ping -u admin --private-key=plays/keys/root-admin -k

Secure the SSH Server:

    ansible-playbook root_servers plays/secure_ssh_server.yml

Secure su:

    ansible-playbook root_servers plays/secure_su.yml




