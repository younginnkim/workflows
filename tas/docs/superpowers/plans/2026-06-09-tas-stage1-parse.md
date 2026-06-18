# TAS! Stage ① `/tas-parse` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `/tas-parse` tool that turns a natural-language webOS Flutter TAS TestCase into a validated app-agnostic semantic IR (YAML).

**Architecture:** A deterministic Python core orchestrates two LLM touch-points (generator, judge) through a replaceable adapter. Runtime pipeline = `generator → Gate A (deterministic schema) → Gate B (LLM faithfulness judge, optional) → retry/escalate`. Golden-regression and negative-fixture checks are author-only eval, kept out of the shipped pipeline. All unit tests run against a `FakeLLM` so the suite is deterministic and needs no API key.

**Tech Stack:** Python 3.10, PyYAML, `anthropic` SDK (runtime LLM adapter), pytest (author eval). Spec: `docs/superpowers/specs/2026-06-09-tas-stage1-parse-design.md`.

---

## File Structure

```
tas-tool/
  stage1_parse/              # ── shipped runtime package ──
    __init__.py
    schema.py                # enum sets + validate() = Gate A (deterministic)
    llm.py                   # LLMAdapter protocol + FakeLLM + AnthropicAdapter + get_adapter()
    generator.py             # generator prompt + YAML extraction + generate_ir()
    judge.py                 # judge prompt + verdict parse + judge_ir() = Gate B
    loop.py                  # run_parse(): generate→A→B→retry→escalate
  parse.py                   # CLI entrypoint (= /tas-parse)
  tests/                     # ── author-only eval harness (not shipped) ──
    __init__.py
    compare.py               # normalize() + semantic_equal() for golden comparison
    conftest.py              # shared fixtures (golden loader)
    golden/
      globalline_search.txt  # TestCase text
      globalline_search.yaml # hand-written golden IR
    fixtures/
      missing_source_span.yaml
      bad_intent.yaml
    test_schema.py           # Gate A unit tests (+ fixtures)
    test_generator.py        # prompt build + YAML extraction
    test_judge.py            # verdict parse
    test_loop.py             # orchestration (retry, escalate, judge toggle) via FakeLLM
    test_golden.py           # golden regression via FakeLLM (plumbing)
  eval/                       # ── real-LLM evals (key-gated, manual) ──
    eval_golden.py           # run real generator vs golden, semantic_equal
    eval_judge.py            # feed hallucinated IR to real judge, expect "fail"
  requirements.txt
  pytest.ini
  README.md
```

Each module has one responsibility. `schema.py` is pure (no LLM, no IO). `llm.py` is the only place that imports `anthropic`. `tests/` and `eval/` never ship.

---

## Task 0: Project scaffold

**Files:**
- Create: `requirements.txt`, `pytest.ini`, `.gitignore`
- Create: `stage1_parse/__init__.py`, `tests/__init__.py`

- [ ] **Step 1: Initialize git and Python package dirs**

```bash
cd /home/younginkim/project/AI/tas-tool
git init
mkdir -p stage1_parse tests/golden tests/fixtures eval
touch stage1_parse/__init__.py tests/__init__.py
```

- [ ] **Step 2: Write `requirements.txt`**

```
PyYAML>=6.0
anthropic>=0.40.0
pytest>=8.0
```

- [ ] **Step 3: Write `pytest.ini`**

```ini
[pytest]
testpaths = tests
python_files = test_*.py
addopts = -v
```

- [ ] **Step 4: Write `.gitignore`**

```
__pycache__/
*.pyc
.venv/
build/
.env
```

- [ ] **Step 5: Create venv and install deps**

Run:
```bash
cd /home/younginkim/project/AI/tas-tool
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```
Expected: installs PyYAML, anthropic, pytest without error. (Use `.venv/bin/python` / `.venv/bin/pytest` for all later steps.)

- [ ] **Step 6: Verify pytest runs (collects 0 tests)**

Run: `.venv/bin/pytest`
Expected: `no tests ran` (exit code 5) — confirms pytest works.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "chore: scaffold tas-tool stage1 project"
```

---

## Task 1: IR schema constants + Gate A `validate()`

**Files:**
- Create: `stage1_parse/schema.py`
- Test: `tests/test_schema.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_schema.py
from stage1_parse.schema import validate

VALID_IR = {
    "test_case_id": "globalline_search_launches_voice",
    "title": "홈 앱 글로벌 라인 Search 버튼 동작 검증",
    "source_ticket": None,
    "target_app": "com.webos.app.home",
    "preconditions": [
        {"kind": "app_lifecycle", "value": "resumed", "app": "com.webos.app.home",
         "source_span": "Precondition: 홈 앱이 foreground"},
    ],
    "steps": [
        {"id": 1, "intent": "focus_move",
         "target": {"role": "button", "match": {"text": "Search", "key": None, "index": None},
                    "container": "글로벌 라인"},
         "source_span": "Step 1: 글로벌 라인에서 Search 버튼으로 포커스 이동"},
        {"id": 2, "intent": "key_press", "key": "OK",
         "source_span": "Step 2: OK 키 입력"},
    ],
    "expected": [
        {"kind": "app_launch", "value": "com.webos.app.voice (search 모드)", "params": None,
         "source_span": "Expected: com.webos.app.voice 가 search 모드로 launch"},
    ],
    "unresolved": [],
}

def test_valid_ir_has_no_errors():
    assert validate(VALID_IR) == []

def test_missing_required_field():
    ir = {k: v for k, v in VALID_IR.items() if k != "title"}
    assert any("title" in e for e in validate(ir))

def test_step_missing_source_span():
    ir = {**VALID_IR, "steps": [{"id": 1, "intent": "tap",
          "target": {"role": "button", "match": {"text": "X", "key": None, "index": None}}}]}
    assert any("source_span" in e for e in validate(ir))

def test_bad_intent_rejected():
    ir = {**VALID_IR, "steps": [{"id": 1, "intent": "teleport",
          "source_span": "x"}]}
    assert any("intent" in e for e in validate(ir))

def test_key_press_requires_valid_key():
    ir = {**VALID_IR, "steps": [{"id": 1, "intent": "key_press", "key": "SPACE",
          "source_span": "x"}]}
    assert any("key" in e for e in validate(ir))

def test_target_required_intent_without_target():
    ir = {**VALID_IR, "steps": [{"id": 1, "intent": "find", "source_span": "x"}]}
    assert any("target" in e for e in validate(ir))

def test_step_ids_must_ascend():
    ir = {**VALID_IR, "steps": [
        {"id": 2, "intent": "key_press", "key": "OK", "source_span": "a"},
        {"id": 1, "intent": "key_press", "key": "OK", "source_span": "b"}]}
    assert any("ascending" in e for e in validate(ir))

def test_bad_lifecycle_value():
    ir = {**VALID_IR, "preconditions": [
        {"kind": "app_lifecycle", "value": "running", "app": None, "source_span": "x"}]}
    assert any("lifecycle" in e for e in validate(ir))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.venv/bin/pytest tests/test_schema.py`
Expected: FAIL with `ModuleNotFoundError: No module named 'stage1_parse.schema'`.

- [ ] **Step 3: Write minimal implementation**

```python
# stage1_parse/schema.py
"""Semantic IR enum sets and Gate A (deterministic validation).

Pure module: no LLM, no IO. Operates on the parsed-YAML dict.
Grounding: see spec 부록 A/B. Roles are an OPEN hint set and are NOT enforced.
"""
from __future__ import annotations

INTENTS = {"find", "focus_move", "key_press", "tap", "scroll", "wait", "read_property"}
KEYS = {"OK", "UP", "DOWN", "LEFT", "RIGHT", "BACK", "HOME"}
EXPECTED_KINDS = {"app_launch", "widget_visible", "property_value", "state_change", "navigation"}
PRECONDITION_KINDS = {"app_lifecycle", "focused", "property_value"}
LIFECYCLE = {"resumed", "inactive", "paused", "detached", "hidden"}
# intents that must carry a `target`
TARGET_REQUIRED = {"find", "focus_move", "tap", "scroll", "read_property"}
REQUIRED_TOP = ("test_case_id", "title", "steps")


def validate(ir) -> list[str]:
    """Return a list of human-readable schema errors. Empty list = Gate A pass."""
    errors: list[str] = []
    if not isinstance(ir, dict):
        return ["IR is not a mapping"]

    for f in REQUIRED_TOP:
        if f not in ir:
            errors.append(f"missing required field: {f}")

    for i, p in enumerate(ir.get("preconditions") or []):
        if "source_span" not in p:
            errors.append(f"preconditions[{i}] missing source_span")
        if p.get("kind") not in PRECONDITION_KINDS:
            errors.append(f"preconditions[{i}] invalid kind: {p.get('kind')}")
        if p.get("kind") == "app_lifecycle" and p.get("value") not in LIFECYCLE:
            errors.append(f"preconditions[{i}] invalid lifecycle value: {p.get('value')}")

    last_id = 0
    for i, s in enumerate(ir.get("steps") or []):
        if "source_span" not in s:
            errors.append(f"steps[{i}] missing source_span")
        intent = s.get("intent")
        if intent not in INTENTS:
            errors.append(f"steps[{i}] invalid intent: {intent}")
        if intent == "key_press" and s.get("key") not in KEYS:
            errors.append(f"steps[{i}] invalid/missing key: {s.get('key')}")
        if intent in TARGET_REQUIRED and not s.get("target"):
            errors.append(f"steps[{i}] intent '{intent}' requires target")
        sid = s.get("id")
        if not isinstance(sid, int) or sid <= last_id:
            errors.append(f"steps[{i}] id must be ascending int, got {sid}")
        else:
            last_id = sid

    for i, e in enumerate(ir.get("expected") or []):
        if "source_span" not in e:
            errors.append(f"expected[{i}] missing source_span")
        if e.get("kind") not in EXPECTED_KINDS:
            errors.append(f"expected[{i}] invalid kind: {e.get('kind')}")

    return errors
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `.venv/bin/pytest tests/test_schema.py`
Expected: 8 passed.

- [ ] **Step 5: Commit**

```bash
git add stage1_parse/schema.py tests/test_schema.py
git commit -m "feat(stage1): IR schema enums + Gate A validate()"
```

---

## Task 2: Negative fixtures for Gate A

**Files:**
- Create: `tests/fixtures/missing_source_span.yaml`, `tests/fixtures/bad_intent.yaml`
- Test: extend `tests/test_schema.py`

- [ ] **Step 1: Write the fixture files**

`tests/fixtures/missing_source_span.yaml`:
```yaml
test_case_id: x
title: x
steps:
  - id: 1
    intent: tap
    target:
      role: button
      match: { text: "X", key: null, index: null }
```

`tests/fixtures/bad_intent.yaml`:
```yaml
test_case_id: x
title: x
steps:
  - id: 1
    intent: fly
    source_span: "Step 1"
```

- [ ] **Step 2: Write the failing test**

```python
# append to tests/test_schema.py
import pathlib
import yaml
from stage1_parse.schema import validate

FIX = pathlib.Path(__file__).parent / "fixtures"

def _load(name):
    return yaml.safe_load((FIX / name).read_text())

def test_fixture_missing_source_span_rejected():
    assert any("source_span" in e for e in validate(_load("missing_source_span.yaml")))

def test_fixture_bad_intent_rejected():
    assert any("intent" in e for e in validate(_load("bad_intent.yaml")))
```

- [ ] **Step 3: Run tests to verify they pass**

Run: `.venv/bin/pytest tests/test_schema.py -k fixture`
Expected: 2 passed (validate already implemented in Task 1).

- [ ] **Step 4: Commit**

```bash
git add tests/fixtures tests/test_schema.py
git commit -m "test(stage1): Gate A negative fixtures"
```

---

## Task 3: LLM adapter (protocol + FakeLLM + Anthropic + factory)

**Files:**
- Create: `stage1_parse/llm.py`
- Test: `tests/test_llm.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_llm.py
import pytest
from stage1_parse.llm import FakeLLM, get_adapter

def test_fakellm_returns_responses_in_order():
    llm = FakeLLM(["a", "b"])
    assert llm.generate("p1") == "a"
    assert llm.generate("p2") == "b"
    assert llm.calls == ["p1", "p2"]

def test_fakellm_raises_when_exhausted():
    llm = FakeLLM([])
    with pytest.raises(RuntimeError):
        llm.generate("p")

def test_get_adapter_fake():
    assert isinstance(get_adapter("fake"), FakeLLM)

def test_get_adapter_unknown():
    with pytest.raises(ValueError):
        get_adapter("nope")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.venv/bin/pytest tests/test_llm.py`
Expected: FAIL with `ModuleNotFoundError: No module named 'stage1_parse.llm'`.

- [ ] **Step 3: Write minimal implementation**

```python
# stage1_parse/llm.py
"""LLM adapter boundary. The ONLY module that imports `anthropic`.

Swapping AnthropicAdapter for a Claude Code subagent adapter later touches
nothing else (spec §6). Tests use FakeLLM so the suite needs no API key.
"""
from __future__ import annotations
import os
from typing import Protocol


class LLMAdapter(Protocol):
    def generate(self, prompt: str) -> str: ...


class FakeLLM:
    """Deterministic adapter: returns canned responses in order; records prompts."""
    def __init__(self, responses):
        self._responses = list(responses)
        self.calls: list[str] = []

    def generate(self, prompt: str) -> str:
        self.calls.append(prompt)
        if not self._responses:
            raise RuntimeError("FakeLLM out of responses")
        return self._responses.pop(0)


class AnthropicAdapter:
    def __init__(self, model: str = "claude-opus-4-8", max_tokens: int = 4096):
        import anthropic  # local import so tests don't require the package
        self._client = anthropic.Anthropic()
        self._model = model
        self._max_tokens = max_tokens

    def generate(self, prompt: str) -> str:
        msg = self._client.messages.create(
            model=self._model,
            max_tokens=self._max_tokens,
            messages=[{"role": "user", "content": prompt}],
        )
        return "".join(b.text for b in msg.content if getattr(b, "type", None) == "text")


def get_adapter(name: str | None = None) -> LLMAdapter:
    name = name or os.environ.get("TAS_LLM", "anthropic")
    if name == "anthropic":
        return AnthropicAdapter()
    if name == "fake":
        return FakeLLM([])
    raise ValueError(f"unknown LLM adapter: {name}")
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `.venv/bin/pytest tests/test_llm.py`
Expected: 4 passed.

- [ ] **Step 5: Commit**

```bash
git add stage1_parse/llm.py tests/test_llm.py
git commit -m "feat(stage1): replaceable LLM adapter (FakeLLM + Anthropic)"
```

---

## Task 4: Generator (prompt + YAML extraction + generate_ir)

**Files:**
- Create: `stage1_parse/generator.py`
- Test: `tests/test_generator.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_generator.py
import pytest
from stage1_parse.generator import build_generator_prompt, parse_ir, generate_ir
from stage1_parse.llm import FakeLLM

YAML_RESPONSE = """Here is the IR:
```yaml
test_case_id: x
title: T
steps:
  - id: 1
    intent: key_press
    key: OK
    source_span: "Step 1: OK"
```
done
"""

def test_parse_ir_extracts_yaml_block():
    ir = parse_ir(YAML_RESPONSE)
    assert ir["test_case_id"] == "x"
    assert ir["steps"][0]["key"] == "OK"

def test_parse_ir_rejects_non_mapping():
    with pytest.raises(ValueError):
        parse_ir("```yaml\n- just\n- a\n- list\n```")

def test_prompt_includes_tc_and_rules():
    p = build_generator_prompt("MY_TC_TEXT", "TVDEVTC-1")
    assert "MY_TC_TEXT" in p
    assert "TVDEVTC-1" in p
    assert "source_span" in p          # rules present
    assert "Never invent" in p

def test_prompt_includes_feedback_on_retry():
    p = build_generator_prompt("tc", None, feedback="steps[0] missing source_span")
    assert "missing source_span" in p

def test_generate_ir_calls_llm_and_parses():
    llm = FakeLLM([YAML_RESPONSE])
    ir = generate_ir("tc", None, llm)
    assert ir["title"] == "T"
    assert len(llm.calls) == 1
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.venv/bin/pytest tests/test_generator.py`
Expected: FAIL with `ModuleNotFoundError: No module named 'stage1_parse.generator'`.

- [ ] **Step 3: Write minimal implementation**

```python
# stage1_parse/generator.py
"""Generator: natural-language TestCase -> semantic IR dict (via LLM)."""
from __future__ import annotations
import re
import yaml

SCHEMA_RULES = """You convert a webOS Flutter TAS TestCase (Korean or English) into a semantic IR (YAML).

HARD RULES:
- Extract ONLY what the TestCase states. Never invent widgets, identifiers, keys, or steps.
- Do NOT output concrete widget TypeNames or properties (a later stage resolves those).
- EVERY preconditions/steps/expected element MUST include a `source_span`: a verbatim quote from the TestCase that justifies it.
- If something is ambiguous (e.g. "that button" with no identifier), do NOT guess — add it to `unresolved`.
- foreground == app_lifecycle value `resumed`.

Emit a SINGLE ```yaml code block with this shape:
test_case_id: <slug from title>
title: <string>
source_ticket: <ticket key or null>
target_app: <appId if stated, else null>
preconditions:
  - kind: app_lifecycle|focused|property_value
    value: <resumed|inactive|paused|detached|hidden when kind=app_lifecycle>
    app: <appId or null>
    source_span: <verbatim quote>
steps:
  - id: <int, ascending from 1>
    intent: find|focus_move|key_press|tap|scroll|wait|read_property
    target:            # required for find/focus_move/tap/scroll/read_property
      role: button|list|item|banner|icon|text|container   # semantic hint
      match: { text: <visible label or null>, key: <explicit id or null>, index: <int or null> }
      container: <semantic parent or null>
    key: OK|UP|DOWN|LEFT|RIGHT|BACK|HOME    # required for key_press only
    source_span: <verbatim quote>
expected:
  - kind: app_launch|widget_visible|property_value|state_change|navigation
    value: <string>
    params: <map or null>
    source_span: <verbatim quote>
unresolved: []         # list of {reason, source_span} for anything ambiguous
"""


def build_generator_prompt(tc_text: str, ticket: str | None, feedback: str | None = None) -> str:
    parts = [SCHEMA_RULES, f"\nticket: {ticket or 'null'}", "\nTestCase:\n" + tc_text]
    if feedback:
        parts.append(
            "\nYour previous attempt was REJECTED. Fix these issues and re-emit the FULL IR:\n"
            + feedback
        )
    return "\n".join(parts)


def parse_ir(raw: str) -> dict:
    """Extract the first ```yaml (or bare) block and parse it into a dict."""
    m = re.search(r"```(?:yaml)?\s*(.*?)```", raw, re.DOTALL)
    text = m.group(1) if m else raw
    data = yaml.safe_load(text)
    if not isinstance(data, dict):
        raise ValueError("LLM did not return a YAML mapping")
    return data


def generate_ir(tc_text: str, ticket: str | None, llm, feedback: str | None = None) -> dict:
    return parse_ir(llm.generate(build_generator_prompt(tc_text, ticket, feedback)))
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `.venv/bin/pytest tests/test_generator.py`
Expected: 5 passed.

- [ ] **Step 5: Commit**

```bash
git add stage1_parse/generator.py tests/test_generator.py
git commit -m "feat(stage1): generator prompt + YAML extraction"
```

---

## Task 5: Judge / Gate B (prompt + verdict parse + judge_ir)

**Files:**
- Create: `stage1_parse/judge.py`
- Test: `tests/test_judge.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_judge.py
from stage1_parse.judge import build_judge_prompt, parse_verdict, judge_ir
from stage1_parse.llm import FakeLLM

def test_parse_verdict_pass():
    v = parse_verdict('```json\n{"verdict": "pass", "defects": []}\n```')
    assert v["verdict"] == "pass"
    assert v["defects"] == []

def test_parse_verdict_fail_with_defects():
    raw = '```json\n{"verdict": "fail", "defects": ["dropped Step 2"]}\n```'
    v = parse_verdict(raw)
    assert v["verdict"] == "fail"
    assert "dropped Step 2" in v["defects"]

def test_judge_prompt_includes_tc_and_ir():
    p = build_judge_prompt("MY_TC", {"title": "T", "steps": []})
    assert "MY_TC" in p
    assert "title: T" in p
    assert "coverage" in p and "faithfulness" in p

def test_judge_ir_calls_llm():
    llm = FakeLLM(['```json\n{"verdict": "pass", "defects": []}\n```'])
    v = judge_ir("tc", {"title": "T", "steps": []}, llm)
    assert v["verdict"] == "pass"
    assert len(llm.calls) == 1
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.venv/bin/pytest tests/test_judge.py`
Expected: FAIL with `ModuleNotFoundError: No module named 'stage1_parse.judge'`.

- [ ] **Step 3: Write minimal implementation**

```python
# stage1_parse/judge.py
"""Gate B: LLM faithfulness judge. Needs no answer key — compares IR to the TC text only."""
from __future__ import annotations
import json
import re
import yaml

JUDGE_RULES = """You are a STRICT faithfulness judge for a TAS semantic IR extracted from a TestCase.
Check TWO things ONLY:
1. coverage: every step and every expected-result stated in the TestCase appears in the IR (nothing dropped).
2. faithfulness: every IR element is traceable to its `source_span` quote in the TestCase, and nothing is invented (no widgets/keys/steps/identifiers that are not in the text).

Do NOT judge style, or whether concrete widget TypeNames are present (a later stage adds those).
Output a SINGLE ```json block exactly:
{"verdict": "pass" | "fail", "defects": ["<specific issue>", ...]}
verdict is "pass" only if BOTH checks hold. Otherwise list concrete defects."""


def build_judge_prompt(tc_text: str, ir: dict) -> str:
    ir_yaml = yaml.safe_dump(ir, allow_unicode=True, sort_keys=False)
    return f"{JUDGE_RULES}\n\nTestCase:\n{tc_text}\n\nIR:\n```yaml\n{ir_yaml}```"


def parse_verdict(raw: str) -> dict:
    m = re.search(r"```(?:json)?\s*(.*?)```", raw, re.DOTALL)
    text = m.group(1) if m else raw
    data = json.loads(text)
    return {"verdict": data.get("verdict"), "defects": data.get("defects", [])}


def judge_ir(tc_text: str, ir: dict, llm) -> dict:
    return parse_verdict(llm.generate(build_judge_prompt(tc_text, ir)))
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `.venv/bin/pytest tests/test_judge.py`
Expected: 4 passed.

- [ ] **Step 5: Commit**

```bash
git add stage1_parse/judge.py tests/test_judge.py
git commit -m "feat(stage1): Gate B faithfulness judge"
```

---

## Task 6: Orchestration loop (`run_parse`)

**Files:**
- Create: `stage1_parse/loop.py`
- Test: `tests/test_loop.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_loop.py
from stage1_parse.loop import run_parse, Result
from stage1_parse.llm import FakeLLM

GOOD_IR_YAML = """```yaml
test_case_id: x
title: T
source_ticket: null
target_app: null
preconditions: []
steps:
  - id: 1
    intent: key_press
    key: OK
    source_span: "Step 1: OK"
expected: []
unresolved: []
```"""

PASS_VERDICT = '```json\n{"verdict": "pass", "defects": []}\n```'
FAIL_VERDICT = '```json\n{"verdict": "fail", "defects": ["dropped a step"]}\n```'

BAD_SCHEMA_YAML = """```yaml
test_case_id: x
title: T
steps:
  - id: 1
    intent: key_press
    key: SPACE
    source_span: "Step 1"
```"""

def test_pass_first_try():
    llm = FakeLLM([GOOD_IR_YAML, PASS_VERDICT])
    r = run_parse("tc", None, llm, use_judge=True)
    assert r.status == "pass"
    assert r.attempts == 1
    assert r.ir["title"] == "T"

def test_no_judge_skips_gate_b():
    llm = FakeLLM([GOOD_IR_YAML])   # only generator response needed
    r = run_parse("tc", None, llm, use_judge=False)
    assert r.status == "pass"
    assert len(llm.calls) == 1      # judge never called

def test_schema_failure_then_retry_succeeds():
    llm = FakeLLM([BAD_SCHEMA_YAML, GOOD_IR_YAML, PASS_VERDICT])
    r = run_parse("tc", None, llm, use_judge=True, max_retries=3)
    assert r.status == "pass"
    assert r.attempts == 2

def test_judge_failure_then_retry_succeeds():
    llm = FakeLLM([GOOD_IR_YAML, FAIL_VERDICT, GOOD_IR_YAML, PASS_VERDICT])
    r = run_parse("tc", None, llm, use_judge=True, max_retries=3)
    assert r.status == "pass"
    assert r.attempts == 2

def test_escalates_after_max_retries():
    # always fails judge -> generator(+judge) per attempt; 1 + max_retries attempts
    responses = []
    for _ in range(4):
        responses += [GOOD_IR_YAML, FAIL_VERDICT]
    llm = FakeLLM(responses)
    r = run_parse("tc", None, llm, use_judge=True, max_retries=3)
    assert r.status == "escalate"
    assert r.defects == ["dropped a step"]
    assert r.ir is not None      # last IR retained
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.venv/bin/pytest tests/test_loop.py`
Expected: FAIL with `ModuleNotFoundError: No module named 'stage1_parse.loop'`.

- [ ] **Step 3: Write minimal implementation**

```python
# stage1_parse/loop.py
"""Runtime pipeline: generator -> Gate A -> Gate B -> retry/escalate (spec §4-1)."""
from __future__ import annotations
from dataclasses import dataclass, field

from .schema import validate
from .generator import generate_ir
from .judge import judge_ir


@dataclass
class Result:
    status: str                 # "pass" | "escalate"
    ir: dict | None
    attempts: int
    defects: list = field(default_factory=list)


def run_parse(tc_text: str, ticket, llm, use_judge: bool = True, max_retries: int = 3) -> Result:
    feedback = None
    last_ir = None
    defects: list = []
    total_attempts = max_retries + 1
    for attempt in range(1, total_attempts + 1):
        try:
            ir = generate_ir(tc_text, ticket, llm, feedback)
        except Exception as ex:                       # YAML/parse failure
            feedback = f"Output was not a valid YAML IR mapping: {ex}"
            defects = [feedback]
            continue
        last_ir = ir

        errs = validate(ir)                            # Gate A
        if errs:
            feedback = "Schema errors:\n" + "\n".join(errs)
            defects = errs
            continue

        if use_judge:                                  # Gate B
            verdict = judge_ir(tc_text, ir, llm)
            if verdict.get("verdict") != "pass":
                defects = verdict.get("defects", [])
                feedback = "Faithfulness defects:\n" + "\n".join(str(d) for d in defects)
                continue

        return Result("pass", ir, attempt, [])

    return Result("escalate", last_ir, total_attempts, defects)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `.venv/bin/pytest tests/test_loop.py`
Expected: 5 passed.

- [ ] **Step 5: Commit**

```bash
git add stage1_parse/loop.py tests/test_loop.py
git commit -m "feat(stage1): orchestration loop with retry + escalation"
```

---

## Task 7: Golden comparison helper + golden regression (FakeLLM plumbing)

**Files:**
- Create: `tests/compare.py`, `tests/conftest.py`
- Create: `tests/golden/globalline_search.txt`, `tests/golden/globalline_search.yaml`
- Test: `tests/test_golden.py`

- [ ] **Step 1: Write the golden TestCase text**

`tests/golden/globalline_search.txt`:
```
[TestCase] 홈 앱 글로벌 라인 Search 버튼 동작 검증
- Precondition: 홈 앱이 foreground
- Step 1: 글로벌 라인에서 Search 버튼으로 포커스 이동
- Step 2: OK 키 입력
- Expected: com.webos.app.voice 가 search 모드로 launch
```

- [ ] **Step 2: Write the golden IR**

`tests/golden/globalline_search.yaml`:
```yaml
test_case_id: globalline_search_launches_voice
title: "홈 앱 글로벌 라인 Search 버튼 동작 검증"
source_ticket: null
target_app: com.webos.app.home
preconditions:
  - kind: app_lifecycle
    value: resumed
    app: com.webos.app.home
    source_span: "Precondition: 홈 앱이 foreground"
steps:
  - id: 1
    intent: focus_move
    target:
      role: button
      match: { text: "Search", key: null, index: null }
      container: "글로벌 라인"
    source_span: "Step 1: 글로벌 라인에서 Search 버튼으로 포커스 이동"
  - id: 2
    intent: key_press
    key: OK
    source_span: "Step 2: OK 키 입력"
expected:
  - kind: app_launch
    value: "com.webos.app.voice (search 모드)"
    params: null
    source_span: "Expected: com.webos.app.voice 가 search 모드로 launch"
unresolved: []
```

- [ ] **Step 3: Write `tests/compare.py` and `tests/conftest.py`**

`tests/compare.py`:
```python
"""Semantic equivalence for golden comparison: ignore source_span quotes."""
from __future__ import annotations
import copy


def normalize(ir: dict) -> dict:
    def strip(node):
        if isinstance(node, dict):
            return {k: strip(v) for k, v in node.items() if k != "source_span"}
        if isinstance(node, list):
            return [strip(x) for x in node]
        return node
    return strip(copy.deepcopy(ir))


def semantic_equal(a: dict, b: dict) -> bool:
    return normalize(a) == normalize(b)
```

`tests/conftest.py`:
```python
import pathlib
import pytest
import yaml

GOLDEN = pathlib.Path(__file__).parent / "golden"


@pytest.fixture
def globalline_case():
    tc = (GOLDEN / "globalline_search.txt").read_text()
    ir = yaml.safe_load((GOLDEN / "globalline_search.yaml").read_text())
    return tc, ir
```

- [ ] **Step 4: Write the failing test**

```python
# tests/test_golden.py
import yaml
from stage1_parse.loop import run_parse
from stage1_parse.llm import FakeLLM
from tests.compare import semantic_equal, normalize

PASS_VERDICT = '```json\n{"verdict": "pass", "defects": []}\n```'

def test_pipeline_passes_golden_through_gates(globalline_case):
    tc, golden = globalline_case
    gen_response = "```yaml\n" + yaml.safe_dump(golden, allow_unicode=True, sort_keys=False) + "```"
    llm = FakeLLM([gen_response, PASS_VERDICT])
    r = run_parse(tc, None, llm, use_judge=True)
    assert r.status == "pass"
    assert semantic_equal(r.ir, golden)

def test_normalize_ignores_source_span():
    a = {"steps": [{"id": 1, "intent": "key_press", "key": "OK", "source_span": "AAA"}]}
    b = {"steps": [{"id": 1, "intent": "key_press", "key": "OK", "source_span": "BBB"}]}
    assert normalize(a) == normalize(b)
```

- [ ] **Step 5: Run test to verify it fails, then passes**

Run: `.venv/bin/pytest tests/test_golden.py`
Expected: initially FAIL (`No module named 'tests.compare'`) before Step 3 files exist; after all files written, 2 passed.

Note: this exercises the *pipeline plumbing* with a seeded LLM. Measuring whether the *real* generator reproduces the golden is the key-gated eval in Task 9.

- [ ] **Step 6: Commit**

```bash
git add tests/compare.py tests/conftest.py tests/golden tests/test_golden.py
git commit -m "test(stage1): golden corpus + semantic-equal regression (plumbing)"
```

---

## Task 8: CLI entrypoint `parse.py` (= /tas-parse)

**Files:**
- Create: `stage1_parse/report.py` (render Result → text)
- Create: `parse.py`
- Test: `tests/test_report.py`

- [ ] **Step 1: Write the failing test for the report renderer**

```python
# tests/test_report.py
import yaml
from stage1_parse.loop import Result
from stage1_parse.report import render

def test_render_pass_shows_yaml_and_ok():
    ir = {"test_case_id": "x", "title": "T", "steps": []}
    out = render(Result("pass", ir, 1, []))
    assert "PASS" in out
    assert "test_case_id: x" in out          # IR yaml included
    assert yaml.safe_load(out.split("```yaml")[1].split("```")[0])["title"] == "T"

def test_render_escalate_lists_defects():
    out = render(Result("escalate", {"title": "T"}, 4, ["dropped Step 2", "invented widget"]))
    assert "ESCALATE" in out
    assert "dropped Step 2" in out
    assert "invented widget" in out
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.venv/bin/pytest tests/test_report.py`
Expected: FAIL with `ModuleNotFoundError: No module named 'stage1_parse.report'`.

- [ ] **Step 3: Write `stage1_parse/report.py`**

```python
# stage1_parse/report.py
"""Render a run_parse Result into a human-facing report block."""
from __future__ import annotations
import yaml
from .loop import Result


def render(result: Result) -> str:
    lines = [f"# /tas-parse — {result.status.upper()} (attempts: {result.attempts})", ""]
    if result.ir is not None:
        ir_yaml = yaml.safe_dump(result.ir, allow_unicode=True, sort_keys=False)
        lines += ["```yaml", ir_yaml.rstrip(), "```", ""]
    if result.defects:
        lines.append("## Defects (needs human confirmation)")
        lines += [f"- {d}" for d in result.defects]
    if result.ir is not None and result.ir.get("unresolved"):
        lines.append("## Unresolved (ambiguous — not guessed)")
        lines += [f"- {u}" for u in result.ir["unresolved"]]
    return "\n".join(lines)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `.venv/bin/pytest tests/test_report.py`
Expected: 2 passed.

- [ ] **Step 5: Write the CLI `parse.py`**

```python
# parse.py
"""/tas-parse — natural-language TAS TestCase -> validated semantic IR.

Exit codes: 0 = PASS, 1 = ESCALATE (generated but needs human confirmation).
LLM adapter via --llm or $TAS_LLM (default: anthropic). Needs ANTHROPIC_API_KEY for the real adapter.
"""
from __future__ import annotations
import argparse
import sys

from stage1_parse.llm import get_adapter
from stage1_parse.loop import run_parse
from stage1_parse.report import render


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="tas-parse")
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--text", help="TestCase text")
    src.add_argument("--file", help="path to a TestCase text file")
    ap.add_argument("--ticket", default=None, help="Zephyr ticket key, e.g. TVDEVTC-23796")
    ap.add_argument("--no-judge", action="store_true", help="skip Gate B faithfulness judge")
    ap.add_argument("--llm", default=None, help="adapter name (default $TAS_LLM or anthropic)")
    ap.add_argument("--max-retries", type=int, default=3)
    args = ap.parse_args(argv)

    tc_text = args.text if args.text is not None else open(args.file, encoding="utf-8").read()
    llm = get_adapter(args.llm)
    result = run_parse(tc_text, args.ticket, llm,
                       use_judge=not args.no_judge, max_retries=args.max_retries)
    print(render(result))
    return 0 if result.status == "pass" else 1


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 6: Smoke-test the CLI wiring with the fake adapter**

Add to `tests/test_report.py` (CLI integration via fake env):
```python
# append to tests/test_report.py
import os
import parse as cli

def test_cli_no_judge_with_fake(monkeypatch, capsys):
    # FakeLLM from get_adapter("fake") has no responses; inject one via monkeypatch
    from stage1_parse import llm as llm_mod
    from stage1_parse.llm import FakeLLM
    good = ("```yaml\ntest_case_id: x\ntitle: T\nsteps:\n"
            "  - id: 1\n    intent: key_press\n    key: OK\n    source_span: \"s\"\n```")
    monkeypatch.setattr(llm_mod, "get_adapter", lambda name=None: FakeLLM([good]))
    monkeypatch.setattr(cli, "get_adapter", lambda name=None: FakeLLM([good]))
    rc = cli.main(["--text", "Step 1: OK", "--no-judge", "--llm", "fake"])
    out = capsys.readouterr().out
    assert rc == 0
    assert "PASS" in out and "test_case_id: x" in out
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `.venv/bin/pytest tests/test_report.py`
Expected: 3 passed.

- [ ] **Step 8: Commit**

```bash
git add stage1_parse/report.py parse.py tests/test_report.py
git commit -m "feat(stage1): /tas-parse CLI + report renderer"
```

---

## Task 9: Real-LLM evals (key-gated, manual)

**Files:**
- Create: `eval/eval_golden.py`, `eval/eval_judge.py`
- Create: `tests/fixtures/hallucinated_globalline.yaml`

These run the REAL generator/judge and are NOT part of `pytest` (they need `ANTHROPIC_API_KEY`). They are the author's quality gate (spec §4-2 / §7).

- [ ] **Step 1: Write a hallucinated (schema-valid) negative fixture for the judge**

`tests/fixtures/hallucinated_globalline.yaml` — adds a Settings step the TC never mentions:
```yaml
test_case_id: globalline_search_launches_voice
title: "홈 앱 글로벌 라인 Search 버튼 동작 검증"
source_ticket: null
target_app: com.webos.app.home
preconditions:
  - kind: app_lifecycle
    value: resumed
    app: com.webos.app.home
    source_span: "Precondition: 홈 앱이 foreground"
steps:
  - id: 1
    intent: focus_move
    target:
      role: button
      match: { text: "Settings", key: null, index: null }
      container: "글로벌 라인"
    source_span: "Step 1: 글로벌 라인에서 Search 버튼으로 포커스 이동"
  - id: 2
    intent: key_press
    key: OK
    source_span: "Step 2: OK 키 입력"
expected:
  - kind: app_launch
    value: "com.webos.app.voice (search 모드)"
    params: null
    source_span: "Expected: com.webos.app.voice 가 search 모드로 launch"
unresolved: []
```

- [ ] **Step 2: Write `eval/eval_golden.py`**

```python
# eval/eval_golden.py
"""Real-LLM golden regression. Requires ANTHROPIC_API_KEY.
Run: .venv/bin/python -m eval.eval_golden
"""
import pathlib
import sys
import yaml

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from stage1_parse.llm import get_adapter           # noqa: E402
from stage1_parse.loop import run_parse            # noqa: E402
from tests.compare import semantic_equal           # noqa: E402

GOLDEN = pathlib.Path(__file__).resolve().parents[1] / "tests" / "golden"


def main() -> int:
    tc = (GOLDEN / "globalline_search.txt").read_text()
    golden = yaml.safe_load((GOLDEN / "globalline_search.yaml").read_text())
    result = run_parse(tc, None, get_adapter(), use_judge=True)
    ok = result.status == "pass" and semantic_equal(result.ir, golden)
    print("GOLDEN:", "PASS" if ok else "FAIL")
    if not ok:
        print(yaml.safe_dump(result.ir, allow_unicode=True, sort_keys=False))
        print("defects:", result.defects)
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 3: Write `eval/eval_judge.py`**

```python
# eval/eval_judge.py
"""Real-LLM judge negative test: a hallucinated (schema-valid) IR must be REJECTED.
Requires ANTHROPIC_API_KEY. Run: .venv/bin/python -m eval.eval_judge
"""
import pathlib
import sys
import yaml

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from stage1_parse.llm import get_adapter           # noqa: E402
from stage1_parse.judge import judge_ir            # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[1]


def main() -> int:
    tc = (ROOT / "tests" / "golden" / "globalline_search.txt").read_text()
    bad = yaml.safe_load((ROOT / "tests" / "fixtures" / "hallucinated_globalline.yaml").read_text())
    verdict = judge_ir(tc, bad, get_adapter())
    caught = verdict.get("verdict") == "fail"
    print("JUDGE caught hallucination:", "PASS" if caught else "FAIL", "|", verdict.get("defects"))
    return 0 if caught else 1


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Verify evals import cleanly without a key (no network call at import)**

Run: `.venv/bin/python -c "import ast; ast.parse(open('eval/eval_golden.py').read()); ast.parse(open('eval/eval_judge.py').read()); print('syntax ok')"`
Expected: `syntax ok`. (Full runs require `ANTHROPIC_API_KEY`; do not run here.)

- [ ] **Step 5: Commit**

```bash
git add eval tests/fixtures/hallucinated_globalline.yaml
git commit -m "test(stage1): real-LLM golden + judge evals (key-gated)"
```

---

## Task 10: Full suite green + README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Run the whole deterministic suite**

Run: `.venv/bin/pytest`
Expected: all tests pass (Tasks 1–8: schema 10, llm 4, generator 5, judge 4, loop 5, golden 2, report 3). No network, no API key.

- [ ] **Step 2: Write `README.md`**

```markdown
# TAS! Stage ① — /tas-parse

Natural-language webOS Flutter TAS TestCase → validated **semantic IR** (YAML).
Stage ① of the TAS! workflow (① /tas-parse → ② /tas-appgen → ③ /tas-tasgen → ④ /tas-verify).
Design: `docs/superpowers/specs/2026-06-09-tas-stage1-parse-design.md`.

## Install
```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
export ANTHROPIC_API_KEY=...   # for the real LLM adapter
```

## Run
```bash
.venv/bin/python parse.py --text "<TestCase text>" [--ticket TVDEVTC-23796] [--no-judge]
.venv/bin/python parse.py --file my_tc.txt
```
Exit code: `0` PASS, `1` ESCALATE (generated but needs human confirmation).

## Pipeline (shipped runtime)
`generator → Gate A (deterministic schema) → Gate B (LLM faithfulness judge, --no-judge to skip) → retry/escalate`.
The judge needs no answer key; it only checks the IR against the TestCase text.

## Author eval (not shipped)
```bash
.venv/bin/pytest                          # deterministic suite (FakeLLM, no key)
.venv/bin/python -m eval.eval_golden      # real-LLM golden regression (needs key)
.venv/bin/python -m eval.eval_judge       # real-LLM judge catches a hallucination (needs key)
```

## Extending
- New intents/keys/kinds → edit `stage1_parse/schema.py` enum sets + `stage1_parse/generator.py` prompt + `eval/` corpus.
- New golden case → add `tests/golden/<name>.txt` + `<name>.yaml`.
- Swap LLM backend (e.g. Claude Code subagent) → add an adapter in `stage1_parse/llm.py`; nothing else changes.
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs(stage1): README for /tas-parse"
```

---

## Self-Review notes (spec coverage)

- **§2 semantic-only / no app source** → enforced: no module reads app source; schema carries no TypeName. ✓ (Tasks 1, 4)
- **§2 위젯 유추 금지** → generator prompt HARD RULES + `unresolved`; judge faithfulness check. ✓ (Tasks 4, 5)
- **§3 IR schema (match text/key/index, app_lifecycle, key enum, source_span invariant, ascending ids)** → Gate A `validate()`. ✓ (Task 1)
- **§4-1 runtime pipeline Gate A + Gate B(toggle) + retry/escalate** → `run_parse` + `--no-judge`. ✓ (Tasks 6, 8)
- **§4-2 / §7 author-only golden + negative fixture** → `tests/golden`, `tests/fixtures`, `eval/`. ✓ (Tasks 2, 7, 9)
- **§5 error handling (yaml-fail retry, escalate after N, ambiguity→unresolved)** → loop try/except + escalate + `unresolved` surfaced in report. ✓ (Tasks 6, 8)
- **§6 Python core + replaceable adapter, /tas-parse naming, module layout** → `llm.get_adapter`, `parse.py`. ✓ (Tasks 3, 8)
- **부록 A/B grounding (find dims, keyId, lifecycle, intent→primitive)** → enum sets + prompt mirror appendices. ✓ (Tasks 1, 4)
```
