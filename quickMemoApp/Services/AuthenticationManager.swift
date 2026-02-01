import SwiftUI
import AuthenticationServices
import CryptoKit

@MainActor
class AuthenticationManager: NSObject, ObservableObject {
    static let shared = AuthenticationManager()

    @Published var userIdentifier: String? {
        didSet {
            if let userIdentifier = userIdentifier {
                UserDefaults.standard.set(userIdentifier, forKey: "userIdentifier")
            } else {
                UserDefaults.standard.removeObject(forKey: "userIdentifier")
            }
        }
    }

    @Published var userEmail: String?
    @Published var userName: String?
    @Published var isSignedIn: Bool = false
    @Published var authError: String?

    private var currentNonce: String?
    private var completionHandler: ((Result<ASAuthorizationAppleIDCredential, Error>) -> Void)?

    private override init() {
        super.init()
        // 保存されたユーザー情報を読み込み
        self.userIdentifier = UserDefaults.standard.string(forKey: "userIdentifier")
        self.userEmail = UserDefaults.standard.string(forKey: "userEmail")
        self.userName = UserDefaults.standard.string(forKey: "userName")
        self.isSignedIn = userIdentifier != nil
    }

    // MARK: - Sign in with Apple

    func signInWithApple(presentationAnchor: ASPresentationAnchor) {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func handleSignInWithAppleSuccess(_ credential: ASAuthorizationAppleIDCredential) async {
        print("🔐 AuthenticationManager: Sign in with Apple success")

        // ユーザー識別子を保存
        self.userIdentifier = credential.user
        print("  - User ID: \(credential.user)")

        // メールアドレスを保存（初回のみ提供される）
        if let email = credential.email {
            self.userEmail = email
            UserDefaults.standard.set(email, forKey: "userEmail")
            print("  - Email: \(email)")
        }

        // フルネームを保存（初回のみ提供される）
        if let fullName = credential.fullName {
            let name = PersonNameComponentsFormatter.localizedString(from: fullName, style: .default)
            if !name.isEmpty {
                self.userName = name
                UserDefaults.standard.set(name, forKey: "userName")
                print("  - Name: \(name)")
            }
        }

        self.isSignedIn = true
        print("  ✅ Sign in completed, starting CloudKit sync...")

        // CloudKitマネージャーに権利情報を同期
        await CloudKitManager.shared.syncSubscriptionStatus()
    }

    // MARK: - Sign Out

    func signOut() {
        self.userIdentifier = nil
        self.userEmail = nil
        self.userName = nil
        self.isSignedIn = false

        UserDefaults.standard.removeObject(forKey: "userIdentifier")
        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "userName")

        // CloudKitから権利情報を削除
        Task {
            await CloudKitManager.shared.clearSubscriptionStatus()
        }
    }

    // MARK: - Check Existing Credentials

    func checkExistingCredentials() {
        guard let userIdentifier = userIdentifier else {
            isSignedIn = false
            return
        }

        // Apple IDプロバイダーで認証状態を確認
        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: userIdentifier) { [weak self] state, error in
            Task { @MainActor in
                switch state {
                case .authorized:
                    self?.isSignedIn = true
                case .revoked, .notFound:
                    self?.signOut()
                default:
                    break
                }
            }
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthenticationManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            Task {
                await handleSignInWithAppleSuccess(credential)
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                // ユーザーがキャンセル
                break
            case .failed:
                self.authError = "認証に失敗しました"
            case .invalidResponse:
                self.authError = "無効なレスポンスです"
            case .notHandled:
                self.authError = "認証がハンドルされませんでした"
            case .unknown:
                self.authError = "不明なエラーが発生しました"
            @unknown default:
                self.authError = error.localizedDescription
            }
        } else {
            self.authError = error.localizedDescription
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthenticationManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // アクティブなウィンドウを返す
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else {
            fatalError("No key window found")
        }
        return window
    }
}

// MARK: - Sign in with Apple Button View

struct SignInWithAppleButton: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @Environment(\.colorScheme) var colorScheme

    var onSignInCompleted: (() -> Void)?

    var body: some View {
        SignInWithAppleButtonView(onTap: {
            if let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }) {
                authManager.signInWithApple(presentationAnchor: window)
            }
        })
        .frame(height: 50)
        .onChange(of: authManager.isSignedIn) { newValue in
            if newValue {
                onSignInCompleted?()
            }
        }
    }
}

struct SignInWithAppleButtonView: UIViewRepresentable {
    @Environment(\.colorScheme) var colorScheme
    let onTap: () -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(
            authorizationButtonType: .signIn,
            authorizationButtonStyle: colorScheme == .dark ? .white : .black
        )
        button.addTarget(context.coordinator, action: #selector(Coordinator.handleButtonTap), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
        // ボタンの更新は不要
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    class Coordinator: NSObject {
        let onTap: () -> Void

        init(onTap: @escaping () -> Void) {
            self.onTap = onTap
        }

        @objc func handleButtonTap() {
            onTap()
        }
    }
}