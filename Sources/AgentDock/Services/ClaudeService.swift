import Foundation
import SwiftAnthropic

class ClaudeService {
    private var service: AnthropicService

    private static let model = "claude-sonnet-4-20250514"
    private static let maxTokens = 4096

    init(apiKey: String) {
        self.service = AnthropicServiceFactory.service(
            apiKey: apiKey,
            betaHeaders: nil
        )
    }

    func sendMessage(messages: [ChatMessage], systemPrompt: String) async throws -> String {
        let anthropicMessages = messages.map { msg -> MessageParameter.Message in
            let role: MessageParameter.Message.Role = msg.role == .user ? .user : .assistant
            return MessageParameter.Message(
                role: role,
                content: .text(msg.content)
            )
        }

        let parameters = MessageParameter(
            model: .other(Self.model),
            messages: anthropicMessages,
            maxTokens: Self.maxTokens,
            system: .text(systemPrompt)
        )

        let response = try await service.createMessage(parameters)

        let text = response.content.compactMap { block -> String? in
            if case .text(let t, _) = block {
                return t
            }
            return nil
        }.joined()

        return text
    }

    func streamMessage(
        messages: [ChatMessage],
        systemPrompt: String
    ) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let anthropicMessages = messages.map { msg -> MessageParameter.Message in
                        let role: MessageParameter.Message.Role =
                            msg.role == .user ? .user : .assistant
                        return MessageParameter.Message(
                            role: role,
                            content: .text(msg.content)
                        )
                    }

                    let parameters = MessageParameter(
                        model: .other(Self.model),
                        messages: anthropicMessages,
                        maxTokens: Self.maxTokens,
                        system: .text(systemPrompt),
                        stream: true
                    )

                    let stream = try await service.streamMessage(parameters)

                    for try await response in stream {
                        if response.streamEvent == .contentBlockDelta,
                           let delta = response.delta,
                           delta.type == "text_delta",
                           let text = delta.text {
                            continuation.yield(text)
                        }

                        if response.streamEvent == .messageStop {
                            continuation.finish()
                            return
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
