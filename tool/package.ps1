Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    $dartCommand = $env:DART_BIN
    if ([string]::IsNullOrWhiteSpace($dartCommand)) {
        $dart = Get-Command dart -ErrorAction SilentlyContinue
        if ($null -ne $dart) {
            $dartCommand = $dart.Source
        } else {
            $isOhosTarget = ($args.Length -gt 0) -and ($args[0].ToLowerInvariant() -in @('ohos', 'harmony', 'setup-ohos'))
            if ($isOhosTarget) {
                $flutterCommand = $env:OHOS_FLUTTER_BIN
            } else {
                $flutterCommand = $env:FLUTTER_BIN
            }
            if ([string]::IsNullOrWhiteSpace($flutterCommand)) {
                $flutterCommand = if ([string]::IsNullOrWhiteSpace($env:FLUTTER_BIN)) { 'flutter' } else { $env:FLUTTER_BIN }
            }
            $flutter = Get-Command $flutterCommand -ErrorAction SilentlyContinue
            if ($null -eq $flutter) {
                throw '找不到 dart 或 flutter；请配置 DART_BIN / FLUTTER_BIN / OHOS_FLUTTER_BIN。'
            }
            $flutterRoot = Split-Path -Parent (Split-Path -Parent $flutter.Source)
            $dartCommand = Join-Path $flutterRoot 'bin/cache/dart-sdk/bin/dart.exe'
        }
    }

    & $dartCommand tool/package.dart @args
    $result = $LASTEXITCODE
} finally {
    Pop-Location
}

exit $result
