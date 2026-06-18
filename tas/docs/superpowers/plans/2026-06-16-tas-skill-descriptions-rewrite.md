# TAS Workflow Skill Descriptions Rewrite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the frontmatter `description:` field of all 5 TAS workflow skills so they are easier to understand and include an invocation placeholder (e.g. `/tas {Zephyr TC 키}`) showing what argument to pass.

**Architecture:** Pure documentation edit. Touch ONLY the YAML frontmatter `description:` value in each `SKILL.md`. Do NOT change the skill `name:`, do NOT touch any body prose, reference files, or scripts. Each new description keeps the original trigger semantics (사용 시점 + 선행/다음 단계) so skill auto-selection still works, but rephrases for clarity and appends a `호출:` invocation example with a `{placeholder}` argument.

**Tech Stack:** Markdown files with YAML frontmatter. Verification via Python `yaml.safe_load` (the repo has a `.venv`) and `grep`.

---

## File Structure

Each skill lives in its own directory under `.claude/skills/`. Only the frontmatter line `description: "..."` (line 3 in each) changes.

- Modify: `.claude/skills/tas/SKILL.md:3` — orchestrator (①→②→③→④)
- Modify: `.claude/skills/tas-parse/SKILL.md:3` — stage ① (parse)
- Modify: `.claude/skills/tas-appgen/SKILL.md:3` — stage ② (appgen)
- Modify: `.claude/skills/tas-tasgen/SKILL.md:3` — stage ③ (tasgen)
- Modify: `.claude/skills/tas-verify/SKILL.md:3` — stage ④ (verify)

All paths are relative to the repo root `/home/younginkim/project/2026/ai/skills/tas/`.

### Conventions for every new description
- Language: Korean (matches originals).
- Keep `name:` untouched.
- Structure: `<단계/역할 한 줄> + <사용 시점> + 호출: \`/<skill> {placeholder}\` (예: …) + 선행/다음 단계`.
- The `description:` value stays a single double-quoted YAML string on one line. Inner code spans use backticks; do NOT use raw double quotes inside the value (would break YAML) — use backticks for invocation examples.

---

### Task 1: Rewrite `tas` (orchestrator) description

**Files:**
- Modify: `.claude/skills/tas/SKILL.md:3`

- [ ] **Step 1: Apply the edit**

Replace the existing `description:` line.

Old (exact):
```
description: "TAS! — Zephyr TC(또는 시나리오 텍스트) 하나로 ①파싱→②appgen→③tasgen→④verify 전 단계를 끝까지 자동으로 돌리는 오케스트레이터. 사용 시점: 사용자가 Zephyr 티켓 키(예: TVDEVTC-23796)나 시나리오 텍스트를 주며 'TAS 전체 자동화'를 원할 때. 개별 단계만 돌리려면 /tas-parse·/tas-appgen·/tas-tasgen·/tas-verify를 직접 쓴다."
```

New (exact):
```
description: "TAS 전체 자동화 오케스트레이터 — Zephyr TC 하나로 ①파싱→②appgen→③tasgen→④verify 4단계를 끝까지 자동 실행한다. 사용 시점: 사용자가 Zephyr 티켓이나 시나리오 텍스트를 주며 TAS 테스트를 처음부터 끝까지 자동으로 만들고 검증하길 원할 때. 호출: `/tas {Zephyr TC 키 또는 시나리오 텍스트}` (예: `/tas TVDEVTC-23796`). 한 단계만 돌리려면 /tas-parse·/tas-appgen·/tas-tasgen·/tas-verify를 직접 호출한다."
```

- [ ] **Step 2: Verify the line changed and no stray quotes**

Run: `grep -n '^description:' .claude/skills/tas/SKILL.md`
Expected: prints line 3 with the new text starting `description: "TAS 전체 자동화 오케스트레이터 —` and containing `` 호출: `/tas {Zephyr TC 키 또는 시나리오 텍스트}` ``.

---

### Task 2: Rewrite `tas-parse` (stage ①) description

**Files:**
- Modify: `.claude/skills/tas-parse/SKILL.md:3`

- [ ] **Step 1: Apply the edit**

Old (exact):
```
description: "TAS 자동화 1단계 — Zephyr Test를 받아 구조화된 IR을 생성한다(이후 ②③④의 공통 입력). 사용 시점: TC로 IR 생성을 원할 때. 다음 단계: /tas-appgen(②)→/tas-tasgen(③)→/tas-verify(④)."
```

New (exact):
```
description: "TAS 자동화 1단계(파싱) — Zephyr TC를 받아 구조화된 테스트 명세(IR YAML)를 생성한다. 이 IR이 이후 ②③④ 단계의 공통 입력이 된다. 사용 시점: TC 하나로 IR만 만들고 싶을 때. 호출: `/tas-parse {Zephyr TC 키 또는 시나리오 텍스트}` (예: `/tas-parse TVDEVTC-74461`). 다음 단계: /tas-appgen(②)→/tas-tasgen(③)→/tas-verify(④)."
```

- [ ] **Step 2: Verify**

Run: `grep -n '^description:' .claude/skills/tas-parse/SKILL.md`
Expected: line 3 starts `description: "TAS 자동화 1단계(파싱) —` and contains `` 호출: `/tas-parse {Zephyr TC 키 또는 시나리오 텍스트}` ``.

---

### Task 3: Rewrite `tas-appgen` (stage ②) description

**Files:**
- Modify: `.claude/skills/tas-appgen/SKILL.md:3`

- [ ] **Step 1: Apply the edit**

Old (exact):
```
description: "TAS 자동화 2단계 — ① IR + app-config + 실제 app repo를 받아 소스에서 TypeName/find/property를 해소해 (1) appgen_output(app + widgets contract + resolved bindings)과 (2) app 측 계측 app_test.dart(toStringMap 매퍼)를 만든다. ①이 미룬 구체화를 끝낸다. 선행: /tas-parse(①). 다음: /tas-tasgen(③)."
```

New (exact):
```
description: "TAS 자동화 2단계(appgen) — ①이 만든 IR과 실제 앱 소스코드를 보고 위젯 TypeName·find 방법·property를 코드에서 확정한다. 산출물: (1) 해소된 바인딩이 담긴 appgen 파일, (2) 앱에 계측을 넣은 app_test.dart. 사용 시점: IR을 실제 앱 위젯에 연결하고 싶을 때. 호출: `/tas-appgen {① IR 파일 경로}` (예: `/tas-appgen output/tas-parse/TVDEVTC-74461.ir.yaml`) — 앱 repo 경로는 실행 중 물어본다. 선행: /tas-parse(①). 다음: /tas-tasgen(③)."
```

- [ ] **Step 2: Verify**

Run: `grep -n '^description:' .claude/skills/tas-appgen/SKILL.md`
Expected: line 3 starts `description: "TAS 자동화 2단계(appgen) —` and contains `` 호출: `/tas-appgen {① IR 파일 경로}` ``.

---

### Task 4: Rewrite `tas-tasgen` (stage ③) description

**Files:**
- Modify: `.claude/skills/tas-tasgen/SKILL.md:3`

- [ ] **Step 1: Apply the edit**

Old (exact):
```
description: "TAS 자동화 3단계 — ① IR + ② appgen_output을 받아 IR step마다 Python TAS 스크립트(+단일 meta base)를 작성해 반영할 TAS repo의 Functional/flutter/<appName>/featureBAT/ 에 직접 쓴다. ②가 TypeName/find/property를 다 풀어놨으므로 슬롯 채우기. 선행: /tas-parse(①)→/tas-appgen(②). 다음: /tas-verify(④)."
```

New (exact):
```
description: "TAS 자동화 3단계(tasgen) — ①의 IR과 ②의 appgen 결과를 받아, IR step마다 실행 가능한 Python TAS 스크립트를 작성해 대상 TAS repo(Functional/flutter/<앱이름>/featureBAT/)에 직접 쓴다. ②가 위젯 정보를 다 풀어놨으므로 정해진 틀에 값만 채워 넣는 단계. 사용 시점: IR+appgen을 실제 TAS 스크립트로 만들고 싶을 때. 호출: `/tas-tasgen {① IR 파일 경로} {② appgen 파일 경로}` — TAS repo 경로는 실행 중 물어본다. 선행: /tas-parse(①)→/tas-appgen(②). 다음: /tas-verify(④)."
```

- [ ] **Step 2: Verify**

Run: `grep -n '^description:' .claude/skills/tas-tasgen/SKILL.md`
Expected: line 3 starts `description: "TAS 자동화 3단계(tasgen) —` and contains `` 호출: `/tas-tasgen {① IR 파일 경로} {② appgen 파일 경로}` ``.

---

### Task 5: Rewrite `tas-verify` (stage ④) description

**Files:**
- Modify: `.claude/skills/tas-verify/SKILL.md:3`

- [ ] **Step 1: Apply the edit**

Old (exact):
```
description: "TAS 자동화 4단계 — ③ 산출 per-TC 스크립트를 연결된 TV에 빌드·배포·실행해 검증한다. 기계적 실행은 전부 번들된 결정론 스크립트 tas-verify.sh가 수행(TV 자동탐지·host-key 무력화·조건부 reboot·빌드·libapp.so 배포·qa-test-runner). 스킬은 config 확보→TC 결정→스크립트 1회 실행→판정만. 선행: /tas-tasgen(③)."
```

New (exact):
```
description: "TAS 자동화 4단계(verify) — ③이 만든 per-TC TAS 스크립트를 연결된 TV에 빌드·배포·실행해 PASS/FAIL을 판정한다. TV 자동탐지·빌드·배포·실행 같은 기계적 작업은 번들 스크립트 tas-verify.sh가 결정론적으로 처리하고, 스킬은 config 확보→TC 결정→스크립트 실행→판정만 한다. 사용 시점: 만든 TAS 스크립트를 실제 TV에서 검증하고 싶을 때. 호출: `/tas-verify {③ per-TC 스크립트 경로}` (예: `/tas-verify Functional/flutter/home/featureBAT/home_hero_banner_shown.py`). 선행: /tas-tasgen(③)."
```

- [ ] **Step 2: Verify**

Run: `grep -n '^description:' .claude/skills/tas-verify/SKILL.md`
Expected: line 3 starts `description: "TAS 자동화 4단계(verify) —` and contains `` 호출: `/tas-verify {③ per-TC 스크립트 경로}` ``.

---

### Task 6: Validate all 5 frontmatter blocks still parse as YAML

**Files:**
- Read-only: all 5 `SKILL.md`

- [ ] **Step 1: Parse each frontmatter with PyYAML**

Run:
```bash
cd /home/younginkim/project/2026/ai/skills/tas && .venv/bin/python - <<'PY'
import yaml, glob, sys
ok = True
for f in sorted(glob.glob('.claude/skills/tas*/SKILL.md')):
    txt = open(f, encoding='utf-8').read()
    assert txt.startswith('---'), f
    fm = txt.split('---', 2)[1]
    data = yaml.safe_load(fm)
    has_call = '호출:' in data['description']
    print(f"{f}: name={data['name']} desc_len={len(data['description'])} has_호출={has_call}")
    if not has_call:
        ok = False
sys.exit(0 if ok else 1)
PY
```
Expected: 5 lines printed, each with `has_호출=True`, exit code 0. (If `.venv/bin/python` lacks PyYAML, fall back to `python3 -c "import yaml"`; if PyYAML is unavailable entirely, skip this task and rely on the per-task `grep` checks.)

- [ ] **Step 2: Confirm no skill name was accidentally changed**

Run: `grep -n '^name:' .claude/skills/tas*/SKILL.md`
Expected: exactly 5 lines — `name: tas`, `name: tas-parse`, `name: tas-appgen`, `name: tas-tasgen`, `name: tas-verify`.

---

## Self-Review

**1. Spec coverage:**
- "tas workflow 관련 description 전부 다 이해하기 쉽게 바꿔주고" → Tasks 1–5 rewrite the `description:` of all 5 workflow skills (tas, tas-parse, tas-appgen, tas-tasgen, tas-verify). ✓
- "실제 어떤 필드를 넣어야할지 placeholder 추가 (`/tas {Zephyr TC Ticket}` 식)" → every new description ends with a `호출: \`/<skill> {placeholder}\`` example; Task 6 Step 1 asserts every description contains `호출:`. ✓
- Decided scope (clarified): frontmatter `description:` only, body prose untouched → each task edits only line 3; Architecture note forbids body edits. ✓

**2. Placeholder scan:** The plan itself contains the full final text for every edit (old + new strings verbatim). The `{...}` tokens inside the *new description values* are the intended user-facing argument placeholders, not plan TODOs. No "TBD"/"implement later"/missing-code steps. ✓

**3. Type/string consistency:** `name:` values are never edited (Task 6 Step 2 guards this). Invocation examples use each skill's own name (`/tas`, `/tas-parse`, `/tas-appgen`, `/tas-tasgen`, `/tas-verify`) consistently. Each new description preserves the original 선행/다음 단계 chain. ✓
