# GitOps EKS Platform with ArgoCD

An internal developer platform built on **Amazon EKS**. Teams deploy microservices via **GitOps (ArgoCD)** and manage namespaces through a **self-service portal**.

## Architecture

```
Developer Portal (Lambda + API Gateway)
    │
    ▼
EKS Cluster ──► ArgoCD (GitOps Controller)
    │
    ├──► Namespace: team-alpha (Guestbook app)
    ├──► Namespace: team-beta (Kustomize app)
    │
    └──► Kyverno Policies (Security Guardrails)
```

## Components

| Component | Technology |
|-----------|------------|
| **Kubernetes** | Amazon EKS 1.29 |
| **GitOps** | ArgoCD |
| **Policies** | Kyverno |
| **Monitoring** | Prometheus + Grafana (Helm) |
| **Portal** | AWS Lambda + API Gateway |
| **Nodes** | t3.small (2 nodes) |

## Infrastructure

| Resource | Details |
|----------|---------|
| VPC | 2 public subnets across 2 AZs |
| EKS | Control plane + 2 managed nodes |
| Cost | ~$100/month (destroy after demo!) |

## Deployment

### 1. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform apply
```

### 2. Configure kubectl

```bash
aws eks update-kubeconfig --region eu-west-2 --name gitopseks2026
kubectl get nodes
```

### 3. Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Port-forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Login: `admin` / get password via `kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d`

### 4. Install Kyverno

```bash
kubectl create namespace kyverno
kubectl apply -f https://raw.githubusercontent.com/kyverno/kyverno/main/config/install.yaml
kubectl apply -f ../kubernetes/policies/
```

### 5. Install Monitoring (Optional)

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack   -n monitoring --create-namespace   -f ../kubernetes/monitoring/prometheus-values.yaml
```

### 6. Deploy ArgoCD Applications

```bash
kubectl apply -f ../kubernetes/argocd-apps/
```

## Test the Portal

```bash
curl $(terraform output -raw portal_api_url)/namespaces
```

## Test Policy Enforcement

```bash
# This should be BLOCKED by Kyverno
kubectl run bad-pod --image=nginx --privileged -n team-alpha

# This should be ALLOWED
kubectl run good-pod --image=nginx -n team-alpha --labels="team=alpha"
```

## Screenshots to Capture

1. **EKS Console** → Cluster overview
2. **EC2 Console** → 2 nodes running
3. **ArgoCD UI** → Applications synced
4. **kubectl** → `kubectl get nodes`, `kubectl get pods -A`
5. **Kyverno** → Policy blocked a privileged pod
6. **Portal API** → `curl` response

## ⚠️ Destroy After Demo

```bash
cd terraform
terraform destroy -auto-approve
```

**Cost: ~$100/month. Destroy within 2-3 hours to minimize charges.**

## Author

AWS Cloud Portfolio Project

---

**Lindokuhle Sithole** - *Cloud Engineer | Cloud DevOps Engineer | Cloud Security Specialist*

Based in Bremen, Germany. BSc Mathematical Science from the University of the Witwatersrand. 5x AWS Certified (Solutions Architect Professional, Security Specialty, CloudOps Engineer Associate, Solutions Architect Associate, Cloud Practitioner) plus CompTIA Security+.

- **LinkedIn:** [linkedin.com/in/lindokuhle-sithole-bb701b19a](https://www.linkedin.com/in/lindokuhle-sithole-bb701b19a)
- **GitHub:** [github.com/lindokuhlesithole](https://github.com/lindokuhlesithole)
- **Email:** sitholelindokuhle371@gmail.com