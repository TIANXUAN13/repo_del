# GitHub 仓库批量删除工具 - Windows PowerShell 版本
# 
# 使用方法:
# 1. 设置环境变量: $env:GITHUB_TOKEN = "your_token_here"
# 2. 运行: .\delete_repos_windows.ps1
#
# 注意: 如果提示执行策略错误，先运行:
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
#

param()

# 设置颜色
$ColorSuccess = "Green"
$ColorError = "Red"
$ColorWarning = "Yellow"
$ColorInfo = "Cyan"
$ColorNormal = "White"

# 全局变量
$script:GitHubToken = $null
$script:Username = $null
$script:Repos = @()

function Write-ColorText {
    param(
        [string]$Text,
        [string]$Color = "White"
    )
    Write-Host $Text -ForegroundColor $Color
}

function Show-Header {
    Clear-Host
    Write-Host ""
    Write-ColorText "╔══════════════════════════════════════════════════════════════════╗" $ColorInfo
    Write-ColorText "║     GitHub 仓库批量删除工具 (Windows PowerShell 版本)            ║" $ColorInfo
    Write-ColorText "╚══════════════════════════════════════════════════════════════════╝" $ColorInfo
    Write-Host ""
}

function Get-GitHubToken {
    $token = $env:GITHUB_TOKEN
    
    if (-not $token) {
        Write-ColorText "错误：未设置 GITHUB_TOKEN 环境变量" $ColorError
        Write-Host ""
        Write-Host "请设置环境变量: " -NoNewline
        Write-ColorText '$env:GITHUB_TOKEN = "your_token_here"' $ColorWarning
        Write-Host ""
        Write-Host "或在系统环境变量中永久设置:"
        Write-Host "  1. 右键'此电脑' → 属性 → 高级系统设置"
        Write-Host "  2. 环境变量 → 新建用户变量"
        Write-Host "  3. 变量名: GITHUB_TOKEN"
        Write-Host "  4. 变量值: 你的 GitHub Token"
        Write-Host ""
        Read-Host "按回车键退出"
        exit 1
    }
    
    return $token
}

function Test-GitHubToken {
    param([string]$Token)
    
    $headers = @{
        "Authorization" = "token $Token"
        "Accept" = "application/vnd.github.v3+json"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/user" -Headers $headers -Method Get
        $script:Username = $response.login
        Write-ColorText "✓ 已连接到用户: $($script:Username)" $ColorSuccess
        return $true
    }
    catch {
        Write-ColorText "✗ 验证 Token 失败: $_" $ColorError
        Read-Host "按回车键退出"
        exit 1
    }
}

function Get-AllRepos {
    $headers = @{
        "Authorization" = "token $script:GitHubToken"
        "Accept" = "application/vnd.github.v3+json"
    }
    
    $allRepos = @()
    $page = 1
    
    Write-ColorText "正在获取仓库列表..." $ColorWarning
    
    while ($true) {
        try {
            $url = "https://api.github.com/user/repos?per_page=100&page=$page&type=owner&sort=updated"
            $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
            
            if ($response.Count -eq 0) {
                break
            }
            
            $allRepos += $response
            Write-Host "  已获取 $($allRepos.Count) 个仓库..." -NoNewline
            Write-Host ""
            
            $page++
        }
        catch {
            Write-ColorText "获取仓库列表失败: $_" $ColorError
            break
        }
    }
    
    $script:Repos = $allRepos
    Write-ColorText "✓ 找到 $($allRepos.Count) 个仓库" $ColorSuccess
}

function Show-Repos {
    if ($script:Repos.Count -eq 0) {
        Write-ColorText "没有找到任何仓库" $ColorWarning
        return
    }
    
    Write-Host ""
    Write-ColorText "═══════════════════════════════════════════════════════════════════" $ColorInfo
    Write-ColorText "仓库列表 ($($script:Repos.Count) 个)" $ColorInfo
    Write-ColorText "═══════════════════════════════════════════════════════════════════" $ColorInfo
    Write-Host ""
    
    for ($i = 0; $i -lt $script:Repos.Count; $i++) {
        $repo = $script:Repos[$i]
        $num = $i + 1
        $vis = if ($repo.private) { "[私有]" } else { "[公开]" }
        $visColor = if ($repo.private) { $ColorError } else { $ColorSuccess }
        $updated = if ($repo.updated_at) { $repo.updated_at.Substring(0, 10) } else { "N/A" }
        
        Write-Host "$num. " -NoNewline -ForegroundColor $ColorInfo
        Write-Host "$($repo.full_name) " -NoNewline
        Write-Host $vis -ForegroundColor $visColor
        
        if ($repo.description) {
            $desc = $repo.description
            if ($desc.Length -gt 60) {
                $desc = $desc.Substring(0, 60) + "..."
            }
            Write-Host "   描述: $desc"
        }
        
        Write-Host "   更新: $updated | ⭐ $($repo.stargazers_count) | 🍴 $($repo.forks_count)"
        Write-Host ""
    }
}

function Parse-Selection {
    param(
        [string]$Input,
        [int]$TotalCount
    )
    
    $indices = @()
    
    # 处理 'all'
    if ($Input -eq "all") {
        for ($i = 0; $i -lt $TotalCount; $i++) {
            $indices += $i
        }
        return $indices
    }
    
    # 分割输入（逗号和空格）
    $parts = $Input -split '[,\s]+' | Where-Object { $_ -ne "" }
    
    foreach ($part in $parts) {
        $part = $part.Trim()
        
        if (-not $part) { continue }
        
        # 处理范围 (如: 1-10)
        if ($part -match "^(\d+)-(\d+)$") {
            $start = [int]$matches[1]
            $end = [int]$matches[2]
            
            if ($start -lt 1 -or $end -gt $TotalCount -or $start -gt $end) {
                Write-ColorText "错误：范围 $part 无效（有效范围：1-$TotalCount）" $ColorError
                continue
            }
            
            for ($i = $start - 1; $i -lt $end; $i++) {
                if ($i -notin $indices) {
                    $indices += $i
                }
            }
        }
        else {
            # 单个数字
            if ($part -match "^\d+$") {
                $num = [int]$part
                if ($num -lt 1 -or $num -gt $TotalCount) {
                    Write-ColorText "错误：编号 $num 超出范围（有效范围：1-$TotalCount）" $ColorError
                    continue
                }
                $idx = $num - 1
                if ($idx -notin $indices) {
                    $indices += $idx
                }
            }
            else {
                Write-ColorText "错误：无法解析 '$part'" $ColorError
            }
        }
    }
    
    return $indices | Sort-Object
}

function Select-Repos {
    if ($script:Repos.Count -eq 0) {
        Write-ColorText "没有仓库可供选择" $ColorWarning
        return $null
    }
    
    Write-Host ""
    Write-ColorText "═══════════════════════════════════════════════════════════════════" $ColorWarning
    Write-ColorText "选择要删除的仓库" $ColorWarning
    Write-ColorText "═══════════════════════════════════════════════════════════════════" $ColorWarning
    Write-Host ""
    Write-Host "输入方式："
    Write-Host "  - 单个数字: " -NoNewline
    Write-ColorText "5" $ColorSuccess
    Write-Host "  - 范围: " -NoNewline
    Write-ColorText "1-10" $ColorSuccess
    Write-Host "  - 多个（逗号或空格）: " -NoNewline
    Write-ColorText "1,3,5,7" $ColorSuccess -NoNewline
    Write-Host " 或 " -NoNewline
    Write-ColorText "1 3 5 7" $ColorSuccess
    Write-Host "  - 混合: " -NoNewline
    Write-ColorText "1-5,8,10-12" $ColorSuccess
    Write-Host "  - 全部: " -NoNewline
    Write-ColorText "all" $ColorSuccess
    Write-Host "  - 返回: " -NoNewline
    Write-ColorText "q" $ColorSuccess
    Write-Host ""
    
    while ($true) {
        $selection = Read-Host "请选择仓库编号"
        
        if ($selection -eq "q" -or $selection -eq "quit") {
            return $null
        }
        
        $indices = Parse-Selection -Input $selection -TotalCount $script:Repos.Count
        
        if ($indices.Count -eq 0) {
            Write-ColorText "未选择任何仓库，请重新输入" $ColorError
            continue
        }
        
        return $indices
    }
}

function Confirm-Deletion {
    param([array]$SelectedIndices)
    
    if (-not $SelectedIndices -or $SelectedIndices.Count -eq 0) {
        return $false
    }
    
    Write-Host ""
    Write-ColorText "═══════════════════════════════════════════════════════════════════" $ColorError
    Write-ColorText "⚠️  即将删除以下仓库（此操作不可恢复！）" $ColorError
    Write-ColorText "═══════════════════════════════════════════════════════════════════" $ColorError
    Write-Host ""
    
    $i = 1
    foreach ($idx in $SelectedIndices) {
        $repo = $script:Repos[$idx]
        $vis = if ($repo.private) { "[私有]" } else { "[公开]" }
        $visColor = if ($repo.private) { $ColorError } else { $ColorSuccess }
        
        Write-Host "$i. $($repo.full_name) " -NoNewline
        Write-Host $vis -ForegroundColor $visColor
        $i++
    }
    
    Write-Host ""
    Write-Host "总计: " -NoNewline
    Write-ColorText "$($SelectedIndices.Count)" $ColorInfo -NoNewline
    Write-Host " 个仓库"
    Write-Host ""
    
    # 双重确认
    Write-Host "请输入以下信息进行确认："
    Write-Host ""
    
    $confirm1 = Read-Host "1. 输入你的 GitHub 用户名 '$($script:Username)' 以确认"
    if ($confirm1 -ne $script:Username) {
        Write-Host ""
        Write-ColorText "❌ 用户名不匹配，取消操作" $ColorError
        return $false
    }
    
    Write-Host ""
    $confirm2 = Read-Host "2. 输入 'DELETE' 最终确认删除"
    if ($confirm2 -ne "DELETE") {
        Write-Host ""
        Write-ColorText "❌ 确认失败，取消操作" $ColorError
        return $false
    }
    
    return $true
}

function Delete-Repos {
    param([array]$SelectedIndices)
    
    Write-Host ""
    Write-ColorText "═══════════════════════════════════════════════════════════════════" $ColorWarning
    Write-ColorText "开始删除..." $ColorWarning
    Write-ColorText "═══════════════════════════════════════════════════════════════════" $ColorWarning
    Write-Host ""
    
    $headers = @{
        "Authorization" = "token $script:GitHubToken"
        "Accept" = "application/vnd.github.v3+json"
    }
    
    $success = 0
    $failed = 0
    
    foreach ($idx in $SelectedIndices) {
        $repo = $script:Repos[$idx]
        $fullname = $repo.full_name
        
        # 调试信息
        Write-Host "  正在删除: $fullname" -ForegroundColor DarkGray
        
        try {
            # 注意：GitHub API URL 直接使用 full_name，不需要额外的 URL 编码
            # 因为 Invoke-RestMethod 会自动处理
            $url = "https://api.github.com/repos/$fullname"
            
            Invoke-RestMethod -Uri $url -Headers $headers -Method Delete
            Write-ColorText "✓ 已删除: $fullname" $ColorSuccess
            $success++
        }
        catch {
            $errorMessage = $_.Exception.Message
            $statusCode = $_.Exception.Response.StatusCode.value__
            
            if ($statusCode -eq 404) {
                Write-ColorText "✗ 删除失败: $fullname - 仓库不存在或已被删除" $ColorError
            } elseif ($statusCode -eq 403) {
                Write-ColorText "✗ 删除失败: $fullname - 权限不足（请检查 Token 是否有 delete_repo 权限）" $ColorError
            } else {
                Write-ColorText "✗ 删除失败: $fullname - $errorMessage" $ColorError
            }
            $failed++
        }
    }
    
    Write-Host ""
    Write-Host "完成: " -NoNewline
    Write-ColorText "✓ $success" $ColorSuccess -NoNewline
    Write-Host " 成功, " -NoNewline
    Write-ColorText "✗ $failed" $ColorError -NoNewline
    Write-Host " 失败"
}

function Filter-Repos {
    param([string]$Keyword)
    
    $filtered = @()
    
    for ($i = 0; $i -lt $script:Repos.Count; $i++) {
        $repo = $script:Repos[$i]
        if ($repo.name -like "*$Keyword*" -or 
            ($repo.description -and $repo.description -like "*$Keyword*")) {
            $filtered += $i
        }
    }
    
    if ($filtered.Count -eq 0) {
        Write-ColorText "没有找到包含 '$Keyword' 的仓库" $ColorWarning
        return $null
    }
    
    Write-Host ""
    Write-ColorText "═══════════════════════════════════════════════════════════════════" $ColorInfo
    Write-ColorText "找到 $($filtered.Count) 个匹配的仓库" $ColorInfo
    Write-ColorText "═══════════════════════════════════════════════════════════════════" $ColorInfo
    Write-Host ""
    
    foreach ($idx in $filtered) {
        $repo = $script:Repos[$idx]
        $num = $idx + 1
        $vis = if ($repo.private) { "[私有]" } else { "[公开]" }
        $visColor = if ($repo.private) { $ColorError } else { $ColorSuccess }
        $desc = if ($repo.description) { 
            if ($repo.description.Length -gt 50) { 
                $repo.description.Substring(0, 50) + "..."
            } else { 
                $repo.description 
            }
        } else { 
            "无描述" 
        }
        
        Write-Host "$num. $($repo.full_name) " -NoNewline
        Write-Host $vis -ForegroundColor $visColor
        Write-Host "   $desc"
        Write-Host ""
    }
    
    return $filtered
}

function Show-MainMenu {
    while ($true) {
        Show-Header
        Write-Host "当前用户: " -NoNewline
        Write-ColorText $script:Username $ColorSuccess -NoNewline
        Write-Host " | 仓库数: " -NoNewline
        Write-ColorText $script:Repos.Count $ColorInfo
        Write-Host ""
        Write-Host "  1. 查看所有仓库"
        Write-Host "  2. 按关键词筛选仓库"
        Write-Host "  3. 选择并删除仓库"
        Write-Host "  4. 刷新仓库列表"
        Write-Host "  5. 退出"
        Write-Host ""
        
        $choice = Read-Host "请选择操作 (1-5)"
        
        switch ($choice) {
            "1" {
                Show-Header
                Show-Repos
                Write-Host ""
                Read-Host "按回车键返回菜单"
            }
            
            "2" {
                Show-Header
                $keyword = Read-Host "请输入关键词"
                if ($keyword) {
                    $filtered = Filter-Repos -Keyword $keyword
                    if ($filtered) {
                        $useFiltered = Read-Host "是否使用筛选结果进行删除? (y/N)"
                        if ($useFiltered -eq "y" -or $useFiltered -eq "Y") {
                            $selectedIndices = Select-ReposFromFiltered -FilteredIndices $filtered
                            if ($selectedIndices) {
                                $selectedRepos = @()
                                foreach ($idx in $selectedIndices) {
                                    $selectedRepos += $filtered[$idx]
                                }
                                
                                if (Confirm-Deletion -SelectedIndices $selectedRepos) {
                                    Delete-Repos -SelectedIndices $selectedRepos
                                    Read-Host "按回车键刷新仓库列表"
                                    Get-AllRepos
                                }
                            }
                        }
                    }
                    Read-Host "按回车键返回菜单"
                }
            }
            
            "3" {
                Show-Header
                Show-Repos
                
                $selectedIndices = Select-Repos
                if ($selectedIndices) {
                    Write-Host ""
                    Write-ColorText "已选择的仓库：" $ColorWarning
                    foreach ($idx in $selectedIndices) {
                        Write-Host "  - $($script:Repos[$idx].full_name)"
                    }
                    
                    Write-Host ""
                    $confirm = Read-Host "确认删除这些仓库? (y/N)"
                    
                    if ($confirm -eq "y" -or $confirm -eq "Y") {
                        if (Confirm-Deletion -SelectedIndices $selectedIndices) {
                            Delete-Repos -SelectedIndices $selectedIndices
                            Read-Host "按回车键刷新仓库列表"
                            Get-AllRepos
                        }
                    }
                }
            }
            
            "4" {
                Show-Header
                Get-AllRepos
                Read-Host "按回车键返回菜单"
            }
            
            "5" {
                Show-Header
                Write-ColorText "再见！" $ColorSuccess
                exit 0
            }
            
            default {
                Write-ColorText "无效选项" $ColorError
                Start-Sleep -Seconds 1
            }
        }
    }
}

function Select-ReposFromFiltered {
    param([array]$FilteredIndices)
    
    Write-Host ""
    Write-ColorText "═══════════════════════════════════════════════════════════════════" $ColorWarning
    Write-ColorText "选择要删除的仓库" $ColorWarning
    Write-ColorText "═══════════════════════════════════════════════════════════════════" $ColorWarning
    Write-Host ""
    Write-Host "输入方式："
    Write-Host "  - 单个数字: " -NoNewline
    Write-ColorText "5" $ColorSuccess
    Write-Host "  - 范围: " -NoNewline
    Write-ColorText "1-10" $ColorSuccess
    Write-Host "  - 多个（逗号或空格）: " -NoNewline
    Write-ColorText "1,3,5,7" $ColorSuccess
    Write-Host "  - 全部: " -NoNewline
    Write-ColorText "all" $ColorSuccess
    Write-Host "  - 返回: " -NoNewline
    Write-ColorText "q" $ColorSuccess
    Write-Host ""
    
    while ($true) {
        $selection = Read-Host "请选择仓库编号"
        
        if ($selection -eq "q" -or $selection -eq "quit") {
            return $null
        }
        
        if ($selection -eq "all") {
            $result = @()
            for ($i = 0; $i -lt $FilteredIndices.Count; $i++) {
                $result += $i
            }
            return $result
        }
        
        $indices = @()
        $parts = $selection -split '[,\s]+' | Where-Object { $_ -ne "" }
        
        foreach ($part in $parts) {
            $part = $part.Trim()
            if (-not $part) { continue }
            
            if ($part -match "^(\d+)-(\d+)$") {
                $start = [int]$matches[1]
                $end = [int]$matches[2]
                
                if ($start -lt 1 -or $end -gt $FilteredIndices.Count -or $start -gt $end) {
                    Write-ColorText "错误：范围 $part 无效" $ColorError
                    continue
                }
                
                for ($i = $start - 1; $i -lt $end; $i++) {
                    if ($i -notin $indices) {
                        $indices += $i
                    }
                }
            }
            elseif ($part -match "^\d+$") {
                $num = [int]$part
                if ($num -lt 1 -or $num -gt $FilteredIndices.Count) {
                    Write-ColorText "错误：编号 $num 超出范围" $ColorError
                    continue
                }
                $idx = $num - 1
                if ($idx -notin $indices) {
                    $indices += $idx
                }
            }
        }
        
        if ($indices.Count -eq 0) {
            Write-ColorText "未选择任何仓库，请重新输入" $ColorError
            continue
        }
        
        return $indices | Sort-Object
    }
}

# 主程序
Show-Header
$script:GitHubToken = Get-GitHubToken

if (Test-GitHubToken -Token $script:GitHubToken) {
    Get-AllRepos
    Show-MainMenu
}
