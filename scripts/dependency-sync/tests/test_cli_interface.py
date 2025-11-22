"""
Unit tests for the CLI interface module.
"""

import pytest
import argparse
import sys
import os
import tempfile
from pathlib import Path
from unittest.mock import patch, mock_open
from io import StringIO

from cli_interface import CLIInterface


class TestCLIInterface:
    """Test cases for CLIInterface class."""
    
    def setup_method(self):
        """Set up test fixtures."""
        self.cli = CLIInterface()
    
    def test_parse_arguments_basic(self):
        """Test basic argument parsing with required arguments."""
        args = ['server/pyproject.toml', 'deploy/Dockerfile']
        parsed = self.cli.parse_arguments(args)
        
        assert parsed.source_files == ['server/pyproject.toml']
        assert parsed.target_dockerfile == 'deploy/Dockerfile'
        assert parsed.verbose is False
        assert parsed.quiet is False
        assert parsed.dry_run is False
        assert parsed.no_backup is False
    
    def test_parse_arguments_multiple_sources(self):
        """Test parsing with multiple source files."""
        args = [
            'server/pyproject.toml',
            'mcp-server/pyproject.toml',
            'deploy/Dockerfile'
        ]
        parsed = self.cli.parse_arguments(args)
        
        assert parsed.source_files == ['server/pyproject.toml', 'mcp-server/pyproject.toml']
        assert parsed.target_dockerfile == 'deploy/Dockerfile'
    
    def test_parse_arguments_with_flags(self):
        """Test parsing with optional flags."""
        args = [
            '--verbose',
            '--dry-run',
            '--no-backup',
            'server/pyproject.toml',
            'deploy/Dockerfile'
        ]
        parsed = self.cli.parse_arguments(args)
        
        assert parsed.verbose is True
        assert parsed.dry_run is True
        assert parsed.no_backup is True
        assert parsed.quiet is False
    
    def test_parse_arguments_short_flags(self):
        """Test parsing with short flag versions."""
        args = ['-v', '-q', 'server/pyproject.toml', 'deploy/Dockerfile']
        
        # This should raise SystemExit due to mutually exclusive options
        with pytest.raises(SystemExit):
            self.cli.parse_arguments(args)
    
    def test_parse_arguments_verbose_quiet_conflict(self):
        """Test that verbose and quiet flags are mutually exclusive."""
        args = ['--verbose', '--quiet', 'server/pyproject.toml', 'deploy/Dockerfile']
        
        with pytest.raises(SystemExit):
            self.cli.parse_arguments(args)
    
    def test_parse_arguments_missing_required(self):
        """Test that missing required arguments raise SystemExit."""
        args = ['server/pyproject.toml']  # Missing target dockerfile
        
        with pytest.raises(SystemExit):
            self.cli.parse_arguments(args)
    
    def test_parse_arguments_help(self):
        """Test that help flag raises SystemExit."""
        args = ['--help']
        
        with pytest.raises(SystemExit):
            self.cli.parse_arguments(args)


class TestFileValidation:
    """Test cases for file validation functionality."""
    
    def setup_method(self):
        """Set up test fixtures."""
        self.cli = CLIInterface()
    
    def test_validate_file_paths_success(self):
        """Test successful file validation."""
        with tempfile.TemporaryDirectory() as temp_dir:
            # Create test files
            pyproject_path = Path(temp_dir) / 'pyproject.toml'
            dockerfile_path = Path(temp_dir) / 'Dockerfile'
            
            pyproject_path.write_text('[tool.poetry.dependencies]\n')
            dockerfile_path.write_text('FROM python:3.9\n')
            
            # Should not raise any exceptions
            self.cli.validate_file_paths([str(pyproject_path)], str(dockerfile_path))
    
    def test_validate_file_paths_source_not_found(self):
        """Test validation with missing source file."""
        with tempfile.TemporaryDirectory() as temp_dir:
            dockerfile_path = Path(temp_dir) / 'Dockerfile'
            dockerfile_path.write_text('FROM python:3.9\n')
            
            missing_source = str(Path(temp_dir) / 'missing.toml')
            
            with pytest.raises(FileNotFoundError, match="Source file not found"):
                self.cli.validate_file_paths([missing_source], str(dockerfile_path))
    
    def test_validate_file_paths_target_not_found(self):
        """Test validation with missing target file."""
        with tempfile.TemporaryDirectory() as temp_dir:
            pyproject_path = Path(temp_dir) / 'pyproject.toml'
            pyproject_path.write_text('[tool.poetry.dependencies]\n')
            
            missing_target = str(Path(temp_dir) / 'missing_dockerfile')
            
            with pytest.raises(FileNotFoundError, match="Target Dockerfile not found"):
                self.cli.validate_file_paths([str(pyproject_path)], missing_target)
    
    def test_validate_file_paths_wrong_source_name(self):
        """Test validation with incorrectly named source file."""
        with tempfile.TemporaryDirectory() as temp_dir:
            wrong_name_path = Path(temp_dir) / 'wrong_name.toml'
            dockerfile_path = Path(temp_dir) / 'Dockerfile'
            
            wrong_name_path.write_text('[tool.poetry.dependencies]\n')
            dockerfile_path.write_text('FROM python:3.9\n')
            
            with pytest.raises(ValueError, match="Source file must be named 'pyproject.toml'"):
                self.cli.validate_file_paths([str(wrong_name_path)], str(dockerfile_path))
    
    def test_validate_file_paths_source_is_directory(self):
        """Test validation when source path is a directory."""
        with tempfile.TemporaryDirectory() as temp_dir:
            source_dir = Path(temp_dir) / 'pyproject.toml'
            dockerfile_path = Path(temp_dir) / 'Dockerfile'
            
            source_dir.mkdir()  # Create as directory instead of file
            dockerfile_path.write_text('FROM python:3.9\n')
            
            with pytest.raises(ValueError, match="Source path is not a file"):
                self.cli.validate_file_paths([str(source_dir)], str(dockerfile_path))
    
    def test_validate_file_paths_target_is_directory(self):
        """Test validation when target path is a directory."""
        with tempfile.TemporaryDirectory() as temp_dir:
            pyproject_path = Path(temp_dir) / 'pyproject.toml'
            target_dir = Path(temp_dir) / 'Dockerfile'
            
            pyproject_path.write_text('[tool.poetry.dependencies]\n')
            target_dir.mkdir()  # Create as directory instead of file
            
            with pytest.raises(ValueError, match="Target path is not a file"):
                self.cli.validate_file_paths([str(pyproject_path)], str(target_dir))
    
    @patch('os.access')
    def test_validate_file_paths_permission_errors(self, mock_access):
        """Test validation with permission errors."""
        with tempfile.TemporaryDirectory() as temp_dir:
            pyproject_path = Path(temp_dir) / 'pyproject.toml'
            dockerfile_path = Path(temp_dir) / 'Dockerfile'
            
            pyproject_path.write_text('[tool.poetry.dependencies]\n')
            dockerfile_path.write_text('FROM python:3.9\n')
            
            # Mock access to return False for read permission on source
            mock_access.side_effect = lambda path, mode: False if mode == os.R_OK else True
            
            with pytest.raises(PermissionError, match="Cannot read source file"):
                self.cli.validate_file_paths([str(pyproject_path)], str(dockerfile_path))


class TestOutputFormatting:
    """Test cases for output formatting functionality."""
    
    def setup_method(self):
        """Set up test fixtures."""
        self.cli = CLIInterface()
    
    @patch('sys.stdout', new_callable=StringIO)
    def test_print_summary_basic(self, mock_stdout):
        """Test basic summary printing."""
        changes = {
            'dependencies_processed': 5,
            'conflicts_resolved': 1,
            'files_processed': 2,
            'changes_made': ['Updated pip install command', 'Added 3 new dependencies'],
            'backup_file': '/tmp/Dockerfile.backup'
        }
        
        self.cli.print_summary(changes)
        output = mock_stdout.getvalue()
        
        assert 'DEPENDENCY SYNC SUMMARY' in output
        assert 'Files processed: 2' in output
        assert 'Dependencies processed: 5' in output
        assert 'Version conflicts resolved: 1' in output
        assert 'Updated pip install command' in output
        assert 'Backup created: /tmp/Dockerfile.backup' in output
    
    @patch('sys.stdout', new_callable=StringIO)
    def test_print_summary_quiet_mode(self, mock_stdout):
        """Test that quiet mode suppresses output."""
        changes = {'dependencies_processed': 5}
        
        self.cli.print_summary(changes, quiet=True)
        output = mock_stdout.getvalue()
        
        assert output == ""
    
    @patch('sys.stdout', new_callable=StringIO)
    def test_print_summary_verbose_mode(self, mock_stdout):
        """Test verbose mode output."""
        changes = {
            'dependencies_processed': 2,
            'files_processed': 1,
            'dependencies': {'fastapi': '>=0.68.0', 'uvicorn': '>=0.15.0'},
            'conflict_resolutions': {
                'requests': {
                    'old_constraints': ['^2.25.0', '>=2.26.0'],
                    'new_constraint': '>=2.26.0'
                }
            }
        }
        
        self.cli.print_summary(changes, verbose=True)
        output = mock_stdout.getvalue()
        
        assert 'Detailed Information:' in output
        assert 'fastapi: >=0.68.0' in output
        assert 'uvicorn: >=0.15.0' in output
        assert 'Conflict resolutions:' in output
        assert 'requests:' in output
    
    @patch('sys.stdout', new_callable=StringIO)
    def test_print_summary_with_warnings(self, mock_stdout):
        """Test summary with warnings."""
        changes = {
            'dependencies_processed': 3,
            'files_processed': 1,
            'warnings': ['Dependency X has unusual version constraint', 'File Y was modified externally']
        }
        
        self.cli.print_summary(changes)
        output = mock_stdout.getvalue()
        
        assert 'Warnings:' in output
        assert '⚠ Dependency X has unusual version constraint' in output
        assert '⚠ File Y was modified externally' in output
    
    @patch('sys.stdout', new_callable=StringIO)
    def test_print_progress_normal(self, mock_stdout):
        """Test normal progress printing."""
        self.cli.print_progress("Processing dependencies")
        output = mock_stdout.getvalue()
        
        assert '• Processing dependencies\n' == output
    
    @patch('sys.stdout', new_callable=StringIO)
    def test_print_progress_verbose(self, mock_stdout):
        """Test verbose progress printing."""
        self.cli.print_progress("Processing dependencies", verbose=True)
        output = mock_stdout.getvalue()
        
        assert '[INFO] Processing dependencies\n' == output
    
    @patch('sys.stdout', new_callable=StringIO)
    def test_print_progress_quiet(self, mock_stdout):
        """Test that quiet mode suppresses progress output."""
        self.cli.print_progress("Processing dependencies", quiet=True)
        output = mock_stdout.getvalue()
        
        assert output == ""


class TestErrorHandling:
    """Test cases for error handling functionality."""
    
    def setup_method(self):
        """Set up test fixtures."""
        self.cli = CLIInterface()
    
    @patch('sys.stderr', new_callable=StringIO)
    def test_handle_errors_file_not_found(self, mock_stderr):
        """Test handling of FileNotFoundError."""
        error = FileNotFoundError("test file not found")
        exit_code = self.cli.handle_errors(error)
        
        assert exit_code == 2
        assert "Error: test file not found" in mock_stderr.getvalue()
    
    @patch('sys.stderr', new_callable=StringIO)
    def test_handle_errors_permission_error(self, mock_stderr):
        """Test handling of PermissionError."""
        error = PermissionError("permission denied")
        exit_code = self.cli.handle_errors(error)
        
        assert exit_code == 3
        assert "Error: permission denied" in mock_stderr.getvalue()
    
    @patch('sys.stderr', new_callable=StringIO)
    def test_handle_errors_value_error(self, mock_stderr):
        """Test handling of ValueError."""
        error = ValueError("invalid value")
        exit_code = self.cli.handle_errors(error)
        
        assert exit_code == 4
        assert "Error: invalid value" in mock_stderr.getvalue()
    
    @patch('sys.stderr', new_callable=StringIO)
    def test_handle_errors_unexpected_error(self, mock_stderr):
        """Test handling of unexpected errors."""
        error = RuntimeError("unexpected error")
        exit_code = self.cli.handle_errors(error)
        
        assert exit_code == 1
        assert "Unexpected error (RuntimeError): unexpected error" in mock_stderr.getvalue()
    
    @patch('sys.stderr', new_callable=StringIO)
    @patch('traceback.print_exc')
    def test_handle_errors_verbose_traceback(self, mock_traceback, mock_stderr):
        """Test that verbose mode prints traceback for unexpected errors."""
        error = RuntimeError("unexpected error")
        self.cli.handle_errors(error, verbose=True)
        
        mock_traceback.assert_called_once()


if __name__ == '__main__':
    pytest.main([__file__])