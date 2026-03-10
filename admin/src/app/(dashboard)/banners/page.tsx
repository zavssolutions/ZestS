"use client";

import { useEffect, useState } from "react";

import { apiDelete, apiGet, apiPost } from "../../../lib/api";

type Banner = {
  id: string;
  title?: string;
  image_url: string;
  link_url?: string;
  placement: string;
  display_order: number;
  is_active: boolean;
};

export default function BannersPage() {
  const [banners, setBanners] = useState<Banner[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [form, setForm] = useState({
    title: "",
    image_url: "",
    link_url: "",
    placement: "home_top",
    display_order: 0,
  });

  const load = () => {
    apiGet<Banner[]>("/admin/banners")
      .then(setBanners)
      .catch((err) => setError(err.message));
  };

  useEffect(() => {
    load();
  }, []);

  const create = async () => {
    setError(null);
    try {
      await apiPost<Banner>("/admin/banners", {
        ...form,
        display_order: Number(form.display_order),
      });
      setForm({ title: "", image_url: "", link_url: "", placement: "home_top", display_order: 0 });
      load();
    } catch (err) {
      setError((err as Error).message);
    }
  };

  const remove = async (id: string) => {
    setError(null);
    try {
      await apiDelete(`/admin/banners/${id}`);
      load();
    } catch (err) {
      setError((err as Error).message);
    }
  };

  return (
    <section>
      <h1>Banners</h1>
      {error && <p style={{ color: "crimson" }}>{error}</p>}
      <div style={{ background: "white", padding: 16, borderRadius: 8, marginBottom: 16 }}>
        <h3>Create Banner</h3>
        <div style={{ display: "grid", gap: 8, gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))" }}>
          <input
            placeholder="Title"
            value={form.title}
            onChange={(e) => setForm({ ...form, title: e.target.value })}
          />
          <input
            placeholder="Image URL"
            value={form.image_url}
            onChange={(e) => setForm({ ...form, image_url: e.target.value })}
          />
          <input
            placeholder="Link URL"
            value={form.link_url}
            onChange={(e) => setForm({ ...form, link_url: e.target.value })}
          />
          <input
            placeholder="Placement"
            value={form.placement}
            onChange={(e) => setForm({ ...form, placement: e.target.value })}
          />
          <input
            type="number"
            placeholder="Display Order"
            value={form.display_order}
            onChange={(e) => setForm({ ...form, display_order: Number(e.target.value) })}
          />
        </div>
        <button style={{ marginTop: 12 }} onClick={create}>
          Save
        </button>
      </div>

      <table style={{ width: "100%", borderCollapse: "collapse", background: "white" }}>
        <thead>
          <tr>
            <th style={{ textAlign: "left", padding: 10 }}>Title</th>
            <th style={{ textAlign: "left", padding: 10 }}>Placement</th>
            <th style={{ textAlign: "left", padding: 10 }}>Order</th>
            <th style={{ textAlign: "left", padding: 10 }}>Actions</th>
          </tr>
        </thead>
        <tbody>
          {banners.map((banner) => (
            <tr key={banner.id}>
              <td style={{ padding: 10 }}>{banner.title ?? ""}</td>
              <td style={{ padding: 10 }}>{banner.placement}</td>
              <td style={{ padding: 10 }}>{banner.display_order}</td>
              <td style={{ padding: 10 }}>
                <button onClick={() => remove(banner.id)}>Delete</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
