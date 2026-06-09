import SwiftUI

// MARK: - Progress ring

struct RingView: View {
    var progress: Double          // 0...1
    var color: Color
    var lineWidth: CGFloat = 18

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: max(0.0001, min(1, progress)))
                .stroke(color.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: progress)
        }
    }
}

// MARK: - Activity pill

struct ActivityPill: View {
    let activity: Activity
    let isSelected: Bool
    let action: () -> Void

    private var color: Color { Color(hex: activity.colorHex) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: activity.iconName)
                Text(activity.name)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(isSelected ? color.opacity(0.22) : Color.secondary.opacity(0.12))
            )
            .overlay(
                Capsule().stroke(isSelected ? color : .clear, lineWidth: 1.5)
            )
            .foregroundStyle(isSelected ? color : Color.secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat card

struct StatCard: View {
    let title: String
    let value: String
    var systemImage: String? = nil
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title.uppercased())
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)

            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial))
    }
}

// MARK: - Reward / progress bar

struct ProgressBar: View {
    var progress: Double
    var color: Color
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.15))
                Capsule().fill(color.gradient)
                    .frame(width: max(0, min(1, progress)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}
