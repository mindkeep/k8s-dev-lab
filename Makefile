#
# k8s-dev-lab Makefile
#

ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

CONFIG = $(ROOT_DIR)/cluster.yml
CONFIG_TMPL = $(ROOT_DIR)/cluster.yml.tmpl
KUBECONFIG = $(ROOT_DIR)/kube_config_cluster.yml
ANSIBLE_CONFIG = $(ROOT_DIR)/ansible/ansible.cfg

WORK_DIR = $(ROOT_DIR)/work
RKE_BINARY = $(WORK_DIR)/rke

# I'd really like to make the _linux-amd64 more dynamic, but have yet to find the right command
RKE_URL = https://github.com/rancher/rke/releases/latest/download/rke_linux-amd64

export KUBECONFIG
export ANSIBLE_CONFIG

all:
	@cat usage.md

$(CONFIG):
	cp $(CONFIG_TMPL) $(CONFIG)

$(WORK_DIR):
	mkdir -p $(WORK_DIR)

$(RKE_BINARY): $(WORK_DIR)
	curl --output $(RKE_BINARY) --location $(RKE_URL)
	chmod +x $(RKE_BINARY)

init: $(CONFIG) $(WORK_DIR)

vagrant_up: init
	vagrant up

ansible_common: vagrant_up
	ansible-playbook \
	  -i .vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory \
	  ansible/common.yml

ansible_k8s: vagrant_up
	ansible-playbook \
	  -i .vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory \
	  ansible/build_k8s.yml

clean_k8s:
	ansible-playbook \
	  -i .vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory \
	  ansible/clean_k8s.yml
	rm $(ANSIBLE_CONFIG)

rke_up: $(RKE_BINARY)
	$(RKE_BINARY) up

clean_rke: $(RKE_BINARY)
	$(RKE_BINARY) remove --force
	rm $(ANSIBLE_CONFIG)

verify:
	kubectl get nodes
	@echo
	@echo All Done!
	@echo
	@echo Remember to \"export KUBECONFIG=$(shell pwd)/$(KUBECONFIG)\"
	@echo

k8s: init vagrant_up ansible_k8s verify

rke: init $(RKE_BINARY) vagrant_up ansible_common rke_up verify

clobber:
	vagrant destroy -f
	rm -rf .vagrant cluster.rkestate $(WORK_DIR) $(KUBECONFIG)
