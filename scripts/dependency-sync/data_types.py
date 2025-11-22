"""
Type definitions and data models for dependency sync operations.

This module defines the core data structures used throughout the dependency
sync tool. It provides dataclasses for representing dependencies, configuration
options, and operation results with comprehensive validation and utility
methods.

The data models follow a clear separation of concerns:
- Dependency: Represents individual package dependencies
- SyncConfig: Configuration for sync operations
- SyncResult: Results and status of sync operations

Example:
    Creating a dependency:

    >>> dep = Dependency(
    ...     name='fastapi',
    ...     constraint='^0.100.0',
    ...     extras=['standard'],
    ...     source_file='server/pyproject.toml'
    ... )
    >>> print(dep.to_pip_format())
    'fastapi[standard]^0.100.0'

    Configuration setup:

    >>> config = SyncConfig(
    ...     source_files=['server/pyproject.toml'],
    ...     target_dockerfile='Dockerfile',
    ...     verbose=True
    ... )

    Result tracking:

    >>> result = SyncResult(success=True, dependencies_processed=5,
    ...                     conflicts_resolved=1, changes_made=[], errors=[])
    >>> result.add_change("Updated Dockerfile")
    >>> print(result.summary())

Classes:
    Dependency: Represents a Python package dependency
    SyncConfig: Configuration for synchronization operations
    SyncResult: Results and status of sync operations
"""

from dataclasses import dataclass
from typing import List, Optional


@dataclass
class Dependency:
    """
    Represents a Python dependency with version constraints.

    This dataclass encapsulates all information about a single Python package
    dependency including its name, version constraint, optional extras, and
    source file information. It provides methods to convert the dependency
    to pip-compatible format.

    Attributes:
        name (str): Package name (e.g., 'fastapi', 'uvicorn')
        constraint (str): Version constraint (e.g., '^0.100.0', '>=1.0.0')
        extras (Optional[List[str]]): Optional extras list (e.g., ['standard'])
        source_file (str): Path to source pyproject.toml file

    Example:
        >>> dep = Dependency(
        ...     name='uvicorn',
        ...     constraint='^0.24.0',
        ...     extras=['standard'],
        ...     source_file='server/pyproject.toml'
        ... )
        >>> print(dep.to_pip_format())
        'uvicorn[standard]^0.24.0'
        >>> print(str(dep))  # Same as to_pip_format()
        'uvicorn[standard]^0.24.0'
    """

    name: str
    constraint: str
    extras: Optional[List[str]] = None
    source_file: str = ""

    def to_pip_format(self) -> str:
        """
        Convert to pip-compatible dependency string.

        Formats the dependency in a way that pip can understand, including
        extras in brackets and version constraints. Handles empty constraints
        gracefully.

        Returns:
            str: Pip-compatible dependency specification.

        Example:
            >>> dep = Dependency('fastapi', '^0.100.0', ['standard'])
            >>> dep.to_pip_format()
            'fastapi[standard]^0.100.0'
            >>>
            >>> dep_no_extras = Dependency('requests', '>=2.28.0')
            >>> dep_no_extras.to_pip_format()
            'requests>=2.28.0'
        """
        extras_str = ""
        if self.extras:
            extras_str = f"[{','.join(self.extras)}]"

        if self.constraint and self.constraint != "*":
            return f"{self.name}{extras_str}{self.constraint}"
        else:
            return f"{self.name}{extras_str}"

    def __str__(self) -> str:
        return self.to_pip_format()


@dataclass
class SyncConfig:
    """
    Configuration for dependency synchronization operations.

    This dataclass holds all configuration options for a dependency sync
    operation including source files, target file, and various operational
    modes. It includes validation to ensure required fields are provided.

    Attributes:
        source_files (List[str]): List of pyproject.toml files to read from
        target_dockerfile (str): Path to Dockerfile to update
        verbose (bool): Enable detailed output (default: False)
        quiet (bool): Suppress non-error output (default: False)
        backup (bool): Create backup before changes (default: True)
        dry_run (bool): Show changes without applying (default: False)

    Example:
        >>> config = SyncConfig(
        ...     source_files=['server/pyproject.toml',
        ...                   'mcp-server/pyproject.toml'],
        ...     target_dockerfile='deploy/docker_images/Dockerfile',
        ...     verbose=True,
        ...     backup=True
        ... )
        >>> print(f"Processing {len(config.source_files)} files")
        Processing 2 files
    """

    source_files: List[str]
    target_dockerfile: str
    verbose: bool = False
    quiet: bool = False
    backup: bool = True
    dry_run: bool = False

    def __post_init__(self) -> None:
        """
        Validate configuration after initialization.

        Ensures that required fields are provided and have valid values.

        Raises:
            ValueError: If required fields are missing or invalid.
        """
        if not self.source_files:
            raise ValueError("At least one source file must be specified")
        if not self.target_dockerfile:
            raise ValueError("Target dockerfile must be specified")


@dataclass
class SyncResult:
    """
    Result of dependency synchronization operation.

    This dataclass captures the complete result of a dependency sync operation
    including success status, statistics, changes made, and any errors that
    occurred. It provides utility methods for result analysis and reporting.

    Attributes:
        success (bool): Whether the operation completed successfully
        dependencies_processed (int): Number of unique dependencies processed
        conflicts_resolved (int): Number of version conflicts resolved
        changes_made (List[str]): List of changes that were applied
        errors (List[str]): List of error messages encountered
        backup_file (Optional[str]): Path to backup file if created

    Example:
        >>> result = SyncResult(
        ...     success=True,
        ...     dependencies_processed=15,
        ...     conflicts_resolved=2,
        ...     changes_made=[],
        ...     errors=[]
        ... )
        >>> result.add_change("Updated Dockerfile with 15 dependencies")
        >>> print(result.summary())
        Sync Status: SUCCESS
        Dependencies Processed: 15
        Conflicts Resolved: 2
        Changes Made: 1
    """

    success: bool
    dependencies_processed: int
    conflicts_resolved: int
    changes_made: List[str]
    errors: List[str]
    backup_file: Optional[str] = None

    def __post_init__(self) -> None:
        """
        Initialize empty lists if None.

        Ensures that list attributes are properly initialized to empty
        lists if they were passed as None.
        """
        if self.changes_made is None:
            self.changes_made = []
        if self.errors is None:
            self.errors = []

    def add_change(self, change: str) -> None:
        """
        Add a change to the changes list.

        Args:
            change (str): Description of the change that was made.
        """
        self.changes_made.append(change)

    def add_error(self, error: str) -> None:
        """
        Add an error to the errors list and mark operation as failed.

        Args:
            error (str): Error message to add.
        """
        self.errors.append(error)
        self.success = False

    def has_errors(self) -> bool:
        """
        Check if there are any errors.

        Returns:
            bool: True if there are errors, False otherwise.
        """
        return len(self.errors) > 0

    def summary(self) -> str:
        """
        Generate a summary string of the sync result.

        Creates a formatted summary of the operation including status,
        statistics, and file information.

        Returns:
            str: Multi-line summary of the sync operation.

        Example:
            >>> result = SyncResult(True, 10, 2, ["Updated Dockerfile"], [])
            >>> print(result.summary())
            Sync Status: SUCCESS
            Dependencies Processed: 10
            Conflicts Resolved: 2
            Changes Made: 1
        """
        status = "SUCCESS" if self.success else "FAILED"
        summary_lines = [
            f"Sync Status: {status}",
            f"Dependencies Processed: {self.dependencies_processed}",
            f"Conflicts Resolved: {self.conflicts_resolved}",
            f"Changes Made: {len(self.changes_made)}",
        ]

        if self.backup_file:
            summary_lines.append(f"Backup Created: {self.backup_file}")

        if self.errors:
            summary_lines.append(f"Errors: {len(self.errors)}")

        return "\n".join(summary_lines)
