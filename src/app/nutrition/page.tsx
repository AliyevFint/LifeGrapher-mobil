export default function NutritionPage() {
  return (
    <main style={{ minHeight: "100vh", background: "#f5f7ff", padding: 18 }}>
      <div style={{ maxWidth: 420, margin: "0 auto" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 18 }}>
          <h2 style={{ margin: 0 }}>Nutrition</h2>
          <span style={{ background: "#34c9b5", color: "white", borderRadius: 10, padding: "8px 10px", fontSize: 12 }}>Today</span>
        </div>

        <div style={{ background: "white", borderRadius: 22, padding: 18, boxShadow: "0 12px 30px rgba(17,24,39,0.04)" }}>
          <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 16 }}>
            <strong>Calories</strong>
            <span style={{ color: "#34c9b5", fontWeight: 700 }}>1,860 / 2,200</span>
          </div>
          <div style={{ height: 12, background: "#edf2ff", borderRadius: 999, overflow: "hidden" }}>
            <div style={{ width: "85%", height: "100%", background: "linear-gradient(90deg, #34c9b5 0%, #6c63ff 100%)" }} />
          </div>

          <div style={{ marginTop: 18, display: "grid", gap: 12 }}>
            {[
              ["Breakfast", "Oatmeal + berries"],
              ["Lunch", "Salmon bowl"],
              ["Dinner", "Chicken salad"],
            ].map(([meal, info]) => (
              <div key={meal} style={{ background: "#f7f9ff", borderRadius: 16, padding: 14 }}>
                <div style={{ fontSize: 12, color: "#5d6b82" }}>{meal}</div>
                <div style={{ marginTop: 4, fontWeight: 700 }}>{info}</div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </main>
  );
}
