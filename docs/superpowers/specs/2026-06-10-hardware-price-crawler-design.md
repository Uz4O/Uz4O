# Hardware Price Crawler Design

## Goal

Build a local, manually operated JD.com price collection tool for CPU, GPU, and motherboard reference prices. The tool must remain independent from the SwiftUI app and must never overwrite production price data automatically.

## Scope

- Read CPU, GPU, and motherboard models from `May/May/Models/HardwareCatalog.swift`.
- Open a visible Chromium browser with a persistent local profile.
- Search JD.com one hardware model at a time and collect the first result page.
- Save raw products before filtering.
- Reject obvious desktops, laptops, bundles, used products, accessories, and mismatched models.
- Calculate a median reference price from accepted products.
- Compare with the previous approved price file and flag changes over 20 percent.
- Require a human to handle login, CAPTCHA, and final review.

The first version does not support Taobao, automatic CAPTCHA handling, proxy rotation, background server deployment, or automatic publishing into the iOS app.

## Architecture

The tool lives under `tools/hardware-price-crawler/`.

- `catalog.py` extracts hardware models from the existing Swift catalog without modifying it.
- `scraper.py` owns visible-browser JD search and raw DOM extraction.
- `pricing.py` normalizes titles, matches models, filters products, calculates median prices, and identifies review cases.
- `storage.py` writes deterministic CSV artifacts.
- `cli.py` exposes `catalog`, `crawl`, and `build-prices` commands.

Browser collection and price calculation are separate. If JD blocks a run, previously collected raw data can still be processed and reviewed.

## Data Flow

1. Extract selected hardware categories into `data/hardware.csv`.
2. Run a visible browser and manually complete login or verification when required.
3. Store each search result in a timestamped raw CSV file.
4. Filter products using category exclusions and normalized model matching.
5. Calculate the median accepted price and normal price range.
6. Compare against `data/approved-reference-prices.csv`.
7. Write reference prices and review-required reports into a new run directory.

## Safety And Failure Handling

- The crawler uses one visible browser and sequential searches.
- Delay between searches defaults to 5 seconds.
- Empty or blocked pages are recorded as errors, not accepted as zero-price results.
- A hardware model with fewer than two accepted products is sent to manual review.
- Prices outside category guardrails are rejected.
- Changes over 20 percent are sent to manual review.
- Browser profile, generated data, and logs are ignored by Git.

## Verification

- Unit tests cover Swift catalog extraction, model matching, exclusion rules, median calculation, insufficient samples, and large price changes.
- A dry-run CLI command processes fixture data without opening JD.com.
- A catalog command confirms the existing Swift catalog can be read successfully.

