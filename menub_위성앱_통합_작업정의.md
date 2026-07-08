# menub 위성 앱 통합 작업 정의서

이 문서는 **개인 유틸리티 앱(위성)을 menub 허브에 붙이는 반복 작업**의 표준 절차다.
새 대화에서 "이 앱을 menub에 통합해줘"라고 하면 이 문서를 기준으로 진행한다.
계약 3가지의 보일러플레이트는 `MenubKit`가 담당하므로, 앱마다 하는 일은 **몇 줄 채우기 + Info.plist + 상태 아이템 게이트**뿐이다.

> 실전 검증됨: Runlet(동적·Xcode), MacKey(정적·SPM), KeyFlow(동적·Xcode) 3앱 통합. 이 문서의 레시피와 §10 함정은 그 작업에서 나온 것이다.

관련 문서: [menub_허브앱_개발지침.md](menub_허브앱_개발지침.md) §7·§7+·§8, [CLAUDE.md](CLAUDE.md).

---

## 0. 전제

- **비샌드박스**: 위성도 비샌드박스여야 공유 폴더 `~/Library/Application Support/menub/`를 허브와 같은 경로로 본다. 샌드박스면 App Group으로 규약을 옮겨야 함(범위 밖).
- **id 일관성**: 위성 `id`는 매니페스트·invoke·managed.json에서 **전부 동일**. 한 번 정하면 바꾸지 않는다(허브 설정이 id 기준).
- **매 실행마다 매니페스트 기록**: `writeManifest()`는 최초 1회가 아니라 **앱이 실행될 때마다** 최신본으로 덮어쓴다. 허브에서 도구를 **삭제(일회성 제거)해도, 그 앱을 다시 실행하면 스스로 재등록**된다. (한 번만 쓰면 이 재등록이 깨진다)
- **작업 저장소 분리**: 통합은 그 위성 앱의 저장소에서 이뤄진다. 커밋/PR은 [CONVENTIONS.md](CONVENTIONS.md)를 따르며 `[[깃 플로우]]`로 정리한다.

---

## 1. 준비물 (앱마다 먼저 파악)

앱 코드에서 아래를 읽어낸다. **특히 굵은 3개는 통합 방식을 좌우하므로 먼저 확인**한다.

| 항목 | 예 | 비고 |
|---|---|---|
| **프로젝트 유형** | Xcode(.xcodeproj) / SPM(Package.swift) | §2에서 통합 방식 갈림 |
| **앱 진입 구조** | SwiftUI `App` / AppKit `NSApplication`+delegate | 런치 훅 위치(§4) |
| **정적 vs 동적** | 고정 메뉴 / 사용자가 추가·삭제하는 목록 | §5(정적) 또는 §6(동적) |
| `id` / `displayName` / `urlScheme` | `runlet` / `Runlet` / `runlet` | 고유·불변 |
| `bundleIdentifier` | `Bundle.main.bundleIdentifier` | 실행 표시용(권장). **주의**: 번들로 실행해야 채워짐(§10) |
| `iconRef` | `sf:terminal` | SF Symbol(선택) |
| **상태 아이템 생성 위치** | `MenuBarExtra{}` 또는 `NSStatusBar…statusItem(...)` | 게이트를 걸 곳(§8) |
| 노출할 액션 | 명령/매크로 목록, 또는 "설정 열기" 등 | 정적/동적 |
| (동적) 목록 변경 지점 | store의 `@Published`/`@Observable` | 재기록 훅(§6) |
| 포커스 민감 여부 | 키 입력을 **다른 앱에 주입**하나? | 맞으면 §10 포커스 항목 |

---

## 2. 통합 방식 결정 (프로젝트 유형별)

| | MenubKit 붙이기 | URL scheme 등록 |
|---|---|---|
| **SPM 앱** (Package.swift) | `Package.swift`에 **정식 로컬 패키지 의존** (아래) — 자동 동기화, 권장 | `make-app.sh`(또는 번들 생성부)의 Info.plist에 CFBundleURLTypes 추가(§7-B) |
| **Xcode 앱** (.xcodeproj, objectVersion 77) | **소스 벤더링** — pbxproj에 SPM을 손으로 배선하는 건 취약하니 MenubKit 소스를 앱에 복사(아래) | 루트에 `<App>-Info.plist` + `INFOPLIST_FILE`(§7-A) |

**SPM 앱 — 정식 의존**:
```swift
// Package.swift
dependencies: [ .package(path: "../Menub/MenubKit") ],
targets: [ .executableTarget(name: "MyApp",
    dependencies: [ .product(name: "MenubKit", package: "MenubKit") ],
    path: "Sources/MyApp") ]
```
그리고 소스에서 `import MenubKit`.

**Xcode 앱 — 벤더링** (동기화 그룹이라 폴더에 넣으면 자동 컴파일):
```
cp <Menub>/MenubKit/Sources/MenubKit/Menub*.swift  <App>/<App>/MenubKit/
```
- `import`가 필요 없다(같은 모듈에 들어감).
- 드리프트 방지를 위해 `<App>/<App>/MenubKit/VENDORED.md`에 "Menub의 MenubKit에서 복사, 바뀌면 다시 복사" 메모를 남긴다.
- Xcode UI로 로컬 패키지를 추가할 수 있으면 그게 더 낫다(벤더링을 대체). 하지만 손으로 pbxproj를 고치지는 않는다.

---

## 3. 핵심 규칙 3가지 (실수 예방)

1. **런치 훅은 뷰가 아니라 앱델리게이트**(§4). `MenuBarExtra`/`.menu`/`.window`의 내용 뷰는 **열릴 때 지연 생성**되므로 `.onAppear`/`.task`가 실행 시점에 안 돈다. 매니페스트 기록·라우팅·게이트는 반드시 앱델리게이트에서 배선한다.
2. **MenuBarExtra 게이트는 `isInserted`**(§8). SceneBuilder에서 `if`로 MenuBarExtra를 감싸면 **컴파일러가 크래시**한다. `MenuBarExtra(_:systemImage:isInserted:)`를 쓴다.
3. **매 실행 재기록 + id 불변**(§0). 목록 변경마다 `writeManifest()`, id는 절대 안 바꾼다.

---

## 4. 런치 훅 — 앱델리게이트에 배선

**SwiftUI 앱**이면 앱델리게이트를 붙인다:
```swift
@main
struct MyApp: App {
    @NSApplicationDelegateAdaptor(MyAppDelegate.self) private var appDelegate
    var body: some Scene {
        // 게이트: 관리 중이면 아이템을 넣지 않음 (isInserted, §8)
        MenuBarExtra("My App", systemImage: "bolt",
                     isInserted: .constant(appDelegate.showsMenuBar)) {
            MenuBarContent().environmentObject(appDelegate.store)
        }
        .menuBarExtraStyle(.menu)
    }
}

final class MyAppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let store = MyStore()
    private let menub = MyMenub()
    let showsMenuBar: Bool                    // 실행 시점 관리 상태로 고정(재실행 반영)

    override init() {
        showsMenuBar = menub.satellite.shouldCreateStatusItem()
        super.init()
    }
    func applicationDidFinishLaunching(_ n: Notification) {
        menub.start(store: store)            // 매니페스트 기록 + onInvoke 연결
    }
    func application(_ a: NSApplication, open urls: [URL]) {
        urls.forEach { menub.route($0) }     // 계약 2: URL 수신
    }
}
```
**AppKit 앱**(이미 delegate 보유)이면 위 세 훅(`init`의 `showsMenuBar`, `applicationDidFinishLaunching`, `application(_:open:)`)을 기존 delegate에 그대로 더한다.

> URL 수신은 메뉴바 앱에서 `application(_:open:)`이 가장 확실하다. `.onOpenURL`은 창이 없을 때 놓칠 수 있어 권장하지 않는다.

---

## 5. 계약 적용 — 정적 메뉴 (고정 액션)

브리지 예:
```swift
import MenubKit   // 벤더링이면 import 없이 사용

final class MyMenub {
    let satellite = MenubSatellite(
        id: "myapp", displayName: "My App", urlScheme: "myapp",
        bundleIdentifier: Bundle.main.bundleIdentifier, iconRef: "sf:bolt")

    func start(openSettings: @escaping () -> Void, showPanel: @escaping () -> Void) {
        satellite.setActions([
            satellite.makeAction(id: "settings", title: "설정 열기", iconRef: "sf:gearshape"),
            satellite.makeAction(id: "panel",    title: "패널 보기")
        ])
        satellite.writeManifest()                 // 계약 1
        satellite.onInvoke { id in                // 계약 2 (invoke는 kit이 파생 → 라우팅과 일치)
            switch id {
            case "settings": openSettings()
            case "panel":    showPanel()
            default: break
            }
        }
    }
    func route(_ url: URL) { satellite.route(url) }
    var showsMenuBar: Bool { satellite.shouldCreateStatusItem() }   // 계약 3
}
```

---

## 6. 계약 적용 — 동적 목록 (Runlet·KeyFlow 유형)

액션을 **데이터에서 생성**하고, 목록이 바뀔 때마다 **재기록**한다. 허브가 폴더를 감시하므로 재기록만 하면 팝오버·팔레트에 자동 반영된다. 사용자 설정(enabled/pin/sort)은 id 기준이라 목록이 늘고 줄어도 안 깨진다.

```swift
func sync(_ items: [Item]) {
    satellite.setActions(items.map {
        satellite.makeAction(id: $0.id.uuidString, title: $0.name)
    })
    satellite.writeManifest()
}
satellite.onInvoke { [weak store] id in
    guard let item = store?.items.first(where: { $0.id.uuidString == id }) else { return }
    store?.run(item)          // 제너릭 라우팅: id로 실행
}
```

**변경 구독(둘 중 하나)** — 시작 시 1회 + 변경마다 재기록:
```swift
// A) Combine (ObservableObject / @Published): 구독 즉시 현재값 방출 → 시작 시 기록됨
cancellable = store.$items.sink { [weak self] in self?.sync($0) }

// B) Observation (@Observable): onChange에서 재등록(스스로 다시 건다)
func track() {
    sync(store.items)
    withObservationTracking { _ = store.items } onChange: { [weak self] in
        Task { @MainActor in self?.track() }
    }
}
```

---

## 7. Info.plist — URL scheme 등록

### 7-A. Xcode 앱 (GENERATE_INFOPLIST_FILE = YES)

CFBundleURLTypes는 `INFOPLIST_KEY_*` 빌드 설정으로 못 넣는다. **부분 plist를 만들어 병합**한다.

1. **레포 루트**에 `<App>-Info.plist` 생성 — URL Types만. (⚠️ 동기화 소스 폴더 **안**에 두면 번들 리소스로 잡혀 충돌하니 루트에 둔다)
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0"><dict>
     <key>CFBundleURLTypes</key>
     <array><dict>
       <key>CFBundleURLName</key><string>ysh.MyApp</string>
       <key>CFBundleURLSchemes</key><array><string>myapp</string></array>
     </dict></array>
   </dict></plist>
   ```
2. pbxproj의 **앱 타깃 Debug/Release** 두 곳(테스트 타깃 아님)에 `INFOPLIST_FILE = "<App>-Info.plist";` 추가. `GENERATE_INFOPLIST_FILE = YES`는 그대로 둔다 → 생성 키(LSUIElement 등)와 병합된다.
   - 앱 타깃 블록은 보통 `INFOPLIST_KEY_LSUIElement` 줄이 있어 구분된다.
3. 병합 확인(빌드 후):
   ```
   /usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes:0:CFBundleURLSchemes:0" <built>.app/Contents/Info.plist
   /usr/libexec/PlistBuddy -c "Print :LSUIElement" <built>.app/Contents/Info.plist
   ```

### 7-B. SPM 앱 (make-app.sh로 번들 생성)

번들 생성 스크립트의 `Info.plist` heredoc에 CFBundleURLTypes를 직접 추가한다(LSUIElement 옆).

---

## 8. 상태 아이템 게이트 (계약 3)

허브가 관리 중이면 자기 메뉴바 아이템을 만들지 않는다. **구조에 따라 방식이 다르다.**

- **SwiftUI `MenuBarExtra`** → `isInserted`로 게이트(§4). `if`로 감싸지 말 것(컴파일러 크래시).
  ```swift
  MenuBarExtra("My App", systemImage: "bolt", isInserted: .constant(appDelegate.showsMenuBar)) { … }
  ```
- **AppKit `NSStatusItem`** → 생성부를 조건으로 감싼다.
  ```swift
  if menub.showsMenuBar { setupStatusItem() }
  ```

반영 시점은 기본 **재실행 기준**(§8-2): 허브에서 토글/삭제 후 위성을 다시 켜면 반영된다.

**즉시 반영(선택)** — 재실행 없이: AppKit `NSStatusItem` 앱은 `observeManagement`로 라이브 전환할 수 있다.
```swift
menub.satellite.observeManagement { isManaged in
    if isManaged { statusItem = nil } else if statusItem == nil { setupStatusItem() }
}
```
(처음 호출 시 현재 상태로 1회 콜백, 메인 큐. MenuBarExtra는 `isInserted`에 상태 바인딩을 연결하면 라이브가 되지만, 앱델리게이트를 관찰 대상으로 만들어야 하니 기본은 재실행으로 둔다.)

### 허브에서 종료 (권장)

허브가 위성을 관리하면 위성 아이콘이 숨겨져 **자기 종료 버튼을 못 쓴다**. 다음 한 줄이면 허브 액션 목록 맨 아래에 표준 "종료"가 **자동으로 붙고**(writeManifest가 덧붙임) **라우팅도 자동 처리**된다:
```swift
satellite.setQuitAction { NSApp.terminate(nil) }   // 매니페스트 기록/재기록 전에 1회 호출
```
- 정적/동적 모두 `writeManifest()`(또는 첫 `sync`) **이전에** 호출한다.
- 종료는 `<scheme>://action/__menub_quit__` URL로 전달된다(팔레트 검색에도 "종료 — 앱이름"으로 뜸).
- 종료 시 MenubKit이 **매니페스트를 먼저 삭제한 뒤 종료**하므로, 그 앱은 **허브 목록에서 즉시 사라진다**. 다시 실행하면 매니페스트가 재기록돼 허브에 다시 나타난다.

---

## 9. 검증 (실측 명령)

```
# 빌드 (Xcode)
xcodebuild -project <App>.xcodeproj -scheme <App> -configuration Debug -derivedDataPath build build
# 또는 (SPM)
swift build

# 실행 후 매니페스트 기록 확인 (계약 1)
"<built>/…/MacOS/<App>" & ; sleep 2
python3 -m json.tool ~/Library/Application\ Support/menub/manifests/<id>.json
```

체크리스트:
- [ ] 실행 → `manifests/<id>.json`에 액션이 정확히 기록됨(계약 1)
- [ ] Info.plist에 scheme + LSUIElement 병합됨(PlistBuddy, §7-A)
- [ ] menub 설정에 후보로 뜨고, 토글 on 시 팝오버/팔레트에 액션 등장
- [ ] 액션 실행 시 실제 기능 동작(계약 2) — ⚠️ 부작용 있는 액션(스크립트·키주입)은 자동으로 트리거하지 말고 코드/단위테스트로만 확인
- [ ] 토글 on + 위성 재실행 → 아이콘 숨김, off → 복귀(계약 3)
- [ ] (동적) 앱에서 항목 추가 → menub에 자동 반영
- [ ] 허브에서 삭제 → 목록에서 사라지고, 앱 재실행 시 재등장

---

## 10. 함정 모음 (자주 하는 실수)

- **SceneBuilder `if` → 컴파일러 크래시**("failed to produce diagnostic"). MenuBarExtra 게이트는 `isInserted`.
- **뷰 생명주기는 실행 시 안 돈다**. MenuBarExtra 내용은 지연 생성 → `.onAppear`/`.task`에 매니페스트 기록을 걸면 앱을 켜도 안 써진다. 앱델리게이트로.
- **Info.plist를 동기화 소스 폴더 안에 두면** 번들 리소스로 중복 취급될 수 있다 → 레포 루트에 두고 `INFOPLIST_FILE`로 지정. `GENERATE_INFOPLIST_FILE=YES`를 끄지 말 것(LSUIElement 등 유실).
- **`Bundle.main.bundleIdentifier`는 `swift run`/생 바이너리에서 nil**. bundleIdentifier 검증은 번들(.app)로 빌드해서 확인.
- **SwiftUI API 추측 금지**. 시그니처가 애매하면 SDK의 `.swiftinterface`에서 확인:
  `grep -rh "public init" $(xcrun --show-sdk-path)/…/SwiftUI.swiftmodule/*.swiftinterface | grep isInserted`
- **키 입력을 다른 앱에 주입하는 앱**(KeyFlow류): URL 호출이 위성을 활성화시켜 포커스를 뺏는다. 올바른 앱을 타겟하려면 프런트 앱을 **연속 추적**해야 한다.
  ```swift
  NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { note in
      if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
         app.bundleIdentifier != Bundle.main.bundleIdentifier { /* previousApp = app */ }
  }
  ```
- **부작용 있는 액션을 검증하다 실제로 실행**하지 말 것(빌드 스크립트·키 주입). 라우팅은 MenubKit 단위테스트로 이미 검증됨.
- **pbxproj에 SPM을 손으로 배선**하려다 프로젝트가 깨진다. Xcode 앱은 벤더링, SPM 앱은 Package.swift.

---

## 11. 작업 순서 요약 (새 대화에서 이대로)

1. §1 준비물 파악 — **프로젝트 유형·진입 구조·정적/동적·상태아이템 위치**를 먼저.
2. §2 MenubKit 붙이기(SPM 의존 or 벤더링).
3. §4 앱델리게이트에 런치 훅 배선(SwiftUI면 어댑터 추가).
4. §5(정적) 또는 §6(동적)으로 액션·`writeManifest`·`onInvoke` 작성.
5. §7 Info.plist에 scheme 등록 + `application(_:open:)`에서 `route`.
6. §8 상태 아이템 게이트(MenuBarExtra=`isInserted`, AppKit=`if`).
7. §9 검증(매니페스트·Info.plist 실측).
8. 각 앱 폴더에 이 정의서 사본 포함.
9. 그 앱 저장소에서 `[[깃 플로우]]`로 정리.

---

## 12. 참고 — MenubKit API 표면

- `MenubSatellite(id:displayName:urlScheme:bundleIdentifier:iconRef:)`
- `makeAction(id:title:keywords:iconRef:) -> MenubAction` — invoke를 `<scheme>://action/<id>`로 파생(라우팅과 일치 보장)
- `setActions([MenubAction])` — 동적이면 변경마다 재호출
- `writeManifest() -> Bool` — 계약 1
- `onInvoke((String) -> Void)` / `route(URL) -> Bool` — 계약 2
- `setQuitAction(title:_:)` — 허브 액션 목록에 표준 "종료"를 자동 추가·처리(관리 중 종료 수단)
- `isManagedByHub` / `shouldCreateStatusItem() -> Bool` — 계약 3
- `observeManagement((Bool) -> Void)` / `stopObservingManagement()` — 계약 3 라이브(선택)

스키마(`MenubManifest`/`MenubAction`/`MenubManagedRegistry`)는 허브와 MenubKit이 공유하는 단일 진실원천이다.
