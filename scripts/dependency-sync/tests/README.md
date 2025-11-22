# Dependency Sync Test Suite

This directory contains comprehensive tests for the dependency sync functionality.

## Test Structure

```
tests/
├── README.md                    # This file
├── conftest.py                  # Shared pytest fixtures
├── test_utils.py               # Test utilities and helpers
├── fixtures/                   # Test fixture files
│   ├── valid_pyproject.toml    # Standard valid pyproject.toml
│   ├── complex_pyproject.toml  # Complex dependencies with various constraint types
│   ├── edge_case_pyproject.toml # Edge cases and special characters
│   ├── conflicting_pyproject*.toml # Files with conflicting dependencies
│   ├── malformed.toml          # Invalid TOML for error testing
│   ├── valid_dockerfile        # Standard Dockerfile format
│   ├── multiline_dockerfile    # Multi-line pip install format
│   ├── single_line_dockerfile  # Single line pip install format
│   └── no_pip_dockerfile       # Dockerfile without pip install
├── test_toml_parser.py         # Unit tests for TOML parsing
├── test_version_translator.py  # Unit tests for version translation
├── test_dependency_merger.py   # Unit tests for dependency merging
├── test_dockerfile_updater.py  # Unit tests for Dockerfile updating
├── test_cli_interface.py       # Unit tests for CLI interface
├── test_data_types.py          # Unit tests for data models
└── test_integration.py         # Integration tests for complete workflow
```

## Running Tests

### Quick Start

```bash
# Run all tests
python -m pytest

# Run with verbose output
python -m pytest -v

# Run specific test file
python -m pytest tests/test_integration.py

# Run specific test
python -m pytest tests/test_integration.py::TestDependencySyncIntegration::test_complete_sync_workflow
```

### Using the Test Runner

```bash
# Run all tests
python run_tests.py

# Run only unit tests
python run_tests.py --unit

# Run only integration tests
python run_tests.py --integration

# Run with coverage
python run_tests.py --coverage

# Run tests matching a pattern
python run_tests.py -k "test_version"

# Run with verbose output
python run_tests.py --verbose
```

### Test Categories

Tests are organized with pytest markers:

- `@pytest.mark.unit`: Unit tests for individual components
- `@pytest.mark.integration`: End-to-end integration tests
- `@pytest.mark.slow`: Tests that take longer to run
- `@pytest.mark.error_handling`: Tests focused on error scenarios

```bash
# Run only unit tests
python -m pytest -m unit

# Run only integration tests
python -m pytest -m integration

# Run all except slow tests
python -m pytest -m "not slow"

# Run error handling tests
python -m pytest -m error_handling
```

## Test Coverage

The test suite covers all requirements from the specification:

### Requirement 1: Poetry Dependency Parsing
- ✅ `test_toml_parser.py`: TOML file parsing
- ✅ `test_integration.py`: Multiple file parsing
- ✅ Dependency extraction and merging
- ✅ Version constraint handling
- ✅ Extras syntax support

### Requirement 2: Poetry to Pip Translation
- ✅ `test_version_translator.py`: All constraint types
- ✅ Caret constraints (`^1.2.3` → `>=1.2.3,<2.0.0`)
- ✅ Tilde constraints (`~1.2.3` → `>=1.2.3,<1.3.0`)
- ✅ Exact versions and ranges
- ✅ Extras preservation

### Requirement 3: Dockerfile Update Automation
- ✅ `test_dockerfile_updater.py`: Dockerfile manipulation
- ✅ `test_integration.py`: End-to-end updates
- ✅ Pattern matching and replacement
- ✅ Format preservation
- ✅ Multi-line handling

### Requirement 4: Configuration and Flexibility
- ✅ `test_cli_interface.py`: Command-line arguments
- ✅ `test_data_types.py`: Configuration validation
- ✅ Multiple source files
- ✅ Path validation
- ✅ Error handling

### Requirement 5: Error Handling and Validation
- ✅ `test_integration.py`: Error scenarios
- ✅ File not found handling
- ✅ Malformed TOML handling
- ✅ Invalid Dockerfile handling
- ✅ Conflict resolution

### Requirement 6: Command Line and Script Integration
- ✅ `test_cli_interface.py`: CLI functionality
- ✅ Exit codes and output modes
- ✅ Verbose and quiet modes
- ✅ Integration testing

### Requirement 7: File Organization and Deployment
- ✅ `test_integration.py`: Path resolution
- ✅ Script integration
- ✅ Deployment workflow testing

## Test Fixtures

### pyproject.toml Fixtures

- **valid_pyproject.toml**: Standard Poetry dependencies
- **complex_pyproject.toml**: Various constraint types and extras
- **edge_case_pyproject.toml**: Special characters and edge cases
- **conflicting_pyproject*.toml**: Files with version conflicts
- **empty_dependencies.toml**: Minimal dependencies
- **malformed.toml**: Invalid TOML syntax

### Dockerfile Fixtures

- **valid_dockerfile**: Standard multi-line pip install
- **multiline_dockerfile**: Complex multi-line format
- **single_line_dockerfile**: Single line pip install
- **multiple_pip_dockerfile**: Multiple pip install commands
- **no_pip_dockerfile**: No pip install commands

## Integration Test Scenarios

The integration tests cover comprehensive real-world scenarios:

1. **Complete Workflow**: End-to-end dependency sync
2. **Multiple Files**: Merging dependencies from multiple sources
3. **Conflict Resolution**: Handling version conflicts
4. **Error Recovery**: Graceful handling of failures
5. **Format Validation**: Ensuring correct pip format output
6. **Performance**: Testing with large dependency sets
7. **Edge Cases**: Special characters and complex constraints
8. **Backup and Recovery**: File backup functionality

## Test Utilities

The `test_utils.py` module provides:

- **FileManager**: Temporary file and directory management
- **Assertion Helpers**: Dockerfile content validation
- **Mock Objects**: Test doubles for complex scenarios
- **Test Data**: Common test constants and fixtures

## Error Testing

Error scenarios are thoroughly tested:

- Malformed TOML files
- Missing source files
- Invalid Dockerfile formats
- Permission errors
- Version constraint conflicts
- Partial processing failures

## Performance Testing

Performance tests ensure the tool scales:

- Large dependency sets (50+ packages)
- Multiple source files (10+ files)
- Complex constraint resolution
- Processing time validation

## Continuous Integration

The test suite is designed for CI/CD integration:

- Fast unit tests for quick feedback
- Comprehensive integration tests
- Clear exit codes and output
- Coverage reporting support
- Parallel test execution support

## Adding New Tests

When adding new functionality:

1. Add unit tests for individual components
2. Add integration tests for end-to-end scenarios
3. Create appropriate fixtures if needed
4. Update this documentation
5. Ensure all requirements are covered

### Test Naming Convention

- Unit tests: `test_<component>_<functionality>`
- Integration tests: `test_<scenario>_<expected_outcome>`
- Error tests: `test_<error_condition>_handling`
- Performance tests: `test_performance_<scenario>`

### Fixture Naming Convention

- Valid scenarios: `<type>_<description>`
- Error scenarios: `<error_type>_<description>`
- Complex scenarios: `complex_<description>`
- Edge cases: `edge_case_<description>`