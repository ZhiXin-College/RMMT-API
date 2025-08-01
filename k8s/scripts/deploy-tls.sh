#!/bin/bash

# RMMT TLS证书部署脚本

set -e

echo "🔐 开始部署RMMT TLS证书配置..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查cert-manager是否已安装
echo -e "${YELLOW}1️⃣ 检查cert-manager状态...${NC}"
if ! kubectl get pods -n cert-manager 2>/dev/null | grep -q "cert-manager"; then
    echo -e "${RED}❌ cert-manager未安装，请先安装cert-manager${NC}"
    echo "安装命令：kubectl apply -f cert-manager.yaml"
    exit 1
fi

# 等待cert-manager就绪
echo -e "${YELLOW}2️⃣ 等待cert-manager就绪...${NC}"
kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager --timeout=300s

# 部署ClusterIssuer
echo -e "${YELLOW}3️⃣ 部署ClusterIssuer...${NC}"
kubectl apply -f rmmt-cluster-issuer.yaml

# 等待ClusterIssuer就绪
echo -e "${YELLOW}4️⃣ 等待ClusterIssuer就绪...${NC}"
kubectl wait --for=condition=ready clusterissuer/letsencrypt-prod --timeout=60s

# 部署Certificate
echo -e "${YELLOW}5️⃣ 部署Certificate...${NC}"
kubectl apply -f rmmt-certificate.yaml

# 等待Certificate就绪
echo -e "${YELLOW}6️⃣ 等待Certificate就绪...${NC}"
kubectl wait --for=condition=ready certificate/rmmt-tls -n rmmt --timeout=300s

# 部署Ingress
echo -e "${YELLOW}7️⃣ 部署Ingress...${NC}"
kubectl apply -f ingress.yaml

# 检查部署状态
echo -e "${YELLOW}8️⃣ 检查部署状态...${NC}"
echo "Certificate状态："
kubectl get certificate -n rmmt

echo "Secret状态："
kubectl get secret -n rmmt | grep tls

echo "Ingress状态："
kubectl get ingress -n rmmt

echo -e "${GREEN}✅ TLS证书部署完成！${NC}"
echo ""
echo "📋 下一步："
echo "1. 确保DNS记录指向服务器IP："
echo "   - student.jaredanjerry.top -> 119.91.223.147"
echo "   - admin.jaredanjerry.top -> 119.91.223.147"
echo "   - api.jaredanjerry.top -> 119.91.223.147"
echo ""
echo "2. 等待证书自动获取（可能需要几分钟）"
echo "3. 访问 https://student.jaredanjerry.top 测试" 