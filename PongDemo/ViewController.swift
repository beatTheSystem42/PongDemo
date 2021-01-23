//
//  ViewController.swift
//  PongDemo
//
//  Created by Quentin Reiser on 1/21/21.
//

import UIKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate {

    var config: ARWorldTrackingConfiguration!
    var sceneView: ARSCNView!
    
    var label: UILabel!
    
    var cupNode: SCNNode!
    var center: CGPoint!
    var canPlace = false
    var waterNode: SCNNode!
    
    // 0 = placing cup
    // 1 = ready to throw ball
    // 2 = ball thrown
    // 3 = sunk it
    var state = 0
    var tStart: CGFloat!
    var pBall: SCNNode!
    var planes: [ARPlaneAnchor] = []
    
    struct PhysicsCategory {
        static let ball = 1
        static let cup = 2
        static let water = 4
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        setup()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        switch state {
        case 1:
            // start point to calculate ball velocity
            // also a point where you could start keeping frames to make a shot clip if you sink it
            tStart = touches.first?.location(in: self.view).y
            label.alpha = 0
        default:
            break
        }
    }
    
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        switch state {
        case 0:
            // place cup, making sure it's on a plane
            if !canPlace {
                label.text = "place on surface"
                return
            } else {
                state = 1
                cupNode.opacity = 1.0
                sceneView.scene.rootNode.addChildNode(pBall)
                label.text = "touch and drag"
            }
        case 1:
            // throw ball
            let tEnd = touches.first?.location(in: self.view).y
            let force = Float(abs(tStart - tEnd!) / 100)
            
            let lDir = SCNVector3Make(0, force * 3.0, -force * 2.0)
            let direction = sceneView.pointOfView!.convertVector(lDir, to: nil)
            
            pBall.physicsBody?.isAffectedByGravity = true
            pBall.physicsBody?.applyForce(direction, asImpulse: true)
            state = 2
            
        case 2:
            // new ball
            pBall.physicsBody?.velocity = SCNVector3(0, 0, 0)
            pBall.physicsBody?.isAffectedByGravity = false
            state = 1
        case 3:
            // restart the game
            state = 0
            cupNode.opacity = 0.88
            pBall.removeFromParentNode()
            label.alpha = 0
        default:
            break
        }
    }
    
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        switch state {
        case 0:
            // previewing cup placement
            let loc = CGPoint(x: center.x, y: center.y)
            let hitTest = sceneView.hitTest(loc, types: .existingPlaneUsingExtent)
                    
            if hitTest.isEmpty {
                let localPos = SCNVector3Make(0, 0, -1)
                let pos = sceneView.pointOfView!.convertPosition(localPos, to: nil)
                cupNode.position = pos
                waterNode.position = SCNVector3(0, 0.24, 0)
                canPlace = false
                return
            } else {
                let columns = hitTest.first?.worldTransform.columns.3
                cupNode.position = SCNVector3(x: columns!.x, y: columns!.y, z: columns!.z)
                waterNode.position = SCNVector3(0, 0.24, 0)
                canPlace = true
            }
        case 1:
            // ready to throw ball
            let localPos = SCNVector3Make(0, 0, -0.5)
            let pos = sceneView.pointOfView!.convertPosition(localPos, to: nil)
            pBall.position = pos
        default:
            break
        }
    }
    
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
            
        let width = CGFloat(planeAnchor.extent.x)
        let height = CGFloat(planeAnchor.extent.z)
        let plane = SCNPlane(width: width, height: height)
        
        let planeNode = SCNNode(geometry: plane)
        
        let x = CGFloat(planeAnchor.center.x)
        let y = CGFloat(planeAnchor.center.y)
        let z = CGFloat(planeAnchor.center.z)
        planeNode.position = SCNVector3(x,y,z)
        planeNode.eulerAngles.x = -.pi / 2
    }
    
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
        // only update planes if you're looking to place the cup
        if state == 0 {
            guard let planeAnchor = anchor as?  ARPlaneAnchor,
                let planeNode = node.childNodes.first,
                let plane = planeNode.geometry as? SCNPlane
                else { return }
             
            
            let width = CGFloat(planeAnchor.extent.x)
            let height = CGFloat(planeAnchor.extent.z)
            plane.width = width
            plane.height = height
             
            let x = CGFloat(planeAnchor.center.x)
            let y = CGFloat(planeAnchor.center.y)
            let z = CGFloat(planeAnchor.center.z)
            planeNode.position = SCNVector3(x,y,z)
        }
    }
    
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        
        var nodeA = contact.nodeA.physicsBody!
        var nodeB = contact.nodeB.physicsBody!
        
        if nodeA.categoryBitMask > nodeB.categoryBitMask {
            nodeA = contact.nodeB.physicsBody!
            nodeB = contact.nodeA.physicsBody!
        }
        
        
        // check if the contact is between the ball and the water
        // check if you've actually thrown the ball
        if nodeA.categoryBitMask == PhysicsCategory.ball  {
            if nodeB.categoryBitMask == PhysicsCategory.water && state == 2 {
                DispatchQueue.main.async {
                    self.label.alpha = 1.0
                    self.label.text = "sunk it"
                }
                state = 3
                pBall.physicsBody?.velocity = SCNVector3(0, 0, 0)
                pBall.physicsBody?.isAffectedByGravity = false
                pBall.position = cupNode.convertPosition(waterNode.position, to: sceneView.scene.rootNode)
            }
        }
    }
    
    
    
    func setup() {
        
        sceneView = ARSCNView(frame: view.frame)
        view.addSubview(sceneView)
        //arView.automaticallyConfigureSession = false
        config = ARWorldTrackingConfiguration()
        
        config.planeDetection = [.horizontal]
        sceneView.autoenablesDefaultLighting = true
        sceneView.session.run(config, options: [])
        sceneView.delegate = self
        sceneView.scene.physicsWorld.contactDelegate = self
        
        let lWidth = view.frame.width * 0.52
        let lHeight = lWidth * 0.24
        let lX = view.frame.width * 0.5 - (lWidth / 2)
        let lY = view.frame.height * 0.18
        let lRect = CGRect(x: lX, y: lY, width: lWidth, height: lHeight)
        label = UILabel(frame: lRect)
        label.layer.cornerRadius = lHeight / 2
        label.clipsToBounds = true
        label.backgroundColor = UIColor.darkGray.withAlphaComponent(0.8)
        label.textColor = UIColor.lightGray
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 20)
        label.text = "tap to place cup"
        view.addSubview(label)
        
        // where cupNode hit test starts
        center = CGPoint(x: view.frame.width / 2, y: view.frame.height * 0.58)
        
        let cupScene = SCNScene(named: "cup.scnassets/RedSoloCup.scn")
        cupNode = cupScene?.rootNode.childNode(withName: "redCup", recursively: false)
        cupNode.opacity = 0.88
        cupNode.scale = SCNVector3(0.44, 0.48, 0.44)
        cupNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        cupNode.physicsBody?.isAffectedByGravity = false
        cupNode.physicsBody?.restitution = 1.0
        cupNode.physicsBody?.mass = 1000
        cupNode.physicsBody?.categoryBitMask = PhysicsCategory.cup
        cupNode.physicsBody?.contactTestBitMask = PhysicsCategory.ball
        cupNode.physicsBody?.collisionBitMask = 0
        sceneView.scene.rootNode.addChildNode(cupNode)
        
        let cHeight = CGFloat(cupNode.boundingBox.max.y - cupNode.boundingBox.min.y)
        let cWidth = CGFloat(cupNode.boundingBox.max.x - cupNode.boundingBox.min.x)
        
        let bGeom = SCNSphere(radius: 0.02)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.white
        bGeom.materials = [mat]
        pBall = SCNNode(geometry: bGeom)
        pBall.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        pBall.physicsBody?.isAffectedByGravity = false
        pBall.physicsBody?.restitution = 1.2
        pBall.physicsBody?.continuousCollisionDetectionThreshold = 0.04
        pBall.physicsBody?.categoryBitMask = PhysicsCategory.ball
        pBall.physicsBody?.contactTestBitMask = PhysicsCategory.water | PhysicsCategory.cup
        
        // water fill layer
        let cGeom = SCNCylinder(radius: cWidth * 0.38, height: cHeight * 0.1)
        let cMat = SCNMaterial()
        cMat.diffuse.contents = UIColor(red: 171/255, green: 207/255, blue: 247/255, alpha: 0.8)
        cGeom.materials = [cMat]
        waterNode = SCNNode(geometry: cGeom)
        waterNode.position = SCNVector3(0, 0.24, 0)
        waterNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        waterNode.physicsBody?.isAffectedByGravity = false
        waterNode.physicsBody?.categoryBitMask = PhysicsCategory.water
        waterNode.physicsBody?.contactTestBitMask = PhysicsCategory.ball
        waterNode.physicsBody?.collisionBitMask = 0
        cupNode.addChildNode(waterNode)
    }
}

