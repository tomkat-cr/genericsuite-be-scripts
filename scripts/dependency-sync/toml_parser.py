"""
TOML Parser Module

Handles reading and parsing pyproject.toml files to extract Poetry
dependencies.

This module provides functionality to parse Poetry project files and extract
dependency information in a format suitable for further processing. It handles
various dependency specification formats including simple version constraints,
complex specifications with extras, and error cases.

Example:
    Basic usage:

    >>> parser = TOMLParser()
    >>> deps = parser.parse_pyproject_file('pyproject.toml')
    >>> print(deps)
    {'fastapi': '^0.100.0', 'uvicorn[standard]': '^0.24.0'}

    Error handling:

    >>> try:
    ...     deps = parser.parse_pyproject_file('missing.toml')
    ... except TOMLParsingError as e:
    ...     print(f"Parse error: {e}")

Classes:
    TOMLParser: Main parser class for pyproject.toml files
"""
import re
import tomllib
from pathlib import Path
from typing import Dict, Any
from exceptions import TOMLParsingError


class TOMLParser:
    """
    Parser for pyproject.toml files to extract Poetry dependencies.

    This class handles the parsing of Poetry project files and extraction of
    dependency information. It supports various dependency formats including
    simple version constraints, complex specifications with extras, and
    provides comprehensive error handling.

    The parser specifically looks for the [tool.poetry.dependencies] section
    and extracts all dependencies except the Python version constraint.

    Example:
        >>> parser = TOMLParser()
        >>> dependencies = parser.parse_pyproject_file('server/pyproject.toml')
        >>> for name, constraint in dependencies.items():
        ...     print(f"{name}: {constraint}")
        fastapi: ^0.100.0
        uvicorn[standard]: ^0.24.0
    """

    def __init__(self) -> None:
        """
        Initialize the TOML parser.

        No configuration is required for the parser as it uses standard
        library components and follows Poetry conventions.
        """
        pass

    def parse_pyproject_file(self, file_path: str) -> Dict[str, str]:
        """
        Parse a pyproject.toml file and extract Poetry dependencies.

        Reads the specified pyproject.toml file, parses its TOML content,
        and extracts all dependencies from the [tool.poetry.dependencies]
        section. The Python version constraint is automatically excluded.

        Args:
            file_path (str): Path to the pyproject.toml file to parse.
                Can be relative or absolute path.

        Returns:
            Dict[str, str]: Dictionary mapping dependency names to their
                version constraints. For dependencies with extras, the key
                includes the extras in brackets (e.g., 'uvicorn[standard]').

        Raises:
            TOMLParsingError: If the file cannot be read, contains invalid
                TOML syntax, or has malformed dependency sections.

        Example:
            >>> parser = TOMLParser()
            >>> deps = parser.parse_pyproject_file('server/pyproject.toml')
            >>> print(deps)
            {
                'fastapi': '^0.100.0',
                'uvicorn[standard]': '^0.24.0',
                'pydantic': '>=2.0.0'
            }
        """
        try:
            # Check if file exists
            path = Path(file_path)
            if not path.exists():
                raise TOMLParsingError(
                    f"File not found: {file_path}",
                    file_path=file_path
                )

            # Read and parse TOML file
            with open(path, 'rb') as f:
                toml_data = tomllib.load(f)

            # Extract dependencies from parsed data

            # From [tool.poetry.dependencies] section
            result = self.extract_poetry_dependencies(toml_data)
            # From [project.dependencies] section
            result.update(self.extract_uv_dependencies(toml_data))
            return result

        except FileNotFoundError:
            raise TOMLParsingError(
                f"File not found: {file_path}",
                file_path=file_path
            )
        except PermissionError:
            raise TOMLParsingError(
                f"Permission denied reading file: {file_path}",
                file_path=file_path
            )
        except tomllib.TOMLDecodeError as e:
            raise TOMLParsingError(
                f"Invalid TOML format: {str(e)}",
                file_path=file_path
            )
        except Exception as e:
            raise TOMLParsingError(
                f"Unexpected error parsing TOML file: {str(e)}",
                file_path=file_path
            )

    def extract_poetry_dependencies(self, toml_data: Dict[str, Any]
                                    ) -> Dict[str, str]:
        """
        Extract dependencies from parsed TOML data.

        Navigates through the TOML data structure to find the Poetry
        dependencies section and extracts all dependency specifications.
        Handles both simple string constraints and complex dictionary
        specifications with extras.

        Args:
            toml_data (Dict[str, Any]): Parsed TOML data as a nested dictionary
                structure, typically from tomllib.load().

        Returns:
            Dict[str, str]: Dictionary mapping dependency names to version
                constraints. Dependencies with extras are formatted as
                'package[extra1,extra2]': 'version_constraint'.

        Raises:
            TOMLParsingError: If the dependency section structure is invalid
                or contains malformed data.

        Example:
            Given TOML data with:
            [tool.poetry.dependencies]
            fastapi = "^0.100.0"
            uvicorn = {extras = ["standard"], version = "^0.24.0"}

            Returns:
            {
                'fastapi': '^0.100.0',
                'uvicorn[standard]': '^0.24.0'
            }
        """
        try:
            # Navigate to [tool.poetry.dependencies] section
            tool_section = toml_data.get('tool', {})
            if not isinstance(tool_section, dict):
                raise TOMLParsingError("Invalid 'tool' section format")

            poetry_section = tool_section.get('poetry', {})
            if not isinstance(poetry_section, dict):
                # No [tool.poetry] section found - return empty dict (not an error)
                return {}

            dependencies_section = poetry_section.get('dependencies', {})
            if not isinstance(dependencies_section, dict):
                raise TOMLParsingError("Invalid 'dependencies' section format")

            # Extract dependencies, excluding Python version
            dependencies = {}
            for name, constraint in dependencies_section.items():
                # Skip Python version constraint
                if name.lower() == 'python':
                    continue

                # Handle different constraint formats
                if isinstance(constraint, str):
                    dependencies[name] = constraint
                elif isinstance(constraint, dict):
                    # Handle complex dependency specifications like:
                    # uvicorn = {extras = ["standard"], version = "^0.24.0"}
                    version = constraint.get('version', '*')
                    extras = constraint.get('extras', [])

                    if extras:
                        # Format with extras: uvicorn[standard]
                        extras_str = ','.join(extras)
                        dependencies[f"{name}[{extras_str}]"] = version
                    else:
                        dependencies[name] = version
                else:
                    # Convert other types to string
                    dependencies[name] = str(constraint)

            return dependencies

        except KeyError as e:
            raise TOMLParsingError(f"Missing required section: {str(e)}")
        except TypeError as e:
            raise TOMLParsingError(
                f"Invalid data type in dependencies section: {str(e)}")
        except Exception as e:
            raise TOMLParsingError(f"Error extracting dependencies: {str(e)}")

    def extract_uv_dependencies(self, toml_data: Dict[str, Any]
                                ) -> Dict[str, str]:
        """
        Extract dependencies from parsed TOML data.

        Navigates through the TOML data structure to find the Uv
        project.dependencies section and extracts all dependency specifications.
        Handles both simple string constraints and complex dictionary
        specifications with extras.

        Args:
            toml_data (Dict[str, Any]): Parsed TOML data as a nested dictionary
                structure, typically from tomllib.load().

        Returns:
            Dict[str, str]: Dictionary mapping dependency names to version
                constraints. Dependencies with extras are formatted as
                'package[extra1,extra2]': 'version_constraint'.

        Raises:
            TOMLParsingError: If the dependency section structure is invalid
                or contains malformed data.

        Example:
            Given TOML data with:

            [project]
            requires-python = ">=3.10,<4.0"
            dependencies = [
                "fastapi>=0.121.3",
                "fastapi-cors>=0.0.6,<0.1.0",
                "uvicorn[standard]>=0.38.0",
                "genericsuite-ai=0.2.0"
            ]

            Returns:
            {
                'fastapi': '^0.121.3',
                'fastapi-cors': '^0.0.6',
                'uvicorn[standard]': '^0.38.0',
                'genericsuite-ai': '0.2.0'
            }

            Given TOML data with:

            [project]
            requires-python = ">=3.10,<4.0"
            dependencies = [
                "fastapi>=0.121.3",
                "genericsuite"
            ]

            Raises:
                TOMLParsingError: If any dependency does not have a version constraint.

        """
        try:
            # Navigate to [project.dependencies] section
            project_section = toml_data.get('project', {})
            if not isinstance(project_section, dict):
                raise TOMLParsingError("Invalid 'project' section format")

            dependencies_section = project_section.get('dependencies', [])
            if not isinstance(dependencies_section, list):
                # No [project.dependencies] section found - return empty dict (not an error)
                return {}

            # Extract dependencies, excluding Python version
            dependencies = {}
            for dependency in dependencies_section:
                # Regex to capture common Python dependency constraint operators
                # This regex looks for '==', '!=', '<=', '>=', '<', '>', '~='
                # It's designed to be used with re.search or re.findall on a dependency string.
                _CONSTRAINT_OPERATOR_REGEX = r"(==|!=|<=|>=|<|>|~=)"
                constraint_operator = re.search(
                    _CONSTRAINT_OPERATOR_REGEX, dependency)

                if not constraint_operator:
                    raise TOMLParsingError(
                        f"Dependency '{dependency}' must have a version constraint")

                operator = constraint_operator.group()
                name = dependency.split(operator)[0].strip()
                constraint = dependency.split(operator)[1].strip()

                # Skip Python version constraint
                if name.lower() == 'python':
                    continue

                if operator in ('>=', '>'):
                    target_operator = '^'
                elif operator == '=':
                    target_operator = ''  # Exact match, version only
                else:
                    target_operator = operator

                # Handle different constraint formats
                if isinstance(constraint, str):
                    dependencies[name] = f"{target_operator}{constraint}"
                else:
                    dependencies[name] = str(constraint)

            return dependencies

        except KeyError as e:
            raise TOMLParsingError(f"Missing required section: {str(e)}")
        except TypeError as e:
            raise TOMLParsingError(
                f"Invalid data type in dependencies section: {str(e)}")
        except Exception as e:
            raise TOMLParsingError(f"Error extracting dependencies: {str(e)}")
