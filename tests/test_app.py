import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "app"))
from app import app  # noqa: E402


class TestApp(unittest.TestCase):
    def setUp(self):
        self.client = app.test_client()

    def test_index_is_html(self):
        resp = self.client.get("/")
        self.assertEqual(resp.status_code, 200)
        self.assertIn("text/html", resp.content_type)

    def test_healthz(self):
        self.assertEqual(self.client.get("/healthz").status_code, 200)

    def test_status_json(self):
        data = self.client.get("/api/status").get_json()
        self.assertEqual(data["status"], "ok")

    def test_greet_valid(self):
        self.assertEqual(self.client.get("/api/greet/Akin").get_json()["message"], "Hello, Akin!")

    def test_greet_rejects_bad_input(self):
        for bad in ("<script>", "a" * 40, "1abc", "a%20b"):
            self.assertEqual(self.client.get(f"/api/greet/{bad}").status_code, 400, bad)

    def test_security_headers_on_every_response(self):
        for path in ("/", "/healthz", "/api/status", "/api/greet/x", "/missing"):
            headers = self.client.get(path).headers
            self.assertIn("default-src 'none'", headers["Content-Security-Policy"], path)
            self.assertEqual(headers["X-Frame-Options"], "DENY", path)
            self.assertEqual(headers["X-Content-Type-Options"], "nosniff", path)


if __name__ == "__main__":
    unittest.main()
