"""Tests for server-level tool behavior (vikunja-mcp #1526).

vikunja_create_task must return GROUND TRUTH — the priority/labels actually
persisted by Vikunja, read back after the write — not the values that were
requested. When they differ (an upstream serialization drop, or a label that
failed to attach), it must surface a `warnings` entry instead of silently
reporting success.
"""

import pytest
from unittest.mock import AsyncMock, patch

import vikunja_mcp.server as server


def _mock_client(create_resp, get_resp, label_id=7):
    """Build an AsyncMock VikunjaClient for the create_task path."""
    client = AsyncMock()
    client.create_task = AsyncMock(return_value=create_resp)
    client.get_or_create_label = AsyncMock(
        side_effect=lambda name: {"id": label_id, "title": name}
    )
    client.attach_label = AsyncMock(return_value={"ok": True})
    client.get_task = AsyncMock(return_value=get_resp)
    return client


@pytest.fixture(autouse=True)
def _active_project():
    """Pretend a project is active for the duration of each test."""
    server._active_project_id = 5
    server._active_project_name = "test-project"
    yield
    server._active_project_id = None
    server._active_project_name = None


@pytest.mark.asyncio
async def test_return_reflects_actually_attached_labels_not_requested():
    """If a requested label did NOT end up attached, the return must report
    the real (empty) label set and warn — never echo the request as success."""
    create_resp = {"id": 42, "title": "T", "priority": 3}
    # Ground truth read-back: label never actually attached.
    get_resp = {"id": 42, "title": "T", "priority": 3, "labels": [], "due_date": ""}
    client = _mock_client(create_resp, get_resp)

    with patch.object(server, "get_client", return_value=client):
        result = await server.vikunja_create_task(
            title="T", priority=3, labels=["bug"]
        )

    assert result["labels"] == []  # ground truth, NOT ["bug"]
    assert "warnings" in result
    assert any("bug" in w for w in result["warnings"])


@pytest.mark.asyncio
async def test_warns_when_stored_priority_differs_from_requested():
    """If Vikunja stored a different priority than requested, return the
    stored value and warn (catches genuine server-side drops)."""
    create_resp = {"id": 42, "title": "T", "priority": 0}
    get_resp = {"id": 42, "title": "T", "priority": 0, "labels": [], "due_date": ""}
    client = _mock_client(create_resp, get_resp)

    with patch.object(server, "get_client", return_value=client):
        result = await server.vikunja_create_task(title="T", priority=3)

    assert result["priority"] == 0  # ground truth, NOT the requested 3
    assert "warnings" in result
    assert any("priority" in w for w in result["warnings"])


@pytest.mark.asyncio
async def test_clean_create_has_no_warnings():
    """When everything persisted as requested, return ground truth and no
    warnings key."""
    create_resp = {"id": 42, "title": "T", "priority": 3}
    get_resp = {
        "id": 42, "title": "T", "priority": 3,
        "labels": [{"title": "bug"}], "due_date": "",
    }
    client = _mock_client(create_resp, get_resp)

    with patch.object(server, "get_client", return_value=client):
        result = await server.vikunja_create_task(
            title="T", priority=3, labels=["bug"]
        )

    assert result["task_id"] == 42
    assert result["priority"] == 3
    assert result["labels"] == ["bug"]
    assert "warnings" not in result
