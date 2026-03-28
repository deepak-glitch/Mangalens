import SwiftUI

struct SignupView: View {

    @EnvironmentObject var auth: SupabaseService
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 52))
                            .foregroundStyle(.blue)

                        Text("Create Account")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Join MangaLens to save your scan history")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 32)

                    // Form
                    VStack(spacing: 14) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)

                        SecureField("Password (min 6 characters)", text: $password)
                            .textContentType(.newPassword)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)

                        SecureField("Confirm Password", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)

                        // Validation hints
                        if !password.isEmpty && password.count < 6 {
                            Label("Password must be at least 6 characters", systemImage: "exclamationmark.circle")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }

                        if !confirmPassword.isEmpty && password != confirmPassword {
                            Label("Passwords do not match", systemImage: "exclamationmark.circle")
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        if let err = errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }

                        if let success = successMessage {
                            VStack(spacing: 6) {
                                Label(success, systemImage: "checkmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                                    .multilineTextAlignment(.center)

                                Button("Back to Sign In") { dismiss() }
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                            }
                            .padding(.top, 4)
                        }

                        if successMessage == nil {
                            Button {
                                signup()
                            } label: {
                                Group {
                                    if auth.isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Create Account")
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
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .navigationTitle("Sign Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var isFormValid: Bool {
        !email.isEmpty && password.count >= 6 && password == confirmPassword
    }

    private func signup() {
        errorMessage = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            do {
                try await auth.signUp(email: email, password: password)
                // If signUp auto-logged in (email confirmation disabled), auth.isLoggedIn = true
                // and the parent ContentView will switch to the main TabView automatically.
                // If email confirmation is required, show success message.
                if !auth.isLoggedIn {
                    successMessage = "Account created! Check your email to confirm your address, then sign in."
                }
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
    SignupView()
        .environmentObject(SupabaseService())
}
#endif
