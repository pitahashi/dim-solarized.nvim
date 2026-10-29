"""Deterministic LSP fixture: exercise Neovim's real semantic-token client.

Tokens/legend are supplied by the test via initializationOptions. This is not
an analysis engine; no installed language server or network service is needed.
"""
import json
import sys

options = {}
while True:
    headers = {}
    while True:
        line = sys.stdin.buffer.readline()
        if not line:
            sys.exit(0)
        if line == b"\r\n":
            break
        name, value = line.decode().split(":", 1)
        headers[name.lower()] = value.strip()
    message = json.loads(sys.stdin.buffer.read(int(headers["content-length"])))
    method = message.get("method")
    if method == "exit":
        break
    if "id" not in message:
        continue
    result = None
    if method == "initialize":
        options = message["params"]["initializationOptions"]
        result = {"capabilities": {
            "textDocumentSync": 1,
            "semanticTokensProvider": {"legend": options["legend"], "full": True},
        }}
    elif method == "textDocument/semanticTokens/full":
        result = {"data": options["data"]}
    body = json.dumps({"jsonrpc": "2.0", "id": message["id"], "result": result}).encode()
    sys.stdout.buffer.write(f"Content-Length: {len(body)}\r\n\r\n".encode() + body)
    sys.stdout.buffer.flush()
