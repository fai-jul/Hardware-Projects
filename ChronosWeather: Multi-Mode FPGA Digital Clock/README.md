# ChronosWeather: Multi-Mode FPGA Digital Clock
**Course:** Digital Logic Design Laboratory (CSE 1204)
**Term:** 1st Year, 2nd Semester
**Project Date:** November 10, 2025

### Team Members
* **MD Faijul Islam** (Roll: [2307024)
* **Anirban Majumder Joy** (Roll: 2307023)

---

## 📌 Project Overview
ChronosWeather is a versatile digital clock system implemented on the Xilinx Basys 3 FPGA. It features multiple operational modes and integrates external data via Python-based UART communication. The system provides a seamless blend of hardware-level timing and software-level data fetching.

### Core Features
* **Stopwatch Mode:** High-precision count-up timer with start/stop/reset functionality.
* **Countdown Timer:** User-programmable countdown with a visual "finished" alert.
* **Smart Alarm:** Settable alarm time with persistent notification and a 1-minute auto-clear window.
* **Weather Integration:** Python script fetches real-time temperature data from OpenWeatherMap API and transmits it to the FPGA via UART.
* **Interactive Interface:** Full utilization of the 4-digit 7-segment display with multiplexing and button debouncing logic.

## 🛠️ Hardware Requirements
* **FPGA Board:** Basys 3 (Artix-7).
* **Display:** 4-Digit 7-Segment Display (Multiplexed).
* **Inputs:** 5 On-board Push Buttons (Reset, Mode, Set, Up, Down).
* **Communication:** Micro-USB cable for UART/JTAG.


## 💻 Software & Environment
* **HDL:** Verilog (Vivado 2023.1 or later).
* **Scripting:** Python 3.x (Requires `pyserial` and `requests` libraries).
* **API:** OpenWeatherMap API Key.

## 🚀 Setup & Execution

### 1. Hardware Implementation
1. Load `digital_clock.v` and `digital_clk.xdc` into a Xilinx Vivado project.
2. Generate Bitstream and program the Basys 3.
3. Use the **Center Button** to reset the system.

### 2. External Data Sync (UART)
1. Install dependencies: `pip install pyserial requests`.
2. Open `uart_sender.py` and update the `SERIAL_PORT` to match your device (e.g., `COM11` or `/dev/ttyUSB0`).
3. Add your OpenWeatherMap API key to `WEATHER_API_KEY`.
4. Run the script: `python uart_sender.py`.

## 🕹️ Controls
| Button | Function |
| :--- | :--- |
| **Center** | System Reset |
| **Up** | Mode Selection (Stopwatch ↔ Timer ↔ Alarm) |
| **Left** | Set/Confirm Selection |
| **Right** | Increment Value (Up) |
| **Down** | Decrement Value (Down) |
| **Switch 0** | Start/Stop (Stopwatch & Timer) |

---
*Developed as a part of the Digital Logic Design Laboratory requirement.*
