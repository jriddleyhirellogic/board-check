#-------------------------------------------------------------------------------
# File             : code_format.cmake
#
# Description      : Utilities for code format based on .clang_format style.
#
# Author/Integrator: Saba Janamian 
#
# Initial Date     : 12/25/2024
#
#-------------------------------------------------------------------------------



# Find cland-format style file and apply it to all source files in a 
# given directory.
function(Format target directory)
  
  find_program(CLANG-FORMAT_PATH "clang-format" REQUIRED)
  
  set(EXPRESSION h hpp hh c cc cxx cpp)
  
  list(TRANSFORM EXPRESSION PREPEND "${directory}/*.")
  
  file(GLOB_RECURSE SOURCE_FILES FOLLOW_SYMLINKS
       LIST_DIRECTORIES false ${EXPRESSION}
  )
  
  # Check if target is an INTERFACE library
  get_target_property(target_type ${target} TYPE)

  if(target_type STREQUAL "INTERFACE_LIBRARY")
      # Create a custom target for interface libraries
      add_custom_target(${target}_format
          COMMAND ${CLANG-FORMAT_PATH} -i --style=file ${SOURCE_FILES}
          COMMENT "Formatting ${target} sources"
      )
      # Make the interface library depend on the format target
      add_dependencies(${target} ${target}_format)
  else()
      # Use PRE_BUILD for regular targets
      add_custom_command(TARGET ${target} PRE_BUILD COMMAND
          ${CLANG-FORMAT_PATH} -i --style=file ${SOURCE_FILES}
      )
  endif()

endfunction()

#-------------------------------------------------------------------------------
# Footer
#
# Change log:
#   [version: 0.1, date: 12/25/2024, author: Saba Janamian]: 
#   Initial implementation based on opensource resources.  
#   https://github.com/PacktPublishing/Modern-CMake-for-Cpp-2E/blob/main/examples/ch15/01-full-project/cmake/Format.cmake
# 
#
#-------------------------------------------------------------------------------