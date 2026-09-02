# Reference-Client Adapter

Reference-Client is the first client repository using this control plane.

Client-side adapter files live in the Reference-Client repo root under:

```text
<reference-client-repo>/.control-plane/
  adapter.json
  protected-paths.json
  verification.json
  install-local-hooks.ps1
  smoke-test.ps1
```

This adapter is intentionally thin.

Its job is to tell the control plane:

- where project state lives
- what paths are protected
- what verification commands apply
- how to wire local hooks back to the extracted control plane

Canonical shared adapter metadata now lives in:

```text
ai-control-plane/adapters/reference-client/adapter.json
```

That shared file describes the stable Reference-Client adapter contract.
The client-local `.control-plane/adapter.json` in the Reference-Client repo remains the
machine-specific overlay because it carries environment-specific values such as
the local `controlPlaneRepo` path.
