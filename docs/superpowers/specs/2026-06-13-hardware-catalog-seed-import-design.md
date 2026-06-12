# Hardware Catalog Seed Import Design

## Goal

Import the existing SwiftUI hardware catalog into the backend database and expose basic read APIs for catalog search and compatible motherboard filtering.

## Scope

- Parse all `HardwareCatalogItem` entries from `May/May/Models/HardwareCatalog.swift`.
- Import CPU, GPU, motherboard, RAM, storage, and PSU entries.
- Store rows in `hardware_component`.
- Keep original `detail` as `detail_raw`.
- Store only reliably parsed specs in JSON.
- Default `is_recommended` to `false` and `status` to `active`.
- Support repeated imports with upsert behavior.

## Out of Scope

- No AI recommendation logic.
- No prices.
- No inferred TDP, performance index, or made-up hardware specs.
- No frontend changes.

## Data Model

`hardware_component`:

- `id` text primary key
- `category` text
- `name` text
- `brand` text
- `detail_raw` text
- `specs` json
- `is_recommended` boolean
- `status` text
- `updated_at` timestamp with timezone

## API

- `GET /v1/catalog/components`
  - Optional filters: `category`, `brand`, `q`
- `GET /v1/catalog/motherboards?cpu=<cpu id or name>`
  - Returns all motherboards when CPU is unknown.
  - Returns socket-compatible motherboards when CPU socket is known.

