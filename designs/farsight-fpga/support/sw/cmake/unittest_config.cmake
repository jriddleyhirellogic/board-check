#-------------------------------------------------------------------------------
# File             : unittest_config.cmake
#
# Description      : Populate GoogleTest suite for unit testing
#
# Author/Integrator: Saba Janamian 
#
# Initial Date     : 12/29/2024
#
#-------------------------------------------------------------------------------

include(FetchContent)

FetchContent_Declare(
  googletest
  GIT_REPOSITORY https://github.com/google/googletest.git
  GIT_TAG v1.14.0
)

# For Windows: Prevent overriding the parent project's
# compiler/linker settings
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)

option(INSTALL_GMOCK "Install GMock" OFF)
option(INSTALL_GTEST "Install GTest" OFF)

FetchContent_MakeAvailable(googletest)

include(GoogleTest)
include("code_coverage")
include("memcheck")

macro(AddTests target)
  message("Adding tests to ${target}")

  target_link_libraries(${target} PRIVATE gtest_main gmock)

  gtest_discover_tests(${target})

  AddCoverage(${target})

  AddMemcheck(${target})
endmacro()

#-------------------------------------------------------------------------------
# Footer
#
# Change log:
#   [version: 0.1, date: 12/29/2024, author: Saba Janamian]: 
#   Initial implementation based on opensource resources.
#   https://github.com/PacktPublishing/Modern-CMake-for-Cpp-2E/blob/main/examples/ch15/01-full-project/cmake/Testing.cmake
#
#-------------------------------------------------------------------------------