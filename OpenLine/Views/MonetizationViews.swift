import SwiftUI

struct ActBreakGateCardView: View {
    let completedAct: Int
    let nextAct: Int
    let title: String
    let subtitle: String
    let isCleared: Bool
    let isWatchingAd: Bool
    let priceDisplay: String
    let language: AppLanguage
    let fontStyle: AppFontStyle
    let palette: StoryPalette
    let onWatchAd: () -> Void
    let onOpenPaywall: () -> Void

    var body: some View {
        let tr = language == .tr
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(tr ? "PERDE ARASI · \(completedAct) ➔ \(nextAct)" : "ACT BREAK · \(completedAct) ➔ \(nextAct)")
                    .font(AppTypography.telemetry(size: 12).weight(.semibold))
                    .foregroundStyle(palette.accent)
                Spacer()
                if isCleared {
                    Label(tr ? "Açıldı" : "Unlocked", systemImage: "checkmark.circle.fill")
                        .font(AppTypography.telemetry(size: 12).weight(.semibold))
                        .foregroundStyle(palette.accent)
                }
            }

            Text(title)
                .font(AppTypography.control(style: fontStyle, size: 16, weight: .bold))
                .foregroundStyle(palette.inkPrimary)

            if !isCleared {
                Text(subtitle)
                    .font(AppTypography.narrative(style: fontStyle, size: 13.5))
                    .foregroundStyle(palette.inkHistory)
                    .lineSpacing(4)

                Button(action: onWatchAd) {
                    HStack(spacing: 8) {
                        if isWatchingAd {
                            ProgressView()
                                .tint(palette.keyChosenText)
                            Text(tr ? "Reklam oynatılıyor..." : "Playing ad...")
                        } else {
                            Image(systemName: "play.rectangle.fill")
                            Text(tr ? "1 Reklam İzle ve \(nextAct). Perde'ye Geç" : "Watch 1 Ad to Unlock Act \(nextAct)")
                        }
                    }
                    .font(AppTypography.control(style: fontStyle, size: 13.5, weight: .semibold))
                    .foregroundStyle(palette.keyChosenText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [palette.keyChosenTop, palette.keyChosenBottom],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: palette.keyChosenSkirt, radius: 0, x: 0, y: 2.5)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isWatchingAd)

                Button(action: onOpenPaywall) {
                    Text(tr ? "Reklamsız + Tüm Hikâyeler (\(priceDisplay))" : "Ad-Free + All Stories (\(priceDisplay))")
                        .font(AppTypography.control(style: fontStyle, size: 12.5, weight: .semibold))
                        .foregroundStyle(palette.inkPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [palette.keyWhiteTop, palette.keyWhiteBottom],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(palette.keyWhiteBorder, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .disabled(isWatchingAd)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(palette.accent, lineWidth: isCleared ? 1 : 1.5)
                )
        )
    }
}

struct AllAccessPaywallSheetView: View {
    @Bindable var profile: PlayerProfile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let tr = profile.language == .tr
        let appTitle = profile.catalog.appTitle.text(for: profile.language)
        let priceLabel = profile.monetization.displayPrice
        let paidStories = profile.catalog.stories.filter { !$0.isFree }

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tr ? "\(appTitle) · Tam Erişim" : "\(appTitle) · All-Access")
                            .font(.title2.bold())
                        Text(
                            tr
                                ? "Tek seferlik \(priceLabel) ile reklamlara veda et; kilitli tüm hikâyeleri ve eklenecek tüm yeni hatları kalıcı olarak aç."
                                : "Unlock every locked story, every upcoming Open Line release, and ad-free play forever with a single one-time \(priceLabel) purchase."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 10) {
                        benefitRow(
                            icon: "sparkles",
                            title: tr ? "Masa 7 — Reklamsız Tam Akış" : "Table 7 — Zero Act-Break Ads",
                            desc: tr ? "Perde araları ve finalden sonraki tüm tekrarlar reklamsız." : "All act breaks and every replay are ad-free."
                        )
                        ForEach(paidStories) { story in
                            benefitRow(
                                icon: "antenna.radiowaves.left.and.right",
                                title: story.title.text(for: profile.language),
                                desc: story.subtitle.text(for: profile.language)
                            )
                        }
                        benefitRow(
                            icon: "infinity",
                            title: tr ? "Gelecekteki Tüm Yeni Hikâyeler Dahil" : "All Future Story Releases Included",
                            desc: tr ? "Abonelik yok; tek ödeme ile tüm güncellemeler senin." : "No recurring subscription; one-time unlock."
                        )
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

                    if let msg = profile.monetization.statusMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    VStack(spacing: 10) {
                        Button {
                            Task {
                                if await profile.monetization.purchaseAllAccess(language: profile.language) == true {
                                    profile.applyAllAccessUnlock()
                                    dismiss()
                                }
                            }
                        } label: {
                            HStack {
                                if profile.monetization.isPurchaseInProgress == true {
                                    ProgressView().tint(.white)
                                }
                                Text(tr ? "Tam Erişimi Aç · \(priceLabel)" : "Unlock All-Access · \(priceLabel)")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(StoryPalette.palette(for: .warmRose).accent)

                        Button {
                            Task {
                                if await profile.monetization.restorePurchases(language: profile.language) == true {
                                    profile.applyAllAccessUnlock()
                                    dismiss()
                                }
                            }
                        } label: {
                            Text(tr ? "Satın Alımı Geri Yükle" : "Restore Purchases")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)


                    }
                }
                .padding(20)
            }
            .navigationTitle(tr ? "Tam Erişim ($0.99)" : "All-Access ($0.99)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr ? "Kapat" : "Close") { dismiss() }
                }
            }
        }
    }

    private func benefitRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(StoryPalette.palette(for: .warmRose).accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}
