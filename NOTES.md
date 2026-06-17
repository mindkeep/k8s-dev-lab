# Notes

Running log of key findings and gotchas from building out this lab. Newest
first.

## 2026-06-17 — Migration to libvirt + Kubespray, first working cluster

Brought the lab up from scratch on libvirt + Kubespray and got a healthy
4-node cluster. The work was mostly a chain of environment/OS issues rather
than anything in the project's own logic. Recording them so they don't have to
be rediscovered.

**Final working setup**

- 4 × `cloud-image/rocky-9` VMs on libvirt, 2 vCPU / 2 GB each
- Single NAT network (`k8s-lab`) with DHCP reservations for stable IPs
  (192.168.56.11–14)
- Kubespray v2.31.0, Kubernetes v1.35.4, containerd, Cilium CNI
- All nodes control plane + worker (untainted); 3 etcd members
- Verified: `make cluster` from a clean slate → all nodes `Ready`, Cilium +
  kube-proxy healthy, workloads schedule across all 4 nodes

### Issues hit and how they were fixed

1. **VMs hung at SeaBIOS "Booting from Hard Disk…"**
   The roboxes `generic/*` boxes ship a disk layout that doesn't boot under
   libvirt's SeaBIOS firmware (and the multi-arch variants made it worse — see
   below). Switched to libvirt-native `cloud-image/*` boxes built from official
   cloud images, which have a hybrid boot layout that works.
   Diagnosed with `virsh screenshot` + serial console — the OS never started,
   so it looked like a network problem but wasn't.

2. **VMs never got an IP ("Waiting for domain to get an IP address…")**
   libvirt doesn't auto-create a network from a bare IP the way VirtualBox
   does, and DHCP needs an explicit range plus the bridge in firewalld's
   `libvirt` zone. Defined `k8s-lab-net.xml` as a NAT network with a DHCP range
   and MAC→IP reservations; the Makefile creates it (and the storage pool)
   before `vagrant up`.

3. **Wrong CPU architecture pulled (arm64 on an amd64 host)**
   Vagrant 2.3.4 (Fedora's package) predates architecture-aware box selection
   and grabbed the arm64 build of a multi-arch `cloud-image` box — the VM then
   hung in SeaBIOS because the disk had no x86 bootloader. Added a `make box`
   target that resolves the correct-arch `.box` URL from Vagrant Cloud, fetches
   it with curl, and adds it from the local file (passing the URL directly
   makes Vagrant misparse it as box metadata). Did **not** upgrade Vagrant —
   Fedora's distro vagrant + vagrant-libvirt work together and HashiCorp's
   build is fragile to pair with libvirt on Fedora.

4. **`/usr/bin/python3.11: No such file or directory` during `bootstrap_os`**
   Ansible-core 2.18's interpreter auto-discovery maps EL10 to python3.11, but
   the cloud images ship a different Python. Pinned
   `ansible_python_interpreter: /usr/bin/python3` in `group_vars/all.yml`
   (OS-agnostic — correct on Rocky 9/10, Debian, Fedora, Ubuntu).

5. **Rocky 10 doesn't produce a working cluster (experimental)**
   The playbook completes, but the dataplane is broken: kube-proxy's default
   IPVS mode fails because the `ipset` binary is missing, and Kubespray pulls a
   newer kernel than the running one so modules don't match until a reboot.
   Kubespray's own docs note the official Rocky 10 cloud image lacks
   `kernel-module-extra` and recommend a custom image. Dropped the default to
   **Rocky 9** (fully supported, and the most representative target for real
   RHEL/Rocky hardware). Rocky 10 left documented as experimental.

6. **Cilium agents crash-looped; nodes stayed `NotReady`** (the real find)
   `cp: cannot create regular file '/hostbin/cilium-mount': Permission denied`.
   Cilium v1.19's init containers (`mount-cgroup`, `install-cni-binaries`) run
   as root with `DAC_OVERRIDE` dropped, so they can't write to `/opt/cni/bin`
   when Kubespray creates it owned by the default `kube` user (mode 0755).
   This is OS-independent — it reproduced identically on Rocky 9 and Rocky 10.
   Confirmed by `chown root:root /opt/cni/bin` + bouncing the Cilium pods (they
   went healthy immediately), then made reproducible with `kube_owner: root`.

### Takeaways

- For libvirt, always use a box that explicitly lists a **libvirt** provider
  built from official cloud images; avoid roboxes `generic/*`.
- On Vagrant < 2.4, pin box architecture yourself — don't trust auto-selection.
- "Playbook completed" ≠ "cluster works." Always check `kubectl get nodes` and
  the CNI/kube-proxy pods; Kubespray can finish green with a dead dataplane.
- `virsh screenshot` is the fastest way to tell a boot failure from a network
  failure.

### Still open

- Local image cache / pull-through registry mirror — each node pulls all
  images independently (4× over the WAN). See the TODO in the README.
- Mixed-OS clusters are wired up (per-node `box:`) but untested.
- Kubespray pinned at v2.31.0; Cilium is the CNI per the original design.
