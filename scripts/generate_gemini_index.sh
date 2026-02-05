#!/usr/bin/env bash
# Global Project Indexer using Gemini CLI
# Location: /home/dev/workspace/scripts/gemini-index.sh

# Get the name of the current directory to identify the project
PROJECT_NAME=$(basename "$PWD")
OUTPUT_DIR=".claude"
OUTPUT_FILE="$OUTPUT_DIR/PROJECT_INDEX.md"

# Ensure the .claude directory exists in the local project
mkdir -p "$OUTPUT_DIR"

echo "🧠 Gemini is indexing project: [$PROJECT_NAME]..."

# We use --all-files but rely on .gitignore to stay lean.
# The prompt is tuned to be a "Map Maker" for Claude.
gemini --all-files -p "You are a technical architect. Analyze the repository at '$PWD'.
Create a high-level Index and Logic Map for another AI (Claude) to use as a reference.
Include:
1. **Core Purpose**: What does this specific project/subdirectory do?
2. **Architecture**: Describe the directory structure and main entry points.
3. **Dependency Graph**: How do the files interact? (e.g., which YAMLs call which scripts).
4. **Context Summary**: Summarize long files (>500 lines) so Claude doesn't have to read them fully.
5. **Key Entities**: List important naming patterns, APIs, or hardware IDs (ESPHome/Proxmox).

Output must be concise Markdown. DO NOT include raw code, only the 'map' of where logic resides." --yolo > "$OUTPUT_FILE"

echo "✅ Index for $PROJECT_NAME generated at $OUTPUT_FILE"
