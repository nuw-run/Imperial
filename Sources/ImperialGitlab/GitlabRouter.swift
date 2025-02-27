import Vapor
import Foundation

public class GitlabRouter: FederatedServiceRouter {

    public static var baseURL: String = "https://gitlab.com/"
    public static var callbackURL: String = "callback"
    public let tokens: FederatedServiceTokens
    public let callbackCompletion: (Request, String) async throws -> Response
    public var scope: [String] = []
    public let callbackURL: String
    public let accessTokenURL: String = "\(GitlabRouter.baseURL.finished(with: "/"))oauth/token"
    public let service: OAuthService = .gitlab
    
    public required init(callback: String, completion: @escaping (Request, String) async throws -> Response) async throws {
        self.tokens = try GitlabAuth()
        self.callbackURL = callback
        self.callbackCompletion = completion
    }
    
    public func authURL(_ request: Request) throws -> String {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.gitlab.com"
        components.path = "/oauth/authorize"
        components.queryItems = [
            clientIDItem,
            .init(name: "redirect_uri", value: GitlabRouter.callbackURL),
            scopeItem,
            codeResponseTypeItem
        ]
        
        guard let url = components.url else {
            throw Abort(.internalServerError)
        }
        
        return url.absoluteString
    }
    
    public func callbackBody(with code: String) -> any Content {
        GitlabCallbackBody(clientId: tokens.clientID,
                           clientSecret: tokens.clientSecret,
                           code: code,
                           grantType: "authorization_code",
                           redirectUri: GitlabRouter.callbackURL)
    }
}
