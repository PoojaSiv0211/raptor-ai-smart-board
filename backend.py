from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
import os
import base64
import io
import re
import requests

from PIL import Image

app = Flask(__name__)
CORS(app)

# ================================
# STORAGE
# ================================
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PDF_STORAGE = os.path.join(BASE_DIR, "pdf_storage")
DEFAULT_FOLDER = "Default"

os.makedirs(PDF_STORAGE, exist_ok=True)
os.makedirs(os.path.join(PDF_STORAGE, DEFAULT_FOLDER), exist_ok=True)

# ================================
# OCR SPACE CONFIG
# ================================
# Free public test key:
# good for demo/testing
OCR_SPACE_API_KEY = "helloworld"
OCR_SPACE_URL = "https://api.ocr.space/parse/image"

# ================================
# HELPERS
# ================================
def safe_name(name: str) -> str:
    name = (name or "").strip()
    return name.replace("\\", "").replace("/", "").replace("..", "")


def clean_text(text: str) -> str:
    text = (text or "").strip()
    text = re.sub(r"[^A-Za-z0-9\s\-]", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def pick_best_topic(text: str):
    cleaned = clean_text(text)
    if not cleaned:
        return None
    return cleaned


def extract_topic_from_image(image: Image.Image):
    try:
        buffer = io.BytesIO()
        image.save(buffer, format="PNG")
        buffer.seek(0)

        response = requests.post(
            OCR_SPACE_URL,
            files={"filename": ("circle_search.png", buffer, "image/png")},
            data={
                "apikey": OCR_SPACE_API_KEY,
                "language": "eng",
                "isOverlayRequired": "false",
                "OCREngine": "2",
                "scale": "true",
                "detectOrientation": "true",
            },
            timeout=30,
        )

        data = response.json()
        print("OCR SPACE RAW:", data)

        parsed_results = data.get("ParsedResults", [])
        if not parsed_results:
            return None

        texts = []
        for item in parsed_results:
            parsed_text = item.get("ParsedText", "")
            cleaned = clean_text(parsed_text)
            if cleaned:
                texts.append(cleaned)

        if not texts:
            return None

        texts = sorted(set(texts), key=lambda x: (len(x.split()), len(x)))
        print("OCR CANDIDATES:", texts)
        return texts[0]

    except Exception as e:
        print("OCR SPACE ERROR:", e)
        return None


# ================================
# FOLDERS
# ================================
@app.route("/api/folders", methods=["GET"])
def list_folders():
    items = [
        f for f in os.listdir(PDF_STORAGE)
        if os.path.isdir(os.path.join(PDF_STORAGE, f))
    ]

    if DEFAULT_FOLDER not in items:
        os.makedirs(os.path.join(PDF_STORAGE, DEFAULT_FOLDER), exist_ok=True)
        items.append(DEFAULT_FOLDER)

    return jsonify({"folders": sorted(items)})


@app.route("/api/folders", methods=["POST"])
def create_folder():
    data = request.get_json(force=True)
    name = safe_name(data.get("name"))

    if not name:
        return jsonify({"error": "Folder name required"}), 400

    path = os.path.join(PDF_STORAGE, name)

    if os.path.exists(path):
        return jsonify({"error": "Folder already exists"}), 400

    os.makedirs(path)
    return jsonify({"message": "Folder created"})


@app.route("/api/delete-folder", methods=["POST"])
def delete_folder():
    data = request.get_json(force=True)
    name = safe_name(data.get("name"))

    if name == DEFAULT_FOLDER:
        return jsonify({"error": "Default folder cannot be deleted"}), 400

    path = os.path.join(PDF_STORAGE, name)

    if not os.path.exists(path):
        return jsonify({"error": "Folder not found"}), 404

    for f in os.listdir(path):
        os.remove(os.path.join(path, f))

    os.rmdir(path)
    return jsonify({"message": "Folder deleted"})


# ================================
# FILES
# ================================
@app.route("/api/files", methods=["GET"])
def list_files():
    folder = safe_name(request.args.get("folder", DEFAULT_FOLDER))
    path = os.path.join(PDF_STORAGE, folder)

    if not os.path.exists(path):
        return jsonify({"error": "Folder not found"}), 404

    files = [f for f in os.listdir(path) if f.lower().endswith(".pdf")]
    return jsonify({"files": sorted(files)})


@app.route("/api/upload", methods=["POST"])
def upload_file():
    folder = safe_name(request.form.get("folder", DEFAULT_FOLDER))
    path = os.path.join(PDF_STORAGE, folder)
    os.makedirs(path, exist_ok=True)

    if "file" not in request.files:
        return jsonify({"error": "No file"}), 400

    file = request.files["file"]
    name = file.filename

    if not name.lower().endswith(".pdf"):
        return jsonify({"error": "Only PDFs allowed"}), 400

    save_path = os.path.join(path, name)
    file.save(save_path)

    return jsonify({"message": "Uploaded", "filename": name})


@app.route("/api/delete", methods=["POST"])
def delete_file():
    data = request.get_json(force=True)

    folder = safe_name(data.get("folder", DEFAULT_FOLDER))
    filename = safe_name(data.get("filename"))

    path = os.path.join(PDF_STORAGE, folder, filename)

    if not os.path.exists(path):
        return jsonify({"error": "File not found"}), 404

    os.remove(path)
    return jsonify({"message": "File deleted"})


@app.route("/api/open/<folder>/<filename>")
def open_pdf(folder, filename):
    folder = safe_name(folder)
    filename = safe_name(filename)

    path = os.path.join(PDF_STORAGE, folder)
    return send_from_directory(path, filename)


# ================================
# CIRCLE SEARCH
# ================================
@app.route("/circle-search", methods=["POST"])
def circle_search():
    try:
        data = request.get_json(silent=True)

        if not data or "image_base64" not in data:
            return jsonify({"error": "Missing image_base64"}), 400

        image_b64 = data["image_base64"]

        if not isinstance(image_b64, str) or not image_b64.strip():
            return jsonify({"error": "Invalid image_base64"}), 400

        try:
            image_bytes = base64.b64decode(image_b64)
        except Exception:
            return jsonify({"error": "Invalid base64 image"}), 400

        try:
            image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        except Exception:
            return jsonify({"error": "Invalid image data"}), 400

        topic = extract_topic_from_image(image)

        if not topic:
            return jsonify({
                "error": "Could not detect readable text from the selected region."
            }), 422

        return jsonify({"topic": topic}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/")
def home():
    return "Circle Search Backend Running"


if __name__ == "__main__":
    app.run(port=5000, debug=True)