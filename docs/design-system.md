# Aura — Design System

> **Status:** derived from the shipped code at `6428b8b`, cross-checked against the
> `ui-ux-pro-max` skill database (Flutter stack rules, 119 UX guidelines, native
> app pro-rules).
>
> **Source of truth:** the Dart token files are normative. This document describes
> them; where the two disagree, the code wins and this document is the bug.
>
> **Why the section numbers look arbitrary:** 15 doc comments across `lib/` cite
> "spec §2", "spec §3", "spec §13.2", "spec §14" and so on. That spec is not in
> the repository. The numbering below is reconstructed so those existing
> references resolve again. Sections marked **(gap)** are places where the code
> cites a decision whose rationale was not recoverable from the code alone.

## §1 Principles

Aura is a **local-first music player**, not a streaming storefront. There is no
funnel, no upsell, no feed. The interface is a quiet frame around someone else's
artwork, and every rule below follows from that.

1. **The product is calm and monochrome; colour is an event.** The base palette
   is a neutral grey ladder. Saturated colour appears only where it carries
   meaning: the album artwork itself, the single teal accent, the heart, and the
   aurora gradient at moments of delight.
2. **Glass is used with restraint.** Blur is a material for surfaces that float
   over content — never a decoration applied by default.
3. **Motion breathes; it does not perform.** Timing is chosen per distance and
   context from a shared token set, never copied.
4. **Tokens over literals.** No widget inlines a raw spacing, radius, icon size,
   duration, or hex value.

## §2 Materials — Liquid Glass

Glass appears on exactly four surface classes: the Now Playing overlay, the
floating bottom nav bar, modal sheets, and the queue panel.

### §2.1 Material levels

`GlassLevel` is the **per-surface role** — what a surface *is*.

| Level | Base sigma | Base fill (dark) | Used by |
|---|---|---|---|
| `ultraThin` | 1 | 0.02 | Overlays directly on artwork |
| `thin` | 2 | 0.03 | Mini player |
| `regular` | 3 | 0.04 | Nav bar, modal sheets (default) |
| `thick` | 4 | 0.05 | Text-heavy panels |

### §2.2 User intensity

`GlassIntensity` is the **global user preference** (Settings → Liquid Glass
intensity), not a design decision: `off` 0 · `subtle` 4 · `medium` 8 ·
`strong` 12 (default) · `ultra` 18. Only `ultra` adds extra white tint (0.06).

The two compose — a surface never reads its own sigma directly:

```
effectiveSigma = level.sigma × (intensity.sigma / strong.sigma)
```

`off` collapses to 0 and the surface must fall back to opaque. **Every glass
surface must render correctly at `off`** — glass is an enhancement, never the
only thing separating foreground from background.

### §2.3 The refracted edge

Glass surfaces carry a hairline inner highlight, not a border: `edgeOpacity`
0.18, `edgeWidth` 0.5, `borderWidth` 1.

### §2.4 Ambient floor

Ambient colour lives only in the **bottom 55%** of the ambient background.
The top of the screen stays neutral so titles and status text never fight a
moving wash.

## §3 Typography

Latin runs on **Inter**; Persian/Arabic on **Vazirmatn**, falling back to the
platform Arabic face when the `.ttf` is absent. Colour is deliberately *not*
baked into any style — it is applied at the call site from `AppColors`, so one
style works in all three themes.

The scale is the iOS 26/27 scale, expressed as `size / weight / line-height`:

| Role | Size | Weight | Line-height | Tracking |
|---|---|---|---|---|
| `largeTitle` | 34 | 700 | 41 | −0.4 |
| `title1` | 28 | 600 | 34 | −0.3 |
| `title2` | 22 | 600 | 28 | −0.2 |
| `title3` | 20 | 600 | 25 | −0.2 |
| `headline` | 17 | 600 | 22 | −0.1 |
| `bodyLarge` | 17 | 400 | 22 | — |
| `callout` | 16 | 400 | 21 | — |
| `subhead` | 15 | 400 | 20 | — |
| `footnote` | 13 | 400 | 18 | — |
| `caption1` | 12 | 400 | 16 | — |
| `caption2` | 11 | 400 | 13 | — |

**Rules**

- **11pt is the floor.** Never specify type below `caption2`.
- **Timers and durations use tabular figures** (`FontFeature.tabularFigures()`)
  so the playhead does not jitter as digits change.
- Legacy aliases (`heroTitle`, `display`, `title`, `body`, `caption`,
  `navLabel`, `action`) are remapped onto the scale above and kept only so
  existing widgets compile. **Do not use them in new code.**

## §4 Colour

### §4.1 Semantic roles

Sixteen roles, consumed through the `AppColors` theme extension. Widgets never
read raw hex.

`background` · `surface` · `surfaceElevated` · `onSurface` · `onSurfaceMuted` ·
`onSurfaceFaint` · `accent` · `onAccent` · `divider` · `glassTint` ·
`glassBorder` · `scrim` · `danger` · `favorite` · `positive` · `warning`

Two roles carry deliberate meaning that is easy to get wrong:

- **`danger` is the only red.** Destructive actions only. Widgets never reach
  for `Colors.red*`.
- **`favorite` is the heart** — the one warm accent in the product. Liked songs
  and the like-button ripple use it. It is **not** `danger`.

### §4.2 Themes

Three variants ship: `amoled` (pure black), `dark` (near-black), `light`
(paper-white — the page steps *down* from white cards, never pure white).

| Role | amoled | dark | light |
|---|---|---|---|
| `background` | `#000000` | `#0A0A0C` | `#F4F4F7` |
| `surface` | `#0C0C0E` | `#141416` | `#FFFFFF` |
| `surfaceElevated` | `#161618` | `#1E1E22` | `#FFFFFF` |
| `onSurface` | `#F5F5F7` | `#F5F5F7` | `#15151A` |
| `onSurfaceMuted` | `#9A9AA0` | `#9A9AA0` | `#5A5A66` |
| `onSurfaceFaint` | `#6A6A70` | `#6A6A70` | `#9494A0` |
| `accent` | `#5FC6BC` | `#5FC6BC` | `#16161B` |
| `divider` | `#1C1C1F` | `#222226` | `#E7E7ED` |
| `glassTint` | `#04FFFFFF` | `#04FFFFFF` | `#9EFFFFFF` |
| `danger` | `#FF6B6B` | `#FF6B6B` | `#D93A3A` |
| `favorite` | `#E66A6A` | `#E66A6A` | `#E0466A` |

Note the light theme is **not** a tinted inversion: `accent` becomes near-black
(`#16161B`) rather than teal, and the glass tint flips from a 1.6% white veil to
a 62% white frost with a *dark* hairline border. Light mode is its own design,
which is why §11 requires it to be verified independently.

### §4.3 The aurora gradient

`AuroraColors` is Aura's bottled delight: teal-mint `#5EE7C8` → sky `#4AA8FF` →
violet `#9A7BFF` → magenta `#FF8FD0`, a 4-stop ribbon at 115°.

**Reserved for:** the logo, onboarding, the play-button disc while playing, and
empty-state icons. Nothing else. The product stays calm and monochrome; aurora
is the moment of joy. Text drawn on an aurora fill uses `onAurora` `#07131A`.

### §4.6 Glass surface roles

A surface declares its `GlassLevel` (§2.1); it does not pick a blur value. The
mini player refracts the current track's dominant hue.

## §5 Spacing & layout rhythm

`2 · 4 · 8 · 12 · 16 · 20 · 24 · 32 · 48` — a clean 4/8 rhythm.

`lg` (16) is the default screen edge inset; `huge` (48) is the vertical rhythm
between major sections. Widgets must never use a raw numeric spacing value.

## §6 Iconography

Sizes are tokenised exactly like spacing: `xs` 14 · `sm` 18 · `md` 20 ·
`lg` 24 (default control) · `xl` 28 · `huge` 40 · `giant` 48. No `Icon(size:)`
inlines a raw number.

One family throughout (Material `Icons.*`, ~280 references, no mixing). Nav tabs
carry a separate `icon`/`activeIcon` pair, so the outline→filled switch marks
selection rather than a colour change alone.

## §7 Artwork

Album art is the loudest thing on screen by design. It carries the largest
radius in the scale (`lg` 20 on Now Playing, `xs` 8 on the mini player) and is
the source of the dynamic accent hue.

## §8 Shared components

Three widgets exist specifically to keep behaviour identical everywhere, and
new UI should reuse them rather than re-implement:

- **`PressScale`** — the standard press feedback: scale to 0.92, spring back
  over 160ms, and collapse to no scale under reduced motion.
- **`AsyncStateView`** — the single loading / error / empty / data treatment.
  Loading is deliberately quiet: a small low-contrast spinner, never a
  full-screen one.
- **`SectionHeader`** — large display title, optional subtitle ("12 songs"),
  trailing actions.

## §9 Feedback & states

Press feedback lands within the `press` token (160ms). Press states change
colour, opacity, or scale — **never layout bounds**, so nothing around the
control jitters.

## §10 Navigation

Five primary tabs — `library`, `artists`, `albums`, `playlists`, `search` — in a
floating glass bar that minimises as the user scrolls down and restores on
scroll up or tab change. Five is the ceiling; adding a sixth tab requires
restructuring, not squeezing.

On scroll, the screen's `largeTitle` morphs into `headline` pinned in the nav
bar.

## §11 Accessibility

**Supported today**

- Reduced motion composes correctly: the in-app toggle *augments* the OS flag
  (`settings.reduceMotion || mq.disableAnimations`) rather than replacing it, so
  a user who set the system preference gets it honoured without finding Aura's
  switch. `PressScale`, the nav bar, and Now Playing all branch on it.
- 26 files respect safe areas.
- Selection is never signalled by colour alone (§6, outline→filled).

**Requirements**

- Body and secondary text ≥ 4.5:1 in *both* themes; 3:1 applies only to large
  text and non-text UI.
- Touch targets ≥ 44pt (iOS) / 48dp (Android); expand the hit area when the
  glyph is smaller.
- Light and dark are verified separately. Light-mode values are never inferred
  from dark (§4.2 explains why they cannot be).

**Known gaps — measured, not asserted** (see the audit table at the end):

- `onSurfaceFaint` fails 4.5:1 in all three themes while being used for real
  caption text.
- System font-size preference is discarded.

## §12 Localisation & RTL

`fa` and `ar` mirror the entire layout via the locale — no per-widget RTL
handling. Persian/Arabic type resolves to Vazirmatn (§3). Any new layout must
be checked mirrored; directional icons and gestures need explicit attention.

## §13 Motion

"Motion that breathes." Durations and curves are tokens; nothing inlines a
`Duration` or `Curve`.

| Token | Value | Use |
|---|---|---|
| `press` | 160ms | Press-and-spring-back |
| `micro` | 220ms | Toggles, button feedback |
| `trackChange` | 280ms | Swipe-to-change-track (§13.6) |
| `screen` | 380ms | Route transitions |
| `albumArt` | 500ms | Album-art morph / hero crossfade |
| `breathing` | 4s loop | The barely-perceptible pulse on playing artwork |

Curves: `standard` (entering, easeOutCubic) · `emphasized` (moving within the
screen) · `fastOut` (dismiss — exits are faster than entrances) · `spring` and
`softSpring` (pop-in overshoot).

### §13.2 The interactive-glass spring

Press and morph on Liquid-Glass controls are driven by a real spring simulation,
not a curve: `mass 1.0, stiffness 380, damping 24` (ζ ≈ 0.61 — underdamped, a
small clean overshoot). Drive it with
`AnimationController.animateWith(SpringSimulation(...))`.

**Every animation must have a reduced-motion path**, `breathing` above all — a
4-second infinite loop is exactly what motion sensitivity guidance targets.

## §14 Geometry & radius

`xs` 8 (mini-player art) · `sm` 12 (rows, chips) · `md` 16 (cards, sheets) ·
`lg` 20 (Now Playing art) · `xl` 28 (floating nav bar) · `pill` 999.

**Concentric rule.** A child inset by `padding` inside a surface of
`parentRadius` rounds by `parentRadius − padding`, clamped at 0. Use
`RadiusTokens.concentric()` / `concentricBr()` — never eyeball a nested corner.

---

## Audit — measured against the shipped tokens

Contrast computed per WCAG 2.x from the hex values in `color_scheme.dart`.

### Findings

| # | Finding | Severity | Evidence |
|---|---|---|---|
| 1 | `onSurfaceFaint` fails 4.5:1 as caption text | **High** | 3.42:1 dark · 3.64:1 amoled · 3.00:1 light (on `surface`). 140 references across 40 files, applied to `AppTextTheme.caption` for timestamps and counts — normal text, so 4.5:1 applies, not 3:1. |
| 2 | System font-size preference discarded | **High** | `app.dart:35` sets `textScaler: TextScaler.linear(settings.textScale)`, replacing the inherited scaler. A user with a large system font gets Aura's default unless they find the in-app slider. Contrast with the line directly below it, which correctly composes reduced motion with the OS flag. |
| 3 | `positive` / `warning` are dead tokens | Low | Defined and interpolated in `color_scheme.dart`, but zero `colors.positive` / `colors.warning` references anywhere in `lib/`. Both would also fail 4.5:1 as light-mode text (3.56:1 and 3.73:1). |
| 4 | Dividers are near-invisible | Judgement | 1.16:1 dark · 1.15:1 amoled · 1.23:1 light. Decorative separators are exempt from 1.4.11, so this is not a violation — but if a divider is ever the only thing separating two rows, it is not doing the job. |

### Passing

Everything else measured clean: primary text 16.6–19.3:1 across all three
themes; secondary (`onSurfaceMuted`) 6.2–7.5:1; `accent` 9.7–16.4:1;
`onAccent` on `accent` 8.4–18.0:1; `danger` and `favorite` pass in all themes.
Spacing is a clean 4/8 rhythm, icon sizes and radii are fully tokenised, five
nav tabs is within the ≤5 ceiling, reduced motion composes with the OS, and one
icon family is used throughout with outline/filled marking selection.

### Suggested fixes

1. Lift `onSurfaceFaint` to ≈ `#8A8A92` (dark/amoled) and ≈ `#6E6E7A` (light) to
   clear 4.5:1, **or** split the role: keep the current value for genuinely
   disabled text (exempt from contrast minimums) and add a `onSurfaceCaption`
   role that meets 4.5:1 for timestamps and counts. The split is the more honest
   fix — the current role is documented as serving both purposes, and only one
   of them is exempt.
2. Derive the text scaler from `mq.textScaler` instead of discarding it, so
   `settings.textScale` reads as a multiplier *on top of* the system preference
   and is clamped to a range the layouts survive. This is not a one-line swap —
   `TextScaler.linear` replaces rather than composes, so it needs a small
   `TextScaler` wrapper — but it makes text scaling behave like the
   reduced-motion line directly beneath it, which already composes correctly.
3. Either adopt `positive` / `warning` (scrobble confirmed, slow network) or drop
   them. If adopted, re-tune the light-mode values first.
