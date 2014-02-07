echo $1
echo $2

if [ "${1}" != "null" ]; then
  echo "Acquire { Retries \"0\"; HTTP { Proxy \"http://${1}\"; }; };" >> "/etc/apt/apt.conf.d/01proxy"
  echo "http_proxy = $1" >> /etc/wgetrc
  export HTTP_PROXY=$1
  echo "set http proxy to $1"
fi

export HTTP_MIRROR=$2

apt-get update
apt-get install python-dev python-pip git -y

mkdir -p /etc/puppet/modules
mkdir -p /etc/puppet/manifests

puppet module install puppetlabs-stdlib -v 4.1.0
puppet module install puppetlabs-apache -v 0.9.0
puppet module install puppetlabs-tftp -v 0.2.1
puppet module install puppetlabs-rsync -v 0.1.0
puppet module install yguenane/devtools
puppet module install netmanagers/dnsmasq

pip install ansible

git clone https://github.com/michaeltchapman/puppet-edeploy.git /etc/puppet/modules/edeploy

cat > /etc/puppet/manifests/site.pp <<EOF
node 'debian-7' {
  class { 'edeploy':
    serv => \$ipaddress_eth1,
    rserv => \$ipaddress_eth1,
    hserv => \$ipaddress_eth1,
    hserv_port => 8080,
    http_install_port => 8080,
    giturl  => 'https://github.com/michaeltchapman/edeploy.git',
    rsync_exports => {'install' => {'path' => '/var/lib/debootstrap/install', 'comment' => 'The Install Path'},
    'metadata' => {'path' => '/var/lib/edeploy/metadata', 'comment' => 'The Metadata Path'},}
  }

  class { 'dnsmasq':
    domain_needed => false,
    interface => 'eth1',
    dhcp_range => ['192.168.99.3, 192.168.99.50'],
    dhcp_boot =>  ['pxelinux.0']
  }

}
EOF

puppet apply /etc/puppet/manifests/site.pp

# something weird going on here
service xinetd restart

# build a minimal debian to boot from
cd /var/lib/edeploy/build
make REPOSITORY=http://$HTTP_MIRROR/debian

# copy initrd and kernel of minimal debian to tftp dir
cp /var/lib/debootstrap/install/D7-H.1.0.0/base/boot/vmlinuz* /var/lib/tftpboot/vmlinuz
cp /var/lib/debootstrap/install/D7-H.1.0.0/initrd.pxe /var/lib/tftpboot
chown -R tftp:tftp /var/lib/tftpboot

# Cloud role, containing cloud-init
wget https://raw2.github.com/enovance/edeploy-roles/master/cloud.install
wget https://raw2.github.com/enovance/edeploy-roles/master/cloud.exclude
chmod a+x cloud.install

# Base openstack role, containing puppet and setting cloud archive
wget https://raw2.github.com/enovance/edeploy-roles/master/openstack-common.install
wget https://raw2.github.com/enovance/edeploy-roles/master/openstack-common.exclude
chmod a+x openstack-common.install

# Make the root password 'test' for openstack-common nodes
echo "do_chroot \${dir} usermod --password p1fhTXKKhbc0M root" >> openstack-common.install

# Create build rules for cloud and openstack-common
cat >> /var/lib/edeploy/build/Makefile <<EOF
cloud: \$(INST)/cloud.done
\$(INST)/cloud.done: cloud.install \$(INST)/base.done
	./cloud.install \$(INST)/base \$(INST)/cloud \$(VERS)
	touch \$(INST)/cloud.done

openstack-common: \$(INST)/openstack-common.done
\$(INST)/openstack-common.done: openstack-common.install \$(INST)/cloud.done
	./openstack-common.install \$(INST)/cloud \$(INST)/openstack-common \$(VERS)
	touch \$(INST)/openstack-common.done
EOF

# build the openstack-common role for debian wheezy and increment version
make DIST=wheezy DVER=D7 VERSION='H.1.0.1' REPOSITORY=http://$HTTP_MIRROR/debian openstack-common

# Now we build a hardware profile, called openstack-server
cat > /var/lib/edeploy/config/openstack-server.configure <<EOF
# -*- python -*-

bootable_disk = '/dev/' + var['disk']

run('dmsetup remove_all || /bin/true')

for disk, path in ((bootable_disk, '/chroot'), ):
    run('parted -s %s mklabel msdos' % disk)
    run('parted -s %s mkpart primary ext2 0%% 100%%' % disk)
    run('dmsetup remove_all || /bin/true')
    run('mkfs.ext4 %s1' % disk)
    run('mkdir -p %s; mount %s1 %s' % (path, disk, path))

open('/post_rsync/etc/network/interfaces', 'w').write('''
auto lo
iface lo inet loopback

auto %(eth)s
allow-hotplug %(eth)s
iface %(eth)s inet static 
  address %(ip)s
  netmask %(netmask)s
''' % var)

set_role('openstack-common', 'D7-H.1.0.1', bootable_disk)
EOF

# Set it to match this type of physical hardware:
cat > /var/lib/edeploy/config/openstack-server.specs <<EOF
# -*- python -*-

[
    ('disk', '\$disk', 'size', 'gt(4)'),
    ('network', '\$eth', 'ipv4', 'network(192.168.99.0/24)')
]
EOF

# Generate a new IP in the non-dhcp range for our server
# This gets passed to the configure script
cat > /var/lib/edeploy/config/openstack-server.cmdb <<EOF
generate({'ip': '192.168.99.150-200',
          'netmask': '255.255.255.0'
          })
EOF

# This controls how many of each profile can be deployed
cat > /var/lib/edeploy/config/state <<EOF
[('openstack-server', '5')]
EOF

# Needs to be read/writeable by the edeploy server
chown -R www-data:www-data /var/lib/edeploy/config

# Now we make a new version, 1.0.2, that has telnet and less installed
cat > /var/lib/edeploy/build/upgrade-from.d/openstack-common_D7-H.1.0.1_D7-H.1.0.2.upgrade <<EOF
. common
install_packages \$dir less telnet
EOF
chmod ug+x /var/lib/edeploy/build/upgrade-from.d/openstack-common_D7-H.1.0.1_D7-H.1.0.2.upgrade

# now we update our install script to match
#cat >> /var/lib/edeploy/build/openstack-common.install <<EOF
#install_packages \$dir less telnet
#EOF

# Now build the new version
./upgrade-from openstack-common D7-H.1.0.1 D7-H.1.0.2 /var/lib/debootstrap
