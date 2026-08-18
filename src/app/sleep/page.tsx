export default function SleepPage() {
  return (
    <main style={{ minHeight: "100vh", background: "#f5f7ff", padding: 18 }}>
      <div style={{ maxWidth: 420, margin: "0 auto" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 18 }}>
          <h2 style={{ margin: 0 }}>Sleep</h2>
          <span style={{ background: "#6c63ff", color: "white", borderRadius: 10, padding: "8px 10px", fontSize: 12 }}>7h 40m</span>
        </div>

        <div style={{ background: "white", borderRadius: 22, padding: 18, boxShadow: "0 12px 30px rgba(17,24,39,0.04)" }}>
          <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 14 }}>
            <strong>Sleep score</strong>
            <span style={{ color: "#6c63ff", fontWeight: 700 }}>89</span>
          </div>

          <div style={{ height: 140, borderRadius: 18, background: "linear-gradient(180deg, #eef3ff 0%, #dfe7ff 100%)", position: "relative", overflow: "hidden" }}>
            <div style={{ position: "absolute", left: 20, right: 20, bottom: 18, height: 80, borderRadius: 18, background: "linear-gradient(180deg, #6c63ff 0%, #8f82ff 100%)", opacity: 0.9 }} />
          </div>

          <div style={{ marginTop: 18, display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
            <div style={{ background: "#f7f9ff", borderRadius: 16, padding: 14 }}>
              <div style={{ color: "#5d6b82", fontSize: 12 }}>Bedtime</div>
              <div style={{ marginTop: 6, fontWeight: 700 }}>11:10 PM</div>
            </div>
            <div style={{ background: "#f7f9ff", borderRadius: 16, padding: 14 }}>
              <div style={{ color: "#5d6b82", fontSize: 12 }}>Wake time</div>
              <div style={{ marginTop: 6, fontWeight: 700 }}>6:50 AM</div>
            </div>
          </div>
        </div>
      </div>
    </main>
  );
}
