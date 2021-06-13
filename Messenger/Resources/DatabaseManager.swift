//
//  DatabaseManager.swift
//  Messenger
//
//  Created by user195395 on 6/2/21.
//

import Foundation
import FirebaseDatabase
import MessageKit

final class DatabaseManager{
    static let shared = DatabaseManager()
    private let database = Database.database().reference()
    static func safeEmail(emailAddress: String) -> String{
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    
}

// MARK: - Account Management
extension DatabaseManager{
    public func userExists( with email: String, completion: @escaping ((Bool) -> Void)){
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        database.child(safeEmail).observeSingleEvent(of: .value, with: {snapshot in
            guard snapshot.value as? [String: Any] != nil else{
                completion(false)
                return
            }
            completion(true)
        })
    }
    /// Inserts new user to database
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool)->Void){
        database.child(user.safeEmail).setValue([
            "first_name"  : user.firstName,
            "last_name" : user.lastName
        ], withCompletionBlock: {error, _ in
            guard error == nil else{
                print("Failed to write to database")
                completion(false)
                return
            }
            self.database.child("users").observeSingleEvent(of: .value, with: {snapshot in
                if var usersCollection = snapshot.value as?[[String: String]]{
                    //check if usercollection already exists
                    let newElement =   [
                        "name": user.firstName + " " + user.lastName,
                        "email": user.safeEmail
                    ]
                    usersCollection.append(newElement)
                    self.database.child("users").setValue(usersCollection, withCompletionBlock: { error, _ in
                        guard error == nil else{
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                }else{
                    //else create
                    let newCollection: [[String: String]] = [
                        [
                            "name": user.firstName + " " + user.lastName,
                            "email": user.safeEmail
                        ]
                    ]
                    self.database.child("users").setValue(newCollection, withCompletionBlock: { error, _ in
                        guard error == nil else{
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                }
            })
            completion(true)
        })
    }
    public func getAllUsers(completion: @escaping (Result<[[String:String]], Error>) -> Void){
        database.child("users").observeSingleEvent(of: .value, with: {snapshot in
            guard let value = snapshot.value as?[[String:String]] else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
    public enum DatabaseError: Error{
        case failedToFetch
    }
}
//MARK: Struct for user
struct ChatAppUser{
    let firstName: String
    let lastName: String
    let emailAddress: String
    var safeEmail : String{
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    var profilePictureFileName: String{
        return"\(safeEmail)_profile_picture.png"
    }
    //let profilePictureUrl : String
}
// MARK: - Getting User infos
extension DatabaseManager{
    public func getDataFor(path:String, completion: @escaping(Result<Any, Error>) -> Void){
        print(path)
        database.child("\(path)").observeSingleEvent(of: .value, with: {snapshot in
            guard let value = snapshot.value else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
}
// MARK: - Managing messages / Convo
extension DatabaseManager{
    public func createNewConversation(with otherUserEmail: String, firstMessage: Message, name : String, completion: @escaping (Bool) -> Void){
        //create a new conversation with targetr
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String, let currentName = UserDefaults.standard.value(forKey: "name") as? String else{
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        let ref = database.child("\(safeEmail)")
        ref.observeSingleEvent(of: .value, with: {[weak self]snapshot in
            guard var userNode = snapshot.value as? [String : Any] else{
                completion(false)
                print("User not found")
                return
            }
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            var message = ""
            switch firstMessage.kind{
            case.text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .contact(_):
                break
            case .custom(_):
                break
            case .audio(_):
                break
            case .linkPreview(_):
                break
            }
            let conversationId = "conversation_\(firstMessage.messageId)"
            let newConversationData: [String:Any] = [
                "id": conversationId,
                "other_user_email": otherUserEmail,
                "name": name,
                "latest_message":[
                    "date": dateString,
                    "message": message,
                    "is_read" : false
                ]
            ]
            let recipient_newConversationData: [String:Any] = [
                "id": conversationId,
                "other_user_email": safeEmail,
                "name": currentName,
                "latest_message":[
                    "date": dateString,
                    "message": message,
                    "is_read" : false
                ]
            ]
            //update recipent conversation entry
            self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: {[weak self]snapshot in
                if var conversations = snapshot.value as? [[String:Any]]{
                    //apend
                    conversations.append(recipient_newConversationData)
                    self?.database.child("\(otherUserEmail)/conversations").setValue(conversations)
                }
                else{
                    self?.database.child("\(otherUserEmail)/conversations").setValue([recipient_newConversationData])
                }
            })
            //update current user entry
            if var conversations = userNode["conversations"] as? [[String:Any]]{
                //conversation already exists ->append
                conversations.append(newConversationData)
                userNode["conversations"] = conversations
                ref.setValue(userNode, withCompletionBlock: {[weak self]error, _ in
                    guard error == nil else{
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversion(conversationID: conversationId, firstMessage: firstMessage, name: name, completion: completion)
                })
            }
            else{
                //convo doesn't exist -> create one into usernode
                userNode["conversations"] = [
                    newConversationData
                ]
            }
            ref.setValue(userNode, withCompletionBlock: {[weak self]error, _ in
                guard error == nil else{
                    completion(false)
                    return
                }
                self?.finishCreatingConversion(conversationID: conversationId, firstMessage: firstMessage, name: name, completion: completion)
            })
        })
        
    }
    private func finishCreatingConversion(conversationID: String, firstMessage: Message, name : String, completion: @escaping (Bool) -> Void){
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)
        var message = ""
        switch firstMessage.kind{
        case.text(let messageText):
            message = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .contact(_):
            break
        case .custom(_):
            break
        case .audio(_):
            break
        case .linkPreview(_):
            break
        }
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else{
            completion(false)
            return
        }
        let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        let collectionMessage :[String:Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": message,
            "date" : dateString,
            "sender_email": currentUserEmail,
            "name":name,
            "is_read" : false
        ]
        let value: [String:Any] = [
            "messages": [
                collectionMessage
            ]
        ]
        database.child("\(conversationID)").setValue(value, withCompletionBlock: {error , _ in
            guard error == nil else{
                completion(false)
                return
            }
            completion(true)
        })
    }
    public func getAllConversations(for email: String, completion: @escaping (Result<[Conversation], Error>) -> Void){
        database.child("\(email)/conversations").observe(.value, with: {snapshot in
            guard let value = snapshot.value as? [[String: Any]] else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            let conversations :[Conversation] = value.compactMap({dictionary in
                guard let conversationId = dictionary["id"] as? String, let name = dictionary["name"] as? String, let otherUserEmail = dictionary["other_user_email"] as? String, let latestMessage = dictionary["latest_message"] as? [String:Any], let date = latestMessage["date"] as? String, let message = latestMessage["message"] as? String, let isRead = latestMessage["is_read"] as? Bool else{
                    print("Failed to get user data")
                    return nil
                }
                let latestMessageObject = LatestMessage(date: date, text: message, isRead: isRead)
                return Conversation(id: conversationId, name: name, otherUserEmail: otherUserEmail, latestMessage: latestMessageObject)
            })
            completion(.success(conversations))
        })
    }
    public func getAllMessagesForConversation(wtih id: String, completion: @escaping (Result<[Message], Error>) -> Void){
        database.child("\(id)/messages").observe(.value, with: {snapshot in
            guard let value = snapshot.value as? [[String: Any]] else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            let messages :[Message] = value.compactMap({dictionary in
                guard let name = dictionary["name"] as? String, let isRead = dictionary["name"] as? String, let messageId = dictionary["id"] as? String, let content = dictionary["content"] as? String, let senderEmail = dictionary["sender_email"] as? String, let dateString = dictionary["date"] as? String, let type = dictionary["type"] as? String,  let date = ChatViewController.dateFormatter.date(from: dateString) else{
                    return nil
                }
                var kind : MessageKind?
                if type == "photo"{
                    guard let imageUrl = URL(string: content), let placeHolder = UIImage(systemName: "plus") else{
                        return nil
                    }
                    let media = Media(url: imageUrl, image: nil, placeholderImage: placeHolder, size: CGSize(width: 300, height: 300))
                    kind = .photo(media)
                }
                else if type == "video"{
                    guard let videoUrl = URL(string: content), let placeHolder = UIImage(systemName:"video_placeholder") else{
                        return nil
                    }
                    let media = Media(url: videoUrl, image: nil, placeholderImage: placeHolder, size: CGSize(width: 300, height: 300))
                    kind = .video(media)

                }
                else{
                    kind = .text(content)
                }
                guard let finalKind = kind else{
                    return nil
                }
                let sender = Sender(photoURL: "", senderId: senderEmail, displayName: name)
                return Message(sender: sender, messageId: messageId, sentDate: date, kind: finalKind)
                
                
                
            })
            completion(.success(messages))
        })
    }
    public func sendMessage(to conversation: String, otherUserEmail: String, name: String, newMessage: Message, completion: @escaping (Bool) -> Void){
        self.database.child("\(conversation)/messages").observeSingleEvent(of: .value, with: {[weak self]snapshot in
            guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else{
                completion(false)
                return
            }
            let currentEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
            guard let strongSelf = self else {
                return
            }
            guard var currentMessages = snapshot.value as? [[String:Any]] else{
                completion(false)
                return
            }
            let messageDate =  newMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            var message = ""
            switch newMessage.kind{
            case.text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(let mediaItem):
                if let targetUrlString = mediaItem.url?.absoluteString{
                    message = targetUrlString
                }
                break
            case .video(let mediaItem):
                if let targetUrlString = mediaItem.url?.absoluteString{
                    message = targetUrlString
                }
                
            case .location(_):
                break
            case .emoji(_):
                break
            case .contact(_):
                break
            case .custom(_):
                break
            case .audio(_):
                break
            case .linkPreview(_):
                break
            }
            guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else{
                completion(false)
                return
            }
            let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
            let newMessageEntry :[String:Any] = [
                "id": newMessage.messageId,
                "type": newMessage.kind.messageKindString,
                "content": message,
                "date" : dateString,
                "sender_email": currentUserEmail,
                "name":name,
                "is_read" : false
            ]
            currentMessages.append(newMessageEntry)
            strongSelf.database.child("\(conversation)/messages").setValue(currentMessages) {error, _ in
                guard error == nil else{
                    completion(false)
                    return
                }
                strongSelf.database.child("\(currentEmail)/conversations").observeSingleEvent(of: .value, with: {snapshot in
                    guard var currentUserConversations = snapshot.value as? [[String:Any]] else{
                        completion(false)
                        return
                    }
                    var targetConversation : [String:Any]?
                    var position = 0
                    let updatedValue :[String:Any] = [
                        "date":dateString,
                        "is_read": false,
                        "message": message
                    ]
                    for conversationDictionary in currentUserConversations{
                        if let currentId = conversationDictionary["id"] as? String, currentId == conversation{
                            targetConversation = conversationDictionary
                            
                            break
                        }
                        position += 1
                    }
                    targetConversation?["latest_message"] = updatedValue
                    guard let finalConversation = targetConversation else{
                        completion(false)
                        return
                    }
                    currentUserConversations[position] = finalConversation
                    strongSelf.database.child("\(currentEmail)/conversations").setValue(currentUserConversations, withCompletionBlock: {error, _ in
                        guard error == nil else{
                            completion(false)
                            return
                        }
                        //update the recipent newest message
                        strongSelf.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: {snapshot in
                            guard var otherUserConversations = snapshot.value as? [[String:Any]] else{
                                completion(false)
                                return
                            }
                            var targetConversation : [String:Any]?
                            var position = 0
                            let updatedValue :[String:Any] = [
                                "date":dateString,
                                "is_read": false,
                                "message": message
                            ]
                            for conversationDictionary in otherUserConversations{
                                if let currentId = conversationDictionary["id"] as? String, currentId == conversation{
                                    targetConversation = conversationDictionary
                                    
                                    break
                                }
                                position += 1
                            }
                            targetConversation?["latest_message"] = updatedValue
                            guard let finalConversation = targetConversation else{
                                completion(false)
                                return
                            }
                            otherUserConversations[position] = finalConversation
                            strongSelf.database.child("\(otherUserEmail)/conversations").setValue(otherUserConversations, withCompletionBlock: {error, _ in
                                guard error == nil else{
                                    completion(false)
                                    return
                                }
                                completion(true)
                            })
                        })

                       
                    })
                })
            }
        })
    }
    public func deleteConversation(conversationId: String, completion: @escaping (Bool) -> Void) {
            guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
                return
            }
            let safeEmail = DatabaseManager.safeEmail(emailAddress: email)

            print("Deleting conversation with id: \(conversationId)")

            // Get all conversations for current user
            // delete conversation in collection with target id
            // reset those conversations for the user in database
            let ref = database.child("\(safeEmail)/conversations")
            ref.observeSingleEvent(of: .value) { snapshot in
                if var conversations = snapshot.value as? [[String: Any]] {
                    var positionToRemove = 0
                    for conversation in conversations {
                        if let id = conversation["id"] as? String,
                            id == conversationId {
                            print("found conversation to delete")
                            break
                        }
                        positionToRemove += 1
                    }

                    conversations.remove(at: positionToRemove)
                    ref.setValue(conversations, withCompletionBlock: { error, _  in
                        guard error == nil else {
                            completion(false)
                            print("faield to write new conversatino array")
                            return
                        }
                        print("deleted conversaiton")
                        completion(true)
                    })
                }
            }
        }
    public func conversationExists(with targetRecipentEmail : String, completion: @escaping (Result<String, Error>) -> Void){
        let safeRecipentEmail = DatabaseManager.safeEmail(emailAddress: targetRecipentEmail)
        guard let senderEmail = UserDefaults.standard.value(forKey: "email") as? String else{
            return
        }
        let safeSenderEmail = DatabaseManager.safeEmail(emailAddress: senderEmail)
        database.child("\(safeRecipentEmail)/conversations").observeSingleEvent(of: .value, with: {snapshot in
            guard let collection = snapshot.value as? [[String:Any]] else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            if let conversation = collection.first(where: {
                guard let targetSenderEmail = $0["other_user_email"] as? String else{
                    
                    return false
                }
                return safeSenderEmail == targetSenderEmail
            }){
                guard let id = conversation["id"] as? String else{
                    completion(.failure(DatabaseError.failedToFetch))
                    return
                }
                completion(.success(id))
                return
            }
            completion(.failure(DatabaseError.failedToFetch))
            return
        })
    }
}

