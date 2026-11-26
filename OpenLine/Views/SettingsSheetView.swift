import SwiftUI

struct SettingsSheetView: View {
    @Bindable var profile: PlayerProfile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let tr = profile.language == .tr
        NavigationStack {
            Form {
                Picker(tr ? "Dil" : "Language", selection: $profile.language) {
                    ForEach(AppLanguage.allCases) { lang in Text(lang.displayLabel).tag(lang) }
                }
                Picker(tr ? "Yazı tipi" : "Typography", selection: $profile.fontStyle) {
                    ForEach(AppFontStyle.allCases) { style in Text(style.title(for: profile.language)).tag(style) }
                }
                Toggle(tr ? "Ses efektleri" : "Sound effects", isOn: Binding(get: { !profile.isMuted }, set: { profile.isMuted = !$0 }))
                LabeledContent(tr ? "Sürüm" : "Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.1")
            }
            .navigationTitle(tr ? "Ayarlar" : "Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(tr ? "Kapat" : "Done") { dismiss() } }
            }
        }.presentationDetents([.medium, .large])
    }
}
