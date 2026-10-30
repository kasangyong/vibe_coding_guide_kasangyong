#!/usr/bin/env bash
# Claude Code MCP 서버 등록 (user scope). 결과는 ~/.claude.json 의 mcpServers 에 저장된다.
# Windows 에서 npx 를 못 찾으면: claude mcp add -s user playwright -- cmd /c npx @playwright/mcp@latest
set -e

claude mcp add -s user playwright -- npx @playwright/mcp@latest

claude mcp list
