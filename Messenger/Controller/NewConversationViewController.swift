//
//  NewConversationViewController.swift
//  Messenger
//
//  Created by user195395 on 5/28/21.
//

import UIKit
import JGProgressHUD
struct SearchResult{
    let name: String
    let email : String
    
}
class NewConversationViewController: UIViewController {
    private let spinner = JGProgressHUD(style: .dark)
    private var users = [[String:String]]()
    private var results = [SearchResult]()
    public var completion: ((SearchResult) -> (Void))?
    private var hasFetched = false
    
    private let searchBar : UISearchBar = {
       let searchBar = UISearchBar()
        searchBar.placeholder = "Search for users..."
        return searchBar
    }()
    private let tableView : UITableView = {
       let table = UITableView()
        table.register(NewConversationCell.self, forCellReuseIdentifier: NewConversationCell.identifier)
        table.isHidden = true
        return table
    }()
    private let noResultsLabel: UILabel = {
       let label = UILabel()
        label.text = "No Results"
        label.textAlignment = .center
        label.isHidden = true
        label.textColor = .green
        label.font = .systemFont(ofSize:21, weight: .medium)
        return label
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        view.addSubview(noResultsLabel)
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        searchBar.delegate = self
        navigationController?.navigationBar.topItem?.titleView = searchBar
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel", style: .done, target: self, action: #selector(dismissSelf))
        searchBar.becomeFirstResponder()
    }
    override func viewDidLayoutSubviews() {
        tableView.frame = view.bounds
        noResultsLabel.frame = CGRect(x: view.width/4, y: (view.height-200)/2, width: view.width/2, height: 200)
    }
    @objc func dismissSelf(){
        dismiss(animated: true, completion: nil)
    }
    
}
extension NewConversationViewController : UITableViewDelegate, UITableViewDataSource{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = results[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: NewConversationCell.identifier, for: indexPath) as! NewConversationCell
        cell.configure(with: model)
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        //start conversation
        let targetUserData = results[indexPath.row]
        print(targetUserData)
        dismiss(animated: true, completion: {[weak self] in
            self?.completion?(targetUserData)
            
        })
        
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
}
extension NewConversationViewController : UISearchBarDelegate{
    func searchBarSearchButtonClicked(_ searchBar : UISearchBar){
        guard let text = searchBar.text , !text.replacingOccurrences(of: " ", with: "").isEmpty else{
            return
        }
        searchBar.resignFirstResponder()
        results.removeAll()
        spinner.show(in: view)
        self.searchUsers(query: text)
    }
    func searchUsers(query: String){
        //check if has already fetched
        if hasFetched{
            //if has fetched, filter the users
            filterUsers(with: query)
        }
        else{
            //if not fetched, get all user
            DatabaseManager.shared.getAllUsers(completion: {[weak self] result in
                switch result{
                case.success(let usersCollection):
                    self?.users = usersCollection
                    self?.hasFetched = true
                    self?.filterUsers(with: query)
                case .failure(let error):
                    print("failed to get users: \(error)")
                }
                
                
            })
        }
        
    }
    func filterUsers(with term: String){
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String, hasFetched else{
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
        self.spinner.dismiss()
        let results : [SearchResult] = self.users.filter({
            guard let email = $0["email"], email != safeEmail else{
                return false
            }
            guard let name = $0["name"]?.lowercased() else{
                return false
            }
            return name.hasPrefix(term.lowercased())
        }).compactMap({
            guard let email = $0["email"], let name = $0["name"] else{
                return nil
            }
            return SearchResult(name: name, email: email)
        })
        self.results = results
        updateUI()
        
    }
    func updateUI(){
        if results.isEmpty{
            noResultsLabel.isHidden = false
            tableView.isHidden = true
        }
        else{
            noResultsLabel.isHidden = true
            tableView.isHidden = false
            tableView.reloadData()
        }
    }
}
