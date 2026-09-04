import SwiftUI

struct DiscoverView: View {
    @StateObject private var viewModel = DiscoverViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    Text("Discover")
                        .font(DesignSystem.largeTitle)
                        .foregroundColor(DesignSystem.backgroundOnboarding)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.top, DesignSystem.Spacing.sm)

                    forYouSection
                    filterChips

                    ForEach(viewModel.sections, id: \.category) { section in
                        categorySection(section.category, section.articles)
                    }
                }
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
            .background(DesignSystem.backgroundMain.ignoresSafeArea())
            .navigationDestination(item: $viewModel.selectedArticle) { article in
                DiscoverArticleDetailView(article: article)
            }
        }
    }

    private var forYouSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label("For You", systemImage: "star")
                .font(DesignSystem.headline)
                .foregroundColor(DesignSystem.backgroundOnboarding)
                .padding(.horizontal, DesignSystem.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(viewModel.forYouArticles) { article in
                        DiscoverCardView(article: article, size: .large)
                            .onTapGesture { viewModel.select(article) }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
        }
    }

    private var filterChips: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Browse By")
                .font(DesignSystem.caption)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
                .padding(.horizontal, DesignSystem.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    filterChip(title: "All", isSelected: viewModel.selectedCategory == nil) {
                        viewModel.selectedCategory = nil
                    }
                    ForEach(DiscoverCategory.allCases) { category in
                        filterChip(title: category.rawValue, isSelected: viewModel.selectedCategory == category) {
                            viewModel.selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.subheadline.weight(.semibold))
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(isSelected ? DesignSystem.backgroundOnboarding : Color.white)
                .foregroundColor(isSelected ? .white : DesignSystem.backgroundOnboarding)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func categorySection(_ category: DiscoverCategory, _ articles: [DiscoverArticle]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(category.rawValue)
                .font(DesignSystem.title2)
                .foregroundColor(DesignSystem.backgroundOnboarding)
                .padding(.horizontal, DesignSystem.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(articles) { article in
                        DiscoverCardView(article: article, size: .regular)
                            .onTapGesture { viewModel.select(article) }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
        }
    }
}

struct DiscoverCardView: View {
    enum Size {
        case regular, large
        var width: CGFloat { self == .large ? 220 : 160 }
        var height: CGFloat { self == .large ? 260 : 220 }
    }

    let article: DiscoverArticle
    var size: Size = .regular

    var body: some View {
        ZStack(alignment: .topLeading) {
            article.category.gradient
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(article.category.rawValue.uppercased())
                    .font(DesignSystem.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, DesignSystem.Spacing.xs)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
                Spacer()
                Text(article.title)
                    .font(DesignSystem.headline)
                    .foregroundColor(.white)
                    .lineLimit(3)
                Text(article.subtitle)
                    .font(DesignSystem.caption)
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(2)
            }
            .padding(DesignSystem.Spacing.md)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius, style: .continuous))
    }
}