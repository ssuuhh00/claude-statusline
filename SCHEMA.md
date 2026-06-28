# statusLine JSON 스키마 정리

Claude Code가 statusline 스크립트에 넘겨주는 데이터의 구조와, 이 저장소의
스크립트가 실제로 사용하는 필드를 정리한 문서입니다.

공식 문서: <https://code.claude.com/docs/en/statusline.md>

---

## 1. 데이터를 어떻게 받아오나

- **Claude API 호출이 아니다.** statusline이 새로고침될 때마다 Claude Code가
  하나의 JSON 객체를 스크립트의 **표준입력(stdin)** 으로 흘려보낸다.
- 스크립트는 그 JSON을 읽어서(`input=$(cat)`) 원하는 필드를 뽑아 한 줄짜리
  텍스트를 **표준출력(stdout)** 으로 내보내면, 그게 statusline에 표시된다.
- `settings.json`에서 연결한다:

  ```json
  {
    "statusLine": {
      "type": "command",
      "command": "bash ~/.claude/status-line.sh"
    }
  }
  ```

- 입력 JSON은 보통 **한 줄(compact)** 로 들어온다. (이 저장소 스크립트는
  pretty-print 형태로 들어와도 동작하도록 입력을 한 줄로 평탄화한 뒤 파싱한다.)

### 각 데이터의 출처

| 데이터 | 어디서 오나 |
|--------|-------------|
| 토큰/컨텍스트 수치 (`context_window.*`) | Anthropic API 응답의 `usage` 데이터 |
| 레이트 리밋 (`rate_limits.*`) | API 응답 **헤더**를 Claude Code가 가공해서 채움 |
| 모델·세션·git·비용 등 | Claude Code 로컬 상태 (API 아님) |

> ⚠️ `rate_limits`는 **Claude.ai Pro/Max 구독에서만** 채워진다. API 키 인증이나
> Bedrock/Vertex 같은 서드파티 인증에서는 객체 자체가 없고, **세션 첫 API 응답
> 이후**에야 나타난다.

---

## 2. 스키마 전체 구조

현재 Claude Code가 보내는 JSON의 주요 필드 (버전에 따라 일부 필드는 없을 수 있음):

```json
{
  "cwd": "/current/working/directory",
  "session_id": "unique-session-id",
  "session_name": "optional-custom-name",
  "transcript_path": "/path/to/transcript.jsonl",
  "version": "2.1.x",

  "model": {
    "id": "claude-opus-4-8",
    "display_name": "Opus"
  },

  "workspace": {
    "current_dir": "/current/working/directory",
    "project_dir": "/original/project/directory",
    "added_dirs": [],
    "git_worktree": "feature-xyz",
    "repo": { "host": "github.com", "owner": "anthropics", "name": "claude-code" }
  },

  "cost": {
    "total_cost_usd": 0.01234,
    "total_duration_ms": 45000,
    "total_api_duration_ms": 2300,
    "total_lines_added": 156,
    "total_lines_removed": 23
  },

  "context_window": {
    "total_input_tokens": 15500,
    "total_output_tokens": 1200,
    "context_window_size": 200000,
    "used_percentage": 8,
    "remaining_percentage": 92,
    "current_usage": {
      "input_tokens": 8500,
      "output_tokens": 1200,
      "cache_creation_input_tokens": 5000,
      "cache_read_input_tokens": 2000
    }
  },
  "exceeds_200k_tokens": false,

  "effort": { "level": "high" },
  "thinking": { "enabled": true },

  "rate_limits": {
    "five_hour": { "used_percentage": 23.5, "resets_at": 1738425600 },
    "seven_day": { "used_percentage": 41.2, "resets_at": 1738857600 }
  },

  "vim": { "mode": "NORMAL" },
  "agent": { "name": "security-reviewer" },
  "pr": { "number": 1234, "url": "https://github.com/.../pull/1234", "review_state": "pending" },
  "worktree": {
    "name": "my-feature", "path": "/.../worktrees/my-feature",
    "branch": "worktree-my-feature", "original_cwd": "/path", "original_branch": "main"
  },
  "output_style": { "name": "default" }
}
```

### 필드 그룹 요약

| 그룹 | 대표 필드 | 비고 |
|------|-----------|------|
| 세션/경로 | `cwd`, `session_id`, `session_name`, `transcript_path`, `version` | 로컬 |
| 모델 | `model.id`, `model.display_name` | 로컬 |
| 워크스페이스 | `workspace.current_dir`, `workspace.project_dir`, `workspace.repo`, `workspace.git_worktree` | 로컬/git |
| 비용 | `cost.total_cost_usd`, `cost.total_duration_ms`, `cost.total_lines_added/removed` | 로컬 |
| 컨텍스트 | `context_window.context_window_size`, `context_window.used_percentage`, `context_window.current_usage.*` | API usage |
| 레이트 리밋 | `rate_limits.five_hour.*`, `rate_limits.seven_day.*` | API 헤더, Pro/Max 전용 |
| 기타 상태 | `effort`, `thinking`, `vim`, `agent`, `pr`, `worktree`, `output_style`, `exceeds_200k_tokens` | 조건부 존재 |

---

## 3. 우리가 statusline 구성에 쓰는 필드

이 저장소 스크립트는 위 스키마 중 **아래 7종류**만 사용한다.

| 표시 요소 | 사용하는 필드 |
|-----------|---------------|
| 1행: 프로젝트명 | `cwd` → basename |
| 1행: 모델 | `model.display_name` |
| 1행: 컨텍스트 총량 | `context_window.context_window_size` |
| 1행: 컨텍스트 사용량 | `context_window.current_usage.input_tokens` + `.cache_creation_input_tokens` + `.cache_read_input_tokens` 의 합 |
| 2행: 5시간 리밋 막대 | `rate_limits.five_hour.used_percentage` |
| 2행: 5시간 리셋 시각 | `rate_limits.five_hour.resets_at` (Unix epoch) |
| 3행: 7일 리밋 막대 | `rate_limits.seven_day.used_percentage` |
| 3행: 7일 리셋 시각 | `rate_limits.seven_day.resets_at` (Unix epoch) |

출력 예시:

```
multi-protocol-gateway │ Opus 4.6 │ 55k/200k
                                              ← 빈 줄
current  ━━━─────────  31%  ⟳ 2:00am
weekly   ────────────   2%  ⟳ apr 10, 9:00pm
```

> **참고:** 컨텍스트 사용 % 막대는 직접 `current_usage` 토큰 합을
> `context_window_size`로 나눠 계산한다. 스키마에 이미 계산된
> `context_window.used_percentage`가 있으므로, 원하면 그 값을 바로 써도 된다.

---

## 4. 스키마 변경 이력 (Anthropic 업데이트)

statusLine JSON은 Claude Code 버전이 올라가며 필드가 추가/변경되어 왔다.
우리 스크립트에 영향을 준 변화 위주로 정리.

| 버전(대략 시기) | 변경 | 우리 영향 |
|----------------|------|-----------|
| v2.1.80 (2026-03) | `rate_limits.five_hour` / `seven_day` 신규 추가 | 2·3행 리밋 막대의 데이터 소스 |
| v2.1.132 (2026-05) | `total_input/output_tokens` 의미를 누적→**현재 컨텍스트**로 변경 | 우리는 `current_usage`를 쓰므로 영향 적음 |
| v2.1.152 (2026-05) | `cache_creation_input_tokens` 보고 버그 수정 | 컨텍스트 사용량 정확도 향상 |
| v2.1.157 (2026-05) | `workspace.repo`, `pr` 객체 추가 | 미사용 (활용 가능) |
| (이후) | **`context_window.used_percentage`** 추가 | ⚠️ 아래 주의 참고 |

### ⚠️ `context_window.used_percentage` 추가로 생긴 버그

`jq` 없이 grep으로 파싱하던 구버전(`status-line.sh`)은 `"used_percentage"`를
JSON 전체에서 긁어 **"1번째=5h, 2번째=7d"** 라고 가정했다. 그런데 스키마에
`context_window.used_percentage`가 추가되면서 이 값이 먼저 잡혀 **인덱스가 한
칸씩 밀리고 rate limit이 잘못 표시**되는 버그가 발생했다.

- **수정:** `rate_limits` 객체 부분만 먼저 잘라낸 뒤 그 안에서 `five_hour` /
  `seven_day` 블록을 각각 분리해 값을 읽도록 변경. 이제 `context_window`나 다른
  곳에 `used_percentage`가 더 생겨도 영향받지 않는다. (`statusline-windows.sh` 참고)

> **교훈:** 위치/순서에 의존하는 파싱은 스키마가 바뀌면 깨진다. `jq`를 쓸 수
> 있으면 `.rate_limits.five_hour.used_percentage`처럼 **명시적 경로**로 읽는 게
> 안전하고, grep으로 파싱할 땐 반드시 상위 객체를 먼저 격리해야 한다.
