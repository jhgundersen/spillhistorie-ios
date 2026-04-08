import SwiftUI

struct ArticleListView: View {
    @Environment(ArticleStore.self) private var store
    let category: ArticleCategory
    @Binding var selectedArticle: Article?
    @State private var searchText = ""

    var filtered: [Article] {
        if searchText.isEmpty { return store.articles }
        return store.articles.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.author?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        Group {
            if store.isLoadingList && store.articles.isEmpty {
                ProgressView("Laster artikler…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = store.error {
                ContentUnavailableView(
                    "Kunne ikke laste",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else {
                List(filtered, selection: selectedArticleID) { article in
                    ArticleRowView(article: article)
                        .tag(article.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedArticle = article
                        }
                        .contextMenu {
                            Button("Apne i Safari", systemImage: "safari") {
                                UIApplication.shared.open(article.link)
                            }
                            ShareLink(item: article.link, subject: Text(article.title)) {
                                Label("Del", systemImage: "square.and.arrow.up")
                            }
                        }
                }
                .listStyle(.plain)
                .refreshable { await store.refresh() }
            }
        }
        .searchable(text: $searchText, prompt: "Sok i artikler")
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: category.id) {
            if store.selectedCategory.id != category.id {
                await store.loadCategory(category)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if store.isLoadingContent {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }

    private var selectedArticleID: Binding<Int?> {
        Binding(
            get: { selectedArticle?.id },
            set: { newValue in
                guard let newValue else {
                    selectedArticle = nil
                    return
                }
                selectedArticle = store.articles.first(where: { $0.id == newValue }) ?? selectedArticle
            }
        )
    }
}
