"""
Exception classes for dependency sync operations.

This module defines a hierarchy of custom exceptions used throughout the
dependency sync tool. Each exception provides specific context about the
type of error that occurred and includes relevant metadata for debugging.

The exception hierarchy follows a clear structure:
- DependencySyncError: Base exception for all sync operations
- TOMLParsingError: Errors during pyproject.toml parsing
- VersionConstraintError: Errors during version constraint translation
- DockerfileUpdateError: Errors during Dockerfile modification

Example:
    Catching specific errors:

    >>> try:
    ...     parser.parse_pyproject_file('invalid.toml')
    ... except TOMLParsingError as e:
    ...     print(f"TOML error: {e}")
    ...     print(f"File: {e.file_path}")
    ...     if e.line_number:
    ...         print(f"Line: {e.line_number}")

    Generic error handling:

    >>> try:
    ...     sync_operation()
    ... except DependencySyncError as e:
    ...     print(f"Sync failed: {e}")
    ...     if e.file_path:
    ...         print(f"Related file: {e.file_path}")

Classes:
    DependencySyncError: Base exception for all dependency sync operations
    TOMLParsingError: Specific to TOML file parsing failures
    VersionConstraintError: Specific to version constraint translation failures
    DockerfileUpdateError: Specific to Dockerfile modification failures
"""


class DependencySyncError(Exception):
    """
    Base exception for dependency sync operations.

    This is the root exception class for all errors that can occur during
    dependency synchronization operations. It provides common functionality
    for storing error context including file paths and formatted error
    messages.

    Attributes:
        message (str): The error message describing what went wrong
        file_path (str, optional): Path to the file related to the error

    Example:
        >>> try:
        ...     raise DependencySyncError("Something went wrong",
        ...     "/path/to/file.toml")
        ... except DependencySyncError as e:
        ...     print(e)  # "Something went wrong (file: /path/to/file.toml)"
        ...     print(e.file_path)  # "/path/to/file.toml"
    """

    def __init__(self, message: str, file_path: str = None) -> None:
        """
        Initialize the exception.

        Args:
            message (str): Error message describing the problem
            file_path (str, optional): Path to related file if applicable
        """
        super().__init__(message)
        self.message = message
        self.file_path = file_path

    def __str__(self) -> str:
        if self.file_path:
            return f"{self.message} (file: {self.file_path})"
        return self.message


class TOMLParsingError(DependencySyncError):
    """
    Raised when TOML parsing fails.

    This exception is raised when there are errors reading or parsing
    pyproject.toml files. It includes additional context such as line
    numbers when available from the TOML parser.

    Attributes:
        message (str): Error message from the TOML parser
        file_path (str, optional): Path to the problematic TOML file
        line_number (int, optional): Line number where the error occurred

    Example:
        >>> try:
        ...     raise TOMLParsingError(
        ...         "Invalid TOML syntax",
        ...         "pyproject.toml",
        ...         line_number=15
        ...     )
        ... except TOMLParsingError as e:
        ...     print(e)  # "Invalid TOML syntax (file: pyproject.toml)
        ...               # (line: 15)"
    """

    def __init__(self, message: str, file_path: str = None,
                 line_number: int = None) -> None:
        """
        Initialize the TOML parsing exception.

        Args:
            message (str): Error message from the parser
            file_path (str, optional): Path to the TOML file
            line_number (int, optional): Line number of the error
        """
        super().__init__(message, file_path)
        self.line_number = line_number

    def __str__(self) -> str:
        base_msg = super().__str__()
        if self.line_number:
            return f"{base_msg} (line: {self.line_number})"
        return base_msg


class VersionConstraintError(DependencySyncError):
    """
    Raised when version constraint translation fails.

    This exception is raised when the version translator cannot parse or
    convert a Poetry version constraint to pip format. It includes context
    about the specific dependency and constraint that caused the problem.

    Attributes:
        message (str): Error message describing the translation problem
        dependency (str, optional): Name of the dependency with the
            problematic constraint
        constraint (str, optional): The constraint that could not be translated

    Example:
        >>> try:
        ...     raise VersionConstraintError(
        ...         "Invalid constraint format",
        ...         dependency="fastapi",
        ...         constraint="invalid-constraint"
        ...     )
        ... except VersionConstraintError as e:
        ...     print(e)  # "Invalid constraint format (dependency: fastapi,
        ...               # constraint: invalid-constraint)"
    """

    def __init__(self, message: str, dependency: str = None,
                 constraint: str = None) -> None:
        """
        Initialize the version constraint exception.

        Args:
            message (str): Error message describing the problem
            dependency (str, optional): Name of the problematic dependency
            constraint (str, optional): The constraint that failed translation
        """
        super().__init__(message)
        self.dependency = dependency
        self.constraint = constraint

    def __str__(self) -> str:
        if self.dependency and self.constraint:
            return f"{self.message} (dependency: {self.dependency},"
            f" constraint: {self.constraint})"
        elif self.dependency:
            return f"{self.message} (dependency: {self.dependency})"
        return self.message


class DockerfileUpdateError(DependencySyncError):
    """
    Raised when Dockerfile update fails.

    This exception is raised when there are errors modifying the Dockerfile,
    such as inability to find the pip install block, file permission issues,
    or backup creation failures. It includes information about backup files
    when available.

    Attributes:
        message (str): Error message describing the update problem
        dockerfile_path (str, optional): Path to the Dockerfile being updated
        backup_path (str, optional): Path to backup file if one was created

    Example:
        >>> try:
        ...     raise DockerfileUpdateError(
        ...         "Could not find pip install block",
        ...         dockerfile_path="Dockerfile",
        ...         backup_path="Dockerfile.backup_20240101_120000"
        ...     )
        ... except DockerfileUpdateError as e:
        ...     print(e)  # "Could not find pip install block
        ...               # (file: Dockerfile)
        ...               # (backup: Dockerfile.backup_20240101_120000)"
    """

    def __init__(self, message: str, dockerfile_path: str = None,
                 backup_path: str = None) -> None:
        """
        Initialize the Dockerfile update exception.

        Args:
            message (str): Error message describing the update problem
            dockerfile_path (str, optional): Path to the Dockerfile
            backup_path (str, optional): Path to backup file if created
        """
        super().__init__(message, dockerfile_path)
        self.backup_path = backup_path

    def __str__(self) -> str:
        base_msg = super().__str__()
        if self.backup_path:
            return f"{base_msg} (backup: {self.backup_path})"
        return base_msg
