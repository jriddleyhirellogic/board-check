#-------------------------------------------------------------------------------
# File             : code_coverage.cmake
#
# Description      : Utilities for code coverage using lcov and genhtml.
#
# Author/Integrator: Saba Janamian 
#
# Initial Date     : 12/25/2024
#
#-------------------------------------------------------------------------------


# Locates the lcov and genhtml programs, which are necessary for generating 
# coverage reports.
function(AddCoverage target)
  find_program(LCOV_PATH lcov REQUIRED)
  find_program(GENHTML_PATH genhtml REQUIRED)

  add_custom_target(coverage-${target}
    
    COMMAND ${LCOV_PATH} -d . --zerocounters
    
    COMMAND $<TARGET_FILE:${target}>
    
    COMMAND ${LCOV_PATH} -d . --capture -o coverage.info
    
    COMMAND ${LCOV_PATH} -r coverage.info '/usr/include/*'
                         -o filtered.info

    COMMAND ${GENHTML_PATH} -o coverage-${target}
                            filtered.info --legend
    COMMAND rm -rf coverage.info filtered.info
    
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
  )

endfunction()


# Clean up coverage data files (*.gcda) before building a specified target.
# Usage: CleanCoverage(my_target)
function(CleanCoverage target)
if (CMAKE_BUILD_TYPE STREQUAL Debug AND ENABLE_TESTING)  
  add_custom_command(TARGET ${target} PRE_BUILD COMMAND
                     find ${CMAKE_BINARY_DIR} -type f
                     -name '*.gcda' -exec cmake -E rm {} +)
  endif()
endfunction()


# Configures a given target to generate code coverage data when built in debug 
# mode and testing is enabled
function(ConfigCoverage target)
  if (CMAKE_BUILD_TYPE STREQUAL Debug AND ENABLE_TESTING)
    
    target_compile_options(${target} PRIVATE --coverage -fno-inline)
    
    target_link_options(${target} PUBLIC --coverage)
  
  endif()
endfunction()

#-------------------------------------------------------------------------------
# Footer
#
# Change log:
#   [version: 0.1, date: 12/25/2024, author: Saba Janamian]: 
#   Initial implementation based on opensource resources.  
#   https://github.com/PacktPublishing/Modern-CMake-for-Cpp-2E/blob/main/examples/ch15/01-full-project/cmake/Coverage.cmake
# 
#
#-------------------------------------------------------------------------------