from flask import Flask

app = Flask(__name__)

@app.route("/")
def index():
    return "Hello from Flask on GKE via GitHub Actions 🚀"

if __name__ == "__main__":
    # Flask will listen on all interfaces, port 8080
    app.run(host="0.0.0.0", port=8080)
