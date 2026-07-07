# CLAUDE.md

이 파일은 이 저장소에서 작업하는 Claude Code를 위한 지침이다.
루트의 세 지침서를 요약한 것이며, 상세 내용은 원문을 따른다:
- [menub_허브앱_개발지침.md](menub_허브앱_개발지침.md) — 제품/아키텍처 기준 문서
- [CONVENTIONS.md](CONVENTIONS.md) — Git(커밋/이슈/브랜치/PR) 규칙
- [claude-단축어-규칙.md](claude-단축어-규칙.md) — `[[단축어]]` 대화 규칙

**언어**: 별도 요청이 없으면 항상 한국어로 답한다.

---

## 프로젝트: menub

여러 개인 유틸리티 앱이 각자 차지하던 메뉴바 아이콘을 **아이콘 1개**로 모으는 macOS 허브 앱. 핵심 그림은 "메뉴바를 팝오버 하나로 접는다".

- **스택**: Swift / SwiftUI (필요 시 AppKit 연동). macOS 앱.
- **통합 모델**: **런처형** — 기존 위성 앱은 유지하고, 허브는 실행/토글/기능 호출만 담당. 위성 앱을 흡수·재작성하지 않는다.
- **메뉴바 점유**: 허브가 상태 아이템 **1개**만 등록. Dock 아이콘 없음(`LSUIElement`).
- **기본 진입 UI**: 팝오버 패널(도구 그리드/리스트, Runlet을 맨 위 핀 고정, 도구→액션 2뎁스).
- **보조 진입 UI**: 전역 단축키로 뜨는 검색 팔레트(전 위성 액션 통합 검색).
- **커스텀(하드 제약)**: 각 도구를 허브에 넣을지 **사용자가 토글**로 정한다. 켜진 위성은 자기 메뉴바 아이콘을 숨기고, 끄면 다시 표시한다.
- **저장소**: 공유 폴더 `~/Library/Application Support/menub/`.
- **샌드박스**: 기본 **비샌드박스**(개인용, 임의 앱 실행·폴더 접근 목적).

### 아키텍처 (뷰 → 코어, 단방향 의존)

- 뷰: `PopoverRootView`, `SettingsView`, `PaletteWindow`(별도 borderless 패널).
- 코어(뷰 비의존): `RegistryStore`(매니페스트 폴더 감시 → 가용 도구의 진실원천), `ConfigStore`(위성별 enabled/pinned/sortIndex·단축키), `Invoker`(URL/앱 실행만, 앱 특정 지식 없음), `RegistrationCoordinator`(허브 관리 플래그 기록), `HotkeyManager`(전역 단축키 → 팔레트 토글).
- **규칙**: 뷰는 Store·Invoker·Coordinator에 의존, 역방향 없음. `RegistryStore`(가용성)와 `ConfigStore`(사용자 선택)를 분리한다. 팝오버 목록 = 가용 도구 ∩ enabled.

### 위성 앱 호환 계약 (3가지)

1. **매니페스트 기록** — 실행 시 `~/Library/Application Support/menub/manifests/<id>.json`에 자기 정보·액션 목록을 최신본으로 기록.
2. **URL scheme 핸들러** — `Info.plist`의 `CFBundleURLTypes`에 scheme 등록 + `onOpenURL`로 수신·실행.
3. **아이콘 숨김 체크** — 실행 시 공유 규약 파일에서 "허브가 관리 중인가"를 확인, 관리 중이면 `NSStatusItem`을 만들지 않는다.

### 비목표

범용 메뉴바 매니저 아님(Ice/Bartender 대체품 아님), 접근성 API로 남의 아이콘 클릭 안 함, 위성 UI를 허브에 임베드하지 않음, 클라우드 동기화·멀티유저·원격제어 범위 밖.

---

## 협업 규칙 (바이브코딩)

- **자율 구현**: 구현을 자율적으로 완성한다. 사용자에게 코드 이해를 요구하지 않는다.
- **보고 형식**: 코드 내부가 아니라 **관찰 가능한 동작** 중심 — (1) 무엇이 되는지, (2) 어떻게 켜서 확인하는지(빌드·실행·클릭/단축키 경로), (3) 어떤 모습인지.
- **마일스톤 단위(M1~M6)**로 실행·검증 가능한 상태에서 끊어 보고. 반쯤 된 것을 넘기지 않는다.
- **확정 명세 보호**: 개발지침 §2 확정 표는 임의 변경 금지. 바꿀 이유가 보이면 트레이드오프와 함께 합의를 먼저 받는다. 위임된 열린 결정은 기본값으로 진행하되 무엇을 왜 골랐는지 보고한다.
- **API 정확성**: 추측한 API/시그니처를 코드·문서에 넣지 않는다. 불확실하면 공식 문서로 확인 후 작성하고, **버전 한정 API는 가용성을 명시**한다(예: `MenuBarExtra`/`.window` macOS 13+, `onOpenURL`·`NSWorkspace.openApplication` macOS 11+).
- **설명 용어**: Swift / SwiftUI / AppKit 용어로만 설명한다. **React/JavaScript 비유·예시 금지.**

---

## 빌드 / 실행

Xcode 프로젝트. 타깃: `Menub`(앱), `MenubTests`(유닛), `MenubUITests`(UI). 스킴: `Menub`. 소스는 `Menub/`.

```
xcodebuild -project Menub.xcodeproj -scheme Menub -configuration Debug build
xcodebuild -project Menub.xcodeproj -scheme Menub test
```

---

## Git 규칙 (CONVENTIONS.md 요약)

- **커밋**: Conventional Commits 기반, 제목·본문 **한국어**. `<타입>: <제목>` (타입: `feat`/`fix`/`docs`/`build`/`chore`/`refactor`). 제목 50자 내외·마침표 없음. `fix`는 본문에 원인을 남긴다. 하나의 커밋에 하나의 관심사.
- **브랜치**: `<타입>/<kebab-case-설명>`, `main`에서 분기, 이슈당 하나, 머지 후 삭제.
- **이슈**: 제목 `[타입] 제목`, 본문은 개요/작업내용(체크박스)/참고.
- **PR**: 제목 `[타입] 제목 (#이슈번호)`, 본문에 `Closes #N`·주요변경·테스트. **PR은 사용자가 GitHub 웹 UI에서 수동 생성**한다(`gh pr create` 사용 금지) — 복붙 가능한 제목·본문을 제공한다. 머지는 Merge commit 방식.

`[[깃 플로우]]` 단축어 호출 시: ① 이슈 발행 ② 터미널 작업(브랜치 생성→관심사별 커밋→푸시) ③ PR 작성 ④ 머지 안내 ⑤ 로컬 브랜치 정리 — 5단계를 순서대로, 각 단계 헤더로 제시한다. 모든 명령 블록은 레포 루트로 `cd`부터 시작하고, 이전 브랜치는 머지된 것으로 간주해 항상 `main`에서 분기한다.
