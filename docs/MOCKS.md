# Demo Mocks — webhook.site Reference

Until Snoonu / FalconFlex ships the real endpoints, three AI actions in the Snoonu OpenCX org are backed by **webhook.site** mocks. This doc explains where they live, what they return, and how to flip them mid-demo.

> webhook.site is a free public request-capture service. Each "token" is a URL that returns a static `default_content` blob on every request. We use it as a no-infra mock host. Tokens auto-renew on every hit; they expire 7 days after the last call.

---

## The 3 mocks

| # | Action name | Mock UUID | Closes which gap |
|---|---|---|---|
| 1 | `falconflex_get_driver_removal_cases` | `ef640d3c-9487-4c6e-bb56-02b9194c2ce3` | G1 — driver vehicle-issue safety threshold |
| 2 | `falconflex_get_task_vertical` | `3e78f203-689a-4140-8b72-66565bba6c3a` | G2 — order vertical / classification |
| 3 | `falconflex_get_agent_profile` | `c861d8ff-aaf4-457e-af5f-8d78aea5e272` | PII-redacted agent view (cybersec gate) |

Each action's `api_endpoint` is `https://webhook.site/<UUID>/api/v1/...`. The path suffix after the UUID is decorative — webhook.site returns the same JSON regardless.

> **Note on Waze / navigation links:** there is no Waze mock and no `maps_*` action. Navigation deep links are constructed inline by the AI from live `falconflex_get_task.pickup.{latitude,longitude}` data — see the OpenCX instruction page "Navigation links — always construct Waze deep links from live task coordinates" (id `cb4ba4f3`). The Waze deep-link URL scheme (`https://waze.com/ul?ll=<lat>,<lng>&navigate=yes`) is pure string construction; no API key or backend call is needed, and the coordinates change per task because they come straight from FalconFlex's live `/tasks/get` endpoint.

---

## 1. `falconflex_get_driver_removal_cases`

**Purpose:** count of recent vehicle-issue removals for the driver. Used in Flow 1 (Vehicle Issue) to evaluate the Snoonu safety threshold (> 5 in 7d OR > 1 same-day → over).

**URL:** `https://webhook.site/ef640d3c-9487-4c6e-bb56-02b9194c2ce3/api/v1/agents/removal-cases?agentId=<id>&reason=VEHICLE_ISSUE&windowDays=7`

**Response (current default):**
```json
{
  "agentId": "69fc6e0e006cade1b37697e7",
  "reason": "VEHICLE_ISSUE",
  "count": 2
}
```

**Tunable:** `count`. Higher = the AI sees the driver as over-threshold and routes to `slack_notify_supply_team`.

**Note:** `windowDays` was removed from the response on 2026-05-17 — the AI was flagging an inconsistency when it queried `windowDays=1` and got back a response labeled `windowDays:7`. Now the mock returns a count without claiming any specific window.

---

## 2. `falconflex_get_task_vertical`

**Purpose:** Snoonu order classification. Drives Flow 4 (Vehicle Change) — only certain verticals require a car.

**URL:** `https://webhook.site/3e78f203-689a-4140-8b72-66565bba6c3a/api/v1/tasks/vertical?taskId=<id>`

**Response (current default):**
```json
{
  "taskId": "6a0975c1c022ced0f45e9550",
  "vertical": "FOOD"
}
```

**Tunable:** `vertical`. Enum: `GROCERY`, `CAKE_ICE_CREAM`, `COFFEE`, `FOOD`, `PHARMACY`, `ELECTRONICS`, `OTHER`. Set to `GROCERY` / `CAKE_ICE_CREAM` / `COFFEE` to demo the bike→car redispatch branches.

---

## 3. `falconflex_get_agent_profile`

**Purpose:** PII-redacted view of a driver. Used when full PII (Qatar ID, passport) shouldn't be surfaced.

**URL:** `https://webhook.site/c861d8ff-aaf4-457e-af5f-8d78aea5e272/api/v1/agents/profile?Id=<id>`

**Response (current default):**
```json
{
  "id": "69fc6e0e006cade1b37697e7",
  "publicId": "39612",
  "fullName": "Bilal Hasan",
  "phoneNumber": "+97412346778",
  "email": "aziz+falconflextest@open.cx",
  "transportTypeId": 2,
  "fleetTypeId": 2,
  "employmentStatusId": 1
}
```

**Tunable:** any field. Set `employmentStatusId: 2` to demo the "blocked driver lookup" flow, for example.

---

## Flip mocks mid-demo

### Helper script (recommended)

[`scripts/set-demo-state.sh`](../scripts/set-demo-state.sh) is the one-call switcher:

```bash
./scripts/set-demo-state.sh status      # show current values
./scripts/set-demo-state.sh safe        # count=2, vertical=FOOD       (under threshold)
./scripts/set-demo-state.sh over        # count=6, vertical=FOOD       (block + supply slack path)
./scripts/set-demo-state.sh grocery     # count=2, vertical=GROCERY    (bike→car redispatch)
./scripts/set-demo-state.sh coffee      # count=2, vertical=COFFEE
./scripts/set-demo-state.sh cake        # count=2, vertical=CAKE_ICE_CREAM
./scripts/set-demo-state.sh clean       # count=0, vertical=FOOD

# Override count for any mode:
INCIDENTS=11 ./scripts/set-demo-state.sh over
```

Each call PATCHes webhook.site's `default_content` for the two main mocks. Effective on the **very next** AI tool call — no redeploy, no restart.

### Web UI (easiest for one-off tweaks)

Each mock has a dashboard at `https://webhook.site/#!/view/<UUID>`. Edit the "Default response → Body" field, save.

- removal_cases — https://webhook.site/#!/view/ef640d3c-9487-4c6e-bb56-02b9194c2ce3
- task_vertical — https://webhook.site/#!/view/3e78f203-689a-4140-8b72-66565bba6c3a
- agent_profile — https://webhook.site/#!/view/c861d8ff-aaf4-457e-af5f-8d78aea5e272

### Direct curl (fastest if you know the shape)

```bash
curl -X PUT https://webhook.site/token/<UUID> \
  -H "Content-Type: application/json" \
  -d '{
    "default_content": "<json-encoded body>",
    "default_content_type": "application/json",
    "default_status": 200
  }'
```

---

## How they're wired into OpenCX

Each of the 4 OpenCX actions has `api_endpoint` pointing at the corresponding webhook.site URL. When the AI agent fires the action during a conversation, OpenCX's backend POSTs (or GETs) to that URL; webhook.site returns the configured JSON; OpenCX hands it back to the AI as the action result.

| Hop | Owner |
|---|---|
| Driver → widget | Vercel (this repo) |
| Widget → OpenCX backend | `api.open.cx` |
| OpenCX backend → action endpoint | `webhook.site` (the mocks) |
| Action endpoint → OpenCX backend | `webhook.site` returns static JSON |
| OpenCX backend → AI reasoning → widget reply | `api.open.cx` |

No part of this lives on your local machine. Changes to the `default_content` are global and instant.

---

## Caveats

1. **No state.** webhook.site mocks always return the configured blob. They don't increment, vary by query params, or remember prior calls. To simulate a counter, flip `count` manually between scenarios.
2. **Token expiry.** Tokens expire 7 days after the last hit. Every demo / smoke test counts as a hit, so day-to-day use keeps them alive. After a quiet week the token (and its UUID) are gone — you'd need to mint a new one and re-PATCH the action's `api_endpoint`.
3. **Public URLs.** Anyone with the UUID can read or change the response. Don't paste these URLs into public docs.
4. **`vertical` value seen by the AI must match what Snoonu actually stores on tasks.** The current enum (`GROCERY`, `CAKE_ICE_CREAM`, `COFFEE`, `FOOD`, …) is the OpenCX-side convention; Snoonu's real category metadata may use different casing or values. Confirm with Snoonu before production cutover (open question on the [API Requirements](https://www.notion.so/3607f1dcfabb8172b197f3e56acbd3e0) doc).

---

## How to add a 5th mock

1. `curl -X POST https://webhook.site/token -H "Content-Type: application/json" -d '{}'` → grab the `uuid` from the response.
2. `curl -X PUT https://webhook.site/token/<UUID> -H "Content-Type: application/json" -d '{"default_content":"<json>","default_content_type":"application/json","default_status":200}'` to set the response.
3. Create the OpenCX action with `api_endpoint: https://webhook.site/<UUID>/api/v1/...` (any path suffix) — see the existing 4 in the OpenCX dashboard for the action shape.
4. Add the mock to `scripts/set-demo-state.sh` if it should be toggled per demo mode.
5. Document the new mock in this file.
