import SwiftUI

struct DiscoverArticleDetailView: View {
    let article: DiscoverArticle
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text(article.bodyIntro)
                        .font(DesignSystem.body)
                        .foregroundColor(DesignSystem.backgroundOnboarding)

                    Text(article.bodyHighlight)
                        .font(DesignSystem.body)
                        .foregroundColor(DesignSystem.backgroundOnboarding)
                        .padding(.leading, DesignSystem.Spacing.sm)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(article.category.gradient).frame(width: 3)
                        }

                    if let sourceCitation = article.sourceCitation {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Source").font(DesignSystem.headline).foregroundColor(DesignSystem.backgroundOnboarding)
                            Text(sourceCitation).font(DesignSystem.caption).foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
                        }
                        .padding(.top, DesignSystem.Spacing.md)
                    }

                    ShareLink(item: "\(article.title) — \(article.subtitle)") {
                        Text("Share")
                            .font(DesignSystem.buttonLabel)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(article.category.gradient)
                            .clipShape(Capsule())
                    }
                    .padding(.top, DesignSystem.Spacing.lg)
                }
                .padding(DesignSystem.Spacing.md)
            }
        }
        .background(DesignSystem.backgroundMain.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        ZStack(alignment: .topLeading) {
            article.category.gradient
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.bottom, DesignSystem.Spacing.md)

                Text(article.title).font(DesignSystem.title).foregroundColor(.white)
                Text(article.subtitle).font(DesignSystem.subheadline).foregroundColor(.white.opacity(0.85))
            }
            .padding(DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.lg)
        }
    }
}