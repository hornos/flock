Flock / Rapid Infrastructure Prototype Engine
=================================================

*The fact is, Adelmo's death has caused much spiritual unease among my flock.*

![Flock](http://24.media.tumblr.com/tumblr_lzinfntu2G1qj8pa7o1_500.gif)

## Install for OS X
Go home:

    cd

For the Flock boot you need `ngnix` and `dnsmasq`:

    brew install nginx dnsmasq python libyaml

Edit your `.profile` or `.bash_profile` and set PATH:

    PATH=/usr/local/bin:$PATH

Install python packages:

    pip pyyaml jinja2 paramiko

For the Flock provision you need Ansible:

    git clone git://github.com/ansible/ansible.git

For the Flock you need Flock:

    git clone git://github.com/hornos/flock.git

Install VirtualBox extension pack.

### Setup
Edit your `.profile` or `.bash_profile`:

    source $HOME/flock/flockrc

Or run

    source $HOME/flock/flockrc

Mind that `flock` always works relative to the current directory:

    pushd flock

Generate SSH keys:

    flock init

Keys and certificates are in the `keys` directory.

## Network Install
Download [syslinux 4.X](https://www.kernel.org/pub/linux/utils/boot/syslinux/) and the following files to `space/boot`:

    core/pxelinux.0
    com32/mboot/mboot.c32

Get install images eg. for Debian (mind the trailing slash!):

    pushd space/boot
    rsync -avP ftp.us.debian.org::debian/dists/wheezy/main/installer-amd64/current/images/netboot/ ./wheezy
    popd

Debian-based systems should be installed with NAT.

Or get the kickass Debian killer CentOS (mind the trailing slash!):

    pushd space/boot
    rsync -avP rsync.hrz.tu-chemnitz.de::ftp/pub/linux/centos/6.4/os/x86_64/isolinux/ ./centos64
    popd

Space Jockey (`jockey`) is a simple Cobbler replacement. You need a simple inventory file like this (`space/hosts`):

    boot_server=10.1.1.254
    dhcp_range="10.1.1.1,10.1.1.128,255.255.255.0,6h"
    interface=eth1

The boot server listens on `boot_server` IP and Debian-based systems use the `interface` interface to reach the internet (NAT or bridged or 2nd physical network card). DNSmasq gives IPs from the `dhcp_range`.

### Core Servers
The following network topology is used:

    Network   VBox Net IPv4 Addr  Mask DHCP
    system    vboxnet0 10.1.1.254 16   off
    external  NAT/Bridged

Create 3 VMs:

    flock out 3 core centos64

Start the boot/kickstart servers on your OS X host each in a separate Terminal tab:

    flock http
    flock boot

Start the background flock:

    flock-vbox start /@core

wait for the reboot signal and turn off the group:

    flock-vbox off /core

Switch to disk boot make a snapshot and start again:

    flock-vbox boot /core disk
    flock-vbox start /@core
    flock-vbox snap /core init

Change the inventory:

    flenv core

Lets bootstrap the flock (mind hostkeys in `$HOME/.ssh/known_hosts`):

    flock bootstrap /core

and ping by `sysop`:

    flock ping @@core

Check the network topology in `networks.yml` and secure the flock:

    flock play @@core secure
    flock reboot @@core
    flock-vbox snap /core secure

Now, reach the ground state:

    flock play @@core ground
    flock reboot @@core
    flock-vbox snap /core ground

Mind that the system network is not protected, due to performance reasons core servers can reach each other wihtout restriction or authentication. Monitoring is done by Ganglia in multicast mode.

Check the cluster state by or on `http://10.1.1.1/ganglia`:

    gstat -a

For the awesome PCP download `ftp://oss.sgi.com/projects/pcp/download/mac/` and install `pcp` and `pcp-gui`. Get realtime statistics:

    pmstat -h 10.1.1.1 -h 10.1.1.2 -h 10.1.1.3
    /Applications/pmchart.app/Contents/MacOS/pmchart -h 10.1.1.1 -c Overview 

### FreeIPA

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

Check `ssl.conf` for a strong [PFS](http://vincent.bernat.im/en/blog/2011-ssl-perfect-forward-secrecy.html) cipher setting.

If you want to enable the CA certificate system-wide run:

    /root/bin/enable_grid_cert

### Clustering
Create common authentication key (`keys/authkey`):

    dd if=/dev/urandom of=keys/authkey bs=128 count=1

Enter Cluster state:

    flock play @@core cluster

The following tools are installed under `/root/bin`:

    ring
    totem
    quorum

### Database
#### MariaDB with Galera
Install database:

    flock play @@core database

Login to the master node and secure the installation:

    mysql_secure_installation

#### Percona

    flock play @@core roles/database/percona

Login to the master node and bootstrap the cluster:

    /etc/init.d/mysql start --wsrep-cluster-address="gcomm://"
    mysql_secure_installation

Now start the whole cluster:

    flock play @@core roles/adatabase/percona_start

Add eg. `--extra-vars "master=percona-01"` if you have a different master.

Verify:

    echo "show status like 'wsrep%'" | mysql -u root -p

Enable php admin interface:

    flock play @@core roles/database/admin

### Storage
#### Gluster
Change to the latest mainline kernel:

    flock play @@core roles/system/kernel
    flock reboot @@core

Install Gluster and setup a 3-node FS cluster:

    flock play @@core roles/cluster/gluster

Login to the master node and bootstrap the cluster:

    /root/gluster_bootstrap

Finally, mount the common directory:

    flock play @@core roles/cluster/glusterfs
    flock play @@core roles/cluster/gtop

Monitor the cluster:

    /root/bin/gtop

### Scheduler
#### Slurm
Generate the Munge auth key:

    dd if=/dev/random bs=1 count=1024 > keys/munge.key

Install Slurm:

    flock play @@core scheduler

Login to the master node and test the queue:

    srun -N 3 hostname

### VPN
Download Easy RSA CA:

    git clone git://github.com/OpenVPN/easy-rsa.git ca/easy-rsa

Create a VPN CA (`vpnca`):

    flock-vpn create

Create server certificates:

    for i in 1 2 3 ; do flock-vpn server vpnca core-0$i; done

Create sysop client certificate:

    flock-vpn client vpnca sysop

Create DH and TA parameters:

    flock-vpn param vpnca

You need the following files:

Filename | Needed By | Purpose | Secret
--- | --- | --- | ---
ca.crt | server & clients | Root CA cert | NO
ca.key | sysop | Root CA key | YES
ta.key | server & clients | HMAC | YES
dh{n}.pem | server | DH parameters | NO
server.crt | server | Server Cert | NO
server.key | server | Server Key | YES
client.crt | client | Client Cert | NO
client.key | client | Client Key | YES

Install OpenVPN servers:

    flock play @core roles/vpn/openvpn

Install Tunnelblick on your mac and link:

    pushd $HOME
    ln -s 'Library/Application Support/Tunnelblick/Configurations' .openvpn
    popd

Install the sysop certificate for Tunnelblick:

    flock-vpn blick vpnca sysop

Prepare VPN configuration for iPhone:

    flock-vpn client vpnca iphone
    flock-vpn iphone

Edit `ca/vpnca/iphone/iphone.ovpn` and connect iPhone go to DEVICES/Phone Apps tab and File Sharing section. Select OpenVPN and Add all the files in the `iphone` directory.

#### Ting
You can determine server IPs by Ting. Register a free [pusher.com](https://github.com/NIIF/nce) account. Generate a key:

    openssl rand -base64 32 > keys/ting.key

Create `keys/ting.yml` with the following content:

    ting:
      key: ...
      secret: ...
      app_id: ...

Enable the role:

    flock play @@core roles/vpn/ting

Install Ting on your mac:

    pushd $HOME
    git clone git://github.com/hornos/ting.git

Edit the `ting.yml` and fill in your app details.

The ting service will pong back the machines external IP ans SSH host fingerprints. On your local machine start the monitor:

    pushd $HOME/ting
    ./ting -k ../flock/keys/ting.key -m client

Ping them

    ./ting -k ../flock/keys/ting.key ping

Hosts are collected in `ting/hosts` as json files. Create an Tunnelblick client configuration based on Ting pongs:

    pushd $HOME/flock
    flock-vpn ting core? core

Now connect with Tunnelblick.


<!--
##      ##    ###    ########  ######## ##      ## ##     ## ##       ######## 
##  ##  ##   ## ##   ##     ## ##       ##  ##  ## ##     ## ##       ##       
##  ##  ##  ##   ##  ##     ## ##       ##  ##  ## ##     ## ##       ##       
##  ##  ## ##     ## ########  ######   ##  ##  ## ##     ## ##       ######   
##  ##  ## ######### ##   ##   ##       ##  ##  ## ##     ## ##       ##       
##  ##  ## ##     ## ##    ##  ##       ##  ##  ## ##     ## ##       ##       
 ###  ###  ##     ## ##     ## ########  ###  ###   #######  ######## ##          
-->

![warewulf](http://warewulf.lbl.gov/images/wwheader-4.png)

## Warewulf HPC Cluster
Warewulf is a badass HPC cluster kit. Create a controller node or nodes and converge them into ground state. In this example I will use 1 controller (core) and 2 compute machines (cn-0[1-2]). Use two network card on the controller, eth0 is on the `system` network. In reality, this network should be on a separated internal LAN (VLAN is not secure by design) since its unsecure and vulnerable to DOS attacks.

### Create the controller triangle

    flock out 3 ww

Start the kickstart servers:

    flock http
    flock boot

and start the group in the background:

    flock-vbox start /@ww

wait for the reboot signal and turn off the group:

    flock-vbox off /ww

switch to disk boot make a snapshot and start:

    flock-vbox boot /ww disk
    flock-vbox start /@ww

Swith to the `ww` nevironment:

    flenv ww

Lets bootstrap the flock (mind hostkeys in `$HOME/.ssh/known_hosts`):

    flock bootstrap /ww

Verify by `sysop`:

    flock ping @@ww

Check the network topology in `networks.yml` and secure the flock:

    flock play @@ww secure
    flock reboot @@ww
    flock-vbox snap /ww secure

#### Ground state

    flock play @@ww ground
    flock reboot @@ww
    flock-vbox snap /ww ground

finally, change the old kernel for good:

    flock play @@ww roles/system/kernel --extra-vars "clean=yes"
    flock reboot @@ww
    flock-vbox snap /ww kernel

Check the boot log for sure:

    flock bootlog @@ww

By default, sysop machines can access the system information page and Ganglia at

    http://10.1.1.1/phpsysinfo
    http://10.1.1.1/ganglia

You can also get live monitoring with PCP console or GUI:

    pmstat -h 10.1.1.1
    pmchart -h 10.1.1.1 -c Overview

#### Globus (optional)
Install globus and openssl as written in the Globus CA section. Edit grid scripts as well as templates in `share/globus_simple_ca` if you want to change key parameters. Create a Warewulf CA (365 days):

    flock-ca create wwca

The new CA is created under the `ca/wwca` directory. The CA certificate is installed under `ca/grid-security` to make requests easy. If you compile Globus with the old OpenSSL (system default) you have to use old-style subject hash. Create old CA hash by:

    flock-ca oldhash

Edit `wwca/grid-ca-ssl.conf` and add the following line under `policy` in `[CA_default]` section, this enables extension copy on sign and let alt names go.

    copy_extensions = copy

Request & sign host certificates of the controller triangle:

    flock cert wwca /ww

Certs, private keys and requests are in `ca/coreca/grid-security`. There is also a `ca/<CAHASH>` directory link for each CA. You have to use the `<CAHASH>` in the playbooks. Get the `<CAHASH>`:

    flock-ca cahash wwca

Edit `roles/globus/vars/globus.yml` and set the default CA hash.

Create and sign the sysop certificate:

    flock-ca user wwca sysop "System Operator"
    flock-ca sign wwca sysop

In order to use `sysop` as a default grid user you have to copy cert and key into the `keys` directory:

    flock-ca keys wwca sysop

Test your user certificate (you might have to create the old hash):

    flock-ca verify wwca sysop

Enable the Grid state:

    flock play @@ww grid

Check `ssl.conf` for a strong [PFS](http://vincent.bernat.im/en/blog/2011-ssl-perfect-forward-secrecy.html) cipher setting.

Verify https in your browser:

    https://10.1.1.1/phpsysinfo
    https://10.1.1.1/ganglia

TODO: PFS SSL

    flock-vbox snap /ww grid

#### Monitoring

TODO: OMD http://omdistro.org/

#### Master and servant
Name the master and backup node for a failover HA:

    flock play @@ww roles/hpc/hosts --extra-vars=\"master=ww-01 backup=ww-02\"
    flock-vbox snap /ww hosts

#### Database
SQL database is used for the scheduler backend. Install the SQL cluster:

    flock play @@ww roles/database/percona --extra-vars "master=ww-01"

Login to the master node and bootstrap the cluster (as root):

    /root/percona_bootstrap

Now start the whole cluster:

    flock play @@ww roles/database/percona_start --extra-vars "master=ww-01"

Verify on the master node:

    echo "show status like 'wsrep%'" | mysql -u root -p

Enable php admin interface:

    flock play @@ww roles/database/admin

The mysql admin page is at `http://10.1.1.1/phpmyadmin`.

    flock-vbox snap /ww sql

#### Gluster
Install a common state directory with Gluster:

    flock play @@ww roles/hpc/gluster --extra-vars="master=ww-01"

Login to the master node and bootstrap the cluster (as root):

    /root/gluster_bootstrap

Finally, mount the common directory (check tune parameters):

    flock play @@ww roles/hpc/glusterfs
    flock play @@ww roles/hpc/gtop

Monitor the cluster (as root):

    /root/bin/gtop

Save:

    flock-vbox snap /ww gluster

#### HA Scheduler
Generate a munge key for the compute cluster and setup the scheduler services:

    dd if=/dev/random bs=1 count=4096 > keys/munge.key
    flock play @@ww scheduler --extra-vars=\"master=ww-01 backup=ww-02\"

Scheduler authentication relies on NTP and the Munge key, keep it in secret. The basic Slurm setup contains only the controller machines. Restart `slurmdbd` can fail.

Login to the master node and check the queue:

    sinfo -a

Verify the queue:

    srun -N 3 hostname

Save:

    flock-vbox snap /ww slurm

#### Warewulf
Generate a cluster key. The cluster key is used to SSH to the compute nodes:

    ssh-keygen -b4096 -N "" -f keys/cluster

TODO: provision node only on the master

Check `networks.yml` and `vars/warewulf.yml` for ip ranges of compute nodes. Install Warewulf:

    flock play @@ww warewulf --extra-vars=\"master=ww-01 backup=ww-02\"

Verify HA so far. Shutdown the master node

    flock shutdown @@ww-01

and check Slurm failover on the backup node (as root):

    /root/bin/slurmlog

Save:

    flock-vbox snap /ww ww

#### Compute nodes
Prepare the Warewulf OS node on the master node. Login to the master node and make a clone:

    pushd /ww/common/chroots
    ./cloneos centos-6

Install basic packages:

    ./clonepackages centos-6

*NOTE:* Ad-hoc installations done:

    ./cloneyum centos-6 install ptpd

*NOTE:* Install new Ansible scripts:

    flock play @@ww roles/warewulf/ansible --extra-vars=\"master=ww-01 backup=ww-02\"

Configure the clone directory:

    ./clonesetup centos-6

On the compute nodes NTP is used for initial time sync and PTP is used for fine sync. The controller node is a PTP master running both NTP and PTP.

FIX (if applicable): Edit `/usr/share/perl5/vendor_perl/Warewulf/Provision/Pxelinux.pm` line 201 comment the if block

FIX (if applicable): Edit `/usr/share/perl5/vendor_perl/Warewulf/Provision/Dhcp/Isc.pm` line 273 comment if block

Edit `/etc/warewulf/vnfs.conf` to exclude unnecessary files and make the image (database tables are created automatically):

    ./cloneimage centos-6

Edit `/etc/warewulf/bootstrap.conf` to load kernel modules/drivers/firmwares and bootstrap the kernel:

    ./clonekernel list centos-6
    ./clonekernel centos-6 3.10.5-1.el6.elrepo.x86_64

FIX: Remove `/etc/warewulf/database-root.conf` which is used for DB creation

    mv /etc/warewulf/database-root.conf /etc/warewulf/database-root.conf.old

Create compute nodes:

    flock out 3 cn

Provision:

    ./clonescan centos-6/3.10.5-1.el6.elrepo.x86_64 compute/cn-0[1-2]
    wwsh provision set cn-0[1-2] --fileadd dynamic_hosts

or do it manually:

    wwsh node new cn-01 --netdev=eth0 --hwaddr=<CN-01 MAC> --ipaddr=10.1.1.11 --groups=compute
    wwsh provision set --lookup groups compute --vnfs=centos-6 --bootstrap=3.10.5-1.el6.elrepo.x86_64
    wwsh provision set --lookup groups compute --fileadd dynamic_hosts

Verify the connection and monitoring:

    ssh -i playbooks/keys/cluster cn-01 hostname
    gstat -a

TODO: master slave host names
TODO: scripts + cgroup
TODO: rsyslog pipi + inittab
http://www.rsyslog.com/doc/ompipe.html

    ./slurmconf cn-0[1-2]

At first, you have to start slurm execute service as well:

    ./cloneservice compute slurm start

Parameter       | srun option | When Run  | Run by | As User
--- | --- | --- | --- | ---
PrologSlurmCtld |             | job start | slurmctld | SlurmUser
Prolog          |             | job start | slurmd    | SlurmdUser
TaskProlog (batch) |          | script start | slurmstepd | User
SrunProlog      | --prolog    | step start | srun     | User
TaskProlog      |             | step start | slurmstepd | User
                | --task-prolog | step start | slurmstepd | User
                | --task-epilog | step finish | slurmstepd | User
TaskEpilog      |             | step finish | slurmstepd | User
SrunEpilog      | --epilog    | step finish | srun  | User
TaskEpilog (batch) |          | script finish | slurmstepd | User
Epilog          |             | job finish | slurmd | SlurmdUser
EpilogSlurmCtld |             | job finish | slurmctld | SlurmUser

Interactive test:

    srun -N 2 -D /common/scratch hostname

Batch test:

    cd /common/scratch
    Create slurm.sh:
    #!/bin/sh 
    #SBATCH -o StdOut
    #SBATCH -e StdErr
    srun hostname

    sbatch -N 2 slurm.sh

MPI test on the host:

    git clone git://github.com/NIIF/nce.git /common/software/nce
    module use /common/software/nce/modulefiles/
    export NCE_ROOT=/common/software/nce
    module load nce/global

Compile the latest OpenMPI:

    yum install gcc gcc-c++ make gcc-gfortran environment-modules
    mkdir -p ${NCE_PACKAGES}/openmpi/1.6.4
    ./configure --prefix=${NCE_PACKAGES}/openmpi/1.6.4
    make && make install
    cd examples
    make
    cd ..
    cp -R examples /common/scratch/
    cd /common/scratch/examples
    module load openmpi/1.6.4

Performance tests (TODO):

    ftp://ftp.mcs.anl.gov/pub/mpi/tools/perftest.tar.gz

TODO: node firewalls

TODO: trusted login node

TODO: LDAP & storage

TODO: [Soft RoCE](http://www.systemfabricworks.com/downloads/roce)

    yum --enablerepo=elrepo-kernel install kernel-ml-devel kernel-ml-headers rpm-build
    yum install libibverbs-devel libibverbs-utils libibverbs
    yum install librdmacm-devel librdmacm-utils librdmacm

Downlod rxe package:

    wget http://198.171.48.62/pub/OFED-1.5.2-rxe.tgz

Edit `/etc/exports`, export fs by `exportfs -a`. Edit Push out a new `autofs.common` config:

    ./autofsconf compute

Service restart:

    ./cloneservice compute gmond restart

TODO:
* Cgroup
* Wake-on-lan with compute suspend
* Kernel 3.10 full nohz cpuset scheduler numa shit ptp
* error: /usr/sbin/nhc: exited with status 0x0100

### Logstash with Kibana
Enable elasticsearch:

    flock play @@core roles/monitor/elasticsearch



## Message Queue

<!--
##     ##    ###    ########   #######   #######  ########  
##     ##   ## ##   ##     ## ##     ## ##     ## ##     ## 
##     ##  ##   ##  ##     ## ##     ## ##     ## ##     ## 
######### ##     ## ##     ## ##     ## ##     ## ########  
##     ## ######### ##     ## ##     ## ##     ## ##        
##     ## ##     ## ##     ## ##     ## ##     ## ##        
##     ## ##     ## ########   #######   #######  ##
-->

## Hadoop

    flock out 3 hadoop centos64

Start the kickstart servers:

    flock http
    flock boot

and start the group in the background:

    flock-vbox start /@hadoop

wait for the reboot signal and turn off the group:

    flock-vbox off /hadoop

switch to disk boot make a snapshot and start:

    flock-vbox boot /hadoop disk
    flock-vbox start /@hadoop
    flock-vbox snap /hadoop init

Swith to the `hadoop` nevironment:

    flenv hadoop

Lets bootstrap the flock (mind hostkeys in `$HOME/.ssh/known_hosts`):

    flock bootstrap /hadoop

Verify by `sysop`:

    flock ping @@hadoop

Check the network topology in `networks.yml` and secure the flock:

    flock play @@hadoop secure
    flock reboot @@hadoop
    flock-vbox snap /hadoop secure

Now, reach the ground state:

    flock play @@hadoop ground
    flock reboot @@hadoop
    flock-vbox snap /hadoop ground

### Prepare
Install Gluster and setup a 3-node FS cluster if you want a storage based HA:

    flock play @@core roles/system/kernel --extra-vars "clean=yes"
    flock reboot @@core

    flock play @@core roles/hpc/gluster

Login to the master node and bootstrap the cluster:

    /root/gluster_bootstrap

Finally, mount the common directory:

    flock play @@core roles/hpc/glusterfs
    flock play @@core roles/hpc/gtop

Monitor the cluster:

    /root/bin/gtop

### CDH4
Deploy standalone HDFS cluster:

    flock play @@hadoop roles/hadoop/deploy --extra-vars \"init=yes master=hadoop-01\"

Login to the master node and format the namenode:

    /root/bin/hdfs_admin format

To remove old data if you have:

    rm -Rf /data/hadoop/{1,2,3}/dfs/dn/*
    ssh hadoop-02 rm -Rf /data/hadoop/{1,2,3}/dfs/dn/*
    ssh hadoop-03 rm -Rf /data/hadoop/{1,2,3}/dfs/dn/*

Start the master name node and the data nodes:

    flock play @@hadoop roles/hadoop/start_hdfs --extra-vars \"master=hadoop-01\"

Login to the master node and initialize Yarn:

    /root/bin/hdfs_admin init

Verify:

    sudo -u hdfs hadoop fs -ls -R /

Enable Yarn:

    flock play @@hadoop roles/hadoop/start_yarn --extra-vars \"master=hadoop-01\"

    flock-vbox snap /hadoop hdfs

Verify mapreduce. Create a [test file](https://github.com/ansible/ansible-examples/tree/master/hadoop) in `/tmp` (hdfs) and run:

    hadoop jar /usr/lib/hadoop-0.20-mapreduce/hadoop-examples.jar grep /tmp/inputfile /tmp/outputfile 'hello'
    hadoop fs -cat /tmp/hadoop.out/part-00000

#### HUE

#### Flume syslog
Login to the master node and initialize Yarn:

    /root/bin/hdfs_admin flume

Enable flume and syslog forwarder:

    flock play @@core roles/hadoop/flume

#### HA

Login to the master node and initilaize Zookeeper HA:

    hdfs zkfc -formatZK

## Communication Center
Install MariaDB master:

    flock play @@com roles/database/mariadb --extra-vars "master=com"
    flock play @@com roles/database/mariadb_master --extra-vars "master=com"

Log in and secure:

    mysql_secure_installation

Install openfire:

    flock play @@com roles/com/openfire --extra-vars \"schema=yes master=com\"

Setup the wizard:

    jdbc:mysql://127.0.0.1:3306/openfire?rewriteBatchedStatements=true

Clustering:

SSL:

## Kernel
### Kdump
Remote kdump
http://blog.kreyolys.com/2011/03/17/no-panic-its-just-a-kernel-panic/


<!--
##     ##  ######   #######  ##     ## 
 ##   ##  ##    ## ##     ## ###   ### 
  ## ##   ##       ##     ## #### #### 
   ###    ##       ##     ## ## ### ## 
  ## ##   ##       ##     ## ##     ## 
 ##   ##  ##    ## ##     ## ##     ## 
##     ##  ######   #######  ##     ## 
-->
## Communicator


## Home Server

## XenServer 6.2
Mount (link) the ISO under `boot/xs62/repo` into jockey's root directory.

    flock-vbox create xs62 RedHat_64 2 2048
    jockey kick xs62 @xs62 10.1.1.30 xs62

### OpenStack
Ground state controller:

    export ANSIBLE_HOSTS=xen
    flock play root@@xc bootstrap
    flock play @@xc secure
    flock reboot @@xc
    flock-vbox snap xc init
    flock play @@xc ground
    flock reboot @@xc
    flock-vbox snap xc ground

SQL and MQ:

    flock play @@xc roles/database/mariadb --extra-vars "master=xc"
    flock play @@xc roles/database/mariadb-nowsrep --extra-vars "master=xc"

Login to `xc` and secure SQL:

    mysql_secure_installation

    flock play @@xc roles/database/memcache.yml
    flock play @@xc roles/mq/rabbitmq.yml
    flock play @@xc roles/monitor/icinga.yml --extra-vars \"schema=yes master=xc\"

    flock-vbox snap xc prestack

#### Identity service
Create admin token:

    openssl rand -hex 10 > keys/admin_token

Install the keystone identity service:

    flock play @@xc roles/openstack/identity --extra-vars "master=xc"

Login to the machine and init/start the service:

    /root/init_openstack_identity

Install sample data:

    /root/sample_data.sh

Verify:

    keystone --os-username=admin --os-password=secrete --os-auth-url=http://localhost:35357/v2.0 token-get

#### Image service
Install glance service:

    flock play @@xc roles/openstack/image --extra-vars "master=xc"

Login to the machine and init/start the service:

    /root/init_openstack_image

TODO Verify:

## Kali
Download the installer package:

    mkdir -p space/boot/kali
    pushd space/boot/kali
    curl http://repo.kali.org/kali/dists/kali/main/installer-amd64/current/images/netboot/netboot.tar.gz | tar xvzf -

Create a machine and bootstrap:

    flock-vbox create kali Debian_64 1 2048
    jockey kick kali @kali 10.1.1.42 kali

![FhGFS](http://www.fhgfs.com/wiki/images/FraunhoferFS.png)

## FhGFS

[FhGFS](http://www.fhgfs.com/wiki/wikka.php?wakka=FhGFS) is a kickass HPC fs you [should use](http://www.hpcwire.com/hpcwire/2013-07-24/fhgfs_designed_for_scalability_flexibility_in_hpc_clusters.html). Create a bunch of hosts by:

    flock out 3 fhgfs centos64

TODO: groupping in the GUI.

Start the kickstart servers:

    flock http
    flock boot

and start the group in the background:

    flock-vbox start /@fhgfs

wait for the reboot signal and turn off the group:

    flock-vbox off /fhgfs

switch to disk boot make a snapshot and start:

    flock-vbox boot /fhgfs disk
    flock-vbox start /@fhgfs
    flock-vbox snap /fhgfs init

Change the inventory:

    flenv fhgfs

Lets bootstrap the flock (mind hostkeys in `$HOME/.ssh/known_hosts`):

    flock bootstrap /fhgfs

and ping by `sysop`:

    flock ping @@fhgfs

Check the network topology in `networks.yml` and secure the flock:

    flock play @@fhgfs secure
    flock reboot @@fhgfs
    flock-vbox snap /fhgfs secure

Now, reach the ground state:

    flock play @@fhgfs ground
    flock reboot @@fhgfs
    flock-vbox snap /fhgfs ground

CentOS `kernel-devel` build link is broken, fix:

     ln -v -f -s /usr/src/kernels/2.6.32-358.14.1.el6.x86_64 /lib/modules/2.6.32-358.el6.x86_64/build

Install FhGFS (mind that InfiniBand is not configured):

    flock play @@fhgfs roles/hpc/fhgfs --extra-vars="master=fhgfs-01"

Verify (TODO cli):

    fhgfs-ctl --listnodes --nodetype=meta --details
    fhgfs-ctl --listnodes --nodetype=storage --details
    fhgfs-net

or check the GUI (use Java 6):

    java -jar /opt/fhgfs/fhgfs-admon-gui/fhgfs-admon-gui.jar

Save it for good:

    flock-vbox snap /fhgfs fhgfs

## Ground state cross-check
Create and `ostest` group with two machines:

    flock-vbox create raring Ubuntu_64 1 2048
    flock-vbox create centos64 RedHat_64 1 2048

    jockey kick centos64 @centos64 10.1.1.1 centos64
    jockey kick raring @raring 10.1.1.2 raring

Start the boot servers and install the systems and reboot. Use the following inventory (`ostest`):

    [ostest]
    centos64 ansible_ssh_host=10.1.1.1 ansible_connection=paramiko
    raring ansible_ssh_host=10.1.1.2 ansible_connection=paramiko

Bootstrap and verify:

    flock bootstrap /ostest
    flock ping @@ostest

Secure and reboot:

    flock play @@ostest secure
    flock reboot @@ostest

Save and start to reach the ground state:

    flock-vbox snap /ostest secure
    flock play @@ostest ground
    flock reboot @@ostest
    flock-vbox snap /ostest ground

## Docker

    flock out 3 docker raring Ubuntu_64

Start the kickstart servers:

    flock http
    flock boot

and start the group in the background:

    flock-vbox start /@docker

wait for the reboot signal and turn off the group:

    flock-vbox off /docker

switch to disk boot make a snapshot and start:

    flock-vbox boot /docker disk
    flock-vbox start /@docker
    flock-vbox snap /docker init

Swith to the `docker` nevironment:

    flenv docker

Lets bootstrap the flock (mind hostkeys in `$HOME/.ssh/known_hosts`):

    flock bootstrap /docker

Verify by `sysop`:

    flock ping @@docker

Check the network topology in `networks.yml` and secure the flock:

    flock play @@docker secure
    flock reboot @@docker
    flock-vbox snap /docker secure

Now, reach the ground state:

    flock play @@docker ground
    flock reboot @@docker
    flock-vbox snap /docker ground

Install docker:
