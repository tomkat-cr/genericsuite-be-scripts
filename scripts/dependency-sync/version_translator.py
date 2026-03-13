"""
Version Translator Module

Converts Poetry version constraints to pip-compatible format.

This module handles the translation of Poetry's semantic versioning constraints
to pip-compatible version specifications. It supports all major Poetry
constraint types including caret (^), tilde (~), exact (==), and range
constraints.

Poetry uses different constraint syntax than pip, so this module bridges that
gap:
- Poetry: ^1.2.3 (compatible release)
- Pip: >=1.2.3,<2.0.0 (equivalent range)

Example:
    Basic usage:

    >>> translator = VersionTranslator()
    >>> pip_constraint = translator.translate_poetry_to_pip('^1.2.3')
    >>> print(pip_constraint)
    '>=1.2.3,<2.0.0'

    With extras:

    >>> full_spec = translator.handle_extras('uvicorn[standard]', '^0.24.0')
    >>> print(full_spec)
    'uvicorn[standard]>=0.24.0,<0.25.0'

Classes:
    VersionTranslator: Main translator class for version constraints
"""

from exceptions import VersionConstraintError


class VersionTranslator:
    """
    Translates Poetry version constraints to pip-compatible format.

    This class provides methods to convert Poetry's semantic versioning
    constraints to pip-compatible version specifications. It handles all
    major constraint types and provides comprehensive error handling.

    Supported constraint types:
    - Caret constraints: ^1.2.3 → >=1.2.3,<2.0.0
    - Tilde constraints: ~1.2.3 → >=1.2.3,<1.3.0
    - Exact constraints: ==1.2.3 → ==1.2.3 (unchanged)
    - Range constraints: >=1.2.3 → >=1.2.3 (unchanged)
    - Bare versions: 1.2.3 → ==1.2.3

    Example:
        >>> translator = VersionTranslator()
        >>> # Caret constraint
        >>> result = translator.translate_poetry_to_pip('^1.2.3')
        >>> print(result)  # '>=1.2.3,<2.0.0'
        >>>
        >>> # Tilde constraint
        >>> result = translator.translate_poetry_to_pip('~1.2.3')
        >>> print(result)  # '>=1.2.3,<1.3.0'
    """

    def __init__(self) -> None:
        """
        Initialize the version translator.

        No configuration is required as the translator uses standard
        semantic versioning rules and Poetry conventions.
        """
        pass

    def translate_poetry_to_pip(self, constraint: str) -> str:
        """
        Convert Poetry version constraint to pip-compatible format.

        This is the main translation method that handles all supported
        Poetry constraint types and converts them to equivalent pip
        version specifications.

        Args:
            constraint (str): Poetry version constraint. Supported formats:
                - Caret: '^1.2.3' (compatible release)
                - Tilde: '~1.2.3' (patch-level changes)
                - Exact: '==1.2.3' or '1.2.3'
                - Range: '>=1.2.3', '<=1.2.3', '<1.2.3'
                - Wildcard: '*' (any version)

        Returns:
            str: Pip-compatible version constraint. Empty string for
                wildcard constraints.

        Raises:
            VersionConstraintError: If the constraint format is invalid
                or cannot be parsed.

        Example:
            >>> translator = VersionTranslator()
            >>> # Caret constraints
            >>> translator.translate_poetry_to_pip('^1.2.3')
            '>=1.2.3,<2.0.0'
            >>> translator.translate_poetry_to_pip('^0.2.3')
            '>=0.2.3,<0.3.0'
            >>>
            >>> # Tilde constraints
            >>> translator.translate_poetry_to_pip('~1.2.3')
            '>=1.2.3,<1.3.0'
            >>>
            >>> # Exact constraints
            >>> translator.translate_poetry_to_pip('1.2.3')
            '==1.2.3'
        """
        if not constraint or constraint == "*":
            return ""

        constraint = constraint.strip()

        # After stripping, check again for empty constraint
        if not constraint:
            return ""

        # Handle exact version constraints (==1.2.3)
        if constraint.startswith("=="):
            return constraint

        # Handle minimum version constraints (>=1.2.3)
        if constraint.startswith(">="):
            return constraint

        # Handle less than constraints (<=1.2.3, <1.2.3)
        if constraint.startswith("<=") or constraint.startswith("<"):
            return constraint

        # Handle caret constraints (^1.2.3)
        if constraint.startswith("^"):
            version = constraint[1:]
            return self.handle_caret_constraint(version)

        # Handle tilde constraints (~1.2.3)
        if constraint.startswith("~"):
            version = constraint[1:]
            return self.handle_tilde_constraint(version)

        # Handle bare version numbers (1.2.3) - treat as exact
        if self._is_valid_version(constraint):
            return f"=={constraint}"

        # If we can't parse it, raise an error
        raise VersionConstraintError(
            f"Invalid version constraint: {constraint}")

    def handle_caret_constraint(self, version: str) -> str:
        """
        Convert caret constraint to pip-compatible range.

        Caret constraints allow changes that do not modify the left-most
        non-zero digit. This implements Poetry's caret constraint semantics:

        - ^1.2.3 := >=1.2.3,<2.0.0 (major version locked)
        - ^0.2.3 := >=0.2.3,<0.3.0 (minor version locked for 0.x)
        - ^0.0.3 := >=0.0.3,<0.0.4 (patch version locked for 0.0.x)

        Args:
            version (str): Version string without the caret prefix.
                Must be a valid semantic version.

        Returns:
            str: Pip-compatible range constraint in the format
                '>=min_version,<max_version'.

        Raises:
            VersionConstraintError: If the version format is invalid.

        Example:
            >>> translator = VersionTranslator()
            >>> translator.handle_caret_constraint('1.2.3')
            '>=1.2.3,<2.0.0'
            >>> translator.handle_caret_constraint('0.2.3')
            '>=0.2.3,<0.3.0'
            >>> translator.handle_caret_constraint('0.0.3')
            '>=0.0.3,<0.0.4'
        """
        if not self._is_valid_version(version):
            raise VersionConstraintError(
                f"Invalid version in caret constraint: {version}")

        parts = version.split('.')

        # Pad with zeros if needed (e.g., "1" -> "1.0.0", "1.2" -> "1.2.0")
        while len(parts) < 3:
            parts.append('0')

        major, minor, patch = parts[0], parts[1], parts[2]

        # Find the left-most non-zero digit and increment appropriately
        if major != '0':
            # ^1.2.3 -> >=1.2.3,<2.0.0
            next_major = str(int(major) + 1)
            return f">={version},<{next_major}.0.0"
        elif minor != '0':
            # ^0.2.3 -> >=0.2.3,<0.3.0
            next_minor = str(int(minor) + 1)
            return f">={version},<0.{next_minor}.0"
        else:
            # ^0.0.3 -> >=0.0.3,<0.0.4
            next_patch = str(int(patch) + 1)
            return f">={version},<0.0.{next_patch}"

    def handle_tilde_constraint(self, version: str) -> str:
        """
        Convert tilde constraint to pip-compatible range.

        Tilde constraints allow patch-level changes if a minor version
        is specified, or minor-level changes if not. This implements
        Poetry's tilde constraint semantics:

        - ~1.2.3 := >=1.2.3,<1.3.0 (patch-level changes allowed)
        - ~1.2 := >=1.2.0,<1.3.0 (patch-level changes allowed)
        - ~1 := >=1.0.0,<2.0.0 (minor and patch changes allowed)

        Args:
            version (str): Version string without the tilde prefix.
                Can be in format 'X', 'X.Y', or 'X.Y.Z'.

        Returns:
            str: Pip-compatible range constraint in the format
                '>=min_version,<max_version'.

        Raises:
            VersionConstraintError: If the version format is invalid.

        Example:
            >>> translator = VersionTranslator()
            >>> translator.handle_tilde_constraint('1.2.3')
            '>=1.2.3,<1.3.0'
            >>> translator.handle_tilde_constraint('1.2')
            '>=1.2.0,<1.3.0'
            >>> translator.handle_tilde_constraint('1')
            '>=1.0.0,<2.0.0'
        """
        if not self._is_valid_version(version):
            raise VersionConstraintError(
                f"Invalid version in tilde constraint: {version}")

        parts = version.split('.')

        if len(parts) == 1:
            # ~1 -> >=1.0.0,<2.0.0
            major = parts[0]
            next_major = str(int(major) + 1)
            return f">={version}.0.0,<{next_major}.0.0"
        elif len(parts) == 2:
            # ~1.2 -> >=1.2.0,<1.3.0
            major, minor = parts[0], parts[1]
            next_minor = str(int(minor) + 1)
            return f">={version}.0,<{major}.{next_minor}.0"
        else:
            # ~1.2.3 -> >=1.2.3,<1.3.0
            major, minor = parts[0], parts[1]
            next_minor = str(int(minor) + 1)
            return f">={version},<{major}.{next_minor}.0"

    def handle_extras(self, dependency: str, constraint: str) -> str:
        """
        Handle dependencies with extras and translate their constraints.

        This method processes dependencies that include extras (additional
        optional features) and applies version constraint translation to
        create a complete pip-compatible dependency specification.

        Args:
            dependency (str): Dependency name with potential extras in
                brackets, e.g., 'uvicorn[standard]' or 'fastapi'.
            constraint (str): Poetry version constraint to translate.

        Returns:
            str: Complete pip-compatible dependency specification with
                extras preserved and constraint translated.

        Example:
            >>> translator = VersionTranslator()
            >>> result = translator.handle_extras(
            ...     'uvicorn[standard]', '^0.24.0')
            >>> print(result)
            'uvicorn[standard]>=0.24.0,<0.25.0'
            >>>
            >>> result = translator.handle_extras('fastapi', '^0.100.0')
            >>> print(result)
            'fastapi>=0.100.0,<0.101.0'
        """
        # Translate the constraint first
        translated_constraint = self.translate_poetry_to_pip(constraint)

        # If there's no constraint, just return the dependency name
        if not translated_constraint:
            return dependency

        # Combine dependency name (with extras) and translated constraint
        return f"{dependency}{translated_constraint}"

    def _is_valid_version(self, version: str) -> bool:
        """
        Check if a string is a valid version number.

        Args:
            version: Version string to validate

        Returns:
            True if valid version format, False otherwise
        """
        import re
        # More strict version pattern:
        #   major[.minor[.patch]][pre-release][+build]
        # Allows 1, 1.2, 1.2.3, 1.2.3a1, 1.2.3-beta.1, etc.
        # But not excessive dots like 1.2.3.4.5.6
        version_pattern = \
            r'^\d+(\.\d+){0,2}([a-zA-Z]\d*|[-+][a-zA-Z0-9\.\-]*)?$'
        return bool(re.match(version_pattern, version))

    def translate_dependency_with_constraint(self, dependency_name: str,
                                             constraint: str) -> str:
        """
        Translate a full dependency specification with name and constraint.

        Args:
            dependency_name: Name of the dependency (may include extras like
                'uvicorn[standard]')
            constraint: Poetry version constraint

        Returns:
            Full pip-compatible dependency specification
        """
        translated_constraint = self.translate_poetry_to_pip(constraint)

        if not translated_constraint:
            return dependency_name

        return f"{dependency_name}{translated_constraint}"
