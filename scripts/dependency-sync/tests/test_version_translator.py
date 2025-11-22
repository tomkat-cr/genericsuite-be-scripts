"""
Unit tests for VersionTranslator class.
"""

import pytest
import sys
from pathlib import Path

# Add the parent directory to the path so we can import the modules
sys.path.insert(0, str(Path(__file__).parent.parent))

from version_translator import VersionTranslator
from exceptions import VersionConstraintError


class TestVersionTranslator:
    """Test cases for VersionTranslator class."""
    
    def setup_method(self):
        """Set up test fixtures."""
        self.translator = VersionTranslator()
    
    def test_translate_empty_constraint(self):
        """Test translation of empty or wildcard constraints."""
        assert self.translator.translate_poetry_to_pip("") == ""
        assert self.translator.translate_poetry_to_pip("*") == ""
        assert self.translator.translate_poetry_to_pip("  ") == ""
    
    def test_translate_exact_version_constraints(self):
        """Test translation of exact version constraints."""
        # Already exact constraints should be preserved
        assert self.translator.translate_poetry_to_pip("==1.2.3") == "==1.2.3"
        assert self.translator.translate_poetry_to_pip("==0.24.0") == "==0.24.0"
        assert self.translator.translate_poetry_to_pip("==2.0.0a1") == "==2.0.0a1"
    
    def test_translate_minimum_version_constraints(self):
        """Test translation of minimum version constraints."""
        assert self.translator.translate_poetry_to_pip(">=1.2.3") == ">=1.2.3"
        assert self.translator.translate_poetry_to_pip(">=0.24.0") == ">=0.24.0"
    
    def test_translate_maximum_version_constraints(self):
        """Test translation of maximum version constraints."""
        assert self.translator.translate_poetry_to_pip("<=1.2.3") == "<=1.2.3"
        assert self.translator.translate_poetry_to_pip("<2.0.0") == "<2.0.0"
    
    def test_translate_bare_version_numbers(self):
        """Test translation of bare version numbers to exact constraints."""
        assert self.translator.translate_poetry_to_pip("1.2.3") == "==1.2.3"
        assert self.translator.translate_poetry_to_pip("0.24.0") == "==0.24.0"
        assert self.translator.translate_poetry_to_pip("2.1") == "==2.1"
        assert self.translator.translate_poetry_to_pip("3") == "==3"
    
    def test_translate_invalid_constraints(self):
        """Test handling of invalid version constraints."""
        with pytest.raises(VersionConstraintError):
            self.translator.translate_poetry_to_pip("invalid")
        
        with pytest.raises(VersionConstraintError):
            self.translator.translate_poetry_to_pip("@#$%")
        
        with pytest.raises(VersionConstraintError):
            self.translator.translate_poetry_to_pip("1.2.3.4.5.6")
    
    def test_is_valid_version(self):
        """Test version validation helper method."""
        # Valid versions
        assert self.translator._is_valid_version("1.2.3")
        assert self.translator._is_valid_version("0.24.0")
        assert self.translator._is_valid_version("2.1")
        assert self.translator._is_valid_version("3")
        assert self.translator._is_valid_version("1.0.0a1")
        assert self.translator._is_valid_version("2.0.0-beta.1")
        
        # Invalid versions
        assert not self.translator._is_valid_version("invalid")
        assert not self.translator._is_valid_version("@#$%")
        assert not self.translator._is_valid_version("")
        assert not self.translator._is_valid_version("v1.2.3")
    
    def test_translate_caret_constraints(self):
        """Test translation of caret constraints."""
        # Basic caret constraints
        assert self.translator.translate_poetry_to_pip("^1.2.3") == ">=1.2.3,<2.0.0"
        assert self.translator.translate_poetry_to_pip("^0.2.3") == ">=0.2.3,<0.3.0"
        assert self.translator.translate_poetry_to_pip("^0.0.3") == ">=0.0.3,<0.0.4"
        
        # Edge cases
        assert self.translator.translate_poetry_to_pip("^2.0.0") == ">=2.0.0,<3.0.0"
        assert self.translator.translate_poetry_to_pip("^10.5.2") == ">=10.5.2,<11.0.0"
    
    def test_translate_tilde_constraints(self):
        """Test translation of tilde constraints."""
        # Basic tilde constraints
        assert self.translator.translate_poetry_to_pip("~1.2.3") == ">=1.2.3,<1.3.0"
        assert self.translator.translate_poetry_to_pip("~1.2") == ">=1.2.0,<1.3.0"
        assert self.translator.translate_poetry_to_pip("~1") == ">=1.0.0,<2.0.0"
        
        # Edge cases
        assert self.translator.translate_poetry_to_pip("~0.2.3") == ">=0.2.3,<0.3.0"
        assert self.translator.translate_poetry_to_pip("~10.5.2") == ">=10.5.2,<10.6.0"
    
    def test_handle_caret_constraint_edge_cases(self):
        """Test caret constraint handling with edge cases."""
        # Test with different version formats
        assert self.translator.handle_caret_constraint("1.2.3") == ">=1.2.3,<2.0.0"
        assert self.translator.handle_caret_constraint("1.2") == ">=1.2,<2.0.0"
        assert self.translator.handle_caret_constraint("1") == ">=1,<2.0.0"
        
        # Test with zero versions
        assert self.translator.handle_caret_constraint("0.2.3") == ">=0.2.3,<0.3.0"
        assert self.translator.handle_caret_constraint("0.0.3") == ">=0.0.3,<0.0.4"
        assert self.translator.handle_caret_constraint("0.0.0") == ">=0.0.0,<0.0.1"
        
        # Test invalid versions
        with pytest.raises(VersionConstraintError):
            self.translator.handle_caret_constraint("invalid")
    
    def test_handle_tilde_constraint_edge_cases(self):
        """Test tilde constraint handling with edge cases."""
        # Test with different version formats
        assert self.translator.handle_tilde_constraint("1.2.3") == ">=1.2.3,<1.3.0"
        assert self.translator.handle_tilde_constraint("1.2") == ">=1.2.0,<1.3.0"
        assert self.translator.handle_tilde_constraint("1") == ">=1.0.0,<2.0.0"
        
        # Test with zero versions
        assert self.translator.handle_tilde_constraint("0.2.3") == ">=0.2.3,<0.3.0"
        assert self.translator.handle_tilde_constraint("0.0.3") == ">=0.0.3,<0.1.0"
        
        # Test invalid versions
        with pytest.raises(VersionConstraintError):
            self.translator.handle_tilde_constraint("invalid")
    
    def test_caret_constraint_version_padding(self):
        """Test that caret constraints properly pad versions."""
        # When handling short versions, they should be padded for comparison
        assert self.translator.handle_caret_constraint("1") == ">=1,<2.0.0"
        assert self.translator.handle_caret_constraint("1.2") == ">=1.2,<2.0.0"
        
        # Zero padding behavior
        assert self.translator.handle_caret_constraint("0") == ">=0,<0.0.1"
        assert self.translator.handle_caret_constraint("0.1") == ">=0.1,<0.2.0"    

    def test_handle_extras_basic(self):
        """Test basic extras handling."""
        # Basic extras with different constraints
        result = self.translator.handle_extras("uvicorn[standard]", "^0.24.0")
        assert result == "uvicorn[standard]>=0.24.0,<0.25.0"
        
        result = self.translator.handle_extras("sqlalchemy[asyncio]", ">=2.0.0")
        assert result == "sqlalchemy[asyncio]>=2.0.0"
        
        result = self.translator.handle_extras("fastapi[all]", "==0.104.1")
        assert result == "fastapi[all]==0.104.1"
    
    def test_handle_extras_multiple_extras(self):
        """Test handling dependencies with multiple extras."""
        result = self.translator.handle_extras("uvicorn[standard,watchfiles]", "^0.24.0")
        assert result == "uvicorn[standard,watchfiles]>=0.24.0,<0.25.0"
        
        result = self.translator.handle_extras("sqlalchemy[asyncio,postgresql]", "~2.0.0")
        assert result == "sqlalchemy[asyncio,postgresql]>=2.0.0,<2.1.0"
    
    def test_handle_extras_no_constraint(self):
        """Test extras handling with no constraint."""
        result = self.translator.handle_extras("uvicorn[standard]", "")
        assert result == "uvicorn[standard]"
        
        result = self.translator.handle_extras("uvicorn[standard]", "*")
        assert result == "uvicorn[standard]"
    
    def test_handle_extras_no_extras(self):
        """Test handling dependencies without extras."""
        result = self.translator.handle_extras("fastapi", "^0.104.1")
        assert result == "fastapi>=0.104.1,<0.105.0"
        
        result = self.translator.handle_extras("requests", "~2.31.0")
        assert result == "requests>=2.31.0,<2.32.0"
    
    def test_translate_dependency_with_constraint(self):
        """Test the full dependency translation method."""
        # Basic dependencies
        result = self.translator.translate_dependency_with_constraint("fastapi", "^0.104.1")
        assert result == "fastapi>=0.104.1,<0.105.0"
        
        # Dependencies with extras
        result = self.translator.translate_dependency_with_constraint("uvicorn[standard]", "^0.24.0")
        assert result == "uvicorn[standard]>=0.24.0,<0.25.0"
        
        # Dependencies with no constraint
        result = self.translator.translate_dependency_with_constraint("numpy", "*")
        assert result == "numpy"
        
        # Dependencies with exact constraints
        result = self.translator.translate_dependency_with_constraint("click", "8.1.7")
        assert result == "click==8.1.7"
    
    def test_extras_with_complex_constraints(self):
        """Test extras with various complex constraint types."""
        # Caret constraints
        result = self.translator.handle_extras("uvicorn[standard]", "^0.2.3")
        assert result == "uvicorn[standard]>=0.2.3,<0.3.0"
        
        # Tilde constraints
        result = self.translator.handle_extras("sqlalchemy[asyncio]", "~1.4.0")
        assert result == "sqlalchemy[asyncio]>=1.4.0,<1.5.0"
        
        # Range constraints
        result = self.translator.handle_extras("django[redis]", ">=4.0.0")
        assert result == "django[redis]>=4.0.0"