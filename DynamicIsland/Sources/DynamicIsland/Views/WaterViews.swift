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

// MARK: - Tab

/// Today's glasses as a filling ring, a quick +1, and the last week as bars.
struct WaterTab: View {
    @Environment(IslandModel.self) private var model
    @State private var splash = 0

    private let ringSize: CGFloat = 92

    var body: some View {
        let goal = max(model.settings.waterDailyGoal, 1)
        let glasses = model.water.glassesToday
        HStack(spacing: 18) {
            ring(glasses: glasses, goal: goal)
            VStack(alignment: .leading, spacing: 4) {
                Text(headline(glasses: glasses, goal: goal))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text(amount(glasses))
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
                    .contentTransition(.numericText())
                streakLabel(goal: goal)
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Button {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { model.water.drink() }
                        splash += 1
                    } label: {
                        Label("Glass", systemImage: "plus")
                    }
                    .buttonStyle(WaterButtonStyle())
                    .help("Log a glass of water")
                    Button {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { model.water.undoGlass() }
                    } label: {
                        Image(systemName: "arrow.uturn.backward").font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(IslandButtonStyle(diameter: 26))
                    .disabled(glasses == 0)
                    .help("Take back the last glass")
                }
            }
            .lineLimit(1)
            .frame(maxHeight: .infinity)
            Spacer(minLength: 0)
            WeekBars(history: model.water.history(7), goal: goal)
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
        .frame(height: IslandLayout.waterContentHeight)
    }

    private func ring(glasses: Int, goal: Int) -> some View {
        let progress = min(Double(glasses) / Double(goal), 1)
        return ZStack {
            Circle().stroke(.white.opacity(0.1), lineWidth: 9)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(AngularGradient(colors: [Color(red: 0.2, green: 0.55, blue: 1), .cyan, Color(red: 0.55, green: 0.95, blue: 1)],
                                        center: .center, startAngle: .degrees(0), endAngle: .degrees(360 * max(progress, 0.01))),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: .cyan.opacity(progress >= 1 ? 0.6 : 0), radius: 6)
            VStack(spacing: 0) {
                Image(systemName: glasses >= goal ? "checkmark" : "drop.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.cyan)
                    .symbolEffect(.bounce, value: splash)
                    .contentTransition(.symbolEffect(.replace))
                Text("\(glasses)")
                    .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(glasses)))
                Text("of \(goal)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .frame(width: ringSize, height: ringSize)
    }

    private func headline(glasses: Int, goal: Int) -> String {
        switch goal - glasses {
        case ...0: "Goal reached"
        case 1: "1 glass to go"
        case let left: "\(left) glasses to go"
        }
    }

    private func amount(_ glasses: Int) -> String {
        let size = model.settings.waterGlassSize
        let goal = model.settings.waterDailyGoal
        return "\(formatLitres(glasses * size)) of \(formatLitres(goal * size))"
    }

    @ViewBuilder
    private func streakLabel(goal: Int) -> some View {
        let streak = model.water.streak(goal: goal)
        if streak > 0 {
            Label(streak == 1 ? "1 day streak" : "\(streak) day streak", systemImage: "flame.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.orange)
        }
    }
}

/// 1.75 l, or 750 ml below a litre.
func formatLitres(_ millilitres: Int) -> String {
    guard millilitres >= 1000 else { return "\(millilitres) ml" }
    let litres = Double(millilitres) / 1000
    return litres.formatted(.number.precision(.fractionLength(0...2))) + " l"
}

/// The last seven days; a full bar means the goal was reached.
private struct WeekBars: View {
    let history: [(day: Date, glasses: Int)]
    let goal: Int

    private let barHeight: CGFloat = 62

    var body: some View {
        HStack(alignment: .bottom, spacing: 7) {
            ForEach(Array(history.enumerated()), id: \.offset) { index, entry in
                let isToday = index == history.count - 1
                let reached = entry.glasses >= goal
                VStack(spacing: 5) {
                    ZStack(alignment: .bottom) {
                        Capsule().fill(.white.opacity(0.08))
                        Capsule()
                            .fill(reached ? AnyShapeStyle(LinearGradient(colors: [.cyan, Color(red: 0.2, green: 0.55, blue: 1)],
                                                                         startPoint: .top, endPoint: .bottom))
                                          : AnyShapeStyle(Color.cyan.opacity(isToday ? 0.75 : 0.4)))
                            .frame(height: entry.glasses == 0 ? 0 : max(6, barHeight * min(CGFloat(entry.glasses) / CGFloat(goal), 1)))
                    }
                    .frame(width: 9, height: barHeight)
                    Text(entry.day.formatted(.dateTime.weekday(.narrow)))
                        .font(.system(size: 9, weight: isToday ? .bold : .medium))
                        .foregroundStyle(.white.opacity(isToday ? 0.9 : 0.4))
                }
                .help("\(entry.glasses) glasses")
            }
        }
        .padding(.trailing, 4)
    }
}

private struct WaterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 26)
            .background(Capsule().fill(Color.cyan.opacity(configuration.isPressed ? 0.6 : 0.85)))
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
