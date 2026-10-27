"""Download only pinned, checksum-verified official OpenCV Zoo artifacts."""
import hashlib
import json
from pathlib import Path
from urllib.request import urlopen

root = Path(__file__).parent
(root / "models").mkdir(exist_ok=True)
for model in json.loads((root / "models.json").read_text())["models"]:
    data = urlopen(model["url"], timeout=120).read()
    if hashlib.sha256(data).hexdigest() != model["sha256"]:
        raise RuntimeError("Model checksum mismatch")
    (root / "models" / model["name"]).write_bytes(data)
