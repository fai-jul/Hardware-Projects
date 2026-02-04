import serial
import time
from datetime import datetime
import requests

# Configure UART settings (match with Basys 3)
# ============================================================
# ⚠️ CHANGE THIS LINE TO YOUR COM PORT! ⚠️
# Check Device Manager → Ports (COM & LPT) to find your port
# ============================================================
SERIAL_PORT = 'COM11'  # ← Change COM7 to YOUR port (COM3, COM4, COM5, etc.)
BAUD_RATE = 115200     # Must match UART module (868 clocks per bit)
TIMEOUT = 1

# ============================================================
# ⚠️ GET YOUR FREE API KEY FROM OPENWEATHERMAP ⚠️
# Sign up at: https://openweathermap.org/api
# Free tier: 1000 calls/day (we only call once every 10 minutes)
# ============================================================
WEATHER_API_KEY = ''  # ← Put your API key here
CITY_NAME = ''  # ← Change to your city
COUNTRY_CODE = ''  # ← Change to your country code (US, UK, BD, etc.)

# Cache weather data to avoid too many API calls
weather_cache = {'temp': 25.0, 'last_update': 0}
WEATHER_UPDATE_INTERVAL = 600  # Update every 10 minutes (600 seconds)

def get_weather_temperature():
    """Get current weather temperature from OpenWeatherMap API"""
    global weather_cache

    current_time = time.time()

    # Use cached temperature if recently updated
    if current_time - weather_cache['last_update'] < WEATHER_UPDATE_INTERVAL:
        return weather_cache['temp']

    # Check if API key is configured
    if WEATHER_API_KEY == 'YOUR_API_KEY_HERE':
        print("\n⚠️  Weather API key not configured!")
        print("   Using fallback temperature: 25°C")
        print("\n   To get real weather:")
        print("   1. Sign up at: https://openweathermap.org/api")
        print("   2. Get your free API key")
        print("   3. Replace 'YOUR_API_KEY_HERE' in the script")
        print("   4. Set your city and country code\n")
        return 25.0

    try:
        # OpenWeatherMap API endpoint
        url = f"http://api.openweathermap.org/data/2.5/weather"
        params = {
            'q': f'{CITY_NAME},{COUNTRY_CODE}',
            'appid': WEATHER_API_KEY,
            'units': 'metric'  # Get temperature in Celsius
        }

        # Make API request with timeout
        response = requests.get(url, params=params, timeout=5)

        if response.status_code == 200:
            data = response.json()
            temp = data['main']['temp']

            # Update cache
            weather_cache['temp'] = temp
            weather_cache['last_update'] = current_time

            # Optional: Print weather details
            weather_desc = data['weather'][0]['description']
            humidity = data['main']['humidity']
            print(f"\n🌤️  Weather Update: {temp:.1f}°C, {weather_desc}, Humidity: {humidity}%")

            return temp
        else:
            print(f"\n⚠️  Weather API error: {response.status_code}")
            return weather_cache['temp']  # Return last known temperature

    except requests.exceptions.Timeout:
        print("\n⚠️  Weather API timeout - using cached temperature")
        return weather_cache['temp']
    except requests.exceptions.RequestException as e:
        print(f"\n⚠️  Weather API connection error: {e}")
        return weather_cache['temp']
    except Exception as e:
        print(f"\n⚠️  Weather API error: {e}")
        return weather_cache['temp']

def format_data_packet():
    """
    Format data as 12 ASCII bytes: DDMMHHMMSSTT
    DD = Day (01-31)
    MM = Month (01-12)
    HH = Hours (00-23)
    MM = Minutes (00-59)
    SS = Seconds (00-59)
    TT = Temperature (00-99)
    """
    now = datetime.now()
    temp = get_weather_temperature()

    # Extract date and time components
    day = now.day
    month = now.month
    hours = now.hour
    minutes = now.minute
    seconds = now.second

    # Temperature as integer (0-99)
    # Handle negative temperatures by adding offset if needed
    if temp < 0:
        temp_int = 0  # Display 0 for negative temps
    else:
        temp_int = int(temp) % 100  # Ensure it's 2 digits

    # Format as 12 ASCII characters: DDMMHHMMSSTT
    packet = f"{day:02d}{month:02d}{hours:02d}{minutes:02d}{seconds:02d}{temp_int:02d}"

    return packet, day, month, hours, minutes, seconds, temp

def main():
    print("\n" + "="*70)
    print("  UART Date/Time/Weather Sender for Basys 3 FPGA")
    print("="*70)

    # Test weather API
    print(f"\n🌍 Location: {CITY_NAME}, {COUNTRY_CODE}")
    print("🌡️  Fetching current weather temperature...")
    test_temp = get_weather_temperature()
    print(f"   Current weather: {test_temp:.1f}°C")

    try:
        # Open serial port
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=TIMEOUT)
        print(f"\n✅ Connected to {SERIAL_PORT} at {BAUD_RATE} baud")
        print("\nData Format: DDMMHHMMSSTT (12 bytes)")
        print("  DD = Day, MM = Month, HH = Hours, MM = Minutes")
        print("  SS = Seconds, TT = Weather Temperature")
        print("\nSending data every 1 second...")
        print("Weather updates every 10 minutes to save API calls")
        print("Press Ctrl+C to stop.\n")
        print("-"*70)

        packet_count = 0

        while True:
            # Create data packet (12 bytes)
            packet, day, month, hours, minutes, seconds, temp = format_data_packet()

            # Send to FPGA (12 ASCII bytes)
            ser.write(packet.encode('ascii'))

            # Display what was sent
            print(f"[{packet_count:04d}] Sent: {packet} | "
                  f"Date: {day:02d}/{month:02d} | "
                  f"Time: {hours:02d}:{minutes:02d}:{seconds:02d} | "
                  f"Weather: {temp:.1f}°C")

            packet_count += 1

            # Wait before next transmission
            time.sleep(1)  # Send every 1 second

    except serial.SerialException as e:
        print(f"\n❌ Error: Could not open serial port {SERIAL_PORT}")
        print(f"Details: {e}")
        print("\n🔧 Troubleshooting Tips:")
        print("- Check if the correct COM port is selected")
        print("  Windows: Check Device Manager → Ports (COM & LPT)")
        print("  Linux: Usually /dev/ttyUSB0 or /dev/ttyUSB1")
        print("  Mac: Usually /dev/tty.usbserial-*")
        print("- Ensure FPGA board is connected via USB")
        print("- Close any other programs using the serial port")
        print("- Try a different USB port")

    except KeyboardInterrupt:
        print("\n\n✅ Transmission stopped by user")

    finally:
        if 'ser' in locals() and ser.is_open:
            ser.close()
            print("Serial port closed")

if __name__ == "__main__":
    print("\n" + "="*70)
    print("  Setup Check")
    print("="*70)
    print("\n📦 Required packages: pyserial, requests")
    print("   Install with: pip install pyserial requests\n")

    # Check if packages are installed
    missing_packages = []
    try:
        import serial
    except ImportError:
        missing_packages.append('pyserial')

    try:
        import requests
    except ImportError:
        missing_packages.append('requests')

    if missing_packages:
        print(f"⚠️  Missing packages: {', '.join(missing_packages)}")
        print(f"   Install with: pip install {' '.join(missing_packages)}\n")
    else:
        print("✅ All required packages installed\n")

    # List available serial ports
    try:
        import serial.tools.list_ports
        ports = serial.tools.list_ports.comports()
        if ports:
            print("📡 Available COM ports:")
            for port in ports:
                print(f"   • {port.device}: {port.description}")
            print()
        else:
            print("⚠️  No COM ports detected. Is your FPGA connected?\n")
    except:
        pass

    main()
