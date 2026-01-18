#!/bin/bash
set -e

# Set hostname
hostnamectl set-hostname k8s-master
echo "${master_ip} k8s-master" >> /etc/hosts
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

# Initialize cluster with reduced resource requirements
kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=${master_ip} \
  --node-name=k8s-master \
  --ignore-preflight-errors=NumCPU,Mem

# Setup kubeconfig for ubuntu user
mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube

# Setup kubeconfig for root
export KUBECONFIG=/etc/kubernetes/admin.conf

# Install Flannel CNI
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# Generate and save join command
kubeadm token create --print-join-command > /tmp/join-command.sh
chmod 644 /tmp/join-command.sh

# Create a script that workers can fetch
cat <<'JOINSCRIPT' > /var/www/html/join.sh
#!/bin/bash
$(cat /tmp/join-command.sh) --ignore-preflight-errors=NumCPU,Mem
JOINSCRIPT
chmod 644 /var/www/html/join.sh

# Install simple HTTP server to serve join command
apt-get install -y apache2
systemctl start apache2
systemctl enable apache2

# Copy join command to web root
cp /tmp/join-command.sh /var/www/html/join-command.txt

echo "Master node setup complete!"