# Adapted from mpv's pinned Windows build wrapper. No downloaded binary libraries.
project('spirv-cross', 'cpp', version: '0.59.0')
cmake = import('cmake')
opts = cmake.subproject_options()
opts.add_cmake_defines({
  'CMAKE_MSVC_RUNTIME_LIBRARY': 'MultiThreaded',
  'CMAKE_POLICY_DEFAULT_CMP0091': 'NEW',
  'SPIRV_CROSS_EXCEPTIONS_TO_ASSERTIONS': 'ON',
  'SPIRV_CROSS_CLI': 'OFF',
  'SPIRV_CROSS_ENABLE_TESTS': 'OFF',
  'SPIRV_CROSS_ENABLE_MSL': 'OFF',
  'SPIRV_CROSS_ENABLE_CPP': 'OFF',
  'SPIRV_CROSS_ENABLE_REFLECT': 'OFF',
  'SPIRV_CROSS_ENABLE_UTIL': 'OFF',
})
p = cmake.subproject('spirv-cross-cmake', options: opts)
dep = declare_dependency(dependencies: [
  p.dependency('spirv-cross-c'), p.dependency('spirv-cross-core'),
  p.dependency('spirv-cross-glsl'), p.dependency('spirv-cross-hlsl'),
])
meson.override_dependency('spirv-cross-c-shared', dep)
