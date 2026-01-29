// Simple test server - direct PTY without tmux
// Run with: bun run test-server.ts

interface Session {
  id: string;
  proc: any;
  readers: { stdout?: any; stderr?: any };
}

const sessions: Map<string, Session> = new Map();

function createSession(id: string, name: string): Session {
  const proc = Bun.spawn(["bash", "-i"], {
    stdin: "pipe",
    stdout: "pipe",
    stderr: "pipe",
    env: {
      ...process.env,
      TERM: "xterm-256color",
      COLUMNS: "80",
      LINES: "24",
    },
  });

  const session: Session = { id, proc, readers: {} };
  sessions.set(id, session);
  console.log(`[Session] Created: ${id} (${name})`);
  return session;
}

// Pre-create 3 sessions
createSession("session-1", "Shell 1");
createSession("session-2", "Shell 2");
createSession("session-3", "Shell 3");

const server = Bun.serve({
  port: 4041,
  fetch(req, server) {
    const url = new URL(req.url);

    if (url.pathname === "/ws") {
      const upgraded = server.upgrade(req);
      if (!upgraded) {
        return new Response("WebSocket upgrade failed", { status: 400 });
      }
      return;
    }

    return new Response("Test server running. Connect to /ws");
  },
  websocket: {
    open(ws) {
      console.log("[WS] Client connected");

      (ws as any).activeSessionId = null;
      (ws as any).outputTask = null;

      // Send sessions list
      const sessionList = Array.from(sessions.entries()).map(([id, s], i) => ({
        id,
        displayName: `Shell ${i + 1}`,
        status: "working",
        lastActivity: new Date().toISOString(),
        lastUserMessage: "Direct PTY test",
        currentWindow: null,
        isPinned: false,
      }));

      ws.send(JSON.stringify({
        type: "sessions",
        sessions: sessionList,
      }));
    },

    message(ws, message) {
      try {
        const msg = JSON.parse(message as string);
        console.log("[WS] Received:", msg.type, msg.sessionId || "");

        switch (msg.type) {
          case "terminal-attach": {
            const session = sessions.get(msg.sessionId);
            if (!session) {
              console.log(`[WS] Session not found: ${msg.sessionId}`);
              return;
            }

            // Stop previous output streaming
            const prevTask = (ws as any).outputTask;
            if (prevTask) {
              prevTask.cancelled = true;
            }

            (ws as any).activeSessionId = msg.sessionId;
            console.log(`[WS] Attached to: ${msg.sessionId}`);

            // Send ready
            ws.send(JSON.stringify({
              type: "terminal-ready",
              sessionId: msg.sessionId,
            }));

            // Start streaming output for this session
            const task = { cancelled: false };
            (ws as any).outputTask = task;

            const streamOutput = async (stream: ReadableStream, name: string) => {
              const reader = stream.getReader();
              const decoder = new TextDecoder();
              try {
                while (!task.cancelled) {
                  const { done, value } = await reader.read();
                  if (done || task.cancelled) break;

                  if ((ws as any).activeSessionId === msg.sessionId) {
                    const text = decoder.decode(value);
                    ws.send(JSON.stringify({
                      type: "terminal-output",
                      sessionId: msg.sessionId,
                      data: text,
                    }));
                  }
                }
              } catch (e) {
                // Stream ended
              }
            };

            streamOutput(session.proc.stdout, "stdout");
            streamOutput(session.proc.stderr, "stderr");
            break;
          }

          case "terminal-input": {
            const session = sessions.get(msg.sessionId);
            if (session && session.proc && session.proc.stdin) {
              session.proc.stdin.write(msg.data);
            }
            break;
          }

          case "terminal-resize":
            console.log(`[WS] Resize: ${msg.cols}x${msg.rows}`);
            break;

          case "terminal-detach":
            console.log(`[WS] Detach: ${msg.sessionId}`);
            break;
        }
      } catch (e) {
        console.error("[WS] Error:", e);
      }
    },

    close(ws) {
      console.log("[WS] Client disconnected");
      const task = (ws as any).outputTask;
      if (task) {
        task.cancelled = true;
      }
    },
  },
});

console.log(`Test server running on http://localhost:${server.port}`);
console.log("3 sessions available - direct shell WITHOUT tmux");
