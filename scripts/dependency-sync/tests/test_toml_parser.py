"""
Unit tests for TOMLParser class.
"""

from exceptions import TOMLParsingError
from toml_parser import TOMLParser
import pytest
import tempfile
import os
from pathlib import Path
from unittest.mock import patch, mock_open

import sys
from pathlib import Path

# Add the parent directory to the path so we can import the modules
sys.path.insert(0, str(Path(__file__).parent.parent))


class TestTOMLParser:
    """Test cases for TOMLParser class."""

    def setup_method(self):
        """Set up test fixtures."""
        self.parser = TOMLParser()
        self.fixtures_dir = Path(__file__).parent / "fixtures"

    def test_parse_valid_pyproject_file(self):
        """Test parsing a valid pyproject.toml file."""
        file_path = self.fixtures_dir / "valid_pyproject.toml"

        result = self.parser.parse_pyproject_file(str(file_path))

        expected = {
            "fastapi": "^0.104.1",
            "uvicorn[standard]": "^0.24.0",
            "pydantic": ">=2.0.0",
            "requests": "~2.31.0",
            "click": "8.1.7",
            "numpy": "*"
        }

        assert result == expected

    def test_parse_file_not_found(self):
        """Test parsing a non-existent file."""
        with pytest.raises(TOMLParsingError) as exc_info:
            self.parser.parse_pyproject_file("nonexistent.toml")

        assert "File not found" in str(exc_info.value)
        assert exc_info.value.file_path == "nonexistent.toml"

    def test_parse_malformed_toml(self):
        """Test parsing a malformed TOML file."""
        file_path = self.fixtures_dir / "malformed.toml"

        with pytest.raises(TOMLParsingError) as exc_info:
            self.parser.parse_pyproject_file(str(file_path))

        assert "Invalid TOML format" in str(exc_info.value)
        assert exc_info.value.file_path == str(file_path)

    def test_parse_permission_denied(self):
        """Test parsing a file with permission denied."""
        with tempfile.NamedTemporaryFile(mode='w', delete=False) as f:
            f.write('[tool.poetry.dependencies]\nfastapi = "^0.104.1"')
            temp_path = f.name

        try:
            # Remove read permissions
            os.chmod(temp_path, 0o000)

            with pytest.raises(TOMLParsingError) as exc_info:
                self.parser.parse_pyproject_file(temp_path)

            assert "Permission denied" in str(exc_info.value)
        finally:
            # Restore permissions and clean up
            os.chmod(temp_path, 0o644)
            os.unlink(temp_path)

    def test_extract_dependencies_valid_data(self):
        """Test extracting dependencies from valid TOML data."""
        toml_data = {
            "tool": {
                "poetry": {
                    "dependencies": {
                        "python": "^3.11",
                        "fastapi": "^0.104.1",
                        "uvicorn": {"extras": ["standard"], "version": "^0.24.0"},
                        "pydantic": ">=2.0.0",
                        "requests": "~2.31.0",
                        "click": "8.1.7",
                        "numpy": "*"
                    }
                }
            }
        }

        result = self.parser.extract_poetry_dependencies(toml_data)

        expected = {
            "fastapi": "^0.104.1",
            "uvicorn[standard]": "^0.24.0",
            "pydantic": ">=2.0.0",
            "requests": "~2.31.0",
            "click": "8.1.7",
            "numpy": "*"
        }

        assert result == expected

    def test_extract_dependencies_no_tool_section(self):
        """Test extracting dependencies when no tool section exists."""
        toml_data = {
            "project": {
                "name": "test-project"
            }
        }

        result = self.parser.extract_poetry_dependencies(toml_data)
        assert result == {}

    def test_extract_dependencies_no_poetry_section(self):
        """Test extracting dependencies when no poetry section exists."""
        toml_data = {
            "tool": {
                "black": {
                    "line-length": 88
                }
            }
        }

        result = self.parser.extract_poetry_dependencies(toml_data)
        assert result == {}

    def test_extract_dependencies_no_dependencies_section(self):
        """Test extracting dependencies when no dependencies section exists."""
        toml_data = {
            "tool": {
                "poetry": {
                    "name": "test-project",
                    "version": "0.1.0"
                }
            }
        }

        result = self.parser.extract_poetry_dependencies(toml_data)
        assert result == {}

    def test_extract_dependencies_only_python(self):
        """Test extracting dependencies when only Python version is specified."""
        toml_data = {
            "tool": {
                "poetry": {
                    "dependencies": {
                        "python": "^3.11"
                    }
                }
            }
        }

        result = self.parser.extract_poetry_dependencies(toml_data)
        assert result == {}

    def test_extract_dependencies_complex_extras(self):
        """Test extracting dependencies with multiple extras."""
        toml_data = {
            "tool": {
                "poetry": {
                    "dependencies": {
                        "python": "^3.11",
                        "uvicorn": {"extras": ["standard", "watchfiles"], "version": "^0.24.0"},
                        "sqlalchemy": {"extras": ["asyncio"], "version": ">=2.0.0"}
                    }
                }
            }
        }

        result = self.parser.extract_poetry_dependencies(toml_data)

        expected = {
            "uvicorn[standard,watchfiles]": "^0.24.0",
            "sqlalchemy[asyncio]": ">=2.0.0"
        }

        assert result == expected

    def test_extract_dependencies_dict_without_version(self):
        """Test extracting dependencies with dict format but no version."""
        toml_data = {
            "tool": {
                "poetry": {
                    "dependencies": {
                        "python": "^3.11",
                        "local-package": {"path": "../local-package"}
                    }
                }
            }
        }

        result = self.parser.extract_poetry_dependencies(toml_data)

        expected = {
            "local-package": "*"
        }

        assert result == expected

    def test_extract_dependencies_invalid_tool_section(self):
        """Test extracting dependencies with invalid tool section format."""
        toml_data = {
            "tool": "invalid"
        }

        with pytest.raises(TOMLParsingError) as exc_info:
            self.parser.extract_poetry_dependencies(toml_data)

        assert "Invalid 'tool' section format" in str(exc_info.value)

    def test_extract_dependencies_invalid_dependencies_section(self):
        """Test extracting dependencies with invalid dependencies section format."""
        toml_data = {
            "tool": {
                "poetry": {
                    "dependencies": "invalid"
                }
            }
        }

        with pytest.raises(TOMLParsingError) as exc_info:
            self.parser.extract_poetry_dependencies(toml_data)

        assert "Invalid 'dependencies' section format" in str(exc_info.value)

    def test_extract_dependencies_numeric_constraint(self):
        """Test extracting dependencies with numeric constraints."""
        toml_data = {
            "tool": {
                "poetry": {
                    "dependencies": {
                        "python": "^3.11",
                        "some-package": 1.0
                    }
                }
            }
        }

        result = self.parser.extract_poetry_dependencies(toml_data)

        expected = {
            "some-package": "1.0"
        }

        assert result == expected

    def test_parse_no_poetry_section_file(self):
        """Test parsing a file without poetry section."""
        file_path = self.fixtures_dir / "no_poetry_section.toml"

        result = self.parser.parse_pyproject_file(str(file_path))
        assert result == {}

    def test_parse_no_dependencies_section_file(self):
        """Test parsing a file without dependencies section."""
        file_path = self.fixtures_dir / "no_dependencies_section.toml"

        result = self.parser.parse_pyproject_file(str(file_path))
        assert result == {}

    def test_parse_empty_dependencies_file(self):
        """Test parsing a file with empty dependencies (only Python)."""
        file_path = self.fixtures_dir / "empty_dependencies.toml"

        result = self.parser.parse_pyproject_file(str(file_path))
        assert result == {}


if __name__ == "__main__":
    pytest.main([__file__])
