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

Install all c2rust-* Rust projects from the script directory.

OPTIONS:
    --prefix=PATH       Specify installation prefix (default: ${DEFAULT_PREFIX})
    --help              Display this help message

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
    valid Cargo.toml file.

    The binaries will be installed to <prefix>/bin

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --prefix=*)
                PREFIX="${1#*=}"
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
    projects=()
    while IFS= read -r project; do
        projects+=("$project")
    done < <(find_projects)
    
    if [[ ${#projects[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No c2rust-* projects found in ${SCRIPT_DIR}${NC}"
        echo "Expected to find directories starting with 'c2rust-' containing Cargo.toml files"
        exit 0
    fi
    
    echo -e "${GREEN}Found ${#projects[@]} project(s):${NC}"
    for project in "${projects[@]}"; do
        echo "  - $(basename "$project")"
    done
    echo ""
    
    # Install each project
    local installed=()
    local failed=()
    
    for project in "${projects[@]}"; do
        if install_project "$project"; then
            installed+=("$(basename "$project")")
        else
            failed+=("$(basename "$project")")
        fi
        echo ""
    done
    
    # Summary
    echo "=========================================="
    echo "Installation Summary"
    echo "=========================================="
    
    if [[ ${#installed[@]} -gt 0 ]]; then
        echo -e "${GREEN}Successfully installed (${#installed[@]}):${NC}"
        for project in "${installed[@]}"; do
            echo -e "  ${GREEN}✓${NC} $project"
        done
    fi
    
    if [[ ${#failed[@]} -gt 0 ]]; then
        echo ""
        echo -e "${RED}Failed to install (${#failed[@]}):${NC}"
        for project in "${failed[@]}"; do
            echo -e "  ${RED}✗${NC} $project"
        done
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
    if [[ ${#failed[@]} -gt 0 ]]; then
        exit 1
    fi
    
    echo ""
    echo -e "${GREEN}All installations completed successfully!${NC}"
}

# Run main function with all arguments
main "$@"
