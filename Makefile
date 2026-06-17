ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

KUBESPRAY_VERSION ?= v2.31.0
KUBESPRAY_REPO = https://github.com/kubernetes-sigs/kubespray.git
KUBESPRAY_DIR = $(ROOT_DIR)/work/kubespray
INVENTORY = $(ROOT_DIR)/inventory
HOSTS = $(INVENTORY)/hosts.yml
VENV = $(ROOT_DIR)/.venv
KUBECONFIG_FILE = $(ROOT_DIR)/admin.conf

# Vagrant box for the nodes. Override at the CLI: `make up BOX=cloud-image/debian-12`.
BOX ?= cloud-image/rocky-9
# Box architecture. Vagrant < 2.4 ignores a box's architecture field and may
# fetch the wrong build (e.g. arm64 on an amd64 host) for multi-arch boxes, so
# we pin and pre-fetch it explicitly. See the `box` target.
BOX_ARCH ?= amd64

export VAGRANT_DEFAULT_PROVIDER = libvirt
export LIBVIRT_DEFAULT_URI = qemu:///system
export BOX

.PHONY: all libvirt box up inventory deploy kubeconfig cluster reset clobber

all:
	@echo ""
	@echo "  box        - pre-fetch the $(BOX_ARCH) box (forces arch on Vagrant < 2.4)"
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

# Ensure the box is present at the pinned architecture. Vagrant < 2.4 can't
# select architecture for multi-arch boxes, so we resolve the $(BOX_ARCH)
# download URL from Vagrant Cloud, fetch the .box with curl (which handles the
# redirect chain), and add it from the local file -- passing the URL directly
# makes Vagrant misparse it as box metadata. Skipped if the box already exists.
box:
	@vagrant box list 2>/dev/null | grep -q '^$(BOX) ' \
	  && { echo "box '$(BOX)' already present"; exit 0; }; \
	set -e; \
	echo "resolving '$(BOX)' ($(BOX_ARCH))..."; \
	url=$$(curl -fsSL "https://app.vagrantup.com/api/v2/box/$(BOX)" | python3 -c 'import sys,json; d=json.load(sys.stdin); v=d["current_version"]["providers"]; print(next(p["download_url"] for p in v if p["name"]=="libvirt" and p.get("architecture")=="$(BOX_ARCH)"))'); \
	mkdir -p $(ROOT_DIR)/work; \
	tmp=$$(mktemp -p $(ROOT_DIR)/work --suffix=.box); \
	trap 'rm -f "$$tmp"' EXIT; \
	echo "downloading box..."; \
	curl -fSL "$$url" -o "$$tmp"; \
	vagrant box add --name '$(BOX)' "$$tmp"

up: libvirt box
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
	vagrant destroy -f 2>/dev/null; \
	for dom in $(shell virsh list --all --name 2>/dev/null | grep '^k8s-dev-lab_'); do \
	  virsh destroy "$$dom" 2>/dev/null; virsh undefine "$$dom" --remove-all-storage 2>/dev/null; \
	done; true
	virsh net-destroy k8s-lab 2>/dev/null; virsh net-undefine k8s-lab 2>/dev/null; true
	rm -rf .vagrant .venv work $(KUBECONFIG_FILE) $(INVENTORY)/artifacts
