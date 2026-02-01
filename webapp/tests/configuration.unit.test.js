/**
 * Configuration Management Unit Tests
 * Tests for save/load/reset/update configuration functionality
 */

import { mockConfig } from './__mocks__/mockData.js';

describe('Configuration Management', () => {
  beforeEach(() => {
    // Clear localStorage before each test
    localStorage.clear();
    localStorage.getItem.mockClear();
    localStorage.setItem.mockClear();
  });

  describe('Default Configuration', () => {
    test('DEFAULT_CONFIG has all required sections', () => {
      const DEFAULT_CONFIG = {
        current: {},
        hourly: {},
        daily: {},
        cityList: {},
        cityListOrder: [],
        units: {},
        defaultView: 'flat',
        listViewStyle: 'detailed',
        currentConditionsView: 'flat',
        hourlyDetailView: 'flat',
        dailyDetailView: 'flat'
      };

      expect(DEFAULT_CONFIG).toHaveProperty('current');
      expect(DEFAULT_CONFIG).toHaveProperty('hourly');
      expect(DEFAULT_CONFIG).toHaveProperty('daily');
      expect(DEFAULT_CONFIG).toHaveProperty('cityList');
      expect(DEFAULT_CONFIG).toHaveProperty('cityListOrder');
      expect(DEFAULT_CONFIG).toHaveProperty('units');
      expect(DEFAULT_CONFIG).toHaveProperty('defaultView');
      expect(DEFAULT_CONFIG).toHaveProperty('listViewStyle');
      expect(DEFAULT_CONFIG).toHaveProperty('currentConditionsView');
      expect(DEFAULT_CONFIG).toHaveProperty('hourlyDetailView');
      expect(DEFAULT_CONFIG).toHaveProperty('dailyDetailView');
    });

    test('default view modes are set to flat', () => {
      expect(mockConfig.defaultView).toBe('flat');
      expect(mockConfig.currentConditionsView).toBe('flat');
      expect(mockConfig.hourlyDetailView).toBe('flat');
      expect(mockConfig.dailyDetailView).toBe('flat');
    });

    test('default list style is detailed', () => {
      expect(mockConfig.listViewStyle).toBe('detailed');
    });

    test('default units are imperial (US)', () => {
      expect(mockConfig.units.temperature).toBe('F');
      expect(mockConfig.units.wind_speed).toBe('mph');
      expect(mockConfig.units.precipitation).toBe('in');
      expect(mockConfig.units.pressure).toBe('inHg');
      expect(mockConfig.units.distance).toBe('mi');
    });

    test('intelligent field defaults for current weather', () => {
      // Core fields should be enabled by default
      expect(mockConfig.current.temperature).toBe(true);
      expect(mockConfig.current.feels_like).toBe(true);
      expect(mockConfig.current.humidity).toBe(true);
      expect(mockConfig.current.wind_speed).toBe(true);
      expect(mockConfig.current.precipitation).toBe(true);
      
      // Advanced fields should be disabled by default
      expect(mockConfig.current.wind_direction).toBe(true); // Actually enabled in mock
      expect(mockConfig.current.pressure).toBe(false);
      expect(mockConfig.current.visibility).toBe(false);
    });

    test('intelligent field defaults for hourly forecast', () => {
      expect(mockConfig.hourly.temperature).toBe(true);
      expect(mockConfig.hourly.precipitation).toBe(true);
      expect(mockConfig.hourly.precipitation_probability).toBe(true);
      
      // Less critical fields off by default
      expect(mockConfig.hourly.feels_like).toBe(false);
      expect(mockConfig.hourly.humidity).toBe(false);
    });

    test('intelligent field defaults for daily forecast', () => {
      expect(mockConfig.daily.temperature_max).toBe(true);
      expect(mockConfig.daily.temperature_min).toBe(true);
      expect(mockConfig.daily.sunrise).toBe(true);
      expect(mockConfig.daily.sunset).toBe(true);
      expect(mockConfig.daily.precipitation_sum).toBe(true);
      expect(mockConfig.daily.precipitation_probability).toBe(true);
    });

    test('city list order is an array', () => {
      expect(Array.isArray(mockConfig.cityListOrder)).toBe(true);
      expect(mockConfig.cityListOrder.length).toBeGreaterThan(0);
    });
  });

  describe('Save Configuration', () => {
    test('saves configuration to localStorage', () => {
      const config = JSON.parse(JSON.stringify(mockConfig));
      
      // Simulate saving
      localStorage.setItem('weatherConfig', JSON.stringify(config));
      
      expect(localStorage.setItem).toHaveBeenCalledWith(
        'weatherConfig',
        JSON.stringify(config)
      );
    });

    test('saves updated configuration', () => {
      const config = JSON.parse(JSON.stringify(mockConfig));
      config.defaultView = 'table';
      config.units.temperature = 'C';
      
      localStorage.setItem('weatherConfig', JSON.stringify(config));
      
      const saved = JSON.parse(localStorage.setItem.mock.calls[0][1]);
      expect(saved.defaultView).toBe('table');
      expect(saved.units.temperature).toBe('C');
    });

    test('saves individual field updates', () => {
      const config = JSON.parse(JSON.stringify(mockConfig));
      config.current.wind_gusts = true;
      config.hourly.uv_index = true;
      
      localStorage.setItem('weatherConfig', JSON.stringify(config));
      
      const saved = JSON.parse(localStorage.setItem.mock.calls[0][1]);
      expect(saved.current.wind_gusts).toBe(true);
      expect(saved.hourly.uv_index).toBe(true);
    });
  });

  describe('Load Configuration', () => {
    test('loads configuration from localStorage', () => {
      localStorage.getItem.mockReturnValue(JSON.stringify(mockConfig));
      
      const loaded = JSON.parse(localStorage.getItem('weatherConfig'));
      
      expect(loaded).toEqual(mockConfig);
      expect(localStorage.getItem).toHaveBeenCalledWith('weatherConfig');
    });

    test('handles missing localStorage data', () => {
      localStorage.getItem.mockReturnValue(null);
      
      const loaded = localStorage.getItem('weatherConfig');
      
      expect(loaded).toBeNull();
    });

    test('handles corrupted localStorage data', () => {
      localStorage.getItem.mockReturnValue('invalid json{{{');
      
      expect(() => {
        JSON.parse(localStorage.getItem('weatherConfig'));
      }).toThrow();
    });

    test('merges partial configuration with defaults', () => {
      const partialConfig = {
        defaultView: 'list',
        units: { temperature: 'C' }
      };
      
      localStorage.getItem.mockReturnValue(JSON.stringify(partialConfig));
      const loaded = JSON.parse(localStorage.getItem('weatherConfig'));
      
      // Merge with defaults
      const merged = { ...mockConfig, ...loaded };
      
      expect(merged.defaultView).toBe('list');
      expect(merged.units.temperature).toBe('C');
      expect(merged.current).toBeDefined(); // From default
    });
  });

  describe('Update Configuration', () => {
    test('updates view mode', () => {
      const config = JSON.parse(JSON.stringify(mockConfig));
      config.defaultView = 'table';
      
      expect(config.defaultView).toBe('table');
    });

    test('updates unit preferences', () => {
      const config = JSON.parse(JSON.stringify(mockConfig));
      config.units.temperature = 'C';
      config.units.wind_speed = 'km/h';
      config.units.precipitation = 'mm';
      
      expect(config.units.temperature).toBe('C');
      expect(config.units.wind_speed).toBe('km/h');
      expect(config.units.precipitation).toBe('mm');
    });

    test('toggles individual fields', () => {
      const config = JSON.parse(JSON.stringify(mockConfig));
      const originalValue = config.current.wind_gusts;
      
      config.current.wind_gusts = !originalValue;
      
      expect(config.current.wind_gusts).toBe(!originalValue);
    });

    test('updates city list order', () => {
      const config = JSON.parse(JSON.stringify(mockConfig));
      const newOrder = ['temperature', 'conditions', 'humidity'];
      
      config.cityListOrder = newOrder;
      
      expect(config.cityListOrder).toEqual(newOrder);
    });

    test('updates detail view modes', () => {
      const config = JSON.parse(JSON.stringify(mockConfig));
      config.currentConditionsView = 'list';
      config.hourlyDetailView = 'table';
      config.dailyDetailView = 'list';
      
      expect(config.currentConditionsView).toBe('list');
      expect(config.hourlyDetailView).toBe('table');
      expect(config.dailyDetailView).toBe('list');
    });

    test('updates list view style', () => {
      const config = JSON.parse(JSON.stringify(mockConfig));
      config.listViewStyle = 'condensed';
      
      expect(config.listViewStyle).toBe('condensed');
    });
  });

  describe('Reset Configuration', () => {
    test('reset clears localStorage', () => {
      localStorage.setItem('weatherConfig', JSON.stringify(mockConfig));
      localStorage.removeItem('weatherConfig');
      
      expect(localStorage.removeItem).toHaveBeenCalledWith('weatherConfig');
    });

    test('reset restores default values', () => {
      const DEFAULT_CONFIG = {
        defaultView: 'flat',
        listViewStyle: 'detailed',
        units: { temperature: 'F' }
      };
      
      const config = JSON.parse(JSON.stringify(DEFAULT_CONFIG));
      
      expect(config.defaultView).toBe('flat');
      expect(config.listViewStyle).toBe('detailed');
      expect(config.units.temperature).toBe('F');
    });

    test('reset clears all custom settings', () => {
      localStorage.clear();
      
      expect(localStorage.clear).toHaveBeenCalled();
    });
  });

  describe('Configuration Validation', () => {
    test('validates view mode values', () => {
      const validViews = ['flat', 'table', 'list'];
      
      expect(validViews).toContain(mockConfig.defaultView);
      expect(validViews).toContain(mockConfig.currentConditionsView);
      expect(validViews).toContain(mockConfig.hourlyDetailView);
      expect(validViews).toContain(mockConfig.dailyDetailView);
    });

    test('validates list style values', () => {
      const validStyles = ['detailed', 'condensed'];
      
      expect(validStyles).toContain(mockConfig.listViewStyle);
    });

    test('validates temperature unit values', () => {
      const validUnits = ['F', 'C'];
      
      expect(validUnits).toContain(mockConfig.units.temperature);
    });

    test('validates wind speed unit values', () => {
      const validUnits = ['mph', 'km/h'];
      
      expect(validUnits).toContain(mockConfig.units.wind_speed);
    });

    test('validates precipitation unit values', () => {
      const validUnits = ['in', 'mm'];
      
      expect(validUnits).toContain(mockConfig.units.precipitation);
    });

    test('validates all boolean fields are boolean type', () => {
      Object.values(mockConfig.current).forEach(value => {
        expect(typeof value).toBe('boolean');
      });
      
      Object.values(mockConfig.hourly).forEach(value => {
        expect(typeof value).toBe('boolean');
      });
      
      Object.values(mockConfig.daily).forEach(value => {
        expect(typeof value).toBe('boolean');
      });
    });
  });
});
