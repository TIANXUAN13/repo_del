@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

:: GitHub 仓库批量删除工具 - Windows CMD/Batch 版本
:: 使用方法: 直接双击运行或在 CMD 中运行 delete_repos_windows.bat
:: 前提: 必须安装 gh CLI 并登录

title GitHub 仓库批量删除工具

echo ╔══════════════════════════════════════════════════════════════════╗
echo ║     GitHub 仓库批量删除工具 (Windows CMD 版本)                   ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.

:: 检查 gh CLI
call :CheckGhCli
if errorlevel 1 exit /b 1

:: 获取用户名
call :GetUsername
if errorlevel 1 exit /b 1

:: 主菜单
call :MainMenu

exit /b 0

:: =====================================================
:: 检查 gh CLI
:: =====================================================
:CheckGhCli
echo [检查] 正在检查 gh CLI 是否安装...

gh --version >nul 2>&1
if errorlevel 1 (
    echo [错误] 未找到 gh CLI，请先安装
    echo.
    echo 下载地址: https://cli.github.com/
    echo.
    echo 或使用 winget 安装:
    echo   winget install --id GitHub.cli
    echo.
    pause
    exit /b 1
)

echo [成功] gh CLI 已安装

:: 检查登录状态
gh auth status >nul 2>&1
if errorlevel 1 (
    echo [错误] 请先登录 gh CLI
    echo.
    echo 运行: gh auth login
    echo.
    pause
    exit /b 1
)

echo [成功] 已登录 gh CLI
echo.
exit /b 0

:: =====================================================
:: 获取用户名
:: =====================================================
:GetUsername
for /f "tokens=*" %%a in ('gh api user -q .login') do (
    set "USERNAME=%%a"
)

if "!USERNAME!"=="" (
    echo [错误] 无法获取用户名
    pause
    exit /b 1
)

echo [信息] 当前用户: !USERNAME!
echo.
exit /b 0

:: =====================================================
:: 主菜单
:: =====================================================
:MainMenu
cls
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║     GitHub 仓库批量删除工具 (Windows CMD 版本)                   ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo 当前用户: %USERNAME%
echo.
echo  [1] 列出所有仓库
echo  [2] 按关键词筛选仓库
echo  [3] 选择并删除仓库
echo  [4] 退出
echo.
set /p choice="请选择操作 (1-4): "

if "%choice%"=="1" call :ListRepos
if "%choice%"=="2" call :FilterRepos
if "%choice%"=="3" call :SelectAndDelete
if "%choice%"=="4" exit /b 0

echo [错误] 无效选项
timeout /t 2 >nul
goto :MainMenu

:: =====================================================
:: 列出所有仓库
:: =====================================================
:ListRepos
cls
echo [获取] 正在获取仓库列表...
echo.

set COUNT=0
for /f "tokens=*" %%a in ('gh repo list %USERNAME% --limit 100 --json name,visibility,description,updatedAt -q ".[] | \"\(.name)|\(.visibility)|\(.description // \"\"无描述\"\")|\(.updatedAt[:10])\""') do (
    set /a COUNT+=1
    for /f "tokens=1,2,3,4 delims=|" %%b in ("%%a") do (
        set "REPO_NAME_!COUNT!=%%b"
        set "REPO_VIS_!COUNT!=%%c"
        set "REPO_DESC_!COUNT!=%%d"
        set "REPO_DATE_!COUNT!=%%e"
    )
)

echo ═══════════════════════════════════════════════════════════════════
echo 仓库列表 (%COUNT% 个)
echo ═══════════════════════════════════════════════════════════════════
echo.

for /l %%i in (1,1,%COUNT%) do (
    set VIS=!REPO_VIS_%%i!
    if "!VIS!"=="PRIVATE" (
        echo %%i. !REPO_NAME_%%i! [私有]
    ) else (
        echo %%i. !REPO_NAME_%%i! [公开]
    )
    echo    !REPO_DESC_%%i!
    echo    更新: !REPO_DATE_%%i!
    echo.
)

echo.
pause
goto :MainMenu

:: =====================================================
:: 按关键词筛选
:: =====================================================
:FilterRepos
cls
set /p keyword="请输入关键词: "

if "!keyword!"=="" (
    echo [错误] 关键词不能为空
    timeout /t 2 >nul
    goto :MainMenu
)

echo.
echo [搜索] 正在查找包含 "!keyword!" 的仓库...
echo.

set FILTER_COUNT=0
for /l %%i in (1,1,%COUNT%) do (
    set "NAME=!REPO_NAME_%%i!"
    set "DESC=!REPO_DESC_%%i!"
    
    echo !NAME! | findstr /i "!keyword!" >nul && (
        set /a FILTER_COUNT+=1
        set "FILTER_INDEX_!FILTER_COUNT!=%%i"
    ) || (
        echo !DESC! | findstr /i "!keyword!" >nul && (
            set /a FILTER_COUNT+=1
            set "FILTER_INDEX_!FILTER_COUNT!=%%i"
        )
    )
)

if %FILTER_COUNT%==0 (
    echo [提示] 没有找到匹配的仓库
    pause
    goto :MainMenu
)

echo ═══════════════════════════════════════════════════════════════════
echo 找到 %FILTER_COUNT% 个匹配的仓库
echo ═══════════════════════════════════════════════════════════════════
echo.

for /l %%i in (1,1,%FILTER_COUNT%) do (
    set IDX=!FILTER_INDEX_%%i!
    set VIS=!REPO_VIS_%IDX%!
    if "!VIS!"=="PRIVATE" (
        echo %%i. !REPO_NAME_%IDX%! [私有]
    ) else (
        echo %%i. !REPO_NAME_%IDX%! [公开]
    )
    echo    !REPO_DESC_%IDX%!
    echo.
)

echo.
set /p usefilter="是否删除这些仓库? (y/N): "
if /i not "!usefilter!"=="y" goto :MainMenu

call :ConfirmAndDeleteFiltered
goto :MainMenu

:: =====================================================
:: 选择并删除仓库
:: =====================================================
:SelectAndDelete
call :ListRepos

echo.
echo 选择方式:
echo   - 输入单个数字: 5
echo   - 输入多个(逗号分隔): 1,3,5,7
echo   - 输入范围: 1-10
echo   - 输入 all 选择全部
echo   - 输入 q 返回
echo.
set /p selection="请选择要删除的仓库: "

if "!selection!"=="q" goto :MainMenu
if "!selection!"=="Q" goto :MainMenu

call :ParseSelection
if errorlevel 1 (
    echo [错误] 选择无效
    pause
    goto :MainMenu
)

echo.
echo 已选择的仓库:
for /l %%i in (1,1,%SELECT_COUNT%) do (
    set IDX=!SELECT_%%i!
    echo   - !REPO_NAME_%IDX%!
)

echo.
set /p confirm="确认删除? (y/N): "
if /i not "!confirm!"=="y" goto :MainMenu

call :ConfirmAndDelete
goto :MainMenu

:: =====================================================
:: 解析选择
:: =====================================================
:ParseSelection
set SELECT_COUNT=0

:: 处理 all
if /i "!selection!"=="all" (
    for /l %%i in (1,1,%COUNT%) do (
        set /a SELECT_COUNT+=1
        set "SELECT_!SELECT_COUNT!=%%i"
    )
    exit /b 0
)

:: 解析逗号分隔
set TEMP=!selection:,= !
for %%a in (!TEMP!) do (
    set PART=%%a
    
    :: 检查是否为范围
    echo !PART! | findstr "-" >nul && (
        for /f "tokens=1,2 delims=-" %%b in ("!PART!") do (
            set START=%%b
            set END=%%c
            
            :: 验证范围
            if !START! LSS 1 goto :ParseError
            if !END! GTR %COUNT% goto :ParseError
            if !START! GTR !END! goto :ParseError
            
            for /l %%x in (!START!,1,!END!) do (
                set /a SELECT_COUNT+=1
                set "SELECT_!SELECT_COUNT!=%%x"
            )
        )
    ) || (
        :: 单个数字
        set NUM=!PART!
        if !NUM! LSS 1 goto :ParseError
        if !NUM! GTR %COUNT% goto :ParseError
        set /a SELECT_COUNT+=1
        set "SELECT_!SELECT_COUNT!=!NUM!"
    )
)

if %SELECT_COUNT%==0 goto :ParseError
exit /b 0

:ParseError
exit /b 1

:: =====================================================
:: 确认并删除
:: =====================================================
:ConfirmAndDelete
cls
echo ═══════════════════════════════════════════════════════════════════
echo ⚠️  即将删除以下仓库（此操作不可恢复！）
echo ═══════════════════════════════════════════════════════════════════
echo.

for /l %%i in (1,1,%SELECT_COUNT%) do (
    set IDX=!SELECT_%%i!
    set VIS=!REPO_VIS_%IDX%!
    if "!VIS!"=="PRIVATE" (
        echo %%i. !REPO_NAME_%IDX%! [私有]
    ) else (
        echo %%i. !REPO_NAME_%IDX%! [公开]
    )
)

echo.
echo 总计: %SELECT_COUNT% 个仓库
echo.

echo 请输入以下信息进行确认:
echo.
set /p confirm1="1. 输入你的 GitHub 用户名 '%USERNAME%' 以确认: "
if not "!confirm1!"=="%USERNAME%" (
    echo.
    echo ❌ 用户名不匹配，取消操作
    pause
    exit /b 1
)

echo.
set /p confirm2="2. 输入 'DELETE' 最终确认删除: "
if not "!confirm2!"=="DELETE" (
    echo.
    echo ❌ 确认失败，取消操作
    pause
    exit /b 1
)

echo.
echo ═══════════════════════════════════════════════════════════════════
echo 开始删除...
echo ═══════════════════════════════════════════════════════════════════
echo.

set SUCCESS=0
set FAILED=0

for /l %%i in (1,1,%SELECT_COUNT%) do (
    set IDX=!SELECT_%%i!
    set REPO=!REPO_NAME_%IDX%!
    
    echo [删除] %USERNAME%/!REPO! ...
    gh repo delete "%USERNAME%/!REPO!" --yes >nul 2>&1
    
    if errorlevel 1 (
        echo   ✗ 删除失败: !REPO!
        set /a FAILED+=1
    ) else (
        echo   ✓ 已删除: !REPO!
        set /a SUCCESS+=1
    )
)

echo.
echo 完成: ✓ %SUCCESS% 成功, ✗ %FAILED% 失败
echo.
pause
exit /b 0

:: =====================================================
:: 确认并删除筛选结果
:: =====================================================
:ConfirmAndDeleteFiltered
cls
echo ═══════════════════════════════════════════════════════════════════
echo ⚠️  即将删除以下仓库（此操作不可恢复！）
echo ═══════════════════════════════════════════════════════════════════
echo.

for /l %%i in (1,1,%FILTER_COUNT%) do (
    set IDX=!FILTER_INDEX_%%i!
    set VIS=!REPO_VIS_%IDX%!
    if "!VIS!"=="PRIVATE" (
        echo %%i. !REPO_NAME_%IDX%! [私有]
    ) else (
        echo %%i. !REPO_NAME_%IDX%! [公开]
    )
)

echo.
echo 总计: %FILTER_COUNT% 个仓库
echo.

echo 请输入以下信息进行确认:
echo.
set /p confirm1="1. 输入你的 GitHub 用户名 '%USERNAME%' 以确认: "
if not "!confirm1!"=="%USERNAME%" (
    echo.
    echo ❌ 用户名不匹配，取消操作
    pause
    exit /b 1
)

echo.
set /p confirm2="2. 输入 'DELETE' 最终确认删除: "
if not "!confirm2!"=="DELETE" (
    echo.
    echo ❌ 确认失败，取消操作
    pause
    exit /b 1
)

echo.
echo ═══════════════════════════════════════════════════════════════════
echo 开始删除...
echo ═══════════════════════════════════════════════════════════════════
echo.

set SUCCESS=0
set FAILED=0

for /l %%i in (1,1,%FILTER_COUNT%) do (
    set IDX=!FILTER_INDEX_%%i!
    set REPO=!REPO_NAME_%IDX%!
    
    echo [删除] %USERNAME%/!REPO! ...
    gh repo delete "%USERNAME%/!REPO!" --yes >nul 2>&1
    
    if errorlevel 1 (
        echo   ✗ 删除失败: !REPO!
        set /a FAILED+=1
    ) else (
        echo   ✓ 已删除: !REPO!
        set /a SUCCESS+=1
    )
)

echo.
echo 完成: ✓ %SUCCESS% 成功, ✗ %FAILED% 失败
echo.
pause
exit /b 0
