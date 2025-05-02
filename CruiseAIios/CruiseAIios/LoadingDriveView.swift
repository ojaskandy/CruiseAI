import SwiftUI

struct LoadingDriveView: View {
    @State private var carOffset: CGFloat = -UIScreen.main.bounds.width
    @State private var loadingText = "Starting your drive..."
    @State private var showDrivePage = false
    
    let appState: AppState
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(gradient: Gradient(colors: appState.theme.gradientColors),
                          startPoint: .topLeading,
                          endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                // Car image with animation
                Image(systemName: "car.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .foregroundColor(.white)
                    .offset(x: carOffset)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.0)) {
                            carOffset = UIScreen.main.bounds.width
                        }
                        // After animation completes, show drive page
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            showDrivePage = true
                        }
                    }
                
                // Loading text
                Text(loadingText)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .fullScreenCover(isPresented: $showDrivePage) {
            DrivePage(appState: appState)
        }
    }
}

struct LoadingDriveView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingDriveView(appState: AppState())
    }
} 