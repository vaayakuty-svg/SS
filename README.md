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

### `Experts/GoldBasketV3.mq5` — XAU/USD M1 Grid-Basket Scalper

Written from scratch to work like the "Gold V3 MT5" EA shown in the @goldv3mt5 Instagram reels. Its source isn't public, so this copies only what the recordings show: XAUUSD M1 strategy-tester runs, a grid step of about $2.21, lots going up 0.01, 0.01, 0.02, 0.02, 0.03, 0.05, 0.08, 0.11, separate buy and sell baskets, no stop loss per order, and each basket closed all at once at a net profit.

**Entry (first order of a basket, checked on each closed M1 bar)**
- Buy: close above the 200 EMA, 9 EMA above 21 EMA and rising, bullish candle closing above the 9 EMA, RSI(14) > 52
- Sell: the mirror image (RSI < 48)

**Grid**
- Adds an order each time price moves `InpGridStepPrice` (default 2.21) against the newest order
- Lot per level comes from `InpLotSequence` (the default copies the observed martingale sequence); `InpLotScale` scales it
- Max 8 orders per basket. Buy and sell baskets run separately (`InpHedgeMode`)

**Exit**
- Basket take profit = total lots × `InpTPPerLot` (default: 0.01 lot → 1.00), at least `InpMinTPMoney`
- **Safety stops the original doesn't appear to have:** basket money stop (default 100) and basket drawdown stop (default 5% of balance). Setting both to 0 makes it work like the original with no stop. That is how martingale grids wipe out accounts.

**Filters:** max spread 40 points, trading hours 02–22 server time, daily loss limit 5%, max 200 baskets per day.

> A martingale grid wins small amounts often and loses big amounts rarely. A strong one-way gold move of $15–20 fills all 8 levels (0.33 lots). Backtest with "Every tick based on real ticks" over months, not one day like the reels, and run on demo first.

## Installation

1. Copy the EA file to your MetaTrader 5 `Experts` folder
2. Restart MetaTrader 5
3. Enable automated trading and run on a demo account first
4. Backtest and optimize parameters for your trading style

## Risk Disclaimer

High-profit strategies come with higher risks. Never risk more than 1-2% of your account balance on a single trade. Always test thoroughly on a demo account before trading live.
