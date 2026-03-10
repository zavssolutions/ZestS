"use client";

import { useEffect, useState } from "react";

import { apiGet } from "../../../lib/api";

type Issue = {
  id: string;
  email?: string;
  message: string;
  status: string;
  created_at: string;
};

export default function SupportPage() {
  const [issues, setIssues] = useState<Issue[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    apiGet<Issue[]>("/admin/support-issues")
      .then(setIssues)
      .catch((err) => setError(err.message));
  }, []);

  return (
    <section>
      <h1>User Issues</h1>
      {error && <p style={{ color: "crimson" }}>{error}</p>}
      <table style={{ width: "100%", borderCollapse: "collapse", background: "white" }}>
        <thead>
          <tr>
            <th style={{ textAlign: "left", padding: 10 }}>Email</th>
            <th style={{ textAlign: "left", padding: 10 }}>Message</th>
            <th style={{ textAlign: "left", padding: 10 }}>Status</th>
          </tr>
        </thead>
        <tbody>
          {issues.map((issue) => (
            <tr key={issue.id}>
              <td style={{ padding: 10 }}>{issue.email ?? ""}</td>
              <td style={{ padding: 10 }}>{issue.message}</td>
              <td style={{ padding: 10 }}>{issue.status}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
