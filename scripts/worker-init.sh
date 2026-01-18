#!/bin/bash
set -e

WORKER_ID=${worker_id}
MASTER_IP=${master_ip}

# Set hostname
hostnamectl set-hostname k8s-worker-$WORKER_ID
echo "10.0.1.10 k8s-master" >> /etc/hosts
echo "10.0.1.11 k8s-worker-1" >> /etc/hosts
echo "10.0.1.12 k8s-worker-2" >> /etc/hosts

# Disable swap
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Load kernel modules
cat <<EOT | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOT

modprobe overlay
modprobe br_netfilter

# Set up required sysctl params
cat <<EOT | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOT

sysctl --system

# Install containerd
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker repo for containerd
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y containerd.io

# Configure containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Install kubeadm, kubelet, kubectl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Configure kubelet for low memory
cat <<EOT | tee /etc/default/kubelet
KUBELET_EXTRA_ARGS=--cgroup-driver=systemd --eviction-hard=memory.available<100Mi --system-reserved=memory=200Mi
EOT

# Wait for master to be ready and fetch join command
echo "Waiting for master node to be ready..."
for i in {1..30}; do
  if curl -f http://$MASTER_IP/join-command.txt -o /tmp/join-command.sh 2>/dev/null; then
    echo "Join command retrieved successfully"
    break
  fi
  echo "Attempt $i: Master not ready yet, waiting 20 seconds..."
  sleep 20
done

# Execute join command
if [ -f /tmp/join-command.sh ]; then
  chmod +x /tmp/join-command.sh
  bash /tmp/join-command.sh --ignore-preflight-errors=NumCPU,Mem
  echo "Worker node joined cluster successfully!"
else
  echo "Failed to retrieve join command from master"
  exit 1
fi