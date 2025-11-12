# LLM FUNCTION
#
# prerequisites:
#   1) export OPENAI_API_KEY="sk-..."
#   2) jq installed (brew install jq)
# Usage:
#
#   llm [MESSAGE]
#     - starts a new conversation
#   llm-same [MESSAGE]
#     - continues the conversation
#
#   llm-reset

# defaults
export LLM_MODEL="${LLM_MODEL:-gpt-4o-mini}"
export LLM_SYSTEM_PROMPT="${LLM_SYSTEM_PROMPT:-"You're in a terminal window. I need quick short answers about every commands. Be concise. Use Markdown."}"

# stateless: always starts a new chat and clears any previous thread
llm() {
  local content="$*"
  local payload resp
  payload=$(jq -n --arg model "$LLM_MODEL" --arg sys "$LLM_SYSTEM_PROMPT" --arg user "$content" \
    '{model:$model, messages:[{role:"system",content:$sys},{role:"user",content:$user}]}')

  resp=$(curl -s https://api.openai.com/v1/chat/completions \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$payload")

  echo "$resp" | jq -r '.choices[0].message.content'
  unset LLM_THREAD
}

# stateful: continues the same chat in this shell by appending to $LLM_THREAD
llm-same() {
  local content="$*"
  local messages payload resp assistant

  if [ -n "$LLM_THREAD" ]; then
    messages="$LLM_THREAD"
  else
    messages=$(jq -n --arg sys "$LLM_SYSTEM_PROMPT" '[{role:"system",content:$sys}]')
  fi

  messages=$(jq --arg user "$content" '. + [{role:"user",content:$user}]' <<< "$messages")

  payload=$(jq -n --arg model "$LLM_MODEL" --argjson msgs "$messages" \
    '{model:$model, messages:$msgs}')

  resp=$(curl -s https://api.openai.com/v1/chat/completions \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$payload")

  assistant=$(echo "$resp" | jq -r '.choices[0].message.content')
  echo "$assistant"

  # append assistant reply back into the thread
  export LLM_THREAD
  LLM_THREAD=$(jq --arg a "$assistant" '. + [{role:"assistant",content:$a}]' <<< "$messages")
}

# small helpers
llm-reset() { unset LLM_THREAD; }
llm-model() { export LLM_MODEL="$1"; echo "model set to $LLM_MODEL"; }
