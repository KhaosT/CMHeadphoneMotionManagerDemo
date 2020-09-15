//
//  ViewController.swift
//  AudioExp
//
//  Created by Khaos Tian on 9/2/20.
//

import UIKit
import SceneKit
import CoreMotion
import Combine

class ViewController: UIViewController, CMHeadphoneMotionManagerDelegate {

    private lazy var sceneView = SCNView()
    private lazy var motionManager = CMHeadphoneMotionManager()

    private var cancellables: Set<AnyCancellable> = []

    private var isUpdating = false

    private var audioSource: SCNAudioSource?
    private var target: SCNNode?
    private var cameraNode: SCNNode?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()

        NSLog("Motion Available: \(motionManager.isDeviceMotionAvailable)")

        motionManager.delegate = self

        NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.startMotionUpdate()
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.stopMotionUpdate()
            }
            .store(in: &cancellables)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startMotionUpdate()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopMotionUpdate()
    }

    private func startMotionUpdate() {
        guard motionManager.isDeviceMotionAvailable,
              !isUpdating else {
            return
        }
        NSLog("Start Motion Update")
        isUpdating = true
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
            if let error = error {
                NSLog("\(error)")
            }

            if let motion = motion {
                self?.updateTargetWithMotion(motion)
            }
        }
    }

    private func stopMotionUpdate() {
        guard motionManager.isDeviceMotionAvailable,
              isUpdating else {
            return
        }
        NSLog("Stop Motion Update")
        isUpdating = false
        motionManager.stopDeviceMotionUpdates()
    }

    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        NSLog("Motion Manager Did Connect")
    }

    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        NSLog("Motion Manager Did Disconnect")
    }

    private func updateTargetWithMotion(_ motion: CMDeviceMotion) {
        guard let target = target else {
            return
        }

        let attitude = motion.attitude
        target.eulerAngles = SCNVector3(attitude.pitch, attitude.yaw, -attitude.roll)
    }

    // MARK: - Setup

    private func setupView() {
        view.backgroundColor = .black

        view.addSubview(sceneView)
        sceneView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate(
            [
                sceneView.topAnchor.constraint(equalTo: view.topAnchor),
                sceneView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                sceneView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                sceneView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ]
        )

        // create a new scene
        let scene = SCNScene(named: "art.scnassets/canvas.scn")!

        let box = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
        let target = SCNNode(geometry: box)
        scene.rootNode.addChildNode(target)
        target.position = SCNVector3(0, 0, 0)
        self.target = target

        // sound
        let sphere = SCNSphere(radius: 1)
        let soundNode = SCNNode(geometry: sphere)
        scene.rootNode.addChildNode(soundNode)
        soundNode.position = SCNVector3(0, 0, -5)

        let source = SCNAudioSource(fileNamed: "audio.m4a")!
        source.loops = true
        source.load()
        self.audioSource = source

        // create and add a camera to the scene
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)
        self.cameraNode = cameraNode

        // place the camera
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 15)

        // create and add a light to the scene
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .omni
        lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
        scene.rootNode.addChildNode(lightNode)

        // create and add an ambient light to the scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = .ambient
        ambientLightNode.light!.color = UIColor.darkGray
        scene.rootNode.addChildNode(ambientLightNode)

        // set the scene to the view
        sceneView.scene = scene

        // allows the user to manipulate the camera
        sceneView.allowsCameraControl = true

        // show statistics such as fps and timing information
        sceneView.showsStatistics = true

        // configure the view
        sceneView.backgroundColor = UIColor.black

        sceneView.audioListener = target
        soundNode.addAudioPlayer(SCNAudioPlayer(source: source))

        // add a tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
    }

    @objc
    func handleTap(_ gestureRecognize: UIGestureRecognizer) {
        // check what nodes are tapped
        let p = gestureRecognize.location(in: sceneView)
        let hitResults = sceneView.hitTest(p, options: [:])
        // check that we clicked on at least one object
        if hitResults.count > 0 {
            // retrieved the first clicked object
            let result = hitResults[0]

            // get its material
            let material = result.node.geometry!.firstMaterial!

            // highlight it
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5

            // on completion - unhighlight
            SCNTransaction.completionBlock = {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.5

                material.emission.contents = UIColor.black

                SCNTransaction.commit()
            }

            material.emission.contents = UIColor.red

            SCNTransaction.commit()
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }
}
