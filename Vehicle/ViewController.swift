//
//  ViewController.swift
//  Vehicle
//
//  Created by Marko Jovanov on 1.9.21.
//

import UIKit
import SceneKit
import ARKit
import CoreMotion

class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    let motionMenager = CMMotionManager()
    var vehicle = SCNPhysicsVehicle()
    var orientation: CGFloat = 0
    var touched: Int = 0
    var accelerationValues = [UIAccelerationValue(0),UIAccelerationValue(0)].self
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        setUpAccelerometer()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    func createConcrete(planeAnchor: ARPlaneAnchor) -> SCNNode {
        let concreteNode = SCNNode(geometry: SCNPlane(width: CGFloat(planeAnchor.extent.x),
                                                      height: CGFloat(planeAnchor.extent.z)))
        concreteNode.geometry?.firstMaterial?.diffuse.contents = UIImage(named: "concrete")
        concreteNode.geometry?.firstMaterial?.isDoubleSided = true
        concreteNode.position = SCNVector3(
            planeAnchor.center.x,
            planeAnchor.center.y,
            planeAnchor.center.z)
        concreteNode.eulerAngles.x = -.pi / 2
        let staticBody = SCNPhysicsBody.static()
        concreteNode.physicsBody = staticBody
        return concreteNode
    }
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        let concreteNode = createConcrete(planeAnchor: planeAnchor)
        node.addChildNode(concreteNode)
    }
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        node.enumerateChildNodes { childNode, _ in
            childNode.removeFromParentNode()
        }
        let concreteNode = createConcrete(planeAnchor: planeAnchor)
        node.addChildNode(concreteNode)
    }
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let _ = anchor as? ARPlaneAnchor else { return }
        node.enumerateChildNodes { childNode, _ in
            childNode.removeFromParentNode()
        }
    }
    @IBAction func addCar(_ sender: UIButton) {
        guard let pointOfView = sceneView.pointOfView else { return }
        let transform = pointOfView.transform
        let orientation = SCNVector3(-transform.m31,
                                     -transform.m32,
                                     -transform.m33)
        let location = SCNVector3(transform.m41,transform.m42,transform.m43)
        let currentPositionOfCamera = orientation + location
        let scene = SCNScene(named: "car-scene.scn")
        let chassis = (scene?.rootNode.childNode(withName: "chassis", recursively: false))!
        let frontLeftWheel = chassis.childNode(withName: "frontLeftParent", recursively: false)
        let frontRightWheel = chassis.childNode(withName: "frontRightParent", recursively: false)
        let rearLeftWheel = chassis.childNode(withName: "rearLeftParent", recursively: false)
        let rearRightWheel = chassis.childNode(withName: "rearRightParent", recursively: false)
        let v_frontLeftWheel = SCNPhysicsVehicleWheel(node: frontLeftWheel!)
        let v_frontRightWheel = SCNPhysicsVehicleWheel(node: frontRightWheel!)
        let v_rearRightWheel = SCNPhysicsVehicleWheel(node: rearRightWheel!)
        let v_rearLeftWheel = SCNPhysicsVehicleWheel(node: rearLeftWheel!)
        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: chassis, options: [SCNPhysicsShape.Option.keepAsCompound: true]))
        body.mass = 5
        chassis.physicsBody = body
        chassis.position = currentPositionOfCamera
        vehicle = SCNPhysicsVehicle(chassisBody: chassis.physicsBody!, wheels: [v_rearLeftWheel,v_rearRightWheel,v_frontRightWheel,v_frontLeftWheel])
        sceneView.scene.physicsWorld.addBehavior(vehicle)
        sceneView.scene.rootNode.addChildNode(chassis)
    }
    func setUpAccelerometer() {
        if motionMenager.isAccelerometerAvailable {
            motionMenager.accelerometerUpdateInterval = 1/60
            motionMenager.startAccelerometerUpdates(to: .main) { accelerometerData, error in
                if let error = error {
                    print(error.localizedDescription)
                    return
                }
                if let acceleration = accelerometerData?.acceleration {
                    self.accelerometerDidChange(acceleration: acceleration)
                }
                
            }
        } else {
            print("not availvaible")
        }
    }
    
    func accelerometerDidChange(acceleration : CMAcceleration) {
        accelerationValues[1] = filtered(currentAcceleration: accelerationValues[1], updatedAcceleration: acceleration.y)
        accelerationValues[0] = filtered(currentAcceleration: accelerationValues[0], updatedAcceleration: acceleration.x)
        if accelerationValues[0] > 0 {
            orientation = -CGFloat(accelerationValues[1])
        } else {
            orientation = CGFloat(accelerationValues[1])
        }
        
    }
    func renderer(_ renderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) {
        var engineForce: CGFloat = 0
        var brakingForce: CGFloat = 0
        vehicle.setSteeringAngle(-orientation, forWheelAt: 2)
        vehicle.setSteeringAngle(-orientation, forWheelAt: 3)
        if touched == 1 {
            engineForce = 50
        } else if touched == 2 {
            engineForce = -50
        } else if touched == 3 {
            brakingForce = 100
        }
        vehicle.applyEngineForce(engineForce, forWheelAt: 0)
        vehicle.applyEngineForce(engineForce, forWheelAt: 1)
        vehicle.applyBrakingForce(brakingForce, forWheelAt: 0)
        vehicle.applyBrakingForce(brakingForce, forWheelAt: 1)
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let _ = touches.first else { return }
        touched += touches.count
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touched = 0
    }
    func filtered(currentAcceleration: Double, updatedAcceleration: Double) -> Double {
        let kFilteringFactor = 0.5
        return updatedAcceleration * kFilteringFactor + currentAcceleration * (1 - kFilteringFactor)
    }
}
func +(left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x + right.x, left.y + right.y, left.z + right.z)
}
