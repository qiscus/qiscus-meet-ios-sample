//
//  File.swift
//  Qiscus
//
//  Created by Rahardyan Bisma on 07/05/18.
//

import Foundation
import QiscusCore
import AlamofireImage

protocol UIChatUserInteraction {
    func sendMessage(withText text: String)
    func loadRoom(withId roomId: String)
    func loadComments(withID roomId: String)
    func loadMore()
    func getAvatarImage(section: Int, imageView: UIImageView)
    func getMessage(atIndexPath: IndexPath) -> CommentModel
}

protocol UIChatViewDelegate {
    func onLoadRoomFinished(roomName: String, roomAvatarURL: URL?)
    func onLoadMessageFinished()
    func onLoadMessageFailed(message: String)
    func onLoadMoreMesageFinished()
    func onReloadComment()
    func onSendingComment(comment: CommentModel, newSection: Bool)
    func onSendMessageFinished(comment: CommentModel)
    func onGotNewComment(newSection: Bool,_message:CommentModel)
    func onUpdateComment(comment: CommentModel, indexpath: IndexPath)
    func onUser(name: String, typing: Bool)
    func onUser(name: String, isOnline: Bool, message: String)
}

class UIChatPresenter: UIChatUserInteraction {
    private var viewPresenter: UIChatViewDelegate?
    var comments: [[CommentModel]]
    var room: RoomModel? 
    var loadMoreAvailable: Bool = true
    var participants : [MemberModel] = [MemberModel]()
    var loadMoreDispatchGroup: DispatchGroup = DispatchGroup()
    var lastIdToLoad: String = ""
    
    init() {
        self.comments = [[CommentModel]]()
    }
    
    func attachView(view : UIChatViewDelegate){
        viewPresenter = view
        if let room = self.room {
            room.delegate = self
            self.loadRoom()
            self.loadComments(withID: room.id)
            viewPresenter?.onLoadRoomFinished(roomName: room.name, roomAvatarURL: room.avatarUrl)
            if let p = room.participants {
                self.participants = p
            }
        }
    }
    
    func detachView() {
        viewPresenter = nil
        if let room = self.room {
            room.delegate = nil
        }
    }
    
    func getMessage(atIndexPath: IndexPath) -> CommentModel {
        let comment = comments[atIndexPath.section][atIndexPath.row]
        return comment
    }
    
    func loadRoom(withId roomId: String) {
        //
    }
    
    /// Update room
    func loadRoom() {
        guard let _room = self.room else { return }
        QiscusCore.shared.getChatRoomWithMessages(roomId: _room.id, onSuccess: { [weak self] (room,comments) in
            guard let instance = self else { return }
            if comments.isEmpty {
                instance.viewPresenter?.onLoadMessageFailed(message: "no message")
                return
            }
            instance.loadComments(withID: room.id)
        }) { [weak self] (error) in
            guard let instance = self else { return }
            instance.viewPresenter?.onLoadMessageFailed(message: error.message)
        }
    }
    
    func loadComments(withID roomId: String) {
        if let room = QiscusCore.database.room.find(id: roomId){
            // load local
            if let _comments = QiscusCore.database.comment.find(roomId: roomId) {
                guard let lastComment = _comments.last else { return }
                // read comment
                if let lastComment = room.lastComment {
                     QiscusCore.shared.markAsRead(roomId: roomId, commentId: lastComment.id)
                }
               
                self.comments = self.groupingComments(_comments)
                self.viewPresenter?.onLoadMessageFinished()
            }
        }
        
    }
    
    func loadMore() {
        if loadMoreAvailable {
            // initiate loadmore operation on background thread
            DispatchQueue.global(qos: .background).async { [weak self] in
                // since this is async we need to use weak rather than owned because we cant guarantee that self instance still exist, so we will use guard to avoid force unwraping optional value
                guard let instance = self else { return }
                
                // initiate loadmore dispatch group (as a queue to make it synchronous)
                instance.loadMoreDispatchGroup.enter()
                
                // avoiding on force unwrap optional value
                guard let lastGroup = instance.comments.last else { return }
                guard let lastComment = lastGroup.last else { return }
                guard let roomId = instance.room?.id else { return }
                
                // make sure that last comment's id isn't empty or load more for current id is still in process to prevent duplicate message
                if lastComment.id.isEmpty || instance.lastIdToLoad == lastComment.id {
                    return
                }
                
                // update lastIdToLoad value
                instance.lastIdToLoad = lastComment.id
                 QiscusCore.shared.getPreviousMessagesById(roomID: roomId,limit: 10,messageId: lastComment.id, onSuccess: { (comments) in
                    
                    // notify the dispatch group that the current process is complete and able to continue to the next load more process
                    instance.loadMoreDispatchGroup.leave()
                    
                    // if the loadmore from core return empty comment than it means that there are no comments left to be loaded anymore
                    if comments.count == 0 {
                        instance.loadMoreAvailable = false
                    }
                    
                    // we group the loaded comments by date(same day) and sender [[you, you][me, me][you]]
                    var groupedLoadedComment = instance.groupingComments(comments)
                    
                    // check if the first comment in the first section from the load more result has the same date then add merge first section from loaded comments with last section from existing comments
                    if lastComment.date.reduceToMonthDayYear() == groupedLoadedComment.first?.first?.date.reduceToMonthDayYear() {
                        // last section of existing comments
                        guard var lastGroup = instance.comments.last else { return }
                        
                        // first section of loaded comments
                        guard let firstGroupInLoadedComment = groupedLoadedComment.first else { return }
                        
                        // merge both of them
                        lastGroup.append(contentsOf: firstGroupInLoadedComment)
                        
                        // remove last section from existing comments
                        instance.comments.removeLast()
                        
                        // replace with merged comment (first section loaded comments and last section existing comment)
                        instance.comments.append(lastGroup)
                        
                        // remove section that has ben merged (first section) from the loaded comments
                        groupedLoadedComment.removeFirst()
                    }
                    
                    // finaly append the loaded comment from load more to existing comments
                    instance.comments.append(contentsOf: groupedLoadedComment)
                    
                    DispatchQueue.main.async {
                        // notify the ui that loadmore has completed
                        instance.viewPresenter?.onLoadMoreMesageFinished()
                    }
                }) { [weak self] (error) in
                    if let instance = self {
                        instance.loadMoreDispatchGroup.leave()
                    }
                }
                
                
                instance.loadMoreDispatchGroup.wait()
            }
        }
    }
    
    func isTyping(_ value: Bool) {
        if let r = self.room {
            QiscusCore.shared.publishTyping(roomID: r.id, isTyping: value)
        }
    }
    
    func sendMessage(withComment comment: CommentModel, onSuccess: @escaping (CommentModel) -> Void, onError: @escaping (String) -> Void) {
        addNewCommentUI(comment, isIncoming: false)
        QiscusCore.shared.sendMessage(message: comment, onSuccess: { [weak self] (comment) in
            self?.didComment(comment: comment, changeStatus: comment.status)
            onSuccess(comment)
        }) { (error) in
            onError(error.message)
        }
    }
    
    func editMessage(withComment comment: CommentModel, onSuccess: @escaping (CommentModel) -> Void, onError: @escaping (String) -> Void) {
        QiscusCore.shared.updateMessage(message: comment, onSuccess: { [weak self] (comment) in
            onSuccess(comment)
        }) { (error) in
            onError(error.message)
        }
    }
    
    func call(message:CommentModel){
      
        addNewCommentUI(message, isIncoming: false)
        QiscusCore.shared.sendMessage(message: message, onSuccess:{ [weak self] (comment) in
            self?.didComment(comment: comment, changeStatus: comment.status)
        }) { (error) in
            //
        }
    }
    
    func sendMessage(withText text: String) {
        // create object comment
        // MARK: TODO improve object generator
        let message = CommentModel()
        message.message = text
        message.type    = "text"
        if let r = self.room {
             message.roomId  = r.id
        }
       
        addNewCommentUI(message, isIncoming: false)
        QiscusCore.shared.sendMessage(message: message, onSuccess:{ [weak self] (comment) in
            self?.didComment(comment: comment, changeStatus: comment.status)
        }) { (error) in
            //
        }
    }
    
    private func addNewCommentUI(_ message: CommentModel, isIncoming: Bool) {
        // add new comment to ui
        var section = false
        if self.comments.count > 0 {
            if self.comments[0].count > 0 {
                let lastComment = self.comments[0][0]
                if lastComment.date.reduceToMonthDayYear() == message.date.reduceToMonthDayYear() {
                    self.comments[0].insert(message, at: 0)
                    section = false
                } else {
                    self.comments.insert([message], at: 0)
                    section = true
                }
            } else {
                self.comments.insert([message], at: 0)
                section = true
            }
        } else {
            // last comments is empty, then create new group and append this comment
            self.comments.insert([message], at: 0)
            section = true
        }
        
        // choose uidelegate
        if isIncoming {
            QiscusCore.shared.markAsRead(roomId: message.roomId, commentId: message.id)
            self.viewPresenter?.onGotNewComment(newSection: section,_message: message)
        }else {
            self.viewPresenter?.onSendingComment(comment: message, newSection: section)
        }
    }
    
    func getAvatarImage(section: Int, imageView: UIImageView) {
        if self.comments.count > 0 {
            if self.comments[0].count > 0 {
                if let url = self.comments[0][0].userAvatarUrl {
                    imageView.af_setImage(withURL: url)
                }
            }
        }
    }
    
    /// Grouping by useremail and date(same day), example [[you,you],[me,me],[me]]
    private func groupingComments(_ data: [CommentModel]) -> [[CommentModel]]{
        var retVal = [[CommentModel]]()
        let groupedMessages = Dictionary(grouping: data) { (element) -> Date in
            return element.date.reduceToMonthDayYear()
        }
        
        let sortedKeys = groupedMessages.keys.sorted(by: { $0.compare($1) == .orderedDescending })
        sortedKeys.forEach { (key) in
            let values = groupedMessages[key]
            retVal.append(values ?? [])
        }
        return retVal
    }
    
    func getIndexPath(comment : CommentModel) -> IndexPath? {
        for (group,c) in self.comments.enumerated() {
            if let index = c.index(where: { $0.uniqId == comment.uniqId }) {
                return IndexPath.init(row: index, section: group)
            }
        }
        return nil
    }
}


// MARK: Core Delegate
extension UIChatPresenter : QiscusCoreRoomDelegate {
    func onMessageUpdated(message: CommentModel) {
        for (group,c) in comments.enumerated() {
            if let index = c.index(where: { $0.uniqId == message.uniqId }) {
                comments[group][index] = message
                self.viewPresenter?.onUpdateComment(comment: message, indexpath: IndexPath(row: index, section: group))
            }
        }
    }
    func onMessageReceived(message: CommentModel){
        // 2check comment already in ui?
        if (self.getIndexPath(comment: message) == nil) {
            self.addNewCommentUI(message, isIncoming: true)
        }
    }
    
    func onMessageDelivered(message : CommentModel){
        // check comment already exist in view
        for (group,c) in comments.enumerated() {
            if let index = c.index(where: { $0.uniqId == message.uniqId }) {
                comments[group][index] = message
                self.viewPresenter?.onUpdateComment(comment: message, indexpath: IndexPath(row: index, section: group))
            }
        }
    }
    
    func onMessageRead(message : CommentModel){
        // check comment already exist in view
        for (group,c) in comments.enumerated() {
            if let index = c.index(where: { $0.uniqId == message.uniqId }) {
                comments[group][index] = message
                self.viewPresenter?.onUpdateComment(comment: message, indexpath: IndexPath(row: index, section: group))
            }
        }
    }
    
    func onMessageDeleted(message: CommentModel){
        for (group,var c) in comments.enumerated() {
            if let index = c.index(where: { $0.uniqId == message.uniqId }) {
                c.remove(at: index)
                self.comments = groupingComments(c)
                self.lastIdToLoad = ""
                self.loadMoreAvailable = true
                self.viewPresenter?.onReloadComment()
            }
        }
    }
    
    func onUserTyping(userId : String, roomId : String, typing: Bool){
        if let user = QiscusCore.database.member.find(byUserId : userId){
            self.viewPresenter?.onUser(name: user.username, typing: typing)
        }
    }
    
    func onUserOnlinePresence(userId: String, isOnline: Bool, lastSeen: Date){
        if let room = self.room {
            if room.type != .group {
                let message = lastSeen.timeAgoSinceDate(numericDates: false)
                if let user = QiscusCore.database.member.find(byUserId : userId){
                    self.viewPresenter?.onUser(name: user.username, isOnline: isOnline, message: message)
                }
            }
        }
    }
    
    //this func was deprecated
    func didDelete(Comment comment: CommentModel) {
        for (group,var c) in comments.enumerated() {
            if let index = c.index(where: { $0.uniqId == comment.uniqId }) {
                c.remove(at: index)
                self.comments = groupingComments(c)
                self.lastIdToLoad = ""
                self.loadMoreAvailable = true
                self.viewPresenter?.onReloadComment()
            }
        }
    }
    
    //this func was deprecated
    func onRoom(update room: RoomModel) {
        // 
    }
    
     //this func was deprecated
    func didComment(comment: CommentModel, changeStatus status: CommentStatus) {
       // check comment already exist in view
       for (group,c) in comments.enumerated() {
           if let index = c.index(where: { $0.uniqId == comment.uniqId }) {
               comments[group][index] = comment
               self.viewPresenter?.onUpdateComment(comment: comment, indexpath: IndexPath(row: index, section: group))
           }
       }
    }
}

