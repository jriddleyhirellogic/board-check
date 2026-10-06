#-------------------------------------------------------------------------------
# File             : CMakeLists.txt
#
# Description      : Sets compiler flags based on the build type
#
#
# Author/Integrator: Saba Janamian 
#
# Initial Date     : 12/31/2024
#
#-------------------------------------------------------------------------------

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Debug CACHE STRING "Build type" FORCE)
endif()

if(CMAKE_BUILD_TYPE STREQUAL "Debug")

    add_compile_options(-g3 -O0)
    if(NOT CMAKE_CROSSCOMPILING AND ENABLE_TESTING)
        add_compile_options(--coverage)
        add_link_options(--coverage)
    endif()
    if(ENABLE_ALL_COMPILER_WARN)
        add_compile_options(-pedantic -Werror  -Wall -Wextra -Wshadow)
        add_compile_options(-Wpointer-arith -Wcast-align -Wformat -Wconversion)
        add_compile_options(-Wunused -Wdeprecated)
    endif()

elseif(CMAKE_BUILD_TYPE STREQUAL "Release")
    # FIXME: Maybe use -Os (size)
    add_compile_options(-DNDEBUG -O2)

    if(ENABLE_ALL_COMPILER_WARN)
        add_compile_options(-pedantic -Werror  -Wall -Wextra -Wshadow)
        add_compile_options(-Wpointer-arith -Wcast-align -Wformat -Wconversion)
        add_compile_options(-Wunused -Wdeprecated)
    endif()

endif()

message(STATUS "Build Type:   ${CMAKE_BUILD_TYPE}")

#-------------------------------------------------------------------------------
# Footer
#
# Change log:
#   [version: 0.1, date: 12/31/2024, author: Saba Janamian]: 
#   Initial implementation.
#   
#
#-------------------------------------------------------------------------------