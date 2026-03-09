import type { ReactNode } from "react";

import { Sidebar } from "../../components/sidebar";

export default function DashboardLayout({ children }: { children: ReactNode }) {
  return (
    <div style={{ display: "grid", gridTemplateColumns: "260px 1fr", minHeight: "100vh" }}>
      <Sidebar />
      <main style={{ padding: 20 }}>{children}</main>
    </div>
  );
}
