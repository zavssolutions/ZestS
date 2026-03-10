export function Sidebar() {
  const nav = [
    ["/", "Dashboard"],
    ["/events", "Events"],
    ["/users", "Users"],
    ["/banners", "Banners"],
    ["/sponsors", "Sponsors"],
    ["/results", "Event Results"],
    ["/support", "User Issues"],
    ["/logs", "Logs"],
    ["/content", "Misc"],
  ];

  return (
    <aside style={{ background: "#06263a", color: "white", padding: 16 }}>
      <h2 style={{ marginTop: 0 }}>ZestS Admin</h2>
      <nav style={{ display: "grid", gap: 10 }}>
        {nav.map(([href, label]) => (
          <a key={href} href={href} style={{ color: "#c8f1ff", textDecoration: "none" }}>
            {label}
          </a>
        ))}
      </nav>
    </aside>
  );
}
