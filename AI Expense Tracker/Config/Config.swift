import Foundation

enum Config {
    // Note: In a production app, you should store this securely (e.g., in Keychain)
    static let openAIKey: String = ""
    
    static let openAIEndpoint = "https://api.openai.com/v1/chat/completions"
} 
