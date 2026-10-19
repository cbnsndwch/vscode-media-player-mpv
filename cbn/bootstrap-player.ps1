$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path -Parent $PSScriptRoot
$engineRoot = if (Test-Path (Join-Path $projectRoot 'meson.build')) { $projectRoot } else { Join-Path $projectRoot 'engine/mpv' }
$tools = Join-Path $projectRoot '.tools'
$downloads = Join-Path $tools 'downloads'
New-Item -ItemType Directory -Force -Path $downloads | Out-Null

function Download-Verified([string]$Url, [string]$Destination, [string]$Sha256) {
    if (-not (Test-Path -LiteralPath $Destination)) {
        & curl.exe --fail --location --retry 3 --silent --show-error --output $Destination $Url
        if ($LASTEXITCODE -ne 0) { throw 'Tool download failed' }
    }
    $actual = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $Sha256) { throw "Tool checksum mismatch: $Destination" }
}

# These are compiler/build tools only. No prebuilt media runtime is downloaded.
Download-Verified 'https://github.com/llvm/llvm-project/releases/download/llvmorg-23.1.3/clang%2Bllvm-23.1.3-x86_64-pc-windows-msvc.tar.zst' `
    (Join-Path $downloads 'llvm.tar.zst') '7e69dc07a4536b79ff24a651a2611990bf8eaab17ea560f1092707c4f31ba01d'
if (-not (Test-Path (Join-Path $tools 'llvm/bin/clang.exe'))) {
    # Windows tar's zstd decoder cannot handle this archive's 1 GiB window.
    & 7z.exe x (Join-Path $downloads 'llvm.tar.zst') "-o$downloads" -y -bsp0
    if ($LASTEXITCODE -ne 0) { throw 'LLVM decompression failed' }
    New-Item -ItemType Directory -Force -Path (Join-Path $tools 'llvm') | Out-Null
    & tar.exe -xf (Join-Path $downloads 'llvm.tar') --strip-components=1 -C (Join-Path $tools 'llvm')
    if ($LASTEXITCODE -ne 0) { throw 'LLVM extraction failed' }
}
Download-Verified 'https://www.nasm.us/pub/nasm/releasebuilds/3.02/win64/nasm-3.02-win64.zip' `
    (Join-Path $downloads 'nasm.zip') '161d0bfaff53c2f9e9f3e69fd0672323ebabafd1268976a5cec11be92a19aee7'
if (-not (Test-Path (Join-Path $tools 'nasm/nasm-3.02/nasm.exe'))) {
    Expand-Archive -LiteralPath (Join-Path $downloads 'nasm.zip') -DestinationPath (Join-Path $tools 'nasm') -Force
}
if (-not (Test-Path (Join-Path $tools 'venv/Scripts/python.exe'))) {
    & uv.exe venv (Join-Path $tools 'venv')
    if ($LASTEXITCODE -ne 0) { throw 'Build environment creation failed' }
}
& uv.exe pip sync --python (Join-Path $tools 'venv/Scripts/python.exe') (Join-Path $PSScriptRoot 'build-tools.lock.txt')
if ($LASTEXITCODE -ne 0) { throw 'Build tool installation failed' }
$env:PATH = (Join-Path $tools 'venv/Scripts') + ';' + $env:PATH
Push-Location $engineRoot
try {
    & (Join-Path $tools 'venv/Scripts/meson.exe') subprojects download
    if ($LASTEXITCODE -ne 0) { throw 'Pinned source download failed' }
    & git.exe -C subprojects/libplacebo submodule update --init --depth 1 `
        3rdparty/glad 3rdparty/jinja 3rdparty/markupsafe 3rdparty/fast_float 3rdparty/Vulkan-Headers
    if ($LASTEXITCODE -ne 0) { throw 'Pinned source submodule download failed' }
    & (Join-Path $PSScriptRoot 'prepare-shaders.ps1')
} finally { Pop-Location }
