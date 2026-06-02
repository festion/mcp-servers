#!/usr/bin/env python3
"""Vikunja MCP Server — persistent task management for Claude Code."""

import os
import sys
import logging
from typing import Annotated, Any
from pydantic import Field
from mcp.server.fastmcp import FastMCP
from vikunja_mcp.client import VikunjaClient
from vikunja_mcp.sanitize import strip_param_leak

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
    title: Annotated[str, Field(description="Task title.")],
    description: Annotated[str, Field(description="Body. Raw HTML ok (<br>,<b>,<code>), not markdown, don't pre-escape. Avoid literal MCP parameter-tags here — caller may drop priority/labels (#1342/#1526).")] = "",
    priority: Annotated[int, Field(description="0=unset,1=low,2=medium,3=high,4=urgent,5=do-now.")] = 0,
    labels: Annotated[list[str] | None, Field(description="Label names; auto-created if missing.")] = None,
    due_date: Annotated[str | None, Field(description="RFC3339, e.g. 2026-05-20T17:00:00Z; '0001-01-01T00:00:00Z'=unset.")] = None,
    start_date: Annotated[str | None, Field(description="RFC3339 datetime.")] = None,
    end_date: Annotated[str | None, Field(description="RFC3339 datetime.")] = None,
    percent_done: Annotated[float | None, Field(description="0.0-1.0.")] = None,
    hex_color: Annotated[str | None, Field(description="Hex without '#', e.g. ff9900.")] = None,
    repeat_after: Annotated[int | None, Field(description="Repeat interval, seconds.")] = None,
    repeat_mode: Annotated[int | None, Field(description="0=after due/end,1=monthly,2=from-current-date.")] = None,
) -> dict[str, Any]:
    """Create a task in the active project. Returns ground-truth priority/labels (read back from Vikunja) plus a `warnings` list if stored differs from requested."""
    project_id = require_project()
    client = get_client()

    description = strip_param_leak(description, "description") or ""

    task = await client.create_task(
        project_id=project_id,
        title=title,
        description=description,
        priority=priority,
        due_date=due_date,
        start_date=start_date,
        end_date=end_date,
        percent_done=percent_done,
        hex_color=hex_color,
        repeat_after=repeat_after,
        repeat_mode=repeat_mode,
    )

    if labels:
        for label_name in labels:
            label = await client.get_or_create_label(label_name)
            await client.attach_label(task["id"], label["id"])

    # Return GROUND TRUTH, not what was requested. The headline "silent drop"
    # (#1526) happens upstream in the caller's tool-call serialization — when
    # priority/labels never reach this server they can't be recovered here —
    # but we can (a) report what Vikunja actually stored by reading the task
    # back, and (b) warn when it differs from what we received. That covers
    # label-attach failures and any genuine server-side drop, so the return
    # value never claims success it can't substantiate.
    final = await client.get_task(task["id"])
    stored_priority = final.get("priority", 0)
    attached_labels = [lb["title"] for lb in (final.get("labels") or [])]

    warnings: list[str] = []
    if priority and stored_priority != priority:
        warnings.append(
            f"requested priority={priority} but Vikunja stored priority={stored_priority}"
        )
    if labels:
        attached_lower = {lb.lower() for lb in attached_labels}
        missing = [lb for lb in labels if lb.lower() not in attached_lower]
        if missing:
            warnings.append(f"requested labels not attached: {missing}")

    result: dict[str, Any] = {
        "task_id": task["id"],
        "title": final.get("title", task["title"]),
        "priority": stored_priority,
        "labels": attached_labels,
        "due_date": final.get("due_date", ""),
        "project": _active_project_name,
    }
    if warnings:
        for w in warnings:
            logger.warning("create_task: %s", w)
        result["warnings"] = warnings
    return result


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
            "due_date": t.get("due_date", ""),
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
        "due_date": task.get("due_date", ""),
        "start_date": task.get("start_date", ""),
        "end_date": task.get("end_date", ""),
        "percent_done": task.get("percent_done", 0),
        "hex_color": task.get("hex_color", ""),
        "repeat_after": task.get("repeat_after", 0),
        "repeat_mode": task.get("repeat_mode", 0),
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
    id: Annotated[int, Field(description="Task ID.")],
    title: Annotated[str, Field(description="New title ('' = keep existing).")] = "",
    description: Annotated[str | None, Field(description="New body (None = keep). Raw HTML ok, not markdown, don't pre-escape.")] = None,
    priority: Annotated[int | None, Field(description="0-5 (None = keep existing).")] = None,
    done: Annotated[bool | None, Field(description="Mark done/undone (None = keep existing).")] = None,
    due_date: Annotated[str | None, Field(description="RFC3339, e.g. 2026-05-20T17:00:00Z; '0001-01-01T00:00:00Z' clears.")] = None,
    start_date: Annotated[str | None, Field(description="RFC3339 datetime.")] = None,
    end_date: Annotated[str | None, Field(description="RFC3339 datetime.")] = None,
    percent_done: Annotated[float | None, Field(description="0.0-1.0.")] = None,
    hex_color: Annotated[str | None, Field(description="Hex without '#'; '' clears.")] = None,
    repeat_after: Annotated[int | None, Field(description="Seconds (0 = no repeat).")] = None,
    repeat_mode: Annotated[int | None, Field(description="0=after due/end,1=monthly,2=from-current-date.")] = None,
) -> dict[str, Any]:
    """Update a task; only provided fields change (read-modify-write avoids Vikunja's full-replacement)."""
    client = get_client()
    changes: dict[str, Any] = {}
    if title:
        changes["title"] = title
    if description is not None:
        changes["description"] = strip_param_leak(description, "description")
    if priority is not None:
        changes["priority"] = priority
    if done is not None:
        changes["done"] = done
    if due_date is not None:
        changes["due_date"] = due_date
    if start_date is not None:
        changes["start_date"] = start_date
    if end_date is not None:
        changes["end_date"] = end_date
    if percent_done is not None:
        changes["percent_done"] = percent_done
    if hex_color is not None:
        changes["hex_color"] = hex_color
    if repeat_after is not None:
        changes["repeat_after"] = repeat_after
    if repeat_mode is not None:
        changes["repeat_mode"] = repeat_mode

    task = await client.update_task(id, **changes)

    return {
        "id": task["id"],
        "title": task["title"],
        "priority": task.get("priority", 0),
        "done": task.get("done", False),
        "due_date": task.get("due_date", ""),
        "start_date": task.get("start_date", ""),
        "end_date": task.get("end_date", ""),
        "percent_done": task.get("percent_done", 0),
        "hex_color": task.get("hex_color", ""),
        "repeat_after": task.get("repeat_after", 0),
        "repeat_mode": task.get("repeat_mode", 0),
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
async def vikunja_add_comment(
    task_id: Annotated[int, Field(description="Task ID.")],
    comment: Annotated[str, Field(description="Comment text. Raw HTML ok (<br>,<b>,<code>), not markdown, don't pre-escape.")],
) -> dict[str, Any]:
    """Add a comment to a task. Useful for multi-session progress notes."""
    client = get_client()
    comment = strip_param_leak(comment, "comment") or ""
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
