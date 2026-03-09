export default function EventsPage() {
  return (
    <section>
      <h1>Events</h1>
      <p>Add, delete, modify, and publish/cancel upcoming events.</p>
      <table style={{ width: "100%", borderCollapse: "collapse", background: "white" }}>
        <thead>
          <tr>
            <th style={{ textAlign: "left", padding: 10 }}>Title</th>
            <th style={{ textAlign: "left", padding: 10 }}>Status</th>
            <th style={{ textAlign: "left", padding: 10 }}>Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td style={{ padding: 10 }}>Sample Event</td>
            <td style={{ padding: 10 }}>draft</td>
            <td style={{ padding: 10 }}>
              <button>Save</button> <button>Publish</button> <button>Cancel</button>
            </td>
          </tr>
        </tbody>
      </table>
    </section>
  );
}
