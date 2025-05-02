//
//  ProfileView.swift
//  CruiseAIios
//
//  Created by Ojas Kandhare on 4/7/25.
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var appState: AppState
    @State private var isEditingProfile = false
    @State private var tempName = ""
    @State private var tempEmail = ""
    @State private var showingSoundTest = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    // Profile header with avatar
                    GlassContainer(theme: appState.theme) {
                        VStack(spacing: 20) {
                            // Avatar
                            ZStack {
                                Circle()
                                    .fill(appState.theme.accentColor.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "person.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(appState.theme.accentColor)
                            }
                            .overlay(
                                Circle()
                                    .stroke(appState.theme.accentColor.opacity(0.3), lineWidth: 2)
                            )
                            .shadow(color: appState.theme.accentColor.opacity(0.3), radius: 10)
                            
                            // User info
                            if isEditingProfile {
                                VStack(spacing: 15) {
                                    TextField("Name", text: $tempName)
                                        .textFieldStyle(GlassTextFieldStyle(theme: appState.theme))
                                    
                                    TextField("Email", text: $tempEmail)
                                        .textFieldStyle(GlassTextFieldStyle(theme: appState.theme))
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                }
                            } else {
                                VStack(spacing: 8) {
                                    Text(appState.userName.isEmpty ? "Add Name" : appState.userName)
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text(appState.userEmail.isEmpty ? "Add Email" : appState.userEmail)
                                        .font(.system(size: 16))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    
                    // Theme selector
                    ThemeSelector(appState: appState)
                    
                    // Developer Tools section
                    GlassContainer(theme: appState.theme) {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Developer Tools")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            // Sound test option
                            Button(action: {
                                showingSoundTest = true
                            }) {
                                HStack(spacing: 15) {
                                    Image(systemName: "speaker.wave.3.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(appState.theme.accentColor)
                                        .frame(width: 32)
                                    
                                    Text("Test Instrumental Sounds")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    
                    // Settings section
                    GlassContainer(theme: appState.theme) {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Settings")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            // Settings options
                            VStack(spacing: 15) {
                                SettingsRow(icon: "bell.fill", title: "Notifications", theme: appState.theme)
                                SettingsRow(icon: "lock.fill", title: "Privacy", theme: appState.theme)
                                SettingsRow(icon: "gear.fill", title: "Preferences", theme: appState.theme)
                                SettingsRow(icon: "questionmark.circle.fill", title: "Help & Support", theme: appState.theme)
                            }
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: appState.theme.gradientColors),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)
                .animation(.easeInOut(duration: 0.5), value: appState.theme)
            )
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditingProfile ? "Save" : "Edit") {
                        if isEditingProfile {
                            // Save changes
                            appState.userName = tempName
                            appState.userEmail = tempEmail
                            appState.saveUserData()
                        } else {
                            // Start editing
                            tempName = appState.userName
                            tempEmail = appState.userEmail
                        }
                        isEditingProfile.toggle()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showingSoundTest) {
                SoundTestView()
            }
        }
    }
}

// Glass text field style
struct GlassTextFieldStyle: TextFieldStyle {
    let theme: AppTheme
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme.accentColor.opacity(0.3), lineWidth: 1)
                    )
            )
            .foregroundColor(.white)
    }
}

// Settings row component
struct SettingsRow: View {
    let icon: String
    let title: String
    let theme: AppTheme
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(theme.accentColor)
                    .frame(width: 32)
                
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, 8)
        }
    }
}

// Preview provider
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView(appState: AppState())
    }
}
