# Decisions Register

<!-- Append-only. Never edit or remove existing rows.
     To reverse a decision, add a new row that supersedes it.
     Read this file at the start of any planning or research phase. -->

| # | When | Scope | Decision | Choice | Rationale | Revisable? | Made By |
|---|------|-------|----------|--------|-----------|------------|---------|
| D001 |  | architecture | AHE lifecycle integration with Qwen Code | Use Qwen Code's native hooks system (SessionStart, PreToolUse) rather than MCP or external daemon | Research of OMX (28k stars), Oh My Pi, GSD2, and Hermes Agent shows that meta-layers integrate via lifecycle hooks + config injection, not MCP. MCP is for external tool exposure. Qwen Code already supports SessionStart and PreToolUse hook types in settings.json. This matches the industry pattern. | Yes | collaborative |
| D002 |  | architecture | Pipeline visibility mechanism | Two-layer: startup hook surfaces findings in conversation context (immediate), reseed script persists pipeline findings to status file (durable) | Layer 1 gives immediate visibility with no risk (startup hook already exists). Layer 2 provides persistence across sessions. Avoids auto-editing QWEN.md until differential measurement proves value. | Yes | collaborative |
| D003 |  | architecture | Session-end capture approach | PreToolUse heartbeat hook tracks ongoing state; stale-detection on next startup infers ended sessions; QWEN.md instruction triggers closure in-session | Qwen Code has no native SessionEnd hook type. PreToolUse provides the only reliable hook point. Writing cumulative state per-tool-call is lightweight and ensures the last session's state is never lost. Stale detection handles abrupt exits. | Yes | collaborative |
