import Foundation

final class ResumeStateStore {
    private static let key = "com.spillhistorie.resumeState"

    func save(_ state: ResumeState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }

    func load() -> ResumeState? {
        guard
            let data = UserDefaults.standard.data(forKey: Self.key),
            let state = try? JSONDecoder().decode(ResumeState.self, from: data),
            state.isResumable
        else { return nil }
        return state
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: Self.key)
    }
}
