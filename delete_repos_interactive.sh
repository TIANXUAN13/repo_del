#!/bin/bash
#
# 交互式GitHub仓库批量删除工具 (gh CLI版本)
# 自动获取仓库列表，让用户勾选删除
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 全局变量
declare -a REPO_NAMES
declare -a REPO_FULL_NAMES
declare -a REPO_VISIBILITY
declare -a REPO_DESC
USERNAME=""

clear_screen() {
    clear || printf "\033c"
}

check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        echo -e "${RED}错误：未找到 gh CLI${NC}"
        echo "请先安装 GitHub CLI: https://cli.github.com/"
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        echo -e "${RED}错误：请先登录 gh CLI${NC}"
        echo "运行: gh auth login"
        exit 1
    fi
}

get_username() {
    USERNAME=$(gh api user -q .login)
    echo -e "${GREEN}✓${NC} 已连接到用户: ${CYAN}$USERNAME${NC}"
}

fetch_repos() {
    echo -e "${YELLOW}正在获取仓库列表...${NC}"
    
    # 清空数组
    REPO_NAMES=()
    REPO_FULL_NAMES=()
    REPO_VISIBILITY=()
    REPO_DESC=()
    
    # 获取仓库列表
    local json_data=$(gh repo list "$USERNAME" --limit 100 --json name,fullName,visibility,description,updatedAt,stargazerCount -q '
        .[] | "\(.name)|\(.fullName)|\(.visibility)|\(.description // "无描述")|\(.updatedAt[:10])|\(.stargazerCount)"
    ')
    
    # 解析数据
    local i=0
    while IFS='|' read -r name fullname visibility desc updated stars; do
        REPO_NAMES[$i]="$name"
        REPO_FULL_NAMES[$i]="$fullname"
        REPO_VISIBILITY[$i]="$visibility"
        REPO_DESC[$i]="$desc"
        ((i++))
    done <<< "$json_data"
    
    echo -e "${GREEN}✓${NC} 找到 ${CYAN}${#REPO_NAMES[@]}${NC} 个仓库"
}

display_repos() {
    if [ ${#REPO_NAMES[@]} -eq 0 ]; then
        echo -e "${YELLOW}没有找到任何仓库${NC}"
        return
    fi
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  仓库列表${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local i=0
    for name in "${REPO_NAMES[@]}"; do
        local num=$((i+1))
        local vis="${REPO_VISIBILITY[$i]}"
        local fullname="${REPO_FULL_NAMES[$i]}"
        local desc="${REPO_DESC[$i]}"
        
        # 截断描述
        if [ ${#desc} -gt 50 ]; then
            desc="${desc:0:50}..."
        fi
        
        if [ "$vis" = "PRIVATE" ]; then
            echo -e "${CYAN}${num}${NC}. ${fullname} ${RED}[私有]${NC}"
        else
            echo -e "${CYAN}${num}${NC}. ${fullname} ${GREEN}[公开]${NC}"
        fi
        
        echo "   ${desc}"
        echo ""
        
        ((i++))
    done
}

parse_selection() {
    local input="$1"
    local -n arr=$2
    local total=$3
    
    # 清空数组
    arr=()
    
    # 处理 'all'
    if [ "$input" = "all" ]; then
        for ((i=0; i<total; i++)); do
            arr+=($i)
        done
        return 0
    fi
    
    # 替换逗号为空格，然后分割
    local parts=$(echo "$input" | tr ',' ' ')
    
    for part in $parts; do
        part=$(echo "$part" | tr -d ' ')
        
        if [ -z "$part" ]; then
            continue
        fi
        
        # 检查是否为范围 (如: 1-10)
        if [[ "$part" =~ ^[0-9]+-[0-9]+$ ]]; then
            local start=$(echo "$part" | cut -d'-' -f1)
            local end=$(echo "$part" | cut -d'-' -f2)
            
            if [ "$start" -lt 1 ] || [ "$end" -gt "$total" ] || [ "$start" -gt "$end" ]; then
                echo -e "${RED}错误：范围 $part 无效（有效范围：1-$total）${NC}"
                return 1
            fi
            
            for ((i=start-1; i<end; i++)); do
                # 检查是否已存在
                local exists=0
                for idx in "${arr[@]}"; do
                    if [ "$idx" -eq "$i" ]; then
                        exists=1
                        break
                    fi
                done
                if [ "$exists" -eq 0 ]; then
                    arr+=($i)
                fi
            done
        else
            # 单个数字
            if ! [[ "$part" =~ ^[0-9]+$ ]]; then
                echo -e "${RED}错误：无法解析 '$part'${NC}"
                return 1
            fi
            
            if [ "$part" -lt 1 ] || [ "$part" -gt "$total" ]; then
                echo -e "${RED}错误：编号 $part 超出范围（有效范围：1-$total）${NC}"
                return 1
            fi
            
            local idx=$((part-1))
            # 检查是否已存在
            local exists=0
            for existing in "${arr[@]}"; do
                if [ "$existing" -eq "$idx" ]; then
                    exists=1
                    break
                fi
            done
            if [ "$exists" -eq 0 ]; then
                arr+=($idx)
            fi
        fi
    done
    
    # 排序
    IFS=$'\n' sorted=($(sort -n <<<"${arr[*]}"))
    unset IFS
    arr=("${sorted[@]}")
    
    return 0
}

select_repos() {
    if [ ${#REPO_NAMES[@]} -eq 0 ]; then
        echo -e "${YELLOW}没有仓库可供选择${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  选择要删除的仓库${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "输入方式："
    echo "  ${CYAN}-${NC} 单个数字: ${GREEN}5${NC}"
    echo "  ${CYAN}-${NC} 范围: ${GREEN}1-10${NC}"
    echo "  ${CYAN}-${NC} 多个（逗号或空格）: ${GREEN}1,3,5,7${NC} 或 ${GREEN}1 3 5 7${NC}"
    echo "  ${CYAN}-${NC} 混合: ${GREEN}1-5,8,10-12${NC}"
    echo "  ${CYAN}-${NC} 全部: ${GREEN}all${NC}"
    echo "  ${CYAN}-${NC} 返回: ${GREEN}q${NC}"
    echo ""
    
    while true; do
        read -p "请选择仓库编号: " selection
        
        if [ "$selection" = "q" ] || [ "$selection" = "quit" ]; then
            return 1
        fi
        
        local -a indices=()
        if parse_selection "$selection" indices ${#REPO_NAMES[@]}; then
            if [ ${#indices[@]} -eq 0 ]; then
                echo -e "${RED}未选择任何仓库，请重新输入${NC}"
                continue
            fi
            
            # 返回选择的索引
            SELECTED_INDICES=("${indices[@]}")
            return 0
        fi
    done
}

confirm_deletion() {
    local -a indices=("$@")
    
    if [ ${#indices[@]} -eq 0 ]; then
        return 1
    fi
    
    echo ""
    echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  ⚠️  即将删除以下仓库（此操作不可恢复！）${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local i=1
    for idx in "${indices[@]}"; do
        local fullname="${REPO_FULL_NAMES[$idx]}"
        local vis="${REPO_VISIBILITY[$idx]}"
        
        if [ "$vis" = "PRIVATE" ]; then
            echo -e "${i}. ${fullname} ${RED}[私有]${NC}"
        else
            echo -e "${i}. ${fullname} ${GREEN}[公开]${NC}"
        fi
        ((i++))
    done
    
    echo ""
    echo -e "总计: ${CYAN}${#indices[@]}${NC} 个仓库"
    echo ""
    
    # 双重确认
    echo "请输入以下信息进行确认："
    echo ""
    
    read -p "1. 输入你的 GitHub 用户名 '$USERNAME' 以确认: " confirm1
    if [ "$confirm1" != "$USERNAME" ]; then
        echo ""
        echo -e "${RED}❌ 用户名不匹配，取消操作${NC}"
        return 1
    fi
    
    echo ""
    read -p "2. 输入 'DELETE' 最终确认删除: " confirm2
    if [ "$confirm2" != "DELETE" ]; then
        echo ""
        echo -e "${RED}❌ 确认失败，取消操作${NC}"
        return 1
    fi
    
    return 0
}

delete_selected_repos() {
    local -a indices=("$@")
    
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  开始删除...${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local success=0
    local failed=0
    
    for idx in "${indices[@]}"; do
        local fullname="${REPO_FULL_NAMES[$idx]}"
        local error_output
        
        error_output=$(gh repo delete "$fullname" --yes 2>&1)
        local exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            echo -e "${GREEN}✓${NC} 已删除: $fullname"
            ((success++))
        else
            ((failed++))
            if echo "$error_output" | grep -q "404"; then
                echo -e "${RED}✗${NC} 删除失败: $fullname (仓库不存在或已被删除 - 404)"
            elif echo "$error_output" | grep -q "403"; then
                echo -e "${RED}✗${NC} 删除失败: $fullname (权限不足或需要重新认证 - 403)"
            else
                echo -e "${RED}✗${NC} 删除失败: $fullname (未知错误)"
            fi
        fi
    done
    
    echo ""
    echo -e "完成: ${GREEN}✓ $success${NC} 成功, ${RED}✗ $failed${NC} 失败"
}

filter_repos() {
    local keyword="$1"
    local -a filtered_indices=()
    
    local i=0
    for name in "${REPO_NAMES[@]}"; do
        local desc="${REPO_DESC[$i]}"
        
        if [[ "${name,,}" == *"${keyword,,}"* ]] || [[ "${desc,,}" == *"${keyword,,}"* ]]; then
            filtered_indices+=($i)
        fi
        ((i++))
    done
    
    if [ ${#filtered_indices[@]} -eq 0 ]; then
        echo -e "${YELLOW}没有找到包含 '$keyword' 的仓库${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  找到 ${CYAN}${#filtered_indices[@]}${BLUE} 个匹配的仓库${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    for idx in "${filtered_indices[@]}"; do
        local num=$((idx+1))
        local fullname="${REPO_FULL_NAMES[$idx]}"
        local vis="${REPO_VISIBILITY[$idx]}"
        local desc="${REPO_DESC[$idx]}"
        
        if [ ${#desc} -gt 50 ]; then
            desc="${desc:0:50}..."
        fi
        
        if [ "$vis" = "PRIVATE" ]; then
            echo -e "${CYAN}${num}${NC}. ${fullname} ${RED}[私有]${NC}"
        else
            echo -e "${CYAN}${num}${NC}. ${fullname} ${GREEN}[公开]${NC}"
        fi
        echo "   ${desc}"
        echo ""
    done
    
    return 0
}

main_menu() {
    while true; do
        clear_screen
        echo ""
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}     GitHub 仓库批量删除工具（交互式）                          ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "当前用户: ${GREEN}$USERNAME${NC} | 仓库数: ${CYAN}${#REPO_NAMES[@]}${NC}"
        echo ""
        echo "  ${CYAN}1.${NC} 查看所有仓库"
        echo "  ${CYAN}2.${NC} 按关键词筛选仓库"
        echo "  ${CYAN}3.${NC} 选择并删除仓库"
        echo "  ${CYAN}4.${NC} 刷新仓库列表"
        echo "  ${CYAN}5.${NC} 退出"
        echo ""
        
        read -p "请选择操作 (1-5): " choice
        
        case $choice in
            1)
                clear_screen
                display_repos
                echo ""
                read -p "按回车键返回菜单..."
                ;;
            
            2)
                clear_screen
                read -p "请输入关键词: " keyword
                if [ -n "$keyword" ]; then
                    filter_repos "$keyword"
                    echo ""
                    read -p "按回车键返回菜单..."
                fi
                ;;
            
            3)
                clear_screen
                display_repos
                
                if select_repos; then
                    echo ""
                    echo -e "${YELLOW}已选择的仓库：${NC}"
                    for idx in "${SELECTED_INDICES[@]}"; do
                        echo "  - ${REPO_FULL_NAMES[$idx]}"
                    done
                    
                    echo ""
                    read -p "确认删除这些仓库? (y/N): " confirm
                    
                    if [[ $confirm =~ ^[Yy]$ ]]; then
                        if confirm_deletion "${SELECTED_INDICES[@]}"; then
                            delete_selected_repos "${SELECTED_INDICES[@]}"
                            
                            # 刷新列表
                            echo ""
                            read -p "按回车键刷新仓库列表..."
                            fetch_repos
                        fi
                    fi
                fi
                ;;
            
            4)
                clear_screen
                fetch_repos
                echo ""
                read -p "按回车键返回菜单..."
                ;;
            
            5)
                clear_screen
                echo -e "${GREEN}再见！${NC}"
                exit 0
                ;;
            
            *)
                echo -e "${RED}无效选项${NC}"
                sleep 1
                ;;
        esac
    done
}

# 主程序
clear_screen
check_gh_cli
get_username
fetch_repos
main_menu
