# AI Safety Guidelines for FastWeather

## CRITICAL RULES FOR AI AGENTS

### 1. Scope Boundaries
- **iOS work** = ONLY modify files in `iOS/` directory
- **Web work** = ONLY modify files in `webapp/` directory  
- **Desktop work** = ONLY modify `fastweather.py` and related files
- **NEVER cross platform boundaries** unless explicitly requested

### 2. Verification Requirements
Before ANY commit, the AI MUST:
1. List ALL files being modified
2. Explain WHY each file needs changes
3. Show `git diff --stat` to confirm scope
4. If changing webapp: RUN the webapp and test affected features
5. If changing iOS: BUILD with xcodebuild to verify compilation

### 3. Forbidden Actions
❌ **NEVER delete HTML elements** without verifying no JavaScript references them
❌ **NEVER remove features** without explicit user confirmation  
❌ **NEVER make "minor changes"** to files outside the requested scope
❌ **NEVER assume code is unused** based on comments alone

### 4. Change Categorization
- **1-10 lines**: Minor change (OK to proceed)
- **10-50 lines**: Medium change (describe what and why)
- **50+ lines**: Major change (STOP and get user approval first)
- **Deletions >20 lines**: ALWAYS get explicit confirmation

### 5. Testing Requirements
**Webapp changes** require:
- Open webapp in browser
- Click through ALL affected UI
- Check browser console for JavaScript errors
- Test with VoiceOver/screen reader if accessibility changed

**iOS changes** require:
- Run xcodebuild and verify BUILD SUCCEEDED
- If UI changes: describe what user will see
- If API changes: verify no compilation errors

### 6. Commit Message Standards
**BAD**: "minor changes", "update files", "fix things"
**GOOD**: Specific description of what changed and why

Format:
```
[Platform] Brief summary

- Specific change 1 with reason
- Specific change 2 with reason
- Files affected: path/to/file.ext

Testing: [what was verified]
```

### 7. Red Flags (STOP IMMEDIATELY)
- User asks for iOS feature → AI starts editing webapp
- Commit includes files from 2+ platforms without explicit request
- Git diff shows >100 deletions without user asking to remove feature
- JavaScript code references HTML IDs that don't exist
- Any change labeled "cleanup" or "simplification" without details

## User Override
User can bypass these rules with explicit commands:
- "Ignore scope boundaries, modify webapp too"
- "I confirmed this deletion, proceed"
- "git commit --no-verify" (bypasses pre-commit hook)

## Responsibility
The AI must advocate for code safety even if user seems in a hurry.
Better to ask "Are you sure?" than to break production code.
