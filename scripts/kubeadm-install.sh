#!/usr/bin/env bash
set -o nounset -o errexit

K8S_VERSION=$1
# CNI_VERSION=$2
HOSTNAME=$3
NODE_IP=$4

cat << EOF > /etc/default/kubelet
KUBELET_EXTRA_ARGS=--node-ip=${NODE_IP}
EOF

# Disable iptables for docker as this interferes with kubernetes networking
mkdir -p /etc/systemd/system/docker.service.d
cat << EOF > /etc/systemd/system/docker.service.d/10-disable-iptables.conf
[Service]
Environment="DOCKER_OPTS=--iptables=false"
EOF
systemctl daemon-reload

systemctl enable docker.service
systemctl start docker.service

# Populate /proc/sys/net/bridge/bridge-nf-call-iptables
modprobe br_netfilter

CNI_VERSION="v0.6.0"
mkdir -p /opt/cni/bin
curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-amd64-${CNI_VERSION}.tgz" | tar -C /opt/cni/bin -xz

CRICTL_VERSION="v1.11.1"
mkdir -p /opt/bin
curl -L "https://github.com/kubernetes-incubator/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz" | tar -C /opt/bin -xz

mkdir -p /opt/bin
cd /opt/bin
curl -L --remote-name-all https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/amd64/{kubeadm,kubelet,kubectl}
chmod +x {kubeadm,kubelet,kubectl}

curl -sSL "https://raw.githubusercontent.com/kubernetes/kubernetes/${K8S_VERSION}/build/debs/kubelet.service" | sed "s:/usr/bin:/opt/bin:g" > /etc/systemd/system/kubelet.service
mkdir -p /etc/systemd/system/kubelet.service.d
curl -sSL "https://raw.githubusercontent.com/kubernetes/kubernetes/${K8S_VERSION}/build/debs/10-kubeadm.conf" | sed "s:/usr/bin:/opt/bin:g" > /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

systemctl enable kubelet.service
systemctl start kubelet.service
