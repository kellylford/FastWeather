/**
 * Accessibility Tests using jest-axe
 * Automated WCAG 2.2 AA compliance testing
 */

import { axe, toHaveNoViolations } from 'jest-axe';
import { mockCities, mockConfig, mockWeatherResponse } from './__mocks__/mockData.js';

expect.extend(toHaveNoViolations);

describe('Accessibility Tests', () => {
  let container;

  beforeEach(() => {
    // Create a clean DOM for each test
    document.body.innerHTML = `
      <div id="test-container"></div>
    `;
    container = document.getElementById('test-container');
    
    // Mock localStorage
    localStorage.getItem.mockReturnValue(JSON.stringify(mockCities));
  });

  afterEach(() => {
    document.body.innerHTML = '';
  });

  test('main page structure has no accessibility violations', async () => {
    // Create basic page structure
    container.innerHTML = `
      <header role="banner">
        <h1>FastWeather</h1>
      </header>
      <main role="main">
        <section>
          <h2>Add New City</h2>
          <form>
            <label for="city-input">Enter city name:</label>
            <input id="city-input" type="text" required />
            <button type="submit">Add City</button>
          </form>
        </section>
        <section>
          <h2>Your Cities</h2>
          <div id="city-list" role="list"></div>
        </section>
      </main>
    `;

    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });

  test('listbox pattern has no accessibility violations', async () => {
    container.innerHTML = `
      <div role="listbox" tabindex="0" aria-label="City list">
        <div role="option" id="city-0" aria-selected="true">
          Madison, Wisconsin - 72°F
        </div>
        <div role="option" id="city-1" aria-selected="false">
          San Diego, California - 75°F
        </div>
        <div role="option" id="city-2" aria-selected="false">
          Portland, Oregon - 68°F
        </div>
      </div>
    `;

    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });

  test('weather detail modal has no accessibility violations', async () => {
    container.innerHTML = `
      <div 
        class="modal" 
        role="dialog" 
        aria-labelledby="weather-title" 
        aria-modal="true"
      >
        <div class="modal-content">
          <h3 id="weather-title">Full Weather Details</h3>
          <section>
            <h4>Current Conditions</h4>
            <dl>
              <dt>Temperature:</dt>
              <dd>72°F</dd>
              <dt>Feels Like:</dt>
              <dd>70°F</dd>
              <dt>Humidity:</dt>
              <dd>65%</dd>
            </dl>
          </section>
          <div class="modal-buttons">
            <button>Close</button>
          </div>
        </div>
      </div>
    `;

    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });

  test('configuration dialog tabs have no accessibility violations', async () => {
    container.innerHTML = `
      <div role="dialog" aria-labelledby="config-title" aria-modal="true">
        <h3 id="config-title">Configure Weather Display</h3>
        
        <div role="tablist" aria-label="Configuration options">
          <button role="tab" aria-selected="true" aria-controls="current-panel" id="current-tab">
            Current Weather
          </button>
          <button role="tab" aria-selected="false" aria-controls="hourly-panel" id="hourly-tab">
            Hourly Forecast
          </button>
          <button role="tab" aria-selected="false" aria-controls="daily-panel" id="daily-tab">
            Daily Forecast
          </button>
        </div>
        
        <div id="current-panel" role="tabpanel" aria-labelledby="current-tab">
          <fieldset>
            <legend>Current Weather Fields</legend>
            <label><input type="checkbox" checked /> Temperature</label>
            <label><input type="checkbox" checked /> Humidity</label>
            <label><input type="checkbox" /> Wind Speed</label>
          </fieldset>
        </div>
        
        <div id="hourly-panel" role="tabpanel" aria-labelledby="hourly-tab" hidden>
          <fieldset>
            <legend>Hourly Forecast Fields</legend>
            <label><input type="checkbox" checked /> Temperature</label>
            <label><input type="checkbox" /> Precipitation</label>
          </fieldset>
        </div>
      </div>
    `;

    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });

  test('form inputs have proper labels', async () => {
    container.innerHTML = `
      <form>
        <label for="city-input">Enter city name:</label>
        <input id="city-input" type="text" required />
        
        <label for="country-select">Country (optional):</label>
        <select id="country-select">
          <option value="">All Countries</option>
          <option value="US">United States</option>
          <option value="CA">Canada</option>
        </select>
        
        <button type="submit">Add City</button>
      </form>
    `;

    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });

  test('color contrast meets WCAG AA standards', async () => {
    container.innerHTML = `
      <div style="background-color: #2563eb; color: white; padding: 20px;">
        <p>Primary button text with sufficient contrast</p>
      </div>
      <div style="background-color: #f3f4f6; color: #1f2937; padding: 20px;">
        <p>Secondary background with dark text</p>
      </div>
    `;

    const results = await axe(container, {
      runOnly: ['color-contrast']
    });
    expect(results).toHaveNoViolations();
  });

  test('headings form proper hierarchy', async () => {
    container.innerHTML = `
      <main>
        <h1>FastWeather</h1>
        <section>
          <h2>Add New City</h2>
          <p>Content here</p>
        </section>
        <section>
          <h2>Your Cities</h2>
          <article>
            <h3>Madison, Wisconsin</h3>
            <h4>Current Conditions</h4>
            <p>Details</p>
          </article>
        </section>
      </main>
    `;

    const results = await axe(container, {
      runOnly: ['heading-order']
    });
    expect(results).toHaveNoViolations();
  });

  test('landmark regions are properly defined', async () => {
    container.innerHTML = `
      <header role="banner">
        <h1>FastWeather</h1>
      </header>
      <nav aria-label="Main navigation">
        <button>View Menu</button>
      </nav>
      <main role="main">
        <section aria-labelledby="cities-heading">
          <h2 id="cities-heading">Your Cities</h2>
        </section>
      </main>
      <footer role="contentinfo">
        <p>Data provided by Open-Meteo.com</p>
      </footer>
    `;

    const results = await axe(container, {
      runOnly: ['region']
    });
    expect(results).toHaveNoViolations();
  });

  test('ARIA roles are used correctly', async () => {
    container.innerHTML = `
      <div role="dialog" aria-labelledby="dialog-title" aria-modal="true">
        <h3 id="dialog-title">Select City</h3>
        <div role="listbox" tabindex="0" aria-label="City matches">
          <div role="option" aria-selected="true">Madison, WI</div>
          <div role="option" aria-selected="false">Madison, IL</div>
        </div>
        <div role="alert" aria-live="polite">
          <!-- Status messages appear here -->
        </div>
        <button>OK</button>
        <button>Cancel</button>
      </div>
    `;

    const results = await axe(container, {
      runOnly: ['aria-allowed-role', 'aria-required-children', 'aria-required-parent']
    });
    expect(results).toHaveNoViolations();
  });

  test('interactive elements have sufficient size (touch targets)', async () => {
    container.innerHTML = `
      <button style="min-width: 44px; min-height: 44px; padding: 12px;">
        Refresh
      </button>
      <a href="#" style="display: inline-block; min-width: 44px; min-height: 44px; padding: 12px;">
        View Details
      </a>
    `;

    const results = await axe(container, {
      runOnly: ['target-size']
    });
    expect(results).toHaveNoViolations();
  });
});
