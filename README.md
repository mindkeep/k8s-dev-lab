# k8s-dev-lab

A local Kubernetes lab using Vagrant (libvirt) and
[Kubespray](https://github.com/kubernetes-sigs/kubespray) for cluster
provisioning.

Four VMs form a cluster where every node runs both the control plane and
workloads (control plane nodes are untainted). Three of the four nodes host
etcd. The default OS is Rocky Linux 9, but the box is configurable (see
[Choosing a box](#choosing-a-box)).

See [NOTES.md](NOTES.md) for a running log of key findings, gotchas, and the
reasoning behind some of the configuration choices.

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

The Vagrant box defaults to `cloud-image/rocky-9`. Override it per run:

```
make up BOX=cloud-image/debian-12
```

or change the `BOX` default in the `Makefile` (or `DEFAULT_BOX` in the
`Vagrantfile` if you run `vagrant` directly).

Use a **libvirt-native** box built from official cloud images — these have a
hybrid boot layout that works under libvirt's SeaBIOS firmware. Verified
options:

| Box                        | OS              | Status        |
|----------------------------|-----------------|---------------|
| `cloud-image/rocky-9`      | Rocky Linux 9   | default       |
| `cloud-image/almalinux-9`  | AlmaLinux 9     | EL9, untested |
| `cloud-image/debian-12`    | Debian 12       | boots + SSH   |
| `cloud-image/ubuntu-24.04` | Ubuntu 24.04    | untested      |
| `cloud-image/rocky-10`     | Rocky Linux 10  | experimental  |

> **Rocky 10 is experimental in Kubespray and currently does not produce a
> working cluster here.** The playbook completes, but the dataplane is broken:
> kube-proxy's default IPVS mode fails because the `ipset` binary is missing,
> Kubespray pulls a newer kernel than the running one (modules require a node
> reboot), and Cilium's init container fails to install its host binaries.
> Kubespray's own docs note the official Rocky 10 cloud image lacks
> `kernel-module-extra` and recommend a custom image. Use Rocky 9 unless you
> want to chase these down.
>
> Avoid the `generic/*` boxes from roboxes: they ship a GPT + BIOS-boot disk
> layout that hangs SeaBIOS at "Booting from Hard Disk…" under recent
> QEMU/libvirt, so the VMs never boot.

To find more, browse [Vagrant Cloud](https://portal.cloud.hashicorp.com/vagrant/discover)
and confirm the box lists a **libvirt** provider before using it.

#### Box architecture (Vagrant < 2.4)

The `cloud-image/*` boxes are multi-arch (amd64 + arm64). Vagrant 2.4+ selects
the right one automatically, but **older Vagrant (e.g. 2.3.x on Fedora) ignores
the architecture field** and may fetch the arm64 build on an amd64 host — those
VMs hang at "Booting from Hard Disk…" because the disk has no x86 bootloader.

To avoid that, `make box` (run automatically by `make up`) resolves the correct
build from Vagrant Cloud and pre-adds it. The architecture defaults to `amd64`;
override with `make up BOX_ARCH=arm64` on an ARM host. If a box of the target
name is already installed, `make box` leaves it alone — remove a wrong-arch box
first with `vagrant box remove <name>`.

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

- `all.yml` — general settings (etcd deployment type, remote Python interpreter)
- `k8s_cluster.yml` — CNI plugin, container runtime, API server cert SANs,
  `kube_owner`

The full set of tunables is documented in Kubespray's
[inventory/sample/group_vars](https://github.com/kubernetes-sigs/kubespray/tree/master/inventory/sample/group_vars).

#### Cilium + `kube_owner`

We set `kube_owner: root`. Cilium v1.19's init containers run as root with
`DAC_OVERRIDE` dropped and cannot write to `/opt/cni/bin` when Kubespray creates
it owned by the default `kube` user — the agents crash-loop with
`cp: cannot create regular file '/hostbin/cilium-mount': Permission denied` and
nodes never go `Ready`. Root-owning the dir fixes it; the control plane runs as
root regardless. If you switch to Calico or Flannel, this override is harmless
but no longer required.

## Layout

```
Vagrantfile                 VM definitions (libvirt)
Makefile                    Orchestration
NOTES.md                    Running log of findings and gotchas
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
