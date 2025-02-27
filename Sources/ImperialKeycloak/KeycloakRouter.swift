import Vapor
import Foundation

public class KeycloakRouter: FederatedServiceRouter {
    public let tokens: FederatedServiceTokens
    public let keycloakTokens: KeycloakAuth
    public let callbackCompletion: (Request, String) async throws -> Response
    public var scope: [String] = []
    public let callbackURL: String
    public let accessTokenURL: String
    public let service: OAuthService = .keycloak
    
    public required init(callback: String, completion: @escaping (Request, String) async throws -> Response) async throws {
        self.tokens = try KeycloakAuth()
        self.keycloakTokens = self.tokens as! KeycloakAuth
        self.accessTokenURL = keycloakTokens.accessTokenURL
        self.callbackURL = callback
        self.callbackCompletion = completion
    }

    public func authURL(_ request: Request) throws -> String {
        return "\(keycloakTokens.authURL)/auth?" +
            "client_id=\(self.tokens.clientID)&" +
            "redirect_uri=\(self.callbackURL)&" +
            "scope=\(scope.joined(separator: "%20"))&" +
            "response_type=code"
    }
    
    public func callbackBody(with code: String) -> any Content {
        KeycloakCallbackBody(code: code,
                             clientId: tokens.clientID,
                             clientSecret: tokens.clientSecret,
                             redirectURI: callbackURL)
    }
}
