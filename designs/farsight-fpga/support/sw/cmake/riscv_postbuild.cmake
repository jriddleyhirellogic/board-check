
# Post-build commands
add_custom_command(TARGET ${EXECUTABLE_NAME} POST_BUILD
    COMMAND "${CMAKE_OBJCOPY}" -O ihex --change-section-lma ${LOAD_MEMORY_ADDRESS} $<TARGET_FILE:${EXECUTABLE_NAME}> "${EXECUTABLE_NAME}.hex"
    COMMENT "Creating HEX file"
)

add_custom_command(TARGET ${EXECUTABLE_NAME} POST_BUILD
    COMMAND "${ELF_SIZE_TOOL}" --format=berkeley $<TARGET_FILE:${EXECUTABLE_NAME}>
    COMMENT "Displaying size of the ELF file"
)

# Define the final deployment directory
set(FINAL_DEPLOYMENT_DIR "$<TARGET_FILE_DIR:${EXECUTABLE_NAME}>/../bin")

# Post-build commands
add_custom_command(TARGET ${EXECUTABLE_NAME} POST_BUILD
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${FINAL_DEPLOYMENT_DIR}"
    COMMAND "${CMAKE_COMMAND}" -E copy $<TARGET_FILE:${EXECUTABLE_NAME}> "${FINAL_DEPLOYMENT_DIR}/${EXECUTABLE_NAME}.elf"
    COMMAND "${CMAKE_COMMAND}" -E copy "${EXECUTABLE_NAME}.hex" "${FINAL_DEPLOYMENT_DIR}/${EXECUTABLE_NAME}.hex"
    COMMAND "${CMAKE_COMMAND}" -E copy "${EXECUTABLE_NAME}.map" "${FINAL_DEPLOYMENT_DIR}/${EXECUTABLE_NAME}.map"
    COMMENT "Copying ELF, HEX, and MAP files to the final-deployment folder"
)


# Clean target
set_directory_properties(PROPERTIES ADDITIONAL_MAKE_CLEAN_FILES
    "${EXECUTABLE_NAME}.hex;${EXECUTABLE_NAME}.map"
)
