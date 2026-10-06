#-------------------------------------------------------------------------------
# File             : build_info.cmake
#
# Description      : Utilities for generating build information which are
#                    Build time stamp, Build GIT SHA, and Project Version.
#
# Author/Integrator: Saba Janamian 
#
# Initial Date     : 12/30/2024
#
#-------------------------------------------------------------------------------

set(BUILDINFO_TEMPLATE_DIR ${CMAKE_CURRENT_LIST_DIR})

set(DESTINATION "${CMAKE_CURRENT_BINARY_DIR}/build_info")

string(TIMESTAMP TIMESTAMP)

find_program(GIT_PATH git REQUIRED)

execute_process(COMMAND ${GIT_PATH} log --pretty=format:'%h' -n 1
                OUTPUT_VARIABLE COMMIT_SHA)

configure_file(
  "${BUILDINFO_TEMPLATE_DIR}/build_info.h.in"
  "${DESTINATION}/build_info.h" @ONLY
)

function(BuildInfo target)
  target_include_directories(${target} PRIVATE ${DESTINATION})
endfunction()

#-------------------------------------------------------------------------------
# Footer
#
# Change log:
#   [version: 0.1, date: 12/30/2024, author: Saba Janamian]: 
#   Initial implementation based on opensource resources.  
#   https://github.com/PacktPublishing/Modern-CMake-for-Cpp-2E/blob/main/examples/ch15/01-full-project/cmake/BuildInfo.cmake
# 
#
#-------------------------------------------------------------------------------