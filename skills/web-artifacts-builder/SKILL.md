---
name: web-artifacts-builder
description: Suite of tools for creating elaborate, multi-component local HTML/web artifacts in Codex using modern frontend web technologies (React, Tailwind CSS, shadcn/ui). Use for complex artifacts requiring state management, routing, or shadcn/ui components - not for simple single-file HTML/JSX snippets.
license: Complete terms in LICENSE.txt
---

# Web Artifacts Builder

To build powerful frontend artifacts in Codex, follow these steps:
1. Initialize the frontend repo using `scripts/init-artifact.sh`
2. Develop your artifact by editing the generated code
3. Bundle all code into a single HTML file using `scripts/bundle-artifact.sh`
4. Share the local file path or start a dev server and give the URL
5. Test the artifact when visual correctness matters

**Stack**: React 18 + TypeScript + Vite + Parcel (bundling) + Tailwind CSS + shadcn/ui

## Design & Style Guidelines

VERY IMPORTANT: To avoid what is often referred to as "AI slop", avoid using excessive centered layouts, purple gradients, uniform rounded corners, and Inter font.
Also follow Codex frontend guidance: build the actual usable experience as the first screen, verify important UI in a browser, and avoid text overlap on mobile and desktop.

## Quick Start

### Step 1: Initialize Project

Run the initialization script to create a new React project:
```bash
bash scripts/init-artifact.sh <project-name>
cd <project-name>
```

This creates a fully configured project with:
- React + TypeScript (via Vite)
- Tailwind CSS 3.4.1 with shadcn/ui theming system
- Path aliases (`@/`) configured
- 40+ shadcn/ui components pre-installed
- All Radix UI dependencies included
- Parcel configured for bundling (via .parcelrc)
- Node 18+ compatibility (auto-detects and pins Vite version)

### Step 2: Develop Your Artifact

To build the artifact, edit the generated files. See **Common Development Tasks** below for guidance.

### Step 3: Bundle to Single HTML File

To bundle the React app into a single HTML file:
```bash
bash scripts/bundle-artifact.sh
```

This creates `bundle.html` - a self-contained HTML file with all JavaScript, CSS, and dependencies inlined. In Codex, give the user the absolute path to this file, or open/test it through the browser tools when appropriate.

**Requirements**: Your project must have an `index.html` in the root directory.

**What the script does**:
- Installs bundling dependencies (parcel, @parcel/config-default, parcel-resolver-tspaths, html-inline)
- Creates `.parcelrc` config with path alias support
- Builds with Parcel (no source maps)
- Inlines all assets into single HTML using html-inline

### Step 4: Share With User

Finally, provide either:

- A local dev server URL, if the app needs a server or live iteration.
- The absolute path to `bundle.html`, if the bundled file works by opening it directly.

### Step 5: Testing/Visualizing the Artifact

Use browser verification for non-trivial UI, charts, animations, responsive layouts, or anything the user will inspect visually.

To test/visualize the artifact, use available Codex tools such as Browser, Chrome, Playwright, or local screenshots. Check at least one desktop and one mobile viewport when layout risk is meaningful.

## Reference

- **shadcn/ui components**: https://ui.shadcn.com/docs/components
