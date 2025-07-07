# GitHub MCP Server - Phase 2 Implementation Details

## Overview

Phase 2 of the GitHub MCP Server Project Board Support adds comprehensive GraphQL implementations for card operations, providing full access to GitHub Projects API v2 features including all field types, detailed content retrieval, and robust error handling.

## Implementation Components

### 1. Enhanced Card Read Operations

#### `list_project_cards` Tool
The enhanced implementation provides:
- Full GraphQL query with all field value types
- Content details for issues, pull requests, and draft issues
- Pagination support with cursor-based navigation
- Filtering by column, content type, and archived status
- Comprehensive field value extraction

**Query Structure:**
```graphql
query($projectId: ID!, $first: Int!, $after: String) {
  node(id: $projectId) {
    ... on ProjectV2 {
      items(first: $first, after: $after) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          id
          type
          createdAt
          updatedAt
          isArchived
          content {
            ... on Issue { /* full issue details */ }
            ... on PullRequest { /* full PR details */ }
            ... on DraftIssue { /* draft details */ }
          }
          fieldValues(first: 20) {
            nodes {
              /* all field value types */
            }
          }
        }
      }
    }
  }
}
```

#### `get_project_card` Tool
Provides detailed information about a specific card:
- Complete metadata (timestamps, archived status)
- Full content with all attributes
- All custom field values with field names
- Related project and column information

### 2. Enhanced Card Write Operations

#### Move Project Card
- Proper GraphQL mutation using `updateProjectV2ItemFieldValue`
- Queries column information to get field and project IDs
- Updates the Status field (which represents columns in API v2)
- Returns updated column information

#### Update Project Card
- Supports all field types (text, number, date, select, etc.)
- Dynamic field ID lookup by name
- Batch field updates with individual error handling
- Type-appropriate value formatting

#### Remove Card from Project
- Dual functionality: archive or delete
- Uses `archiveProjectV2Item` for soft removal
- Uses `deleteProjectV2Item` for permanent removal
- Returns operation status

#### Bulk Move Cards
- Batch operations for multiple cards
- Efficient column information caching
- Individual error tracking per card
- Summary statistics in response

### 3. Supporting Infrastructure

#### GraphQL Schema Fragments
Reusable query fragments ensure consistency:
- `ProjectV2ItemFieldValueFragment` - All field value types
- `ProjectV2FieldFragment` - Field definitions
- `IssueFragment` - Complete issue details
- `PullRequestFragment` - Complete PR details
- `ProjectV2ItemFragment` - Full card representation

#### Error Handling Utilities
Comprehensive error management:
- GraphQL error parsing and formatting
- User-friendly error messages
- ID format validation
- Context-specific error guidance
- Permission and not-found error helpers

## Technical Implementation Details

### Field Value Handling

The implementation supports all GitHub Projects API v2 field types:

1. **Text Fields**
   ```go
   ... on ProjectV2ItemFieldTextValue {
     text
     field { name }
   }
   ```

2. **Number Fields**
   ```go
   ... on ProjectV2ItemFieldNumberValue {
     number
     field { name }
   }
   ```

3. **Date Fields**
   ```go
   ... on ProjectV2ItemFieldDateValue {
     date
     field { name }
   }
   ```

4. **Single Select Fields** (Columns)
   ```go
   ... on ProjectV2ItemFieldSingleSelectValue {
     name
     optionId
     field { name }
   }
   ```

5. **Iteration Fields**
   ```go
   ... on ProjectV2ItemFieldIterationValue {
     title
     startDate
     duration
     field { name }
   }
   ```

6. **User Fields**
   ```go
   ... on ProjectV2ItemFieldUserValue {
     users(first: 10) {
       nodes { login }
     }
     field { name }
   }
   ```

7. **Label Fields**
   ```go
   ... on ProjectV2ItemFieldLabelValue {
     labels(first: 10) {
       nodes { name, color }
     }
     field { name }
   }
   ```

8. **Milestone Fields**
   ```go
   ... on ProjectV2ItemFieldMilestoneValue {
     milestone { title, dueOn, state }
     field { name }
   }
   ```

9. **Pull Request Fields**
   ```go
   ... on ProjectV2ItemFieldPullRequestValue {
     pullRequests(first: 10) {
       nodes { title, number }
     }
     field { name }
   }
   ```

### Error Handling Patterns

1. **ID Validation**
   ```go
   if err := ValidateProjectID(projectID); err != nil {
     return nil, err
   }
   ```

2. **GraphQL Error Formatting**
   ```go
   if gqlErr, ok := ParseGraphQLError(err); ok {
     return nil, fmt.Errorf(FormatGraphQLError(gqlErr))
   }
   ```

3. **Not Found Errors**
   ```go
   return nil, fmt.Errorf(HandleNotFoundError("project", projectID))
   ```

4. **Permission Errors**
   ```go
   return nil, fmt.Errorf(HandlePermissionError("update", "project"))
   ```

## Integration Examples

### List Cards with Filtering
```go
params := map[string]interface{}{
  "board_id": "PVT_kwDOAM6J184ACzDx",
  "column_id": "PVTFSC_lADOAM6J184ACzDxzgBKm8s",
  "content_type": "issue",
  "include_archived": false,
  "limit": 50,
}

result, err := handler(ctx, params)
```

### Get Full Card Details
```go
params := map[string]interface{}{
  "card_id": "PVTI_lADOAM6J184ACzDxzgBKm9A",
}

result, err := handler(ctx, params)
// Returns complete card with all fields and content
```

### Update Multiple Fields
```go
params := map[string]interface{}{
  "card_id": "PVTI_lADOAM6J184ACzDxzgBKm9A",
  "fields": map[string]interface{}{
    "Status": "In Progress",
    "Priority": "High",
    "Estimate": 5.0,
    "Due Date": "2025-02-01",
  },
}

result, err := handler(ctx, params)
```

## Performance Considerations

### Query Complexity
- Full card queries with all fields consume ~10-20 GraphQL points
- List operations with 50 cards consume ~50-100 points
- Rate limit: 5000 points per hour

### Response Size
- Full card details can be 5-10KB per card
- List of 50 cards can be 250-500KB
- Consider pagination for large projects

### Optimization Strategies
1. Use filtering to reduce result sets
2. Implement cursor-based pagination
3. Cache frequently accessed data (Phase 3)
4. Request only needed fields (future enhancement)

## Migration Guide

### From Simple to Enhanced Tools

1. **Update Tool Registration**
   ```go
   // Old
   toolsets.NewServerTool(MoveProjectCardSimple(getGQLClient, t))
   
   // New
   toolsets.NewServerTool(MoveProjectCard(getGQLClient, t))
   ```

2. **Handle Enhanced Responses**
   ```go
   // Simple response
   {
     "card_id": "PVTI_123",
     "message": "Operation completed"
   }
   
   // Enhanced response
   {
     "success": true,
     "card_id": "PVTI_123",
     "column_id": "PVTFSC_456",
     "column_name": "In Progress",
     "project_id": "PVT_789",
     "message": "Card moved successfully"
   }
   ```

3. **Error Handling**
   ```go
   // Check for structured errors
   if err != nil {
     if gqlErr, ok := ParseGraphQLError(err); ok {
       // Handle GraphQL-specific errors
       userMessage := FormatGraphQLError(gqlErr)
     }
   }
   ```

## Testing

### Unit Tests
- Snapshot tests for all tool definitions
- Tests verify tool schemas match expected format
- Run with: `UPDATE_TOOLSNAPS=true go test ./pkg/github -run Test_ProjectCardTools`

### Integration Testing (Phase 3)
- Mock GraphQL responses for offline testing
- Real API tests with test projects
- Performance benchmarks for large queries

## Known Limitations

1. **Pagination**: Manual cursor management required
2. **Caching**: No built-in cache (every request hits API)
3. **Field Creation**: Cannot create new custom fields
4. **Bulk Reads**: No batch get operation for multiple cards
5. **Webhooks**: No real-time updates support

## Future Enhancements (Phase 3)

1. **Pagination Helpers**
   - Auto-pagination for large result sets
   - Page size optimization
   - Cursor state management

2. **Caching Layer**
   - TTL-based cache for read operations
   - Cache invalidation on writes
   - Configurable cache strategies

3. **Field Management**
   - Create custom fields
   - Update field configurations
   - Delete unused fields

4. **Advanced Features**
   - Automation rules
   - Webhook integration
   - Batch operations
   - Query optimization

## Troubleshooting

### Common Issues

1. **"Invalid ID format" errors**
   - Ensure IDs use correct prefixes (PVT_, PVTI_, PVTFSC_)
   - Use list operations to get valid IDs

2. **"Could not resolve to a node" errors**
   - Item was deleted or you lack permissions
   - Verify token has 'project' scope

3. **Rate limit errors**
   - Reduce query frequency
   - Implement caching (Phase 3)
   - Use pagination for large queries

4. **Large response errors**
   - Use pagination with smaller limits
   - Filter by specific columns/types
   - Exclude archived items

## Code Organization

```
pkg/github/
├── projects.go              # Project board operations
├── project_columns.go       # Column management
├── project_cards.go         # Simple card operations (Phase 1)
├── project_cards_v2.go      # Full GraphQL card reads (Phase 2)
├── project_cards_enhanced.go # Enhanced write operations (Phase 2)
├── graphql_schemas.go       # Reusable GraphQL fragments (Phase 2)
├── graphql_errors.go        # Error handling utilities (Phase 2)
└── tools.go                 # Tool registration
```

## References

- [GitHub Projects API v2 Documentation](https://docs.github.com/en/graphql/reference/objects#projectv2)
- [GraphQL API Rate Limits](https://docs.github.com/en/graphql/overview/resource-limitations)
- [MCP Tool Development Guide](https://modelcontextprotocol.io/docs/tools)
- [GitHub GraphQL Explorer](https://docs.github.com/en/graphql/overview/explorer)