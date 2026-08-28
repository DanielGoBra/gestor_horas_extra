"""Lanzador de demostración: API local + cliente de escritorio.

Doble clic en GestorHorasExtra.exe: arranca el backend en 127.0.0.1:8000,
abre la app Flutter y apaga el servidor al cerrar la ventana.
"""
from __future__ import annotations

import multiprocessing
import os
import socket
import sys
import threading
import time
import traceback
import urllib.error
import urllib.request
from pathlib import Path

PUERTO = 8000
HOST = "127.0.0.1"


def _raiz() -> Path:
    override = os.environ.get("GHE_DEMO_ROOT")
    if override:
        return Path(override)
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent.parent


def _preparar_stdio(log_path: Path) -> None:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    destino = open(log_path, "a", encoding="utf-8")
    if sys.stdout is None:
        sys.stdout = destino
    if sys.stderr is None:
        sys.stderr = destino
    os.environ.setdefault("PYTHONUNBUFFERED", "1")


def _log(mensaje: str) -> None:
    linea = f"{time.strftime('%Y-%m-%d %H:%M:%S')} {mensaje}"
    print(linea, flush=True)


def _aviso(titulo: str, texto: str, error: bool = True) -> None:
    _log(f"{titulo}: {texto}")
    try:
        import ctypes

        ctypes.windll.user32.MessageBoxW(None, texto, titulo, 0x10 if error else 0x40)
    except Exception:
        pass


def _puerto_libre(host: str, puerto: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.settimeout(0.3)
        return sock.connect_ex((host, puerto)) != 0


def _esperar_salud(url: str, intentos: int = 80) -> bool:
    for _ in range(intentos):
        try:
            with urllib.request.urlopen(url, timeout=0.5) as resp:
                if resp.status == 200:
                    return True
        except (urllib.error.URLError, TimeoutError, OSError):
            time.sleep(0.25)
    return False


def _ruta_cliente(raiz: Path) -> Path | None:
    candidatos = [
        raiz / "cliente" / "gestor_horas_extra_client.exe",
        raiz / "desktop_client" / "build" / "windows" / "x64" / "runner" / "Release" / "gestor_horas_extra_client.exe",
    ]
    for ruta in candidatos:
        if ruta.is_file():
            return ruta
    return None


def main() -> int:
    multiprocessing.freeze_support()
    raiz = _raiz()
    datos = raiz / "datos"
    datos.mkdir(parents=True, exist_ok=True)
    _preparar_stdio(datos / "lanzador.log")
    _log(f"inicio raiz={raiz} frozen={getattr(sys, 'frozen', False)}")

    backend = raiz / "backend"
    if backend.is_dir():
        sys.path.insert(0, str(backend))

    db_path = (datos / "gestor_horas_extra.db").resolve()
    os.environ["GHE_DATABASE_URL"] = "sqlite:///" + db_path.as_posix()
    os.environ.setdefault("GHE_JWT_SECRET", "demo-rrhh-no-usar-en-produccion-32b")

    cliente = _ruta_cliente(raiz)
    if cliente is None:
        _aviso(
            "Gestor de Horas Extra",
            "No se encontró el cliente de escritorio (carpeta 'cliente').\n"
            "Vuelva a copiar la carpeta completa de la demo.",
        )
        return 1
    _log(f"cliente={cliente}")

    servidor_propio = False
    server = None
    if not _puerto_libre(HOST, PUERTO):
        if not _esperar_salud(f"http://{HOST}:{PUERTO}/health", intentos=8):
            _aviso(
                "Gestor de Horas Extra",
                f"El puerto {PUERTO} está ocupado por otro programa.\n"
                "Ciérrelo e intente de nuevo.",
            )
            return 1
        _log("reutilizando API ya en ejecución")
    else:
        try:
            import uvicorn

            from app.infra.db import configurar_engine
            from app.main import app

            configurar_engine(os.environ["GHE_DATABASE_URL"])
            config = uvicorn.Config(
                app,
                host=HOST,
                port=PUERTO,
                log_level="warning",
                access_log=False,
                workers=1,
                reload=False,
            )
            server = uvicorn.Server(config)
            hilo = threading.Thread(target=server.run, name="ghe-api", daemon=True)
            hilo.start()
            servidor_propio = True
            _log("hilo de API iniciado")
        except Exception:
            _log(traceback.format_exc())
            _aviso(
                "Gestor de Horas Extra",
                "No se pudo iniciar el servidor local.\n"
                "Revise datos\\lanzador.log junto al ejecutable.",
            )
            return 1

        if not _esperar_salud(f"http://{HOST}:{PUERTO}/health"):
            _log("timeout esperando /health")
            _aviso(
                "Gestor de Horas Extra",
                "El servidor local no respondió a tiempo.\n"
                "Revise datos\\lanzador.log junto al ejecutable.",
            )
            return 1
        _log("API en http://127.0.0.1:8000 lista")

    try:
        import subprocess

        proceso = subprocess.Popen(
            [str(cliente)],
            cwd=str(cliente.parent),
        )
        _log(f"cliente pid={proceso.pid}")
        proceso.wait()
        _log(f"cliente salió con código {proceso.returncode}")
    except OSError as exc:
        _aviso("Gestor de Horas Extra", f"No se pudo abrir la aplicación.\n\n{exc}")
        return 1
    finally:
        if servidor_propio and server is not None:
            server.should_exit = True
            _log("API detenida")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
