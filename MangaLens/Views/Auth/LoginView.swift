import SwiftUI

struct LoginView: View {

    @EnvironmentObject var auth: SupabaseService

    @State private var email = ""
    @State private var password = ""
    @State private var showSignup = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo / Branding
                    VStack(spacing: 10) {
                        Image(systemName: "viewfinder.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(.blue)

                        Text("MangaLens")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Translate manga instantly")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 48)

                    // Form
                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)

                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)

                        if let err = errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            login()
                        } label: {
                            Group {
                                if auth.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Sign In")
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isFormValid ? Color.blue : Color.blue.opacity(0.4))
                            .cornerRadius(14)
                        }
                        .disabled(!isFormValid || auth.isLoading)
                    }
                    .padding(.horizontal, 24)

                    // Sign up link
                    Button {
                        showSignup = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundColor(.secondary)
                            Text("Sign Up")
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        .font(.subheadline)
                    }

                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSignup) {
                SignupView()
                    .environmentObject(auth)
            }
        }
    }

    private var isFormValid: Bool {
        !email.isEmpty && password.count >= 6
    }

    private func login() {
        errorMessage = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            do {
                try await auth.signIn(email: email, password: password)
            } catch let error as SupabaseError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    LoginView()
        .environmentObject(SupabaseService())
}
#endif
