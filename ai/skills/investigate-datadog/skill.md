# Investigate Production/Staging Issues Using Datadog API

## Overview
This skill guides investigation of application behavior, performance issues, errors, and metrics in **production or staging environments** using the Datadog API. Use this to analyze logs, metrics, APM traces, slow queries, and correlate events to understand system behavior.

## When to Use This Skill

Activate this skill when investigating production or staging issues:
- Errors, timeouts, or exceptions in production/staging
- Performance degradations or slowdowns
- Database query performance and slow queries
- Request patterns or error rate spikes
- Correlating logs with metrics or APM traces
- Understanding system behavior patterns
- Root cause analysis direction for production incidents

## Core Principle: Use Subagents for Investigation

**CRITICAL**: All Datadog API interactions MUST be delegated to subagents to avoid context window overload.

The main agent's role is to:
1. Understand the investigation goal from context
2. Analyze relevant code to identify what's logged and tracked
3. Break down into specific, answerable questions
4. Launch subagents with precise queries
5. Apply scientific method to validate/invalidate hypotheses
6. Synthesize results into actionable insights

Do NOT attempt to query Datadog directly from the main agent context.

## Environment Setup

Required environment variables:
- `$DATADOG_API_KEY`: Read-only Datadog API key
- `$DATADOG_API_KEY_ID`: Datadog Application/API key ID

**Important**: Always use `.fetch` to load these variables to catch configuration errors early:

```ruby
api_key = ENV.fetch("DATADOG_API_KEY")
app_key = ENV.fetch("DATADOG_API_KEY_ID")
```

This will raise a clear error if variables are missing, rather than silently returning `nil`.

## Available Tools and Data Sources

### Datadog API Client Gem
The `datadog_api_client` gem provides programmatic access:

```ruby
require "datadog_api_client"

# Configure the API client (always use .fetch)
config = DatadogAPIClient::Configuration.new.configure do |c|
  c.api_key = ENV.fetch("DATADOG_API_KEY")
  c.application_key = ENV.fetch("DATADOG_API_KEY_ID")
end

api_client = DatadogAPIClient::APIClient.new(config)

# Available APIs
logs_api = DatadogAPIClient::V2::LogsAPI.new(api_client)
metrics_api = DatadogAPIClient::V2::MetricsAPI.new(api_client)
```

### Datadog APM and Slow Queries
Datadog APM tracks application performance including:
- **Slow queries**: Database queries exceeding performance thresholds
- **Trace duration**: End-to-end request latency
- **Service dependencies**: How services interact
- **Resource-level metrics**: Per-endpoint performance

When investigating performance issues, check:
1. APM traces for affected endpoints
2. Slow query logs in Datadog APM
3. Database query execution plans
4. N+1 query patterns

### Application Logging Patterns

The application uses `Glogger` for structured logging with hash-based key/value pairs:

```ruby
# Common patterns in the codebase
Glogger.info("Processing batch", { batch_id: batch.id, size: batch.size })
Glogger.error("Failed to create program", { organization_id: id, errors: errors.full_messages })
Glogger.warn("Bad request exception", { error: e.message, controller: controller_name })
```

### Metrics Tracking

Metrics are sent via `lib/metrics/*` classes:

```ruby
# Example patterns from the codebase
DatadogMetric.timing("payout.completion_time", milliseconds, tags: ["vendor:stripe"])
DatadogMetric.gauge("sidekiq.queue_latency", latency_seconds, tags: ["queue:default"])
```

Common metric namespaces:
- `payout.*` - Payout processing metrics
- `sidekiq.*` - Background job metrics
- `postgresql.*` - Database metrics
- `trace.*` - APM traces

## Investigation Workflow

### Step 1: Extract Context from User Input

**IMPORTANT**: Only ask clarifying questions if information is NOT already provided in context.

Analyze the user's prompt for:

1. **Time Range**: Extract or infer intelligently
   - "yesterday around 2 PM" → Set specific window
   - "this week" → Calculate range, start 1-2 days BEFORE issue likely started
   - "last 24 hours" → Calculate exact window
   - If ambiguous → Ask for clarification

2. **Scope**: Determine from context
   - Error messages mentioned → Focus on logs
   - "slow" or "timeout" → Focus on APM, slow queries, metrics
   - Specific classes/controllers mentioned → Analyze code to find what's logged
   - If unclear → Ask what aspect to investigate

3. **Known Context**: Extract from prompt
   - Stack traces, error messages
   - Customer/organization IDs
   - Git commits or deployment references
   - Specific endpoints or operations

**DO NOT ask for confirmation about what to query.** Use code analysis to determine what's logged and proceed with investigation.

### Step 2: Analyze Code to Understand Logging

Before querying Datadog, understand what the application logs:

1. **Find relevant classes** mentioned in the prompt
2. **Search for `Glogger` calls** in those classes and related code
3. **Identify logged fields** (organization_id, error messages, duration, etc.)
4. **Note metric calls** (`DatadogMetric.timing`, `.gauge`, etc.)
5. **Understand controller/action patterns** for log queries

This analysis informs precise Datadog queries without guessing.

### Step 3: Launch Subagents with Precise Queries

**Each subagent should receive**:
- Exact Datadog query syntax
- Precise time range (with timezone)
- Clear instructions on what data to return
- Freedom to gather adjacent/relevant data

**Example subagent prompt** (this is ONE example - subagents should use creativity):

```
Use the Datadog API to investigate timeout errors with these parameters:

**Primary Query**:
`@controller:"Api::V2::PayoutsController" @action:"create" @error:*timeout* env:production`

**Time Range**:
Start: 2025-12-08 12:00:00 UTC
End: 2025-12-08 18:00:00 UTC

**Required Output**:
- Total error count and timeline (hourly buckets)
- Error message patterns with frequencies
- Affected organization IDs (if logged)
- Sample logs (3-5 representative examples with full context)

**Additional Context to Gather** (use your judgment):
- Check for correlated database metrics (connections, locks)
- Look for slow query logs in APM around same timeframe
- Check if error rate correlates with traffic spikes
- Identify any patterns in affected customers

Return structured JSON with your findings and any hypotheses formed.

Environment variables:
- Use ENV.fetch("DATADOG_API_KEY")
- Use ENV.fetch("DATADOG_API_KEY_ID")
```

### Step 4: Apply Scientific Method

As data comes in, actively work to validate or invalidate hypotheses:

**Hypothesis Formation**:
- Based on initial data, form specific hypotheses
- Example: "Timeouts correlate with database lock contention"

**Hypothesis Testing**:
- Query additional data to test hypothesis
- Example: Check `postgresql.locks.count` metric during timeout window

**Invalidation Attempts**:
- Actively try to disprove hypotheses
- Example: "If hypothesis is true, we should see X. Do we? No? Then hypothesis is invalid."

**Isolation of Variables**:
- Look for counter-examples
- Check if pattern holds across different time ranges
- Verify pattern doesn't exist in unaffected time periods

### Step 5: Synthesize and Present Findings

Present findings as investigation direction, not necessarily complete root cause:

```
## Investigation Results: [Issue Description]

### Summary
[High-level summary of findings]

### Timeline
[Key events in chronological order with evidence]

### Hypotheses Tested
✓ **Validated**: [Hypothesis supported by data]
  - Evidence: [Specific log/metric data]

✗ **Invalidated**: [Hypothesis disproven]
  - Counter-evidence: [Why this doesn't hold]

? **Unclear**: [Needs more investigation]
  - What's needed: [Additional data sources required]

### Evidence
- **Logs**: [Patterns found, sample counts]
- **Metrics**: [Trends, spikes, correlations]
- **APM/Slow Queries**: [Performance data]
- **Correlations**: [Relationships discovered]

### Investigation Direction
[What to look at next - may not be complete root cause]

1. [Specific area to investigate further]
2. [Alternative hypothesis to test]
3. [External systems to check (if AI can't access)]

### Recommendations
[Actionable items based on findings]
```

## Common Investigation Patterns

### Pattern 1: Timeout/Performance Investigation
```
1. Query logs for timeout errors in time range
2. Check APM traces for affected endpoints
3. Look for slow queries in Datadog APM
   - Database query execution time
   - Look for N+1 patterns
   - Check for missing indexes
4. Check database metrics (connections, locks, CPU)
5. Correlate with deployment times
6. Test hypothesis: Does removing time period X invalidate the pattern?
```

### Pattern 2: Error Rate Spike
```
1. Query error logs in time window
2. Group by error type and frequency
3. Identify affected resources (customers, endpoints)
4. Check for code changes (git history)
5. Look for correlated metrics (traffic, resource usage)
6. Test: Does error pattern exist before the spike? After?
```

### Pattern 3: Database Performance
```
1. Query slow query logs in APM
2. Identify problematic queries
3. Check for missing indexes via execution plans
4. Look for N+1 query patterns in logs
5. Check database metrics (CPU, memory, connections)
6. Correlate with application changes
```

## Datadog Query Syntax Reference

### Log Query Syntax
```
# Field matching
@field:"value"                    # Exact match
@field:*partial*                  # Contains
@field:>100                       # Greater than
@field:[100 TO 200]               # Range
-@field:value                     # NOT

# Logical operators
@field:value1 OR @field:value2    # OR
@field:value AND @other:value     # AND

# Common fields
env:production                    # Environment (production/staging)
env:staging                       # Staging environment
status:error                      # Status level
@controller:"ControllerName"      # Rails controller
@action:"action_name"             # Rails action
@error:*timeout*                  # Error patterns
@duration:>1000                   # Duration in ms

# Structured fields (from Glogger)
@organization_id:123
@batch_id:"abc"
@customer_id:456
```

### Metrics Query
```ruby
# Query time series data
metrics_api.query_timeseries({
  from: start_time.to_i,
  to: end_time.to_i,
  query: "avg:metric.name{tag_key:tag_value}"
})

# Aggregations: avg, sum, min, max, count
# Grouping by tags: {tag:value}
```

## Subagent Output Requirements

All subagents MUST return:

1. **Structured data** (JSON or well-formatted tables)
2. **Summary statistics** (counts, rates, percentiles)
3. **Timeline data** (appropriate granularity for time range)
4. **Sample data** (representative examples, NOT full dumps)
5. **Patterns identified** (grouped by common characteristics)
6. **Hypotheses formed** (based on data observed)
7. **Adjacent findings** (related data that might be relevant)

**DO NOT** return:
- Full raw log dumps (always sample)
- Unstructured walls of text
- Data without interpretation
- Single data points without context

## Hypothesis Invalidation Examples

### Example 1: Database Lock Hypothesis
```
Hypothesis: "Timeouts caused by database lock contention"

Test:
- Query: `postgresql.locks.count` during timeout window
- Result: No spike in lock count during timeouts
- Conclusion: ✗ Hypothesis invalidated

Alternative hypothesis:
- Check connection pool exhaustion
- Query: `postgresql.connections.used`
- Result: Connections at 95% capacity during timeouts
- Conclusion: ✓ Connection exhaustion more likely cause
```

### Example 2: Code Change Hypothesis
```
Hypothesis: "Error spike caused by recent deployment"

Test:
- Check git log for deployments before spike
- Result: No deployments in 3 days before spike
- Conclusion: ✗ Deployment not the cause

Alternative:
- Check for external dependency changes
- Query logs for external API errors
- Result: Third-party API response time degraded
- Conclusion: ✓ External dependency issue confirmed
```

## Important Reminders

1. **Always use subagents** - Never query Datadog in main agent context
2. **Use ENV.fetch** - Fail fast with clear errors on missing config
3. **Be autonomous** - Don't ask for query confirmation, use code analysis
4. **Infer intelligently** - Extract time ranges and scope from context
5. **Question only when necessary** - Only ask if critical info is missing
6. **Sample, don't dump** - Return representative data, not everything
7. **Test hypotheses** - Actively try to invalidate findings
8. **Isolate variables** - Look for counter-examples
9. **Think adjacent** - Gather related data that might shed light
10. **Direction, not certainty** - Provide investigation direction, acknowledge limitations
11. **Slow queries matter** - Always check APM for slow queries in performance issues
12. **Production/Staging only** - This skill is for production and staging environments

## Troubleshooting

### Environment Variable Errors
```ruby
# If you see nil errors, check configuration:
begin
  api_key = ENV.fetch("DATADOG_API_KEY")
rescue KeyError => e
  puts "ERROR: #{e.message}"
  puts "Please set DATADOG_API_KEY environment variable"
  exit 1
end
```

### Too Much Data
- Narrow time window
- Add more specific filters
- Request TOP N instead of all results
- Group/aggregate before returning

### Cannot Find Logs
- Verify time range and timezone
- Check environment filter (production vs staging)
- Broaden query (remove restrictive filters)
- Verify field names with wildcards: `@field:*`

### Metrics Don't Match Logs
- Ensure identical time ranges
- Check for clock skew
- Verify metric aggregation intervals
- Confirm tag filters match log filters

## Checklist for Successful Investigation

- [ ] Extracted time range and scope from context
- [ ] Analyzed code to understand what's logged
- [ ] Identified relevant metrics and APM traces
- [ ] Formed initial hypotheses
- [ ] Launched subagents with precise queries
- [ ] Received structured data from subagents
- [ ] Tested hypotheses with data
- [ ] Attempted to invalidate findings
- [ ] Checked for counter-examples
- [ ] Synthesized findings into investigation direction
- [ ] Provided actionable recommendations
- [ ] Documented what still needs investigation

## Additional Resources

- Datadog API Client: https://github.com/DataDog/datadog-api-client-ruby
- Console helpers: `console/datadog.rb` in codebase
- Metrics examples: `lib/metrics/*.rb` in codebase
- Logging examples: Search for `Glogger` calls in relevant classes
