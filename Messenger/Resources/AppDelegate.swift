//
//  AppDelegate.swift
//  Messenger
//
//  Created by user195395 on 5/28/21.
//

import UIKit
import CoreData
import Firebase
import FBSDKCoreKit
import GoogleSignIn


@main
class AppDelegate: UIResponder, UIApplicationDelegate , GIDSignInDelegate{
    
    
    
    
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()
        
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        GIDSignIn.sharedInstance()?.delegate = self
        GIDSignIn.sharedInstance()?.clientID = FirebaseApp.app()?.options.clientID
        
        return true
    }
    
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        
        ApplicationDelegate.shared.application(
            app,
            open: url,
            sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String,
            annotation: options[UIApplication.OpenURLOptionsKey.annotation]
        )
        return GIDSignIn.sharedInstance().handle(url)
        
    }
    //ggidn signin function
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        guard error == nil else{
            if let error = error{
                print(error)
            }
            return
        }
        guard let user = user else{
            return
        }
        print("Logged in user: \(user)")
        guard let email = user.profile.email, let firstName = user.profile.givenName, let lastName = user.profile.familyName else{
            return
        }
        UserDefaults.standard.set(email,forKey: "email")
        UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")
        DatabaseManager.shared.userExists(with: email, completion: {exists in
            if !exists{
                let chatUser = ChatAppUser(firstName: firstName,
                                           lastName: lastName,
                                           emailAddress: email)
                DatabaseManager.shared.insertUser(with: chatUser, completion: {success in
                    if success{
                        if user.profile.hasImage{
                            guard let url = user.profile.imageURL(withDimension: 200) else{
                                return
                            }
                            URLSession.shared.dataTask(with: url, completionHandler: {data, _, _ in
                                guard let data = data else{
                                    return
                                }
                                let fileName = chatUser.profilePictureFileName
                                StorageManager.shared.uploadProfilePicture(with: data, fileName: fileName, completion: {result in
                                    switch result{
                                    case .success(let downloadUrl):
                                        UserDefaults.standard.set(downloadUrl, forKey: "profile_picture_url")
                                        print(downloadUrl)
                                    case.failure(let error):
                                        print("storage manager error \(error)")
                                    }
                                })
                                
                            }).resume()
                            
                        }
                    }
                })
            }
        })
        guard let authentication = user.authentication else{
            print("Missing auth object off of google user")
            return
            
        }
        let credential = GoogleAuthProvider.credential(withIDToken: authentication.idToken, accessToken: authentication.accessToken)
        FirebaseAuth.Auth.auth().signIn(with: credential, completion: {authResult, error in
            guard authResult != nil, error == nil else{
                print("failed to log in with google credential")
                return
            }
            print("successfully signed in with google")
            NotificationCenter.default.post(name: .didLogInNotification, object: nil)
        })
    }
    //ggid log out function
    func sign(_ signIn: GIDSignIn!, didDisconnectWith user: GIDGoogleUser!, withError error: Error!) {
        print("Google user was disconnected")
        
    }
    
    
    
}

