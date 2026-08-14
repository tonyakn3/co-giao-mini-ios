import Foundation

@MainActor
final class GeminiLiveClient: ObservableObject {
    enum State: String {
        case idle, connecting, listening, speaking, error
    }

    @Published var state: State = .idle
    @Published var captionSpeaker = "Mini"
    @Published var captionText = "Hello Hà Anh!"
    @Published var errorMessage = ""

    private var task: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var toolBusy = false

    let audio = AudioEngine()
    let memory: MemoryStore

    init(memory: MemoryStore) {
        self.memory = memory
        audio.onPCM16k = { [weak self] data in
            Task { @MainActor in
                await self?.sendAudio(data)
            }
        }
    }

    func start(apiKey: String) async {
        guard !apiKey.isEmpty else {
            errorMessage = "Chưa có Gemini API key."
            state = .error
            return
        }

        do {
            state = .connecting
            let token = try await mintEphemeralToken(apiKey: apiKey)
            let model = "gemini-3.1-flash-live-preview"
            let endpoint = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContentConstrained?access_token=\(token)"
            guard let url = URL(string: endpoint) else { throw URLError(.badURL) }

            let session = URLSession(configuration: .default)
            task = session.webSocketTask(with: url)
            task?.resume()
            receiveLoop()

            try await sendSetup(model: model)

            try audio.start()
            state = .listening

            try await sendJSON([
                "realtimeInput": [
                    "text": "Begin naturally now. Greet Hà Anh warmly. She may speak Vietnamese, English, or mix both. Understand all of them and gently help her toward simple English. Do not default to a quiz or color question."
                ]
            ])
        } catch {
            errorMessage = error.localizedDescription
            state = .error
            stop()
        }
    }

    func stop() {
        receiveTask?.cancel()
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        audio.stop()
        state = .idle
    }

    private func mintEphemeralToken(apiKey: String) async throws -> String {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/auth_tokens")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let expire = ISO8601DateFormatter().string(from: Date().addingTimeInterval(30 * 60))
        let newSessionExpire = ISO8601DateFormatter().string(from: Date().addingTimeInterval(60))
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "uses": 1,
            "expireTime": expire,
            "newSessionExpireTime": newSessionExpire
        ])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "Gemini", code: 1, userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "Token error"])
        }
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let token = obj?["name"] as? String else {
            throw NSError(domain: "Gemini", code: 2, userInfo: [NSLocalizedDescriptionKey: "Gemini token không hợp lệ"])
        }
        return token
    }

    private func teacherPrompt() -> String {
        """
        You are Mini, the AI teacher in the app “Cô Giáo Mini”, teaching a 6-year-old Vietnamese child named \(memory.memory.nickname).

        GOAL:
        Make her enjoy speaking English, understand simple English, improve pronunciation gradually, build vocabulary, and feel confident.

        BILINGUAL POLICY:
        - Understand Vietnamese, English, and mixed Vietnamese-English naturally.
        - Default to very simple, short English.
        - If she asks in Vietnamese, answer the real question first, then naturally teach the useful English word or short sentence.
        - If she is confused or says she does not understand, explain briefly in simple Vietnamese, then return to English.
        - Do not translate every sentence. Vietnamese is support, not the main lesson language.
        - Correct gently. Do not interrupt every small mistake.
        - Usually use 1–3 short sentences and at most one easy question at a time.
        - Do not force a quiz during natural conversation.
        - Accept Vietnamese-accented English and imperfect attempts.

        OPENING:
        Vary openings. Good examples: “Hello Hà Anh! Can I help you?”, “Hi Hà Anh! What would you like to do today?”, “Do you want to talk, play a game, or hear a story?”
        Never default repeatedly to “What color...?”

        MEMORY:
        Current local learning memory JSON: \(memory.compactJSON())
        Use it naturally. Do not reveal the raw memory.
        Use tools only for durable learning-relevant memory: name/nickname, stable interests, useful word progress, recurring learning errors.
        Never store address, school name, phone number, precise location, passwords, full legal name, or other unnecessary private information.

        SAFETY:
        All content must be appropriate for a six-year-old. Never encourage secrecy from parents. For danger or injury, tell her to get a trusted adult.
        """
    }

    private func sendSetup(model: String) async throws {
        let setup: [String: Any] = [
            "setup": [
                "model": "models/\(model)",
                "generationConfig": [
                    "responseModalities": ["AUDIO"],
                    "speechConfig": [
                        "voiceConfig": [
                            "prebuiltVoiceConfig": ["voiceName": "Kore"]
                        ]
                    ]
                ],
                "inputAudioTranscription": [:],
                "outputAudioTranscription": [:],
                "systemInstruction": [
                    "parts": [["text": teacherPrompt()]]
                ],
                "tools": [[
                    "functionDeclarations": [
                        [
                            "name": "remember_child_name",
                            "description": "Save the child's preferred first name or nickname only after she clearly states it.",
                            "parameters": [
                                "type": "OBJECT",
                                "properties": ["name": ["type": "STRING"]],
                                "required": ["name"]
                            ]
                        ],
                        [
                            "name": "remember_interest",
                            "description": "Save a stable age-appropriate interest that can personalize future lessons.",
                            "parameters": [
                                "type": "OBJECT",
                                "properties": ["interest": ["type": "STRING"]],
                                "required": ["interest"]
                            ]
                        ],
                        [
                            "name": "record_word_progress",
                            "description": "Record a clear English learning event, not every word.",
                            "parameters": [
                                "type": "OBJECT",
                                "properties": [
                                    "word": ["type": "STRING"],
                                    "event": [
                                        "type": "STRING",
                                        "enum": ["recognized","repeated","recalled","used_independently","needs_practice"]
                                    ]
                                ],
                                "required": ["word","event"]
                            ]
                        ],
                        [
                            "name": "record_learning_error",
                            "description": "Save a recurring or educationally useful English mistake.",
                            "parameters": [
                                "type": "OBJECT",
                                "properties": [
                                    "type": ["type": "STRING"],
                                    "original": ["type": "STRING"],
                                    "target": ["type": "STRING"]
                                ],
                                "required": ["original","target"]
                            ]
                        ]
                    ]
                ]]
            ]
        ]
        try await sendJSON(setup)
    }

    private func receiveLoop() {
        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    guard let message = try await self?.task?.receive() else { break }
                    await self?.handle(message)
                } catch {
                    if !Task.isCancelled {
                        await MainActor.run {
                            self?.errorMessage = error.localizedDescription
                            self?.state = .error
                        }
                    }
                    break
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) async {
        let data: Data
        switch message {
        case .string(let text):
            data = Data(text.utf8)
        case .data(let d):
            data = d
        @unknown default:
            return
        }

        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        if let toolCall = root["toolCall"] as? [String: Any] {
            await handleToolCall(toolCall)
        }

        guard let serverContent = root["serverContent"] as? [String: Any] else { return }

        if (serverContent["interrupted"] as? Bool) == true {
            audio.interruptPlayback()
            state = .listening
        }

        if let input = serverContent["inputTranscription"] as? [String: Any],
           let text = input["text"] as? String, !text.isEmpty {
            captionSpeaker = memory.memory.nickname
            captionText = text
            state = .listening
        }

        if let output = serverContent["outputTranscription"] as? [String: Any],
           let text = output["text"] as? String, !text.isEmpty {
            captionSpeaker = "Cô Giáo Mini"
            captionText = text
            state = .speaking
        }

        if let turn = serverContent["modelTurn"] as? [String: Any],
           let parts = turn["parts"] as? [[String: Any]] {
            for part in parts {
                guard let inline = part["inlineData"] as? [String: Any],
                      let mime = inline["mimeType"] as? String,
                      mime.hasPrefix("audio/pcm"),
                      let b64 = inline["data"] as? String,
                      let pcm = Data(base64Encoded: b64) else { continue }
                audio.playPCM24k(pcm)
                state = .speaking
            }
        }

        if (serverContent["turnComplete"] as? Bool) == true {
            state = .listening
        }
    }

    private func handleToolCall(_ toolCall: [String: Any]) async {
        guard !toolBusy,
              let calls = toolCall["functionCalls"] as? [[String: Any]] else { return }
        toolBusy = true
        var responses: [[String: Any]] = []

        for call in calls {
            let id = call["id"] as? String ?? UUID().uuidString
            let name = call["name"] as? String ?? ""
            let args = call["args"] as? [String: Any] ?? [:]

            switch name {
            case "remember_child_name":
                if let value = args["name"] as? String { memory.setName(value) }
            case "remember_interest":
                if let value = args["interest"] as? String { memory.addInterest(value) }
            case "record_word_progress":
                if let word = args["word"] as? String, let event = args["event"] as? String {
                    memory.recordWord(word, event: event)
                }
            case "record_learning_error":
                if let original = args["original"] as? String, let target = args["target"] as? String {
                    memory.recordError(original: original, target: target, type: args["type"] as? String ?? "other")
                }
            default: break
            }

            responses.append([
                "id": id,
                "name": name,
                "response": ["result": "ok"]
            ])
        }

        try? await sendJSON(["toolResponse": ["functionResponses": responses]])
        toolBusy = false
    }

    private func sendAudio(_ data: Data) async {
        guard state != .idle, state != .error, !toolBusy else { return }
        try? await sendJSON([
            "realtimeInput": [
                "audio": [
                    "data": data.base64EncodedString(),
                    "mimeType": "audio/pcm;rate=16000"
                ]
            ]
        ])
    }

    private func sendJSON(_ obj: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: obj)
        guard let text = String(data: data, encoding: .utf8) else { return }
        try await task?.send(.string(text))
    }
}
