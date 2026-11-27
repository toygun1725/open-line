import SwiftUI

struct SettingsSheetView: View {
    @Bindable var profile: PlayerProfile
    @Environment(\.dismiss) private var dismiss
    private let surface = Color(red: 0.09, green: 0.15, blue: 0.18)
    private let row = Color(red: 0.15, green: 0.22, blue: 0.26)

    var body: some View {
        let tr = profile.language == .tr
        NavigationStack {
            Form {
                Section {
                    Picker(tr ? "Dil" : "Language", selection: $profile.language) {
                        ForEach(AppLanguage.allCases) { lang in Text(lang.displayLabel).tag(lang) }
                    }
                    Picker(tr ? "Mesaj yazısı" : "Message font", selection: $profile.fontStyle) {
                        ForEach(AppFontStyle.allCases) { style in Text(style.title(for: profile.language)).tag(style) }
                    }
                    Text(tr ? "Merhaba, mesajım ulaştı mı?" : "Hello, did my message reach you?")
                        .font(AppTypography.narrative(style: profile.fontStyle, size: 16))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(9)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    Picker(tr ? "Cevap yazısı" : "Reply font", selection: $profile.replyFontStyle) {
                        ForEach(ReplyFontStyle.allCases) { style in Text(style.title(for: profile.language)).tag(style) }
                    }
                    Text(tr ? "Biraz bekle, buradayım." : "Give it a moment. I'm here.")
                        .font(AppTypography.reply(style: profile.replyFontStyle))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(9)
                        .background(Color.white.opacity(0.08),
                                    in: UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 10,
                                                              bottomTrailingRadius: 10, topTrailingRadius: 4))
                    Toggle(tr ? "Ses efektleri" : "Sound effects", isOn: Binding(get: { !profile.isMuted }, set: { profile.isMuted = !$0 }))
                }.listRowBackground(row)
                Section {
                    LabeledContent(tr ? "Sürüm" : "Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.1")
                }.listRowBackground(row)
            }
            .scrollContentBackground(.hidden)
            .background(surface)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(tr ? "Ayarlar" : "Settings")
                        .font(.system(.title2, design: .serif))
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .confirmationAction) { Button(tr ? "Kapat" : "Done") { dismiss() } }
            }
        }
        .tint(Color(red: 0.91, green: 0.76, blue: 0.65))
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
