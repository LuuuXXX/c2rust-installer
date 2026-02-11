#!/usr/bin/env bash

set -e

# Default installation prefix
DEFAULT_PREFIX="${HOME}/.local"
PREFIX=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Display help message
show_help() {
    cat << EOF
Usage: ${0} [OPTIONS]

Install all c2rust-* Rust projects and additional components from the script directory.

OPTIONS:
    --prefix=PATH       Specify installation prefix (default: ${DEFAULT_PREFIX})
    --help, -h          Display this help message

EXAMPLES:
    # Install with default prefix
    ${0}

    # Install with custom prefix
    ${0} --prefix=/opt/c2rust

    # Display help
    ${0} --help

DESCRIPTION:
    This script automatically discovers and installs all Rust projects in the
    script directory that start with 'c2rust-'. Each project must contain a
    Cargo.toml file.

    The binaries will be installed to <prefix>/bin

    Additionally, the script will process and install the following components
    if they are present in the script directory:
    
    - c2rust-build-master: Builds and installs libhook.so to <prefix>/lib
    - hybrid-build: Builds and installs libc2rust-hybrid-build.so to <prefix>/lib
    - translate_and_fix: Copies the directory to <prefix>/python

INSTALLATION STRUCTURE:
    <prefix>/bin     - Binary executables from Rust projects
    <prefix>/lib     - Shared libraries (.so files)
    <prefix>/python  - Python modules and scripts

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --prefix=*)
                PREFIX="${1#*=}"
                if [[ -z "$PREFIX" ]]; then
                    echo -e "${RED}Error: --prefix= requires a non-empty path argument${NC}" >&2
                    exit 1
                fi
                shift
                ;;
            --prefix)
                if [[ -n "$2" ]] && [[ "$2" != --* ]]; then
                    PREFIX="$2"
                    shift 2
                else
                    echo -e "${RED}Error: --prefix requires a path argument${NC}" >&2
                    exit 1
                fi
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}Error: Unknown option: $1${NC}" >&2
                echo "Use --help for usage information" >&2
                exit 1
                ;;
        esac
    done

    # Use default prefix if not specified
    if [[ -z "$PREFIX" ]]; then
        PREFIX="$DEFAULT_PREFIX"
    fi
}

# Find all c2rust-* projects
find_projects() {
    local projects=()
    
    # Enable nullglob to handle the case where no matches are found
    shopt -s nullglob
    
    for dir in "${SCRIPT_DIR}"/c2rust-*; do
        if [[ -d "$dir" ]]; then
            if [[ -f "$dir/Cargo.toml" ]]; then
                projects+=("$dir")
            else
                echo -e "${YELLOW}Warning: Skipping '$dir' - no Cargo.toml found${NC}" >&2
            fi
        fi
    done
    
    shopt -u nullglob
    
    # Only output if there are projects
    if [[ ${#projects[@]} -gt 0 ]]; then
        printf '%s\n' "${projects[@]}"
    fi
    return 0
}

# Install a single project
install_project() {
    local project_path="$1"
    local project_name
    project_name="$(basename "$project_path")"
    
    echo -e "${BLUE}Installing ${project_name}...${NC}"
    
    # Try with --locked first, suppress output if it fails
    if cargo install --path "$project_path" --root "$PREFIX" --locked >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Successfully installed ${project_name}${NC}"
        return 0
    fi
    
    # Fallback: try without --locked, showing output
    if cargo install --path "$project_path" --root "$PREFIX"; then
        echo -e "${GREEN}✓ Successfully installed ${project_name}${NC}"
        return 0
    fi
    
    echo -e "${RED}Error: Failed to install ${project_name}${NC}" >&2
    return 1
}

# Ensure required directory structure exists
ensure_directories() {
    echo "Setting up directory structure..."
    
    local dirs_created=()
    local dirs_existed=()
    
    for dir in "lib" "python"; do
        local dir_path="${PREFIX}/${dir}"
        if [[ ! -d "$dir_path" ]]; then
            if mkdir -p "$dir_path"; then
                dirs_created+=("$dir")
                echo -e "${GREEN}✓ Created ${dir} directory${NC}"
            else
                echo -e "${RED}Error: Failed to create ${dir} directory${NC}" >&2
                return 1
            fi
        else
            dirs_existed+=("$dir")
        fi
    done
    
    # bin directory should already exist from cargo install, but check anyway
    if [[ ! -d "${PREFIX}/bin" ]]; then
        if mkdir -p "${PREFIX}/bin"; then
            dirs_created+=("bin")
            echo -e "${GREEN}✓ Created bin directory${NC}"
        else
            echo -e "${RED}Error: Failed to create bin directory${NC}" >&2
            return 1
        fi
    fi
    
    if [[ ${#dirs_created[@]} -eq 0 ]]; then
        echo -e "${GREEN}✓ All required directories already exist${NC}"
    fi
    
    return 0
}

# Handle c2rust-build-master directory
install_c2rust_build_master() {
    local build_dir="${SCRIPT_DIR}/c2rust-build-master"
    
    if [[ ! -d "$build_dir" ]]; then
        return 0  # Not an error, just not present
    fi
    
    echo "Processing c2rust-build-master..."
    
    local hook_dir="${build_dir}/hook"
    if [[ ! -d "$hook_dir" ]]; then
        echo -e "${YELLOW}Warning: c2rust-build-master exists but hook/ directory not found${NC}" >&2
        return 1
    fi
    
    if [[ ! -f "${hook_dir}/build.sh" ]]; then
        echo -e "${YELLOW}Warning: build.sh not found in ${hook_dir}${NC}" >&2
        return 1
    fi
    
    echo "Building hook library..."
    
    # Navigate to hook directory and run build.sh
    if ! (cd "$hook_dir" && ./build.sh); then
        echo -e "${RED}Error: Failed to build hook library${NC}" >&2
        return 1
    fi
    
    # Find and copy libhook.so
    local libhook_path="${hook_dir}/libhook.so"
    if [[ ! -f "$libhook_path" ]]; then
        echo -e "${RED}Error: libhook.so not found after build${NC}" >&2
        return 1
    fi
    
    if cp "$libhook_path" "${PREFIX}/lib/"; then
        echo -e "${GREEN}✓ Successfully built and installed libhook.so${NC}"
        return 0
    else
        echo -e "${RED}Error: Failed to copy libhook.so${NC}" >&2
        return 1
    fi
}

# Handle hybrid-build directory
install_hybrid_build() {
    local hybrid_dir="${SCRIPT_DIR}/hybrid-build"
    
    if [[ ! -d "$hybrid_dir" ]]; then
        return 0  # Not an error, just not present
    fi
    
    echo "Processing hybrid-build..."
    
    echo "Building hybrid-build library..."
    
    # Navigate to hybrid-build directory and run make
    if ! (cd "$hybrid_dir" && make); then
        echo -e "${RED}Error: Failed to build hybrid-build library${NC}" >&2
        return 1
    fi
    
    # Find and copy libc2rust-hybrid-build.so
    local lib_path="${hybrid_dir}/libc2rust-hybrid-build.so"
    if [[ ! -f "$lib_path" ]]; then
        echo -e "${RED}Error: libc2rust-hybrid-build.so not found after build${NC}" >&2
        return 1
    fi
    
    if cp "$lib_path" "${PREFIX}/lib/"; then
        echo -e "${GREEN}✓ Successfully built and installed libc2rust-hybrid-build.so${NC}"
        return 0
    else
        echo -e "${RED}Error: Failed to copy libc2rust-hybrid-build.so${NC}" >&2
        return 1
    fi
}

# Handle translate_and_fix directory
install_translate_and_fix() {
    local translate_dir="${SCRIPT_DIR}/translate_and_fix"
    
    if [[ ! -d "$translate_dir" ]]; then
        return 0  # Not an error, just not present
    fi
    
    echo "Processing translate_and_fix..."
    
    # Copy the entire directory to PREFIX/python/
    if cp -r "$translate_dir" "${PREFIX}/python/"; then
        echo -e "${GREEN}✓ Successfully copied translate_and_fix to python directory${NC}"
        return 0
    else
        echo -e "${RED}Error: Failed to copy translate_and_fix directory${NC}" >&2
        return 1
    fi
}

# Install additional components
install_additional_components() {
    local additional_succeeded=()
    local additional_failed=()
    
    echo ""
    echo "=========================================="
    echo "Additional Components Installation"
    echo "=========================================="
    echo ""
    
    # Ensure directory structure
    if ensure_directories; then
        additional_succeeded+=("Directory structure")
    else
        additional_failed+=("Directory structure")
    fi
    echo ""
    
    # Install c2rust-build-master if present
    if [[ -d "${SCRIPT_DIR}/c2rust-build-master" ]]; then
        if install_c2rust_build_master; then
            additional_succeeded+=("c2rust-build-master")
        else
            additional_failed+=("c2rust-build-master")
        fi
        echo ""
    fi
    
    # Install hybrid-build if present
    if [[ -d "${SCRIPT_DIR}/hybrid-build" ]]; then
        if install_hybrid_build; then
            additional_succeeded+=("hybrid-build")
        else
            additional_failed+=("hybrid-build")
        fi
        echo ""
    fi
    
    # Install translate_and_fix if present
    if [[ -d "${SCRIPT_DIR}/translate_and_fix" ]]; then
        if install_translate_and_fix; then
            additional_succeeded+=("translate_and_fix")
        else
            additional_failed+=("translate_and_fix")
        fi
        echo ""
    fi
    
    # Return arrays via global variables for summary
    ADDITIONAL_SUCCEEDED=("${additional_succeeded[@]}")
    ADDITIONAL_FAILED=("${additional_failed[@]}")
    
    # Return failure if any component failed
    if [[ ${#additional_failed[@]} -gt 0 ]]; then
        return 1
    fi
    return 0
}

# Main installation function
main() {
    parse_args "$@"
    
    echo "=========================================="
    echo "c2rust Projects Installer"
    echo "=========================================="
    echo ""
    echo "Installation prefix: $PREFIX"
    echo "Script directory: $SCRIPT_DIR"
    echo ""
    
    # Check if cargo is installed
    if ! command -v cargo &> /dev/null; then
        echo -e "${RED}Error: cargo is not installed or not in PATH${NC}" >&2
        echo "Please install Rust from https://rustup.rs/" >&2
        exit 1
    fi
    
    # Find all c2rust-* projects
    echo "Searching for c2rust-* projects..."
    local -a projects=()
    while IFS= read -r project; do
        projects+=("$project")
    done < <(find_projects)
    
    # Install each project
    local installed=()
    local failed=()
    
    if [[ ${#projects[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No c2rust-* projects found in ${SCRIPT_DIR}${NC}"
        echo "Expected to find directories starting with 'c2rust-' containing Cargo.toml files"
        echo ""
    else
        echo -e "${GREEN}Found ${#projects[@]} project(s):${NC}"
        for project in "${projects[@]}"; do
            echo "  - $(basename "$project")"
        done
        echo ""
        
        # Install each project
        for project in "${projects[@]}"; do
            if install_project "$project"; then
                installed+=("$(basename "$project")")
            else
                failed+=("$(basename "$project")")
            fi
            echo ""
        done
    fi
    
    # Install additional components
    local -a ADDITIONAL_SUCCEEDED=()
    local -a ADDITIONAL_FAILED=()
    install_additional_components || true  # Don't exit on failure, we handle it in summary
    
    # Summary
    echo "=========================================="
    echo "Installation Summary"
    echo "=========================================="
    
    if [[ ${#installed[@]} -gt 0 ]]; then
        echo -e "${GREEN}Successfully installed Rust projects (${#installed[@]}):${NC}"
        for project in "${installed[@]}"; do
            echo -e "  ${GREEN}✓${NC} $project"
        done
    fi
    
    if [[ ${#failed[@]} -gt 0 ]]; then
        echo ""
        echo -e "${RED}Failed to install Rust projects (${#failed[@]}):${NC}"
        for project in "${failed[@]}"; do
            echo -e "  ${RED}✗${NC} $project"
        done
    fi
    
    # Show additional components summary
    if [[ ${#ADDITIONAL_SUCCEEDED[@]} -gt 0 || ${#ADDITIONAL_FAILED[@]} -gt 0 ]]; then
        echo ""
        echo "Additional Components:"
        
        if [[ ${#ADDITIONAL_SUCCEEDED[@]} -gt 0 ]]; then
            for component in "${ADDITIONAL_SUCCEEDED[@]}"; do
                echo -e "  ${GREEN}✓${NC} $component"
            done
        fi
        
        if [[ ${#ADDITIONAL_FAILED[@]} -gt 0 ]]; then
            for component in "${ADDITIONAL_FAILED[@]}"; do
                echo -e "  ${RED}✗${NC} $component"
            done
        fi
    fi
    
    echo ""
    echo "Installation path: ${PREFIX}/bin"
    
    # Check if PREFIX/bin is in PATH
    if [[ ":$PATH:" != *":${PREFIX}/bin:"* ]]; then
        echo ""
        echo -e "${YELLOW}Note: ${PREFIX}/bin is not in your PATH${NC}"
        echo "Add the following line to your shell configuration file:"
        echo "  export PATH=\"${PREFIX}/bin:\$PATH\""
    fi
    
    # Exit with error if any installations failed
    if [[ ${#failed[@]} -gt 0 || ${#ADDITIONAL_FAILED[@]} -gt 0 ]]; then
        exit 1
    fi
    
    echo ""
    echo -e "${GREEN}All installations completed successfully!${NC}"
}

# Run main function with all arguments
main "$@"
