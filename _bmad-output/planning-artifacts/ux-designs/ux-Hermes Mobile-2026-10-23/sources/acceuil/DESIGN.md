---
name: Lumina Conversational
colors:
  surface: '#0f131c'
  surface-dim: '#0f131c'
  surface-bright: '#353943'
  surface-container-lowest: '#0a0e17'
  surface-container-low: '#181b25'
  surface-container: '#1c1f29'
  surface-container-high: '#262a34'
  surface-container-highest: '#31353f'
  on-surface: '#dfe2ef'
  on-surface-variant: '#c2c6d6'
  inverse-surface: '#dfe2ef'
  inverse-on-surface: '#2c303a'
  outline: '#8c909f'
  outline-variant: '#424754'
  surface-tint: '#adc6ff'
  primary: '#adc6ff'
  on-primary: '#002e6a'
  primary-container: '#4d8eff'
  on-primary-container: '#00285d'
  inverse-primary: '#005ac2'
  secondary: '#4edea3'
  on-secondary: '#003824'
  secondary-container: '#00a572'
  on-secondary-container: '#00311f'
  tertiary: '#d0bcff'
  on-tertiary: '#3c0091'
  tertiary-container: '#a078ff'
  on-tertiary-container: '#340080'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#d8e2ff'
  primary-fixed-dim: '#adc6ff'
  on-primary-fixed: '#001a42'
  on-primary-fixed-variant: '#004395'
  secondary-fixed: '#6ffbbe'
  secondary-fixed-dim: '#4edea3'
  on-secondary-fixed: '#002113'
  on-secondary-fixed-variant: '#005236'
  tertiary-fixed: '#e9ddff'
  tertiary-fixed-dim: '#d0bcff'
  on-tertiary-fixed: '#23005c'
  on-tertiary-fixed-variant: '#5516be'
  background: '#0f131c'
  on-background: '#dfe2ef'
  surface-variant: '#31353f'
typography:
  headline-lg:
    fontFamily: Geist
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Geist
    fontSize: 26px
    fontWeight: '600'
    lineHeight: 34px
    letterSpacing: -0.015em
  headline-md:
    fontFamily: Geist
    fontSize: 22px
    fontWeight: '500'
    lineHeight: 30px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Geist
    fontSize: 18px
    fontWeight: '500'
    lineHeight: 26px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 26px
    letterSpacing: -0.005em
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 22px
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 18px
  label-lg:
    fontFamily: Geist
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Geist
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Geist
    fontSize: 10px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.04em
  code-inline:
    fontFamily: Geist
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-mobile: 0.75rem
  margin: 1.5rem
  margin-mobile: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1.25rem
  space-xl: 2rem
---

## Brand & Style

This design system embodies refined intelligence: a serene, distraction-free environment engineered for human-AI collaboration. Drawing inspiration from modern high-end editorial tools and progressive conversational assistants, the visual language balances clinical precision with organic warmth.

The aesthetic fuses **Minimalism** with subtle **Tonal Depth**:
- **Clarity over ornamentation:** Interfaces recede to let thought, dialogue, and synthesized output lead.
- **Micro-tactility:** Interactive anchors (input pills, voice triggers, model selector nodes) possess crisp, physical affordances without visual clutter.
- **Luminous accents:** Generative states and active processing moments are communicated through focused, glowing radial accents and ambient rings, rather than loud decorative textures.

## Colors

The palette is anchored in an obsidian slate environment designed for extended reading sessions and OLED power efficiency, highlighted by focused luminescence.

- **Primary (`#3B82F6` - Cobalt Luminance):** Used for focal system responses, prompt completions, active audio waveforms, and primary send states.
- **Secondary (`#10B981` - Emerald Synthesis):** Reserved for grounded states, verification badges, token metrics, and real-time tool execution markers.
- **Tertiary (`#8B5CF6` - Neural Violet):** Marks generative transition stages, model selector toggles, and multi-modal attachment processing.
- **Neutral (`#090D16` - Deep Obsidian Slate):** Establishes the canvas base. Derived neutral steps (`#111827`, `#1F2937`, `#374151`) dictate surfaces, floating bars, and user bubble boundaries, avoiding pure pitch black to preserve spatial layer separation.
- **Accent Ring (`#60A5FA` / `#A78BFA` gradient blend):** Utilized exclusively for the pulsating active ring of the AI avatar during thinking/streaming cycles.

## Typography

The type system creates an intentional pairing: **Geist** for technical precision in headlines, meta markers, badges, and controls; **Inter** for organic, high-legibility conversational reading in extended message flows.

- **Geist (Headlines & Labels):** Provides crisp modern geometric contours, keeping metadata, pill prompts, and model indicators distinct from conversational text.
- **Inter (Body & Dialogue):** Tuned for comfortable optical rendering against dark surfaces. Extended line heights prevent cognitive fatigue across dense code blocks and synthesized markdown responses.
- **Formatting Rules:** Inline code blocks use `code-inline` with subtle background tinting. Markdown lists enforce 8px bottom margins between nodes for distinct scannability.

## Layout & Spacing

Layout centers around a fluid conversational vertical river designed primarily for mobile-first thumb-zone navigation, adaptable to tablet and desktop sidebars.

- **Layout Structure:** Single-column message stream constrained to max 768px on wider viewports. Bottom input elements float above the scroll plane, anchored to the hardware bottom safe area.
- **Conversation Threading Rhythm:**
  - Turn gap (between distinct user & assistant turns): `space-xl` (32px).
  - Intra-turn gap (between multi-part bubbles or artifacts): `space-sm` (8px).
  - Avatar-to-bubble horizontal clearance: `space-md` (12px).
- **Responsive Handling:** On mobile viewports (`<640px`), outer canvas margin compresses to `margin-mobile` (16px) to maximize message bubble width while sustaining edge buffer.

## Elevation & Depth

Visual hierarchy relies on **Tonal Layering** coupled with **Subtle Luminous Diffusion** rather than stark drop shadows:

- **Level 0 (Canvas Base):** Deep slate `#090D16`. Background for default scroll canvas.
- **Level 1 (System / Assistant Surface):** Transparent canvas background with flush baseline; assistant responses occupy Level 0 or a bare minimal `#0F172A` tone without heavy container edges to reinforce seamless flow.
- **Level 2 (User Message Bubbles):** `#1E293B` with a crisp 1px border (`rgba(255, 255, 255, 0.08)`).
- **Level 3 (Floating Input & Controls):** `#111827` at 85% opacity with an active `16px` backdrop-filter blur, rimmed by a micro-stroke (`rgba(255, 255, 255, 0.12)`).
- **Active AI Ring Glow:** The avatar uses a dual-layer box shadow: an inner stroke of `0 0 0 1.5px rgba(96, 165, 250, 0.9)` and an outer bloom of `0 0 14px rgba(96, 165, 250, 0.45)` during active generation.

## Shapes

The interface embraces a **pill-dominant geometry** (`roundedness: 3`) to evoke tactile fluidity and software friendliness:

- **Input Shell:** True continuous pill (`rounded-full` / `9999px`), ensuring standard thumb comfort regardless of expansion.
- **User Chat Bubbles:** Rounded with `1.25rem` (20px) corners, with the bottom-right terminal corner slightly attenuated to `0.375rem` (6px) to anchor directionality.
- **Assistant Artifacts & Cards:** `rounded-lg` (1rem / 16px) with precise interior padding for code blocks and rich citations.
- **Action Nodes & Badges:** Full capsule geometries for status tokens and suggestion chips.

## Components

### 1. Chat Bubbles
- **User Bubble:** Aligned right, background `#1E293B`, text `#F8FAFC`, subtle top-edge highlight stroke (`rgba(255, 255, 255, 0.1)`). Max width: 85% of viewport width.
- **Assistant Response:** Aligned left, flush minimal background, text `#E2E8F0`. Features seamless copy, thumbs up/down, and branch retry micro-actions that reveal on hover or tap.

### 2. Floating Input Bar
- Composed of an all-in-one pill container (`bg-[#111827]/90`, backdrop-blur `16px`, border `rgba(255, 255, 255, 0.12)`).
- **Left Slot:** Attachment paperclip / plus icon with subtle micro-interaction state.
- **Center Slot:** Auto-expanding text input with placeholder styled in muted slate (`#64748B`).
- **Right Slot:** Dual-action cluster featuring an audio/voice waveform icon and a circular primary send button (`#3B82F6` base; transitions from muted gray to vibrant blue on input detection).

### 3. AI Avatar with Active Glow Ring
- 32x32px circular token featuring an iconographic node or bespoke monogram on `#0F172A`.
- Surrounded by an offset 2px concentric indicator ring. When streaming or synthesizing, the ring pulses smoothly using an emerald-to-cobalt animated gradient with ambient glow diffusion.

### 4. Status Badges & Model Switcher
- Pill-shaped badges using `label-md` typography.
- Background `rgba(255, 255, 255, 0.05)`, border `rgba(255, 255, 255, 0.1)`. Includes a miniature 6px indicator dot representing latency/system health or specific model tier (e.g., Fast vs. Deep Reasoning).

### 5. Quick Suggestion Chips
- Horizontally scrollable row situated above the input bar.
- Low-contrast translucent dark slate fill, bordered by hairline outlines, displaying contextual prompt starters with subtle hover/press compressions.