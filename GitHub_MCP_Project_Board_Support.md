# GitHub MCP Server Project Board Support

## Overview

The GitHub MCP Server now includes comprehensive support for GitHub Projects API v2, enabling users to manage project boards, columns, and cards through the Model Context Protocol (MCP). This implementation provides 18 new tools organized into three categories.

## Implementation Status

**Phase 1: Core Implementation** ✅ Complete (January 2025)
- Basic project board operations (5 tools)
- Column management (6 tools)
- Card operations (7 tools)

**Phase 2: Enhanced Features** 🔄 Planned
- Bulk read operations
- Advanced filtering
- Performance optimizations

**Phase 3: Advanced Features** 📅 Future
- Custom field management
- Automation rules
- Webhook integrations

## Available Tools

### Project Board Management (5 tools)

#### 1. `create_project_board`
Create a new GitHub project board with customizable settings.

**Parameters:**
- `owner` (required): Repository owner or organization login
- `name` (required): Name of the project board
- `description`: Description of the project board
- `repository`: Repository name (for repository-level projects)
- `template`: Template to use (kanban, scrum, bug_triage, none)
- `public`: Whether the project should be public (default: false)

**Example:**
```json
{
  "owner": "myorg",
  "name": "Q1 2025 Roadmap",
  "description": "Quarterly planning board",
  "template": "kanban"
}
```

#### 2. `update_project_board`
Update settings and metadata of an existing project board.

**Parameters:**
- `board_id` (required): ID of the project board to update
- `title`: New title for the project board
- `description`: New description for the project board
- `short_description`: New short description
- `public`: Update visibility of the project board
- `closed`: Close or reopen the project board

#### 3. `delete_project_board`
Delete or archive a project board.

**Parameters:**
- `board_id` (required): ID of the project board to delete
- `confirm` (required): Confirmation flag to prevent accidental deletion

#### 4. `list_project_boards`
List all accessible project boards for a user or organization.

**Parameters:**
- `owner` (required): User or organization login
- `type`: Filter by owner type (user, organization, all)
- `include_closed`: Include closed project boards (default: false)
- `limit`: Maximum number of boards to return (default: 20, max: 100)

#### 5. `get_project_board`
Get detailed information and statistics for a specific project board.

**Parameters:**
- `board_id` (required): ID of the project board
- `include_fields`: Include field definitions (default: true)
- `include_stats`: Include item statistics (default: true)

### Column Management (6 tools)

#### 6. `create_project_column`
Create a new column in a project board.

**Parameters:**
- `board_id` (required): ID of the project board
- `name` (required): Name of the column
- `description`: Description of the column
- `color`: Color for the column (hex format)
- `limit`: Work in progress (WIP) limit for the column

#### 7. `update_project_column`
Update properties and configurations of an existing project column.

**Parameters:**
- `column_id` (required): ID of the column to update
- `name`: New name for the column
- `description`: New description for the column
- `limit`: New WIP limit for the column

#### 8. `delete_project_column`
Delete a column from a project board with proper validation.

**Parameters:**
- `column_id` (required): ID of the column to delete
- `archive_cards`: Whether to archive cards in the column (default: true)

#### 9. `reorder_project_columns`
Change the order of columns within a project board.

**Parameters:**
- `board_id` (required): ID of the project board
- `column_order` (required): Array of column IDs in the desired order

#### 10. `list_project_columns`
List all columns for a specific project board.

**Parameters:**
- `board_id` (required): ID of the project board
- `include_stats`: Include card count statistics for each column

#### 11. `get_project_column`
Get detailed column information and statistics.

**Parameters:**
- `column_id` (required): ID of the column
- `include_cards`: Include cards in this column

### Card Operations (7 tools)

#### 12. `add_card_to_project`
Add an existing issue or pull request to a project board.

**Parameters:**
- `board_id` (required): ID of the project board
- `content_id` (required): ID of the issue or pull request to add
- `column_id`: ID of the column to add the card to (optional)

#### 13. `move_project_card`
Move a project card to a different column.

**Parameters:**
- `card_id` (required): ID of the card to move
- `column_id` (required): ID of the target column
- `position`: Position in column (top, bottom)

#### 14. `update_project_card`
Update properties and custom fields of a project card.

**Parameters:**
- `card_id` (required): ID of the card to update
- `fields`: Custom field values to update

#### 15. `remove_card_from_project`
Remove a card from a project board or archive it.

**Parameters:**
- `card_id` (required): ID of the card to remove
- `archive`: Archive the card instead of removing

#### 16. `bulk_move_cards`
Move multiple cards between columns in bulk.

**Parameters:**
- `card_ids` (required): Array of card IDs to move
- `target_column_id` (required): ID of the target column

#### 17. `list_project_cards`
List cards in a project board with filtering options.

**Parameters:**
- `board_id` (required): ID of the project board
- `column_id`: Filter by specific column
- `content_type`: Filter by content type (issue, pull_request)
- `include_archived`: Include archived cards
- `limit`: Maximum number of cards to return

#### 18. `get_project_card`
Get detailed information about a specific project card.

**Parameters:**
- `card_id` (required): ID of the card to retrieve

## Technical Implementation

### Architecture
- **Language**: Go
- **API**: GitHub GraphQL API v4 (githubv4)
- **Pattern**: MCP tool registration with read/write separation
- **Testing**: Snapshot-based tool definition tests

### Key Files
- `pkg/github/projects.go` - Project board operations
- `pkg/github/project_columns.go` - Column management
- `pkg/github/project_cards.go` - Card operations
- `pkg/github/tools.go` - Tool registration

### GitHub Projects API v2 Considerations
1. **Columns as Status Fields**: In API v2, columns are represented as options in the Status field
2. **GraphQL Required**: All operations use GitHub's GraphQL API
3. **Item IDs**: Cards are referenced by item IDs, not card IDs
4. **Field Values**: Custom fields require specific mutation patterns

## Usage Examples

### Create a Sprint Board
```bash
# Create a new kanban board
mcp-cli call create_project_board '{
  "owner": "myteam",
  "name": "Sprint 23",
  "description": "Two week sprint",
  "template": "kanban"
}'

# Add columns
mcp-cli call create_project_column '{
  "board_id": "PVT_123",
  "name": "In Progress",
  "limit": 5
}'

# Add an issue
mcp-cli call add_card_to_project '{
  "board_id": "PVT_123",
  "content_id": "I_456",
  "column_id": "PVTFSC_789"
}'
```

### Bulk Operations
```bash
# Move multiple cards to Done column
mcp-cli call bulk_move_cards '{
  "card_ids": ["PVTI_1", "PVTI_2", "PVTI_3"],
  "target_column_id": "PVTFSC_999"
}'
```

## Limitations

### Current Limitations (Phase 1)
1. **Simplified Mutations**: Some write operations return simplified responses
2. **No Bulk Reads**: Bulk read operations planned for Phase 2
3. **Limited Field Support**: Custom field management coming in Phase 3
4. **Template Constraints**: GitHub API v2 has limited template support

### API Constraints
- GitHub Projects API v2 differs significantly from classic projects
- Rate limits apply to GraphQL operations
- Some features require specific GitHub plan levels

## Troubleshooting

### Common Issues

1. **Authentication Errors**
   - Ensure GitHub token has `project` scope
   - For org projects, need `read:org` scope

2. **Project Not Found**
   - Use full project ID (e.g., `PVT_kwDOAM6J184ACzDx`)
   - Check if project is accessible with token

3. **Column Operations Fail**
   - Remember columns are Status field options
   - Use field IDs, not column names

4. **Card Addition Fails**
   - Verify issue/PR exists and is accessible
   - Check project accepts the content type

## Future Enhancements

### Phase 2 (Planned)
- Bulk read operations for performance
- Advanced filtering and search
- Pagination support
- Caching layer

### Phase 3 (Future)
- Custom field CRUD operations
- Automation rule management
- Webhook event handling
- Template creation

## Related Documentation
- [GitHub Projects API v2](https://docs.github.com/en/graphql/reference/objects#projectv2)
- [MCP Tool Development](../development/mcp-tools.md)
- [GitHub MCP Server](./github-mcp-server.md)