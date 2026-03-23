"""Tests for Vikunja client operations."""

import pytest
import httpx
from unittest.mock import AsyncMock, patch
from vikunja_mcp.client import VikunjaClient

_FAKE_REQUEST = httpx.Request("GET", "http://test")


def _make_response(status_code: int, json_data):
    """Create an httpx.Response with a request attached (required for raise_for_status)."""
    return httpx.Response(status_code, json=json_data, request=_FAKE_REQUEST)


@pytest.fixture
def client():
    return VikunjaClient("http://localhost:3456", "test-token")


@pytest.mark.asyncio
async def test_list_projects(client):
    mock_response = _make_response(200, [
        {"id": 1, "title": "Inbox"},
        {"id": 5, "title": "operations"},
    ])
    client.client = AsyncMock()
    client.client.get = AsyncMock(return_value=mock_response)

    projects = await client.list_projects()
    assert len(projects) == 2
    assert projects[1]["title"] == "operations"
    client.client.get.assert_called_once_with("/projects", params={"per_page": 50, "page": 1})


@pytest.mark.asyncio
async def test_get_project_by_name_found(client):
    mock_response = _make_response(200, [
        {"id": 1, "title": "Inbox"},
        {"id": 5, "title": "operations"},
    ])
    client.client = AsyncMock()
    client.client.get = AsyncMock(return_value=mock_response)

    project = await client.get_project_by_name("operations")
    assert project is not None
    assert project["id"] == 5


@pytest.mark.asyncio
async def test_get_project_by_name_case_insensitive(client):
    mock_response = _make_response(200, [
        {"id": 5, "title": "Operations"},
    ])
    client.client = AsyncMock()
    client.client.get = AsyncMock(return_value=mock_response)

    project = await client.get_project_by_name("operations")
    assert project is not None
    assert project["id"] == 5


@pytest.mark.asyncio
async def test_get_project_by_name_not_found(client):
    mock_response = _make_response(200, [
        {"id": 1, "title": "Inbox"},
    ])
    client.client = AsyncMock()
    client.client.get = AsyncMock(return_value=mock_response)

    project = await client.get_project_by_name("operations")
    assert project is None


@pytest.mark.asyncio
async def test_create_project(client):
    mock_response = _make_response(200, {
        "id": 10, "title": "operations", "description": "Ops tasks",
    })
    client.client = AsyncMock()
    client.client.put = AsyncMock(return_value=mock_response)

    project = await client.create_project("operations", "Ops tasks")
    assert project["id"] == 10
    client.client.put.assert_called_once_with("/projects", json={
        "title": "operations", "description": "Ops tasks",
    })


# --- Task CRUD tests ---


@pytest.mark.asyncio
async def test_create_task(client):
    mock_response = _make_response(200, {
        "id": 42, "title": "Fix the thing", "project_id": 5,
    })
    client.client = AsyncMock()
    client.client.put = AsyncMock(return_value=mock_response)

    task = await client.create_task(5, "Fix the thing", description="It's broken", priority=3)
    assert task["id"] == 42
    assert task["title"] == "Fix the thing"
    client.client.put.assert_called_once_with(
        "/projects/5/tasks",
        json={"title": "Fix the thing", "description": "It's broken", "priority": 3},
    )


@pytest.mark.asyncio
async def test_list_tasks_open(client):
    mock_response = _make_response(200, [
        {"id": 1, "title": "Open task", "done": False},
    ])
    client.client = AsyncMock()
    client.client.get = AsyncMock(return_value=mock_response)

    tasks = await client.list_tasks(5, filter_mode="open")
    assert len(tasks) == 1
    client.client.get.assert_called_once_with(
        "/projects/5/tasks",
        params={"per_page": 50, "page": 1, "filter": "done = false"},
    )


@pytest.mark.asyncio
async def test_list_tasks_done(client):
    mock_response = _make_response(200, [
        {"id": 2, "title": "Done task", "done": True},
    ])
    client.client = AsyncMock()
    client.client.get = AsyncMock(return_value=mock_response)

    tasks = await client.list_tasks(5, filter_mode="done")
    assert len(tasks) == 1
    client.client.get.assert_called_once_with(
        "/projects/5/tasks",
        params={"per_page": 50, "page": 1, "filter": "done = true"},
    )


@pytest.mark.asyncio
async def test_list_tasks_all(client):
    mock_response = _make_response(200, [
        {"id": 1, "title": "Open task", "done": False},
        {"id": 2, "title": "Done task", "done": True},
    ])
    client.client = AsyncMock()
    client.client.get = AsyncMock(return_value=mock_response)

    tasks = await client.list_tasks(5, filter_mode="all")
    assert len(tasks) == 2
    client.client.get.assert_called_once_with(
        "/projects/5/tasks",
        params={"per_page": 50, "page": 1},
    )


@pytest.mark.asyncio
async def test_get_task(client):
    mock_response = _make_response(200, {
        "id": 42, "title": "Fix the thing", "description": "It's broken",
        "priority": 3, "done": False, "project_id": 5,
    })
    client.client = AsyncMock()
    client.client.get = AsyncMock(return_value=mock_response)

    task = await client.get_task(42)
    assert task["id"] == 42
    assert task["title"] == "Fix the thing"
    client.client.get.assert_called_once_with("/tasks/42")


@pytest.mark.asyncio
async def test_update_task_read_modify_write(client):
    """CRITICAL: verify GET is called first, then POST with full merged object."""
    existing_task = {
        "id": 42, "title": "Fix the thing", "description": "It's broken",
        "priority": 3, "done": False, "project_id": 5,
        "labels": [], "due_date": None,
    }
    get_response = _make_response(200, existing_task)
    updated_task = {
        **existing_task,
        "title": "Fix the thing (urgent)",
        "priority": 5,
    }
    post_response = _make_response(200, updated_task)

    client.client = AsyncMock()
    client.client.get = AsyncMock(return_value=get_response)
    client.client.post = AsyncMock(return_value=post_response)

    result = await client.update_task(42, title="Fix the thing (urgent)", priority=5)

    # Verify GET was called to fetch existing task
    client.client.get.assert_called_once_with("/tasks/42")

    # Verify POST was called with the full merged object
    post_call_args = client.client.post.call_args
    assert post_call_args[0][0] == "/tasks/42"
    posted_body = post_call_args[1]["json"]
    # New values are applied
    assert posted_body["title"] == "Fix the thing (urgent)"
    assert posted_body["priority"] == 5
    # Existing fields are preserved (not reset to zero values)
    assert posted_body["description"] == "It's broken"
    assert posted_body["done"] is False
    assert posted_body["project_id"] == 5
    assert posted_body["labels"] == []
    assert posted_body["due_date"] is None

    # Result comes from POST response
    assert result["title"] == "Fix the thing (urgent)"
    assert result["priority"] == 5


@pytest.mark.asyncio
async def test_delete_task(client):
    mock_response = _make_response(200, {"message": "success"})
    client.client = AsyncMock()
    client.client.delete = AsyncMock(return_value=mock_response)

    result = await client.delete_task(42)
    assert result["message"] == "success"
    client.client.delete.assert_called_once_with("/tasks/42")
