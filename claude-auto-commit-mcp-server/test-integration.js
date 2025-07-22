// Simple integration test for Claude Auto-Commit MCP Server
const { spawn } = require('child_process');

async function testServer() {
  console.log('Testing Claude Auto-Commit MCP Server...');
  
  const server = spawn('node', ['dist/index.js'], {
    stdio: ['pipe', 'pipe', 'pipe'],
    env: { ...process.env, ANTHROPIC_API_KEY: 'test-key' }
  });

  // Test tools list request
  const testRequest = {
    jsonrpc: '2.0',
    id: 1,
    method: 'tools/list',
    params: {}
  };

  let output = '';
  let error = '';

  server.stdout.on('data', (data) => {
    output += data.toString();
  });

  server.stderr.on('data', (data) => {
    error += data.toString();
  });

  // Send test request
  server.stdin.write(JSON.stringify(testRequest) + '\n');

  // Wait for response
  await new Promise(resolve => setTimeout(resolve, 2000));

  server.kill();

  console.log('Test Results:');
  console.log('=============');
  
  if (output) {
    try {
      const response = JSON.parse(output);
      if (response.result && response.result.tools) {
        console.log('✅ Server responds correctly');
        console.log('✅ Available tools:', response.result.tools.map(t => t.name));
        
        // Verify our three tools are present
        const toolNames = response.result.tools.map(t => t.name);
        const expectedTools = ['generate_commit_message', 'auto_stage_and_commit', 'smart_commit'];
        
        const allPresent = expectedTools.every(tool => toolNames.includes(tool));
        if (allPresent) {
          console.log('✅ All expected tools are available');
        } else {
          console.log('❌ Missing expected tools');
        }
      } else {
        console.log('❌ Invalid response format');
      }
    } catch (e) {
      console.log('❌ Could not parse response:', e.message);
      console.log('Raw output:', output);
    }
  } else {
    console.log('❌ No output received');
  }

  if (error && !error.includes('Starting Claude Auto-Commit MCP Server in stdio mode')) {
    console.log('⚠️  Errors:', error);
  }

  console.log('\n🎉 Integration test completed!');
}

testServer().catch(console.error);