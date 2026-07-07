# menub 위성 앱 통합 작업 정의서

이 문서는 **개인 유틸리티 앱(위성)을 menub 허브에 붙이는 반복 작업**의 표준 절차다.
새 대화에서 "이 앱을 menub에 통합해줘"라고 하면 이 문서를 기준으로 진행한다.
계약 3가지의 보일러플레이트는 `MenubKit` 패키지가 담당하므로, 앱마다 하는 일은 **몇 줄 채우기 + Info.plist 한 줄 + 상태 아이템 게이트**뿐이다.

관련 문서: [menub_허브앱_개발지침.md](menub_허브앱_개발지침.md) §7·§7+·§8, [CLAUDE.md](CLAUDE.md).

---

## 0. 전제

- **비샌드박스**: 위성도 비샌드박스여야 공유 폴더 `~/Library/Application Support/menub/`를 허브와 같은 경로로 본다. 샌드박스면 App Group으로 규약을 옮겨야 함(범위 밖).
- **id 일관성**: 위성 `id`는 매니페스트·invoke·managed.json에서 **전부 동일**. 한 번 정하면 바꾸지 않는다(허브 설정이 id 기준).
- **MenubKit 의존**: 각 위성은 `MenubKit`(이 저장소 `MenubKit/`)을 SPM 의존으로 추가한다.
- **작업 저장소 분리**: 통합은 그 위성 앱의 저장소에서 이뤄진다. 커밋/브랜치/PR은 [CONVENTIONS.md](CONVENTIONS.md)를 따르며, `[[깃 플로우]]`로 정리한다.

---

## 1. 준비물 (앱마다 확인/결정할 것)

새 대화 시작 시 아래를 파악한다(대부분 앱 코드에서 읽어낼 수 있음):

| 항목 | 예 | 비고 |
|---|---|---|
| `id` | `runlet` | 고유·불변 |
| `displayName` | `Runlet` | 표시명 |
| `urlScheme` | `runlet` | Info.plist에 등록할 scheme |
| `bundleIdentifier` | `Bundle.main.bundleIdentifier` | 실행 중 표시용(선택, 권장) |
| `iconRef` | `sf:terminal` | SF Symbol 또는 리소스 경로(선택) |
| **노출할 액션/명령** | 고정 메뉴 항목들, 또는 동적 명령 목록 | 정적/동적 판단 |
| **명령 변경(저장) 지점** | "명령어 관리" 저장/삭제 경로 | 동적일 때 재기록 훅 위치 |
| **상태 아이템 생성 위치** | `NSStatusBar.system.statusItem(...)` 호출부 | 아이콘 숨김 게이트를 감쌀 곳 |

**정적 vs 동적 판단**: 액션이 고정이면 정적, 사용자가 앱 안에서 명령을 추가/삭제하면 동적. 동적이면 §4를 따른다.

---

## 2. MenubKit 의존 추가

Xcode에서 대상 앱 프로젝트에 로컬 패키지로 추가:

- File → Add Package Dependencies → Add Local… → `/Users/seokho/Developer/Menub/MenubKit` 선택 → 앱 타깃에 `MenubKit` 라이브러리 추가.
- 또는 Package.swift 사용 시:
  ```swift
  .package(path: "../Menub/MenubKit")
  // 타깃 dependencies에 "MenubKit"
  ```

> 나중에 위성이 많아지면 MenubKit을 별도 저장소로 분리해 URL 의존으로 바꿀 수 있다(그때 결정).

---

## 3. 계약 적용 — 정적 메뉴 (고정 액션)

```swift
import MenubKit

let menub = MenubSatellite(
    id: "myapp",
    displayName: "My App",
    urlScheme: "myapp",
    bundleIdentifier: Bundle.main.bundleIdentifier,
    iconRef: "sf:bolt"
)

func setUpMenub() {
    // 액션 정의 (invoke는 kit이 파생 → 라우팅과 절대 어긋나지 않음)
    menub.setActions([
        menub.makeAction(id: "open",    title: "창 열기"),
        menub.makeAction(id: "refresh", title: "새로고침", keywords: ["reload"])
    ])
    menub.writeManifest()                        // 계약 1

    // 라우터: 액션 id로 분기
    menub.onInvoke { actionID in                 // 계약 2
        switch actionID {
        case "open":    openMainWindow()
        case "refresh": refresh()
        default:        break
        }
    }
}

// 앱 시작 시
setUpMenub()
if menub.shouldCreateStatusItem() {              // 계약 3
    createMyStatusItem()
}
```

---

## 4. 계약 적용 — 동적 명령 (Runlet 유형)

액션을 **데이터에서 생성**하고, 명령이 바뀔 때마다 **재기록**한다. 허브는 매니페스트 폴더를 감시하므로 재기록만 하면 팝오버·팔레트에 **자동 반영**된다(허브 재시작·코드 수정 불필요).

```swift
import MenubKit

let menub = MenubSatellite(
    id: "runlet", displayName: "Runlet", urlScheme: "runlet",
    bundleIdentifier: Bundle.main.bundleIdentifier, iconRef: "sf:terminal"
)

// ① 현재 명령 목록 → 액션으로 변환 후 재기록. 명령이 바뀔 때마다 호출.
func syncMenub() {
    menub.setActions(commandStore.commands.map { cmd in
        menub.makeAction(id: cmd.id, title: cmd.name, keywords: cmd.tags)
    })
    menub.writeManifest()
}

// ② 제너릭 라우터: 어떤 명령이 와도 id로 실행
menub.onInvoke { commandID in commandStore.run(commandID) }

// 앱 시작 시 + 명령 추가/삭제/수정/순서변경 저장 경로마다 syncMenub() 호출
syncMenub()
if menub.shouldCreateStatusItem() { createMyStatusItem() }
```

**핵심**: `syncMenub()`를 "명령어 관리"의 모든 변경 저장 지점에 한 줄씩 건다. 사용자 설정(enabled/pin/sort)은 위성 id 기준이라 명령이 늘고 줄어도 안 깨진다.

---

## 5. Info.plist — URL scheme 등록 (계약 2의 나머지)

앱 타깃 Info에 추가(빌드 설정 `INFOPLIST_KEY_...`가 아니라 URL Types이므로 Info.plist/Target Info의 URL Types UI 사용):

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string>com.example.myapp</string>
    <key>CFBundleURLSchemes</key>
    <array><string>myapp</string></array>
  </dict>
</array>
```

수신부 연결:

- SwiftUI: `WindowGroup { … }.onOpenURL { menub.route($0) }` (macOS 11+)
- AppKit: `func application(_ app: NSApplication, open urls: [URL]) { urls.forEach { menub.route($0) } }`

---

## 6. 상태 아이템 게이트 (계약 3)

기존 상태 아이템 생성 코드를 조건으로 감싼다:

```swift
// 변경 전
statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

// 변경 후
if menub.shouldCreateStatusItem() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    // …기존 메뉴 구성…
}
```

반영 시점은 **재실행 기준**(§8-2): 허브에서 토글한 뒤 위성을 다시 켜면 아이콘이 숨거나 다시 뜬다. 라이브 반영이 필요하면 위성이 `managed.json`을 파일 감시하도록 확장(선택).

---

## 7. 검증 체크리스트

통합 후 아래를 확인한다:

- [ ] 앱 실행 → menub 설정에 이 위성이 **후보로 뜬다** (계약 1)
- [ ] menub 설정에서 토글 on → 팝오버/팔레트에 **액션이 뜬다**
- [ ] 액션 클릭 / 팔레트 Enter → **실제 기능이 실행된다** (계약 2)
- [ ] 토글 on + 위성 재실행 → 위성이 **자기 아이콘을 숨긴다**, off → 다시 뜬다 (계약 3)
- [ ] (동적) 앱에서 명령 추가 → menub에 **자동으로 액션이 늘어난다** (재기록 감시)
- [ ] `bundleIdentifier` 지정 시 실행 중이면 **초록 점** 표시

빠른 수동 확인:
```
cat ~/Library/Application\ Support/menub/manifests/<id>.json   # 매니페스트 기록 확인
cat ~/Library/Application\ Support/menub/managed.json          # 관리 목록 확인
```

---

## 8. 작업 순서 요약 (새 대화에서 이대로)

1. 준비물(§1) 파악 — 앱 코드에서 id/scheme/bundleId/액션/상태아이템 위치 확인.
2. MenubKit 로컬 패키지 추가(§2).
3. 정적(§3) 또는 동적(§4)으로 `MenubSatellite` 설정 + `writeManifest()` 훅.
4. Info.plist에 scheme 등록 + `onOpenURL`/`open:`에서 `route`(§5).
5. 상태 아이템 생성부를 `shouldCreateStatusItem()`로 게이트(§6).
6. 검증 체크리스트(§7) 통과 확인.
7. 그 앱 저장소에서 `[[깃 플로우]]`로 커밋/PR 정리.

---

## 9. 참고 — MenubKit API 표면

- `MenubSatellite(id:displayName:urlScheme:bundleIdentifier:iconRef:)`
- `makeAction(id:title:keywords:iconRef:) -> MenubAction` — invoke를 `<scheme>://action/<id>`로 파생
- `setActions([MenubAction])` — 동적이면 변경 시마다 재호출
- `writeManifest() -> Bool` — 계약 1
- `onInvoke((String) -> Void)` / `route(URL) -> Bool` — 계약 2
- `isManagedByHub: Bool` / `shouldCreateStatusItem() -> Bool` — 계약 3

스키마는 허브의 `SatelliteManifest`/`ManagedRegistry`와 `MenubKit`이 공유하는 단일 진실원천이다.
