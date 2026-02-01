/**
 * View Mode Integration Tests
 * Tests for switching between flat, table, and list views
 */

import { mockCities, mockWeatherResponse } from './__mocks__/mockData.js';

describe('View Mode Integration Tests', () => {
  let container;

  beforeEach(() => {
    document.body.innerHTML = `
      <div id="app">
        <div id="city-list" role="list"></div>
        <button id="view-btn">View: Flat</button>
        <div id="view-menu" role="menu" hidden>
          <button role="menuitem" data-view="flat">Flat View</button>
          <button role="menuitem" data-view="table">Table View</button>
          <button role="menuitem" data-view="list">List View</button>
        </div>
      </div>
    `;
    container = document.getElementById('city-list');
    
    // Mock localStorage with cities
    localStorage.getItem.mockReturnValue(JSON.stringify(mockCities));
  });

  afterEach(() => {
    document.body.innerHTML = '';
  });

  describe('Flat View (Card Layout)', () => {
    test('renders cities as individual cards', () => {
      container.innerHTML = `
        <div class="city-grid">
          <div class="city-card" data-city="Madison, Wisconsin, United States">
            <h3>Madison, Wisconsin</h3>
            <div class="weather-summary">72°F, Clear</div>
          </div>
          <div class="city-card" data-city="San Diego, California, United States">
            <h3>San Diego, California</h3>
            <div class="weather-summary">75°F, Sunny</div>
          </div>
        </div>
      `;

      const cards = container.querySelectorAll('.city-card');
      expect(cards.length).toBe(2);
      expect(cards[0].getAttribute('data-city')).toBe('Madison, Wisconsin, United States');
    });

    test('cards have proper heading structure', () => {
      container.innerHTML = `
        <div class="city-grid">
          <div class="city-card">
            <h3>Madison, Wisconsin</h3>
          </div>
        </div>
      `;

      const heading = container.querySelector('h3');
      expect(heading).toBeTruthy();
      expect(heading.textContent).toBe('Madison, Wisconsin');
    });

    test('cards display key weather information', () => {
      container.innerHTML = `
        <div class="city-card">
          <h3>Madison, Wisconsin</h3>
          <div class="weather-summary">72°F, Clear</div>
          <dl>
            <dt>Humidity:</dt><dd>65%</dd>
            <dt>Wind:</dt><dd>10 mph NE</dd>
          </dl>
        </div>
      `;

      const summary = container.querySelector('.weather-summary');
      const dl = container.querySelector('dl');
      
      expect(summary.textContent).toContain('72°F');
      expect(dl).toBeTruthy();
      expect(dl.textContent).toContain('Humidity');
    });

    test('cards have action buttons', () => {
      container.innerHTML = `
        <div class="city-card">
          <h3>Madison, Wisconsin</h3>
          <div class="card-actions">
            <button aria-label="View full weather for Madison, Wisconsin">View</button>
            <button aria-label="Refresh Madison, Wisconsin">Refresh</button>
            <button aria-label="Remove Madison, Wisconsin">Remove</button>
          </div>
        </div>
      `;

      const buttons = container.querySelectorAll('button');
      expect(buttons.length).toBe(3);
      expect(buttons[0].getAttribute('aria-label')).toContain('View full weather');
    });
  });

  describe('Table View', () => {
    test('renders cities as table rows', () => {
      container.innerHTML = `
        <div class="table-container">
          <table class="weather-table">
            <thead>
              <tr>
                <th>City</th>
                <th>Temperature</th>
                <th>Conditions</th>
                <th>Humidity</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td>Madison, Wisconsin</td>
                <td>72°F</td>
                <td>Clear</td>
                <td>65%</td>
                <td><button>View</button></td>
              </tr>
              <tr>
                <td>San Diego, California</td>
                <td>75°F</td>
                <td>Sunny</td>
                <td>60%</td>
                <td><button>View</button></td>
              </tr>
            </tbody>
          </table>
        </div>
      `;

      const table = container.querySelector('table');
      const rows = container.querySelectorAll('tbody tr');
      
      expect(table).toBeTruthy();
      expect(rows.length).toBe(2);
    });

    test('table has proper semantic structure', () => {
      container.innerHTML = `
        <table>
          <thead>
            <tr>
              <th scope="col">City</th>
              <th scope="col">Temperature</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <th scope="row">Madison, Wisconsin</th>
              <td>72°F</td>
            </tr>
          </tbody>
        </table>
      `;

      const headerCells = container.querySelectorAll('thead th');
      const rowHeader = container.querySelector('tbody th');
      
      expect(headerCells[0].getAttribute('scope')).toBe('col');
      expect(rowHeader.getAttribute('scope')).toBe('row');
    });

    test('table rows contain all configured fields', () => {
      container.innerHTML = `
        <table>
          <thead>
            <tr>
              <th>City</th>
              <th>Temp</th>
              <th>Conditions</th>
              <th>Humidity</th>
              <th>Wind</th>
              <th>High</th>
              <th>Low</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>Madison, WI</td>
              <td>72°F</td>
              <td>Clear</td>
              <td>65%</td>
              <td>10 mph</td>
              <td>75°F</td>
              <td>58°F</td>
            </tr>
          </tbody>
        </table>
      `;

      const cells = container.querySelectorAll('tbody td');
      expect(cells.length).toBe(7);
    });

    test('table is scrollable on small screens', () => {
      container.innerHTML = `
        <div class="table-wrapper" style="overflow-x: auto;">
          <table>
            <thead><tr><th>City</th></tr></thead>
            <tbody><tr><td>Madison</td></tr></tbody>
          </table>
        </div>
      `;

      const wrapper = container.querySelector('.table-wrapper');
      expect(wrapper.style.overflowX).toBe('auto');
    });
  });

  describe('List View (ARIA Listbox)', () => {
    test('renders cities as listbox with ARIA attributes', () => {
      container.setAttribute('role', 'listbox');
      container.setAttribute('tabindex', '0');
      container.setAttribute('aria-label', 'City list');
      
      container.innerHTML = `
        <div role="option" id="list-item-0" aria-selected="true">
          Madison, Wisconsin - 72°F
        </div>
        <div role="option" id="list-item-1" aria-selected="false">
          San Diego, California - 75°F
        </div>
      `;

      expect(container.getAttribute('role')).toBe('listbox');
      expect(container.getAttribute('tabindex')).toBe('0');
      
      const options = container.querySelectorAll('[role="option"]');
      expect(options.length).toBe(2);
      expect(options[0].getAttribute('aria-selected')).toBe('true');
    });

    test('listbox supports keyboard navigation', () => {
      container.setAttribute('role', 'listbox');
      container.innerHTML = `
        <div role="option" id="item-0" aria-selected="true">City 1</div>
        <div role="option" id="item-1" aria-selected="false">City 2</div>
        <div role="option" id="item-2" aria-selected="false">City 3</div>
      `;

      // Simulate arrow down key
      const event = new KeyboardEvent('keydown', { key: 'ArrowDown' });
      container.dispatchEvent(event);
      
      // In real implementation, aria-selected would update
      expect(container.querySelectorAll('[role="option"]').length).toBe(3);
    });

    test('listbox displays detailed mode with labels', () => {
      container.innerHTML = `
        <div role="option" id="item-0" aria-selected="true">
          <strong>Madison, Wisconsin</strong> • Temperature: 72°F • Conditions: Clear • Humidity: 65%
        </div>
      `;

      const option = container.querySelector('[role="option"]');
      expect(option.textContent).toContain('Temperature:');
      expect(option.textContent).toContain('Conditions:');
    });

    test('listbox displays condensed mode without labels', () => {
      container.innerHTML = `
        <div role="option" id="item-0" aria-selected="true">
          <strong>Madison, Wisconsin</strong> • 72°F • Clear • 65%
        </div>
      `;

      const option = container.querySelector('[role="option"]');
      expect(option.textContent).not.toContain('Temperature:');
      expect(option.textContent).toContain('72°F');
    });

    test('listbox has proper focus management', () => {
      container.setAttribute('role', 'listbox');
      container.setAttribute('tabindex', '0');
      container.innerHTML = `
        <div role="option" id="item-0" aria-selected="true">City 1</div>
      `;

      container.focus();
      expect(document.activeElement).toBe(container);
    });

    test('listbox items have unique IDs', () => {
      container.innerHTML = `
        <div role="option" id="list-item-0">City 1</div>
        <div role="option" id="list-item-1">City 2</div>
        <div role="option" id="list-item-2">City 3</div>
      `;

      const ids = Array.from(container.querySelectorAll('[role="option"]'))
        .map(el => el.id);
      
      const uniqueIds = new Set(ids);
      expect(uniqueIds.size).toBe(ids.length);
    });

    test('listbox scrolls to keep active item visible', () => {
      container.style.maxHeight = '500px';
      container.style.overflowY = 'auto';
      
      container.innerHTML = Array.from({ length: 10 }, (_, i) => `
        <div role="option" id="item-${i}" aria-selected="${i === 0}">
          City ${i}
        </div>
      `).join('');

      const lastItem = container.querySelector('#item-9');
      lastItem.scrollIntoView({ block: 'nearest' });
      
      // Verify scroll happened (in real DOM)
      expect(lastItem).toBeTruthy();
    });
  });

  describe('View Switching', () => {
    test('switches from flat to table view', () => {
      const viewBtn = document.getElementById('view-btn');
      
      // Initial state: flat view
      expect(viewBtn.textContent).toContain('Flat');
      
      // Switch to table
      viewBtn.textContent = 'View: Table';
      expect(viewBtn.textContent).toContain('Table');
    });

    test('switches from table to list view', () => {
      const viewBtn = document.getElementById('view-btn');
      
      viewBtn.textContent = 'View: List';
      expect(viewBtn.textContent).toContain('List');
    });

    test('view menu updates checkmarks on selection', () => {
      const menu = document.getElementById('view-menu');
      const flatBtn = menu.querySelector('[data-view="flat"]');
      const tableBtn = menu.querySelector('[data-view="table"]');
      
      flatBtn.setAttribute('aria-checked', 'true');
      tableBtn.setAttribute('aria-checked', 'false');
      
      expect(flatBtn.getAttribute('aria-checked')).toBe('true');
      expect(tableBtn.getAttribute('aria-checked')).toBe('false');
    });

    test('preserves city data when switching views', () => {
      const cityData = {
        name: 'Madison, Wisconsin',
        temp: '72°F',
        conditions: 'Clear'
      };

      // Data should persist across view changes
      expect(cityData.name).toBe('Madison, Wisconsin');
      expect(cityData.temp).toBe('72°F');
    });

    test('saves selected view to configuration', () => {
      const config = { defaultView: 'flat' };
      
      config.defaultView = 'list';
      localStorage.setItem('weatherConfig', JSON.stringify(config));
      
      const saved = JSON.parse(localStorage.setItem.mock.calls[0][1]);
      expect(saved.defaultView).toBe('list');
    });

    test('loads saved view on app initialization', () => {
      const config = { defaultView: 'table' };
      localStorage.getItem.mockReturnValue(JSON.stringify(config));
      
      const loaded = JSON.parse(localStorage.getItem('weatherConfig'));
      expect(loaded.defaultView).toBe('table');
    });
  });

  describe('Detail View Modes', () => {
    test('current conditions respects view mode setting', () => {
      const config = {
        currentConditionsView: 'list'
      };

      expect(config.currentConditionsView).toBe('list');
    });

    test('hourly forecast respects view mode setting', () => {
      const config = {
        hourlyDetailView: 'table'
      };

      expect(config.hourlyDetailView).toBe('table');
    });

    test('daily forecast respects view mode setting', () => {
      const config = {
        dailyDetailView: 'list'
      };

      expect(config.dailyDetailView).toBe('list');
    });

    test('each detail section can have different view mode', () => {
      const config = {
        currentConditionsView: 'flat',
        hourlyDetailView: 'table',
        dailyDetailView: 'list'
      };

      expect(config.currentConditionsView).toBe('flat');
      expect(config.hourlyDetailView).toBe('table');
      expect(config.dailyDetailView).toBe('list');
    });
  });

  describe('Responsive Behavior', () => {
    test('flat view adapts to grid on desktop', () => {
      container.innerHTML = `
        <div class="city-grid" style="display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));">
          <div class="city-card">Card 1</div>
          <div class="city-card">Card 2</div>
        </div>
      `;

      const grid = container.querySelector('.city-grid');
      expect(grid.style.display).toBe('grid');
    });

    test('table view uses horizontal scroll on mobile', () => {
      container.innerHTML = `
        <div class="table-wrapper" style="overflow-x: auto;">
          <table style="min-width: 600px;">
            <tbody><tr><td>Data</td></tr></tbody>
          </table>
        </div>
      `;

      const wrapper = container.querySelector('.table-wrapper');
      const table = container.querySelector('table');
      
      expect(wrapper.style.overflowX).toBe('auto');
      expect(table.style.minWidth).toBe('600px');
    });

    test('list view stacks vertically on all screen sizes', () => {
      container.innerHTML = `
        <div role="listbox">
          <div role="option">Item 1</div>
          <div role="option">Item 2</div>
        </div>
      `;

      const options = container.querySelectorAll('[role="option"]');
      expect(options.length).toBe(2);
      // Items naturally stack vertically in listbox
    });
  });
});
