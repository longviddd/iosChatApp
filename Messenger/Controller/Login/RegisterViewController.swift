//
//  RegisterViewController.swift
//  Messenger
//
//  Created by user195395 on 5/28/21.
//

import UIKit
import FirebaseAuth
import JGProgressHUD
class RegisterViewController: UIViewController {
    //creating neccesary views and fields
    private let spinner = JGProgressHUD(style: .dark)
    //creating views and subviews
    private let scrollView : UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.clipsToBounds = true
        return scrollView
    }()
    private let firstNameField: UITextField = {
       let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .continue
        field.layer.cornerRadius = 10
        field.layer.borderWidth = 1
        
        field.placeholder = "Your First Name..."
        return field
    }()
    private let lastNameField : UITextField = {
       let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .continue
        field.layer.cornerRadius = 10
        field.layer.borderWidth = 1
        
        field.placeholder = "Your Last Name..."
        return field
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
    private let registerButton : UIButton = {
        let button = UIButton()
        button.setTitle("Register", for: .normal)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.layer.masksToBounds = true
        button.titleLabel?.font = .systemFont(ofSize:20, weight: . bold)
        return button
    }()
    
    private let imageView : UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "person.circle")
        imageView.contentMode = .scaleAspectFit
        imageView.layer.masksToBounds = true
        imageView.layer.borderWidth = 2
        imageView.layer.borderColor = UIColor.lightGray.cgColor
        return imageView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "Log In"
        // Do any additional setup after loading the view.
       
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        scrollView.addSubview(emailField)
        scrollView.addSubview(firstNameField)
        scrollView.addSubview(lastNameField)
        scrollView.addSubview(passwordField)
        scrollView.addSubview(registerButton)
        registerButton.addTarget(self, action:#selector(registerButtonTapped), for: .touchUpInside)
        emailField.delegate = self
        passwordField.delegate = self
        scrollView.isUserInteractionEnabled = true
        imageView.isUserInteractionEnabled = true
        let gesture = UITapGestureRecognizer(target: self, action: #selector(didTapChangeProfilePic))
        gesture.numberOfTapsRequired = 1
        gesture.numberOfTapsRequired = 1
        imageView.addGestureRecognizer(gesture)
    }
    @objc private func didTapChangeProfilePic(){
        presentPhotoActionSheet()
    }
    //changing positions of views and subviews
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        
        let size = scrollView.width/3
        imageView.frame = CGRect(x: (view.width-size)/2, y: 20, width: size, height: size)
        imageView.layer.cornerRadius = imageView.width/2.0
        emailField.frame = CGRect(x: 30, y: imageView.bottom + 10, width: scrollView.width-60, height: 52)
        firstNameField.frame = CGRect(x: 30, y: emailField.bottom + 10, width: scrollView.width-60, height: 52)
        lastNameField.frame = CGRect(x: 30, y: firstNameField.bottom + 10, width: scrollView.width-60, height: 52)
        passwordField.frame = CGRect(x: 30, y: lastNameField .bottom + 10, width: scrollView.width-60, height: 52)
        registerButton.frame = CGRect(x: 30, y: passwordField.bottom + 10, width: scrollView.width-60, height: 40)
    }
    //function when register button is tapped
    @objc private func registerButtonTapped(){
        emailField.resignFirstResponder()
        passwordField.resignFirstResponder()
        firstNameField.resignFirstResponder()
        lastNameField.resignFirstResponder()
        //soft validation
        guard let firstName = firstNameField.text, let lastName = lastNameField.text, let email = emailField.text , let password = passwordField.text, !email.isEmpty, !password.isEmpty,password.count >= 6, !firstName.isEmpty, !lastName.isEmpty else{
            //alert user if log in failed
            alertUserLoginError()
            return
            
        }
        spinner.show(in: view)
        //call databasemanager if validation is ok and add user to firebase real time database
        DatabaseManager.shared.userExists(with: email, completion: {[weak self] exists in
            guard let strongSelf = self else{
                
                return
            }
            DispatchQueue.main.async {
                strongSelf.spinner.dismiss()
            }
            guard !exists else{
                self?.alertUserLoginError(message: "Email has already been used.")
                return
                //user already exists
            }
            FirebaseAuth.Auth.auth().createUser(withEmail: email, password: password, completion: {authResult, error in

                guard authResult != nil, error == nil else{
                    print("Error creating user: \(error)")
                    return
                }
                let chatUser = ChatAppUser(firstName: firstName, lastName: lastName, emailAddress: email)
                DatabaseManager.shared.insertUser(with: chatUser, completion: {success in
                    if success{
                        //upload image
                        guard let image = strongSelf.imageView.image, let data = image.pngData() else{
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
                    }
                })
                
                strongSelf.navigationController?.dismiss(animated: true, completion: nil)
            })
        })

        //firebase login
    }
    func alertUserLoginError(message : String = "Please enter all information to create an account"){
        let alert = UIAlertController(title: "Something is not right here!", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
        present(alert, animated:true)
    }
    

}
//extension for textfield delegeate to change first responder
extension RegisterViewController:UITextFieldDelegate{
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField  == emailField{
            passwordField.becomeFirstResponder()
        }else if textField == passwordField{
            registerButtonTapped()
        }
        return true
    }
}
//extension in order for user to choose profile image
extension RegisterViewController : UIImagePickerControllerDelegate, UINavigationControllerDelegate{
    func presentPhotoActionSheet(){
        //create action sheet
        let actionSheet = UIAlertController(title: "Profile Picture", message: "How would you like to select a pictrure", preferredStyle: .actionSheet)
        //add action to the actionsheet
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        actionSheet.addAction(UIAlertAction(title: "Take Photo", style: .default, handler: { [weak self] _ in
            self?.presentCamera()
        }))
        actionSheet.addAction(UIAlertAction(title: "Choose photo", style: .default, handler: { [weak self] _ in
            self?.presentPhotoPicker()
        }))
        present(actionSheet,animated: true)
    }
    //func to open imagepickerview
    func presentCamera(){
        let vc = UIImagePickerController()
        vc.sourceType = .camera
        vc.delegate = self
        vc.allowsEditing = true
        present(vc, animated: true)
    }
    //func to present photopickerview
    func presentPhotoPicker(){
        let vc = UIImagePickerController()
        vc.sourceType = .photoLibrary
        vc.delegate = self
        vc.allowsEditing = true
        present(vc, animated: true)
        
    }
    //func after user has chosen the image
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let selectedImage = info[UIImagePickerController.InfoKey.editedImage] as? UIImage else{
            return
        }
        self.imageView.image = selectedImage
        
        
        
    }
    //dismiss the imagePicker
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
}

