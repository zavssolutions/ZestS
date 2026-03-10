"use client";

import { useEffect, useState } from "react";

import { apiGet, apiPut } from "../../../lib/api";

type StaticPage = {
  slug: string;
  title: string;
  content: string;
};

export default function ContentPage() {
  const [about, setAbout] = useState("");
  const [terms, setTerms] = useState("");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    apiGet<StaticPage>("/pages/about-us")
      .then((page) => setAbout(page.content))
      .catch((err) => setError(err.message));
    apiGet<StaticPage>("/pages/terms-and-conditions")
      .then((page) => setTerms(page.content))
      .catch((err) => setError(err.message));
  }, []);

  const save = async () => {
    setError(null);
    try {
      await apiPut<StaticPage>("/admin/pages/about-us", {
        slug: "about-us",
        title: "About Us",
        content: about,
      });
      await apiPut<StaticPage>("/admin/pages/terms-and-conditions", {
        slug: "terms-and-conditions",
        title: "Terms and Conditions",
        content: terms,
      });
    } catch (err) {
      setError((err as Error).message);
    }
  };

  return (
    <section>
      <h1>Misc Content</h1>
      {error && <p style={{ color: "crimson" }}>{error}</p>}
      <div style={{ display: "grid", gap: 12, maxWidth: 900 }}>
        <label>
          About Us
          <textarea rows={6} style={{ width: "100%" }} value={about} onChange={(e) => setAbout(e.target.value)} />
        </label>
        <label>
          Terms and Conditions
          <textarea rows={6} style={{ width: "100%" }} value={terms} onChange={(e) => setTerms(e.target.value)} />
        </label>
        <button onClick={save}>Save</button>
      </div>
    </section>
  );
}
