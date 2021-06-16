//
//  ProfileViewController.swift
//  Messenger
//
//  Created by user195395 on 5/28/21.
//

import UIKit
import FirebaseAuth
import FBSDKLoginKit
import GoogleSignIn
import SDWebImage
enum ProfileViewModelType{
    case info, logout
}
struct ProfileViewModel{
    let viewModelType:  ProfileViewModelType
    let title : String
    let handler : (() -> Void)?
}
class ProfileViewController: UIViewController {
    @IBOutlet var tableView : UITableView!
    var data = [ProfileViewModel]()
    
    

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(ProfileTableViewCell.self, forCellReuseIdentifier: ProfileTableViewCell.identifier)
        data.append(ProfileViewModel(viewModelType: .info, title: "Name: \(UserDefaults.standard.value(forKey: "name") as? String)", handler: nil))
        data.append(ProfileViewModel(viewModelType: .info, title: "Email: \(UserDefaults.standard.value(forKey: "email") as? String)", handler: nil))
        data.append(ProfileViewModel(viewModelType: .logout, title: "Log Out", handler: {[weak self] in
            guard let strongSelf = self else{
                return
            }
            let actionSheet = UIAlertController(title: "", message: "", preferredStyle: .actionSheet)
            actionSheet.addAction(UIAlertAction(title: "Log Out", style: .destructive, handler: { [weak self] _ in
                guard let strongSelf = self else{
                    return
                }
                FBSDKLoginKit.LoginManager().logOut()
                GIDSignIn.sharedInstance().signOut()
                do{
                    try FirebaseAuth.Auth.auth().signOut()
                    let vc = LoginViewController()
                    let nav = UINavigationController(rootViewController: vc)
                    nav.modalPresentationStyle = .fullScreen
                    strongSelf.present(nav, animated: true)
                }
                catch{
                    print("Failed to log out!")
                }

            }))
            actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            strongSelf.present(actionSheet, animated: true)
        }))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableHeaderView = createTableHeader()
    

        // Do any additional setup after loading the view.
    }
    func createTableHeader() -> UIView? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else{
            return nil
        }
        print("This is the email: \(email)")
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        let fileName = safeEmail + "_profile_picture.png"
        
        let path = "image/"+fileName
        
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.width, height: 300))
        headerView.backgroundColor = .link
        let imageView = UIImageView(frame:CGRect(x: (view.width-150)/2, y: 75, width: 150, height: 150))
        
        imageView.contentMode = .scaleAspectFit
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.layer.borderWidth = 3
        imageView.backgroundColor = .white
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = imageView.width/2
        headerView.addSubview(imageView)
        StorageManager.shared.downloadUrl(for: path, completion:{[weak self] result in
            switch result{
            case .success(let url):
                imageView.sd_setImage(with: url, completed: nil)
                print(url)
            case .failure(let error):
                print("failed to get download url: \(error)")
            }
        })
        return headerView
        
    }

    

}
//extension for tableview
extension ProfileViewController : UITableViewDelegate, UITableViewDataSource{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = data[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: ProfileTableViewCell.identifier, for: indexPath) as! ProfileTableViewCell
        cell.setUp(with: viewModel)
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        //creating actionsheet when user click log out
        data[indexPath.row].handler?()
    }
}
class ProfileTableViewCell : UITableViewCell{
    static let identifier = "ProfileTableViewCell"
    public func setUp(with viewModel: ProfileViewModel){
        self.textLabel?.text = viewModel.title
        switch viewModel.viewModelType{
        case.info:
            self.textLabel?.textAlignment = .left
            
        case .logout:
            
            self.textLabel?.textColor = .red
            self.textLabel?.textAlignment = .center
            
        }
    }
}
