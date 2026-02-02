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

## Final Assessment

**Questions to Answer:**

1. Explain packet flow: pod1 → pod2 (different nodes)
2. What happens: `kubectl apply -f deployment.yaml`?
3. How to upgrade 1.27 → 1.28 with zero downtime?
4. Complete etcd restore procedure?
5. Multi-tenant isolation strategy?

---

## Next Steps

**Certifications:**
- CKA (Certified Kubernetes Administrator)
- CKAD (Certified Kubernetes Application Developer)
- CKS (Certified Kubernetes Security Specialist)

**Resources:**
- [Kubernetes Docs](https://kubernetes.io/docs/)
- [K8s The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

---

**Good luck! 🚀**

> Remember: Understanding > Memorization
