#!/bin/bash
# Parasto Workspace Sanity Check
# Run before every Claude Code session to confirm you're in the right place.
# Updated: 2026-02-19 — canonical HEAD bumped to 4fee5ef

EXPECTED_PATH="$HOME/Projects/ParastoLocal/myna_flutter"
EXPECTED_BRANCH="cleanup/code-review-backup-20260201-213457"
# Minimum expected HEAD — any commit AT OR AFTER this is acceptable
MINIMUM_HEAD="4fee5ef"

PASS=0
FAIL=0

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║          PARASTO WORKSPACE SANITY CHECK                  ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Check 1: Path
ACTUAL_PATH="$(pwd)"
if [[ "$ACTUAL_PATH" == "$EXPECTED_PATH" ]]; then
  echo "✅ PATH:    $ACTUAL_PATH"
  PASS=$((PASS+1))
else
  echo "❌ PATH:    $ACTUAL_PATH"
  echo "   EXPECTED: $EXPECTED_PATH"
  FAIL=$((FAIL+1))
fi

# Check 2: Branch
ACTUAL_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
if [[ "$ACTUAL_BRANCH" == "$EXPECTED_BRANCH" ]]; then
  echo "✅ BRANCH:  $ACTUAL_BRANCH"
  PASS=$((PASS+1))
else
  echo "❌ BRANCH:  $ACTUAL_BRANCH"
  echo "   EXPECTED: $EXPECTED_BRANCH"
  FAIL=$((FAIL+1))
fi

# Check 3: HEAD commit — must be at or after minimum SHA
ACTUAL_HEAD_SHORT="$(git rev-parse --short HEAD 2>/dev/null)"
ACTUAL_HEAD_FULL="$(git rev-parse HEAD 2>/dev/null)"
# Check if minimum HEAD is an ancestor of (or equal to) current HEAD
if git merge-base --is-ancestor "$MINIMUM_HEAD" HEAD 2>/dev/null; then
  echo "✅ HEAD:    $ACTUAL_HEAD_FULL"
  echo "   SHORT:    $ACTUAL_HEAD_SHORT (at or after canonical minimum $MINIMUM_HEAD)"
  PASS=$((PASS+1))
else
  echo "❌ HEAD:    $ACTUAL_HEAD_FULL"
  echo "   EXPECTED: at or after $MINIMUM_HEAD"
  echo "   ⚠️  You may be on the OLD CLONE. Do NOT build!"
  FAIL=$((FAIL+1))
fi

# Check 4: Latest commit
LATEST="$(git log --oneline -1 2>/dev/null)"
echo "ℹ️  LATEST:  $LATEST"

# Check 5: iCloud safety
XATTR_OUT="$(xattr . 2>/dev/null)"
if echo "$XATTR_OUT" | grep -q "file-provider-domain-id"; then
  echo "❌ iCLOUD:  WARNING — this path is iCloud-synced!"
  echo "   NEVER build iOS from an iCloud path."
  FAIL=$((FAIL+1))
else
  echo "✅ iCLOUD:  Safe — no iCloud sync detected"
  PASS=$((PASS+1))
fi

# Check 6: Dangerous old clone detection
OLD_CLONE="$HOME/Documents/Projects/Myna-Parasto-Current/myna_flutter"
if [[ -d "$OLD_CLONE/ios/Runner.xcodeproj" ]]; then
  echo "⚠️  OLD CLONE: $OLD_CLONE still has ios/Runner.xcodeproj"
  echo "   Risk: Xcode could accidentally build from this. Consider renaming."
else
  echo "✅ OLD CLONE: ios/Runner.xcodeproj neutralized or absent"
  PASS=$((PASS+1))
fi

# Check 7: DerivedData check — warn if Runner DerivedData exists from wrong path
DERIVED=$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -name "Runner-*" 2>/dev/null | head -1)
if [[ -n "$DERIVED" ]]; then
  echo "ℹ️  DerivedData: $DERIVED (exists — run 'flutter clean' if build seems wrong)"
else
  echo "✅ DerivedData: No stale Runner build data"
  PASS=$((PASS+1))
fi

# Summary
echo ""
echo "──────────────────────────────────────────────────────────"
if [[ $FAIL -eq 0 ]]; then
  echo "✅ YOU ARE ON THE RIGHT VERSION — all checks passed ($PASS/$((PASS+FAIL)))"
  echo "   Safe to build. Device installs will come from:"
  echo "   $EXPECTED_PATH"
else
  echo "❌ PROBLEMS DETECTED — $FAIL check(s) failed. Do NOT start coding."
  echo "   Fix the issues above before opening Claude Code."
fi
echo "──────────────────────────────────────────────────────────"
echo ""

exit $FAIL
