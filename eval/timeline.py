#!/usr/bin/env python3
"""Print where the time goes in a run log: clerk (main session) actions and subagent durations."""
import json, sys, datetime
ev = [json.loads(l) for l in open(sys.argv[1]) if l.startswith("{")]
st, t0 = {}, None
for e in ev:
    ts = e.get("timestamp")
    if ts and t0 is None:
        t0 = datetime.datetime.fromisoformat(ts.replace("Z", "+00:00"))
    if e.get("type") == "system" and e.get("subtype") == "task_started":
        st[e["task_id"]] = e["description"]
    if e.get("type") == "system" and e.get("subtype") == "task_notification":
        u = e.get("usage", {})
        print(f"         subagent {st.get(e['task_id'])!r}: {u.get('duration_ms', 0)/1000:.1f}s")
    if e.get("type") == "assistant" and not e.get("parent_tool_use_id") and ts:
        d = (datetime.datetime.fromisoformat(ts.replace("Z", "+00:00")) - t0).total_seconds()
        for c in e["message"].get("content", []):
            if c.get("type") in ("tool_use", "text"):
                n = len(json.dumps(c.get("input", c.get("text", "")), ensure_ascii=False))
                print(f"  {d:6.1f}s clerk {c.get('type')} {c.get('name', '')} ({n} chars)")
