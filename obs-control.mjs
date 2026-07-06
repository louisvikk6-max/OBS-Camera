import OBSWebSocket from 'obs-websocket-js';

function parseJsonArg(index) {
  const value = process.argv[index];
  if (!value) {
    return {};
  }
  if (value.startsWith('base64:')) {
    return JSON.parse(Buffer.from(value.slice('base64:'.length), 'base64').toString('utf8'));
  }
  return JSON.parse(value);
}

async function connect(port) {
  const obs = new OBSWebSocket();
  await obs.connect(`ws://127.0.0.1:${port}`, undefined, {
    rpcVersion: 1,
    eventSubscriptions: 0,
  });
  return obs;
}

async function request(port, requestType, requestData = {}) {
  const obs = await connect(port);
  try {
    const response = await obs.call(requestType, requestData);
    console.log(JSON.stringify(response ?? {}));
  } finally {
    await obs.disconnect();
  }
}

async function wait(port, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  let lastError = '';

  while (Date.now() < deadline) {
    try {
      const obs = await connect(port);
      await obs.disconnect();
      console.log(JSON.stringify({ ok: true }));
      return;
    } catch (error) {
      lastError = error?.message ?? String(error);
      await new Promise((resolve) => setTimeout(resolve, 500));
    }
  }

  throw new Error(`Timed out waiting for OBS websocket on port ${port}. ${lastError}`);
}

async function batchStart(ports) {
  const clients = await Promise.all(ports.map(async (port) => {
    try {
      return { port, obs: await connect(port) };
    } catch (error) {
      return { port, error: error?.message ?? String(error) };
    }
  }));

  try {
    const responses = await Promise.all(
      clients.map(async (client) => {
        if (!client.obs) {
          return { port: client.port, ok: false, error: client.error };
        }

        try {
          const status = await client.obs.call('GetRecordStatus');
          if (status?.outputActive) {
            return { port: client.port, ok: false, error: 'OBS is already recording.' };
          }

          const response = await client.obs.call('StartRecord');
          return { port: client.port, ok: true, response: response ?? {} };
        } catch (error) {
          return { port: client.port, ok: false, error: error?.message ?? String(error) };
        }
      }),
    );
    console.log(JSON.stringify(responses));
  } finally {
    await Promise.allSettled(clients.filter((client) => client.obs).map((client) => client.obs.disconnect()));
  }
}

async function batchStop(ports) {
  const clients = await Promise.all(ports.map(async (port) => {
    try {
      return { port, obs: await connect(port) };
    } catch (error) {
      return { port, error: error?.message ?? String(error) };
    }
  }));

  try {
    const responses = await Promise.all(
      clients.map(async (client) => {
        if (!client.obs) {
          return { port: client.port, ok: false, error: client.error };
        }

        try {
          const status = await client.obs.call('GetRecordStatus');
          if (!status?.outputActive) {
            return { port: client.port, ok: true, alreadyStopped: true, response: {} };
          }

          const response = await client.obs.call('StopRecord');
          return { port: client.port, ok: true, response: response ?? {} };
        } catch (error) {
          return { port: client.port, ok: false, error: error?.message ?? String(error) };
        }
      }),
    );
    console.log(JSON.stringify(responses));
  } finally {
    await Promise.allSettled(clients.filter((client) => client.obs).map((client) => client.obs.disconnect()));
  }
}

async function main() {
  const command = process.argv[2];

  if (command === 'wait') {
    const port = Number(process.argv[3]);
    const timeoutMs = Number(process.argv[4] ?? '60000');
    await wait(port, timeoutMs);
    return;
  }

  if (command === 'request') {
    const port = Number(process.argv[3]);
    const requestType = process.argv[4];
    const requestData = parseJsonArg(5);
    await request(port, requestType, requestData);
    return;
  }

  if (command === 'batch-start') {
    const ports = process.argv.slice(3).map(Number);
    await batchStart(ports);
    return;
  }

  if (command === 'batch-stop') {
    const ports = process.argv.slice(3).map(Number);
    await batchStop(ports);
    return;
  }

  throw new Error(`Unknown command: ${command}`);
}

main().catch((error) => {
  console.error(error?.stack ?? error?.message ?? String(error));
  process.exit(1);
});
