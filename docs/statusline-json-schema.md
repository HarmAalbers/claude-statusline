# Claude Code Statusline JSON Schema

This document describes the complete JSON schema that Claude Code sends to the statusline via stdin.

## Complete Schema (v2.1.x)

```json
{
  "hook_event_name": "Status",
  "session_id": "abc123...",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/current/working/directory",
  "version": "2.1.11",

  "model": {
    "id": "claude-opus-4-5-20251101",
    "display_name": "Opus 4.5"
  },

  "workspace": {
    "current_dir": "/current/working/directory",
    "project_dir": "/original/project/directory"
  },

  "output_style": {
    "name": "default"
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

| Field | Type | Description |
|-------|------|-------------|
| `hook_event_name` | string | Always "Status" for statusline hook |
| `session_id` | string | Unique session identifier |
| `transcript_path` | string | Path to session JSONL transcript file |
| `cwd` | string | Current working directory |
| `version` | string | Claude Code version |

### Model Information

| Field | Type | Description |
|-------|------|-------------|
| `model.id` | string | Full model identifier (e.g., `claude-opus-4-5-20251101`) |
| `model.display_name` | string | Human-friendly name (e.g., `Opus 4.5`) |

### Workspace

| Field | Type | Description |
|-------|------|-------------|
| `workspace.current_dir` | string | Current working directory |
| `workspace.project_dir` | string | Original project root when Claude Code was launched |

### Cost Tracking

| Field | Type | Description |
|-------|------|-------------|
| `cost.total_cost_usd` | float | Session cost in USD |
| `cost.total_duration_ms` | int | Total session duration in milliseconds |
| `cost.total_api_duration_ms` | int | Time spent on API calls in milliseconds |
| `cost.total_lines_added` | int | Lines of code added this session |
| `cost.total_lines_removed` | int | Lines of code removed this session |

### Context Window

| Field | Type | Description |
|-------|------|-------------|
| `context_window.context_window_size` | int | Max tokens (200k for most, 1M for Sonnet 4.5) |
| `context_window.used_percentage` | float | Pre-calculated % used (added v2.1.6) |
| `context_window.remaining_percentage` | float | Pre-calculated % remaining (added v2.1.6) |
| `context_window.total_input_tokens` | int | Cumulative input tokens (session total) |
| `context_window.total_output_tokens` | int | Cumulative output tokens (session total) |

### Current Usage (Cache Metrics)

| Field | Type | Description |
|-------|------|-------------|
| `context_window.current_usage.input_tokens` | int | Current turn input tokens |
| `context_window.current_usage.output_tokens` | int | Current turn output tokens |
| `context_window.current_usage.cache_creation_input_tokens` | int | Tokens written to cache |
| `context_window.current_usage.cache_read_input_tokens` | int | Tokens read from cache |

## Important Notes

### Token Counting Caveats

The `total_input_tokens` and `total_output_tokens` appear to be session totals (all tokens ever sent/received), not the current context window contents. This can show values exceeding the context window size (e.g., 340k tokens for a 200k window).

**Recommended approach**: Use the pre-calculated `used_percentage` and `remaining_percentage` fields (added in v2.1.6) rather than calculating from token counts.

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
.context_window.total_input_tokens     # Fallback only
.context_window.total_output_tokens    # Fallback only

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
