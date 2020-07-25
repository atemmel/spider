cmake_minimum_required(VERSION 3.10)
project(spider)

# Set a default build type if none was specified
set(default_build_type "Release")
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  message(STATUS "Setting build type to '${default_build_type}' as none was specified.")
  set(CMAKE_BUILD_TYPE "${default_build_type}")
endif()

file(GLOB_RECURSE SOURCES RELATIVE ${CMAKE_SOURCE_DIR} "./src/*.cpp")
add_executable(spider ${SOURCES})
set_property(TARGET spider PROPERTY CXX_STANDARD 17)
include_directories(./include)

add_compile_options(-pedantic -Wall -Wextra -Wfloat-equal -Wwrite-strings -Wno-unused-parameter -Wundef -Wcast-qual -Wshadow -Wredundant-decls)

find_library(libcurses ncursesw REQUIRED IMPORTED)
find_library(libmagic magic REQUIRED IMPORTED)
find_library(libgit2 git2 REQUIRED IMPORTED)
find_library(libdl dl REQUIRED IMPORTED)
find_library(libfs stdc++fs REQUIRED IMPORTED)

target_link_libraries(spider ${libcurses} ${libmagic} ${libgit2} ${libdl} ${libfs})

install(TARGETS spider DESTINATION bin)
