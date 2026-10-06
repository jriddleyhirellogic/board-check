#-------------------------------------------------------------------------------
# File: cpp_check.cmake
#
# Description: Utility function to add CPPCheck to a target.
#
# Author/Integrator: Saba Janamian 
#
# Initial Date: 12/25/2024
#
#-------------------------------------------------------------------------------

function(AddCppCheck target)

  find_program(CPPCHECK_PATH cppcheck REQUIRED)

  set_target_properties(
    ${target}
    PROPERTIES CXX_CPPCHECK
    "${CPPCHECK_PATH};--enable=warning;--error-exitcode=1"
  )

  endfunction()

#-------------------------------------------------------------------------------
# Footer
#
# Change log:
#   [version: 0.1, date: 12/25/2024, author: Saba Janamian]: 
#   Initial implementation based on opensource resources.  
#   https://github.com/PacktPublishing/Modern-CMake-for-Cpp-2E/blob/main/examples/ch15/01-full-project/cmake/CppCheck.cmake
# 
#
#-------------------------------------------------------------------------------