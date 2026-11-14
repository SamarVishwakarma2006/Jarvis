import http from 'node:http';

const apiKey = process.env.OPENAI_API_KEY;
const model = process.env.VOICEDESK_MODEL;
if (!apiKey || !model) {
  console.error('Set OPENAI_API_KEY and VOICEDESK_MODEL before starting the VoiceDesk AI service.');
  process.exit(1);
}

const schema = {
  type: 'object',
  properties: {
    intent: { type: 'string', enum: ['open_notepad', 'open_calculator', 'open_file', 'minimize_window', 'maximize_window', 'close_window', 'take_screenshot', 'unknown'] },
    reply: { type: 'string' },
    requires_confirmation: { type: 'boolean' },
  },
  required: ['intent', 'reply', 'requires_confirmation'],
  additionalProperties: false,
};

const server = http.createServer(async (request, response) => {
  response.setHeader('Content-Type', 'application/json');
  response.setHeader('Access-Control-Allow-Origin', 'http://127.0.0.1');
  if (request.method !== 'POST' || request.url !== '/intent') {
    response.writeHead(404).end(JSON.stringify({ error: 'Not found' }));
    return;
  }

  try {
    let body = '';
    for await (const chunk of request) {
      body += chunk;
      if (body.length > 4000) throw new Error('Request is too large.');
    }
    const { text } = JSON.parse(body);
    if (typeof text !== 'string' || !text.trim() || text.length > 1000) {
      response.writeHead(400).end(JSON.stringify({ error: 'Provide a non-empty transcript under 1000 characters.' }));
      return;
    }

    const result = await fetch('https://api.openai.com/v1/responses', {
      method: 'POST',
      headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model,
        store: false,
        instructions: 'Map the user request to exactly one allowed desktop intent. Never invent commands or file paths. If unclear, use unknown and ask a short clarifying question. Set requires_confirmation true for close_window. Set it false for every other intent. Opening a file means asking the desktop app to show its file picker.',
        input: text,
        text: { format: { type: 'json_schema', name: 'desktop_intent', strict: true, schema } },
      }),
    });
    const data = await result.json();
    if (!result.ok) throw new Error(data.error?.message || `Model request failed (${result.status}).`);
    const output = data.output?.flatMap(item => item.content || []).find(item => item.type === 'output_text')?.text;
    if (!output) throw new Error('The model returned no structured intent.');
    const intent = JSON.parse(output);
    if (intent.intent === 'close_window') intent.requires_confirmation = true;
    response.writeHead(200).end(JSON.stringify(intent));
  } catch (error) {
    response.writeHead(400).end(JSON.stringify({ error: error.message }));
  }
});

server.listen(43127, '127.0.0.1', () => console.log('VoiceDesk AI service listening on http://127.0.0.1:43127'));
