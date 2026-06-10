import SwiftUI

// MARK: - Progress ring

struct RingView: View {
    var progress: Double          // 0...1
    var color: Color
    var lineWidth: CGFloat = 18

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.12), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: max(0.0001, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
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
                    .symbolRenderingMode(.monochrome)
                Text(activity.name.uppercased())
                    .tracking(0.8)
            }
            .font(.sditMono(11))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? color : Color.sditMuted)
            .overlay(
                Rectangle().stroke(isSelected ? color : Color.sditHairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat card

struct StatCard: View {
    let title: String
    let value: String
    var systemImage: String? = nil
    var tint: Color = .sditMarine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .symbolRenderingMode(.monochrome)
                }
                Text(title.uppercased())
                    .tracking(1)
            }
            .font(.sditMono(10))
            .foregroundStyle(Color.sditGold)

            Text(value)
                .font(.sditDisplay(22))
                .foregroundStyle(Color.sditInk)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.sditSurface)
        .overlay(Rectangle().stroke(Color.sditHairline, lineWidth: 1))
    }
}

// MARK: - Reward / progress bar

struct ProgressBar: View {
    var progress: Double
    var color: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(color.opacity(0.12))
                Rectangle().fill(color)
                    .frame(width: max(0, min(1, progress)) * geo.size.width)
                    .animation(.easeInOut(duration: 0.4), value: progress)
            }
        }
        .frame(height: height)
    }
}
