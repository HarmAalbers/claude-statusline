# Claude Code Statusline JSON Schema

This document describes the complete JSON schema that Claude Code sends to the statusline via stdin.

## Complete Schema (v2.x)

```json
{
  "hook_event_name": "Status",
  "session_id": "abc123...",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/current/working/directory",
  "version": "2.1.11",
  "exceeds_200k_tokens": false,

  "model": {
    "id": "claude-opus-4-6-20260101",
    "display_name": "Opus"
  },

  "workspace": {
    "current_dir": "/current/working/directory",
    "project_dir": "/original/project/directory"
  },

  "output_style": {
    "name": "default"
  },

  "vim": {
    "mode": "NORMAL"
  },

  "agent": {
    "name": "my-agent"
  },

  "cost": {
    "total_cost_usd": 0.01234,
    "total_duration_ms": 45000,
    "total_api_duration_ms": 2300,
    "total_lines_added": 156,
    "total_lines_removed": 23
  },

  "context_window": {
    "context_window_size": 200000,
    "used_percentage": 42.5,
    "remaining_percentage": 57.5,
    "total_input_tokens": 15234,
    "total_output_tokens": 4521,
    "current_usage": {
      "input_tokens": 8500,
      "output_tokens": 1200,
      "cache_creation_input_tokens": 5000,
      "cache_read_input_tokens": 2000
    }
  }
}
```

## Field Reference

### Root Level Fields

| Field                | Type    | Description                                                          |
|----------------------|---------|----------------------------------------------------------------------|
| `hook_event_name`    | string  | Always "Status" for statusline hook                                  |
| `session_id`         | string  | Unique session identifier                                            |
| `transcript_path`    | string  | Path to session JSONL transcript file                                |
| `cwd`                | string  | Current working directory (deprecated, use `workspace.current_dir`)  |
| `version`            | string  | Claude Code version                                                  |
| `exceeds_200k_tokens`| boolean | Whether total tokens exceed the 200K threshold (long-context pricing)|

### Model Information

| Field                | Type   | Description                                                            |
|----------------------|--------|------------------------------------------------------------------------|
| `model.id`           | string | Full model identifier (e.g., `claude-opus-4-6-20260101`)              |
| `model.display_name` | string | Human-friendly name (e.g., `Opus`). May be just the tier name.        |

### Workspace

| Field                   | Type   | Description                                         |
|-------------------------|--------|-----------------------------------------------------|
| `workspace.current_dir` | string | Current working directory (preferred over `cwd`)    |
| `workspace.project_dir` | string | Original project root when Claude Code was launched |

### Output Style

| Field               | Type   | Description                                                        |
|---------------------|--------|--------------------------------------------------------------------|
| `output_style.name` | string | Current output style (e.g., `default`, `explanatory`, `concise`)   |

### Vim Mode

| Field      | Type   | Description                                                     |
|------------|--------|-----------------------------------------------------------------|
| `vim.mode` | string | Current vim mode when vim mode is enabled (`NORMAL`, `INSERT`)  |

> **Note**: The `vim` object is only present when vim mode is enabled in settings.

### Agent

| Field        | Type   | Description                                  |
|--------------|--------|----------------------------------------------|
| `agent.name` | string | Agent name when using `--agent` flag         |

> **Note**: The `agent` object is only present when running with a custom agent.

### Cost Tracking

| Field                        | Type  | Description                             |
|------------------------------|-------|-----------------------------------------|
| `cost.total_cost_usd`        | float | Session cost in USD                     |
| `cost.total_duration_ms`     | int   | Total session duration in milliseconds  |
| `cost.total_api_duration_ms` | int   | Time spent on API calls in milliseconds |
| `cost.total_lines_added`     | int   | Lines of code added this session        |
| `cost.total_lines_removed`   | int   | Lines of code removed this session      |

### Context Window

| Field                                 | Type       | Description                                                                  |
|---------------------------------------|------------|------------------------------------------------------------------------------|
| `context_window.context_window_size`  | int        | Max tokens (200K default, 1M for Opus 4.6, Sonnet 4.6, Sonnet 4.5, Sonnet 4)|
| `context_window.used_percentage`      | float/null | Pre-calculated % used (input tokens only). Null before first API call.       |
| `context_window.remaining_percentage` | float/null | Pre-calculated % remaining. Null before first API call.                      |
| `context_window.total_input_tokens`   | int        | Cumulative input tokens (session total)                                      |
| `context_window.total_output_tokens`  | int        | Cumulative output tokens (session total)                                     |

### Current Usage (Cache Metrics)

| Field                                                      | Type     | Description                |
|------------------------------------------------------------|----------|----------------------------|
| `context_window.current_usage.input_tokens`                | int      | Current turn input tokens  |
| `context_window.current_usage.output_tokens`               | int      | Current turn output tokens |
| `context_window.current_usage.cache_creation_input_tokens` | int      | Tokens written to cache    |
| `context_window.current_usage.cache_read_input_tokens`     | int      | Tokens read from cache     |

> **Note**: `current_usage` is `null` before the first API call in a session.

## Important Notes

### Null Values Early in Session

Several fields may be `null` or missing before the first API call completes:
- `context_window.used_percentage` and `remaining_percentage` — null until the first API response
- `context_window.current_usage` — null before first API call
- `cost.total_cost_usd` — 0 until first API call

Your statusline script should handle these gracefully (e.g., `// 0` or `// "__EMPTY__"` in jq).

### used_percentage Calculation

The `used_percentage` field is calculated from **input tokens only**: `input_tokens + cache_creation_input_tokens + cache_read_input_tokens`. It does **not** include `output_tokens`. When falling back to manual calculation, use input tokens only.

### Token Counting Caveats

The `total_input_tokens` and `total_output_tokens` are session totals (all tokens ever sent/received), not the current context window contents. This can show values exceeding the context window size (e.g., 340k tokens for a 200k window).

**Recommended approach**: Use the pre-calculated `used_percentage` and `remaining_percentage` fields rather than calculating from token counts.

### Long-Context Pricing

When `exceeds_200k_tokens` is `true`, long-context pricing applies:
- Input pricing doubles (e.g., Opus 4.6: $5 → $10/MTok, Sonnet 4.x: $3 → $6/MTok)
- Output pricing increases by 50% (e.g., Opus 4.6: $25 → $37.50/MTok)

### Cache Efficiency

Cache efficiency can be calculated from:
- `cache_read_input_tokens` - Tokens retrieved from cache (90% cheaper)
- `cache_creation_input_tokens` - Tokens written to cache

Higher cache read ratio = lower cost.

### Fields NOT Yet Exposed

The following fields have been requested but are not yet available:

- `rate_limit.session_used_percentage` - Hourly quota usage
- `rate_limit.session_reset_time` - When hourly quota resets
- `rate_limit.weekly_used_percentage` - Weekly quota usage
- `rate_limit.weekly_reset_time` - When weekly quota resets
- `auto_compact_threshold_percent` - Compaction threshold setting

## Usage in statusline.sh

This project extracts the following fields for display:

```bash
# Core fields
.workspace.current_dir
.cost.total_cost_usd
.model.display_name
.model.id
.session_id
.transcript_path

# Context window (prefer pre-calculated percentages)
.context_window.used_percentage        # Use this!
.context_window.remaining_percentage   # Use this!
.context_window.context_window_size
.context_window.total_input_tokens     # Fallback only (input-only calc)

# Cache efficiency
.context_window.current_usage.cache_read_input_tokens
.context_window.current_usage.cache_creation_input_tokens

# Code productivity
.cost.total_lines_added
.cost.total_lines_removed

# Duration metrics
.cost.total_duration_ms
.cost.total_api_duration_ms
```

## Version History

- **v2.1.6**: Added `used_percentage` and `remaining_percentage` fields
- **v2.1.x**: Added `total_lines_added`, `total_lines_removed` in cost object
- **v2.x**: Added `exceeds_200k_tokens`, `output_style`, `vim`, `agent` objects
