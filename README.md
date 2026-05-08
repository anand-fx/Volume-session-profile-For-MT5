# Volume-session-profile-For-MT5
Volume session profile indicator using Market tick volume.

What It Does ?
This is a Volume Profile indicator for MetaTrader 5 that analyzes the previous trading session (specifically the NYSE/NASDAQ session starting at 9:30 AM New York time) and maps out where the most trading volume occurred across different price levels. It then highlights three critical price zones that professional traders use to make decisions.


Instead of showing volume over time (like a standard volume bar), a Volume Profile shows volume at price. It answers the question: "At which price level did the market spend the most time and trade the most volume yesterday?"
The indicator divides the session's price range into 400 bins (price buckets) and distributes tick volume across them, producing a horizontal histogram on the chart.


The Three Key Levels It Produces
POC (Point of Control)The single price bin with the highest volume — where the market found the most agreement
VAH (Value Area High)The upper boundary of the zone containing 70% of all session volume
VAL (Value Area Low)The lower boundary of that same 70% zone

Demonstartion Video : 


https://github.com/user-attachments/assets/0fb1b843-c872-4731-8822-150c7f174085




NOTE : This shows Previous days volume session Not present. The live Tick volume based indicator is under development.This is the First version I've developed.

Best Features
1. Auto DST-Aware New York Time Conversion
The indicator correctly handles Daylight Saving Time transitions automatically. It calculates whether New York is on EDT (UTC−4) or EST (UTC−5) and adjusts the session window accordingly — a detail most retail indicators get wrong, leading to misaligned session data.
2. Accurate Volume Distribution Algorithm
Rather than dumping all of a candle's volume into a single bin, it splits volume between the upper and lower halves of each candle proportionally based on where the close was relative to the high/low. This is a much more realistic approximation of where volume actually occurred within each bar.
3. Clean Visual Histogram
The horizontal histogram uses color-coded bars — yellow for the POC bin, blue for all Value Area bins, and gray for outside the Value Area — giving an immediate visual read of the profile shape at a glance.
4. Persistent Live Dashboard
A formatted on-chart dashboard (via Comment()) shows the current timezone, the exact session start/end timestamps, and live VAH/POC/VAL/Bid prices — all updating on every tick.
6. Session Boundary Markers
A dashed vertical line marks the previous session's open and a solid line marks its close, so you always know exactly which price action the profile was built from.
7. Efficient Redraw Logic
The indicator only recalculates on a new bar open (barTime != g_LastBarTime), not on every tick — keeping CPU load minimal on live charts while still refreshing the dashboard in real time.
