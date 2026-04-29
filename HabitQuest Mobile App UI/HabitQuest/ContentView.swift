import SwiftUI

private let threeColumnGrid = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
private let twoColumnGrid = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
private let sixColumnGrid = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)
private let calendarGrid = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

struct ContentView: View {
    @EnvironmentObject private var store: HabitQuestStore

    var body: some View {
        QuestDeviceContainer {
            Group {
                switch store.phase {
                case .splash:
                    SplashScreen()
                case .onboarding:
                    OnboardingScreen()
                case .login:
                    LoginScreen()
                case .main:
                    MainExperienceView()
                }
            }
            .background(Color.white)
        }
    }
}

private struct QuestDeviceContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let showsPreviewShell = proxy.size.width > 520
            ZStack {
                QuestPalette.outerBackground
                    .ignoresSafeArea()

                if showsPreviewShell {
                    content
                        .frame(
                            width: min(QuestLayout.maxPhoneWidth, proxy.size.width - 48),
                            height: min(QuestLayout.maxPhoneHeight, proxy.size.height - 48)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                        .shadow(color: Color.black.opacity(0.18), radius: 28, x: 0, y: 18)
                } else {
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}

private struct MainExperienceView: View {
    @EnvironmentObject private var store: HabitQuestStore

    private var pathBinding: Binding<[AppDestination]> {
        Binding(
            get: { store.path },
            set: { store.path = $0 }
        )
    }

    var body: some View {
        NavigationStack(path: pathBinding) {
            MainTabShell()
                .navigationDestination(for: AppDestination.self) { destination in
                    switch destination {
                    case .addHabit:
                        AddHabitScreen()
                    case .habitDetail(let id):
                        HabitDetailScreen(habitID: id)
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct MainTabShell: View {
    @EnvironmentObject private var store: HabitQuestStore

    var body: some View {
        Group {
            switch store.selectedTab {
            case .dashboard:
                DashboardScreen()
            case .analytics:
                AnalyticsScreen()
            case .achievements:
                AchievementsScreen()
            case .profile:
                ProfileScreen()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            QuestTabBar(selectedTab: store.selectedTab) { tab in
                withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                    store.selectedTab = tab
                }
            }
        }
    }
}

private struct SplashScreen: View {
    @EnvironmentObject private var store: HabitQuestStore
    @State private var logoVisible = false
    @State private var spinLoader = false

    var body: some View {
        ZStack(alignment: .bottom) {
            QuestPalette.primaryGradient.linear
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(.white.opacity(0.18))
                        .frame(width: 128, height: 128)
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .stroke(.white.opacity(0.28), lineWidth: 4)
                        )
                        .overlay(
                            Text("\u{1F3AE}")
                                .font(.system(size: 68))
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 24, x: 0, y: 16)
                        .scaleEffect(logoVisible ? 1 : 0.2)
                        .rotationEffect(.degrees(logoVisible ? 0 : -180))

                    Text("HabitQuest")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(logoVisible ? 1 : 0)
                        .offset(y: logoVisible ? 0 : 20)

                    Text("Level up your habits")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.top, 2)
                        .opacity(logoVisible ? 1 : 0)
                        .offset(y: logoVisible ? 0 : 20)

                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .stroke(.white.opacity(0.2), lineWidth: 4)
                                .frame(width: 48, height: 48)

                            Circle()
                                .trim(from: 0.08, to: 0.82)
                                .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 48, height: 48)
                                .rotationEffect(.degrees(spinLoader ? 360 : 0))
                        }
                        .padding(.top, 42)

                        Text("Loading...")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .opacity(logoVisible ? 1 : 0)
                }

                Spacer()
            }
            .padding(.horizontal, 32)

            Text("Version 1.0.0")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
                .padding(.bottom, 24)
        }
        .task {
            guard store.phase == .splash else { return }

            withAnimation(.spring(response: 0.82, dampingFraction: 0.78)) {
                logoVisible = true
            }
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                spinLoader = true
            }

            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.35)) {
                    store.completeSplash()
                }
            }
        }
    }
}

private struct OnboardingScreen: View {
    @EnvironmentObject private var store: HabitQuestStore
    @State private var currentStep = 0

    private var step: OnboardingStepModel {
        SampleData.onboardingSteps[currentStep]
    }

    private var isLastStep: Bool {
        currentStep == SampleData.onboardingSteps.count - 1
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                if !isLastStep {
                    Button("Skip") {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            store.finishOnboarding()
                        }
                    }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(QuestPalette.gray400)
                    .padding(.top, 24)
                    .padding(.trailing, QuestLayout.contentPadding)
                } else {
                    Color.clear.frame(height: 40)
                }
            }

            Spacer()

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(step.gradient.linear)
                        .frame(width: 128, height: 128)
                        .shadow(color: Color.black.opacity(0.14), radius: 20, x: 0, y: 12)
                        .overlay(
                            Text(step.icon)
                                .font(.system(size: 62))
                        )
                        .padding(.bottom, 32)

                    Text(step.title)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(QuestPalette.gray900)
                        .lineSpacing(4)
                        .padding(.bottom, 16)

                    Text(step.description)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(QuestPalette.gray500)
                        .lineSpacing(4)
                        .padding(.horizontal, 24)

                    if !step.features.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(Array(step.features.enumerated()), id: \.offset) { index, feature in
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(step.gradient.linear)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Image(systemName: feature.symbolName)
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundStyle(.white)
                                        )

                                    Text(feature.text)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(QuestPalette.gray700)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(12)
                                .questCardStyle(
                                    background: AnyShapeStyle(Color.white),
                                    border: QuestPalette.gray100,
                                    shadowColor: Color.black.opacity(0.05),
                                    shadowRadius: 10,
                                    shadowY: 6
                                )
                                .animation(.easeOut(duration: 0.25).delay(0.08 * Double(index)), value: currentStep)
                            }
                        }
                        .padding(.top, 28)
                        .padding(.horizontal, 24)
                    }
                }
                .id(currentStep)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                .animation(.easeInOut(duration: 0.28), value: currentStep)
            }
            .padding(.horizontal, 8)

            Spacer()

            HStack(spacing: 8) {
                ForEach(0..<SampleData.onboardingSteps.count, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(index == currentStep ? AnyShapeStyle(QuestPalette.primaryGradient.horizontal) : AnyShapeStyle(QuestPalette.gray300))
                        .frame(width: index == currentStep ? 32 : 8, height: 8)
                        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: currentStep)
                }
            }
            .padding(.bottom, 24)

            Button {
                if isLastStep {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        store.finishOnboarding()
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.28)) {
                        currentStep += 1
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(isLastStep ? "Get Started" : "Continue")
                    if !isLastStep {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
            }
            .buttonStyle(QuestFilledButtonStyle(gradient: step.gradient))
            .padding(.horizontal, QuestLayout.contentPadding)
            .padding(.bottom, 28)
        }
    }
}

private struct LoginScreen: View {
    @EnvironmentObject private var store: HabitQuestStore
    @State private var email = ""
    @State private var password = ""
    @State private var showsPassword = false
    @State private var isSignUp = false

    private var authButtonTitle: String {
        store.isAuthenticating ? (isSignUp ? "Creating Account..." : "Signing In...") : (isSignUp ? "Sign Up" : "Sign In")
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white.opacity(0.18))
                    .frame(width: 80, height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.28), lineWidth: 2)
                    )
                    .overlay(
                        Text("\u{1F3AE}")
                            .font(.system(size: 48))
                    )
                    .shadow(color: Color.black.opacity(0.16), radius: 18, x: 0, y: 10)

                VStack(spacing: 4) {
                    Text("HabitQuest")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Level up your habits")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 56)
            .padding(.bottom, 48)
            .background(QuestPalette.primaryGradient.linear)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isSignUp ? "Create Account" : "Welcome Back")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(QuestPalette.gray900)

                        Text(isSignUp ? "Sign up to start your habit journey" : "Sign in to continue your quest")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(QuestPalette.gray500)
                    }

                    VStack(spacing: 20) {
                        if let authErrorMessage = store.authErrorMessage {
                            AuthMessageCard(
                                text: authErrorMessage,
                                tint: QuestPalette.red,
                                background: Color(hex: 0xFEF2F2),
                                border: Color(hex: 0xFECACA),
                                systemImage: "exclamationmark.circle.fill"
                            )
                        }

                        if let authInfoMessage = store.authInfoMessage {
                            AuthMessageCard(
                                text: authInfoMessage,
                                tint: QuestPalette.green,
                                background: Color(hex: 0xECFDF3),
                                border: Color(hex: 0xA7F3D0),
                                systemImage: "checkmark.circle.fill"
                            )
                        }

                        if !store.isFirebaseConfigured {
                            AuthMessageCard(
                                text: "Firebase is not fully connected yet. Add `GoogleService-Info.plist` to turn on auth.",
                                tint: QuestPalette.orange,
                                background: Color(hex: 0xFFF7ED),
                                border: Color(hex: 0xFED7AA),
                                systemImage: "wrench.and.screwdriver.fill"
                            )
                        }

                        LabeledTextField(
                            title: "Email",
                            placeholder: "Enter your email",
                            text: $email,
                            leadingSystemImage: "envelope.fill"
                        )
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(QuestPalette.gray700)

                            HStack(spacing: 12) {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(QuestPalette.gray400)
                                    .frame(width: 20)

                                Group {
                                    if showsPassword {
                                        TextField("Enter your password", text: $password)
                                    } else {
                                        SecureField("Enter your password", text: $password)
                                    }
                                }
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(QuestPalette.gray900)

                                Button {
                                    showsPassword.toggle()
                                } label: {
                                    Image(systemName: showsPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundStyle(QuestPalette.gray400)
                                }
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 56)
                            .background(QuestPalette.gray50)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(QuestPalette.gray200, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }

                        if !isSignUp {
                            HStack {
                                Spacer()
                                Button("Forgot Password?") {
                                    Task {
                                        await store.sendPasswordReset(email: email)
                                    }
                                }
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(QuestPalette.purple)
                                    .disabled(store.isAuthenticating)
                            }
                        }

                        Button {
                            Task {
                                await store.signIn(email: email, password: password, isSignUp: isSignUp)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                if store.isAuthenticating {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                }

                                Text(authButtonTitle)
                            }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                        }
                        .buttonStyle(QuestFilledButtonStyle(gradient: QuestPalette.primaryGradient))
                        .disabled(store.isAuthenticating)
                    }

                    HStack(spacing: 16) {
                        Rectangle()
                            .fill(QuestPalette.gray200)
                            .frame(height: 1)
                        Text("Or continue with")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(QuestPalette.gray500)
                        Rectangle()
                            .fill(QuestPalette.gray200)
                            .frame(height: 1)
                    }

                    VStack(spacing: 12) {
                        Button {
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "applelogo")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Apple Sign-In Soon")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                        }
                        .buttonStyle(QuestSolidButtonStyle(background: .black, foreground: .white))
                        .disabled(true)
                        .opacity(0.6)

                        Button {
                        } label: {
                            HStack(spacing: 12) {
                                Text("G")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color(hex: 0x4285F4), Color(hex: 0x34A853), Color(hex: 0xFBBC05), Color(hex: 0xEA4335)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Text("Google Sign-In Soon")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                        }
                        .buttonStyle(QuestOutlinedButtonStyle())
                        .disabled(true)
                        .opacity(0.6)
                    }

                    HStack(spacing: 4) {
                        Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                            .foregroundStyle(QuestPalette.gray500)

                        Button(isSignUp ? "Sign In" : "Sign Up") {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isSignUp.toggle()
                                store.authErrorMessage = nil
                                store.authInfoMessage = nil
                            }
                        }
                        .foregroundStyle(QuestPalette.purple)
                        .fontWeight(.semibold)
                    }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
                .padding(.horizontal, QuestLayout.contentPadding)
                .padding(.vertical, 32)
            }
        }
    }
}

private struct DashboardScreen: View {
    @EnvironmentObject private var store: HabitQuestStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                VStack(spacing: 20) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("HabitQuest")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(store.todayLabel)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.78))
                        }

                        Spacer()

                        Button {
                            store.showAddHabit()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .frame(width: 48, height: 48)
                        }
                        .buttonStyle(QuestGlassIconButtonStyle())
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Level \(store.userProfile.level)")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.78))
                                Text("\(store.userProfile.currentXP.formatted(.number.grouping(.automatic))) / \(store.userProfile.xpToNextLevel.formatted(.number.grouping(.automatic))) XP")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }

                            Spacer()

                            Text(store.userProfile.avatar)
                                .font(.system(size: 34))
                        }

                        QuestProgressBar(
                            progress: store.xpProgress,
                            fillStyle: AnyShapeStyle(Color.white),
                            trackColor: .white.opacity(0.22),
                            height: 8
                        )
                    }
                    .padding(16)
                    .questCardStyle(
                        background: AnyShapeStyle(Color.white.opacity(0.12)),
                        border: .white.opacity(0.22),
                        shadowColor: .clear
                    )
                }
                .padding(.horizontal, QuestLayout.contentPadding)
                .padding(.top, 50)
                .padding(.bottom, 28)
                .background(
                    QuestPalette.primaryGradient.linear
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: 32,
                                bottomTrailingRadius: 32,
                                topTrailingRadius: 0,
                                style: .continuous
                            )
                        )
                )

                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Today's Progress")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(QuestPalette.gray900)

                        HStack(spacing: 24) {
                            QuestProgressRing(progress: Double(store.dailyCompletionPercentage) / 100, size: 100, lineWidth: 8) {
                                VStack(spacing: 2) {
                                    Text("\(store.completedHabitsCount)")
                                        .font(.system(size: 30, weight: .bold, design: .rounded))
                                        .foregroundStyle(QuestPalette.purple)
                                    Text("of \(store.habits.count)")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(QuestPalette.gray500)
                                }
                            }

                            VStack(spacing: 14) {
                                DashboardStatLine(label: "Completion", value: "\(store.dailyCompletionPercentage)%", valueColor: QuestPalette.gray900)
                                DashboardStatLine(label: "XP Earned", value: "+\(store.totalXPToday) XP", valueGradient: QuestPalette.primaryGradient)
                                DashboardStatLine(label: "Longest Streak", value: "\(store.userProfile.longestStreak) days", valueColor: QuestPalette.orange)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(20)
                    .questCardStyle()

                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(QuestPalette.primaryGradient.linear)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "sparkles")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                            )

                        Text(store.motivationalMessage)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(QuestPalette.gray700)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                    .questCardStyle(
                        background: AnyShapeStyle(
                            LinearGradient(colors: [QuestPalette.purpleSoft, Color(hex: 0xEEF2FF)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        ),
                        border: Color(hex: 0xE9D5FF),
                        shadowColor: Color.black.opacity(0.03),
                        shadowRadius: 10,
                        shadowY: 6
                    )

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Today's Habits")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(QuestPalette.gray900)

                        if store.habits.isEmpty {
                            VStack(spacing: 12) {
                                Text("No habits yet")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(QuestPalette.gray900)
                                Text("Create your first habit to start earning XP.")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(QuestPalette.gray500)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(24)
                            .questCardStyle()
                        } else {
                            VStack(spacing: 12) {
                                ForEach(store.habits) { habit in
                                    HabitRowCard(
                                        habit: habit,
                                        onToggle: {
                                            store.toggleHabit(id: habit.id)
                                        },
                                        onSelect: {
                                            store.showHabitDetail(id: habit.id)
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, QuestLayout.contentPadding)
                .padding(.bottom, 24)
            }
        }
        .background(Color.white)
    }
}

private struct AddHabitScreen: View {
    @EnvironmentObject private var store: HabitQuestStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = HabitDraft()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Create New Habit")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(QuestGlassIconButtonStyle())
            }
            .padding(.horizontal, QuestLayout.contentPadding)
            .padding(.top, 50)
            .padding(.bottom, 24)
            .background(QuestPalette.primaryGradient.linear)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    LabeledTextField(
                        title: "Habit Name",
                        placeholder: "e.g., Morning Meditation",
                        text: $draft.name
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel("Choose Icon")

                        LazyVGrid(columns: sixColumnGrid, spacing: 12) {
                            ForEach(SampleData.habitIconOptions, id: \.self) { icon in
                                Button {
                                    draft.icon = icon
                                } label: {
                                    Text(icon)
                                        .font(.system(size: 28))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 52)
                                }
                                .buttonStyle(QuestOptionButtonStyle(isSelected: draft.icon == icon))
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel("Category")

                        LazyVGrid(columns: twoColumnGrid, spacing: 12) {
                            ForEach(SampleData.categories, id: \.self) { category in
                                Button(category) {
                                    draft.category = category
                                }
                                .buttonStyle(QuestChipButtonStyle(isSelected: draft.category == category))
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel("Frequency")

                        LazyVGrid(columns: twoColumnGrid, spacing: 12) {
                            ForEach(SampleData.frequencies, id: \.self) { frequency in
                                Button(frequency) {
                                    draft.frequency = frequency
                                }
                                .buttonStyle(QuestChipButtonStyle(isSelected: draft.frequency == frequency))
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Label("Set Reminder", systemImage: "clock.fill")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(QuestPalette.gray900)

                            Spacer()

                            QuestToggle(isOn: $draft.reminderEnabled)
                        }

                        if draft.reminderEnabled {
                            DatePicker(
                                "Reminder Time",
                                selection: $draft.reminderTime,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                            .frame(height: 150)
                            .clipped()
                        }
                    }
                    .padding(16)
                    .questCardStyle(
                        background: AnyShapeStyle(Color.white),
                        border: QuestPalette.gray200,
                        shadowColor: Color.black.opacity(0.04),
                        shadowRadius: 10,
                        shadowY: 6
                    )
                }
                .padding(.horizontal, QuestLayout.contentPadding)
                .padding(.vertical, 24)
            }

            Button {
                store.addHabit(from: draft)
                dismiss()
            } label: {
                Text("Create Habit")
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            }
            .buttonStyle(QuestFilledButtonStyle(gradient: QuestPalette.primaryGradient))
            .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
            .padding(.horizontal, QuestLayout.contentPadding)
            .padding(.bottom, 24)
        }
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct HabitDetailScreen: View {
    @EnvironmentObject private var store: HabitQuestStore
    @Environment(\.dismiss) private var dismiss
    let habitID: String

    var body: some View {
        Group {
            if let habit = store.habit(withID: habitID) {
                HabitDetailContent(habit: habit)
            } else {
                VStack(spacing: 16) {
                    Text("Habit not found")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Button("Back to Dashboard") {
                        dismiss()
                    }
                    .buttonStyle(QuestFilledButtonStyle(gradient: QuestPalette.primaryGradient))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func HabitDetailContent(habit: Habit) -> some View {
        let calendarInfo = HabitCalendarInfo(habit: habit)

        VStack(spacing: 0) {
            VStack(spacing: 20) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 17, weight: .bold))
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(QuestGlassIconButtonStyle())

                    Spacer()

                    HStack(spacing: 8) {
                        Button(action: { }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 16, weight: .bold))
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(QuestGlassIconButtonStyle())

                        Button {
                            store.deleteHabit(id: habit.id)
                            dismiss()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .bold))
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(QuestGlassIconButtonStyle())
                    }
                }

                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.white.opacity(0.18))
                        .frame(width: 64, height: 64)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(.white.opacity(0.28), lineWidth: 1)
                        )
                        .overlay(
                            Text(habit.icon)
                                .font(.system(size: 36))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(habit.name)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("\(habit.category) \u{2022} \(habit.frequency)")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, QuestLayout.contentPadding)
            .padding(.top, 50)
            .padding(.bottom, 24)
            .background(QuestPalette.primaryGradient.linear)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    LazyVGrid(columns: threeColumnGrid, spacing: 12) {
                        DetailStatCard(emoji: "\u{1F525}", value: "\(habit.streak)", label: "Day Streak", tintBackground: Color(hex: 0xFFF7ED), border: Color(hex: 0xFED7AA))
                        DetailStatCard(emoji: "\u{26A1}", value: "\(habit.xp)", label: "XP / Day", tintBackground: QuestPalette.purpleSoft, border: Color(hex: 0xE9D5FF))
                        DetailStatCard(emoji: "\u{2713}", value: "\(calendarInfo.completionRate)%", label: "Complete", tintBackground: QuestPalette.greenSoft, border: Color(hex: 0xBBF7D0))
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Label("Completion History", systemImage: "calendar")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(QuestPalette.gray900)

                        Text(calendarInfo.monthTitle)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(QuestPalette.gray500)

                        LazyVGrid(columns: calendarGrid, spacing: 8) {
                            ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { symbol in
                                Text(symbol)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(QuestPalette.gray500)
                                    .frame(maxWidth: .infinity)
                            }

                            ForEach(0..<calendarInfo.leadingBlankDays, id: \.self) { _ in
                                Color.clear.frame(height: 34)
                            }

                            ForEach(calendarInfo.days) { day in
                                Text("\(day.number)")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(day.foregroundColor)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 34)
                                    .background(day.backgroundStyle)
                                    .overlay(day.borderShape)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                    }
                    .padding(20)
                    .questCardStyle()

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Statistics")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(QuestPalette.gray900)

                        VStack(spacing: 14) {
                            DetailInfoRow(label: "Current Streak", value: "\u{1F525} \(habit.streak) days", valueColor: QuestPalette.orange)
                            DetailInfoRow(label: "Total Completions", value: "\(habit.completionHistory.count)", valueColor: QuestPalette.gray900)
                            DetailInfoRow(label: "Total XP Earned", value: "\(habit.totalEarnedXP) XP", valueColor: QuestPalette.purple)
                            if habit.reminderEnabled {
                                DetailInfoRow(label: "Daily Reminder", value: habit.reminderTime ?? "Not set", valueColor: QuestPalette.gray900)
                            }
                        }
                    }
                    .padding(20)
                    .questCardStyle()
                }
                .padding(.horizontal, QuestLayout.contentPadding)
                .padding(.vertical, 24)
            }
        }
        .background(Color.white)
    }
}

private struct AchievementsScreen: View {
    @EnvironmentObject private var store: HabitQuestStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Achievements")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 16) {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(QuestPalette.yellowGradient.linear)
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Text("\u{1F451}")
                                        .font(.system(size: 30))
                                )
                                .shadow(color: Color.black.opacity(0.16), radius: 16, x: 0, y: 8)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current Level")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.76))
                                Text("Level \(store.userProfile.level)")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                        }

                        VStack(spacing: 8) {
                            HStack {
                                Text("Progress to Level \(store.userProfile.level + 1)")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.76))
                                Spacer()
                                Text("\(store.userProfile.currentXP) / \(store.userProfile.xpToNextLevel) XP")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                            }

                            QuestProgressBar(
                                progress: store.xpProgress,
                                fillStyle: AnyShapeStyle(Color.white),
                                trackColor: .white.opacity(0.22),
                                height: 8
                            )
                        }
                    }
                    .padding(20)
                    .questCardStyle(
                        background: AnyShapeStyle(Color.white.opacity(0.12)),
                        border: .white.opacity(0.22),
                        shadowColor: .clear
                    )
                }
                .padding(.horizontal, QuestLayout.contentPadding)
                .padding(.top, 50)
                .padding(.bottom, 28)
                .background(
                    QuestPalette.primaryGradient.linear
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: 32,
                                bottomTrailingRadius: 32,
                                topTrailingRadius: 0,
                                style: .continuous
                            )
                        )
                )

                LazyVGrid(columns: threeColumnGrid, spacing: 12) {
                    OverviewMetricCard(symbol: "trophy.fill", symbolColor: QuestPalette.orange, value: "\(store.unlockedAchievementsCount)", label: "Unlocked", backgroundColors: [Color(hex: 0xFFFBEB), Color(hex: 0xFFF7ED)], border: Color(hex: 0xFDE68A))
                    OverviewMetricCard(symbol: "star.fill", symbolColor: QuestPalette.purple, value: "\(store.achievementCompletionPercentage)%", label: "Complete", backgroundColors: [QuestPalette.purpleSoft, Color(hex: 0xEEF2FF)], border: Color(hex: 0xE9D5FF))
                    OverviewMetricCard(symbol: "bolt.fill", symbolColor: QuestPalette.blue, value: "\(store.totalAchievementBonusXP)", label: "Bonus XP", backgroundColors: [Color(hex: 0xEFF6FF), Color(hex: 0xECFEFF)], border: Color(hex: 0xBFDBFE))
                }
                .padding(.horizontal, QuestLayout.contentPadding)

                VStack(spacing: 16) {
                    QuestProgressRing(progress: Double(store.achievementCompletionPercentage) / 100, size: 140, lineWidth: 12) {
                        VStack(spacing: 4) {
                            GradientText("\(store.finishedAchievementsCount)", gradient: QuestPalette.primaryGradient)
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                            Text("of \(store.achievements.count)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(QuestPalette.gray500)
                        }
                    }

                    Text("Achievement Progress")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(QuestPalette.gray500)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .questCardStyle()
                .padding(.horizontal, QuestLayout.contentPadding)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Available Achievements")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(QuestPalette.gray900)

                    VStack(spacing: 12) {
                        ForEach(store.achievements.filter { !$0.claimed }) { achievement in
                            AchievementBadgeView(achievement: achievement) {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                                    store.claimAchievement(id: achievement.id)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, QuestLayout.contentPadding)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Finished Achievements")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(QuestPalette.gray900)

                    if store.finishedAchievements.isEmpty {
                        EmptyStateCard(
                            symbol: "checkmark.seal.fill",
                            title: "No finished achievements yet",
                            message: "Claim an unlocked achievement to move it here."
                        )
                    } else {
                        VStack(spacing: 12) {
                            ForEach(store.finishedAchievements) { achievement in
                                AchievementBadgeView(achievement: achievement)
                            }
                        }
                    }
                }
                .padding(.horizontal, QuestLayout.contentPadding)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Next Level Rewards")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(QuestPalette.gray900)

                    VStack(spacing: 12) {
                        RewardRow(emoji: "\u{1F3A8}", title: "Custom Theme Colors", subtitle: "Unlock at Level \(store.userProfile.level + 1)")
                        RewardRow(emoji: "\u{1F31F}", title: "Exclusive Icons Pack", subtitle: "Unlock at Level \(store.userProfile.level + 2)")
                    }
                }
                .padding(20)
                .questCardStyle(
                    background: AnyShapeStyle(
                        LinearGradient(colors: [QuestPalette.purpleSoft, Color(hex: 0xEEF2FF)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    ),
                    border: Color(hex: 0xE9D5FF),
                    shadowColor: Color.black.opacity(0.03),
                    shadowRadius: 10,
                    shadowY: 6
                )
                .padding(.horizontal, QuestLayout.contentPadding)
                .padding(.bottom, 24)
            }
        }
        .background(Color.white)
    }
}

private struct AnalyticsScreen: View {
    @EnvironmentObject private var store: HabitQuestStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Progress & Analytics")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Track your journey to success")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.76))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, QuestLayout.contentPadding)
                .padding(.top, 50)
                .padding(.bottom, 28)
                .background(
                    QuestPalette.primaryGradient.linear
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: 32,
                                bottomTrailingRadius: 32,
                                topTrailingRadius: 0,
                                style: .continuous
                            )
                        )
                )

                LazyVGrid(columns: twoColumnGrid, spacing: 12) {
                    AnalyticsMetricCard(symbol: "chart.line.uptrend.xyaxis", symbolColor: QuestPalette.green, value: "\(store.completedHabitsCount)/\(store.habits.count)", label: "Completed Today", backgroundColors: [QuestPalette.greenSoft, Color(hex: 0xECFDF5)], border: Color(hex: 0xBBF7D0))
                    AnalyticsMetricCard(symbol: "calendar", symbolColor: QuestPalette.orange, value: "\(store.averageStreak)", label: "Avg Streak Days", backgroundColors: [QuestPalette.orangeSoft, Color(hex: 0xFEF2F2)], border: Color(hex: 0xFED7AA))
                    AnalyticsMetricCard(symbol: "bolt.fill", symbolColor: QuestPalette.purple, value: "1240", label: "XP This Week", backgroundColors: [QuestPalette.purpleSoft, Color(hex: 0xEEF2FF)], border: Color(hex: 0xE9D5FF))
                    AnalyticsMetricCard(symbol: "rosette", symbolColor: QuestPalette.blue, value: "88%", label: "Success Rate", backgroundColors: [Color(hex: 0xEFF6FF), Color(hex: 0xECFEFF)], border: Color(hex: 0xBFDBFE))
                }
                .padding(.horizontal, QuestLayout.contentPadding)

                VStack(alignment: .leading, spacing: 16) {
                    Text("This Week's Activity")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(QuestPalette.gray900)

                    WeeklyBarChart(data: SampleData.weeklyActivity)
                }
                .padding(20)
                .questCardStyle()
                .padding(.horizontal, QuestLayout.contentPadding)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Monthly Completion Rate")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(QuestPalette.gray900)

                    MonthlyLineChart(data: SampleData.monthlyCompletion)
                        .frame(height: 220)
                }
                .padding(20)
                .questCardStyle()
                .padding(.horizontal, QuestLayout.contentPadding)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Habit Breakdown")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(QuestPalette.gray900)

                    VStack(spacing: 16) {
                        ForEach(store.habits.prefix(3)) { habit in
                            HabitBreakdownRow(habit: habit)
                        }
                    }
                }
                .padding(20)
                .questCardStyle()
                .padding(.horizontal, QuestLayout.contentPadding)

                VStack(alignment: .leading, spacing: 12) {
                    Text("\u{1F4A1} Insights")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(QuestPalette.gray900)

                    InsightBullet(text: "You're most consistent on weekdays! Keep it up! \u{1F3AF}")
                    InsightBullet(text: "Your morning habits have a 95% completion rate \u{2B50}")
                    InsightBullet(text: "You've completed 21 habits this week - new record! \u{1F3C6}")
                }
                .padding(20)
                .questCardStyle(
                    background: AnyShapeStyle(
                        LinearGradient(colors: [QuestPalette.purpleSoft, Color(hex: 0xEEF2FF)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    ),
                    border: Color(hex: 0xE9D5FF),
                    shadowColor: Color.black.opacity(0.03),
                    shadowRadius: 10,
                    shadowY: 6
                )
                .padding(.horizontal, QuestLayout.contentPadding)
                .padding(.bottom, 24)
            }
        }
        .background(Color.white)
    }
}

private struct ProfileScreen: View {
    @EnvironmentObject private var store: HabitQuestStore

    private let settingsItems: [(symbol: String, title: String, gradient: QuestGradientSet)] = [
        ("bell.fill", "Notifications", QuestPalette.cyanGradient),
        ("person.fill", "Edit Profile", QuestPalette.primaryGradient),
        ("shield.fill", "Privacy & Security", QuestPalette.greenGradient),
        ("questionmark.circle.fill", "Help & Support", QuestPalette.orangeGradient)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                VStack(spacing: 20) {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(.white.opacity(0.18))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.28), lineWidth: 4)
                            )
                            .overlay(
                                Text(store.userProfile.avatar)
                                    .font(.system(size: 48))
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.displayName)
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Level \(store.userProfile.level) Habit Master")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.78))

                            if !store.authEmail.isEmpty {
                                Text(store.authEmail)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.72))
                            }
                        }

                        Spacer()

                        Button(action: { }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18, weight: .bold))
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(QuestGlassIconButtonStyle())
                    }

                    VStack(spacing: 10) {
                        HStack {
                            Text("Progress to Level \(store.userProfile.level + 1)")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.78))
                            Spacer()
                            Text("\(store.userProfile.currentXP) / \(store.userProfile.xpToNextLevel) XP")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                        }

                        QuestProgressBar(
                            progress: store.xpProgress,
                            fillStyle: AnyShapeStyle(Color.white),
                            trackColor: .white.opacity(0.22),
                            height: 8
                        )
                    }
                    .padding(16)
                    .questCardStyle(
                        background: AnyShapeStyle(Color.white.opacity(0.12)),
                        border: .white.opacity(0.22),
                        shadowColor: .clear
                    )
                }
                .padding(.horizontal, QuestLayout.contentPadding)
                .padding(.top, 50)
                .padding(.bottom, 28)
                .background(
                    QuestPalette.primaryGradient.linear
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: 32,
                                bottomTrailingRadius: 32,
                                topTrailingRadius: 0,
                                style: .continuous
                            )
                        )
                )

                LazyVGrid(columns: threeColumnGrid, spacing: 12) {
                    OverviewMetricCard(symbol: "crown.fill", symbolColor: QuestPalette.yellow, value: "\(store.userProfile.level)", label: "Level", backgroundColors: [Color(hex: 0xFFFBEB), Color(hex: 0xFFF7ED)], border: Color(hex: 0xFDE68A))
                    OverviewMetricCard(symbol: "flame.fill", symbolColor: QuestPalette.orange, value: "\(store.userProfile.longestStreak)", label: "Best Streak", backgroundColors: [QuestPalette.orangeSoft, Color(hex: 0xFEF2F2)], border: Color(hex: 0xFED7AA))
                    OverviewMetricCard(symbol: "target", symbolColor: QuestPalette.purple, value: "\(store.userProfile.totalHabitsCompleted)", label: "Completed", backgroundColors: [QuestPalette.purpleSoft, Color(hex: 0xEEF2FF)], border: Color(hex: 0xE9D5FF))
                }
                .padding(.horizontal, QuestLayout.contentPadding)

                VStack(spacing: 16) {
                    QuestProgressRing(progress: store.xpProgress, size: 140, lineWidth: 12) {
                        VStack(spacing: 4) {
                            GradientText("\(Int((store.xpProgress * 100).rounded()))%", gradient: QuestPalette.primaryGradient)
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                            Text("to next level")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(QuestPalette.gray500)
                        }
                    }

                    Text("\(max(store.userProfile.xpToNextLevel - store.userProfile.currentXP, 0)) XP remaining")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(QuestPalette.gray500)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .questCardStyle()
                .padding(.horizontal, QuestLayout.contentPadding)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Recent Achievements")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(QuestPalette.gray900)

                    HStack(spacing: 12) {
                        ForEach(["\u{1F3AF}", "\u{26A1}", "\u{1F305}"], id: \.self) { emoji in
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(QuestPalette.primaryGradient.linear)
                                .frame(width: 56, height: 56)
                                .overlay(
                                    Text(emoji)
                                        .font(.system(size: 28))
                                )
                                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 8)
                        }

                        Text("+3 more")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(QuestPalette.gray500)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(20)
                .questCardStyle(
                    background: AnyShapeStyle(
                        LinearGradient(colors: [QuestPalette.purpleSoft, Color(hex: 0xEEF2FF)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    ),
                    border: Color(hex: 0xE9D5FF),
                    shadowColor: Color.black.opacity(0.03),
                    shadowRadius: 10,
                    shadowY: 6
                )
                .padding(.horizontal, QuestLayout.contentPadding)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Settings")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(QuestPalette.gray900)

                    VStack(spacing: 0) {
                        ForEach(Array(settingsItems.enumerated()), id: \.offset) { index, item in
                            Button(action: { }) {
                                HStack(spacing: 16) {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(item.gradient.linear)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Image(systemName: item.symbol)
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundStyle(.white)
                                        )

                                    Text(item.title)
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundStyle(QuestPalette.gray900)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(QuestPalette.gray400)
                                }
                                .padding(16)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if index < settingsItems.count - 1 {
                                Divider()
                                    .padding(.leading, 72)
                            }
                        }
                    }
                    .questCardStyle(
                        background: AnyShapeStyle(Color.white),
                        border: QuestPalette.gray100,
                        shadowColor: Color.black.opacity(0.05),
                        shadowRadius: 10,
                        shadowY: 6
                    )
                }
                .padding(.horizontal, QuestLayout.contentPadding)

                Button {
                    store.signOut()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                }
                .buttonStyle(QuestDangerButtonStyle())
                .padding(.horizontal, QuestLayout.contentPadding)

                Text("HabitQuest v1.0.0")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(QuestPalette.gray400)
                    .padding(.bottom, 24)
            }
        }
        .background(Color.white)
    }
}

private struct QuestTabBar: View {
    let selectedTab: MainTab
    let onSelect: (MainTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(tab == selectedTab ? AnyShapeStyle(QuestPalette.primaryGradient.linear) : AnyShapeStyle(Color.clear))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: tab.systemImage)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(tab == selectedTab ? .white : QuestPalette.gray400)
                            )

                        Text(tab.title)
                            .font(.system(size: 10, weight: tab == selectedTab ? .semibold : .medium, design: .rounded))
                            .foregroundStyle(tab == selectedTab ? QuestPalette.purple : QuestPalette.gray500)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Color.white)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(QuestPalette.gray200)
                .frame(height: 1)
        }
    }
}

private struct HabitRowCard: View {
    let habit: Habit
    let onToggle: () -> Void
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onToggle) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(habit.completed ? AnyShapeStyle(QuestPalette.primaryGradient.linear) : AnyShapeStyle(QuestPalette.gray100))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Group {
                            if habit.completed {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.white)
                            } else {
                                Text(habit.icon)
                                    .font(.system(size: 24))
                            }
                        }
                    )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text(habit.name)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(QuestPalette.gray900)

                HStack(spacing: 12) {
                    Text("\u{1F525} \(habit.streak) day streak")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(QuestPalette.gray500)

                    Text("+\(habit.xp) XP")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(QuestPalette.purple)
                }
            }

            Spacer()
        }
        .padding(16)
        .questCardStyle(
            background: AnyShapeStyle(Color.white),
            border: QuestPalette.gray100,
            shadowColor: Color.black.opacity(0.05),
            shadowRadius: 10,
            shadowY: 6
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}

private struct AchievementBadgeView: View {
    let achievement: Achievement
    let onClaim: (() -> Void)?

    private var isClaimable: Bool {
        achievement.unlocked && !achievement.claimed
    }

    init(achievement: Achievement, onClaim: (() -> Void)? = nil) {
        self.achievement = achievement
        self.onClaim = onClaim
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(achievement.unlocked ? AnyShapeStyle(QuestPalette.primaryGradient.linear) : AnyShapeStyle(QuestPalette.gray200))
                .frame(width: 56, height: 56)
                .overlay(
                    Text(achievement.unlocked ? achievement.icon : "\u{1F512}")
                        .font(.system(size: 30))
                )

            VStack(alignment: .leading, spacing: 8) {
                Text(achievement.title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(achievement.unlocked ? QuestPalette.purpleDark : QuestPalette.gray400)

                Text(achievement.description)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(QuestPalette.gray500)

                if achievement.claimed {
                    AchievementStatusPill(text: "Finished", symbol: "checkmark.seal.fill", tint: QuestPalette.green, background: Color(hex: 0xECFDF3), border: Color(hex: 0xA7F3D0))
                } else if isClaimable {
                    AchievementStatusPill(text: "Claim +\(achievement.xpReward) XP", symbol: "bolt.fill", tint: QuestPalette.purple, background: QuestPalette.purpleSoft, border: Color(hex: 0xE9D5FF))
                } else if let progress = achievement.progress, let total = achievement.total {
                    VStack(spacing: 6) {
                        HStack {
                            Text("Progress")
                            Spacer()
                            Text("\(progress)/\(total)")
                        }
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(QuestPalette.gray500)

                        QuestProgressBar(
                            progress: total == 0 ? 0 : Double(progress) / Double(total),
                            fillStyle: AnyShapeStyle(QuestPalette.primaryGradient.horizontal),
                            trackColor: QuestPalette.gray200,
                            height: 6
                        )
                    }
                }
            }
        }
        .padding(16)
        .questCardStyle(
            background: achievement.unlocked
                ? AnyShapeStyle(
                    LinearGradient(colors: [QuestPalette.purpleSoft, Color(hex: 0xEEF2FF)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                : AnyShapeStyle(Color.white),
            border: achievement.unlocked ? Color(hex: 0xE9D5FF) : QuestPalette.gray100,
            shadowColor: Color.black.opacity(0.05),
            shadowRadius: 10,
            shadowY: 6
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard isClaimable else { return }
            onClaim?()
        }
    }
}

private struct AchievementStatusPill: View {
    let text: String
    let symbol: String
    let tint: Color
    let background: Color
    let border: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(background)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(border, lineWidth: 1)
                )
        )
    }
}

private struct EmptyStateCard: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(QuestPalette.gray400)

            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(QuestPalette.gray700)

            Text(message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(QuestPalette.gray500)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .questCardStyle(
            background: AnyShapeStyle(QuestPalette.gray50),
            border: QuestPalette.gray100,
            shadowColor: Color.black.opacity(0.03),
            shadowRadius: 10,
            shadowY: 6
        )
    }
}

private struct WeeklyBarChart: View {
    let data: [WeeklyActivityPoint]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(data) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.day)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(QuestPalette.gray500)

                        Spacer()

                        Text("\(item.completed)/\(item.total)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(QuestPalette.purple)
                    }

                    GeometryReader { proxy in
                        let maxCompleted = max(data.map(\.completed).max() ?? 1, 1)
                        let percentage = Double(item.completed) / Double(maxCompleted)

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(QuestPalette.gray100)
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(QuestPalette.primaryGradient.horizontal)
                                .frame(width: max(proxy.size.width * percentage, 18))
                        }
                    }
                    .frame(height: 32)
                }
            }
        }
    }
}

private struct MonthlyLineChart: View {
    struct ChartPoint: Identifiable {
        let label: String
        let point: CGPoint

        var id: String { label }
    }

    let data: [MonthlyCompletionPoint]

    var body: some View {
        GeometryReader { proxy in
            let points = chartPoints(in: proxy.size)

            ZStack {
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(QuestPalette.gray200)
                        .frame(height: 1)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 28)
                }

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first.point)
                    for point in points.dropFirst() {
                        path.addLine(to: point.point)
                    }
                }
                .stroke(QuestPalette.purple, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                ForEach(points) { item in
                    Circle()
                        .fill(QuestPalette.purple)
                        .frame(width: 10, height: 10)
                        .position(item.point)

                    Text(item.label)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(QuestPalette.gray500)
                        .position(x: item.point.x, y: proxy.size.height - 10)
                }
            }
        }
    }

    private func chartPoints(in size: CGSize) -> [ChartPoint] {
        guard data.count > 1 else { return [] }

        let chartHeight = size.height - 40
        let horizontalPadding: CGFloat = 20
        let verticalPadding: CGFloat = 20

        return data.enumerated().map { index, item in
            let x = horizontalPadding + (CGFloat(index) / CGFloat(data.count - 1)) * (size.width - horizontalPadding * 2)
            let y = chartHeight - ((CGFloat(item.percentage) / 100) * (chartHeight - verticalPadding * 2)) - verticalPadding
            return ChartPoint(label: item.week, point: CGPoint(x: x, y: y))
        }
    }
}

private struct HabitBreakdownRow: View {
    let habit: Habit

    private var completionRate: Double {
        Double(habit.completionHistory.count) / 30
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Text(habit.icon)
                        .font(.system(size: 22))
                    Text(habit.name)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(QuestPalette.gray900)
                }

                Spacer()

                Text("\(Int((completionRate * 100).rounded()))%")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(QuestPalette.purple)
            }

            QuestProgressBar(
                progress: completionRate,
                fillStyle: AnyShapeStyle(QuestPalette.primaryGradient.horizontal),
                trackColor: QuestPalette.gray100,
                height: 8
            )
        }
    }
}

private struct QuestProgressRing<CenterContent: View>: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let centerContent: () -> CenterContent

    init(
        progress: Double,
        size: CGFloat,
        lineWidth: CGFloat,
        @ViewBuilder centerContent: @escaping () -> CenterContent
    ) {
        self.progress = progress
        self.size = size
        self.lineWidth = lineWidth
        self.centerContent = centerContent
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(QuestPalette.gray100, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(QuestPalette.primaryGradient.linear, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            centerContent()
        }
        .frame(width: size, height: size)
    }
}

private struct QuestProgressBar: View {
    let progress: Double
    let fillStyle: AnyShapeStyle
    let trackColor: Color
    let height: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(trackColor)
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(fillStyle)
                    .frame(width: max(proxy.size.width * min(max(progress, 0), 1), 0))
            }
        }
        .frame(height: height)
    }
}

private struct QuestToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.78)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule(style: .continuous)
                    .fill(isOn ? QuestPalette.purple : QuestPalette.gray300)
                    .frame(width: 50, height: 30)

                Circle()
                    .fill(.white)
                    .frame(width: 22, height: 22)
                    .padding(.horizontal, 4)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct LabeledTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var leadingSystemImage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(QuestPalette.gray700)

            HStack(spacing: 12) {
                if let leadingSystemImage {
                    Image(systemName: leadingSystemImage)
                        .foregroundStyle(QuestPalette.gray400)
                        .frame(width: 20)
                }

                TextField(placeholder, text: $text)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(QuestPalette.gray900)
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(QuestPalette.gray50)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(QuestPalette.gray200, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

private struct AuthMessageCard: View {
    let text: String
    let tint: Color
    let background: Color
    let border: Color
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .padding(.top, 2)

            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(QuestPalette.gray700)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct SectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(QuestPalette.gray700)
    }
}

private struct DashboardStatLine: View {
    let label: String
    let value: String
    var valueColor: Color? = nil
    var valueGradient: QuestGradientSet? = nil

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(QuestPalette.gray500)
            Spacer()
            if let valueGradient {
                GradientText(value, gradient: valueGradient)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            } else {
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(valueColor ?? QuestPalette.gray900)
            }
        }
    }
}

private struct DetailStatCard: View {
    let emoji: String
    let value: String
    let label: String
    let tintBackground: Color
    let border: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(emoji)
                .font(.system(size: 30))
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(QuestPalette.gray900)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(QuestPalette.gray500)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .questCardStyle(
            background: AnyShapeStyle(
                LinearGradient(colors: [tintBackground, tintBackground.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
            ),
            border: border,
            shadowColor: Color.black.opacity(0.03),
            shadowRadius: 8,
            shadowY: 4
        )
    }
}

private struct OverviewMetricCard: View {
    let symbol: String
    let symbolColor: Color
    let value: String
    let label: String
    let backgroundColors: [Color]
    let border: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(symbolColor)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(QuestPalette.gray900)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(QuestPalette.gray500)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .questCardStyle(
            background: AnyShapeStyle(LinearGradient(colors: backgroundColors, startPoint: .topLeading, endPoint: .bottomTrailing)),
            border: border,
            shadowColor: Color.black.opacity(0.03),
            shadowRadius: 8,
            shadowY: 4
        )
    }
}

private struct AnalyticsMetricCard: View {
    let symbol: String
    let symbolColor: Color
    let value: String
    let label: String
    let backgroundColors: [Color]
    let border: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(symbolColor)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(QuestPalette.gray900)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(QuestPalette.gray500)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .questCardStyle(
            background: AnyShapeStyle(LinearGradient(colors: backgroundColors, startPoint: .topLeading, endPoint: .bottomTrailing)),
            border: border,
            shadowColor: Color.black.opacity(0.03),
            shadowRadius: 8,
            shadowY: 4
        )
    }
}

private struct RewardRow: View {
    let emoji: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(QuestPalette.primaryGradient.linear)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(emoji)
                        .font(.system(size: 22))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(QuestPalette.gray900)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(QuestPalette.gray500)
            }
            Spacer()
        }
    }
}

private struct InsightBullet: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\u{2022}")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(QuestPalette.gray700)
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(QuestPalette.gray700)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct DetailInfoRow: View {
    let label: String
    let value: String
    let valueColor: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(QuestPalette.gray500)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(valueColor)
        }
    }
}

private struct GradientText: View {
    let text: String
    let gradient: QuestGradientSet

    init(_ text: String, gradient: QuestGradientSet) {
        self.text = text
        self.gradient = gradient
    }

    var body: some View {
        Text(text)
            .foregroundStyle(gradient.horizontal)
    }
}

private struct HabitCalendarInfo {
    struct Day: Identifiable {
        let number: Int
        let isCompleted: Bool
        let isToday: Bool

        var id: Int { number }

        var foregroundColor: Color {
            if isCompleted {
                return .white
            }
            if isToday {
                return QuestPalette.purple
            }
            return QuestPalette.gray500
        }

        var backgroundStyle: AnyShapeStyle {
            if isCompleted {
                return AnyShapeStyle(QuestPalette.primaryGradient.linear)
            }
            if isToday {
                return AnyShapeStyle(Color(hex: 0xF3E8FF))
            }
            return AnyShapeStyle(QuestPalette.gray50)
        }

        @ViewBuilder
        var borderShape: some View {
            if isToday && !isCompleted {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(hex: 0xD8B4FE), lineWidth: 2)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.clear, lineWidth: 0)
            }
        }
    }

    let monthTitle: String
    let leadingBlankDays: Int
    let days: [Day]
    let completionRate: Int

    init(habit: Habit) {
        let calendar = Calendar.current
        let today = Date()
        let currentMonth = calendar.component(.month, from: today)
        let currentYear = calendar.component(.year, from: today)
        let firstDay = calendar.date(from: DateComponents(year: currentYear, month: currentMonth, day: 1)) ?? today
        let daysInMonth = calendar.range(of: .day, in: .month, for: today)?.count ?? 30
        let weekday = calendar.component(.weekday, from: firstDay)
        let todayDay = calendar.component(.day, from: today)

        monthTitle = QuestFormatters.monthYear.string(from: firstDay)
        leadingBlankDays = max(weekday - 1, 0)
        completionRate = Int((Double(habit.completionHistory.count) / Double(daysInMonth) * 100).rounded())

        days = (1...daysInMonth).map { number in
            let dateString = String(format: "%04d-%02d-%02d", currentYear, currentMonth, number)
            return Day(
                number: number,
                isCompleted: habit.completionHistory.contains(dateString),
                isToday: number == todayDay
            )
        }
    }
}

private struct QuestFilledButtonStyle: ButtonStyle {
    let gradient: QuestGradientSet

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: QuestLayout.buttonRadius, style: .continuous)
                    .fill(gradient.horizontal)
            )
            .shadow(color: Color.black.opacity(0.14), radius: 12, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct QuestSolidButtonStyle: ButtonStyle {
    let background: Color
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(foreground)
            .background(
                RoundedRectangle(cornerRadius: QuestLayout.buttonRadius, style: .continuous)
                    .fill(background)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct QuestOutlinedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(QuestPalette.gray900)
            .background(
                RoundedRectangle(cornerRadius: QuestLayout.buttonRadius, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: QuestLayout.buttonRadius, style: .continuous)
                    .stroke(QuestPalette.gray200, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct QuestDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(QuestPalette.red)
            .background(
                RoundedRectangle(cornerRadius: QuestLayout.buttonRadius, style: .continuous)
                    .fill(Color(hex: 0xFEF2F2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: QuestLayout.buttonRadius, style: .continuous)
                    .stroke(Color(hex: 0xFECACA), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct QuestGlassIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(configuration.isPressed ? 0.3 : 0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.28), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct QuestOptionButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(QuestPalette.primaryGradient.linear) : AnyShapeStyle(QuestPalette.gray100))
            )
            .foregroundStyle(isSelected ? .white : QuestPalette.gray900)
            .scaleEffect(configuration.isPressed ? 0.96 : (isSelected ? 1.04 : 1))
            .shadow(color: isSelected ? Color.black.opacity(0.12) : .clear, radius: 10, x: 0, y: 6)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct QuestChipButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(isSelected ? .white : QuestPalette.gray700)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(QuestPalette.primaryGradient.linear) : AnyShapeStyle(QuestPalette.gray100))
            )
            .shadow(color: isSelected ? Color.black.opacity(0.1) : .clear, radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
