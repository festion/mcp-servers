"""Tests for vikunja_mcp.sanitize: defensive `<parameter>`-tag stripping."""

import logging

from vikunja_mcp.sanitize import strip_param_leak


def test_returns_none_unchanged():
    assert strip_param_leak(None, "description") is None


def test_returns_empty_unchanged():
    assert strip_param_leak("", "description") == ""


def test_passes_through_clean_text():
    text = "A description with no leak. Has <b>bold</b> and <code>code</code>."
    assert strip_param_leak(text, "description") == text


def test_strips_fully_closed_tag(caplog):
    text = 'Body text.<parameter name="priority">3</parameter>'
    with caplog.at_level(logging.WARNING):
        result = strip_param_leak(text, "description")
    assert result == "Body text."
    assert "priority" in caplog.text
    assert "'3'" in caplog.text


def test_strips_unclosed_tag(caplog):
    # The most common observed fingerprint: trailing param, no closing tag.
    text = 'Body text.\n<parameter name="priority">3'
    with caplog.at_level(logging.WARNING):
        result = strip_param_leak(text, "description")
    assert result == "Body text."  # trailing whitespace stripped


def test_strips_with_description_prefix(caplog):
    text = 'Body text.</description>\n<parameter name="priority">3</parameter>'
    with caplog.at_level(logging.WARNING):
        result = strip_param_leak(text, "description")
    assert result == "Body text."


def test_strips_multiple_leaks(caplog):
    text = 'A<parameter name="priority">3</parameter>B<parameter name="done">true</parameter>'
    with caplog.at_level(logging.WARNING):
        result = strip_param_leak(text, "description")
    assert result == "AB"
    assert "priority" in caplog.text
    assert "done" in caplog.text


def test_ignores_html_escaped_parameter_tags():
    # Callers documenting the gotcha use escaped form — must be preserved verbatim.
    text = "Avoid raw &lt;parameter name=&quot;X&quot;&gt; tags in descriptions."
    assert strip_param_leak(text, "description") == text


def test_ignores_similar_unmatching_tags():
    text = "Some <param>bad</param> and <parameters>worse</parameters> tags."
    assert strip_param_leak(text, "description") == text


def test_warning_includes_field_label(caplog):
    text = 'X<parameter name="priority">3</parameter>'
    with caplog.at_level(logging.WARNING):
        strip_param_leak(text, "comment")
    assert "comment" in caplog.text


def test_no_warning_for_clean_text(caplog):
    text = "Just normal text with <b>tags</b>."
    with caplog.at_level(logging.WARNING):
        strip_param_leak(text, "description")
    assert caplog.records == []


def test_strips_labels_value_with_brackets(caplog):
    # labels is JSON-shaped; the value contains [", ", ] but no '<'.
    text = 'Body.<parameter name="labels">["bug","docs"]</parameter>'
    with caplog.at_level(logging.WARNING):
        result = strip_param_leak(text, "description")
    assert result == "Body."
    assert "labels" in caplog.text
