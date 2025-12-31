# MarketRange ADR

Professional Average Daily Range (ADR) tracker for MetaTrader 4.

MarketRange ADR is a comprehensive tool designed to help traders track market volatility and daily range expansions. Unlike standard ADR indicators, it includes critical metrics like the Daily Open, Mid-point levels, and dual-percentage tracking to show exactly where the price sits relative to its expected daily movement.

## Features

- **Daily Open Tracking**: Clearly marks the start of the trading day.
- **ADR High & Low Levels**: Automatically calculates and plots ATR-based range targets.
- **ADR Mid-Point**: Displays the average of the High and Low targets for added context.
- **Dual Percentage Metrics**: See both "Up size" and "Down size" percentages (e.g., 50/50 means price is at the mid-point).
- **Customizable Timezones**: Adjust for Data and Session offsets.
- **Visual Alerts**: Lines change color and thickness when the ADR target is hit.
- **Email Alerts**: Get notified exactly when a range target is reached.

## Installation

1. Download the `MarketRange_ADR.mq4` file.
2. Open MetaTrader 4.
3. Go to `File` > `Open Data Folder`.
4. Navigate to `MQL4` > `Indicators`.
5. Paste the file into the folder.
6. Restart MT4 or refresh the Indicators list in the Navigator.

## Parameters

- `TimeZoneOfData`: Your broker's chart time zone (GMT offset).
- `TimeZoneOfSession`: Your target session time zone (GMT offset).
- `ATRPeriod`: The number of days used to calculate the average range (default: 15).
- `LineColorOpen`: Color for the Daily Open price line.
- `LineColorMid`: Color for the average ADR mid-point line.
- `SendEmailAlert`: Enable/disable email notifications on range hits.

## License

MIT License - feel free to use and modify for your own trading!
