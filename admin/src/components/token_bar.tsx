"use client";

import { useEffect, useState } from "react";

export function TokenBar() {
  const [token, setToken] = useState("");

  useEffect(() => {
    const stored = localStorage.getItem("zests_admin_token") ?? "";
    setToken(stored);
  }, []);

  const onSave = () => {
    localStorage.setItem("zests_admin_token", token.trim());
  };

  return (
    <div
      style={{
        display: "flex",
        gap: 12,
        alignItems: "center",
        padding: "12px 16px",
        background: "#ffffff",
        border: "1px solid #e6eef3",
        borderRadius: 8,
        marginBottom: 16,
      }}
    >
      <strong>Admin Token</strong>
      <input
        value={token}
        onChange={(event) => setToken(event.target.value)}
        placeholder="Paste Firebase ID token"
        style={{ flex: 1, padding: 8 }}
      />
      <button onClick={onSave}>Save</button>
    </div>
  );
}
