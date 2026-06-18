# TAS! — Zephyr/자연어 TC → TAS 코드 자동화 (Claude Code 스킬)

webOS Flutter 앱의 Zephyr TestCase(또는 자연어 TC)를 받아 App 계측·TAS 스크립트를 만드는
워크플로우. **Claude Code 스킬로 동작한다** — 별도 Python 도구·API 키·디바이스 없이, 각 단계에서
에이전트가 직접 생성하고 모르는 패턴은 지어내지 않고 사람에게 확인한다.

## 4단계 (각 단계 = 슬래시 커맨드)

- **`① /tas-parse`** — 인테이크(app-config 1회 + per-TC packet[Zephyr 키/텍스트 + preconditions])
  → semantic IR(YAML). 앱 비종속. TypeName/property 해석은 ②로 미룬다.
- **`② /tas-appgen`** — ① IR + app-config + **실제 app repo(또는 애매한 부분 직접입력)** → 소스에서
  TypeName/find/property 해소 → `appgen_output`(app meta + widgets contract + resolved bindings).
- **`③ /tas-tasgen`** — ① IR + ② appgen_output → per-TC Python TAS 스크립트(+meta base).
  ②가 다 풀어놨으므로 슬롯 채우기(새 판단 없음).
- **`④ /tas-verify`** — 빌드·디바이스 실행·되돌림. *(미구현)*

## 구조

각 스킬은 자립형이다(`SKILL.md` + `reference/`):
- `.claude/skills/tas-parse/` — `SKILL.md` + `reference/ir-schema.md`(생성 규칙·불변식).
- `.claude/skills/tas-appgen/` — `SKILL.md` + `reference/appgen-schema.md`(출력 스키마·해소 절차).
- `.claude/skills/tas-tasgen/` — `SKILL.md` + `reference/tasgen-mapping.md`(dispatch 표·규칙·예시)
  + `reference/tasbase.py`(생성 스크립트가 호출하는 primitive 라이브러리 = 디바이스의
  `Functional/flutter/_tas/tasbase.py`로 배포되는 산출물).

전역에서 `~/.claude/skills/{tas-parse,tas-tasgen}`이 위로 symlink되어 `/tas-parse`·`/tas-tasgen`으로 동작.

설계 문서(설계 의도·계약·dispatch 표의 권위 출처): `docs/superpowers/specs/`.
