---
name: clipboard
description: Copy text to the system clipboard. Use when user asks to copy something, send to clipboard, or similar requests.
---

# Clipboard

Copy content to the user's system clipboard.

## How to Copy

Use a heredoc to reliably handle multi-line content, quotes, and special characters:

```bash
cat << 'EOF' | pbcopy
Your content here.
Can span multiple lines.
Handles "quotes" and 'apostrophes' without escaping.
EOF
```

## Platform Commands

- **macOS**: `pbcopy` (copy) / `pbpaste` (verify)
- **Linux**: `xclip -selection clipboard` or `xsel --clipboard`

## After Copying

Verify the clipboard content worked:

```bash
pbpaste | head -3
```

If verification shows different content, the sandbox may be blocking clipboard access. In that case, inform the user and display the text directly so they can copy it manually.
