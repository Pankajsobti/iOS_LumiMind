import Foundation

import Combine

@MainActor
final class DiscoverViewModel: ObservableObject {
    @Published var selectedCategory: DiscoverCategory?
    @Published var selectedArticle: DiscoverArticle?

    let allArticles: [DiscoverArticle] = DiscoverCatalog.articles

    var forYouArticles: [DiscoverArticle] {
        allArticles.filter { $0.isForYou }
    }

    var sections: [(category: DiscoverCategory, articles: [DiscoverArticle])] {
        let source = selectedCategory.map { cat in allArticles.filter { $0.category == cat } } ?? allArticles
        return DiscoverCategory.allCases.compactMap { category in
            let items = source.filter { $0.category == category }
            return items.isEmpty ? nil : (category, items)
        }
    }

    func select(_ article: DiscoverArticle) {
        selectedArticle = article
    }
}