#-------------------------------------------------------------------------------
# File: no_in_src_builds.cmake
#
# Description: Utility to prevent in-source builds
#
# Author/Integrator: Saba Janamian 
#
# Initial Date: 12/25/2024
#
#-------------------------------------------------------------------------------

if(PROJECT_SOURCE_DIR STREQUAL PROJECT_BINARY_DIR)
  message(FATAL_ERROR
    "\n"
    "Error: In-source builds are not allowed.\n"
    "Please create a separate build directory and run:\n"
    "  cmake -B <build_directory> -S .\n"
    "\n"
    "To clean up files accidentally generated, run:\n"
    "  rm -rf CMakeFiles CMakeCache.txt\n"
  )
endif()

#-------------------------------------------------------------------------------
# Footer
#
# Change log:
#   [version: 0.1, date: 12/25/2024, author: Saba Janamian]: 
#   Initial implementation based on opensource resources.  
#   https://github.com/PacktPublishing/Modern-CMake-for-Cpp-2E/blob/main/examples/ch15/01-full-project/cmake/NoInSourceBuilds.cmake
# 
#
#-------------------------------------------------------------------------------
