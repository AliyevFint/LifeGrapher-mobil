export default function DashboardPage() {
  return (
    <main style={{ minHeight: "100vh", background: "#f5f7ff", padding: 18 }}>
      <div style={{ maxWidth: 420, margin: "0 auto" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 18 }}>
          <div>
            <div style={{ color: "#5d6b82", fontSize: 12 }}>Overview</div>
            <h2 style={{ margin: "6px 0 0", fontSize: 28 }}>Dashboard</h2>
          </div>
          <div style={{ background: "#6c63ff", color: "white", borderRadius: 12, padding: "8px 12px", fontSize: 12 }}>+ Add</div>
        </div>

        <div style={{ display: "grid", gap: 12 }}>
          {[
            ["Nutrition", "86%", "#34c9b5"],
            ["Sleep", "7.4h", "#6c63ff"],
            ["Hydration", "2.1L", "#5fd0ff"],
          ].map(([label, value, color]) => (
            <div key={label} style={{ background: "white", borderRadius: 20, padding: 18, boxShadow: "0 12px 30px rgba(17,24,39,0.04)" }}>
              <div style={{ color: "#5d6b82", fontSize: 12 }}>{label}</div>
              <div style={{ marginTop: 8, display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <strong style={{ fontSize: 26 }}>{value}</strong>
                <span style={{ width: 10, height: 10, borderRadius: "50%", background: color, display: "inline-block" }} />
              </div>
            </div>
          ))}
        </div>
      </div>
    </main>
  );
}
