#!/usr/bin/env python3
"""
Test runner script for dependency sync tests.
"""

import sys
import subprocess
import argparse


def run_command(cmd, description):
    """Run a command and return the result."""
    print(f"\n{'='*60}")
    print(f"Running: {description}")
    print(f"Command: {' '.join(cmd)}")
    print(f"{'='*60}")

    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.stdout:
        print("STDOUT:")
        print(result.stdout)

    if result.stderr:
        print("STDERR:")
        print(result.stderr)

    print(f"Exit code: {result.returncode}")
    return result.returncode == 0


def main():
    parser = argparse.ArgumentParser(description="Run dependency sync tests")
    parser.add_argument("--unit", action="store_true",
                        help="Run unit tests only")
    parser.add_argument("--integration", action="store_true",
                        help="Run integration tests only")
    parser.add_argument("--slow", action="store_true",
                        help="Include slow tests")
    parser.add_argument("--verbose", "-v",
                        action="store_true", help="Verbose output")
    parser.add_argument("--coverage", action="store_true",
                        help="Run with coverage")
    parser.add_argument("--pattern", "-k", help="Run tests matching pattern")

    args = parser.parse_args()

    # Base pytest command
    cmd = ["python", "-m", "pytest"]

    if args.verbose:
        cmd.append("-v")
    else:
        cmd.append("-q")

    # Add coverage if requested
    if args.coverage:
        cmd.extend(["--cov=.", "--cov-report=html", "--cov-report=term"])

    # Add pattern if specified
    if args.pattern:
        cmd.extend(["-k", args.pattern])

    # Determine which tests to run
    test_paths = []

    if args.unit:
        # Run unit tests (all except integration)
        cmd.extend(["-m", "not integration and not slow"])
        test_paths.append("tests/")
    elif args.integration:
        # Run integration tests
        cmd.extend(["-m", "integration"])
        if args.slow:
            cmd[-1] += " or slow"
        test_paths.append("tests/test_integration.py")
    else:
        # Run all tests
        if not args.slow:
            cmd.extend(["-m", "not slow"])
        test_paths.append("tests/")

    cmd.extend(test_paths)

    # Run the tests
    success = run_command(cmd, "Dependency Sync Tests")

    if success:
        print("\n✅ All tests passed!")
        return 0
    else:
        print("\n❌ Some tests failed!")
        return 1


if __name__ == "__main__":
    sys.exit(main())
