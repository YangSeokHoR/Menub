# Claude 단축어 규칙

메시지에 `[[단축어]]`가 포함되면 해당 규칙을 그 대화에 적용한다.
Always respond in Korean unless asked otherwise.

# How to use this file
- When my message contains `[[label]]`, find the matching `## [[label]]` section below and follow the text under it as your operating instructions for this conversation. A section runs until the next `## ` heading (or, for a body wrapped in `%%%`, the closing `%%%` marker).
- A heading like `## [[버그 보고]] <증상><기대 동작><에러·로그>` lists the inputs that shortcut expects. The `<...>` items are slots; I'll supply their content in my message (labeled or inline). If a required slot is empty, ask before proceeding.
- If a section's body is wrapped in `%%% ... %%%`, treat everything between the markers as the verbatim prompt body — including any `#`/`##` headings inside it, which belong to the quoted prompt, not to this file.
- If two instructions in this file conflict, prefer the more specific shortcut body over the general rules above.

## [[버그 보고]] <증상><기대 동작><에러·로그>

Something isn't working. Symptom: <증상>. Expected behavior: <기대 동작>. Error message or log output: <에러·로그>. Narrow down the cause before proposing a fix: first give the most likely causes in rank order. If my report is missing the one piece of information that would best split the problem space, tell me exactly what to run or check and what output to paste back.

## [[기대 동작]] <현재 동작><원하는 동작>

Currently: <현재 동작>. What I want instead: <원하는 동작>. Before changing code, restate the desired behavior in one or two sentences, including any edge cases you think are implied, so I can correct misreadings cheaply. After the change, list exactly what I should check to confirm it works.

## [[전제 확인]]

My machine and remote services may have changed outside this conversation. Before acting, state the assumptions you are making about external state (git branches, merge status, file locations, what I have or haven't run). Verify what you can with tools; ask me only about assumptions that would change your approach.

## [[깃 플로우]]

%%%
#Follow CONVENTIONS.md in the repo. If CONVENTIONS.md isn't in this conversation, tell me and fall back to standard Conventional Commits.
Work in this order: Always deliver in exactly these five steps, in this order, with these headers:
1. **이슈 발행** — GitHub New Issue에 붙여넣을 제목(한 줄)과 본문(별도 마크다운 블록).
2. **터미널 작업** — 하나의 명령 블록으로, 이 순서대로:
   (a) 작업 중인 저장소의 루트 경로로 `cd`한 뒤, main 최신화 후 새 브랜치 생성
   (b) 관심사별로 분리된 커밋들 — 각 커밋은 `git add <파일>` + `git commit -m "..."`
       형태로 즉시 복사-실행 가능하게. 메시지 본문/불릿까지 따옴표 안에 포함.
   (c) 푸시
3. **PR 작성** — GitHub 웹 폼에 붙여넣을 제목(한 줄)과 본문(별도 마크다운 블록).
4. **머지** — 웹에서 Merge pull request로 머지하라는 안내.
5. **로컬 브랜치 삭제** — 머지 후 정리 명령 블록(main 체크아웃·pull·브랜치 삭제·prune).

Do not reorder, merge, or omit any step. Each step gets its own header in this
sequence, every time.

- Terminal commands: give them clean, with no inline comments inside the command blocks.
- Every terminal command block must start with a `cd` to the current repo's root path. Infer that path from the conversation context (the repo I'm working in); do not hardcode a fixed path.
- I create PRs manually on the GitHub web UI, not with `gh`. Provide the PR title and body formatted for copy-paste into the web form: title on its own line, body as a separate plain markdown block I can paste into the description field. Do not give a `gh pr create` command.
- Assume the previous branch is already merged. When I invoke this, treat any prior feature branch as merged into `main`. Always branch the new work from `main` (start with `git checkout main && git pull` before creating the branch). Do not stack new work on the old feature branch.
- After step 5, add a separate "참고 (index.lock 오류 시)" block to be used only if git reports an index.lock error. Do not put it inside the step 2 or step 5 command blocks, since deleting the lock while another git process is running can corrupt the repo. The block cd's to the same repo root and runs `rm -f .git/index.lock`.
%%%

## [[검증 게이트]] <도입 검토 중인 기능>

I'm considering: <도입 검토 중인 기능>. Before building anything, design the cheapest test that would tell us whether it's worth building, distinguishing what you can run yourself from what I must run. State the go/no-go threshold before we run the test, so the result is judged against a bar set in advance. After the test, give a clear go or no-go recommendation with the deciding evidence.

## [[코드리뷰]]

%%%
# SwiftUI Code Review — Layered Pass Prompt

You are an expert SwiftUI reviewer checking my code for both bugs and clean-code quality.

## Before you start (context)
- State the assumed **minimum deployment target**. If I haven't given one, ask once, or assume iOS 17+ and say so explicitly.
- **Detect which state paradigm the code uses, and review against THAT paradigm:**
  - **Observation (iOS 17+):** `@Observable` classes, `@State` for owned reference types, `@Bindable` for bindings, `@Environment(MyType.self)`.
  - **Legacy Combine:** `ObservableObject` + `@Published`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject`.
  - If both appear, note the mix and whether it looks intentional.
- I do **not** require MVVM. A plain model method, computed property, or formatter is a perfectly good home for logic — don't push a view model where a simpler owner fits.
- If a pass finds nothing worth changing, **say so explicitly**. Do not invent findings to fill the checklist.

## Output format (every finding)
For each issue: **location** → **what's wrong** → **the concrete bug or risk it causes** → **before/after snippet** → **severity** tag (`bug` / `correctness-risk` / `style` / `perf-non-blocking`).

## Workflow (review first, then apply on approval)
1. **Review only.** Run all three passes as a review. Do not modify any code in this phase.
2. **Present findings grouped by pass**, using the finding format above (don't restate the format — just apply it). Then **stop and wait for my approval**; apply nothing until I confirm.
3. **Apply on approval, incrementally.** A "step" = one self-contained change that leaves the code compiling. Group tightly-related fixes into a single coherent step rather than splitting one finding across several — default to one batch per pass. After each step, pause for my confirmation before the next. Tell me if you'd prefer finer or coarser granularity.
4. Because Pass 1 fixes often reshape later findings, **after applying the Pass 1 batch, re-check which Pass 2/3 findings still apply** before continuing.

Work in three ordered passes. Complete each fully before the next, and announce which pass you're on at its start. **Order matters:** state-ownership problems are frequently the root cause of other smells, so fixing them first makes downstream issues shrink or change shape.

---

### PASS 1 — State ownership & data flow (do this first)
Review against the **detected paradigm**.

**Value types (both paradigms):**
- `@State` only for values the view itself owns. Flag any value passed in from a parent that should be `@Binding`.
- Flag workarounds where external code mutates a view's `@State` indirectly — treat this as evidence the ownership is misplaced.

**Reference types — Observation (`@Observable`):**
- Owned/created in this view → `@State private var vm = VM()` (NOT `@StateObject`).
- Merely received → plain `let vm: VM` / `var vm: VM` (no wrapper).
- Needs bindings into the object's properties → `@Bindable`.
- Flag: `@StateObject`/`@ObservedObject` applied to an `@Observable` type; a received object marked `@State` (it pins the first reference and ignores later updates — a silent staleness bug); missing `@Bindable` where two-way bindings are used.

**Reference types — Legacy (`ObservableObject`):**
- Created here → `@StateObject` (survives view re-init).
- Received → `@ObservedObject`.
- Flag reversals: `@ObservedObject` at the creation site risks the object being recreated/destroyed on re-render; `@StateObject` on a received object ignores the parent's instance.

**Threading vs. environment:**
- Flag values hand-threaded through many layers. Recommend `@Environment` / environment object — **but weigh the cost:** environment trades explicitness and testability for convenience and can make invalidation harder to predict, so for only 2–3 layers explicit passing may be the better call. Say which you'd choose and why.

> For every state finding, name the concrete bug it causes or risks, **then** give the corrected ownership.

---

### PASS 2 — View responsibility & decomposition
- Flag any `body` that is long (~50+ lines) or describes more than one thing. **Test:** if you can't explain the view in a single sentence, it has more than one responsibility.
- Move business logic (networking, transformation, sorting, filtering, formatting, calculation) out of / near `body` into a model method or view model.
- Recommend splitting:
  - Stateless visual chunks → computed property (`private var header: some View`) for readability.
  - Reusable or stateful chunks → their own `View` struct.
  - **Performance note:** a separate `View` struct also creates a dependency-tracking boundary, so SwiftUI can skip re-evaluating it when its inputs are unchanged; a computed `some View` is re-run as part of the parent's body. Prefer a struct boundary for chunks that are expensive or update on a different cadence than their parent — even if they're stateless.

---

### PASS 3 — Remaining clean-code checks (grouped)
- **Magic numbers / hardcoded values:** repeated padding, inline colors, duplicated strings. When the *same concept* repeats, hoist it into one named constant (enum / design-token style). Don't couple values that merely happen to share a number.
- **Repeated modifier combinations / duplicated button or card layouts:** extract into a `ViewModifier`, a `View` extension, or a reusable component.
- **Side effects:**
  - Prefer `.task {}` over `.onAppear { Task {} }` so cancellation is tied to view lifetime automatically (and consider `.task(id:)` when the work depends on a value).
  - Check `.onAppear` logic is safe against multiple invocations (back-navigation, tab switches).
  - Flag force-unwraps (`!`) and `try!` that **lack a clear, stated invariant**. A compile-time-known literal (e.g. `URL(string:)!` on a constant) is acceptable; unwrapping runtime/optional data is not.
  - Confirm UI state is mutated on the main actor; flag view models doing UI work off `@MainActor`.
- **Naming & readability:** views and properties should reveal their role (no `MyView2`); remove meaningless abbreviations and overused unnamed closure params (`$0` nesting).
- **Performance (note, mark non-blocking):** large `VStack` that should be `LazyVStack`/`List`; heavy computation (sorting, filtering) inside `body` on every recomputation. (For small collections, plain `VStack` is fine — only flag genuinely large ones.)

---

*Optional Pass 4, on request: accessibility (labels, Dynamic Type, contrast) and `#Preview` coverage.*
- respond in Korean
%%%
