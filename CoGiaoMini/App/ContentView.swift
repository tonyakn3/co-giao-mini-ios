import SwiftUI

struct ContentView: View {
    @StateObject private var memory = MemoryStore()
    @StateObject private var clientHolder = ClientHolder()
    @State private var showSettings = false
    @State private var apiKey = KeychainStore.load()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 1, green: 0.97, blue: 0.98), Color(red: 1, green: 0.92, blue: 0.96)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cô Giáo Mini ♡")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(Color.pink)
                        Text("English Teacher")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .padding(10)
                            .background(.white.opacity(0.9), in: Circle())
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(client.captionSpeaker)
                        .font(.caption.bold())
                        .foregroundStyle(.pink)
                    Text(client.captionText)
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(4)
                        .minimumScaleFactor(0.8)
                }
                .padding(16)
                .background(.white.opacity(0.94))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.06), radius: 12, y: 6)

                GeometryReader { geo in
                    Image("mimi-full")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                }
                .frame(maxHeight: .infinity)

                if !client.errorMessage.isEmpty {
                    Text(client.errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    Task {
                        if client.state == .idle || client.state == .error {
                            if apiKey.isEmpty {
                                showSettings = true
                            } else {
                                await client.start(apiKey: apiKey)
                            }
                        } else {
                            client.stop()
                        }
                    }
                } label: {
                    Label(
                        client.state == .idle || client.state == .error ? "Nói với Cô Giáo Mini" : "Kết thúc",
                        systemImage: client.state == .idle || client.state == .error ? "mic.fill" : "stop.fill"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .onAppear {
            clientHolder.attach(memory: memory)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(apiKey: $apiKey)
        }
    }

    private var client: GeminiLiveClient {
        clientHolder.client ?? GeminiLiveClient(memory: memory)
    }

    private var statusText: String {
        switch client.state {
        case .idle: return "Sẵn sàng"
        case .connecting: return "Đang kết nối Gemini Live…"
        case .listening: return "Cô Giáo Mini đang nghe Hà Anh…"
        case .speaking: return "Cô Giáo Mini đang nói…"
        case .error: return "Có lỗi kết nối"
        }
    }
}

@MainActor
final class ClientHolder: ObservableObject {
    @Published var client: GeminiLiveClient?

    func attach(memory: MemoryStore) {
        if client == nil { client = GeminiLiveClient(memory: memory) }
    }
}

struct SettingsView: View {
    @Binding var apiKey: String
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Gemini API key") {
                    SecureField("AIza…", text: $draft)
                    Text("Key chỉ được lưu trong Keychain trên iPhone/iPad. Không chụp hoặc gửi key cho người khác.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Lưu API key") {
                        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !value.isEmpty {
                            KeychainStore.save(value)
                            apiKey = value
                        }
                        dismiss()
                    }
                    Button("Xóa API key", role: .destructive) {
                        KeychainStore.delete()
                        apiKey = ""
                        draft = ""
                    }
                }
            }
            .navigationTitle("Cài đặt")
            .onAppear { draft = apiKey }
        }
    }
}
