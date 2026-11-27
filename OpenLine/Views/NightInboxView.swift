import SwiftUI
import ImageIO
import UIKit

struct NightInboxView: View {
    @Bindable var directory: LineDirectory
    let onSettings: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let profile = directory.profile
        let tr = profile.language == .tr
        ZStack {
            HourlyCityView().ignoresSafeArea()
            LinearGradient(stops: [
                .init(color: Color(red: 0.03, green: 0.08, blue: 0.11).opacity(0.88), location: 0),
                .init(color: .black.opacity(0.40), location: 0.27),
                .init(color: .clear, location: 0.55),
                .init(color: .black.opacity(0.78), location: 1)
            ], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ViewThatFits(in: .vertical) {
                content(profile, tr: tr)
                ScrollView { content(profile, tr: tr) }
            }
        }
        .foregroundStyle(.white)
        .environment(\.locale, Locale(identifier: tr ? "tr_TR" : "en_US"))
    }

    private func content(_ profile: PlayerProfile, tr: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(profile.catalog.appTitle.text(for: profile.language))
                    .font(.system(.title2, design: .serif)).accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: onSettings) {
                    Image(systemName: "gearshape").frame(width: 44, height: 44)
                }.buttonStyle(.plain).accessibilityLabel(tr ? "Ayarlar" : "Settings")
            }
            .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.22)).frame(height: 1) }
            .padding(.horizontal, 6)
            TimelineView(.everyMinute) { time in
                VStack(spacing: 3) {
                    Text(time.date, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.subheadline.weight(.semibold)).tracking(0.7)
                    Text(time.date, style: .time)
                        .font(.system(size: 88, weight: .thin)).monospacedDigit()
                        .minimumScaleFactor(0.62).lineLimit(1)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .shadow(color: .black.opacity(0.6), radius: 7, y: 2)
            }.padding(.top, 19).padding(.horizontal, 6)
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

private struct HourlyCityView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var frame: (hour: Int, image: UIImage)?

    var body: some View {
        TimelineView(.everyMinute) { context in
            let hour = Calendar.autoupdatingCurrent.component(.hour, from: context.date)
            Color(red: 0.05, green: 0.08, blue: 0.11)
                .overlay {
                    ZStack {
                        Image("NightCity").resizable().scaledToFill()
                        if let frame {
                            Image(uiImage: frame.image).resizable().scaledToFill()
                                .id(frame.hour)
                                .transition(.opacity)
                        }
                    }
                }
                .clipped()
                .onChange(of: hour, initial: true) { _, hour in
                    let name = String(format: "%02d", hour)
                    let next = Bundle.main.url(forResource: name, withExtension: "webp", subdirectory: "wallpapers")
                        .flatMap { CGImageSourceCreateWithURL($0 as CFURL, nil) }
                        .flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
                        .map { UIImage(cgImage: $0) }
                    if let next {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.45)) { frame = (hour, next) }
                    }
                }
        }.accessibilityHidden(true)
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
        let direct = line.hasStarted && !locked
        let latest = line.latestMessage
        VStack(alignment: .leading, spacing: 0) {
            Button(action: direct ? onOpen : onExpand) {
                HStack(alignment: .top, spacing: 12) {
                    Text(String(sender.prefix(1)))
                        .font(.system(.title2, design: .serif).italic())
                        .frame(width: 42, height: 42)
                        .background(
                            LinearGradient(colors: [line.palette.keyChosenTop, line.palette.keyChosenBottom],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(sender).font(.headline)
                        Text(s.title.text(for: lang)).font(.caption.weight(.medium))
                            .foregroundStyle(line.palette.windowSignal)
                        Text(latest?.text ?? s.invitation.text(for: lang)).font(.subheadline)
                            .lineLimit(expanded ? nil : 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 7) {
                        if let latest {
                            Text(latest.date, style: .time).font(.caption2).monospacedDigit()
                        }
                        Image(systemName: locked ? "lock" : expanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold))
                            .accessibilityHidden(!locked)
                            .accessibilityLabel(tr ? "Kilitli" : "Locked")
                    }
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.top, 3)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain)
            if expanded && !direct {
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
        }.padding(13)
        .background(
            LinearGradient(colors: [Color(red: 0.14, green: 0.19, blue: 0.23).opacity(0.97),
                                    Color(red: 0.06, green: 0.10, blue: 0.14).opacity(0.94)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 15)
        )
        .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(.white.opacity(0.17)).allowsHitTesting(false))
        .shadow(color: .black.opacity(0.22), radius: 9, y: 5)
    }

    private func actionTitle(locked: Bool, tr: Bool) -> String {
        if locked { return tr ? "Tam Erişimi aç" : "Unlock All Access" }
        return tr ? "Hatta bağlan" : "Connect"
    }
}
