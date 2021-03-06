//
//  InterfaceController.swift
//  yourtimewatch Extension
//
//  Created by Kensaku Tanaka on 2018/07/06.
//  Copyright © 2018年 Kensaku Tanaka. All rights reserved.
//

import WatchKit
import Foundation
import WatchConnectivity


class InterfaceController: WKInterfaceController, WCSessionDelegate {
    var active = false
    var clocks: [Clock] = Clock.defaultClocks() {
        didSet {
            if self.clocks.count == 0 {
                self.clocks = Clock.defaultClocks()
            }
        }
    }
    var _index = 0
    var index: Int {
        get {
            if self._index >= clocks.count {
                self._index = 0
            }
            return self._index
        }
        set {
            if newValue >= clocks.count {
                self._index = 0
            } else {
                self._index = newValue
            }
            UserDefaults.standard.set(self._index, forKey: "index")
        }
    }
    var isBlackBackground: Bool = UserDefaults.standard.bool(forKey: "isBlackBackground")
    var backgroundColor: UIColor {
        return isBlackBackground ? .black : .white
    }
    var foregroundColor: UIColor {
        return isBlackBackground ? .white : .black
    }
    
    var centerX: CGFloat = 0.0
    var centerY: CGFloat = 0.0
    var radius: CGFloat = 0.0
    var dx: CGFloat = 0.0
    
    var animateLeft: Bool = false
    var animateRight: Bool = false
    var fadeout: Bool = true
    
    @IBOutlet var image: WKInterfaceImage!
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            if session.isReachable {
                self.send(session)
            }
        }
        let manager = FileManager.default
        if let dir = manager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let filePath = dir.appendingPathComponent("clocks.txt")
            self.clocks = self.parse(url: filePath)
        }
        self.index = UserDefaults.standard.integer(forKey: "index")
    }
    
    func send(_ session: WCSession) {
        session.sendMessage([:], replyHandler: nil, errorHandler: {(error) in
            if session.isReachable {
                self.send(session)
            }
        })
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        if WCSession.isSupported() {
            let session = WCSession.default
            if session.isReachable {
                self.send(session)
            }
        }
        centerX = self.contentFrame.width / 2
        centerY = self.contentFrame.height / 2
        radius = min(centerX,centerY)
        dx = radius / 10
        active = true
        self.draw()
        self.animation()
    }
    
    func draw() {
        guard index >= 0 && index < clocks.count else {
            index = 0
            UserDefaults.standard.set(self.index, forKey: "index")
            return
        }
        UIGraphicsBeginImageContext(self.contentFrame.size)
        if let context : CGContext = UIGraphicsGetCurrentContext() {
            context.setFillColor(backgroundColor.cgColor)
            context.fill(CGRect(x: 0,
                                y: 0,
                                width: self.contentFrame.width,
                                height: self.contentFrame.height))
            let now = clocks[index].calc(time: Date().millisecond())
            let hourUnitAngle = Clock.unitAngle(totalNum: clocks[index].hours)
            let hourRadian = clocks[index].sig * now.hour * hourUnitAngle
            let hourRatio = CGFloat(0.3)
            drawNeedle(width: CGFloat(3.0), ratio: hourRatio, radian: hourRadian, context: context)
            let minuteUnitAngle = Clock.unitAngle(totalNum: clocks[index].minutes)
            let minuteRadian = clocks[index].sig * Double(now.minute) * minuteUnitAngle
            let minuteRatio = CGFloat(0.5)
            drawNeedle(width: CGFloat(1.5), ratio: minuteRatio, radian: minuteRadian, context: context)
            let secondUnitAngle = Clock.unitAngle(totalNum: clocks[index].seconds)
            let secondRadian = clocks[index].sig * Double(now.second) * secondUnitAngle
            let secondRatio = CGFloat(0.8)
            drawNeedle(width: CGFloat(0.8), ratio: secondRatio, radian: secondRadian, context: context)
            self.setTitle(clocks[index].name)
            drawDial()
            if let cgImage:CGImage = context.makeImage() {
                let uiImage = UIImage(cgImage: cgImage)
                UIGraphicsEndImageContext()
                self.image.setImage(uiImage)
            }
        }
    }
    
    func drawDial() {
        guard index >= 0 && index < clocks.count else {
            index = 0
            UserDefaults.standard.set(self.index, forKey: "index")
            return
        }
        let whratio = self.contentFrame.width / self.contentFrame.height
        let fontSize = CGFloat(10)
        let attributes: [NSAttributedString.Key : AnyObject] = [
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: foregroundColor
        ]
        let ratio = CGFloat(0.9)
        let angle = clocks[index].sig * Clock.unitAngle(totalNum: clocks[index].hours)
        let range = clocks[index].dialFromOne ? 1...clocks[index].hours : 0...(clocks[index].hours-1)
        for i in range {
            let x = centerX + whratio * radius * ratio * CGFloat(sin(Double(i) * angle)) - fontSize/2
            let y = centerY - radius * ratio * CGFloat(cos(Double(i) * angle)) - fontSize/2
            NSAttributedString(string: "\(i)", attributes:attributes).draw(at: CGPoint(x:x,y:y))
        }
    }
    
    func drawNeedle(width: CGFloat, ratio: CGFloat, radian: Double, context: CGContext) {
        let whratio = self.contentFrame.width / self.contentFrame.height
        context.setStrokeColor(foregroundColor.cgColor)
        context.move(to: CGPoint(x:centerX,y:centerY))
        context.setLineWidth(width)
        let dx = radius * ratio * CGFloat(sin(radian))
        let dy = -radius * ratio * CGFloat(cos(radian))
        context.addLine(to: CGPoint(x: centerX + whratio*dx, y: centerY+dy))
        context.strokePath()
    }
    
    func animation() {
        if !active {
            return
        }
        self.animate(withDuration: 0.1, animations: {
            if self.animateRight {
                if self.fadeout {
                    if self.centerX >= 1.5 * self.contentFrame.width {
                        self.index -= 1
                        UserDefaults.standard.set(self.index, forKey: "index")
                        self.centerX = -0.5 * self.contentFrame.width
                        self.fadeout = false
                    } else {
                        self.centerX += self.dx
                    }
                } else {
                    if self.centerX >= 0.5 * self.contentFrame.width {
                        self.animateRight = false
                        self.fadeout = true
                        self.centerX = 0.5 * self.contentFrame.width
                    } else {
                        self.centerX += self.dx
                    }
                }
            }
            if self.animateLeft {
                if self.fadeout {
                    if self.centerX <= -0.5 * self.contentFrame.width {
                        self.index += 1
                        UserDefaults.standard.set(self.index, forKey: "index")
                        self.centerX = 1.5 * self.contentFrame.width
                        self.fadeout = false
                    } else {
                        self.centerX -= self.dx
                    }
                } else {
                    if self.centerX <= 0.5 * self.contentFrame.width {
                        self.animateLeft = false
                        self.fadeout = true
                        self.centerX = 0.5 * self.contentFrame.width
                    } else {
                        self.centerX -= self.dx
                    }
                }
            }
            self.draw()
            self.animation()
        })
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
        active = false
    }
    
    // MARK: - WCSession delegate methods
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }
    
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let manager = FileManager.default
        if let dir = manager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let filePath = dir.appendingPathComponent("clocks.txt")
            do {
                try? manager.removeItem(at: filePath)
                try manager.moveItem(at: file.fileURL, to: filePath)
                print("write file")
            } catch {
                print("cant write file")
            }
            self.clocks = self.parse(url: filePath)
        }
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        if let val = userInfo["remove"] {
            let removedIndex = val as! Int
            if index > removedIndex {
                index -= 1
            } else if index == removedIndex {
                index = 0
            }
        }
        if
            let fromVal = userInfo["from"],
            let toVal = userInfo["to"] {
            let fromIndex = fromVal as! Int
            let toIndex = toVal as! Int
            if index == fromIndex {
                index = toIndex
            } else if (fromIndex - index) * (toIndex - index) < 0 {
                if fromIndex < toIndex {
                    index -= 1
                } else {
                    index += 1
                }
            }
        }
        
    }
    
    func parse(url: URL) -> [Clock] {
        do {
            var result : [Clock] = []
            let text = try String(contentsOf: url, encoding: String.Encoding.utf8)
            print(text)
            let lines = text.components(separatedBy: "\n")
            let data = lines[0..<(lines.count-1)].map {
                str in return str.components(separatedBy: "\t")
            }
            
            for var datum in data {
                if
                    let ampmValue = Int(datum[1]),
                    let ampm = Ampm(rawValue: ampmValue),
                    let hours = Int(datum[2]),
                    let minutes = Int(datum[3]),
                    let seconds = Int(datum[4]),
                    let dialFromOne = Bool(datum[5]),
                    let clockwise = Bool(datum[6]) {
                    result.append(Clock(name: datum[0],
                                        ampm: ampm,
                                        hours: hours,
                                        minutes: minutes,
                                        seconds: seconds,
                                        dialFromOne: dialFromOne,
                                        clockwise: clockwise))
                }
            }
            print("parse file")
            return result
        } catch {
            print("cant parse file")
            return Clock.defaultClocks()
        }
    }
    
    @IBAction func onSwipeRight(_ sender: Any) {
        if self.index > 0 && !animateLeft && !animateRight {
            animateRight = true
        }
    }
    
    @IBAction func onSwipeLeft(_ sender: Any) {
        if self.index < self.clocks.count - 1 && !animateLeft && !animateRight {
            animateLeft = true
        }
    }
    
    @IBAction func onDobleTap(_ sender: Any) {
        isBlackBackground = !isBlackBackground
        UserDefaults.standard.set(isBlackBackground, forKey: "isBlackBackground")
    }
}
