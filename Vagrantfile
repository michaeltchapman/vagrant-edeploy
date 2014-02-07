# -*- mode: ruby -*-
# vi: set ft=ruby :

if ENV.has_key?('HTTP_PROXY')
  args = [ ENV['HTTP_PROXY'] ]
else
  args = [ 'null' ]
end

if ENV.has_key?('APT_MIRROR')
  args.push( ENV['APT_MIRROR'] )
else
  args.push( 'http.us.debian.org' )
end

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.define "edeployd" do |edeploy|
    edeploy.vm.box = "debian"
    edeploy.vm.network "private_network", ip: "192.168.99.100"
    edeploy.vm.provision "shell", inline: "sed -i 's/http.us.debian.org/" + args[1] + "/g' /etc/apt/sources.list"
    edeploy.vm.provision "shell" do |s|
      s.path = "build.sh"
      s.args = args
    end
  end

  config.vm.define "targetd" do |target|
    target.vm.box = "blank"
    target.vm.network "private_network", ip: "192.168.99.55"
    target.vm.provider "virtualbox" do |v|
      v.customize ['modifyvm', :id ,'--nicbootprio2','1']
      v.customize ['modifyvm', :id ,'--memory','1024']
      v.gui = true
    end
  end
end
