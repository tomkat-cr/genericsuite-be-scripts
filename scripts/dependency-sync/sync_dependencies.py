#!/usr/bin/env python3
"""
Dependency Sync Script

Main script for synchronizing Poetry dependencies from pyproject.toml files
to Docker pip installation commands.

This module provides the main orchestration logic for the dependency sync tool.
It coordinates TOML parsing, version constraint translation, dependency
merging, and Dockerfile updating operations.

Example:
    Basic usage from command line:

    $ python sync_dependencies.py server/pyproject.toml \
        deploy/docker_images/Dockerfile

    Multiple source files:

    $ python sync_dependencies.py server/pyproject.toml \
        mcp-server/pyproject.toml deploy/docker_images/Dockerfile

    Programmatic usage:

    >>> from sync_dependencies import DependencySync
    >>> from data_types import SyncConfig
    >>> config = SyncConfig(
    ...     source_files=['server/pyproject.toml'],
    ...     target_dockerfile='deploy/docker_images/Dockerfile'
    ... )
    >>> sync = DependencySync()
    >>> result = sync.sync_dependencies(config)
    >>> print(f"Success: {result.success}")

Attributes:
    DependencySync: Main orchestrator class for dependency synchronization
    main: Entry point function for command-line usage
"""

import sys
import logging

from toml_parser import TOMLParser
from version_translator import VersionTranslator
from dependency_merger import DependencyMerger
from dockerfile_updater import DockerfileUpdater
from cli_interface import CLIInterface
from data_types import SyncConfig, SyncResult
from exceptions import (
    DependencySyncError,
    TOMLParsingError,
    VersionConstraintError,
    DockerfileUpdateError)


class DependencySync:
    """
    Main orchestrator for dependency synchronization.

    This class coordinates all the components needed for synchronizing Poetry
    dependencies from pyproject.toml files to Docker pip installation commands.
    It handles the complete workflow from parsing to Dockerfile updates.

    Attributes:
        toml_parser (TOMLParser): Parser for pyproject.toml files
        version_translator (VersionTranslator): Converts Poetry constraints to
            pip format
        dependency_merger (DependencyMerger): Merges and resolves dependency
            conflicts
        dockerfile_updater (DockerfileUpdater): Updates Dockerfile pip install
            commands
        cli_interface (CLIInterface): Handles command-line interactions
        logger (logging.Logger): Logger for debugging and error reporting

    Example:
        >>> sync = DependencySync()
        >>> config = SyncConfig(
        ...     source_files=['pyproject.toml'],
        ...     target_dockerfile='Dockerfile'
        ... )
        >>> result = sync.sync_dependencies(config)
        >>> if result.success:
        ...     print(f"Processed {result.dependencies_processed}"
        ...           " dependencies")
    """

    def __init__(self) -> None:
        """
        Initialize the dependency sync orchestrator.

        Creates instances of all required components and sets up logging.
        All components are initialized with their default configurations.
        """
        self.toml_parser = TOMLParser()
        self.version_translator = VersionTranslator()
        self.dependency_merger = DependencyMerger()
        self.dockerfile_updater = DockerfileUpdater()
        self.cli_interface = CLIInterface()

        # Set up logging
        self.logger = logging.getLogger(__name__)

    def sync_dependencies(self, config: SyncConfig) -> SyncResult:
        """
        Main method to synchronize dependencies from Poetry to Docker.

        This method orchestrates the complete synchronization workflow:
        1. Parse all specified pyproject.toml files
        2. Merge dependencies and resolve conflicts
        3. Translate Poetry version constraints to pip format
        4. Create backup of target Dockerfile (if requested)
        5. Update Dockerfile with new pip install command

        Args:
            config (SyncConfig): Configuration object containing:
                - source_files: List of pyproject.toml file paths
                - target_dockerfile: Path to Dockerfile to update
                - verbose: Enable detailed output
                - quiet: Suppress non-error output
                - backup: Create backup before changes
                - dry_run: Show changes without applying them

        Returns:
            SyncResult: Result object containing:
                - success: Whether operation completed successfully
                - dependencies_processed: Number of unique dependencies found
                - conflicts_resolved: Number of version conflicts resolved
                - changes_made: List of changes applied
                - errors: List of error messages
                - backup_file: Path to backup file (if created)

        Example:
            >>> config = SyncConfig(
            ...     source_files=['server/pyproject.toml',
            ...                   'mcp-server/pyproject.toml'],
            ...     target_dockerfile='deploy/docker_images/Dockerfile',
            ...     verbose=True
            ... )
            >>> result = sync.sync_dependencies(config)
            >>> if result.success:
            ...     print(f"Updated {len(result.changes_made)} items")
            ... else:
            ...     print(f"Failed with {len(result.errors)} errors")
        """
        result = SyncResult(
            success=True,
            dependencies_processed=0,
            conflicts_resolved=0,
            changes_made=[],
            errors=[]
        )

        try:
            # Step 1: Parse all pyproject.toml files
            if not config.quiet:
                self.cli_interface.print_progress(
                    "Parsing pyproject.toml files...", config.verbose,
                    config.quiet)

            all_dependencies = []
            for source_file in config.source_files:
                try:
                    if config.verbose:
                        self.cli_interface.print_progress(
                            f"Parsing {source_file}...", config.verbose,
                            config.quiet)

                    dependencies = self.toml_parser.parse_pyproject_file(
                        source_file)
                    all_dependencies.append(dependencies)

                    if config.verbose:
                        self.cli_interface.print_progress(
                            f"Found {len(dependencies)} dependencies in"
                            f" {source_file}",
                            config.verbose, config.quiet
                        )

                except TOMLParsingError as e:
                    result.add_error(f"Failed to parse {source_file}: {e}")
                    continue

            if result.has_errors() and not all_dependencies:
                # All files failed to parse
                return result

            # Step 2: Merge dependencies and resolve conflicts
            if not config.quiet:
                self.cli_interface.print_progress(
                    "Merging dependencies...", config.verbose, config.quiet)

            merged_dependencies = self.dependency_merger.merge_dependencies(
                *all_dependencies)
            result.dependencies_processed = len(merged_dependencies)

            if config.verbose:
                self.cli_interface.print_progress(
                    f"Merged to {len(merged_dependencies)} unique"
                    " dependencies",
                    config.verbose, config.quiet
                )

            # Step 3: Translate version constraints
            if not config.quiet:
                self.cli_interface.print_progress(
                    "Translating version constraints...", config.verbose,
                    config.quiet)

            translated_dependencies = {}
            for dep_name, constraint in merged_dependencies.items():
                try:
                    translated_constraint = \
                        self.version_translator.translate_poetry_to_pip(
                            constraint)
                    translated_dependencies[dep_name] = translated_constraint

                    if config.verbose and translated_constraint != constraint:
                        self.cli_interface.print_progress(
                            f"Translated {dep_name}: {constraint} →"
                            f" {translated_constraint}",
                            config.verbose, config.quiet
                        )

                except VersionConstraintError as e:
                    result.add_error(
                        f"Failed to translate constraint for {dep_name}: {e}")
                    # Use original constraint as fallback
                    translated_dependencies[dep_name] = constraint

            # Step 4: Create backup if requested
            backup_file = None
            if config.backup and not config.dry_run:
                try:
                    if not config.quiet:
                        self.cli_interface.print_progress(
                            "Creating backup...", config.verbose, config.quiet)

                    backup_file = self.dockerfile_updater.backup_dockerfile(
                        config.target_dockerfile)
                    result.backup_file = backup_file
                    result.add_change(f"Created backup: {backup_file}")

                except DockerfileUpdateError as e:
                    result.add_error(f"Failed to create backup: {e}")
                    # Continue without backup if requested
                    if config.verbose:
                        self.cli_interface.print_progress(
                            "Continuing without backup...", config.verbose,
                            config.quiet)

            # Step 5: Update Dockerfile
            if config.dry_run:
                if not config.quiet:
                    self.cli_interface.print_progress(
                        "DRY RUN: Would update Dockerfile with dependencies",
                        config.verbose, config.quiet)
                result.add_change("DRY RUN: Dockerfile would be updated")
            else:
                try:
                    if not config.quiet:
                        self.cli_interface.print_progress(
                            "Updating Dockerfile...", config.verbose,
                            config.quiet)

                    self.dockerfile_updater.update_pip_install(
                        config.target_dockerfile, translated_dependencies)
                    result.add_change(
                        "Updated pip install command in"
                        f" {config.target_dockerfile}")

                    if config.verbose:
                        self.cli_interface.print_progress(
                            f"Successfully updated {config.target_dockerfile}",
                            config.verbose, config.quiet
                        )

                except DockerfileUpdateError as e:
                    result.add_error(f"Failed to update Dockerfile: {e}")
                    result.success = False

            # Final success check
            if result.has_errors():
                result.success = False

            return result

        except Exception as e:
            result.add_error(f"Unexpected error during synchronization: {e}")
            self.logger.exception("Unexpected error in sync_dependencies")
            return result


def main() -> int:
    """
    Main entry point for the script.

    Returns:
        Exit code (0 for success, non-zero for errors)
    """
    cli_interface = CLIInterface()

    try:
        # Step 1: Parse command line arguments
        args = cli_interface.parse_arguments()

        # Step 2: Set up logging
        log_level = logging.DEBUG if args.verbose else logging.INFO
        if args.quiet:
            log_level = logging.WARNING

        logging.basicConfig(
            level=log_level,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )

        # Step 3: Validate file paths
        try:
            cli_interface.validate_file_paths(
                args.source_files, args.target_dockerfile)
        except (FileNotFoundError, PermissionError, ValueError) as e:
            return cli_interface.handle_errors(e, args.verbose)

        # Step 4: Create configuration
        config = SyncConfig(
            source_files=args.source_files,
            target_dockerfile=args.target_dockerfile,
            verbose=args.verbose,
            quiet=args.quiet,
            backup=not args.no_backup,
            dry_run=args.dry_run
        )

        # Step 5: Run synchronization
        sync = DependencySync()
        result = sync.sync_dependencies(config)

        # Step 6: Print results
        changes_dict = {
            'dependencies_processed': result.dependencies_processed,
            'conflicts_resolved': result.conflicts_resolved,
            'files_processed': len(config.source_files),
            'changes_made': result.changes_made,
            'backup_file': result.backup_file,
            'warnings': [],  # Could be populated from warnings module
            'dependencies': {},  # Could be populated for verbose output
            'conflict_resolutions': {}  # Could be populated for verbose output
        }

        cli_interface.print_summary(changes_dict, args.verbose, args.quiet)

        # Step 7: Return appropriate exit code
        if result.success:
            if not args.quiet:
                print("\n✅ Dependency synchronization completed successfully!")
            return 0
        else:
            if not args.quiet:
                print("\n❌ Dependency synchronization failed!")
                print("Errors:")
                for error in result.errors:
                    print(f"  • {error}")
            return 1

    except DependencySyncError as e:
        return cli_interface.handle_errors(e, getattr(args, 'verbose', False))
    except KeyboardInterrupt:
        print("\n\nOperation cancelled by user.", file=sys.stderr)
        return 130  # Standard exit code for SIGINT
    except Exception as e:
        return cli_interface.handle_errors(e, getattr(args, 'verbose', False))


if __name__ == "__main__":
    sys.exit(main())
