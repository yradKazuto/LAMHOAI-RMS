# LAMHOAI RMS — Brand Guidelines

**Last updated:** 2026-10-08

## Overview

LAMHOAI RMS is a residential management system for homeowners' associations.
The brand voice is **professional, trustworthy, and community-focused**:
a corporate-grade operations tool that still feels like it serves a neighborhood.

## Brand Attributes

| Attribute    | Expression                                                  |
|--------------|-------------------------------------------------------------|
| **Tone**     | Professional, precise, reliable                              |
| **Audience** | HOA admins, accountants, officers — operations staff, not consumers |
| **Vibe**     | Calm navy enterprise: clean, organized, data-dense but not cluttered |
| **Do**       | Be consistent, be precise with money, be role-appropriate    |
| **Don't**    | Be flashy, be generic-corporate, be inconsistent             |

## Color System

### Primary

| Token            | Value   | Usage                                    |
|------------------|---------|------------------------------------------|
| `blue-500`       | #2563EB | Primary buttons, active states, links    |
| `blue-600`       | #2E6BE6 | Primary hover                            |
| `blue-900`       | #0D2A5C | Header, brand mark, key headlines        |

### Neutrals (Navy family)

| Token            | Value   | Usage                                    |
|------------------|---------|------------------------------------------|
| `navy-900`       | #1E293B | Sidebar, strong headings, primary text   |
| `navy-700`       | #5A7099 | Muted body text, helper text             |
| `navy-500`       | #8A9BB0 | Disabled, tertiary text                  |
| `navy-300`       | #D0DBEE | Strong borders (tables, cards)           |
| `navy-200`       | #E0E8F4 | Subtle borders, dividers                 |
| `navy-100`       | #EEF2F7 | Card alt backgrounds                     |
| `navy-50`        | #F5F7FA | Page background                          |

### Status

| Token            | Value   | Meaning                                  |
|------------------|---------|------------------------------------------|
| `green-600`      | #1A7A4A | Paid, success, approved                  |
| `amber-700`      | #7A6A1A | Pending, reviewing, caution              |
| `danger`         | #CC2200 | Overdue, rejected, urgent (UI accent)    |
| `red-700`        | #991B1C | Error states, validation failures        |

### Usage rules

- Use semantic tokens everywhere — never raw hex in components.
- Status colors carry meaning; do not reuse a status hue for decoration.
- Money is shown in **₱ (Philippine Peso)** — always with 2 decimals on detail views, no decimals on summary cards.
- Keep 90% of the palette grayscale-navy; accent color only draws attention to actions and alerts.

## Typography

**Font family:** Inter (UI-first, highly legible at small sizes).

| Style              | Size  | Weight  | Use                              |
|--------------------|-------|---------|----------------------------------|
| Page title         | 22px  | 700     | Dashboard greeting, screen titles|
| H1 / Card title    | 16px  | 600-700 | Section headings, card headers   |
| Body               | 13.5px| 400-500 | Main content text                |
| Table row          | 12.5px| 600     | Data rows                        |
| Label / Caption    | 11.5px| 400-500 | Form labels, subtitles           |
| Helper / Muted     | 11px  | 400     | Helper text, timestamps, subtitles |

- Line height default: 1.5 for body, 1.3 for headings.
- Never use `Colors.grey[]` — it produces unpredictable contrast. Use the navy neutrals.

## Spacing & Layout

- Base unit: **4px**. Everything is a multiple of 4 (2, 4, 8, 12, 16, 20, 24, 28, 32).
- Page padding: 28-32px horizontal, 28px vertical.
- Card padding: 20px.
- Gap between stacked cards: 14-28px depending on visual weight.
- Desktop sidebar: 220px. Mobile drawer: 220px.

## Shape & Depth

- Card / button radius: **12px** (primary), 8px (secondary, nav items).
- Dialog radius: 16px.
- Shadow (card): `0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1)`.
- No more than **one** shadow intensity anywhere in the UI — it's the card shadow.
- No more than one radius: 12px, period. 8px and 16px are exceptions only for nav items and dialogs.

## Iconography

- Use Material Symbols / icons consistently; 18px for nav, 15px for inline, 20px for stat cards.
- Never mix outlined and filled icons on the same screen.

## Motion

- All transitions: **150-200ms**, ease-out.
- Hover states on interactive elements only.
- Loaders: small 18px circular spinner; never a full-screen spinner for a list card.

## Responsive Behavior

| Breakpoint | Width       | Behavior                                    |
|------------|-------------|---------------------------------------------|
| Mobile     | < 700px     | Full-screen dialogs, stacked cards, drawer  |
| Tablet     | 700-900px   | 2-column layouts, dialogs at 92% width      |
| Desktop    | >= 900px    | Sidebar docked, 3-column stat grids         |

## What Makes This Brand

1. **Consistency is the product.** The same navy palette, same spacing, same radius, same shadow on every screen.
2. **Role-aware.** What an admin sees differs from an accountant — the UI exposes only what the user is allowed to do.
3. **Money-first.** Pesos, amounts, due dates are the heroes. Everything else recedes.
