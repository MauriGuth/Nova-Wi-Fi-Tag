#!/usr/bin/env python3
"""Genera la estructura estática de un sticker Nova Wi-Fi Tag por tagId:

    t/<tagId>/index.html          página de fallback (Android / desktop / iPhone sin App Clip)
    t/<tagId>/wifi.mobileconfig   perfil Wi-Fi para iOS
    api/tags/<tagId>.json         credenciales que consume el App Clip

Uso:
    ./gen.py --id casa --name "Wi-Fi de Mauri" --ssid IPLAN-925365-5G --password Huentelaf-1 --security WPA2 --org Mauri
    ./gen.py --id demo --name "Red de prueba Nova" --ssid NovaDemo --password demo-2026-nova

Seguridad: WPA2 (default), WPA2-WPA3, WPA-WPA2 u OPEN (sin clave).
Requiere `segno` o `qrcode` para el QR:  pip3 install segno
"""
import argparse
import html
import io
import json
import plistlib
import sys
import uuid
from pathlib import Path

HOST = "wifi.novasolutions.ar"
ROOT = Path(__file__).resolve().parent

SECURITY = {
    #  valor        mobileconfig EncryptionType   prefijo QR (WIFI:T:...)
    "WPA2":      {"mobileconfig": "WPA2", "qr": "WPA"},
    "WPA2-WPA3": {"mobileconfig": "Any",  "qr": "WPA"},
    "WPA-WPA2":  {"mobileconfig": "Any",  "qr": "WPA"},
    "OPEN":      {"mobileconfig": "None", "qr": "nopass"},
}


def qr_svg(text: str) -> str:
    """SVG inline del QR (misma salida que la página original: segno, borde 2)."""
    try:
        import segno
        qr = segno.make(text, error="m")
        buf = io.BytesIO()
        qr.save(buf, kind="svg", xmldecl=False, svgns=False, svgclass=None, lineclass=None, border=2, omitsize=True, nl=False)
        return buf.getvalue().decode("utf-8")
    except ImportError:
        pass
    try:
        import qrcode
        import qrcode.image.svg
        img = qrcode.make(text, image_factory=qrcode.image.svg.SvgPathImage, border=2)
        return img.to_string().decode("utf-8")
    except ImportError:
        sys.exit("Falta una librería para el QR: pip3 install segno")


def wifi_qr_text(ssid: str, password: str, security: str) -> str:
    def esc(value: str) -> str:
        for ch in '\\;,":':
            value = value.replace(ch, "\\" + ch)
        return value
    kind = SECURITY[security]["qr"]
    if kind == "nopass":
        return f"WIFI:T:nopass;S:{esc(ssid)};;"
    return f"WIFI:T:{kind};S:{esc(ssid)};P:{esc(password)};;"


def stable_uuid(*parts: str) -> str:
    return str(uuid.uuid5(uuid.NAMESPACE_URL, "https://%s/%s" % (HOST, "/".join(parts)))).upper()


def make_mobileconfig(tag_id: str, name: str, ssid: str, password: str, security: str, org: str) -> bytes:
    encryption = SECURITY[security]["mobileconfig"]
    wifi = {
        "AutoJoin": True,
        "EncryptionType": encryption,
        "HIDDEN_NETWORK": False,
        "IsHotspot": False,
        "PayloadDescription": f"Agrega la red Wi-Fi “{ssid}” y se conecta automáticamente.",
        "PayloadDisplayName": f"Red Wi-Fi {ssid}",
        "PayloadIdentifier": f"ar.novasolutions.wifi.{tag_id}.wifi",
        "PayloadOrganization": org,
        "PayloadType": "com.apple.wifi.managed",
        "PayloadUUID": stable_uuid("t", tag_id, "wifi"),
        "PayloadVersion": 1,
        "ProxyType": "None",
        "SSID_STR": ssid,
    }
    if encryption != "None":
        wifi["Password"] = password
    profile = {
        "ConsentText": {
            "default": (
                f"Este perfil solo agrega la red Wi-Fi “{ssid}” a tu iPhone. No instala nada más y puedes "
                "eliminarlo cuando quieras desde Ajustes → General → VPN y gestión de dispositivos."
            )
        },
        "PayloadContent": [wifi],
        "PayloadDescription": f"Instala este perfil para conectarte a la red Wi-Fi “{ssid}” sin escribir la clave.",
        "PayloadDisplayName": name,
        "PayloadIdentifier": f"ar.novasolutions.wifi.{tag_id}",
        "PayloadOrganization": org,
        "PayloadRemovalDisallowed": False,
        "PayloadType": "Configuration",
        "PayloadUUID": stable_uuid("t", tag_id),
        "PayloadVersion": 1,
    }
    return plistlib.dumps(profile, sort_keys=True)


def render_page(template: str, tag_id: str, name: str, ssid: str, password: str, security: str) -> str:
    has_password = SECURITY[security]["qr"] != "nopass"
    data = {"ssid": ssid, "pass": password if has_password else ""}
    # JSON dentro de <script>: escapar < > & para que nunca cierre el script ni rompa el HTML.
    safe_json = (json.dumps(data, ensure_ascii=False)
                 .replace("<", "\\u003c").replace(">", "\\u003e").replace("&", "\\u0026"))
    replacements = {
        "{{TITLE}}": html.escape(name),
        "{{SSID}}": html.escape(ssid),
        "{{PROFILE_HREF}}": f"/t/{tag_id}/wifi.mobileconfig",
        "{{QR_SVG}}": qr_svg(wifi_qr_text(ssid, password, security)),
        "{{DATA_JSON}}": safe_json,
        "{{PASS_ROW_HIDDEN}}": "" if has_password else " hidden",
    }
    page = template
    for key, value in replacements.items():
        page = page.replace(key, value)
    return page


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--id", required=True, help="tagId (letras, números, guion y guion bajo)")
    parser.add_argument("--name", required=True, help='nombre amigable, ej. "Wi-Fi de Mauri"')
    parser.add_argument("--ssid", required=True)
    parser.add_argument("--password", default="", help="clave (vacía para redes OPEN)")
    parser.add_argument("--security", default="WPA2", choices=sorted(SECURITY))
    parser.add_argument("--org", default="Nova Solutions", help="PayloadOrganization del perfil")
    parser.add_argument("--out", default=str(ROOT), help="carpeta raíz del sitio (default: junto a gen.py)")
    args = parser.parse_args()

    tag_id = args.id
    if not tag_id or len(tag_id) > 64 or not all(c.isalnum() and c.isascii() or c in "-_" for c in tag_id):
        sys.exit("tagId inválido: solo letras, números, guion y guion bajo (máx. 64).")
    if args.security != "OPEN" and not (8 <= len(args.password.encode()) <= 63):
        sys.exit("La clave WPA debe tener entre 8 y 63 caracteres (iOS no acepta la PSK de 64 hex).")
    if not (1 <= len(args.ssid.encode()) <= 32):
        sys.exit("El SSID debe tener entre 1 y 32 bytes.")

    out = Path(args.out)
    tag_dir = out / "t" / tag_id
    api_dir = out / "api" / "tags"
    tag_dir.mkdir(parents=True, exist_ok=True)
    api_dir.mkdir(parents=True, exist_ok=True)

    template = (ROOT / "templates" / "page.html").read_text(encoding="utf-8")
    page = render_page(template, tag_id, args.name, args.ssid, args.password, args.security)
    (tag_dir / "index.html").write_text(page, encoding="utf-8")

    profile = make_mobileconfig(tag_id, args.name, args.ssid, args.password, args.security, args.org)
    (tag_dir / "wifi.mobileconfig").write_bytes(profile)

    api = {
        "id": tag_id,
        "name": args.name,
        "ssid": args.ssid,
        "password": args.password if args.security != "OPEN" else "",
        "security": args.security,
    }
    (api_dir / f"{tag_id}.json").write_text(json.dumps(api, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    for path in (tag_dir / "index.html", tag_dir / "wifi.mobileconfig", api_dir / f"{tag_id}.json"):
        print(f"  {path.relative_to(out)}  ({path.stat().st_size} bytes)")
    print(f"URL del sticker:   https://{HOST}/t/{tag_id}")
    print(f"API del App Clip:  https://{HOST}/api/tags/{tag_id}.json")


if __name__ == "__main__":
    main()
