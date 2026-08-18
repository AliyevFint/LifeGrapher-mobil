export default function HomePage() {
  return (
    <main style={{
      minHeight: "100vh",
      width: "100%",
      display: "flex",
      justifyContent: "center",
      alignItems: "center",
      background: "linear-gradient(180deg, #eef3ff 0%, #f8f9ff 100%)",
      padding: "28px 16px",
    }}>
      <div style={{
        width: "100%",
        maxWidth: 420,
        borderRadius: 28,
        background: "rgba(255,255,255,0.75)",
        boxShadow: "0 20px 50px rgba(17,24,39,0.08)",
        border: "1px solid rgba(108,99,255,0.12)",
        overflow: "hidden",
      }}>
        <div style={{
          background: "linear-gradient(135deg, #6c63ff 0%, #37b5a6 100%)",
          color: "white",
          padding: "24px 20px 18px",
        }}>
          <div style={{ fontSize: 12, opacity: 0.8, marginBottom: 8 }}>Good morning</div>
          <h1 style={{ margin: 0, fontSize: 28 }}>LifeGrapher</h1>
          <div style={{ marginTop: 18, display: "flex", justifyContent: "space-between" }}>
            <div>
              <div style={{ fontSize: 12, opacity: 0.8 }}>Today</div>
              <strong style={{ fontSize: 22 }}>2,340</strong>
            </div>
            <div>
              <div style={{ fontSize: 12, opacity: 0.8 }}>Steps</div>
              <strong style={{ fontSize: 22 }}>8.4k</strong>
            </div>
          </div>
        </div>

        <div style={{ padding: 20 }}>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12, marginBottom: 18 }}>
            {[
              ["Nutrition", "1,860 kcal"],
              ["Sleep", "7h 40m"],
            ].map(([label, value]) => (
              <div key={label} style={{
                background: "#f7f9ff",
                borderRadius: 18,
                padding: 14,
                border: "1px solid rgba(108,99,255,0.08)",
              }}>
                <div style={{ fontSize: 12, color: "#5d6b82" }}>{label}</div>
                <div style={{ marginTop: 8, fontWeight: 700 }}>{value}</div>
              </div>
            ))}
          </div>

          <div style={{
            background: "#f7f9ff",
            borderRadius: 18,
            padding: 16,
            marginBottom: 18,
          }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 10 }}>
              <strong>Focus today</strong>
              <span style={{ color: "#34c9b5", fontWeight: 700 }}>3 tasks</span>
            </div>
            <ul style={{ margin: 0, paddingLeft: 18, color: "#132238", lineHeight: 1.8 }}>
              <li>Drink 2L water</li>
              <li>Walk 30 minutes</li>
              <li>Review nutrition plan</li>
            </ul>
          </div>

          <div style={{
            display: "grid",
            gridTemplateColumns: "repeat(3, minmax(0, 1fr))",
            gap: 12,
          }}>
            {[
              ["Home", "🏠"],
              ["Track", "📊"],
              ["Profile", "👤"],
            ].map(([label, icon]) => (
              <button key={label} style={{
                border: "0",
                borderRadius: 16,
                background: "#ffffff",
                padding: "12px 8px",
                boxShadow: "0 8px 20px rgba(17,24,39,0.04)",
                fontWeight: 700,
                color: "#132238",
              }}>
                <div style={{ fontSize: 22 }}>{icon}</div>
                <div style={{ marginTop: 6, fontSize: 12 }}>{label}</div>
              </button>
            ))}
          </div>
        </div>
      </div>
    </main>
  );
}
