---
name: testing-standards
description: Testing anti-patterns and quality standards for TDD. Preloaded into eng and rev subagents.
user-invocable: false
---

# Testing Standards

Single source of truth for testing anti-patterns and quality rules. Preloaded into both the Engineer and Reviewer subagents.

## Anti-Patterns - NEVER DO THESE

### Never Test Mock Behavior

```python
# BAD - testing the mock exists
assert mock_service.result == x

# GOOD - testing actual behavior
assert response.status_code == 200
assert result.name == "expected"
assert mock_service.called_with(id=x)
```

### Never Add Test-Only Methods to Production

```python
# BAD - method only used in tests
class Session:
    def _test_cleanup(self): ...

# GOOD - test utilities in test files
def cleanup_session(session): ...
```

### Mock Minimally

Mock external services (Twilio, Salesforce, OpenAI), not internal logic. If mock setup exceeds test logic, consider integration test.

### Don't Test Code You Didn't Write

- Framework behavior (Django ORM, DRF serializers)
- Library functionality (standard CRUD, built-in validators)
- Configuration ("does this field appear?")

Test YOUR logic, not theirs.

**Framework Validation Red Flags:**
- Tests that validate Pydantic field validators work (confidence range, type coercion)
- Tests that validate Django constraints fire (unique, FK, null)
- Test names include "validates", "validator", "constraint"
- Test only creates object and checks validation/constraint behavior

### Test Redundancy

Before writing/approving, check for tests that should be consolidated:
- Multiple tests with identical setup but different inputs -> parameterize with subTest
- Tests with same setup but different assertions -> combine into one test
- Nearly identical tests testing variations of same behavior

### Red Flags - STOP If You See These

- Assertion checks for `*-mock` test IDs
- Methods only called in test files
- Mock setup is >50% of test code
- Can't explain why mock is needed
- Wrote code before test
- Test passed immediately (testing existing behavior)
- Rationalizing "just this once"

## Quality Patterns

### Prefer Exact Assertions

**Principle:** Use exact assertions (`assertEqual`) over partial matches (`assertIn`) when testing complete output. Exact assertions catch more regressions.

```python
# BAD - partial match, misses many issues
self.assertIn("phone", prompt)
self.assertIn("email", prompt)

# GOOD - exact match catches any changes
expected_prompt = "Fields: contact.phone contact.email\nChunks: ..."
self.assertEqual(prompt, expected_prompt)
```

### Recognize Parameterization Opportunities

When writing tests for the same behavior with different inputs/outputs, use parameterization from the start.

**Pattern:** Multiple similar tests -> One parameterized test

```python
# BAD - repetitive tests
def test_confidence_above_threshold(self):
    result = ExtractionResult(confidence=0.95)
    attr = save_extraction_result(result)
    self.assertEqual(attr.status, Status.ACTIVE)

def test_confidence_below_threshold(self):
    result = ExtractionResult(confidence=0.85)
    attr = save_extraction_result(result)
    self.assertEqual(attr.status, Status.NEEDS_REVIEW)

# GOOD - parameterized test
def test_confidence_threshold(self):
    def _run_test(case_name, confidence, expected_status):
        result = ExtractionResult(
            field_key=f"field_{case_name}",  # Unique per iteration
            confidence=confidence
        )
        attr = save_extraction_result(result)
        self.assertEqual(attr.status, expected_status)

    test_cases = [
        {"case_name": "above", "confidence": 0.95, "expected_status": Status.ACTIVE},
        {"case_name": "below", "confidence": 0.85, "expected_status": Status.NEEDS_REVIEW},
    ]
    self.run_parametrized_tests(_run_test, test_cases)
```

**When to Parameterize:**
- Testing threshold behavior (above/below cutoff)
- Testing multiple status/state values
- Testing same logic with different error cases
- Testing same behavior across different input types
