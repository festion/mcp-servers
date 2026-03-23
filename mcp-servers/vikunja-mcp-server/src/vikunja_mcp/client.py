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
