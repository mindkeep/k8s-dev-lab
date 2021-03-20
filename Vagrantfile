# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'

cluster_yml = YAML.load_file("cluster.yml")

Vagrant.configure("2") do |config|

  config.vm.box = "ubuntu/bionic64"

  # this is a bit of a hack
  # Vagrant doesn't seem smart enough to set host_vars for each generated
  # inventory line, it only retains the last nodes setting for all nodes.
  # To work around this, we add to the hash and set it each time within
  # the provision step.
  host_vars = {}
  nodes = cluster_yml['nodes']

 nodes.each do |node_cfg|
    #hostname = "wat"
    hostname = node_cfg['hostname_override']
    ip = node_cfg['address']

    config.vm.define hostname do |node|
      node.vm.hostname = hostname
      node.vm.network "private_network", ip: ip

      config.vm.provider "virtualbox" do |vb|
        vb.cpus = 2
        vb.memory = 2048
        vb.gui = false
        # need to research these a bit more to understand impact, but it works
        vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
        vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
      end

      node.vm.provision "ansible" do |ansible|
        # This is mostly a stub to set the host_vars, but helpful for newbies
        ansible.playbook = "ansible/dump_facts.yml"
        # add to global host_var and assign it to ansible hostvars each time
        # to get these in the inventory file
        host_vars[hostname] = {
          "hostname" => hostname,
          "node_ip" => ip
        }
        ansible.host_vars = host_vars
      end
    end
  end
end
