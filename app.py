from flask import Flask

app = Flask(__name__)

@app.route("/")
def hello():
    return "Hello from Flask on GKE 3. Reusable pipeline!"

@app.route("/healthz")
def healthz():
    # Simple health endpoint for K8s probes
    return "ok", 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)