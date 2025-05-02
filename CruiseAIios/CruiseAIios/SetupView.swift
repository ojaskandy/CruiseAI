//
//  SetupView.swift
//  CruiseAIios
//
//  Created by Ojas Kandhare on 4/3/25.
//

import SwiftUI

struct SetupView: View {
    @ObservedObject var appState: AppState
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @State private var name = ""
    @State private var email = ""
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Gradient background with theme colors
            LinearGradient(gradient: Gradient(colors: appState.theme.gradientColors), 
                           startPoint: .topLeading, 
                           endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)
            
            // Content
            VStack {
                // Logo at the top
                ZStack {
                    // Colorful gradient background for logo
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.95, green: 0.3, blue: 0.5),  // Pink
                                    Color(red: 1.0, green: 0.5, blue: 0.2),   // Orange
                                    Color(red: 0.3, green: 0.9, blue: 0.5)    // Green
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    // "C" letter for CruiseAI
                    Image(systemName: "c.circle.fill")
                        .font(.system(size: 120))
                        .foregroundColor(.white)
                }
                .padding(.top, 40)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
                
                // Title
                Text("Welcome to CruiseAI")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                // Page content
                TabView(selection: $currentPage) {
                    // Page 1: Welcome
                    WelcomeSetupPage(appState: appState)
                        .tag(0)
                    
                    // Page 2: User Info
                    UserInfoSetupPage(name: $name, email: $email, appState: appState)
                        .tag(1)
                    
                    // Page 3: Free Access
                    FreeAccessSetupPage(appState: appState)
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                .transition(.slide)
                
                // Navigation buttons
                HStack {
                    // Back button (hidden on first page)
                    Button(action: {
                        withAnimation {
                            currentPage -= 1
                        }
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(15)
                    }
                    .opacity(currentPage > 0 ? 1 : 0)
                    .disabled(currentPage == 0)
                    
                    Spacer()
                    
                    // Next/Finish button
                    Button(action: {
                        if currentPage < 2 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            // Save user info to app state
                            appState.userName = name
                            appState.userEmail = email
                            appState.hasCompletedSetup = true
                            
                            // Dismiss setup view
                            isPresented = false
                        }
                    }) {
                        HStack {
                            Text(currentPage < 2 ? "Next" : "Get Started")
                            Image(systemName: currentPage < 2 ? "chevron.right" : "checkmark")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(15)
                        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
                    }
                    .disabled(currentPage == 1 && (name.isEmpty || !isValidEmail(email)))
                    .opacity(currentPage == 1 && (name.isEmpty || !isValidEmail(email)) ? 0.5 : 1)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
                
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(currentPage == index ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 10, height: 10)
                            .scaleEffect(currentPage == index ? 1.2 : 1.0)
                            .animation(.spring(), value: currentPage)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
    
    // Validate email format
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}

// Welcome Page
struct WelcomeSetupPage: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 25) {
            // Welcome message
            Text("Drive Smarter, Not Harder")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // App description
            Text("CruiseAI uses your phone's camera and advanced AI to help you drive safer and smarter. No extra hardware needed!")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            
            // Features list
            VStack(alignment: .leading, spacing: 15) {
                FeatureItem(icon: "camera.fill", title: "Real-time Object Detection", description: "Identifies vehicles, pedestrians, and road signs")
                FeatureItem(icon: "exclamationmark.triangle.fill", title: "Safety Alerts", description: "Warns you of potential hazards on the road")
                FeatureItem(icon: "speedometer", title: "Speed Monitoring", description: "Tracks your speed with visual indicators")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(Color.white.opacity(0.1))
            .cornerRadius(15)
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .padding(.top, 20)
    }
}

// User Info Page
struct UserInfoSetupPage: View {
    @Binding var name: String
    @Binding var email: String
    @ObservedObject var appState: AppState
    @FocusState private var focusedField: Field?
    @State private var keyboardHeight: CGFloat = 0
    
    enum Field {
        case name, email
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                Text("Tell Us About Yourself")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("We'll use this information to personalize your experience")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                
                VStack(spacing: 20) {
                    // Name field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Name")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        TextField("", text: $name)
                            .placeholder(when: name.isEmpty) {
                                Text("Enter your name").foregroundColor(.white.opacity(0.5))
                            }
                            .padding()
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                            .focused($focusedField, equals: .name)
                            .submitLabel(.next)
                            .onSubmit {
                                focusedField = .email
                            }
                    }
                    
                    // Email field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Email")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        TextField("", text: $email)
                            .placeholder(when: email.isEmpty) {
                                Text("Enter your email").foregroundColor(.white.opacity(0.5))
                            }
                            .padding()
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($focusedField, equals: .email)
                            .submitLabel(.done)
                    }
                    
                    // Privacy note
                    Text("Your information is stored locally on your device and is never shared with third parties.")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(Color.white.opacity(0.1))
                .cornerRadius(15)
                .padding(.horizontal, 20)
                
                Spacer(minLength: keyboardHeight > 0 ? keyboardHeight - 100 : 0)
            }
            .padding(.top, 20)
        }
        .onAppear {
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    keyboardHeight = keyboardFrame.height
                }
            }
            
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                keyboardHeight = 0
            }
        }
        .gesture(
            TapGesture()
                .onEnded { _ in
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        )
    }
}

// Free Access Page
struct FreeAccessSetupPage: View {
    @ObservedObject var appState: AppState
    @State private var isGlowing = false
    
    var body: some View {
        VStack(spacing: 25) {
            // Congratulations message
            Text("Congratulations!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // Free access message
            Text("You've received free access to CruiseAI")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            
            // Feedback request
            VStack(spacing: 20) {
                Text("All we ask in return is your feedback to help us improve driving safety for everyone.")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                // Contact info
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.white)
                    
                    Text("ojaskandy@gmail.com")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.vertical, 15)
                .padding(.horizontal, 20)
                .background(Color.white.opacity(0.2))
                .cornerRadius(10)
                
                // Feedback button
                Button(action: {
                    if let url = URL(string: "https://forms.gle/upoTt5ZRXGCgxvFq7") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .shadow(color: isGlowing ? Color.green : Color.clear, radius: 5, x: 0, y: 0)
                            .opacity(isGlowing ? 1.0 : 0.8)
                        
                        Text("Give Feedback")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 15)
                    .padding(.horizontal, 25)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.green.opacity(0.7), Color.blue.opacity(0.7)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(15)
                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
                }
                .padding(.top, 10)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(Color.white.opacity(0.1))
            .cornerRadius(15)
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .padding(.top, 20)
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isGlowing = true
            }
        }
    }
}

// Feature item component
struct FeatureItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.2))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
        }
    }
}

// Extension for placeholder text in TextField
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

struct SetupView_Previews: PreviewProvider {
    static var previews: some View {
        SetupView(appState: AppState(), isPresented: .constant(true))
    }
}
