export default function ContentPage() {
  return (
    <section>
      <h1>Misc Content</h1>
      <p>Manage About Us, Terms and Conditions, Privacy Policy, and FAQs.</p>
      <div style={{ display: "grid", gap: 12, maxWidth: 700 }}>
        <label>
          About Us
          <textarea rows={6} style={{ width: "100%" }} defaultValue="" />
        </label>
        <label>
          Terms and Conditions
          <textarea rows={6} style={{ width: "100%" }} defaultValue="" />
        </label>
      </div>
    </section>
  );
}
