#!/usr/bin/env python3
"""tas-parse IR checker — schema/invariant + source_span hallucination checks.

Throwaway verification tool for the /tas-parse skill. Judges only what can be
checked deterministically; semantic completeness is judged by a human.

IR shape (per reference/ir-schema.md): each TC sub-check is a self-contained
`step = {id, name, preconditions, actions, expected}`. Lowered intents live in
`actions`. Global (TC-wide) preconditions live at top level.

Usage:
    tas-parse-check.py <ir.yaml> <tc_source.txt> [--json]

Exit code:
    0  PASS      — schema/invariants ok, every source_span found verbatim, no unresolved
    2  ESCALATE  — otherwise valid but `unresolved` is non-empty
    1  FAIL      — any schema/invariant violation or hallucinated source_span
"""
import sys
import re
import json
import html

try:
    import yaml
except ImportError:
    sys.stderr.write("ERROR: pyyaml required (pip install pyyaml)\n")
    sys.exit(3)

# ---- enums from reference/ir-schema.md ----
INTENTS = {"find", "focus_move", "key_press", "tap", "scroll", "wait", "read_property"}
KEYS = {"OK", "UP", "DOWN", "LEFT", "RIGHT", "BACK", "HOME"}
TARGET_INTENTS = {"find", "focus_move", "tap", "scroll", "read_property"}
PRECOND_KINDS = {"app_lifecycle", "focused", "property_value", "environment"}
EXPECTED_KINDS = {"app_launch", "widget_visible", "property_value", "state_change", "navigation"}
LIFECYCLE = {"resumed", "inactive", "paused", "detached", "hidden"}
MATCH_KEYS = {"text", "key", "index"}
SNAKE = re.compile(r"^[a-z0-9]+(_[a-z0-9]+)*$")


def normalize(s):
    """Strip HTML, decode entities, collapse whitespace — for verbatim substring test."""
    s = html.unescape(str(s))
    s = re.sub(r"<[^>]+>", " ", s)        # drop html tags (ZAPI fields often html)
    s = re.sub(r"\s+", " ", s)            # collapse whitespace
    return s.strip()


def is_int(v):
    return isinstance(v, int) and not isinstance(v, bool)


def check(ir, src_raw):
    errors, escalates = [], []
    src = normalize(src_raw)
    src_lower = src.lower()

    def span_present(span, where):
        if span is None or str(span).strip() == "":
            errors.append(f"{where}: source_span missing/empty")
            return
        norm = normalize(span)
        if norm and norm in src:
            return
        if norm and norm.lower() in src_lower:
            escalates.append(f"{where}: source_span found only case-insensitively (near match): {norm!r}")
            return
        errors.append(f"{where}: source_span NOT found verbatim in TC source (hallucination?): {norm!r}")

    def check_precond(pc, w):
        if not isinstance(pc, dict):
            errors.append(f"{w}: not a mapping"); return
        k = pc.get("kind")
        if k not in PRECOND_KINDS:
            errors.append(f"{w}: invalid kind {k!r} (allowed {sorted(PRECOND_KINDS)})")
        if k == "app_lifecycle" and pc.get("value") not in LIFECYCLE:
            errors.append(f"{w}: app_lifecycle value {pc.get('value')!r} not in {sorted(LIFECYCLE)}")
        span_present(pc.get("source_span"), w)

    def check_expected(ex, w):
        if not isinstance(ex, dict):
            errors.append(f"{w}: not a mapping"); return
        if ex.get("kind") not in EXPECTED_KINDS:
            errors.append(f"{w}: invalid kind {ex.get('kind')!r} (allowed {sorted(EXPECTED_KINDS)})")
        span_present(ex.get("source_span"), w)

    if not isinstance(ir, dict):
        return ["top-level IR is not a mapping"], []

    # required top fields
    for f in ("test_case_id", "title", "steps"):
        if f not in ir or ir[f] in (None, "", []):
            errors.append(f"required top field missing/empty: {f}")

    # global (top-level) preconditions — optional
    for i, pc in enumerate(ir.get("preconditions") or []):
        check_precond(pc, f"preconditions[{i}]")

    # steps — each is a self-contained scenario
    steps = ir.get("steps") or []
    prev_id = 0
    for i, st in enumerate(steps):
        w = f"steps[{i}]"
        if not isinstance(st, dict):
            errors.append(f"{w}: not a mapping"); continue

        # step.id: int, ascending-by-1 from 1
        sid = st.get("id")
        if not is_int(sid):
            errors.append(f"{w}: id must be an integer (got {sid!r})")
        else:
            if sid != prev_id + 1:
                errors.append(f"{w}: id {sid} not ascending-by-1 (expected {prev_id + 1})")
            prev_id = sid

        # step.name: non-empty snake_case slug
        name = st.get("name")
        if not isinstance(name, str) or not name.strip():
            errors.append(f"{w}: name missing/empty (snake_case slug required)")
        elif not SNAKE.match(name):
            errors.append(f"{w}: name {name!r} is not snake_case")

        # step.preconditions — optional
        for j, pc in enumerate(st.get("preconditions") or []):
            check_precond(pc, f"{w}.preconditions[{j}]")

        # step.actions — >=1, ids ascending from 1 within the step
        actions = st.get("actions") or []
        if not actions:
            errors.append(f"{w}: actions must have at least 1 entry")
        a_prev = 0
        for j, act in enumerate(actions):
            aw = f"{w}.actions[{j}]"
            if not isinstance(act, dict):
                errors.append(f"{aw}: not a mapping"); continue
            aid = act.get("id")
            if not is_int(aid):
                errors.append(f"{aw}: id must be an integer (got {aid!r})")
            else:
                if aid != a_prev + 1:
                    errors.append(f"{aw}: id {aid} not ascending-by-1 within step (expected {a_prev + 1})")
                a_prev = aid
            intent = act.get("intent")
            if intent not in INTENTS:
                errors.append(f"{aw}: invalid intent {intent!r} (allowed {sorted(INTENTS)})")
            if intent == "key_press" and act.get("key") not in KEYS:
                errors.append(f"{aw}: key_press requires valid key, got {act.get('key')!r}")
            if intent in TARGET_INTENTS:
                tgt = act.get("target")
                if not isinstance(tgt, dict):
                    errors.append(f"{aw}: intent {intent!r} requires a target mapping")
                else:
                    match = tgt.get("match")
                    if isinstance(match, dict):
                        extra = set(match.keys()) - MATCH_KEYS
                        if extra:
                            errors.append(f"{aw}: target.match has non-allowed keys {sorted(extra)} "
                                          f"(only {sorted(MATCH_KEYS)} — TypeName/property leak?)")
            span_present(act.get("source_span"), aw)

        # step.expected — >=1
        expected = st.get("expected") or []
        if not expected:
            errors.append(f"{w}: expected must have at least 1 entry")
        for j, ex in enumerate(expected):
            check_expected(ex, f"{w}.expected[{j}]")

    # unresolved -> escalate
    for i, u in enumerate(ir.get("unresolved") or []):
        reason = u.get("reason") if isinstance(u, dict) else u
        escalates.append(f"unresolved[{i}]: {reason}")

    return errors, escalates


def main():
    args = [a for a in sys.argv[1:] if a != "--json"]
    as_json = "--json" in sys.argv
    if len(args) != 2:
        sys.stderr.write(__doc__)
        sys.exit(3)
    ir_path, src_path = args
    with open(ir_path) as f:
        ir = yaml.safe_load(f)
    with open(src_path) as f:
        src_raw = f.read()

    errors, escalates = check(ir, src_raw)
    verdict = "FAIL" if errors else ("ESCALATE" if escalates else "PASS")

    if as_json:
        print(json.dumps({"verdict": verdict, "errors": errors, "escalates": escalates},
                         ensure_ascii=False, indent=2))
    else:
        print(f"=== {ir_path}  ->  {verdict} ===")
        if errors:
            print(f"\nERRORS ({len(errors)}):")
            for e in errors:
                print(f"  ✗ {e}")
        if escalates:
            print(f"\nESCALATE/NOTES ({len(escalates)}):")
            for e in escalates:
                print(f"  ! {e}")
        if not errors and not escalates:
            print("  ✓ schema/invariants ok, all source_span verbatim, no unresolved")

    sys.exit(0 if verdict == "PASS" else (2 if verdict == "ESCALATE" else 1))


if __name__ == "__main__":
    main()
