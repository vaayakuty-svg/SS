---
name: public-apis
description: Find a free public API for a project. Use when the user asks "is there a free API for X", "find an API for weather/crypto/movies/...", "which API should I use for X", "API without an API key", or needs a data source for an app, bot, website or trading tool. Searches a bundled copy of the public-apis list (~1,400 APIs across 50 categories) with auth, HTTPS and CORS details.
---

# Public APIs finder

`references/apis.md` is a snapshot of [public-apis/public-apis](https://github.com/public-apis/public-apis) (MIT), taken 2026-10-30 at commit `2098dd7`. It is about 330 KB, so **never read it whole**: search it.

## Format

Each category is a `### <Category>` heading followed by a table:

```
| [Name](https://docs-url) | Description | Auth | HTTPS | CORS |
```

- **Auth:** `No` (no key needed), `apiKey`, `OAuth`, `X-Mashape-Key`, `User-Agent`
- **HTTPS:** `Yes` / `No`
- **CORS:** `Yes` (callable straight from browser JS), `No` (needs a backend/proxy), `Unknown`

Categories include Animals, Anime, Books, Business, Calendar, Cryptocurrency, Currency Exchange, Development, Dictionaries, Entertainment, Finance, Food & Drink, Games & Comics, Geocoding, Government, Health, Jobs, Machine Learning, Music, News, Open Data, Photography, Science & Math, Security, Shopping, Social, Sports & Fitness, Test Data, Text Analysis, Transportation, Video, Weather, and more. List them all with `grep -n '^### ' references/apis.md`.

## How to search

1. Turn the need into a category and 2–4 keywords (e.g. "gold price for my EA" → Finance / Currency Exchange; gold, metal, forex).
2. Search by keyword across all categories (case-insensitive):
   `grep -i -E 'gold|metal|forex' references/apis.md`
3. Or read one category: `sed -n '/^### Weather/,/^### /p' references/apis.md`
4. Apply the user's constraints with extra filters, e.g. no key: `| grep '| No |'`; browser use: CORS `Yes`; always prefer HTTPS `Yes`.

## Answer

- Give 3–5 picks max, as a short table: name (linked to docs), what it gives, Auth, HTTPS, CORS. Recommend one and say why.
- The list is a snapshot and community-maintained: APIs may be dead, rate-limited or now paid. Say so, and when network access allows, open the docs link to confirm it is live before the user builds on it.
- If nothing fits, say so plainly and suggest searching the web for newer options.
- Don't ask the user for API keys in chat; tell them where to sign up and to keep the key in an env var or config file outside the repo.
