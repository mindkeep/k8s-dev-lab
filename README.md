
# k8s-dev-lab

This repo is intended as laboratory for testing various kubernetes deployments.

[[TOC]]

## Requirements

vagrant
virtualbox
roughly 6G ram or the VMs

## K8s Cluster setup

...

vagrant up

That's it! Hopefully...

Vagrant will create the VMs via virtualbox and provision Kubernetes via ansible.

## Notes

This creates 3 VMs by default.
At the moment k8s-1 is the master node, and k8s-2 and k8s-3 are the workers. I'd like to change this so that all nodes are configured to be master/control-plane and schedulable.

## TODO

This is a pretty quick and dirty start that will hopefully grow a bit as I go.

This first cut is using k8s, but I'm hoping to add some conditional logic around k8s vs rke vs k3s (maybe). I'm also going to start with flannel as the CNI, but may look into calico as well.

## Reference
https://kubernetes.io/blog/2019/03/15/kubernetes-setup-using-ansible-and-vagrant/ - this was very useful as a starting guide, and now that I'm looking there are several other projects with similar goals.
