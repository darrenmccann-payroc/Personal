"""
SFTP Parallel Upload Test
Replicates an SFTP user pattern per file:
  1. Open connection -> ls files -> close
  2. Open connection -> upload file -> close
Runs 10 files in parallel across 100 files, then cleans up
all remote files in a single connection.

Requirements:
    pip install paramiko
"""

import os
import random
import logging
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed

import paramiko

# ── Configuration ─────────────────────────────────────────────
SFTP_HOST     = "vip-ilb-elk-dev-doo-pyrc-ftp-02.payroc.dev"
SFTP_PORT     = 22
SFTP_USER     = "test-user-create"
SFTP_PASSWORD = ""
SFTP_KEY_PATH = "/home/dmccann/.ssh/id_ed25519" # e.g. "/home/you/.ssh/id_rsa"  or None for password auth
REMOTE_DIR    = "/upload/test"

NUM_FILES     = 100
FILE_SIZE_KB  = 10
MAX_WORKERS   = 10
LOCAL_TMP_DIR = "/tmp/sftp_test"
# ─────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(threadName)-10s] %(levelname)-5s %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger(__name__)
print_lock = threading.Lock()


# ── Helpers ───────────────────────────────────────────────────

def load_private_key(path: str) -> paramiko.PKey:
    """Auto-detect and load any supported private key type."""
    for key_class in (
        paramiko.Ed25519Key,
        paramiko.ECDSAKey,
        paramiko.RSAKey,
        paramiko.DSSKey,
    ):
        try:
            return key_class.from_private_key_file(path)
        except paramiko.SSHException:
            continue
    raise ValueError(f"Could not load private key from {path} -- unsupported format")


def new_sftp() -> tuple[paramiko.SFTPClient, paramiko.Transport]:
    """Open a fresh SFTP connection and return (sftp, transport)."""
    transport = paramiko.Transport((SFTP_HOST, SFTP_PORT))
    if SFTP_KEY_PATH:
        key = load_private_key(SFTP_KEY_PATH)
        transport.connect(username=SFTP_USER, pkey=key)
    else:
        transport.connect(username=SFTP_USER, password=SFTP_PASSWORD)
    sftp = paramiko.SFTPClient.from_transport(transport)
    return sftp, transport

def close_sftp(sftp: paramiko.SFTPClient, transport: paramiko.Transport):
    try: sftp.close()
    except Exception: pass
    try: transport.close()
    except Exception: pass


def generate_local_files():
    os.makedirs(LOCAL_TMP_DIR, exist_ok=True)
    log.info("Generating %d local files (%d KB each) in %s ...", NUM_FILES, FILE_SIZE_KB, LOCAL_TMP_DIR)
    for i in range(1, NUM_FILES + 1):
        path = os.path.join(LOCAL_TMP_DIR, f"testfile_{i:04d}.dat")
        with open(path, "wb") as f:
            f.write(os.urandom(FILE_SIZE_KB * 1024))
    log.info("Local files ready.")


def cleanup_local_files():
    for i in range(1, NUM_FILES + 1):
        path = os.path.join(LOCAL_TMP_DIR, f"testfile_{i:04d}.dat")
        try: os.remove(path)
        except FileNotFoundError: pass
    try: os.rmdir(LOCAL_TMP_DIR)
    except OSError: pass
    log.info("Local temp files removed.")


# ── Per-file worker ───────────────────────────────────────────

def process_file(index: int) -> bool:
    filename    = f"testfile_{index:04d}.dat"
    local_path  = os.path.join(LOCAL_TMP_DIR, filename)
    remote_path = f"{REMOTE_DIR}/{filename}"

    # Connection 1: ls
    try:
        sftp, transport = new_sftp()
        listing = sftp.listdir(REMOTE_DIR)
        with print_lock:
            log.info("[%04d] ls  -> %d items in %s", index, len(listing), REMOTE_DIR)
        close_sftp(sftp, transport)
    except Exception as exc:
        log.error("[%04d] ls FAILED: %s", index, exc)
        return False

    # Connection 2: upload
    try:
        sftp, transport = new_sftp()
        sftp.put(local_path, remote_path)
        with print_lock:
            log.info("[%04d] put -> %s uploaded", index, filename)
        close_sftp(sftp, transport)
    except Exception as exc:
        log.error("[%04d] put FAILED: %s", index, exc)
        return False

    return True


# ── Remote cleanup ────────────────────────────────────────────

def remote_cleanup():
    log.info("=== Remote cleanup (single connection) ===")
    sftp, transport = new_sftp()
    deleted = 0
    try:
        for i in range(1, NUM_FILES + 1):
            remote_path = f"{REMOTE_DIR}/testfile_{i:04d}.dat"
            try:
                sftp.remove(remote_path)
                deleted += 1
            except FileNotFoundError:
                log.warning("Cleanup: %s not found (skipped)", remote_path)
            except Exception as exc:
                log.error("Cleanup: could not delete %s -- %s", remote_path, exc)
    finally:
        close_sftp(sftp, transport)
    log.info("=== Cleanup done: %d/%d files deleted ===", deleted, NUM_FILES)


# ── Main ──────────────────────────────────────────────────────

def main():
    generate_local_files()

    log.info("=== Starting parallel uploads (%d workers) ===", MAX_WORKERS)
    success = failure = 0

    with ThreadPoolExecutor(max_workers=MAX_WORKERS, thread_name_prefix="sftp") as pool:
        futures = {pool.submit(process_file, i): i for i in range(1, NUM_FILES + 1)}
        for future in as_completed(futures):
            if future.result():
                success += 1
            else:
                failure += 1

    log.info("=== Upload phase complete: %d succeeded, %d failed ===", success, failure)

    remote_cleanup()
    cleanup_local_files()
    log.info("=== All done ===")


if __name__ == "__main__":
    main()

