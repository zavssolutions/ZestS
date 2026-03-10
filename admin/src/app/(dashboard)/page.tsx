"use client";

import { useEffect, useState } from "react";

import { apiGet } from "../../lib/api";

type Stats = {
  total_users: number;
  active_users_today: number;
  total_events: number;
  registrations_today: number;
  trend: { users_delta: number };
};

export default function DashboardPage() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    apiGet<Stats>("/admin/stats")
      .then(setStats)
      .catch((err) => setError(err.message));
  }, []);

  return (
    <div>
      <h1>Dashboard</h1>
      {error && <p style={{ color: "crimson" }}>{error}</p>}
      {!stats && !error && <p>Loading stats...</p>}
      {stats && (
        <div style={{ display: "grid", gap: 12, gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))" }}>
          <div style={{ background: "white", padding: 16, borderRadius: 8 }}>
            <strong>Total Users</strong>
            <div>{stats.total_users}</div>
          </div>
          <div style={{ background: "white", padding: 16, borderRadius: 8 }}>
            <strong>Active Users Today</strong>
            <div>{stats.active_users_today}</div>
          </div>
          <div style={{ background: "white", padding: 16, borderRadius: 8 }}>
            <strong>Total Events</strong>
            <div>{stats.total_events}</div>
          </div>
          <div style={{ background: "white", padding: 16, borderRadius: 8 }}>
            <strong>Registrations Today</strong>
            <div>{stats.registrations_today}</div>
          </div>
          <div style={{ background: "white", padding: 16, borderRadius: 8 }}>
            <strong>User Trend</strong>
            <div>{stats.trend.users_delta}</div>
          </div>
        </div>
      )}
    </div>
  );
}
