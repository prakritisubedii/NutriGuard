//
//  LoginView.swift
//  NutriGuard_App
//
//  Sign in · Sign up · Forgot password — all in one screen.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthState

    @State private var mode: Mode = .login

    // Shared fields
    @State private var email   = ""
    @State private var password = ""

    // Sign-up only
    @State private var name            = ""
    @State private var confirmPassword = ""
    @State private var showPassword    = false
    @State private var showConfirm     = false

    // Forgot password
    @State private var resetEmailSent = false

    enum Mode { case login, signUp, forgotPassword }

    // MARK: Validation

    private var isValid: Bool {
        let e = email.trimmingCharacters(in: .whitespaces)
        switch mode {
        case .login:
            return e.contains("@") && !password.isEmpty
        case .signUp:
            return e.contains("@") && password.count >= 6
                && password == confirmPassword
                && !name.trimmingCharacters(in: .whitespaces).isEmpty
        case .forgotPassword:
            return e.contains("@") && e.contains(".")
        }
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                logoSection
                    .padding(.top, 56)
                    .padding(.bottom, 36)

                formCard
                    .padding(.horizontal, 20)

                bottomToggle
                    .padding(.top, 20)
                    .padding(.bottom, 44)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .animation(.spring(duration: 0.3), value: mode)
        .animation(.spring(duration: 0.3), value: resetEmailSent)
        .onChange(of: mode) { _, _ in
            auth.errorMessage = nil
            resetEmailSent    = false
        }
    }

    // MARK: - Sections

    private var logoSection: some View {
        VStack(spacing: 10) {
            Image("LogoWithText")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 600, maxHeight: 720)
        }
    }

    private var formCard: some View {
        VStack(spacing: 14) {
            // Mode picker (only login / sign up)
            if mode != .forgotPassword {
                Picker("Mode", selection: $mode) {
                    Text("Sign In").tag(Mode.login)
                    Text("Sign Up").tag(Mode.signUp)
                }
                .pickerStyle(.segmented)
            }

            // ── Forgot password success state ──
            if mode == .forgotPassword && resetEmailSent {
                resetSentState
            } else {
                fields
                errorRow
                primaryButton
                if mode == .login { forgotPasswordLink }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }

    // MARK: Fields

    @ViewBuilder
    private var fields: some View {
        if mode == .signUp {
            AuthTextField(icon: "person.fill", placeholder: "Full name", text: $name)
                .transition(.push(from: .top).combined(with: .opacity))
        }

        if mode == .forgotPassword {
            VStack(alignment: .leading, spacing: 6) {
                Text("Reset Password")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Text("Enter your account email and we'll send a reset link.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity)
        }

        AuthTextField(
            icon: "envelope.fill",
            placeholder: "Email address",
            text: $email
        )
        .keyboardType(.emailAddress)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()

        if mode != .forgotPassword {
            AuthSecureField(
                icon: "lock.fill",
                placeholder: "Password\(mode == .signUp ? " (min 6 chars)" : "")",
                text: $password,
                isRevealed: $showPassword
            )

            if mode == .signUp {
                AuthSecureField(
                    icon: "lock.shield.fill",
                    placeholder: "Confirm password",
                    text: $confirmPassword,
                    isRevealed: $showConfirm
                )
                .transition(.push(from: .top).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private var errorRow: some View {
        if let err = auth.errorMessage {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill").font(.footnote)
                Text(err).font(.system(.footnote, design: .rounded))
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var primaryButton: some View {
        Button { Task { await submit() } } label: {
            ZStack {
                if auth.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(buttonLabel)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isValid ? Color.green : Color.green.opacity(0.35))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!isValid || auth.isLoading)
    }

    private var forgotPasswordLink: some View {
        Button("Forgot password?") {
            withAnimation { mode = .forgotPassword }
        }
        .font(.system(.footnote, design: .rounded))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var resetSentState: some View {
        VStack(spacing: 14) {
            Image(systemName: "envelope.badge.shield.half.filled.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            VStack(spacing: 6) {
                Text("Check your inbox")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Text("A password reset link has been sent to\n\(email.lowercased())")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Back to Sign In") {
                withAnimation { mode = .login }
            }
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(.green)
            .padding(.top, 4)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private var bottomToggle: some View {
        Group {
            if mode == .forgotPassword {
                Button("Back to Sign In") {
                    withAnimation { mode = .login }
                }
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.green)
            } else {
                HStack(spacing: 4) {
                    Text(mode == .login ? "New to NutriGuard?" : "Already have an account?")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                    Button(mode == .login ? "Create account" : "Sign in") {
                        withAnimation { mode = (mode == .login) ? .signUp : .login }
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.green)
                }
            }
        }
    }

    // MARK: Helpers

    private var buttonLabel: String {
        switch mode {
        case .login:          return "Sign In"
        case .signUp:         return "Create Account"
        case .forgotPassword: return "Send Reset Link"
        }
    }

    private func submit() async {
        let e = email.trimmingCharacters(in: .whitespaces)
        switch mode {
        case .login:
            await auth.login(email: e, password: password)
        case .signUp:
            await auth.signUp(email: e, password: password,
                              name: name.trimmingCharacters(in: .whitespaces))
        case .forgotPassword:
            await auth.requestPasswordReset(email: e)
            if auth.errorMessage == nil {
                withAnimation { resetEmailSent = true }
            }
        }
    }
}

// MARK: - Reusable field components

private struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.green)
                .frame(width: 20)
            TextField(placeholder, text: $text)
                .autocorrectionDisabled()
        }
        .padding(13)
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }
}

private struct AuthSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @Binding var isRevealed: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.green)
                .frame(width: 20)
            Group {
                if isRevealed { TextField(placeholder, text: $text) }
                else          { SecureField(placeholder, text: $text) }
            }
            .autocorrectionDisabled()
            Button { isRevealed.toggle() } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(13)
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }
}

// MARK: - Splash view (session restore screen)

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 20) {
                Image("LogoIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 180, maxHeight: 120)
                ProgressView()
            }
        }
    }
}

// MARK: - Preview

@MainActor
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView().environmentObject(AuthState())
    }
}
