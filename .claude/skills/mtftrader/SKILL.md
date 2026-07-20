```markdown
# mtftrader Development Patterns

> Auto-generated skill from repository analysis

## Overview
This skill teaches you the development patterns and conventions used in the `mtftrader` Python codebase. You'll learn about file naming, import/export styles, commit message habits, and how to structure and run tests. This guide is ideal for contributors looking to maintain consistency or onboard quickly to the project.

## Coding Conventions

### File Naming
- **PascalCase** is used for file names.
  - Example: `TradeManager.py`, `SignalProcessor.py`

### Import Style
- **Relative imports** are preferred within the codebase.
  - Example:
    ```python
    from .TradeManager import TradeManager
    from .utils import calculate_pnl
    ```

### Export Style
- **Named exports** are used; classes and functions are explicitly defined and exported.
  - Example:
    ```python
    class TradeManager:
        pass

    def calculate_pnl():
        pass
    ```

### Commit Patterns
- Commit messages are freeform, with no strict prefixing.
- Average commit message length is around 108 characters.

## Workflows

### Adding a New Feature
**Trigger:** When implementing a new functionality or module  
**Command:** `/add-feature`

1. Create a new file using PascalCase (e.g., `NewFeature.py`).
2. Use relative imports to include dependencies from within the project.
3. Define your classes and functions with explicit names.
4. Write or update corresponding test files (see Testing Patterns).
5. Commit your changes with a clear, descriptive message.

### Refactoring Existing Code
**Trigger:** When improving or restructuring existing code  
**Command:** `/refactor-code`

1. Identify the module or file to refactor.
2. Maintain PascalCase naming for any new or renamed files.
3. Update imports to remain relative.
4. Ensure all exports remain named and explicit.
5. Update or add tests as needed.
6. Commit with a message describing the refactor.

### Writing and Running Tests
**Trigger:** When adding or modifying tests  
**Command:** `/run-tests`

1. Create or update test files matching the `*.test.*` pattern (e.g., `TradeManager.test.py`).
2. Use the same import conventions as the main codebase.
3. Write tests for all new or changed functionality.
4. Run tests using your preferred Python test runner (framework is not specified).
5. Ensure all tests pass before committing.

## Testing Patterns

- Test files follow the `*.test.*` naming pattern (e.g., `OrderHandler.test.py`).
- The specific test framework is unknown; use standard Python testing practices.
- Tests should cover all major functionality and edge cases.

**Example test file:**
```python
from .TradeManager import TradeManager

def test_trade_execution():
    manager = TradeManager()
    assert manager.execute_trade() is True
```

## Commands
| Command         | Purpose                                      |
|-----------------|----------------------------------------------|
| /add-feature    | Scaffold and implement a new feature/module  |
| /refactor-code  | Refactor existing code to improve structure  |
| /run-tests      | Run all tests in the codebase                |
```
