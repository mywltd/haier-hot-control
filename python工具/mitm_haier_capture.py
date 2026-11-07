# -*- coding: utf-8 -*-
"""mitmproxy addon: 捕获海尔智家 App 的 API 请求, 落盘到 haier_captures/。

用法:
    mitmdump -s mitm_haier_capture.py

过滤域名: zj.haier.net / account-api.haier.net / uws.haier.net /
          appserver.haier.net / uhome.haier.net / gw.haier.net

输出:
    haier_captures/requests.json   全部请求摘要 (path, headers, body)
    haier_captures/tokens.json     自动提取的 token / appKey
"""

from __future__ import annotations

import json
import re
import time
from pathlib import Path

try:
    from mitmproxy import http, ctx
except ImportError:  # pragma: no cover
    raise SystemExit("请先 pip install mitmproxy, 再运行: mitmdump -s mitm_haier_capture.py")

HOST_RE = re.compile(
    r"(zj(?:-yanshou)?\.haier\.net|account-api\.haier\.net|uws\.haier\.net|"
    r"appserver(?:-yanshou)?\.haier\.net|uhome[-\w]*\.haier(?:iot)?\.net|gw\.haier\.net|"
    r"app\.haieruplus\.com|resource\.haier\.net)",
    re.I,
)

TOKEN_KEYS = (
    "accessToken",
    "access_token",
    "refreshToken",
    "refresh_token",
    "accountToken",
    "appKey",
    "app_key",
    "appSecret",
    "app_secret",
    "clientId",
    "client_id",
    "appId",
    "uhome_access_token",
)

OUT_DIR = Path("haier_captures")


class HaierCapture:
    def __init__(self) -> None:
        OUT_DIR.mkdir(exist_ok=True)
        self.req_path = OUT_DIR / "requests.json"
        self.tok_path = OUT_DIR / "tokens.json"
        self.records: list[dict] = []
        self.tokens: dict[str, str] = {}
        if self.tok_path.is_file():
            try:
                self.tokens = json.loads(self.tok_path.read_text(encoding="utf-8"))
            except Exception:
                self.tokens = {}

    def _is_haier(self, flow) -> bool:
        return bool(HOST_RE.search(flow.request.pretty_host or ""))

    def _save(self) -> None:
        self.req_path.write_text(
            json.dumps(self.records, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        self.tok_path.write_text(
            json.dumps(self.tokens, ensure_ascii=False, indent=2), encoding="utf-8"
        )

    def _harvest(self, headers: dict, body_text: str) -> None:
        for k, v in headers.items():
            for key in TOKEN_KEYS:
                if k.lower() == key.lower() and v and v not in ("null", "None"):
                    self.tokens[key] = v
        for key in TOKEN_KEYS:
            for m in re.finditer(rf'"{key}"\s*:\s*"([^"]+)"', body_text):
                self.tokens[key] = m.group(1)

    def request(self, flow) -> None:
        if not self._is_haier(flow):
            return
        req = flow.request
        try:
            body_text = req.get_text(strict=False) or ""
        except Exception:
            body_text = ""
        headers = dict(req.headers)
        self._harvest(headers, body_text)
        rec = {
            "ts": time.time(),
            "method": req.method,
            "host": req.pretty_host,
            "path": req.path,
            "url": req.pretty_url,
            "headers": {k: v for k, v in headers.items() if k.lower() != "cookie"},
            "body": body_text[:20000],
        }
        self.records.append(rec)
        self._save()
        ctx.log.info(f"[haier-capture] {req.method} {req.pretty_url}")

    def response(self, flow) -> None:
        if not self._is_haier(flow):
            return
        try:
            body_text = flow.response.get_text(strict=False) or ""
        except Exception:
            body_text = ""
        self._harvest({}, body_text)
        for rec in reversed(self.records):
            if rec.get("url") == flow.request.pretty_url and "response" not in rec:
                rec["response"] = {
                    "status": flow.response.status_code,
                    "body": body_text[:20000],
                }
                break
        self._save()

    def done(self) -> None:
        self._save()
        ctx.log.info(f"[haier-capture] 完成, 共 {len(self.records)} 条 -> {self.req_path}")


addons = [HaierCapture()]
