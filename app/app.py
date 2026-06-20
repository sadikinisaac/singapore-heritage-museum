"""
Singapore Heritage Museum - Flask Backend
DevSecOps Capstone Project
"""

import os
import logging
from datetime import datetime
from flask import Flask, jsonify, render_template, request, abort
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_talisman import Talisman

# ── Logging ──────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)


# ── App Factory ───────────────────────────────────────────────────────────────
def create_app():
    app = Flask(__name__)

    # Security headers via Flask-Talisman
    csp = {
        "default-src": "'self'",
        "style-src": ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
        "font-src": ["'self'", "https://fonts.gstatic.com"],
        "script-src": "'self'",
        "img-src": ["'self'", "data:"],
    }
    Talisman(
        app,
        content_security_policy=csp,
        force_https=False,          # set True behind HTTPS in prod
        strict_transport_security=False,
    )

    # Rate limiting
    limiter = Limiter(
        get_remote_address,
        app=app,
        default_limits=["200 per day", "60 per hour"],
        storage_uri="memory://",
    )

    # ── Static exhibit data (simulates a DB) ─────────────────────────────────
    EXHIBITS = [
        {
            "id": 1,
            "name": "Ancient Maritime Trade Routes",
            "era": "14th–17th Century",
            "description": (
                "Explore how Singapore became a vital node in the maritime silk "
                "roads, connecting China, India, and the Arab world."
            ),
            "gallery": "Gallery A",
            "image": "maritime.svg",
        },
        {
            "id": 2,
            "name": "Colonial Singapore",
            "era": "1819–1942",
            "description": (
                "Trace the transformation of a small fishing village into a "
                "bustling British colonial port city under Stamford Raffles."
            ),
            "gallery": "Gallery B",
            "image": "colonial.svg",
        },
        {
            "id": 3,
            "name": "The Japanese Occupation",
            "era": "1942–1945",
            "description": (
                "A sobering look at the Syonan-to years — the resilience, "
                "sacrifice, and stories of those who lived through the darkest "
                "chapter of Singapore's history."
            ),
            "gallery": "Gallery C",
            "image": "occupation.svg",
        },
        {
            "id": 4,
            "name": "Road to Independence",
            "era": "1945–1965",
            "description": (
                "From post-war recovery to merger with Malaysia and finally "
                "independence — witness the birth of a nation."
            ),
            "gallery": "Gallery D",
            "image": "independence.svg",
        },
        {
            "id": 5,
            "name": "Modern Singapore",
            "era": "1965–Present",
            "description": (
                "From third-world to first in a single generation — the economic "
                "miracle, Garden City vision, and Singapore's role in global affairs."
            ),
            "gallery": "Gallery E",
            "image": "modern.svg",
        },
    ]

    EVENTS = [
        {
            "id": 1,
            "title": "Night at the Museum: Peranakan Nights",
            "date": "2025-05-10",
            "time": "7:00 PM – 10:00 PM",
            "description": "An evening of Peranakan culture, cuisine, and storytelling.",
            "price": "SGD 18",
        },
        {
            "id": 2,
            "title": "School Holiday Workshop: Batik Printing",
            "date": "2025-05-24",
            "time": "10:00 AM – 12:00 PM",
            "description": "Hands-on batik printing workshop for children aged 7–14.",
            "price": "SGD 12",
        },
        {
            "id": 3,
            "title": "Public Lecture: Singapore's Maritime Legacy",
            "date": "2025-06-07",
            "time": "2:00 PM – 4:00 PM",
            "description": "Expert talk by Dr. Tan Wei Lin on early trade networks.",
            "price": "Free",
        },
    ]

    # ── Routes ────────────────────────────────────────────────────────────────
    @app.route("/")
    def index():
        logger.info("Home page accessed from %s", request.remote_addr)
        return render_template("index.html")

    @app.route("/health")
    @limiter.exempt
    def health():
        """Health-check endpoint for Docker / load balancers."""
        return jsonify(
            {
                "status": "healthy",
                "service": "singapore-heritage-museum",
                "timestamp": datetime.utcnow().isoformat(),
                "version": os.getenv("APP_VERSION", "1.0.0"),
                "environment": os.getenv("FLASK_ENV", "development"),
            }
        ), 200

    @app.route("/api/exhibits")
    def get_exhibits():
        logger.info("Exhibits list requested")
        return jsonify({"exhibits": EXHIBITS, "total": len(EXHIBITS)})

    @app.route("/api/exhibits/<int:exhibit_id>")
    def get_exhibit(exhibit_id):
        exhibit = next((e for e in EXHIBITS if e["id"] == exhibit_id), None)
        if not exhibit:
            logger.warning("Exhibit %d not found", exhibit_id)
            abort(404)
        return jsonify(exhibit)

    @app.route("/api/events")
    def get_events():
        logger.info("Events list requested")
        return jsonify({"events": EVENTS, "total": len(EVENTS)})

    @app.route("/api/tickets", methods=["POST"])
    @limiter.limit("10 per minute")
    def book_ticket():
        data = request.get_json(silent=True)
        if not data:
            return jsonify({"error": "Invalid JSON body"}), 400

        required = ["name", "email", "event_id", "quantity"]
        missing = [f for f in required if f not in data]
        if missing:
            return jsonify({"error": f"Missing fields: {missing}"}), 422

        # Basic input validation
        if not isinstance(data["quantity"], int) or data["quantity"] < 1:
            return jsonify({"error": "Quantity must be a positive integer"}), 422

        logger.info(
            "Ticket booked: event=%s qty=%s by %s",
            data["event_id"],
            data["quantity"],
            data["email"],
        )
        return jsonify(
            {
                "success": True,
                "booking_ref": f"SGM-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}",
                "message": "Booking confirmed. Check your email for details.",
            }
        ), 201

    # ── Error Handlers ────────────────────────────────────────────────────────
    @app.errorhandler(404)
    def not_found(e):
        return jsonify({"error": "Resource not found"}), 404

    @app.errorhandler(429)
    def rate_limited(e):
        return jsonify({"error": "Too many requests. Please slow down."}), 429

    @app.errorhandler(500)
    def server_error(e):
        logger.error("Internal server error: %s", str(e))
        return jsonify({"error": "Internal server error"}), 500

    return app


app = create_app()

if __name__ == "__main__":
    debug = os.getenv("FLASK_ENV") == "development"
    app.run(
        host="0.0.0.0",  # nosec B104
        port=5000,
        debug=debug,
    )
