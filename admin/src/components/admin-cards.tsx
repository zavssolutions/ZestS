export function AdminCards() {
  const cards = [
    ["Total Users", "0"],
    ["Active Users Today", "0"],
    ["Total Events", "0"],
    ["Registrations Today", "0"],
  ];

  return (
    <section style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(160px,1fr))", gap: 12 }}>
      {cards.map(([title, value]) => (
        <article key={title} style={{ background: "white", borderRadius: 12, padding: 14 }}>
          <p style={{ margin: 0, color: "#4b5563" }}>{title}</p>
          <h2 style={{ marginBottom: 0 }}>{value}</h2>
        </article>
      ))}
    </section>
  );
}
