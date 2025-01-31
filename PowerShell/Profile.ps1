
# クイックアクセス用のハッシュテーブル
$global:QuickAccess = @{}

# 設定を保存するファイル
$QuickAccessFile = "$env:USERPROFILE\quickaccess.json"

# 設定を読み込む
function Load-QuickAccess {
    if (Test-Path $QuickAccessFile) {
        try {
            $jsonData = Get-Content -Raw $QuickAccessFile | ConvertFrom-Json
            if ($jsonData -is [PSCustomObject]) {
                $global:QuickAccess = @{}
                $jsonData.PSObject.Properties | ForEach-Object {
                    $global:QuickAccess[$_.Name] = $_.Value
                }
            }
        }
        catch {
            Write-Host "エラー: 設定の読み込みに失敗しました。" -ForegroundColor Red
        }
    }
}

# 設定を保存する
function Save-QuickAccess {
    try {
        $global:QuickAccess | ConvertTo-Json -Depth 10 | Set-Content -Path $QuickAccessFile -Encoding UTF8
    }
    catch {
        Write-Host "エラー: 設定の保存に失敗しました。" -ForegroundColor Red
    }
}

# クイックアクセスに登録
function add-go {
    param (
        [string]$key,
        [string]$path
    )

    if (-not (Test-Path $path)) {
        Write-Host "指定されたパス '$path' は存在しません。" -ForegroundColor Red
        return
    }

    $global:QuickAccess[$key] = $path
    Save-QuickAccess
    Write-Host "登録完了: '$key' -> '$path'" -ForegroundColor Green
}

# クイックアクセスで移動
function go {
    param (
        [string]$key
    )

    if ($key) {
        # 引数が指定されている場合、そのパスに移動
        if ($global:QuickAccess.ContainsKey($key)) {
            Set-Location -Path $global:QuickAccess[$key]
        }
        else {
            Write-Host "エイリアス '$key' は登録されていません。" -ForegroundColor Red
        }
    }
    else {
        # 引数が指定されていない場合、登録済みのキーとパスを表示し、選択
        $choices = $global:QuickAccess.GetEnumerator() | Select-Object Key, Value
        $selection = Show-SelectionMenu -choices $choices
        
        if ($selection) {
            Set-Location -Path $selection.Value
        }
        else {
            Write-Host "選択がキャンセルされました。" -ForegroundColor Yellow
        }
    }
}

# 登録済みリスト表示
function list-go {
    if ($global:QuickAccess.Count -eq 0) {
        Write-Host "登録されているエイリアスはありません。" -ForegroundColor Yellow
    }
    else {
        $global:QuickAccess.GetEnumerator() | ForEach-Object {
            Write-Host "$($_.Key) -> $($_.Value)"
        }
    }
}

# ユーザーに選択肢を表示して選ばせる（上下矢印で選択）
function Show-SelectionMenu {
    param (
        [array]$choices
    )
    
    $selectionIndex = 0
    $choicesCount = $choices.Count
    $cursorTop = [Console]::CursorTop # 現在のカーソル位置

    # 初期表示（選択肢の表示）
    Show-Choices -choices $choices -selectionIndex $selectionIndex

    while ($true) {
        # ユーザー入力の受け取り
        $key = [System.Console]::ReadKey($true).Key
        
        if ($key -eq 'UpArrow') {
            # 上矢印
            $selectionIndex = ($selectionIndex - 1 + $choicesCount) % $choicesCount
            Update-ChoicesDisplay -choices $choices -selectionIndex $selectionIndex -cursorTop $cursorTop
        }
        elseif ($key -eq 'DownArrow') {
            # 下矢印
            $selectionIndex = ($selectionIndex + 1) % $choicesCount
            Update-ChoicesDisplay -choices $choices -selectionIndex $selectionIndex -cursorTop $cursorTop
        }
        elseif ($key -eq 'Enter') {
            # Enterで選択確定
            return $choices[$selectionIndex]
        }
        elseif ($key -eq 'Escape') {
            # Escapeでキャンセル
            return $null
        }
    }
}

# 選択肢を表示する
function Show-Choices {
    param (
        [array]$choices,
        [int]$selectionIndex
    )
    
    # 新しい選択肢の表示
    $choices | ForEach-Object -Begin { $i = 0 } {
        $prefix = if ($i -eq $selectionIndex) { ">>" } else { "  " }
        Write-Host "$prefix $($_.Key) -> $($_.Value)"
        $i++
    }
}

# 選択肢を更新する
function Update-ChoicesDisplay {
    param (
        [array]$choices,
        [int]$selectionIndex,
        [int]$cursorTop
    )
    
    # カーソルを移動
    [Console]::SetCursorPosition(0, $cursorTop)
    
    # 画面の消去（選択肢の行だけ消去）
    $numChoices = $choices.Count
    for ($i = 0; $i -lt $numChoices; $i++) {
        Write-Host "`r$([string]::new(' ', [Console]::WindowWidth))"
    }

    # 新しい選択肢の表示
    Show-Choices -choices $choices -selectionIndex $selectionIndex
}

# 初回実行時に設定を読み込む
Load-QuickAccess