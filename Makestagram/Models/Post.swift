//
//  Post.swift
//  Makestagram
//
//  Created by Scott Chow on 6/23/16.
//  Copyright © 2016 Make School. All rights reserved.
//

import UIKit
import Parse
import Bond
import ConvenienceKit

class Post: PFObject, PFSubclassing {
    
    @NSManaged var imageFile: PFFile?
    @NSManaged var user: PFUser?
    var image: Observable<UIImage?> = Observable(nil)
    var photoUploadTask: UIBackgroundTaskIdentifier?
    var likes: Observable<[PFUser]?> = Observable(nil)
    static var imageCache: NSCacheSwift<String, UIImage>!
    
    func uploadPost() {
        
        if let image = image.value {
            
            guard let imageData = UIImageJPEGRepresentation(image, 0.8) else {return}
            guard let imageFile = PFFile(name: "image.jpg", data: imageData) else {return}
            
            user = PFUser.currentUser()
            self.imageFile = imageFile
            
            photoUploadTask = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler { () -> Void in
                UIApplication.sharedApplication().endBackgroundTask(self.photoUploadTask!)
            }
            
            saveInBackgroundWithBlock { (success: Bool, error: NSError?) -> Void in
                UIApplication.sharedApplication().endBackgroundTask(self.photoUploadTask!)
            }
        }
    }
    
    func downloadImage() {
        
        image.value = Post.imageCache[self.imageFile!.name]
        
        if (image.value == nil) {
            
            imageFile?.getDataInBackgroundWithBlock { (data: NSData?, error: NSError?) -> Void in
                
                if let data = data {
                    
                    let image = UIImage(data: data, scale: 1.0)!
                    self.image.value = image
                    Post.imageCache[self.imageFile!.name] = image
                }
            }
        }
    }
    
    func fetchLikes() {
        
        if (likes.value != nil) {
            return
        }
        
        ParseHelper.likesForPost(self, completionBlock: { (likes: [PFObject]?, error: NSError?) -> Void in
            
            let validLikes = likes?.filter { like in like[ParseHelper.ParseLikeFromUser] != nil }
            self.likes.value = validLikes?.map { like in
                let fromUser = like[ParseHelper.ParseLikeFromUser] as! PFUser
                return fromUser
            }
        })
    }
    
    func toggleLikePost(user: PFUser) {
        
        if(doesUserLikePost(user)) {
            
            likes.value = likes.value?.filter { $0 != user}
            ParseHelper.unlikePost(user, post: self)
        } else {
            
            likes.value?.append(user)
            ParseHelper.likePost(user, post: self)
        }
    }
    
    func doesUserLikePost(user: PFUser) -> Bool {
        if let likes = likes.value {
            return likes.contains(user)
        } else {
            return false
        }
    }
    
    static func parseClassName() -> String {
        return "Post"
    }
    
    override init() {
        super.init()
    }
    
    override class func initialize() {
        var onceToken: dispatch_once_t = 0;
        dispatch_once(&onceToken) {
            self.registerSubclass()
            
            Post.imageCache = NSCacheSwift<String, UIImage>()
        }
    }
}



