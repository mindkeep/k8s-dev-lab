#!/bin/bash

set -e

vagrant up

ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook \
  -i .vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory \
  ansible/build_k8s.yml

echo "All done!"
echo
echo "# KUBECONFIG=work/kube.config kubectl get nodes"
KUBECONFIG=work/kube.config kubectl get nodes

echo
echo "Use \"KUBECONFIG=work/kube.config kubectl ... \" to start working with your kubernetes cluster."
echo
