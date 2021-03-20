
# k8s-dev-lab

This repo is intended as laboratory for testing various kubernetes deployments.

## Requirements

vagrant
virtualbox
roughly 6G ram (3 x 2G) for the VMs

## make targets

[usage](usage.md)

Run either _make rke_ or _make k8s_ and you should be off to the races.

## Configuration

*cluster.yml* (copied from cluster.yml.tmpl if not present) is defined by
Rancher's RKE
[cluster.yml](https://rancher.com/docs/rke/latest/en/example-yamls/) format.
This file is read in Vagrantfile to create the virtualbox VMs. It reads the
nodes list and uses *hostname_override* and *address* for VM creation. (While
*hostname_override* is not typically required for RKE, it is for this project's
Vagrantfile.)

Depending on whether you ran with _make rke_ or _make k8s_, this will create a
k8s cluster (using kubeadm/kubelet) or use RKE's container based approach,
respectively.

With _make rke_, you get all the flexibility available in RKE itself. With a
small bit of ansible automation to install the docker runtime.

With _make k8s_, the cluster creation is entirely driven via ansible (and is
much more limited in flexibility (at least for now)). ansible/build_k8s.yml
currently expects 3 VMs (no more, no less). Future versions will try to further
leverage cluster.yml to make this more dynamic.

## TODO

* update ansible k8s to read cluster.yml's roles and allow for variable VMS and configuration.
* maybe add redhat package management
* add support for different CNI's in k8s
* add a k3s target/implementation

This is a pretty quick and dirty start that will hopefully grow a bit as I go.

This first cut used K8s, but RKE makes so much of this easy... My goal is to
learn and evaluation different kubernetes implementations, so I'm going to try
to get these somewhat feature comparable.

## Reference
https://kubernetes.io/blog/2019/03/15/kubernetes-setup-using-ansible-and-vagrant/
- this was very useful as a starting guide, and now that I'm looking there are
several other projects with similar goals.
