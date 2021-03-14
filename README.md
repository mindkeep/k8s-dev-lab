
# k8s-dev-lab

This repo is intended as laboratory for testing various kubernetes deployments.

## Requirements

vagrant
virtualbox
roughly 6G ram (3 x 2G) for the VMs

## make targets

[usage](usage.md)

Run either "make rke" or "make k8s" and you should be off to the races.

## Notes

This creates 3 VMs by default. You can modify rke's cluster.yml to tweak settings, but for the moment vagrant only sets up 3 VMs.
k8s-1 is the master node, and k8s-2 and k8s-3 are the workers. I'd like to change this so that all nodes are configured to be master/control-plane and schedulable.

## TODO

* make vagrant read cluster.yml to dynamically configure a different number of VMS.
* maybe add redhat package management
* add options for cni (rke has this, but k8s is hard coded to flannel)

This is a pretty quick and dirty start that will hopefully grow a bit as I go.

This first cut is using k8s, but I'm hoping to add some conditional logic around k8s vs rke vs k3s (maybe). I'm also going to start with flannel as the CNI, but may look into calico as well.

## Reference
https://kubernetes.io/blog/2019/03/15/kubernetes-setup-using-ansible-and-vagrant/ - this was very useful as a starting guide, and now that I'm looking there are several other projects with similar goals.
