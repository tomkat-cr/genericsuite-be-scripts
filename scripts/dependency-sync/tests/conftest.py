"""
Shared pytest fixtures for dependency sync tests.
"""

import os
import tempfile
import shutil
from pathlib import Path
import pytest

from .test_utils import FileManager, load_fixture


@pytest.fixture(scope="session")
def fixtures_dir():
    """Get the path to the test fixtures directory."""
    return Path(__file__).parent / "fixtures"


@pytest.fixture
def temp_dir():
    """Create a temporary directory for test files."""
    temp_dir = tempfile.mkdtemp()
    yield temp_dir
    shutil.rmtree(temp_dir, ignore_errors=True)


@pytest.fixture
def file_manager():
    """Provide a FileManager instance for managing test files."""
    manager = FileManager()
    yield manager
    manager.cleanup()


@pytest.fixture
def sample_pyproject_content():
    """Sample pyproject.toml content for testing."""
    return """[tool.poetry]
name = "test-project"
version = "0.1.0"
description = "Test project for dependency sync"

[tool.poetry.dependencies]
python = "^3.8"
fastapi = "^0.104.1"
uvicorn = {extras = ["standard"], version = "^0.24.0"}
pydantic = ">=2.0.0"
requests = "~2.31.0"
click = "8.1.7"
numpy = "*"
"""


@pytest.fixture
def sample_dockerfile_content():
    """Sample Dockerfile content for testing."""
    return """FROM python:3.9

WORKDIR /app

RUN pip install --upgrade pip && pip install --no-cache-dir \\
    "old-package==1.0.0" \\
    "another-package>=2.0.0"

COPY . .

CMD ["python", "main.py"]
"""


@pytest.fixture
def complex_pyproject_content():
    """Complex pyproject.toml content with various dependency types."""
    return """[tool.poetry]
name = "complex-project"
version = "1.0.0"

[tool.poetry.dependencies]
python = "^3.8"
fastapi = "^0.104.1"
pydantic = "^2.5.0"
requests = "~2.31.0"
click = "8.1.7"
numpy = ">=1.24.0"
pandas = ">=1.5.0,<3.0.0"
uvicorn = {extras = ["standard"], version = "^0.24.0"}
sqlalchemy = {extras = ["asyncio", "postgresql"], version = "^2.0.0"}
pytest = "*"
django = ">=4.0.0,<5.0.0"
"""


@pytest.fixture
def multiline_dockerfile_content():
    """Multiline Dockerfile content for testing."""
    return """FROM python:3.11-slim

WORKDIR /app

RUN pip install --upgrade pip && pip install --no-cache-dir \\
    "fastapi>=0.68.0" \\
    "uvicorn[standard]>=0.15.0" \\
    "pydantic>=1.8.0" \\
    "requests>=2.25.0" \\
    "click>=8.0.0"

COPY . .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
"""


@pytest.fixture
def create_test_files(temp_dir):
    """Factory fixture for creating test files."""
    def _create_files(pyproject_content: str, dockerfile_content: str):
        pyproject_path = os.path.join(temp_dir, "pyproject.toml")
        dockerfile_path = os.path.join(temp_dir, "Dockerfile")
        
        with open(pyproject_path, 'w') as f:
            f.write(pyproject_content)
        
        with open(dockerfile_path, 'w') as f:
            f.write(dockerfile_content)
        
        return pyproject_path, dockerfile_path
    
    return _create_files


@pytest.fixture
def create_multiple_pyproject_files(temp_dir):
    """Factory fixture for creating multiple pyproject.toml files."""
    def _create_files(*contents):
        files = []
        for i, content in enumerate(contents):
            file_path = os.path.join(temp_dir, f"pyproject{i+1}.toml")
            with open(file_path, 'w') as f:
                f.write(content)
            files.append(file_path)
        return files
    
    return _create_files


@pytest.fixture
def load_fixture_file(fixtures_dir):
    """Factory fixture for loading fixture files."""
    def _load_fixture(filename: str) -> str:
        return load_fixture(fixtures_dir, filename)
    
    return _load_fixture


# Parametrized fixtures for testing different scenarios
@pytest.fixture(params=[
    "valid_pyproject.toml",
    "complex_pyproject.toml",
    "edge_case_pyproject.toml"
])
def pyproject_fixture_file(request, fixtures_dir):
    """Parametrized fixture that provides different pyproject.toml files."""
    return fixtures_dir / request.param


@pytest.fixture(params=[
    "valid_dockerfile",
    "multiline_dockerfile",
    "single_line_dockerfile"
])
def dockerfile_fixture_file(request, fixtures_dir):
    """Parametrized fixture that provides different Dockerfile formats."""
    return fixtures_dir / request.param


@pytest.fixture(params=[
    ("conflicting_pyproject1.toml", "conflicting_pyproject2.toml"),
])
def conflicting_pyproject_files(request, fixtures_dir):
    """Parametrized fixture that provides conflicting pyproject.toml files."""
    file1, file2 = request.param
    return fixtures_dir / file1, fixtures_dir / file2


# Error scenario fixtures
@pytest.fixture
def malformed_toml_file(temp_dir):
    """Create a malformed TOML file for error testing."""
    content = """[tool.poetry]
name = "test-project"
version = "0.1.0"
description = "Malformed TOML file

[tool.poetry.dependencies
python = "^3.8"
fastapi = "^0.104.1"
"""
    file_path = os.path.join(temp_dir, "malformed.toml")
    with open(file_path, 'w') as f:
        f.write(content)
    return file_path


@pytest.fixture
def dockerfile_without_pip(temp_dir):
    """Create a Dockerfile without pip install commands."""
    content = """FROM python:3.9

COPY . /app
WORKDIR /app

RUN echo "No pip install commands here"

CMD ["python", "main.py"]
"""
    file_path = os.path.join(temp_dir, "Dockerfile")
    with open(file_path, 'w') as f:
        f.write(content)
    return file_path


@pytest.fixture
def readonly_dockerfile(temp_dir):
    """Create a read-only Dockerfile for permission testing."""
    content = """FROM python:3.9

RUN pip install --upgrade pip && pip install --no-cache-dir \\
    "fastapi>=0.68.0"

COPY . /app
CMD ["python", "main.py"]
"""
    file_path = os.path.join(temp_dir, "Dockerfile")
    with open(file_path, 'w') as f:
        f.write(content)
    
    # Make file read-only
    os.chmod(file_path, 0o444)
    
    yield file_path
    
    # Restore write permissions for cleanup
    try:
        os.chmod(file_path, 0o644)
    except (OSError, FileNotFoundError):
        pass