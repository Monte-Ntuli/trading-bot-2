# Supply & Demand Trading Bot (MQL5)

A MetaTrader 5 Expert Advisor (EA) that automates trading decisions based on supply and demand zones, fakeout detection, candlestick patterns, and robust risk management.

---

## 📈 Features

* **Supply & Demand Zones**: Identifies key support and resistance areas.
* **Fakeout Detection**: Filters out false breakouts beyond a configurable threshold.
* **Candlestick Patterns**: Detects bullish and bearish engulfing patterns on the H1 timeframe.
* **Dynamic Risk Management**:

  * Lot sizing by percentage of account balance.
  * Configurable stop loss and take profit in pips.
  * Trailing Stop Loss to lock in profits.
* **Trade Filtering**:

  * Minimum spread and other custom conditions.
  * Prevents duplicate trades on the same symbol.
* **Logging**:

  * Local CSV logging (`Logs.csv`).
  * Remote logging via Google Sheets (replaceable Apps Script URL).
* **Error Handling**: Gracefully handles invalid volume, stop-level errors, and other execution issues.
* **Notifications**: Sends MT5 push notifications on trade execution.

---

## 🛠️ Requirements

* MetaTrader 5 build 3300 or later
* A Google account (for remote logging, optional)

---

## 🚀 Installation

1. **Download or clone this repository**:

   ```bash
   git clone https://github.com/Monte-Ntuli/trading-bot-2.git
   ```
2. **Open MetaTrader 5** and select **File > Open Data Folder**.
3. Navigate to **MQL5/Experts/** and copy `SND_Bot.mq5` into that folder.
4. Launch **MetaEditor**, open `SND_Bot.mq5`, and click **Compile**.
5. In MT5, open any chart, drag **SND\_Bot** from the Navigator onto it, and enable **AutoTrading**.

---

## ⚙️ Input Parameters

| Parameter          | Description                                                 | Default |
| ------------------ | ----------------------------------------------------------- | ------- |
| `LotSize`          | Fixed lot size (if `RiskPercentage` is 0)                   | `0.01`  |
| `RiskPercentage`   | Risk per trade as % of balance (overrides `LotSize` if > 0) | `1.0`   |
| `StopLossPips`     | Stop Loss distance in pips                                  | `50`    |
| `TakeProfitPips`   | Take Profit distance in pips                                | `100`   |
| `FakeoutThreshold` | Extra points beyond zone to confirm genuine breakouts       | `10`    |
| `MinSpread`        | Minimum spread (in pips) to allow trading                   | `2`     |
| `CooldownMinutes`  | Minutes to wait between trades on the same symbol           | `5`     |
| `GoogleScriptURL`  | Your Google Apps Script Web App endpoint for remote logging | (blank) |

> **Tip**: Leave `GoogleScriptURL` blank to disable remote logging.

---

## 📊 Logging

### Local CSV

* All trades are appended to `Logs.csv` in `MQL5/Files/`.
* Includes timestamp, symbol, direction, entry/exit prices, profit, and error messages.

### Google Sheets

1. Create a Google Apps Script Web App that accepts POST requests.
2. Set `GoogleScriptURL` to your Web App URL in the EA inputs.
3. The EA will send trade details as JSON payload.

---

## ⚠️ Risk Warning

Trading involves significant risk. Backtest and demo-test this EA thoroughly before applying it to a live account. Only trade amounts you can afford to lose.

---

## 🛠️ Troubleshooting

* **Compilation errors**: Ensure you’re using the latest MetaEditor.
* **Invalid volume / stop-level errors**: Adjust `LotSize` or chart symbol settings.
* **Missing logs**: Check file permissions in the `MQL5/Files/` folder.
* **Google Sheets not updating**: Verify your Apps Script and CORS settings.

---

## 🤝 Contributing

Contributions are welcome! Please fork the repo and open a pull request:

1. Fork this repository.
2. Create a feature branch (`git checkout -b feature/YourFeature`).
3. Commit your changes (`git commit -m "Add YourFeature"`).
4. Push to the branch (`git push origin feature/YourFeature`).
5. Open a Pull Request and describe your changes.

---

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

## ✉️ Contact

For questions or support, reach out to **Monte Ntuli**:

* Email: `youremail@example.com`

*Happy trading!*

