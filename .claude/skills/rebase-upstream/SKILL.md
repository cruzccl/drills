---
name: rebase-upstream
description: Check for a new Lichess Mobile release and, if there is one, rebase Drills onto it, fix what breaks, and build an APK for the user to test before pushing.
disable-model-invocation: true
---

# Rebase onto an upstream release

The fork follows releases of Lichess Mobile, never `upstream/main` (see "Keeping up with upstream"
in `AGENTS.md`, which holds the **current base**). Answer the user in Spanish; commits stay in
English, with no Claude attribution.

## 1. Is there a new release?

```bash
git fetch upstream --tags
git tag --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1   # latest release; ignores .fdroid tags
```

The release is newer when the current base is an ancestor of it and differs from it
(`git merge-base --is-ancestor <base> <tag>`). If it isn't, tell the user there is nothing to
rebase onto, and stop. Otherwise give them a short summary of the release
(`git log --oneline --no-merges <base>..<tag>`: the fixes and changes that matter to Drills) and go on.

## 2. Rebase

The working tree must be clean. Keep a backup branch, then rebase:

```bash
git branch backup/pre-rebase-<tag> main
git rebase --onto <tag> <base> main
```

Resolve every conflict so that **upstream's new shape carries the fork's intent**: take upstream's
version of the code and re-apply what the fork's commit meant to do on top of it, rather than
restoring the fork's old code. Lessons from past rebases:

- Upstream restructures (a file moved or split, a widget redesigned, an API removed): adapt the
  Drills change to the new structure. When Drills relied on something upstream deleted, copy the
  small piece into Drills' own code instead of reviving it in upstream files.
- A Drills behaviour must survive: if upstream moves a control Drills shows into a menu that
  Drills hides, keep the control visible for Drills.
- Docs (`README.md`, `AGENTS.md`): the README is the fork's own; in `AGENTS.md`, take upstream's
  text and re-add the fork's sections.
- Upstream tests that build the app with `const Application()` and expect the tabs need
  `Application(upstream: true)`.
- When a resolution makes a commit message false, rewrite that message (`git commit -F` before
  `git rebase --continue`).

Keep the user posted on which commit (n of N) you are on and how each conflict was solved.

## 3. Make it build and pass

Run these from the repo with the toolchain on `PATH` (see the toolchain memory), and follow the
machine's memory limits in the global `CLAUDE.md` (tests and builds one after the other):

1. Flutter version: if `pubspec.yaml` pins a newer one than `fvm flutter --version`, run
   `fvm flutter upgrade`.
2. `fvm flutter pub get --enforce-lockfile`, `fvm dart run build_runner build
   --delete-conflicting-outputs`, `./scripts/gen-drill-translations.sh`.
3. `fvm flutter analyze` with no issues, `dart format` on every file you touched, and
   `fvm flutter test --concurrency=2` all green.

Put every fix that isn't a conflict resolution, plus the new current base in `AGENTS.md`, in one
commit: `build: adapt Drills to Lichess Mobile <tag>`, its body listing what changed upstream and
how Drills follows. The step is done when `git status` is clean, analyze and tests are green, and
nothing is pushed.

## 4. Hand over an APK

```bash
fvm flutter build apk --release --dart-define=DRILLS_COMMIT=$(git rev-parse --short HEAD)
(cd android && ./gradlew --stop)
cp build/app/outputs/flutter-apk/app-release.apk ~/MEGA/drills-$(date +%F).apk
```

The Drill settings show two things next to each other, both fixed by this build:

- the version, from `pubspec.yaml`, which the rebase brings to the release's version: check that
  it reads the new `<tag>`;
- the commit, from `DRILLS_COMMIT`: the `HEAD` at build time, i.e. the adaptation commit. A later
  commit that doesn't lead to a new APK (docs, skills) needs no rebuild. Its GitHub link works
  once pushed.

Tell the user the APK is in `~/MEGA`, ask them to test it, and summarise the conflicts and
adaptations worth checking on the phone. Don't push.

## 5. Push, once the user says it works

```bash
git push --force-with-lease origin main
git branch -D backup/pre-rebase-<tag>
```
