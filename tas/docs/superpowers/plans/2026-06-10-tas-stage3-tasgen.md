# TAS! Stage ③ `/tas-tasgen` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a deterministic renderer that turns a stage① IR + stage② appgen_output (resolved bindings) into thin per-TC Python TAS scripts, on top of a tool-shipped generic `TasFlutterBase`.

**Architecture:** Pure-Python, no LLM, no device. `schema.py` validates inputs + contract join (Gate A, dict level); `gate.py` validates rendered output (AST parse + every `self.<primitive>()` ∈ base API); `render.py` dispatches IR steps/expected → primitive calls; `tasbase.py` is the shipped framework base; `tasgen.py` is the CLI orchestrator. Bespoke/unsupported → escalate (stub + reason), never guess.

**Tech Stack:** Python 3 (stdlib `ast`, `re`) + PyYAML. pytest. Mirrors stage① module conventions (`stage1_parse/`).

---

## File Structure

```
stage3_tasgen/
  __init__.py
  propparse.py   # pure Map.toString() parser  (parse_property_string, parse_properties)
  schema.py      # input-structural validation + contract join  (validate_appgen, check_contract)
  gate.py        # output-side Gate A  (base_methods, self_calls, check_output)
  render.py      # (IR, appgen) -> Python source  (render_app_base, render_tc, render_scripts, Escalate)
  tasbase.py     # SHIPPED generic TasFlutterBase (framework artifact; AST-tested, not imported)
  report.py      # render_report(result)
tasgen.py        # CLI = /tas-tasgen
tests/
  test_propparse.py
  test_schema3.py
  test_gate3.py
  test_render3.py
  test_golden3.py
  golden3/
    globalline_search.ir.yaml + globalline_search.appgen.yaml + globalline_search.expected.py + HomeTasBase.expected.py
    qcard.ir.yaml + qcard.appgen.yaml + qcard.expected.py
  fixtures3/
    unknown_typename.appgen.yaml
    missing_binding.appgen.yaml
    key_not_in_contract.appgen.yaml
```

Each module is pure and focused (≤ ~90 lines), matching stage①. `tasbase.py` is the one framework-coupled file: it imports `webos.utils.*` so it cannot be imported inside the tas-tool venv — it is validated by **AST introspection only**.

---

## Task 1: `propparse.py` — Map.toString() parser

**Files:**
- Create: `stage3_tasgen/__init__.py` (empty)
- Create: `stage3_tasgen/propparse.py`
- Test: `tests/test_propparse.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_propparse.py
from stage3_tasgen.propparse import parse_property_string, parse_properties


def test_parses_simple_map():
    assert parse_property_string("{item_count: 5, group_label: HOME_SH_QCARD}") == {
        "item_count": "5",
        "group_label": "HOME_SH_QCARD",
    }


def test_strips_braces_and_handles_empty():
    assert parse_property_string("{}") == {}
    assert parse_property_string("") == {}


def test_value_containing_colon_is_kept_whole():
    # split on the FIRST ': ' only
    assert parse_property_string("{url: http://x: y}") == {"url": "http://x: y"}


def test_parse_properties_maps_each():
    assert parse_properties(["{a: 1}", "{b: 2}"]) == [{"a": "1"}, {"b": "2"}]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.venv/bin/python -m pytest tests/test_propparse.py -q`
Expected: FAIL — `ModuleNotFoundError: No module named 'stage3_tasgen'`

- [ ] **Step 3: Write minimal implementation**

```python
# stage3_tasgen/propparse.py
"""Pure parser for Dart Map.toString() property strings.

webOS Flutter getProperty() returns each widget's properties as a Dart
`Map.toString()` string: "{key: val, key2: val2}". This mirrors util/home.py's
inline parsing, factored out so it is unit-testable without the device/framework.
Pure module: stdlib only.
"""
from __future__ import annotations


def parse_property_string(s: str) -> dict:
    s = s.strip()
    if s.startswith("{") and s.endswith("}"):
        s = s[1:-1]
    out: dict = {}
    if not s.strip():
        return out
    for part in s.split(", "):
        if ": " in part:
            k, v = part.split(": ", 1)
            out[k] = v
    return out


def parse_properties(props: list[str]) -> list[dict]:
    return [parse_property_string(p) for p in props]
```

Also create empty `stage3_tasgen/__init__.py`:

```python
```

- [ ] **Step 4: Run test to verify it passes**

Run: `.venv/bin/python -m pytest tests/test_propparse.py -q`
Expected: PASS (4 passed)

- [ ] **Step 5: Commit**

```bash
git add stage3_tasgen/__init__.py stage3_tasgen/propparse.py tests/test_propparse.py
git commit -m "feat(stage3): Map.toString property parser (pure)"
```

---

## Task 2: `schema.py` — input validation + contract join (Gate A, dict level)

**Files:**
- Create: `stage3_tasgen/schema.py`
- Test: `tests/test_schema3.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_schema3.py
from stage3_tasgen.schema import validate_appgen, check_contract

GOOD_APPGEN = {
    "app": {
        "flutter_app_id": "com.webos.tas.home",
        "sam_app_id": "com.webos.app.home",
        "flag_file": "/var/luna/preferences/tas_home_enabled",
        "base_class_name": "HomeTasBase",
    },
    "widgets": {"Button": ["text", "semanticsLabel"], "WAnimatedCarousel": ["item_count", "group_label"]},
    "bindings": [
        {"step_id": 1, "typeName": "Button", "find": {"method": "byText", "value": "Search"}},
        {"expected_index": 0, "kind": "app_launch", "appId": "com.webos.app.voice"},
    ],
    "unsupported": [],
}

GOOD_IR = {
    "test_case_id": "globalline_search",
    "title": "t",
    "steps": [
        {"id": 1, "intent": "focus_move", "target": {"role": "button"}, "source_span": "s"},
        {"id": 2, "intent": "key_press", "key": "OK", "source_span": "s"},
    ],
    "expected": [{"kind": "app_launch", "source_span": "s"}],
}


def test_good_appgen_passes():
    assert validate_appgen(GOOD_APPGEN) == []


def test_app_missing_field_flagged():
    bad = {**GOOD_APPGEN, "app": {"flutter_app_id": "x"}}
    errs = validate_appgen(bad)
    assert any("base_class_name" in e for e in errs)


def test_binding_must_have_exactly_one_anchor():
    bad = {**GOOD_APPGEN, "bindings": [{"step_id": 1, "expected_index": 0}]}
    assert any("exactly one" in e for e in validate_appgen(bad))


def test_bad_find_method_flagged():
    bad = {**GOOD_APPGEN, "bindings": [{"step_id": 1, "typeName": "Button", "find": {"method": "byNose", "value": "x"}}]}
    assert any("find.method" in e for e in validate_appgen(bad))


def test_contract_good_passes():
    assert check_contract(GOOD_IR, GOOD_APPGEN) == []


def test_contract_missing_binding_for_target_step():
    appgen = {**GOOD_APPGEN, "bindings": [{"expected_index": 0, "kind": "app_launch", "appId": "x"}]}
    assert any("no binding" in e for e in check_contract(GOOD_IR, appgen))


def test_contract_unknown_typename():
    appgen = {**GOOD_APPGEN, "bindings": [
        {"step_id": 1, "typeName": "Ghost", "find": {"method": "byText", "value": "Search"}},
        {"expected_index": 0, "kind": "app_launch", "appId": "x"},
    ]}
    assert any("not in widgets" in e for e in check_contract(GOOD_IR, appgen))


def test_contract_property_key_not_exposed():
    ir = {"test_case_id": "qcard", "title": "t",
          "steps": [], "expected": [{"kind": "property_value", "source_span": "s"}]}
    appgen = {**GOOD_APPGEN, "bindings": [
        {"expected_index": 0, "kind": "property_value", "typeName": "WAnimatedCarousel",
         "key": "ghost_key", "op": ">=", "value": 1}]}
    assert any("not exposed" in e for e in check_contract(ir, appgen))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.venv/bin/python -m pytest tests/test_schema3.py -q`
Expected: FAIL — `ModuleNotFoundError: No module named 'stage3_tasgen.schema'`

- [ ] **Step 3: Write minimal implementation**

```python
# stage3_tasgen/schema.py
"""Stage ③ input validation + contract join (Gate A, dict level).

Pure module: no LLM, no IO, no device. Operates on parsed-YAML dicts
(IR from stage①, appgen_output mock from stage②). See spec §3, §6-1.
"""
from __future__ import annotations

APP_REQUIRED = ("flutter_app_id", "sam_app_id", "flag_file", "base_class_name")
FIND_METHODS = {"byTypeName", "byText", "byKey"}
OPS = {"==", "!=", ">", ">=", "<", "<="}
# IR intents that require a resolved target binding (spec §3-2, §5)
TARGET_INTENTS = {"find", "focus_move", "tap", "scroll", "read_property"}


def validate_appgen(appgen) -> list[str]:
    """Structural validation of the stage② output. Empty list = pass."""
    errors: list[str] = []
    if not isinstance(appgen, dict):
        return ["appgen is not a mapping"]

    app = appgen.get("app")
    if not isinstance(app, dict):
        errors.append("missing/invalid 'app' block")
    else:
        for f in APP_REQUIRED:
            if not app.get(f):
                errors.append(f"app missing required field: {f}")

    widgets = appgen.get("widgets")
    if not isinstance(widgets, dict):
        errors.append("missing/invalid 'widgets' contract")
    else:
        for tn, keys in widgets.items():
            if not isinstance(keys, list):
                errors.append(f"widgets[{tn}] must be a list of property keys")

    bindings = appgen.get("bindings", [])
    if not isinstance(bindings, list):
        errors.append("'bindings' must be a list")
    else:
        for i, b in enumerate(bindings):
            if not isinstance(b, dict):
                errors.append(f"bindings[{i}] not a mapping")
                continue
            if ("step_id" in b) == ("expected_index" in b):
                errors.append(f"bindings[{i}] must have exactly one of step_id/expected_index")
            find = b.get("find")
            if find is not None and find.get("method") not in FIND_METHODS:
                errors.append(f"bindings[{i}].find.method invalid: {find.get('method')}")
            if b.get("op") is not None and b.get("op") not in OPS:
                errors.append(f"bindings[{i}].op invalid: {b.get('op')}")
    return errors


def _binding_for_step(appgen, sid):
    for b in appgen.get("bindings", []):
        if b.get("step_id") == sid:
            return b
    return None


def check_contract(ir, appgen) -> list[str]:
    """Join-integrity between IR and appgen bindings. Empty list = pass."""
    errors: list[str] = []
    widgets = appgen.get("widgets") or {}
    step_ids = {s.get("id") for s in ir.get("steps") or []}
    n_expected = len(ir.get("expected") or [])

    for s in ir.get("steps") or []:
        if s.get("intent") in TARGET_INTENTS:
            b = _binding_for_step(appgen, s.get("id"))
            if b is None:
                errors.append(f"step {s.get('id')} ({s.get('intent')}) has no binding")
                continue
            tn = b.get("typeName")
            if tn is None:
                errors.append(f"binding for step {s.get('id')} missing typeName")
            elif tn not in widgets:
                errors.append(f"binding step {s.get('id')}: typeName '{tn}' not in widgets contract")

    for i, b in enumerate(appgen.get("bindings", [])):
        if "step_id" in b and b["step_id"] not in step_ids:
            errors.append(f"bindings[{i}].step_id {b['step_id']} not in IR steps")
        if "expected_index" in b:
            ei = b["expected_index"]
            if not isinstance(ei, int) or isinstance(ei, bool) or ei < 0 or ei >= n_expected:
                errors.append(f"bindings[{i}].expected_index {ei} out of range (0..{n_expected - 1})")
        if b.get("kind") == "property_value":
            tn, key = b.get("typeName"), b.get("key")
            if tn in widgets and key not in (widgets.get(tn) or []):
                errors.append(f"bindings[{i}]: key '{key}' not exposed by widgets[{tn}]")
    return errors
```

- [ ] **Step 4: Run test to verify it passes**

Run: `.venv/bin/python -m pytest tests/test_schema3.py -q`
Expected: PASS (8 passed)

- [ ] **Step 5: Commit**

```bash
git add stage3_tasgen/schema.py tests/test_schema3.py
git commit -m "feat(stage3): appgen schema + contract-join validation (Gate A dict level)"
```

---

## Task 3: `gate.py` — output-side Gate A (AST parse + primitive-in-base)

**Files:**
- Create: `stage3_tasgen/gate.py`
- Test: `tests/test_gate3.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_gate3.py
from stage3_tasgen.gate import base_methods, self_calls, check_output

BASE_SRC = '''
class TasFlutterBase:
    def focus(self, typeName=None): pass
    def send_key(self, key): pass
    def assert_app_launch(self, appId): pass
'''


def test_base_methods_extracts_defs():
    assert base_methods(BASE_SRC) == {"focus", "send_key", "assert_app_launch"}


def test_self_calls_finds_invocations():
    src = "def run(self):\n    self.focus('Button')\n    self.send_key('OK')\n"
    assert self_calls(src) == {"focus", "send_key"}


def test_check_output_passes_when_all_known():
    src = "def run(self):\n    self.focus('B')\n    self.assert_app_launch('x')\n"
    assert check_output(src, base_methods(BASE_SRC)) == []


def test_check_output_flags_unknown_primitive():
    src = "def run(self):\n    self.teleport('B')\n"
    errs = check_output(src, base_methods(BASE_SRC))
    assert any("teleport" in e for e in errs)


def test_check_output_flags_syntax_error():
    errs = check_output("def run(self)\n  pass", base_methods(BASE_SRC))
    assert any("syntax error" in e for e in errs)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.venv/bin/python -m pytest tests/test_gate3.py -q`
Expected: FAIL — `ModuleNotFoundError: No module named 'stage3_tasgen.gate'`

- [ ] **Step 3: Write minimal implementation**

```python
# stage3_tasgen/gate.py
"""Stage ③ output-side Gate A: validate generated Python deterministically.

`base_methods` introspects tasbase.py by AST (NOT import — it depends on the
webos framework and cannot load in this venv). `check_output` asserts the
generated code parses and every self.<primitive>() it calls is defined on the
shipped base. See spec §6-1.
"""
from __future__ import annotations

import ast


def base_methods(tasbase_source: str) -> set[str]:
    tree = ast.parse(tasbase_source)
    out: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.ClassDef):
            for item in node.body:
                if isinstance(item, (ast.FunctionDef, ast.AsyncFunctionDef)):
                    out.add(item.name)
    return out


def self_calls(source: str) -> set[str]:
    """Method names invoked as self.<name>(...) anywhere in source."""
    tree = ast.parse(source)
    out: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
            v = node.func.value
            if isinstance(v, ast.Name) and v.id == "self":
                out.add(node.func.attr)
    return out


def check_output(source: str, allowed: set[str]) -> list[str]:
    try:
        ast.parse(source)
    except SyntaxError as e:
        return [f"generated code has syntax error: {e}"]
    return [f"calls undefined primitive: self.{name}()"
            for name in sorted(self_calls(source)) if name not in allowed]
```

- [ ] **Step 4: Run test to verify it passes**

Run: `.venv/bin/python -m pytest tests/test_gate3.py -q`
Expected: PASS (5 passed)

- [ ] **Step 5: Commit**

```bash
git add stage3_tasgen/gate.py tests/test_gate3.py
git commit -m "feat(stage3): output Gate A — AST parse + primitive-in-base check"
```

---

## Task 4: `tasbase.py` — shipped generic `TasFlutterBase`

**Files:**
- Create: `stage3_tasgen/tasbase.py`
- Test: extend `tests/test_gate3.py` (AST-based; do NOT import the module)

- [ ] **Step 1: Write the failing test**

Append to `tests/test_gate3.py`:

```python
import pathlib
from stage3_tasgen.gate import base_methods as _bm

TASBASE = pathlib.Path(__file__).parent.parent / "stage3_tasgen" / "tasbase.py"
REQUIRED_PRIMITIVES = {
    "find", "focus", "send_key", "tap", "wait", "get_property",
    "assert_widget_present", "assert_any_present", "assert_property", "assert_app_launch",
    "run_flutter_test",
}


def test_tasbase_defines_all_primitives():
    methods = _bm(TASBASE.read_text())
    missing = REQUIRED_PRIMITIVES - methods
    assert not missing, f"tasbase.py missing primitives: {missing}"


def test_tasbase_parses():
    import ast
    ast.parse(TASBASE.read_text())  # must be syntactically valid Python
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.venv/bin/python -m pytest tests/test_gate3.py -q`
Expected: FAIL — `FileNotFoundError` / tasbase.py does not exist

- [ ] **Step 3: Write minimal implementation**

```python
# stage3_tasgen/tasbase.py
###################################################################################
# @@@LICENSE
#
#   Copyright (c) 2024 by LG Electronics Inc.
#
#   All rights reserved. No part of this work may be reproduced, stored in a
#   retrieval system, or transmitted by any means without prior written
#   permission of LG Electronics Inc.
#
# LICENSE@@@
####################################################################################
"""Generic, app-agnostic TAS base for webOS Flutter apps (SHIPPED runtime artifact).

Runs inside the `automation-tests` framework (imports webos.utils.*); it is NOT
importable in the tas-tool venv and is validated by AST only. Subclasses fill the
meta class-attrs (FLUTTER_APP_ID / SAM_APP_ID / FLAG_FILE / JIRA_ID). Encapsulates
find / key / getProperty-parse / assert primitives so generated per-TC scripts stay
thin. The Map.toString parser mirrors stage3_tasgen/propparse.py (kept identical).
"""
from webos.utils.Flutter import Flutter
from webos.utils.Sam import Sam
from webos.utils.LunaSend import LunaSend
from webos.utils.pytell.input_generator_service import InputGeneratorService
from webos.utils.zephyr.ZephyrTest import ZephyrTest
from webos.utils.utils import wait_for_time

_KEYID = {
    "OK": 4294967309, "DOWN": 4294968065, "LEFT": 4294968066,
    "RIGHT": 4294968067, "UP": 4294968068,
}
_KEYNAME = {"OK": "enter", "UP": "up", "DOWN": "down", "LEFT": "left",
            "RIGHT": "right", "BACK": "back", "HOME": "home"}


class TasFlutterBase(ZephyrTest):
    FLUTTER_APP_ID = None
    SAM_APP_ID = None
    FLAG_FILE = None
    JIRA_ID = None
    test_name = "TasFlutterBase"

    def __init__(self):
        ZephyrTest.__init__(self, self.test_name, author="younginn.kim")
        if self.JIRA_ID:
            self.set_zephyr_key(self.JIRA_ID)

    def _run(self, **kwargs):
        self._cmd = self.get_command_line()
        self._sam = Sam(self._cmd)
        self._luna = LunaSend(cmd=self._cmd)
        self._input = InputGeneratorService(self._cmd)
        self._flutter = Flutter(cmd=self._cmd)
        self._flutter.checkTestEnviroment(filename=self.FLAG_FILE)
        self.log_info("[START] {0}".format(self.test_name))
        try:
            self.run_flutter_test()
        finally:
            self.log_info("[END] {0}".format(self.test_name))

    # ── low-level ───────────────────────────────────────────────
    def find(self, typeName=None, by_text=None, by_key=None, index=None):
        if by_text is not None:
            res = self._flutter.findByText(by_text)
        elif by_key is not None:
            res = self._flutter.findByKey(by_key)
        else:
            res = self._flutter.findByTypeName(typeName)
        if index is not None:
            self._flutter.findAt(index)
        return res

    def focus(self, typeName=None, by_text=None, by_key=None, index=None):
        self.find(typeName, by_text, by_key, index)
        self._flutter.setFocus()

    def send_key(self, key):
        self._input.press_key(_KEYNAME[key])

    def tap(self):
        self._flutter.tap()

    def wait(self, seconds=1):
        wait_for_time(seconds)

    def get_property(self):
        response = self._flutter.getProperty()
        if "properties" not in response:
            return []
        results = []
        for prop in response["properties"]:
            prop = prop[1:-1]
            item = {}
            for data in prop.split(", "):
                kv = data.split(": ", 1)
                if len(kv) > 1:
                    item[kv[0]] = kv[1]
            results.append(item)
        return results

    # ── assertions (primitives) ─────────────────────────────────
    def assert_widget_present(self, typeName, where=None):
        self.find(typeName)
        results = self.get_property()
        if where:
            ok = any(all(r.get(k) == v for k, v in where.items()) for r in results)
        else:
            ok = len(results) > 0
        self.assertTrue(ok, "ERROR: {0} not present (where={1})".format(typeName, where))

    def assert_any_present(self, options):
        for opt in options:
            self.find(opt["typeName"])
            results = self.get_property()
            where = opt.get("where")
            if where:
                if any(all(r.get(k) == v for k, v in where.items()) for r in results):
                    return
            elif len(results) > 0:
                return
        self.assertTrue(False, "ERROR: none of {0} present".format(options))

    def assert_property(self, typeName, key, op, value, group=None):
        self.find(typeName)
        results = self.get_property()
        if group is not None:
            results = [r for r in results if r.get("group_label") == group]
        actual = None
        for r in results:
            if key in r:
                actual = r[key]
                break
        ok = self._compare(actual, op, value)
        self.assertTrue(ok, "ERROR: {0}.{1} {2} {3} (actual={4})".format(typeName, key, op, value, actual))

    def assert_app_launch(self, appId):
        fg = self._sam.getForegroundAppInfo().get("appId")
        self.assertEqual(appId, fg, "ERROR: {0} not foreground (actual={1})".format(appId, fg))

    @staticmethod
    def _compare(actual, op, value):
        if actual is None:
            return False
        try:
            a, b = int(actual), int(value)
        except (TypeError, ValueError):
            a, b = str(actual), str(value)
        return {"==": a == b, "!=": a != b, ">": a > b, ">=": a >= b,
                "<": a < b, "<=": a <= b}[op]

    def run_flutter_test(self):
        raise NotImplementedError
```

- [ ] **Step 4: Run test to verify it passes**

Run: `.venv/bin/python -m pytest tests/test_gate3.py -q`
Expected: PASS (7 passed)

- [ ] **Step 5: Commit**

```bash
git add stage3_tasgen/tasbase.py tests/test_gate3.py
git commit -m "feat(stage3): shipped generic TasFlutterBase + AST presence tests"
```

---

## Task 5: `render.py` — app base + per-TC renderer

**Files:**
- Create: `stage3_tasgen/render.py`
- Test: `tests/test_render3.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_render3.py
import ast
import pytest
from stage3_tasgen.render import render_app_base, render_tc, Escalate

APP = {
    "flutter_app_id": "com.webos.tas.home",
    "sam_app_id": "com.webos.app.home",
    "flag_file": "/var/luna/preferences/tas_home_enabled",
    "base_class_name": "HomeTasBase",
    "jira_id": "TVDEVTC-23796",
}
APPGEN = {
    "app": APP,
    "widgets": {"Button": ["text"], "WAnimatedCarousel": ["item_count", "group_label"]},
    "bindings": [
        {"step_id": 1, "typeName": "Button", "find": {"method": "byText", "value": "Search"}},
        {"expected_index": 0, "kind": "app_launch", "appId": "com.webos.app.voice"},
    ],
}
IR = {
    "test_case_id": "globalline_search",
    "title": "t",
    "steps": [
        {"id": 1, "intent": "focus_move", "target": {"role": "button"}, "source_span": "s"},
        {"id": 2, "intent": "key_press", "key": "OK", "source_span": "s"},
    ],
    "expected": [{"kind": "app_launch", "source_span": "s"}],
}


def test_app_base_has_meta_and_parses():
    src = render_app_base(APPGEN, tasbase_import="Functional.flutter._tas.tasbase")
    ast.parse(src)
    assert "class HomeTasBase(TasFlutterBase):" in src
    assert "FLUTTER_APP_ID = 'com.webos.tas.home'" in src
    assert "from Functional.flutter._tas.tasbase import TasFlutterBase" in src


def test_tc_renders_focus_key_launch_in_order():
    src = render_tc(IR, APPGEN)
    ast.parse(src)
    assert "class GloballineSearch(HomeTasBase):" in src
    body = src[src.index("def run_flutter_test"):]
    i_focus = body.index("self.focus('Button', by_text='Search')")
    i_key = body.index("self.send_key('OK')")
    i_launch = body.index("self.assert_app_launch('com.webos.app.voice')")
    assert i_focus < i_key < i_launch


def test_tc_renders_property_assert():
    ir = {"test_case_id": "qcard", "title": "t", "steps": [],
          "expected": [{"kind": "property_value", "source_span": "s"}]}
    appgen = {"app": APP, "widgets": {"WAnimatedCarousel": ["item_count", "group_label"]},
              "bindings": [{"expected_index": 0, "kind": "property_value",
                            "typeName": "WAnimatedCarousel", "key": "item_count",
                            "op": ">=", "value": 1, "group": "HOME_SH_QCARD"}]}
    src = render_tc(ir, appgen)
    assert "self.assert_property('WAnimatedCarousel', 'item_count', '>=', 1, group='HOME_SH_QCARD')" in src


def test_unsupported_kind_escalates():
    ir = {"test_case_id": "x", "title": "t", "steps": [],
          "expected": [{"kind": "navigation", "source_span": "s"}]}
    appgen = {"app": APP, "widgets": {}, "bindings": [{"expected_index": 0, "kind": "navigation"}]}
    with pytest.raises(Escalate):
        render_tc(ir, appgen)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.venv/bin/python -m pytest tests/test_render3.py -q`
Expected: FAIL — `ModuleNotFoundError: No module named 'stage3_tasgen.render'`

- [ ] **Step 3: Write minimal implementation**

```python
# stage3_tasgen/render.py
"""Stage ③ deterministic renderer: (IR, appgen) -> Python source.

No LLM. Dispatches IR steps/expected to TasFlutterBase primitive calls per the
spec §4-4 table. Anything outside the v1 linear subset raises Escalate (the
caller emits a stub + reason). See spec §4, §5.
"""
from __future__ import annotations

import re

LICENSE = (
    "###################################################################################\n"
    "# @@@LICENSE\n#\n#   Copyright (c) 2024 by LG Electronics Inc.\n#\n"
    "#   All rights reserved. No part of this work may be reproduced, stored in a\n"
    "#   retrieval system, or transmitted by any means without prior written\n"
    "#   permission of LG Electronics Inc.\n#\n# LICENSE@@@\n"
    "####################################################################################\n"
)
DEFAULT_TASBASE_IMPORT = "Functional.flutter._tas.tasbase"


class Escalate(Exception):
    """Raised when a TC needs logic outside the v1 linear-sequence subset."""


def _class_name(test_case_id: str) -> str:
    return "".join(p.capitalize() for p in re.split(r"[_\-\s]+", test_case_id) if p)


def _binding_for_step(appgen, sid):
    for b in appgen.get("bindings", []):
        if b.get("step_id") == sid:
            return b
    return None


def _binding_for_expected(appgen, idx):
    for b in appgen.get("bindings", []):
        if b.get("expected_index") == idx:
            return b
    return {}


def render_app_base(appgen, tasbase_import=DEFAULT_TASBASE_IMPORT) -> str:
    app = appgen["app"]
    name = app["base_class_name"]
    lines = [
        LICENSE,
        f"from {tasbase_import} import TasFlutterBase",
        "",
        "",
        f"class {name}(TasFlutterBase):",
        f"    FLUTTER_APP_ID = {app['flutter_app_id']!r}",
        f"    SAM_APP_ID = {app['sam_app_id']!r}",
        f"    FLAG_FILE = {app['flag_file']!r}",
    ]
    if app.get("jira_id"):
        lines.append(f"    JIRA_ID = {app['jira_id']!r}")
    lines.append("")
    return "\n".join(lines)


def _find_kwargs(find) -> str:
    if not find:
        return ""
    m = find["method"]
    parts = []
    if m == "byText":
        parts.append(f"by_text={find['value']!r}")
    elif m == "byKey":
        parts.append(f"by_key={find['value']!r}")
    if find.get("index") is not None:
        parts.append(f"index={find['index']}")
    return (", " + ", ".join(parts)) if parts else ""


def _render_step(step, binding) -> list[str]:
    intent = step["intent"]
    if intent == "key_press":
        return [f"self.send_key({step['key']!r})"]
    if intent == "wait":
        return [f"self.wait({step.get('seconds', 1)})"]
    if binding is None:
        raise Escalate(f"step {step.get('id')} ({intent}) has no binding")
    tn = binding["typeName"]
    fk = _find_kwargs(binding.get("find"))
    if intent == "focus_move":
        return [f"self.focus({tn!r}{fk})"]
    if intent == "find":
        return [f"self.find({tn!r}{fk})"]
    if intent == "tap":
        return [f"self.focus({tn!r}{fk})", "self.tap()"]
    if intent == "read_property":
        return [f"self.find({tn!r}{fk})", "self.get_property()"]
    if intent == "scroll":
        return [f"self.send_key({step.get('direction', 'DOWN')!r})"]
    raise Escalate(f"intent '{intent}' not supported in v1")


def _render_expected(exp, binding) -> str:
    kind = binding.get("kind") or exp.get("kind")
    if kind == "app_launch":
        return f"self.assert_app_launch({binding['appId']!r})"
    if kind == "widget_visible":
        tn = binding["typeName"]
        where = binding.get("where")
        return (f"self.assert_widget_present({tn!r}, where={where!r})" if where
                else f"self.assert_widget_present({tn!r})")
    if kind == "property_value":
        base = f"self.assert_property({binding['typeName']!r}, {binding['key']!r}, {binding['op']!r}, {binding['value']!r}"
        grp = binding.get("group")
        return base + (f", group={grp!r})" if grp else ")")
    if kind == "any_present":
        return f"self.assert_any_present({binding['options']!r})"
    raise Escalate(f"expected kind '{kind}' not supported in v1")


def render_tc(ir, appgen, tasbase_import=DEFAULT_TASBASE_IMPORT) -> str:
    base = appgen["app"]["base_class_name"]
    cls = _class_name(ir["test_case_id"])
    stem = ir["test_case_id"]

    body: list[str] = []
    for step in ir.get("steps") or []:
        body += _render_step(step, _binding_for_step(appgen, step["id"]))
    for idx, exp in enumerate(ir.get("expected") or []):
        body.append(_render_expected(exp, _binding_for_expected(appgen, idx)))
    if not body:
        raise Escalate("no renderable steps/expected")

    indent = "\n        "
    # base module file is written as "{base}.py" by render_scripts → import name must match (no lowercasing)
    return (
        LICENSE
        + f"from {tasbase_import.rsplit('.', 1)[0]}.{base} import {base}\n\n\n"
        + f"class {cls}({base}):\n\n"
        + "    def __init__(self):\n"
        + f"        self.test_name = {stem!r}\n"
        + f"        {base}.__init__(self)\n\n"
        + "    def run_flutter_test(self):\n        "
        + indent.join(body) + "\n"
    )
```

- [ ] **Step 4: Run test to verify it passes**

Run: `.venv/bin/python -m pytest tests/test_render3.py -q`
Expected: PASS (4 passed)

- [ ] **Step 5: Commit**

```bash
git add stage3_tasgen/render.py tests/test_render3.py
git commit -m "feat(stage3): deterministic render (app base + per-TC dispatch + escalate)"
```

---

## Task 6: `render_scripts` orchestration + `report.py`

**Files:**
- Modify: `stage3_tasgen/render.py` (add `render_scripts`)
- Create: `stage3_tasgen/report.py`
- Test: extend `tests/test_render3.py`

- [ ] **Step 1: Write the failing test**

Append to `tests/test_render3.py`:

```python
from stage3_tasgen.render import render_scripts
from stage3_tasgen.report import render_report


def test_render_scripts_emits_base_and_tc():
    result = render_scripts(IR, APPGEN)
    assert result["escalated"] is False
    files = result["files"]
    assert "HomeTasBase.py" in files
    assert "globalline_search.py" in files
    assert "class GloballineSearch(HomeTasBase):" in files["globalline_search.py"]


def test_render_scripts_escalates_with_reason():
    ir = {"test_case_id": "x", "title": "t", "steps": [],
          "expected": [{"kind": "navigation", "source_span": "s"}]}
    appgen = {"app": APP, "widgets": {}, "bindings": [{"expected_index": 0, "kind": "navigation"}]}
    result = render_scripts(ir, appgen)
    assert result["escalated"] is True
    assert "navigation" in result["reason"]
    assert "NotImplementedError" in result["files"]["x.py"]


def test_report_mentions_files_and_status():
    result = render_scripts(IR, APPGEN)
    text = render_report(result)
    assert "globalline_search.py" in text
    assert "OK" in text
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.venv/bin/python -m pytest tests/test_render3.py -q`
Expected: FAIL — `ImportError: cannot import name 'render_scripts'`

- [ ] **Step 3: Write minimal implementation**

Append to `stage3_tasgen/render.py`:

```python
def _escalation_stub(ir, appgen, reason: str, tasbase_import=DEFAULT_TASBASE_IMPORT) -> str:
    base = appgen["app"]["base_class_name"]
    cls = _class_name(ir["test_case_id"])
    return (
        LICENSE
        + f"from {tasbase_import.rsplit('.', 1)[0]}.{base} import {base}\n\n\n"
        + f"class {cls}({base}):\n\n"
        + "    def __init__(self):\n"
        + f"        self.test_name = {ir['test_case_id']!r}\n"
        + f"        {base}.__init__(self)\n\n"
        + "    def run_flutter_test(self):\n"
        + f"        # ESCALATE: {reason}\n"
        + "        # bespoke logic (loop/shell/multi-app/OR) — fill in by hand. See stage③ spec §5.\n"
        + f"        raise NotImplementedError({reason!r})\n"
    )


def render_scripts(ir, appgen, tasbase_import=DEFAULT_TASBASE_IMPORT) -> dict:
    """Render the full output set. Returns {files, escalated, reason}.

    files: {filename -> source}, always includes <Base>.py + <stem>.py.
    """
    base_name = appgen["app"]["base_class_name"]
    files = {f"{base_name}.py": render_app_base(appgen, tasbase_import)}
    stem = ir["test_case_id"]
    if appgen.get("unsupported"):
        reason = "appgen marked unsupported: {0}".format(appgen["unsupported"])
        files[f"{stem}.py"] = _escalation_stub(ir, appgen, reason, tasbase_import)
        return {"files": files, "escalated": True, "reason": reason}
    try:
        files[f"{stem}.py"] = render_tc(ir, appgen, tasbase_import)
        return {"files": files, "escalated": False, "reason": ""}
    except Escalate as e:
        files[f"{stem}.py"] = _escalation_stub(ir, appgen, str(e), tasbase_import)
        return {"files": files, "escalated": True, "reason": str(e)}
```

Create `stage3_tasgen/report.py`:

```python
# stage3_tasgen/report.py
"""Human-readable report for a stage③ render result."""
from __future__ import annotations


def render_report(result: dict, gate_errors=None) -> str:
    gate_errors = gate_errors or []
    lines = ["# /tas-tasgen report", ""]
    status = "ESCALATE" if result["escalated"] else ("FAIL" if gate_errors else "OK")
    lines.append(f"status: {status}")
    if result.get("reason"):
        lines.append(f"reason: {result['reason']}")
    lines.append("")
    lines.append("generated files:")
    for name in sorted(result["files"]):
        lines.append(f"  - {name}")
    if gate_errors:
        lines.append("")
        lines.append("Gate A errors:")
        for e in gate_errors:
            lines.append(f"  - {e}")
    return "\n".join(lines)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `.venv/bin/python -m pytest tests/test_render3.py -q`
Expected: PASS (7 passed)

- [ ] **Step 5: Commit**

```bash
git add stage3_tasgen/render.py stage3_tasgen/report.py tests/test_render3.py
git commit -m "feat(stage3): render_scripts orchestration + report"
```

---

## Task 7: `tasgen.py` — CLI (`/tas-tasgen`)

**Files:**
- Create: `tasgen.py`
- Test: `tests/test_golden3.py` (CLI smoke + exit codes)

- [ ] **Step 1: Write the failing test**

```python
# tests/test_golden3.py
import subprocess, sys, pathlib

ROOT = pathlib.Path(__file__).parent.parent
G = ROOT / "tests" / "golden3"


def _run(ir, appgen, outdir):
    return subprocess.run(
        [sys.executable, str(ROOT / "tasgen.py"),
         "--ir", str(ir), "--appgen", str(appgen), "-o", str(outdir)],
        capture_output=True, text=True,
    )


def test_cli_globalline_search_exit0(tmp_path):
    r = _run(G / "globalline_search.ir.yaml", G / "globalline_search.appgen.yaml", tmp_path)
    assert r.returncode == 0, r.stdout + r.stderr
    assert (tmp_path / "globalline_search.py").exists()
    assert (tmp_path / "HomeTasBase.py").exists()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.venv/bin/python -m pytest tests/test_golden3.py -q`
Expected: FAIL — golden3 yamls / tasgen.py do not exist yet (FileNotFoundError or non-zero exit)

- [ ] **Step 3: Write minimal implementation**

Create the golden input pair `tests/golden3/globalline_search.ir.yaml`:

```yaml
test_case_id: globalline_search
title: "홈 글로벌 라인 Search 버튼 동작 검증"
steps:
  - id: 1
    intent: focus_move
    target: { role: button, match: { text: "Search" } }
    source_span: "Step 1"
  - id: 2
    intent: key_press
    key: OK
    source_span: "Step 2"
expected:
  - kind: app_launch
    source_span: "Expected"
```

Create `tests/golden3/globalline_search.appgen.yaml`:

```yaml
app:
  test_label: "Tas Sample"
  flutter_app_id: com.webos.tas.home
  sam_app_id: com.webos.app.home
  package_main: package:home/main.dart
  flag_file: /var/luna/preferences/tas_home_enabled
  jira_id: TVDEVTC-23796
  base_class_name: HomeTasBase
widgets:
  Button: [text, semanticsLabel]
bindings:
  - step_id: 1
    typeName: Button
    find: { method: byText, value: "Search" }
  - expected_index: 0
    kind: app_launch
    appId: com.webos.app.voice
unsupported: []
```

Create `tasgen.py`:

```python
# tasgen.py  (= /tas-tasgen)
"""Stage ③ CLI: (IR + appgen) -> per-TC Python TAS scripts.

Pipeline: load yaml -> Gate A (validate_appgen + check_contract) -> render_scripts
-> output Gate A (check_output vs tasbase primitives) -> write files + report.
Exit: 0 OK, 1 escalate (generated stub, needs human), 2 Gate A failure.
"""
from __future__ import annotations

import argparse
import pathlib
import sys

import yaml

from stage3_tasgen.schema import validate_appgen, check_contract
from stage3_tasgen.render import render_scripts, DEFAULT_TASBASE_IMPORT
from stage3_tasgen.gate import base_methods, check_output
from stage3_tasgen.report import render_report

HERE = pathlib.Path(__file__).parent
TASBASE = HERE / "stage3_tasgen" / "tasbase.py"


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="tas-tasgen")
    ap.add_argument("--ir", required=True)
    ap.add_argument("--appgen", required=True)
    ap.add_argument("-o", "--out", default="build/tas")
    ap.add_argument("--tasbase-import", default=DEFAULT_TASBASE_IMPORT)
    args = ap.parse_args(argv)

    ir = yaml.safe_load(pathlib.Path(args.ir).read_text())
    appgen = yaml.safe_load(pathlib.Path(args.appgen).read_text())

    gate = validate_appgen(appgen) + check_contract(ir, appgen)
    if gate:
        print(render_report({"files": {}, "escalated": False, "reason": ""}, gate))
        return 2

    result = render_scripts(ir, appgen, args.tasbase_import)

    allowed = base_methods(TASBASE.read_text())
    out_errors = []
    for name, src in result["files"].items():
        out_errors += [f"{name}: {e}" for e in check_output(src, allowed)]
    if out_errors:
        print(render_report(result, out_errors))
        return 2

    outdir = pathlib.Path(args.out)
    outdir.mkdir(parents=True, exist_ok=True)
    for name, src in result["files"].items():
        (outdir / name).write_text(src)

    print(render_report(result))
    return 1 if result["escalated"] else 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run test to verify it passes**

Run: `.venv/bin/python -m pytest tests/test_golden3.py -q`
Expected: PASS (1 passed)

- [ ] **Step 5: Commit**

```bash
git add tasgen.py tests/golden3/globalline_search.ir.yaml tests/golden3/globalline_search.appgen.yaml tests/test_golden3.py
git commit -m "feat(stage3): /tas-tasgen CLI + globalline_search golden input"
```

---

## Task 8: Golden regression — frozen expected output

**Files:**
- Create: `tests/golden3/globalline_search.expected.py`, `tests/golden3/HomeTasBase.expected.py`
- Create: `tests/golden3/qcard.ir.yaml`, `tests/golden3/qcard.appgen.yaml`, `tests/golden3/qcard.expected.py`
- Test: extend `tests/test_golden3.py`

- [ ] **Step 1: Write the failing test**

Append to `tests/test_golden3.py`:

```python
import yaml
from stage3_tasgen.render import render_scripts


def _load(stem):
    ir = yaml.safe_load((G / f"{stem}.ir.yaml").read_text())
    appgen = yaml.safe_load((G / f"{stem}.appgen.yaml").read_text())
    return ir, appgen


def test_globalline_search_matches_golden():
    ir, appgen = _load("globalline_search")
    files = render_scripts(ir, appgen)["files"]
    assert files["globalline_search.py"] == (G / "globalline_search.expected.py").read_text()
    assert files["HomeTasBase.py"] == (G / "HomeTasBase.expected.py").read_text()


def test_qcard_matches_golden():
    ir, appgen = _load("qcard")
    files = render_scripts(ir, appgen)["files"]
    assert files["qcard.py"] == (G / "qcard.expected.py").read_text()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.venv/bin/python -m pytest tests/test_golden3.py -q -k matches_golden`
Expected: FAIL — expected.py / qcard.* files do not exist

- [ ] **Step 3: Write minimal implementation**

Generate the expected files from the (already-tested) renderer, then eyeball them before freezing:

Run:
```bash
.venv/bin/python tasgen.py --ir tests/golden3/globalline_search.ir.yaml \
  --appgen tests/golden3/globalline_search.appgen.yaml -o tests/golden3
mv tests/golden3/globalline_search.py tests/golden3/globalline_search.expected.py
mv tests/golden3/HomeTasBase.py tests/golden3/HomeTasBase.expected.py
```

Create `tests/golden3/qcard.ir.yaml`:

```yaml
test_case_id: qcard
title: "Q카드 shelf 출력 확인"
steps: []
expected:
  - kind: property_value
    source_span: "Expected: Q카드 shelf item_count >= 1"
```

Create `tests/golden3/qcard.appgen.yaml`:

```yaml
app:
  test_label: "Tas Sample"
  flutter_app_id: com.webos.tas.home
  sam_app_id: com.webos.app.home
  package_main: package:home/main.dart
  flag_file: /var/luna/preferences/tas_home_enabled
  jira_id: TVDEVTC-23796
  base_class_name: HomeTasBase
widgets:
  WAnimatedCarousel: [item_count, group_label]
bindings:
  - expected_index: 0
    kind: property_value
    typeName: WAnimatedCarousel
    key: item_count
    op: ">="
    value: 1
    group: HOME_SH_QCARD
unsupported: []
```

Run:
```bash
.venv/bin/python tasgen.py --ir tests/golden3/qcard.ir.yaml \
  --appgen tests/golden3/qcard.appgen.yaml -o tests/golden3
mv tests/golden3/qcard.py tests/golden3/qcard.expected.py
rm -f tests/golden3/HomeTasBase.py   # qcard run also emits a base; drop the dup
```

Manually read both `*.expected.py` files and confirm they match the spec §4 shape (license header, 3-layer imports, ordered primitive calls). They are now the frozen golden.

- [ ] **Step 4: Run test to verify it passes**

Run: `.venv/bin/python -m pytest tests/test_golden3.py -q`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
git add tests/golden3/
git commit -m "test(stage3): golden regression — globalline_search + qcard frozen outputs"
```

---

## Task 9: Negative fixtures — Gate A rejects bad plans end-to-end

**Files:**
- Create: `tests/fixtures3/unknown_typename.appgen.yaml`, `missing_binding.appgen.yaml`, `key_not_in_contract.appgen.yaml`
- Test: extend `tests/test_golden3.py`

- [ ] **Step 1: Write the failing test**

Append to `tests/test_golden3.py`:

```python
F = ROOT / "tests" / "fixtures3"


def test_unknown_typename_exit2(tmp_path):
    r = _run(G / "globalline_search.ir.yaml", F / "unknown_typename.appgen.yaml", tmp_path)
    assert r.returncode == 2
    assert "not in widgets" in r.stdout


def test_missing_binding_exit2(tmp_path):
    r = _run(G / "globalline_search.ir.yaml", F / "missing_binding.appgen.yaml", tmp_path)
    assert r.returncode == 2
    assert "no binding" in r.stdout


def test_key_not_in_contract_exit2(tmp_path):
    r = _run(G / "qcard.ir.yaml", F / "key_not_in_contract.appgen.yaml", tmp_path)
    assert r.returncode == 2
    assert "not exposed" in r.stdout
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.venv/bin/python -m pytest tests/test_golden3.py -q -k exit2`
Expected: FAIL — fixture files do not exist (CLI errors / wrong code)

- [ ] **Step 3: Write minimal implementation**

Create `tests/fixtures3/unknown_typename.appgen.yaml` (typeName not in widgets):

```yaml
app: { flutter_app_id: a, sam_app_id: b, flag_file: c, base_class_name: HomeTasBase }
widgets: { Button: [text] }
bindings:
  - step_id: 1
    typeName: Ghost
    find: { method: byText, value: "Search" }
  - expected_index: 0
    kind: app_launch
    appId: com.webos.app.voice
unsupported: []
```

Create `tests/fixtures3/missing_binding.appgen.yaml` (focus_move step 1 has no binding):

```yaml
app: { flutter_app_id: a, sam_app_id: b, flag_file: c, base_class_name: HomeTasBase }
widgets: { Button: [text] }
bindings:
  - expected_index: 0
    kind: app_launch
    appId: com.webos.app.voice
unsupported: []
```

Create `tests/fixtures3/key_not_in_contract.appgen.yaml` (item_count not exposed):

```yaml
app: { flutter_app_id: a, sam_app_id: b, flag_file: c, base_class_name: HomeTasBase }
widgets: { WAnimatedCarousel: [group_label] }
bindings:
  - expected_index: 0
    kind: property_value
    typeName: WAnimatedCarousel
    key: item_count
    op: ">="
    value: 1
    group: HOME_SH_QCARD
unsupported: []
```

- [ ] **Step 4: Run test to verify it passes**

Run: `.venv/bin/python -m pytest tests/test_golden3.py -q`
Expected: PASS (6 passed)

- [ ] **Step 5: Commit**

```bash
git add tests/fixtures3/ tests/test_golden3.py
git commit -m "test(stage3): negative fixtures — Gate A rejects unknown type / missing binding / unexposed key"
```

---

## Task 10: Escalation end-to-end + full-suite green

**Files:**
- Create: `tests/golden3/bespoke_loop.ir.yaml`, `tests/golden3/bespoke_loop.appgen.yaml`
- Test: extend `tests/test_golden3.py`

- [ ] **Step 1: Write the failing test**

Append to `tests/test_golden3.py`:

```python
def test_bespoke_escalates_exit1(tmp_path):
    r = _run(G / "bespoke_loop.ir.yaml", G / "bespoke_loop.appgen.yaml", tmp_path)
    assert r.returncode == 1
    assert "ESCALATE" in r.stdout
    stub = (tmp_path / "bespoke_loop.py").read_text()
    assert "NotImplementedError" in stub
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.venv/bin/python -m pytest tests/test_golden3.py -q -k bespoke`
Expected: FAIL — bespoke_loop.* do not exist

- [ ] **Step 3: Write minimal implementation**

Create `tests/golden3/bespoke_loop.ir.yaml` (a `navigation` expected → v1 unsupported → escalate):

```yaml
test_case_id: bespoke_loop
title: "launch home repeatedly (bespoke)"
steps: []
expected:
  - kind: navigation
    source_span: "Expected: relaunch loop"
```

Create `tests/golden3/bespoke_loop.appgen.yaml`:

```yaml
app:
  flutter_app_id: com.webos.tas.home
  sam_app_id: com.webos.app.home
  flag_file: /var/luna/preferences/tas_home_enabled
  base_class_name: HomeTasBase
widgets: {}
bindings:
  - expected_index: 0
    kind: navigation
unsupported: []
```

- [ ] **Step 4: Run test to verify it passes, then run the WHOLE suite**

Run: `.venv/bin/python -m pytest tests/test_golden3.py -q`
Expected: PASS (7 passed)

Run: `.venv/bin/python -m pytest -q`
Expected: PASS — all stage① (36) + stage③ tests green, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add tests/golden3/bespoke_loop.ir.yaml tests/golden3/bespoke_loop.appgen.yaml tests/test_golden3.py
git commit -m "test(stage3): bespoke TC escalates with NotImplementedError stub (exit 1)"
```

---

## Task 11: `/tas-tasgen` skill + README

**Files:**
- Create: `.claude/skills/tas-tasgen/SKILL.md`
- Symlink: `~/.claude/skills/tas-tasgen` → repo skill dir (mirrors stage① `/tas-parse`)
- Modify: `README.md` (add stage③ section)

- [ ] **Step 1: Write the skill**

Create `.claude/skills/tas-tasgen/SKILL.md`:

```markdown
---
name: tas-tasgen
description: "TAS 자동화 3단계 — ① IR + ② appgen_output(resolved bindings)를 받아 얇은 per-TC Python TAS 스크립트(+앱 meta base)를 결정론적으로 생성한다. 앱 비종속, LLM/디바이스/API키 불필요. 사용 시점: stage① IR(yaml)과 stage② appgen output(yaml)이 준비됐고 TAS 스크립트를 찍고 싶을 때. 선행: /tas-parse(①). 다음: /tas-verify(④)."
---

# /tas-tasgen — IR + appgen → Python TAS 스크립트 (stage③)

결정론 렌더러. 추측 없음 — v1 미지원(루프/셸/멀티앱/OR)은 escalate 스텁을 찍고 사람에게 넘긴다.

## 입력
- `--ir <IR.yaml>` : stage①(`/tas-parse`) 산출 IR.
- `--appgen <appgen.yaml>` : stage② 산출(앱 meta + widgets contract + bindings). 스키마는 stage③ 스펙 §3-2.

## 실행
\`\`\`bash
python3 /home/younginkim/project/AI/tas-tool/tasgen.py \
  --ir <IR.yaml> --appgen <appgen.yaml> -o build/tas
\`\`\`
- 산출: `build/tas/<App>TasBase.py`(앱당 1) + `build/tas/<stem>.py`(TC당). `tasbase.py`는 도구에 고정 포함.
- 종료코드: `0` 생성·검증 OK / `1` escalate(스텁 생성, 사람 보완 필요) / `2` Gate A 실패(계약 위반).

## 결과별 안내
- **exit 2 (Gate A)**: 리포트의 오류대로 appgen 수정 — typeName이 widgets에 없음 / target-step에 binding 없음 / property key 미노출 / primitive가 base에 없음.
- **exit 1 (escalate)**: v1 선형 시퀀스로 표현 불가(루프·셸·멀티앱·OR조건). 생성된 스텁의 `run_flutter_test`를 사람이 채운다.
- **exit 0**: `build/tas/`의 스크립트를 ④(`/tas-verify`)로 빌드·실행.

## 원칙
- ③은 이미 풀린 것을 코드로 옮길 뿐 — TypeName/property를 새로 해석하지 않는다(②의 책임).
- 모르는 패턴을 지어내지 말 것. escalate면 사람에게 확인.
```

- [ ] **Step 2: Create the symlink and verify**

Run:
```bash
ln -sfn /home/younginkim/project/AI/tas-tool/.claude/skills/tas-tasgen /home/younginkim/.claude/skills/tas-tasgen
ls -l /home/younginkim/.claude/skills/tas-tasgen
```
Expected: symlink resolves to the repo skill dir.

- [ ] **Step 3: Update README**

Add to `README.md` a `## stage③ /tas-tasgen` section: one-line purpose, the run command, exit-code table, and a pointer to the spec `docs/superpowers/specs/2026-06-10-tas-stage3-tasgen-design.md`. (Mirror the stage① section's format already in the file.)

- [ ] **Step 4: Verify the whole suite once more**

Run: `.venv/bin/python -m pytest -q`
Expected: PASS — all green.

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/tas-tasgen/SKILL.md README.md
git commit -m "feat(stage3): /tas-tasgen skill + README"
```

---

## Self-Review Notes (author)

- **Spec coverage**: §2 책임(결정론·LLM없음)→Tasks 5-7; §3 입력계약→Task 2(schema)+golden yamls; §4 3-layer 출력→Task 4(tasbase)+Task 5(render); §4-4 dispatch표→Task 5; §5 escalate→Tasks 6,10; §6-1 Gate A(dict+AST)→Tasks 2,3,7; §6-2 골든/negative→Tasks 8,9; §7 모듈→all; skill 배포→Task 11. `assert_any_present`/OR는 tasbase에 포함(Task 4)하되 v1 골든은 escalate 경로로만 검증(Task 10) — OR-binding 렌더는 차기.
- **Placeholder scan**: none — every step has concrete code/commands.
- **Type consistency**: `render_scripts` returns `{files, escalated, reason}` (Tasks 6,7,8,10 agree). Primitive names in `render.py` emits ⊆ `tasbase.py` defs ⊆ `REQUIRED_PRIMITIVES` (Task 4) — verified by output Gate A (Task 7) and the AST presence test (Task 4). `base_class_name`/`_class_name()` naming consistent across render + stubs.
```
