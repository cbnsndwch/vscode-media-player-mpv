# Adapted from mpv ci/build-win32.ps1 at the pinned engine baseline.
# Source fetching is deliberately separate. No git-sync-deps or other downloads.
project('shaderc', 'cpp', version: '2026.2')
python = find_program('python3')
run_command(python,
  '../shaderc_cmake/third_party/spirv-tools/utils/update_build_version.py',
  '../shaderc_cmake/third_party/spirv-tools/CHANGES',
  '../shaderc_cmake/third_party/spirv-tools/build-version.inc', check: true)
cmake = import('cmake')
opts = cmake.subproject_options()
opts.add_cmake_defines({
  'CMAKE_MSVC_RUNTIME_LIBRARY': 'MultiThreaded',
  'CMAKE_POLICY_DEFAULT_CMP0091': 'NEW',
  'SHADERC_SKIP_INSTALL': 'ON',
  'SHADERC_SKIP_TESTS': 'ON',
  'SHADERC_SKIP_EXAMPLES': 'ON',
  'SHADERC_SKIP_COPYRIGHT_CHECK': 'ON',
  'SPIRV_SKIP_TESTS': 'ON',
  'SPIRV_SKIP_EXECUTABLES': 'ON',
})
p = cmake.subproject('shaderc_cmake', options: opts)
dep = declare_dependency(dependencies: [
  p.dependency('shaderc'), p.dependency('shaderc_util'),
  p.dependency('SPIRV-Tools-static'), p.dependency('SPIRV-Tools-opt'),
  p.dependency('glslang'),
])
meson.override_dependency('shaderc', dep)
