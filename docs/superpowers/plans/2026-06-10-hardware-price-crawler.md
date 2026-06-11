# Hardware Price Crawler Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local, human-supervised JD.com crawler that produces reviewed reference prices for CPUs, GPUs, and motherboards without touching the SwiftUI frontend.

**Architecture:** Keep browser collection separate from deterministic catalog extraction, filtering, reference-price calculation, and CSV storage. Use a visible persistent Playwright browser only for collection; keep all business rules testable without network access.

**Tech Stack:** Python 3.9+, Playwright, standard-library `csv`, `dataclasses`, `statistics`, `unittest`.

---

### Task 1: Price Rules

**Files:**
- Create: `tools/hardware-price-crawler/tests/test_pricing.py`
- Create: `tools/hardware-price-crawler/price_crawler/pricing.py`

- [ ] Write failing tests for matching exact hardware variants, rejecting bundles and used products, median calculation, insufficient samples, and price-change review.
- [ ] Run `python3 -m unittest discover -s tools/hardware-price-crawler/tests -v` and verify the tests fail because `price_crawler.pricing` does not exist.
- [ ] Implement the minimum deterministic pricing rules.
- [ ] Run the test command and verify all pricing tests pass.

### Task 2: Swift Catalog Extraction

**Files:**
- Create: `tools/hardware-price-crawler/tests/test_catalog.py`
- Create: `tools/hardware-price-crawler/price_crawler/catalog.py`

- [ ] Write failing tests that extract only CPU, GPU, and motherboard records from a Swift catalog fixture.
- [ ] Run the tests and verify the catalog module is missing.
- [ ] Implement section-bounded Swift catalog extraction.
- [ ] Run the tests and verify they pass.

### Task 3: CSV Storage And Reports

**Files:**
- Create: `tools/hardware-price-crawler/tests/test_storage.py`
- Create: `tools/hardware-price-crawler/price_crawler/storage.py`

- [ ] Write failing tests for deterministic hardware, raw-product, reference-price, and review CSV output.
- [ ] Implement CSV reading and writing.
- [ ] Run all tests.

### Task 4: JD Browser Collection And CLI

**Files:**
- Create: `tools/hardware-price-crawler/price_crawler/scraper.py`
- Create: `tools/hardware-price-crawler/price_crawler/cli.py`
- Create: `tools/hardware-price-crawler/run.py`

- [ ] Implement visible persistent-browser collection with sequential keyword searches and a configurable delay.
- [ ] Implement `catalog`, `crawl`, and `build-prices` commands.
- [ ] Verify `catalog` against `May/May/Models/HardwareCatalog.swift`.
- [ ] Verify `build-prices` against fixture raw data.

### Task 5: Operator Documentation

**Files:**
- Create: `tools/hardware-price-crawler/README.md`
- Create: `tools/hardware-price-crawler/requirements.txt`
- Modify: `.gitignore`

- [ ] Document installation, weekly operation, manual review, and publishing boundaries.
- [ ] Ignore browser profile and generated run data.
- [ ] Install dependencies and run the complete test suite.

