import Foundation
import Vapor

/// Defines a type that implements the routing to get an access token from an OAuth provider.
/// See implementations in the `Services/(Google|GitHub)/$0Router.swift` files
public protocol FederatedServiceRouter {
    
    /// A class that gets the client ID and secret from environment variables.
    var tokens: FederatedServiceTokens { get }
    
    /// The callback that is fired after the access token is fetched from the OAuth provider.
    /// The response that is returned from this callback is also returned from the callback route.
    var callbackCompletion: (Request, String) async throws -> Response { get }
    
    /// The scopes to get permission for when getting the access token.
    /// Usage of this property varies by provider.
    var scope: [String] { get set }
    
    /// The key to acess the code URL query parameter
    var codeKey: String { get }
    
    /// The key to acess the error URL query parameter
    var errorKey: String { get }
    
    /// The OAuthService associated with the router
    var service: OAuthService { get }
    
    /// The URL (or URI) for that route that the provider will fire when the user authenticates with the OAuth provider.
    var callbackURL: String { get }
    
    /// HTTPHeaders for the Callback request
    var callbackHeaders: HTTPHeaders { get }

    /// The URL on the app that will redirect to the `authURL` to get the access token from the OAuth provider.
    var accessTokenURL: String { get }
    
    /// The URL of the page that the user will be redirected to to get the access token.
    func authURL(_ request: Request) throws -> String
    
    /// Creates an instence of the type implementing the protocol.
    ///
    /// - Parameters:
    ///   - callback: The callback URL that the OAuth provider will redirect to after authenticating the user.
    ///   - completion: The completion handler that will be fired at the end of the `callback` route. The access token is passed into it.
    /// - Throws: Any errors that could occur in the implementation.
    init(callback: String, completion: @escaping (Request, String) async throws -> Response) async throws
    
    /// Configures the `authenticate` and `callback` routes with the droplet.
    ///
    /// - Parameters:
    ///   - authURL: The URL for the route that will redirect the user to the OAuth provider.
    ///   - authenticateCallback: Execute custom code within the authenticate closure before redirection.
    /// - Throws: N/A
    func configureRoutes(withAuthURL authURL: String, authenticateCallback: ((Request) async throws -> Void)?, on router: RoutesBuilder) async throws
    
    /// Gets an access token from an OAuth provider.
    /// This method is the main body of the `callback` handler.
    ///
    /// - Parameters: request: The request for the route
    ///   this method is called in.
    func fetchToken(from request: Request) async throws -> String
    
    /// Creates CallbackBody with authorization code
    func callbackBody(with code: String) -> any Content
    
    /// The route that the OAuth provider calls when the user has been authenticated.
    ///
    /// - Parameter request: The request from the OAuth provider.
    /// - Returns: A response that should redirect the user back to the app.
    /// - Throws: An errors that occur in the implementation code.
    func callback(_ request: Request) async throws -> Response
}

extension FederatedServiceRouter {
    
    public var codeKey: String { "code" }
    public var errorKey: String { "error" }
    public var callbackHeaders: HTTPHeaders { [:] }
   
    public func configureRoutes(withAuthURL authURL: String, authenticateCallback: ((Request) async throws -> Void)?, on router: RoutesBuilder) async throws {
        router.get(callbackURL.pathComponents, use: self.callback)
		router.get(authURL.pathComponents) { req async throws -> Response in
            let redirect: Response = req.redirect(to: try self.authURL(req))
            guard let authenticateCallback = authenticateCallback else {
                return redirect
            }
            try await authenticateCallback(req)
            return redirect
        }
    }
    
    public func fetchToken(from request: Request) async throws -> String {
        let code: String
        if let queryCode: String = try request.query.get(at: codeKey) {
            code = queryCode
        } else if let error: String = try request.query.get(at: errorKey) {
            throw Abort(.badRequest, reason: error)
        } else {
            throw Abort(.badRequest, reason: "Missing 'code' key in URL query")
        }
        
        let url = URI(string: accessTokenURL)
        let body = try JSONEncoder().encode(callbackBody(with: code))
        
        let response = try await request.client.post(url, headers: self.callbackHeaders, beforeSend: { r in
            r.body = ByteBuffer(data: body)
        })
        return try response.content.get(String.self, at: ["access_token"])
    }
    
    public func callback(_ request: Request) async throws -> Response {
        let accessToken = try await self.fetchToken(from: request)
        let session = request.session
        try session.setAccessToken(accessToken)
        try session.set("access_token_service", to: self.service)
        return try await self.callbackCompletion(request, accessToken)
    }
}

/// Convenience URLQueryItems
extension FederatedServiceRouter {
    public var clientIDItem: URLQueryItem {
        .init(name: "client_id", value: tokens.clientID)
    }
    
    public var redirectURIItem: URLQueryItem {
        .init(name: "redirect_uri", value: callbackURL)
    }
    
    public var scopeItem: URLQueryItem {
        .init(name: "scope", value: scope.joined(separator: " "))
    }
    
    public var codeResponseTypeItem: URLQueryItem {
        .init(name: "response_type", value: "code")
    }
}
