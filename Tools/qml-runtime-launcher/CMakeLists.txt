cmake_minimum_required(VERSION 3.21)

project(NuclideQmlLauncher LANGUAGES C)

add_executable(NuclideLauncher WIN32 src/launcher.c src/apply.c src/apply_path.c)
target_compile_definitions(NuclideLauncher PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN)
target_link_libraries(NuclideLauncher PRIVATE user32 winhttp bcrypt)

add_executable(apply_path_test src/apply_path.c src/apply_path_test.c)
target_compile_definitions(apply_path_test PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN)
target_link_libraries(apply_path_test PRIVATE user32)

if(MSVC)
    target_compile_options(NuclideLauncher PRIVATE /W4 /permissive-)
else()
    target_compile_options(NuclideLauncher PRIVATE -Wall -Wextra -Wpedantic)
endif()
