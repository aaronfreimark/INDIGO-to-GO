//
//  SignInWithAppleCoordinator.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 11/2/20.
//

import Foundation
import SwiftUI
import Firebase
import AuthenticationServices
import CryptoKit

struct SignInWithAppleButtonView: View {

    @State private var nonce: String?
    @EnvironmentObject var client: IndigoClientViewModel

    var body: some View {
        if self.client.isFirebaseSignedIn {
                      
            // Someone is signed in.
            
            Text("You are signed in.")
            Button("Sign Out", action: firebaseSignOut)

        } else {

            // Nobody is signed in. Present the Sign in with Apple button
            
            SignInWithAppleButton(
                onRequest: prepareSIWA,
                onCompletion: completeSIWA
            )
            .frame(width: 280, height: 50)
            .cornerRadius(9)
            .padding(.vertical)

        }
    }
    
    // MARK: - SIWA Helpers
        
    func prepareSIWA(request: ASAuthorizationAppleIDRequest) {
        request.state = "signIn"
        request.requestedScopes = []

        self.nonce = randomNonceString()
        request.nonce = sha256(self.nonce!)
    }
    
    func completeSIWA(result: (Result<ASAuthorization, Error>)) {
        switch result {
        case .success (let authResults):

            print("Authorization successful.")
            if let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential {

                // Save authorised user ID for future reference
                UserDefaults.standard.set(appleIDCredential.user, forKey: "appleAuthorizedUserIdKey")

                guard let nonce = self.nonce else {
                    fatalError("Invalid state: A login callback was received, but no login request was sent.")
                }
                guard let appleIDToken = appleIDCredential.identityToken else {
                    print("Unable to fetch identity token")
                    return
                }
                guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                    print("Unable to serialise token string from data: \(appleIDToken.debugDescription)")
                    return
                }
                guard let stateRaw = appleIDCredential.state, let state = SignInState(rawValue: stateRaw) else {
                    print("Invalid state: request must be started with one of the SignInStates")
                    return
                }

                let credential = OAuthProvider.credential(withProviderID: "apple.com",
                                                          idToken: idTokenString,
                                                          rawNonce: nonce)
                
                switch state {
                case .signIn:
                    Auth.auth().signIn(with: credential) { (result, error) in
                        if let error = error {
                            print("Error authenticating: \(error.localizedDescription)")
                            return
                        }

                        if let user = result?.user {
                            print("Firebase User: \(user)")
                        }
                    }
                case .reauth:
                    Auth.auth().currentUser?.reauthenticate(with: credential, completion: { (result, error) in
                        if let error = error {
                            print("Error authenticating: \(error.localizedDescription)")
                            return
                        }
                        if let user = result?.user {
                            print("Firebase User: \(user)")
                        }
                    })
                }
            }
                
        case .failure (let error):
            // 3
            print("Authorization failed: " + error.localizedDescription)
            
        }

    }
    
    func firebaseSignOut() {
        UserDefaults.standard.set(nil, forKey: "appleAuthorizedUserIdKey")
        let firebaseAuth = Auth.auth()
        do {
            try firebaseAuth.signOut()
        } catch let signOutError as NSError {
            print ("Error signing out: %@", signOutError)
        }
    }
}



enum SignInState: String {
    case signIn
    case reauth
}


// Adapted from https://auth0.com/docs/api-auth/tutorials/nonce#generate-a-cryptographically-random-nonce
private func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    let charset: Array<Character> =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remainingLength = length
    
    while remainingLength > 0 {
        let randoms: [UInt8] = (0 ..< 16).map { _ in
            var random: UInt8 = 0
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if errorCode != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
            }
            return random
        }
        
        randoms.forEach { random in
            if remainingLength == 0 {
                return
            }
            
            if random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
    }
    
    return result
}

@available(iOS 13, *)
private func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashedData = SHA256.hash(data: inputData)
    let hashString = hashedData.compactMap {
        return String(format: "%02x", $0)
    }.joined()
    
    return hashString
}

