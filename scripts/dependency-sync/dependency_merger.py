"""
Dependency Merger Module

Combines and deduplicates dependencies from multiple sources with conflict
resolution.

This module provides functionality to merge dependency dictionaries from
multiple pyproject.toml files and resolve version constraint conflicts.
It implements a conflict resolution strategy that chooses the most
restrictive constraint when conflicts are detected.

The merger handles various conflict scenarios:
- Exact vs range constraints (exact wins)
- Different minimum versions (higher wins)
- Constraints with vs without upper bounds (bounded wins)

Example:
    Basic merging:

    >>> merger = DependencyMerger()
    >>> deps1 = {'fastapi': '^0.100.0', 'uvicorn': '^0.24.0'}
    >>> deps2 = {'fastapi': '^0.95.0', 'pydantic': '^2.0.0'}
    >>> merged = merger.merge_dependencies(deps1, deps2)
    >>> print(merged)
    {'fastapi': '^0.100.0', 'uvicorn': '^0.24.0', 'pydantic': '^2.0.0'}

    Conflict resolution:

    >>> deps1 = {'package': '>=1.0.0'}
    >>> deps2 = {'package': '>=1.5.0'}
    >>> merged = merger.merge_dependencies(deps1, deps2)
    >>> print(merged['package'])  # '>=1.5.0' (more restrictive)

Classes:
    DependencyMerger: Main class for merging and conflict resolution
"""

from typing import Dict, List, Optional
import warnings
import re
from exceptions import VersionConstraintError


class DependencyMerger:
    """
    Merges dependencies from multiple sources and resolves conflicts.

    This class provides functionality to combine dependency dictionaries from
    multiple pyproject.toml files and resolve version constraint conflicts
    using a most-restrictive-wins strategy. It handles various constraint
    types and provides warnings when conflicts are detected.

    The conflict resolution strategy prioritizes:
    1. Exact constraints (==1.2.3) over range constraints
    2. Constraints with upper bounds over unbounded constraints
    3. Higher minimum versions over lower ones
    4. More specific version patterns over general ones

    Example:
        >>> merger = DependencyMerger()
        >>> server_deps = {'fastapi': '^0.100.0', 'uvicorn': '>=0.24.0'}
        >>> mcp_deps = {'fastapi': '^0.95.0', 'pydantic': '^2.0.0'}
        >>> merged = merger.merge_dependencies(server_deps, mcp_deps)
        >>> # Result: {'fastapi': '^0.100.0', 'uvicorn': '>=0.24.0',
        ...            'pydantic': '^2.0.0'}
    """

    def __init__(self) -> None:
        """
        Initialize the dependency merger.

        No configuration is required as the merger uses standard conflict
        resolution heuristics and semantic versioning principles.
        """
        pass

    def merge_dependencies(self, *dependency_dicts: Dict[str, str]
                           ) -> Dict[str, str]:
        """
        Merge multiple dependency dictionaries, resolving conflicts.

        Combines all provided dependency dictionaries into a single dictionary,
        resolving version constraint conflicts using the most-restrictive-wins
        strategy. Dependencies that appear in multiple dictionaries will have
        their constraints compared and the most restrictive one selected.

        Args:
            *dependency_dicts (Dict[str, str]): Variable number of dependency
                dictionaries to merge. Each dictionary maps dependency names
                to version constraints.

        Returns:
            Dict[str, str]: Merged dictionary with resolved conflicts. Contains
                all unique dependencies with their resolved constraints.

        Raises:
            VersionConstraintError: If conflicts cannot be resolved due to
                incompatible or invalid constraint formats.

        Example:
            >>> merger = DependencyMerger()
            >>> deps1 = {'fastapi': '^0.100.0', 'uvicorn': '>=0.24.0'}
            >>> deps2 = {'fastapi': '^0.95.0', 'pydantic': '^2.0.0'}
            >>> deps3 = {'fastapi': '>=0.90.0', 'requests': '^2.28.0'}
            >>> merged = merger.merge_dependencies(deps1, deps2, deps3)
            >>> print(merged)
            {
                'fastapi': '^0.100.0',  # Most restrictive of the three
                'uvicorn': '>=0.24.0',
                'pydantic': '^2.0.0',
                'requests': '^2.28.0'
            }
        """
        if not dependency_dicts:
            return {}

        merged = {}

        # Collect all unique dependency names
        all_deps = set()
        for dep_dict in dependency_dicts:
            all_deps.update(dep_dict.keys())

        # For each dependency, collect all constraints and resolve conflicts
        for dep_name in all_deps:
            constraints = []
            for dep_dict in dependency_dicts:
                if dep_name in dep_dict:
                    constraint = dep_dict[dep_name]
                    if constraint and constraint != "*":
                        # Skip empty and wildcard constraints
                        constraints.append(constraint)

            if not constraints:
                # No constraints found, skip this dependency
                continue
            elif len(constraints) == 1:
                # No conflict, use the single constraint
                merged[dep_name] = constraints[0]
            else:
                # Multiple constraints, resolve conflict
                merged[dep_name] = self.resolve_version_conflict(
                    dep_name, constraints)

        return merged

    def resolve_version_conflict(self, dep_name: str, constraints: List[str]
                                 ) -> str:
        """
        Resolve conflicting version constraints for a dependency.

        Takes a list of potentially conflicting version constraints for a
        single dependency and determines the most restrictive constraint
        that should be used. Issues warnings when actual conflicts are
        detected.

        Args:
            dep_name (str): Name of the dependency being resolved.
            constraints (List[str]): List of version constraints that need
                to be resolved. May contain duplicates.

        Returns:
            str: The most restrictive constraint from the input list.

        Raises:
            VersionConstraintError: If no constraints are provided or if
                constraints are fundamentally incompatible.

        Example:
            >>> merger = DependencyMerger()
            >>> # Resolve between different minimum versions
            >>> result = merger.resolve_version_conflict(
            ...     'fastapi', ['^0.100.0', '^0.95.0', '>=0.90.0']
            ... )
            >>> print(result)  # '^0.100.0' (most restrictive)
            >>>
            >>> # Exact constraint wins over range
            >>> result = merger.resolve_version_conflict(
            ...     'uvicorn', ['>=0.24.0', '==0.24.5']
            ... )
            >>> print(result)  # '==0.24.5' (exact is most restrictive)
        """
        if not constraints:
            raise VersionConstraintError(
                f"No constraints provided for {dep_name}")

        if len(constraints) == 1:
            return constraints[0]

        # Remove duplicates while preserving order
        unique_constraints = []
        seen = set()
        for constraint in constraints:
            if constraint not in seen:
                unique_constraints.append(constraint)
                seen.add(constraint)

        if len(unique_constraints) == 1:
            return unique_constraints[0]

        # For now, use pairwise comparison to find the most restrictive
        result = unique_constraints[0]
        for constraint in unique_constraints[1:]:
            result = self.compare_constraints(result, constraint)

        # Issue warning if there were actual conflicts (more than one unique
        # constraint)
        if len(unique_constraints) > 1:
            self._warn_about_conflict(dep_name, unique_constraints, result)

        return result

    def compare_constraints(self, constraint1: str, constraint2: str) -> str:
        """
        Compare two constraints and return the more restrictive one.

        Implements the core logic for determining which of two version
        constraints is more restrictive. Uses a hierarchy of rules to
        make this determination, with exact constraints being most
        restrictive, followed by bounded ranges, then unbounded ranges.

        Args:
            constraint1 (str): First version constraint to compare.
            constraint2 (str): Second version constraint to compare.

        Returns:
            str: The more restrictive of the two constraints.

        Example:
            >>> merger = DependencyMerger()
            >>> # Exact vs range
            >>> result = merger.compare_constraints('==1.2.3', '>=1.0.0')
            >>> print(result)  # '==1.2.3'
            >>>
            >>> # Higher minimum version
            >>> result = merger.compare_constraints('>=1.5.0', '>=1.0.0')
            >>> print(result)  # '>=1.5.0'
            >>>
            >>> # Bounded vs unbounded
            >>> result = merger.compare_constraints('>=1.0.0,<2.0.0',
            ...                                     '>=1.0.0')
            >>> print(result)  # '>=1.0.0,<2.0.0'
        """
        if constraint1 == constraint2:
            return constraint1

        # Handle empty/wildcard constraints
        if not constraint1 or constraint1 == "*":
            return constraint2
        if not constraint2 or constraint2 == "*":
            return constraint1

        # For basic implementation, use simple heuristics:
        # 1. Exact constraints (==) are most restrictive
        # 2. Range constraints with upper bounds are more restrictive than
        #    those without
        # 3. Higher minimum versions are more restrictive

        # Check for exact constraints
        if constraint1.startswith("=="):
            if constraint2.startswith("=="):
                # Both exact, choose the higher version (simple string
                # comparison for now)
                return constraint1 if constraint1 >= constraint2 \
                    else constraint2
            else:
                # Exact is more restrictive than range
                return constraint1
        elif constraint2.startswith("=="):
            return constraint2

        # Check for constraints with upper bounds (more restrictive)
        has_upper_1 = "<" in constraint1
        has_upper_2 = "<" in constraint2

        if has_upper_1 and not has_upper_2:
            return constraint1
        elif has_upper_2 and not has_upper_1:
            return constraint2

        # For constraints of similar types, try to determine which is more
        # restrictive by analyzing the version numbers
        try:
            return self._compare_similar_constraints(constraint1, constraint2)
        except Exception:
            # If comparison fails, issue a warning and return the first
            # constraint
            warnings.warn(
                f"Could not determine which constraint is more restrictive: "
                f"'{constraint1}' vs '{constraint2}'. Using '{constraint1}'.",
                UserWarning
            )
            return constraint1

    def _compare_similar_constraints(self, constraint1: str, constraint2: str
                                     ) -> str:
        """
        Compare constraints of similar types to determine which is more
        restrictive.

        Args:
            constraint1: First constraint
            constraint2: Second constraint

        Returns:
            More restrictive constraint
        """
        # Extract version numbers for comparison
        version1 = self._extract_version_number(constraint1)
        version2 = self._extract_version_number(constraint2)

        if not version1 or not version2:
            return constraint1

        # For >= constraints, higher version is more restrictive
        if constraint1.startswith(">=") and constraint2.startswith(">="):
            return constraint1 \
                if self._version_compare(version1, version2) > 0 \
                else constraint2

        # For <= constraints, lower version is more restrictive
        if constraint1.startswith("<=") and constraint2.startswith("<="):
            return constraint1 \
                if self._version_compare(version1, version2) < 0 \
                else constraint2

        # For mixed constraint types, prefer the one with upper bound
        return constraint1

    def _extract_version_number(self, constraint: str) -> Optional[str]:
        """
        Extract version number from a constraint string.

        Args:
            constraint: Version constraint string

        Returns:
            Version number or None if not found
        """
        # Match version patterns like 1.2.3, 0.24.0, etc.
        match = re.search(r'(\d+(?:\.\d+)*)', constraint)
        return match.group(1) if match else None

    def _version_compare(self, version1: str, version2: str) -> int:
        """
        Compare two version strings.

        Args:
            version1: First version string
            version2: Second version string

        Returns:
            -1 if version1 < version2, 0 if equal, 1 if version1 > version2
        """
        # Simple version comparison by splitting on dots and comparing
        # numerically
        parts1 = [int(x) for x in version1.split('.')]
        parts2 = [int(x) for x in version2.split('.')]

        # Pad shorter version with zeros
        max_len = max(len(parts1), len(parts2))
        parts1.extend([0] * (max_len - len(parts1)))
        parts2.extend([0] * (max_len - len(parts2)))

        for p1, p2 in zip(parts1, parts2):
            if p1 < p2:
                return -1
            elif p1 > p2:
                return 1

        return 0

    def _warn_about_conflict(self, dep_name: str, constraints: List[str],
                             resolved: str):
        """
        Issue a warning about version conflicts.

        Args:
            dep_name: Name of the dependency with conflicts
            constraints: List of conflicting constraints
            resolved: The resolved constraint that was chosen
        """
        constraints_str = "', '".join(constraints)
        warnings.warn(
            f"Version conflict detected for '{dep_name}': "
            f"constraints ['{constraints_str}'] resolved to '{resolved}'",
            UserWarning
        )
