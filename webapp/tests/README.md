# FastWeather Test Suite

Comprehensive testing for the FastWeather web application using Jest, Testing Library, and jest-axe.

## Test Structure

```
tests/
├── __mocks__/
│   ├── mockData.js          # Shared test data (weather, cities, config)
│   └── styleMock.js         # CSS import mock
├── setup.js                 # Global test configuration
├── accessibility.a11y.test.js      # Accessibility compliance tests
├── configuration.unit.test.js      # Configuration management tests
└── viewModes.integration.test.js   # View switching tests
```

## Running Tests

### Install Dependencies
```bash
cd webapp
npm install
```

### Run All Tests
```bash
npm test
```

### Run Specific Test Suites
```bash
npm run test:a11y           # Accessibility tests only
npm run test:unit           # Unit tests only
npm run test:integration    # Integration tests only
```

### Watch Mode (re-run on file changes)
```bash
npm run test:watch
```

### Coverage Report
```bash
npm run test:coverage
```

## Test Files Explained

### 1. accessibility.a11y.test.js
**Purpose:** Automated WCAG 2.2 AA compliance testing

**What it tests:**
- Main page structure has no violations
- ARIA listbox pattern is correct
- Modal dialogs have proper attributes
- Tab navigation is accessible
- Form inputs have labels
- Color contrast meets standards
- Heading hierarchy is proper
- Landmark regions are defined
- ARIA roles are used correctly
- Touch targets are sufficient (44px minimum)

**Example test:**
```javascript
test('listbox pattern has no accessibility violations', async () => {
  container.innerHTML = `
    <div role="listbox" tabindex="0" aria-label="City list">
      <div role="option" id="city-0" aria-selected="true">Madison, WI</div>
    </div>
  `;
  
  const results = await axe(container);
  expect(results).toHaveNoViolations();
});
```

### 2. configuration.unit.test.js
**Purpose:** Tests configuration save/load/reset functionality

**What it tests:**
- DEFAULT_CONFIG has all required sections
- Default values are intelligent (flat view, detailed list style)
- Default units are set (imperial for US)
- Configuration saves to localStorage correctly
- Configuration loads from localStorage
- Handles missing/corrupted localStorage data
- Updates individual settings
- Reset restores defaults
- Validates configuration values

**Example test:**
```javascript
test('saves configuration to localStorage', () => {
  const config = { defaultView: 'table' };
  localStorage.setItem('weatherConfig', JSON.stringify(config));
  
  expect(localStorage.setItem).toHaveBeenCalledWith(
    'weatherConfig',
    JSON.stringify(config)
  );
});
```

### 3. viewModes.integration.test.js
**Purpose:** Tests view mode switching (flat/table/list)

**What it tests:**
- Flat view renders city cards correctly
- Table view has proper semantic structure
- List view implements ARIA listbox pattern
- Keyboard navigation works in list view
- Detailed vs condensed modes display correctly
- View switching preserves data
- Configuration saves selected view
- Each detail section can have different view mode
- Responsive behavior on different screen sizes

**Example test:**
```javascript
test('renders cities as listbox with ARIA attributes', () => {
  container.setAttribute('role', 'listbox');
  container.innerHTML = `
    <div role="option" id="item-0" aria-selected="true">City 1</div>
  `;
  
  expect(container.getAttribute('role')).toBe('listbox');
});
```

## Writing New Tests

### Test File Naming Convention
- `*.a11y.test.js` - Accessibility tests (uses jest-axe)
- `*.unit.test.js` - Unit tests (isolated function testing)
- `*.integration.test.js` - Integration tests (multiple components working together)

### Example Test Template
```javascript
import { mockCities, mockConfig } from './__mocks__/mockData.js';

describe('Feature Name', () => {
  beforeEach(() => {
    // Setup before each test
    document.body.innerHTML = '<div id="test-container"></div>';
  });

  afterEach(() => {
    // Cleanup after each test
    document.body.innerHTML = '';
  });

  test('should do something specific', () => {
    // Arrange
    const element = document.getElementById('test-container');
    
    // Act
    element.textContent = 'Test';
    
    // Assert
    expect(element.textContent).toBe('Test');
  });
});
```

## Available Test Utilities

### Jest Matchers
```javascript
expect(value).toBe(expected)          // Strict equality
expect(value).toEqual(expected)       // Deep equality
expect(value).toBeTruthy()            // Truthy value
expect(value).toBeFalsy()             // Falsy value
expect(value).toBeNull()              // null
expect(value).toBeDefined()           // not undefined
expect(value).toContain(item)         // Array/string contains
expect(fn).toThrow()                  // Function throws error
```

### Jest-Axe Matchers
```javascript
const results = await axe(container);
expect(results).toHaveNoViolations(); // No accessibility violations
```

### Mock Functions
```javascript
localStorage.getItem.mockReturnValue(JSON.stringify(data));
localStorage.setItem.mockClear();
expect(localStorage.setItem).toHaveBeenCalledWith('key', 'value');
```

### DOM Utilities
```javascript
const element = container.querySelector('.class-name');
const elements = container.querySelectorAll('[role="option"]');
element.setAttribute('aria-label', 'Label text');
element.textContent = 'New text';
```

## Coverage Goals

Current thresholds (set in package.json):
- **Branches:** 70%
- **Functions:** 70%
- **Lines:** 70%
- **Statements:** 70%

## Common Test Patterns

### Testing ARIA Attributes
```javascript
test('element has proper ARIA attributes', () => {
  const listbox = container.querySelector('[role="listbox"]');
  expect(listbox.getAttribute('tabindex')).toBe('0');
  expect(listbox.getAttribute('aria-label')).toBe('City list');
});
```

### Testing Keyboard Events
```javascript
test('handles arrow down key', () => {
  const event = new KeyboardEvent('keydown', { key: 'ArrowDown' });
  element.dispatchEvent(event);
  // Check result
});
```

### Testing localStorage
```javascript
test('saves to localStorage', () => {
  localStorage.setItem('key', 'value');
  expect(localStorage.setItem).toHaveBeenCalledWith('key', 'value');
});
```

### Testing Accessibility
```javascript
test('has no accessibility violations', async () => {
  container.innerHTML = '<button aria-label="Close">X</button>';
  const results = await axe(container);
  expect(results).toHaveNoViolations();
});
```

## Debugging Tests

### Run specific test file
```bash
npm test -- accessibility.a11y.test.js
```

### Run tests matching pattern
```bash
npm test -- --testNamePattern="listbox"
```

### Run tests in verbose mode
```bash
npm test -- --verbose
```

### Update snapshots (if using snapshot testing)
```bash
npm test -- -u
```

## Next Steps - Tests to Add

### Priority Tests
1. **keyboard.integration.test.js** - Test all keyboard shortcuts (Alt+G, Alt+L, Ctrl+R, Tab navigation)
2. **listbox.integration.test.js** - Deep testing of ARIA listbox pattern implementation
3. **weatherAPI.unit.test.js** - Test API fetch functions, error handling, data parsing
4. **cityManagement.integration.test.js** - Test add/remove/reorder cities
5. **geocoding.unit.test.js** - Test city search and geocoding

### Additional Test Ideas
- **unitConversion.unit.test.js** - Test temperature, wind speed, precipitation conversions
- **weatherCodes.unit.test.js** - Test WMO weather code descriptions
- **uvIndex.unit.test.js** - Test UV index categories and descriptions
- **dewPoint.unit.test.js** - Test dew point comfort calculations
- **rendering.unit.test.js** - Test renderFlatView, renderTableView, renderListView functions
- **focus.a11y.test.js** - Test focus management in modals and dialogs
- **screenReader.a11y.test.js** - Test ARIA announcements and labels

## Continuous Integration

To run tests in CI/CD pipeline:
```bash
npm test -- --ci --coverage --maxWorkers=2
```

## Resources

- [Jest Documentation](https://jestjs.io/docs/getting-started)
- [Testing Library](https://testing-library.com/docs/)
- [jest-axe](https://github.com/nickcolley/jest-axe)
- [WCAG 2.2 Guidelines](https://www.w3.org/WAI/WCAG22/quickref/)
- [ARIA Authoring Practices](https://www.w3.org/WAI/ARIA/apg/)

## Troubleshooting

### Tests fail with "Cannot find module"
Run `npm install` to ensure all dependencies are installed.

### Tests fail with "localStorage is not defined"
This should be handled by setup.js. Check that jest.config in package.json points to the setup file.

### Accessibility tests fail unexpectedly
Run tests individually to identify which rule is failing:
```bash
npm test -- --testNamePattern="accessibility violations"
```

### Coverage doesn't reach threshold
Identify uncovered lines:
```bash
npm run test:coverage
# Open coverage/lcov-report/index.html in browser
```

## Contributing Tests

When adding new features to FastWeather:
1. Write tests BEFORE implementing the feature (TDD)
2. Ensure tests cover happy path AND error cases
3. Add accessibility tests for any new UI elements
4. Run `npm run test:coverage` to ensure coverage doesn't drop
5. Update this README if adding new test categories
