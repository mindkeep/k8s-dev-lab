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
RKE2_BINARY = $(WORK_DIR)/rke2

OS = $(shell uname -s | tr A-Z a-z)
RKE_ARCH = $(shell uname -m | sed -e s/x86_64/amd64/ -e s/armv8\*/arm64/ -e s/aarch64*/arm64/)
K3S_NAME = k3s  # TODO rename for other archs
RKE_URL = https://github.com/rancher/rke/releases/latest/download/rke_$(OS)-$(RKE_ARCH)
RKE2_URL = https://github.com/rancher/rke2/releases/latest/download/rke2.$(OS)-$(RKE_ARCH)
K3S_URL = https://github.com/k3s-io/k3s/releases/latest/download/$(K3S_NAME)

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

$(RKE2_BINARY): $(WORK_DIR)
	curl --output $(RKE2_BINARY) --location $(RKE2_URL)
	chmod +x $(RKE2_BINARY)

$(K3S_BINARY): $(WORK_DIR)
	curl --output $(K3S_BINARY) --location $(K3S_URL)
	chmod +x $(K3S_BINARY)

init: $(CONFIG) $(WORK_DIR)

vagrant_up: init
	vagrant up

ansible_common:
	ansible-playbook \
	  -i .vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory \
	  ansible/common.yml

ansible_k8s:
	ansible-playbook \
	  -i .vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory \
	  ansible/build_k8s.yml

clean_k8s:
	ansible-playbook \
	  -i .vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory \
	  ansible/clean_k8s.yml

rke_up: $(RKE_BINARY)
	$(RKE_BINARY) up

rke2_up: $(RKE2_BINARY)
	$(RKE2_BINARY) up

clean_rke: $(RKE_BINARY)
	$(RKE_BINARY) remove --force

clean_rke2: $(RKE2_BINARY)
	$(RKE2_BINARY) remove --force

verify:
	@echo Updating KUBECONFIG with new context
	cp ~/.kube/config ~/.kube/config.bak
	KUBECONFIG=~/.kube/config.bak:$(KUBECONFIG) kubectl config view --flatten > ~/.kube/config
	kubectl get nodes
	@echo
	@echo All Done!
	@echo

k8s: init vagrant_up ansible_k8s verify

rke: init $(RKE_BINARY) vagrant_up ansible_common rke_up verify

rke2: init $(RKE2_BINARY) vagrant_up ansible_common rke2_up verify

clobber:
	vagrant destroy -f
	rm -rf .vagrant cluster.rkestate $(WORK_DIR) $(KUBECONFIG)
