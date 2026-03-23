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
