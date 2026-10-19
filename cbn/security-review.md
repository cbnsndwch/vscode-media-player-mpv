# Security review — in progress

## Scope and evidence

Engine baseline: mpv `6a262d11f63733d37e3ee6d5fafcb1be1ef83952`.
This is a targeted source/build and integration review, not an exhaustive audit of
mpv, FFmpeg, every decoder, GPU drivers, or the Windows operating system.

Reviewed initially: `ci/build-win32.ps1`, `meson.build`, `meson.options`,
`options/options.c`, `stream/network.c`, `stream/stream.c`, `demux/demux.c`,
`demux/demux_lavf.c`, and the subprocess command entry points in `player/command.c`.

Upstream's public GitHub advisory endpoint currently returns
GHSA-546v-22c3-7927 (terminal sequence injection, affected versions < 0.41.0).
That result is evidence about published advisories, not proof of absence of bugs.

## Initial findings and decisions

1. Upstream's Windows build script uses moving Git branches and invokes dependency
   synchronization during configuration. We do not execute that script. Our build
   uses explicit Git commit pins and hashed source/patch archives. Build tools are
   recorded separately; no prebuilt player or media libraries are accepted.
2. mpv defaults enable config loading, automatic user-script loading, yt-dlp hooks,
   adjacent-file loading and demuxer references. The integration must launch with
   an explicit restricted argument list, disable these features, and accept only
   validated playback settings. Keep built-in on-screen controls.
3. mpv exposes subprocess commands and an intentionally unauthenticated IPC API.
   Do not expose IPC over TCP. Use a local, restricted transport and do not pass
   workspace-controlled config, input bindings, executable paths or arbitrary
   arguments to the process. Disabling autoloading is not a process sandbox.
4. TLS certificate verification is already enabled in the pinned source. Preserve
   it. Remote media must travel over the existing authenticated SSH channel.
5. The future file bridge must authorize only a specifically selected, opened
   regular file. No directory browsing, arbitrary-path endpoint, public listener,
   shell interpolation, disabled SSH host verification, or credential in logs.
   Range requests, expiry, cancellation, replacement races and disconnect cleanup
   need negative tests before the extension is installable.
6. OSV flagged HarfBuzz 13.0.1 for OSV-2026-962 (uninitialized memory in font
   subsetting). Update to the hash-verified 14.6.0 source release. GitHub's
   compare endpoint confirms 14.6.0 contains the advisory's fix commit
   `6c2107ace765f95c67d65a21f94b54a2f12d80dc` (357 commits ahead, zero behind).
   Also disable unused font subsetting. Do not ship the initial build.
   HarfBuzz 14.6.0 needs one build fix with subsetting disabled and Clang 23:
   make an internal header helper `static inline` instead of `static` to avoid
   its unused-function error. The small patch is checked in and hashed with
   the source overlays; warning checks remain enabled.

## Compatibility and isolation

Retain broad FFmpeg decoding/demuxing and hardware decoding. Disable optional
native C plugins, JavaScript, VapourSynth, capture/device input and archive loading
for the initial profile. Lua is retained for built-in controls, with automatic user
script loading and yt-dlp disabled at launch. Container formats and codecs are
distinct: enumerate actual compiled decoders/demuxers and test representative files.

The build includes mpv's `gpu` Direct3D 11 renderer and OpenGL rendering.
Shaderc, glslang, SPIRV-Tools and SPIRV-Cross are built from pinned sources;
the production dependency list excludes their test-only dependencies. Their
sources are fetched before configuration, with no `git-sync-deps` execution.
Vulkan rendering and libplacebo's `gpu-next` Direct3D 11 backend are excluded.
The latter reproducibly crashed with a benign H.264 fixture on this laptop,
including with hardware decoding disabled (Windows access violation 0xc0000005).
Both mpv's `gpu` Direct3D 11 renderer and `gpu-next` OpenGL passed the same test.
This isolates the failing rendering path; it does not establish the underlying
cause or exploitability. The failing backend is compiled out, and the launch
profile selects the tested standard Direct3D renderer.

## Outstanding verification

- Complete the native source build and record all dependency versions/hashes.
- Verify PE hardening, decoder inventory and unit tests.
- Exercise representative audio/video, malformed inputs, seeking and startup.
- Implement and test the SSH integration and restricted launch profile.
- Review known vulnerabilities for the resolved dependency inventory.
- Evaluate Windows process containment; compiler protections are not isolation.
- Test the final installed flow with the user's Ubuntu Remote SSH session.
