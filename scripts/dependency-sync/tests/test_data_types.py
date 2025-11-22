"""
Unit tests for data types module.
"""

import pytest
from data_types import Dependency, SyncConfig, SyncResult


class TestDependency:
    """Test cases for Dependency dataclass."""
    
    def test_dependency_creation(self):
        """Test basic dependency creation."""
        dep = Dependency(name="requests", constraint=">=2.25.0")
        assert dep.name == "requests"
        assert dep.constraint == ">=2.25.0"
        assert dep.extras is None
        assert dep.source_file == ""
    
    def test_dependency_with_extras(self):
        """Test dependency creation with extras."""
        dep = Dependency(
            name="uvicorn",
            constraint=">=0.24.0",
            extras=["standard"],
            source_file="server/pyproject.toml"
        )
        assert dep.name == "uvicorn"
        assert dep.constraint == ">=0.24.0"
        assert dep.extras == ["standard"]
        assert dep.source_file == "server/pyproject.toml"
    
    def test_to_pip_format_basic(self):
        """Test basic pip format conversion."""
        dep = Dependency(name="requests", constraint=">=2.25.0")
        assert dep.to_pip_format() == "requests>=2.25.0"
    
    def test_to_pip_format_with_extras(self):
        """Test pip format conversion with extras."""
        dep = Dependency(name="uvicorn", constraint=">=0.24.0", extras=["standard"])
        assert dep.to_pip_format() == "uvicorn[standard]>=0.24.0"
    
    def test_to_pip_format_multiple_extras(self):
        """Test pip format conversion with multiple extras."""
        dep = Dependency(name="uvicorn", constraint=">=0.24.0", extras=["standard", "watchfiles"])
        assert dep.to_pip_format() == "uvicorn[standard,watchfiles]>=0.24.0"
    
    def test_to_pip_format_no_constraint(self):
        """Test pip format conversion without constraint."""
        dep = Dependency(name="requests", constraint="")
        assert dep.to_pip_format() == "requests"
    
    def test_to_pip_format_wildcard_constraint(self):
        """Test pip format conversion with wildcard constraint."""
        dep = Dependency(name="requests", constraint="*")
        assert dep.to_pip_format() == "requests"
    
    def test_str_representation(self):
        """Test string representation of dependency."""
        dep = Dependency(name="requests", constraint=">=2.25.0")
        assert str(dep) == "requests>=2.25.0"


class TestSyncConfig:
    """Test cases for SyncConfig dataclass."""
    
    def test_sync_config_creation(self):
        """Test basic sync config creation."""
        config = SyncConfig(
            source_files=["server/pyproject.toml"],
            target_dockerfile="deploy/docker_images/Dockerfile"
        )
        assert config.source_files == ["server/pyproject.toml"]
        assert config.target_dockerfile == "deploy/docker_images/Dockerfile"
        assert config.verbose is False
        assert config.quiet is False
        assert config.backup is True
        assert config.dry_run is False
    
    def test_sync_config_with_options(self):
        """Test sync config creation with all options."""
        config = SyncConfig(
            source_files=["server/pyproject.toml", "mcp-server/pyproject.toml"],
            target_dockerfile="deploy/docker_images/Dockerfile",
            verbose=True,
            quiet=False,
            backup=False,
            dry_run=True
        )
        assert config.source_files == ["server/pyproject.toml", "mcp-server/pyproject.toml"]
        assert config.target_dockerfile == "deploy/docker_images/Dockerfile"
        assert config.verbose is True
        assert config.quiet is False
        assert config.backup is False
        assert config.dry_run is True
    
    def test_sync_config_validation_empty_source_files(self):
        """Test sync config validation with empty source files."""
        with pytest.raises(ValueError, match="At least one source file must be specified"):
            SyncConfig(
                source_files=[],
                target_dockerfile="deploy/docker_images/Dockerfile"
            )
    
    def test_sync_config_validation_empty_target(self):
        """Test sync config validation with empty target dockerfile."""
        with pytest.raises(ValueError, match="Target dockerfile must be specified"):
            SyncConfig(
                source_files=["server/pyproject.toml"],
                target_dockerfile=""
            )


class TestSyncResult:
    """Test cases for SyncResult dataclass."""
    
    def test_sync_result_creation(self):
        """Test basic sync result creation."""
        result = SyncResult(
            success=True,
            dependencies_processed=5,
            conflicts_resolved=1,
            changes_made=["Updated pip install command"],
            errors=[]
        )
        assert result.success is True
        assert result.dependencies_processed == 5
        assert result.conflicts_resolved == 1
        assert result.changes_made == ["Updated pip install command"]
        assert result.errors == []
        assert result.backup_file is None
    
    def test_sync_result_with_backup(self):
        """Test sync result creation with backup file."""
        result = SyncResult(
            success=True,
            dependencies_processed=3,
            conflicts_resolved=0,
            changes_made=["Updated dependencies"],
            errors=[],
            backup_file="Dockerfile.backup_20231201_120000"
        )
        assert result.backup_file == "Dockerfile.backup_20231201_120000"
    
    def test_sync_result_post_init_none_lists(self):
        """Test sync result post_init with None lists."""
        result = SyncResult(
            success=True,
            dependencies_processed=0,
            conflicts_resolved=0,
            changes_made=None,
            errors=None
        )
        assert result.changes_made == []
        assert result.errors == []
    
    def test_add_change(self):
        """Test adding changes to sync result."""
        result = SyncResult(
            success=True,
            dependencies_processed=0,
            conflicts_resolved=0,
            changes_made=[],
            errors=[]
        )
        result.add_change("Added new dependency")
        result.add_change("Updated existing dependency")
        
        assert len(result.changes_made) == 2
        assert "Added new dependency" in result.changes_made
        assert "Updated existing dependency" in result.changes_made
    
    def test_add_error(self):
        """Test adding errors to sync result."""
        result = SyncResult(
            success=True,
            dependencies_processed=0,
            conflicts_resolved=0,
            changes_made=[],
            errors=[]
        )
        result.add_error("Failed to parse file")
        result.add_error("Permission denied")
        
        assert len(result.errors) == 2
        assert "Failed to parse file" in result.errors
        assert "Permission denied" in result.errors
        assert result.success is False  # Should be set to False when error is added
    
    def test_has_errors(self):
        """Test has_errors method."""
        result = SyncResult(
            success=True,
            dependencies_processed=0,
            conflicts_resolved=0,
            changes_made=[],
            errors=[]
        )
        assert result.has_errors() is False
        
        result.add_error("Some error")
        assert result.has_errors() is True
    
    def test_summary_success(self):
        """Test summary generation for successful sync."""
        result = SyncResult(
            success=True,
            dependencies_processed=5,
            conflicts_resolved=2,
            changes_made=["Updated pip install", "Resolved conflicts"],
            errors=[],
            backup_file="Dockerfile.backup_20231201_120000"
        )
        
        summary = result.summary()
        assert "Sync Status: SUCCESS" in summary
        assert "Dependencies Processed: 5" in summary
        assert "Conflicts Resolved: 2" in summary
        assert "Changes Made: 2" in summary
        assert "Backup Created: Dockerfile.backup_20231201_120000" in summary
        assert "Errors:" not in summary
    
    def test_summary_failure(self):
        """Test summary generation for failed sync."""
        result = SyncResult(
            success=False,
            dependencies_processed=3,
            conflicts_resolved=0,
            changes_made=["Partial update"],
            errors=["File not found", "Permission denied"]
        )
        
        summary = result.summary()
        assert "Sync Status: FAILED" in summary
        assert "Dependencies Processed: 3" in summary
        assert "Conflicts Resolved: 0" in summary
        assert "Changes Made: 1" in summary
        assert "Errors: 2" in summary
        assert "Backup Created:" not in summary