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

## Installation

1. Copy the EA file to your MetaTrader 5 `Experts` folder
2. Restart MetaTrader 5
3. Enable automated trading and run on a demo account first
4. Backtest and optimize parameters for your trading style

## Risk Disclaimer

High-profit strategies come with higher risks. Never risk more than 1-2% of your account balance on a single trade. Always test thoroughly on a demo account before trading live.

## Neon Coast (open world game)

`game/index.html` is a self-contained 3D open world game that runs in the browser (Three.js, loaded from a CDN). It is set in the Sunline State, a sunny 1980s peninsula inspired by fan maps of GTA VI's Leonida. All names, places and code are original.

- **Neon Bay**, an art-deco city with pastel low-rises on Ocean Drive, glass towers, a park and a beach Ferris wheel; windows and neon light up at night
- **Highway 1** with traffic, running down the coast and across the **Coral Keys** on bridges to a lighthouse
- **Sawgrass Glades** swamp with cypress, gators and flamingos, **Lake Oki**, and the forested **Pine Ridge** with deer
- Drive any parked car (E), with a synthwave car radio (R)
- Take jobs (J): taxi fares in a car and timed courier runs on foot, paid in cash
- Fly the seaplane from the Neon Bay dock, or launch a scouting drone (Q) that can pick up tapes
- Pedestrians walk the sidewalks of Neon Bay
- Twelve mixtapes to find, marked by pink beams of light, a compass, a minimap and a full state map (M)
- An eight-minute day/night cycle, region names as you travel, keyboard and mouse or touch controls, and progress saved in the browser

Open `game/index.html` in a modern browser to play.

## GTA_SZ (深城纪)

`gta-sz/` is a git submodule linking to [linranff/GTA_SZ](https://github.com/linranff/GTA_SZ), a browser game set in Shenzhen. See [GTA_SZ.md](GTA_SZ.md) for how to run it, how it is built, and why it is linked rather than copied.

## Dustbound Frontier (Godot 4)

`dustbound-frontier/` is a Western open world prototype for Godot 4.3: an outlaw with a revolver, Copper the horse, a frontier town, a bandit camp and a first mission. Open `dustbound-frontier/project.godot` in Godot and press F5. See its [README](dustbound-frontier/README.md), the [Malayalam quick start](dustbound-frontier/docs/QUICK_START_MALAYALAM.md) and the [validation report](dustbound-frontier/docs/VALIDATION_REPORT.md).
