"""
Integration tests for the complete dependency sync workflow.
"""

from .test_utils import (
    FileManager,
    assert_dockerfile_contains_dependencies,
    assert_dockerfile_not_contains_dependencies,
    extract_pip_dependencies_from_dockerfile,
    SAMPLE_DEPENDENCIES,
    EXPECTED_PIP_DEPENDENCIES
)
from exceptions import DependencySyncError
from data_types import SyncConfig, SyncResult
from sync_dependencies import DependencySync
import os
import tempfile
import shutil
from pathlib import Path
import pytest

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


class TestDependencySyncIntegration:
    """Integration tests for the complete dependency sync workflow."""

    @pytest.fixture
    def temp_dir(self):
        """Create a temporary directory for test files."""
        temp_dir = tempfile.mkdtemp()
        yield temp_dir
        shutil.rmtree(temp_dir)

    @pytest.fixture
    def sample_pyproject_toml(self, temp_dir):
        """Create a sample pyproject.toml file."""
        content = """
[tool.poetry]
name = "test-project"
version = "0.1.0"

[tool.poetry.dependencies]
python = "^3.8"
requests = "^2.25.0"
fastapi = ">=0.68.0"
uvicorn = {extras = ["standard"], version = "^0.24.0"}
"""
        file_path = os.path.join(temp_dir, "pyproject.toml")
        with open(file_path, 'w') as f:
            f.write(content)
        return file_path

    @pytest.fixture
    def sample_dockerfile(self, temp_dir):
        """Create a sample Dockerfile."""
        content = """FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --upgrade pip && pip install --no-cache-dir \\
    "old-package==1.0.0" \\
    "another-package>=2.0.0"

COPY . .

CMD ["python", "app.py"]
"""
        file_path = os.path.join(temp_dir, "Dockerfile")
        with open(file_path, 'w') as f:
            f.write(content)
        return file_path

    @pytest.fixture
    def multiple_pyproject_files(self, temp_dir):
        """Create multiple pyproject.toml files for testing merging."""
        # First file
        content1 = """
[tool.poetry.dependencies]
python = "^3.8"
requests = "^2.25.0"
fastapi = ">=0.68.0"
"""
        file1 = os.path.join(temp_dir, "pyproject1.toml")
        with open(file1, 'w') as f:
            f.write(content1)

        # Second file
        content2 = """
[tool.poetry.dependencies]
python = "^3.8"
uvicorn = {extras = ["standard"], version = "^0.24.0"}
pydantic = "~1.8.0"
"""
        file2 = os.path.join(temp_dir, "pyproject2.toml")
        with open(file2, 'w') as f:
            f.write(content2)

        return [file1, file2]

    def test_complete_sync_workflow(self, sample_pyproject_toml, sample_dockerfile):
        """Test the complete synchronization workflow with a single file."""
        # Create configuration
        config = SyncConfig(
            source_files=[sample_pyproject_toml],
            target_dockerfile=sample_dockerfile,
            verbose=False,
            quiet=True,
            backup=True,
            dry_run=False
        )

        # Run synchronization
        sync = DependencySync()
        result = sync.sync_dependencies(config)

        # Verify results
        assert result.success is True
        assert result.dependencies_processed > 0
        assert len(result.changes_made) > 0
        assert len(result.errors) == 0
        assert result.backup_file is not None

        # Verify backup was created
        assert os.path.exists(result.backup_file)

        # Verify Dockerfile was updated
        with open(sample_dockerfile, 'r') as f:
            updated_content = f.read()

        # Should contain the new dependencies
        assert "requests" in updated_content
        assert "fastapi" in updated_content
        assert "uvicorn[standard]" in updated_content

        # Should not contain old dependencies
        assert "old-package" not in updated_content
        assert "another-package" not in updated_content

    def test_multiple_files_sync(self, multiple_pyproject_files, sample_dockerfile):
        """Test synchronization with multiple pyproject.toml files."""
        config = SyncConfig(
            source_files=multiple_pyproject_files,
            target_dockerfile=sample_dockerfile,
            verbose=False,
            quiet=True,
            backup=False,
            dry_run=False
        )

        sync = DependencySync()
        result = sync.sync_dependencies(config)

        # Verify results
        assert result.success is True
        assert result.dependencies_processed > 0
        assert len(result.errors) == 0

        # Verify Dockerfile contains dependencies from both files
        with open(sample_dockerfile, 'r') as f:
            updated_content = f.read()

        assert "requests" in updated_content
        assert "fastapi" in updated_content
        assert "uvicorn[standard]" in updated_content
        assert "pydantic" in updated_content

    def test_dry_run_mode(self, sample_pyproject_toml, sample_dockerfile):
        """Test dry run mode doesn't modify files."""
        # Read original content
        with open(sample_dockerfile, 'r') as f:
            original_content = f.read()

        config = SyncConfig(
            source_files=[sample_pyproject_toml],
            target_dockerfile=sample_dockerfile,
            verbose=False,
            quiet=True,
            backup=False,
            dry_run=True
        )

        sync = DependencySync()
        result = sync.sync_dependencies(config)

        # Verify results
        assert result.success is True
        assert "DRY RUN" in result.changes_made[0]

        # Verify file wasn't modified
        with open(sample_dockerfile, 'r') as f:
            current_content = f.read()

        assert current_content == original_content

    def test_missing_source_file(self, sample_dockerfile):
        """Test handling of missing source files."""
        config = SyncConfig(
            source_files=["/nonexistent/pyproject.toml"],
            target_dockerfile=sample_dockerfile,
            verbose=False,
            quiet=True,
            backup=False,
            dry_run=False
        )

        sync = DependencySync()
        result = sync.sync_dependencies(config)

        # Should fail gracefully
        assert result.success is False
        assert len(result.errors) > 0
        assert "not found" in result.errors[0].lower()

    def test_malformed_toml_file(self, sample_dockerfile, temp_dir):
        """Test handling of malformed TOML files."""
        # Create malformed TOML file
        malformed_file = os.path.join(temp_dir, "malformed.toml")
        with open(malformed_file, 'w') as f:
            f.write("invalid toml content [[[")

        config = SyncConfig(
            source_files=[malformed_file],
            target_dockerfile=sample_dockerfile,
            verbose=False,
            quiet=True,
            backup=False,
            dry_run=False
        )

        sync = DependencySync()
        result = sync.sync_dependencies(config)

        # Should fail gracefully
        assert result.success is False
        assert len(result.errors) > 0
        assert "toml" in result.errors[0].lower()

    def test_invalid_dockerfile(self, sample_pyproject_toml, temp_dir):
        """Test handling of Dockerfile without pip install command."""
        # Create Dockerfile without pip install
        invalid_dockerfile = os.path.join(temp_dir, "Dockerfile_invalid")
        with open(invalid_dockerfile, 'w') as f:
            f.write("FROM python:3.9\nCOPY . .\nCMD ['python', 'app.py']")

        config = SyncConfig(
            source_files=[sample_pyproject_toml],
            target_dockerfile=invalid_dockerfile,
            verbose=False,
            quiet=True,
            backup=False,
            dry_run=False
        )

        sync = DependencySync()
        result = sync.sync_dependencies(config)

        # Should fail gracefully
        assert result.success is False
        assert len(result.errors) > 0
        assert "pip install" in result.errors[0].lower()

    def test_version_constraint_translation(self, temp_dir, sample_dockerfile):
        """Test that version constraints are properly translated."""
        # Create pyproject.toml with various constraint types
        content = """
[tool.poetry.dependencies]
python = "^3.8"
caret_constraint = "^1.2.3"
tilde_constraint = "~2.1.0"
exact_constraint = "==3.0.0"
minimum_constraint = ">=4.5.0"
"""
        pyproject_file = os.path.join(temp_dir, "pyproject.toml")
        with open(pyproject_file, 'w') as f:
            f.write(content)

        config = SyncConfig(
            source_files=[pyproject_file],
            target_dockerfile=sample_dockerfile,
            verbose=False,
            quiet=True,
            backup=False,
            dry_run=False
        )

        sync = DependencySync()
        result = sync.sync_dependencies(config)

        assert result.success is True

        # Check that constraints were translated
        with open(sample_dockerfile, 'r') as f:
            content = f.read()

        # Caret constraint should be translated to range
        assert "caret_constraint>=1.2.3,<2.0.0" in content
        # Tilde constraint should be translated to range
        assert "tilde_constraint>=2.1.0,<2.2.0" in content
        # Exact constraint should remain exact
        assert "exact_constraint==3.0.0" in content
        # Minimum constraint should remain as-is
        assert "minimum_constraint>=4.5.0" in content

    def test_backup_creation(self, sample_pyproject_toml, sample_dockerfile):
        """Test that backup files are created correctly."""
        config = SyncConfig(
            source_files=[sample_pyproject_toml],
            target_dockerfile=sample_dockerfile,
            verbose=False,
            quiet=True,
            backup=True,
            dry_run=False
        )

        sync = DependencySync()
        result = sync.sync_dependencies(config)

        assert result.success is True
        assert result.backup_file is not None
        assert os.path.exists(result.backup_file)

        # Verify backup contains original content
        with open(result.backup_file, 'r') as f:
            backup_content = f.read()

        assert "old-package==1.0.0" in backup_content
        assert "another-package>=2.0.0" in backup_content

    def test_no_backup_option(self, sample_pyproject_toml, sample_dockerfile):
        """Test that backup is skipped when disabled."""
        config = SyncConfig(
            source_files=[sample_pyproject_toml],
            target_dockerfile=sample_dockerfile,
            verbose=False,
            quiet=True,
            backup=False,
            dry_run=False
        )

        sync = DependencySync()
        result = sync.sync_dependencies(config)

        assert result.success is True
        assert result.backup_file is None

        # Verify no backup files were created
        dockerfile_dir = os.path.dirname(sample_dockerfile)
        backup_files = [f for f in os.listdir(
            dockerfile_dir) if f.startswith("Dockerfile.backup")]
        assert len(backup_files) == 0

    @pytest.mark.integration
    def test_real_world_pyproject_files(self, temp_dir, fixtures_dir):
        """Test with real-world pyproject.toml files from the project."""
        # Use actual pyproject.toml files from the project
        server_pyproject = fixtures_dir / "complex_pyproject.toml"

        # Create a test Dockerfile
        dockerfile_content = """FROM python:3.11-slim

WORKDIR /app

RUN pip install --upgrade pip && pip install --no-cache-dir \\
    "old-dependency==1.0.0"

COPY . .
CMD ["python", "main.py"]
"""
        dockerfile_path = os.path.join(temp_dir, "Dockerfile")
        with open(dockerfile_path, 'w') as f:
            f.write(dockerfile_content)

        config = SyncConfig(
            source_files=[str(server_pyproject)],
            target_dockerfile=dockerfile_path,
            verbose=True,
            quiet=False,
            backup=True,
            dry_run=False
        )

        sync = DependencySync()
        result = sync.sync_dependencies(config)

        assert result.success is True
        assert result.dependencies_processed > 5  # Should have many dependencies

        # Verify complex dependencies are handled correctly
        with open(dockerfile_path, 'r') as f:
            content = f.read()

        # Check for properly translated constraints
        assert "fastapi>=0.104.1,<1.0.0" in content
        assert "pydantic>=2.5.0,<3.0.0" in content
        assert "requests>=2.31.0,<2.32.0" in content
        assert "uvicorn[standard]>=0.24.0,<1.0.0" in content
        assert "sqlalchemy[asyncio,postgresql]>=2.0.0,<3.0.0" in content

    @pytest.mark.integration
    def test_edge_case_dependencies(self, temp_dir, fixtures_dir):
        """Test handling of edge case dependencies."""
        edge_case_pyproject = fixtures_dir / "edge_case_pyproject.toml"

        dockerfile_content = """FROM python:3.9
RUN pip install --upgrade pip && pip install --no-cache-dir \\
    "placeholder==1.0.0"
COPY . .
CMD ["python", "main.py"]
"""
        dockerfile_path = os.path.join(temp_dir, "Dockerfile")
        with open(dockerfile_path, 'w') as f:
            f.write(dockerfile_content)

        config = SyncConfig(
            source_files=[str(edge_case_pyproject)],
            target_dockerfile=dockerfile_path,
            verbose=False,
            quiet=True,
            backup=False,
            dry_run=False
        )

        sync = DependencySync()
        result = sync.sync_dependencies(config)

        assert result.success is True

        with open(dockerfile_path, 'r') as f:
            content = f.read()

        # Verify edge cases are handled
        assert "package-with-hyphens>=1.0.0,<2.0.0" in content
        assert "package_with_underscores>=2.0.0,<3.0.0" in content
        assert "package123>=3.0.0,<4.0.0" in content
        assert "special-package==1.0.0a1" in content
        assert "beta-package==2.0.0b1" in content

    @pytest.mark.integration
    def test_conflicting_dependencies_resolution(self, temp_dir, fixtures_dir):
        """Test resolution of conflicting dependencies from multiple files."""
        conflicting_files = [
            fixtures_dir / "conflicting_pyproject1.toml",
            fixtures_dir / "conflicting_pyproject2.toml"
        ]

        dockerfile_content = """FROM python:3.9
RUN pip install --upgrade pip && pip install --no-cache-dir \\
    "old-dep==1.0.0"
COPY . .
CMD ["python", "main.py"]
"""
        dockerfile_path = os.path.join(temp_dir, "Dockerfile")
        with open(dockerfile_path, 'w') as f:
            f.write(dockerfile_content)

        config = SyncConfig(
            source_files=[str(f) for f in conflicting_files],
            target_dockerfile=dockerfile_path,
            verbose=True,
            quiet=False,
            backup=False,
            dry_run=False
        )

        sync = DependencySync()
        result = sync.sync_dependencies(config)

        assert result.success is True
        assert result.conflicts_resolved > 0

        with open(dockerfile_path, 'r') as f:
            content = f.read()

        # Verify conflicts were resolved (should use more restrictive constraints)
        # requests: ^2.28.0 vs ~2.30.0 -> should resolve to more restrictive
        # fastapi: >=0.100.0 vs ^0.104.0 -> should resolve to ^0.104.0
        assert "fastapi>=0.104.0,<1.0.0" in content
        # Should use the more restrictive ^2.0.0
        assert "pydantic>=2.0.0,<3.0.0" in content

    @pytest.mark.integration
    def test_different_dockerfile_formats(self, temp_dir, fixtures_dir):
        """Test with different Dockerfile formats."""
        pyproject_file = fixtures_dir / "valid_pyproject.toml"

        # Test with multiline Dockerfile
        multiline_dockerfile = fixtures_dir / "multiline_dockerfile"
        shutil.copy(multiline_dockerfile, os.path.join(
            temp_dir, "multiline_dockerfile"))
        multiline_path = os.path.join(temp_dir, "multiline_dockerfile")

        config = SyncConfig(
            source_files=[str(pyproject_file)],
            target_dockerfile=multiline_path,
            verbose=False,
            quiet=True,
            backup=False,
            dry_run=False
        )

        sync = DependencySync()
        result = sync.sync_dependencies(config)

        assert result.success is True

        # Test with single line Dockerfile
        single_line_dockerfile = fixtures_dir / "single_line_dockerfile"
        shutil.copy(single_line_dockerfile, os.path.join(
            temp_dir, "single_line_dockerfile"))
        single_line_path = os.path.join(temp_dir, "single_line_dockerfile")

        config.target_dockerfile = single_line_path
        result = sync.sync_dependencies(config)

        assert result.success is True

    @pytest.mark.integration
    def test_large_dependency_set(self, temp_dir):
        """Test with a large number of dependencies."""
        # Create a pyproject.toml with many dependencies
        large_deps_content = """[tool.poetry]
name = "large-project"
version = "1.0.0"

[tool.poetry.dependencies]
python = "^3.8"
"""
        # Add 50 dependencies
        for i in range(50):
            large_deps_content += f'package{i:02d} = "^{i % 5 + 1}.0.0"\n'

        pyproject_path = os.path.join(temp_dir, "pyproject.toml")
        with open(pyproject_path, 'w') as f:
            f.write(large_deps_content)

        dockerfile_content = """FROM python:3.9
RUN pip install --upgrade pip && pip install --no-cache-dir \\
    "placeholder==1.0.0"
COPY . .
CMD ["python", "main.py"]
"""
        dockerfile_path = os.path.join(temp_dir, "Dockerfile")
        with open(dockerfile_path, 'w') as f:
            f.write(dockerfile_content)

        config = SyncConfig(
            source_files=[pyproject_path],
            target_dockerfile=dockerfile_path,
            verbose=False,
            quiet=True,
            backup=False,
            dry_run=False
        )

        sync = DependencySync()
        result = sync.sync_dependencies(config)

        assert result.success is True
        assert result.dependencies_processed == 50

        # Verify all dependencies are in the Dockerfile
        with open(dockerfile_path, 'r') as f:
            content = f.read()

        for i in range(50):
            expected_dep = f"package{i:02d}>={i % 5 + 1}.0.0,<{i % 5 + 2}.0.0"
            assert expected_dep in content

    @pytest.mark.integration
    @pytest.mark.error_handling
    def test_recovery_from_partial_failures(self, temp_dir):
        """Test recovery from partial failures during processing."""
        # Create one valid and one invalid pyproject.toml file
        valid_content = """[tool.poetry]
name = "valid-project"
version = "1.0.0"

[tool.poetry.dependencies]
python = "^3.8"
requests = "^2.28.0"
"""
        valid_path = os.path.join(temp_dir, "valid.toml")
        with open(valid_path, 'w') as f:
            f.write(valid_content)

        invalid_content = """[tool.poetry]
name = "invalid-project"
version = "1.0.0"

[tool.poetry.dependencies
python = "^3.8"
fastapi = "^0.104.0"
"""
        invalid_path = os.path.join(temp_dir, "invalid.toml")
        with open(invalid_path, 'w') as f:
            f.write(invalid_content)

        dockerfile_content = """FROM python:3.9
RUN pip install --upgrade pip && pip install --no-cache-dir \\
    "old-dep==1.0.0"
COPY . .
CMD ["python", "main.py"]
"""
        dockerfile_path = os.path.join(temp_dir, "Dockerfile")
        with open(dockerfile_path, 'w') as f:
            f.write(dockerfile_content)

        config = SyncConfig(
            source_files=[valid_path, invalid_path],
            target_dockerfile=dockerfile_path,
            verbose=False,
            quiet=True,
            backup=False,
            dry_run=False
        )

        sync = DependencySync()
        result = sync.sync_dependencies(config)

        # Should partially succeed - process valid file despite invalid one
        assert len(result.errors) > 0  # Should have errors from invalid file
        # But should still process the valid dependencies
        assert result.dependencies_processed > 0

    @pytest.mark.integration
    def test_performance_with_multiple_files(self, temp_dir):
        """Test performance with multiple pyproject.toml files."""
        import time

        # Create 10 pyproject.toml files
        pyproject_files = []
        for i in range(10):
            content = f"""[tool.poetry]
name = "project-{i}"
version = "1.0.0"

[tool.poetry.dependencies]
python = "^3.8"
package{i} = "^{i + 1}.0.0"
common-package = "^1.0.0"
"""
            file_path = os.path.join(temp_dir, f"pyproject{i}.toml")
            with open(file_path, 'w') as f:
                f.write(content)
            pyproject_files.append(file_path)

        dockerfile_content = """FROM python:3.9
RUN pip install --upgrade pip && pip install --no-cache-dir \\
    "old-dep==1.0.0"
COPY . .
CMD ["python", "main.py"]
"""
        dockerfile_path = os.path.join(temp_dir, "Dockerfile")
        with open(dockerfile_path, 'w') as f:
            f.write(dockerfile_content)

        config = SyncConfig(
            source_files=pyproject_files,
            target_dockerfile=dockerfile_path,
            verbose=False,
            quiet=True,
            backup=False,
            dry_run=False
        )

        start_time = time.time()
        sync = DependencySync()
        result = sync.sync_dependencies(config)
        end_time = time.time()

        assert result.success is True
        assert result.dependencies_processed >= 10  # At least one from each file

        # Should complete in reasonable time (less than 5 seconds)
        processing_time = end_time - start_time
        assert processing_time < 5.0, f"Processing took too long: {processing_time:.2f}s"

    @pytest.mark.integration
    def test_output_format_validation(self, temp_dir, fixtures_dir):
        """Test that output matches expected pip install format exactly."""
        pyproject_file = fixtures_dir / "valid_pyproject.toml"

        dockerfile_content = """FROM python:3.9
RUN pip install --upgrade pip && pip install --no-cache-dir \\
    "old-dep==1.0.0"
COPY . .
CMD ["python", "main.py"]
"""
        dockerfile_path = os.path.join(temp_dir, "Dockerfile")
        with open(dockerfile_path, 'w') as f:
            f.write(dockerfile_content)

        config = SyncConfig(
            source_files=[str(pyproject_file)],
            target_dockerfile=dockerfile_path,
            verbose=False,
            quiet=True,
            backup=False,
            dry_run=False
        )

        sync = DependencySync()
        result = sync.sync_dependencies(config)

        assert result.success is True

        # Extract and validate the pip dependencies format
        dependencies = extract_pip_dependencies_from_dockerfile(
            dockerfile_path)

        # Verify format is correct
        for dep in dependencies:
            # Should be quoted strings with proper version constraints
            assert not dep.startswith(
                '"'), f"Dependency should not have quotes: {dep}"
            assert not dep.endswith(
                '"'), f"Dependency should not have quotes: {dep}"

            # Should have proper version constraints
            if "==" in dep or ">=" in dep or "<" in dep:
                # Has version constraint - verify format
                if "[" in dep:
                    # Has extras - verify format
                    assert dep.count("[") == 1, f"Invalid extras format: {dep}"
                    assert dep.count("]") == 1, f"Invalid extras format: {dep}"

        # Verify specific expected dependencies
        expected_deps = [
            "fastapi>=0.104.1,<1.0.0",
            "uvicorn[standard]>=0.24.0,<1.0.0",
            "pydantic>=2.0.0",
            "requests>=2.31.0,<2.32.0",
            "click==8.1.7",
            "numpy"
        ]

        for expected_dep in expected_deps:
            assert expected_dep in dependencies, f"Expected dependency not found: {expected_dep}"

    @pytest.mark.integration
    @pytest.mark.slow
    def test_stress_test_with_complex_scenarios(self, temp_dir):
        """Stress test with complex dependency scenarios."""
        # Create a very complex pyproject.toml
        complex_content = """[tool.poetry]
name = "stress-test-project"
version = "1.0.0"

[tool.poetry.dependencies]
python = "^3.8"
# Mix of all constraint types
caret-dep1 = "^1.2.3"
caret-dep2 = "^2.0.0"
tilde-dep1 = "~1.5.0"
tilde-dep2 = "~3.2.1"
exact-dep1 = "==4.0.0"
exact-dep2 = "1.0.0"
range-dep1 = ">=1.0.0,<2.0.0"
range-dep2 = ">=2.5.0,<3.0.0"
# Dependencies with extras
extras-dep1 = {extras = ["extra1"], version = "^1.0.0"}
extras-dep2 = {extras = ["extra1", "extra2"], version = "~2.0.0"}
extras-dep3 = {extras = ["standard", "full"], version = ">=3.0.0"}
# Wildcard
wildcard-dep = "*"
# Pre-release versions
prerelease-dep1 = "1.0.0a1"
prerelease-dep2 = "2.0.0b2"
prerelease-dep3 = "3.0.0rc1"
# Complex package names
package-with-many-hyphens = "^1.0.0"
package_with_many_underscores = "^2.0.0"
Package-With-Mixed-Case = "^3.0.0"
"""

        pyproject_path = os.path.join(temp_dir, "pyproject.toml")
        with open(pyproject_path, 'w') as f:
            f.write(complex_content)

        dockerfile_content = """FROM python:3.11-slim

WORKDIR /app

RUN pip install --upgrade pip && pip install --no-cache-dir \\
    "stress-test-placeholder==1.0.0"

COPY . .
CMD ["python", "main.py"]
"""
        dockerfile_path = os.path.join(temp_dir, "Dockerfile")
        with open(dockerfile_path, 'w') as f:
            f.write(dockerfile_content)

        config = SyncConfig(
            source_files=[pyproject_path],
            target_dockerfile=dockerfile_path,
            verbose=True,
            quiet=False,
            backup=True,
            dry_run=False
        )

        sync = DependencySync()
        result = sync.sync_dependencies(config)

        assert result.success is True
        assert result.dependencies_processed > 15
        assert result.backup_file is not None

        # Verify all complex dependencies were processed correctly
        with open(dockerfile_path, 'r') as f:
            content = f.read()

        # Verify various constraint types
        assert "caret-dep1>=1.2.3,<2.0.0" in content
        assert "tilde-dep1>=1.5.0,<1.6.0" in content
        assert "exact-dep1==4.0.0" in content
        assert "range-dep1>=1.0.0,<2.0.0" in content
        assert "extras-dep1[extra1]>=1.0.0,<2.0.0" in content
        assert "extras-dep2[extra1,extra2]>=2.0.0,<2.1.0" in content
        assert "wildcard-dep" in content
        assert "prerelease-dep1==1.0.0a1" in content
