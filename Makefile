ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

KUBESPRAY_VERSION ?= v2.31.0
KUBESPRAY_REPO = https://github.com/kubernetes-sigs/kubespray.git
KUBESPRAY_DIR = $(ROOT_DIR)/work/kubespray
INVENTORY = $(ROOT_DIR)/inventory
HOSTS = $(INVENTORY)/hosts.yml
VENV = $(ROOT_DIR)/.venv
KUBECONFIG_FILE = $(ROOT_DIR)/admin.conf

# Vagrant box for the nodes. Override at the CLI: `make up BOX=cloud-image/debian-12`.
BOX ?= cloud-image/rocky-10

export VAGRANT_DEFAULT_PROVIDER = libvirt
export LIBVIRT_DEFAULT_URI = qemu:///system
export BOX

.PHONY: all libvirt up inventory deploy kubeconfig cluster reset clobber

all:
	@echo ""
	@echo "  up         - create VMs with vagrant"
	@echo "  inventory  - create inventory/hosts.yml from the template"
	@echo "  deploy     - run kubespray to install kubernetes"
	@echo "  kubeconfig - copy kubeconfig to ./admin.conf"
	@echo "  cluster    - full pipeline: up + deploy + kubeconfig"
	@echo "  reset      - tear down kubernetes (keeps VMs)"
	@echo "  clobber    - destroy VMs and all generated files"
	@echo ""

$(KUBESPRAY_DIR):
	mkdir -p $(ROOT_DIR)/work
	git clone --depth 1 --branch $(KUBESPRAY_VERSION) $(KUBESPRAY_REPO) $(KUBESPRAY_DIR)

$(VENV)/.kubespray-deps: $(KUBESPRAY_DIR)
	python3 -m venv $(VENV)
	$(VENV)/bin/pip install -r $(KUBESPRAY_DIR)/requirements.txt
	touch $@

libvirt:
	@virsh pool-info default >/dev/null 2>&1 || \
	  (virsh pool-define-as default dir --target /var/lib/libvirt/images && virsh pool-start default && virsh pool-autostart default)
	@virsh net-info k8s-lab >/dev/null 2>&1 || \
	  (virsh net-define $(ROOT_DIR)/k8s-lab-net.xml && virsh net-start k8s-lab && virsh net-autostart k8s-lab)

up: libvirt
	vagrant up

# Create the working inventory from the template if it doesn't exist yet.
# The template is not a prerequisite, so existing edits are never overwritten.
$(HOSTS):
	cp $(HOSTS).tmpl $(HOSTS)

inventory: $(HOSTS)

deploy: $(VENV)/.kubespray-deps $(HOSTS)
	cd $(KUBESPRAY_DIR) && $(VENV)/bin/ansible-playbook \
	  -i $(HOSTS) \
	  cluster.yml \
	  -b --become-user=root

kubeconfig:
	@test -f $(INVENTORY)/artifacts/admin.conf \
	  || (echo "Run 'make deploy' first." && exit 1)
	cp $(INVENTORY)/artifacts/admin.conf $(KUBECONFIG_FILE)
	sed -i 's|server: https://127.0.0.1:.*|server: https://192.168.56.11:6443|' $(KUBECONFIG_FILE)
	@echo ""
	@echo "export KUBECONFIG=$(KUBECONFIG_FILE)"
	@echo ""

cluster: up deploy kubeconfig
	@echo "Cluster ready."

reset: $(VENV)/.kubespray-deps $(HOSTS)
	cd $(KUBESPRAY_DIR) && $(VENV)/bin/ansible-playbook \
	  -i $(HOSTS) \
	  reset.yml \
	  -b --become-user=root \
	  -e reset_confirmation=yes

clobber:
	vagrant destroy -f || true
	-virsh net-destroy k8s-lab 2>/dev/null; virsh net-undefine k8s-lab 2>/dev/null; true
	rm -rf .vagrant .venv work $(KUBECONFIG_FILE) $(INVENTORY)/artifacts
