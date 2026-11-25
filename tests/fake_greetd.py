"""A scripted greetd double for the protocol tests.

It speaks real greetd IPC framing (4-byte native-endian length + JSON)
over a Unix socket, but instead of PAM it follows a fixed script:
create_session -> secret prompt -> (ok | second visible prompt |
auth_error) -> success -> start_session -> success. The double records
every request it received so tests can assert on the exact wire
conversation, including that start_session carries the expected argv.
"""
import json
import socket
import struct
import threading


class FakeGreetd:
    def __init__(self, sock_path, *, mode="ok", password="mate-2026"):
        self.requests = []
        self.sock_path = sock_path
        self.mode = mode
        self.password = password
        self._thread = None
        self._server = None
        self._answers = 0

    def start(self):
        self._server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self._server.bind(str(self.sock_path))
        self._server.listen(1)
        self._thread = threading.Thread(target=self._serve, daemon=True)
        self._thread.start()

    def stop(self):
        if self._server:
            self._server.close()

    def _send(self, conn, obj):
        payload = json.dumps(obj).encode("utf-8")
        conn.sendall(struct.pack("=I", len(payload)) + payload)

    def _recv(self, conn):
        header = self._read_exact(conn, 4)
        if header is None:
            return None
        (length,) = struct.unpack("=I", header)
        payload = self._read_exact(conn, length)
        if payload is None:
            return None
        req = json.loads(payload.decode("utf-8"))
        self.requests.append(req)
        return req

    @staticmethod
    def _read_exact(conn, n):
        buf = b""
        while len(buf) < n:
            chunk = conn.recv(n - len(buf))
            if not chunk:
                return None
            buf += chunk
        return buf

    def _serve(self):
        try:
            conn, _ = self._server.accept()
        except OSError:
            return
        with conn:
            while True:
                req = self._recv(conn)
                if req is None:
                    return
                kind = req.get("type")
                if kind == "create_session":
                    # Real greetd keeps a session "under configuration"
                    # after auth_error until the greeter cancels it; a
                    # second create_session is rejected. Model that so
                    # retry flows must cancel first (seat-verified
                    # against greetd 0.10.3).
                    if getattr(self, "_configured", False):
                        self._send(conn, {
                            "type": "error",
                            "error_type": "error",
                            "description": "a session is already being configured",
                        })
                        continue
                    self._configured = True
                    self._send(conn, {
                        "type": "auth_message",
                        "auth_message_type": "secret",
                        "auth_message": "Password: ",
                    })
                elif kind == "post_auth_message_response":
                    self._answers += 1
                    response = req.get("response")
                    if response != self.password and self.mode != "two-prompts":
                        self._send(conn, {
                            "type": "error",
                            "error_type": "auth_error",
                            "description": "authentication failed (scripted)",
                        })
                    elif self.mode == "two-prompts" and self._answers == 1:
                        self._send(conn, {
                            "type": "auth_message",
                            "auth_message_type": "visible",
                            "auth_message": "One-time code: ",
                        })
                    else:
                        self._send(conn, {"type": "success"})
                elif kind == "start_session":
                    self._configured = False
                    self._send(conn, {"type": "success"})
                elif kind == "cancel_session":
                    self._configured = False
                    self._send(conn, {"type": "success"})
                else:
                    self._send(conn, {
                        "type": "error",
                        "error_type": "error",
                        "description": f"unknown request {kind!r}",
                    })
