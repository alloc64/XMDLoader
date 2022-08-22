cmake_minimum_required(VERSION 3.22)
project(XMDLoader)

set(CMAKE_CXX_STANDARD 20)

find_package(OpenGL REQUIRED)

add_compile_options(-fpermissive)

add_executable(XMDLoader
        xmdmodel.h
        xmdmodel.cpp
        console.h
        console.cpp
        math/vector.cpp
        math/vector.h
        main.cpp)

target_link_libraries(XMDLoader ${OPENGL_LIBRARIES})