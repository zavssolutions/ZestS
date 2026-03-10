"use client";

import { useEffect, useState } from "react";

import { apiDelete, apiGet, apiPost, apiPut } from "../../../lib/api";

type Event = {
  id: string;
  title: string;
  status: string;
  start_at_utc: string;
  end_at_utc: string;
  location_name: string;
  venue_city?: string;
};

type EventCreate = {
  title: string;
  start_at_utc: string;
  end_at_utc: string;
  location_name: string;
  venue_city?: string;
};

export default function EventsPage() {
  const [events, setEvents] = useState<Event[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [form, setForm] = useState<EventCreate>({
    title: "",
    start_at_utc: "",
    end_at_utc: "",
    location_name: "",
    venue_city: "",
  });

  const load = () => {
    apiGet<Event[]>("/admin/events")
      .then(setEvents)
      .catch((err) => setError(err.message));
  };

  useEffect(() => {
    load();
  }, []);

  const onCreate = async () => {
    setError(null);
    try {
      await apiPost<Event>("/events", {
        ...form,
        description: "",
      });
      setForm({ title: "", start_at_utc: "", end_at_utc: "", location_name: "", venue_city: "" });
      load();
    } catch (err) {
      setError((err as Error).message);
    }
  };

  const updateStatus = async (id: string, status: string) => {
    setError(null);
    try {
      await apiPut(`/admin/events/${id}`, { status });
      load();
    } catch (err) {
      setError((err as Error).message);
    }
  };

  const onDelete = async (id: string) => {
    setError(null);
    try {
      await apiDelete(`/admin/events/${id}`);
      load();
    } catch (err) {
      setError((err as Error).message);
    }
  };

  return (
    <section>
      <h1>Events</h1>
      {error && <p style={{ color: "crimson" }}>{error}</p>}

      <div style={{ background: "white", padding: 16, borderRadius: 8, marginBottom: 16 }}>
        <h3>Create Event</h3>
        <div style={{ display: "grid", gap: 8, gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))" }}>
          <input
            placeholder="Title"
            value={form.title}
            onChange={(e) => setForm({ ...form, title: e.target.value })}
          />
          <input
            placeholder="Start UTC (YYYY-MM-DDTHH:MM:SSZ)"
            value={form.start_at_utc}
            onChange={(e) => setForm({ ...form, start_at_utc: e.target.value })}
          />
          <input
            placeholder="End UTC (YYYY-MM-DDTHH:MM:SSZ)"
            value={form.end_at_utc}
            onChange={(e) => setForm({ ...form, end_at_utc: e.target.value })}
          />
          <input
            placeholder="Location"
            value={form.location_name}
            onChange={(e) => setForm({ ...form, location_name: e.target.value })}
          />
          <input
            placeholder="City"
            value={form.venue_city}
            onChange={(e) => setForm({ ...form, venue_city: e.target.value })}
          />
        </div>
        <button style={{ marginTop: 12 }} onClick={onCreate}>
          Save
        </button>
      </div>

      <table style={{ width: "100%", borderCollapse: "collapse", background: "white" }}>
        <thead>
          <tr>
            <th style={{ textAlign: "left", padding: 10 }}>Title</th>
            <th style={{ textAlign: "left", padding: 10 }}>Status</th>
            <th style={{ textAlign: "left", padding: 10 }}>Actions</th>
          </tr>
        </thead>
        <tbody>
          {events.map((event) => (
            <tr key={event.id}>
              <td style={{ padding: 10 }}>{event.title}</td>
              <td style={{ padding: 10 }}>{event.status}</td>
              <td style={{ padding: 10 }}>
                <button onClick={() => updateStatus(event.id, "published")}>Publish</button>{" "}
                <button onClick={() => updateStatus(event.id, "canceled")}>Cancel</button>{" "}
                <button onClick={() => onDelete(event.id)}>Delete</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
