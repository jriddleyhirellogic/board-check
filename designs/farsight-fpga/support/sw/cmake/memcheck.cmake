#-------------------------------------------------------------------------------
# File             : mem_check.cmake
#
# Description      : Memcheck cover provides a bash helper for Valgrind Memcheck 
#                    analysis.
#
# Author/Integrator: Saba Janamian 
#
# Initial Date     : 12/29/2024
#
#-------------------------------------------------------------------------------

include(FetchContent)

FetchContent_Declare(
  memcheck-cover
  GIT_REPOSITORY https://github.com/Farigh/memcheck-cover.git
  GIT_TAG        release-1.2
)

FetchContent_MakeAvailable(memcheck-cover)

function(AddMemcheck target)

set(MEMCHECK_PATH ${memcheck-cover_SOURCE_DIR}/bin)

set(REPORT_PATH "${CMAKE_BINARY_DIR}/valgrind-${target}")

add_custom_target(memcheck-${target}

    COMMAND ${MEMCHECK_PATH}/memcheck_runner.sh -o
            "${REPORT_PATH}/report"
            -- $<TARGET_FILE:${target}>

    COMMAND ${MEMCHECK_PATH}/generate_html_report.sh
            -i ${REPORT_PATH}
            -o ${REPORT_PATH}

    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
  )
endfunction()

#-------------------------------------------------------------------------------
# Footer
#
# Change log:
#   [version: 0.1, date: 12/29/2024, author: Saba Janamian]: 
#   Initial implementation based on opensource resources.
#   https://github.com/PacktPublishing/Modern-CMake-for-Cpp-2E/blob/main/examples/ch15/01-full-project/cmake/Memcheck.cmake
#
#-------------------------------------------------------------------------------