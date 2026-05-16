# Snoonu Rider Portal — OpenCX widget demo

A self-contained mock of the **Snoonu Rider Portal** with the **OpenCX agentic support widget** embedded and pre-wired for a sales demo:

- Active Trip card with three stage tabs (`on the way to merchant`, `at merchant`, `on the way to customer`).
- Each stage flips the widget's persistent banner + L2 starter questions to match the rider's live moment.
- Rider profile (Bilal Hasan, #39612) attached on every conversation via `user.data.customData`.
- Supplier directory (Open Test Supplier) attached via `context.suppliers`.
- The four documented Snoonu × OpenCX workflows (Vehicle Issue, Can't find merchant, Chained order removal, Vehicle change request) attached via `context.documented_workflows`, with rider-facing L2 labels generated from them.

No build step. No dependencies. One file: [`index.html`](./index.html).

---

## Run locally

```bash
# any static server works — pick one
python3 -m http.server 8765
# or
npx serve .
```

Open <http://localhost:8765>.

---

## Deploy to Vercel (1 minute)

### Option A — push to GitHub, import in Vercel UI

```bash
# 1. Create the repo on github.com (e.g. snoonu-rider-portal-demo)
# 2. From this folder:
git init
git add .
git commit -m "initial: Snoonu Rider Portal demo with OpenCX widget"
git branch -M main
git remote add origin git@github.com:<you>/snoonu-rider-portal-demo.git
git push -u origin main
```

Then in the Vercel dashboard: **Add New… → Project → Import** the repo. Framework preset: **Other** (auto-detected as static). Click **Deploy**.

### Option B — Vercel CLI (no GitHub needed)

```bash
npx vercel
```

Follow the prompts. The included [`vercel.json`](./vercel.json) configures clean URLs and basic security headers.

---

## What's wired

### Widget config (in `index.html`, end of file)

| Field | Value |
|---|---|
| `token` | `fa8e14f2163a82dea05f75d46a53100d` |
| `bot.name` | `Snoo` |
| `bot.avatarUrl` | inline-SVG rounded "S" mark |
| `assets.organizationLogo` | inline-SVG `snoonu RIDER PORTAL` wordmark |
| `theme.primaryColor` | `#D90217` (Snoonu red) |
| `user.externalId` | rider `public_id` |
| `user.data.customData` | full rider profile (12 fields) |
| `context.current_trip` | live trip stage + merchant + customer + order |
| `context.suppliers` | supplier directory |
| `context.documented_workflows` | the 4 Flows (id, name, summary, FF endpoints, applies_to_stages) |
| `sessionCustomData` | `channel`, `trip_id`, `trip_stage`, `l1_reason` (for inbox filtering) |
| `messageCustomData` | `platform`, `surface`, `app_version`, `trip_stage` |
| `advancedInitialMessages` | persistent stage-specific banner |
| `initialQuestions` | stage-specific L2 list (from `DOCUMENTED_WORKFLOWS`) |

### Stage → L2 reasons

| Stage | L2 reasons (rider-facing) |
|---|---|
| **On the way to merchant** | F1 Vehicle Issue · F2 Can't find merchant · F3 Drop one from chain · F4 Switch to car · *Something else* |
| **At merchant** | F1 Vehicle Issue · F3 Drop one from chain · F4 Switch to car · *Something else* |
| **On the way to customer** | F1 Vehicle Issue · F3 Drop one from chain · *Something else* |

Each L2 maps back to a documented workflow with FF endpoints — the AI receives that mapping on every message.

---

## Customizing

Open [`index.html`](./index.html), search for the marked sections in the closing `<script>` block.

| Want to change | Edit |
|---|---|
| Widget token | `token: '...'` (top of `buildOptions`) |
| Bot name / avatar | `bot.name`, `bot.avatarUrl` |
| Brand color | `theme.primaryColor` (and CSS `--brand` for the page) |
| Rider data | `const rider = { ... }` |
| Supplier directory | `const suppliers = [ ... ]` |
| Active trip details | `const activeTrip = { ... }` |
| Add an L2 workflow | append an entry to `DOCUMENTED_WORKFLOWS` with `applies_to_stages` |
| Stage banner copy | `STAGES.<stage>.banner` |
| Hide demo banner at top | remove `<div class="demo-banner">` |

---

## Notes

- The widget bundle loads from `unpkg.com/@opencx/widget@latest/dist-embed/script.js`. For production-grade deployments, pin a version (e.g. `@opencx/widget@1.x`).
- All branding (Snoonu wordmark, S-mark, colour) is approximated for a sales demo only — replace with real assets before any external use.
