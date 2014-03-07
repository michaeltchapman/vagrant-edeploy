Vagrant environment for edeploy
===============================

Vagrant environment that will create a vm and install and configure edeploy using puppet-edeploy, along with a dhcp server. Then it will compile the pxe and base roles, an openstack-common role, and an update to the openstack-common role, so that you can see what the process is for managing a cluster with edeploy. There is also a blank VM that can be easily deployed once these tasks are done to see it in action.

## Requirements

    Vagrant 2.0 (http://www.vagrantup.com/)
    Virtualbox 4+ (https://www.virtualbox.org/wiki/Downloads)
    Virtualbox extensions

The extensions are needed to give VMs pxe capability, without which the environment does not demonstrate much at all.

The running VMs will need about 2GB of memory.

## Installation

Clone this repository

    git clone https://github.com/michaeltchapman/vagrant-edeploy
    cd vagrant-edeploy

Install the two vagrant boxes

    vagrant box add debian https://dl.dropboxusercontent.com/s/si19tbftilcuipz/debian-7.0-amd64.box?dl=1&token_hash=AAGu8u0J4P7zZwcz7WpgdEf6HGntPHVpxqHxyp26sdL-sA
    vagrant box add blank blank.box

The first box will be used to deploy edeploy and is a pretty standard debian wheezy box from www.vagrantbox.es. The second is a box with almost nothing attached except a couple of nics, one of which will be set to pxe boot.

## Running the demo

If you have an http proxy, like squid, you can use it via en environment variable

    export HTTP_PROXY=192.168.0.13:8000

You can similarly change the http debian mirror:

    export APT_MIRROR=mirror.aarnet.edu.au

First, bring up the edeploy box.

    vagrant up edeployd

You can follow along with what's happening by looking at the build.sh script.

Once this is done, create the target vm by doing

    vagrant up target

Then quit out and watch the node deploy via the gui.

You can log in with the root user and the password test. The less command is not going to be available initially, but by updating from tree D7-H.1.0.1 to 1.0.2, it will be made available.

     less /etc/passwd
     edeploy update D7-H-1.0.2
     less /etc/passwd

# TODO:

Merge changes under michaeltchapman back upstream
Get metadata to do something useful
Remove errors from base image build by installing ansible.
