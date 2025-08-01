# RMMT Kubernetes 部署指南

## 概述

这个目录包含了RMMT（Roommate Matcher）系统在Kubernetes集群上的完整部署配置。

## 架构说明

```
            ┌───────────────────────────────┐
            │         External Traffic      │
            └──────────────┬────────────────┘
                           │
                ┌──────────▼──────────┐
                │   Traefik Ingress   │
                │     Controller      │
                └──────────┬──────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
┌───────▼───────┐  ┌───────▼───────┐  ┌───────▼───────┐
│ RMMT-Student  │  │ RMMT-Admin    │  │ RMMT-DB-Admin │
│ (Frontend)    │  │ (Frontend)    │  │ (DB Manager)  │
└───────┬───────┘  └───────┬───────┘  └───────┬───────┘
        │                  │                  │
        └──────────┬───────┴───────┐          │
                   │               │          │
             ┌─────▼─────┐   ┌─────▼─────┐    │
             │ RMMT-API  │   │ RMMT-Task │    │
             │ (Backend) │   │ (Worker)  │    │
             └─────┬─────┘   └───────────┘    │
                   │                          │
           ┌───────▼────────┐                 │
           │ RMMT-DB-MySQL  │                 │
           │  (Database)    │─────────────────┘
           └────────────────┘
```

## 当前技术栈

### Ingress Controller
- **当前使用**: Traefik Ingress Controller
- **版本**: v2.10+
- **特点**: 
  - 自动服务发现
  - 内置负载均衡
  - 支持Let's Encrypt自动证书
  - 基本安全头配置

### 安全配置
- **TLS/SSL**: Let's Encrypt自动证书
- **安全头**: X-Frame-Options, X-Content-Type-Options, X-XSS-Protection
- **CORS**: 跨域资源共享配置
- **速率限制**: 基本请求频率限制
- **HTTPS重定向**: 强制HTTP到HTTPS重定向

## 文件结构

```
k8s/
├── namespace.yaml              # 命名空间定义
├── configmap.yaml             # 配置映射
├── secret.yaml                # 密钥配置
├── rmmt-api.yaml             # API服务部署和服务
├── rmmt-student.yaml         # 学生前端部署和服务
├── rmmt-admin.yaml           # 管理前端部署和服务
├── rmmt-db-mysql.yaml        # MySQL数据库部署
├── rmmt-db-admin.yaml        # Adminer数据库管理界面
├── rmmt-task.yaml            # 后台任务部署
├── ingress.yaml              # Traefik Ingress配置
├── kustomization.yaml        # Kustomize配置
├── README.md                 # 本文件
└── network/                  # 网络安全配置
    ├── network-policy.yaml   # 网络策略
    └── waf-configmap.yaml    # WAF配置（为未来Nginx准备）
```

## 前置要求

1. **Kubernetes集群** (v1.19+)
   ```bash
    curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | INSTALL_K3S_MIRROR=cn INSTALL_K3S_EXEC="server" sh -s - --tls-san <YOUR_EXTERNAL_IP> --node-external-ip <YOUR_EXTERNAL_IP> --docker
    ```
2. **kubectl** 命令行工具
3. **Docker镜像** 已构建并推送到镜像仓库
   ```bash
   rmmt-api:latest
   rmmt-student:latest
   rmmt-admin:latest
   mysql:8.0
   adminer:latest
   ```
4. **Traefik Ingress Controller** (v2.10+)(在安装Kubernetes的时候会顺便安装)
5. **cert-manager** (用于SSL证书)
   ```bash
   kubectl apply -f tls/cert-manager.yaml
   kubectl apply -f tls/cluster-issuer.yaml
   ```

## 部署步骤

### 1. 构建Docker镜像

Docker镜像构建在对应Repo的仓库中均有Actions提供，可以直接运行Actions便可以自动推送到jaredanjerry/rmmt-api、jaredanjerry/rmmt-student、jaredanjerry/rmmt-admin中，只需要按照下列步骤拉取相应镜像即可

```bash
docker pull docker.1ms.run/jaredanjerry/rmmt-api:latest # 在国内服务器要使用registry
docker pull docker.1ms.run/jaredanjerry/rmmt-student:latest
docker pull docker.1ms.run/jaredanjerry/rmmt-admin:latest
docker tag docker.1ms.run/jaredanjerry/rmmt-api:latest rmmt-api:latest
docker tag docker.1ms.run/jaredanjerry/rmmt-student:latest rmmt-student:latest
docker tag docker.1ms.run/jaredanjerry/rmmt-admin:latest rmmt-admin:latest
```

### 2. 更新配置

在部署前，请更新以下配置：

1. **镜像名称**: 在deployment文件中更新镜像名称
2. **域名**: 在ingress.yaml中更新域名
3. **密钥**: 在secret.yaml中更新敏感信息
4. **配置**: 在configmap.yaml中更新应用配置
5. **tls证书**: 在tls/rmmt-certificate.yaml中更新tls证书（对应域名）

### 3. 部署到Kubernetes

```bash
# 使用kubectl直接部署
kubectl apply -f k8s/

# 或使用kustomize
kubectl apply -k k8s/

# 检查部署状态
kubectl get all -n rmmt
kubectl get ingress -n rmmt
```

### 4. 验证部署

```bash
# 检查Pod状态
kubectl get pods -n rmmt

# 检查服务状态
kubectl get svc -n rmmt

# 检查Ingress状态
kubectl get ingress -n rmmt

# 查看日志
kubectl logs -f deployment/rmmt-api -n rmmt
kubectl logs -f deployment/rmmt-student -n rmmt
kubectl logs -f deployment/rmmt-admin -n rmmt
```

## 访问地址

部署成功后，可以通过以下地址访问：

- **学生前端**: https://roommate.seth24.com
- **管理前端**: https://rmadmin.seth24.com
- **数据库管理**: https://rmapi.seth24.com

## 配置说明

### 环境变量

- `NUXT_API_URL`: 前端访问API的地址
- `DB_HOST`: 数据库主机地址
- `DB_PASSWORD`: 数据库密码
- `JWT_SECRET`: JWT签名密钥

### 资源限制

- **API服务**: 256Mi-512Mi内存，250m-500m CPU
- **前端服务**: 128Mi-256Mi内存，100m-200m CPU
- **数据库**: 512Mi-1Gi内存，500m-1000m CPU
- **后台任务**: 512Mi-1Gi内存，200m-500m CPU

### 安全配置

当前Traefik配置包含以下安全特性：

```yaml
# HTTPS重定向
traefik.ingress.kubernetes.io/ssl-redirect: "true"

# 安全头
traefik.ingress.kubernetes.io/headers-custom-response-headers: |
  X-Frame-Options:SAMEORIGIN,
  X-Content-Type-Options:nosniff,
  X-XSS-Protection:1; mode=block,
  Referrer-Policy:no-referrer-when-downgrade,
  Content-Security-Policy:default-src 'self' http: https: data: blob: 'unsafe-inline' 'unsafe-eval'

# 速率限制
traefik.ingress.kubernetes.io/rate-limit: "100"
traefik.ingress.kubernetes.io/rate-limit-burst: "200"
```

## 扩展和缩放

```bash
# 扩展API服务副本数
kubectl scale deployment rmmt-api --replicas=3 -n rmmt

# 扩展前端服务副本数
kubectl scale deployment rmmt-student --replicas=3 -n rmmt
kubectl scale deployment rmmt-admin --replicas=3 -n rmmt
```

## 备份和恢复

```bash
# 备份配置
kubectl get all -n rmmt -o yaml > rmmt-backup.yaml

# 恢复配置
kubectl apply -f rmmt-backup.yaml
```

## 未来计划

由于配置时间有限，目前k8s系统没有添加系统监控，日志管理和高级防火墙（仅有Traefik流量控制和每个镜像自带的nginx），后续计划添加

建议配置以下：

[ ] **Prometheus + Grafana**: 监控应用指标
[ ] **ELK Stack**: 集中日志管理
[ ] **AlertManager**: 告警通知
[ ] **Nginx Ingress Controller + WAF**: 高级防火墙（在部署的时候需要disable traefik）
