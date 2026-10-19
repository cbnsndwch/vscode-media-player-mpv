# CBN Windows source build

This downstream branch pins the media runtime sources and builds them locally.
It does not use mpv/FFmpeg release binaries or prebuilt container images.
The upstream baseline is `6a262d11f63733d37e3ee6d5fafcb1be1ef83952`.

The build environment is Windows x64 with PowerShell 7, Visual Studio 2022 Build
Tools and Windows SDK 10.0.22621.0. Python, uv, Git, curl and 7-Zip are build tools.
Compiler/download digests and Python build-tool versions are pinned in
`build-tools.lock.txt`. These tools are distinct from the source-built playback
runtime. The scripts install project-local tools rather than modifying PATH globally.

```powershell
./cbn/bootstrap-player.ps1
./cbn/build-player.ps1 -Test
```

Outputs are under `build/player/`. The initial profile keeps broad FFmpeg codecs,
Direct3D 11/OpenGL output, Windows hardware decoding, WASAPI, Lua built-in controls
and libass subtitles. Optional C plugins, JavaScript, capture devices, VapourSynth,
archive loading and Vulkan output are disabled.

The newer libplacebo Direct3D 11 renderer is excluded after a reproducible crash
in testing. The VS Code integration selects mpv's tested `gpu` Direct3D renderer.
HarfBuzz is updated to 14.6.0 to incorporate the OSV-2026-962 fix. A one-line build
fix marks an unused internal header helper inline with font subsetting disabled.

See `security-review.md` for the review scope and limitations. This is not a claim
of a full audit of the codecs, graphics drivers or Windows.
