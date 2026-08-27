# GitHub Support ticket — stuck workflow run cannot be cancelled

File at: https://support.github.com (must be filed by the org owner / billing
contact for metanorma). Suggested fields and body below.

- **Subject:** Workflow run stuck in "queued" state — cancel API returns HTTP 500
- **Repository:** metanorma/serialbench
- **Run:** https://github.com/metanorma/serialbench/actions/runs/32621796565
- **Category:** Actions / workflow runs

## Body

A workflow run in metanorma/serialbench has been stuck in `queued` state since
2026-08-23 06:00:32 UTC (workflow `benchmark-weekly`, triggered via
`workflow_dispatch`):

- Run ID: 32621796565
- It has never created a single job (the runs/<id>/jobs API returns
  `total_count: 0` after ~24h)
- Cancelling fails server-side with HTTP 500 from both the UI and the REST API:

```
POST /repos/metanorma/serialbench/actions/runs/32621796565/cancel
→ 500 {"message": "Failed to cancel workflow run", "status": 500}
```

(reproduced repeatedly between 2026-08-23 ~10:00Z and 2026-08-24)

While it existed, this wedged run also appeared to hold the in-progress slot of
the workflow's concurrency group (`"pages"` at the time), preventing any other
run of that workflow from starting; we worked around it by renaming the
concurrency group, so the operational impact is now limited to the stuck run
itself.

Please force-cancel / purge run 32621796565 so it stops occupying queue state.

Additional context: around the same window, several runs of the same workflow
queued at zero jobs and were only recoverable by cancellation (those cancels
succeeded); only 32621796565 consistently returns 500.

## Update 2026-08-24 ~05:30Z — second incident, broader scope

Starting 2026-08-24 04:01Z (immediately after a successful release workflow
pushed a bump commit + tag to main), ALL workflows in metanorma/serialbench
stopped starting jobs: five runs (including two `rake` CI runs on push
events, which normally begin within seconds) sat `queued`/`pending` with
zero jobs for over 80 minutes. https://www.githubstatus.com reported
"All Systems Operational" throughout, and the repo's Actions permissions
are enabled with no changes.

This is the same zero-job orchestration stall as the primary report, now
affecting every workflow rather than one concurrency group.

## Update 2026-08-25 09:35Z — fourth incident

From 01:45Z, two runs wedged again: one `pending` with zero jobs for 7.5
hours, one `queued` with 47 created jobs that never started (including
plain `ubuntu-latest` setup jobs). Cancelling the queued run released the
queue within a minute, letting the remaining run start — the same
cancel-to-unwedge remedy as every prior incident. Runner evictions
("shutdown signal", ~6 minutes into jobs) also recurred throughout
2026-08-24/25, requiring repeated `rerun --failed` cycles.
