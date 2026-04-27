/* Singapore Heritage Museum — Frontend JS */
"use strict";

// ── Exhibits ─────────────────────────────────────────────────────────
const ICONS = ["⛵", "🏛️", "📜", "🌟", "🦁"];

async function loadExhibits() {
  const grid = document.getElementById("exhibits-grid");
  try {
    const res = await fetch("/api/exhibits");
    if (!res.ok) throw new Error("Network error");
    const { exhibits } = await res.json();

    grid.innerHTML = "";
    exhibits.forEach((ex, i) => {
      const card = document.createElement("article");
      card.className = "exhibit-card";
      card.style.animationDelay = `${i * 0.1}s`;
      card.innerHTML = `
        <div class="exhibit-card__thumb">${ICONS[i % ICONS.length]}</div>
        <div class="exhibit-card__body">
          <div class="exhibit-card__era">${ex.era}</div>
          <h3 class="exhibit-card__name">${ex.name}</h3>
          <p class="exhibit-card__desc">${ex.description}</p>
          <div class="exhibit-card__gallery">${ex.gallery}</div>
        </div>`;
      grid.appendChild(card);
    });
  } catch (err) {
    grid.innerHTML = `<p style="color:var(--muted);grid-column:1/-1">
      Unable to load exhibits at this time.</p>`;
  }
}

// ── Events ───────────────────────────────────────────────────────────
const MONTHS = ["Jan","Feb","Mar","Apr","May","Jun",
                "Jul","Aug","Sep","Oct","Nov","Dec"];

async function loadEvents() {
  const list = document.getElementById("events-list");
  try {
    const res = await fetch("/api/events");
    if (!res.ok) throw new Error("Network error");
    const { events } = await res.json();

    list.innerHTML = "";
    events.forEach((ev, i) => {
      const d = new Date(ev.date);
      const card = document.createElement("article");
      card.className = "event-card";
      card.style.animationDelay = `${i * 0.1}s`;
      card.innerHTML = `
        <div class="event-card__date-box">
          <div class="event-card__day">${d.getDate()}</div>
          <div class="event-card__month">${MONTHS[d.getMonth()]}</div>
        </div>
        <div>
          <h3 class="event-card__title">${ev.title}</h3>
          <p class="event-card__meta">🕐 ${ev.time}</p>
          <p class="event-card__desc">${ev.description}</p>
        </div>
        <div class="event-card__price-col">
          <span class="event-card__price">${ev.price}</span>
          <button class="btn btn--ghost btn--sm book-btn"
                  data-event-id="${ev.id}"
                  data-event-name="${ev.title}">
            Book
          </button>
        </div>`;
      list.appendChild(card);
    });

    document.querySelectorAll(".book-btn").forEach(btn => {
      btn.addEventListener("click", () => openModal(
        btn.dataset.eventId,
        btn.dataset.eventName
      ));
    });
  } catch (err) {
    list.innerHTML = `<p style="color:rgba(237,231,220,0.5);text-align:center">
      Unable to load events at this time.</p>`;
  }
}

// ── Modal ────────────────────────────────────────────────────────────
let currentEventId = null;

function openModal(eventId, eventName) {
  currentEventId = eventId;
  document.getElementById("modal-event-name").textContent = eventName;
  document.getElementById("form-msg").textContent = "";
  document.getElementById("form-msg").className = "form-msg";
  document.getElementById("f-name").value = "";
  document.getElementById("f-email").value = "";
  document.getElementById("f-qty").value = 1;
  document.getElementById("ticket-modal").classList.add("open");
}

function closeModal() {
  document.getElementById("ticket-modal").classList.remove("open");
  currentEventId = null;
}

document.getElementById("modal-close").addEventListener("click", closeModal);
document.getElementById("modal-backdrop").addEventListener("click", closeModal);

document.getElementById("submit-booking").addEventListener("click", async () => {
  const name  = document.getElementById("f-name").value.trim();
  const email = document.getElementById("f-email").value.trim();
  const qty   = parseInt(document.getElementById("f-qty").value, 10);
  const msg   = document.getElementById("form-msg");

  if (!name || !email || !currentEventId) {
    msg.textContent = "Please fill in all fields.";
    msg.className = "form-msg error";
    return;
  }

  try {
    const res = await fetch("/api/tickets", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        name, email, quantity: qty,
        event_id: parseInt(currentEventId, 10),
      }),
    });
    const data = await res.json();
    if (res.ok) {
      msg.textContent = `✓ ${data.message} Ref: ${data.booking_ref}`;
      msg.className = "form-msg success";
      setTimeout(closeModal, 3000);
    } else {
      msg.textContent = data.error || "Booking failed. Please try again.";
      msg.className = "form-msg error";
    }
  } catch {
    msg.textContent = "Network error. Please try again.";
    msg.className = "form-msg error";
  }
});

// ── Health Check ─────────────────────────────────────────────────────
async function checkHealth() {
  const dot = document.getElementById("health-status");
  try {
    const res = await fetch("/health");
    dot.style.color = res.ok ? "#4caf50" : "#f44336";
  } catch {
    dot.style.color = "#f44336";
  }
}

// ── Init ─────────────────────────────────────────────────────────────
document.addEventListener("DOMContentLoaded", () => {
  loadExhibits();
  loadEvents();
  checkHealth();
});
