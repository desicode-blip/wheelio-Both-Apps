"""Private IAM-only image checks. No image/embedding logging or persistence.

One-to-one comparison assists the per-job identity check; it is not liveness,
KYC approval, a hiring decision or permission to transfer money.
"""
import base64
import json
import os
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
os.environ["OPENCV_IO_MAX_IMAGE_PIXELS"] = "16000000"
import cv2
import numpy as np

cv2.setNumThreads(1)
root = Path(__file__).parent / "models"
detector = cv2.FaceDetectorYN.create(str(root / "face_detection_yunet_2023mar.onnx"), "", (320, 320), 0.9, 0.3, 5000)
recognizer = cv2.FaceRecognizerSF.create(str(root / "face_recognition_sface_2021dec.onnx"), "")
lock = threading.Lock()

def decode(value):
    data = base64.b64decode(value, validate=True)
    if len(data) > 8 * 1024 * 1024:
        raise ValueError("Photo exceeds size limit")
    photo = cv2.imdecode(np.frombuffer(data, np.uint8), cv2.IMREAD_COLOR)
    if photo is None or photo.shape[0] * photo.shape[1] > 16_000_000:
        raise ValueError("Unreadable photo")
    if max(photo.shape[:2]) > 1600:
        photo = cv2.resize(photo, None, fx=1600/max(photo.shape[:2]), fy=1600/max(photo.shape[:2]))
    return photo

def quality(photo):
    gray = cv2.cvtColor(photo, cv2.COLOR_BGR2GRAY)
    if min(gray.shape) < 240:
        return "tooSmall"
    if float(gray.mean()) < 25 and float((gray < 25).mean()) > .8:
        return "tooDark"
    if float(gray.var()) < 8:
        return "obscured"
    return None

def feature(photo):
    if quality(photo):
        return None
    detector.setInputSize((photo.shape[1], photo.shape[0]))
    _, faces = detector.detect(photo)
    if faces is None or len(faces) != 1 or min(faces[0][2:4]) < 80:
        return None
    return recognizer.feature(recognizer.alignCrop(photo, faces[0]))

def compare(reference, capture):
    with lock:
        a, b = feature(reference), feature(capture)
        if a is None or b is None:
            return {"status": "retake", "reason": "Show one clearly lit face, close to the camera."}
        similarity = float(recognizer.match(a, b, cv2.FaceRecognizerSF_FR_COSINE))
    # OpenCV's published SFace cosine baseline. Calibrate with consenting real
    # device captures before live operations; uncertain results get human review.
    return {"status": "candidateMatch" if similarity >= .363 else "review", "score": round(similarity, 4), "model": "opencv-sface-2021dec"}

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass  # Never write request bodies, face images or embeddings to logs.

    def respond(self, code, body):
        payload = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        self.respond(200, {"ready": True})

    def do_POST(self):
        try:
            length = int(self.headers.get("Content-Length", 0))
            if not 0 < length <= 24 * 1024 * 1024:
                return self.respond(413, {"error": "Photo request too large"})
            data = json.loads(self.rfile.read(length))
            if self.path == "/compare":
                return self.respond(200, compare(decode(data["reference"]), decode(data["capture"])))
            if self.path == "/quality":
                return self.respond(200, {"issue": quality(decode(data["capture"]))})
            if self.path == "/thumbnail":
                photo = decode(data["capture"])
                if max(photo.shape[:2]) > 960:
                    photo = cv2.resize(photo, None, fx=960/max(photo.shape[:2]), fy=960/max(photo.shape[:2]))
                ok, encoded = cv2.imencode(".jpg", photo, [cv2.IMWRITE_JPEG_QUALITY, 80])
                if not ok:
                    raise ValueError("Unreadable photo")
                return self.respond(200, {"data": base64.b64encode(encoded).decode(), "issue": quality(photo)})
            self.respond(404, {"error": "Unknown check"})
        except (ValueError, KeyError, cv2.error):
            self.respond(400, {"error": "Retake this photo"})
        except Exception:
            self.respond(503, {"error": "Photo check unavailable"})

if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", int(os.environ.get("PORT", "8080"))), Handler).serve_forever()
