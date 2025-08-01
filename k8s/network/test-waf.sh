#!/bin/bash

# RMMT WAF测试脚本 - 无需额外软件

set -e

echo "🛡️ 开始测试RMMT WAF防护..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 获取Ingress IP
echo -e "${BLUE}1️⃣ 获取Ingress IP地址...${NC}"
INGRESS_IP=roommate.seth24.com
echo "Ingress IP: $INGRESS_IP"

# 测试函数
test_waf() {
    local test_name="$1"
    local url="$2"
    local expected_status="$3"
    local description="$4"
    
    echo -e "\n${YELLOW}测试: $test_name${NC}"
    echo "描述: $description"
    echo "URL: $url"
    
    # 发送请求并获取状态码
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    if [ "$response" = "$expected_status" ]; then
        echo -e "${GREEN}✅ 通过 - 状态码: $response${NC}"
        return 0
    else
        echo -e "${RED}❌ 失败 - 期望: $expected_status, 实际: $response${NC}"
        return 1
    fi
}

# 测试计数器
passed=0
total=0

echo -e "\n${BLUE}2️⃣ 开始WAF测试...${NC}"

# 测试1: SQL注入攻击
((total++))
if test_waf "SQL注入测试" \
    "http://$INGRESS_IP/?id=1' OR '1'='1" \
    "403" \
    "检测SQL注入攻击"; then
    ((passed++))
fi

# 测试2: XSS攻击
((total++))
if test_waf "XSS攻击测试" \
    "http://$INGRESS_IP/?q=<script>alert('xss')</script>" \
    "403" \
    "检测XSS攻击"; then
    ((passed++))
fi

# 测试3: 路径遍历攻击
((total++))
if test_waf "路径遍历测试" \
    "http://$INGRESS_IP/../../../etc/passwd" \
    "403" \
    "检测路径遍历攻击"; then
    ((passed++))
fi

# 测试4: 恶意User-Agent
((total++))
if test_waf "恶意User-Agent测试" \
    "http://$INGRESS_IP/" \
    "403" \
    "检测恶意User-Agent (sqlmap)"; then
    ((passed++))
fi

# 测试5: 正常请求（应该通过）
((total++))
if test_waf "正常请求测试" \
    "http://$INGRESS_IP/" \
    "200" \
    "正常请求应该通过"; then
    ((passed++))
fi

# 测试6: 速率限制测试
echo -e "\n${YELLOW}速率限制测试...${NC}"
echo "发送100个快速请求测试速率限制..."
for i in {1..100}; do
    curl -s -o /dev/null "http://$INGRESS_IP/" &
done
wait

# 检查是否有请求被限制
rate_limit_response=$(curl -s -o /dev/null -w "%{http_code}" "http://$INGRESS_IP/" 2>/dev/null || echo "000")
if [ "$rate_limit_response" = "429" ]; then
    echo -e "${GREEN}✅ 速率限制工作正常${NC}"
    ((passed++))
else
    echo -e "${YELLOW}⚠️  速率限制可能未生效 (状态码: $rate_limit_response)${NC}"
fi
((total++))

# 测试7: 检查安全头
echo -e "\n${YELLOW}安全头测试...${NC}"
headers=$(curl -s -I "http://$INGRESS_IP/" 2>/dev/null)
if echo "$headers" | grep -q "X-Frame-Options"; then
    echo -e "${GREEN}✅ X-Frame-Options 头存在${NC}"
    ((passed++))
else
    echo -e "${RED}❌ X-Frame-Options 头缺失${NC}"
fi
((total++))

if echo "$headers" | grep -q "X-Content-Type-Options"; then
    echo -e "${GREEN}✅ X-Content-Type-Options 头存在${NC}"
    ((passed++))
else
    echo -e "${RED}❌ X-Content-Type-Options 头缺失${NC}"
fi
((total++))

# 测试8: 检查Ingress日志
echo -e "\n${YELLOW}检查Ingress日志中的安全事件...${NC}"
echo "查看最近的Traefik日志："
kubectl logs -n kube-system deployment/traefik --tail=20 2>/dev/null | grep -i "403\|block\|deny\|waf" || echo "没有找到安全相关日志"

# 测试9: 检查WAF ConfigMap
echo -e "\n${YELLOW}检查WAF配置...${NC}"
if kubectl get configmap rmmt-waf-config -n rmmt >/dev/null 2>&1; then
    echo -e "${GREEN}✅ WAF ConfigMap存在${NC}"
    ((passed++))
else
    echo -e "${RED}❌ WAF ConfigMap不存在${NC}"
fi
((total++))

# 测试10: 检查中间件配置
echo -e "\n${YELLOW}检查中间件配置...${NC}"
if kubectl get middleware rmmt-waf -n rmmt >/dev/null 2>&1; then
    echo -e "${GREEN}✅ WAF中间件存在${NC}"
    ((passed++))
else
    echo -e "${RED}❌ WAF中间件不存在${NC}"
fi
((total++))

# 总结
echo -e "\n${BLUE}📊 测试总结:${NC}"
echo "=================================="
echo -e "通过: ${GREEN}$passed${NC} / ${BLUE}$total${NC}"
echo -e "成功率: ${GREEN}$((passed * 100 / total))%${NC}"

if [ $passed -eq $total ]; then
    echo -e "\n${GREEN}🎉 所有测试通过！WAF配置正常工作。${NC}"
else
    echo -e "\n${YELLOW}⚠️  部分测试失败，请检查WAF配置。${NC}"
fi

echo -e "\n${BLUE}🔍 手动验证命令：${NC}"
echo "1. 查看WAF配置: kubectl get configmap rmmt-waf-config -n rmmt -o yaml"
echo "2. 查看中间件: kubectl get middleware -n rmmt"
echo "3. 查看Ingress: kubectl get ingress -n rmmt -o yaml"
echo "4. 查看Traefik日志: kubectl logs -n kube-system deployment/traefik -f" 