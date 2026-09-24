---
name: "rsg-redm-ui-design"
description: "standard UI design to use with my scripts"
---

# RDR2 Stable-Style NUI Prompt

Paste this into a conversation (with the target script's `html/` files attached or described) to make any FiveM/RedM NUI match the rex-stables look.

---

Style this script's NUI (HTML/CSS/JS UI) to match the "RDR2 leather & gold" theme used across my other RedM scripts. Apply these exact rules:

**Fonts & base**
- Font: 'Roboto' from Google Fonts (weights 400/500/600/700, italic 400). Add the `<link>` preconnect + stylesheet tags for it.
- `html, body`: transparent background, `overflow: hidden`, `user-select: none`, full width/height.
- Root container is `position: fixed; inset: 0;` and toggles visibility via a `.hidden { display: none; }` class rather than removing elements.
- Add a full-screen `#vignette` overlay: `radial-gradient` darkening the edges plus a subtle flat dark overlay, `pointer-events: none`.

**Color palette (CSS variables on `:root`)**
```
--rdr-black: #000000;
--rdr-panel: #0a0a0a;
--rdr-panel-2: #141414;
--rdr-leather: #1c1c1c;
--rdr-red: #4a4a4a;
--rdr-red-bright: #2a2a2a;
--rdr-gold: #ffffff;
--rdr-gold-dim: #5a5a5a;
--rdr-parchment: #ffffff;
--rdr-text: #f2f2f2;
--rdr-muted: #9a9a9a;
--rdr-green: #5a7d4f;
--rdr-cost-ok: #6fbf73;
--rdr-cost-over: #e0554f;
--rdr-amber: #d9a441;
--rdr-shadow: rgba(0, 0, 0, 0.85);
```
(Despite the variable names referencing "gold", the actual accent is monochrome — white/grey, not yellow. Keep it that way for consistency.)

**Panel / card chrome**
- Main panel: fixed width (~380–460px depending on content), rounded corners (`border-radius: 3px`), 1px `var(--rdr-gold-dim)` border plus a second inset `outline: 1px solid rgba(0,0,0,0.6)` offset -5px (a "double border" engraved look).
- Background: a diagonal gradient `linear-gradient(160deg, var(--rdr-panel-2), var(--rdr-panel) 60%, var(--rdr-black))`, optionally layered with a faint repeating horizontal-line texture (`repeating-linear-gradient` at ~1.5% white opacity) for a grain effect.
- Box shadow: `0 20px 60px var(--rdr-shadow)` plus `inset 0 0 40px rgba(0,0,0,0.5)`.
- Header: centered uppercase title (~24–26px, letter-spacing 1px, `text-shadow`), small uppercase subtitle beneath in `--rdr-muted` with wide letter-spacing (3px). Circular icon buttons (chevron/back, seal/close) flank the header — 32px circles, radial-gradient fill, gold-dim border, brighten on hover.
- Section divider: a horizontal line pair with a centered ✦ character, built from two `::before`/`::after` gradient lines fading from the center.

**List rows / cards**
- Each row: flex layout, ~2px border-radius, subtle vertical gradient background (`rgba(255,255,255,0.03)` to `rgba(0,0,0,0.15)`), 1px border at low-opacity gold (`rgba(201,162,75,0.18)`), padding ~12–14px, gap ~14px.
- Hover: brighten background gradient, border turns solid `--rdr-gold-dim`/`--rdr-gold`, and nudge with `transform: translateX(2px)`.
- Disabled state: `opacity: 0.45; cursor: not-allowed;`.
- Round icon badge on the left (34px circle, radial-gradient, gold-dim border).
- Optional small uppercase badge/pill on the right (1px border, 2px radius, small letter-spacing).
- Descriptive text under a title uses italic style in `--rdr-muted`.

**Stat/progress bars**
- Track: `height: 6–11px`, `background: rgba(0,0,0,0.45)`, 1px gold-dim border, rounded, `inset` shadow.
- Fill: rounded on the left edge only, color-coded via modifier classes:
  - `.stat-good` → green gradient (`#7fcf82` → `--rdr-cost-ok`)
  - `.stat-warn` → amber gradient (`#eec06a` → `--rdr-amber`)
  - `.stat-bad` → red gradient (`#ec7a75` → `--rdr-cost-over`)
- Animate width/color changes with `transition: width 0.35s ease, background-color 0.35s ease`.

**Buttons**
- "Wood" button style: `linear-gradient(180deg, #2e2e2e, #141414)`, 1px gold-dim border, 2px radius, uppercase text, letter-spacing ~1.5px, small font (~12.5px). Hover: border brightens to full gold, `filter: brightness(1.3)`.
- Muted/secondary variant: darker gradient (`#1c1c1c` → `#0a0a0a`) and muted text color.

**Modals**
- Centered card, same double-border/gradient/shadow treatment as the main panel, ~380px wide.
- Uppercase title, then an `.ink-divider` (thin centered gradient line ~70% width) beneath it.
- Actions row: flex buttons using the wood-btn style, `justify-content: center` when there's a single action.
- Text inputs: dark translucent background (`rgba(0,0,0,0.35)`), gold-dim border, glows with a soft box-shadow ring on focus (`box-shadow: 0 0 0 2px rgba(201,162,75,0.15)`, border turns full gold).

**Toasts**
- Fixed bottom-right stack, `flex-direction: column-reverse`, gap ~10px.
- Same panel gradient/border, plus a 4px colored left border indicating type: success → green, error → red-bright, info → gold/white.
- Small uppercase label above the message in `--rdr-muted`.
- Slide-in/out animation from the right (`translateX(30px)` ↔ `0`, opacity fade, ~0.25s ease).

**General principles**
- Everything is dark, high-contrast, monochrome-with-accent — no bright colors except the semantic good/warn/bad states.
- Heavy use of uppercase + letter-spacing for labels/titles, italic for secondary/descriptive text.
- Circular buttons for navigation/dismiss actions; rectangular "wood" buttons for confirm/cancel actions.
- Subtle gradients and soft shadows everywhere instead of flat fills — nothing should look flat or web-default.
- Keep interactions snappy: ~0.15s ease transitions on hover states, ~0.25–0.35s on state/content changes.

Apply this exact palette and component styling to the attached script's UI, adapting layout/structure to fit its existing functionality, but keep all visual language (colors, borders, shadows, typography, button/toast/modal treatment) identical to the rules above.