# MetaTrader 5 High-Profit Trading Strategies EA

This repository contains professional MetaTrader 5 Expert Advisors (EAs) implementing high-profit trading strategies including:

1. **High-Probability Breakout Strategy** - Trade aggressive breakouts from consolidation zones
2. **Scalping with Order Flow & Volume Spread Analysis (VSA)** - Capture quick moves using volume analysis
3. **Mean Reversion Strategy** - Trade extreme price moves back to average
4. **Advanced Hedging & Grid Strategy** - Martingale-based automated trading

## Features

- **Risk Management**: Automatic position sizing (1-2% risk per trade)
- **Multiple Timeframes**: Optimized for M1, M5, M15 charts
- **Volume Analysis**: Integrated VSA and institutional order flow detection
- **Demo Mode**: Test on demo accounts before live trading
- **Customizable Parameters**: Easily adjust all strategy parameters

## Installation

1. Copy the EA file to your MetaTrader 5 `Experts` folder
2. Restart MetaTrader 5
3. Enable automated trading and run on a demo account first
4. Backtest and optimize parameters for your trading style

## Risk Disclaimer

High-profit strategies come with higher risks. Never risk more than 1-2% of your account balance on a single trade. Always test thoroughly on a demo account before trading live.

## SaveEA – XAUUSD M1 Tick-Momentum Scalper

File: `Experts/SaveEA.mq5`

A fast scalper built for gold (XAUUSD) on the M1 chart:

- **Entry**: opens a buy or sell when price moves at least `InpTriggerPoints` within `InpMomentumSeconds` and is still near the high or low of that move.
- **Exit**: places a tight initial stop-loss, moves it to break-even, then trails it behind price. An optional take-profit and a maximum holding time are available.
- **Sizing**: fixed lots (0.01 by default) or a percentage of equity at risk per trade.
- **Protection**: spread filter, trading-hours window, cooldown between entries, maximum open positions, and daily loss and profit limits.
- Each trade carries its own magic number, so the EA leaves manual trades and other EAs alone.

Usage: copy `SaveEA.mq5` to `MQL5/Experts/`, compile it in MetaEditor, and attach it to an XAUUSD M1 chart. Before trading live, backtest with **"Every tick based on real ticks"**. Results from the other modelling modes are unreliable for tick scalpers, and small accounts ($3–$10) will often be too small for broker margin and stop-out rules.

### Exness Standard preset

`Presets/SaveEA_Exness_Standard.set` adjusts SaveEA for an Exness Standard account (symbol `XAUUSDm`, no commission, wider gold spread). To load it, open the EA's **Inputs** tab, click **Load**, and pick the file. Before using it, check the gold spread in Market Watch and set `InpMaxSpreadPoints` a bit above it. With a 700-point stop, each 0.01-lot loss is about $7, so on a $10–$20 balance use a Standard Cent account or a demo instead.
