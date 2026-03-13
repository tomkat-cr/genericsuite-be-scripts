"""
CLI Interface module for dependency synchronization tool.

This module provides command-line argument parsing and user interaction
for the dependency sync tool. It handles argument validation, file path
checking, progress reporting, and error handling for the command-line
interface.

The CLI supports various modes of operation including verbose output for
debugging, quiet mode for automation, and dry-run mode for testing changes
without applying them.

Example:
    Basic command-line usage:

    >>> from cli_interface import CLIInterface
    >>> cli = CLIInterface()
    >>> args = cli.parse_arguments()  # Parses sys.argv
    >>> cli.validate_file_paths(args.source_files, args.target_dockerfile)

    Error handling:

    >>> try:
    ...     cli.validate_file_paths(['missing.toml'], 'Dockerfile')
    ... except FileNotFoundError as e:
    ...     exit_code = cli.handle_errors(e, verbose=True)

Classes:
    CLIInterface: Main command-line interface handler
"""

import argparse
import sys
from pathlib import Path
from typing import List, Optional, Dict, Any
import os


class CLIInterface:
    """
    Command-line interface for the dependency sync tool.

    This class handles all command-line interactions including argument
    parsing, file validation, progress reporting, and error handling.
    It provides a consistent interface for both interactive and automated
    usage.

    Attributes:
        parser (argparse.ArgumentParser): Configured argument parser for
            command-line options and arguments.

    Example:
        >>> cli = CLIInterface()
        >>> args = cli.parse_arguments()
        >>> if args.verbose:
        ...     cli.print_progress("Starting sync...", True, False)
        >>> cli.validate_file_paths(args.source_files, args.target_dockerfile)
    """

    def __init__(self) -> None:
        """
        Initialize the CLI interface.

        Creates and configures the argument parser with all supported
        command-line options and arguments.
        """
        self.parser = self._create_parser()

    def _create_parser(self) -> argparse.ArgumentParser:
        """Create and configure the argument parser."""
        parser = argparse.ArgumentParser(
            description="Synchronize Poetry dependencies from pyproject.toml"
            " files to Dockerfile pip install commands",
            formatter_class=argparse.RawDescriptionHelpFormatter,
            epilog="""
Examples:
  %(prog)s server/pyproject.toml deploy/docker_images/Dockerfile
  %(prog)s server/pyproject.toml mcp-server/pyproject.toml \
    deploy/docker_images/Dockerfile
  %(prog)s --verbose --dry-run server/pyproject.toml \
    deploy/docker_images/Dockerfile
            """
        )

        # Positional arguments
        parser.add_argument(
            'source_files',
            nargs='+',
            help='One or more pyproject.toml files to read dependencies from'
        )

        parser.add_argument(
            'target_dockerfile',
            help='Dockerfile to update with synchronized dependencies'
        )

        # Optional arguments
        parser.add_argument(
            '-v', '--verbose',
            action='store_true',
            help='Enable verbose output with detailed processing information'
        )

        parser.add_argument(
            '-q', '--quiet',
            action='store_true',
            help='Enable quiet mode with minimal output'
        )

        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Show what would be done without making actual changes'
        )

        parser.add_argument(
            '--no-backup',
            action='store_true',
            help='Skip creating backup of the original Dockerfile'
        )

        return parser

    def parse_arguments(self, args: Optional[List[str]] = None
                        ) -> argparse.Namespace:
        """
        Parse command line arguments.

        Args:
            args: Optional list of arguments to parse. If None, uses sys.argv.

        Returns:
            Parsed arguments namespace.

        Raises:
            SystemExit: If argument parsing fails or help is requested.
        """
        try:
            parsed_args = self.parser.parse_args(args)

            # Validate mutually exclusive options
            if parsed_args.verbose and parsed_args.quiet:
                self.parser.error(
                    "--verbose and --quiet options are mutually exclusive")

            return parsed_args

        except SystemExit as e:
            # Re-raise SystemExit to maintain argparse behavior
            raise e

    def validate_file_paths(self, source_files: List[str],
                            target_dockerfile: str) -> None:
        """
        Validate that all specified files exist and are accessible.

        Args:
            source_files: List of pyproject.toml file paths to validate.
            target_dockerfile: Dockerfile path to validate.

        Raises:
            FileNotFoundError: If any source file doesn't exist.
            PermissionError: If files are not readable/writable.
            ValueError: If file paths are invalid.
        """
        # Validate source files
        for source_file in source_files:
            source_path = Path(source_file)

            if not source_path.exists():
                raise FileNotFoundError(
                    f"Source file not found: {source_file}")

            if not source_path.is_file():
                raise ValueError(f"Source path is not a file: {source_file}")

            if not os.access(source_path, os.R_OK):
                raise PermissionError(
                    f"Cannot read source file: {source_file}")

            # Validate it's a pyproject.toml file
            if source_path.name != 'pyproject.toml':
                raise ValueError(
                    "Source file must be named 'pyproject.toml':"
                    f" {source_file}")

        # Validate target dockerfile
        dockerfile_path = Path(target_dockerfile)

        if not dockerfile_path.exists():
            raise FileNotFoundError(
                f"Target Dockerfile not found: {target_dockerfile}")

        if not dockerfile_path.is_file():
            raise ValueError(f"Target path is not a file: {target_dockerfile}")

        if not os.access(dockerfile_path, os.R_OK):
            raise PermissionError(
                f"Cannot read target Dockerfile: {target_dockerfile}")

        if not os.access(dockerfile_path, os.W_OK):
            raise PermissionError(
                f"Cannot write to target Dockerfile: {target_dockerfile}")

    def print_summary(self, changes: Dict[str, Any], verbose: bool = False,
                      quiet: bool = False) -> None:
        """
        Print a summary of changes made during synchronization.

        Args:
            changes: Dictionary containing information about changes made.
            verbose: Whether to print detailed information.
            quiet: Whether to suppress most output.
        """
        if quiet:
            return

        print("\n" + "="*60)
        print("DEPENDENCY SYNC SUMMARY")
        print("="*60)

        # Basic statistics
        dependencies_processed = changes.get('dependencies_processed', 0)
        conflicts_resolved = changes.get('conflicts_resolved', 0)
        files_processed = changes.get('files_processed', 0)

        print(f"Files processed: {files_processed}")
        print(f"Dependencies processed: {dependencies_processed}")

        if conflicts_resolved > 0:
            print(f"Version conflicts resolved: {conflicts_resolved}")

        # Show changes made
        changes_made = changes.get('changes_made', [])
        if changes_made:
            print("\nChanges made:")
            for change in changes_made:
                print(f"  • {change}")
        else:
            print("\nNo changes were necessary.")

        # Show backup information
        backup_file = changes.get('backup_file')
        if backup_file:
            print(f"\nBackup created: {backup_file}")

        # Verbose output
        if verbose:
            self._print_verbose_details(changes)

        # Show any warnings
        warnings = changes.get('warnings', [])
        if warnings:
            print("\nWarnings:")
            for warning in warnings:
                print(f"  ⚠ {warning}")

        print("="*60)

    def _print_verbose_details(self, changes: Dict[str, Any]) -> None:
        """Print detailed verbose information."""
        print("\nDetailed Information:")

        # Show processed dependencies
        dependencies = changes.get('dependencies', {})
        if dependencies:
            print("  Dependencies found:")
            for name, constraint in sorted(dependencies.items()):
                print(f"    {name}: {constraint}")

        # Show conflict resolutions
        conflicts = changes.get('conflict_resolutions', {})
        if conflicts:
            print("  Conflict resolutions:")
            for dep_name, resolution in conflicts.items():
                old_constraints = resolution.get('old_constraints', [])
                new_constraint = resolution.get('new_constraint', '')
                print(f"    {dep_name}: {old_constraints} → {new_constraint}")

    def handle_errors(self, error: Exception, verbose: bool = False) -> int:
        """
        Handle and report errors with appropriate exit codes.

        Args:
            error: The exception that occurred.
            verbose: Whether to print detailed error information.

        Returns:
            Appropriate exit code for the error type.
        """
        error_type = type(error).__name__

        if isinstance(error, FileNotFoundError):
            print(f"Error: {error}", file=sys.stderr)
            return 2  # File not found

        elif isinstance(error, PermissionError):
            print(f"Error: {error}", file=sys.stderr)
            return 3  # Permission denied

        elif isinstance(error, ValueError):
            print(f"Error: {error}", file=sys.stderr)
            return 4  # Invalid input

        else:
            print(f"Unexpected error ({error_type}): {error}", file=sys.stderr)
            if verbose:
                import traceback
                traceback.print_exc()
            return 1  # General error

    def print_progress(self, message: str, verbose: bool = False,
                       quiet: bool = False) -> None:
        """
        Print progress information during processing.

        Args:
            message: Progress message to display.
            verbose: Whether verbose mode is enabled.
            quiet: Whether quiet mode is enabled.
        """
        if quiet:
            return

        if verbose:
            print(f"[INFO] {message}")
        else:
            print(f"• {message}")
