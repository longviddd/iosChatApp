//
//  LoginViewController.swift
//  Messenger
//
//  Created by user195395 on 5/28/21.
//

import UIKit
import FirebaseAuth
import FBSDKLoginKit
import GoogleSignIn
import JGProgressHUD

class LoginViewController: UIViewController {
    private let spinner = JGProgressHUD(style: .dark)
    
    private let scrollView : UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.clipsToBounds = true
        return scrollView
    }()
    
    private let emailField : UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .continue
        field.layer.cornerRadius = 10
        field.layer.borderWidth = 1
        
        field.placeholder = "Your Email Address..."
        return field
    }()
    private let passwordField : UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .done
        
        field.layer.cornerRadius = 10
        field.layer.borderWidth = 1
        field.isSecureTextEntry = true
        field.placeholder = "Your Password..."
        return field
    }()
    private let loginButton : UIButton = {
        let button = UIButton()
        button.setTitle("Log In", for: .normal)
        button.backgroundColor = .link
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.layer.masksToBounds = true
        button.titleLabel?.font = .systemFont(ofSize:20, weight: . bold)
        return button
    }()
    
    private let imageView : UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "logo")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    private let fbloginButton : FBLoginButton = {
        let button = FBLoginButton()
        button.permissions = ["email", "public_profile"]
        return button
    }()
    private let googleLogInButton = GIDSignInButton()
    private var loginObserver: NSObjectProtocol?
    override func viewDidLoad() {
        super.viewDidLoad()
        loginObserver = NotificationCenter.default.addObserver(forName: Notification.Name.didLogInNotification, object: nil, queue: .main, using: {[weak self] _ in
            guard let strongSelf = self else{
                return
            }
            strongSelf.navigationController?.dismiss(animated: true, completion: nil)
        })
        view.backgroundColor = .white
        title = "Log In"
        GIDSignIn.sharedInstance()?.presentingViewController = self
        // Do any additional setup after loading the view.
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Register", style: .done, target: self, action: #selector(didTapRegister))
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        scrollView.addSubview(emailField)
        scrollView.addSubview(passwordField)
        scrollView.addSubview(fbloginButton)
        scrollView.addSubview(googleLogInButton)
        fbloginButton.delegate = self
        scrollView.addSubview(loginButton)
        loginButton.addTarget(self, action:#selector(loginButtonTapped), for: .touchUpInside)
        emailField.delegate = self
        passwordField.delegate = self
    }
    deinit{
        if let observer = loginObserver{
            NotificationCenter.default.removeObserver(observer)
        }
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        
        let size = scrollView.width/3
        imageView.frame = CGRect(x: (view.width-size)/2, y: 20, width: size, height: size)
        emailField.frame = CGRect(x: 30, y: imageView.bottom + 10, width: scrollView.width-60, height: 52)
        passwordField.frame = CGRect(x: 30, y: emailField.bottom + 10, width: scrollView.width-60, height: 52)
        loginButton.frame = CGRect(x: 30, y: passwordField.bottom + 10, width: scrollView.width-60, height: 40)
        fbloginButton.frame = CGRect(x: 30, y: loginButton.bottom + 10, width: scrollView.width-60, height: 40)
        googleLogInButton.frame = CGRect(x: 30, y: fbloginButton.bottom + 10, width: scrollView.width-60, height: 40)
        
    }
    @objc private func didTapRegister(){
        let vc = RegisterViewController()
        vc.title = "Create Account"
        navigationController?.pushViewController(vc, animated: true)
    }
    @objc private func loginButtonTapped(){
        guard let email = emailField.text , let password = passwordField.text, !email.isEmpty, !password.isEmpty,password.count >= 6 else{
            alertUserLoginError()
            return
            
        }
        spinner.show(in:view)
        //firebase login
        FirebaseAuth.Auth.auth().signIn(withEmail: email, password: password, completion: {[weak self] authResult, error in
            guard let strongSelf = self else{
                return
            }
            DispatchQueue.main.async{
                strongSelf.spinner.dismiss()
            }
            guard let result = authResult, error == nil else{
                print("Failed to log in user with email: \(email)")
                return
            }
            strongSelf.navigationController?.dismiss(animated: true, completion: nil)
            let user = result.user
            let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
            print(safeEmail)
            DatabaseManager.shared.getDataFor(path: safeEmail, completion: {result in
                switch result{
                case.success(let data):
                    guard let userData = data as? [String: Any], let firstName = userData["first_name"] as? String, let lastName = userData["last_name"] as? String else{
                        return
                    }
                    UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")
                case .failure(let error):
                    print("Failed to read data \(error)")
                }
            })
            UserDefaults.standard.set(email, forKey: "email")
            
            print("Logged in \(user)")
        })
        
        emailField.resignFirstResponder()
        passwordField.resignFirstResponder()
    }
    func alertUserLoginError(){
        let alert = UIAlertController(title: "Something is not right here!", message: "Please enter all information to log in", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
        present(alert, animated:true)
    }
    
    
}
extension LoginViewController:UITextFieldDelegate{
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField  == emailField{
            passwordField.becomeFirstResponder()
        }else if textField == passwordField{
            loginButtonTapped()
        }
        return true
    }
}
extension LoginViewController : LoginButtonDelegate{
    func loginButtonDidLogOut(_ loginButton: FBLoginButton) {
        
    }
    
    
    func loginButton(_ loginButton: FBLoginButton, didCompleteWith result: LoginManagerLoginResult?, error: Error?) {
        guard let token = result?.token?.tokenString else{
            print("User failed tro log in with facebook!")
            return
        }
        let facebookRequest = FBSDKLoginKit.GraphRequest(graphPath: "me", parameters: ["fields": "email, first_name, last_name, picture.type(large)"], tokenString: token, version: nil, httpMethod: .get)
        facebookRequest.start(completionHandler: {_, result, error in
            guard let result = result as? [String : Any], error == nil else{
                print("Failed to make facebook graph request")
                return
            }
            print("\(result)")
            
            guard let firstName = result["first_name"] as? String,let lastName = result["last_name"] as? String, let email = result["email"] as? String, let picture = result["picture"] as? [String:Any], let data = picture["data"] as?[String:Any], let pictureUrl = data["url"]  as? String else{
                print("Failed to get email and name")
                return
            }
            UserDefaults.standard.set(email, forKey: "email")
            UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")
            
            DatabaseManager.shared.userExists(with: email, completion: { exists in
                if !exists{
                    let chatUser = ChatAppUser(firstName: firstName, lastName: lastName, emailAddress: email)
                    DatabaseManager.shared.insertUser(with: chatUser, completion: {success in
                        if success{
                            guard let url = URL(string: pictureUrl) else{
                                return
                            }
                            URLSession.shared.dataTask(with: url, completionHandler: {data, _, error in
                                guard let data = data, error == nil else{
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
                    })
                }
            })
            let credential = FacebookAuthProvider.credential(withAccessToken: token)
            FirebaseAuth.Auth.auth().signIn(with: credential, completion: { [weak self] authResult, error in
                guard let strongSelf = self else{
                    return
                }
                guard authResult != nil, error == nil else{
                    print("Facebook credential login failed, MFA might be needed!")
                    return
                }
                print("Successfully logged in!")
                strongSelf.navigationController?.dismiss(animated: true, completion: nil)
            })
            
        })
    }
    
    
}
