Flock - The Rapid Infrastructure Prototype Engine
=================================================

*The fact is, Adelmo's death has caused much spiritual unease among my flock.*

## Install
Go home:

    cd

For the Flock boot you need `ngnix` and `dnsmasq`:

    brew install ngnix dnsmasq

For the Flock provision you need Ansible:

    git clone git clone git://github.com/ansible/ansible.git

For the Flock you need Flock:

    git://github.com/hornos/flock.git

### Setup
Edit your `.profile` or `.bash_profile`:

    source $HOME/flock/flockrc

Or run

    source $HOME/flock/flockrc

Mind that `flock` always works relative to the current directory:

    push flock

Generate SSH keys:

    flock init

Keys and certificates are in the `keys` directory.

## Network Install
Space Jockey (`jockey`) is a simple Cobbler replacement. You need a simple inventory file like this (`space/hosts`):

    boot_server=10.1.1.254
    dhcp_range="10.1.1.1,10.1.1.128,255.255.255.0,6h"
    interface=eth1

The boot server listens on `boot_server` IP and Debian-based systems use the `interface` interface to reach the internet (NAT or bridged or 2nd physical network card). DNSmasq gives IPs from the `dhcp_range`.

### Core Servers
The following network topology is used:

    Network   VBox Net IPv4 Addr  Mask DHCP
    system    vboxnetN 10.1.1.254 16   off
    external  NAT/Bridged

If you use VirtualBox for modelling you can create the servers by:

    for i in 1 2 3 ; do flock-vbox create core-0$i; done

Set the boot device to the 1st network interface:

    for i in 1 2 3 ; do flock-vbox boot core-0$i net; done

Kickstart the cores with CentOS:

    for i in 1 2 3 ; do jockey kick centos64 @core-0$i 10.1.1.$i core-0$i; done

Start the kickstart servers:

    jockey http
    jockey masq

and the machines:

    for i in 1 2 3 ; do flock-vbox start core-0$i; done

restart after installation is ready:

    for i in 1 2 3 ; do flock-vbox off core-0$i; done
    for i in 1 2 3 ; do flock-vbox boot core-0$i disk; done
    for i in 1 2 3 ; do flock-vbox start core-0$i; done

In case of real servers you have to play with ipmi.

## Provision with Ansible
You need an inventory file with your hosts, edit `hosts`

    [core]
    core-01 ansible_ssh_host=10.1.1.1
    core-02 ansible_ssh_host=10.1.1.2
    core-03 ansible_ssh_host=10.1.1.3

Test the 1st server:

    jockey password @core-01
    flock ping root@core-01

### Boostrap
Bootstrap the System Operator:

    for i in 1 2 3 ; do jockey password @core-0$i; flock play root@core-0$i bootstrap; done

and ping the by `sysop`:

    flock ping @@core

### Ground State
You need a simple network topology (`networks.yml`):

    interfaces:
      bmc: eth0
      system: eth0
      external: eth1
      dhcp: eth1
    networks:
      bmc: 10.0.0.0
      system: 10.1.0.0
      compute: 10.1.1.0
      vpn: 10.9.0.0
    masks:
      system: 16
      compute: 24
      home: 24
      vpn: 24
    dhcp_masks:
      system: 255.255.0.0
      compute: 255.255.255.0
    broadcasts:
      system: 10.1.255.255
    sysops:
      - 10.1.1.254
      - 10.1.1.253
    master: core-01

Currently, we have role-like playbooks. First, secure the installation:

    flock play @@core secure

Due to selinux you have to reboot now:

    flock reboot @@core

Now, reach the ground state:

    flock play @@core ground
    flock reboot @@core

Mind that the system network is not protected, due to performance reasons core servers can reach each other wihtout any serious authentication. Ground monitoring is done by Ganglia in multicast mode.

Check the cluster state by or on `http://10.1.1.1/ganglia`:

    gstat -a

For the awesome PCP download `ftp://oss.sgi.com/projects/pcp/download/mac/` and install `pcp` and `pcp-gui`. Get realtime statistics:

    pmstat -h 10.1.1.1 -h 10.1.1.2 -h 10.1.1.3
    /Applications/pmchart.app/Contents/MacOS/pmchart -h 10.1.1.1 -c Overview 

### Globus CA
Install the certificate utilities and Globus on your mac:

    make globus_simple_ca globus_gsi_cert_utils

There is a hash mismatch between OpenSSL 0.9 and 1.X. Install newer OpenSSL on your mac. You can use the [NCE module/package manager](https://github.com/NIIF/nce). Load the Globus and the new OpenSSL environment:

    module load globus openssl

The Grid needs a PKI, which protects access and the communication. You can create as many CA as you like. It is advised to make many short-term flat CAs. Edit grid scripts as well as templates in `share/globus_simple_ca` if you want to change key parameters. Create a Core CA:

    flock-ca create coreca 365 sysop@localhost

The new CA is created under the `ca/coreca` directory. The CA certificate is installed under `ca/grid-security` to make requests easy. If you compile Globus with the old OpenSSL (system default) you have to use old-style subject hash. Create old CA hash by:

    flock-ca oldhash

Edit `coreca/grid-ca-ssl.conf` and add the following line under `policy` in `CA_default` section, this enables extension copy on sign and let alt names go.

    copy_extensions = copy

Request & sign host certificates:

    for i in 1 2 3 ; do flock-ca host coreca core-0$i; done
    for i in 1 2 3 ; do flock-ca sign coreca core-0$i; done

Certs, private keys and requests are in `ca/coreca/grid-security`. There is also a `ca/<CAHASH>` directory link for each CA. You have to use the `<CAHASH>` in the playbooks. Get the `<CAHASH>`:

    flock-ca cahash coreca

Edit `roles/globus/vars/globus.yml` and set the default CA hash.

Create and sign the sysop certificate:

    flock-ca user coreca sysop "System Operator"
    flock-ca sign coreca sysop

In order to use `sysop` as a default grid user you have to copy cert and key into the `keys` directory:

    flock-ca keys coreca sysop

Create a pkcs12 version if you need for the browser (this command works in the `keys` directory):

    flock-ca p12 sysop

Test your user certificate (you might have to create the old hash):

    flock-ca verify coreca sysop

Enter Grid state:

    flock play @@core grid

### Clustering

### VPN

### Message Queue

### Filesystem

### Scheduler

### Hadoop


