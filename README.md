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
Space Jockey (`jockey`) is a simple Cobbler replacement