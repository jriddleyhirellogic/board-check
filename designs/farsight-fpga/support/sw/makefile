#-------------------------------------------------------------------------------
# File : makefile
#
# Description : Makefile for running CMake generate and build or
# cleaning the project with support for different IMX build targets
#
# Author/Integrator: Saba Janamian
#
# Initial Date : 12/29/2024
# Updated Date : 09/03/2025
# Updated Date : 12/04/2025 (removed extra make recipe)
#-------------------------------------------------------------------------------
#

# Default IMX target (can be overridden)
IMX_TARGET ?= 1

.PHONY: \
	all \
	clean \
	generate-debug \
	generate-release \
	build \
	help

help:
	@echo ""
	@echo "Available make targets:"
	@echo " help                                    - Show this help message"
	@echo " clean                                   - Remove the 'build/' directory"
	@echo ""
	@echo "Debug builds:"
	@echo " generate-debug                          - Generate CMake Debug build for IMX531 All Pixel FREQ 0"
	@echo ""
	@echo "Release builds:"
	@echo " generate-release                        - Generate CMake Release build for IMX531 All Pixel FREQ 0"
	@echo ""
	@echo " build                                   - Build using previously generated CMake files"
	@echo ""

clean:
	rm -fR build/

generate-debug:
	cmake -B build -S . -DCMAKE_BUILD_TYPE=Debug

generate-release:
	cmake -B build -S . -DCMAKE_BUILD_TYPE=Release


build:
	cmake --build build