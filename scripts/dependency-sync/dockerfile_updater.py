"""
Dockerfile Updater Module

Locates and replaces pip install commands in Dockerfiles.
"""
# pylint: disable=line-too-long
# flake8: noqa: E501

import os
import shutil
import re
from datetime import datetime
from typing import Dict, Tuple
from exceptions import DockerfileUpdateError


class DockerfileUpdater:
    """Updates pip install commands in Dockerfiles with new dependencies."""

    def __init__(self):
        """Initialize the Dockerfile updater."""
        pass

    def _read_dockerfile(self, dockerfile_path: str) -> str:
        """
        Read Dockerfile content.

        Args:
            dockerfile_path: Path to the Dockerfile

        Returns:
            Dockerfile content as string

        Raises:
            DockerfileUpdateError: If reading fails
        """
        if not os.path.exists(dockerfile_path):
            raise DockerfileUpdateError(
                f"Dockerfile not found: {dockerfile_path}",
                dockerfile_path=dockerfile_path
            )

        if not os.access(dockerfile_path, os.R_OK):
            raise DockerfileUpdateError(
                f"Cannot read Dockerfile: {dockerfile_path}",
                dockerfile_path=dockerfile_path
            )

        try:
            with open(dockerfile_path, 'r', encoding='utf-8') as f:
                return f.read()
        except (OSError, IOError, UnicodeDecodeError) as e:
            raise DockerfileUpdateError(
                f"Failed to read Dockerfile: {str(e)}",
                dockerfile_path=dockerfile_path
            )

    def _write_dockerfile(self, dockerfile_path: str, content: str) -> None:
        """
        Write content to Dockerfile.

        Args:
            dockerfile_path: Path to the Dockerfile
            content: Content to write

        Raises:
            DockerfileUpdateError: If writing fails
        """
        if not os.access(os.path.dirname(dockerfile_path) or '.', os.W_OK):
            raise DockerfileUpdateError(
                "Cannot write to directory: "
                f"{os.path.dirname(dockerfile_path)}",
                dockerfile_path=dockerfile_path
            )

        try:
            with open(dockerfile_path, 'w', encoding='utf-8') as f:
                f.write(content)
        except (OSError, IOError, UnicodeEncodeError) as e:
            raise DockerfileUpdateError(
                f"Failed to write Dockerfile: {str(e)}",
                dockerfile_path=dockerfile_path
            )

    def update_pip_install(self, dockerfile_path: str,
                           dependencies: Dict[str, str]) -> None:
        """
        Update pip install command in Dockerfile with new dependencies.

        Args:
            dockerfile_path: Path to the Dockerfile
            dependencies: Dictionary of dependencies to install

        Raises:
            DockerfileUpdateError: If update fails
        """
        # Read current Dockerfile content
        content = self._read_dockerfile(dockerfile_path)

        # Find the pip install block
        start_idx, end_idx = self.find_pip_install_block(content)

        # Format new dependencies
        formatted_deps = self.format_pip_dependencies(dependencies)

        # Create new pip install command
        new_pip_command = (
            "RUN pip install --upgrade pip && pip install --no-cache-dir \\\n"
            f"{formatted_deps}\n\n"
        )

        # Replace the old pip install block with the new one
        new_content = (
            content[:start_idx] +
            new_pip_command +
            content[end_idx:]
        )

        # Write the updated content back to the file
        self._write_dockerfile(dockerfile_path, new_content)

    def find_pip_install_block(self, content: str) -> Tuple[int, int]:
        """
        Locate the pip install command block in Dockerfile content.

        Args:
            content: Dockerfile content as string

        Returns:
            Tuple of (start_index, end_index) for the pip install block

        Raises:
            DockerfileUpdateError: If pip install block not found
        """
        # Find the start of the pip install command
        pip_start_pattern = re.compile(
            r'RUN\s+pip\s+install\s+--upgrade\s+pip\s+&&\s+pip\s+install\s+--no-cache-dir\s*\\?\s*\n',
            re.MULTILINE
        )

        # Alternative pattern for simpler pip install commands
        simple_pip_start_pattern = re.compile(
            r'RUN\s+pip\s+install\s+(?:--no-cache-dir\s+)?\\?\s*\n',
            re.MULTILINE
        )

        # Try to find the start of the pip install block
        start_match = pip_start_pattern.search(content)
        if not start_match:
            start_match = simple_pip_start_pattern.search(content)

        if not start_match:
            raise DockerfileUpdateError(
                "No pip install command block found in Dockerfile. "
                "Expected format: RUN pip install --upgrade pip && "
                "pip install --no-cache-dir ..."
            )

        start_idx = start_match.start()

        # Find the end of the pip install block by looking for the next RUN,
        # COPY, EXPOSE, CMD, etc.
        # or end of file
        remaining_content = content[start_match.end():]

        # Pattern to match the end of the pip install block
        # This matches either:
        # 1. A line that doesn't start with whitespace and contains a package
        #    (last dependency line)
        # 2. The start of the next Dockerfile instruction
        # 3. End of file

        lines = remaining_content.split('\n')
        end_offset = 0
        in_pip_block = True

        for i, line in enumerate(lines):
            stripped_line = line.strip()

            # Skip empty lines
            if not stripped_line:
                end_offset += len(line) + 1  # +1 for newline
                continue

            # Check if this line is part of the pip install block
            if in_pip_block:
                # Check if this line looks like a package dependency
                if (stripped_line.startswith('"')
                    and stripped_line.endswith('"')) or \
                   (stripped_line.startswith('"')
                        and stripped_line.endswith('" \\')):
                    # This is a dependency line
                    end_offset += len(line) + 1
                    # If this line doesn't end with backslash, it's the last
                    # dependency
                    if not stripped_line.endswith(' \\'):
                        end_offset += 0  # Don't include the newline after the
                        # last dependency
                        break
                elif stripped_line.startswith('"') \
                        and not stripped_line.endswith('"'):
                    # Malformed dependency line, but still part of pip block
                    end_offset += len(line) + 1
                else:
                    # This line is not a dependency, so pip block has ended
                    break
            else:
                break

        # If we didn't find a clear end, look for the next Dockerfile
        # instruction
        if in_pip_block:
            next_instruction_pattern = re.compile(
                r'^\s*(RUN|COPY|ADD|EXPOSE|CMD|ENTRYPOINT|WORKDIR|ENV|ARG|LABEL|USER|VOLUME|STOPSIGNAL|HEALTHCHECK|SHELL|FROM)\s+',
                re.MULTILINE
            )

            next_match = next_instruction_pattern.search(remaining_content)
            if next_match:
                end_offset = next_match.start()
            else:
                # No next instruction found, use end of remaining content
                end_offset = len(remaining_content)

        end_idx = start_match.end() + end_offset

        return start_idx, end_idx

    def format_pip_dependencies(self, dependencies: Dict[str, str]) -> str:
        """
        Format dependencies for pip install command with proper line breaks.

        Args:
            dependencies: Dictionary of dependencies to format

        Returns:
            Formatted dependency string for Dockerfile
        """
        if not dependencies:
            return ""

        formatted_deps = []

        # Sort dependencies for consistent output
        for name, constraint in sorted(dependencies.items()):
            # Handle dependencies with or without version constraints
            if constraint and constraint.strip() and constraint != "*":
                # Clean up constraint (remove extra whitespace and normalize
                # spaces)
                clean_constraint = re.sub(r'\s+', '', constraint.strip())
                dep_string = f'    "{name}{clean_constraint}"'
            else:
                # No version constraint specified
                dep_string = f'    "{name}"'

            formatted_deps.append(dep_string)

        # Join with backslash continuation for multi-line format
        if len(formatted_deps) == 1:
            # Single dependency - no backslash needed
            return formatted_deps[0]
        else:
            # Multiple dependencies - use backslash continuation
            # All lines except the last one get a backslash
            result_lines = []
            for i, dep in enumerate(formatted_deps):
                if i < len(formatted_deps) - 1:
                    result_lines.append(f"{dep} \\")
                else:
                    result_lines.append(dep)

            return "\n".join(result_lines)

    def backup_dockerfile(self, dockerfile_path: str) -> str:
        """
        Create a backup of the original Dockerfile.

        Args:
            dockerfile_path: Path to the Dockerfile

        Returns:
            Path to the backup file

        Raises:
            DockerfileUpdateError: If backup creation fails
        """
        if not os.path.exists(dockerfile_path):
            raise DockerfileUpdateError(
                f"Dockerfile not found: {dockerfile_path}",
                dockerfile_path=dockerfile_path
            )

        if not os.access(dockerfile_path, os.R_OK):
            raise DockerfileUpdateError(
                f"Cannot read Dockerfile: {dockerfile_path}",
                dockerfile_path=dockerfile_path
            )

        # Create backup filename with timestamp
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_path = f"{dockerfile_path}.backup_{timestamp}"

        try:
            shutil.copy2(dockerfile_path, backup_path)
            return backup_path
        except (OSError, IOError) as e:
            raise DockerfileUpdateError(
                f"Failed to create backup: {str(e)}",
                dockerfile_path=dockerfile_path
            )
