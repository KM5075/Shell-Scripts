# クイックアクセス用のハッシュテーブル
$global:QuickAccess = @{}

# 設定を保存するファイル
$QuickAccessFile = "$env:USERPROFILE\quickaccess.json"

# 設定を読み込む
function go-Load-QuickAccess {
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
function go-add {

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

# クイックアクセスから削除
function go-remove {
    param (
        [string]$key
    )

    if ($global:QuickAccess.ContainsKey($key)) {
        $global:QuickAccess.Remove($key)
        $global:QuickAccess | ConvertTo-Json -Depth 10 | Set-Content $QuickAccessFile
        Write-Host "削除完了: '$key'" -ForegroundColor Yellow
    }
    else {
        Write-Host "エイリアス '$key' は登録されていません。" -ForegroundColor Red
    }
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
function go-list {
    if ($global:QuickAccess.Count -eq 0) {
        Write-Host "登録されているエイリアスはありません。" -ForegroundColor Yellow
    }
    else {
        $global:QuickAccess.GetEnumerator() | ForEach-Object {
            Write-Host "$($_.Key) -> $($_.Value)"
        }
    }
}

# ユーザーに選択肢を表示して選ばせる（上下矢印 & Vim風の "j" / "k" に対応）
function Show-SelectionMenu {
    param (
        [array]$choices
    )
    
    $selectionIndex = 0
    $choicesCount = $choices.Count
    $cursorTop = [Console]::CursorTop # 現在のカーソル位置

    # 初期表示
    Show-Choices -choices $choices -selectionIndex $selectionIndex

    while ($true) {
        # ユーザー入力の受け取り
        $key = [System.Console]::ReadKey($true)

        if ($key.Key -eq 'UpArrow' -or $key.KeyChar -eq 'k') {
            # 上移動 (↑キー または "k")
            $selectionIndex = ($selectionIndex - 1 + $choicesCount) % $choicesCount
            Update-ChoicesDisplay -choices $choices -selectionIndex $selectionIndex -cursorTop $cursorTop
        }
        elseif ($key.Key -eq 'DownArrow' -or $key.KeyChar -eq 'j') {
            # 下移動 (↓キー または "j")
            $selectionIndex = ($selectionIndex + 1) % $choicesCount
            Update-ChoicesDisplay -choices $choices -selectionIndex $selectionIndex -cursorTop $cursorTop
        }
        elseif ($key.Key -eq 'Enter') {
            # Enterで選択確定
            return $choices[$selectionIndex]
        }
        elseif ($key.Key -eq 'Escape') {
            # Escapeでキャンセル
            return $null
        }
    }
}


# 選択肢を表示する（現在の選択位置を強調）
function Show-Choices {
    param (
        [array]$choices,
        [int]$selectionIndex
    )

    $cursorTop = [Console]::CursorTop # 現在のカーソル位置を取得

    for ($i = 0; $i -lt $choices.Count; $i++) {
        if ($i -eq $selectionIndex) {
            Write-Host ("  " + ">>" + " " + $choices[$i]) -ForegroundColor Red
        }
        else {
            Write-Host ("     " + $choices[$i]) -ForegroundColor Blue
        }
    }

    return $cursorTop
}

# カーソルを適切な位置に戻し、リストを更新する
function Update-ChoicesDisplay {
    param (
        [array]$choices,
        [int]$selectionIndex,
        [int]$cursorTop
    )

    [Console]::SetCursorPosition(0, $cursorTop) # カーソル位置をリセット

    for ($i = 0; $i -lt $choices.Count; $i++) {
        if ($i -eq $selectionIndex) {
            Write-Host ("  " + ">>" + " " + $choices[$i]) -ForegroundColor Red
        }
        else {
            Write-Host ("     " + $choices[$i]) -ForegroundColor Blue
        }
    }
}

# 初回実行時に設定を読み込む
go-Load-QuickAccess