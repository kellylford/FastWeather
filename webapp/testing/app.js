/**
 * FastWeather Web Application
 * Accessible weather application with WCAG 2.2 AA compliance
 */

// Constants
const KMH_TO_MPH = 0.621371;
const MM_TO_INCHES = 0.0393701;
const HPA_TO_INHG = 0.02953;
const M_TO_MILES = 0.000621371;
const M_TO_KM = 0.001;
const OPEN_METEO_API_URL = 'https://api.open-meteo.com/v1/forecast';
const NOMINATIM_URL = 'https://nominatim.openstreetmap.org/search';

// WMO Weather interpretation codes
const WEATHER_CODES = {
    0: 'Clear sky', 1: 'Mainly clear', 2: 'Partly cloudy', 3: 'Overcast',
    45: 'Fog', 48: 'Depositing rime fog',
    51: 'Light drizzle', 53: 'Moderate drizzle', 55: 'Dense drizzle',
    56: 'Light freezing drizzle', 57: 'Dense freezing drizzle',
    61: 'Slight rain', 63: 'Moderate rain', 65: 'Heavy rain',
    66: 'Light freezing rain', 67: 'Heavy freezing rain',
    71: 'Slight snow fall', 73: 'Moderate snow fall', 75: 'Heavy snow fall',
    77: 'Snow grains',
    80: 'Slight rain showers', 81: 'Moderate rain showers', 82: 'Violent rain showers',
    85: 'Slight snow showers', 86: 'Heavy snow showers',
    95: 'Thunderstorm',
    96: 'Thunderstorm with slight hail', 99: 'Thunderstorm with heavy hail'
};

// Default configuration
const DEFAULT_CONFIG = {
    current: {
        temperature: true,
        feels_like: true,
        humidity: true,
        wind_speed: true,
        wind_direction: true,
        pressure: false,
        visibility: false,
        precipitation: true,
        cloud_cover: false,
        rain: false,
        showers: false,
        snowfall: false
    },
    hourly: {
        temperature: true,
        feels_like: false,
        humidity: false,
        precipitation: true,
        wind_speed: false,
        cloud_cover: false
    },
    daily: {
        temperature_max: true,
        temperature_min: true,
        sunrise: true,
        sunset: true,
        precipitation_sum: true,
        wind_speed_max: false
    },
    cityList: {
        temperature: true,
        conditions: true,
        feels_like: true,
        humidity: true,
        wind_speed: true,
        wind_direction: true,
        high_temp: true,
        low_temp: true
    },
    units: {
        temperature: 'F',
        wind_speed: 'mph',
        precipitation: 'in',
        pressure: 'inHg',
        distance: 'mi'
    }
};

// Application state
let cities = {};
let weatherData = {};
let currentConfig = JSON.parse(JSON.stringify(DEFAULT_CONFIG));
let currentCityMatches = [];
let focusReturnElement = null;
let currentView = 'flat'; // 'flat', 'table', or 'list'
let listNavigationHandler = null;
let cachedCityCoordinates = null; // Cache for pre-geocoded city coordinates
let currentStateCities = null; // Store current state cities being viewed
let currentStateName = null; // Store current state name

// Initialize app
document.addEventListener('DOMContentLoaded', async () => {
    console.log('=== FastWeather Initializing ===');
    loadCitiesFromStorage();
    loadConfigFromStorage();
    initializeEventListeners();
    renderCityList();
    
    // Load cached city coordinates
    console.log('About to load cached city coordinates...');
    await loadCachedCityCoordinates();
    console.log('After loadCachedCityCoordinates, cachedCityCoordinates is:', cachedCityCoordinates ? 'LOADED' : 'NULL/UNDEFINED');
    
    announceToScreenReader('FastWeather application loaded');
    console.log('=== FastWeather Initialization Complete ===');
});

// Load cached city coordinates from JSON file
async function loadCachedCityCoordinates() {
    try {
        console.log('Fetching us-cities-cached.json...');
        const response = await fetch('us-cities-cached.json');
        console.log('Fetch response:', response.status, response.statusText);
        if (response.ok) {
            cachedCityCoordinates = await response.json();
            const stateCount = cachedCityCoordinates ? Object.keys(cachedCityCoordinates).length : 0;
            const states = cachedCityCoordinates ? Object.keys(cachedCityCoordinates).join(', ') : 'none';
            console.log(`✓ Successfully loaded cached city coordinates for ${stateCount} states: ${states}`);
            
            // Add a global debug function for easy access
            window.debugCache = () => {
                console.log('=== Cache Debug Info ===');
                console.log('cachedCityCoordinates exists:', !!cachedCityCoordinates);
                if (cachedCityCoordinates) {
                    console.log('States in cache:', Object.keys(cachedCityCoordinates));
                    Object.keys(cachedCityCoordinates).forEach(state => {
                        console.log(`  ${state}: ${cachedCityCoordinates[state].length} cities`);
                    });
                }
            };
            console.log('You can run debugCache() in console to check cache status');
            console.log('You can run reloadCache() to try loading again');
        } else {
            console.error(`❌ Failed to fetch cached city coordinates: HTTP ${response.status} ${response.statusText}`);
        }
    } catch (error) {
        console.error('❌ Could not load cached city coordinates:', error);
        console.error('Error details:', error.message, error.stack);
    }
}

// Manual cache reload function for debugging
window.reloadCache = async function() {
    console.log('Manually reloading cache...');
    await loadCachedCityCoordinates();
    if (cachedCityCoordinates) {
        console.log('✓ Cache reloaded successfully');
        window.debugCache();
    } else {
        console.error('❌ Cache still not loaded');
    }
};

// Event Listeners
function initializeEventListeners() {
    // Add city form
    document.getElementById('add-city-form').addEventListener('submit', handleAddCity);
    
    // State selector form
    document.getElementById('state-selector-form').addEventListener('submit', handleStateSelection);
    
    // Configuration dialog
    document.getElementById('configure-btn').addEventListener('click', openConfigDialog);
    document.getElementById('apply-config-btn').addEventListener('click', applyConfiguration);
    document.getElementById('save-config-btn').addEventListener('click', saveConfiguration);
    document.getElementById('cancel-config-btn').addEventListener('click', closeConfigDialog);
    
    // City selection dialog
    document.getElementById('select-city-btn').addEventListener('click', handleCitySelection);
    document.getElementById('cancel-selection-btn').addEventListener('click', closeCitySelectionDialog);
    
    // Refresh all
    document.getElementById('refresh-all-btn').addEventListener('click', refreshAllCities);
    
    // View menu button
    const viewMenuBtn = document.getElementById('view-menu-btn');
    const viewMenu = document.getElementById('view-menu');
    
    viewMenuBtn.addEventListener('click', toggleViewMenu);
    
    // Menu item clicks
    document.querySelectorAll('#view-menu [role="menuitem"]').forEach(item => {
        item.addEventListener('click', (e) => {
            const view = e.target.dataset.view;
            switchView(view);
            closeViewMenu();
        });
    });
    
    // Close menu on Escape or outside click
    document.addEventListener('click', (e) => {
        if (!e.target.closest('.view-menu-container')) {
            closeViewMenu();
        }
    });
    
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && viewMenu.hidden === false) {
            closeViewMenu();
            viewMenuBtn.focus();
        }
    });
    
    // Keyboard navigation in menu
    viewMenu.addEventListener('keydown', handleViewMenuKeydown);
    
    // Close weather details
    document.getElementById('close-weather-details-btn').addEventListener('click', closeWeatherDetailsDialog);
    
    // Tab navigation for config dialog
    setupTabNavigation();
    
    // Keyboard shortcuts
    document.addEventListener('keydown', handleKeyboardShortcuts);
    
    // Close modals on Escape
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            closeAllModals();
        }
    });
}

// Keyboard shortcuts
function handleKeyboardShortcuts(e) {
    // Ctrl+R: Refresh all cities
    if (e.ctrlKey && e.key === 'r') {
        e.preventDefault();
        refreshAllCities();
    }
}

// Tab navigation
function setupTabNavigation() {
    const tabs = document.querySelectorAll('[role="tab"]');
    const panels = document.querySelectorAll('[role="tabpanel"]');
    
    tabs.forEach((tab, index) => {
        tab.addEventListener('click', () => activateTab(tab, panels));
        tab.addEventListener('keydown', (e) => {
            let newIndex = index;
            
            if (e.key === 'ArrowRight') {
                newIndex = (index + 1) % tabs.length;
                e.preventDefault();
            } else if (e.key === 'ArrowLeft') {
                newIndex = (index - 1 + tabs.length) % tabs.length;
                e.preventDefault();
            } else if (e.key === 'Home') {
                newIndex = 0;
                e.preventDefault();
            } else if (e.key === 'End') {
                newIndex = tabs.length - 1;
                e.preventDefault();
            }
            
            if (newIndex !== index) {
                activateTab(tabs[newIndex], panels);
                tabs[newIndex].focus();
            }
        });
    });
}

function activateTab(selectedTab, panels) {
    const tabs = document.querySelectorAll('[role="tab"]');
    
    tabs.forEach(tab => {
        tab.setAttribute('aria-selected', 'false');
        tab.setAttribute('tabindex', '-1');
    });
    
    panels.forEach(panel => {
        panel.hidden = true;
    });
    
    selectedTab.setAttribute('aria-selected', 'true');
    selectedTab.setAttribute('tabindex', '0');
    
    const panelId = selectedTab.getAttribute('aria-controls');
    document.getElementById(panelId).hidden = false;
}

// Add city handler
async function handleAddCity(e) {
    e.preventDefault();
    
    const input = document.getElementById('city-input');
    const countrySelect = document.getElementById('country-select');
    const cityName = input.value.trim();
    const countryCode = countrySelect ? countrySelect.value : '';
    const errorDiv = document.getElementById('city-search-error');
    
    if (!cityName) {
        showError(errorDiv, 'Please enter a city name');
        return;
    }
    
    clearError(errorDiv);
    
    try {
        const matches = await geocodeCity(cityName, countryCode);
        
        if (matches.length === 0) {
            showError(errorDiv, `No cities found for "${cityName}"`);
            return;
        }
        
        if (matches.length === 1) {
            await addCity(matches[0]);
            input.value = '';
        } else {
            currentCityMatches = matches;
            showCitySelectionDialog(cityName, matches);
        }
    } catch (error) {
        showError(errorDiv, `Error searching for city: ${error.message}`);
    }
}

// Geocode city
async function geocodeCity(cityName, countryCode = '') {
    const params = new URLSearchParams({
        q: cityName,
        format: 'json',
        addressdetails: '1',
        limit: '5'
    });
    
    if (countryCode) {
        params.set('countrycodes', countryCode);
    }
    
    const response = await fetch(`${NOMINATIM_URL}?${params}`, {
        headers: { 'User-Agent': 'FastWeather Web/1.0' }
    });
    
    if (!response.ok) throw new Error('Failed to search for city');
    
    const results = await response.json();
    
    return results.map(r => {
        const address = r.address || {};
        const city = address.city || address.town || address.village || cityName;
        const state = address.state || '';
        const country = address.country || '';
        const displayParts = [city, state, country].filter(p => p);
        
        return {
            display: displayParts.join(', '),
            city, state, country,
            lat: parseFloat(r.lat),
            lon: parseFloat(r.lon)
        };
    });
}

// City selection dialog
function showCitySelectionDialog(originalInput, matches) {
    const dialog = document.getElementById('city-selection-dialog');
    const listBox = document.getElementById('city-matches-list');
    const desc = document.getElementById('city-selection-desc');
    
    desc.textContent = `Multiple cities found for "${originalInput}". Please select one:`;
    
    listBox.innerHTML = '';
    matches.forEach((match, index) => {
        const option = document.createElement('div');
        option.className = 'city-option';
        option.setAttribute('role', 'option');
        option.setAttribute('id', `city-option-${index}`);
        option.setAttribute('aria-selected', index === 0 ? 'true' : 'false');
        option.textContent = `${match.display} (${match.lat.toFixed(4)}, ${match.lon.toFixed(4)})`;
        option.dataset.index = index;
        
        option.addEventListener('click', () => {
            setActiveOption(index);
            handleCitySelection();
        });
        
        listBox.appendChild(option);
    });
    
    // Set aria-activedescendant to the first option
    listBox.setAttribute('aria-activedescendant', 'city-option-0');
    
    focusReturnElement = document.activeElement;
    dialog.hidden = false;
    
    // Add keyboard navigation to listBox
    listBox.addEventListener('keydown', handleCityListKeydown);
    
    // Set up focus trap
    trapFocus(dialog);
    
    // Focus the listbox
    listBox.focus();
    
    // Scroll first option into view
    const firstOption = listBox.querySelector('#city-option-0');
    if (firstOption) {
        firstOption.scrollIntoView({ block: 'nearest' });
    }
}

function setActiveOption(index) {
    const listBox = document.getElementById('city-matches-list');
    const options = Array.from(listBox.querySelectorAll('.city-option'));
    
    if (index < 0 || index >= options.length) return;
    
    // Update aria-selected on all options
    options.forEach((opt, i) => {
        opt.setAttribute('aria-selected', i === index ? 'true' : 'false');
    });
    
    // Update aria-activedescendant on listbox
    listBox.setAttribute('aria-activedescendant', `city-option-${index}`);
    
    // Scroll option into view
    options[index].scrollIntoView({ block: 'nearest' });
}

function handleCityListKeydown(e) {
    const listBox = e.currentTarget;
    const options = Array.from(listBox.querySelectorAll('.city-option'));
    const currentIndex = options.findIndex(opt => opt.getAttribute('aria-selected') === 'true');
    
    let newIndex = currentIndex;
    
    switch(e.key) {
        case 'ArrowDown':
            e.preventDefault();
            newIndex = Math.min(currentIndex + 1, options.length - 1);
            if (newIndex !== currentIndex) {
                setActiveOption(newIndex);
            }
            break;
            
        case 'ArrowUp':
            e.preventDefault();
            newIndex = Math.max(currentIndex - 1, 0);
            if (newIndex !== currentIndex) {
                setActiveOption(newIndex);
            }
            break;
            
        case 'Home':
            e.preventDefault();
            setActiveOption(0);
            break;
            
        case 'End':
            e.preventDefault();
            setActiveOption(options.length - 1);
            break;
            
        case 'Enter':
            e.preventDefault();
            handleCitySelection();
            break;
            
        case ' ':
            e.preventDefault();
            handleCitySelection();
            break;
    }
}

async function handleCitySelection() {
    const selected = document.querySelector('.city-option[aria-selected="true"]');
    if (!selected) return;
    
    const index = parseInt(selected.dataset.index);
    const match = currentCityMatches[index];
    
    closeCitySelectionDialog();
    await addCity(match);
    document.getElementById('city-input').value = '';
}

function closeCitySelectionDialog() {
    const dialog = document.getElementById('city-selection-dialog');
    const listBox = document.getElementById('city-matches-list');
    
    // Remove event listener
    listBox.removeEventListener('keydown', handleCityListKeydown);
    
    // Clear aria-activedescendant
    listBox.removeAttribute('aria-activedescendant');
    
    dialog.hidden = true;
    if (focusReturnElement) {
        focusReturnElement.focus();
        focusReturnElement = null;
    }
}

// Add city to list
async function addCity(cityData, skipRender = false) {
    const key = cityData.display;
    
    if (cities[key]) {
        announceToScreenReader(`${key} is already in your list`);
        return false;
    }
    
    cities[key] = [cityData.lat, cityData.lon];
    saveCitiesToStorage();
    
    // Only render city list if not in state browsing mode
    if (!skipRender) {
        renderCityList();
    }
    
    announceToScreenReader(`${key} added to list`);
    
    // Fetch weather for new city
    await fetchWeatherForCity(key, cityData.lat, cityData.lon);
    
    return true;
}

// Handle state selection
async function handleStateSelection(e) {
    e.preventDefault();
    
    const stateSelect = document.getElementById('state-select');
    const stateName = stateSelect.value;
    const errorDiv = document.getElementById('state-selector-error');
    
    console.log('State selected:', stateName);
    
    if (!stateName) {
        showError(errorDiv, 'Please select a state');
        return;
    }
    
    clearError(errorDiv);
    
    // Check if US_CITIES_BY_STATE is defined
    if (typeof US_CITIES_BY_STATE === 'undefined') {
        console.error('US_CITIES_BY_STATE not loaded');
        showError(errorDiv, 'City data not loaded. Please refresh the page.');
        return;
    }
    
    // Get cities for the selected state
    const stateCities = US_CITIES_BY_STATE[stateName];
    
    if (!stateCities || stateCities.length === 0) {
        showError(errorDiv, 'No cities found for this state');
        return;
    }
    
    // Load all 50 cities
    console.log('Loading all', stateCities.length, 'cities');
    displayStateCities(stateName, stateCities, stateCities.length);
}

// Show your cities (return from state browsing)
function showYourCities() {
    const stateSelectorSection = document.querySelector('.state-selector-section');
    const cityListSection = document.querySelector('.city-list-section');
    const heading = document.getElementById('your-cities-heading');
    
    // Clear state cities tracking
    currentStateCities = null;
    currentStateName = null;
    
    // Reset heading and show state selector
    heading.textContent = 'Your Cities';
    stateSelectorSection.hidden = false;
    cityListSection.hidden = false;
    
    // Re-render the user's city list
    renderCityList();
    
    announceToScreenReader('Returned to your cities list');
}

// Display state cities
async function displayStateCities(stateName, cityNames, totalCount = null) {
    // Hide state selector section and show city list section with state cities
    const stateSelectorSection = document.querySelector('.state-selector-section');
    const cityListSection = document.querySelector('.city-list-section');
    const heading = document.getElementById('your-cities-heading');
    const container = document.getElementById('city-list');
    
    const displayTotal = totalCount || cityNames.length;
    
    // Keep state selector visible and update heading
    stateSelectorSection.hidden = false;
    heading.innerHTML = `Cities in ${stateName} <button id="back-to-your-cities-btn" class="back-btn" aria-label="Return to your cities list">← Back to Your Cities</button>`;
    container.innerHTML = '<p class="loading-text">Loading weather data... (0/' + cityNames.length + ')</p>';
    cityListSection.hidden = false;
    
    // Add event listener for back button
    document.getElementById('back-to-your-cities-btn').addEventListener('click', () => {
        showYourCities();
    });
    
    console.log('displayStateCities called with', cityNames.length, 'cities');
    console.log('Cached data available:', cachedCityCoordinates ? Object.keys(cachedCityCoordinates) : 'none');
    console.log(`Looking for cached data for state: "${stateName}" (length: ${stateName.length}, charCodes: ${[...stateName].map(c => c.charCodeAt(0)).join(',')})`);
    
    // Debug: Check exact match
    if (cachedCityCoordinates) {
        const cacheKeys = Object.keys(cachedCityCoordinates);
        console.log('Exact match test:');
        cacheKeys.forEach(key => {
            if (key.toLowerCase().includes('alabama') || stateName.toLowerCase().includes('alabama')) {
                console.log(`  Cache key "${key}" (${key.length} chars) === "${stateName}" (${stateName.length} chars)? ${key === stateName}`);
            }
        });
    }
    
    console.log(`Cache has "${stateName}":`, cachedCityCoordinates && cachedCityCoordinates[stateName] ? 'YES' : 'NO');
    
    const citiesData = [];
    
    // Check if we have cached coordinates for this state
    const useCached = cachedCityCoordinates && cachedCityCoordinates[stateName];
    
    if (useCached) {
        // Use cached coordinates - much faster!
        console.log(`✓ Using cached coordinates for ${stateName} (${cachedCityCoordinates[stateName].length} cities in cache)`);
        
        for (let i = 0; i < cityNames.length; i++) {
            const cityName = cityNames[i];
            const cachedCity = cachedCityCoordinates[stateName].find(c => c.name === cityName);
            
            if (cachedCity) {
                const state = cachedCity.state || stateName;
                const country = cachedCity.country || 'United States';
                const cityInfo = {
                    name: cityName,
                    display: `${cityName}, ${state}, ${country}`,
                    state: state,
                    country: country,
                    lat: cachedCity.lat,
                    lon: cachedCity.lon,
                    weather: null
                };
                
                // Fetch weather data for this city
                try {
                    const weather = await fetchWeatherData(cityInfo.lat, cityInfo.lon);
                    cityInfo.weather = weather;
                    console.log(`Loaded weather for ${cityName}`);
                } catch (weatherError) {
                    console.error(`Error fetching weather for ${cityName}:`, weatherError);
                }
                
                citiesData.push(cityInfo);
                
                // Update progress
                container.innerHTML = `<p class="loading-text">Loading weather data... (${i + 1}/${cityNames.length})</p>`;
            } else {
                console.warn(`City ${cityName} not found in cache`);
            }
        }
    } else {
        // Fall back to geocoding if no cached data
        console.warn(`⚠ No cached data found for "${stateName}", falling back to geocoding (this will be slow)`);
        console.log('Possible reasons:');
        console.log('  1. JSON file not loaded (check network tab)');
        console.log('  2. State name mismatch (check spelling/capitalization)');
        console.log('  3. State not yet added to cache');
        if (cachedCityCoordinates) {
            console.log('  Available states:', Object.keys(cachedCityCoordinates));
        }
        const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
        
        for (let i = 0; i < cityNames.length; i++) {
            const cityName = cityNames[i];
            try {
                const fullName = `${cityName}, ${stateName}`;
                const matches = await geocodeCity(fullName, 'us');
                if (matches && matches.length > 0) {
                    const cityInfo = {
                        name: cityName,
                        display: matches[0].display,
                        state: stateName,
                        country: 'United States',
                        lat: matches[0].lat,
                        lon: matches[0].lon,
                        weather: null
                    };
                    
                    // Fetch weather data for this city
                    try {
                        const weather = await fetchWeatherData(cityInfo.lat, cityInfo.lon);
                        cityInfo.weather = weather;
                    } catch (weatherError) {
                        console.error(`Error fetching weather for ${cityName}:`, weatherError);
                    }
                    
                    citiesData.push(cityInfo);
                }
                
                // Update progress
                container.innerHTML = `<p class="loading-text">Loading weather data... (${i + 1}/${cityNames.length})</p>`;
                
                // Rate limiting: wait 1.1 seconds between geocoding requests
                if (i < cityNames.length - 1) {
                    await delay(1100);
                }
            } catch (error) {
                console.error(`Error geocoding ${cityName}:`, error);
            }
        }
    }
    
    // Render the cities list
    console.log('Rendering', citiesData.length, 'cities');
    if (citiesData.length > 0) {
        // Store state cities for view switching
        currentStateCities = citiesData;
        currentStateName = stateName;
        
        heading.innerHTML = `Cities in ${stateName} (${citiesData.length}) <button id="back-to-your-cities-btn" class="back-btn" aria-label="Return to your cities list">← Back to Your Cities</button>`;
        renderStateCitiesWithWeather(container, citiesData);
        announceToScreenReader(`Loaded ${citiesData.length} cities with weather for ${stateName}`);
        
        // Re-attach event listener for back button
        document.getElementById('back-to-your-cities-btn').addEventListener('click', () => {
            showYourCities();
        });
    } else {
        container.innerHTML = '<p class="error-message">Failed to load city data. Please try again later.</p>';
        announceToScreenReader('Failed to load city data');
    }
}

// Helper function to fetch weather data without storing in weatherData object
async function fetchWeatherData(lat, lon) {
    const params = new URLSearchParams({
        latitude: lat,
        longitude: lon,
        current: 'temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,rain,showers,snowfall,weather_code,cloud_cover,pressure_msl,wind_speed_10m,wind_direction_10m,visibility',
        hourly: 'cloudcover',
        daily: 'temperature_2m_max,temperature_2m_min',
        forecast_days: '1',
        timezone: 'auto'
    });
    
    const response = await fetch(`${OPEN_METEO_API_URL}?${params}`);
    if (!response.ok) throw new Error('Failed to fetch weather data');
    
    return await response.json();
}

// Render state cities with weather in the current view
function renderStateCitiesWithWeather(container, citiesData) {
    container.innerHTML = '';
    
    if (currentView === 'table') {
        renderStateCitiesTableWithWeather(container, citiesData);
    } else if (currentView === 'list') {
        renderStateCitiesListWithWeather(container, citiesData);
    } else {
        renderStateCitiesFlatWithWeather(container, citiesData);
    }
}

// Render state cities in the current view (legacy function - keeping for compatibility)
function renderStateCities(container, citiesData) {
    container.innerHTML = '';
    
    if (currentView === 'table') {
        renderStateCitiesTable(container, citiesData);
    } else if (currentView === 'list') {
        renderStateCitiesList(container, citiesData);
    } else {
        renderStateCitiesFlat(container, citiesData);
    }
}

// Render state cities in flat view
function renderStateCitiesFlat(container, citiesData) {
    container.setAttribute('role', 'list');
    
    citiesData.forEach((cityData) => {
        const card = document.createElement('article');
        card.className = 'city-card state-city-card';
        card.setAttribute('role', 'listitem');
        card.setAttribute('aria-label', `${cityData.display}`);
        
        const header = document.createElement('div');
        header.className = 'city-card-header';
        
        const title = document.createElement('h4');
        title.textContent = cityData.display;
        header.appendChild(title);
        card.appendChild(header);
        
        const content = document.createElement('div');
        content.className = 'city-card-content';
        
        const coords = document.createElement('p');
        coords.className = 'coordinates';
        coords.textContent = `Coordinates: ${cityData.lat.toFixed(4)}, ${cityData.lon.toFixed(4)}`;
        content.appendChild(coords);
        
        card.appendChild(content);
        
        const controls = document.createElement('div');
        controls.className = 'city-card-controls';
        
        const addBtn = createButton('➕ Add to My Cities', `Add ${cityData.display} to your cities list`, async () => {
            await addCityFromState(cityData);
        });
        addBtn.className = 'add-city-btn';
        controls.appendChild(addBtn);
        
        card.appendChild(controls);
        container.appendChild(card);
    });
}

// Render state cities in table view
function renderStateCitiesTable(container, citiesData) {
    container.setAttribute('role', 'region');
    
    const table = document.createElement('table');
    table.className = 'weather-table';
    
    const thead = document.createElement('thead');
    const headerRow = document.createElement('tr');
    
    const cityHeader = document.createElement('th');
    cityHeader.textContent = 'City';
    cityHeader.scope = 'col';
    headerRow.appendChild(cityHeader);
    
    const coordsHeader = document.createElement('th');
    coordsHeader.textContent = 'Coordinates';
    coordsHeader.scope = 'col';
    headerRow.appendChild(coordsHeader);
    
    const actionsHeader = document.createElement('th');
    actionsHeader.textContent = 'Actions';
    actionsHeader.scope = 'col';
    headerRow.appendChild(actionsHeader);
    
    thead.appendChild(headerRow);
    table.appendChild(thead);
    
    const tbody = document.createElement('tbody');
    
    citiesData.forEach((cityData) => {
        const row = document.createElement('tr');
        
        const cityCell = document.createElement('th');
        cityCell.scope = 'row';
        cityCell.textContent = cityData.display;
        row.appendChild(cityCell);
        
        const coordsCell = document.createElement('td');
        coordsCell.textContent = `${cityData.lat.toFixed(4)}, ${cityData.lon.toFixed(4)}`;
        row.appendChild(coordsCell);
        
        const actionsCell = document.createElement('td');
        const addBtn = createButton('➕ Add', `Add ${cityData.display} to your cities list`, async () => {
            await addCityFromState(cityData);
        });
        addBtn.className = 'add-city-btn-small';
        actionsCell.appendChild(addBtn);
        row.appendChild(actionsCell);
        
        tbody.appendChild(row);
    });
    
    table.appendChild(tbody);
    container.appendChild(table);
}

// Render state cities in list view
function renderStateCitiesList(container, citiesData) {
    container.setAttribute('role', 'listbox');
    container.setAttribute('tabindex', '0');
    container.setAttribute('aria-label', 'State cities - use arrow keys to navigate');
    
    citiesData.forEach((cityData, index) => {
        const item = document.createElement('div');
        item.className = 'list-view-item state-city-item';
        item.setAttribute('role', 'option');
        item.id = `state-city-item-${index}`;
        item.setAttribute('aria-selected', index === 0 ? 'true' : 'false');
        
        const textSpan = document.createElement('span');
        textSpan.textContent = `${cityData.display} (${cityData.lat.toFixed(4)}, ${cityData.lon.toFixed(4)})`;
        item.appendChild(textSpan);
        
        const addBtn = createButton('➕ Add', `Add ${cityData.display} to your cities list`, async (e) => {
            e.stopPropagation();
            await addCityFromState(cityData);
        });
        addBtn.className = 'add-city-btn-small inline';
        item.appendChild(addBtn);
        
        item.dataset.cityData = JSON.stringify(cityData);
        
        container.appendChild(item);
    });
    
    container.setAttribute('aria-activedescendant', 'state-city-item-0');
}

// Add city from state selection
async function addCityFromState(cityData) {
    const added = await addCity({
        display: cityData.display,
        city: cityData.name,
        state: cityData.state || '',
        country: cityData.country || 'United States',
        lat: cityData.lat,
        lon: cityData.lon
    }, true); // Skip render - we'll stay in state view
    
    // Re-render state cities to update button states
    if (added && currentStateCities && currentStateName) {
        const container = document.getElementById('city-list');
        renderStateCitiesWithWeather(container, currentStateCities);
    }
}

// Remove city from user's list (for state browsing)
async function removeCityFromState(cityData) {
    const key = cityData.display;
    
    if (cities[key]) {
        delete cities[key];
        delete weatherData[key];
        saveCitiesToStorage();
        announceToScreenReader(`${key} removed from list`);
        
        // Re-render state cities to update button states
        if (currentStateCities && currentStateName) {
            const container = document.getElementById('city-list');
            renderStateCitiesWithWeather(container, currentStateCities);
        }
    }
}

// Render state cities with weather data in flat view
function renderStateCitiesFlatWithWeather(container, citiesData) {
    container.setAttribute('role', 'list');
    
    citiesData.forEach((cityData) => {
        const card = document.createElement('article');
        card.className = 'city-card state-city-card';
        card.setAttribute('role', 'listitem');
        card.setAttribute('aria-label', `Weather for ${cityData.display}`);
        
        const header = document.createElement('div');
        header.className = 'city-card-header';
        
        const title = document.createElement('h4');
        title.textContent = cityData.display;
        header.appendChild(title);
        card.appendChild(header);
        
        const content = document.createElement('div');
        content.className = 'city-card-content';
        
        if (cityData.weather && cityData.weather.current) {
            const current = cityData.weather.current;
            const weatherDesc = WEATHER_CODES[current.weather_code] || 'Unknown';
            
            const summary = document.createElement('div');
            summary.className = 'weather-summary';
            
            if (currentConfig.cityList.temperature) {
                const temp = convertTemperature(current.temperature_2m);
                const tempSpan = document.createElement('span');
                tempSpan.className = 'temperature';
                tempSpan.textContent = `${temp}°${currentConfig.units.temperature}`;
                summary.appendChild(tempSpan);
            }
            
            if (currentConfig.cityList.conditions) {
                const descSpan = document.createElement('span');
                descSpan.className = 'weather-desc';
                descSpan.textContent = weatherDesc;
                summary.appendChild(descSpan);
            }
            
            content.appendChild(summary);
            
            const details = document.createElement('dl');
            details.className = 'weather-details';
            
            if (currentConfig.cityList.feels_like) {
                addDetail(details, 'Feels Like', `${convertTemperature(current.apparent_temperature)}°${currentConfig.units.temperature}`);
            }
            
            if (currentConfig.cityList.humidity) {
                addDetail(details, 'Humidity', `${current.relative_humidity_2m}%`);
            }
            
            if (currentConfig.cityList.wind_speed) {
                const windSpeed = convertWindSpeed(current.wind_speed_10m);
                addDetail(details, 'Wind Speed', `${windSpeed} ${currentConfig.units.wind_speed}`);
            }
            
            if (currentConfig.cityList.wind_direction) {
                const cardinal = degreesToCardinal(current.wind_direction_10m);
                addDetail(details, 'Wind Direction', `${cardinal} (${current.wind_direction_10m}°)`);
            }
            
            content.appendChild(details);
            
            if (cityData.weather.daily && (currentConfig.cityList.high_temp || currentConfig.cityList.low_temp)) {
                const forecast = document.createElement('div');
                forecast.className = 'daily-forecast';
                
                const forecastTitle = document.createElement('h5');
                forecastTitle.textContent = 'Today';
                forecast.appendChild(forecastTitle);
                
                const forecastDetails = document.createElement('dl');
                
                if (currentConfig.cityList.high_temp) {
                    addDetail(forecastDetails, 'High', `${convertTemperature(cityData.weather.daily.temperature_2m_max[0])}°${currentConfig.units.temperature}`);
                }
                
                if (currentConfig.cityList.low_temp) {
                    addDetail(forecastDetails, 'Low', `${convertTemperature(cityData.weather.daily.temperature_2m_min[0])}°${currentConfig.units.temperature}`);
                }
                
                forecast.appendChild(forecastDetails);
                content.appendChild(forecast);
            }
        } else {
            content.innerHTML = '<p class="loading-text">No weather data available</p>';
        }
        
        card.appendChild(content);
        
        const controls = document.createElement('div');
        controls.className = 'city-card-controls';
        
        // Check if city is already in user's list
        const isInList = cities[cityData.display];
        
        if (isInList) {
            const removeBtn = createButton('✖ Remove from List', `Remove ${cityData.display} from your cities list`, async () => {
                await removeCityFromState(cityData);
            });
            removeBtn.className = 'remove-btn';
            controls.appendChild(removeBtn);
        } else {
            const addBtn = createButton('➕ Add to My Cities', `Add ${cityData.display} to your cities list`, async () => {
                await addCityFromState(cityData);
            });
            addBtn.className = 'add-city-btn';
            controls.appendChild(addBtn);
        }
        
        card.appendChild(controls);
        container.appendChild(card);
    });
}

// Render state cities with weather in table view
function renderStateCitiesTableWithWeather(container, citiesData) {
    container.setAttribute('role', 'region');
    
    const table = document.createElement('table');
    table.className = 'weather-table';
    
    const thead = document.createElement('thead');
    const headerRow = document.createElement('tr');
    
    const cityHeader = document.createElement('th');
    cityHeader.textContent = 'City';
    cityHeader.scope = 'col';
    headerRow.appendChild(cityHeader);
    
    const columnConfig = [
        { key: 'temperature', label: 'Temperature' },
        { key: 'conditions', label: 'Conditions' },
        { key: 'feels_like', label: 'Feels Like' },
        { key: 'humidity', label: 'Humidity' },
        { key: 'wind_speed', label: 'Wind Speed' },
        { key: 'wind_direction', label: 'Wind Direction' },
        { key: 'high_temp', label: 'High' },
        { key: 'low_temp', label: 'Low' }
    ];
    
    columnConfig.forEach(col => {
        if (currentConfig.cityList[col.key]) {
            const th = document.createElement('th');
            th.textContent = col.label;
            th.scope = 'col';
            headerRow.appendChild(th);
        }
    });
    
    const actionsHeader = document.createElement('th');
    actionsHeader.textContent = 'Actions';
    actionsHeader.scope = 'col';
    headerRow.appendChild(actionsHeader);
    
    thead.appendChild(headerRow);
    table.appendChild(thead);
    
    const tbody = document.createElement('tbody');
    
    citiesData.forEach((cityData) => {
        const row = document.createElement('tr');
        
        const cityCell = document.createElement('th');
        cityCell.scope = 'row';
        cityCell.textContent = cityData.display;
        row.appendChild(cityCell);
        
        if (cityData.weather && cityData.weather.current) {
            const current = cityData.weather.current;
            
            if (currentConfig.cityList.temperature) {
                const tempCell = document.createElement('td');
                tempCell.textContent = `${convertTemperature(current.temperature_2m)}°${currentConfig.units.temperature}`;
                row.appendChild(tempCell);
            }
            
            if (currentConfig.cityList.conditions) {
                const condCell = document.createElement('td');
                condCell.textContent = WEATHER_CODES[current.weather_code] || 'Unknown';
                row.appendChild(condCell);
            }
            
            if (currentConfig.cityList.feels_like) {
                const feelsCell = document.createElement('td');
                feelsCell.textContent = `${convertTemperature(current.apparent_temperature)}°${currentConfig.units.temperature}`;
                row.appendChild(feelsCell);
            }
            
            if (currentConfig.cityList.humidity) {
                const humidityCell = document.createElement('td');
                humidityCell.textContent = `${current.relative_humidity_2m}%`;
                row.appendChild(humidityCell);
            }
            
            if (currentConfig.cityList.wind_speed) {
                const windSpeedCell = document.createElement('td');
                const windSpeed = convertWindSpeed(current.wind_speed_10m);
                windSpeedCell.textContent = `${windSpeed} ${currentConfig.units.wind_speed}`;
                row.appendChild(windSpeedCell);
            }
            
            if (currentConfig.cityList.wind_direction) {
                const windDirCell = document.createElement('td');
                const windDir = degreesToCardinal(current.wind_direction_10m);
                windDirCell.textContent = `${windDir} (${current.wind_direction_10m}°)`;
                row.appendChild(windDirCell);
            }
            
            if (currentConfig.cityList.high_temp && cityData.weather.daily) {
                const highCell = document.createElement('td');
                highCell.textContent = `${convertTemperature(cityData.weather.daily.temperature_2m_max[0])}°${currentConfig.units.temperature}`;
                row.appendChild(highCell);
            }
            
            if (currentConfig.cityList.low_temp && cityData.weather.daily) {
                const lowCell = document.createElement('td');
                lowCell.textContent = `${convertTemperature(cityData.weather.daily.temperature_2m_min[0])}°${currentConfig.units.temperature}`;
                row.appendChild(lowCell);
            }
        } else {
            const enabledColumns = columnConfig.filter(col => currentConfig.cityList[col.key]).length;
            for (let i = 0; i < enabledColumns; i++) {
                const loadingCell = document.createElement('td');
                loadingCell.textContent = 'N/A';
                row.appendChild(loadingCell);
            }
        }
        
        const actionsCell = document.createElement('td');
        
        const isInList = cities[cityData.display];
        
        if (isInList) {
            const removeBtn = createButton('✖ Remove', `Remove ${cityData.display} from your cities list`, async () => {
                await removeCityFromState(cityData);
            });
            removeBtn.className = 'remove-btn-small';
            actionsCell.appendChild(removeBtn);
        } else {
            const addBtn = createButton('➕ Add', `Add ${cityData.display} to your cities list`, async () => {
                await addCityFromState(cityData);
            });
            addBtn.className = 'add-city-btn-small';
            actionsCell.appendChild(addBtn);
        }
        
        row.appendChild(actionsCell);
        
        tbody.appendChild(row);
    });
    
    table.appendChild(tbody);
    container.appendChild(table);
}

// Render state cities with weather in list view
function renderStateCitiesListWithWeather(container, citiesData) {
    container.setAttribute('role', 'listbox');
    container.setAttribute('tabindex', '0');
    container.setAttribute('aria-label', 'State cities with weather - use arrow keys to navigate');
    
    citiesData.forEach((cityData, index) => {
        const item = document.createElement('div');
        item.className = 'list-view-item state-city-item';
        item.setAttribute('role', 'option');
        item.id = `state-city-item-${index}`;
        item.setAttribute('aria-selected', index === 0 ? 'true' : 'false');
        
        let weatherText = cityData.display;
        if (cityData.weather && cityData.weather.current) {
            const current = cityData.weather.current;
            const parts = [];
            
            if (currentConfig.cityList.temperature) {
                const temp = convertTemperature(current.temperature_2m);
                parts.push(`${temp}°${currentConfig.units.temperature}`);
            }
            
            if (currentConfig.cityList.conditions) {
                const weatherDesc = WEATHER_CODES[current.weather_code] || 'Unknown';
                parts.push(weatherDesc);
            }
            
            if (currentConfig.cityList.feels_like) {
                const feels = convertTemperature(current.apparent_temperature);
                parts.push(`Feels: ${feels}°${currentConfig.units.temperature}`);
            }
            
            if (currentConfig.cityList.humidity) {
                parts.push(`Humidity: ${current.relative_humidity_2m}%`);
            }
            
            weatherText = `${cityData.display} - ${parts.join(', ')}`;
        }
        
        const textSpan = document.createElement('span');
        textSpan.textContent = weatherText;
        item.appendChild(textSpan);
        
        const isInList = cities[cityData.display];
        
        if (isInList) {
            const removeBtn = createButton('✖ Remove', `Remove ${cityData.display} from your cities list`, async (e) => {
                e.stopPropagation();
                await removeCityFromState(cityData);
            });
            removeBtn.className = 'remove-btn-small inline';
            item.appendChild(removeBtn);
        } else {
            const addBtn = createButton('➕ Add', `Add ${cityData.display} to your cities list`, async (e) => {
                e.stopPropagation();
                await addCityFromState(cityData);
            });
            addBtn.className = 'add-city-btn-small inline';
            item.appendChild(addBtn);
        }
        
        container.appendChild(item);
    });
    
    container.setAttribute('aria-activedescendant', 'state-city-item-0');
}

// Fetch weather data
async function fetchWeatherForCity(cityName, lat, lon, detailed = false) {
    try {
        const params = new URLSearchParams({
            latitude: lat,
            longitude: lon,
            current: 'temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,rain,showers,snowfall,weather_code,cloud_cover,pressure_msl,wind_speed_10m,wind_direction_10m,visibility',
            timezone: 'auto'
        });
        
        if (detailed) {
            params.append('hourly', 'temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,weathercode,cloudcover,windspeed_10m');
            params.append('daily', 'weathercode,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_sum,windspeed_10m_max');
            params.append('forecast_days', '16');
        } else {
            params.append('hourly', 'cloudcover');
            params.append('daily', 'temperature_2m_max,temperature_2m_min');
            params.append('forecast_days', '1');
        }
        
        const response = await fetch(`${OPEN_METEO_API_URL}?${params}`);
        if (!response.ok) throw new Error('Failed to fetch weather data');
        
        const data = await response.json();
        weatherData[cityName] = data;
        
        renderCityList();
        announceToScreenReader(`Weather data updated for ${cityName}`);
        
        return data;
    } catch (error) {
        console.error(`Error fetching weather for ${cityName}:`, error);
        announceToScreenReader(`Failed to fetch weather for ${cityName}`);
        throw error;
    }
}

// Render city list
function renderCityList() {
    const container = document.getElementById('city-list');
    const emptyState = document.getElementById('empty-state');
    
    if (Object.keys(cities).length === 0) {
        container.innerHTML = '';
        emptyState.hidden = false;
        // Clean up list view controls if they exist
        const existingControls = document.querySelector('.list-view-controls');
        if (existingControls) {
            existingControls.remove();
        }
        return;
    }
    
    emptyState.hidden = true;
    container.innerHTML = '';
    
    // Remove any existing list navigation handler
    if (listNavigationHandler) {
        container.removeEventListener('keydown', listNavigationHandler);
        listNavigationHandler = null;
    }
    
    // Clean up list view controls if they exist
    const existingControls = document.querySelector('.list-view-controls');
    if (existingControls) {
        existingControls.remove();
    }
    
    // Render based on current view
    if (currentView === 'table') {
        renderTableView(container);
    } else if (currentView === 'list') {
        renderListView(container);
    } else {
        renderFlatView(container);
    }
}

// View menu functions
function toggleViewMenu() {
    const viewMenu = document.getElementById('view-menu');
    const viewMenuBtn = document.getElementById('view-menu-btn');
    const isExpanded = viewMenuBtn.getAttribute('aria-expanded') === 'true';
    
    if (isExpanded) {
        closeViewMenu();
    } else {
        openViewMenu();
    }
}

function openViewMenu() {
    const viewMenu = document.getElementById('view-menu');
    const viewMenuBtn = document.getElementById('view-menu-btn');
    
    viewMenu.hidden = false;
    viewMenuBtn.setAttribute('aria-expanded', 'true');
    
    // Focus first menu item
    const firstItem = viewMenu.querySelector('[role="menuitem"]');
    if (firstItem) {
        firstItem.focus();
    }
}

function closeViewMenu() {
    const viewMenu = document.getElementById('view-menu');
    const viewMenuBtn = document.getElementById('view-menu-btn');
    
    viewMenu.hidden = true;
    viewMenuBtn.setAttribute('aria-expanded', 'false');
}

function handleViewMenuKeydown(e) {
    const items = Array.from(e.currentTarget.querySelectorAll('[role="menuitem"]'));
    const currentIndex = items.indexOf(document.activeElement);
    
    let handled = false;
    
    switch(e.key) {
        case 'ArrowDown':
            e.preventDefault();
            const nextIndex = currentIndex < items.length - 1 ? currentIndex + 1 : 0;
            items[nextIndex].focus();
            handled = true;
            break;
            
        case 'ArrowUp':
            e.preventDefault();
            const prevIndex = currentIndex > 0 ? currentIndex - 1 : items.length - 1;
            items[prevIndex].focus();
            handled = true;
            break;
            
        case 'Home':
            e.preventDefault();
            items[0].focus();
            handled = true;
            break;
            
        case 'End':
            e.preventDefault();
            items[items.length - 1].focus();
            handled = true;
            break;
    }
}

// View switcher
function switchView(view) {
    currentView = view;
    
    // Update menu item states
    document.querySelectorAll('#view-menu [role="menuitem"]').forEach(item => {
        const isSelected = item.dataset.view === view;
        item.setAttribute('aria-checked', isSelected ? 'true' : 'false');
    });
    
    // Update button label
    const viewLabel = view.charAt(0).toUpperCase() + view.slice(1);
    document.getElementById('current-view-label').textContent = `View: ${viewLabel}`;
    
    // Re-render with new view - check if viewing state cities or user cities
    if (currentStateCities && currentStateName) {
        // Re-render state cities with new view
        const container = document.getElementById('city-list');
        renderStateCitiesWithWeather(container, currentStateCities);
    } else {
        // Re-render user cities with new view
        renderCityList();
    }
    announceToScreenReader(`Switched to ${view} view`);
}

// Flat view (original card-based layout)
function renderFlatView(container) {
    container.setAttribute('role', 'list');
    container.removeAttribute('tabindex');
    container.removeAttribute('aria-activedescendant');
    
    Object.keys(cities).forEach((cityName, index) => {
        const [lat, lon] = cities[cityName];
        const weather = weatherData[cityName];
        
        const cityCard = createCityCard(cityName, lat, lon, weather, index);
        container.appendChild(cityCard);
    });
}

// Create city card
function createCityCard(cityName, lat, lon, weather, index) {
    const card = document.createElement('article');
    card.className = 'city-card';
    card.setAttribute('role', 'listitem');
    card.setAttribute('aria-label', `Weather for ${cityName}`);
    
    const header = document.createElement('div');
    header.className = 'city-card-header';
    
    const titleButton = document.createElement('button');
    titleButton.className = 'city-title-btn';
    titleButton.setAttribute('aria-label', cityName);
    titleButton.addEventListener('click', () => showFullWeather(cityName, lat, lon));
    
    const title = document.createElement('h3');
    title.textContent = cityName;
    titleButton.appendChild(title);
    
    header.appendChild(titleButton);
    card.appendChild(header);
    
    // Weather content
    const content = document.createElement('div');
    content.className = 'city-card-content';
    
    if (weather) {
        const current = weather.current;
        const weatherDesc = WEATHER_CODES[current.weather_code] || 'Unknown';
        
        const summary = document.createElement('div');
        summary.className = 'weather-summary';
        summary.setAttribute('role', 'status');
        summary.setAttribute('aria-live', 'polite');
        
        // Temperature
        if (currentConfig.cityList.temperature) {
            const temp = convertTemperature(current.temperature_2m);
            const tempSpan = document.createElement('span');
            tempSpan.className = 'temperature';
            tempSpan.textContent = `${temp}°${currentConfig.units.temperature}`;
            tempSpan.setAttribute('aria-label', `Temperature: ${temp} degrees ${currentConfig.units.temperature === 'F' ? 'Fahrenheit' : 'Celsius'}`);
            summary.appendChild(tempSpan);
        }
        
        // Weather description
        if (currentConfig.cityList.conditions) {
            const descSpan = document.createElement('span');
            descSpan.className = 'weather-desc';
            descSpan.textContent = weatherDesc;
            summary.appendChild(descSpan);
        }
        
        content.appendChild(summary);
        
        // Additional details
        const details = document.createElement('dl');
        details.className = 'weather-details';
        
        if (currentConfig.cityList.feels_like) {
            addDetail(details, 'Feels Like', `${convertTemperature(current.apparent_temperature)}°${currentConfig.units.temperature}`);
        }
        
        if (currentConfig.cityList.humidity) {
            addDetail(details, 'Humidity', `${current.relative_humidity_2m}%`);
        }
        
        if (currentConfig.cityList.wind_speed) {
            const windSpeed = convertWindSpeed(current.wind_speed_10m);
            addDetail(details, 'Wind Speed', `${windSpeed} ${currentConfig.units.wind_speed}`);
        }
        
        if (currentConfig.cityList.wind_direction) {
            const cardinal = degreesToCardinal(current.wind_direction_10m);
            addDetail(details, 'Wind Direction', `${cardinal} (${current.wind_direction_10m}°)`);
        }
        
        content.appendChild(details);
        
        // High/Low temps if available
        if (weather.daily && (currentConfig.cityList.high_temp || currentConfig.cityList.low_temp)) {
            const forecast = document.createElement('div');
            forecast.className = 'daily-forecast';
            
            const forecastTitle = document.createElement('h4');
            forecastTitle.textContent = 'Today';
            forecast.appendChild(forecastTitle);
            
            const forecastDetails = document.createElement('dl');
            
            if (currentConfig.cityList.high_temp) {
                addDetail(forecastDetails, 'High', `${convertTemperature(weather.daily.temperature_2m_max[0])}°${currentConfig.units.temperature}`);
            }
            
            if (currentConfig.cityList.low_temp) {
                addDetail(forecastDetails, 'Low', `${convertTemperature(weather.daily.temperature_2m_min[0])}°${currentConfig.units.temperature}`);
            }
            
            forecast.appendChild(forecastDetails);
            content.appendChild(forecast);
        }
    } else {
        content.innerHTML = '<p class="loading-text">Loading weather data...</p>';
    }
    
    card.appendChild(content);
    
    // Controls at the bottom for better screen reader experience
    const controls = document.createElement('div');
    controls.className = 'city-card-controls';
    
    // Move up button
    if (index > 0) {
        const upBtn = createButton('↑', `Move ${cityName} up in list`, () => moveCityUp(cityName));
        upBtn.className = 'icon-btn';
        controls.appendChild(upBtn);
    }
    
    // Move down button
    if (index < Object.keys(cities).length - 1) {
        const downBtn = createButton('↓', `Move ${cityName} down in list`, () => moveCityDown(cityName));
        downBtn.className = 'icon-btn';
        controls.appendChild(downBtn);
    }
    
    // Remove button
    const removeBtn = createButton('🗑️', `Remove ${cityName} from list`, () => removeCity(cityName));
    removeBtn.className = 'icon-btn remove-btn';
    controls.appendChild(removeBtn);
    
    card.appendChild(controls);
    
    return card;
}

function addDetail(dl, label, value) {
    const dt = document.createElement('dt');
    dt.textContent = label + ':';
    const dd = document.createElement('dd');
    dd.textContent = value;
    dl.appendChild(dt);
    dl.appendChild(dd);
}

function createButton(text, ariaLabel, onClick) {
    const btn = document.createElement('button');
    btn.innerHTML = text;
    btn.setAttribute('aria-label', ariaLabel);
    btn.addEventListener('click', onClick);
    return btn;
}

// Table view
function renderTableView(container) {
    container.setAttribute('role', 'region');
    container.removeAttribute('tabindex');
    container.removeAttribute('aria-activedescendant');
    
    const table = document.createElement('table');
    table.className = 'weather-table';
    
    // Table header - dynamically build based on config
    const thead = document.createElement('thead');
    const headerRow = document.createElement('tr');
    
    // City column always present
    const cityHeader = document.createElement('th');
    cityHeader.textContent = 'City';
    cityHeader.scope = 'col';
    headerRow.appendChild(cityHeader);
    
    // Add headers based on config
    const columnConfig = [
        { key: 'temperature', label: 'Temperature' },
        { key: 'conditions', label: 'Conditions' },
        { key: 'feels_like', label: 'Feels Like' },
        { key: 'humidity', label: 'Humidity' },
        { key: 'wind_speed', label: 'Wind Speed' },
        { key: 'wind_direction', label: 'Wind Direction' },
        { key: 'high_temp', label: 'High' },
        { key: 'low_temp', label: 'Low' }
    ];
    
    columnConfig.forEach(col => {
        if (currentConfig.cityList[col.key]) {
            const th = document.createElement('th');
            th.textContent = col.label;
            th.scope = 'col';
            headerRow.appendChild(th);
        }
    });
    
    const actionsHeader = document.createElement('th');
    actionsHeader.textContent = 'Actions';
    actionsHeader.scope = 'col';
    headerRow.appendChild(actionsHeader);
    
    thead.appendChild(headerRow);
    table.appendChild(thead);
    
    // Table body
    const tbody = document.createElement('tbody');
    
    Object.keys(cities).forEach((cityName, index) => {
        const [lat, lon] = cities[cityName];
        const weather = weatherData[cityName];
        
        const row = document.createElement('tr');
        
        // City name (row header)
        const cityCell = document.createElement('th');
        cityCell.scope = 'row';
        
        // Make city name a clickable link
        const cityLink = document.createElement('a');
        cityLink.href = '#';
        cityLink.textContent = cityName;
        cityLink.className = 'city-link';
        cityLink.setAttribute('aria-label', cityName);
        cityLink.addEventListener('click', (e) => {
            e.preventDefault();
            showFullWeather(cityName, lat, lon);
        });
        
        cityCell.appendChild(cityLink);
        row.appendChild(cityCell);
        
        if (weather && weather.current) {
            const current = weather.current;
            
            // Add cells based on config
            if (currentConfig.cityList.temperature) {
                const tempCell = document.createElement('td');
                tempCell.textContent = `${convertTemperature(current.temperature_2m)}°${currentConfig.units.temperature}`;
                row.appendChild(tempCell);
            }
            
            if (currentConfig.cityList.conditions) {
                const condCell = document.createElement('td');
                condCell.textContent = WEATHER_CODES[current.weather_code] || 'Unknown';
                row.appendChild(condCell);
            }
            
            if (currentConfig.cityList.feels_like) {
                const feelsCell = document.createElement('td');
                feelsCell.textContent = `${convertTemperature(current.apparent_temperature)}°${currentConfig.units.temperature}`;
                row.appendChild(feelsCell);
            }
            
            if (currentConfig.cityList.humidity) {
                const humidityCell = document.createElement('td');
                humidityCell.textContent = `${current.relative_humidity_2m}%`;
                row.appendChild(humidityCell);
            }
            
            if (currentConfig.cityList.wind_speed) {
                const windSpeedCell = document.createElement('td');
                const windSpeed = convertWindSpeed(current.wind_speed_10m);
                windSpeedCell.textContent = `${windSpeed} ${currentConfig.units.wind_speed}`;
                row.appendChild(windSpeedCell);
            }
            
            if (currentConfig.cityList.wind_direction) {
                const windDirCell = document.createElement('td');
                const windDir = degreesToCardinal(current.wind_direction_10m);
                windDirCell.textContent = `${windDir} (${current.wind_direction_10m}°)`;
                row.appendChild(windDirCell);
            }
            
            if (currentConfig.cityList.high_temp && weather.daily) {
                const highCell = document.createElement('td');
                highCell.textContent = `${convertTemperature(weather.daily.temperature_2m_max[0])}°${currentConfig.units.temperature}`;
                row.appendChild(highCell);
            }
            
            if (currentConfig.cityList.low_temp && weather.daily) {
                const lowCell = document.createElement('td');
                lowCell.textContent = `${convertTemperature(weather.daily.temperature_2m_min[0])}°${currentConfig.units.temperature}`;
                row.appendChild(lowCell);
            }
        } else {
            // Loading cells - count enabled columns
            const enabledColumns = columnConfig.filter(col => currentConfig.cityList[col.key]).length;
            for (let i = 0; i < enabledColumns; i++) {
                const loadingCell = document.createElement('td');
                loadingCell.textContent = 'Loading...';
                row.appendChild(loadingCell);
            }
        }
        
        // Actions cell
        const actionsCell = document.createElement('td');
        const actionsDiv = document.createElement('div');
        actionsDiv.className = 'table-actions';
        
        if (index > 0) {
            const upBtn = createButton('↑', `Move ${cityName} up`, () => moveCityUp(cityName));
            upBtn.className = 'icon-btn-small';
            actionsDiv.appendChild(upBtn);
        }
        
        if (index < Object.keys(cities).length - 1) {
            const downBtn = createButton('↓', `Move ${cityName} down`, () => moveCityDown(cityName));
            downBtn.className = 'icon-btn-small';
            actionsDiv.appendChild(downBtn);
        }
        
        const removeBtn = createButton('🗑️', `Remove ${cityName}`, () => removeCity(cityName));
        removeBtn.className = 'icon-btn-small remove-btn';
        actionsDiv.appendChild(removeBtn);
        
        actionsCell.appendChild(actionsDiv);
        row.appendChild(actionsCell);
        
        tbody.appendChild(row);
    });
    
    table.appendChild(tbody);
    container.appendChild(table);
}

// List view (compact, keyboard navigable)
function renderListView(container) {
    container.setAttribute('role', 'listbox');
    container.setAttribute('tabindex', '0');
    container.setAttribute('aria-label', 'Cities list - use arrow keys to navigate, Enter to view details');
    
    let activeIndex = 0;
    const cityNames = Object.keys(cities);
    
    // Create list items
    cityNames.forEach((cityName, index) => {
        const [lat, lon] = cities[cityName];
        const weather = weatherData[cityName];
        
        const item = document.createElement('div');
        item.className = 'list-view-item';
        item.setAttribute('role', 'option');
        item.id = `list-item-${index}`;
        item.setAttribute('aria-selected', index === 0 ? 'true' : 'false');
        
        // City name and weather summary in one line
        let weatherText = cityName;
        if (weather && weather.current) {
            const current = weather.current;
            const parts = [];
            
            if (currentConfig.cityList.temperature) {
                const temp = convertTemperature(current.temperature_2m);
                parts.push(`${temp}°${currentConfig.units.temperature}`);
            }
            
            if (currentConfig.cityList.conditions) {
                const weatherDesc = WEATHER_CODES[current.weather_code] || 'Unknown';
                parts.push(weatherDesc);
            }
            
            if (currentConfig.cityList.feels_like) {
                const feels = convertTemperature(current.apparent_temperature);
                parts.push(`Feels: ${feels}°${currentConfig.units.temperature}`);
            }
            
            if (currentConfig.cityList.humidity) {
                parts.push(`Humidity: ${current.relative_humidity_2m}%`);
            }
            
            if (currentConfig.cityList.wind_speed || currentConfig.cityList.wind_direction) {
                let windPart = 'Wind: ';
                if (currentConfig.cityList.wind_direction) {
                    const windDir = degreesToCardinal(current.wind_direction_10m);
                    windPart += `${windDir} `;
                }
                if (currentConfig.cityList.wind_speed) {
                    const windSpeed = convertWindSpeed(current.wind_speed_10m);
                    windPart += `${windSpeed} ${currentConfig.units.wind_speed}`;
                }
                parts.push(windPart.trim());
            }
            
            if (weather.daily) {
                if (currentConfig.cityList.high_temp) {
                    const high = convertTemperature(weather.daily.temperature_2m_max[0]);
                    parts.push(`High: ${high}°${currentConfig.units.temperature}`);
                }
                if (currentConfig.cityList.low_temp) {
                    const low = convertTemperature(weather.daily.temperature_2m_min[0]);
                    parts.push(`Low: ${low}°${currentConfig.units.temperature}`);
                }
            }
            
            weatherText = `${cityName} - ${parts.join(', ')}`;
        } else {
            weatherText = `${cityName} - Loading...`;
        }
        
        item.textContent = weatherText;
        item.dataset.cityName = cityName;
        item.dataset.lat = lat;
        item.dataset.lon = lon;
        item.dataset.index = index;
        
        container.appendChild(item);
    });
    
    // Set initial active descendant
    container.setAttribute('aria-activedescendant', 'list-item-0');
    
    // Keyboard navigation handler
    listNavigationHandler = (e) => {
        const items = container.querySelectorAll('.list-view-item');
        const currentActive = container.getAttribute('aria-activedescendant');
        activeIndex = parseInt(currentActive.split('-')[2]);
        
        let handled = false;
        
        switch(e.key) {
            case 'ArrowDown':
                e.preventDefault();
                if (activeIndex < items.length - 1) {
                    activeIndex++;
                    setActiveListItem(container, items, activeIndex);
                }
                handled = true;
                break;
                
            case 'ArrowUp':
                e.preventDefault();
                if (activeIndex > 0) {
                    activeIndex--;
                    setActiveListItem(container, items, activeIndex);
                }
                handled = true;
                break;
                
            case 'Home':
                e.preventDefault();
                activeIndex = 0;
                setActiveListItem(container, items, activeIndex);
                handled = true;
                break;
                
            case 'End':
                e.preventDefault();
                activeIndex = items.length - 1;
                setActiveListItem(container, items, activeIndex);
                handled = true;
                break;
                
            case 'Enter':
            case ' ':
                e.preventDefault();
                const activeItem = items[activeIndex];
                const cityName = activeItem.dataset.cityName;
                const lat = parseFloat(activeItem.dataset.lat);
                const lon = parseFloat(activeItem.dataset.lon);
                showFullWeather(cityName, lat, lon);
                handled = true;
                break;
        }
        
        if (handled) {
            const item = items[activeIndex];
            announceToScreenReader(item.textContent);
        }
    };
    
    container.addEventListener('keydown', listNavigationHandler);
    
    // Add control buttons for list view (single set that acts on focused city)
    const controlsDiv = document.createElement('div');
    controlsDiv.className = 'list-view-controls';
    
    const upBtn = createButton('↑ Move Up', 'Move selected city up in list', () => {
        const items = container.querySelectorAll('.list-view-item');
        const currentActive = container.getAttribute('aria-activedescendant');
        const activeIndex = parseInt(currentActive.split('-')[2]);
        const cityName = items[activeIndex].dataset.cityName;
        moveCityUp(cityName);
    });
    upBtn.className = 'list-control-btn';
    
    const downBtn = createButton('↓ Move Down', 'Move selected city down in list', () => {
        const items = container.querySelectorAll('.list-view-item');
        const currentActive = container.getAttribute('aria-activedescendant');
        const activeIndex = parseInt(currentActive.split('-')[2]);
        const cityName = items[activeIndex].dataset.cityName;
        moveCityDown(cityName);
    });
    downBtn.className = 'list-control-btn';
    
    const removeBtn = createButton('🗑️ Remove', 'Remove selected city from list', () => {
        const items = container.querySelectorAll('.list-view-item');
        const currentActive = container.getAttribute('aria-activedescendant');
        const activeIndex = parseInt(currentActive.split('-')[2]);
        const cityName = items[activeIndex].dataset.cityName;
        removeCity(cityName);
    });
    removeBtn.className = 'list-control-btn remove-btn';
    
    const detailsBtn = createButton('📋 Full Details', 'View full weather details for selected city', () => {
        const items = container.querySelectorAll('.list-view-item');
        const currentActive = container.getAttribute('aria-activedescendant');
        const activeIndex = parseInt(currentActive.split('-')[2]);
        const cityName = items[activeIndex].dataset.cityName;
        const lat = parseFloat(items[activeIndex].dataset.lat);
        const lon = parseFloat(items[activeIndex].dataset.lon);
        showFullWeather(cityName, lat, lon);
    });
    detailsBtn.className = 'list-control-btn';
    
    controlsDiv.appendChild(detailsBtn);
    controlsDiv.appendChild(upBtn);
    controlsDiv.appendChild(downBtn);
    controlsDiv.appendChild(removeBtn);
    
    container.parentElement.insertBefore(controlsDiv, container.nextSibling);
}

function setActiveListItem(container, items, index) {
    // Update aria-selected
    items.forEach((item, i) => {
        item.setAttribute('aria-selected', i === index ? 'true' : 'false');
    });
    
    // Update aria-activedescendant
    container.setAttribute('aria-activedescendant', `list-item-${index}`);
    
    // Scroll into view
    items[index].scrollIntoView({ block: 'nearest', behavior: 'smooth' });
}

// City management
function moveCityUp(cityName) {
    const keys = Object.keys(cities);
    const index = keys.indexOf(cityName);
    if (index <= 0) return;
    
    const newCities = {};
    keys.forEach((key, i) => {
        if (i === index - 1) {
            newCities[cityName] = cities[cityName];
        } else if (i === index) {
            newCities[keys[index - 1]] = cities[keys[index - 1]];
        } else {
            newCities[key] = cities[key];
        }
    });
    
    cities = newCities;
    saveCitiesToStorage();
    renderCityList();
    announceToScreenReader(`Moved ${cityName} up in the list`);
}

function moveCityDown(cityName) {
    const keys = Object.keys(cities);
    const index = keys.indexOf(cityName);
    if (index < 0 || index >= keys.length - 1) return;
    
    const newCities = {};
    keys.forEach((key, i) => {
        if (i === index) {
            newCities[keys[index + 1]] = cities[keys[index + 1]];
        } else if (i === index + 1) {
            newCities[cityName] = cities[cityName];
        } else {
            newCities[key] = cities[key];
        }
    });
    
    cities = newCities;
    saveCitiesToStorage();
    renderCityList();
    announceToScreenReader(`Moved ${cityName} down in the list`);
}

async function refreshCity(cityName, lat, lon) {
    announceToScreenReader(`Refreshing weather for ${cityName}`);
    await fetchWeatherForCity(cityName, lat, lon);
}

async function refreshAllCities() {
    if (Object.keys(cities).length === 0) return;
    
    announceToScreenReader('Refreshing all cities');
    
    const promises = Object.entries(cities).map(([cityName, [lat, lon]]) => 
        fetchWeatherForCity(cityName, lat, lon)
    );
    
    try {
        await Promise.all(promises);
        announceToScreenReader('All cities refreshed');
    } catch (error) {
        announceToScreenReader('Some cities failed to refresh');
    }
}

function removeCity(cityName) {
    if (!confirm(`Remove ${cityName} from your cities?`)) return;
    
    delete cities[cityName];
    delete weatherData[cityName];
    saveCitiesToStorage();
    renderCityList();
    announceToScreenReader(`Removed ${cityName} from your cities`);
}

// Full weather details
async function showFullWeather(cityName, lat, lon) {
    const dialog = document.getElementById('weather-details-dialog');
    const title = document.getElementById('weather-details-title');
    const content = document.getElementById('weather-details-content');
    
    title.textContent = `Full Weather Details - ${cityName}`;
    content.innerHTML = '<p class="loading-text">Loading detailed forecast...</p>';
    
    focusReturnElement = document.activeElement;
    dialog.hidden = false;
    trapFocus(dialog);
    
    try {
        const weather = await fetchWeatherForCity(cityName, lat, lon, true);
        content.innerHTML = renderFullWeatherDetails(weather);
    } catch (error) {
        content.innerHTML = `<p class="error-message">Failed to load detailed forecast: ${error.message}</p>`;
    }
}

function renderFullWeatherDetails(weather) {
    let html = '<div class="full-weather-details">';
    
    // Current conditions (expanded)
    html += '<section><h4>Current Conditions</h4><dl>';
    const current = weather.current;
    
    html += `<dt>Temperature:</dt><dd>${convertTemperature(current.temperature_2m)}°${currentConfig.units.temperature}</dd>`;
    html += `<dt>Feels Like:</dt><dd>${convertTemperature(current.apparent_temperature)}°${currentConfig.units.temperature}</dd>`;
    html += `<dt>Weather:</dt><dd>${WEATHER_CODES[current.weather_code] || 'Unknown'}</dd>`;
    html += `<dt>Humidity:</dt><dd>${current.relative_humidity_2m}%</dd>`;
    const windCardinal = degreesToCardinal(current.wind_direction_10m);
    html += `<dt>Wind:</dt><dd>${convertWindSpeed(current.wind_speed_10m)} ${currentConfig.units.wind_speed} ${windCardinal} (${current.wind_direction_10m}°)</dd>`;
    html += `<dt>Pressure:</dt><dd>${convertPressure(current.pressure_msl)} ${currentConfig.units.pressure}</dd>`;
    html += `<dt>Cloud Cover:</dt><dd>${current.cloud_cover}%</dd>`;
    html += `<dt>Visibility:</dt><dd>${convertDistance(current.visibility)} ${currentConfig.units.distance}</dd>`;
    
    html += '</dl></section>';
    
    // Next 24 hours hourly forecast
    if (weather.hourly) {
        html += '<section><h4>Next 24 Hours</h4>';
        html += '<div class="hourly-forecast">';
        
        // Get current time and find the starting hour index
        const now = new Date();
        const currentHour = now.getHours();
        
        // Open-Meteo hourly data is in local timezone
        // Find the closest hour index that matches or is after current time
        let startIndex = 0;
        for (let i = 0; i < weather.hourly.time.length; i++) {
            const hourTime = new Date(weather.hourly.time[i]);
            if (hourTime >= now) {
                startIndex = i;
                break;
            }
        }
        
        // Display next 24 hours (or up to end of available data)
        const endIndex = Math.min(startIndex + 24, weather.hourly.time.length);
        
        for (let i = startIndex; i < endIndex; i++) {
            const hourTime = new Date(weather.hourly.time[i]);
            const timeStr = hourTime.toLocaleTimeString(undefined, { 
                hour: 'numeric', 
                hour12: true 
            });
            
            html += '<article class="hourly-item">';
            html += `<h5>${timeStr}</h5>`;
            html += `<p class="hourly-weather">${WEATHER_CODES[weather.hourly.weathercode[i]] || 'Unknown'}</p>`;
            html += `<p class="hourly-temp">${convertTemperature(weather.hourly.temperature_2m[i])}°${currentConfig.units.temperature}</p>`;
            
            if (currentConfig.hourly.feels_like) {
                html += `<p>Feels: ${convertTemperature(weather.hourly.apparent_temperature[i])}°${currentConfig.units.temperature}</p>`;
            }
            
            if (currentConfig.hourly.humidity) {
                html += `<p>Humidity: ${weather.hourly.relative_humidity_2m[i]}%</p>`;
            }
            
            if (currentConfig.hourly.precipitation) {
                html += `<p>Precip: ${convertPrecipitation(weather.hourly.precipitation[i])} ${currentConfig.units.precipitation}</p>`;
            }
            
            if (currentConfig.hourly.wind_speed) {
                html += `<p>Wind: ${convertWindSpeed(weather.hourly.windspeed_10m[i])} ${currentConfig.units.wind_speed}</p>`;
            }
            
            if (currentConfig.hourly.cloud_cover) {
                html += `<p>Clouds: ${weather.hourly.cloudcover[i]}%</p>`;
            }
            
            html += '</article>';
        }
        
        html += '</div></section>';
    }
    
    // 16-day forecast
    if (weather.daily) {
        html += '<section><h4>16-Day Forecast</h4>';
        html += '<div class="forecast-grid">';
        
        for (let i = 0; i < 16 && i < weather.daily.time.length; i++) {
            const date = new Date(weather.daily.time[i]);
            let dayLabel;
            if (i === 0) {
                dayLabel = 'Today';
            } else {
                // Use browser's locale for date formatting
                const weekday = date.toLocaleDateString(undefined, { weekday: 'short' });
                const monthDay = date.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
                dayLabel = `${weekday}, ${monthDay}`;
            }
            
            html += '<article class="forecast-day">';
            html += `<h5>${dayLabel}</h5>`;
            html += `<p class="forecast-weather">${WEATHER_CODES[weather.daily.weathercode[i]] || 'Unknown'}</p>`;
            html += `<p class="forecast-temp">High: ${convertTemperature(weather.daily.temperature_2m_max[i])}°${currentConfig.units.temperature}</p>`;
            html += `<p class="forecast-temp">Low: ${convertTemperature(weather.daily.temperature_2m_min[i])}°${currentConfig.units.temperature}</p>`;
            
            if (currentConfig.daily.precipitation_sum) {
                html += `<p>Precip: ${convertPrecipitation(weather.daily.precipitation_sum[i])} ${currentConfig.units.precipitation}</p>`;
            }
            
            if (currentConfig.daily.sunrise && weather.daily.sunrise) {
                const sunrise = new Date(weather.daily.sunrise[i]).toLocaleTimeString('en-US', { 
                    hour: 'numeric', minute: '2-digit', hour12: true 
                });
                html += `<p>☀️ ${sunrise}</p>`;
            }
            
            if (currentConfig.daily.sunset && weather.daily.sunset) {
                const sunset = new Date(weather.daily.sunset[i]).toLocaleTimeString('en-US', { 
                    hour: 'numeric', minute: '2-digit', hour12: true 
                });
                html += `<p>🌙 ${sunset}</p>`;
            }
            
            html += '</article>';
        }
        
        html += '</div></section>';
    }
    
    html += '</div>';
    return html;
}

function closeWeatherDetailsDialog() {
    const dialog = document.getElementById('weather-details-dialog');
    dialog.hidden = true;
    if (focusReturnElement) {
        focusReturnElement.focus();
        focusReturnElement = null;
    }
}

// Configuration dialog
function openConfigDialog() {
    const dialog = document.getElementById('config-dialog');
    
    // Load current config into form
    Object.keys(currentConfig.current).forEach(key => {
        const checkbox = document.querySelector(`input[name="current-${key}"]`);
        if (checkbox) checkbox.checked = currentConfig.current[key];
    });
    
    Object.keys(currentConfig.hourly).forEach(key => {
        const checkbox = document.querySelector(`input[name="hourly-${key}"]`);
        if (checkbox) checkbox.checked = currentConfig.hourly[key];
    });
    
    Object.keys(currentConfig.daily).forEach(key => {
        const checkbox = document.querySelector(`input[name="daily-${key}"]`);
        if (checkbox) checkbox.checked = currentConfig.daily[key];
    });
    
    Object.keys(currentConfig.cityList).forEach(key => {
        const checkbox = document.querySelector(`input[name="citylist-${key}"]`);
        if (checkbox) checkbox.checked = currentConfig.cityList[key];
    });
    
    document.querySelector(`input[name="temp-unit"][value="${currentConfig.units.temperature}"]`).checked = true;
    document.querySelector(`input[name="wind-unit"][value="${currentConfig.units.wind_speed}"]`).checked = true;
    document.querySelector(`input[name="precip-unit"][value="${currentConfig.units.precipitation}"]`).checked = true;
    document.querySelector(`input[name="pressure-unit"][value="${currentConfig.units.pressure}"]`).checked = true;
    document.querySelector(`input[name="distance-unit"][value="${currentConfig.units.distance}"]`).checked = true;
    
    focusReturnElement = document.activeElement;
    dialog.hidden = false;
    trapFocus(dialog);
    document.getElementById('current-tab').focus();
}

function applyConfiguration() {
    updateConfigFromForm();
    renderCityList();
    announceToScreenReader('Configuration applied');
}

function saveConfiguration() {
    updateConfigFromForm();
    saveConfigToStorage();
    renderCityList();
    closeConfigDialog();
    announceToScreenReader('Configuration saved');
}

function updateConfigFromForm() {
    // Current weather
    Object.keys(currentConfig.current).forEach(key => {
        const checkbox = document.querySelector(`input[name="current-${key}"]`);
        if (checkbox) currentConfig.current[key] = checkbox.checked;
    });
    
    // Hourly forecast
    Object.keys(currentConfig.hourly).forEach(key => {
        const checkbox = document.querySelector(`input[name="hourly-${key}"]`);
        if (checkbox) currentConfig.hourly[key] = checkbox.checked;
    });
    
    // Daily forecast
    Object.keys(currentConfig.daily).forEach(key => {
        const checkbox = document.querySelector(`input[name="daily-${key}"]`);
        if (checkbox) currentConfig.daily[key] = checkbox.checked;
    });
    
    // City list
    Object.keys(currentConfig.cityList).forEach(key => {
        const checkbox = document.querySelector(`input[name="citylist-${key}"]`);
        if (checkbox) currentConfig.cityList[key] = checkbox.checked;
    });
    
    // Units
    currentConfig.units.temperature = document.querySelector('input[name="temp-unit"]:checked').value;
    currentConfig.units.wind_speed = document.querySelector('input[name="wind-unit"]:checked').value;
    currentConfig.units.precipitation = document.querySelector('input[name="precip-unit"]:checked').value;
    currentConfig.units.pressure = document.querySelector('input[name="pressure-unit"]:checked').value;
    currentConfig.units.distance = document.querySelector('input[name="distance-unit"]:checked').value;
}

function closeConfigDialog() {
    const dialog = document.getElementById('config-dialog');
    dialog.hidden = true;
    if (focusReturnElement) {
        focusReturnElement.focus();
        focusReturnElement = null;
    }
}

// Unit conversion
function degreesToCardinal(degrees) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    const index = Math.round(degrees / 45) % 8;
    return directions[index];
}

function convertTemperature(celsius) {
    if (currentConfig.units.temperature === 'F') {
        return Math.round(celsius * 9/5 + 32);
    }
    return Math.round(celsius);
}

function convertWindSpeed(kmh) {
    if (currentConfig.units.wind_speed === 'mph') {
        return Math.round(kmh * KMH_TO_MPH);
    }
    return Math.round(kmh);
}

function convertPrecipitation(mm) {
    if (currentConfig.units.precipitation === 'in') {
        return (mm * MM_TO_INCHES).toFixed(2);
    }
    return mm.toFixed(1);
}

function convertPressure(hpa) {
    if (currentConfig.units.pressure === 'inHg') {
        return (hpa * HPA_TO_INHG).toFixed(2);
    }
    return hpa.toFixed(1);
}

function convertDistance(meters) {
    if (currentConfig.units.distance === 'mi') {
        return (meters * M_TO_MILES).toFixed(1);
    }
    return (meters * M_TO_KM).toFixed(1);
}

// Storage
function loadCitiesFromStorage() {
    const stored = localStorage.getItem('fastweather-cities');
    if (stored) {
        try {
            cities = JSON.parse(stored);
        } catch (e) {
            console.error('Failed to load cities:', e);
            cities = {};
        }
    } else {
        // Load default cities
        cities = {
            "Madison, Wisconsin, United States": [43.074761, -89.3837613],
            "San Diego, California, United States": [32.7174202, -117.162772]
        };
    }
    
    // Fetch weather for all cities
    Object.entries(cities).forEach(([cityName, [lat, lon]]) => {
        fetchWeatherForCity(cityName, lat, lon);
    });
}

function saveCitiesToStorage() {
    localStorage.setItem('fastweather-cities', JSON.stringify(cities));
}

function loadConfigFromStorage() {
    const stored = localStorage.getItem('fastweather-config');
    if (stored) {
        try {
            const loaded = JSON.parse(stored);
            currentConfig = loaded;
            // Ensure cityList exists for backward compatibility
            if (!currentConfig.cityList) {
                currentConfig.cityList = DEFAULT_CONFIG.cityList;
            }
            // Ensure pressure unit exists for backward compatibility
            if (!currentConfig.units.pressure) {
                currentConfig.units.pressure = DEFAULT_CONFIG.units.pressure;
            }
            // Ensure distance unit exists for backward compatibility
            if (!currentConfig.units.distance) {
                currentConfig.units.distance = DEFAULT_CONFIG.units.distance;
            }
        } catch (e) {
            console.error('Failed to load config:', e);
        }
    }
}

function saveConfigToStorage() {
    localStorage.setItem('fastweather-config', JSON.stringify(currentConfig));
}

// Utility functions
function showError(element, message) {
    element.textContent = message;
    element.classList.add('visible');
}

function clearError(element) {
    element.textContent = '';
    element.classList.remove('visible');
}

function announceToScreenReader(message) {
    const announcement = document.createElement('div');
    announcement.setAttribute('role', 'status');
    announcement.setAttribute('aria-live', 'polite');
    announcement.setAttribute('aria-atomic', 'true');
    announcement.className = 'visually-hidden';
    document.body.appendChild(announcement);
    
    // Add text after a brief delay to ensure screen readers detect the change
    setTimeout(() => {
        announcement.textContent = message;
    }, 100);
    
    // Remove after screen readers have had time to announce
    setTimeout(() => {
        if (announcement.parentNode) {
            document.body.removeChild(announcement);
        }
    }, 2000);
}

function closeAllModals() {
    document.querySelectorAll('.modal:not([hidden])').forEach(modal => {
        modal.hidden = true;
    });
    
    if (focusReturnElement) {
        focusReturnElement.focus();
        focusReturnElement = null;
    }
}

// Focus trap for modal dialogs
function trapFocus(element) {
    const focusableElements = element.querySelectorAll(
        'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    const firstFocusable = focusableElements[0];
    const lastFocusable = focusableElements[focusableElements.length - 1];
    
    element.addEventListener('keydown', function(e) {
        if (e.key !== 'Tab') return;
        
        if (e.shiftKey) {
            if (document.activeElement === firstFocusable) {
                lastFocusable.focus();
                e.preventDefault();
            }
        } else {
            if (document.activeElement === lastFocusable) {
                firstFocusable.focus();
                e.preventDefault();
            }
        }
    });
}
