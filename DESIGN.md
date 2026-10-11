# AMBIDEX website design

Design documentation for the static site in `web/` (export in `dist/`). It records what the source
implements so another page can be added without reinventing tokens or components. Every value below
is taken from `web/src/styles.css` and the components in `web/src/components/` unless stated otherwise.

## Overview

Audience: holders and prospective buyers of AMBI who want the facts of the token, the live pool price,
their own balance and a way to act (add the token to a wallet, send it, open the swap). The visual
character is quiet and factual: a near-white page, white cards with a hairline shadow, one indigo accent
for actions and links, and system sans-serif type. Numbers and addresses are treated as first-class
content and use tabular numerals or monospace.

Hierarchy is carried by size, weight and spacing, not by lines. Dense facts live inside cards; prose
sits on the page background. The page is a single scroll with hash anchors (`#stats`, `#lookup`,
`#trade`, `#contract`); there is no router.

The hero layout (copy on the leading side, action card on the trailing side) belongs to the home page.
The rules that apply everywhere are the tokens, the type scale, the card, the button variants, the
field pattern, and the `.section` two-column grid.

## Colors

Defined once in `:root` of `web/src/styles.css`, in `oklch()`. Components use only the semantic tier.

Primitives (hue-named ramps, never used directly in components):

| Token | Value | Notes |
| --- | --- | --- |
| `--gray-50` … `--gray-900` | `oklch(0.985 0.003 260)` → `oklch(0.2 0.02 260)` | neutral ramp, hue 260, steps 50/100/200/300/600/700/900 |
| `--indigo-100/200/500/600/700` | `oklch(0.95 0.03 275)`, `oklch(0.9 0.06 275)`, `oklch(0.5 0.19 275)`, `oklch(0.44 0.19 275)`, `oklch(0.38 0.16 275)` | accent ramp, hue 275 |
| `--green-100/700` | `oklch(0.95 0.04 150)`, `oklch(0.42 0.12 150)` | success |
| `--amber-100/700` | `oklch(0.96 0.05 80)`, `oklch(0.45 0.1 70)` | warning (wrong network notice) |
| `--red-100/700` | `oklch(0.95 0.03 25)`, `oklch(0.46 0.18 25)` | error |

Semantic tokens and their jobs:

| Token | Points at | Use |
| --- | --- | --- |
| `--color-bg-page` | `--gray-50` | `body` background, sticky header (at 0.9 alpha) |
| `--color-bg-surface` | `#fff` | cards, stat tiles, inputs, secondary buttons |
| `--color-bg-sunken` | `--gray-100` | account box, address values, neutral notice |
| `--color-bg-hover` | `--gray-100` | hover fill on nav links, ghost and secondary buttons |
| `--color-border` | `--gray-200` | header rule, card-internal dividers, footer rule |
| `--color-border-strong` | `--gray-300` | input and secondary-button borders |
| `--color-text-primary` | `--gray-900` | headings, values, labels, body |
| `--color-text-secondary` | `--gray-700` | ledes, nav, stat labels, footer, address values |
| `--color-text-muted` | `--gray-600` | captions, hints, placeholders, `dt` labels (smallest text; 6.0:1 or better on every surface it is used on) |
| `--color-accent-solid` / `--color-accent-hover` | `--indigo-500` / `--indigo-600` | the one filled action per section, logo tile |
| `--color-accent-text` | `--indigo-700` | links and link-styled buttons |
| `--color-accent-tint` | `--indigo-100` | reserved for accent-tinted surfaces (og image pill); not used on the page yet |
| `--color-focus` | `--indigo-500` | 2px `:focus-visible` outline with 2px offset |
| `--color-warning-bg/text` | amber | `.notice--warning` |
| `--color-error-bg/text` | red | `.field__error` text and invalid input borders |
| `--color-success-bg/text` | green | reserved; success is currently conveyed with text in the status line |

Measured contrast (WCAG 2, rendered pairs, see `artifacts/validation.md`): all text pairs on the page
are 6.0:1 or higher; white on `--color-accent-solid` is 6.39:1. The accent means "interactive": do not
use indigo for static emphasis. There is no dark theme; `color-scheme: light` is declared.

## Typography

Family: `--font-sans: ui-sans-serif, system-ui, -apple-system, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif`.
No web font is bundled; the system face renders, which keeps the export free of font files. Monospace
for addresses and hashes: `--font-mono: ui-monospace, 'SF Mono', Menlo, Consolas, 'Liberation Mono', monospace`
applied through `code`.

One scale of six sizes:

| Token | Size | Used for |
| --- | --- | --- |
| `--text-xs` | 13px | captions: `.card__footnote`, `.field__hint`, `.stat__detail`, `.address-row__note` |
| `--text-sm` | 14px | UI labels: nav, `.field label`, `.stat__label`, `dt`, small buttons, address values, footer |
| `--text-base` | 16px | body, inputs (16px keeps iOS from zooming), buttons, brand name, `h3.send-form__title` |
| `--text-lg` | 20px | `.card__title` (h2/h3 inside cards), `.stat__value`, `.hero__lede` |
| `--text-xl` | 28px | `.section-title` (h2) |
| `--text-display` | `clamp(2.125rem, 1.5rem + 2.6vw, 2.875rem)` (34–46px) | `h1.hero__title` only |

Weights: 400 body, 500 buttons/labels/nav, 600 card titles, 650 section titles and stat values, 700 h1.
Nothing below 400. Line heights: `--leading-tight` 1.1 (h1, section titles), `--leading-snug` 1.3
(card titles, lede, stat values), `--leading-body` 1.55 (everything else). Letter-spacing −0.02em on h1,
−0.01em on section titles, none elsewhere.

Wrapping: `text-wrap: balance` on h1 and section titles; `text-wrap: pretty` on ledes, hints and footer
prose; `overflow-wrap: anywhere` on `code` and `.stat__value` so hashes and long numbers never overflow.
Changing values (`.num`) use `font-variant-numeric: tabular-nums`. Measure caps: `.hero__copy` 34rem,
`.section-lede` 34rem, footer paragraphs 44rem. Links use `text-decoration-thickness: from-font` and
`text-underline-position: from-font`.

Headings descend: h1 display → h2 28px (`.section-title`) → h3 20px (`.card__title`). The action card's
"Your AMBI" is an h2 styled as `.card__title` (20px) because it sits inside a card in the hero; keep
card headings at `--text-lg` regardless of level.

## Layout

Spacing is a 4px scale: `--space-1` 4px, `-2` 8px, `-3` 12px, `-4` 16px, `-5` 24px, `-6` 32px, `-7` 48px,
`-8` 64px. Within a group use 8–12px; between groups 16px+; between sections 48–64px.

Primitives in `web/src/styles.css`:

- `.container`: `max-width: 68rem`, centered, `padding-inline: max(clamp(1rem, 4vw, 2rem), safe-area insets)`.
  Everything with text sits inside it; backgrounds (header, footer) bleed to the viewport edge.
- `.stack` / `.stack--tight`: vertical flex with 16px / 8px gaps.
- `.button-row`: wrapping flex row with 12px gaps for peer buttons.
- `.section`: single column; from `56rem` a two-column grid `minmax(0,1fr) minmax(0,1.4fr)` with the intro
  (`.section__intro`: title, lede, one action) on the leading side and a card on the trailing side.
- `.hero`: single column; from `56rem` `minmax(0,1.1fr) minmax(20rem,26rem)` with the action card trailing.
- `.stat-grid`: `repeat(auto-fit, minmax(min(100%, 13rem), 1fr))`, so tiles go 1 → 2 → 4 across as width allows.
- `.lookup-form`: stacked; from `40rem` input and button on one row.
- `.kv` / `.kv__row`: definition rows with a `minmax(7rem, 9rem)` label column; `.kv__row--wide` stacks
  label over a long value (hashes).

Breakpoints come from content: 40rem (lookup form) and 56rem (two-column hero and sections). Logical
properties (`padding-inline`, `inset-block-start`, `margin-inline-end`) are used throughout. The header is
`position: sticky` at `--header-height` 3.5rem; anchored sections use `scroll-margin-top` to clear it.

Observed in the browser: no horizontal overflow at 320, 390, 820, 1280 or 1536px; at 390×844 the h1,
lede and the action card's main button are inside the first screen. Native 200% zoom was not tested.

## Elevation & Depth

Flat by default. One shadow token, `--shadow-card`
(`0 0 0 1px oklch(0 0 0 / 0.06), 0 1px 2px oklch(0 0 0 / 0.04), 0 8px 24px -12px oklch(0 0 0 / 0.12)`),
lifts cards, stat tiles and the skip link off the page. It replaces a border: cards have none. Real 1px
borders (`--color-border`) only mark structure: the header rule, footer rule, and dividers inside a card
(`.send-form`, `.address-list`). Inputs and secondary buttons carry a 1px `--color-border-strong` border
because they are controls. The sticky header is the page color at 90% alpha with `backdrop-filter: blur(8px)`
(a solid fallback is declared first). No overlays or modals exist.

## Shapes

`--radius-sm` 6px (small buttons, address values, focus outline), `--radius-md` 10px (buttons, inputs,
stat tiles, notices, account box), `--radius-lg` 16px (cards). Cards use 24px padding with 10px inner
elements, which keeps nested corners visually concentric enough; do not put a 16px-radius element inside
a card. The logo tile is a 64-unit rounded square (`rx=14`) in `web/public/favicon.svg` and `Logo` in
`web/src/components/Icons.tsx`.

## Components

- **Button** (`.button` in `styles.css`, used as `<button>` or `<a>`): 44px min height, 10px radius,
  500 weight, icon gap 8px. Variants: `--primary` (accent fill, white text; exactly one per section),
  `--secondary` (white with strong border), `--ghost` (transparent, secondary text), modifiers `--small`
  (36px) and `--block` (full width). States: hover fills gated by `@media (hover: hover)`; `:active`
  scales to 0.96 only under `prefers-reduced-motion: no-preference`; `:disabled` at 0.6 opacity with
  `not-allowed`; `:focus-visible` 2px accent outline, 2px offset. Busy buttons keep their verb and switch
  the label ("Waiting for wallet…", "Sending…") while disabled.
- **Link button** (`.link-button`): inline text action (Refresh). Looks like a link, is a `<button>`,
  with 4px vertical padding and negative margin for a 24px+ hit area.
- **Field** (`.field`, in `WalletPanel.tsx` and `BalanceLookup.tsx`): visible `<label for>`, 44px input at
  16px, hint in `.field__hint` (13px muted) and error in `.field__error` (14px red with a dot). Errors set
  `aria-invalid="true"`, are linked with `aria-describedby`, say how to fix, and focus the first invalid
  field on submit. Validation runs on submit; submit stays enabled until a request starts.
- **Card** (`.card`): white, 16px radius, shadow, 24px padding, 16px vertical gap. `.card__title`
  (20px/600), `.card__lede`, `.card__footnote`, `.card__header` (title with a trailing small button).
  `.card--action` marks the hero wallet card.
- **Stat tile** (`Stats.tsx`, `.stat`): `dt` label 14px, `dd` value 20px/650 tabular, optional 13px detail.
  Loading shows "Loading…", failure shows "Unavailable" plus a section-level error with a Refresh action.
- **Notice** (`.notice`, `.notice--warning`): icon plus text, sunken or amber. Used for "no wallet"
  and "wrong network" states; the warning carries its own primary button.
- **Address row** (`AddressRow.tsx`): label, optional note, monospace value in a sunken pill, then a
  `CopyButton` and an Etherscan link. The copy button's label changes to "Copied" for two seconds and
  "Select and copy" if the clipboard is unavailable; the accessible name includes what is copied.
- **Key–value list** (`.kv`): facts with short labels; use `.kv__row--wide` for hashes.
- **Icons** (`Icons.tsx`): inline SVG, 16px, 1.5px stroke, `currentColor`, `aria-hidden`.
- **Header / nav** (`App.tsx`): brand link plus three 44px-tall anchor links; a "Skip to content" link is
  the first focusable element.
- **Wallet panel** (`WalletPanel.tsx`): disconnected (connect buttons per detected EIP-6963 wallet, or a
  notice when none), connected (account box, Add AMBI to wallet, Swap link, Send form), and
  wrong-network (warning notice with Switch to Ethereum). Status text lives in `role="status"` lines.

## Do's and Don'ts

- Start a new page from `.container` with `.section` blocks; put prose in `.section__intro` and data in a `.card`.
- Use one `.button--primary` per section; make peers `--secondary` or `--ghost`. Put the accent on the
  background of that one action, never on neutral button text.
- Reference only semantic tokens (`--color-*`, `--text-*`, `--space-*`, `--radius-*`); add a token if a
  role is missing rather than reusing a border color for text.
- Keep text sizes on the six-step scale and weights at 400 or above; headings descend h1 → h2 → h3.
- Every input gets a visible label, a hint before the mistake and an error that names the fix.
- Addresses and hashes go in `code` inside `.kv__code` or an `AddressRow`, never in a fixed-width box.
- Don't add a dark theme, a second accent hue or decorative motion; don't hide content without a cue.

Recipe for another page: copy `web/index.html`'s head (update title, description, og tags), render
`<header>` and `<footer>` from `App.tsx`, add `<main className="container">` with one `.section` per
topic, reuse `Stats`, `AddressRow`, `CopyButton`, `.field` and `.button` classes, and keep the chain facts
in `web/src/config.ts` as the only source of addresses.
