#!/usr/bin/env python3
"""
Accessible GUI Weather Application using PyQt5
Fully accessible with screen readers, keyboard navigation, and proper focus management
Uses Open-Meteo API (no API key required)
"""

import sys
import json
import requests
import logging
from datetime import datetime
from typing import Dict, Tuple, Optional, List
import threading
import os

from PyQt5.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, 
    QLabel, QLineEdit, QPushButton, QListWidget, QTextEdit, 
    QMessageBox, QDialog, QDialogButtonBox, QStatusBar, QGroupBox,
    QListWidgetItem, QSplitter, QFrame, QStackedWidget, QCheckBox,
    QScrollArea, QGridLayout, QTabWidget
)
from PyQt5.QtCore import Qt, QThread, pyqtSignal, QTimer, QEvent
from PyQt5.QtGui import QFont, QKeySequence
from PyQt5.QtWidgets import QShortcut

# Constants (same as original)
KMH_TO_MPH = 0.621371
MM_TO_INCHES = 0.0393701
OPEN_METEO_API_URL = "https://api.open-meteo.com/v1/forecast"
NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"


class WeatherFetchThread(QThread):
    """Background thread for fetching weather data"""
    weather_ready = pyqtSignal(str, dict)  # city_name, weather_data
    error_occurred = pyqtSignal(str, str)   # city_name, error_message
    
    def __init__(self, city_name, lat, lon, detail="basic", forecast_days=7):
        super().__init__()
        self.city_name = city_name
        self.lat = lat
        self.lon = lon
        self.detail = detail
        self.forecast_days = forecast_days
    
    def run(self):
        try:
            params = {
                "latitude": self.lat,
                "longitude": self.lon,
                "current_weather": True,
                "timezone": "auto",
            }
            
            if self.detail == "full":
                params["hourly"] = "temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,windspeed_10m,winddirection_10m"
                params["daily"] = "temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_sum"
                params["forecast_days"] = self.forecast_days
            
            response = requests.get(OPEN_METEO_API_URL, params=params, timeout=10)
            response.raise_for_status()
            data = response.json()
            
            self.weather_ready.emit(self.city_name, data)
            
        except Exception as e:
            self.error_occurred.emit(self.city_name, str(e))


class GeocodingThread(QThread):
    """Background thread for geocoding cities"""
    results_ready = pyqtSignal(str, list)  # original_input, matches
    error_occurred = pyqtSignal(str)       # error_message
    
    def __init__(self, city_input):
        super().__init__()
        self.city_input = city_input
    
    def run(self):
        try:
            params = {
                "q": self.city_input,
                "format": "json",
                "addressdetails": 1,
                "limit": 5,
            }
            headers = {
                "User-Agent": "FastWeather GUI/1.0 (accessible weather app)"
            }
            
            response = requests.get(NOMINATIM_URL, params=params, headers=headers, timeout=10)
            response.raise_for_status()
            results = response.json()
            
            matches = []
            for r in results:
                address = r.get("address", {})
                city_name = address.get('city') or address.get('town') or address.get('village') or self.city_input
                state = address.get('state', '')
                country = address.get('country', '')
                
                # Build display name
                display_parts = [city_name]
                if state:
                    display_parts.append(state)
                if country:
                    display_parts.append(country)
                
                matches.append({
                    "display": ", ".join(display_parts),
                    "city": city_name,
                    "state": state,
                    "country": country,
                    "lat": float(r["lat"]),
                    "lon": float(r["lon"])
                })
            
            self.results_ready.emit(self.city_input, matches)
            
        except Exception as e:
            self.error_occurred.emit(str(e))


class CitySelectionDialog(QDialog):
    """Accessible dialog for selecting from multiple city matches"""
    
    def __init__(self, matches, original_input, parent=None):
        super().__init__(parent)
        self.matches = matches
        self.selected_match = None
        
        self.setWindowTitle("Select City")
        self.setModal(True)
        self.resize(600, 400)
        
        # Set up layout
        layout = QVBoxLayout(self)
        
        # Label
        label = QLabel(f"Multiple cities found for '{original_input}'. Please select one:")
        label.setWordWrap(True)
        layout.addWidget(label)
        
        # List widget for cities
        self.city_list = QListWidget()
        self.city_list.setAccessibleName("City selection list")
        self.city_list.setAccessibleDescription("Use arrow keys to navigate and Enter to select")
        
        for i, match in enumerate(matches):
            item_text = f"{match['display']} (latitude: {match['lat']:.4f}, longitude: {match['lon']:.4f})"
            item = QListWidgetItem(item_text)
            item.setData(Qt.UserRole, i)  # Store index
            self.city_list.addItem(item)
        
        # Select first item by default
        if matches:
            self.city_list.setCurrentRow(0)
        
        layout.addWidget(self.city_list)
        
        # Button box
        button_box = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        button_box.accepted.connect(self.accept_selection)
        button_box.rejected.connect(self.reject)
        layout.addWidget(button_box)
        
        # Connect double-click and Enter
        self.city_list.itemDoubleClicked.connect(self.accept_selection)
        self.city_list.itemActivated.connect(self.accept_selection)
        
        # Set focus
        self.city_list.setFocus()
    
    def accept_selection(self):
        current_row = self.city_list.currentRow()
        if current_row >= 0 and current_row < len(self.matches):
            self.selected_match = self.matches[current_row]
            self.accept()
    
    def get_selected_match(self):
        return self.selected_match


class WeatherConfigDialog(QDialog):
    """Dialog for configuring weather display options"""
    
    def __init__(self, current_config, parent=None):
        super().__init__(parent)
        self.config = current_config.copy()  # Make a copy to avoid modifying original until saved
        self.init_ui()
        
    def init_ui(self):
        """Initialize the configuration dialog UI"""
        self.setWindowTitle("Configure Weather Display")
        self.setGeometry(200, 200, 600, 500)
        
        layout = QVBoxLayout(self)
        
        # Instructions
        instructions = QLabel("Select which weather details to display:")
        instructions.setAccessibleDescription("Use Tab to navigate between checkboxes, Space to toggle")
        layout.addWidget(instructions)
        
        # Create tab widget for different sections
        tabs = QTabWidget()
        
        # Current Weather tab
        current_tab = QWidget()
        current_layout = QVBoxLayout(current_tab)
        current_layout.addWidget(QLabel("Current Weather Details:"))
        
        self.current_checkboxes = {}
        current_options = [
            ('temperature', 'Current Temperature'),
            ('feels_like', 'Feels Like Temperature'),
            ('humidity', 'Humidity'),
            ('wind_speed', 'Wind Speed'),
            ('wind_direction', 'Wind Direction'),
            ('pressure', 'Atmospheric Pressure'),
            ('visibility', 'Visibility'),
            ('uv_index', 'UV Index'),
            ('precipitation', 'Current Precipitation')
        ]
        
        for key, label in current_options:
            checkbox = QCheckBox(label)
            checkbox.setChecked(self.config['current'].get(key, False))
            checkbox.setAccessibleDescription(f"Toggle display of {label.lower()}")
            self.current_checkboxes[key] = checkbox
            current_layout.addWidget(checkbox)
            
        tabs.addTab(current_tab, "Current Weather")
        
        # Hourly Weather tab
        hourly_tab = QWidget()
        hourly_layout = QVBoxLayout(hourly_tab)
        hourly_layout.addWidget(QLabel("Next 12 Hours Details:"))
        
        self.hourly_checkboxes = {}
        hourly_options = [
            ('temperature', 'Hourly Temperature'),
            ('feels_like', 'Hourly Feels Like'),
            ('humidity', 'Hourly Humidity'),
            ('precipitation', 'Hourly Precipitation'),
            ('wind_speed', 'Hourly Wind Speed'),
            ('wind_direction', 'Hourly Wind Direction')
        ]
        
        for key, label in hourly_options:
            checkbox = QCheckBox(label)
            checkbox.setChecked(self.config['hourly'].get(key, False))
            checkbox.setAccessibleDescription(f"Toggle display of {label.lower()}")
            self.hourly_checkboxes[key] = checkbox
            hourly_layout.addWidget(checkbox)
            
        tabs.addTab(hourly_tab, "Next 12 Hours")
        
        # Daily Weather tab
        daily_tab = QWidget()
        daily_layout = QVBoxLayout(daily_tab)
        daily_layout.addWidget(QLabel("7-Day Forecast Details:"))
        
        self.daily_checkboxes = {}
        daily_options = [
            ('temperature_max', 'Daily High Temperature'),
            ('temperature_min', 'Daily Low Temperature'),
            ('sunrise', 'Sunrise Time'),
            ('sunset', 'Sunset Time'),
            ('precipitation_sum', 'Daily Precipitation Total'),
            ('precipitation_hours', 'Hours of Precipitation'),
            ('wind_speed_max', 'Maximum Wind Speed'),
            ('wind_direction_dominant', 'Dominant Wind Direction')
        ]
        
        for key, label in daily_options:
            checkbox = QCheckBox(label)
            checkbox.setChecked(self.config['daily'].get(key, False))
            checkbox.setAccessibleDescription(f"Toggle display of {label.lower()}")
            self.daily_checkboxes[key] = checkbox
            daily_layout.addWidget(checkbox)
            
        tabs.addTab(daily_tab, "7-Day Forecast")
        
        layout.addWidget(tabs)
        
        # Button box
        button_box = QDialogButtonBox(QDialogButtonBox.Save | QDialogButtonBox.Cancel)
        button_box.accepted.connect(self.accept)
        button_box.rejected.connect(self.reject)
        
        # Make the Save button accessible
        save_button = button_box.button(QDialogButtonBox.Save)
        save_button.setAccessibleDescription("Save weather display configuration and return to weather view")
        
        cancel_button = button_box.button(QDialogButtonBox.Cancel)
        cancel_button.setAccessibleDescription("Cancel changes and return to weather view")
        
        layout.addWidget(button_box)
        
    def get_configuration(self):
        """Get the current configuration from checkboxes"""
        new_config = {
            'current': {},
            'hourly': {},
            'daily': {}
        }
        
        # Collect current weather settings
        for key, checkbox in self.current_checkboxes.items():
            new_config['current'][key] = checkbox.isChecked()
            
        # Collect hourly weather settings
        for key, checkbox in self.hourly_checkboxes.items():
            new_config['hourly'][key] = checkbox.isChecked()
            
        # Collect daily weather settings
        for key, checkbox in self.daily_checkboxes.items():
            new_config['daily'][key] = checkbox.isChecked()
            
        return new_config


class AccessibleWeatherApp(QMainWindow):
    """Main accessible weather application window"""
    
    def __init__(self):
        super().__init__()
        self.city_data = {}
        self.city_file = os.path.join(os.path.dirname(__file__), "city.json")
        self.last_focused_city_index = 0  # Track last focused city for tab navigation
        
        # Initialize weather display configuration
        self.weather_config = {
            'current': {
                'temperature': True,
                'feels_like': True,
                'humidity': True,
                'wind_speed': True,
                'wind_direction': True,
                'pressure': False,
                'visibility': False,
                'uv_index': False,
                'precipitation': True
            },
            'hourly': {
                'temperature': True,
                'feels_like': False,
                'humidity': False,
                'precipitation': True,
                'wind_speed': False,
                'wind_direction': False
            },
            'daily': {
                'temperature_max': True,
                'temperature_min': True,
                'sunrise': True,
                'sunset': True,
                'precipitation_sum': True,
                'precipitation_hours': False,
                'wind_speed_max': False,
                'wind_direction_dominant': False
            }
        }
        
        # Load existing cities
        self.load_city_data()
        
        # Set up UI
        self.init_ui()
        
        # Set up keyboard shortcuts
        self.setup_shortcuts()
        
        # Set initial focus based on whether cities exist
        self.set_initial_focus()
        
        # Configure logging
        logging.basicConfig(level=logging.INFO)
    
    def closeEvent(self, event):
        """Clean up when the application is closing"""
        # Stop any running threads gracefully
        if hasattr(self, 'geocoding_thread') and self.geocoding_thread is not None:
            try:
                if self.geocoding_thread.isRunning():
                    self.geocoding_thread.terminate()
                    if not self.geocoding_thread.wait(2000):  # Wait up to 2 seconds
                        self.geocoding_thread.quit()
            except RuntimeError:
                pass  # Thread already deleted
        
        if hasattr(self, 'weather_thread') and self.weather_thread is not None:
            try:
                if self.weather_thread.isRunning():
                    self.weather_thread.terminate()
                    if not self.weather_thread.wait(2000):
                        self.weather_thread.quit()
            except RuntimeError:
                pass
        
        if hasattr(self, 'full_weather_thread') and self.full_weather_thread is not None:
            try:
                if self.full_weather_thread.isRunning():
                    self.full_weather_thread.terminate()
                    if not self.full_weather_thread.wait(2000):
                        self.full_weather_thread.quit()
            except RuntimeError:
                pass
        
        if hasattr(self, 'weather_threads'):
            for thread in self.weather_threads:
                try:
                    if thread.isRunning():
                        thread.terminate()
                        if not thread.wait(1000):
                            thread.quit()
                except RuntimeError:
                    pass
        
        # Clean up shortcuts
        if hasattr(self, 'escape_shortcut'):
            self.escape_shortcut.deleteLater()
        if hasattr(self, 'alt_b_shortcut'):
            self.alt_b_shortcut.deleteLater()
        if hasattr(self, 'alt_left_shortcut'):
            self.alt_left_shortcut.deleteLater()
        
        event.accept()
    
    def init_ui(self):
        """Initialize the user interface with accessibility features"""
        self.setWindowTitle("FastWeather - Accessible Weather Application")
        self.setGeometry(100, 100, 1000, 700)
        
        # Create stacked widget to manage main view and full weather view
        self.stacked_widget = QStackedWidget()
        self.setCentralWidget(self.stacked_widget)
        
        # Create main view widget
        self.main_widget = QWidget()
        self.stacked_widget.addWidget(self.main_widget)
        
        # Main layout
        main_layout = QVBoxLayout(self.main_widget)
        main_layout.setSpacing(10)
        
        # City input section
        input_group = QGroupBox("Add New City")
        input_layout = QHBoxLayout(input_group)
        
        input_label = QLabel("Enter city name or zip code:")
        input_label.setAccessibleDescription("Type a city name, zip code, or location to add to your weather list")
        
        self.city_input = QLineEdit()
        self.city_input.setAccessibleName("City or zip code input")
        self.city_input.setAccessibleDescription("Enter a city name, zip code, or location. Press Enter to add to your list.")
        self.city_input.setPlaceholderText("e.g., Madison, WI or 53703 or London, UK")
        self.city_input.returnPressed.connect(self.add_city)
        
        self.add_button = QPushButton("Add City")
        self.add_button.setAccessibleDescription("Add the entered city to your weather list")
        self.add_button.clicked.connect(self.add_city)
        self.add_button.setDefault(True)
        
        input_layout.addWidget(input_label)
        input_layout.addWidget(self.city_input, 1)
        input_layout.addWidget(self.add_button)
        
        main_layout.addWidget(input_group)
        
        # Create splitter for resizable sections
        splitter = QSplitter(Qt.Horizontal)
        
        # Left side - City list and controls (now takes full width)
        left_widget = QWidget()
        left_layout = QVBoxLayout(left_widget)
        
        # City list
        city_group = QGroupBox("Your Cities - Current Weather")
        city_layout = QVBoxLayout(city_group)
        
        self.city_list = QListWidget()
        self.city_list.setAccessibleName("Your saved cities with current weather")
        self.city_list.setAccessibleDescription("Use arrow keys to navigate cities. Current weather is shown for each city. Press Enter for full weather details.")
        self.city_list.currentItemChanged.connect(self.on_city_selected)
        self.city_list.itemActivated.connect(self.show_full_weather)
        self.city_list.setFocusPolicy(Qt.StrongFocus)  # Ensure it receives focus properly
        
        # Install event filter to handle focus events and remember last focused city
        self.city_list.installEventFilter(self)
        
        city_layout.addWidget(self.city_list)
        
        # City management buttons
        button_layout = QHBoxLayout()
        
        self.move_up_button = QPushButton("Move Up")
        self.move_up_button.setAccessibleDescription("Move the selected city up in the list (Alt+U)")
        self.move_up_button.clicked.connect(self.move_city_up)
        self.move_up_button.setEnabled(False)
        
        self.move_down_button = QPushButton("Move Down")
        self.move_down_button.setAccessibleDescription("Move the selected city down in the list (Alt+D)")
        self.move_down_button.clicked.connect(self.move_city_down)
        self.move_down_button.setEnabled(False)
        
        self.remove_button = QPushButton("Remove City")
        self.remove_button.setAccessibleDescription("Remove the selected city from your list")
        self.remove_button.clicked.connect(self.remove_city)
        self.remove_button.setEnabled(False)
        
        self.refresh_button = QPushButton("Refresh Weather")
        self.refresh_button.setAccessibleDescription("Refresh weather data for the selected city")
        self.refresh_button.clicked.connect(self.refresh_weather)
        self.refresh_button.setEnabled(False)
        
        self.full_weather_button = QPushButton("Full Weather")
        self.full_weather_button.setAccessibleDescription("Open detailed weather forecast for the selected city")
        self.full_weather_button.clicked.connect(self.show_full_weather)
        self.full_weather_button.setEnabled(False)
        
        button_layout.addWidget(self.move_up_button)
        button_layout.addWidget(self.move_down_button)
        button_layout.addWidget(self.remove_button)
        button_layout.addWidget(self.refresh_button)
        button_layout.addWidget(self.full_weather_button)
        
        city_layout.addLayout(button_layout)
        left_layout.addWidget(city_group)
        
        # Add the city widget to take the full width (no right panel anymore)
        splitter.addWidget(left_widget)
        splitter.setStretchFactor(0, 1)  # City list takes full space
        
        main_layout.addWidget(splitter)
        
        # Status bar
        self.status_bar = QStatusBar()
        self.setStatusBar(self.status_bar)
        self.status_bar.showMessage("Ready - Enter a city name or zip code to add to your list")
        
        # Populate city list
        self.update_city_list()
        
        # Set initial focus - if we have cities, focus the city list, otherwise focus input
        # Use QTimer with longer delay to ensure focus is set after everything is ready
        QTimer.singleShot(100, self.set_initial_focus)
    
    def set_initial_focus(self):
        """Set the initial focus after UI initialization"""
        # Use QTimer to defer focus setting until after the UI is fully initialized
        QTimer.singleShot(0, self._do_initial_focus)
    
    def _do_initial_focus(self):
        """Actually set the focus - called after UI is ready"""
        if self.city_data and self.city_list.count() > 0:
            # Cities exist, focus on the city list and ensure proper selection
            if self.city_list.currentRow() == -1:
                # No current selection, set to first item
                self.city_list.setCurrentRow(0)
                self.last_focused_city_index = 0
            
            # Ensure focus is on the city list
            self.city_list.setFocus()
            
            # Force update of button states
            current_row = self.city_list.currentRow()
            total_cities = self.city_list.count()
            self.remove_button.setEnabled(True)
            self.refresh_button.setEnabled(True)
            self.full_weather_button.setEnabled(True)
            self.move_up_button.setEnabled(current_row > 0)
            self.move_down_button.setEnabled(current_row < total_cities - 1)
        else:
            # No cities exist, focus on the input box
            self.city_input.setFocus()
    
    def setup_shortcuts(self):
        """Set up keyboard shortcuts for accessibility"""
        # F1 for help
        help_shortcut = QShortcut(QKeySequence("F1"), self)
        help_shortcut.activated.connect(self.show_help)
        
        # F5 and Ctrl+R for refresh
        refresh_shortcut1 = QShortcut(QKeySequence("F5"), self)
        refresh_shortcut1.activated.connect(self.refresh_weather)
        
        refresh_shortcut2 = QShortcut(QKeySequence("Ctrl+R"), self)
        refresh_shortcut2.activated.connect(self.refresh_weather)
        
        # Delete key, Ctrl+D, and Alt+Delete for delete (changed Alt+D to avoid conflict)
        delete_shortcut1 = QShortcut(QKeySequence("Delete"), self)
        delete_shortcut1.activated.connect(self.remove_city)
        
        delete_shortcut2 = QShortcut(QKeySequence("Ctrl+D"), self)
        delete_shortcut2.activated.connect(self.remove_city)
        
        delete_shortcut3 = QShortcut(QKeySequence("Alt+Delete"), self)
        delete_shortcut3.activated.connect(self.remove_city)
        
        # Alt+U and Alt+D for move up/down
        move_up_shortcut = QShortcut(QKeySequence("Alt+U"), self)
        move_up_shortcut.activated.connect(self.move_city_up)
        
        move_down_shortcut = QShortcut(QKeySequence("Alt+D"), self)
        move_down_shortcut.activated.connect(self.move_city_down)
        
        # Ctrl+N and Alt+A for new city (focus input)
        new_shortcut1 = QShortcut(QKeySequence("Ctrl+N"), self)
        new_shortcut1.activated.connect(lambda: self.city_input.setFocus())
        
        new_shortcut2 = QShortcut(QKeySequence("Alt+A"), self)
        new_shortcut2.activated.connect(lambda: self.city_input.setFocus())
        
        # Install event filter for city list to handle Shift+Up/Down
        self.city_list.installEventFilter(self)
    
    def show_help(self):
        """Show accessible help dialog"""
        help_text = """FastWeather - Accessible Weather App

KEYBOARD NAVIGATION:
• Tab/Shift+Tab - Navigate between controls
• Arrow Keys - Navigate city list (current weather is shown for each city)
• Enter - Add city (from input) or show full weather (from city list)

KEYBOARD SHORTCUTS:
• F1 - Show this help
• F5 or Ctrl+R - Refresh weather for selected city  
• Delete, Ctrl+D, or Alt+Delete - Remove selected city
• Alt+U - Move selected city up in list
• Alt+D - Move selected city down in list
• Shift+Up/Down - Move selected city up/down in list
• Ctrl+N or Alt+A - Focus on city input field (add new city)

FULL WEATHER NAVIGATION:
• Arrow Keys - Navigate line by line
• Ctrl+Up/Down - Jump between sections (days, forecasts)
• Escape, Alt+B, Alt+Left - Return to city list

HOW TO USE:
1. Type a city name or zip code in the input field
2. Press Enter or click "Add City" 
3. Tab to your city list or click on it
4. Use arrow keys to select cities (current weather is shown in the list)
5. Press Enter or click "Full Weather" for detailed forecast with "feels like" temperatures

ACCESSIBILITY FEATURES:
• Full screen reader support with NVDA, JAWS, Narrator
• Complete keyboard navigation - no mouse required
• Proper focus management and tab order
• Clear status announcements
• High contrast support
• Current weather displayed directly in city list

SUPPORTED INPUT FORMATS:
• City names: "Madison", "London"
• City with state: "Madison, WI", "Portland, OR"  
• City with country: "London, UK", "Paris, France"
• Zip codes: "53703", "97201"
• International: "Tokyo, Japan", "Sydney, Australia"

WEATHER DETAILS:
• Current temperature and "feels like" temperature
• 12-hour forecast with apparent temperatures
• 7-day forecast with high/low temperatures
• Wind, humidity, and precipitation information

The app uses the free Open-Meteo weather service - no API key required!"""
        
        msg = QMessageBox(self)
        msg.setWindowTitle("Help - FastWeather")
        msg.setText(help_text)
        msg.setStandardButtons(QMessageBox.Ok)
        msg.exec_()
    
    def load_city_data(self):
        """Load city data from JSON file"""
        try:
            if os.path.exists(self.city_file):
                with open(self.city_file, 'r') as f:
                    self.city_data = json.load(f)
                print(f"Loaded {len(self.city_data)} cities from {self.city_file}")
        except Exception as e:
            logging.error(f"Error loading city data: {e}")
            print(f"Error loading city data: {e}")
            self.city_data = {}
    
    def save_city_data(self):
        """Save city data to JSON file"""
        try:
            with open(self.city_file, 'w') as f:
                json.dump(self.city_data, f, indent=4)
        except Exception as e:
            logging.error(f"Error saving city data: {e}")
            self.status_bar.showMessage(f"Error saving cities: {e}")
    
    def update_city_list(self, reload_weather=True):
        """Update the city list widget with weather info"""
        # Store current selection
        current_city = None
        current_item = self.city_list.currentItem()
        if current_item:
            current_city = current_item.data(Qt.UserRole)
        
        self.city_list.clear()
        for city in self.city_data.keys():
            # Initially add city with "Loading..." status
            item_text = f"{city} - Loading weather..."
            item = QListWidgetItem(item_text)
            item.setData(Qt.UserRole, city)
            self.city_list.addItem(item)
        
        # Update button states
        has_cities = len(self.city_data) > 0
        self.remove_button.setEnabled(has_cities)
        self.refresh_button.setEnabled(has_cities)
        self.full_weather_button.setEnabled(has_cities)
        self.move_up_button.setEnabled(has_cities)
        self.move_down_button.setEnabled(has_cities)
        
        # Restore selection if we had one
        if current_city:
            for i in range(self.city_list.count()):
                item = self.city_list.item(i)
                if item.data(Qt.UserRole) == current_city:
                    self.city_list.setCurrentRow(i)
                    self.last_focused_city_index = i
                    break
        elif self.city_list.count() > 0:
            # Set to last focused city index or first city
            index = min(self.last_focused_city_index, self.city_list.count() - 1)
            self.city_list.setCurrentRow(index)
        
        # Load weather for all cities (optional)
        if reload_weather and has_cities:
            self.load_all_weather()
    
    def update_city_list_order_only(self):
        """Update city list order without reloading weather (for moves)"""
        # Store current weather data from UI
        current_weather_data = {}
        for i in range(self.city_list.count()):
            item = self.city_list.item(i)
            city_name = item.data(Qt.UserRole)
            current_weather_data[city_name] = item.text()
        
        # Store current selection
        current_city = None
        current_item = self.city_list.currentItem()
        if current_item:
            current_city = current_item.data(Qt.UserRole)
        
        # Clear and rebuild list in new order
        self.city_list.clear()
        for city in self.city_data.keys():
            # Use existing weather data if available
            if city in current_weather_data:
                item_text = current_weather_data[city]
            else:
                item_text = f"{city} - Loading weather..."
            
            item = QListWidgetItem(item_text)
            item.setData(Qt.UserRole, city)
            self.city_list.addItem(item)
        
        # Update button states
        has_cities = len(self.city_data) > 0
        self.remove_button.setEnabled(has_cities)
        self.refresh_button.setEnabled(has_cities)
        self.full_weather_button.setEnabled(has_cities)
        self.move_up_button.setEnabled(has_cities)
        self.move_down_button.setEnabled(has_cities)
        
        # Restore selection
        if current_city:
            for i in range(self.city_list.count()):
                item = self.city_list.item(i)
                if item.data(Qt.UserRole) == current_city:
                    self.city_list.setCurrentRow(i)
                    self.last_focused_city_index = i
                    break
    
    def load_all_weather(self):
        """Load basic weather for all cities and update list items"""
        for i in range(self.city_list.count()):
            item = self.city_list.item(i)
            city_name = item.data(Qt.UserRole)
            if city_name in self.city_data:
                lat, lon = self.city_data[city_name]
                # Create a weather thread for this city
                weather_thread = WeatherFetchThread(city_name, lat, lon, "basic")
                weather_thread.weather_ready.connect(self.update_city_item_weather)
                weather_thread.error_occurred.connect(self.update_city_item_error)
                weather_thread.finished.connect(lambda thread=weather_thread: self.cleanup_weather_thread(thread))
                weather_thread.start()
                # Store the thread to prevent garbage collection
                if not hasattr(self, 'weather_threads'):
                    self.weather_threads = []
                self.weather_threads.append(weather_thread)
    
    def cleanup_weather_thread(self, thread):
        """Remove finished weather thread from the list"""
        if hasattr(self, 'weather_threads') and thread in self.weather_threads:
            self.weather_threads.remove(thread)
            thread.deleteLater()
    
    def update_city_item_weather(self, city_name, data):
        """Update a specific city item with weather data"""
        current_weather = data.get("current_weather", {})
        if current_weather:
            temp_c = current_weather.get("temperature", 0)
            temp_f = self.celsius_to_fahrenheit(temp_c)
            weather_code = current_weather.get("weathercode", 0)
            conditions = self.weather_code_description(weather_code)
            
            # Create short weather description for list
            weather_summary = f"{temp_f:.0f}°F, {conditions}"
            item_text = f"{city_name} - {weather_summary}"
        else:
            item_text = f"{city_name} - No weather data"
        
        # Find and update the item
        for i in range(self.city_list.count()):
            item = self.city_list.item(i)
            if item.data(Qt.UserRole) == city_name:
                item.setText(item_text)
                break
    
    def update_city_item_error(self, city_name, error_msg):
        """Update a city item with error message"""
        item_text = f"{city_name} - Weather unavailable"
        
        # Find and update the item
        for i in range(self.city_list.count()):
            item = self.city_list.item(i)
            if item.data(Qt.UserRole) == city_name:
                item.setText(item_text)
                break
    
    def add_city(self):
        """Add a new city to the list"""
        city_input = self.city_input.text().strip()
        if not city_input:
            return
        
        # Prevent multiple concurrent geocoding operations
        if hasattr(self, 'geocoding_thread') and self.geocoding_thread is not None:
            try:
                if self.geocoding_thread.isRunning():
                    self.status_bar.showMessage("Please wait for current lookup to complete...")
                    return
            except RuntimeError:
                # Thread was already deleted, safe to continue
                pass
        
        self.status_bar.showMessage("Looking up city coordinates...")
        self.add_button.setEnabled(False)
        self.city_input.setEnabled(False)
        
        # Start geocoding thread
        self.geocoding_thread = GeocodingThread(city_input)
        self.geocoding_thread.results_ready.connect(self.handle_geocoding_results)
        self.geocoding_thread.error_occurred.connect(self.handle_geocoding_error)
        self.geocoding_thread.finished.connect(self.cleanup_geocoding_thread)
        self.geocoding_thread.start()
    
    def handle_geocoding_results(self, original_input, matches):
        """Handle geocoding results"""
        self.add_button.setEnabled(True)
        self.city_input.setEnabled(True)
        
        if not matches:
            self.status_bar.showMessage(f"Could not find coordinates for '{original_input}'")
            QMessageBox.warning(
                self, 
                "City Not Found", 
                f"Could not find '{original_input}'.\n\nTry:\n• More specific spelling\n• Include state or country\n• Use zip code for US locations"
            )
            self.city_input.setFocus()
            return
        
        if len(matches) == 1:
            # Single match - add directly
            self.add_city_from_match(matches[0])
        else:
            # Multiple matches - show selection dialog
            dialog = CitySelectionDialog(matches, original_input, self)
            if dialog.exec_() == QDialog.Accepted:
                selected = dialog.get_selected_match()
                if selected:
                    self.add_city_from_match(selected)
            
            self.city_input.setFocus()
    
    def add_city_from_match(self, match):
        """Add a city from a geocoding match"""
        city_key = match['display']
        
        if city_key in self.city_data:
            self.status_bar.showMessage(f"{city_key} is already in your list")
            QMessageBox.information(self, "City Already Added", f"{city_key} is already in your city list.")
            self.city_input.clear()
            self.city_input.setFocus()
            return
        
        self.city_data[city_key] = [match['lat'], match['lon']]
        self.save_city_data()
        self.update_city_list()
        self.city_input.clear()
        self.status_bar.showMessage(f"Added {city_key}")
        
        # Select the new city and get its weather
        for i in range(self.city_list.count()):
            if self.city_list.item(i).data(Qt.UserRole) == city_key:
                self.city_list.setCurrentRow(i)
                self.get_basic_weather()
                break
        
        self.city_input.setFocus()
    
    def cleanup_geocoding_thread(self):
        """Clean up the geocoding thread when it finishes"""
        if hasattr(self, 'geocoding_thread') and self.geocoding_thread is not None:
            self.geocoding_thread.deleteLater()
            self.geocoding_thread = None
    
    def handle_geocoding_error(self, error_msg):
        """Handle geocoding errors"""
        self.add_button.setEnabled(True)
        self.city_input.setEnabled(True)
        self.status_bar.showMessage(f"Network error: {error_msg}")
        QMessageBox.critical(self, "Network Error", f"Could not connect to geocoding service:\n{error_msg}\n\nPlease check your internet connection and try again.")
        self.city_input.setFocus()
    
    def on_city_selected(self, current, previous):
        """Handle city selection change"""
        if current:
            current_row = self.city_list.currentRow()
            total_cities = self.city_list.count()
            
            # Track the last focused city index
            self.last_focused_city_index = current_row
            
            # Update button states
            self.remove_button.setEnabled(True)
            self.refresh_button.setEnabled(True)
            self.full_weather_button.setEnabled(True)
            
            # Enable/disable move buttons based on position
            self.move_up_button.setEnabled(current_row > 0)
            self.move_down_button.setEnabled(current_row < total_cities - 1)
    
    def refresh_weather(self):
        """Refresh weather for currently selected city"""
        current_item = self.city_list.currentItem()
        if current_item:
            city_name = current_item.data(Qt.UserRole)
            if city_name in self.city_data:
                lat, lon = self.city_data[city_name]
                # Create a weather thread for this city to refresh its display
                weather_thread = WeatherFetchThread(city_name, lat, lon, "basic")
                weather_thread.weather_ready.connect(self.update_city_item_weather)
                weather_thread.error_occurred.connect(self.update_city_item_error)
                weather_thread.finished.connect(lambda thread=weather_thread: self.cleanup_weather_thread(thread))
                weather_thread.start()
                # Store the thread to prevent garbage collection
                if not hasattr(self, 'weather_threads'):
                    self.weather_threads = []
                self.weather_threads.append(weather_thread)
                self.status_bar.showMessage(f"Refreshing weather for {city_name}...")
        else:
            self.status_bar.showMessage("Please select a city to refresh weather")
    
    def remove_city(self):
        """Remove selected city from the list"""
        current_item = self.city_list.currentItem()
        if not current_item:
            QMessageBox.warning(self, "No Selection", "Please select a city to remove.")
            return
        
        city_name = current_item.data(Qt.UserRole)
        current_row = self.city_list.currentRow()
        
        reply = QMessageBox.question(
            self,
            "Confirm Removal", 
            f"Remove '{city_name}' from your city list?",
            QMessageBox.Yes | QMessageBox.No,
            QMessageBox.No
        )
        
        if reply == QMessageBox.Yes:
            if city_name in self.city_data:
                del self.city_data[city_name]
                self.save_city_data()
                
                # Update the list and maintain focus on next closest item
                self.update_city_list()
                
                # Restore focus to the closest item
                total_items = self.city_list.count()
                if total_items > 0:
                    # If we deleted the last item, go to the new last item
                    if current_row >= total_items:
                        new_row = total_items - 1
                    else:
                        # Stay at the same row (which now has the next item)
                        new_row = current_row
                    
                    self.city_list.setCurrentRow(new_row)
                    self.city_list.setFocus()
                else:
                    # No cities left, clear weather display and focus input
                    self.city_input.setFocus()
                
                self.status_bar.showMessage(f"Removed {city_name}")
            else:
                self.status_bar.showMessage(f"Error: City '{city_name}' not found")
    
    def move_city_up(self):
        """Move the selected city up in the list"""
        current_item = self.city_list.currentItem()
        if not current_item:
            QMessageBox.warning(self, "No Selection", "Please select a city to move.")
            return
        
        current_row = self.city_list.currentRow()
        if current_row <= 0:
            self.status_bar.showMessage("City is already at the top")
            return
        
        # Store the city name for status message
        city_name = current_item.data(Qt.UserRole)
        
        try:
            # Get city list as ordered list
            city_keys = list(self.city_data.keys())
            
            # Validate indices
            if current_row >= len(city_keys) or current_row - 1 < 0:
                self.status_bar.showMessage("Cannot move city: invalid position")
                return
            
            # Swap positions in the list
            city_keys[current_row], city_keys[current_row - 1] = city_keys[current_row - 1], city_keys[current_row]
            
            # Rebuild city_data in new order
            new_city_data = {}
            for city_key in city_keys:
                if city_key in self.city_data:  # Safety check
                    new_city_data[city_key] = self.city_data[city_key]
            
            # Only update if we have the same number of cities
            if len(new_city_data) == len(self.city_data):
                self.city_data = new_city_data
                
                # Save and update UI (without reloading weather to prevent conflicts)
                self.save_city_data()
                self.update_city_list_order_only()
                
                # Keep focus on the moved city (now one row up)
                new_row = max(0, current_row - 1)
                if new_row < self.city_list.count():
                    self.city_list.setCurrentRow(new_row)
                    self.city_list.setFocus()
                
                self.status_bar.showMessage(f"Moved {city_name} up")
            else:
                self.status_bar.showMessage("Error: City data corrupted during move")
                
        except Exception as e:
            self.status_bar.showMessage(f"Error moving city: {str(e)}")
            # Reload city data to recover
            self.load_city_data()
            self.update_city_list(reload_weather=True)
    
    def move_city_down(self):
        """Move the selected city down in the list"""
        current_item = self.city_list.currentItem()
        if not current_item:
            QMessageBox.warning(self, "No Selection", "Please select a city to move.")
            return
        
        current_row = self.city_list.currentRow()
        total_cities = len(self.city_data)
        
        if current_row >= total_cities - 1:
            self.status_bar.showMessage("City is already at the bottom")
            return
        
        # Store the city name for status message
        city_name = current_item.data(Qt.UserRole)
        
        try:
            # Get city list as ordered list
            city_keys = list(self.city_data.keys())
            
            # Validate indices
            if current_row >= len(city_keys) or current_row + 1 >= len(city_keys):
                self.status_bar.showMessage("Cannot move city: invalid position")
                return
            
            # Swap positions in the list
            city_keys[current_row], city_keys[current_row + 1] = city_keys[current_row + 1], city_keys[current_row]
            
            # Rebuild city_data in new order
            new_city_data = {}
            for city_key in city_keys:
                if city_key in self.city_data:  # Safety check
                    new_city_data[city_key] = self.city_data[city_key]
            
            # Only update if we have the same number of cities
            if len(new_city_data) == len(self.city_data):
                self.city_data = new_city_data
                
                # Save and update UI (without reloading weather to prevent conflicts)
                self.save_city_data()
                self.update_city_list_order_only()
                
                # Keep focus on the moved city (now one row down)
                new_row = min(self.city_list.count() - 1, current_row + 1)
                if new_row >= 0:
                    self.city_list.setCurrentRow(new_row)
                    self.city_list.setFocus()
                
                self.status_bar.showMessage(f"Moved {city_name} down")
            else:
                self.status_bar.showMessage("Error: City data corrupted during move")
                
        except Exception as e:
            self.status_bar.showMessage(f"Error moving city: {str(e)}")
            # Reload city data to recover
            self.load_city_data()
            self.update_city_list(reload_weather=True)
    
    def show_full_weather(self):
        """Show full weather details in the same window"""
        current_item = self.city_list.currentItem()
        if not current_item:
            QMessageBox.warning(self, "No Selection", "Please select a city to see full weather.")
            return
        
        city_name = current_item.data(Qt.UserRole)
        if city_name not in self.city_data:
            return
        
        lat, lon = self.city_data[city_name]
        
        # Show full weather view
        self.show_full_weather_view(city_name, lat, lon)
    
    def hide_main_content(self):
        """Hide the main interface elements"""
        # This method is no longer needed with stacked widget approach
        pass
    
    def show_full_weather_view(self, city_name, lat, lon):
        """Create and show the full weather view"""
        # Store current city data for potential reconfiguration
        self.current_city_data = (city_name, lat, lon)
        
        # Always recreate the full weather widget to avoid reuse issues
        if hasattr(self, 'full_weather_widget'):
            # Clean up old shortcuts to prevent crashes
            if hasattr(self, 'escape_shortcut'):
                self.escape_shortcut.deleteLater()
            if hasattr(self, 'alt_b_shortcut'):
                self.alt_b_shortcut.deleteLater()
            if hasattr(self, 'alt_left_shortcut'):
                self.alt_left_shortcut.deleteLater()
            
            # Remove the old widget from the stacked widget
            self.stacked_widget.removeWidget(self.full_weather_widget)
            self.full_weather_widget.deleteLater()
        
        # Create new full weather widget
        self.full_weather_widget = QWidget()
        self.stacked_widget.addWidget(self.full_weather_widget)
        
        layout = QVBoxLayout(self.full_weather_widget)
        
        # Header with back button
        header_layout = QHBoxLayout()
        
        # Back button
        self.back_button = QPushButton("← Back to City List")
        self.back_button.setAccessibleName("Back to city list")
        self.back_button.setAccessibleDescription("Return to the main city list view")
        self.back_button.clicked.connect(self.show_main_view)
        self.back_button.setFocusPolicy(Qt.StrongFocus)
        header_layout.addWidget(self.back_button)
        
        # Title
        title_label = QLabel(f"Full Weather - {city_name}")
        title_label.setStyleSheet("font-weight: bold; font-size: 14px;")
        title_label.setAccessibleName(f"Full weather for {city_name}")
        header_layout.addWidget(title_label)
        
        header_layout.addStretch()
        
        # Configure button
        self.configure_button = QPushButton("Configure")
        self.configure_button.setAccessibleName("Configure weather display")
        self.configure_button.setAccessibleDescription("Configure which weather details to show")
        self.configure_button.clicked.connect(self.show_weather_configuration)
        self.configure_button.setFocusPolicy(Qt.StrongFocus)
        header_layout.addWidget(self.configure_button)
        
        layout.addLayout(header_layout)
        
        # Weather display area - using list widget for better accessibility
        self.full_weather_display = QListWidget()
        self.full_weather_display.setAccessibleName(f"Full weather details for {city_name}")
        self.full_weather_display.setAccessibleDescription("Navigate with arrow keys, press Space or Enter to hear individual items. Ctrl+Up/Down jumps between sections.")
        self.full_weather_display.setFont(QFont("Courier", 10))
        self.full_weather_display.setAlternatingRowColors(True)
        self.full_weather_display.setFocusPolicy(Qt.StrongFocus)
        
        # Install event filter for the list widget to handle Ctrl+Up/Down
        self.full_weather_display.installEventFilter(self)
        
        # Add loading message
        loading_item = QListWidgetItem(f"Loading full weather for {city_name}...")
        self.full_weather_display.addItem(loading_item)
        layout.addWidget(self.full_weather_display)
        
        # Set up escape key handling and navigation shortcuts
        self.full_weather_widget.setFocusPolicy(Qt.StrongFocus)
        self.full_weather_widget.installEventFilter(self)
        
        # Add back navigation shortcuts for the full weather view with proper cleanup
        self.escape_shortcut = QShortcut(QKeySequence("Escape"), self.full_weather_widget)
        self.escape_shortcut.activated.connect(self.show_main_view)
        
        self.alt_b_shortcut = QShortcut(QKeySequence("Alt+B"), self.full_weather_widget)
        self.alt_b_shortcut.activated.connect(self.show_main_view)
        
        self.alt_left_shortcut = QShortcut(QKeySequence("Alt+Left"), self.full_weather_widget)
        self.alt_left_shortcut.activated.connect(self.show_main_view)
        
        # Focus on the weather list for accessibility (not the back button)
        self.full_weather_display.setFocus()
        
        # Switch to the full weather view
        self.stacked_widget.setCurrentWidget(self.full_weather_widget)
        
        # Load weather data
        self.load_full_weather_data(city_name, lat, lon)
    
    def load_full_weather_data(self, city_name, lat, lon):
        """Load full weather data in background"""
        # Prevent multiple concurrent full weather operations
        if hasattr(self, 'full_weather_thread') and self.full_weather_thread is not None:
            try:
                if self.full_weather_thread.isRunning():
                    return
            except RuntimeError:
                # Thread was already deleted, safe to continue
                pass
        
        weather_thread = WeatherFetchThread(city_name, lat, lon, "full", 7)
        weather_thread.weather_ready.connect(self.display_full_weather_content)
        weather_thread.error_occurred.connect(self.display_full_weather_error)
        weather_thread.finished.connect(lambda: self.cleanup_full_weather_thread())
        weather_thread.start()
        
        # Store thread to prevent garbage collection
        self.full_weather_thread = weather_thread
    
    def cleanup_full_weather_thread(self):
        """Clean up the full weather thread"""
        if hasattr(self, 'full_weather_thread') and self.full_weather_thread is not None:
            self.full_weather_thread.deleteLater()
            self.full_weather_thread = None
    
    def display_full_weather_content(self, city_name, data):
        """Display the full weather content in list format"""
        # Clear existing items
        self.full_weather_display.clear()
        
        # Get weather data as list items using the format_full_weather method
        weather_text = self.format_full_weather(city_name, data)
        weather_lines = weather_text.split('\n')
        
        # Add each line to the list widget, filtering out separator lines
        for line in weather_lines:
            stripped_line = line.strip()
            # Skip empty lines and separator lines (lines of dashes or equals)
            if stripped_line and not self.is_separator_line(stripped_line):
                list_item = QListWidgetItem(line)
                # Set accessible description for screen readers
                list_item.setToolTip(line)
                
                # Mark section headers for navigation
                if self.is_section_header(stripped_line):
                    list_item.setData(Qt.UserRole, "section_header")
                
                self.full_weather_display.addItem(list_item)
        
        # Focus on the first item for immediate navigation
        if self.full_weather_display.count() > 0:
            self.full_weather_display.setCurrentRow(0)
        
        # Announce to screen reader
        self.full_weather_display.setAccessibleDescription(f"Full weather data loaded for {city_name}. {self.full_weather_display.count()} items. Use arrow keys to navigate.")
    
    def is_separator_line(self, line):
        """Check if a line is just a separator (dashes, equals, etc.)"""
        # Remove whitespace and check if line consists only of separator characters
        cleaned = line.strip()
        if not cleaned:
            return True
        
        # Check if line is made up entirely of separator characters
        separator_chars = {'-', '=', '_', '*', '#'}
        return len(set(cleaned)) == 1 and cleaned[0] in separator_chars
    
    def is_section_header(self, line):
        """Check if a line is a section header for navigation"""
        # Section headers typically contain keywords like these
        section_keywords = [
            "CURRENT WEATHER", "HOURLY FORECAST", "12-HOUR FORECAST", "DAILY FORECAST", "7-DAY FORECAST",
            "Today", "Tomorrow", "Monday", "Tuesday", "Wednesday", 
            "Thursday", "Friday", "Saturday", "Sunday",
            "===", "REPORT FOR", "📊", "🗓️", "Report generated"
        ]
        
        line_upper = line.upper()
        return any(keyword.upper() in line_upper for keyword in section_keywords)
    
    def navigate_to_next_section(self):
        """Navigate to the next section header in the full weather list"""
        if not hasattr(self, 'full_weather_display'):
            return
            
        current_row = self.full_weather_display.currentRow()
        count = self.full_weather_display.count()
        
        # Look for next section header
        for i in range(current_row + 1, count):
            item = self.full_weather_display.item(i)
            if item and item.data(Qt.UserRole) == "section_header":
                self.full_weather_display.setCurrentRow(i)
                return
        
        # If no section found, go to last item
        if count > 0:
            self.full_weather_display.setCurrentRow(count - 1)
    
    def navigate_to_previous_section(self):
        """Navigate to the previous section header in the full weather list"""
        if not hasattr(self, 'full_weather_display'):
            return
            
        current_row = self.full_weather_display.currentRow()
        
        # Look for previous section header
        for i in range(current_row - 1, -1, -1):
            item = self.full_weather_display.item(i)
            if item and item.data(Qt.UserRole) == "section_header":
                self.full_weather_display.setCurrentRow(i)
                return
        
        # If no section found, go to first item
        if self.full_weather_display.count() > 0:
            self.full_weather_display.setCurrentRow(0)
    
    def display_full_weather_error(self, city_name, error_msg):
        """Display error message for full weather"""
        self.full_weather_display.clear()
        error_item = QListWidgetItem(f"Error loading weather for {city_name}: {error_msg}")
        self.full_weather_display.addItem(error_item)
        self.full_weather_display.setCurrentRow(0)
    
    def show_main_view(self):
        """Return to the main view"""
        # Switch back to main view
        self.stacked_widget.setCurrentWidget(self.main_widget)
        
        # Focus back on city list
        self.city_list.setFocus()
    
    def show_weather_configuration(self):
        """Show the weather configuration dialog"""
        dialog = WeatherConfigDialog(self.weather_config, self)
        if dialog.exec_() == QDialog.Accepted:
            # Update configuration with new settings
            self.weather_config = dialog.get_configuration()
            
            # Reload the current weather display with new configuration
            if hasattr(self, 'full_weather_display') and hasattr(self, 'current_city_data'):
                city_name, lat, lon = self.current_city_data
                self.load_full_weather_data(city_name, lat, lon)
    
    def eventFilter(self, obj, event):
        """Handle keyboard events in full weather view and city list"""
        try:
            # Handle focus events for the city list to restore last focused city
            if event.type() == QEvent.FocusIn and obj == self.city_list:
                if self.city_list.count() > 0:
                    # If no item is currently selected, restore to last focused city
                    if self.city_list.currentRow() == -1:
                        index = min(self.last_focused_city_index, self.city_list.count() - 1)
                        self.city_list.setCurrentRow(index)
                    
                    # Ensure the current item is properly highlighted and announced
                    current_item = self.city_list.currentItem()
                    if current_item:
                        # Force the screen reader to announce the current item
                        self.city_list.setCurrentItem(current_item)
                        # Also update our tracking
                        self.last_focused_city_index = self.city_list.currentRow()
                return False  # Allow normal focus processing
            
            if event.type() == event.KeyPress:
                # Handle escape key for back navigation
                if (hasattr(self, 'full_weather_widget') and 
                    self.full_weather_widget and
                    obj == self.full_weather_widget and 
                    event.key() == Qt.Key_Escape):
                    self.show_main_view()
                    return True
                
                # Handle Shift+Up/Down for moving cities in the main city list
                if obj == self.city_list and hasattr(self, 'city_list'):
                    modifiers = event.modifiers()
                    key = event.key()
                    
                    if modifiers & Qt.ShiftModifier:
                        if key == Qt.Key_Up:
                            self.move_city_up()
                            return True
                        elif key == Qt.Key_Down:
                            self.move_city_down()
                            return True
                
                # Handle Ctrl+Up/Down for section navigation in the full weather list
                if (hasattr(self, 'full_weather_display') and 
                    self.full_weather_display and
                    obj == self.full_weather_display):
                    
                    modifiers = event.modifiers()
                    key = event.key()
                    
                    if modifiers & Qt.ControlModifier:
                        if key == Qt.Key_Up:
                            self.navigate_to_previous_section()
                            return True
                        elif key == Qt.Key_Down:
                            self.navigate_to_next_section()
                            return True
                    
                    # Handle escape key from the list widget too
                    if key == Qt.Key_Escape:
                        self.show_main_view()
                        return True
        except Exception as e:
            # Log the error but don't crash the app
            print(f"Event filter error: {e}")
            if hasattr(self, 'status_bar'):
                self.status_bar.showMessage(f"Keyboard shortcut error: {str(e)}")
        
        return super().eventFilter(obj, event)
    
    # Utility functions
    def celsius_to_fahrenheit(self, celsius: float) -> float:
        return (celsius * 9 / 5) + 32
    
    def calculate_feels_like(self, temp_c: float, wind_kmh: float, humidity: float) -> float:
        """Calculate feels like temperature using wind chill and heat index formulas"""
        temp_f = self.celsius_to_fahrenheit(temp_c)
        wind_mph = wind_kmh * KMH_TO_MPH
        
        # Use wind chill for cold temperatures (below 50°F/10°C)
        if temp_f <= 50:
            if wind_mph > 3:
                # Wind chill formula (in Fahrenheit)
                feels_like_f = (35.74 + (0.6215 * temp_f) - 
                               (35.75 * (wind_mph ** 0.16)) + 
                               (0.4275 * temp_f * (wind_mph ** 0.16)))
            else:
                feels_like_f = temp_f  # No wind chill at low wind speeds
        
        # Use heat index for warm temperatures (above 80°F/26.7°C)
        elif temp_f >= 80 and humidity >= 40:
            # Heat index formula (in Fahrenheit)
            feels_like_f = (-42.379 + 2.04901523 * temp_f + 10.14333127 * humidity -
                           0.22475541 * temp_f * humidity - 6.83783e-03 * temp_f**2 -
                           5.481717e-02 * humidity**2 + 1.22874e-03 * temp_f**2 * humidity +
                           8.5282e-04 * temp_f * humidity**2 - 1.99e-06 * temp_f**2 * humidity**2)
        else:
            # For moderate temperatures, feels like equals actual temperature
            feels_like_f = temp_f
        
        # Convert back to Celsius
        return (feels_like_f - 32) * 5 / 9
    
    def degrees_to_cardinal(self, degrees: float) -> str:
        directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        index = round(degrees / 45) % 8
        return directions[index]
    
    def weather_code_description(self, code: int) -> str:
        descriptions = {
            0: "Clear sky", 1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
            45: "Fog", 48: "Depositing rime fog",
            51: "Light drizzle", 53: "Moderate drizzle", 55: "Dense drizzle",
            56: "Light freezing drizzle", 57: "Dense freezing drizzle",
            61: "Slight rain", 63: "Moderate rain", 65: "Heavy rain",
            66: "Light freezing rain", 67: "Heavy freezing rain",
            71: "Slight snow", 73: "Moderate snow", 75: "Heavy snow",
            77: "Snow grains",
            80: "Slight rain showers", 81: "Moderate rain showers", 82: "Violent rain showers",
            85: "Slight snow showers", 86: "Heavy snow showers",
            95: "Thunderstorm",
            96: "Thunderstorm with slight hail", 99: "Thunderstorm with heavy hail"
        }
        return descriptions.get(code, "Unknown conditions")
    
    def format_full_weather(self, city_name: str, data: dict) -> str:
        """Format full weather information using configuration"""
        result = [f"Full Weather Report for {city_name}"]
        result.append("=" * 50)
        result.append("")
        
        # Current weather
        current_weather = data.get("current_weather", {})
        if current_weather:
            result.append("CURRENT WEATHER")
            result.append("-" * 20)
            
            temp_c = current_weather.get("temperature", 0)
            temp_f = self.celsius_to_fahrenheit(temp_c)
            wind_kmh = current_weather.get("windspeed", 0)
            wind_mph = wind_kmh * KMH_TO_MPH
            wind_dir = current_weather.get("winddirection", 0)
            wind_cardinal = self.degrees_to_cardinal(wind_dir)
            weather_code = current_weather.get("weathercode", 0)
            conditions = self.weather_code_description(weather_code)
            
            # Calculate feels like temperature
            feels_like_c = self.calculate_feels_like(temp_c, wind_kmh, 50)  # Assume 50% humidity
            feels_like_f = self.celsius_to_fahrenheit(feels_like_c)
            
            # Display configured current weather items
            current_config = self.weather_config['current']
            
            if current_config.get('temperature', True):
                result.append(f"Temperature: {temp_f:.1f}°F ({temp_c:.1f}°C)")
            
            if current_config.get('feels_like', True):
                result.append(f"Feels Like: {feels_like_f:.1f}°F ({feels_like_c:.1f}°C)")
            
            result.append(f"Conditions: {conditions}")  # Always show conditions
            
            if current_config.get('wind_speed', True) and current_config.get('wind_direction', True):
                result.append(f"Wind: {wind_mph:.1f} mph {wind_cardinal} ({wind_dir}°)")
            elif current_config.get('wind_speed', True):
                result.append(f"Wind Speed: {wind_mph:.1f} mph")
            elif current_config.get('wind_direction', True):
                result.append(f"Wind Direction: {wind_cardinal} ({wind_dir}°)")
            
            if current_config.get('humidity', True):
                # For current weather, we don't have humidity from the API, so we note this
                result.append("Humidity: See hourly data for humidity details")
            
            if current_config.get('precipitation', True):
                result.append("Precipitation: See hourly data for precipitation details")
                
            result.append("")
        
        # Hourly forecast (next 12 hours)
        hourly = data.get("hourly", {})
        if hourly and hourly.get("time"):
            hourly_config = self.weather_config['hourly']
            
            # Check if any hourly options are enabled
            if any(hourly_config.values()):
                result.append("12-HOUR FORECAST")
                result.append("-" * 20)
                
                times = hourly.get("time", [])
                temps = hourly.get("temperature_2m", [])
                apparent_temps = hourly.get("apparent_temperature", [])
                humidity = hourly.get("relative_humidity_2m", [])
                precip = hourly.get("precipitation", [])
                wind_speeds = hourly.get("windspeed_10m", [])
                wind_dirs = hourly.get("winddirection_10m", [])
                
                # Find the current hour index
                current_weather = data.get("current_weather", {})
                api_current_time = current_weather.get("time", "")
                start_index = 0
                
                if api_current_time:
                    try:
                        api_time = datetime.strptime(api_current_time, "%Y-%m-%dT%H:%M")
                        for i, time_str in enumerate(times):
                            try:
                                forecast_time = datetime.strptime(time_str, "%Y-%m-%dT%H:%M")
                                if forecast_time >= api_time:
                                    start_index = i
                                    break
                            except:
                                continue
                    except:
                        start_index = 0
                
                # Get next 12 hours
                end_index = min(start_index + 12, len(times))
                
                for i in range(start_index, end_index):
                    time_str = self.format_time(times[i], with_date=False)
                    hourly_line = [time_str + ":"]
                    
                    if hourly_config.get('temperature', True) and i < len(temps):
                        temp_f = self.celsius_to_fahrenheit(temps[i])
                        hourly_line.append(f"{temp_f:.0f}°F")
                    
                    if hourly_config.get('feels_like', False) and i < len(apparent_temps):
                        if apparent_temps[i] is not None:
                            feels_like_f = self.celsius_to_fahrenheit(apparent_temps[i])
                            hourly_line.append(f"feels {feels_like_f:.0f}°F")
                    
                    if hourly_config.get('humidity', False) and i < len(humidity):
                        hourly_line.append(f"{humidity[i]:.0f}% humidity")
                    
                    if hourly_config.get('precipitation', True) and i < len(precip):
                        prec_in = precip[i] * MM_TO_INCHES
                        hourly_line.append(f"{prec_in:.2f}\" rain")
                    
                    if hourly_config.get('wind_speed', False) and i < len(wind_speeds):
                        wind_mph = wind_speeds[i] * KMH_TO_MPH
                        wind_info = f"{wind_mph:.0f} mph"
                        
                        if hourly_config.get('wind_direction', False) and i < len(wind_dirs):
                            wind_card = self.degrees_to_cardinal(wind_dirs[i])
                            wind_info += f" {wind_card}"
                        
                        hourly_line.append(wind_info)
                    elif hourly_config.get('wind_direction', False) and i < len(wind_dirs):
                        wind_card = self.degrees_to_cardinal(wind_dirs[i])
                        hourly_line.append(f"from {wind_card}")
                    
                    result.append(" ".join(hourly_line))
                
                result.append("")
        
        # Daily forecast
        daily = data.get("daily", {})
        if daily and daily.get("time"):
            daily_config = self.weather_config['daily']
            
            # Check if any daily options are enabled
            if any(daily_config.values()):
                result.append("7-DAY FORECAST")
                result.append("-" * 20)
                
                times = daily.get("time", [])
                max_temps = daily.get("temperature_2m_max", [])
                min_temps = daily.get("temperature_2m_min", [])
                sunrise_times = daily.get("sunrise", [])
                sunset_times = daily.get("sunset", [])
                precip_sums = daily.get("precipitation_sum", [])
                
                for i in range(min(len(times), 7)):
                    date_str = self.format_date(times[i])
                    result.append(f"{date_str}:")
                    
                    temp_line = []
                    if daily_config.get('temperature_max', True) and i < len(max_temps):
                        max_f = self.celsius_to_fahrenheit(max_temps[i])
                        temp_line.append(f"High: {max_f:.0f}°F")
                    
                    if daily_config.get('temperature_min', True) and i < len(min_temps):
                        min_f = self.celsius_to_fahrenheit(min_temps[i])
                        temp_line.append(f"Low: {min_f:.0f}°F")
                    
                    if temp_line:
                        result.append(f"  {' '.join(temp_line)}")
                    
                    sun_line = []
                    if daily_config.get('sunrise', True) and i < len(sunrise_times):
                        sunrise = self.format_time(sunrise_times[i], with_date=False)
                        sun_line.append(f"Sunrise: {sunrise}")
                    
                    if daily_config.get('sunset', True) and i < len(sunset_times):
                        sunset = self.format_time(sunset_times[i], with_date=False)
                        sun_line.append(f"Sunset: {sunset}")
                    
                    if sun_line:
                        result.append(f"  {' '.join(sun_line)}")
                    
                    if daily_config.get('precipitation_sum', True) and i < len(precip_sums):
                        precip_in = precip_sums[i] * MM_TO_INCHES
                        result.append(f"  Precipitation: {precip_in:.2f}\"")
                    
                    result.append("")
        
        result.append(f"Report generated: {datetime.now().strftime('%Y-%m-%d %I:%M %p')}")
        
        return "\n".join(result)
    
    def format_time(self, time_str: str, with_date: bool = True) -> str:
        """Format ISO time string"""
        try:
            dt = datetime.strptime(time_str, "%Y-%m-%dT%H:%M")
            if with_date:
                return dt.strftime("%A, %m/%d %I:%M %p")
            else:
                return dt.strftime("%I:%M %p")
        except:
            return time_str
    
    def format_date(self, date_str: str) -> str:
        """Format date string"""
        try:
            dt = datetime.strptime(date_str, "%Y-%m-%d")
            return dt.strftime("%A, %B %d")
        except:
            return date_str


def main():
    """Main function to run the accessible weather application"""
    # Enable high DPI scaling before creating QApplication
    QApplication.setAttribute(Qt.AA_EnableHighDpiScaling, True)
    QApplication.setAttribute(Qt.AA_UseHighDpiPixmaps, True)
    
    app = QApplication(sys.argv)
    
    # Set application properties for accessibility
    app.setApplicationName("FastWeather")
    app.setApplicationDisplayName("FastWeather - Accessible Weather App")
    app.setApplicationVersion("2.0")
    app.setOrganizationName("FastWeather")
    
    # Create and show main window
    window = AccessibleWeatherApp()
    window.show()
    
    # Run the application
    sys.exit(app.exec_())


if __name__ == "__main__":
    main()
