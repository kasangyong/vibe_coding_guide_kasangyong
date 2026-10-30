#!/usr/bin/env bash
# Codex MCP 서버 등록. 결과는 ~/.codex/config.toml 의 [mcp_servers.<이름>] 에 저장된다.
# Windows 에서 npx 를 못 찾으면: codex mcp add playwright -- cmd /c npx @playwright/mcp@latest
set -e

codex mcp add playwright -- npx @playwright/mcp@latest

codex mcp list
