"""Integration test against live Vikunja instance.

Run with: PYTHONPATH=src pytest tests/test_integration.py -v -s
(Reads VIKUNJA_URL and VIKUNJA_API_TOKEN from .env or environment)
"""

import os
import pytest
import pytest_asyncio
from vikunja_mcp.client import VikunjaClient

# Load .env if present
_env_path = os.path.join(os.path.dirname(__file__), "..", ".env")
if os.path.exists(_env_path):
    with open(_env_path) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, val = line.split("=", 1)
                os.environ.setdefault(key, val)

VIKUNJA_URL = os.getenv("VIKUNJA_URL", "http://192.168.1.143:3456")
VIKUNJA_TOKEN = os.getenv("VIKUNJA_API_TOKEN", "")

pytestmark = pytest.mark.skipif(
    not VIKUNJA_TOKEN, reason="VIKUNJA_API_TOKEN not set"
)


@pytest_asyncio.fixture
async def client():
    c = VikunjaClient(VIKUNJA_URL, VIKUNJA_TOKEN)
    yield c
    await c.close()


@pytest.mark.asyncio
async def test_full_lifecycle(client):
    """Create project -> create task -> update -> add comment -> label -> delete -> delete project."""

    # Create test project
    project = await client.create_project(
        "__mcp_test_project__", "Integration test — safe to delete"
    )
    project_id = project["id"]
    assert project["title"] == "__mcp_test_project__"

    try:
        # Create task
        task = await client.create_task(
            project_id=project_id,
            title="Test task",
            description="Created by integration test",
            priority=3,
        )
        task_id = task["id"]
        assert task["title"] == "Test task"
        assert task["priority"] == 3

        # List tasks
        tasks = await client.list_tasks(project_id=project_id, filter_mode="open")
        assert any(t["id"] == task_id for t in tasks)

        # Update task (read-modify-write) — mark done
        updated = await client.update_task(task_id, done=True)
        assert updated["done"] is True
        # Verify description survived the update (critical: proves read-modify-write works)
        assert updated["description"] == "Created by integration test"

        # Add comment
        comment = await client.add_comment(task_id, "Integration test comment")
        assert comment["comment"] == "Integration test comment"

        # List comments
        comments = await client.list_comments(task_id)
        assert len(comments) >= 1

        # Create and attach label
        label = await client.get_or_create_label("__test_label__")
        await client.attach_label(task_id, label["id"])

        # Verify label attached
        task_detail = await client.get_task(task_id)
        label_titles = [lb["title"] for lb in (task_detail.get("labels") or [])]
        assert "__test_label__" in label_titles

        # Delete task
        result = await client.delete_task(task_id)
        assert "deleted" in result["message"].lower() or "Successfully" in result["message"]

    finally:
        # Cleanup: delete test project
        resp = await client.client.delete(f"/projects/{project_id}")
        assert resp.status_code == 200
