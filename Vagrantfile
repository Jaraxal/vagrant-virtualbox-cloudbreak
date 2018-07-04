# -*- mode: ruby -*-
# vi: set ft=ruby :

# Using yaml to load external configuration files
require 'yaml'

Vagrant.configure("2") do |config|
  # Using the hostmanager vagrant plugin to update the host files
  config.hostmanager.enabled = true
  config.hostmanager.manage_host = true
  config.hostmanager.manage_guest = true
  config.hostmanager.ignore_private_ip = false

  # Run install script
  config.vm.provision "shell", path: "install.sh"

  # Loading in the VM configuration information
  servers = YAML.load_file('servers.yaml')

  servers.each do |servers| 
    config.vm.define servers["name"] do |srv|
      srv.ssh.username = "vagrant"
      srv.ssh.password = "vagrant"

      srv.vm.box = servers["box"] # Speciy the name of the Vagrant box file to use
      srv.vm.hostname = servers["name"] # Set the hostname of the VM
      srv.vm.network "private_network", ip: servers["ip"], :adapater=>2 # Add a second adapater with a specified IP
      #srv.vm.network :forwarded_port, guest: 22, host: servers["port"] # Add a port forwarding rule
      srv.vm.network :forwarded_port, guest: 443, host: 10443 # Add a port forwarding rule
      srv.vm.provision :shell, inline: "sed -i'' '/^127.0.0.1\\t#{srv.vm.hostname}\\t#{srv.vm.hostname}$/d' /etc/hosts" # Remove the extraneous first entry in /etc/hosts

      srv.vm.provider :virtualbox do |vb|
        vb.name = servers["name"] # Name of the VM in VirtualBox
        vb.cpus = servers["cpus"] # How many CPUs to allocate to the VM
        vb.memory = servers["ram"] # How much memory to allocate to the VM
      end
    end
  end
end
