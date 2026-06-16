# Price Ingest Design

## Goal

Import manually approved hardware reference prices into the backend database so build, review, and upgrade services can reason about budget and price fairness.

## Scope

- Accept only approved reference-price CSV files.
- Store one current reference price row per hardware component.
- Keep crawler provenance fields: range, accepted/rejected counts, review reasons, source, and approval time.
- Provide read-only price APIs.
- Do not expose a public write/admin upload endpoint before authentication exists.

## Input Format

The importer consumes the crawler's `reference-prices.csv` shape after a human has copied or renamed it as approved:

- `target_id`
- `reference_price`
- `normal_price_min`
- `normal_price_max`
- `accepted_count`
- `rejected_count`
- `review_reasons`

Rows without `reference_price` are skipped because they are not approved usable prices.

## Data Model

`component_price`:

- `component_id` primary key and foreign key to `hardware_component.id`
- `reference_price`
- `price_range_low`
- `price_range_high`
- `source`
- `accepted_count`
- `rejected_count`
- `review_reasons`
- `approved_at`
- `updated_at`

## API

- `GET /v1/catalog/prices`
- `GET /v1/catalog/components/{component_id}/price`

