import Foundation

struct WordProgress: Codable {
    var recognized: Int = 0
    var repeated: Int = 0
    var recalled: Int = 0
    var usedIndependently: Int = 0
    var needsPractice: Int = 0
}

struct LearningError: Codable, Identifiable {
    let id: UUID
    var original: String
    var target: String
    var type: String
    var frequency: Int
}

struct ChildMemory: Codable {
    var nickname: String = "Hà Anh"
    var interests: [String] = []
    var words: [String: WordProgress] = [:]
    var errors: [LearningError] = []
}

@MainActor
final class MemoryStore: ObservableObject {
    @Published private(set) var memory = ChildMemory()
    private let key = "co_giao_mini_memory_v1"

    init() { load() }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(ChildMemory.self, from: data) else { return }
        memory = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(memory) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func setName(_ name: String) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned.count <= 40 else { return }
        memory.nickname = cleaned
        save()
    }

    func addInterest(_ interest: String) {
        let value = interest.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 80 else { return }
        if !memory.interests.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
            memory.interests.append(value)
            memory.interests = Array(memory.interests.suffix(20))
            save()
        }
    }

    func recordWord(_ word: String, event: String) {
        let keyWord = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyWord.isEmpty else { return }
        var p = memory.words[keyWord] ?? WordProgress()
        switch event {
        case "recognized": p.recognized += 1
        case "repeated": p.repeated += 1
        case "recalled": p.recalled += 1
        case "used_independently": p.usedIndependently += 1
        default: p.needsPractice += 1
        }
        memory.words[keyWord] = p
        save()
    }

    func recordError(original: String, target: String, type: String) {
        if let idx = memory.errors.firstIndex(where: { $0.original == original && $0.target == target }) {
            memory.errors[idx].frequency += 1
        } else {
            memory.errors.append(.init(id: UUID(), original: original, target: target, type: type, frequency: 1))
            memory.errors = Array(memory.errors.suffix(30))
        }
        save()
    }

    func compactJSON() -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(memory) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
