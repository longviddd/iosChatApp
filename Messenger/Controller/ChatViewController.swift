//
//  ChatViewController.swift
//  Messenger
//
//  Created by user195395 on 6/4/21.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import SDWebImage
import AVFoundation
import AVKit
struct Message : MessageType{
    var sender: SenderType
    
    var messageId: String
    
    var sentDate: Date
    
    var kind: MessageKind
}
struct Sender: SenderType{
    var photoURL: String
    var senderId: String
    var displayName: String
}
struct Media : MediaItem{
    var url: URL?
    var image: UIImage?
    var placeholderImage: UIImage
    var size: CGSize
}
extension MessageKind{
    var messageKindString : String{
        switch self{
        
        case .text(_):
            return "text"
        case .attributedText(_):
            return "attributed_text"
        case .photo(_):
            return "photo"
        case .video(_):
            return "video"
        case .location(_):
            return "location"
        case .emoji(_):
            return "emoji"
        case .audio(_):
            return "audio"
        case .contact(_):
            return "contact"
        case .linkPreview(_):
            return "linkPreview"
        case .custom(_):
            return "custom"
        }
    }
}


class ChatViewController: MessagesViewController {
    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        
        return formatter
    }()
    public var isNewConversation = false
    public let otherUserEmail : String
    private let conversationId : String?
    private var messages = [Message]()
    private var selfSender: Sender?{
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else{
            return nil
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        return Sender(photoURL: "", senderId: safeEmail, displayName: "Me")
    }
    init(with email : String, id: String?){
        self.conversationId = id
        self.otherUserEmail = email
        super.init(nibName: nil, bundle: nil)
        
    }
    //listen for messages and update the view
    private func listenForMessages(id: String){
        DatabaseManager.shared.getAllMessagesForConversation(wtih: id, completion: {[weak self]result in
            switch result{
            case .success(let messages):
                guard !messages.isEmpty else{
                    print("No messages")
                    return
                }
                self?.messages = messages
                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()
                    self?.messagesCollectionView.scrollToLastItem()
                }
            case .failure(let error):
                print("Failed to get messages: \(error)")
            }
        })
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        view.backgroundColor = .red
        //set delegates
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messagesCollectionView.delegate = self
        messageInputBar.delegate = self as InputBarAccessoryViewDelegate
        
        setupInputButton()
    }
    private func setupInputButton(){
        let button = InputBarButtonItem()
        button.setSize(CGSize(width: 35, height: 35), animated: false)
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.onTouchUpInside{ [weak self]_ in
            self?.presentInputActionSheet()
        }
        messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: false)
        messageInputBar.setStackViewItems([button], forStack: .left, animated: false)    }
    private func presentInputActionSheet(){
        let actionSheet = UIAlertController(title: "Attach media", message: "What would you like to attach?", preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Photo", style: .default, handler: {[weak self] _ in
            self?.presentPhotoInputActionSheet()
        }))
        actionSheet.addAction(UIAlertAction(title: "Video", style: .default, handler: {[weak self] _ in
            self?.presentVideoInputActionSheet()
        }))
        actionSheet.addAction(UIAlertAction(title: "Audio", style: .default, handler: {_ in
            
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(actionSheet, animated: true)
    }
    private func presentPhotoInputActionSheet(){
        let actionSheet = UIAlertController(title: "Attach photo", message: "Where would you like to attack a photo?", preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: {[weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: {[weak self]_ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
        present(actionSheet, animated: true)
    }
    private func presentVideoInputActionSheet(){
        let actionSheet = UIAlertController(title: "Attach Video", message: "Where would you like to attach a video?", preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: {[weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: {[weak self]_ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            self?.present(picker, animated: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
        present(actionSheet, animated: true)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
        if let conversationId = conversationId{
            listenForMessages(id: conversationId)
        }
    }
}
//extension for messagecollectionview
extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate{
    //func to get sender
    func currentSender() -> SenderType {
        if let sender = selfSender{
            return sender
        }
        fatalError("Self sender is nil, email should be cached")
        
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
    private func createMessageId() -> String?{
        
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else{
            return nil
        }
        let safeCurrentEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
        let dateString = Self.dateFormatter.string(from: Date())
        let newIdentifier = "\(otherUserEmail)_\(safeCurrentEmail)_\(dateString)"
        return newIdentifier
        
    }
    func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        guard let message  = message as? Message else{
            return
        }
        switch message.kind{
        case .photo(let media):
            guard let imageUrl = media.url else{
                return
            }
            imageView.sd_setImage(with: imageUrl, completed: nil)
        default:
            break
        }
    }
    
    
}
extension ChatViewController : MessageCellDelegate{
    func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else{
            return
        }
        let message = messages[indexPath.section]
        switch message.kind{
        case .photo(let media):
            guard let imageUrl = media.url else{
                return
            }
            let vc = PhotoViewerViewController(with: imageUrl)
            self.navigationController?.pushViewController(vc, animated: true)
        case .video(let media):
            guard let videoUrl = media.url else{
                return
            }
            let vc = AVPlayerViewController()
            vc.player = AVPlayer(url: videoUrl)
            present(vc, animated: true)
            
        default:
            break
        }
    }
}
extension ChatViewController:InputBarAccessoryViewDelegate{
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty, let selfSender = self.selfSender, let messageId = createMessageId() else{
            return
        }
        print("Sending \(text)")
        //check if convo is new
        let message = Message(sender: selfSender, messageId: messageId, sentDate: Date(), kind: .text(text))
        if isNewConversation{
            DatabaseManager.shared.createNewConversation(with: otherUserEmail, firstMessage: message, name: self.title ?? "User", completion: { [weak self]success in
                if success{
                    self?.messageInputBar.inputTextView.text = nil
                    print("message sent")
                    self?.isNewConversation = false
                }
                else{
                    print("Message failed to send")
                    
                }
            })
        }
        else{
            guard let conversationId = conversationId, let name = self.title else{
                return
            }
            //add to the convo in firebase
            DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: otherUserEmail, name: name, newMessage: message, completion: {success in
                if success{
                    print("Message sent")
                }
                else{
                    print("Message not sent")
                }
            })
        }
        
    }
}

//extension for imagepicker delegate
extension ChatViewController : UIImagePickerControllerDelegate, UINavigationControllerDelegate{
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        //dismiss picker
        picker.dismiss(animated: true, completion: nil)
        //check if user picked valid image
        guard let messageId = createMessageId(), let conversationId = conversationId, let name =  self.title, let selfSender = selfSender else{
            return
        }
        if let image = info[.editedImage] as? UIImage, let imageData = image.pngData(){
            //check if it is image type
            let fileName = "photo_message_" +  messageId.replacingOccurrences(of: " ", with: "-") + ".png"
            //create file name to upload to storage 
            //upload image
            StorageManager.shared.uploadMessagePhoto(with: imageData, fileName: fileName, completion: {[weak self]result in
                guard let strongSelf = self else{
                    return
                }
                
                switch result{
                case .success(let urlString):
                    //send message if success uploading
                    print("Uploaded Message Photo: \(urlString)")
                    guard let url = URL(string: urlString), let placeholder = UIImage(systemName: "plus") else{
                        return
                    }
                    let media = Media(url: url, image: nil, placeholderImage: placeholder, size: .zero)
                    let message = Message(sender: selfSender, messageId: messageId, sentDate: Date(), kind: .photo(media))
                    DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: strongSelf.otherUserEmail, name: name, newMessage: message, completion: {success in
                        if success {
                            print("Sent photo message")
                        }
                        else{
                            print("Photo failed to send")
                        }
                    })
                    break
                case .failure(let error):
                    print("Failed to upload photo \(error)")
                }
            })
        }
        else if let videoUrl = info[.mediaURL] as? URL{
            //check if videourl is valid
            let fileName = "photo_message_" +  messageId.replacingOccurrences(of: " ", with: "-") + ".mov"
            //create fileName for video
            StorageManager.shared.uploadMessageVideo(with: videoUrl, fileName: fileName, completion: {[weak self]result in
                guard let strongSelf = self else{
                    return
                }
                
                switch result{
                case .success(let urlString):
                    //send message if success uploading
                    print("Uploaded Message video: \(urlString)")
                    guard let url = URL(string: urlString), let placeholder = UIImage(systemName: "plus") else{
                        return
                    }
                    let media = Media(url: url, image: nil, placeholderImage: placeholder, size: .zero)
                    let message = Message(sender: selfSender, messageId: messageId, sentDate: Date(), kind: .video(media))
                    DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: strongSelf.otherUserEmail, name: name, newMessage: message, completion: {success in
                        if success {
                            print("Sent photo message")
                        }
                        else{
                            print("Photo failed to send")
                        }
                    })
                    break
                case .failure(let error):
                    print("Failed to upload photo \(error)")
                }
            })

            
        }


        
    }
}
