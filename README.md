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

## Included EAs

### `Experts/GoldScalperATR.mq5` — XAU/USD M1 Scalper

A transparent ATR breakout scalper for gold on the 1-minute chart. Every rule is in the source.

**Entry (evaluated once per closed M1 bar)**
- Trend: on the trend timeframe (default M15), close above a rising 50 EMA → longs only; below a falling one → shorts only
- M1 close on the trend side of the 21 EMA
- Breakout: M1 close beyond the high/low of the previous 15 bars
- Volatility: ATR(14) at least 1.1× its 50-bar average

**Exits**
- Stop loss 1.5× ATR, take profit 2.0× ATR
- Breakeven (+20 points) once profit reaches 1× ATR, then trails at 1× ATR

**Risk controls**
- Position size = 1% of balance at the stop (skips the trade if the minimum lot would risk more)
- One position at a time, 5-bar cooldown after an entry
- Max 10 entries and 3% loss per server day
- Max spread 35 points; trades only 08:00–20:00 server time (adjust to your broker's clock)

All values are inputs. Backtest in the Strategy Tester ("Every tick based on real ticks") and run on demo before going live.

### `Experts/GoldSessionBreakout.mq5` — XAU/USD Asian-range breakout

Trades the breakout of the quiet Asian session into the London/New York sessions. One trade per day at most, no grid or martingale. Works on any chart timeframe (the range is read from M5 data).

**Entry**
- Range = high/low of 00:00–07:00 server time
- At 07:00 a buy-stop is placed 50 points above the range and a sell-stop 50 points below (OCO: when one fills, the other is deleted)
- Day is skipped if the range is narrower than 300 or wider than 2500 points, or if price has already broken out
- Optional trend filter: only buys above the H1 200 EMA, only sells below it

**Exits**
- Stop loss at the far side of the range, capped at 1500 points; take profit 1.5× the stop distance
- Breakeven (+20 points) once the trade is 1R in profit
- Untriggered orders deleted at 16:00; any open trade closed at 21:00

**Risk controls**
- Position size = 1% of balance at the stop (skips the day if the minimum lot would risk more)
- Max spread 40 points when placing orders; option to skip Fridays
- Remembers if it already traded today, even after a terminal restart

Hours are **server time** — check your broker's clock (many use GMT+2/+3) and shift them so the range covers the Asian session.

## Installation

1. Copy the EA file to your MetaTrader 5 `Experts` folder
2. Restart MetaTrader 5
3. Enable automated trading and run on a demo account first
4. Backtest and optimize parameters for your trading style

## Risk Disclaimer

High-profit strategies come with higher risks. Never risk more than 1-2% of your account balance on a single trade. Always test thoroughly on a demo account before trading live.
