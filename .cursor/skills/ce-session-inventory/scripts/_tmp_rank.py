import json

sessions = []
metas = []
path = r"C:\Users\sokky\AppData\Local\Temp\nuclide_kw_out.jsonl"
with open(path, encoding="utf-8") as f:
    for line in f:
        o = json.loads(line)
        if o.get("_meta"):
            metas.append(o)
        else:
            sessions.append(o)

# Deduplicate by session id / file
seen = set()
uniq = []
for s in sessions:
    key = s.get("session") or s.get("file")
    if key in seen:
        continue
    seen.add(key)
    uniq.append(s)

print("unique_sessions", len(uniq))
print("meta_batches", len(metas))
print("files_matched_sum", sum(m.get("files_matched", 0) for m in metas))
print("parse_errors_sum", sum(m.get("parse_errors", 0) for m in metas))
print("processed_sum", sum(m.get("files_processed", 0) for m in metas))

# Prefer Beaumont / air* hits over generic stiletto
def score(s):
    km = s.get("keyword_matches") or {}
    topic = (
        km.get("Beaumont", 0) * 100
        + km.get("airdash", 0) * 50
        + km.get("air_dash", 0) * 50
        + km.get("airstall", 0) * 50
        + km.get("air_stall", 0) * 50
        + km.get("airdodge", 0) * 40
        + km.get("air_dodge", 0) * 40
        + km.get("movement_kit", 0) * 30
        + km.get("stiletto", 0)
    )
    return (topic, s.get("match_count", 0), s.get("size", 0))

uniq.sort(key=score, reverse=True)
print("---TOP---")
for s in uniq[:25]:
    print(json.dumps({
        "platform": s.get("platform"),
        "session": s.get("session"),
        "size": s.get("size"),
        "ts": s.get("ts"),
        "last_ts": s.get("last_ts"),
        "branch": s.get("branch"),
        "match_count": s.get("match_count"),
        "keyword_matches": s.get("keyword_matches"),
        "score": score(s)[0],
        "file": s.get("file"),
    }))
