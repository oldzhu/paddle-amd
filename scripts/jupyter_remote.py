#!/usr/bin/env python3

import argparse
import base64
import http.cookiejar
import json
import os
import re
import shlex
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

import websocket


DEFAULT_SESSION_FILE = os.path.expanduser("~/.cache/paddle-amd/jupyter-remote-session.json")


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def normalize_base_url(url: str) -> str:
    return url.rstrip("/")


class JupyterRemote:
    def __init__(self, session_file: str):
        self.session_path = Path(session_file)
        self.cookie_path = self.session_path.with_suffix(".cookies.txt")
        self.cookie_jar = http.cookiejar.MozillaCookieJar(str(self.cookie_path))
        if self.cookie_path.exists():
            try:
                self.cookie_jar.load(ignore_discard=True, ignore_expires=True)
            except Exception:
                pass
        self.opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(self.cookie_jar))
        self.state = self._load_state()

    def _load_state(self):
        if self.session_path.exists():
            return json.loads(self.session_path.read_text())
        return {}

    def _save_state(self):
        ensure_parent(self.session_path)
        self.session_path.write_text(json.dumps(self.state, indent=2, sort_keys=True))
        ensure_parent(self.cookie_path)
        self.cookie_jar.save(ignore_discard=True, ignore_expires=True)

    def _request(self, method: str, url: str, data=None, headers=None):
        headers = headers or {}
        request = urllib.request.Request(url, data=data, headers=headers, method=method)
        return self.opener.open(request)

    def _auth_headers(self):
        headers = {"Accept": "application/json"}
        token = self.state.get("token")
        xsrf = None
        for cookie in self.cookie_jar:
            if cookie.name == "_xsrf":
                xsrf = cookie.value
                break
        if token:
            headers["Authorization"] = f"token {token}"
        if xsrf:
            headers["X-XSRFToken"] = xsrf
        return headers

    def login_with_token(self, base_url: str, token: str):
        base_url = normalize_base_url(base_url)
        self.state = {"base_url": base_url, "token": token, "auth_mode": "token"}
        self._save_state()
        info = self.get_json("/api")
        return info

    def login_with_password(self, base_url: str, password: str):
        base_url = normalize_base_url(base_url)
        login_url = f"{base_url}/login?next=%2Flab"
        response = self._request("GET", login_url)
        html = response.read().decode("utf-8", errors="replace")
        match = re.search(r'name="_xsrf" value="([^"]+)"', html)
        if not match:
            raise RuntimeError("Could not find _xsrf token on Jupyter login page")
        xsrf = match.group(1)
        form = urllib.parse.urlencode({"_xsrf": xsrf, "password": password}).encode()
        headers = {"Content-Type": "application/x-www-form-urlencoded"}
        self._request("POST", login_url, data=form, headers=headers)
        self.state = {"base_url": base_url, "auth_mode": "password"}
        self._save_state()
        info = self.get_json("/api")
        return info

    def get_json(self, path: str):
        base_url = self.state.get("base_url")
        if not base_url:
            raise RuntimeError("No remote session configured. Run login first.")
        url = f"{base_url}{path}"
        with self._request("GET", url, headers=self._auth_headers()) as response:
            return json.loads(response.read().decode("utf-8"))

    def post_json(self, path: str, payload: dict):
        base_url = self.state.get("base_url")
        if not base_url:
            raise RuntimeError("No remote session configured. Run login first.")
        url = f"{base_url}{path}"
        data = json.dumps(payload).encode("utf-8")
        headers = self._auth_headers()
        headers["Content-Type"] = "application/json"
        with self._request("POST", url, data=data, headers=headers) as response:
            return json.loads(response.read().decode("utf-8"))

    def upload_file(self, local_path: str, remote_path: str):
        local = Path(local_path)
        content = base64.b64encode(local.read_bytes()).decode("ascii")
        payload = {
            "type": "file",
            "format": "base64",
            "content": content,
        }
        base_url = self.state.get("base_url")
        url = f"{base_url}/api/contents/{urllib.parse.quote(remote_path.lstrip('/'))}"
        data = json.dumps(payload).encode("utf-8")
        headers = self._auth_headers()
        headers["Content-Type"] = "application/json"
        with self._request("PUT", url, data=data, headers=headers) as response:
            return json.loads(response.read().decode("utf-8"))

    def websocket_url(self, terminal_name: str):
        base_url = self.state.get("base_url")
        if not base_url:
            raise RuntimeError("No remote session configured. Run login first.")
        ws_base = base_url.replace("http://", "ws://").replace("https://", "wss://")
        url = f"{ws_base}/terminals/websocket/{terminal_name}"
        token = self.state.get("token")
        if token:
            url = f"{url}?token={urllib.parse.quote(token)}"
        return url

    def execute_in_terminal(self,
                            terminal_name: str,
                            command: str,
                            timeout: float = 60.0,
                            use_script_file: bool = False):
        ws = websocket.create_connection(self.websocket_url(terminal_name), timeout=timeout)
        ws.settimeout(timeout)
        marker = f"__PADDLE_AMD_DONE_{uuid.uuid4().hex}__"
        if use_script_file:
            script_path = f"/tmp/paddle_amd_exec_{uuid.uuid4().hex}.sh"
            wrapped = (
                "cat <<'__PADDLE_AMD_REMOTE_SCRIPT__' > "
                + shlex.quote(script_path)
                + "\n"
                + command
                + "\n__PADDLE_AMD_REMOTE_SCRIPT__\n"
                + "bash "
                + shlex.quote(script_path)
                + "\n"
                + "__paddle_amd_status=$?\n"
                + "rm -f "
                + shlex.quote(script_path)
                + "\n"
                + f"printf '\n{marker}:%s\\n' \"$__paddle_amd_status\"\n"
            )
        else:
            wrapped = (
                "bash -lc "
                + shlex.quote(
                    command
                    + "\n"
                    + f"__paddle_amd_status=$?; printf '\\n{marker}:%s\\n' \"$__paddle_amd_status\"\n"
                )
                + "\n"
            )

        output_parts = []
        exit_code = None
        try:
            try:
                first = ws.recv()
                if first:
                    payload = json.loads(first)
                    if payload[0] != "setup":
                        output_parts.append(str(first))
            except Exception:
                pass

            ws.send(json.dumps(["stdin", wrapped]))

            while True:
                raw = ws.recv()
                if raw is None:
                    break
                try:
                    payload = json.loads(raw)
                except Exception:
                    output_parts.append(str(raw))
                    continue

                msg_type = payload[0]
                if msg_type in {"stdout", "stderr"}:
                    output_parts.append(payload[1])
                    combined = "".join(output_parts)
                    match = re.search(re.escape(marker) + r":(\d+)", combined)
                    if match:
                        exit_code = int(match.group(1))
                        combined = re.sub(r"\n?" + re.escape(marker) + r":\d+\n?", "\n", combined)
                        return {
                            "terminal": terminal_name,
                            "exit_code": exit_code,
                            "output": combined.rstrip(),
                        }
                elif msg_type == "disconnect":
                    break
        finally:
            ws.close()

        return {
            "terminal": terminal_name,
            "exit_code": exit_code,
            "output": "".join(output_parts).rstrip(),
        }


def cmd_login(args):
    client = JupyterRemote(args.session_file)
    if args.token:
        info = client.login_with_token(args.url, args.token)
    else:
        info = client.login_with_password(args.url, args.password)
    print(json.dumps(info, indent=2, sort_keys=True))


def cmd_info(args):
    client = JupyterRemote(args.session_file)
    print(json.dumps(client.get_json("/api"), indent=2, sort_keys=True))


def cmd_list_terminals(args):
    client = JupyterRemote(args.session_file)
    print(json.dumps(client.get_json("/api/terminals"), indent=2, sort_keys=True))


def cmd_create_terminal(args):
    client = JupyterRemote(args.session_file)
    payload = {}
    if args.name:
        payload["name"] = args.name
    print(json.dumps(client.post_json("/api/terminals", payload), indent=2, sort_keys=True))


def cmd_list_sessions(args):
    client = JupyterRemote(args.session_file)
    print(json.dumps(client.get_json("/api/sessions"), indent=2, sort_keys=True))


def cmd_upload(args):
    client = JupyterRemote(args.session_file)
    print(json.dumps(client.upload_file(args.local_path, args.remote_path), indent=2, sort_keys=True))


def cmd_exec(args):
    client = JupyterRemote(args.session_file)
    terminal_name = args.terminal
    if not terminal_name:
        terminals = client.get_json("/api/terminals")
        if terminals:
            terminal_name = terminals[0]["name"]
        else:
            created = client.post_json("/api/terminals", {})
            terminal_name = created["name"]

    command = args.command if args.command is not None else Path(args.command_file).read_text()
    result = client.execute_in_terminal(
        terminal_name,
        command,
        timeout=args.timeout,
        use_script_file=args.command_file is not None,
    )
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        if result["output"]:
            print(result["output"])
        print(f"\n[exit_code={result['exit_code']}]")


def build_parser():
    parser = argparse.ArgumentParser(description="Helpers for the remote AMD ROCm Jupyter environment")
    parser.add_argument("--session-file", default=DEFAULT_SESSION_FILE, help="Session metadata file path")
    subparsers = parser.add_subparsers(dest="command", required=True)

    login = subparsers.add_parser("login", help="Authenticate against the Jupyter server")
    login.add_argument("--url", required=True, help="Base Jupyter URL, for example http://host:port")
    auth = login.add_mutually_exclusive_group(required=True)
    auth.add_argument("--token", help="Jupyter token")
    auth.add_argument("--password", help="Jupyter password")
    login.set_defaults(func=cmd_login)

    info = subparsers.add_parser("info", help="Fetch /api info for the active session")
    info.set_defaults(func=cmd_info)

    list_terminals = subparsers.add_parser("list-terminals", help="List remote terminals")
    list_terminals.set_defaults(func=cmd_list_terminals)

    create_terminal = subparsers.add_parser("create-terminal", help="Create a remote terminal")
    create_terminal.add_argument("--name", help="Optional terminal name")
    create_terminal.set_defaults(func=cmd_create_terminal)

    list_sessions = subparsers.add_parser("list-sessions", help="List remote Jupyter sessions")
    list_sessions.set_defaults(func=cmd_list_sessions)

    upload = subparsers.add_parser("upload", help="Upload a local file through the Jupyter contents API")
    upload.add_argument("local_path", help="Local file to upload")
    upload.add_argument("remote_path", help="Remote path relative to the Jupyter contents root")
    upload.set_defaults(func=cmd_upload)

    exec_parser = subparsers.add_parser("exec", help="Execute a command in a remote Jupyter terminal over websocket")
    exec_parser.add_argument("--terminal", help="Remote terminal name; defaults to the first terminal or creates one")
    exec_group = exec_parser.add_mutually_exclusive_group(required=True)
    exec_group.add_argument("--command", help="Command string to execute remotely")
    exec_group.add_argument("--command-file", help="Local file whose contents will be executed remotely")
    exec_parser.add_argument("--timeout", type=float, default=60.0, help="Websocket receive timeout in seconds")
    exec_parser.add_argument("--json", action="store_true", help="Emit JSON instead of plain text")
    exec_parser.set_defaults(func=cmd_exec)

    return parser


def main():
    parser = build_parser()
    args = parser.parse_args()
    try:
        args.func(args)
    except urllib.error.HTTPError as err:
        body = err.read().decode("utf-8", errors="replace")
        print(f"HTTP {err.code}: {body}", file=sys.stderr)
        sys.exit(1)
    except Exception as err:
        print(str(err), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()