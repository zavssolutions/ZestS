import Link from "next/link";

export default function LoginPage() {
  return (
    <main style={{ minHeight: "100vh", display: "grid", placeItems: "center", padding: 16 }}>
      <section
        style={{
          width: "100%",
          maxWidth: 420,
          background: "white",
          borderRadius: 14,
          padding: 24,
          boxShadow: "0 12px 30px rgba(0,0,0,.08)",
        }}
      >
        <h1 style={{ marginTop: 0 }}>Admin Login</h1>
        <p style={{ color: "#4b5563" }}>Use Firebase admin account to continue.</p>
        <button
          style={{
            width: "100%",
            border: "none",
            borderRadius: 10,
            padding: "10px 14px",
            cursor: "pointer",
            background: "#0891b2",
            color: "white",
          }}
        >
          Continue with Google
        </button>
        <p style={{ marginTop: 16, color: "#6b7280" }}>
          Demo access: <Link href="/">open dashboard</Link>
        </p>
      </section>
    </main>
  );
}
