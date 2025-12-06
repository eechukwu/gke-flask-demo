import os
from flask import Flask, jsonify

app = Flask(__name__)

@app.route("/")
def hello():
    # Read config value from ConfigMap (falls back to default if not set)
    app_message = os.getenv("APP_MESSAGE", "Default message from code")
    return f"🎊 SATURDAY NIGHT DEPLOY 🎊 Flask on GKE 4 | {app_message}"

@app.route("/healthz")
def healthz():
    # Simple health endpoint for K8s probes
    return "ok", 200

@app.route("/debug-config")
def debug_config():
    """
    Small helper endpoint for the lab:
    - Shows the APP_MESSAGE value
    - Only indicates whether API_TOKEN is present (does NOT print the token)
    """
    app_message = os.getenv("APP_MESSAGE", "missing")
    has_token = bool(os.getenv("API_TOKEN"))

    return jsonify(
        app_message=app_message,
        has_api_token=has_token,
    ), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)