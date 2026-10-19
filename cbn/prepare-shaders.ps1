$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$engineRoot = if (Test-Path (Join-Path $projectRoot 'meson.build')) { $projectRoot } else { Join-Path $projectRoot 'engine/mpv' }
$subprojects = Join-Path $engineRoot 'subprojects'
$sources = Get-Content (Join-Path $PSScriptRoot 'shader-sources.lock.json') | ConvertFrom-Json
foreach ($source in $sources) {
    if ($source.revision -notmatch '^[0-9a-f]{40}$') { throw 'Non-pinned source' }
    $destination = Join-Path $subprojects $source.path
    if (-not (Test-Path (Join-Path $destination '.git'))) {
        New-Item -ItemType Directory -Force -Path $destination | Out-Null
        git -C $destination init --quiet
        if ($LASTEXITCODE -ne 0) { throw 'git init failed' }
        git -C $destination remote add origin $source.url
        git -C $destination fetch --depth 1 origin $source.revision
        if ($LASTEXITCODE -ne 0) { throw 'Source fetch failed' }
        git -C $destination checkout --detach FETCH_HEAD
        if ($LASTEXITCODE -ne 0) { throw 'Source checkout failed' }
    }
    $actual = git -C $destination rev-parse HEAD
    if ($LASTEXITCODE -ne 0 -or $actual -ne $source.revision) {
        throw "Source revision mismatch: $($source.path)"
    }
}
# Same semantic fix as upstream mpv's Windows script; Meson's CMake adapter cannot
# resolve this generator expression. No shader compiler runtime code is changed.
$cmakePath = Join-Path $subprojects 'shaderc_cmake/third_party/CMakeLists.txt'
$cmakeText = Get-Content -LiteralPath $cmakePath -Raw
$before = 'set(GLSLANG_ENABLE_INSTALL $<NOT:${SKIP_GLSLANG_INSTALL}>)'
$after = "if (SKIP_GLSLANG_INSTALL)`n      set(GLSLANG_ENABLE_INSTALL OFF)`n    else()`n      set(GLSLANG_ENABLE_INSTALL ON)`n    endif()"
if ($cmakeText.Contains($before)) {
    [IO.File]::WriteAllText($cmakePath, $cmakeText.Replace($before, $after))
} elseif (-not $cmakeText.Contains($after)) {
    throw 'Unexpected shaderc CMake source; refusing to patch'
}
foreach ($wrapper in @('shaderc','spirv-cross-c-shared')) {
    $destination = Join-Path $subprojects $wrapper
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    Copy-Item -LiteralPath (Join-Path $subprojects "packagefiles/$wrapper/meson.build") -Destination $destination
}
