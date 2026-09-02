# Project Adapter Template

Copy this directory to attach a new project to ai-control-plane.

## Steps

1. Copy `.control-plane/` files to your project root:
   - `adapter.json` → `.control-plane/adapter.json`
   - `protected-paths.json` → `.control-plane/protected-paths.json`

2. Create `.agents/` directory and copy:
   - `ACTIVE_EDIT_OWNERSHIP.md` → `.agents/ACTIVE_EDIT_OWNERSHIP.md`

3. Replace all `{{PLACEHOLDER}}` values in `adapter.json` and `protected-paths.json`.

4. Run the health check:
   ```
   & "C:\path\to\ai-control-plane\scripts\check-attach-health.ps1" -ClientRoot "."
   ```

5. Commit the attach files:
   ```
   git add .control-plane .agents
   git commit -m "chore: attach ai-control-plane"
   ```

## Fields Reference

| Field | Description |
|-------|-------------|
| adapterId | Unique kebab-case ID for this client |
| project | Project folder name |
| displayName | Human-readable name |
| controlPlaneRepo | Absolute path to ai-control-plane on this machine |
| ownershipFile | Path to ACTIVE_EDIT_OWNERSHIP.md (relative to project root) |
