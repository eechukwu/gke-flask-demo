# Kubernetes Inner Workings - 14-Day Hands-On Lab Guide 🧪

> A practical lab guide to master Kubernetes internals through daily hands-on exercises.

---

## 📋 Table of Contents

- [Lab Setup](#lab-setup)
- [Day 1: Architecture & Components](#day-1-kubernetes-architecture--components)
- [Day 2: etcd Deep Dive](#day-2-etcd-deep-dive)
- [Day 3: Networking Fundamentals](#day-3-networking-fundamentals)
- [Day 4: CNI & Service Networking](#day-4-cni-plugins--service-networking)
- [Day 5: DNS & Network Policies](#day-5-dns--network-policies)
- [Day 6: Scheduler & Resources](#day-6-scheduler--resource-management)
- [Day 7: Storage & CSI](#day-7-storage--csi)
- [Day 8: RBAC & Security](#day-8-rbac--security)
- [Day 9: Certificates](#day-9-certificates--authentication)
- [Day 10: Cluster Upgrades](#day-10-cluster-upgrades)
- [Day 11: Backup & DR](#day-11-backup--disaster-recovery)
- [Day 12: Troubleshooting Control Plane](#day-12-troubleshooting-control-plane)
- [Day 13: Troubleshooting Networking](#day-13-troubleshooting-networking)
- [Day 14: Advanced Scenarios](#day-14-advanced-scenarios)
- [Deep Interview Questions](#deep-interview-questions)

**Total Time:** ~18 hours (practice at your own pace)

---

## Lab Setup

### Prerequisites

- Linux/Mac (or WSL2 on Windows)
- 8GB RAM minimum (16GB recommended)
- 30GB free disk space
- Docker installed

### Option 1: kubeadm (Recommended - Production-Like)

#### Step 1: Create VMs with Vagrant

```bash
# Install Vagrant and VirtualBox (Ubuntu/Debian)
sudo apt-get install vagrant virtualbox

# Create Vagrantfile
cat > Vagrantfile <<'EOF'
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  
  config.vm.define "master" do |master|
    master.vm.hostname = "k8s-master"
    master.vm.network "private_network", ip: "192.168.56.10"
    master.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = 2
    end
  end
  
  (1..2).each do |i|
    config.vm.define "worker#{i}" do |worker|
      worker.vm.hostname = "k8s-worker#{i}"
      worker.vm.network "private_network", ip: "192.168.56.#{10+i}"
      worker.vm.provider "virtualbox" do |vb|
        vb.memory = "2048"
        vb.cpus = 2
      end
    end
  end
end
EOF

vagrant up
vagrant ssh master
```

#### Step 2: Install Kubernetes (Run on ALL nodes)

```bash
sudo su -

# Disable swap
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Load kernel modules
cat <<EOF | tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Configure sysctl
cat <<EOF | tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system

# Install containerd
apt-get update
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Install kubeadm, kubelet, kubectl
apt-get install -y apt-transport-https ca-certificates curl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | \
  gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | \
  tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
```

#### Step 3: Initialize Master Node

```bash
# On master node only
kubeadm init --apiserver-advertise-address=192.168.56.10 --pod-network-cidr=10.244.0.0/16

# Setup kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install Calico CNI
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml
```

#### Step 4: Join Worker Nodes

```bash
# On each worker, run the join command from master output:
sudo kubeadm join 192.168.56.10:6443 --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

#### Verify Setup

```bash
kubectl get nodes
# Should show: master + 2 workers in Ready state
```

---

### Option 2: kind (Faster Setup)

```bash
# Install kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Create multi-node cluster
cat > kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
EOF

kind create cluster --config kind-config.yaml --name lab-cluster

# Install CNI
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml
```

---

## Day 1: Kubernetes Architecture & Components

**Learning Objectives:**
- Understand control plane components
- Understand node components  
- See how components communicate

### Exercise 1.1: Explore Control Plane

```bash
# List control plane pods
kubectl get pods -n kube-system

# Describe API server
kubectl describe pod -n kube-system kube-apiserver-<name>
```

**📝 Questions:**
1. How many containers in the etcd pod?
2. What port does API server listen on?
3. What command does scheduler use?

### Exercise 1.2: Component Logs

```bash
# View API server logs
kubectl logs -n kube-system kube-apiserver-<name> | head -50

# View scheduler logs  
kubectl logs -n kube-system kube-scheduler-<name> -f

# Create deployment and watch scheduler
kubectl create deployment nginx --image=nginx --replicas=3
```

### Exercise 1.3: Component Communication

```bash
# Check API endpoint
kubectl cluster-info

# On master node - check kubelet config
sudo cat /etc/kubernetes/kubelet.conf | grep server

# View certificates
sudo ls -la /etc/kubernetes/pki/
```

### Exercise 1.4: Simulate Failure

```bash
# Create test deployment
kubectl create deployment test --image=nginx --replicas=3

# Stop scheduler (on master)
sudo systemctl stop kube-scheduler

# Try scaling - pods stay Pending
kubectl scale deployment test --replicas=5
kubectl get pods

# Restart scheduler
sudo systemctl start kube-scheduler
```

**📝 Daily Summary:**
- Document which component does what
- Draw architecture diagram from memory
- Note what happens when each component fails

---

## Day 2: etcd Deep Dive

**Learning Objectives:**
- Understand etcd architecture
- Practice backup and restore
- Learn etcd operations

### Exercise 2.1: Access etcd

```bash
# Create alias for easier access
alias etcdctl='sudo ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key'

# Check members
etcdctl member list
```

### Exercise 2.2: Explore Data

```bash
# List all keys
etcdctl get / --prefix --keys-only | head -20

# Get pods
etcdctl get /registry/pods --prefix --keys-only

# Count keys
etcdctl get / --prefix --keys-only | wc -l
```

**📝 Task:** Create a ConfigMap and find it in etcd

```bash
kubectl create configmap test --from-literal=key=value
etcdctl get /registry/configmaps/default/test
```

### Exercise 2.3: Backup

```bash
# Take snapshot
etcdctl snapshot save /tmp/backup-$(date +%Y%m%d).db

# Verify
etcdctl snapshot status /tmp/backup-$(date +%Y%m%d).db
```

### Exercise 2.4: Restore (⚠️ DESTRUCTIVE!)

```bash
# Create test namespace
kubectl create namespace test-restore

# Backup
etcdctl snapshot save /tmp/before-delete.db

# Delete namespace
kubectl delete namespace test-restore

# Restore (stop services first)
sudo systemctl stop kube-apiserver etcd
etcdctl snapshot restore /tmp/before-delete.db --data-dir=/var/lib/etcd-restore

# Update etcd manifest to use new data-dir
# Then start services
sudo systemctl start etcd kube-apiserver

# Verify namespace is back
kubectl get namespace test-restore
```

**📝 Summary:** How often to backup? What's your RPO/RTO?

---

## Day 3: Networking Fundamentals

**Learning Objectives:**
- Understand three networks (node, pod, service)
- See pod networking in action
- Explore packet flow

### Exercise 3.1: Identify Networks

```bash
# 1. Node network
kubectl get nodes -o wide

# 2. Pod network  
kubectl get pods -o wide --all-namespaces

# 3. Service network
kubectl get svc --all-namespaces

# Check CIDRs
kubectl cluster-info dump | grep -E 'cluster-cidr|service-cluster-ip-range'
```

**📝 Document your CIDRs:**
- Node: ___________
- Pod: ___________  
- Service: ___________

### Exercise 3.2: Pod-to-Pod Communication

```bash
# Create test pods
kubectl run pod1 --image=nicolaka/netshoot -- sleep 3600
kubectl run pod2 --image=nicolaka/netshoot -- sleep 3600

# Get IPs
kubectl get pods -o wide

# Test connectivity
kubectl exec pod1 -- ping -c 3 <pod2-ip>
kubectl exec pod1 -- traceroute <pod2-ip>
```

**📝 Questions:**
1. What interface? (eth0)
2. Default gateway?
3. Hops to reach pod2?

### Exercise 3.3: CNI Configuration

```bash
# On node - check CNI
ls /etc/cni/net.d/
cat /etc/cni/net.d/*.conf

# Check CNI binaries
ls /opt/cni/bin/

# Calico config
kubectl get ippool -o yaml
```

**📝 Summary:** Draw packet flow from pod1 to pod2

---

## Day 4: CNI Plugins & Service Networking

**Learning Objectives:**
- Understand Services
- Explore kube-proxy
- Learn service types

### Exercise 4.1: How Services Work

```bash
# Create deployment + service
kubectl create deployment web --image=nginx --replicas=3
kubectl expose deployment web --port=80

# Check details
kubectl get svc web
kubectl get endpoints web

# Test from pod
kubectl run test --image=busybox -it --rm -- wget -O- web
```

### Exercise 4.2: kube-proxy

```bash
# Check kube-proxy mode
kubectl logs -n kube-system <kube-proxy-pod> | grep "Using"

# On node - check iptables
sudo iptables-save | grep web
```

### Exercise 4.3: Service Types

**NodePort:**
```bash
kubectl create deployment np-test --image=nginx
kubectl expose deployment np-test --type=NodePort --port=80

# Access from outside
curl http://<node-ip>:<nodeport>
```

**Headless Service:**
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: nginx-headless
spec:
  clusterIP: None
  selector:
    app: nginx-sts
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: nginx-sts
spec:
  serviceName: nginx-headless
  replicas: 3
  selector:
    matchLabels:
      app: nginx-sts
  template:
    metadata:
      labels:
        app: nginx-sts
    spec:
      containers:
      - name: nginx
        image: nginx
EOF

# Check DNS returns pod IPs
kubectl run test --image=busybox -it --rm -- nslookup nginx-headless
```

**📝 Summary:** When to use each service type?

---

## Day 5: DNS & Network Policies

**Learning Objectives:**
- Understand CoreDNS
- Implement Network Policies
- Practice isolation

### Exercise 5.1: CoreDNS

```bash
# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl get configmap -n kube-system coredns -o yaml

# Test DNS
kubectl run test --image=busybox -it --rm -- nslookup kubernetes.default
```

### Exercise 5.2: Network Policies

```bash
# Create namespace
kubectl create namespace netpol-test

# Create pods
kubectl run frontend --image=nginx -n netpol-test
kubectl run backend --image=nginx -n netpol-test

# Test connectivity (works)
kubectl exec -n netpol-test frontend -- wget -O- backend

# Apply deny-all
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: netpol-test
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

# Test again (fails)
kubectl exec -n netpol-test frontend -- wget -O- backend --timeout=5
```

**📝 Summary:** Draw network policy diagram

---

## Day 6: Scheduler & Resource Management

**Learning Objectives:**
- Understand scheduler
- Practice node selection
- Manage resources

### Exercise 6.1: Node Selectors

```bash
# Label nodes
kubectl label nodes <worker1> disktype=ssd
kubectl label nodes <worker2> disktype=hdd

# Deploy with selector
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ssd-only
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ssd-only
  template:
    metadata:
      labels:
        app: ssd-only
    spec:
      nodeSelector:
        disktype: ssd
      containers:
      - name: nginx
        image: nginx
EOF

# Check placement
kubectl get pods -l app=ssd-only -o wide
```

### Exercise 6.2: QoS Classes

```bash
# Guaranteed (requests = limits)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: guaranteed
spec:
  containers:
  - name: nginx
    image: nginx
    resources:
      requests:
        cpu: "500m"
        memory: "256Mi"
      limits:
        cpu: "500m"
        memory: "256Mi"
EOF

kubectl describe pod guaranteed | grep "QoS Class"
```

**📝 Eviction Order:** BestEffort → Burstable → Guaranteed

---

## Day 7: Storage & CSI

**Learning Objectives:**
- Understand PV/PVC lifecycle
- Work with Storage Classes

### Exercise 7.1: Manual PV/PVC

```bash
# Create PV
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: manual-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  hostPath:
    path: /tmp/manual-pv
EOF

# Create PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: manual-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# Check binding
kubectl get pv,pvc
```

**📝 Summary:** Explain PV/PVC lifecycle

---

## Day 8: RBAC & Security

**Learning Objectives:**
- Implement RBAC
- Create service accounts
- Practice least privilege

### Exercise 8.1: Service Account + Role

```bash
# Create SA
kubectl create serviceaccount pod-reader
kubectl create namespace rbac-test

# Create Role
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader-role
  namespace: rbac-test
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
EOF

# Create RoleBinding
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: rbac-test
subjects:
- kind: ServiceAccount
  name: pod-reader
  namespace: default
roleRef:
  kind: Role
  name: pod-reader-role
  apiGroup: rbac.authorization.k8s.io
EOF

# Test
kubectl auth can-i get pods --namespace=rbac-test \
  --as=system:serviceaccount:default:pod-reader
```

**📝 Summary:** Role vs ClusterRole?

---

## Day 9: Certificates & Authentication

**Learning Objectives:**
- Understand K8s PKI
- Check certificate expiration

### Exercise 9.1: PKI Exploration

```bash
# On master
sudo ls -lR /etc/kubernetes/pki/

# View API server cert
sudo openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text -noout
```

### Exercise 9.2: Certificate Expiration

```bash
# Check expiration
sudo kubeadm certs check-expiration

# Renew all
sudo kubeadm certs renew all

# Restart
sudo systemctl restart kubelet
```

**⚠️ Certs expire after 1 year!**

---

## Day 10: Cluster Upgrades

**Learning Objectives:**
- Upgrade control plane
- Upgrade worker nodes

### Exercise 10.1: Upgrade Master

```bash
# Backup etcd first!
etcdctl snapshot save /tmp/pre-upgrade.db

# Upgrade kubeadm
sudo apt-mark unhold kubeadm
sudo apt-get install -y kubeadm=1.28.0-00
sudo apt-mark hold kubeadm

# Plan & apply
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.28.0

# Upgrade kubelet
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet=1.28.0-00 kubectl=1.28.0-00
sudo apt-mark hold kubelet kubectl

sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

### Exercise 10.2: Upgrade Worker

```bash
# On master - drain node
kubectl drain <worker> --ignore-daemonsets

# On worker - upgrade
sudo kubeadm upgrade node
# (then upgrade kubelet/kubectl same as master)

# On master - uncordon
kubectl uncordon <worker>
```

**📝 Rules:** One minor version at a time!

---

## Day 11: Backup & Disaster Recovery

**Learning Objectives:**
- Automate backups
- Practice restore

### Exercise 11.1: Backup Script

```bash
cat > /usr/local/bin/etcd-backup.sh <<'EOF'
#!/bin/bash
BACKUP_DIR="/var/backups/etcd"
mkdir -p $BACKUP_DIR

ETCDCTL_API=3 etcdctl snapshot save $BACKUP_DIR/snapshot-$(date +%Y%m%d).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

find $BACKUP_DIR -name "*.db" -mtime +7 -delete
EOF

chmod +x /usr/local/bin/etcd-backup.sh
```

### Exercise 11.2: Automate with Cron

```bash
# Daily at 2 AM
sudo crontab -e
# Add: 0 2 * * * /usr/local/bin/etcd-backup.sh >> /var/log/etcd-backup.log 2>&1
```

**📝 Summary:** RPO/RTO targets?

---

## Day 12: Troubleshooting Control Plane

**Learning Objectives:**
- Debug API server
- Fix etcd
- Troubleshoot scheduler

### Exercise 12.1: API Server Down

```bash
# Simulate
sudo systemctl stop kube-apiserver

# Troubleshoot
ps aux | grep kube-apiserver
sudo journalctl -u kube-apiserver -n 50
sudo kubeadm certs check-expiration

# Fix
sudo systemctl start kube-apiserver
```

### Exercise 12.2: Debug Checklist

```bash
cat > /usr/local/bin/k8s-debug.sh <<'EOF'
#!/bin/bash
echo "=== K8s Cluster Status ==="
kubectl get nodes
kubectl get pods -n kube-system
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20
kubeadm certs check-expiration
df -h | grep /var
EOF

chmod +x /usr/local/bin/k8s-debug.sh
```

---

## Day 13: Troubleshooting Networking

**Learning Objectives:**
- Debug Services
- Fix DNS
- Troubleshoot CNI

### Exercise 13.1: Service Not Working

```bash
# Create service
kubectl create deployment web --image=nginx --replicas=3
kubectl expose deployment web --port=80

# Troubleshoot
kubectl get svc web
kubectl get endpoints web
kubectl describe svc web

# Check kube-proxy
kubectl logs -n kube-system <kube-proxy-pod>
```

### Exercise 13.2: DNS Issues

```bash
# Test
kubectl run test --image=busybox -it --rm -- nslookup kubernetes.default

# Troubleshoot
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
kubectl exec test -- cat /etc/resolv.conf
```

---

## Day 14: Advanced Scenarios

**Learning Objectives:**
- Handle complex failures
- Practice DR
- Create runbooks

### Final Challenge

Set up and troubleshoot:
1. 3-tier app with network policies
2. RBAC for two teams
3. Simulate failures:
   - Kill worker node
   - Stop etcd
   - Delete CNI
4. Recover and document

### Create Runbooks

```bash
cat > runbook-api-down.md <<EOF
# Runbook: API Server Down

## Symptoms
- kubectl fails
- Cannot access cluster

## Diagnosis
1. Check process: ps aux | grep kube-apiserver
2. Check logs: journalctl -u kube-apiserver
3. Check etcd: etcdctl endpoint health
4. Check certs: kubeadm certs check-expiration

## Resolution
1. Restart: systemctl start kube-apiserver
2. If etcd issue: see etcd runbook
3. If cert expired: kubeadm certs renew all
4. If all else fails: restore from backup

## Prevention
- Monitor cert expiration
- Regular backups
- Health checks
EOF
```

---

## Deep Interview Questions

### Architecture & Components (Advanced)

**Q1: Explain the complete flow when you run `kubectl apply -f deployment.yaml`. Include every component involved.**

<details>
<summary>Click to see detailed answer</summary>

**Complete Flow:**

1. **kubectl → API Server**
   - kubectl reads kubeconfig, gets API server endpoint + auth credentials
   - Performs client-side validation of YAML
   - Sends HTTP POST to API server (`/apis/apps/v1/namespaces/default/deployments`)

2. **API Server Processing**
   - Authentication: Validates client certificate/token
   - Authorization: Checks RBAC (can this user create deployments?)
   - Admission Controllers: 
     - Mutating: May modify the deployment (inject sidecars, set defaults)
     - Validating: Ensures deployment meets policies (resource quotas, pod security)
   - Validation: Schema validation against OpenAPI spec
   - Writes to etcd at `/registry/deployments/default/<deployment-name>`
   - Returns success to kubectl

3. **Controller Manager Detects Change**
   - Deployment Controller watches API server for Deployment objects
   - Sees new Deployment via watch mechanism (long-lived HTTP connection)
   - Calculates desired state: needs to create a ReplicaSet
   - Creates ReplicaSet object via API server

4. **ReplicaSet Controller Reacts**
   - ReplicaSet Controller watches for ReplicaSet objects
   - Sees new ReplicaSet, calculates: need to create N Pods
   - Creates N Pod objects (with `nodeName=""`) via API server

5. **Scheduler Detects Unscheduled Pods**
   - Scheduler watches for Pods where `nodeName=""` (unscheduled)
   - For each pod:
     - **Filtering:** Eliminates nodes (insufficient resources, taints, node selectors)
     - **Scoring:** Ranks remaining nodes (spread, resource utilization)
     - **Binding:** Updates Pod object with `nodeName=<chosen-node>` via API server

6. **Kubelet Detects Pod Assignment**
   - Kubelet on assigned node watches API server for pods scheduled to it
   - Sees new Pod assigned to its node
   - Pulls container image (if not cached)
   - Calls CRI (containerd): Creates containers
   - Calls CNI plugin: Sets up pod networking (veth pair, IP allocation, routes)
   - Starts containers
   - Monitors liveness/readiness probes
   - Reports pod status back to API server

7. **Service/Endpoints Controller (if Service exists)**
   - Watches Pods with labels matching Service selector
   - Updates Endpoints object with new Pod IPs
   - kube-proxy watches Endpoints, updates iptables/ipvs rules

**Key Points:**
- API server is the only component that talks to etcd
- All other components watch API server (never talk directly to each other)
- Everything is event-driven via watch mechanisms
- Each controller maintains its own reconciliation loop

</details>

---

**Q2: Why is etcd's quorum (N/2)+1? Why can't you run a 2-node etcd cluster?**

<details>
<summary>Click to see detailed answer</summary>

**Raft Consensus & Split-Brain Problem:**

**Why (N/2)+1?**
- Raft consensus algorithm requires majority agreement for writes
- Prevents split-brain: two parts of cluster thinking they're both primary
- Formula: `quorum = floor(N/2) + 1`

**Examples:**
- 1 node: quorum=1, can lose 0 nodes ❌ (no HA)
- 2 nodes: quorum=2, can lose 0 nodes ❌ (worse than 1!)
- 3 nodes: quorum=2, can lose 1 node ✅
- 4 nodes: quorum=3, can lose 1 node (same as 3, wastes resources!)
- 5 nodes: quorum=3, can lose 2 nodes ✅
- 6 nodes: quorum=4, can lose 2 nodes (same as 5, wastes resources!)

**Why NOT 2 nodes?**
Network partition scenario:
```
Node A  ←—network partition—→  Node B
   ↓                              ↓
Client writes "X=1"         Client writes "X=2"
```

With 2 nodes:
- Both need each other for quorum (2/2)
- If network partitions, NEITHER can accept writes (total failure)
- Worse than single node (which at least works)

With 3 nodes:
```
Node A ←—partition—→ Node B + Node C
   ↓                        ↓
Isolated              Has quorum (2/3)
Can't write ✅        Can write ✅
```

**Production Recommendation:**
- **3 nodes**: Most common, good balance
- **5 nodes**: If you need to survive 2 failures
- **7 nodes**: Rarely needed, high write latency

**Interview Gold:** "Even numbers don't improve fault tolerance vs. odd-1, so always use odd numbers: 3, 5, or 7."

</details>

---

**Q3: The API server goes down. What still works? What breaks?**

<details>
<summary>Click to see detailed answer</summary>

**What Still Works:**

1. **Existing Pods Keep Running**
   - Containers continue running on nodes
   - Kubelet doesn't need API server for running containers
   - Applications serve traffic normally

2. **Pod-to-Pod Networking**
   - CNI networking already configured
   - iptables/ipvs rules already in place
   - Services continue to work (kube-proxy rules cached)

3. **Liveness/Readiness Probes**
   - Kubelet runs probes locally
   - Will restart failed containers
   - However, can't update Pod status in API

4. **DNS (CoreDNS)**
   - CoreDNS pods keep running
   - DNS queries continue to work
   - Using cached Service data

**What Breaks:**

1. **kubectl Commands**
   - All kubectl commands fail (can't reach API)
   - `kubectl get`, `kubectl logs`, `kubectl exec` all fail

2. **New Pod Scheduling**
   - No new pods can be scheduled
   - Scheduler can't assign nodes
   - Deployments can't scale

3. **Controllers Stop Working**
   - ReplicaSets won't create replacement pods
   - Failed pods won't be replaced
   - Deployments won't reconcile
   - Auto-scaling doesn't work

4. **Status Updates Blocked**
   - Kubelet can't report pod status
   - Metrics not updated
   - Events not recorded

5. **New Service/Endpoint Updates**
   - kube-proxy can't learn about new services
   - New pods won't be added to endpoints
   - Service routing stale

**Recovery Priority:**
1. Restore API server ASAP
2. Check etcd (API server dependency)
3. Check certificates (common failure)
4. Check logs: `journalctl -u kube-apiserver`

**Interview Insight:** "The cluster continues serving traffic, but can't adapt to changes. This is why multi-master HA is critical."

</details>

---

### Networking Deep Dive

**Q4: Trace a packet from pod1 (10.244.1.5) on node1 to pod2 (10.244.2.10) on node2 using Calico. Include every hop.**

<details>
<summary>Click to see detailed answer</summary>

**Complete Packet Journey:**

**Step 1: Pod1 Container Network Stack**
```
Application sends packet: 10.244.1.5 → 10.244.2.10
↓
eth0 in pod (actually veth pair endpoint)
```

**Step 2: Pod's Network Namespace → Host**
```
veth pair: pod's eth0 ←→ host's caliXXXX interface
Packet traverses veth pair to host network namespace
```

**Step 3: Host (Node1) Routing**
```bash
# On node1, kernel checks routing table
ip route show
# Shows: 10.244.2.0/24 via 192.168.56.11 dev eth0

Packet sent to node2's IP (192.168.56.11) via eth0
```

**Step 4: Calico Encapsulation (if IP-in-IP mode)**
```
Original packet: [IP: 10.244.1.5 → 10.244.2.10] [TCP/Data]
                          ↓
Encapsulated:    [IP: 192.168.56.10 → 192.168.56.11] 
                 [IP: 10.244.1.5 → 10.244.2.10] [TCP/Data]
```

**Step 5: Physical Network**
```
Packet travels through physical/VM network
192.168.56.10 (node1) → 192.168.56.11 (node2)
```

**Step 6: Node2 Receives & Decapsulates**
```
Node2 kernel receives encapsulated packet
Calico IPIP module decapsulates
Extracts: [IP: 10.244.1.5 → 10.244.2.10] [TCP/Data]
```

**Step 7: Node2 Routing to Pod2**
```bash
# Kernel checks routing table
ip route show
# Shows: 10.244.2.10 dev caliYYYY

Routes packet to caliYYYY (veth pair to pod2)
```

**Step 8: veth Pair to Pod2**
```
Packet traverses veth pair: host's caliYYYY → pod2's eth0
Pod2 application receives packet
```

**Calico Modes Compared:**

| Mode | Encapsulation | Overhead | Use Case |
|------|---------------|----------|----------|
| **IP-in-IP** | Yes | ~20 bytes | Cross-subnet (default) |
| **VXLAN** | Yes | ~50 bytes | Requires L3 |
| **BGP (no encap)** | No | 0 bytes | Full L3 routing |

**Key Points for Interview:**
- veth pairs connect pod to host
- Routing table determines next hop
- Encapsulation preserves pod IPs across nodes
- Calico uses BGP for route distribution
- kube-proxy doesn't touch pod-to-pod traffic

</details>

---

**Q5: kube-proxy has three modes: iptables, ipvs, and eBPF (Cilium). Explain each and when to use them.**

<details>
<summary>Click to see detailed answer</summary>

### 1. iptables Mode (Default)

**How It Works:**
```bash
# For each Service, creates iptables chain
-A KUBE-SERVICES -d 10.96.0.100/32 -p tcp --dport 80 -j KUBE-SVC-XXX

# Random load balancing to endpoints
-A KUBE-SVC-XXX -m statistic --mode random --probability 0.33 -j KUBE-SEP-POD1
-A KUBE-SVC-XXX -m statistic --mode random --probability 0.50 -j KUBE-SEP-POD2
-A KUBE-SVC-XXX -j KUBE-SEP-POD3
```

**Pros:**
- Default, well-tested
- Works everywhere

**Cons:**
- O(n) lookup time
- Doesn't scale >5000 services
- No real load balancing (just random)

---

### 2. IPVS Mode

**How It Works:**
- Uses Linux kernel's IPVS
- Hash table lookups O(1)
- Real load balancing algorithms

**Load Balancing Algorithms:**
- `rr` - Round Robin
- `lc` - Least Connection
- `dh` - Destination Hashing

**Pros:**
- O(1) lookup time (fast!)
- Scales to 10,000+ services
- Real LB algorithms

**Cons:**
- Requires kernel modules
- More complex troubleshooting

---

### 3. eBPF Mode (Cilium)

**How It Works:**
- Uses eBPF programs
- Packet processing in kernel
- Bypasses iptables entirely

**Pros:**
- Fastest (kernel fast path)
- Scales infinitely
- Advanced features (L7 policies)

**Cons:**
- Requires kernel 4.9.17+
- Complex setup

---

### Comparison Table

| Feature | iptables | IPVS | eBPF |
|---------|----------|------|------|
| **Max Services** | ~5,000 | ~50,000 | Unlimited |
| **Lookup Speed** | O(n) | O(1) | O(1) |
| **CPU Usage** | High | Medium | Low |

---

### When to Use Each

**Use iptables:**
- Small clusters (<100 services)
- Default setup

**Use IPVS:**
- Medium to large clusters (100-10,000 services)
- Need better load balancing

**Use eBPF (Cilium):**
- Large scale (1,000+ services)
- Need L7 policies
- Modern kernel available

**Interview Gold:** "IPVS is the sweet spot for production clusters. eBPF is cutting-edge but requires modern kernel."

</details>

---

### Additional Resources

- [Kubernetes Official Docs](https://kubernetes.io/docs/)
- [Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)
- [CKA Exam Curriculum](https://github.com/cncf/curriculum)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

---

**Good luck with your interview! 🚀**

> Remember: It's not about memorizing—it's about understanding the *why* behind each decision. Practice these scenarios until you can explain them in your sleep.
