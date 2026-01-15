#!/usr/bin/env bash
#
# Build release packages for Conduit
# Reads version info from dist.info and builds release packages with various optimization levels
#
# Usage: ./build_release.sh [-c|--clean]
#   -c, --clean    Remove existing release directory before building

set -euo pipefail

# Parse arguments
CLEAN=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--clean)
            CLEAN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [-c|--clean]"
            exit 1
            ;;
    esac
done

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to project root (where squish is located)
cd "$PROJECT_ROOT"

# Read dist.info
echo -e "\033[36mReading dist.info...\033[0m"
if [[ ! -f "dist.info" ]]; then
    echo "Error: dist.info not found"
    exit 1
fi

DIST_INFO=$(cat "dist.info")

# Parse version
VERSION=$(echo "$DIST_INFO" | grep -oP 'version\s*=\s*"\K[^"]+' || true)
if [[ -z "$VERSION" ]]; then
    echo "Error: Could not find version in dist.info"
    exit 1
fi

# Parse name
NAME=$(echo "$DIST_INFO" | grep -oP 'name\s*=\s*"\K[^"]+' || true)
if [[ -z "$NAME" ]]; then
    echo "Error: Could not find name in dist.info"
    exit 1
fi

echo -e "\033[32mBuilding $NAME version $VERSION\033[0m"

# Create dist directory inside release folder
DIST_DIR="$SCRIPT_DIR/dist"
if [[ "$CLEAN" == true ]] && [[ -d "$DIST_DIR" ]]; then
    echo -e "\033[33mCleaning dist directory...\033[0m"
    rm -rf "$DIST_DIR"
fi

mkdir -p "$DIST_DIR"

# Build variants (output:args:desc:suffix)
declare -a VARIANTS=(
    "conduit.lua||standard|"
    "conduit.min.lua|--minify -minify-level=full|minified|-min"
    "conduit.ugl.lua|--uglify -uglify-level=full|uglified|-ugl"
    "conduit.min.ugl.lua|--minify -minify-level=full --uglify -uglify-level=full|minified + uglified|-min-ugl"
)

# Additional files to include in each package
ADDITIONAL_FILES=("README.md" "LICENSE" "dist.info")

for variant in "${VARIANTS[@]}"; do
    IFS='|' read -r OUTPUT_FILE VARIANT_ARGS DESC SUFFIX <<< "$variant"

    echo -e "\n\033[36mBuilding $OUTPUT_FILE ($DESC)...\033[0m"

    # Build squish command
    SQUISH_CMD="lua squish --output=\"$OUTPUT_FILE\" $VARIANT_ARGS"

    echo -e "  \033[90mRunning: $SQUISH_CMD\033[0m"
    eval "$SQUISH_CMD"

    if [[ ! -f "$OUTPUT_FILE" ]]; then
        echo -e "  \033[33mWarning: $OUTPUT_FILE was not created\033[0m"
        continue
    fi

    # Fix require paths for standalone module
    echo -e "  \033[90mFixing require paths...\033[0m"
    sed -i 's/require\s*(\s*"conduit\.server"\s*)/require("server")/g' "$OUTPUT_FILE"
    sed -i 's/require\s*(\s*"conduit\.templates"\s*)/require("templates")/g' "$OUTPUT_FILE"
    sed -i 's/require\s*(\s*"conduit\.console"\s*)/require("console")/g' "$OUTPUT_FILE"

    # Create package for this variant
    PACKAGE_NAME="$(echo "$NAME" | tr '[:upper:]' '[:lower:]')-$VERSION$SUFFIX"
    PACKAGE_DIR="$DIST_DIR/$PACKAGE_NAME"

    rm -rf "$PACKAGE_DIR"
    mkdir -p "$PACKAGE_DIR"

    # Copy built file
    cp "$OUTPUT_FILE" "$PACKAGE_DIR/"

    # Copy additional files if they exist
    for file in "${ADDITIONAL_FILES[@]}"; do
        if [[ -f "$file" ]]; then
            cp "$file" "$PACKAGE_DIR/"
        fi
    done

    # Create archive
    ARCHIVE_NAME="$PACKAGE_NAME.tar.gz"
    ARCHIVE_PATH="$DIST_DIR/$ARCHIVE_NAME"
    echo -e "  \033[90mCreating archive $ARCHIVE_NAME...\033[0m"
    tar -czf "$ARCHIVE_PATH" -C "$DIST_DIR" "$PACKAGE_NAME"

    # Clean up package directory and built file
    rm -rf "$PACKAGE_DIR"
    rm -f "$OUTPUT_FILE"

    echo -e "  \033[32mCreated $ARCHIVE_NAME\033[0m"
done

echo -e "\n\033[32mBuild complete!\033[0m"
echo -e "\n\033[36mPackages created:\033[0m"
for archive in "$DIST_DIR"/*.tar.gz; do
    if [[ -f "$archive" ]]; then
        echo -e "  \033[37m$(basename "$archive")\033[0m"
    fi
done
