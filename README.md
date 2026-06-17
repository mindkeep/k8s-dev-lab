# k8s-dev-lab

A local Kubernetes lab using Vagrant (libvirt) and
[Kubespray](https://github.com/kubernetes-sigs/kubespray) for cluster
provisioning.

Four VMs form a cluster where every node runs both the control plane and
workloads (control plane nodes are untainted). Three of the four nodes host
etcd. The default OS is Rocky Linux 10, but the box is configurable (see
[Choosing a box](#choosing-a-box)).

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
| `inventory`  | Create `inventory/hosts.yml` from the template   |
| `deploy`     | Install Kubernetes via Kubespray                 |
| `kubeconfig` | Copy kubeconfig to `./admin.conf`                |
| `cluster`    | Full pipeline: up + deploy + kubeconfig          |
| `reset`      | Remove Kubernetes but keep the VMs               |
| `clobber`    | Destroy VMs and all generated files              |

## Configuration

### Inventory

The cluster topology (node names, IPs, and which nodes are control plane /
worker / etcd) lives in `inventory/hosts.yml`. This file is generated from
`inventory/hosts.yml.tmpl` on first use and is git-ignored, so your edits stay
local. Create or edit it with:

```
make inventory      # copies the template if hosts.yml doesn't exist yet
$EDITOR inventory/hosts.yml
```

Re-running `make inventory` never overwrites an existing `hosts.yml`. To start
over from the template, delete `hosts.yml` first.

### Nodes

To change VM names, IPs, or count, edit the `NODES` array at the top of the
`Vagrantfile`. **These must stay in sync** with `inventory/hosts.yml` — the
hostnames and IPs have to match, and each node's IP is pinned by a DHCP
reservation (MAC → IP) in `k8s-lab-net.xml`. So adding a node means updating all
three: `Vagrantfile`, `k8s-lab-net.xml`, and `inventory/hosts.yml`.

### Choosing a box

The Vagrant box defaults to `cloud-image/rocky-10`. Override it per run:

```
make up BOX=cloud-image/debian-12
```

or change the `BOX` default in the `Makefile` (or `DEFAULT_BOX` in the
`Vagrantfile` if you run `vagrant` directly).

Use a **libvirt-native** box built from official cloud images — these have a
hybrid boot layout that works under libvirt's SeaBIOS firmware. Verified
options:

| Box                        | OS              |
|----------------------------|-----------------|
| `cloud-image/rocky-10`     | Rocky Linux 10  |
| `cloud-image/rocky-9`      | Rocky Linux 9   |
| `cloud-image/almalinux-9`  | AlmaLinux 9     |
| `cloud-image/debian-12`    | Debian 12       |
| `cloud-image/ubuntu-24.04` | Ubuntu 24.04    |

> If Rocky 10 gives Kubespray trouble (EL10 support is relatively new),
> `cloud-image/rocky-9` is the safest bet.
>
> Avoid the `generic/*` boxes from roboxes: they ship a GPT + BIOS-boot disk
> layout that hangs SeaBIOS at "Booting from Hard Disk…" under recent
> QEMU/libvirt, so the VMs never boot.

To find more, browse [Vagrant Cloud](https://portal.cloud.hashicorp.com/vagrant/discover)
and confirm the box lists a **libvirt** provider before using it.

### Mixed-OS clusters (experimental)

Kubespray detects each node's OS, so a heterogeneous cluster is possible. Give a
node its own box with an optional `box:` key in the `Vagrantfile` `NODES` array:

```ruby
{ name: "k8s-4", ip: "192.168.56.14", mac: "52:54:00:ab:01:04",
  box: "cloud-image/debian-12" },
```

Nodes without a `box:` key use the default. This is wired up but not yet
tested — treat it as a starting point.

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
  hosts.yml.tmpl            Inventory template (tracked)
  hosts.yml                 Working inventory (git-ignored, generated)
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
