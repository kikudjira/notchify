import SwiftUI

// Black pill that extends from the physical notch —
// top corners are square (hidden at screen edge), bottom corners are rounded.
private struct NotchPill: Shape {
    var radius: CGFloat = 8
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = radius
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
                 radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r),
                 radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.closeSubpath()
        return p
    }
}

struct NotchView: View {
    @EnvironmentObject var statusManager: StatusManager

    private var showMascot: Bool {
        switch statusManager.status {
        case .idle, .doneBadge, .errorBadge: return false
        default: return true
        }
    }

    private var badgeText: String? {
        switch statusManager.status {
        case .doneBadge:  return "Done"
        case .errorBadge: return "Error"
        default:          return nil
        }
    }

    private var badgeColor: Color {
        statusManager.status == .doneBadge
            ? Color(red: 0.12, green: 0.78, blue: 0.28)
            : Color(red: 0.95, green: 0.22, blue: 0.12)
    }

    var body: some View {
        ZStack {
            // Badge persists after mascot leaves
            if let text = badgeText {
                Text(text)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(badgeColor.opacity(0.93))
                    )
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.65).combined(with: .opacity),
                            removal:   .opacity
                        )
                    )
            }

            if showMascot {
                CrabView(status: statusManager.status)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.35, dampingFraction: 0.75),
                   value: statusManager.status)
    }
}
