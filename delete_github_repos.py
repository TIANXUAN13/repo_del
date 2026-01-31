#!/usr/bin/env python3
"""
批量删除GitHub仓库脚本
使用前请确保设置GITHUB_TOKEN环境变量
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

def get_repos_to_delete():
    """返回要删除的仓库列表（在这里修改）"""
    # 示例：请修改为你想要删除的仓库名
    repos = [
        # "username/repo1",
        # "username/repo2",
        # "username/repo3",
    ]
    return repos

def list_repos(token, username=None):
    """列出用户的所有仓库"""
    headers = {
        'Authorization': f'token {token}',
        'Accept': 'application/vnd.github.v3+json'
    }
    
    if username:
        url = f'https://api.github.com/users/{username}/repos'
    else:
        url = 'https://api.github.com/user/repos'
    
    repos = []
    page = 1
    
    while True:
        response = requests.get(
            f'{url}?per_page=100&page={page}&type=owner',
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
    
    return repos

def delete_repo(token, repo_full_name):
    """删除指定仓库"""
    headers = {
        'Authorization': f'token {token}',
        'Accept': 'application/vnd.github.v3+json'
    }
    
    # GitHub API URL 直接使用 full_name，requests 库会自动处理编码
    url = f'https://api.github.com/repos/{repo_full_name}'
    
    response = requests.delete(url, headers=headers)
    
    if response.status_code == 204:
        print(f"✓ 成功删除: {repo_full_name}")
        return True
    else:
        error_msg = response.json().get('message', 'Unknown error')
        if response.status_code == 404:
            print(f"✗ 删除失败 {repo_full_name}: 仓库不存在或已被删除")
        elif response.status_code == 403:
            print(f"✗ 删除失败 {repo_full_name}: 权限不足（请检查 Token 是否有 delete_repo 权限）")
        else:
            print(f"✗ 删除失败 {repo_full_name}: {response.status_code} - {error_msg}")
        return False

def main():
    print("=" * 60)
    print("GitHub 仓库批量删除工具")
    print("=" * 60)
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
        print("验证Token失败，请检查GITHUB_TOKEN是否正确")
        sys.exit(1)
    
    user = response.json()
    username = user['login']
    print(f"当前用户: {username}")
    print()
    
    # 选择模式
    print("请选择操作模式:")
    print("1. 列出所有仓库")
    print("2. 删除指定仓库（需在代码中编辑repos列表）")
    print("3. 按关键词筛选删除")
    print()
    
    choice = input("请输入选项 (1/2/3): ").strip()
    
    if choice == '1':
        # 列出所有仓库
        print("\n正在获取仓库列表...")
        repos = list_repos(token)
        
        if not repos:
            print("没有找到任何仓库")
            return
        
        print(f"\n找到 {len(repos)} 个仓库:\n")
        for i, repo in enumerate(repos, 1):
            visibility = "🔒 私有" if repo['private'] else "🌐 公开"
            print(f"{i}. {repo['full_name']} ({visibility})")
            if repo['description']:
                print(f"   描述: {repo['description']}")
        
    elif choice == '2':
        # 删除指定仓库
        repos = get_repos_to_delete()
        
        if not repos:
            print("\n错误：请在 get_repos_to_delete() 函数中填写要删除的仓库名")
            print("格式: '用户名/仓库名'")
            return
        
        print(f"\n准备删除以下 {len(repos)} 个仓库:")
        for repo in repos:
            print(f"  - {repo}")
        
        confirm = input(f"\n⚠️  警告：此操作不可恢复！\n输入 '{username}' 确认删除: ")
        
        if confirm != username:
            print("确认失败，取消操作")
            return
        
        print("\n开始删除...")
        success_count = 0
        for repo in repos:
            if delete_repo(token, repo):
                success_count += 1
        
        print(f"\n完成: 成功删除 {success_count}/{len(repos)} 个仓库")
        
    elif choice == '3':
        # 按关键词筛选
        keyword = input("\n请输入关键词筛选仓库名: ").strip()
        
        if not keyword:
            print("关键词不能为空")
            return
        
        print(f"\n正在查找包含 '{keyword}' 的仓库...")
        all_repos = list_repos(token)
        
        matching_repos = [
            repo for repo in all_repos 
            if keyword.lower() in repo['name'].lower()
        ]
        
        if not matching_repos:
            print(f"没有找到包含 '{keyword}' 的仓库")
            return
        
        print(f"\n找到 {len(matching_repos)} 个匹配的仓库:")
        for repo in matching_repos:
            visibility = "🔒 私有" if repo['private'] else "🌐 公开"
            print(f"  - {repo['full_name']} ({visibility})")
        
        confirm = input(f"\n⚠️  警告：即将删除这些仓库！\n输入 'DELETE' 确认: ")
        
        if confirm != 'DELETE':
            print("确认失败，取消操作")
            return
        
        print("\n开始删除...")
        success_count = 0
        for repo in matching_repos:
            if delete_repo(token, repo['full_name']):
                success_count += 1
        
        print(f"\n完成: 成功删除 {success_count}/{len(matching_repos)} 个仓库")
    
    else:
        print("无效选项")

if __name__ == '__main__':
    main()
