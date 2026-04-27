"""
Unit Tests — Singapore Heritage Museum API
Run: pytest tests/ -v
"""
import json
import pytest
from app.app import create_app


@pytest.fixture()
def client():
    app = create_app()
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c


# ── Health ─────────────────────────────────────────────────────────────────
class TestHealth:
    def test_health_returns_200(self, client):
        res = client.get("/health")
        assert res.status_code == 200

    def test_health_json_structure(self, client):
        data = json.loads(client.get("/health").data)
        assert data["status"] == "healthy"
        assert "timestamp" in data
        assert "version" in data
        assert "environment" in data

    def test_health_service_name(self, client):
        data = json.loads(client.get("/health").data)
        assert data["service"] == "singapore-heritage-museum"


# ── Exhibits ───────────────────────────────────────────────────────────────
class TestExhibits:
    def test_exhibits_list(self, client):
        res = client.get("/api/exhibits")
        assert res.status_code == 200

    def test_exhibits_has_items(self, client):
        data = json.loads(client.get("/api/exhibits").data)
        assert len(data["exhibits"]) > 0
        assert data["total"] == len(data["exhibits"])

    def test_exhibit_fields(self, client):
        data = json.loads(client.get("/api/exhibits").data)
        ex = data["exhibits"][0]
        for field in ("id", "name", "era", "description", "gallery"):
            assert field in ex

    def test_single_exhibit(self, client):
        res = client.get("/api/exhibits/1")
        assert res.status_code == 200
        data = json.loads(res.data)
        assert data["id"] == 1

    def test_exhibit_not_found(self, client):
        res = client.get("/api/exhibits/999")
        assert res.status_code == 404


# ── Events ─────────────────────────────────────────────────────────────────
class TestEvents:
    def test_events_list(self, client):
        res = client.get("/api/events")
        assert res.status_code == 200

    def test_events_has_items(self, client):
        data = json.loads(client.get("/api/events").data)
        assert len(data["events"]) > 0


# ── Ticket Booking ─────────────────────────────────────────────────────────
class TestTickets:
    VALID_PAYLOAD = {
        "name": "Tan Ah Kow",
        "email": "ahkow@example.com",
        "event_id": 1,
        "quantity": 2,
    }

    def test_booking_success(self, client):
        res = client.post(
            "/api/tickets",
            data=json.dumps(self.VALID_PAYLOAD),
            content_type="application/json",
        )
        assert res.status_code == 201
        data = json.loads(res.data)
        assert data["success"] is True
        assert "booking_ref" in data
        assert data["booking_ref"].startswith("SGM-")

    def test_booking_missing_fields(self, client):
        res = client.post(
            "/api/tickets",
            data=json.dumps({"name": "Test"}),
            content_type="application/json",
        )
        assert res.status_code == 422

    def test_booking_invalid_quantity(self, client):
        payload = {**self.VALID_PAYLOAD, "quantity": -1}
        res = client.post(
            "/api/tickets",
            data=json.dumps(payload),
            content_type="application/json",
        )
        assert res.status_code == 422

    def test_booking_no_json_body(self, client):
        res = client.post("/api/tickets", data="not-json",
                          content_type="text/plain")
        assert res.status_code == 400

    def test_booking_zero_quantity(self, client):
        payload = {**self.VALID_PAYLOAD, "quantity": 0}
        res = client.post(
            "/api/tickets",
            data=json.dumps(payload),
            content_type="application/json",
        )
        assert res.status_code == 422


# ── Security Headers ───────────────────────────────────────────────────────
class TestSecurityHeaders:
    def test_csp_header_present(self, client):
        res = client.get("/")
        # Flask-Talisman injects CSP
        assert res.status_code == 200

    def test_404_returns_json(self, client):
        res = client.get("/nonexistent-route")
        assert res.status_code == 404
        data = json.loads(res.data)
        assert "error" in data
