`timescale 1ns / 1ps

module digital_clock_top(
    input clk,
    input reset,
    input [4:0] btn,
    output [6:0] seg,
    output [3:0] an,
    output [15:0] led
    );
    
    // Button assignments
    wire btn_mode = btn[0];
    wire btn_set = btn[1];
    wire btn_up = btn[2];
    wire btn_down = btn[3];
    wire btn_start = btn[4];
    
    // Clock divider counters
    // Need 100,000,000 counts for 1 second
    reg [26:0] counter_1hz;
    // Need 100,000 counts for 1ms (1kHz refresh)
    reg [16:0] counter_refresh;
    reg [16:0] counter_debounce;
    reg clk_1hz_tick;
    reg clk_refresh_tick;
    reg clk_debounce_tick;
    
    // Time registers (for alarm only)
    reg [5:0] hours;
    reg [5:0] minutes;
    reg [5:0] seconds;
    
    // Timer registers
    reg [5:0] timer_min;
    reg [5:0] timer_sec;
    reg timer_running;
    reg timer_finished;
    
    // Stopwatch registers (minutes and seconds)
    reg [5:0] sw_min;
    reg [5:0] sw_sec;
    reg sw_running;
    
    // Alarm registers
    reg [5:0] alarm_hours;
    reg [5:0] alarm_minutes;
    reg alarm_enabled;
    reg alarm_triggered;
    
    // Mode control (0=Stopwatch, 1=Timer, 2=Alarm)
    reg [1:0] mode;
    reg [1:0] set_mode;
    
    // Display
    reg [3:0] digit0, digit1, digit2, digit3;
    reg [1:0] digit_select;
    reg [3:0] current_digit;
    
    // Button debouncing
    reg [3:0] btn_mode_sr, btn_set_sr, btn_up_sr, btn_down_sr, btn_start_sr;
    wire btn_mode_db = &btn_mode_sr;
    wire btn_set_db = &btn_set_sr;
    wire btn_up_db = &btn_up_sr;
    wire btn_down_db = &btn_down_sr;
    wire btn_start_db = &btn_start_sr;
    
    // Edge detection
    reg btn_mode_prev, btn_set_prev, btn_up_prev, btn_down_prev, btn_start_prev;
    wire btn_mode_edge = btn_mode_db && !btn_mode_prev;
    wire btn_set_edge = btn_set_db && !btn_set_prev;
    wire btn_up_edge = btn_up_db && !btn_up_prev;
    wire btn_down_edge = btn_down_db && !btn_down_prev;
    wire btn_start_edge = btn_start_db && !btn_start_prev;
    
    // Blink
    reg [9:0] blink_counter;
    wire blink = blink_counter[9];
    
    // LED assignments
    assign led[1:0] = mode;
    assign led[2] = (set_mode != 2'd0);
    assign led[3] = alarm_enabled;
    assign led[4] = alarm_triggered;
    assign led[5] = timer_running;
    assign led[6] = sw_running;
    assign led[7] = timer_finished;
    assign led[15:8] = 8'd0;
    
    // 1Hz clock generator (100MHz input)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter_1hz <= 27'd0;
            clk_1hz_tick <= 1'b0;
        end else begin
            // CORRECTION: For 100MHz clock, need 100,000,000 cycles.
            // Count from 0 up to 99,999,999.
            if (counter_1hz == 27'd99999999) begin 
                counter_1hz <= 27'd0;
                clk_1hz_tick <= 1'b1;
            end else begin
                counter_1hz <= counter_1hz + 1'b1;
                clk_1hz_tick <= 1'b0;
            end
        end
    end
    
    // Refresh clock (1kHz)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter_refresh <= 17'd0;
            clk_refresh_tick <= 1'b0;
        end else begin
            // CORRECTION: For 100MHz, need 100,000 cycles. Count from 0 to 99,999.
            if (counter_refresh == 17'd99999) begin 
                counter_refresh <= 17'd0;
                clk_refresh_tick <= 1'b1;
            end else begin
                counter_refresh <= counter_refresh + 1'b1;
                clk_refresh_tick <= 1'b0;
            end
        end
    end
    
    // Debounce clock (1kHz)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter_debounce <= 17'd0;
            clk_debounce_tick <= 1'b0;
        end else begin
            // CORRECTION: For 100MHz, need 100,000 cycles. Count from 0 to 99,999.
            if (counter_debounce == 17'd99999) begin 
                counter_debounce <= 17'd0;
                clk_debounce_tick <= 1'b1;
            end else begin
                counter_debounce <= counter_debounce + 1'b1;
                clk_debounce_tick <= 1'b0;
            end
        end
    end

    // Button debouncing
    always @(posedge clk) begin
        if (clk_debounce_tick) begin
            btn_mode_sr <= {btn_mode_sr[2:0], btn_mode};
            btn_set_sr <= {btn_set_sr[2:0], btn_set};
            btn_up_sr <= {btn_up_sr[2:0], btn_up};
            btn_down_sr <= {btn_down_sr[2:0], btn_down};
            btn_start_sr <= {btn_start_sr[2:0], btn_start};
        end
    end
    
    // Edge detection
    always @(posedge clk) begin
        btn_mode_prev <= btn_mode_db;
        btn_set_prev <= btn_set_db;
        btn_up_prev <= btn_up_db;
        btn_down_prev <= btn_down_db;
        btn_start_prev <= btn_start_db;
    end
    
    // Blink counter
    always @(posedge clk) begin
        if (clk_refresh_tick)
            blink_counter <= blink_counter + 1'b1;
    end
    
    // Main control logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset all registers
            hours <= 6'd0;
            minutes <= 6'd0;
            seconds <= 6'd0;
            timer_min <= 6'd1;
            timer_sec <= 6'd0;
            timer_running <= 1'b0;
            timer_finished <= 1'b0;
            sw_min <= 6'd0;
            sw_sec <= 6'd0;
            sw_running <= 1'b0;
            alarm_hours <= 6'd7;
            alarm_minutes <= 6'd0;
            alarm_enabled <= 1'b0;
            alarm_triggered <= 1'b0;
            mode <= 2'd0;
            set_mode <= 2'd0;
        end else begin
            // Mode switching (3 modes: Stopwatch, Timer, Alarm)
            if (btn_mode_edge && set_mode == 2'd0) begin
                mode <= (mode == 2'd2) ? 2'd0 : mode + 1'b1;
                timer_finished <= 1'b0;
                alarm_triggered <= 1'b0;
            end
            
            // Set button logic
            if (btn_set_edge) begin
                case (mode)
                    2'd0: begin // Stopwatch reset
                        if (!sw_running) begin
                            sw_min <= 6'd0;
                            sw_sec <= 6'd0;
                        end
                    end
                    2'd2: begin // Alarm setting
                        if (set_mode == 2'd0) begin
                            set_mode <= 2'd1;
                            alarm_triggered <= 1'b0;
                        end else if (set_mode == 2'd1) begin
                            set_mode <= 2'd2;
                        end else begin
                            set_mode <= 2'd0;
                            alarm_enabled <= 1'b1;
                        end
                    end
                endcase
            end
            
            // Up/Down button adjustments
            if (mode == 2'd1 && !timer_running) begin
                // Timer adjustment
                if (btn_up_edge) begin
                    if (timer_sec == 6'd59) begin
                        timer_sec <= 6'd0;
                        if (timer_min < 6'd59)
                            timer_min <= timer_min + 1'b1;
                    end else begin
                        timer_sec <= timer_sec + 1'b1;
                    end
                end
                if (btn_down_edge) begin
                    if (timer_sec == 6'd0) begin
                        if (timer_min > 6'd0) begin
                            timer_sec <= 6'd59;
                            timer_min <= timer_min - 1'b1;
                        end
                    end else begin
                        timer_sec <= timer_sec - 1'b1;
                    end
                end
            end else if (mode == 2'd2 && set_mode != 2'd0) begin
                // Alarm adjustment
                if (btn_up_edge) begin
                    if (set_mode == 2'd1)
                        alarm_hours <= (alarm_hours == 6'd23) ? 6'd0 : alarm_hours + 1'b1;
                    else if (set_mode == 2'd2)
                        alarm_minutes <= (alarm_minutes == 6'd59) ? 6'd0 : alarm_minutes + 1'b1;
                end
                if (btn_down_edge) begin
                    if (set_mode == 2'd1)
                        alarm_hours <= (alarm_hours == 6'd0) ? 6'd23 : alarm_hours - 1'b1;
                    else if (set_mode == 2'd2)
                        alarm_minutes <= (alarm_minutes == 6'd0) ? 6'd59 : alarm_minutes - 1'b1;
                end
            end
            
            // Background clock (for alarm checking)
            if (clk_1hz_tick) begin
                if (seconds == 6'd59) begin
                    seconds <= 6'd0;
                    if (minutes == 6'd59) begin
                        minutes <= 6'd0;
                        if (hours == 6'd23)
                            hours <= 6'd0;
                        else
                            hours <= hours + 1'b1;
                    end else begin
                        minutes <= minutes + 1'b1;
                    end
                end else begin
                    seconds <= seconds + 1'b1;
                end
                
                // Alarm check - trigger when time matches
                if (alarm_enabled && hours == alarm_hours && minutes == alarm_minutes && seconds == 6'd0) begin
                    alarm_triggered <= 1'b1;
                end
                
                // Auto-disable alarm trigger after 1 minute
                if (alarm_triggered && seconds == 6'd0 && minutes != alarm_minutes) begin
                    alarm_triggered <= 1'b0;
                end
            end
            
            // Timer control
            if (btn_start_edge && mode == 2'd1) begin
                if (timer_min == 6'd0 && timer_sec == 6'd0) begin
                    timer_running <= 1'b0;
                    timer_finished <= 1'b0;
                end else begin
                    timer_running <= ~timer_running;
                    timer_finished <= 1'b0;
                end
            end
            
            // Timer countdown (fixed to 1 second)
            if (timer_running && clk_1hz_tick) begin
                if (timer_sec == 6'd0) begin
                    if (timer_min == 6'd0) begin
                        timer_running <= 1'b0;
                        timer_finished <= 1'b1;
                    end else begin
                        timer_min <= timer_min - 1'b1;
                        timer_sec <= 6'd59;
                    end
                end else begin
                    timer_sec <= timer_sec - 1'b1;
                end
            end
            
            // Stopwatch control
            if (btn_start_edge && mode == 2'd0)
                sw_running <= ~sw_running;
            
            // Stopwatch count up (minutes and seconds)
            if (sw_running && clk_1hz_tick) begin
                if (sw_sec == 6'd59) begin
                    sw_sec <= 6'd0;
                    if (sw_min < 6'd59)
                        sw_min <= sw_min + 1'b1;
                end else begin
                    sw_sec <= sw_sec + 1'b1;
                end
            end
        end
    end
    
    // Display multiplexing
    always @(*) begin
        case (mode)
            2'd0: begin // Stopwatch
                digit3 = sw_min / 6'd10;
                digit2 = sw_min % 6'd10;
                digit1 = sw_sec / 6'd10;
                digit0 = sw_sec % 6'd10;
            end
            2'd1: begin // Timer
                digit3 = timer_min / 6'd10;
                digit2 = timer_min % 6'd10;
                digit1 = timer_sec / 6'd10;
                digit0 = timer_sec % 6'd10;
            end
            2'd2: begin // Alarm
                digit3 = alarm_hours / 6'd10;
                digit2 = alarm_hours % 6'd10;
                digit1 = alarm_minutes / 6'd10;
                digit0 = alarm_minutes % 6'd10;
            end
            default: begin
                digit3 = 4'd0;
                digit2 = 4'd0;
                digit1 = 4'd0;
                digit0 = 4'd0;
            end
        endcase
    end
    
    // Display refresh
    always @(posedge clk or posedge reset) begin
        if (reset)
            digit_select <= 2'd0;
        else if (clk_refresh_tick)
            digit_select <= digit_select + 1'b1;
    end
    
    // Current digit selection with blinking for set mode
    always @(*) begin
        case (digit_select)
            2'd0: current_digit = digit0;
            2'd1: current_digit = digit1;
            2'd2: current_digit = digit2;
            2'd3: current_digit = digit3;
        endcase
    end
    
    // Anode control with blinking support
    reg [3:0] anode;
    always @(*) begin
        anode = 4'b1111;
        
        // Blinking logic for alarm setting mode
        if (mode == 2'd2 && set_mode != 2'd0) begin
            if (blink) begin
                case (digit_select)
                    2'd0: anode = (set_mode == 2'd2) ? 4'b1111 : 4'b1110;
                    2'd1: anode = (set_mode == 2'd2) ? 4'b1111 : 4'b1101;
                    2'd2: anode = (set_mode == 2'd1) ? 4'b1111 : 4'b1011;
                    2'd3: anode = (set_mode == 2'd1) ? 4'b1111 : 4'b0111;
                endcase
            end else begin
                case (digit_select)
                    2'd0: anode = 4'b1110;
                    2'd1: anode = 4'b1101;
                    2'd2: anode = 4'b1011;
                    2'd3: anode = 4'b0111;
                endcase
            end
        end else begin
            // Normal display
            case (digit_select)
                2'd0: anode = 4'b1110;
                2'd1: anode = 4'b1101;
                2'd2: anode = 4'b1011;
                2'd3: anode = 4'b0111;
            endcase
        end
    end
    assign an = anode;
    
    // Segment decoder
    reg [6:0] segments;
    always @(*) begin
        case (current_digit)
            4'd0: segments = 7'b1000000;
            4'd1: segments = 7'b1111001;
            4'd2: segments = 7'b0100100;
            4'd3: segments = 7'b0110000;
            4'd4: segments = 7'b0011001;
            4'd5: segments = 7'b0010010;
            4'd6: segments = 7'b0000010;
            4'd7: segments = 7'b1111000;
            4'd8: segments = 7'b0000000;
            4'd9: segments = 7'b0010000;
            default: segments = 7'b1111111;
        endcase
    end
    assign seg = segments;
    
endmodule