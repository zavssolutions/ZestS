"use client";

import { useEffect, useState } from "react";

import { apiDelete, apiGet, apiPost } from "../../../lib/api";

type Sponsor = {
  id: string;
  name: string;
  logo_url?: string;
  website_url?: string;
  is_active: boolean;
};

export default function SponsorsPage() {
  const [sponsors, setSponsors] = useState<Sponsor[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [form, setForm] = useState({
    name: "",
    logo_url: "",
    website_url: "",
  });

  const load = () => {
    apiGet<Sponsor[]>("/admin/sponsors")
      .then(setSponsors)
      .catch((err) => setError(err.message));
  };

  useEffect(() => {
    load();
  }, []);

  const create = async () => {
    setError(null);
    try {
      await apiPost<Sponsor>("/admin/sponsors", form);
      setForm({ name: "", logo_url: "", website_url: "" });
      load();
    } catch (err) {
      setError((err as Error).message);
    }
  };

  const remove = async (id: string) => {
    setError(null);
    try {
      await apiDelete(`/admin/sponsors/${id}`);
      load();
    } catch (err) {
      setError((err as Error).message);
    }
  };

  return (
    <section>
      <h1>Sponsors</h1>
      {error && <p style={{ color: "crimson" }}>{error}</p>}
      <div style={{ background: "white", padding: 16, borderRadius: 8, marginBottom: 16 }}>
        <h3>Create Sponsor</h3>
        <div style={{ display: "grid", gap: 8, gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))" }}>
          <input
            placeholder="Name"
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
          />
          <input
            placeholder="Logo URL"
            value={form.logo_url}
            onChange={(e) => setForm({ ...form, logo_url: e.target.value })}
          />
          <input
            placeholder="Website URL"
            value={form.website_url}
            onChange={(e) => setForm({ ...form, website_url: e.target.value })}
          />
        </div>
        <button style={{ marginTop: 12 }} onClick={create}>
          Save
        </button>
      </div>

      <table style={{ width: "100%", borderCollapse: "collapse", background: "white" }}>
        <thead>
          <tr>
            <th style={{ textAlign: "left", padding: 10 }}>Name</th>
            <th style={{ textAlign: "left", padding: 10 }}>Website</th>
            <th style={{ textAlign: "left", padding: 10 }}>Actions</th>
          </tr>
        </thead>
        <tbody>
          {sponsors.map((sponsor) => (
            <tr key={sponsor.id}>
              <td style={{ padding: 10 }}>{sponsor.name}</td>
              <td style={{ padding: 10 }}>{sponsor.website_url ?? ""}</td>
              <td style={{ padding: 10 }}>
                <button onClick={() => remove(sponsor.id)}>Delete</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
