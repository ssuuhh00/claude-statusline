# claude-statusline

레이트 리밋 진행 막대와 리셋 시각을 보여주는 Claude Code 커스텀 statusline 스크립트.

## 미리보기

```
multi-protocol-gateway │ Opus 4.6 │ 74k/1000k

current  ━━━─────────  31%  ⟳ 2:00am
weekly   ────────────   2%  ⟳ apr 10, 9:00pm
```

- 1행: 프로젝트명 │ 모델 │ 컨텍스트 토큰 (사용량/총량, 둘 다 `k` 표기)
- 2행: 5시간 레이트 리밋 막대 + 리셋 시각
- 3행: 7일 레이트 리밋 막대 + 리셋 시각
- 사용률에 따른 색상: 초록 → 주황 → 노랑 → 빨강

## 버전

| 파일 | 플랫폼 | JSON 파서 | 요구사항 |
|------|--------|-----------|----------|
| `statusline-mac.sh`     | macOS         | `jq`             | `brew install jq` (BSD `date`·`bash`는 기본 내장) |
| `statusline-ubuntu.sh`  | Ubuntu 24.04  | `jq`             | `sudo apt install jq` (bash·GNU `date`는 기본 내장) |
| `statusline-windows.sh` | Windows       | grep/sed (jq 불필요) | Git Bash 또는 MSYS2 (`bash` 4+, GNU `date` — 둘 다 기본 포함) |

두 버전의 출력은 동일하다. Windows 버전은 `jq` 의존성을 없애고
(Git Bash에는 보통 `jq`가 없음) `grep`/`sed`로 JSON을 파싱한다.

## 설치

### macOS

```bash
brew install jq                              # 기본 미설치
cp statusline-mac.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

### Ubuntu 24.04

```bash
sudo apt install -y jq                       # 기본 미설치
cp statusline-ubuntu.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

### Windows (Git Bash / MSYS2)

```bash
cp statusline-windows.sh ~/.claude/status-line.sh
```

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/status-line.sh"
  }
}
```

## 동작 원리 — statusLine JSON

Claude Code는 새로고침할 때마다 스크립트의 **표준입력(stdin)** 으로 JSON 객체를
흘려보낸다 (이것은 별도의 Claude API 호출이 아니라 Claude Code 로컬 데이터다).
스크립트는 아래 필드를 읽어 statusline을 구성한다. 공식 문서:
<https://code.claude.com/docs/en/statusline.md>

| 필드 경로 | 용도 |
|-----------|------|
| `model.display_name` | 모델 이름 |
| `cwd` | 프로젝트명 (basename) |
| `context_window.context_window_size` | 컨텍스트 총량 |
| `context_window.current_usage.{input_tokens,cache_creation_input_tokens,cache_read_input_tokens}` | 컨텍스트 사용량 |
| `rate_limits.five_hour.{used_percentage,resets_at}` | 5시간 막대 |
| `rate_limits.seven_day.{used_percentage,resets_at}` | 7일 막대 |

데이터 출처: 컨텍스트/토큰 수치는 Anthropic API의 `usage` 데이터에서 오고,
`rate_limits.*`는 Claude Code가 API 레이트 리밋 응답 헤더로부터 만들어낸다
(**Claude.ai Pro/Max 전용** — API 키나 Bedrock/Vertex 인증에서는 없으며, 세션 첫
API 응답 이후에만 나타남). 세션/git 관련 필드는 로컬에서 채워진다.

스키마 전체 구조와 필드 매핑은 [SCHEMA.md](SCHEMA.md) 참고.

### 스키마 변경 주의 (no-jq 버전 관련 중요)

Claude Code가 나중에 **`context_window.used_percentage`** 필드를 추가했다.
Windows 버전은 `used_percentage`를 읽기 **전에** `rate_limits` 객체를 먼저
격리하므로, 이 추가 필드를 레이트 리밋 값으로 오인하지 않는다. "모든
`used_percentage`를 긁어오는" 단순한 방식은 현재 스키마에서 막대를 잘못 매핑하므로
피해야 한다.

## 요구사항

- `bash` 4+
- macOS/Linux: `jq` + GNU `date`
- Windows: Git Bash 또는 MSYS2 (추가 설치 불필요)
- 레이트 리밋 데이터를 보려면 Claude.ai Pro/Max 구독이 있는 Claude Code
