import SwiftUI

// Canvas: 20 × 12 pixel units, ps = 3.0 pts each → 60 × 36 pt total.
// Mascot body: bx=6, by=2 (8 wide × 5 tall body + 2 tall legs)
//
//  Claude Code mascot shape:
//  row 0:  . . X X X X . .   ← rounded top
//  row 1:  X X X X X X X X   ← body upper
//  row 2:  X ● ● X X ● ● X   ← face  (● = 2-wide dark eye)
//  row 3:  X X X X X X X X   ← belly
//  row 4:  X X X X X X X X   ← belly bottom
//  row 5:  . X . X . X . X   ← legs (offsets 1,3,5,7)
//  row 6:  . X . X . X . X
//
//  Arms extend from sides: left at bx-2..bx-1, right at bx+8..bx+9
//
//  Pickaxe (working, right side, cols ≤ 19):
//  frame 0  rest      — hangs vertically below arm
//  frame 1  raised    — diagonal NE, head at top-right
//  frame 2  mid-swing — horizontal, head is vertical T at col 19
//  frame 3  impact    — diagonal down, head horizontal at bottom + dust
//
//  Zzz (waiting / sleep):
//  3×3 Z glyphs float up-right in 4-frame cycle

// MARK: - Working animation from PNG sprite sheet

private struct WorkingAnimationView: View {
    @State private var frame = 0
    private let frameNames = ["work_0", "work_1", "work_2"]

    var body: some View {
        let name = frameNames[frame]
        Group {
            if let url = Bundle.module.url(forResource: name, withExtension: "png"),
               let nsImg = NSImage(contentsOf: url) {
                Image(nsImage: nsImg)
                    .interpolation(.none)
            } else {
                Color.clear.frame(width: 32, height: 24)
            }
        }
        .onReceive(
            Timer.publish(every: 0.20, on: .main, in: .common).autoconnect()
        ) { _ in
            frame = (frame + 1) % frameNames.count
        }
    }
}

// MARK: - Start animation: plays once on launch, freezes on last frame

private struct StartAnimationView: View {
    let agentID: String
    @State private var frame = 0

    // Load however many start_XX.png frames exist in the bundle
    private let frameNames: [String] = {
        var names: [String] = []
        for i in 0...99 {
            let name = String(format: "start_%02d", i)
            if Bundle.module.url(forResource: name, withExtension: "png") != nil {
                names.append(name)
            } else {
                break
            }
        }
        return names
    }()

    var body: some View {
        let name = frameNames.isEmpty ? "" : frameNames[frame]
        Group {
            if !name.isEmpty,
               let url = Bundle.module.url(forResource: name, withExtension: "png"),
               let nsImg = NSImage(contentsOf: url) {
                Image(nsImage: nsImg)
                    .interpolation(.none)
            } else {
                Color.clear.frame(width: 32, height: 24)
            }
        }
        .onReceive(
            Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()
        ) { _ in
            if frame < frameNames.count - 1 {
                frame += 1
            } else {
                StatusManager.shared.markStartDone(agentID: agentID)
            }
        }
    }
}

// MARK: - Bye animation: plays once, then goes idle

private struct ByeAnimationView: View {
    let agentID: String
    @State private var frame = 0
    @State private var done = false

    private let frameNames: [String] = {
        var names: [String] = []
        for i in 0...99 {
            let name = String(format: "bye_%02d", i)
            if Bundle.module.url(forResource: name, withExtension: "png") != nil {
                names.append(name)
            } else {
                break
            }
        }
        return names
    }()

    var body: some View {
        let name = (frameNames.isEmpty || done) ? "" : frameNames[frame]
        Group {
            if !name.isEmpty,
               let url = Bundle.module.url(forResource: name, withExtension: "png"),
               let nsImg = NSImage(contentsOf: url) {
                Image(nsImage: nsImg)
                    .interpolation(.none)
            } else {
                Color.clear.frame(width: 32, height: 24)
            }
        }
        .onAppear {
            // If no bye frames exist, skip straight to idle so start animation
            // is guaranteed a fresh CrabView on the next launch.
            if frameNames.isEmpty {
                StatusManager.shared.removeAgent(id: agentID)
            }
        }
        .onReceive(
            Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()
        ) { _ in
            guard !done, !frameNames.isEmpty else { return }
            if frame < frameNames.count - 1 {
                frame += 1
            } else {
                done = true
                StatusManager.shared.removeAgent(id: agentID)
            }
        }
    }
}

// MARK: - Done animation: plays once, freezes on last frame

private struct DoneAnimationView: View {
    @State private var frame = 0
    private let frameNames: [String] = (0...3).map { String(format: "done_%02d", $0) }

    var body: some View {
        let name = frameNames[frame]
        Group {
            if let url = Bundle.module.url(forResource: name, withExtension: "png"),
               let nsImg = NSImage(contentsOf: url) {
                Image(nsImage: nsImg)
                    .interpolation(.none)
            } else {
                Color.clear.frame(width: 32, height: 24)
            }
        }
        .onReceive(
            Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()
        ) { _ in
            // Advance only while not on the last frame
            if frame < frameNames.count - 1 {
                frame += 1
            }
        }
    }
}

// MARK: - Waiting animation: intro (frames 0-3) plays once, then frames 4-9 loop

private struct WaitingAnimationView: View {
    @State private var frame = 0
    private let totalFrames = 8
    private let loopStart   = 4    // first 4 are intro, last 4 loop
    private let frameNames: [String] = (0...7).map { String(format: "wait_%02d", $0) }

    var body: some View {
        let name = frameNames[frame]
        Group {
            if let url = Bundle.module.url(forResource: name, withExtension: "png"),
               let nsImg = NSImage(contentsOf: url) {
                Image(nsImage: nsImg)
                    .interpolation(.none)
            } else {
                Color.clear.frame(width: 32, height: 24)
            }
        }
        .onReceive(
            Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()
        ) { _ in
            if frame < totalFrames - 1 {
                frame += 1
            } else {
                frame = loopStart   // loop back to start of loop section
            }
        }
    }
}

// MARK: - Main mascot view

struct CrabView: View {
    let status: ClaudeStatus
    let agentID: String
    @State private var frame: Int = 0

    private let ps: CGFloat     = 3.0
    private let canvasCols: Int = 20
    private let canvasRows: Int = 12

    var body: some View {
        if status == .start {
            StartAnimationView(agentID: agentID)
        } else if status == .bye {
            ByeAnimationView(agentID: agentID)
        } else if status == .working {
            WorkingAnimationView()
        } else if status == .done {
            DoneAnimationView()
        } else if status == .waiting {
            WaitingAnimationView()
        } else {
            Canvas { ctx, _ in
                drawAll(ctx: ctx, f: frame)
            }
            .frame(width:  CGFloat(canvasCols) * ps,
                   height: CGFloat(canvasRows) * ps)
            .onReceive(
                Timer.publish(every: frameDuration, on: .main, in: .common).autoconnect()
            ) { _ in
                frame = (frame + 1) % totalFrames
            }
        }
    }

    private var totalFrames: Int {
        switch status {
        case .idle, .doneBadge, .errorBadge: return 1
        case .start, .bye: return 1
        case .working: return 3
        case .waiting: return 4
        case .done:    return 2
        case .error:   return 4
        }
    }

    private var frameDuration: TimeInterval {
        switch status {
        case .working: return 0.20
        case .waiting: return 0.60
        case .error:   return 0.12
        case .done:    return 0.50
        default:       return 1.0
        }
    }

    // MARK: - Dispatch

    private func drawAll(ctx: GraphicsContext, f: Int) {
        let salmon = Color(red: 0.91, green: 0.56, blue: 0.47)
        let dark   = Color(red: 0.13, green: 0.08, blue: 0.06)
        let pick   = Color(white: 0.88)                          // pickaxe
        let yellow = Color(red: 1.0,  green: 0.90, blue: 0.20)  // Zzz
        let green  = Color(red: 0.15, green: 0.90, blue: 0.30)  // sparkles
        let red    = Color(red: 1.0,  green: 0.22, blue: 0.12)  // error tint

        let bx = 6, by = 2

        switch status {
        case .idle, .doneBadge, .errorBadge:
            break   // window hidden for these states
        case .start, .bye:
            break   // handled by StartAnimationView / ByeAnimationView

        case .working:
            drawBody(ctx, bx: bx, by: by, salmon: salmon, dark: dark)
            workingAnimation(ctx, bx: bx, by: by, f: f, salmon: salmon, pick: pick)

        case .waiting:
            drawBody(ctx, bx: bx, by: by, salmon: salmon, dark: dark, asleep: true)
            sleepZzz(ctx, bx: bx, by: by, f: f, c: yellow)

        case .done:
            drawBody(ctx, bx: bx, by: by, salmon: salmon, dark: dark)
            doneAnimation(ctx, bx: bx, by: by, f: f, salmon: salmon, green: green)

        case .error:
            let offsets = [-1, 0, 1, 0]
            let dx = offsets[f % 4]
            drawBody(ctx, bx: bx + dx, by: by, salmon: red.opacity(0.88), dark: dark)
        }
    }

    // MARK: - Body

    private func drawBody(_ ctx: GraphicsContext, bx: Int, by: Int,
                          salmon: Color, dark: Color, asleep: Bool = false) {
        let s = salmon, d = dark
        // Rounded top (6 wide, inset 1 each side)
        for c in 2...5 { drawPixel(ctx, bx+c, by, s) }
        // Full-width body
        for c in 0...7 { drawPixel(ctx, bx+c, by+1, s) }
        // Face row
        for c in 0...7 {
            if asleep {
                // Closed / squinting eyes: single centre pixel per eye
                let closed = (c == 2 || c == 5)
                drawPixel(ctx, bx+c, by+2, closed ? d : s)
            } else {
                // Normal 2-wide eyes
                let eye = (c == 1 || c == 2 || c == 5 || c == 6)
                drawPixel(ctx, bx+c, by+2, eye ? d : s)
            }
        }
        // Belly
        for c in 0...7 { drawPixel(ctx, bx+c, by+3, s) }
        for c in 0...7 { drawPixel(ctx, bx+c, by+4, s) }
        // Four legs
        for c in [1, 3, 5, 7] {
            drawPixel(ctx, bx+c, by+5, s)
            drawPixel(ctx, bx+c, by+6, s)
        }
    }

    // MARK: - Arms

    private func leftArm(_ ctx: GraphicsContext,
                         bx: Int, by: Int, dy: Int, c: Color) {
        drawPixel(ctx, bx-1, by+dy, c)
        drawPixel(ctx, bx-2, by+dy, c)
    }

    private func rightArm(_ ctx: GraphicsContext,
                          bx: Int, by: Int, dy: Int, c: Color) {
        drawPixel(ctx, bx+8, by+dy, c)
        drawPixel(ctx, bx+9, by+dy, c)
    }

    // MARK: - Working (right arm + pickaxe swing, 4 frames)
    //
    //  Pickaxe anatomy (all coords relative to bx=6, by=2):
    //  frame 0  rest    arm dy=3 → shaft down (col 15, rows 5-7)
    //                             head horiz at row 7 (cols 13-17)
    //                             tips at row 8 (cols 13 & 17)
    //  frame 1  raised  arm dy=1 → shaft NE (col 16 row 2, col 17 row 1)
    //                             head horiz at row 0 (cols 17-19)
    //                             tip at (19,1)
    //  frame 2  horiz   arm dy=2 → shaft horiz (cols 16-18, row 4)
    //                             head vertical at col 19 (rows 2-6)
    //  frame 3  impact  arm dy=4 → shaft SE (col 15 row 7, col 16 row 8)
    //                             head horiz at row 9 (cols 15-18)
    //                             dust at rows 10-11

    private func workingAnimation(_ ctx: GraphicsContext,
                                  bx: Int, by: Int, f: Int,
                                  salmon: Color, pick: Color) {
        leftArm(ctx, bx: bx, by: by, dy: 3, c: salmon)   // left arm rests

        switch f {
        case 0: // rest — pickaxe hangs vertically
            rightArm(ctx, bx: bx, by: by, dy: 3, c: salmon)
            // shaft straight down from grip
            drawPixel(ctx, bx+9, by+4, pick); drawPixel(ctx, bx+9, by+5, pick); drawPixel(ctx, bx+9, by+6, pick)
            // head horizontal (4 wide each side of shaft)
            drawPixel(ctx, bx+7, by+6, pick); drawPixel(ctx, bx+8, by+6, pick)
            drawPixel(ctx, bx+10, by+6, pick); drawPixel(ctx, bx+11, by+6, pick)
            // tips pointing down
            drawPixel(ctx, bx+7, by+7, pick); drawPixel(ctx, bx+11, by+7, pick)

        case 1: // raised — arm up, pickaxe NE
            rightArm(ctx, bx: bx, by: by, dy: 1, c: salmon)
            // shaft diagonal NE from grip
            drawPixel(ctx, bx+10, by,   pick); drawPixel(ctx, bx+11, by-1, pick)
            // head horizontal at top
            drawPixel(ctx, bx+11, by-2, pick); drawPixel(ctx, bx+12, by-2, pick); drawPixel(ctx, bx+13, by-2, pick)
            // perpendicular tips
            drawPixel(ctx, bx+13, by-1, pick); drawPixel(ctx, bx+13, by-3, pick)  // by-3 = -1, guarded

        case 2: // mid-swing — arm mid, pickaxe horizontal
            rightArm(ctx, bx: bx, by: by, dy: 2, c: salmon)
            // shaft horizontal
            drawPixel(ctx, bx+10, by+2, pick); drawPixel(ctx, bx+11, by+2, pick); drawPixel(ctx, bx+12, by+2, pick)
            // head vertical at far end (T-shape)
            for r in 0...4 { drawPixel(ctx, bx+13, by+r, pick) }

        case 3: // impact — arm low, pickaxe hits down, dust
            rightArm(ctx, bx: bx, by: by, dy: 4, c: salmon)
            // shaft diagonal SE
            drawPixel(ctx, bx+9,  by+5, pick); drawPixel(ctx, bx+10, by+6, pick); drawPixel(ctx, bx+11, by+7, pick)
            // head horizontal at impact
            drawPixel(ctx, bx+9,  by+7, pick); drawPixel(ctx, bx+10, by+7, pick)
            drawPixel(ctx, bx+12, by+7, pick)
            // dust
            drawPixel(ctx, bx+8,  by+9, pick.opacity(0.55))
            drawPixel(ctx, bx+11, by+9, pick.opacity(0.55))
            drawPixel(ctx, bx+13, by+8, pick.opacity(0.30))

        default: break
        }
    }

    // MARK: - Waiting / Sleep (Zzz floating up-right, 4 frames)
    //
    //  Three 3×3 Z glyphs appear at staggered heights:
    //  z0: (bx+9, by+3) = (15, 5) — near right shoulder
    //  z1: (bx+10, by)  = (16, 2) — mid
    //  z2: (bx+11, by-2)= (17, 0) — near top of canvas
    //
    //  Each frame a new Z appears at the lowest position; older Z's rise.

    private func sleepZzz(_ ctx: GraphicsContext,
                          bx: Int, by: Int, f: Int, c: Color) {
        let z0 = (col: bx+9,  row: by+3)
        let z1 = (col: bx+10, row: by)
        let z2 = (col: bx+11, row: by-2)

        switch f {
        case 0:
            drawZ(ctx, col: z0.col, row: z0.row, c: c)
        case 1:
            drawZ(ctx, col: z1.col, row: z1.row, c: c)
            drawZ(ctx, col: z0.col, row: z0.row, c: c.opacity(0.50))
        case 2:
            drawZ(ctx, col: z2.col, row: z2.row, c: c.opacity(0.85))
            drawZ(ctx, col: z1.col, row: z1.row, c: c.opacity(0.90))
            drawZ(ctx, col: z0.col, row: z0.row, c: c.opacity(0.35))
        case 3:
            drawZ(ctx, col: z2.col, row: z2.row, c: c.opacity(0.55))
            drawZ(ctx, col: z1.col, row: z1.row, c: c.opacity(0.65))
        default: break
        }
    }

    /// 3×3 Z glyph:  X X X  /  . X .  /  X X X
    private func drawZ(_ ctx: GraphicsContext, col: Int, row: Int, c: Color) {
        for dc in 0...2 { drawPixel(ctx, col+dc, row,   c) }   // top bar
        drawPixel(ctx, col+1, row+1, c)                          // diagonal centre
        for dc in 0...2 { drawPixel(ctx, col+dc, row+2, c) }   // bottom bar
    }

    // MARK: - Done (both arms raised + green sparkles)

    private func doneAnimation(_ ctx: GraphicsContext,
                               bx: Int, by: Int, f: Int,
                               salmon: Color, green: Color) {
        leftArm(ctx,  bx: bx, by: by, dy: 1, c: salmon)
        rightArm(ctx, bx: bx, by: by, dy: 1, c: salmon)

        if f == 0 {
            drawPixel(ctx, bx+2, by-2, green); drawPixel(ctx, bx+5, by-2, green)
            drawPixel(ctx, bx+0, by-1, green); drawPixel(ctx, bx+7, by-1, green)
        } else {
            drawPixel(ctx, bx+1, by-2, green); drawPixel(ctx, bx+6, by-2, green)
            drawPixel(ctx, bx-1, by-1, green.opacity(0.5)); drawPixel(ctx, bx+8, by-1, green.opacity(0.5))
        }
    }

    // MARK: - Pixel primitive

    private func drawPixel(_ ctx: GraphicsContext, _ col: Int, _ row: Int, _ color: Color) {
        guard col >= 0, row >= 0 else { return }
        let rect = CGRect(x: CGFloat(col) * ps, y: CGFloat(row) * ps,
                          width: ps - 0.5, height: ps - 0.5)
        ctx.fill(Path(rect), with: .color(color))
    }
}
