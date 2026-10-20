# Project Zapp — Cloudflare D1 & Worker Backend Setup Guide

This document outlines the step-by-step instructions to wire the **Project Zapp** Flutter frontend with a **Cloudflare Worker** and **Cloudflare D1 Database**.

---

## Architecture Overview

```
Flutter Mobile / Web App
   │
   ├── [Local-First Store]  ──> SQLite (`sqflite` on mobile / in-memory on web)
   │
   └── [Network Layer]      ──> `lib/core/api_client.dart`
                                  │
                                  ▼ (HTTPS / Bearer JWT)
                            Cloudflare Worker (`worker-auth`)
                                  │
                                  ▼ (SQL Queries)
                            Cloudflare D1 Database
```

---

## 1. Quick Prerequisites

Make sure you have Node.js (v18+) and npm installed.

```bash
# 1. Install Cloudflare Wrangler CLI globally
npm install -g wrangler

# 2. Login to your Cloudflare account
wrangler login
```

---

## 2. Setting Up Cloudflare D1 Database

```bash
# In the project root:
wrangler d1 create project-zapp-db
```

Wrangler will output your database configuration details, for example:
```toml
[[d1_databases]]
binding = "DB"
database_name = "project-zapp-db"
database_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

Save or note this `database_id`.

---

## 3. Applying the Database Schema

The complete relational schema is located at [`worker-auth/schema.sql`](../worker-auth/schema.sql).

Execute the schema against your Cloudflare D1 database:

```bash
# For local development testing:
wrangler d1 execute project-zapp-db --local --file=./worker-auth/schema.sql

# For production cloud deployment:
wrangler d1 execute project-zapp-db --remote --file=./worker-auth/schema.sql
```

The schema creates:
- `users`: User profiles, roles (`USER` / `ADMIN`), status.
- `courses`: Parsed VTOP course metadata (Code, Name, Slot, Venue, Faculty).
- `user_timetable_slots`: 7-day deconstructed slot schedule matrix.
- `groups`: Study Squad definitions and unique 8-character squad codes.
- `group_members`: Membership links with roles (`OWNER`, `MEMBER`).
- `rate_limits`: Edge rate limiting.

---

## 4. Cloudflare Worker Configuration (`wrangler.toml`)

Create or update `wrangler.toml` inside your worker folder:

```toml
name = "project-zapp-api"
main = "src/index.ts"
compatibility_date = "2024-04-01"

[[d1_databases]]
binding = "DB"
database_name = "project-zapp-db"
database_id = "<YOUR_DATABASE_ID_FROM_STEP_2>"

[vars]
JWT_SECRET = "super-secret-jwt-key-replace-in-production"
```

---

## 5. Wiring the Frontend to Your Cloudflare Worker

Open [`lib/core/constants.dart`](../lib/core/constants.dart):

```dart
// Change from example URL to your deployed Cloudflare Worker URL:
const String apiBaseUrl = 'https://project-zapp-api.<your-cloudflare-subdomain>.workers.dev';
```

That's it! The Flutter frontend is already built with dual-mode support:
- **Offline Mode**: If the backend is not connected, the app seamlessly falls back to local SQLite caching and seed demo data so nothing ever crashes.
- **Connected Mode**: When `apiBaseUrl` points to a live Worker, `api_client.dart` automatically:
  1. Authenticates via `/api/login` and receives a Bearer JWT.
  2. Uploads parsed timetables via `/api/timetable/upload`.
  3. Fetches live Study Squad members and busy slots via `/api/squad/:code`.
  4. Allows admins to fetch all student schedules via `/api/timetable/all`.

---

## 6. Testing Endpoints Locally

Run your worker locally before deploying:

```bash
wrangler dev --local
```

You can test with curl or Postman against `http://localhost:8787`:

```bash
# Health check / status
curl http://localhost:8787/api/health

# Test squad fetch
curl http://localhost:8787/api/squad/K8M2-9PL4
```

---

## 7. Deploying to Cloudflare

When ready, deploy your Worker with one command:

```bash
wrangler deploy
```

Copy the live URL produced by Wrangler (e.g. `https://project-zapp-api.username.workers.dev`) and paste it into [`lib/core/constants.dart`](../lib/core/constants.dart).
