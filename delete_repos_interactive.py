#!/usr/bin/env python3
"""
交互式GitHub仓库批量删除工具
自动获取仓库列表，让用户勾选删除
"""

import os
import sys
import requests
from urllib.parse import quote

def get_github_token():
    """从环境变量获取GitHub Token"""
    token = os.environ.get('GITHUB_TOKEN')
    if not token:
        print("错误：请设置GITHUB_TOKEN环境变量")
        print("例如: export GITHUB_TOKEN='your_token_here'")
        sys.exit(1)
    return token

def get_all_repos(token):
    """获取用户的所有仓库"""
    headers = {
        'Authorization': f'token {token}',
        'Accept': 'application/vnd.github.v3+json'
    }
    
    repos = []
    page = 1
    
    print("正在获取仓库列表...")
    
    while True:
        response = requests.get(
            f'https://api.github.com/user/repos?per_page=100&page={page}&type=owner&sort=updated',
            headers=headers
        )
        
        if response.status_code != 200:
            print(f"获取仓库列表失败: {response.status_code}")
            print(response.json())
            break
        
        data = response.json()
        if not data:
            break
        
        repos.extend(data)
        page += 1
        print(f"  已获取 {len(repos)} 个仓库...")
    
    return repos

def display_repos(repos):
    """显示仓库列表"""
    if not repos:
        print("\n没有找到任何仓库")
        return
    
    print(f"\n{'='*80}")
    print(f"找到 {len(repos)} 个仓库：")
    print(f"{'='*80}")
    print()
    
    for i, repo in enumerate(repos, 1):
        visibility = "🔒 私有" if repo['private'] else "🌐 公开"
        updated = repo['updated_at'][:10] if repo['updated_at'] else 'N/A'
        
        print(f"{i:3d}. {repo['full_name']:<50} {visibility}")
        if repo['description']:
            desc = repo['description'][:60] + '...' if len(repo['description']) > 60 else repo['description']
            print(f"     描述: {desc}")
        print(f"     更新: {updated} | ⭐ {repo['stargazers_count']} | 🍴 {repo['forks_count']}")
        print()

def select_repos_interactive(repos):
    """交互式选择要删除的仓库"""
    if not repos:
        return []
    
    print("\n" + "="*80)
    print("选择要删除的仓库")
    print("="*80)
    print("\n输入方式：")
    print("  - 输入单个数字: 5")
    print("  - 输入范围: 1-10")
    print("  - 输入多个（逗号分隔）: 1,3,5,7")
    print("  - 输入多个（空格分隔）: 1 3 5 7")
    print("  - 混合使用: 1-5,8,10-12")
    print("  - 输入 'all' 选择全部")
    print("  - 输入 'q' 或 'quit' 退出")
    print()
    
    while True:
        user_input = input("请选择要删除的仓库编号: ").strip().lower()
        
        if user_input in ['q', 'quit', 'exit']:
            print("取消操作")
            return []
        
        if user_input == 'all':
            return list(range(len(repos)))
        
        selected_indices = set()
        
        # 处理逗号和空格分隔
        parts = user_input.replace(',', ' ').split()
        
        for part in parts:
            part = part.strip()
            if not part:
                continue
            
            # 处理范围 (如: 1-10)
            if '-' in part:
                try:
                    start, end = part.split('-', 1)
                    start = int(start.strip())
                    end = int(end.strip())
                    
                    if start < 1 or end > len(repos) or start > end:
                        print(f"错误：范围 {part} 无效（有效范围：1-{len(repos)}）")
                        continue
                    
                    selected_indices.update(range(start-1, end))
                except ValueError:
                    print(f"错误：无法解析 '{part}'")
                    continue
            else:
                # 处理单个数字
                try:
                    num = int(part)
                    if num < 1 or num > len(repos):
                        print(f"错误：编号 {num} 超出范围（有效范围：1-{len(repos)}）")
                        continue
                    selected_indices.add(num - 1)
                except ValueError:
                    print(f"错误：无法解析 '{part}'")
                    continue
        
        if selected_indices:
            return sorted(list(selected_indices))
        else:
            print("未选择任何仓库，请重新输入")

def confirm_deletion(selected_repos, username):
    """最终确认删除"""
    if not selected_repos:
        return False
    
    print("\n" + "="*80)
    print("⚠️  即将删除以下仓库（此操作不可恢复！）")
    print("="*80)
    print()
    
    for i, repo in enumerate(selected_repos, 1):
        visibility = "私有" if repo['private'] else "公开"
        print(f"{i}. {repo['full_name']} ({visibility})")
    
    print()
    print(f"总计: {len(selected_repos)} 个仓库")
    print()
    
    # 双重确认
    print("请输入以下信息进行确认：")
    print()
    
    # 第一重：输入用户名
    confirm1 = input(f"1. 输入你的 GitHub 用户名 '{username}' 以确认: ")
    if confirm1 != username:
        print("\n❌ 用户名不匹配，取消操作")
        return False
    
    # 第二重：输入 DELETE
    print()
    confirm2 = input("2. 输入 'DELETE' 最终确认删除: ")
    if confirm2 != 'DELETE':
        print("\n❌ 确认失败，取消操作")
        return False
    
    return True

def delete_repo(token, repo_full_name):
    """删除指定仓库"""
    headers = {
        'Authorization': f'token {token}',
        'Accept': 'application/vnd.github.v3+json'
    }
    
    # GitHub API URL 格式: https://api.github.com/repos/owner/repo
    # 注意：斜杠 / 不应被编码，所以 safe='/'
    # 实际上 requests 库会自动处理 URL，不需要手动编码
    url = f'https://api.github.com/repos/{repo_full_name}'
    
    response = requests.delete(url, headers=headers)
    
    if response.status_code == 204:
        return True, None
    else:
        error_msg = response.json().get('message', 'Unknown error')
        return False, error_msg

def filter_repos(repos, keyword):
    """按关键词过滤仓库"""
    keyword_lower = keyword.lower()
    return [
        repo for repo in repos
        if keyword_lower in repo['name'].lower() 
        or (repo['description'] and keyword_lower in repo['description'].lower())
    ]

def main():
    print("="*80)
    print(" GitHub 仓库批量删除工具（交互式）")
    print("="*80)
    print()
    
    # 获取Token
    token = get_github_token()
    
    # 获取当前用户
    headers = {
        'Authorization': f'token {token}',
        'Accept': 'application/vnd.github.v3+json'
    }
    response = requests.get('https://api.github.com/user', headers=headers)
    
    if response.status_code != 200:
        print("❌ 验证Token失败，请检查GITHUB_TOKEN是否正确")
        sys.exit(1)
    
    user = response.json()
    username = user['login']
    print(f"✓ 已连接到用户: {username}")
    print()
    
    # 获取所有仓库
    repos = get_all_repos(token)
    
    if not repos:
        print("\n没有找到任何仓库")
        return
    
    # 主循环
    while True:
        print("\n" + "="*80)
        print("主菜单")
        print("="*80)
        print()
        print("1. 查看所有仓库")
        print("2. 按关键词筛选仓库")
        print("3. 选择并删除仓库")
        print("4. 退出")
        print()
        
        choice = input("请选择操作 (1-4): ").strip()
        print()
        
        if choice == '1':
            display_repos(repos)
        
        elif choice == '2':
            keyword = input("请输入关键词: ").strip()
            if keyword:
                filtered = filter_repos(repos, keyword)
                print(f"\n找到 {len(filtered)} 个匹配的仓库")
                display_repos(filtered)
                
                if filtered:
                    use_filtered = input("是否使用筛选结果进行删除? (y/N): ").strip().lower()
                    if use_filtered in ['y', 'yes']:
                        selected_indices = select_repos_interactive(filtered)
                        if selected_indices:
                            selected_repos = [filtered[i] for i in selected_indices]
                            
                            if confirm_deletion(selected_repos, username):
                                print("\n" + "="*80)
                                print("开始删除...")
                                print("="*80)
                                
                                success_count = 0
                                fail_count = 0
                                
                                for repo in selected_repos:
                                    success, error = delete_repo(token, repo['full_name'])
                                    if success:
                                        print(f"✓ 已删除: {repo['full_name']}")
                                        success_count += 1
                                    else:
                                        print(f"✗ 删除失败: {repo['full_name']} - {error}")
                                        fail_count += 1
                                
                                print()
                                print(f"完成: ✓ {success_count} 成功, ✗ {fail_count} 失败")
                                
                                # 重新获取列表
                                repos = get_all_repos(token)
        
        elif choice == '3':
            display_repos(repos)
            
            selected_indices = select_repos_interactive(repos)
            
            if selected_indices:
                selected_repos = [repos[i] for i in selected_indices]
                
                print("\n" + "="*80)
                print("已选择的仓库：")
                print("="*80)
                for repo in selected_repos:
                    visibility = "私有" if repo['private'] else "公开"
                    print(f"  - {repo['full_name']} ({visibility})")
                
                confirm = input("\n确认删除这些仓库? (y/N): ").strip().lower()
                
                if confirm in ['y', 'yes']:
                    if confirm_deletion(selected_repos, username):
                        print("\n" + "="*80)
                        print("开始删除...")
                        print("="*80)
                        
                        success_count = 0
                        fail_count = 0
                        
                        for repo in selected_repos:
                            success, error = delete_repo(token, repo['full_name'])
                            if success:
                                print(f"✓ 已删除: {repo['full_name']}")
                                success_count += 1
                            else:
                                print(f"✗ 删除失败: {repo['full_name']} - {error}")
                                fail_count += 1
                        
                        print()
                        print(f"完成: ✓ {success_count} 成功, ✗ {fail_count} 失败")
                        
                        # 重新获取列表
                        repos = get_all_repos(token)
        
        elif choice == '4':
            print("再见！")
            break
        
        else:
            print("无效选项，请重新选择")

if __name__ == '__main__':
    main()
