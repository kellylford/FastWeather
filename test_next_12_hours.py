#!/usr/bin/env python3
"""
Test script to verify the next 12 hours forecast logic
"""
from datetime import datetime

# Test data simulating API response
test_times = [
    "2025-07-24T10:00",  # Past
    "2025-07-24T11:00",  # Past
    "2025-07-24T12:00",  # Past 
    "2025-07-24T13:00",  # Current/near current
    "2025-07-24T14:00",  # Next hour
    "2025-07-24T15:00",  # +2 hours
    "2025-07-24T16:00",  # +3 hours
    "2025-07-24T17:00",  # +4 hours
    "2025-07-24T18:00",  # +5 hours
    "2025-07-24T19:00",  # +6 hours
    "2025-07-24T20:00",  # +7 hours
    "2025-07-24T21:00",  # +8 hours
    "2025-07-24T22:00",  # +9 hours
    "2025-07-24T23:00",  # +10 hours
    "2025-07-25T00:00",  # +11 hours
    "2025-07-25T01:00",  # +12 hours
    "2025-07-25T02:00",  # +13 hours (should not be included)
]

def test_next_12_hours_logic():
    """Test the next 12 hours logic"""
    print("Testing Next 12 Hours Logic")
    print("=" * 40)
    
    # Simulate current time as 1:30 PM (13:30)
    current_time = datetime(2025, 7, 24, 13, 30)
    print(f"Current time: {current_time.strftime('%Y-%m-%d %H:%M')}")
    print()
    
    times = test_times
    start_index = 0
    
    # Find the current or next hour
    for i, time_str in enumerate(times):
        try:
            forecast_time = datetime.strptime(time_str, "%Y-%m-%dT%H:%M")
            if forecast_time >= current_time:
                start_index = i
                print(f"Found start index: {start_index} at {time_str}")
                break
        except:
            continue
    
    # Get next 12 hours starting from current time
    end_index = min(start_index + 12, len(times))
    
    print(f"Will show hours {start_index} to {end_index-1}")
    print()
    print("Next 12 hours forecast:")
    print("-" * 30)
    
    for i in range(start_index, end_index):
        time_str = times[i]
        try:
            dt = datetime.strptime(time_str, "%Y-%m-%dT%H:%M")
            formatted_time = dt.strftime("%I:%M %p")
            print(f"{formatted_time}: [weather data would be here]")
        except:
            print(f"{time_str}: [weather data would be here]")
    
    print()
    print(f"Total hours shown: {end_index - start_index}")

if __name__ == "__main__":
    test_next_12_hours_logic()
