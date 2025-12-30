# JupyterHub SSH Access - Research & Implementation Notes

**Date**: 2025-12-26
**Project**: tofu_era
**Tool**: [jupyterhub-ssh](https://github.com/yuvipanda/jupyterhub-ssh) by Yuvi Panda

---

## Overview

jupyterhub-ssh enables SSH and SFTP access to any JupyterHub deployment. It works by:

1. **SSH Server**: Accepts SSH connections, authenticates via JupyterHub API tokens, then proxies to Jupyter terminals via Terminado
2. **SFTP Server** (optional): Provides file transfer to user home directories (requires NFS-backed storage)

---

## How Authentication Works

Users **do NOT use SSH keys**. Instead:

1. User visits `https://<hub-address>/hub/token`
2. Copies their JupyterHub API token
3. SSHs with: `ssh <username>@<ssh-host>`
4. Enters the API token as the password

```bash
# Example workflow
$ ssh myuser@ssh.cae-dev.rocktalus.com
myuser@ssh.cae-dev.rocktalus.com's password: <paste token here>
jovyan@jupyter-myuser:~$
```

---

## What Works and What Doesn't

### Works

| Feature | Status | Notes |
|---------|--------|-------|
| Interactive SSH terminal | Yes | Full terminal access to user container |
| SFTP file transfer | Yes* | *Requires NFS-backed home directories |
| Multiple concurrent sessions | Yes | Can have multiple SSH sessions |

### Does NOT Work

| Feature | Status | Notes |
|---------|--------|-------|
| SSH key authentication | No | Token-only authentication |
| SCP (secure copy) | No | Non-interactive commands not supported |
| Port forwarding / tunneling | No | Cannot tunnel ports (e.g., for Dask dashboards) |
| Non-interactive commands | No | `ssh user@host 'ls -la'` won't work |
| rsync over SSH | No | Relies on non-interactive SSH |
| Attach to running kernels | No | SSH terminal is separate from Jupyter kernels |

### SCP vs SFTP

**SCP will NOT work** because it requires non-interactive command execution over SSH, which jupyterhub-ssh doesn't support.

**SFTP CAN work** but requires NFS-backed storage. SFTP is a separate protocol that doesn't rely on SSH command execution - it has its own subsystem. However, our current setup uses EBS-backed PVCs (per-pod storage), not shared NFS, so SFTP won't work without infrastructure changes.

**Workaround for file transfer without SFTP**:
- Use JupyterLab's built-in file upload/download
- Use `curl`/`wget` from within the SSH session
- Use cloud storage (S3) with `aws s3 cp`

---

## Infrastructure Requirements

| Component | Description | Cost Impact |
|-----------|-------------|-------------|
| Helm release | jupyterhub-ssh chart deployed alongside DaskHub | Minimal (small pod) |
| LoadBalancer | Needs its own NLB for SSH (port 22) | ~$16-20/month per NLB |
| DNS record | e.g., `ssh.cae-dev.rocktalus.com` | None (just config) |
| Host key secret | Auto-generated or provided RSA key | None |

### Helm Chart Installation

```bash
helm install jupyterhub-ssh \
  --repo https://yuvipanda.github.io/jupyterhub-ssh/ jupyterhub-ssh \
  --set hubUrl=https://cae-dev.rocktalus.com \
  --set ssh.enabled=true \
  --set sftp.enabled=false \
  --namespace daskhub
```

### AWS NLB Service Configuration

```yaml
ssh:
  enabled: true
  service:
    type: LoadBalancer
    port: 22
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
      service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
      service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
```

---

## Deployment Approaches

### Option A: Separate NLB (Recommended)

Deploy jupyterhub-ssh with its own LoadBalancer service.

**Pros:**
- Isolated from JupyterHub proxy
- Simple to configure and debug
- Can be enabled/disabled independently

**Cons:**
- Extra NLB cost (~$16-20/month)
- Additional DNS record needed

### Option B: Share Existing NLB via Traefik

Add SSH port to the existing JupyterHub proxy service and configure Traefik to route SSH traffic.

**Pros:**
- No extra NLB cost

**Cons:**
- Requires modifying DaskHub Helm values
- Complex Traefik TCP routing configuration
- Tighter coupling with JupyterHub deployment

---

## Implementation Plan

### Phase 1: Create Terraform Module

Create `modules/jupyterhub-ssh/`:

```
modules/jupyterhub-ssh/
├── main.tf        # Helm release
├── variables.tf   # Configuration options
└── outputs.tf     # SSH endpoint info
```

### Phase 2: Add Variables

```hcl
variable "enable_ssh_access" {
  description = "Enable SSH access to JupyterHub user servers"
  type        = bool
  default     = false
}

variable "ssh_port" {
  description = "Port for SSH service (22 standard, 2222 for firewall traversal)"
  type        = number
  default     = 22
}

variable "ssh_domain_name" {
  description = "Domain name for SSH access (e.g., ssh.hub.example.com)"
  type        = string
  default     = ""
}
```

### Phase 3: Deploy and Configure DNS

After `tofu apply`:

1. Get NLB hostname from outputs
2. Add DNS CNAME record: `ssh.cae-dev.rocktalus.com` → `<nlb-hostname>`

### Phase 4: User Documentation

Document the connection workflow for users.

---

## Challenges & Caveats

### 1. SFTP Requires NFS (Major Infrastructure Change)

Current setup uses EBS-backed PVCs per user pod. SFTP requires **shared NFS storage** so the SFTP pod can access user home directories.

To enable SFTP would require:
- AWS EFS (~$0.30/GB/month + $0.03/GB transfer)
- Or self-managed NFS server

**Recommendation**: Start with SSH only, skip SFTP.

### 2. Port 22 May Be Blocked

Many corporate/university networks block outbound port 22.

**Options:**
- Use port 22 (standard) - some users may be blocked
- Use port 2222 (non-standard) - better firewall traversal
- Expose both ports

### 3. Token UX is Clunky

Users must manually copy tokens each time. No way around this currently.

**Potential improvements:**
- Document `~/.ssh/config` with password manager integration
- Write a CLI wrapper tool that fetches tokens automatically
- Use longer-lived tokens (security tradeoff)

### 4. No Connection to Running Kernels

SSH gives a terminal, but it's **separate from Jupyter kernels**. You cannot:
- Attach to a running Python session
- Debug a notebook cell interactively
- Access variables from a running kernel

It's a fresh terminal in the same container with access to the same filesystem.

### 5. Security Considerations

- Host key is auto-generated (can provide your own for consistency)
- Tokens have same permissions as user's JupyterHub session
- SSH session runs as same user (jovyan/UID 1000)
- Token lifetime matches JupyterHub token settings

---

## Cost Analysis

| Resource | Monthly Cost |
|----------|--------------|
| NLB (dedicated) | ~$16-20 |
| SSH pod (0.1 CPU, 128Mi) | ~$0.50 |
| **Total** | **~$17-21/month** |

If sharing existing NLB (Option B): ~$0.50/month (pod only)

---

## Alternative Approaches Considered

### 1. Web-based Terminal (Current)

JupyterLab already has a built-in terminal. Why add SSH?

**SSH advantages:**
- Native terminal experience (proper key bindings, tmux/screen)
- Works with existing SSH-based workflows
- Can use local terminal emulator preferences
- Persistent sessions (with tmux)

### 2. code-server (VSCode in Browser)

Already implemented in cae-dev. Provides terminal access through VSCode's integrated terminal.

### 3. SSHSpawner (NERSC)

[NERSC/sshspawner](https://github.com/NERSC/sshspawner) - Different approach where JupyterHub SSHs to spawn notebooks on remote systems. Not applicable here.

---

## References

- [jupyterhub-ssh GitHub](https://github.com/yuvipanda/jupyterhub-ssh)
- [Helm Chart Values](https://github.com/yuvipanda/jupyterhub-ssh/blob/main/helm-chart/jupyterhub-ssh/values.yaml)
- [AWS NLB Annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.6/guide/service/annotations/)
- [Jupyter Community Discussion](https://discourse.jupyter.org/t/how-to-use-ssh-to-z-jh-in-local-cluster/11856)

---

## Decision Log

| Question | Decision | Rationale |
|----------|----------|-----------|
| SFTP needed? | TBD | Requires EFS migration |
| Which port? | TBD | 22 (standard) vs 2222 (firewall-friendly) |
| Separate NLB? | TBD | Recommend yes for simplicity |
| First environment? | TBD | Suggest cae-testing |
