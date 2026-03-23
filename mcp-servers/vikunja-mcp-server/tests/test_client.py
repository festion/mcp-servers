"""Tests for Vikunja client project operations."""

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
