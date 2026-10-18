"""Small web service used to demonstrate a DevSecOps pipeline.

It is deliberately boring: the interesting part is everything that checks it.
"""
import os
import re

from flask import Flask, jsonify

app = Flask(__name__)

NAME_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_-]{0,31}$")


# SECURITY-HEADERS-BEGIN
@app.after_request
def add_security_headers(response):
    """Browser-side protections on every response (checked by the DAST stage)."""
    response.headers["Content-Security-Policy"] = (
        "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'"
    )
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Permissions-Policy"] = "geolocation=(), microphone=(), camera=()"
    response.headers["Cache-Control"] = "no-store"
    return response


# SECURITY-HEADERS-END


@app.get("/")
def index():
    return (
        "<!doctype html><html lang='en'><head><meta charset='utf-8'>"
        "<title>DevSecOps demo</title></head>"
        "<body><h1>DevSecOps demo</h1><p>Status: ok</p></body></html>"
    )


@app.get("/healthz")
def healthz():
    return "ok", 200, {"Content-Type": "text/plain"}


@app.get("/api/status")
def status():
    return jsonify(status="ok", version=os.environ.get("APP_VERSION", "dev"))


@app.get("/api/greet/<name>")
def greet(name):
    # Validate input against an allow-list instead of trusting it.
    if not NAME_RE.match(name):
        return jsonify(error="name must be 1-32 letters, digits, '-' or '_'"), 400
    return jsonify(message=f"Hello, {name}!")
