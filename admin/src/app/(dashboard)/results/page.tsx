"use client";

import { useEffect, useState } from "react";

import { apiDelete, apiGet, apiPost } from "../../../lib/api";

type Result = {
  id: string;
  event_id: string;
  category_id: string;
  user_id: string;
  rank?: number;
  timing_ms?: number;
  points_earned: number;
};

export default function ResultsPage() {
  const [results, setResults] = useState<Result[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [form, setForm] = useState({
    event_id: "",
    category_id: "",
    user_id: "",
    rank: "",
    timing_ms: "",
    points_earned: "0",
  });

  const load = () => {
    apiGet<Result[]>("/admin/event-results")
      .then(setResults)
      .catch((err) => setError(err.message));
  };

  useEffect(() => {
    load();
  }, []);

  const create = async () => {
    setError(null);
    try {
      await apiPost<Result>("/admin/event-results", {
        event_id: form.event_id,
        category_id: form.category_id,
        user_id: form.user_id,
        rank: form.rank ? Number(form.rank) : null,
        timing_ms: form.timing_ms ? Number(form.timing_ms) : null,
        points_earned: Number(form.points_earned || 0),
      });
      setForm({ event_id: "", category_id: "", user_id: "", rank: "", timing_ms: "", points_earned: "0" });
      load();
    } catch (err) {
      setError((err as Error).message);
    }
  };

  const remove = async (id: string) => {
    setError(null);
    try {
      await apiDelete(`/admin/event-results/${id}`);
      load();
    } catch (err) {
      setError((err as Error).message);
    }
  };

  return (
    <section>
      <h1>Event Results</h1>
      {error && <p style={{ color: "crimson" }}>{error}</p>}
      <div style={{ background: "white", padding: 16, borderRadius: 8, marginBottom: 16 }}>
        <h3>Add Result</h3>
        <div style={{ display: "grid", gap: 8, gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))" }}>
          <input
            placeholder="Event ID"
            value={form.event_id}
            onChange={(e) => setForm({ ...form, event_id: e.target.value })}
          />
          <input
            placeholder="Category ID"
            value={form.category_id}
            onChange={(e) => setForm({ ...form, category_id: e.target.value })}
          />
          <input
            placeholder="User ID"
            value={form.user_id}
            onChange={(e) => setForm({ ...form, user_id: e.target.value })}
          />
          <input
            placeholder="Rank"
            value={form.rank}
            onChange={(e) => setForm({ ...form, rank: e.target.value })}
          />
          <input
            placeholder="Timing (ms)"
            value={form.timing_ms}
            onChange={(e) => setForm({ ...form, timing_ms: e.target.value })}
          />
          <input
            placeholder="Points"
            value={form.points_earned}
            onChange={(e) => setForm({ ...form, points_earned: e.target.value })}
          />
        </div>
        <button style={{ marginTop: 12 }} onClick={create}>
          Save
        </button>
      </div>

      <table style={{ width: "100%", borderCollapse: "collapse", background: "white" }}>
        <thead>
          <tr>
            <th style={{ textAlign: "left", padding: 10 }}>Event</th>
            <th style={{ textAlign: "left", padding: 10 }}>User</th>
            <th style={{ textAlign: "left", padding: 10 }}>Rank</th>
            <th style={{ textAlign: "left", padding: 10 }}>Points</th>
            <th style={{ textAlign: "left", padding: 10 }}>Actions</th>
          </tr>
        </thead>
        <tbody>
          {results.map((result) => (
            <tr key={result.id}>
              <td style={{ padding: 10 }}>{result.event_id}</td>
              <td style={{ padding: 10 }}>{result.user_id}</td>
              <td style={{ padding: 10 }}>{result.rank ?? ""}</td>
              <td style={{ padding: 10 }}>{result.points_earned}</td>
              <td style={{ padding: 10 }}>
                <button onClick={() => remove(result.id)}>Delete</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
