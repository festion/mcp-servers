"""Defensive input sanitization for caller-supplied text fields.

See vikunja-mcp #1342: Claude Code's tool-call XML marshaller silently drops
typed parameters (e.g. `priority`) when the surrounding description string
contains a raw `<parameter name="...">...</parameter>` substring. The
description ends up with the leaked tag appended, and the typed field
defaults silently (priority=0, done=false, etc.).

This module detects the leak fingerprint at the MCP-server entry point and
strips it, logging a WARNING so the recurrence is visible to operators
without blocking the create/update call.
"""

import logging
import re

logger = logging.getLogger(__name__)

# Matches the leak fingerprints observed on 2026-05-16:
#   <parameter name="priority">3</parameter>           (fully closed)
#   <parameter name="priority">3                       (no closing tag)
#   </description>\n<parameter name="priority">3       (with description prefix)
# Both the </description> prefix and the </parameter> suffix are optional;
# the value group [^<]* stops at the next tag boundary or end-of-string.
_PARAM_LEAK_RE = re.compile(
    r'(?:</?description>\s*)?'
    r'<parameter\s+name="([a-zA-Z_][a-zA-Z0-9_]*)">'
    r'([^<]*)'
    r'(?:</parameter>)?',
)


def strip_param_leak(text: str | None, field: str) -> str | None:
    """Strip leaked `<parameter name="X">V</parameter>` tags from `text`.

    Returns the cleaned string with each match removed and trailing
    whitespace stripped. Returns the input unchanged when it is None,
    empty, or contains no matches. Each stripped tag emits a WARNING log
    line naming the field, leaked parameter, and value.

    Args:
        text: Caller-supplied description or comment body.
        field: Label used in the log message (e.g. "description",
            "comment"). Purely cosmetic.
    """
    if not text:
        return text

    def _capture(m: re.Match) -> str:
        logger.warning(
            "%s: stripped leaked <parameter name=%r> tag (value=%r) "
            "— probable caller XML-serialization bug; see vikunja-mcp #1342",
            field, m.group(1), m.group(2),
        )
        return ""

    cleaned = _PARAM_LEAK_RE.sub(_capture, text).rstrip()
    return cleaned
