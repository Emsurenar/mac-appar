import SwiftUI

struct WaterReminderView: View {
    @Environment(IslandModel.self) private var model
    @State private var drip = false

    var body: some View {
        let goal = model.settings.waterDailyGoal
        let glasses = model.water.glassesToday
        VStack(spacing: 0) {
            Color.clear.frame(height: model.notch.height)
            HStack(spacing: 12) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: drip)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.cyan))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Time for some water")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("\(glasses) of \(goal) glasses today")
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.55))
                }
                .lineLimit(1)
                Spacer(minLength: 0)
                Button("Later") { model.dismissWaterReminder(drank: false) }
                    .buttonStyle(CapsuleButtonStyle())
                Button("Done") { model.dismissWaterReminder(drank: true) }
                    .buttonStyle(CapsuleButtonStyle(isProminent: true))
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
        .padding(.horizontal, model.earRadius)
        .onAppear { drip = true }
    }
}
