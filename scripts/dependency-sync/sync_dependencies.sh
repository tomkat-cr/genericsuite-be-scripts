#!/bin/bash

# Dependency Sync Bash Wrapper Script
#
# This script provides a convenient bash wrapper around the Python dependency
# synchronization tool. It handles default file path resolution and provides
# easy integration with deployment workflows.

set -euo pipefail

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="${SCRIPT_DIR}/sync_dependencies.py"

# Default file paths (relative to project root)
DEFAULT_SERVER_PYPROJECT="server/pyproject.toml"
DEFAULT_MCP_PYPROJECT="mcp-server/pyproject.toml"
DEFAULT_DOCKERFILE="deploy/docker_images/Dockerfile-Python"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [SOURCE_FILES...] [TARGET_DOCKERFILE]

Synchronize Poetry dependencies from pyproject.toml files to Dockerfile pip install commands.

ARGUMENTS:
    SOURCE_FILES        One or more pyproject.toml files (optional, uses defaults if not provided)
    TARGET_DOCKERFILE   Target Dockerfile to update (optional, uses default if not provided)

OPTIONS:
    -h, --help          Show this help message and exit
    -v, --verbose       Enable verbose output with detailed processing information
    -q, --quiet         Enable quiet mode with minimal output
    --dry-run           Show what would be done without making actual changes
    --no-backup         Skip creating backup of the original Dockerfile
    --defaults          Use default file paths for common project structures
    --list-defaults     Show default file paths and exit

DEFAULT FILE PATHS:
    Server pyproject.toml:     ${DEFAULT_SERVER_PYPROJECT}
    MCP Server pyproject.toml: ${DEFAULT_MCP_PYPROJECT}
    Target Dockerfile:         ${DEFAULT_DOCKERFILE}

EXAMPLES:
    # Use default file paths
    $(basename "$0") --defaults

    # Specify custom files
    $(basename "$0") server/pyproject.toml deploy/docker_images/Dockerfile

    # Multiple source files with verbose output
    $(basename "$0") -v server/pyproject.toml mcp-server/pyproject.toml deploy/docker_images/Dockerfile

    # Dry run to see what would be changed
    $(basename "$0") --dry-run --defaults

    # Quiet mode for CI/CD integration
    $(basename "$0") -q --defaults

EOF
}

# Function to show default paths
show_defaults() {
    echo "Default file paths (relative to project root):"
    echo "  Server pyproject.toml:     ${DEFAULT_SERVER_PYPROJECT}"
    echo "  MCP Server pyproject.toml: ${DEFAULT_MCP_PYPROJECT}"
    echo "  Target Dockerfile:         ${DEFAULT_DOCKERFILE}"
}

# Function to find project root
find_project_root() {
    local current_dir="$PWD"
    
    # Look for the main project root indicators (prioritize .git and main package.json)
    while [[ "$current_dir" != "/" ]]; do
        # Check for .git directory (most reliable indicator of project root)
        if [[ -d "$current_dir/.git" ]]; then
            echo "$current_dir"
            return 0
        fi
        
        # Check for main package.json (not in node_modules)
        if [[ -f "$current_dir/package.json" ]] && [[ ! "$current_dir" =~ node_modules ]]; then
            # Additional check: make sure this looks like the main project
            if [[ -d "$current_dir/server" ]] || [[ -d "$current_dir/deploy" ]] || [[ -d "$current_dir/ui" ]]; then
                echo "$current_dir"
                return 0
            fi
        fi
        
        current_dir="$(dirname "$current_dir")"
    done
    
    # Fallback: look for pyproject.toml but prefer higher-level directories
    current_dir="$PWD"
    while [[ "$current_dir" != "/" ]]; do
        if [[ -f "$current_dir/pyproject.toml" ]]; then
            # Check if this looks like the main project root
            if [[ -d "$current_dir/server" ]] || [[ -d "$current_dir/deploy" ]] || [[ -d "$current_dir/ui" ]]; then
                echo "$current_dir"
                return 0
            fi
        fi
        current_dir="$(dirname "$current_dir")"
    done
    
    # If no project root found, use current directory
    echo "$PWD"
}

# Function to resolve file paths relative to project root
resolve_path() {
    local file_path="$1"
    local project_root="$2"
    
    # If path is absolute, use as-is
    if [[ "$file_path" = /* ]]; then
        echo "$file_path"
        return 0
    fi
    
    # If path is relative, resolve from project root
    local resolved_path="${project_root}/${file_path}"
    echo "$resolved_path"
}

# Function to check if file exists and is readable
check_file_exists() {
    local file_path="$1"
    local file_type="$2"
    
    if [[ ! -f "$file_path" ]]; then
        print_error "${file_type} not found: $file_path"
        return 1
    fi
    
    if [[ ! -r "$file_path" ]]; then
        print_error "${file_type} is not readable: $file_path"
        return 1
    fi
    
    return 0
}

# Function to check if Python script exists
check_python_script() {
    if [[ ! -f "$PYTHON_SCRIPT" ]]; then
        print_error "Python script not found: $PYTHON_SCRIPT"
        print_error "Make sure you're running this script from the correct location."
        return 1
    fi
    
    if [[ ! -x "$PYTHON_SCRIPT" ]]; then
        print_warning "Python script is not executable, attempting to make it executable..."
        chmod +x "$PYTHON_SCRIPT" || {
            print_error "Failed to make Python script executable: $PYTHON_SCRIPT"
            return 1
        }
    fi
    
    return 0
}

# Main function
main() {
    local use_defaults=false
    local python_args=()
    local source_files=()
    local target_dockerfile=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            --list-defaults)
                show_defaults
                exit 0
                ;;
            --defaults)
                use_defaults=true
                shift
                ;;
            -v|--verbose|-q|--quiet|--dry-run|--no-backup)
                python_args+=("$1")
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                echo "Use --help for usage information."
                exit 1
                ;;
            *)
                # Positional arguments - collect them for later processing
                if [[ -z "$target_dockerfile" ]]; then
                    # If we haven't set target_dockerfile yet, this could be a source file
                    # We'll determine this later based on file extension or position
                    if [[ "$1" == *.toml ]]; then
                        source_files+=("$1")
                    else
                        # Assume this is the target dockerfile if it's not a .toml file
                        target_dockerfile="$1"
                    fi
                else
                    # If target_dockerfile is already set, this must be an extra argument
                    print_error "Too many arguments. Target Dockerfile already specified: $target_dockerfile"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Find project root
    local project_root
    project_root="$(find_project_root)"
    print_info "Project root: $project_root"
    
    # Handle default file paths
    if [[ "$use_defaults" == true ]]; then
        print_info "Using default file paths..."
        
        # Check which default source files exist
        local server_pyproject
        local mcp_pyproject
        server_pyproject="$(resolve_path "$DEFAULT_SERVER_PYPROJECT" "$project_root")"
        mcp_pyproject="$(resolve_path "$DEFAULT_MCP_PYPROJECT" "$project_root")"
        
        if check_file_exists "$server_pyproject" "Server pyproject.toml"; then
            source_files+=("$server_pyproject")
        fi
        
        if check_file_exists "$mcp_pyproject" "MCP Server pyproject.toml"; then
            source_files+=("$mcp_pyproject")
        fi
        
        # Use default dockerfile
        target_dockerfile="$(resolve_path "$DEFAULT_DOCKERFILE" "$project_root")"
    else
        # If no source files specified and not using defaults, try to find them
        if [[ ${#source_files[@]} -eq 0 ]]; then
            print_info "No source files specified, checking for default files..."
            
            local server_pyproject
            local mcp_pyproject
            server_pyproject="$(resolve_path "$DEFAULT_SERVER_PYPROJECT" "$project_root")"
            mcp_pyproject="$(resolve_path "$DEFAULT_MCP_PYPROJECT" "$project_root")"
            
            if check_file_exists "$server_pyproject" "Server pyproject.toml" 2>/dev/null; then
                source_files+=("$server_pyproject")
                print_info "Found server pyproject.toml: $server_pyproject"
            fi
            
            if check_file_exists "$mcp_pyproject" "MCP Server pyproject.toml" 2>/dev/null; then
                source_files+=("$mcp_pyproject")
                print_info "Found MCP server pyproject.toml: $mcp_pyproject"
            fi
        fi
        
        # If no target dockerfile specified, use default
        if [[ -z "$target_dockerfile" ]]; then
            target_dockerfile="$(resolve_path "$DEFAULT_DOCKERFILE" "$project_root")"
            print_info "Using default Dockerfile: $target_dockerfile"
        else
            # Resolve relative path
            target_dockerfile="$(resolve_path "$target_dockerfile" "$project_root")"
        fi
    fi
    
    # Validate that we have at least one source file
    if [[ ${#source_files[@]} -eq 0 ]]; then
        print_error "No source pyproject.toml files found or specified."
        print_error "Use --help for usage information or --list-defaults to see expected file locations."
        exit 1
    fi
    
    # Resolve all source file paths
    local resolved_source_files=()
    for source_file in "${source_files[@]}"; do
        local resolved_source
        resolved_source="$(resolve_path "$source_file" "$project_root")"
        resolved_source_files+=("$resolved_source")
    done
    
    # Validate all files exist
    print_info "Validating files..."
    
    for source_file in "${resolved_source_files[@]}"; do
        if ! check_file_exists "$source_file" "Source pyproject.toml"; then
            exit 1
        fi
    done
    
    if ! check_file_exists "$target_dockerfile" "Target Dockerfile"; then
        exit 1
    fi
    
    # Check Python script exists
    if ! check_python_script; then
        exit 1
    fi
    
    # Build final command
    local cmd=("$PYTHON_SCRIPT")
    if [[ ${#python_args[@]} -gt 0 ]]; then
        cmd+=("${python_args[@]}")
    fi
    cmd+=("${resolved_source_files[@]}")
    cmd+=("$target_dockerfile")
    
    # Show what we're about to run
    print_info "Running dependency synchronization..."
    if [[ ${#python_args[@]} -gt 0 ]] && ([[ " ${python_args[*]} " =~ " --verbose " ]] || [[ " ${python_args[*]} " =~ " -v " ]]); then
        print_info "Command: ${cmd[*]}"
    fi
    
    # Execute the Python script
    if "${cmd[@]}"; then
        print_success "Dependency synchronization completed successfully!"
        exit 0
    else
        local exit_code=$?
        print_error "Dependency synchronization failed with exit code: $exit_code"
        exit $exit_code
    fi
}

BASE_DIR="$(find_project_root)"
if [ -f "${BASE_DIR}/.env" ]; then
    set -o allexport; . "${BASE_DIR}/.env" ; set +o allexport ;
fi

# Run main function with all arguments
main "$@"