# TAS Skill Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fold the battle-tested runtime fixes discovered while verifying TVDEVTC-74461 back into the TAS *skill* artifacts (template + docs + checkers) so future `/tas-tasgen`/`/tas-appgen`/`/tas-verify` runs don't regress.

**Architecture:** The fixes currently live only in the *deployed* copy `automation-tests/.../home_tas_base.py`. The skill template `tas-tasgen/reference/tasbase.py` (from which every base is regenerated) is unchanged, so the bugs would come back on the next regen. This plan ports the primitives into the template, propagates the new contracts they require through the appgen/tasgen docs + schema, and adds a deterministic AST checker for the base — matching this repo's `verification/<skill>/<skill>-check.py` idiom (not pytest).

**Tech Stack:** Python 3.10 (skill checkers, `ast`/`pyyaml`), Markdown (SKILL.md + reference docs), Dart (app_test.dart instrumentation contract — described, not edited here).

## Global Constraints

- `tas-tasgen/reference/tasbase.py` imports `webos.utils.*` and is **NOT importable** off-device → it is validated **by AST only**; checkers must `ast.parse` it, never `import` it.
- Keep the existing LG `@@@LICENSE` header verbatim at the top of every `.py` artifact.
- **Backward compatible:** only *add* primitives / *widen* signatures with defaults. Never rename or change the arity of existing primitives (`find/focus/send_key/tap/wait/get_property/assert_widget_present/assert_any_present/assert_property/assert_app_launch`) — already-generated per-TC scripts call them.
- Plans dir: `docs/superpowers/plans/`. Verification dir: `verification/<skill>/`. Outputs live in `output/<stage>/`.
- Source of truth after this plan = the template `reference/tasbase.py`; the deployed `home_tas_base.py` is a regenerated copy (do not hand-maintain it).
- Ground truth for the on-device behaviors encoded here = this session's verify logs (async launch; per-TC state pollution; lazy-list off-screen tiles; relaunch settle nondeterminism).

---

### Task 1: Establish the tas-tasgen AST checker (test harness)

Creates the deterministic checker this plan's later tasks extend. It only AST-parses `reference/tasbase.py` (never imports it) and asserts the **current** primitive contract, so it passes against today's template — establishing a green baseline before we add new requirements.

**Files:**
- Create: `verification/tas-tasgen/tas-tasgen-check.py`
- Create: `verification/tas-tasgen/results.md`

**Interfaces:**
- Produces: a CLI `tas-tasgen-check.py <tasbase.py>` exiting `0` PASS / `1` FAIL, plus helper `methods_of(tree) -> dict[str, ast.FunctionDef]` and `assert_method(methods, name, errors)` reused by Tasks 2–4.

- [ ] **Step 1: Write the checker with the baseline (currently-true) assertions**

```python
#!/usr/bin/env python3
"""tas-tasgen reference/tasbase.py checker — AST-only (never imports webos.utils.*).

Asserts the generated base exposes the required app-agnostic primitives with
backward-compatible signatures. Logic-coupled behaviors (poll loop, per-TC
reset, scan loop) are asserted structurally in later tasks.

Usage:  tas-tasgen-check.py <path/to/tasbase.py>
Exit:   0 PASS | 1 FAIL
"""
import ast
import sys

REQUIRED_METHODS = [
    "_run", "_check_flutter_service", "find", "focus", "send_key", "tap",
    "wait", "get_property", "assert_widget_present", "assert_any_present",
    "assert_property", "assert_app_launch",
]


def methods_of(tree):
    out = {}
    for node in ast.walk(tree):
        if isinstance(node, ast.ClassDef):
            for item in node.body:
                if isinstance(item, ast.FunctionDef):
                    out[item.name] = item
    return out


def assert_method(methods, name, errors):
    if name not in methods:
        errors.append("missing method: {0}".format(name))
        return None
    return methods[name]


def check(src):
    errors = []
    tree = ast.parse(src)
    methods = methods_of(tree)
    for name in REQUIRED_METHODS:
        assert_method(methods, name, errors)
    return errors


def main():
    if len(sys.argv) != 2:
        sys.stderr.write("usage: tas-tasgen-check.py <tasbase.py>\n")
        return 1
    with open(sys.argv[1]) as f:
        errors = check(f.read())
    if errors:
        for e in errors:
            print("FAIL:", e)
        return 1
    print("PASS: tasbase.py contract ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run it against the current template — expect PASS**

Run: `python3 verification/tas-tasgen/tas-tasgen-check.py .claude/skills/tas-tasgen/reference/tasbase.py`
Expected: `PASS: tasbase.py contract ok` (exit 0). Baseline is green.

- [ ] **Step 3: Seed results.md**

```markdown
# tas-tasgen 검증 결과 (verification/tas-tasgen/)

`reference/tasbase.py`는 device 전용(webos.utils.*) → **AST로만** 검증한다.
ground truth = 이 plan(2026-06-17-tas-skill-hardening)이 명시한 primitive 계약.

| 날짜 | tasbase.py 리비전 | 판정 | 비고 |
|---|---|---|---|
| 2026-06-17 | baseline | PASS | 필수 primitive 존재 확인 |
```

- [ ] **Step 4: Commit**

```bash
git add verification/tas-tasgen/tas-tasgen-check.py verification/tas-tasgen/results.md
git commit -m "test(tas-tasgen): add AST checker for tasbase primitive contract"
```

---

### Task 2: Poll for async app launch in `assert_app_launch`

**Why (ground truth):** `home_04` launched `com.webos.app.mediadiscovery` correctly, but `assert_app_launch` read the foreground *immediately* after `OK` — before the app finished launching — and saw `com.webos.app.home`, so it failed; ~3 s later the app was foreground. App launch is async; the assertion must poll.

**Files:**
- Modify: `verification/tas-tasgen/tas-tasgen-check.py`
- Modify: `.claude/skills/tas-tasgen/reference/tasbase.py:154-156`

**Interfaces:**
- Consumes: `methods_of`, `assert_method` (Task 1).
- Produces: `assert_app_launch(self, appId, retries=20, interval=0.5)` that loops.

- [ ] **Step 1: Add the failing assertion to the checker**

Append inside `check()` (after the `REQUIRED_METHODS` loop):

```python
    m = methods.get("assert_app_launch")
    if m is not None:
        has_loop = any(isinstance(n, (ast.For, ast.While)) for n in ast.walk(m))
        argnames = [a.arg for a in m.args.args]
        if not has_loop:
            errors.append("assert_app_launch must poll (no loop found)")
        if "retries" not in argnames or "interval" not in argnames:
            errors.append("assert_app_launch must accept retries/interval")
```

- [ ] **Step 2: Run checker — expect FAIL**

Run: `python3 verification/tas-tasgen/tas-tasgen-check.py .claude/skills/tas-tasgen/reference/tasbase.py`
Expected: FAIL with `assert_app_launch must poll (no loop found)` and `...retries/interval` (exit 1).

- [ ] **Step 3: Implement polling in the template**

Replace `reference/tasbase.py` lines 154-156 with:

```python
    def assert_app_launch(self, appId, retries=20, interval=0.5):
        """앱 실행은 비동기 — foreground가 appId가 될 때까지 최대 retries*interval 폴링."""
        fg = None
        for _ in range(retries):
            fg = self._sam.getForegroundAppInfo().get("appId")
            if fg == appId:
                return
            wait_for_time(interval)
        self.assertEqual(appId, fg, "ERROR: {0} not foreground (actual={1})".format(appId, fg))
```

- [ ] **Step 4: Run checker — expect PASS**

Run: `python3 verification/tas-tasgen/tas-tasgen-check.py .claude/skills/tas-tasgen/reference/tasbase.py`
Expected: `PASS: tasbase.py contract ok` (exit 0).

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/tas-tasgen/reference/tasbase.py verification/tas-tasgen/tas-tasgen-check.py
git commit -m "fix(tas-tasgen): poll foreground in assert_app_launch (async launch)"
```

---

### Task 3: Per-TC state reset in `_run`

**Why (ground truth):** `home_04` launched another app and left it foreground; `home_05` then started with the *wrong* app foreground (no clean home) and did nothing — `expected …, got mediadiscovery`. Per-TC scripts assume the home app at its initial screen, but nothing resets it between TCs. Re-running `home` (SAM) before each flutter test + a settle delay restores a deterministic start. (Settle of 3 s proved too short under repeated relaunch; use 7 s + 2 s post-service.)

**Files:**
- Modify: `verification/tas-tasgen/tas-tasgen-check.py`
- Modify: `.claude/skills/tas-tasgen/reference/tasbase.py:60-64` (the flutter branch of `_run`)

**Interfaces:**
- Consumes: `methods_of` (Task 1).
- Produces: `_run` calls `self._sam.launch(self.SAM_APP_ID)` before `self.run_flutter_test()`.

- [ ] **Step 1: Add the failing assertion to the checker**

Append inside `check()`:

```python
    r = methods.get("_run")
    if r is not None:
        srcseg = ast.get_source_segment(src, r) or ""
        launches = "self._sam.launch(self.SAM_APP_ID)" in srcseg
        idx_reset = srcseg.find("self._sam.launch(self.SAM_APP_ID)")
        idx_runft = srcseg.find("self.run_flutter_test()")
        if not launches:
            errors.append("_run must relaunch SAM_APP_ID for per-TC reset")
        elif idx_runft != -1 and not (0 <= idx_reset < idx_runft):
            errors.append("_run must reset home BEFORE run_flutter_test()")
```

- [ ] **Step 2: Run checker — expect FAIL**

Run: `python3 verification/tas-tasgen/tas-tasgen-check.py .claude/skills/tas-tasgen/reference/tasbase.py`
Expected: FAIL with `_run must relaunch SAM_APP_ID for per-TC reset` (exit 1).
(`_check_flutter_service` calls `self._sam.launch(self.SAM_APP_ID)` too, but only inside its own method body — `ast.get_source_segment(_run)` does not include it.)

- [ ] **Step 3: Implement the reset in the template**

Replace `reference/tasbase.py` lines 60-64 with:

```python
            if type(self).run_flutter_test is not __class__.run_flutter_test:
                self._flutter = Flutter(cmd=self._cmd)
                self._flutter.checkTestEnviroment(filename=self.FLAG_FILE)
                # TC 독립성: 직전 TC가 다른 앱을 띄웠을 수 있으므로 매 TC 시작 시
                # 홈을 다시 foreground(초기화면)로 올린 뒤 서비스 확인.
                # 셸프 렌더/포커스 정착까지 충분히 대기(짧으면 네비게이션이 비결정적).
                self._sam.launch(self.SAM_APP_ID)
                wait_for_time(7)
                self._check_flutter_service()
                wait_for_time(2)
                self.run_flutter_test()
```

- [ ] **Step 4: Run checker — expect PASS**

Run: `python3 verification/tas-tasgen/tas-tasgen-check.py .claude/skills/tas-tasgen/reference/tasbase.py`
Expected: `PASS: tasbase.py contract ok` (exit 0).

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/tas-tasgen/reference/tasbase.py verification/tas-tasgen/tas-tasgen-check.py
git commit -m "fix(tas-tasgen): relaunch+settle home per TC for state isolation"
```

---

### Task 4: `focus_scan` primitive for lazy horizontal lists

**Why (ground truth):** App List is a lazy `EHorizontalList` — off-screen tiles aren't in the widget tree, so `findByKey('com.webos.app.mediadiscovery')` can't reach them and `OK` does nothing. We need D-pad scanning: press RIGHT, re-read `getProperty`, stop when the target tile is **actually focused** (`isFocused`), with a render-then-`setFocus` fallback when `isFocused` isn't instrumented.

**Files:**
- Modify: `verification/tas-tasgen/tas-tasgen-check.py`
- Modify: `.claude/skills/tas-tasgen/reference/tasbase.py` (add method after `focus`, ~line 93)

**Interfaces:**
- Consumes: `find`, `get_property`, `focus`, `self._input`, `_KEYNAME`, `wait_for_time`.
- Produces: `focus_scan(self, typeName, key, direction='RIGHT', id_key='id', focus_key='isFocused', max_steps=40, settle=0.5) -> True`. Item widgets it scans must expose `id_key` (and ideally `focus_key`) via getProperty — enforced in Task 5.

- [ ] **Step 1: Add the failing assertion to the checker**

Add `"focus_scan"` is **not** in `REQUIRED_METHODS` (optional primitive); instead append a structural check inside `check()`:

```python
    fs = methods.get("focus_scan")
    if fs is None:
        errors.append("missing method: focus_scan (lazy-list scan primitive)")
    else:
        names = [a.arg for a in fs.args.args]
        for need in ("typeName", "key", "direction", "id_key"):
            if need not in names:
                errors.append("focus_scan must accept {0}".format(need))
        if not any(isinstance(n, ast.For) for n in ast.walk(fs)):
            errors.append("focus_scan must loop (scan steps)")
        seg = ast.get_source_segment(src, fs) or ""
        if "press_key" not in seg:
            errors.append("focus_scan must press a direction key per step")
```

- [ ] **Step 2: Run checker — expect FAIL**

Run: `python3 verification/tas-tasgen/tas-tasgen-check.py .claude/skills/tas-tasgen/reference/tasbase.py`
Expected: FAIL with `missing method: focus_scan ...` (exit 1).

- [ ] **Step 3: Implement `focus_scan` in the template**

Insert after the `focus` method (after line 93):

```python
    def focus_scan(self, typeName, key, direction='RIGHT', id_key='id',
                   focus_key='isFocused', max_steps=40, settle=0.5):
        """lazy 가로 리스트에서 D-pad로 이동하며 대상 타일을 '실제 포커스'로 만든다.
        매 스텝 typeName 위젯들의 getProperty를 읽어 (a) 대상이 이미 focus면 종료,
        (b) isFocused 미계측이면 '렌더되면 setFocus' 폴백, (c) 아니면 방향키 1회.
        off-screen 타일은 트리에 없으므로 직접 findByKey 대신 스캔이 필요하다."""
        for _ in range(max_steps):
            self.find(typeName)
            results = self.get_property()
            if any(r.get(id_key) == key
                   and str(r.get(focus_key)).lower() == 'true' for r in results):
                return True
            rendered = any(r.get(id_key) == key for r in results)
            has_focus_prop = any(focus_key in r for r in results)
            if rendered and not has_focus_prop:
                self.focus(typeName, by_key=key)   # 폴백(덜 견고: 렌더=포커스 가정)
                return True
            self._input.press_key(_KEYNAME[direction])
            wait_for_time(settle)
        self.assertTrue(False, "ERROR: focus_scan {0}.{1}={2} not focusable in {3} {4} steps".format(
            typeName, id_key, key, max_steps, direction))
```

- [ ] **Step 4: Run checker — expect PASS**

Run: `python3 verification/tas-tasgen/tas-tasgen-check.py .claude/skills/tas-tasgen/reference/tasbase.py`
Expected: `PASS: tasbase.py contract ok` (exit 0).

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/tas-tasgen/reference/tasbase.py verification/tas-tasgen/tas-tasgen-check.py
git commit -m "feat(tas-tasgen): add focus_scan primitive for lazy horizontal lists"
```

---

### Task 5: Teach appgen + tasgen the scan contract

**Why:** `focus_scan` only exists if (a) appgen emits a binding that *requests* a scan, and (b) the scanned widget exposes `id` (+`isFocused`) via toStringMap, and (c) tasgen's dispatch table maps that binding to `self.focus_scan(...)`. Without this, authors will keep emitting plain `focus(..., by_key=...)` that silently fails on long lists.

**Files:**
- Modify: `.claude/skills/tas-appgen/reference/appgen-schema.md`
- Modify: `.claude/skills/tas-tasgen/reference/tasgen-mapping.md`
- Modify: `verification/tas-appgen/tas-appgen-check.py`

**Interfaces:**
- Consumes: appgen `find` object (Task is doc/contract only).
- Produces: optional `find.scan: true` + `find.scroll_dir: RIGHT|DOWN` (default RIGHT) on a `focus_move`/`tap` binding; when present, the binding's `typeName` must list `id` (and `isFocused`) in `widgets[typeName]`.

- [ ] **Step 1: Add a failing assertion to the appgen checker**

In `verification/tas-appgen/tas-appgen-check.py`, inside the per-binding `refs` checks, add: when a binding's `find` has `scan` truthy, the `typeName`'s widget property list must contain `id` and `isFocused`.

```python
            find = b.get("find") or {}
            if find.get("scan"):
                props = (ag.get("widgets") or {}).get(b.get("typeName"), [])
                for need in ("id", "isFocused"):
                    if need not in props:
                        errors.append(
                            "scan binding {0} needs widgets[{1}] to expose {2}".format(
                                (b.get("step_id"), b.get("action_id")), b.get("typeName"), need))
```

- [ ] **Step 2: Run the appgen checker against a hand-made scan fixture — expect FAIL**

Run: create `output/tas-appgen/_scanfix.appgen.yaml` with a `find:{scan:true}` binding whose `widgets` omits `isFocused`, then
`python3 verification/tas-appgen/tas-appgen-check.py output/tas-appgen/_scanfix.appgen.yaml output/tas-parse/TVDEVTC-74461.ir.yaml`
Expected: FAIL listing `scan binding ... needs widgets[...] to expose isFocused`.

- [ ] **Step 3: Document `find.scan` in appgen-schema.md**

In `appgen-schema.md`, under the `bindings` block, add after the target-action line:

```markdown
  # ── lazy 리스트(가로/세로) 안의 아이템을 키로 선택할 때 ──
  #    find.scan: true → ③이 self.focus_scan(typeName, value, scroll_dir)로 생성.
  #    off-screen 타일은 트리에 없어 byKey 직접 포커스가 실패하므로 D-pad 스캔.
  #    이때 widgets[typeName] 는 반드시 id 와 isFocused 를 노출해야 한다(매퍼에 추가).
  - { step_id, action_id, typeName, find: { method: byKey, value: <model.id>, scan: true, scroll_dir: RIGHT } }
```

And in the app_test.dart guidance, note: "스캔 대상 아이템 위젯은 `properties['id'] = w.<idField>;` 와 `properties['isFocused'] = w.<isFocusedField>;` 를 둘 다 노출한다(D-pad 스캔이 실제 포커스를 확인)."

- [ ] **Step 4: Document the dispatch in tasgen-mapping.md**

In the dispatch table of `tasgen-mapping.md`, change the `focus_move` row and add a note:

```markdown
| action `focus_move` (find.scan 없음) | typeName + find | `self.focus('<typeName>', by_key='<v>')` (byText→`by_text=`, byTypeName→typeName만, index→`index=`) |
| action `focus_move`/`tap` (find.scan: true) | typeName + find(value, scroll_dir) | `self.focus_scan('<typeName>', '<value>', '<scroll_dir, 기본 RIGHT>')` |
```

Add to the **규칙** list: "lazy 리스트 아이템 선택(find.scan)은 `focus_scan`을 쓴다 — 직접 `focus(by_key=)`는 off-screen에서 실패. 상태 격리(매 TC 홈 relaunch)는 base가 보장하므로 step 스크립트에서 재현하지 않는다."

- [ ] **Step 5: Re-run the appgen checker against a *correct* scan fixture — expect PASS, then delete fixture**

Run: fix `_scanfix.appgen.yaml` so `widgets` exposes `id` + `isFocused`, re-run the command from Step 2.
Expected: PASS (or ESCALATE only for unrelated coverage). Then `rm output/tas-appgen/_scanfix.appgen.yaml`.

- [ ] **Step 6: Commit**

```bash
git add .claude/skills/tas-appgen/reference/appgen-schema.md .claude/skills/tas-tasgen/reference/tasgen-mapping.md verification/tas-appgen/tas-appgen-check.py
git commit -m "feat(tas): define find.scan contract (appgen schema + tasgen dispatch + checker)"
```

---

### Task 6: Make instrumentation activation mandatory in appgen

**Why (ground truth):** The first verify wiped out steps 1–3 because `app_test.dart` had every mapper commented and **no `toStringMap`** wired — `getProperty` returned empty, so every `widget_visible` failed. `tas-appgen-check.py` already has an `instrument` check but it's *optional*. Make it required whenever bindings exist, and make the appgen SKILL.md state it explicitly.

**Files:**
- Modify: `verification/tas-appgen/tas-appgen-check.py`
- Modify: `.claude/skills/tas-appgen/SKILL.md`

**Interfaces:**
- Consumes: existing `instrument` check + `app_test.dart` path arg.
- Produces: `instrument` violations become FAIL (exit 1) when `app_test.dart` is supplied and `bindings` is non-empty.

- [ ] **Step 1: Tighten the checker**

In `tas-appgen-check.py`, where the optional `instrument` result is computed, when an `app_test.dart` path is given and `ag["bindings"]` is non-empty, append any missing-mapper / missing-`toStringMap` findings to `errors` (FAIL) instead of a soft/optional list. Concretely, ensure the code path that detects "TypeName not registered in printProperties" and "`toStringMap:` absent in `testWebosApplication(`" pushes to `errors`.

- [ ] **Step 2: Run against the known-good instrumented file — expect PASS**

Run: `python3 verification/tas-appgen/tas-appgen-check.py output/tas-appgen/TVDEVTC-74461.appgen.yaml output/tas-parse/TVDEVTC-74461.ir.yaml /home/younginkim/project/app/qml/com.webos.app.home_qml/integration_test/app_test.dart`
Expected: PASS (the file now wires `toStringMap`). If it FAILs, the checker change is too strict — narrow it to the two specific signals above.

- [ ] **Step 3: Make the requirement explicit in appgen SKILL.md**

In `tas-appgen/SKILL.md` step 5, add a sentence: "**toStringMap 미배선 = 전 위젯 getProperty 공백 → 모든 widget_visible FAIL.** 매퍼를 주석으로 두지 말고 `testWebosApplication(..., toStringMap: printProperties)` 인자를 반드시 활성화한다. (`tas-appgen-check.py`가 app_test.dart 경로를 받으면 이를 강제한다.)"

- [ ] **Step 4: Commit**

```bash
git add verification/tas-appgen/tas-appgen-check.py .claude/skills/tas-appgen/SKILL.md
git commit -m "fix(tas-appgen): require active toStringMap instrumentation"
```

---

### Task 7: Document verify caveats — state, flakiness, empirical feedback

**Why (ground truth):** Three reusable lessons emerged at ④ that aren't written down: (1) `--exec-only` is unreliable for state-mutating TCs unless the base resets state (now it does — Task 3); (2) launch/navigation TCs can be flaky and a single FAIL right after a passing run is a state/timing signal, not necessarily a binding bug; (3) when `assert_app_launch` fails with a *consistent* `actual=<X>`, that observed foreground is the empirical correction to feed back to ② (e.g., "recommend first tile actually launches `com.webos.app.livetv`").

**Files:**
- Modify: `.claude/skills/tas-verify/SKILL.md`

**Interfaces:** Docs only.

- [ ] **Step 1: Add a "상태·플래키·피드백" subsection to tas-verify SKILL.md**

Under section 4 (판정), add:

```markdown
### 상태·플래키·피드백 (launch/navigation TC)
- **상태 격리:** base(③ tasbase)가 매 TC 시작 시 홈을 relaunch+정착시킨다. 따라서
  app을 띄우는 TC도 독립 실행된다. **`--exec-only`는 app/app_test.dart가 그대로일 때만** 쓰고,
  앱·계측이 바뀌면 전체(A~D)로 재배포한다(스크립트만 바뀌면 exec-only 가능).
- **플래키 판별:** 동일 스크립트가 직전엔 PASS인데 이번엔 `got <SAM_APP_ID>`(=무동작)면
  바인딩 오류가 아니라 **relaunch 정착/포커스 타이밍** 신호다. 해당 TC만 1회 재실행해 재현 여부 확인.
- **경험적 피드백 → ②:** `assert_app_launch` 실패가 매번 동일한 `actual=<X>`면, 그 X가 그 동선의
  실제 실행 앱이다. ②(appgen)의 expected appId를 X로 정정(예: recommend 첫 타일 → `com.webos.app.livetv`).
  화면 단언 실패가 전 위젯에서 나면 계측(toStringMap) 문제이므로 ②로 되돌린다.
```

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/tas-verify/SKILL.md
git commit -m "docs(tas-verify): document state isolation, flakiness, empirical feedback"
```

---

## Self-Review

**Spec coverage** (lessons → tasks):
- Async launch → Task 2. ✓
- TC state pollution → Task 3 (base) + Task 7 (doc). ✓
- Lazy-list off-screen tiles → Task 4 (primitive) + Task 5 (contract/dispatch). ✓
- Relaunch settle nondeterminism → Task 3 (7s/2s settle) + Task 7 (flaky guidance). ✓
- Instrumentation inactive (commented toStringMap) → Task 6. ✓
- Empirical foreground correction (mediadiscovery vs discovery; livetv) → Task 7. ✓
- Regression risk (fixes only in deployed copy) → Tasks 2–4 port to template; Task 1 guards via checker. ✓

**Placeholder scan:** All code/edits are concrete (real AST checks, real method bodies, exact line ranges, exact commands). No TBD/"handle edge cases". ✓

**Type/name consistency:** `methods_of`/`assert_method` defined in Task 1, reused in 2–4. `focus_scan` signature identical in Task 4 (impl), Task 5 (dispatch/contract). `find.scan`/`scroll_dir` names identical across appgen-schema, tasgen-mapping, appgen-check. `assert_app_launch(appId, retries, interval)` consistent. ✓

**Known residual risk (not silently dropped):** Task 3's fixed 7 s settle is empirical, not proven sufficient under all loads; Task 4's `setFocus` fallback assumes render≈focus when `isFocused` is absent. Both are called out in-task; if navigation remains flaky after this plan, the next iteration is `isFocused`-everywhere + a launch-retry gate in `tas-verify.sh` (out of scope here).
