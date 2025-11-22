"""
Unit tests for DependencyMerger class.
"""

import pytest
import sys
from pathlib import Path

# Add the parent directory to the path so we can import the modules
sys.path.insert(0, str(Path(__file__).parent.parent))

from dependency_merger import DependencyMerger
from exceptions import VersionConstraintError


class TestDependencyMerger:
    """Test cases for DependencyMerger class."""
    
    def setup_method(self):
        """Set up test fixtures."""
        self.merger = DependencyMerger()
    
    def test_merge_empty_dependencies(self):
        """Test merging with no dependency dictionaries."""
        result = self.merger.merge_dependencies()
        assert result == {}
    
    def test_merge_single_dependency_dict(self):
        """Test merging with a single dependency dictionary."""
        deps = {"fastapi": "^0.104.1", "uvicorn": "^0.24.0"}
        result = self.merger.merge_dependencies(deps)
        assert result == deps
    
    def test_merge_non_overlapping_dependencies(self):
        """Test merging dictionaries with no overlapping dependencies."""
        deps1 = {"fastapi": "^0.104.1", "uvicorn": "^0.24.0"}
        deps2 = {"pydantic": ">=2.0.0", "requests": "~2.31.0"}
        
        result = self.merger.merge_dependencies(deps1, deps2)
        
        expected = {
            "fastapi": "^0.104.1",
            "uvicorn": "^0.24.0",
            "pydantic": ">=2.0.0",
            "requests": "~2.31.0"
        }
        assert result == expected
    
    def test_merge_identical_dependencies(self):
        """Test merging dictionaries with identical dependencies."""
        deps1 = {"fastapi": "^0.104.1", "uvicorn": "^0.24.0"}
        deps2 = {"fastapi": "^0.104.1", "pydantic": ">=2.0.0"}
        
        result = self.merger.merge_dependencies(deps1, deps2)
        
        expected = {
            "fastapi": "^0.104.1",
            "uvicorn": "^0.24.0",
            "pydantic": ">=2.0.0"
        }
        assert result == expected
    
    def test_merge_with_empty_constraints(self):
        """Test merging with empty or wildcard constraints."""
        deps1 = {"fastapi": "^0.104.1", "numpy": ""}
        deps2 = {"fastapi": "^0.104.1", "scipy": "*"}
        
        result = self.merger.merge_dependencies(deps1, deps2)
        
        expected = {
            "fastapi": "^0.104.1"
        }
        assert result == expected
    
    def test_merge_multiple_dictionaries(self):
        """Test merging multiple dependency dictionaries."""
        deps1 = {"fastapi": "^0.104.1"}
        deps2 = {"uvicorn": "^0.24.0"}
        deps3 = {"pydantic": ">=2.0.0"}
        
        result = self.merger.merge_dependencies(deps1, deps2, deps3)
        
        expected = {
            "fastapi": "^0.104.1",
            "uvicorn": "^0.24.0",
            "pydantic": ">=2.0.0"
        }
        assert result == expected
    
    def test_resolve_version_conflict_no_constraints(self):
        """Test version conflict resolution with no constraints."""
        with pytest.raises(VersionConstraintError):
            self.merger.resolve_version_conflict("fastapi", [])
    
    def test_resolve_version_conflict_single_constraint(self):
        """Test version conflict resolution with single constraint."""
        result = self.merger.resolve_version_conflict("fastapi", ["^0.104.1"])
        assert result == "^0.104.1"
    
    def test_resolve_version_conflict_identical_constraints(self):
        """Test version conflict resolution with identical constraints."""
        constraints = ["^0.104.1", "^0.104.1", "^0.104.1"]
        result = self.merger.resolve_version_conflict("fastapi", constraints)
        assert result == "^0.104.1"
    
    def test_compare_constraints_identical(self):
        """Test comparing identical constraints."""
        result = self.merger.compare_constraints("^0.104.1", "^0.104.1")
        assert result == "^0.104.1"
    
    def test_compare_constraints_with_empty(self):
        """Test comparing constraints where one is empty."""
        result = self.merger.compare_constraints("^0.104.1", "")
        assert result == "^0.104.1"
        
        result = self.merger.compare_constraints("", "^0.104.1")
        assert result == "^0.104.1"
        
        result = self.merger.compare_constraints("^0.104.1", "*")
        assert result == "^0.104.1"
    
    def test_compare_constraints_exact_vs_range(self):
        """Test comparing exact constraints vs range constraints."""
        # Exact constraint should be more restrictive
        result = self.merger.compare_constraints("==0.104.1", "^0.104.0")
        assert result == "==0.104.1"
        
        result = self.merger.compare_constraints(">=0.104.0", "==0.104.1")
        assert result == "==0.104.1"
    
    def test_compare_constraints_with_upper_bounds(self):
        """Test comparing constraints with and without upper bounds."""
        # Constraint with upper bound should be more restrictive
        result = self.merger.compare_constraints(">=1.0.0,<2.0.0", ">=1.0.0")
        assert result == ">=1.0.0,<2.0.0"
        
        result = self.merger.compare_constraints(">=1.0.0", ">=1.0.0,<2.0.0")
        assert result == ">=1.0.0,<2.0.0"
    
    def test_merge_with_conflicting_constraints(self):
        """Test merging with conflicting constraints that need resolution."""
        deps1 = {"fastapi": "==0.104.1", "uvicorn": "^0.24.0"}
        deps2 = {"fastapi": ">=0.104.0", "pydantic": ">=2.0.0"}
        
        result = self.merger.merge_dependencies(deps1, deps2)
        
        # Exact constraint should win over range constraint
        expected = {
            "fastapi": "==0.104.1",
            "uvicorn": "^0.24.0",
            "pydantic": ">=2.0.0"
        }
        assert result == expected
    
    def test_compare_similar_constraints_greater_equal(self):
        """Test comparing >= constraints."""
        # Higher version should be more restrictive
        result = self.merger.compare_constraints(">=1.2.0", ">=1.1.0")
        assert result == ">=1.2.0"
        
        result = self.merger.compare_constraints(">=2.0.0", ">=1.9.0")
        assert result == ">=2.0.0"
    
    def test_compare_similar_constraints_less_equal(self):
        """Test comparing <= constraints."""
        # Lower version should be more restrictive
        result = self.merger.compare_constraints("<=1.1.0", "<=1.2.0")
        assert result == "<=1.1.0"
        
        result = self.merger.compare_constraints("<=1.9.0", "<=2.0.0")
        assert result == "<=1.9.0"
    
    def test_extract_version_number(self):
        """Test version number extraction from constraints."""
        assert self.merger._extract_version_number(">=1.2.3") == "1.2.3"
        assert self.merger._extract_version_number("==0.24.0") == "0.24.0"
        assert self.merger._extract_version_number("^1.0.0") == "1.0.0"
        assert self.merger._extract_version_number("~2.1") == "2.1"
        assert self.merger._extract_version_number("invalid") is None
    
    def test_version_compare(self):
        """Test version comparison logic."""
        # Equal versions
        assert self.merger._version_compare("1.2.3", "1.2.3") == 0
        
        # First version higher
        assert self.merger._version_compare("1.2.3", "1.2.2") == 1
        assert self.merger._version_compare("2.0.0", "1.9.9") == 1
        assert self.merger._version_compare("1.2", "1.1.9") == 1
        
        # Second version higher
        assert self.merger._version_compare("1.2.2", "1.2.3") == -1
        assert self.merger._version_compare("1.9.9", "2.0.0") == -1
        assert self.merger._version_compare("1.1.9", "1.2") == -1
    
    def test_resolve_version_conflict_with_warnings(self):
        """Test that version conflict resolution issues warnings."""
        import warnings
        
        with warnings.catch_warnings(record=True) as w:
            warnings.simplefilter("always")
            
            # This should trigger a warning due to conflicting constraints
            result = self.merger.resolve_version_conflict("fastapi", [">=1.0.0", ">=1.1.0"])
            
            # Should choose the more restrictive constraint
            assert result == ">=1.1.0"
            
            # Should have issued a warning
            assert len(w) == 1
            assert "Version conflict detected" in str(w[0].message)
            assert "fastapi" in str(w[0].message)
    
    def test_merge_with_version_conflicts_and_warnings(self):
        """Test merging with conflicts that generate warnings."""
        import warnings
        
        deps1 = {"fastapi": ">=1.0.0", "uvicorn": "^0.24.0"}
        deps2 = {"fastapi": ">=1.1.0", "pydantic": ">=2.0.0"}
        
        with warnings.catch_warnings(record=True) as w:
            warnings.simplefilter("always")
            
            result = self.merger.merge_dependencies(deps1, deps2)
            
            expected = {
                "fastapi": ">=1.1.0",  # More restrictive constraint
                "uvicorn": "^0.24.0",
                "pydantic": ">=2.0.0"
            }
            assert result == expected
            
            # Should have issued a warning for the fastapi conflict
            assert len(w) == 1
            assert "fastapi" in str(w[0].message)
    
    def test_complex_constraint_resolution(self):
        """Test resolution of complex constraint scenarios."""
        # Mix of exact, range, and caret constraints
        deps1 = {"package": "==1.2.3"}
        deps2 = {"package": ">=1.2.0"}
        deps3 = {"package": "^1.2.0"}
        
        result = self.merger.merge_dependencies(deps1, deps2, deps3)
        
        # Exact constraint should win
        assert result["package"] == "==1.2.3"
    
    def test_incompatible_constraints_handling(self):
        """Test handling of potentially incompatible constraints."""
        import warnings
        
        # These constraints might be incompatible
        deps1 = {"package": "<=1.0.0"}
        deps2 = {"package": ">=2.0.0"}
        
        with warnings.catch_warnings(record=True) as w:
            warnings.simplefilter("always")
            
            # Should not raise an exception, but should warn
            result = self.merger.merge_dependencies(deps1, deps2)
            
            # Should pick one of the constraints (implementation dependent)
            assert "package" in result
            assert result["package"] in ["<=1.0.0", ">=2.0.0"]
            
            # Should have issued a warning
            assert len(w) >= 1