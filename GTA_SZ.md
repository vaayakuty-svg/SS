# GTA_SZ (深城纪) in this repo

`gta-sz/` is a git submodule pointing to [linranff/GTA_SZ](https://github.com/linranff/GTA_SZ), a browser open world game set in Shenzhen. It is pinned to upstream commit `73603f3`. The project and all its assets belong to linranff and the ShenChengJi contributors.

## Why a submodule and not a copy

Its code is MIT-licensed, but its assets are not covered by that license. The two playable characters (Kuki Shinobu and Yelan) are miHoYo models adapted for MMD by 观海 (Guanhai), and their terms forbid redistribution. Map data from OpenStreetMap is ODbL, and other assets carry their own credits under `public/licenses/`.

Copying the files into this repo would redistribute those models. The submodule links to the original repository, so the files stay with the original authors and are downloaded from upstream when you set it up.

## Run it

You need Node.js 22 or newer and [Git LFS](https://git-lfs.com/). The game's assets are about 390 MB.

```sh
git submodule update --init gta-sz
cd gta-sz
git lfs install
git lfs pull
npm ci
npm run dev -- --port 5173
```

Open `http://127.0.0.1:5173/`. A PC with a real graphics card is recommended. There is also a hosted version at <https://shenchengji.gtasz.workers.dev/>.

Controls: WASD to drive, Space handbrake, F to get out and walk, T to switch between car and tank, M for the city map, J for city life jobs, L to change the lighting, Y for rain, C for the camera, G for the sightseeing view. The in-game text is mostly in Simplified Chinese.

## What it plays like

It is a compressed version of Shenzhen Bay, Nanshan, Futian and part of Luohu. You start on Binhai Boulevard (滨海大道) in a sports car at sunset, with wet roads that reflect the sky and street lights. It has:

- Real road layouts and building footprints from OpenStreetMap, with 37 hand-modelled landmarks such as Ping An Finance Center, KK100, Diwang Tower and the Tencent Binhai buildings
- Car, tank, walking, drone and plane modes
- Day, sunset and night lighting, plus rain with puddles
- NPC traffic that stops at 395 signalised junctions, pedestrians, and e-bike rows outside metro stations
- A city life system with small jobs (deliveries, comfort visits, service calls), cash, levels and upgrades, plus short story chapters
- A café with characters, a road-name HUD, a minimap and a speedometer

When I ran it, the production build loaded, the city appeared, and the car drove off on Binhai Boulevard with the first story job ("最后一单", "The last order") on screen. The character model failed to load in that test, and the game kept running without it, as it is designed to.

## How it is built

It is a TypeScript and Vite app that renders with Babylon.js 8 (WebGL2). Most of the 15,000 lines in `src/` are one module per city system: `city-world.ts` assembles the scene, `driving.ts` and `traffic.ts` handle cars, `city-flight*.ts` handles the plane, `city-tank*.ts` the tank, `pedestrians.ts` the sidewalk walkers, `city-career*.ts` the jobs, and `city-story*.ts` the story chapters.

The city is made offline, then loaded as files:

1. **Map data.** `scripts/download_osm.py` and the `prepare_*.py` scripts pull roads and building footprints from OpenStreetMap and terrain heights from Copernicus 30 m elevation data. Everything is placed around a local origin at longitude 114.025, latitude 22.536, scaled by 0.6 so the city fits a game.
2. **Geometry in Blender.** Python scripts run inside Blender (`build_city_ground.py`, `build_city_facades.py`, `build_landmark_details.py` and others) to extrude buildings, lay roads and ground, and model landmarks, trees, the car and the floatplane.
3. **Game files.** The results are exported as GLB models with JSON manifests that record positions, parameters and file hashes, then compressed with glTF Transform and meshoptimizer. `npm run assets` rebuilds everything into a separate folder so a bad rebuild can't overwrite the working city.
4. **Runtime.** Babylon.js streams those GLB files in, adds materials, reflections, lighting presets and weather, and runs the gameplay systems on top.

Playwright scripts in `scripts/` drive the game in a real browser to check landmarks, performance and character loading. The README explains that the author directed the project and used AI models to write and debug most of it.

## Credits

- Code: MIT, © 2026 linranff and the ShenChengJi (深城纪) contributors
- Roads and footprints: © OpenStreetMap contributors, ODbL
- Characters: models provided by miHoYo; MMD adaptation by 观海 (Guanhai). Not covered by the MIT license, and not redistributed here
- Other assets: see `gta-sz/public/licenses/` and `gta-sz/data/ATTRIBUTION.md`
