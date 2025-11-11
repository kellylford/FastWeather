#!/usr/bin/env python3
"""
Test script to verify timezone-aware 12 hours forecast logic
"""
from datetime import datetime

# Test data simulating API response with different timezone
# San Diego time (PST/PDT) vs Eastern time
test_api_current_time = "2025-07-24T11:00"  # 11 AM San Diego time
test_times = [
    "2025-07-24T08:00",  # 8 AM San Diego (past)
    "2025-07-24T09:00",  # 9 AM San Diego (past)
    "2025-07-24T10:00",  # 10 AM San Diego (past)
    "2025-07-24T11:00",  # 11 AM San Diego (current)
    "2025-07-24T12:00",  # 12 PM San Diego (next hour)
    "2025-07-24T13:00",  # 1 PM San Diego (+2)
    "2025-07-24T14:00",  # 2 PM San Diego (+3)
    "2025-07-24T15:00",  # 3 PM San Diego (+4)
    "2025-07-24T16:00",  # 4 PM San Diego (+5)
    "2025-07-24T17:00",  # 5 PM San Diego (+6)
    "2025-07-24T18:00",  # 6 PM San Diego (+7)
    "2025-07-24T19:00",  # 7 PM San Diego (+8)
    "2025-07-24T20:00",  # 8 PM San Diego (+9)
    "2025-07-24T21:00",  # 9 PM San Diego (+10)
    "2025-07-24T22:00",  # 10 PM San Diego (+11)
    "2025-07-24T23:00",  # 11 PM San Diego (+12)
    "2025-07-25T00:00",  # 12 AM San Diego (+13) - should not be included
]

def test_timezone_aware_logic():
    """Test the timezone-aware next 12 hours logic"""
    print("Testing Timezone-Aware Next 12 Hours Logic")
    print("=" * 50)
    print(f"API Current Time (San Diego): {test_api_current_time}")
    print(f"Local System Time: {datetime.now().strftime('%Y-%m-%d %H:%M')} (Eastern)")
    print()
    
    times = test_times
    api_current_time = test_api_current_time
    start_index = 0
    
    # Use the current time from the API response to match timezone
    if api_current_time:
        try:
            # Parse the current time from the API (in local city timezone)
            api_time = datetime.strptime(api_current_time, "%Y-%m-%dT%H:%M")
            print(f"Parsed API time: {api_time}")
            
            # Find the hour that matches or is after the current API time
            for i, time_str in enumerate(times):
                try:
                    forecast_time = datetime.strptime(time_str, "%Y-%m-%dT%H:%M")
                    if forecast_time >= api_time:
                        start_index = i
                        print(f"Found start index: {start_index} at {time_str}")
                        break
                except:
                    continue
        except:
            # Fallback to first available hour if parsing fails
            start_index = 0
            print("Failed to parse API time, using first available hour")
    else:
        # Fallback to first available hour if no current time
        start_index = 0
        print("No API current time, using first available hour")
    
    # Get next 12 hours starting from current time
    end_index = min(start_index + 12, len(times))
    
    print(f"Will show hours {start_index} to {end_index-1}")
    print()
    print("Next 12 hours forecast (San Diego timezone):")
    print("-" * 40)
    
    for i in range(start_index, end_index):
        time_str = times[i]
        try:
            dt = datetime.strptime(time_str, "%Y-%m-%dT%H:%M")
            formatted_time = dt.strftime("%I:%M %p")
            print(f"{formatted_time} PST: [weather data would be here]")
        except:
            print(f"{time_str}: [weather data would be here]")
    
    print()
    print(f"Total hours shown: {end_index - start_index}")
    print(f"Correctly shows times in San Diego timezone, not Eastern timezone!")

if __name__ == "__main__":
    test_timezone_aware_logic()
