# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  config.vm.box = "ubuntu/bionic64"

  (1..3).each do |i|
    hostname = "k8s-#{i}"
    ip = "192.168.99.#{i + 10}"
    
    config.vm.define hostname do |node|
      node.vm.hostname = hostname
      node.vm.network "private_network", ip: ip

      config.vm.provider "virtualbox" do |vb|
        vb.cpus = 2
        vb.memory = 2048
      end

      node.vm.provision "ansible" do |ansible|
        if i == 1
          ansible.playbook = "ansible/create_cluster.yml"
        else
          ansible.playbook = "ansible/join_cluster.yml"
        end
        ansible.extra_vars = {
          hostname: hostname,
          node_ip: ip
        }
      end
    end
  end
end
