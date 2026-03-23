#!/usr/bin/env python3
"""Vikunja MCP Server — persistent task management for Claude Code."""

import os
import sys
import logging
from mcp.server.fastmcp import FastMCP

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler(sys.stderr)],
)
logger = logging.getLogger(__name__)

mcp = FastMCP("Vikunja Task Manager")


def main():
    mcp.run()


if __name__ == "__main__":
    main()
