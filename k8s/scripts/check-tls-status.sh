#!/bin/bash

# RMMT TLS证书状态检查脚本

set -e

echo "🔍 检查RMMT TLS证书状态..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查cert-manager状态
echo -e "${BLUE}1️⃣ 检查cert-manager状态...${NC}"
if kubectl get pods -n cert-manager 2>/dev/null | grep -q "cert-manager"; then
    echo -e "${GREEN}✅ cert-manager已安装${NC}"
    kubectl get pods -n cert-manager
else
    echo -e "${RED}❌ cert-manager未安装${NC}"
    exit 1
fi

echo ""

# 检查ClusterIssuer状态
echo -e "${BLUE}2️⃣ 检查ClusterIssuer状态...${NC}"
if kubectl get clusterissuer letsencrypt-prod 2>/dev/null; then
    echo -e "${GREEN}✅ ClusterIssuer已配置${NC}"
else
    echo -e "${RED}❌ ClusterIssuer未配置${NC}"
fi

echo ""

# 检查Certificate状态
echo -e "${BLUE}3️⃣ 检查Certificate状态...${NC}"
if kubectl get certificate -n rmmt 2>/dev/null; then
    echo -e "${GREEN}✅ Certificate已配置${NC}"
else
    echo -e "${YELLOW}⚠️  Certificate未配置${NC}"
fi

echo ""

# 检查TLS Secret状态
echo -e "${BLUE}4️⃣ 检查TLS Secret状态...${NC}"
if kubectl get secret rmmt-tls -n rmmt 2>/dev/null; then
    echo -e "${GREEN}✅ TLS Secret已创建${NC}"
    echo "Secret详情："
    kubectl describe secret rmmt-tls -n rmmt
else
    echo -e "${YELLOW}⚠️  TLS Secret未创建${NC}"
fi

echo ""

# 检查Ingress状态
echo -e "${BLUE}5️⃣ 检查Ingress状态...${NC}"
if kubectl get ingress -n rmmt 2>/dev/null; then
    echo -e "${GREEN}✅ Ingress已配置${NC}"
    kubectl get ingress -n rmmt
else
    echo -e "${YELLOW}⚠️  Ingress未配置${NC}"
fi

echo ""

# 检查DNS解析
echo -e "${BLUE}6️⃣ 检查DNS解析状态...${NC}"
DOMAINS=("student.jaredanjerry.top" "admin.jaredanjerry.top" "api.jaredanjerry.top")
SERVER_IP="119.91.223.147"

for domain in "${DOMAINS[@]}"; do
    echo -n "检查 $domain: "
    if nslookup "$domain" 2>/dev/null | grep -q "$SERVER_IP"; then
        echo -e "${GREEN}✅ 解析正确${NC}"
    else
        echo -e "${RED}❌ 解析失败或指向错误IP${NC}"
        echo "  期望IP: $SERVER_IP"
        echo "  当前解析:"
        nslookup "$domain" 2>/dev/null || echo "    无法解析"
    fi
done

echo ""

# 检查证书请求状态
echo -e "${BLUE}7️⃣ 检查证书请求状态...${NC}"
if kubectl get certificaterequest -n rmmt 2>/dev/null; then
    echo "证书请求详情："
    kubectl describe certificaterequest -n rmmt
else
    echo -e "${YELLOW}⚠️  没有证书请求${NC}"
fi

echo ""

# 检查Order状态
echo -e "${BLUE}8️⃣ 检查Order状态...${NC}"
if kubectl get order -n rmmt 2>/dev/null; then
    echo "Order详情："
    kubectl describe order -n rmmt
else
    echo -e "${YELLOW}⚠️  没有Order${NC}"
fi

echo ""

# 检查Challenge状态
echo -e "${BLUE}9️⃣ 检查Challenge状态...${NC}"
if kubectl get challenge -n rmmt 2>/dev/null; then
    echo "Challenge详情："
    kubectl describe challenge -n rmmt
else
    echo -e "${YELLOW}⚠️  没有Challenge${NC}"
fi

echo ""

# 检查Traefik日志中的TLS错误
echo -e "${BLUE}🔟 检查Traefik TLS错误...${NC}"
echo "最近的Traefik日志（TLS相关）："
kubectl logs -n kube-system deployment/traefik --tail=20 2>/dev/null | grep -i "tls\|cert\|ssl" || echo "没有找到TLS相关日志"

echo ""

# 总结
echo -e "${BLUE}📋 状态总结:${NC}"
echo "=================================="

# 检查关键组件
COMPONENTS=(
    "cert-manager:$(kubectl get pods -n cert-manager --no-headers 2>/dev/null | wc -l | tr -d ' ')"
    "clusterissuer:$(kubectl get clusterissuer letsencrypt-prod --no-headers 2>/dev/null | wc -l | tr -d ' ')"
    "certificate:$(kubectl get certificate -n rmmt --no-headers 2>/dev/null | wc -l | tr -d ' ')"
    "tls-secret:$(kubectl get secret rmmt-tls -n rmmt --no-headers 2>/dev/null | wc -l | tr -d ' ')"
    "ingress:$(kubectl get ingress -n rmmt --no-headers 2>/dev/null | wc -l | tr -d ' ')"
)

for component in "${COMPONENTS[@]}"; do
    name=$(echo "$component" | cut -d: -f1)
    count=$(echo "$component" | cut -d: -f2)
    if [ "$count" -gt 0 ]; then
        echo -e "${GREEN}✅ $name: 已配置${NC}"
    else
        echo -e "${RED}❌ $name: 未配置${NC}"
    fi
done

echo ""
echo -e "${YELLOW}💡 下一步操作建议:${NC}"
echo "1. 如果DNS解析失败，需要配置DNS记录："
echo "   - student.jaredanjerry.top -> $SERVER_IP"
echo "   - admin.jaredanjerry.top -> $SERVER_IP"
echo "   - api.jaredanjerry.top -> $SERVER_IP"
echo ""
echo "2. 如果所有组件都已配置但证书未就绪，等待几分钟让cert-manager自动处理"
echo ""
echo "3. 如果遇到问题，可以查看详细日志："
echo "   kubectl logs -n cert-manager deployment/cert-manager"
echo "   kubectl logs -n kube-system deployment/traefik" 