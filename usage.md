# k8s-dev-lab make usage

## make k8s
Makes a basic kubernetes cluster.

## make clean_k8s
Attempts to clean k8s configuration, but preserves VM instances.

## make rke
Makes a basic rke kubernetes cluster using cluster.yml.
This file will be copied from cluster.yml.tmpl, but you can easily
experiment with addition options.

## make clean_rke
Calls "rke remove", but not exactly a thorough clean... yet

## make clobber
Completely blows away the VMs and brings things to a blank slate.
