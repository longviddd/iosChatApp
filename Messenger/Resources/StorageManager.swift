//
//  StorageManager.swift
//  Messenger
//
//  Created by user195395 on 6/5/21.
//

import Foundation
import FirebaseStorage
final class StorageManager{
    public typealias UploadPictureCompletion = (Result<String,Error>) -> Void
    static let shared = StorageManager()
    private let storage = Storage.storage().reference()
    //func to upload profile picture
    public func uploadProfilePicture(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
        storage.child("image/\(fileName)").putData(data, metadata: nil, completion: {metadata, error in
            guard error == nil else{
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            self.storage.child("image/\(fileName)").downloadURL(completion: {url, error in
                guard let url = url else{
                    print("")
                    completion(.failure(StorageErrors.failedToGetDownloadUrl))
                    return
                }
                let urlString = url.absoluteString
                print("download url returned: \(urlString)")
                completion(.success(urlString))
                
            })
        })
    }
    ///Upload image that will be sent in a convo
    public func uploadMessagePhoto(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
        storage.child("messages_images/\(fileName)").putData(data, metadata: nil, completion: {[weak self]metadata, error in
            guard error == nil else{
                print("failed to upload image")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            self?.storage.child("messages_images/\(fileName)").downloadURL(completion: {url, error in
                guard let url = url else{
                    print("")
                    completion(.failure(StorageErrors.failedToGetDownloadUrl))
                    return
                }
                let urlString = url.absoluteString
                print("download url returned: \(urlString)")
                completion(.success(urlString))
                
            })
        })
    }
    public func uploadMessageVideo(with fileUrl: URL, fileName: String, completion: @escaping UploadPictureCompletion) {
        storage.child("messages_videos/\(fileName)").putFile(from: fileUrl, metadata: nil, completion: {metadata, error in
            guard error == nil else{
                print("failed to upload video to firebase")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            self.storage.child("messages_videos/\(fileName)").downloadURL(completion: {url, error in
                guard let url = url else{
                    print("")
                    completion(.failure(StorageErrors.failedToGetDownloadUrl))
                    return
                }
                let urlString = url.absoluteString
                print("download url returned: \(urlString)")
                completion(.success(urlString))
                
            })
        })
    }
    ///Upload videos that are sent
    public func downloadUrl(for path: String, completion: @escaping (Result<URL,Error>) -> Void){
        let reference = storage.child(path)
        reference.downloadURL(completion: {url, error in
            guard let url = url, error == nil else{
                completion(.failure(StorageErrors.failedToGetDownloadUrl))
                return
            }
            completion(.success(url))
        })
    }
    public enum StorageErrors: Error{
        case failedToUpload
        case failedToGetDownloadUrl
    }
}
