Push Claude config changes to GitHub — other machines auto-pull on next launch.

## Workflow
1. cd ~/.claude
2. `git status --short` — show what changed
3. `git add -A` — stage all
4. `git commit -m "<user's message>"` — commit
5. `git push origin master` — push

## Before pushing
- If CLAUDE.md was changed, verify syntax is correct
- If plugin-skill-manifest.json was changed, verify JSON is valid
- If memory files changed, verify frontmatter is intact
- If you see unexpected files staged (image-cache, paste-cache, sync.log, status*.json), remove them with `git reset -- <file>` first — those are ephemeral

## After pushing
Confirm: "Pushed. Other machines pull on next launch."