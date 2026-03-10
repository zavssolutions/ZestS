"use client";

import { useEffect, useState } from "react";

import { apiGet } from "../../../lib/api";

type User = {
  id: string;
  role: string;
  first_name?: string;
  last_name?: string;
  email?: string;
  mobile_no?: string;
  is_active: boolean;
  is_verified: boolean;
};

export default function UsersPage() {
  const [users, setUsers] = useState<User[]>([]);
  const [search, setSearch] = useState("");
  const [error, setError] = useState<string | null>(null);

  const load = (query?: string) => {
    const param = query ? `?search=${encodeURIComponent(query)}` : "";
    apiGet<User[]>(`/admin/users${param}`)
      .then(setUsers)
      .catch((err) => setError(err.message));
  };

  useEffect(() => {
    load();
  }, []);

  return (
    <section>
      <h1>Users</h1>
      {error && <p style={{ color: "crimson" }}>{error}</p>}
      <div style={{ marginBottom: 12 }}>
        <input
          placeholder="Search users"
          style={{ padding: 8, width: 280 }}
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <button style={{ marginLeft: 8 }} onClick={() => load(search)}>
          Search
        </button>
      </div>
      <table style={{ width: "100%", borderCollapse: "collapse", background: "white" }}>
        <thead>
          <tr>
            <th style={{ textAlign: "left", padding: 10 }}>Name</th>
            <th style={{ textAlign: "left", padding: 10 }}>Role</th>
            <th style={{ textAlign: "left", padding: 10 }}>Email</th>
            <th style={{ textAlign: "left", padding: 10 }}>Phone</th>
            <th style={{ textAlign: "left", padding: 10 }}>Active</th>
          </tr>
        </thead>
        <tbody>
          {users.map((user) => (
            <tr key={user.id}>
              <td style={{ padding: 10 }}>{`${user.first_name ?? ""} ${user.last_name ?? ""}`}</td>
              <td style={{ padding: 10 }}>{user.role}</td>
              <td style={{ padding: 10 }}>{user.email ?? "-"}</td>
              <td style={{ padding: 10 }}>{user.mobile_no ?? "-"}</td>
              <td style={{ padding: 10 }}>{user.is_active ? "Yes" : "No"}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
