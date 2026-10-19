param([switch]$ConfigureOnly, [switch]$Reconfigure, [switch]$Test)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path -Parent $PSScriptRoot
$engineRoot = if (Test-Path (Join-Path $projectRoot 'meson.build')) { $projectRoot } else { Join-Path $projectRoot 'engine/mpv' }
$buildRoot = Join-Path $projectRoot 'build/player'
$toolsRoot = Join-Path $projectRoot '.tools'

function Invoke-Checked([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed with exit code $LASTEXITCODE" }
}

$devShell = 'C:/Program Files (x86)/Microsoft Visual Studio/2022/BuildTools/Common7/Tools/Launch-VsDevShell.ps1'
& $devShell -Arch amd64 -HostArch amd64 -SkipAutomaticLocation | Out-Null
$nasm = Get-ChildItem (Join-Path $toolsRoot 'nasm') -Filter nasm.exe -Recurse | Select-Object -First 1
if (-not $nasm) { throw 'NASM is missing' }
$env:PATH = @((Join-Path $toolsRoot 'llvm/bin'), (Join-Path $toolsRoot 'venv/Scripts'),
    $nasm.DirectoryName, 'C:/Program Files/Git/usr/bin', $env:PATH) -join ';'
$env:CC = 'clang'
$env:CXX = 'clang++'
$env:CC_LD = 'lld-link'
$env:CXX_LD = 'lld-link'
$env:WINDRES = 'llvm-rc'
$env:PKG_CONFIG = ''
$meson = Join-Path $toolsRoot 'venv/Scripts/meson.exe'

# Fail on floating source references. Meson verifies archive source/patch hashes.
foreach ($wrap in Get-ChildItem (Join-Path $engineRoot 'subprojects') -Filter '*.wrap') {
    $content = Get-Content -LiteralPath $wrap.FullName -Raw
    if ($content.Contains('[wrap-git]') -and $content -notmatch '(?m)^revision\s*=\s*[0-9a-f]{40}\s*$') {
        throw "Unpinned Git dependency: $($wrap.Name)"
    }
}

# auto_features is global in Meson, including FFmpeg's individual codec options.
# Disable mpv's optional integrations explicitly so codec auto-detection stays on.
$featureOptions = [regex]::Matches((Get-Content (Join-Path $engineRoot 'meson.options') -Raw),
    "option\('([^']+)',\s*type:\s*'feature'")
$disabledFeatures = @($featureOptions | ForEach-Object { "-D$($_.Groups[1].Value)=disabled" })
$forcedSources = 'libavcodec,libavfilter,libavformat,libavutil,libswresample,libswscale,libplacebo,libass,luajit,dav1d,freetype2,harfbuzz,fribidi,zlib,bzip2,libpng,iconv,dl,shaderc,spirv-cross-c-shared'
$options = @('--wrap-mode=default', "--force-fallback-for=$forcedSources", '--buildtype=release', '--auto-features=auto') + $disabledFeatures + @(
    '-Ddefault_library=static', '-Dprefer_static=false', '-Db_vscrt=mt',
    '-Db_ndebug=true', '-Dbuild-date=false', '-Dlibmpv=false', '-Dtests=true',
    '-Dc_link_args=-Wl,/DYNAMICBASE,/HIGHENTROPYVA,/NXCOMPAT,/guard:cf',
    '-Dcpp_link_args=-Wl,/DYNAMICBASE,/HIGHENTROPYVA,/NXCOMPAT,/guard:cf',
    '-Dc_args=-fstack-protector-strong -Xclang -cfguard',
    '-Dcpp_args=-fstack-protector-strong -Xclang -cfguard',
    '-Dlua=luajit', '-Djavascript=disabled', '-Dcplugins=disabled',
    '-Dvapoursynth=disabled', '-Dlibarchive=disabled', '-Dlibavdevice=disabled',
    '-Dsubrandr=disabled', '-Dvulkan=disabled', '-Dwin32-smtc=disabled',
    '-Dd3d11=enabled', '-Dshaderc=enabled', '-Dspirv-cross=enabled',
    '-Dgl=enabled', '-Dgl-win32=enabled', '-Dwasapi=enabled',
    '-Dd3d-hwaccel=enabled', '-Dd3d9-hwaccel=enabled', '-Dvector=enabled',
    '-Dwin32-threads=enabled',
    '-Dzlib=enabled', '-Diconv=enabled', '-Djpeg=disabled',
    '-Dffmpeg:gpl=enabled', '-Dffmpeg:version3=enabled', '-Dffmpeg:ffnvcodec=disabled',
    '-Dffmpeg:programs=enabled', '-Dffmpeg:tests=disabled',
    '-Dffmpeg:ffplay=disabled', '-Dffmpeg:sdl2=disabled', '-Dffmpeg:lzma=disabled',
    '-Dffmpeg:avdevice=disabled', '-Dffmpeg:libdav1d=enabled',
    '-Dffmpeg:zlib=enabled', '-Dffmpeg:bzlib=enabled',
    '-Dffmpeg:libjxl_threads=disabled', '-Dffmpeg:vulkan=disabled',
    '-Dlibplacebo:demos=false', '-Dlibplacebo:tests=false',
    '-Dlibplacebo:opengl=enabled', '-Dlibplacebo:gl-proc-addr=enabled',
    '-Dlibplacebo:d3d11=disabled', '-Dlibplacebo:vulkan=disabled',
    '-Dlibplacebo:shaderc=enabled', '-Dlibplacebo:glslang=disabled',
    '-Dlibplacebo:lcms=disabled', '-Dlibplacebo:libdovi=disabled',
    '-Dlibplacebo:xxhash=disabled', '-Dlibplacebo:unwind=disabled',
    '-Dlibass:directwrite=enabled', '-Dlibass:asm=enabled',
    '-Dlibass:fontconfig=disabled', '-Dlibass:libunibreak=disabled', '-Dlibass:test=disabled',
    '-Dharfbuzz:freetype=enabled', '-Dharfbuzz:tests=disabled',
    '-Dharfbuzz:icu=disabled', '-Dharfbuzz:cairo=disabled', '-Dharfbuzz:chafa=disabled',
    '-Dharfbuzz:glib=disabled', '-Dharfbuzz:gobject=disabled',
    '-Dharfbuzz:introspection=disabled', '-Dharfbuzz:docs=disabled',
    '-Dharfbuzz:subset=disabled',
    '-Dharfbuzz:utilities=disabled', '-Dluajit:amalgam=true',
    '-Ddav1d:enable_tools=false', '-Ddav1d:enable_tests=true'
)
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $buildRoot) | Out-Null
Push-Location $engineRoot
try {
    if ($Reconfigure) {
        Invoke-Checked $meson (@('setup', '--reconfigure', $buildRoot) + $options)
    } elseif (-not (Test-Path (Join-Path $buildRoot 'build.ninja'))) {
        Invoke-Checked $meson (@('setup', $buildRoot) + $options)
    }
    if (-not $ConfigureOnly) {
        Invoke-Checked $meson @('compile', '-C', $buildRoot, '-j', '12')
    }
    if ($Test) {
        Invoke-Checked $meson @('test', '-C', $buildRoot, '--print-errorlogs', '--num-processes', '4')
    }
} finally { Pop-Location }
