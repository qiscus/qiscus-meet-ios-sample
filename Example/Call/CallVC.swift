//
//  CallController.swift
//  Example
//
//  Created by Gustu Maulana Firmansyah on 05/11/21.
//  Copyright © 2021 Qiscus. All rights reserved.
//

import Foundation
import QiscusCore
import UIKit
import QiscusMeet
class CallVC : UIViewController {
    var isCaller:Bool = false
    var isCalling:Bool = false
    @IBOutlet weak var imageCaller: UIImageView!
    @IBOutlet weak var nameCaller: UILabel!
    
    @IBOutlet weak var btHangUp: UIButton!
    @IBOutlet weak var btAnswer: UIButton!
    var room : RoomModel? {
        set(newValue) {
            self.presenter.room = newValue
            self.refreshUI()
        }
        get {
            return self.presenter.room
        }
    }
    
    var profile:UserModel?=nil
    
    var presenter:UIChatPresenter = UIChatPresenter()

    override func viewDidLoad() {
        self.setupUI()
        profile = QiscusCore.getUserData()
//        QiscusCore.delegate = self
        QiscusMeet.shared.QiscusMeetDelegate = self
    }
    override func viewWillAppear(_ animated: Bool) {
        presenter.attachView(view: self)
    }
    override func viewWillDisappear(_ animated: Bool) {
        presenter.detachView()
    }
    func setupUI(){
        presenter.attachView(view: self)
        if(self.isCaller){
            self.nameCaller.text = "Calling "+room!.name
            self.btAnswer.isHidden = true
            self.btHangUp.setTitle("Cancel", for: .normal)
        }else{
            self.nameCaller.text = "Incoming Call "+room!.name
            self.btAnswer.isHidden = false
            self.btHangUp.isHidden = false
        }
        self.imageCaller.layer.cornerRadius = 100
        self.imageCaller.layer.masksToBounds = true
        self.imageCaller.af_setImage(withURL: room?.avatarUrl! ??  URL(string: "https://hello.jpg")!)
        self.btAnswer.addTarget(self, action: #selector(answerCall), for: .touchUpInside)
        self.btHangUp.addTarget(self, action: #selector(rejectCall), for: .touchUpInside)
        navigationItem.setHidesBackButton(true, animated: true)
        
    }
    
    @objc func rejectCall(){
        if(self.isCaller){
            let message = CommentModel()
            message.message = "Call Canceled"
            message.type = "call"
            message.roomId = self.room!.id
            message.extras = ["status":"reject"]
            presenter.call(message: message)
        }else{
            let message = CommentModel()
            message.message = "Call Rejected"
            message.type = "call"
            message.roomId = self.room!.id
            message.extras = ["status":"reject"]
            presenter.call(message: message)
        }
        self.view.window?.rootViewController?.dismiss(animated: true, completion: nil)
    }
    
    @objc func answerCall(){
        let message = CommentModel()
        message.message = "Call Answered"
        message.type = "call"
        message.roomId = self.room!.id
        message.extras = ["status":"answer"]
        presenter.call(message: message)
    }
    
    
    @objc func calling(){
        self.isCaller = true
        // create object comment
        // MARK: TODO improve object generator
        let message = CommentModel()
        message.message = "Incoming call"
        message.type    = "call"
        message.extras = ["status":"calling"]
        if let r = self.room {
             message.roomId  = r.id
        }
        presenter.call(message: message)
    }
  

    @objc func reSubscribeRoom(_ notification: Notification)
    {
        self.presenter.attachView(view: self)
    }
    
    func refreshUI() {
        if self.isViewLoaded {
            self.presenter.attachView(view: self)
            self.setupUI()
        }
    }
    
}
extension CallVC : UIChatViewDelegate{
    func onLoadRoomFinished(roomName: String, roomAvatarURL: URL?) {
        
    }
    
    func onLoadMessageFinished() {
        
    }
    
    func onLoadMessageFailed(message: String) {
        
    }
    
    func onLoadMoreMesageFinished() {
        
    }
    
    func onReloadComment() {
        
    }
    
    func onSendingComment(comment: CommentModel, newSection: Bool) {
        
    }
    
    func onSendMessageFinished(comment: CommentModel) {
        
    }
    
    func onGotNewComment(newSection: Bool, _message: CommentModel) {
    }
    
    func onUpdateComment(comment: CommentModel, indexpath: IndexPath) {
    }
    
    func onUser(name: String, typing: Bool) {
        
    }
    
    func onUser(name: String, isOnline: Bool, message: String) {
        
    }
}

extension CallVC : QiscusMeetDelegate {
    func conferenceJoined() {
        
    }
    
    func conferenceWillJoin() {
        
    }
    
    func conferenceTerminated() {

        UIApplication.shared.keyWindow!.rootViewController?.dismiss(animated: true, completion: nil)
        
    }
    
    func participantJoined() {
        
    }
    
    func participantLeft() {
    QiscusMeet.endCall()
        UIApplication.shared.keyWindow!.rootViewController?.dismiss(animated: true, completion: nil)
        
    }
    
    
}
