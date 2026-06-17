# k8s-dev-lab

A local Kubernetes lab using Vagrant (libvirt) and
[Kubespray](https://github.com/kubernetes-sigs/kubespray) for cluster
provisioning.

Four Debian 12 VMs (the `cloud-image/debian-12` box) form a cluster where every
node runs both the control plane and workloads (control plane nodes are
untainted). Three of the four nodes host etcd.

> **Box choice:** use a libvirt-native box built from official cloud images
> (e.g. `cloud-image/debian-12`). The `generic/*` boxes from roboxes ship a
> GPT + BIOS-boot disk layout that hangs SeaBIOS at "Booting from Hard Disk…"
> under recent QEMU/libvirt, so the VMs never boot. To change the box, edit
> `config.vm.box` in the `Vagrantfile`.

## Requirements

- **vagrant** with the **vagrant-libvirt** plugin
- **libvirt / QEMU-KVM**
- **python3** with **venv** — used to install Ansible and Kubespray deps
- ~8 GB free RAM (4 × 2 GB VMs)

### libvirt permissions

Your user must be in the `libvirt` group to manage system-level VMs, networks,
and storage pools without sudo:

```
sudo usermod -aG libvirt $USER
```

Log out and back in (or run `newgrp libvirt`) for the change to take effect.

`make up` automatically creates the libvirt storage pool and network if they
don't exist. These are system-level resources (`qemu:///system`) and persist
across reboots (autostart is enabled). `make clobber` tears them down.

## Quick start

```
make cluster
```

This runs three steps in sequence:

1. `make up` — creates the VMs
2. `make deploy` — clones Kubespray and runs its Ansible playbooks
3. `make kubeconfig` — copies `admin.conf` to the project root

Once it finishes:

```
export KUBECONFIG=$(pwd)/admin.conf
kubectl get nodes
```

## Make targets

| Target       | Description                                      |
|--------------|--------------------------------------------------|
| `up`         | Create VMs with Vagrant                          |
| `deploy`     | Install Kubernetes via Kubespray                 |
| `kubeconfig` | Copy kubeconfig to `./admin.conf`                |
| `cluster`    | Full pipeline: up + deploy + kubeconfig          |
| `reset`      | Remove Kubernetes but keep the VMs               |
| `clobber`    | Destroy VMs and all generated files              |

## Configuration

### Nodes

Edit the `NODES` array at the top of `Vagrantfile` to change VM names, IPs, or
count. Match any changes in `inventory/hosts.yml`.

### Kubespray version

```
make deploy KUBESPRAY_VERSION=v2.28.0
```

The default is set in the Makefile. Kubespray is cloned into `work/kubespray/`.

### Cluster settings

Kubespray variables live in `inventory/group_vars/`:

- `all.yml` — general settings (etcd deployment type, etc.)
- `k8s_cluster.yml` — CNI plugin, container runtime, API server cert SANs

The full set of tunables is documented in Kubespray's
[inventory/sample/group_vars](https://github.com/kubernetes-sigs/kubespray/tree/master/inventory/sample/group_vars).

## Layout

```
Vagrantfile                 VM definitions (libvirt)
Makefile                    Orchestration
k8s-lab-net.xml             libvirt network (NAT + DHCP reservations)
inventory/
  hosts.yml                 Kubespray inventory (4 nodes)
  group_vars/
    all.yml                 General overrides
    k8s_cluster.yml         Cluster-level overrides
work/                       (git-ignored) Kubespray clone
```

Ansible settings come from Kubespray's own `ansible.cfg`; the `deploy` and
`reset` targets run from inside `work/kubespray/` so it is picked up.

## TODO

- Explore a local image cache / pull-through registry mirror. Each node pulls
  the full set of container images independently, so a 4-node bring-up fetches
  everything 4× over the WAN — wasteful and slow. A shared local cache (e.g. a
  `registry:2` pull-through mirror, or Kubespray's `download_run_once` /
  `download_localhost` options) would pull once and distribute internally.
