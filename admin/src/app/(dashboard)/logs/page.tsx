"use client";

import { useEffect, useState } from "react";

import { apiGet } from "../../../lib/api";

type LogEntry = {
  id: string;
  level: string;
  action: string;
  entity_type?: string;
  entity_id?: string;
  created_at: string;
};

export default function LogsPage() {
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    apiGet<LogEntry[]>("/admin/logs")
      .then(setLogs)
      .catch((err) => setError(err.message));
  }, []);

  return (
    <section>
      <h1>Logs</h1>
      {error && <p style={{ color: "crimson" }}>{error}</p>}
      <table style={{ width: "100%", borderCollapse: "collapse", background: "white" }}>
        <thead>
          <tr>
            <th style={{ textAlign: "left", padding: 10 }}>Time</th>
            <th style={{ textAlign: "left", padding: 10 }}>Level</th>
            <th style={{ textAlign: "left", padding: 10 }}>Action</th>
            <th style={{ textAlign: "left", padding: 10 }}>Entity</th>
          </tr>
        </thead>
        <tbody>
          {logs.map((log) => (
            <tr key={log.id}>
              <td style={{ padding: 10 }}>{new Date(log.created_at).toLocaleString()}</td>
              <td style={{ padding: 10 }}>{log.level}</td>
              <td style={{ padding: 10 }}>{log.action}</td>
              <td style={{ padding: 10 }}>{log.entity_type ?? ""}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
