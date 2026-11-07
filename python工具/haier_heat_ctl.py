#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""海尔智家 U+ 采暖控制器 (可直接使用)

API 来源: xxxifan/haier_win11_widgets (参考 banto6/haier), 已实测签名通过。

用法:
  python haier_heat_ctl.py login --phone 138xxxxxxxx --password 你的密码
  python haier_heat_ctl.py whoami
  python haier_heat_ctl.py devices
  python haier_heat_ctl.py attrs <deviceId|名称>
  python haier_heat_ctl.py status <deviceId|名称>
  python haier_heat_ctl.py on <设备>
  python haier_heat_ctl.py off <设备>
  python haier_heat_ctl.py set-temp <设备> <温度>
  python haier_heat_ctl.py set <设备> 属性=值 [属性=值 ...]

使用前设置 HAIER_APP_ID / HAIER_APP_KEY 环境变量。
会话保存在 haier_session.json (含 token, 自动续期)。
设备控制走 WebSocket 网关 (pip install websocket-client)。
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import random
import ssl
import sys
import time
import urllib.error
import urllib.request
from urllib.parse import urlparse

# ------------------------------------------------------------------ 配置

APP_ID = os.environ.get("HAIER_APP_ID", "MB-UZHSH-0001")
APP_KEY = os.environ.get("HAIER_APP_KEY", "")

LOGIN_API = "https://zj.haier.net/api-gw/oauthserver/account/v1/login"
REFRESH_API = "https://zj.haier.net/api-gw/oauthserver/account/v1/refreshToken"
USERINFO_API = "https://account-api.haier.net/v2/haier/userinfo"
DEVICES_API = "https://uws.haier.net/uds/v1/protected/deviceinfos"
DIGITAL_MODEL_API = "https://uws.haier.net/shadow/v1/devdigitalmodels"
GATEWAY_API = "https://uws.haier.net/gmsWS/wsag/assign"

SESSION_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "haier_session.json")
SUCCESS = "00000"


# ------------------------------------------------------------------ 签名


def make_sign(app_id, app_key, timestamp, body, url):
    compact = body.replace("\t", "").replace("\r", "").replace("\n", "").replace(" ", "")
    content = urlparse(url).path + compact + app_id + app_key + str(timestamp)
    return hashlib.sha256(content.encode("utf-8")).hexdigest()


def sequence_id():
    return time.strftime("%Y%m%d%H%M%S") + str(random.randint(100000, 999999))


# ------------------------------------------------------------------ HTTP


def http_call(method, url, payload=None, token=""):
    if not APP_ID.strip() or not APP_KEY.strip():
        raise RuntimeError("请先设置 HAIER_APP_ID / HAIER_APP_KEY 环境变量")
    body = ""
    if payload is not None:
        body = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    ts = str(int(time.time() * 1000))
    headers = {
        "accessToken": token,
        "appId": APP_ID,
        "appKey": APP_KEY,
        "clientId": token or "13800000000",
        "sequenceId": sequence_id(),
        "sign": make_sign(APP_ID, APP_KEY, ts, body, url),
        "timestamp": ts,
        "timezone": "+8",
        "language": "zh-CN",
        "Content-Type": "application/json",
    }
    data = body.encode("utf-8") if body else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    ctx = ssl._create_unverified_context()
    try:
        with urllib.request.urlopen(req, timeout=30, context=ctx) as resp:
            content = resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        content = e.read().decode("utf-8", "replace")
    try:
        obj = json.loads(content)
    except json.JSONDecodeError:
        return {"_raw": content}
    rc = obj.get("retCode")
    if rc is not None and rc != SUCCESS:
        raise RuntimeError(f"接口返回 [{rc}]: {obj.get('retInfo')}")
    return obj


# ------------------------------------------------------------------ 会话


def load_session():
    if os.path.exists(SESSION_FILE):
        with open(SESSION_FILE, encoding="utf-8") as f:
            return json.load(f)
    return {}


def save_session(sess):
    with open(SESSION_FILE, "w", encoding="utf-8") as f:
        json.dump(sess, f, ensure_ascii=False, indent=2)


def ensure_token(sess):
    """必要时刷新 token, 返回有效 token。"""
    token = sess.get("accountToken", "")
    expires_at = sess.get("expiresAt", 0)
    if token and time.time() < expires_at - 60:
        return token
    rt = sess.get("refreshToken", "")
    if not rt:
        return token
    try:
        obj = http_call("POST", REFRESH_API, {"refreshToken": rt})
        info = obj["data"]["tokenInfo"]
        sess.update({
            "accountToken": info["accountToken"],
            "refreshToken": info["refreshToken"],
            "expiresAt": int(time.time()) + int(info["expiresIn"]),
        })
        save_session(sess)
        return sess["accountToken"]
    except Exception as e:
        print(f"[warn] 刷新 token 失败: {e}", file=sys.stderr)
        return token


# ------------------------------------------------------------------ 设备


def get_devices(token):
    obj = http_call("GET", DEVICES_API, token=token)
    devs = obj.get("deviceinfos", [])
    devs.sort(key=lambda d: (d.get("deviceName") or d.get("deviceId", "")))
    return devs


def find_device(token, key):
    devs = get_devices(token)
    for d in devs:
        if d.get("deviceId") == key:
            return d
    for d in devs:
        name = d.get("deviceName") or ""
        if key in name or key in (d.get("deviceId") or ""):
            return d
    raise RuntimeError(f"找不到设备: {key}")


def get_model(token, device_id):
    obj = http_call("POST", DIGITAL_MODEL_API, {"deviceInfoList": [{"deviceId": device_id}]}, token=token)
    detail = obj.get("detailInfo") or {}
    model = detail.get(device_id) or {}
    if isinstance(model, str):
        model = json.loads(model)
    return model


def get_snapshot(token, device_id):
    attrs = get_model(token, device_id).get("attributes", [])
    return {a["name"]: a["value"] for a in attrs if "value" in a}


# ------------------------------------------------------------------ 网关控制 (WebSocket)


def ws_control(token, device_id, attrs):
    """经 WebSocket 网关下发控制命令。"""
    try:
        import websocket
    except ImportError:
        raise RuntimeError("需要 WebSocket 库: pip install websocket-client")

    gw = http_call("POST", GATEWAY_API, {"clientId": token, "token": token})
    addr = gw["agAddr"].replace("http://", "wss://").replace("https://", "wss://")
    url = f"{addr}/userag?token={token}&agClientId={token}"

    sn = "".join(random.choice("abcdef1234567890") for _ in range(32))
    msg = {
        "agClientId": token,
        "topic": "BatchCmdReq",
        "content": {
            "trace": sn,
            "sn": sn,
            "data": [{
                "sn": sn, "index": 0, "delaySeconds": 0, "subSn": sn + ":0",
                "deviceId": device_id,
                "cmdArgs": {k: str(v) for k, v in attrs.items()},
            }],
        },
    }

    sslopt = {"cert_reqs": ssl.CERT_NONE}
    ws = websocket.create_connection(url, timeout=15, sslopt=sslopt)
    try:
        ws.send(json.dumps(msg, ensure_ascii=False))
        deadline = time.time() + 12
        while time.time() < deadline:
            try:
                raw = ws.recv()
            except Exception:
                break
            if not raw:
                continue
            resp = json.loads(raw)
            content = resp.get("content") or {}
            sns = set()
            if isinstance(content, dict):
                if content.get("sn"):
                    sns.add(content["sn"])
                for item in content.get("data") or []:
                    if isinstance(item, dict) and item.get("sn"):
                        sns.add(item["sn"])
            if sn in sns and resp.get("topic") != "BatchCmdReq":
                return resp
        return None
    finally:
        try:
            ws.close()
        except Exception:
            pass


# ------------------------------------------------------------------ 命令


def cmd_login(args):
    obj = http_call("POST", LOGIN_API, {"username": args.phone, "password": args.password})
    info = obj["data"]["tokenInfo"]
    sess = {
        "phone": args.phone,
        "accountToken": info["accountToken"],
        "refreshToken": info["refreshToken"],
        "expiresAt": int(time.time()) + int(info["expiresIn"]),
    }
    save_session(sess)
    print("登录成功, token 已保存到", SESSION_FILE)
    return 0


def cmd_whoami(_args):
    sess = load_session()
    token = ensure_token(sess)
    if not token:
        print("未登录, 先执行: login --phone xxx --password xxx", file=sys.stderr)
        return 2
    obj = http_call("GET", USERINFO_API, token=token)
    # userinfo 不走 retCode 包装
    req = urllib.request.Request(USERINFO_API, headers={"Authorization": f"Bearer {token}"})
    ctx = ssl._create_unverified_context()
    with urllib.request.urlopen(req, timeout=20, context=ctx) as resp:
        info = json.loads(resp.read().decode("utf-8", "replace"))
    print(json.dumps({k: v for k, v in info.items() if k in ("userId", "nickname", "phone", "userName")}, ensure_ascii=False, indent=2))
    return 0


def cmd_devices(_args):
    sess = load_session()
    token = ensure_token(sess)
    if not token:
        print("未登录", file=sys.stderr)
        return 2
    for d in get_devices(token):
        status = "在线" if d.get("online") else "离线"
        print(f"{d.get('deviceId','')}  [{status}]  {d.get('deviceName','')}  ({d.get('productCodeT') or d.get('deviceType','')})")
    return 0


def cmd_attrs(args):
    sess = load_session()
    token = ensure_token(sess)
    d = find_device(token, args.device)
    print(f"# {d.get('deviceName')} ({d.get('deviceId')})")
    for a in get_model(token, d["deviceId"]).get("attributes", []):
        rw = "rw" if a.get("write") or a.get("writable") else "ro"
        rng = ""
        if a.get("valueRange"):
            rng = f"  取值:{a['valueRange']}"
        elif a.get("enum") or a.get("enums"):
            rng = f"  可选:{a.get('enum') or a.get('enums')}"
        print(f"  {a.get('name','')} = {a.get('value','')}  ({rw}){rng}")
    return 0


def cmd_status(args):
    sess = load_session()
    token = ensure_token(sess)
    d = find_device(token, args.device)
    snap = get_snapshot(token, d["deviceId"])
    print(f"# {d.get('deviceName')} ({d.get('deviceId')})")
    for k, v in snap.items():
        print(f"  {k} = {v}")
    return 0


def _do_set(args, attrs):
    sess = load_session()
    token = ensure_token(sess)
    d = find_device(token, args.device)
    print(f"下发到 {d.get('deviceName')}: {attrs}")
    resp = ws_control(token, d["deviceId"], attrs)
    print("网关响应:", json.dumps(resp, ensure_ascii=False) if resp else "(超时未收到响应, 命令可能已生效)")
    time.sleep(1)
    snap = get_snapshot(token, d["deviceId"])
    for k in attrs:
        if k in snap:
            print(f"  确认 {k} = {snap[k]}")
    return 0


def cmd_on(args):
    return _do_set(args, {"onOffStatus": "true"})


def cmd_off(args):
    return _do_set(args, {"onOffStatus": "false"})


def cmd_set_temp(args):
    return _do_set(args, {"targetTemperature": str(args.temp)})


def cmd_set(args):
    attrs = {}
    for kv in args.pairs:
        if "=" not in kv:
            print(f"格式错误(应为 属性=值): {kv}", file=sys.stderr)
            return 2
        k, v = kv.split("=", 1)
        attrs[k] = v
    return _do_set(args, attrs)


def cmd_logout(_args):
    if os.path.exists(SESSION_FILE):
        os.remove(SESSION_FILE)
    print("已退出登录")
    return 0


# ------------------------------------------------------------------ 入口


def main():
    p = argparse.ArgumentParser(description="海尔智家 U+ 采暖控制器")
    sub = p.add_subparsers(dest="cmd", required=True)

    lg = sub.add_parser("login", help="手机号+密码登录")
    lg.add_argument("--phone", required=True)
    lg.add_argument("--password", required=True)
    lg.set_defaults(func=cmd_login)

    sub.add_parser("whoami", help="当前账号").set_defaults(func=cmd_whoami)
    sub.add_parser("devices", help="设备列表").set_defaults(func=cmd_devices)
    sub.add_parser("logout", help="退出登录").set_defaults(func=cmd_logout)

    at = sub.add_parser("attrs", help="设备属性")
    at.add_argument("device")
    at.set_defaults(func=cmd_attrs)

    st = sub.add_parser("status", help="设备状态")
    st.add_argument("device")
    st.set_defaults(func=cmd_status)

    for name, fn, help_ in (("on", cmd_on, "开机"), ("off", cmd_off, "关机")):
        c = sub.add_parser(name, help=help_)
        c.add_argument("device")
        c.set_defaults(func=fn)

    tp = sub.add_parser("set-temp", help="设置温度")
    tp.add_argument("device")
    tp.add_argument("temp")
    tp.set_defaults(func=cmd_set_temp)

    se = sub.add_parser("set", help="设置任意属性")
    se.add_argument("device")
    se.add_argument("pairs", nargs="+")
    se.set_defaults(func=cmd_set)

    args = p.parse_args()
    try:
        return args.func(args)
    except Exception as e:
        print(f"[error] {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
