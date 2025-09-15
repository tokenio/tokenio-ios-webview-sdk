#!/bin/bash

# Path to the project file
PROJECT_FILE="TokenTestiOS.xcodeproj/project.pbxproj"

# Make a backup of the project file
cp "$PROJECT_FILE" "${PROJECT_FILE}.backup"

# Enable testability for the main target
sed -i '' 's/SWIFT_OPTIMIZATION_LEVEL = "-O"/SWIFT_OPTIMIZATION_LEVEL = "-Onone"/g' "$PROJECT_FILE"

# Enable testability for debug configurations
sed -i '' 's/SWIFT_OPTIMIZATION_LEVEL = "-O";/SWIFT_OPTIMIZATION_LEVEL = "-Onone";/g' "$PROJECT_FILE"

# Enable testability for the test target
sed -i '' 's/ENABLE_TESTABILITY = NO;/ENABLE_TESTABILITY = YES;/g' "$PROJECT_FILE"

# Set the test host correctly
sed -i '' 's/TEST_HOST = "";/TEST_HOST = "\$(BUILT_PRODUCTS_DIR)\/TokenTestiOS.app\/TokenTestiOS";/g' "$PROJECT_FILE"

# Set the bundle loader
sed -i '' 's/BUNDLE_LOADER = "";/BUNDLE_LOADER = "\$(TEST_HOST)";/g' "$PROJECT_FILE"

echo "Project settings updated successfully. A backup was created at ${PROJECT_FILE}.backup"
