# GitHub 仓库批量删除工具 - 跨平台版本

提供了多种方式适应不同操作系统：

## 📋 快速选择指南

| 你的系统 | 推荐脚本 | 执行方式 |
|---------|---------|---------|
| **Windows** | `delete_repos_windows.ps1` | PowerShell（推荐） |
| **Windows** | `delete_repos_windows.bat` | CMD/批处理 |
| **Windows** | `delete_repos_interactive.py` | Python（通用） |
| **macOS** | `delete_repos_interactive.sh` | Bash |
| **Linux** | `delete_repos_interactive.sh` | Bash |
| **所有系统** | `delete_repos_interactive.py` | Python |

---

## 🪟 Windows 用户指南

### 方式一：PowerShell 脚本（推荐）`delete_repos_windows.ps1`

**特点：**
- ✅ 原生 Windows 支持
- ✅ 彩色输出
- ✅ 完整的交互式菜单
- ✅ 支持所有功能

**使用方法：**

```powershell
# 1. 设置执行策略（首次使用需要，之后不需要）
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 2. 设置 Token
$env:GITHUB_TOKEN = "your_token_here"

# 3. 运行脚本
.\delete_repos_windows.ps1
```

**或者使用 Python 方式：**
```powershell
# 安装 Python 依赖
pip install requests

# 设置 Token
$env:GITHUB_TOKEN = "your_token_here"

# 运行
python delete_repos_interactive.py
```

---

### 方式二：CMD/Batch 脚本 `delete_repos_windows.bat`

**特点：**
- ✅ 无需额外配置
- ✅ 在 CMD 或 PowerShell 中都能运行
- ⚠️ 功能较简单（基于 gh CLI）

**使用方法：**

```cmd
# 1. 确保已安装 gh CLI 并登录
gh auth login

# 2. 双击运行或在 CMD 中执行
delete_repos_windows.bat
```

---

### 方式三：Python 脚本（最通用）

**适用于所有 Windows 版本，功能最全**

```powershell
# 1. 安装 Python（如果未安装）
# 下载地址: https://www.python.org/downloads/

# 2. 安装依赖
pip install requests

# 3. 设置环境变量
$env:GITHUB_TOKEN = "your_token_here"

# 4. 运行
python delete_repos_interactive.py
```

---

## 🍎 macOS 用户指南

### 推荐：Bash 交互式脚本

```bash
# 1. 安装 gh CLI
brew install gh

# 2. 登录
git auth login

# 3. 赋予权限并运行
chmod +x delete_repos_interactive.sh
./delete_repos_interactive.sh
```

**或者使用 Python：**
```bash
export GITHUB_TOKEN='your_token'
pip install requests
python delete_repos_interactive.py
```

---

## 🐧 Linux 用户指南

### 推荐：Bash 交互式脚本

```bash
# Ubuntu/Debian
sudo apt install gh

# CentOS/RHEL/Fedora
sudo yum install gh
# 或
sudo dnf install gh

# 登录
git auth login

# 运行
chmod +x delete_repos_interactive.sh
./delete_repos_interactive.sh
```

**或者使用 Python：**
```bash
export GITHUB_TOKEN='your_token'
pip3 install requests
python3 delete_repos_interactive.py
```

---

## 🔧 各脚本详细说明

### 1. `delete_repos_windows.ps1` - Windows PowerShell 版本

**依赖：**
- PowerShell 5.1 或更高版本（Windows 10/11 自带）
- 无需 gh CLI
- 只需要 GitHub Token

**功能：**
- 自动获取所有仓库
- 可视化列表展示
- 支持范围选择（如：1-10,15,20-25）
- 关键词筛选
- 双重确认机制

---

### 2. `delete_repos_windows.bat` - Windows CMD 版本

**依赖：**
- gh CLI（必须安装）
- CMD 或 PowerShell

**功能：**
- 基于 gh CLI 的操作
- 列出仓库
- 选择删除
- 关键词筛选

---

### 3. `delete_repos_interactive.py` - 跨平台 Python 版本

**依赖：**
- Python 3.6+
- requests 库

**适用系统：**
- ✅ Windows
- ✅ macOS
- ✅ Linux

---

### 4. `delete_repos_interactive.sh` - Unix/Linux/macOS 版本

**依赖：**
- Bash
- gh CLI

**适用系统：**
- ✅ macOS
- ✅ Linux
- ❌ Windows（除非使用 WSL/Git Bash）

---

## 📦 文件清单

```
E:\learn\repo_del/
├── README.md                          # 本文档
├── delete_github_repos.py             # 基础 Python 版本
├── delete_github_repos.sh             # 基础 Bash 版本
├── delete_repos_interactive.py        # 交互式 Python（跨平台）⭐
├── delete_repos_interactive.sh        # 交互式 Bash（Unix/macOS）
├── delete_repos_windows.ps1           # Windows PowerShell ⭐
└── delete_repos_windows.bat           # Windows CMD/Batch
```

---

## 🚀 快速开始（Windows）

### 步骤 1：获取 GitHub Token

1. 访问 https://github.com/settings/tokens
2. 点击 "Generate new token (classic)"
3. 勾选 `delete_repo` 权限
4. 生成并复制 token

### 步骤 2：选择脚本

**如果你熟悉 PowerShell（推荐）：**
```powershell
# 右键点击 PowerShell 图标，选择"以管理员身份运行"
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
$env:GITHUB_TOKEN = "ghp_xxxxxxxxxxxx"
.\delete_repos_windows.ps1
```

**如果你想要最简单的方式：**
```powershell
# 安装 Python
pip install requests
$env:GITHUB_TOKEN = "ghp_xxxxxxxxxxxx"
python delete_repos_interactive.py
```

**如果你已安装 gh CLI：**
```cmd
# 双击运行 delete_repos_windows.bat
# 或在 CMD 中运行：
delete_repos_windows.bat
```

---

## 🚀 快速开始（macOS/Linux）

```bash
# 安装 gh CLI
brew install gh        # macOS
sudo apt install gh    # Ubuntu/Debian

# 登录
git auth login

# 运行
chmod +x delete_repos_interactive.sh
./delete_repos_interactive.sh
```

---

## ⚠️ 安全提示

1. **Token 安全：**
   - 不要将 Token 硬编码在脚本中
   - 使用环境变量传递
   - Windows 用户可以在"系统属性 → 环境变量"中设置

2. **删除前确认：**
   - 所有脚本都有双重确认机制
   - 需要输入用户名和 "DELETE"
   - 建议先列出仓库查看

3. **不可恢复：**
   - 删除是永久性的
   - 重要仓库请先备份

---

## 🔧 Windows 环境变量设置方法

### 方法一：临时设置（当前会话有效）
```powershell
$env:GITHUB_TOKEN = "your_token_here"
```

### 方法二：永久设置（推荐）

1. 右键"此电脑" → 属性 → 高级系统设置
2. 点击"环境变量"
3. 在"用户变量"中点击"新建"
4. 变量名：`GITHUB_TOKEN`
5. 变量值：你的 GitHub Token
6. 确定保存
7. 重启 PowerShell/CMD

### 方法三：PowerShell Profile（高级）
```powershell
# 编辑 PowerShell 配置文件
notepad $PROFILE

# 添加以下内容
$env:GITHUB_TOKEN = "your_token_here"
```

---

## ❓ 常见问题

### Q: Windows 提示"无法加载脚本，因为在此系统上禁止运行脚本"
**A:** 执行 `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

### Q: Python 提示"'pip' 不是内部或外部命令"
**A:** 安装 Python 时勾选 "Add Python to PATH"，或重新安装 Python

### Q: 如何查看 gh CLI 是否安装？
**A:** 运行 `gh --version`，如果显示版本号则已安装

### Q: Token 权限不足？
**A:** 确保 Token 勾选了 `delete_repo` 权限

---

## 📝 许可证

MIT License
