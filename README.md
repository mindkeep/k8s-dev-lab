
# k8s-dev-lab

This repo is intended as laboratory for testing various kubernetes deployments.

## Requirements

vagrant
virtualbox
roughly 6G ram (3 x 2G) for the VMs

## K8s Cluster setup

...

~~vagrant up~~
./scripts/setup_k8s.sh

That's it! Hopefully...

Vagrant will create the VMs via virtualbox.
Ansible will provision Kubernetes.
I separated these for more flexibility and to allow different configuration scenarios.

## Notes

This creates 3 VMs by default.
At the moment k8s-1 is the master node, and k8s-2 and k8s-3 are the workers. I'd like to change this so that all nodes are configured to be master/control-plane and schedulable.

## TODO

* make all nodes control-plane and workers
* maybe add redhat package management
* seperate plays into k8s and rke installation (rke will likely be the default later, but starting with k8s)
* add options for cni

This is a pretty quick and dirty start that will hopefully grow a bit as I go.

This first cut is using k8s, but I'm hoping to add some conditional logic around k8s vs rke vs k3s (maybe). I'm also going to start with flannel as the CNI, but may look into calico as well.

## Reference
https://kubernetes.io/blog/2019/03/15/kubernetes-setup-using-ansible-and-vagrant/ - this was very useful as a starting guide, and now that I'm looking there are several other projects with similar goals.
