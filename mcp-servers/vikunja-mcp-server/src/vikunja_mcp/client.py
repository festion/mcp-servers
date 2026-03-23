"""Vikunja REST API client."""

import httpx
from typing import Any


class VikunjaClient:
    """Async HTTP client for Vikunja REST API."""

    def __init__(self, base_url: str, api_token: str):
        self.base_url = base_url.rstrip("/")
        self.client = httpx.AsyncClient(
            base_url=f"{self.base_url}/api/v1",
            headers={
                "Authorization": f"Bearer {api_token}",
                "Content-Type": "application/json",
            },
            timeout=30.0,
        )

    async def close(self):
        await self.client.aclose()

    async def list_projects(self) -> list[dict[str, Any]]:
        """List all projects. Handles pagination."""
        all_projects = []
        page = 1
        while True:
            resp = await self.client.get("/projects", params={"per_page": 50, "page": page})
            resp.raise_for_status()
            batch = resp.json()
            if not batch:
                break
            all_projects.extend(batch)
            if len(batch) < 50:
                break
            page += 1
        return all_projects

    async def get_project_by_name(self, name: str) -> dict[str, Any] | None:
        """Find a project by name (case-insensitive)."""
        projects = await self.list_projects()
        for p in projects:
            if p["title"].lower() == name.lower():
                return p
        return None

    async def create_project(self, title: str, description: str = "") -> dict[str, Any]:
        """Create a new project."""
        resp = await self.client.put("/projects", json={
            "title": title,
            "description": description,
        })
        resp.raise_for_status()
        return resp.json()

    # --- Task operations ---

    async def create_task(self, project_id: int, title: str, description: str = "", priority: int = 0) -> dict[str, Any]:
        """Create a task in a project. Uses PUT."""
        body: dict[str, Any] = {"title": title}
        if description:
            body["description"] = description
        if priority:
            body["priority"] = priority
        resp = await self.client.put(f"/projects/{project_id}/tasks", json=body)
        resp.raise_for_status()
        return resp.json()

    async def list_tasks(self, project_id: int, filter_mode: str = "open", page: int = 1) -> list[dict[str, Any]]:
        """List tasks. filter_mode: open, done, all."""
        params: dict[str, Any] = {"per_page": 50, "page": page}
        if filter_mode == "open":
            params["filter"] = "done = false"
        elif filter_mode == "done":
            params["filter"] = "done = true"
        resp = await self.client.get(f"/projects/{project_id}/tasks", params=params)
        resp.raise_for_status()
        return resp.json()

    async def get_task(self, task_id: int) -> dict[str, Any]:
        """Get a single task."""
        resp = await self.client.get(f"/tasks/{task_id}")
        resp.raise_for_status()
        return resp.json()

    async def update_task(self, task_id: int, **changes) -> dict[str, Any]:
        """Update via read-modify-write. GET first, merge changes, POST full object."""
        existing = await self.get_task(task_id)
        existing.update(changes)
        resp = await self.client.post(f"/tasks/{task_id}", json=existing)
        resp.raise_for_status()
        return resp.json()

    async def delete_task(self, task_id: int) -> dict[str, Any]:
        """Delete a task."""
        resp = await self.client.delete(f"/tasks/{task_id}")
        resp.raise_for_status()
        return resp.json()

    # --- Label operations ---

    async def list_labels(self) -> list[dict[str, Any]]:
        """List all labels."""
        resp = await self.client.get("/labels")
        resp.raise_for_status()
        return resp.json()

    async def create_label(self, title: str, hex_color: str = "") -> dict[str, Any]:
        """Create a new label. Uses PUT."""
        body: dict[str, Any] = {"title": title}
        if hex_color:
            body["hex_color"] = hex_color
        resp = await self.client.put("/labels", json=body)
        resp.raise_for_status()
        return resp.json()

    async def get_or_create_label(self, title: str) -> dict[str, Any]:
        """Get existing label by title, or create it."""
        labels = await self.list_labels()
        for label in labels:
            if label["title"].lower() == title.lower():
                return label
        return await self.create_label(title)

    async def attach_label(self, task_id: int, label_id: int) -> dict[str, Any]:
        """Attach a label to a task."""
        resp = await self.client.put(f"/tasks/{task_id}/labels", json={"label_id": label_id})
        resp.raise_for_status()
        return resp.json()

    # --- Comment operations ---

    async def add_comment(self, task_id: int, comment: str) -> dict[str, Any]:
        """Add a comment to a task."""
        resp = await self.client.put(f"/tasks/{task_id}/comments", json={"comment": comment})
        resp.raise_for_status()
        return resp.json()

    async def list_comments(self, task_id: int) -> list[dict[str, Any]]:
        """List comments on a task."""
        resp = await self.client.get(f"/tasks/{task_id}/comments")
        resp.raise_for_status()
        return resp.json()
