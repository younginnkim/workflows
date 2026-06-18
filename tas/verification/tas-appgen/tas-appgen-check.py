#!/usr/bin/env python3
"""tas-appgen appgen_output checker — schema/invariant + IR cross-reference checks.

Throwaway verification tool for the /tas-appgen skill. Judges only what can be
checked deterministically; whether a binding's typeName/find/property is the
*correct* one for the app source is judged by a human (needs the app `lib/`).

Checks (per reference/appgen-schema.md):
  schema      app block fields, widgets shape, binding shapes, find.method enum
  refs        binding.typeName in widgets; property_value.key / where keys in
              widgets[typeName]; any_present options likewise
  ir-xref     every binding (step_id, action_id|expected_index) exists in the IR
              and points at a target action / real expected; non-target intents
              (key_press/wait) carry no binding
  coverage    every IR target action & expected is bound OR listed in unsupported
  instrument  (optional) every widgets TypeName registered in app_test.dart and
              toStringMap wired into testWebosApplication

Convention: expected_index is the 0-based index into that step's `expected[]`.

Usage:
    tas-appgen-check.py <appgen_output.yaml> <ir.yaml> [app_test.dart] [--json]

Exit code:
    0  PASS      schema/refs/xref ok, full coverage, no unsupported
    2  ESCALATE  otherwise valid but `unsupported` non-empty or a coverage gap
    1  FAIL      any schema/invariant/reference/xref/instrument violation
"""
import sys
import json

try:
    import yaml
except ImportError:
    sys.stderr.write("ERROR: pyyaml required (pip install pyyaml)\n")
    sys.exit(3)

# ---- enums from reference/appgen-schema.md + ir-schema.md ----
FIND_METHODS = {"byText", "byKey", "byTypeName"}
# IR target intents (only these carry an action binding)
TARGET_INTENTS = {"find", "focus_move", "tap", "scroll", "read_property"}
# appgen expected-binding kinds: the 4 well-specified shapes + IR's loose kinds
EXPECTED_KINDS = {"app_launch", "property_value", "widget_visible", "any_present",
                  "navigation", "state_change"}
STRICT_KINDS = {"app_launch", "property_value", "widget_visible", "any_present"}
APP_FIELDS = ("sam_app_id", "flutter_app_id", "flag_file", "base_class_name")


def is_int(v):
    return isinstance(v, int) and not isinstance(v, bool)


def index_ir(ir):
    """Return (target_actions, nontarget_actions, expecteds) maps keyed by ref."""
    target, nontarget, expecteds = {}, {}, set()
    for st in ir.get("steps") or []:
        sid = st.get("id")
        for act in st.get("actions") or []:
            ref = (sid, act.get("id"))
            intent = act.get("intent")
            (target if intent in TARGET_INTENTS else nontarget)[ref] = intent
        for idx, _ex in enumerate(st.get("expected") or []):
            expecteds.add((sid, idx))
    return target, nontarget, expecteds


def check(ag, ir):
    errors, escalates = [], []

    if not isinstance(ag, dict):
        return ["top-level appgen_output is not a mapping"], []
    if not isinstance(ir, dict):
        return ["IR is not a mapping (cannot cross-reference)"], []

    target_actions, nontarget_actions, expecteds = index_ir(ir)

    # ---- app block ----
    app = ag.get("app")
    if not isinstance(app, dict):
        errors.append("app: missing/not a mapping")
    else:
        for f in APP_FIELDS:
            if not app.get(f):
                errors.append(f"app.{f}: missing/empty")

    # ---- widgets ----
    widgets = ag.get("widgets")
    if widgets is None:
        widgets = {}
    if not isinstance(widgets, dict):
        errors.append("widgets: not a mapping")
        widgets = {}
    else:
        for tn, keys in widgets.items():
            if not isinstance(keys, list):
                errors.append(f"widgets[{tn}]: value must be a list of property keys")

    def need_typename(tn, w):
        if tn not in widgets:
            errors.append(f"{w}: typeName {tn!r} not in widgets")
            return False
        return True

    def need_key(tn, key, w):
        if tn in widgets and key not in (widgets.get(tn) or []):
            errors.append(f"{w}: key {key!r} not exposed by widgets[{tn}] "
                          f"(app_test.dart toStringMap gap?)")

    # ---- bindings ----
    seen_actions, seen_expected = set(), set()
    for i, b in enumerate(ag.get("bindings") or []):
        w = f"bindings[{i}]"
        if not isinstance(b, dict):
            errors.append(f"{w}: not a mapping"); continue
        sid = b.get("step_id")
        is_action = "action_id" in b
        is_expected = "expected_index" in b

        if is_action == is_expected:
            errors.append(f"{w}: must have exactly one of action_id / expected_index")
            continue

        if is_action:
            ref = (sid, b.get("action_id"))
            seen_actions.add(ref)
            need_typename(b.get("typeName"), w)
            find = b.get("find")
            if not isinstance(find, dict):
                errors.append(f"{w}: find missing/not a mapping")
            else:
                if find.get("method") not in FIND_METHODS:
                    errors.append(f"{w}: find.method {find.get('method')!r} invalid "
                                  f"(allowed {sorted(FIND_METHODS)})")
                if find.get("value") in (None, ""):
                    errors.append(f"{w}: find.value missing/empty")
            # IR cross-reference
            if ref in nontarget_actions:
                errors.append(f"{w}: binds non-target action {ref} "
                              f"(intent {nontarget_actions[ref]!r} takes no binding)")
            elif ref not in target_actions:
                errors.append(f"{w}: action ref {ref} not found in IR")
        else:  # expected
            ref = (sid, b.get("expected_index"))
            seen_expected.add(ref)
            kind = b.get("kind")
            if kind not in EXPECTED_KINDS:
                errors.append(f"{w}: kind {kind!r} invalid (allowed {sorted(EXPECTED_KINDS)})")
            elif kind == "app_launch":
                if not b.get("appId"):
                    errors.append(f"{w}: app_launch requires appId")
            elif kind == "property_value":
                tn = b.get("typeName")
                need_typename(tn, w)
                if not b.get("key"):
                    errors.append(f"{w}: property_value requires key")
                else:
                    need_key(tn, b.get("key"), w)
                if not b.get("op"):
                    errors.append(f"{w}: property_value requires op")
                if "value" not in b:
                    errors.append(f"{w}: property_value requires value")
            elif kind == "widget_visible":
                tn = b.get("typeName")
                need_typename(tn, w)
                where = b.get("where")
                if isinstance(where, dict):
                    for k in where:
                        need_key(tn, k, w)
            elif kind == "any_present":
                opts = b.get("options") or []
                if not opts:
                    errors.append(f"{w}: any_present requires non-empty options[]")
                for oi, o in enumerate(opts):
                    ow = f"{w}.options[{oi}]"
                    if not isinstance(o, dict):
                        errors.append(f"{ow}: not a mapping"); continue
                    tn = o.get("typeName")
                    need_typename(tn, ow)
                    where = o.get("where")
                    if isinstance(where, dict):
                        for k in where:
                            need_key(tn, k, ow)
            if ref not in expecteds:
                errors.append(f"{w}: expected ref {ref} not found in IR")

    # ---- unsupported -> escalate ----
    for u in ag.get("unsupported") or []:
        reason = u.get("reason") if isinstance(u, dict) else u
        escalates.append(f"unsupported: {reason}")

    # ---- coverage gaps (bound OR in unsupported; we can't read free-form unsupported) ----
    for ref in sorted(target_actions, key=lambda r: (r[0] or 0, r[1] or 0)):
        if ref not in seen_actions:
            escalates.append(f"IR target action {ref} ({target_actions[ref]}) "
                             f"has no binding — coverage gap (check unsupported)")
    for ref in sorted(expecteds, key=lambda r: (r[0] or 0, r[1] or 0)):
        if ref not in seen_expected:
            escalates.append(f"IR expected {ref} has no binding — coverage gap "
                             f"(check unsupported)")

    return errors, escalates, widgets


def check_instrument(widgets, dart_text):
    errs = []
    if "toStringMap" not in dart_text:
        errs.append("app_test.dart: no toStringMap argument wired into testWebosApplication")
    for tn in widgets:
        if tn not in dart_text:
            errs.append(f"app_test.dart: TypeName {tn!r} not registered "
                        f"(no mapper / printProperties entry)")
    return errs


def main():
    argv = [a for a in sys.argv[1:] if a != "--json"]
    as_json = "--json" in sys.argv
    if len(argv) not in (2, 3):
        sys.stderr.write(__doc__)
        sys.exit(3)
    ag_path, ir_path = argv[0], argv[1]
    dart_path = argv[2] if len(argv) == 3 else None

    with open(ag_path) as f:
        ag = yaml.safe_load(f)
    with open(ir_path) as f:
        ir = yaml.safe_load(f)

    result = check(ag, ir)
    if len(result) == 2:                 # early bail (top-level not a mapping)
        errors, escalates = result
    else:
        errors, escalates, widgets = result
        if dart_path:
            with open(dart_path) as f:
                errors.extend(check_instrument(widgets, f.read()))

    verdict = "FAIL" if errors else ("ESCALATE" if escalates else "PASS")

    if as_json:
        print(json.dumps({"verdict": verdict, "errors": errors, "escalates": escalates},
                         ensure_ascii=False, indent=2))
    else:
        print(f"=== {ag_path}  ->  {verdict} ===")
        if errors:
            print(f"\nERRORS ({len(errors)}):")
            for e in errors:
                print(f"  ✗ {e}")
        if escalates:
            print(f"\nESCALATE/NOTES ({len(escalates)}):")
            for e in escalates:
                print(f"  ! {e}")
        if not errors and not escalates:
            print("  ✓ schema/refs/IR-xref ok, full coverage, no unsupported")

    sys.exit(0 if verdict == "PASS" else (2 if verdict == "ESCALATE" else 1))


if __name__ == "__main__":
    main()
