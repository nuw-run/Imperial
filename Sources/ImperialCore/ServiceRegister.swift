import Vapor

extension RoutesBuilder {
    
    /// Registers an OAuth provider's router with
    /// the parent route.
    ///
    /// - Parameters:
    ///   - provider: The provider who's router will be used.
    ///   - authUrl: The path to navigate to authenticate.
    ///   - authenticateCallback: Execute custom code within the authenticate closure before redirection.
    ///   - callback: The path or URL that the provider with
    ///     redirect to when authentication completes.
    ///   - scope: The scopes to get access to on authentication.
    ///   - completion: A callback with the current request and fetched
    ///     access token that is called when auth completes.
    public func oAuth<OAuthProvider>(
        from provider: OAuthProvider.Type,
        authenticate authUrl: String,
        authenticateCallback: ((Request) async throws -> Void)? = nil,
        callback: String,
        scope: [String] = [],
        completion: @escaping (Request, String) async throws -> Response
    ) async throws where OAuthProvider: FederatedService {
        _ = try await OAuthProvider(
            routes: self,
            authenticate: authUrl,
            authenticateCallback: authenticateCallback,
            callback: callback,
            scope: scope,
            completion: completion
        )
    }
    
    /// Registers an OAuth provider's router with
    /// the parent route and a redirection callback.
    ///
    /// - Parameters:
    ///   - provider: The provider who's router will be used.
    ///   - authUrl: The path to navigate to authenticate.
    ///   - authenticateCallback: Execute custom code within the authenticate closure before redirection.
    ///   - callback: The path or URL that the provider with
    ///     redirect to when authentication completes.
    ///   - scope: The scopes to get access to on authentication.
    ///   - redirect: The path/URL to redirect to when auth completes.
    public func oAuth<OAuthProvider>(
        from provider: OAuthProvider.Type,
        authenticate authUrl: String,
        authenticateCallback: ((Request) async throws -> Void)? = nil,
        callback: String,
        scope: [String] = [],
        redirect redirectURL: String
    ) async throws where OAuthProvider: FederatedService {
        try await self.oAuth(from: OAuthProvider.self, authenticate: authUrl, authenticateCallback: authenticateCallback, callback: callback, scope: scope) { (request, _) in
            let redirect: Response = request.redirect(to: redirectURL)
            return redirect
        }
    }
}
