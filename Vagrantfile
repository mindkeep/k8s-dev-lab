# -*- mode: ruby -*-
# vi: set ft=ruby :

# Default Vagrant box for all nodes. Override per-run with `make up BOX=...`
# (the Makefile exports BOX), or set a per-node `box:` in NODES below for a
# mixed-OS cluster. Use a libvirt-native box built from official cloud images;
# see the README for recommendations.
DEFAULT_BOX = ENV.fetch("BOX", "cloud-image/rocky-10")

# Node definitions. The name/ip/mac here must stay in sync with
# inventory/hosts.yml and the DHCP reservations in k8s-lab-net.xml.
# Add an optional `box:` key to any node to run a different OS on it.
NODES = [
  { name: "k8s-1", ip: "192.168.56.11", mac: "52:54:00:ab:01:01" },
  { name: "k8s-2", ip: "192.168.56.12", mac: "52:54:00:ab:01:02" },
  { name: "k8s-3", ip: "192.168.56.13", mac: "52:54:00:ab:01:03" },
  { name: "k8s-4", ip: "192.168.56.14", mac: "52:54:00:ab:01:04" },
]

Vagrant.configure("2") do |config|
  config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.provider :libvirt do |lv|
    lv.cpus = 2
    lv.memory = 2048
    lv.management_network_name = "k8s-lab"
    lv.management_network_address = "192.168.56.0/24"
    lv.management_network_mode = "nat"
  end

  NODES.each do |node|
    config.vm.define node[:name] do |n|
      n.vm.hostname = node[:name]
      n.vm.box = node.fetch(:box, DEFAULT_BOX)
      n.vm.provider :libvirt do |lv|
        lv.management_network_mac = node[:mac]
      end
    end
  end
end
