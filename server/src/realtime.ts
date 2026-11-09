import type { Server } from 'node:http';
import { WebSocket, WebSocketServer } from 'ws';
import { verifyAccessToken } from './lib/auth.js';
import { newId } from './lib/crypto.js';
import { logger } from './lib/logger.js';

export interface RealtimeEvent {
  id: string;
  type: string;
  version: 1;
  occurredAt: string;
  resource: { type: string; id: string };
  data: Record<string, unknown>;
}

class RealtimeHub {
  private wss: WebSocketServer | null = null;
  private clients = new Map<string, Set<WebSocket>>();
  private heartbeat: NodeJS.Timeout | null = null;

  attach(server: Server) {
    this.wss = new WebSocketServer({ noServer: true });

    server.on('upgrade', (request, socket, head) => {
      const url = new URL(request.url ?? '/', 'http://localhost');
      if (url.pathname !== '/v1/ws') {
        socket.destroy();
        return;
      }
      const token = url.searchParams.get('token') ?? '';
      let userId: string;
      try {
        userId = verifyAccessToken(token).id;
      } catch {
        socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
        socket.destroy();
        return;
      }
      this.wss?.handleUpgrade(request, socket, head, (ws) => {
        this.register(userId, ws);
      });
    });

    this.heartbeat = setInterval(() => {
      for (const sockets of this.clients.values()) {
        for (const ws of sockets) {
          if ((ws as WebSocket & { isAlive?: boolean }).isAlive === false) {
            ws.terminate();
            continue;
          }
          (ws as WebSocket & { isAlive?: boolean }).isAlive = false;
          ws.ping();
        }
      }
    }, 30_000);
    this.heartbeat.unref();

    logger.info('realtime gateway attached');
  }

  private register(userId: string, ws: WebSocket) {
    const sockets = this.clients.get(userId) ?? new Set<WebSocket>();
    sockets.add(ws);
    this.clients.set(userId, sockets);
    (ws as WebSocket & { isAlive?: boolean }).isAlive = true;

    ws.on('pong', () => {
      (ws as WebSocket & { isAlive?: boolean }).isAlive = true;
    });
    ws.on('close', () => {
      sockets.delete(ws);
      if (sockets.size === 0) this.clients.delete(userId);
    });
    // Clients may only subscribe to their own authenticated stream. Room
    // authorization is enforced server-side when events are published.
    ws.send(
      JSON.stringify({
        type: 'connection.ready',
        version: 1,
        occurredAt: new Date().toISOString(),
        data: { userId },
      }),
    );
  }

  publish(userIds: string[], type: string, resource: { type: string; id: string }, data: Record<string, unknown>) {
    const event: RealtimeEvent = {
      id: newId(),
      type,
      version: 1,
      occurredAt: new Date().toISOString(),
      resource,
      data,
    };
    const payload = JSON.stringify(event);
    for (const userId of new Set(userIds)) {
      for (const ws of this.clients.get(userId) ?? []) {
        if (ws.readyState === WebSocket.OPEN) ws.send(payload);
      }
    }
    return event;
  }

  onlineCount() {
    let count = 0;
    for (const sockets of this.clients.values()) count += sockets.size;
    return count;
  }

  close() {
    if (this.heartbeat) clearInterval(this.heartbeat);
    for (const sockets of this.clients.values()) {
      for (const ws of sockets) ws.close(1001, 'server shutting down');
    }
    this.clients.clear();
    this.wss?.close();
    this.wss = null;
  }
}

export const hub = new RealtimeHub();
