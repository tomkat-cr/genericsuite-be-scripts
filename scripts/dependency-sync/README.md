# Dependency Sync Tool

This tool automatically synchronizes Python dependencies from Poetry `pyproject.toml` files to Docker `pip install` commands in Dockerfiles.

## Overview

The dependency sync tool consists of:
- `sync_dependencies.py` - Main Python implementation
- `sync_dependencies.sh` - Bash wrapper script for easy integration
- Supporting modules for TOML parsing, version translation, and Dockerfile updating

## Usage

### Bash Wrapper (Recommended)

The bash wrapper provides convenient defaults and integration with the project structure:

```bash
# Use default file paths (recommended for this project)
deploy/dependency-sync/sync_dependencies.sh --defaults

# Specify custom files
deploy/dependency-sync/sync_dependencies.sh server/pyproject.toml deploy/docker_images/Dockerfile

# Multiple source files
deploy/dependency-sync/sync_dependencies.sh server/pyproject.toml mcp-server/pyproject.toml deploy/docker_images/Dockerfile

# Dry run to see what would be changed
deploy/dependency-sync/sync_dependencies.sh --dry-run --defaults

# Verbose output for debugging
deploy/dependency-sync/sync_dependencies.sh --verbose --defaults

# Quiet mode for CI/CD
deploy/dependency-sync/sync_dependencies.sh --quiet --defaults
```

### Python Script (Direct)

You can also call the Python script directly:

```bash
cd deploy/dependency-sync
python sync_dependencies.py server/pyproject.toml mcp-server/pyproject.toml ../docker_images/Dockerfile
```

### Integration with Deployment

The tool is integrated with the deployment workflow:

```bash
# From the deploy directory
make sync-deps

# The build process automatically runs dependency sync
make build
```

## Default File Paths

When using `--defaults`, the tool looks for:
- **Server pyproject.toml**: `server/pyproject.toml`
- **MCP Server pyproject.toml**: `mcp-server/pyproject.toml`
- **Target Dockerfile**: `deploy/docker_images/Dockerfile`

All paths are resolved relative to the project root.

## Features

### Version Constraint Translation

The tool translates Poetry version constraints to pip-compatible format:

- `^1.2.3` → `>=1.2.3,<2.0.0` (caret constraints)
- `~1.2.3` → `>=1.2.3,<1.3.0` (tilde constraints)
- `>=1.2.3` → `>=1.2.3` (minimum version)
- `==1.2.3` → `==1.2.3` (exact version)
- `1.2.3` → `==1.2.3` (implicit exact)

### Dependency Merging

When multiple `pyproject.toml` files are specified:
- Dependencies are merged into a unified list
- Conflicts are resolved by choosing the most restrictive constraint
- Warnings are shown for conflicting constraints

### Extras Support

Dependencies with extras are properly handled:
- `uvicorn[standard]^0.24.0` → `uvicorn[standard]>=0.24.0,<0.25.0`

### Safety Features

- **Automatic backups**: Original Dockerfile is backed up before changes
- **Dry run mode**: See what would be changed without making modifications
- **Validation**: All files are validated before processing
- **Error handling**: Clear error messages and appropriate exit codes

## Options

### Bash Wrapper Options

- `-h, --help` - Show help message
- `-v, --verbose` - Enable verbose output
- `-q, --quiet` - Enable quiet mode
- `--dry-run` - Show changes without applying them
- `--no-backup` - Skip creating backup files
- `--defaults` - Use default file paths
- `--list-defaults` - Show default file paths

### Python Script Options

- `-v, --verbose` - Enable verbose output
- `-q, --quiet` - Enable quiet mode
- `--dry-run` - Show changes without applying them
- `--no-backup` - Skip creating backup files

## Examples

### Basic Usage

```bash
# Sync dependencies using defaults
deploy/dependency-sync/sync_dependencies.sh --defaults
```

### Custom Files

```bash
# Sync specific files
deploy/dependency-sync/sync_dependencies.sh \
    custom/pyproject.toml \
    another/pyproject.toml \
    docker/Dockerfile
```

### Development Workflow

```bash
# Check what would change
deploy/dependency-sync/sync_dependencies.sh --dry-run --verbose --defaults

# Apply changes
deploy/dependency-sync/sync_dependencies.sh --defaults

# Build with updated dependencies
cd deploy && make build
```

### CI/CD Integration

```bash
# Quiet mode for automated builds
deploy/dependency-sync/sync_dependencies.sh --quiet --defaults
if [ $? -eq 0 ]; then
    echo "Dependencies synchronized successfully"
else
    echo "Dependency sync failed"
    exit 1
fi
```

## Error Handling

The tool provides clear error messages and appropriate exit codes:

- **Exit code 0**: Success
- **Exit code 1**: General error (file not found, parsing error, etc.)
- **Exit code 130**: Interrupted by user (Ctrl+C)

Common error scenarios:
- Missing `pyproject.toml` files
- Malformed TOML syntax
- Missing or unwritable Dockerfile
- Invalid version constraints
- Permission errors

## Integration Points

### Makefile Integration

The tool is integrated into the deployment Makefile:

```makefile
# Synchronize dependencies
sync-deps:
    dependency-sync/sync_dependencies.sh --defaults
```

### Build Script Integration

The Docker build script automatically runs dependency sync:

```bash
# In deploy/docker_images/build_docker_images.sh
../dependency-sync/sync_dependencies.sh --defaults
```

### Project Structure

```
deploy/
├── dependency-sync/
│   ├── sync_dependencies.py      # Main Python script
│   ├── sync_dependencies.sh      # Bash wrapper
│   ├── README.md                 # This file
│   ├── toml_parser.py           # TOML parsing module
│   ├── version_translator.py    # Version constraint translation
│   ├── dependency_merger.py     # Dependency merging logic
│   ├── dockerfile_updater.py    # Dockerfile manipulation
│   ├── cli_interface.py         # Command-line interface
│   ├── data_types.py           # Data models
│   ├── exceptions.py           # Custom exceptions
│   └── tests/                  # Test suite
├── docker_images/
│   ├── Dockerfile              # Target Dockerfile
│   └── build_docker_images.sh  # Build script (with integration)
└── Makefile                    # Deployment commands (with sync-deps)
```

## Troubleshooting

### Common Issues

1. **"Python script not found"**
   - Make sure you're running from the correct directory
   - Check that `sync_dependencies.py` exists and is executable

2. **"Project root not found"**
   - The tool looks for `pyproject.toml`, `package.json`, or `.git` to find project root
   - Run from within the project directory

3. **"File not found" errors**
   - Check that the specified files exist
   - Use `--list-defaults` to see expected file locations
   - Use absolute paths if needed

4. **Permission errors**
   - Ensure you have read access to source files
   - Ensure you have write access to the target Dockerfile
   - Check file permissions with `ls -la`

### Debug Mode

Use verbose mode to see detailed processing information:

```bash
deploy/dependency-sync/sync_dependencies.sh --verbose --defaults
```

This will show:
- File paths being processed
- Dependencies found in each file
- Version constraint translations
- Merge operations and conflict resolutions
- Dockerfile update operations

### Manual Recovery

If something goes wrong, backups are automatically created:

```bash
# Find the backup file
ls -la deploy/docker_images/Dockerfile.backup_*

# Restore from backup
cp deploy/docker_images/Dockerfile.backup_YYYYMMDD_HHMMSS deploy/docker_images/Dockerfile
```

### Advanced Troubleshooting

#### Version Constraint Issues

If you encounter version constraint translation errors:

```bash
# Check the specific constraint causing issues
grep -n "problematic-package" server/pyproject.toml mcp-server/pyproject.toml

# Test constraint translation manually
python -c "
from version_translator import VersionTranslator
vt = VersionTranslator()
print(vt.translate_poetry_to_pip('^1.2.3'))
"
```

#### Dockerfile Format Issues

If the tool can't find or update the pip install block:

1. Ensure your Dockerfile has a pip install command in this format:
   ```dockerfile
   RUN pip install --upgrade pip && pip install --no-cache-dir \
       "package1>=1.0.0" \
       "package2>=2.0.0"
   ```

2. Check for unsupported formats:
   ```bash
   # This format is NOT supported
   RUN pip install package1 package2
   
   # This format IS supported
   RUN pip install --upgrade pip && pip install --no-cache-dir \
       "package1" \
       "package2"
   ```

#### Dependency Conflict Resolution

When conflicts are detected, the tool chooses the most restrictive constraint:

```bash
# Example conflict resolution
# server/pyproject.toml: fastapi = "^0.100.0"
# mcp-server/pyproject.toml: fastapi = "^0.95.0"
# Result: fastapi>=0.100.0,<0.101.0 (more restrictive)
```

To resolve conflicts manually:
1. Review the conflict warnings in verbose output
2. Update one of the pyproject.toml files to use compatible constraints
3. Re-run the sync tool

#### Testing Your Changes

After running the dependency sync:

```bash
# Test that the Dockerfile builds successfully
cd deploy/docker_images
docker build -t test-build .

# Check the installed packages match expectations
docker run --rm test-build pip list | grep -E "(fastapi|uvicorn|pydantic)"
```

## Performance Considerations

For large projects with many dependencies:

- The tool processes files sequentially and is typically fast (< 5 seconds)
- Memory usage is minimal as files are processed one at a time
- Network access is not required (only local file operations)

## Security Considerations

- The tool only reads pyproject.toml files and writes to the specified Dockerfile
- No external network requests are made
- File permissions are preserved
- Backups prevent accidental data loss

## Contributing

To contribute to the dependency sync tool:

1. Run the test suite: `python run_tests.py`
2. Add tests for new functionality
3. Update documentation for any changes
4. Follow the existing code style and patterns

## Version History

- **v1.0**: Initial implementation with basic Poetry to pip translation
- **v1.1**: Added support for extras syntax and conflict resolution
- **v1.2**: Enhanced error handling and backup functionality
- **v1.3**: Added bash wrapper and integration with deployment scripts