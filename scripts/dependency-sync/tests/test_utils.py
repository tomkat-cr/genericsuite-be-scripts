"""
Test utilities for dependency sync tests.
"""

import os
import tempfile
import shutil
from pathlib import Path
from typing import Dict, List, Optional
import pytest


class FileManager:
    """Utility class for managing test files and directories."""

    def __init__(self):
        self.temp_dirs = []
        self.temp_files = []

    def create_temp_dir(self) -> str:
        """Create a temporary directory and track it for cleanup."""
        temp_dir = tempfile.mkdtemp()
        self.temp_dirs.append(temp_dir)
        return temp_dir

    def create_temp_file(self, content: str, suffix: str = ".tmp") -> str:
        """Create a temporary file with content and track it for cleanup."""
        fd, temp_file = tempfile.mkstemp(suffix=suffix)
        try:
            with os.fdopen(fd, 'w') as f:
                f.write(content)
        except:
            os.close(fd)
            raise
        self.temp_files.append(temp_file)
        return temp_file

    def create_pyproject_file(self, dependencies: Dict[str, str], temp_dir: str,
                              filename: str = "pyproject.toml") -> str:
        """Create a pyproject.toml file with specified dependencies."""
        content = """[tool.poetry]
name = "test-project"
version = "0.1.0"
description = "Test project"

[tool.poetry.dependencies]
python = "^3.8"
"""
        for name, constraint in dependencies.items():
            if constraint.startswith("{"):
                # Handle complex dependency format
                content += f'{name} = {constraint}\n'
            else:
                content += f'{name} = "{constraint}"\n'

        file_path = os.path.join(temp_dir, filename)
        with open(file_path, 'w') as f:
            f.write(content)
        return file_path

    def create_dockerfile(self, pip_dependencies: List[str], temp_dir: str,
                          filename: str = "Dockerfile") -> str:
        """Create a Dockerfile with specified pip dependencies."""
        deps_str = " \\\n    ".join([f'"{dep}"' for dep in pip_dependencies])
        content = f"""FROM python:3.9

WORKDIR /app

RUN pip install --upgrade pip && pip install --no-cache-dir \\
    {deps_str}

COPY . .

CMD ["python", "main.py"]
"""
        file_path = os.path.join(temp_dir, filename)
        with open(file_path, 'w') as f:
            f.write(content)
        return file_path

    def cleanup(self):
        """Clean up all temporary files and directories."""
        for temp_file in self.temp_files:
            try:
                os.unlink(temp_file)
            except (OSError, FileNotFoundError):
                pass

        for temp_dir in self.temp_dirs:
            try:
                shutil.rmtree(temp_dir)
            except (OSError, FileNotFoundError):
                pass

        self.temp_files.clear()
        self.temp_dirs.clear()


@pytest.fixture
def file_manager():
    """Pytest fixture that provides a FileManager and cleans up after tests."""
    manager = FileManager()
    yield manager
    manager.cleanup()


@pytest.fixture
def fixtures_dir():
    """Get the path to the test fixtures directory."""
    return Path(__file__).parent / "fixtures"


def load_fixture(fixtures_dir: Path, filename: str) -> str:
    """Load content from a fixture file."""
    fixture_path = fixtures_dir / filename
    if not fixture_path.exists():
        raise FileNotFoundError(f"Fixture file not found: {fixture_path}")

    with open(fixture_path, 'r') as f:
        return f.read()


def assert_dockerfile_contains_dependencies(dockerfile_path: str,
                                            expected_deps: List[str]):
    """Assert that a Dockerfile contains all expected dependencies."""
    with open(dockerfile_path, 'r') as f:
        content = f.read()

    for dep in expected_deps:
        assert dep in content, f"Dependency '{dep}' not found in Dockerfile"


def assert_dockerfile_not_contains_dependencies(dockerfile_path: str,
                                                unexpected_deps: List[str]):
    """Assert that a Dockerfile does not contain any unexpected dependencies."""
    with open(dockerfile_path, 'r') as f:
        content = f.read()

    for dep in unexpected_deps:
        assert dep not in content, f"Unexpected dependency '{dep}' found in Dockerfile"


def extract_pip_dependencies_from_dockerfile(dockerfile_path: str) -> List[str]:
    """Extract pip dependencies from a Dockerfile."""
    import re

    with open(dockerfile_path, 'r') as f:
        content = f.read()

    # Pattern to match pip install commands with dependencies
    pattern = r'RUN pip install[^&]*?--no-cache-dir\s*\\?\s*\n((?:\s*"[^"]+"\s*\\?\s*\n?)*)'
    match = re.search(pattern, content, re.MULTILINE | re.DOTALL)

    if not match:
        return []

    deps_section = match.group(1)
    # Extract individual dependencies
    dep_pattern = r'"([^"]+)"'
    dependencies = re.findall(dep_pattern, deps_section)

    return dependencies


class MockSyncResult:
    """Mock SyncResult for testing."""

    def __init__(self, success: bool = True, dependencies_processed: int = 0,
                 conflicts_resolved: int = 0, changes_made: Optional[List[str]] = None,
                 errors: Optional[List[str]] = None, backup_file: Optional[str] = None):
        self.success = success
        self.dependencies_processed = dependencies_processed
        self.conflicts_resolved = conflicts_resolved
        self.changes_made = changes_made or []
        self.errors = errors or []
        self.backup_file = backup_file


class MockSyncConfig:
    """Mock SyncConfig for testing."""

    def __init__(self, source_files: List[str], target_dockerfile: str,
                 verbose: bool = False, quiet: bool = True, backup: bool = True,
                 dry_run: bool = False):
        self.source_files = source_files
        self.target_dockerfile = target_dockerfile
        self.verbose = verbose
        self.quiet = quiet
        self.backup = backup
        self.dry_run = dry_run


# Test data constants
SAMPLE_DEPENDENCIES = {
    "fastapi": "^0.104.1",
    "uvicorn": '{extras = ["standard"], version = "^0.24.0"}',
    "pydantic": ">=2.0.0",
    "requests": "~2.31.0",
    "click": "8.1.7",
    "numpy": "*"
}

EXPECTED_PIP_DEPENDENCIES = [
    "fastapi>=0.104.1,<1.0.0",
    "uvicorn[standard]>=0.24.0,<1.0.0",
    "pydantic>=2.0.0",
    "requests>=2.31.0,<2.32.0",
    "click==8.1.7",
    "numpy"
]

CONFLICTING_DEPENDENCIES_SET1 = {
    "requests": "^2.28.0",
    "fastapi": ">=0.100.0",
    "pydantic": "^2.0.0"
}

CONFLICTING_DEPENDENCIES_SET2 = {
    "requests": "~2.30.0",
    "fastapi": "^0.104.0",
    "pydantic": ">=1.10.0"
}
