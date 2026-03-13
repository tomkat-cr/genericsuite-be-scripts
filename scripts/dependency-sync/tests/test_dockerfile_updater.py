"""
Unit tests for DockerfileUpdater class.
"""

import os
import tempfile
import pytest
import sys
from pathlib import Path
from unittest.mock import patch, mock_open

# Add the parent directory to the path so we can import the modules
sys.path.insert(0, str(Path(__file__).parent.parent))

from dockerfile_updater import DockerfileUpdater
from exceptions import DockerfileUpdateError


class TestDockerfileUpdater:
    """Test cases for DockerfileUpdater class."""
    
    def setup_method(self):
        """Set up test fixtures."""
        self.updater = DockerfileUpdater()
    
    def test_backup_dockerfile_success(self):
        """Test successful Dockerfile backup creation."""
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.Dockerfile') as temp_file:
            temp_file.write("FROM python:3.9\nRUN pip install requests\n")
            temp_file.flush()
            dockerfile_path = temp_file.name
        
        try:
            # Create backup
            backup_path = self.updater.backup_dockerfile(dockerfile_path)
            
            # Verify backup was created
            assert os.path.exists(backup_path)
            assert backup_path.startswith(f"{dockerfile_path}.backup_")
            
            # Verify backup content matches original
            with open(dockerfile_path, 'r') as original:
                original_content = original.read()
            with open(backup_path, 'r') as backup:
                backup_content = backup.read()
            
            assert original_content == backup_content
            
            # Clean up
            os.unlink(backup_path)
        finally:
            os.unlink(dockerfile_path)
    
    def test_backup_dockerfile_file_not_found(self):
        """Test backup creation when Dockerfile doesn't exist."""
        non_existent_path = "/path/that/does/not/exist/Dockerfile"
        
        with pytest.raises(DockerfileUpdateError) as exc_info:
            self.updater.backup_dockerfile(non_existent_path)
        
        assert "Dockerfile not found" in str(exc_info.value)
        assert non_existent_path in str(exc_info.value)
    
    def test_backup_dockerfile_permission_denied(self):
        """Test backup creation when file is not readable."""
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.Dockerfile') as temp_file:
            temp_file.write("FROM python:3.9\n")
            dockerfile_path = temp_file.name
        
        try:
            # Remove read permissions
            os.chmod(dockerfile_path, 0o000)
            
            with pytest.raises(DockerfileUpdateError) as exc_info:
                self.updater.backup_dockerfile(dockerfile_path)
            
            assert "Cannot read Dockerfile" in str(exc_info.value)
        finally:
            # Restore permissions and clean up
            os.chmod(dockerfile_path, 0o644)
            os.unlink(dockerfile_path)
    
    @patch('shutil.copy2')
    def test_backup_dockerfile_copy_fails(self, mock_copy):
        """Test backup creation when copy operation fails."""
        mock_copy.side_effect = OSError("Disk full")
        
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.Dockerfile') as temp_file:
            temp_file.write("FROM python:3.9\n")
            dockerfile_path = temp_file.name
        
        try:
            with pytest.raises(DockerfileUpdateError) as exc_info:
                self.updater.backup_dockerfile(dockerfile_path)
            
            assert "Failed to create backup" in str(exc_info.value)
            assert "Disk full" in str(exc_info.value)
        finally:
            os.unlink(dockerfile_path)
    
    def test_read_dockerfile_success(self):
        """Test successful Dockerfile reading."""
        content = "FROM python:3.9\nRUN pip install requests\nCOPY . /app\n"
        
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.Dockerfile') as temp_file:
            temp_file.write(content)
            dockerfile_path = temp_file.name
        
        try:
            result = self.updater._read_dockerfile(dockerfile_path)
            assert result == content
        finally:
            os.unlink(dockerfile_path)
    
    def test_read_dockerfile_file_not_found(self):
        """Test reading non-existent Dockerfile."""
        non_existent_path = "/path/that/does/not/exist/Dockerfile"
        
        with pytest.raises(DockerfileUpdateError) as exc_info:
            self.updater._read_dockerfile(non_existent_path)
        
        assert "Dockerfile not found" in str(exc_info.value)
    
    def test_read_dockerfile_permission_denied(self):
        """Test reading Dockerfile without permissions."""
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.Dockerfile') as temp_file:
            temp_file.write("FROM python:3.9\n")
            dockerfile_path = temp_file.name
        
        try:
            # Remove read permissions
            os.chmod(dockerfile_path, 0o000)
            
            with pytest.raises(DockerfileUpdateError) as exc_info:
                self.updater._read_dockerfile(dockerfile_path)
            
            assert "Cannot read Dockerfile" in str(exc_info.value)
        finally:
            # Restore permissions and clean up
            os.chmod(dockerfile_path, 0o644)
            os.unlink(dockerfile_path)
    
    @patch('os.path.exists', return_value=True)
    @patch('os.access', return_value=True)
    @patch('builtins.open', side_effect=UnicodeDecodeError('utf-8', b'', 0, 1, 'invalid'))
    def test_read_dockerfile_unicode_error(self, mock_open, mock_access, mock_exists):
        """Test reading Dockerfile with unicode decode error."""
        with pytest.raises(DockerfileUpdateError) as exc_info:
            self.updater._read_dockerfile("test_dockerfile")
        
        assert "Failed to read Dockerfile" in str(exc_info.value)
    
    def test_write_dockerfile_success(self):
        """Test successful Dockerfile writing."""
        content = "FROM python:3.9\nRUN pip install requests\n"
        
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.Dockerfile') as temp_file:
            dockerfile_path = temp_file.name
        
        try:
            self.updater._write_dockerfile(dockerfile_path, content)
            
            # Verify content was written correctly
            with open(dockerfile_path, 'r') as f:
                written_content = f.read()
            
            assert written_content == content
        finally:
            os.unlink(dockerfile_path)
    
    def test_write_dockerfile_permission_denied(self):
        """Test writing Dockerfile to directory without permissions."""
        with tempfile.TemporaryDirectory() as temp_dir:
            # Remove write permissions from directory
            os.chmod(temp_dir, 0o444)
            dockerfile_path = os.path.join(temp_dir, "Dockerfile")
            
            try:
                with pytest.raises(DockerfileUpdateError) as exc_info:
                    self.updater._write_dockerfile(dockerfile_path, "FROM python:3.9\n")
                
                assert "Cannot write to directory" in str(exc_info.value)
            finally:
                # Restore permissions
                os.chmod(temp_dir, 0o755)
    
    @patch('builtins.open', side_effect=OSError("Disk full"))
    def test_write_dockerfile_io_error(self, mock_open):
        """Test writing Dockerfile when IO error occurs."""
        with pytest.raises(DockerfileUpdateError) as exc_info:
            self.updater._write_dockerfile("test_dockerfile", "content")
        
        assert "Failed to write Dockerfile" in str(exc_info.value)
        assert "Disk full" in str(exc_info.value)
    
    def test_find_pip_install_block_success(self):
        """Test successful pip install block detection."""
        dockerfile_content = """FROM python:3.9

RUN pip install --upgrade pip && pip install --no-cache-dir \\
    "requests==2.28.0" \\
    "fastapi>=0.68.0"

COPY . /app
WORKDIR /app
"""
        
        start_idx, end_idx = self.updater.find_pip_install_block(dockerfile_content)
        
        # Verify the detected block
        detected_block = dockerfile_content[start_idx:end_idx]
        assert "RUN pip install --upgrade pip && pip install --no-cache-dir" in detected_block
        assert "requests==2.28.0" in detected_block
        assert "fastapi>=0.68.0" in detected_block
    
    def test_find_pip_install_block_simple_format(self):
        """Test pip install block detection with simple format."""
        dockerfile_content = """FROM python:3.9

RUN pip install --no-cache-dir \\
    "requests==2.28.0" \\
    "fastapi>=0.68.0"

COPY . /app
"""
        
        start_idx, end_idx = self.updater.find_pip_install_block(dockerfile_content)
        
        # Verify the detected block
        detected_block = dockerfile_content[start_idx:end_idx]
        assert "RUN pip install --no-cache-dir" in detected_block
        assert "requests==2.28.0" in detected_block
    
    def test_find_pip_install_block_not_found(self):
        """Test pip install block detection when no block exists."""
        dockerfile_content = """FROM python:3.9

COPY . /app
WORKDIR /app
RUN echo "No pip install here"
"""
        
        with pytest.raises(DockerfileUpdateError) as exc_info:
            self.updater.find_pip_install_block(dockerfile_content)
        
        assert "No pip install command block found" in str(exc_info.value)
    
    def test_find_pip_install_block_multiple_blocks(self):
        """Test pip install block detection with multiple blocks (should find first)."""
        dockerfile_content = """FROM python:3.9

RUN pip install --upgrade pip && pip install --no-cache-dir \\
    "requests==2.28.0"

RUN pip install --no-cache-dir \\
    "fastapi>=0.68.0"

COPY . /app
"""
        
        start_idx, end_idx = self.updater.find_pip_install_block(dockerfile_content)
        
        # Should find the first block
        detected_block = dockerfile_content[start_idx:end_idx]
        assert "requests==2.28.0" in detected_block
        # Should not include the second block
        assert "fastapi>=0.68.0" not in detected_block
    
    def test_format_pip_dependencies_single_dependency(self):
        """Test formatting a single dependency."""
        dependencies = {"requests": "==2.28.0"}
        
        result = self.updater.format_pip_dependencies(dependencies)
        
        assert result == '    "requests==2.28.0"'
    
    def test_format_pip_dependencies_multiple_dependencies(self):
        """Test formatting multiple dependencies with backslash continuation."""
        dependencies = {
            "requests": "==2.28.0",
            "fastapi": ">=0.68.0",
            "uvicorn": ">=0.15.0"
        }
        
        result = self.updater.format_pip_dependencies(dependencies)
        
        expected = '''    "fastapi>=0.68.0" \\
    "requests==2.28.0" \\
    "uvicorn>=0.15.0"'''
        
        assert result == expected
    
    def test_format_pip_dependencies_no_version_constraints(self):
        """Test formatting dependencies without version constraints."""
        dependencies = {
            "requests": "",
            "fastapi": "*",
            "uvicorn": None
        }
        
        result = self.updater.format_pip_dependencies(dependencies)
        
        expected = '''    "fastapi" \\
    "requests" \\
    "uvicorn"'''
        
        assert result == expected
    
    def test_format_pip_dependencies_mixed_constraints(self):
        """Test formatting dependencies with mixed constraint types."""
        dependencies = {
            "requests": "==2.28.0",
            "fastapi": "",
            "uvicorn": ">=0.15.0,<1.0.0",
            "pydantic": "^1.8.0"
        }
        
        result = self.updater.format_pip_dependencies(dependencies)
        
        expected = '''    "fastapi" \\
    "pydantic^1.8.0" \\
    "requests==2.28.0" \\
    "uvicorn>=0.15.0,<1.0.0"'''
        
        assert result == expected
    
    def test_format_pip_dependencies_empty_dict(self):
        """Test formatting empty dependencies dictionary."""
        dependencies = {}
        
        result = self.updater.format_pip_dependencies(dependencies)
        
        assert result == ""
    
    def test_format_pip_dependencies_whitespace_handling(self):
        """Test formatting dependencies with extra whitespace in constraints."""
        dependencies = {
            "requests": "  ==2.28.0  ",
            "fastapi": " >= 0.68.0 "
        }
        
        result = self.updater.format_pip_dependencies(dependencies)
        
        expected = '''    "fastapi>=0.68.0" \\
    "requests==2.28.0"'''
        
        assert result == expected
    
    def test_update_pip_install_integration(self):
        """Test complete pip install update process."""
        dockerfile_content = """FROM python:3.9

RUN pip install --upgrade pip && pip install --no-cache-dir \\
    "old-package==1.0.0"

COPY . /app
WORKDIR /app
"""
        
        dependencies = {
            "requests": "==2.28.0",
            "fastapi": ">=0.68.0"
        }
        
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.Dockerfile') as temp_file:
            temp_file.write(dockerfile_content)
            temp_file.flush()
            dockerfile_path = temp_file.name
        
        try:
            # Update the Dockerfile
            self.updater.update_pip_install(dockerfile_path, dependencies)
            
            # Read the updated content
            with open(dockerfile_path, 'r') as f:
                updated_content = f.read()
            
            # Verify the update
            assert "old-package==1.0.0" not in updated_content
            assert "requests==2.28.0" in updated_content
            assert "fastapi>=0.68.0" in updated_content
            assert "RUN pip install --upgrade pip && pip install --no-cache-dir" in updated_content
            
            # Verify the structure is maintained
            assert "FROM python:3.9" in updated_content
            assert "COPY . /app" in updated_content
            assert "WORKDIR /app" in updated_content
            
        finally:
            os.unlink(dockerfile_path)