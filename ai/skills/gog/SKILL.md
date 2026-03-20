---
name: gog
description: Google Workspace CLI — Gmail, Calendar, Drive, Docs, Sheets, Slides, Tasks, Forms, Chat, People, Groups, Keep, Apps Script.
---

# gog

Use `gog` for Google Workspace operations. Requires OAuth setup.

## Setup (once)

- `gog auth credentials /path/to/client_secret.json`
- `gog auth add you@gmail.com --services gmail,calendar,drive,contacts,docs,sheets,tasks,slides,forms,chat,people,groups,keep,appscript`
- `gog auth list`

Set `GOG_ACCOUNT=you@gmail.com` to avoid repeating `--account`.

## Top-Level Aliases

- `gog ls` — list Drive files (alias for `drive ls`)
- `gog search "query"` — search Drive (alias for `drive search`)
- `gog open <target>` — print web URL for a Google URL/ID (offline)
- `gog download <fileId>` — download a Drive file
- `gog upload <localPath>` — upload a file to Drive
- `gog send` — send email (alias for `gmail send`)
- `gog me` / `gog whoami` — show your profile
- `gog status` — show auth/config status

## Gmail

### Read

- Search threads: `gog gmail search 'newer_than:7d' --max 10`
- Search messages (per-email, ignores threading): `gog gmail messages search "in:inbox from:ryanair.com" --max 20`
- Get message: `gog gmail get <messageId>`
- Download attachment: `gog gmail attachment <messageId> <attachmentId> --out /tmp/file.pdf`
- Get web URL: `gog gmail url <threadId>`

### Write

- Send (plain): `gog gmail send --to a@b.com --subject "Hi" --body "Hello"`
- Send (multi-line): `gog gmail send --to a@b.com --subject "Hi" --body-file ./message.txt`
- Send (stdin): `gog gmail send --to a@b.com --subject "Hi" --body-file -`
- Send (HTML): `gog gmail send --to a@b.com --subject "Hi" --body-html "<p>Hello</p>"`
- Reply: `gog gmail send --to a@b.com --subject "Re: Hi" --body "Reply" --reply-to-message-id <msgId>`

### Drafts

- List: `gog gmail drafts list`
- Create: `gog gmail drafts create --to a@b.com --subject "Hi" --body-file ./message.txt`
- Send: `gog gmail drafts send <draftId>`
- Update: `gog gmail drafts update <draftId> --body "Updated"`
- Delete: `gog gmail drafts delete <draftId>`

### Organize

- Archive: `gog gmail archive <messageId>`
- Mark read: `gog gmail mark-read <messageId>`
- Mark unread: `gog gmail unread <messageId>`
- Trash: `gog gmail trash <messageId>`
- Batch delete: `gog gmail batch delete <msgId1> <msgId2> ...`
- Batch modify labels: `gog gmail batch modify <msgId1> <msgId2> --add-labels LABEL_ID --remove-labels INBOX`

### Labels

- List: `gog gmail labels list`
- Get (with counts): `gog gmail labels get <labelIdOrName>`
- Create: `gog gmail labels create "My Label"`
- Rename: `gog gmail labels rename <labelIdOrName> "New Name"`
- Modify threads: `gog gmail labels modify <threadId> --add-labels LABEL_ID`
- Delete: `gog gmail labels delete <labelIdOrName>`

### Email Formatting

- Prefer plain text. Use `--body-file` for multi-paragraph messages (or `--body-file -` for stdin).
- `--body` does not unescape `\n`. Use a heredoc or `$'Line 1\n\nLine 2'` for inline newlines.
- Use `--body-html` only when you need rich formatting.
- HTML tags: `<p>` paragraphs, `<br>` line breaks, `<strong>` bold, `<em>` italic, `<a href="url">` links, `<ul>`/`<li>` lists.

Example (plain text via stdin):

```bash
gog gmail send --to recipient@example.com \
  --subject "Meeting Follow-up" \
  --body-file - <<'EOF'
Hi Name,

Thanks for meeting today. Next steps:
- Item one
- Item two

Best regards,
Your Name
EOF
```

## Calendar

### Events

- List events: `gog calendar events <calendarId> --from <iso> --to <iso>`
- List all calendars' events: `gog calendar events --from <iso> --to <iso>`
- Get event: `gog calendar event <calendarId> <eventId>`
- Create: `gog calendar create <calendarId> --summary "Title" --from <iso> --to <iso>`
- Create with color: `gog calendar create <calendarId> --summary "Title" --from <iso> --to <iso> --event-color 7`
- Update: `gog calendar update <calendarId> <eventId> --summary "New Title" --event-color 4`
- Delete: `gog calendar delete <calendarId> <eventId>`
- Search: `gog calendar search "query"`

### Scheduling

- Free/busy: `gog calendar freebusy --from <iso> --to <iso>`
- Find conflicts: `gog calendar conflicts --from <iso> --to <iso>`
- RSVP/respond: `gog calendar respond <calendarId> <eventId> --status accepted` (accepted|declined|tentative)
- Propose new time: `gog calendar propose-time <calendarId> <eventId>`

### Calendar Management

- List calendars: `gog calendar calendars`
- Subscribe: `gog calendar subscribe <calendarId>`
- Calendar ACL: `gog calendar acl <calendarId>`
- Colors: `gog calendar colors`
- Team schedule: `gog calendar team <group-email> --from <iso> --to <iso>`

### Special Events

- Focus time: `gog calendar focus-time --from <iso> --to <iso>`
- Out of office: `gog calendar out-of-office --from <iso> --to <iso>`
- Working location: `gog calendar working-location --from <iso> --to <iso> --type home` (home|office|custom)

### Calendar Colors

Event color IDs (from `gog calendar colors`):
- 1: #a4bdfc, 2: #7ae7bf, 3: #dbadff, 4: #ff887c, 5: #fbd75b
- 6: #ffb878, 7: #46d6db, 8: #e1e1e1, 9: #5484ed, 10: #51b749, 11: #dc2127

## Drive

- List files: `gog drive ls` / `gog drive ls --folder <folderId>`
- Search: `gog drive search "query" --max 10`
- Get metadata: `gog drive get <fileId>`
- Download: `gog drive download <fileId> --out /tmp/file.pdf`
- Upload: `gog drive upload ./file.pdf --folder <folderId>`
- Create folder: `gog drive mkdir "Folder Name" --folder <parentId>`
- Copy: `gog drive copy <fileId> "New Name"`
- Move: `gog drive move <fileId> --folder <targetFolderId>`
- Rename: `gog drive rename <fileId> "New Name"`
- Delete (trash): `gog drive delete <fileId>` / `--permanent` for forever
- Share: `gog drive share <fileId> --email user@example.com --role writer` (reader|writer|commenter)
- Unshare: `gog drive unshare <fileId> <permissionId>`
- List permissions: `gog drive permissions <fileId>`
- Get web URL: `gog drive url <fileId>`
- List shared drives: `gog drive drives`

## Docs

### Read

- Cat (plain text): `gog docs cat <docId>`
- Export: `gog docs export <docId> --format txt --out /tmp/doc.txt` (txt|md|pdf|docx)
- Info/metadata: `gog docs info <docId>`
- Structure (numbered paragraphs): `gog docs structure <docId>`
- List tabs: `gog docs list-tabs <docId>`

### Write

- Write (replace body): `gog docs write <docId> --text "New content"`
- Write from file: `gog docs write <docId> --file ./content.txt`
- Write from stdin: `gog docs write <docId> --file -`
- Append: `gog docs write <docId> --text "More content" --append`
- Write to specific tab: `gog docs write <docId> --text "Content" --tab-id <tabId>`

### Edit

- Find and replace (all): `gog docs find-replace <docId> "old text" "new text"`
- Find and replace (first only): `gog docs find-replace <docId> "old" "new" --first`
- Find and replace (markdown with images): `gog docs find-replace <docId> "placeholder" --content-file ./content.md --format markdown`
- Quick edit: `gog docs edit <docId> "find" "replace"`
- Sed-style regex: `gog docs sed <docId> 's/pattern/replacement/g'`
- Insert at position: `gog docs insert <docId> "text" --index 1`
- Delete range: `gog docs delete <docId> --start 10 --end 50`
- Clear all content: `gog docs clear <docId>`

### Other

- Create: `gog docs create "Title"`
- Copy: `gog docs copy <docId> "New Title"`

## Sheets

### Read

- Get values: `gog sheets get <sheetId> "Tab!A1:D10" --json`
- Metadata: `gog sheets metadata <sheetId>`
- Read formatting: `gog sheets read-format <sheetId> "Tab!A1:D10"`
- Get notes: `gog sheets notes <sheetId> "Tab!A1:D10"`
- Get hyperlinks: `gog sheets links <sheetId> "Tab!A1:D10"`

### Write

- Update: `gog sheets update <sheetId> "Tab!A1:B2" --values-json '[["A","B"],["1","2"]]' --input USER_ENTERED`
- Append: `gog sheets append <sheetId> "Tab!A:C" --values-json '[["x","y","z"]]' --insert INSERT_ROWS`
- Clear: `gog sheets clear <sheetId> "Tab!A2:Z"`
- Update note: `gog sheets update-note <sheetId> "Tab!A1" --note "My note"`

### Structure

- Insert rows: `gog sheets insert <sheetId> "Tab" ROWS 5 --count 3`
- Insert columns: `gog sheets insert <sheetId> "Tab" COLUMNS 2 --count 1`
- Find and replace: `gog sheets find-replace <sheetId> "old" "new"`

### Formatting

- Format cells: `gog sheets format <sheetId> "Tab!A1:D1" --bold --background-color "#f0f0f0"`
- Number format: `gog sheets number-format <sheetId> "Tab!A:A" --type CURRENCY`
- Freeze rows/cols: `gog sheets freeze <sheetId> --rows 1 --cols 1`
- Merge cells: `gog sheets merge <sheetId> "Tab!A1:B1"`
- Unmerge: `gog sheets unmerge <sheetId> "Tab!A1:B1"`
- Resize columns: `gog sheets resize-columns <sheetId> "A:C" --width 200`
- Resize rows: `gog sheets resize-rows <sheetId> "1:5" --height 40`

### Tab Management

- Add tab: `gog sheets add-tab <sheetId> "New Tab"`
- Rename tab: `gog sheets rename-tab <sheetId> "Old Name" "New Name"`
- Delete tab: `gog sheets delete-tab <sheetId> "Tab Name"` (use `--force` to skip confirmation)

### Other

- Create: `gog sheets create "Title"`
- Copy: `gog sheets copy <sheetId> "New Title"`
- Export: `gog sheets export <sheetId> --format csv --out /tmp/data.csv` (csv|xlsx|pdf)

## Slides

- Export: `gog slides export <presentationId> --format pdf --out /tmp/deck.pdf` (pdf|pptx)
- Info: `gog slides info <presentationId>`
- Create: `gog slides create "Title"`
- Create from markdown: `gog slides create-from-markdown "Title" --content-file ./slides.md`
- Create from template: `gog slides create-from-template <templateId> "Title"`
- Copy: `gog slides copy <presentationId> "New Title"`
- List slides: `gog slides list-slides <presentationId>`
- Read slide content: `gog slides read-slide <presentationId> <slideId>`
- Add slide (image): `gog slides add-slide <presentationId> ./image.png`
- Replace slide image: `gog slides replace-slide <presentationId> <slideId> ./new-image.png`
- Update speaker notes: `gog slides update-notes <presentationId> <slideId> --notes "Notes text"`
- Delete slide: `gog slides delete-slide <presentationId> <slideId>`

## Tasks

- List task lists: `gog tasks lists list`
- Create task list: `gog tasks lists create "My List"`
- List tasks: `gog tasks list <tasklistId>`
- Get task: `gog tasks get <tasklistId> <taskId>`
- Add task: `gog tasks add <tasklistId> --title "Buy groceries" --notes "Milk, eggs"`
- Update: `gog tasks update <tasklistId> <taskId> --title "Updated title"`
- Mark done: `gog tasks done <tasklistId> <taskId>`
- Mark undone: `gog tasks undo <tasklistId> <taskId>`
- Delete: `gog tasks delete <tasklistId> <taskId>`
- Clear completed: `gog tasks clear <tasklistId>`

## Forms

- Get form: `gog forms get <formId>`
- Create: `gog forms create --title "Survey"`
- Update: `gog forms update <formId> --title "New Title"`
- Add question: `gog forms add-question <formId> --title "Your name?"`
- Delete question: `gog forms delete-question <formId> <index>`
- Move question: `gog forms move-question <formId> <oldIndex> <newIndex>`
- List responses: `gog forms responses list <formId>`
- Get response: `gog forms responses get <formId> <responseId>`

## People

- Your profile: `gog people me`
- Get user: `gog people get <userId>`
- Search directory: `gog people search "query"`
- Relations: `gog people relations`

## Chat

- List spaces: `gog chat spaces list`
- Find space: `gog chat spaces find "space name"`
- Create space: `gog chat spaces create "Space Name"`
- List messages: `gog chat messages list <space>`
- Send message: `gog chat messages send <space> --text "Hello"`
- React: `gog chat messages react <message> "👍"`
- DM: `gog chat dm send <email> --text "Hello"`
- Find/create DM space: `gog chat dm space <email>`

## Groups

- List groups: `gog groups list`
- List members: `gog groups members <groupEmail>`

## Keep (Workspace only)

- List notes: `gog keep list`
- Get note: `gog keep get <noteId>`
- Search: `gog keep search "query"`
- Create: `gog keep create --title "Note" --text "Content"`
- Delete: `gog keep delete <noteId>`
- Download attachment: `gog keep attachment <attachmentName>`

## Apps Script

- Get project: `gog appscript get <scriptId>`
- Get content: `gog appscript content <scriptId>`
- Run function: `gog appscript run <scriptId> <function>`
- Create: `gog appscript create --title "My Script"`

## Contacts

- List: `gog contacts list --max 20`

## Scripting Tips

### Output Flags

- `--json` — JSON output (all commands)
- `--plain` — stable TSV output, no colors
- `--results-only` — in JSON mode, emit only the primary result (drops envelope/pagination)
- `--select "field1,field2"` — in JSON mode, select specific fields (supports dot paths)
- `--no-input` — never prompt, fail instead (useful for CI)
- `--dry-run` — print intended actions without making changes
- `--force` — skip confirmations for destructive commands

### Piping Patterns

```bash
# Get all event IDs for today
gog calendar events primary --from 2024-01-15 --to 2024-01-16 --json --results-only | jq '.[].id'

# Download all attachments from a message
gog gmail get <msgId> --json | jq -r '.payload.parts[] | select(.filename != "") | .body.attachmentId' | \
  xargs -I{} gog gmail attachment <msgId> {}

# Export a sheet tab to CSV
gog sheets export <sheetId> --format csv --out /tmp/data.csv
```

## Notes

- Confirm before sending mail or creating events.
- `gog gmail search` returns one row per thread; use `gog gmail messages search` for individual emails.
- Sheets values can be passed via `--values-json` (recommended) or as inline rows.
- Docs `find-replace` supports `--format markdown` for rich replacements including inline images.
- Use `gog open <url-or-id>` to quickly get a web URL for any Google resource.
