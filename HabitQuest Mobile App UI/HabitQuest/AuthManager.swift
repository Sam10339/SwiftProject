import Foundation
import FirebaseAuth
import FirebaseCore

struct AuthSession: Equatable {
    let userID: String
    let email: String?
}

enum AuthError: LocalizedError {
    case firebaseNotConfigured
    case emptyCredentials
    case missingResetEmail

    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured:
            return "Firebase isn't configured yet. Add a GoogleService-Info.plist file from the Firebase console to enable auth."
        case .emptyCredentials:
            return "Enter both your email and password."
        case .missingResetEmail:
            return "Enter your email address first so we know where to send the reset link."
        }
    }
}

protocol AuthManaging {
    var isConfigured: Bool { get }
    var currentUserEmail: String? { get }
    var currentSession: AuthSession? { get }

    func observeAuthChanges(_ handler: @escaping (AuthSession?) -> Void)
    func signIn(email: String, password: String, isSignUp: Bool) async throws -> AuthSession
    func sendPasswordReset(email: String) async throws
    func signOut() throws
}

enum FirebaseBootstrap {
    @discardableResult
    static func configureIfPossible() -> Bool {
        if FirebaseApp.app() != nil {
            return true
        }

        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            return false
        }

        FirebaseApp.configure()
        return true
    }
}

final class FirebaseAuthManager: AuthManaging {
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    var isConfigured: Bool {
        FirebaseApp.app() != nil
    }

    var currentUserEmail: String? {
        guard isConfigured else { return nil }
        return Auth.auth().currentUser?.email
    }

    var currentSession: AuthSession? {
        guard isConfigured, let user = Auth.auth().currentUser else { return nil }
        return AuthSession(userID: user.uid, email: user.email)
    }

    deinit {
        guard let authStateHandle, isConfigured else { return }
        Auth.auth().removeStateDidChangeListener(authStateHandle)
    }

    func observeAuthChanges(_ handler: @escaping (AuthSession?) -> Void) {
        guard isConfigured else {
            handler(nil)
            return
        }

        if let authStateHandle {
            Auth.auth().removeStateDidChangeListener(authStateHandle)
        }

        authStateHandle = Auth.auth().addStateDidChangeListener { _, user in
            guard let user else {
                handler(nil)
                return
            }

            handler(AuthSession(userID: user.uid, email: user.email))
        }
    }

    func signIn(email: String, password: String, isSignUp: Bool) async throws -> AuthSession {
        guard isConfigured else {
            throw AuthError.firebaseNotConfigured
        }

        let result: AuthDataResult
        if isSignUp {
            result = try await Auth.auth().createUser(withEmail: email, password: password)
        } else {
            result = try await Auth.auth().signIn(withEmail: email, password: password)
        }

        return AuthSession(userID: result.user.uid, email: result.user.email)
    }

    func sendPasswordReset(email: String) async throws {
        guard isConfigured else {
            throw AuthError.firebaseNotConfigured
        }

        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    func signOut() throws {
        guard isConfigured else {
            throw AuthError.firebaseNotConfigured
        }

        try Auth.auth().signOut()
    }
}
