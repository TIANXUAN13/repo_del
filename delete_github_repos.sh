#!/bin/bash
#
# 批量删除GitHub仓库脚本 (使用 gh CLI)
# 需要先安装 GitHub CLI: https://cli.github.com/
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "GitHub 仓库批量删除工具 (gh CLI版本)"
echo "========================================"
echo ""

# 检查 gh CLI 是否安装
if ! command -v gh &> /dev/null; then
    echo -e "${RED}错误：未找到 gh CLI${NC}"
    echo "请先安装 GitHub CLI: https://cli.github.com/"
    exit 1
fi

# 检查登录状态
if ! gh auth status &> /dev/null; then
    echo -e "${RED}错误：请先登录 gh CLI${NC}"
    echo "运行: gh auth login"
    exit 1
fi

# 获取当前用户名
USERNAME=$(gh api user -q .login)
echo -e "当前用户: ${GREEN}$USERNAME${NC}"
echo ""

# 显示菜单
echo "请选择操作:"
echo "1) 列出所有仓库"
echo "2) 删除指定仓库（从文件读取）"
echo "3) 按关键词筛选删除"
echo "4) 删除单个仓库"
echo ""

read -p "请输入选项 (1-4): " choice

case $choice in
    1)
        echo -e "\n${YELLOW}正在获取仓库列表...${NC}"
        gh repo list "$USERNAME" --limit 100 --json name,visibility,description -q '
            .[] | "\(.name) [\(.visibility)] - \(.description // "无描述")"
        '
        ;;
        
    2)
        # 创建仓库列表文件示例
        REPO_FILE="repos_to_delete.txt"
        
        if [ ! -f "$REPO_FILE" ]; then
            echo -e "${YELLOW}创建示例文件: $REPO_FILE${NC}"
            cat > "$REPO_FILE" << 'EOF'
# 在此文件中列出要删除的仓库（每行一个）
# 格式: 用户名/仓库名
# 示例:
# username/old-repo-1
# username/old-repo-2
EOF
            echo -e "${RED}请先编辑 $REPO_FILE 文件，添加要删除的仓库${NC}"
            exit 1
        fi
        
        # 读取要删除的仓库（过滤掉注释和空行）
        REPOS=$(grep -v '^#' "$REPO_FILE" | grep -v '^$' | grep -v '^\s*$')
        
        if [ -z "$REPOS" ]; then
            echo -e "${RED}错误: $REPO_FILE 中没有有效的仓库名${NC}"
            exit 1
        fi
        
        echo -e "\n${YELLOW}准备删除以下仓库:${NC}"
        echo "$REPOS" | while read repo; do
            echo "  - $repo"
        done
        
        echo ""
        read -p "⚠️  警告：此操作不可恢复！输入 '$USERNAME' 确认删除: " confirm
        
        if [ "$confirm" != "$USERNAME" ]; then
            echo -e "${RED}确认失败，取消操作${NC}"
            exit 1
        fi
        
        echo -e "\n${YELLOW}开始删除...${NC}"
        success=0
        failed=0
        
        echo "$REPOS" | while read repo; do
            error_output=$(gh repo delete "$repo" --yes 2>&1)
            exit_code=$?
            if [ $exit_code -eq 0 ]; then
                echo -e "${GREEN}✓ 已删除: $repo${NC}"
                ((success++))
            else
                ((failed++))
                if echo "$error_output" | grep -q "HTTP 404"; then
                    echo -e "${RED}✗ 删除失败: $repo - 仓库不存在或已被删除${NC}"
                elif echo "$error_output" | grep -q "HTTP 403"; then
                    echo -e "${RED}✗ 删除失败: $repo - 权限不足（请检查 Token 是否有 delete_repo 权限）${NC}"
                else
                    echo -e "${RED}✗ 删除失败: $repo${NC}"
                    echo -e "${RED}  错误信息: $error_output${NC}"
                fi
            fi
        done
        
        echo ""
        echo -e "${GREEN}完成: 成功 $success, 失败 $failed${NC}"
        ;;
        
    3)
        read -p "请输入关键词: " keyword
        
        if [ -z "$keyword" ]; then
            echo -e "${RED}关键词不能为空${NC}"
            exit 1
        fi
        
        echo -e "\n${YELLOW}查找包含 '$keyword' 的仓库...${NC}"
        
        # 获取匹配的仓库
        MATCHING=$(gh repo list "$USERNAME" --limit 100 --json name -q ".[] | select(.name | contains(\"$keyword\")) | .name")
        
        if [ -z "$MATCHING" ]; then
            echo -e "${RED}没有找到匹配的仓库${NC}"
            exit 1
        fi
        
        echo -e "${YELLOW}找到以下匹配的仓库:${NC}"
        echo "$MATCHING" | while read name; do
            echo "  - $USERNAME/$name"
        done
        
        echo ""
        read -p "⚠️  输入 'DELETE' 确认删除这些仓库: " confirm
        
        if [ "$confirm" != "DELETE" ]; then
            echo -e "${RED}确认失败，取消操作${NC}"
            exit 1
        fi
        
        echo -e "\n${YELLOW}开始删除...${NC}"
        
        echo "$MATCHING" | while read name; do
            error_output=$(gh repo delete "$USERNAME/$name" --yes 2>&1)
            exit_code=$?
            if [ $exit_code -eq 0 ]; then
                echo -e "${GREEN}✓ 已删除: $USERNAME/$name${NC}"
            else
                if echo "$error_output" | grep -q "HTTP 404"; then
                    echo -e "${RED}✗ 删除失败: $USERNAME/$name - 仓库不存在或已被删除${NC}"
                elif echo "$error_output" | grep -q "HTTP 403"; then
                    echo -e "${RED}✗ 删除失败: $USERNAME/$name - 权限不足（请检查 Token 是否有 delete_repo 权限）${NC}"
                else
                    echo -e "${RED}✗ 删除失败: $USERNAME/$name${NC}"
                    echo -e "${RED}  错误信息: $error_output${NC}"
                fi
            fi
        done
        ;;
        
    4)
        read -p "请输入要删除的仓库名 (格式: 用户名/仓库名): " repo
        
        if [ -z "$repo" ]; then
            echo -e "${RED}仓库名不能为空${NC}"
            exit 1
        fi
        
        echo ""
        read -p "⚠️  确认删除 $repo? (y/N): " confirm
        
        if [[ $confirm =~ ^[Yy]$ ]]; then
            error_output=$(gh repo delete "$repo" --yes 2>&1)
            exit_code=$?
            if [ $exit_code -eq 0 ]; then
                echo -e "${GREEN}✓ 已成功删除: $repo${NC}"
            else
                if echo "$error_output" | grep -q "HTTP 404"; then
                    echo -e "${RED}✗ 删除失败: 仓库不存在或已被删除${NC}"
                elif echo "$error_output" | grep -q "HTTP 403"; then
                    echo -e "${RED}✗ 删除失败: 权限不足（请检查 Token 是否有 delete_repo 权限）${NC}"
                else
                    echo -e "${RED}✗ 删除失败${NC}"
                    echo -e "${RED}  错误信息: $error_output${NC}"
                fi
            fi
        else
            echo "取消操作"
        fi
        ;;
        
    *)
        echo -e "${RED}无效选项${NC}"
        exit 1
        ;;
esac
