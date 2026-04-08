import SwiftUI

struct SidebarView: View {
    @Environment(ArticleStore.self) private var store
    @Binding var selectedCategory: ArticleCategory
    @Binding var showPodcasts: Bool
    @Binding var showSettings: Bool

    var body: some View {
        List {
            Section("Artikler") {
                ForEach(ArticleCategory.all) { category in
                    Button {
                        selectedCategory = category
                        showPodcasts = false
                        showSettings = false
                    } label: {
                        Label(category.name, systemImage: categoryIcon(category))
                            .foregroundStyle(selectedCategory.id == category.id && !showPodcasts ? Color.accentColor : Color.primary)
                    }
                    .listRowBackground(
                        selectedCategory.id == category.id && !showPodcasts
                            ? Color.accentColor.opacity(0.12)
                            : Color.clear
                    )
                }
            }

            Section("Podkast") {
                Button {
                    showPodcasts = true
                    showSettings = false
                } label: {
                    Label("Alle episoder", systemImage: "waveform")
                        .foregroundStyle(showPodcasts ? Color.accentColor : Color.primary)
                }
                .listRowBackground(showPodcasts ? Color.accentColor.opacity(0.12) : Color.clear)
            }

            Section("App") {
                Button {
                    showSettings = true
                    showPodcasts = false
                } label: {
                    Label("Innstillinger", systemImage: "gearshape")
                        .foregroundStyle(showSettings ? Color.accentColor : Color.primary)
                }
                .listRowBackground(showSettings ? Color.accentColor.opacity(0.12) : Color.clear)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Spillhistorie")
        .navigationBarTitleDisplayMode(.large)
    }

    private func categoryIcon(_ cat: ArticleCategory) -> String {
        switch cat.id {
        case "framside": return "house"
        case "nyespill": return "gamecontroller"
        case "retro": return "clock.arrow.circlepath"
        case "indie": return "sparkles"
        case "inntrykk": return "eye"
        case "features": return "star"
        case "quiz": return "questionmark.circle"
        default: return "doc.text"
        }
    }
}
