# 📈 Supply & Demand Trading Bot (MQL5)

This is an MQL5-based trading bot designed to automate trading decisions using supply and demand zones, fakeout detection, candlestick patterns (bullish/bearish engulfing), and risk management strategies.

## 🚀 Features

- Auto-buy/sell based on price breakouts and key levels
- Engulfing candlestick pattern detection (H1)
- Dynamic lot sizing using risk percentage
- Local and Google Sheets trade logging
- Spread and trade condition filtering
- Trailing Stop Loss for locking in profits
- Trade duplication prevention
- Handles invalid volume and stop-level errors gracefully

## 📂 Files

- `SND_Bot.mq5`: Main bot logic
- `Logs.csv`: Auto-generated trade log stored locally in the `MQL5/Files` folder

## 🛠️ How to Install

1. Open MetaTrader 5.
2. Go to `File > Open Data Folder`.
3. Navigate to: `MQL5 > Experts`
4. Clone or download this repository and place `SND_Bot.mq5` inside the `Experts` folder.
5. Compile it via MetaEditor.
6. Attach the bot to any chart and enable AutoTrading.

## ⚙️ Inputs

| Parameter           | Description                           |
|---------------------|---------------------------------------|
| `LotSize`           | Default trade size                    |
| `StopLossPips`      | Stop loss in pips                     |
| `TakeProfitPips`    | Take profit in pips                   |
| `RiskPercentage`    | Risk per trade based on balance (%)   |
| `FakeoutThreshold`  | Points beyond S&D level for fakeout   |

## 📡 Google Sheets Logging

The bot sends trade data to a Google Apps Script endpoint:
https://script.google.com/
You can replace this with your own Apps Script URL for privacy.

## 📝 Local Logging

Trades are also saved to `Logs.csv`, located at:


## 📌 Notes

- The bot only executes one trade per symbol at a time to prevent duplicates.
- It waits 5 minutes between trades (`CanTrade()` cooldown).
- Trade entries will fail gracefully with clear logs when conditions are not met.

## 📧 Notifications

A notification is sent on successful trade execution. Ensure push notifications are enabled in MT5 settings.

## 🔒 Risk Warning

Use this bot on a demo account before applying it to live markets. Always ensure your strategy is tested and your risk appetite is clearly defined.

---

## 🤝 Contributing

Pull requests are welcome! If you find bugs or have suggestions, please open an issue.

## 📜 License

MIT License — see [`LICENSE`](LICENSE) for details.
