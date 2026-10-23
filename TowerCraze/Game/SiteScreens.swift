import SwiftUI
import SpriteKit

// MARK: - 1. Стройплощадка (старт)

struct SiteView: View {
    @EnvironmentObject var app: TowerAppModel
    @EnvironmentObject var progress: GameProgress
    @EnvironmentObject var stats: SiteStats
    @State private var swing = false
    @State private var dropIn = false

    var body: some View {
        ZStack {
            SiteBackground()
            VStack(spacing: 0) {
                // табличка висит на тросах и покачивается
                Image(uiImage: Art.image("menu_logo"))
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 360)
                    .rotationEffect(.degrees(swing ? 2.5 : -2.5), anchor: .top)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: swing)
                    .offset(y: dropIn ? 0 : -300)
                    .animation(.spring(response: 0.9, dampingFraction: 0.55), value: dropIn)
                    .padding(.top, 10)
                HStack(spacing: 12) {
                    statBox(value: "\(stats.bestFloors)", label: "Best floors", icon: "building.2.fill")
                    statBox(value: Format.number(progress.best), label: "Best score", icon: "star.fill")
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                Spacer()
                Image(uiImage: Art.image("helmet"))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 130)
                    .rotationEffect(.degrees(swing ? -6 : 6))
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: swing)
                Button("Start Building") {
                    siteTap()
                    app.startRun()
                }
                .buttonStyle(ChunkyButtonStyle(height: 70))
                .padding(.horizontal, 40)
                .padding(.top, 14)
                Spacer().frame(height: 26)
                VStack(spacing: 0) {
                    HazardStripe(height: 12)
                    HStack(spacing: 0) {
                        toolbarButton("Blueprints", icon: "doc.text.fill") { app.go(.blueprints) }
                        Rectangle().fill(Site.ink).frame(width: 3)
                        toolbarButton("Skyline", icon: "building.columns.fill") { app.go(.skyline) }
                        Rectangle().fill(Site.ink).frame(width: 3)
                        toolbarButton("Settings", icon: "wrench.and.screwdriver.fill") { app.go(.settings) }
                    }
                    .frame(height: 86)
                    .background(Site.concrete)
                }
                .overlay(Rectangle().stroke(Site.ink, lineWidth: 4))
            }
        }
        .onAppear {
            dropIn = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { swing = true }
        }
    }

    private func statBox(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .black))
                .foregroundColor(Site.orange)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(Site.font(22)).foregroundColor(Site.ink)
                Text(label).font(Site.font(12, .bold)).foregroundColor(Site.ink.opacity(0.7))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .signPanel()
    }

    private func toolbarButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            siteTap()
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 24, weight: .black))
                Text(title).font(Site.font(13, .heavy)).textCase(.uppercase)
            }
            .foregroundColor(Site.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}

// MARK: - 2. Стройка: сцена и пульт крана

struct BuildView: View {
    @EnvironmentObject var app: TowerAppModel
    @EnvironmentObject var progress: GameProgress
    @ObservedObject var session: TowerSession
    @Environment(\.scenePhase) private var phase

    var body: some View {
        screen
            .onChange(of: phase) { value in
                if value != .active && !session.over { session.setPaused(true) }
            }
    }

    @ViewBuilder private var screen: some View {
        ZStack {
            SpriteView(scene: session.scene)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                if session.chain > 1 {
                    Text("CHAIN x\(session.chain)")
                        .font(Site.font(24))
                        .foregroundColor(Site.yellow)
                        .shadow(color: Site.ink, radius: 0, x: 2, y: 3)
                        .transition(.scale.combined(with: .opacity))
                        .padding(.top, 6)
                }
                Spacer()
                controls
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: session.chain)
            if session.paused && !session.over {
                pausePanel.transition(.opacity)
            }
            if session.showOver {
                overPanel.transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                siteTap()
                withAnimation { session.setPaused(true) }
            } label: {
                Image(systemName: "pause.fill")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(Site.ink)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Site.yellow))
                    .overlay(Circle().stroke(Site.ink, lineWidth: 4))
            }
            .buttonStyle(PressStyle())
            VStack(alignment: .leading, spacing: 0) {
                Text("SCORE").font(Site.font(11, .heavy)).foregroundColor(Site.ink.opacity(0.7))
                Text(Format.number(session.score)).font(Site.font(24)).foregroundColor(Site.ink)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .signPanel()
            VStack(alignment: .leading, spacing: 0) {
                Text("FLOOR").font(Site.font(11, .heavy)).foregroundColor(Site.ink.opacity(0.7))
                Text("\(session.floors)").font(Site.font(24)).foregroundColor(Site.ink)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .signPanel(Site.yellow)
            Spacer(minLength: 0)
            VStack(spacing: 2) {
                Text("NEXT").font(Site.font(11, .heavy)).foregroundColor(Site.ink.opacity(0.7))
                HStack(spacing: 2) {
                    if session.nextIsTNT {
                        Image(uiImage: Art.image("tnt")).resizable().frame(width: 30, height: 30)
                    } else {
                        ForEach(0..<session.nextColors.count, id: \.self) { i in
                            Image(uiImage: Art.image("brick_\(max(0, session.nextColors[i]))")).resizable().frame(width: 28, height: 28)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .signPanel()
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    private var controls: some View {
        VStack(spacing: 8) {
            Text("Slide to move, tap the shaft to drop, swipe up to turn")
                .font(Site.font(11, .heavy))
                .foregroundColor(.white)
                .shadow(color: Site.ink, radius: 0, x: 1, y: 1)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 7).fill(Site.ink.opacity(0.35))
                    RoundedRectangle(cornerRadius: 7)
                        .fill(session.timeFraction < 0.3 ? Site.red : Site.yellow)
                        .frame(width: max(0, geo.size.width * CGFloat(session.timeFraction)))
                }
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Site.ink, lineWidth: 3))
            }
            .frame(height: 16)
            HStack(spacing: 14) {
                Button {
                    siteTap()
                    session.rotate()
                } label: {
                    Label("Rotate", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(ChunkyButtonStyle(fill: Site.concrete, height: 62))
                Button {
                    session.drop()
                } label: {
                    Label("Drop", systemImage: "arrow.down.to.line")
                }
                .buttonStyle(ChunkyButtonStyle(fill: Site.yellow, height: 62))
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }

    private var pausePanel: some View {
        ZStack {
            Site.ink.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Coffee Break").font(Site.font(32)).foregroundColor(Site.ink)
                Image(systemName: "cup.and.saucer.fill").font(.system(size: 44, weight: .black)).foregroundColor(Site.orange)
                Button("Back to Work") {
                    siteTap()
                    withAnimation { session.setPaused(false) }
                }
                .buttonStyle(ChunkyButtonStyle())
                Button("New Shift") {
                    siteTap()
                    app.startRun()
                }
                .buttonStyle(ChunkyButtonStyle(fill: Site.concrete))
                Button("Leave Site") {
                    siteTap()
                    app.leaveRun()
                }
                .buttonStyle(ChunkyButtonStyle(fill: Color.white))
            }
            .padding(24)
            .signPanel()
            .padding(.horizontal, 34)
        }
    }

    private var overPanel: some View {
        let run = app.lastRun
        return ZStack {
            Site.ink.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Tower Collapsed").font(Site.font(30)).foregroundColor(Site.ink)
                HazardStripe(height: 12)
                HStack(spacing: 16) {
                    resultStat("Score", Format.number(run?.score ?? session.score))
                    resultStat("Floors", "\(run?.floors ?? session.floors)")
                    resultStat("Bricks", "\(run?.bricks ?? session.bricks)")
                }
                if run?.newBest == true {
                    Text("New best score!")
                        .font(Site.font(20))
                        .foregroundColor(Site.orange)
                }
                Text("Best score \(Format.number(progress.best))")
                    .font(Site.font(14, .bold))
                    .foregroundColor(Site.ink.opacity(0.7))
                Button("Build Again") {
                    siteTap()
                    app.startRun()
                }
                .buttonStyle(ChunkyButtonStyle())
                Button("Back to Site") {
                    siteTap()
                    app.leaveRun()
                }
                .buttonStyle(ChunkyButtonStyle(fill: Site.concrete))
            }
            .padding(24)
            .signPanel(Color.white)
            .padding(.horizontal, 28)
        }
    }

    private func resultStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Site.font(26)).foregroundColor(Site.ink)
            Text(label.uppercased()).font(Site.font(11, .heavy)).foregroundColor(Site.ink.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 3. Чертежи (достижения)

struct BlueprintsView: View {
    @EnvironmentObject var app: TowerAppModel
    @EnvironmentObject var progress: GameProgress

    var body: some View {
        ZStack(alignment: .top) {
            BlueprintBackground()
            VStack(spacing: 0) {
                SiteHeader(title: "Blueprints") { app.go(.site) }
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        Text("\(progress.unlockedCount) of \(progress.achievements.count) approved")
                            .font(Site.font(16, .heavy))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.top, 14)
                        ForEach(progress.achievements) { a in
                            sheet(a)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 30)
                }
            }
        }
    }

    private func sheet(_ a: AchievementDef) -> some View {
        let got = progress.isUnlocked(a.id)
        return HStack(spacing: 14) {
            Image(uiImage: Art.image(a.icon))
                .resizable()
                .scaledToFit()
                .frame(width: 58, height: 58)
                .saturation(got ? 1 : 0)
                .opacity(got ? 1 : 0.5)
            VStack(alignment: .leading, spacing: 3) {
                Text(a.title).font(Site.font(18)).foregroundColor(.white)
                Text(a.detail).font(Site.font(13, .semibold)).foregroundColor(.white.opacity(0.8))
            }
            Spacer(minLength: 0)
            Text(got ? "APPROVED" : "PENDING")
                .font(Site.font(12))
                .foregroundColor(got ? Site.yellow : .white.opacity(0.5))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(got ? Site.yellow : Color.white.opacity(0.4), lineWidth: 3))
                .rotationEffect(.degrees(-10))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(got ? 0.14 : 0.06)))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [8, 5])))
    }
}

// MARK: - 4. Линия небоскрёбов (лидерборд)

struct SkylineView: View {
    @EnvironmentObject var app: TowerAppModel
    @EnvironmentObject var progress: GameProgress
    @State private var grow = false

    var body: some View {
        let rows = progress.leaderboard()
        let top = CGFloat(rows.first?.score ?? 1)
        return ZStack(alignment: .top) {
            SiteBackground()
            VStack(spacing: 0) {
                SiteHeader(title: "Skyline") { app.go(.site) }
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(rows) { row in
                            HStack(spacing: 10) {
                                Text("\(row.rank)")
                                    .font(Site.font(20))
                                    .foregroundColor(Site.ink)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(row.rank <= 3 ? Site.yellow : Color.white))
                                    .overlay(Circle().stroke(Site.ink, lineWidth: 3))
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(row.name).font(Site.font(17)).foregroundColor(Site.ink)
                                        Spacer()
                                        Text(Format.number(row.score)).font(Site.font(17)).foregroundColor(Site.ink)
                                    }
                                    GeometryReader { geo in
                                        HStack(spacing: 0) {
                                            Rectangle()
                                                .fill(row.isPlayer ? Site.orange : Site.blueprint)
                                                .frame(width: grow ? geo.size.width * CGFloat(row.score) / max(top, 1) : 0)
                                            Spacer(minLength: 0)
                                        }
                                    }
                                    .frame(height: 10)
                                }
                            }
                            .padding(12)
                            .signPanel(row.isPlayer ? Site.yellow : Site.concrete)
                        }
                        if progress.best == 0 {
                            Text("Finish a shift to add your tower to the skyline")
                                .font(Site.font(15, .bold))
                                .foregroundColor(Site.ink)
                                .multilineTextAlignment(.center)
                                .padding(12)
                                .signPanel(Color.white)
                        }
                    }
                    .padding(18)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { grow = true }
        }
    }
}

// MARK: - 5. Настройки

struct SiteSettingsView: View {
    @EnvironmentObject var app: TowerAppModel
    @State private var confirm = false

    var body: some View {
        ZStack(alignment: .top) {
            SiteBackground()
            VStack(spacing: 0) {
                SiteHeader(title: "Settings") { app.go(.site) }
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 46, weight: .black))
                        .foregroundColor(Site.red)
                    Text("Clear Data")
                        .font(Site.font(30))
                        .foregroundColor(Site.ink)
                    Text("Removes your best scores, floors, bricks cleared and approved blueprints from this device.")
                        .font(Site.font(15, .semibold))
                        .foregroundColor(Site.ink.opacity(0.8))
                        .multilineTextAlignment(.center)
                    Button("Clear Data") {
                        siteTap()
                        confirm = true
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: Site.red, text: .white))
                }
                .padding(24)
                .signPanel(Color.white)
                .padding(.horizontal, 28)
                Spacer()
                Spacer()
            }
        }
        .alert("Clear all data?", isPresented: $confirm) {
            Button("Cancel", role: .cancel) { siteTap() }
            Button("Clear", role: .destructive) { app.clearData() }
        } message: {
            Text("Scores, floors and blueprints will be reset.")
        }
    }
}
