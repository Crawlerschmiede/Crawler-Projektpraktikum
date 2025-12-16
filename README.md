# Crawler-Projektpraktikum

Godot 4 project for a small crawler-style game.

## Setup Instructions

### Prerequisites

- Install **Godot 4.5.1** (this is the version used in CI).
- Install Git (and ensure it is on your PATH).
- Install Git LFS.
- (Windows) Install the Visual C++ Redistributable (x64): https://aka.ms/vc14/vc_redist.x64.exe

### Clone + Git LFS

- Clone this repository.
- Enable Git LFS so large assets are pulled correctly:

  ```bash
  git lfs install
  git lfs pull
  ```

### Open and Run

- Open the project in Godot (open the folder containing `project.godot`).
- Press **F5 / Run Project**.

<div style="border:3px solid #e60000; background-color:#fff3f3; padding:16px; border-radius:6px; color:#b30000;">
<h2 style="margin:0 0 8px;">⚠️ IMPORTANT</h2>
<p style="margin:0 0 8px;">Before opening the project, ensure the required runtime and file handling are set up. Missing these steps can lead to missing assets, broken git history or editor errors.</p>
<ul style="margin:0 0 0 20px;">
	<li>Enable Git LFS for large assets: <code>git lfs install</code> (or <code>git lfs install --local</code> in the project directory).</li>
	<li>Install the Visual C++ Redistributable (x64).</li>
</ul>
</div>

## Building / Exporting

- Export presets are stored in `export_presets.cfg`.
- CI and releases use these export names:
  - `Windows Desktop` → produces `build/windows/Crawler-Projektpraktikum.exe` + `.pck`
  - `Linux` → produces `build/linux/Crawler-Projektpraktikum.x86_64` + `.pck`

To export locally, use the Godot Editor: **Project → Export…** and select the preset.

## Optional Addons

### GDScript Toolkit

- Install the GDScript Toolkit via uv or pip directly
  - uv: `uv tool install "gdtoolkit==4.*"`
  - pip: `pip install "gdtoolkit==4.*"`

```
# Format GDScript files
gdformat scripts/

# Lint GDScript files
gdlint scripts/
```

Linting Docs: https://github.com/Scony/godot-gdscript-toolkit/wiki/3.-Linter

### Pre Commit Hook
- Install pre-commit via uv or pip directly
  - uv: `uv tool install pre-commit`
  - pip: `pip install pre-commit`
- Install the git hooks
  - `pre-commit install`

## CI (GitHub Actions)

These workflows live in `.github/workflows/`:

- `gdscript-format.yml`
  - Runs on pushes to `dev`, and on PRs targeting `dev` (and can be run manually)
  - Auto-formats GDScript in `scripts/` via `gdformat`
  - If formatting changes files, it commits them back to the same branch (uses `GITHUB_TOKEN`)
  - Safety: only runs with write permissions for branches in this repo (skips PRs from forks)
- `gdscript-lint.yml`
  - Runs on pushes to `dev` and on PRs targeting `dev` or `main`
  - Runs `gdlint scripts/`
- `test-build.yml`
  - Runs on pushes to `dev` and on PRs targeting `dev` or `main`
  - Exports Windows and Linux builds (build validation)
- `release.yml`
  - Runs when you push a tag matching `v*` (example: `v0.1.0`)
  - Also supports manual runs via **workflow_dispatch** with a `tag` input
  - Builds + packages Windows (`.zip`) and Linux (`.tar.gz`) and publishes a GitHub Release

## Branching Strategy

- Main branch is `main`
- Develop branch is `dev`
- Feature and other branches should be created from `dev` and merged back into `dev`
- Releases are merged from `dev` into `main`
- Hotfixes are created from `main` and merged back into both `main` and `dev`

## Release Process (dev → main → versioned release)

This is the current workflow:

1. Create a PR in GitHub to merge `dev` → `main`.
2. Merge the PR in GitHub after CI passes.
3. Create a versioned release by tagging `main`:

   ```bash
   git checkout main
   git pull
   git tag -a v0.1.0 -m "Release v0.1.0"
   git push origin v0.1.0
   ```

   This triggers the release workflow which builds and publishes a GitHub Release with downloadable artifacts.

4. Sync `dev` back with `main`:

   ```bash
   git checkout dev
   git pull origin main
   git push origin dev
   ```