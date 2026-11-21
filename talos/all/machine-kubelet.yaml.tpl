# KubeletConfig has no extraMounts, so kubelet stays on legacy .machine.kubelet
# (needed by machine-openebs-local.yaml); delete the generated KubeletConfig.
apiVersion: v1alpha1
kind: KubeletConfig
$patch: delete
---
machine:
  kubelet:
    image: ghcr.io/siderolabs/kubelet:{{ .KubernetesVersion }}
    extraConfig:
      serializeImagePulls: false
    defaultRuntimeSeccompProfileEnabled: true
    disableManifestsDirectory: true
---
apiVersion: v1alpha1
kind: KubeNodeConfig
nodeIP:
  validSubnets:
    - 192.168.20.0/24
