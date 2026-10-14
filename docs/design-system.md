# Aura — Design System

> **Status:** derived from the shipped code, cross-checked against the
> `ui-ux-pro-max` skill database (Flutter stack rules, 119 UX guidelines, native
> app pro-rules). The contrast findings this document opened have since been
> fixed in `color_scheme.dart` and `app.dart`; the audit at the end records
> what changed.
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
| `onSurfaceFaint` | `#7F7F85` | `#85858B` | `#6F6F7B` |
| `accent` | `#5FC6BC` | `#5FC6BC` | `#16161B` |
| `divider` | `#1C1C1F` | `#222226` | `#E7E7ED` |
| `glassTint` | `#04FFFFFF` | `#04FFFFFF` | `#9EFFFFFF` |
| `danger` | `#FF6B6B` | `#FF6B6B` | `#D62B2B` |
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

**Verified** (see the audit at the end): every text role clears 4.5:1 against
every ground it can land on — `background`, `surface` and `surfaceElevated` — in
all three themes, and the system font-size preference is honoured.

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

Contrast computed per WCAG 2.x directly from the hex values in
`color_scheme.dart`, against **every ground a role can land on** —
`background`, `surface` and `surfaceElevated` — in all three themes. Text roles
are held to 4.5:1; `favorite` and `accent` are graphics and held to 3:1.

**Current status: no failures.** The four findings below were open when this
document was first written and have since been fixed in code.

### Resolved

| # | Finding | Was | Now |
|---|---|---|---|
| 1 | `onSurfaceFaint` failed 4.5:1 as caption text in all three themes, across 136 references in 40 files | 3.09 / 3.36 / 2.73:1 | **4.53 / 4.54 / 4.52:1** |
| 2 | `app.dart` replaced the inherited `textScaler`, discarding the OS font-size preference | system pref ignored | composed, clamped 0.85–2.0 |
| 3 | `positive` / `warning` would fail 4.5:1 as light-mode text | 3.25 / 3.39:1 | **4.53 / 4.51:1** |
| 4 | `danger` passed on white cards but failed on the light page background | 4.14:1 | **4.51:1** |

Finding 4 was surfaced only when the audit was widened to measure every role
against `background` as well as `surface`. The original pass measured `danger`
against `surface` alone, where it read 4.55:1 — a reminder that a role has to
clear the *worst* ground it can land on, not a representative one.

### A note on finding 1

The first draft of this document proposed *splitting* the role: keep
`onSurfaceFaint` for disabled text, which is exempt from contrast minimums, and
add a compliant `onSurfaceCaption` for real content. Checking the call sites
before implementing showed the premise was wrong — there are **zero**
disabled-state usages. Every one of the 136 references is a caption, a count, a
timestamp, or an icon. With nothing left to claim the exemption, the correct fix
was simply to lift the role itself to meet 4.5:1, which is what shipped.

### Still open — by decision, not oversight

- **`positive` and `warning` remain unused.** Their values are now correct in
  every theme, so adopting them is safe whenever a real site appears (scrobble
  confirmed, slow network). Wiring them into the existing snackbars is a design
  decision, not a defect, and was deliberately left alone.
- **Dividers sit near the threshold of visibility** — 1.16:1 dark, 1.15:1
  amoled, 1.23:1 light. Decorative separators are exempt from the non-text
  contrast rule, so this is not a violation. It becomes one the moment a divider
  is the only thing separating two rows.
- **Four decorative graphics derive from `onSurfaceFaint` via `withOpacity()`**
  (0.28–0.45): a drag handle, an equaliser track, and two inactive-dot
  indicators. All improved automatically with the lift. They are graphics rather
  than text, so they are out of scope for a caption-contrast fix; the
  inactive/current page dots are the ones worth a second look, since they carry
  state.

### Clean

Primary text 15.3–16.6:1 worst-case across all three themes; secondary
5.9–6.5:1. Spacing holds a 4/8 rhythm; icon sizes, radii and motion are fully
tokenised; five nav tabs is within the ≤5 ceiling; one icon family throughout
with outline/filled marking selection; and reduced motion composes with the OS
flag across `PressScale`, the nav bar and Now Playing.

### Not verified here

There is no Flutter SDK in the environment these changes were made in, so
`flutter analyze` and the widget tests have **not** been run against them. The
colour changes are literal constant swaps and carry little risk. The
`textScaler` change is real logic and should be exercised on device — in
particular at a 2.0 composed scale, which the app could not previously reach.
