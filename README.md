# Crawler-Projektpraktikum

## Setup Instructions

- Download godot from https://godotengine.org/download/windows/
- Clone this repository
- Download and install https://aka.ms/vc14/vc_redist.x64.exe for the git addon to work
- Make sure git is installed and in your PATH
- run `git lfs install` to enable git lfs (or `git lfs install --local` in the project directory)
- Open the project in godot

<div style="border:3px solid #e60000; background-color:#fff3f3; padding:16px; border-radius:6px; color:#b30000;">
<h2 style="margin:0 0 8px;">⚠️ IMPORTANT</h2>
<p style="margin:0 0 8px;">Before opening the project, ensure the required runtime and file handling are set up. Missing these steps can lead to missing assets, broken git history or editor errors.</p>
<ul style="margin:0 0 0 20px;">
	<li>Enable Git LFS for large assets: <code>git lfs install</code> (or <code>git lfs install --local</code> in the project directory).</li>
	<li>Install the Visual C++ Redistributable (x64).</li>
</ul>
</div>

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

## Branching Strategy
- Main branch is `main`
- Develop branch is `dev`
- Feature and other branches should be created from `dev` and merged back into `dev`
- Releases are merged from `dev` into `main`
- Hotfixes are created from `main` and merged back into both `main` and `dev`