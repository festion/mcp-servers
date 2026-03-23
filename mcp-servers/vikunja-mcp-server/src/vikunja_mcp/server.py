#!/usr/bin/env python3
"""Vikunja MCP Server — persistent task management for Claude Code."""

import os
import sys
import logging
from typing import Any
from mcp.server.fastmcp import FastMCP
from vikunja_mcp.client import VikunjaClient

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler(sys.stderr)],
)
logger = logging.getLogger(__name__)

mcp = FastMCP("Vikunja Task Manager")

# Global state
_client: VikunjaClient | None = None
_active_project_id: int | None = None
_active_project_name: str | None = None


def get_client() -> VikunjaClient:
    """Get or create the Vikunja client."""
    global _client
    if _client is None:
        url = os.getenv("VIKUNJA_URL", "http://192.168.1.143:3456")
        token = os.getenv("VIKUNJA_API_TOKEN", "")
        if not token:
            raise ValueError("VIKUNJA_API_TOKEN environment variable is required")
        _client = VikunjaClient(url, token)
        logger.info("Vikunja client initialized: %s", url)
    return _client


def require_project() -> int:
    """Return active project ID or raise."""
    if _active_project_id is None:
        raise ValueError(
            "No active project. Call vikunja_set_project first (or use /proj)."
        )
    return _active_project_id


@mcp.tool()
async def vikunja_set_project(name: str) -> dict[str, Any]:
    """Set the active Vikunja project by name. Auto-creates if not found.

    Call this when activating a project (e.g., via /proj). All subsequent
    task operations are scoped to this project.
    """
    global _active_project_id, _active_project_name
    client = get_client()

    project = await client.get_project_by_name(name)
    if project is None:
        logger.info("Project '%s' not found, creating...", name)
        project = await client.create_project(name, f"Claude Code tasks for {name}")

    _active_project_id = project["id"]
    _active_project_name = project["title"]
    logger.info("Active project: %s (id=%d)", _active_project_name, _active_project_id)

    return {
        "project_id": project["id"],
        "project_name": project["title"],
        "description": project.get("description", ""),
    }


@mcp.tool()
async def vikunja_create_project(name: str, description: str = "") -> dict[str, Any]:
    """Create a new Vikunja project explicitly.

    Normally projects are auto-created by vikunja_set_project. Use this
    only when you need to create a project without setting it as active.
    """
    client = get_client()
    project = await client.create_project(name, description)
    return {
        "project_id": project["id"],
        "project_name": project["title"],
        "description": project.get("description", ""),
    }


@mcp.tool()
async def vikunja_create_task(
    title: str,
    description: str = "",
    priority: int = 0,
    labels: list[str] | None = None,
) -> dict[str, Any]:
    """Create a task in the active project.

    Args:
        title: Task title (required).
        description: Task description (markdown supported).
        priority: 0=unset, 1=low, 2=medium, 3=high, 4=urgent, 5=do-now.
        labels: Optional list of label names (auto-created if they don't exist).
    """
    project_id = require_project()
    client = get_client()

    task = await client.create_task(
        project_id=project_id,
        title=title,
        description=description,
        priority=priority,
    )

    if labels:
        for label_name in labels:
            label = await client.get_or_create_label(label_name)
            await client.attach_label(task["id"], label["id"])

    return {
        "task_id": task["id"],
        "title": task["title"],
        "priority": task.get("priority", 0),
        "labels": labels or [],
        "project": _active_project_name,
    }


@mcp.tool()
async def vikunja_list_tasks(
    filter: str = "open",
    label: str = "",
) -> dict[str, Any]:
    """List tasks in the active project.

    Args:
        filter: "open" (default), "done", or "all".
        label: Optional label name to filter by.
    """
    project_id = require_project()
    client = get_client()

    tasks = await client.list_tasks(project_id=project_id, filter_mode=filter)

    task_list = []
    for t in tasks:
        task_labels = [lb["title"] for lb in (t.get("labels") or [])]
        if label and label.lower() not in [l.lower() for l in task_labels]:
            continue
        task_list.append({
            "id": t["id"],
            "title": t["title"],
            "priority": t.get("priority", 0),
            "done": t.get("done", False),
            "labels": task_labels,
        })

    return {
        "project": _active_project_name,
        "filter": filter,
        "count": len(task_list),
        "tasks": task_list,
    }


@mcp.tool()
async def vikunja_get_task(id: int) -> dict[str, Any]:
    """Get full details of a task including comments.

    Args:
        id: Task ID.
    """
    client = get_client()
    task = await client.get_task(id)
    comments = await client.list_comments(id)

    return {
        "id": task["id"],
        "title": task["title"],
        "description": task.get("description", ""),
        "priority": task.get("priority", 0),
        "done": task.get("done", False),
        "labels": [lb["title"] for lb in (task.get("labels") or [])],
        "comments": [
            {"id": c["id"], "text": c["comment"], "created": c.get("created", "")}
            for c in comments
        ],
        "created": task.get("created", ""),
        "updated": task.get("updated", ""),
    }


@mcp.tool()
async def vikunja_update_task(
    id: int,
    title: str = "",
    description: str | None = None,
    priority: int | None = None,
    done: bool | None = None,
) -> dict[str, Any]:
    """Update a task. Only provided fields are changed.

    Uses read-modify-write to avoid Vikunja's full-replacement behavior.

    Args:
        id: Task ID.
        title: New title (empty string = keep existing).
        description: New description (None = keep existing).
        priority: New priority 0-5 (None = keep existing).
        done: Mark as done/undone (None = keep existing).
    """
    client = get_client()
    changes: dict[str, Any] = {}
    if title:
        changes["title"] = title
    if description is not None:
        changes["description"] = description
    if priority is not None:
        changes["priority"] = priority
    if done is not None:
        changes["done"] = done

    task = await client.update_task(id, **changes)

    return {
        "id": task["id"],
        "title": task["title"],
        "priority": task.get("priority", 0),
        "done": task.get("done", False),
        "updated": task.get("updated", ""),
    }


@mcp.tool()
async def vikunja_delete_task(id: int) -> dict[str, Any]:
    """Delete a task.

    Args:
        id: Task ID.
    """
    client = get_client()
    result = await client.delete_task(id)
    return {"deleted": True, "task_id": id, "message": result.get("message", "")}


@mcp.tool()
async def vikunja_add_comment(task_id: int, comment: str) -> dict[str, Any]:
    """Add a comment to a task. Useful for multi-session progress notes.

    Args:
        task_id: Task ID.
        comment: Comment text.
    """
    client = get_client()
    result = await client.add_comment(task_id, comment)
    return {
        "comment_id": result["id"],
        "task_id": task_id,
        "comment": result["comment"],
        "created": result.get("created", ""),
    }


def main():
    mcp.run()


if __name__ == "__main__":
    main()
