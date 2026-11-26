import SwiftUI

struct NightInboxView: View {
    @Bindable var directory: LineDirectory
    let onSettings: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let profile = directory.profile
        let tr = profile.language == .tr
        ZStack {
            Color(red: 0.05, green: 0.08, blue: 0.11).ignoresSafeArea()
            Color.clear.overlay {
                Image("NightCity").resizable().scaledToFill()
            }.clipped().ignoresSafeArea().accessibilityHidden(true)
            LinearGradient(colors: [.black.opacity(0.13), .clear, .black.opacity(0.54)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ViewThatFits(in: .vertical) {
                content(profile, tr: tr)
                ScrollView { content(profile, tr: tr) }
            }
        }
        .foregroundStyle(.white)
        .environment(\.locale, Locale(identifier: tr ? "tr_TR" : "en_US"))
    }

    private func content(_ profile: PlayerProfile, tr: Bool) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(profile.catalog.appTitle.text(for: profile.language)).font(.system(.headline, design: .serif))
                Spacer()
                Button(action: onSettings) {
                    Image(systemName: "gearshape").frame(width: 44, height: 44)
                }.accessibilityLabel(tr ? "Ayarlar" : "Settings")
            }.padding(.horizontal, 10)
            TimelineView(.everyMinute) { time in
                VStack(spacing: 0) {
                    Text(time.date, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.subheadline.weight(.medium))
                    Text(time.date, style: .time)
                        .font(.system(size: 74, weight: .thin)).monospacedDigit()
                        .minimumScaleFactor(0.62).lineLimit(1)
                }
            }.padding(.top, 8)
            Spacer(minLength: 32)
            ForEach(directory.lines, id: \.activeStory.id) { line in
                let story = line.activeStory
                let expanded = directory.expandedID == story.id
                InboxMessageView(line: line, expanded: expanded,
                    onExpand: {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                            directory.expandedID = expanded ? nil : story.id
                        }
                    }, onOpen: { directory.open(line) })
            }
        }.padding(.horizontal, 16).padding(.bottom, 12)
    }
}

private struct InboxMessageView: View {
    let line: StoryEngine
    let expanded: Bool
    let onExpand: () -> Void
    let onOpen: () -> Void

    var body: some View {
        let s = line.activeStory
        let lang = line.language
        let tr = lang == .tr
        let locked = !s.isFree && !line.isAllAccessUnlocked
        let sender = s.senderName.text(for: lang)
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onExpand) {
                HStack(alignment: .top, spacing: 10) {
                    Text(String(sender.prefix(1)))
                        .font(.system(.title2, design: .serif).italic())
                        .frame(width: 38, height: 38)
                        .background(line.palette.accent.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(sender).font(.headline)
                            Text(s.title.text(for: lang)).font(.caption).foregroundStyle(.white.opacity(0.77))
                        }
                        Text(line.latestMessage ?? s.invitation.text(for: lang)).font(.subheadline)
                            .lineLimit(expanded ? nil : 2)
                    }
                    Spacer(minLength: 2)
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.caption).padding(.top, 4)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain)
            if expanded {
                Divider().overlay(.white.opacity(0.2)).padding(.vertical, 10)
                Text(s.synopsis.text(for: lang)).font(.subheadline)
                if locked {
                    Text(line.profile.monetization.displayPrice).font(.caption).padding(.top, 6)
                }
                Button(action: onOpen) {
                    Text(actionTitle(locked: locked, tr: tr))
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(.black).background(line.palette.keyWhiteBottom, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).padding(.top, 10)
            }
        }.padding(14)
        .background(Color(red: 0.08, green: 0.11, blue: 0.14).opacity(0.88), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.18)))
    }

    private func actionTitle(locked: Bool, tr: Bool) -> String {
        if locked { return tr ? "Tam Erişimi aç" : "Unlock All Access" }
        if line.visibleEnding != nil { return tr ? "Konuşmayı oku" : "Read conversation" }
        if line.hasStarted { return tr ? "Konuşmaya dön" : "Resume conversation" }
        return tr ? "Hatta bağlan" : "Connect"
    }
}
