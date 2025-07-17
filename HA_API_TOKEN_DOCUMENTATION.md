# Home Assistant API Token Documentation

## Token Details
- **Name**: GitHub Deploy
- **Created**: 2025-07-14
- **Purpose**: CI/CD Pipeline automation for Home Assistant configuration deployment
- **Scope**: Full API access

## Test Results
✅ All API endpoints tested successfully:
- Basic API endpoint: `{"message":"API running."}`
- Configuration check: `{"result":"valid","errors":null,"warnings":null}`
- States endpoint: Accessible

## GitHub Secrets Configuration
Add this token to your GitHub repository secrets as:
- **Secret Name**: `HA_API_TOKEN`
- **Secret Value**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiI4NmMxODNkNmY1MjQ0NWI3YWIzOTdjNjM3NmYyMzI5ZCIsImlhdCI6MTc1MjUwNjQxNiwiZXhwIjoyMDY3ODY2NDE2fQ.rA3h9P1WYk0jKiLOchq711rD3Gyb-k1En27BeiY3sHA`

## Usage in CI/CD
This token enables the following automation capabilities:
- Configuration validation via `/api/config/core/check_config`
- Service reloads and restarts
- State monitoring and validation
- Full Home Assistant API access

## Security Notes
- Token expires: 2067-08-16 (50+ years from creation)
- Store securely in GitHub repository secrets
- Never commit to version control
- Has full API access - handle with care

## API Endpoints Available
- `GET /api/` - API status
- `POST /api/config/core/check_config` - Configuration validation
- `GET /api/states` - Entity states
- `POST /api/services/{domain}/{service}` - Service calls
- And full Home Assistant REST API access