//
//  GameViewController.swift
//  Planetarium
//
//  Created by Sihao Lu on 8/3/25.
//

import UIKit
import RealityKit
import Combine

class GameViewController: UIViewController {
    private var arView: ARView!
    private var cancellables = Set<AnyCancellable>()
    private var azimuth: Float = 0      // Horizontal rotation (longitude) -π to π
    private var altitude: Float = 0     // Vertical rotation (latitude) -π/2 to π/2
    private var sceneAnchor: AnchorEntity?
    private var cameraEntity: Entity?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set view background
        view.backgroundColor = .black
        
        // Create ARView
        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arView)
        
        // Configure the ARView
        setupARView()
        
        // Load and display the Scene.usdz
        Task { @MainActor in
            try await loadScene()
        }
    }
    
    private func setupARView() {
        // Disable AR features and use it as a 3D viewer
        arView.automaticallyConfigureSession = false
        
        // Set camera position at origin with non-AR mode
        arView.cameraMode = .nonAR
        
        // Create an entity to hold the camera component
        let cameraEntity = Entity()
        var component = PerspectiveCameraComponent()
        component.fieldOfViewInDegrees = 90
        // Create an orthographic camera component and add it to the camera entity
        cameraEntity.components.set(component)
        
        // Store reference to camera entity
        self.cameraEntity = cameraEntity
        
        // Add camera to scene
        let cameraAnchor = AnchorEntity(world: .zero)
        cameraAnchor.addChild(cameraEntity)
        arView.scene.addAnchor(cameraAnchor)
        
        // Configure environment
        arView.environment.background = .color(.black)
        
        // Add pan gesture for rotation (but not translation)
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        arView.addGestureRecognizer(panGesture)
    }
    
    private func loadScene() async throws {
        // Load the Scene.usdz file
        guard let sceneURL = Bundle.main.url(forResource: "Scene", withExtension: "usdz") else {
            print("Could not find Scene.usdz in bundle")
            return
        }
        
        // Load the scene asynchronously
        let entity = try await Entity(contentsOf: sceneURL, withName: nil)
        
        // Add the loaded scene to the anchor at origin
        let anchor = AnchorEntity(world: [0, 0, 0])
        anchor.addChild(entity)
        
        // Add directional markers for debugging
        addDirectionalMarkers(to: anchor)
        
        self.arView.scene.addAnchor(anchor)
        self.sceneAnchor = anchor
    }
    
    private func addDirectionalMarkers(to anchor: AnchorEntity) {
        let markerRadius: Float = 5.0  // Distance from center
        
        // Create simple sphere markers
        let markerMesh = MeshResource.generateSphere(radius: 0.1)
        
        // North (positive Y) - Blue
        let northMaterial = SimpleMaterial(color: .blue, isMetallic: false)
        let northMarker = ModelEntity(mesh: markerMesh, materials: [northMaterial])
        northMarker.position = SIMD3<Float>(0, markerRadius, 0)
        anchor.addChild(northMarker)
        
        // South (negative Y) - Red
        let southMaterial = SimpleMaterial(color: .red, isMetallic: false)
        let southMarker = ModelEntity(mesh: markerMesh, materials: [southMaterial])
        southMarker.position = SIMD3<Float>(0, -markerRadius, 0)
        anchor.addChild(southMarker)
        
        // East (positive X) - Green
        let eastMaterial = SimpleMaterial(color: .green, isMetallic: false)
        let eastMarker = ModelEntity(mesh: markerMesh, materials: [eastMaterial])
        eastMarker.position = SIMD3<Float>(markerRadius, 0, 0)
        anchor.addChild(eastMarker)
        
        // West (negative X) - Yellow
        let westMaterial = SimpleMaterial(color: .yellow, isMetallic: false)
        let westMarker = ModelEntity(mesh: markerMesh, materials: [westMaterial])
        westMarker.position = SIMD3<Float>(-markerRadius, 0, 0)
        anchor.addChild(westMarker)
        
        // Zenith (positive Z) - White
        let zenithMaterial = SimpleMaterial(color: .white, isMetallic: false)
        let zenithMarker = ModelEntity(mesh: markerMesh, materials: [zenithMaterial])
        zenithMarker.position = SIMD3<Float>(0, 0, markerRadius)
        anchor.addChild(zenithMarker)
        
        // Nadir (negative Z) - Black with emissive
        let nadirMaterial = SimpleMaterial(color: .black, isMetallic: false)
        let nadirMarker = ModelEntity(mesh: markerMesh, materials: [nadirMaterial])
        nadirMarker.position = SIMD3<Float>(0, 0, -markerRadius)
        anchor.addChild(nadirMarker)
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let cameraEntity = cameraEntity else { return }
        
        let translation = gesture.translation(in: arView)
        
        // Convert pan to rotation - adjust sensitivity
        let deltaX = Float(translation.x) * 0.002
        let deltaY = Float(translation.y) * 0.002
        
        switch gesture.state {
        case .changed:
            // Update azimuth (horizontal pan = rotate around Y axis)
            azimuth += deltaX
            
            // Keep azimuth in -π to π range for consistency
            if azimuth > Float.pi {
                azimuth -= 2 * Float.pi
            } else if azimuth < -Float.pi {
                azimuth += 2 * Float.pi
            }
            
            // Update altitude (vertical pan = rotate around X axis)
            altitude += deltaY
            
            // Clamp altitude to prevent flipping over poles
            altitude = max(-Float.pi/2, min(Float.pi/2, altitude))
            
            // Create camera rotation using standard spherical coordinates
            // Azimuth rotates around Y (up/down) axis
            // Altitude rotates around X (left/right) axis
            
            // Create individual rotations
            let azimuthRotation = simd_quatf(angle: azimuth, axis: SIMD3<Float>(0, 1, 0))
            let altitudeRotation = simd_quatf(angle: altitude, axis: SIMD3<Float>(1, 0, 0))
            
            // Apply rotations in order: azimuth first, then altitude
            // This ensures the camera always stays level with latitude lines
            let cameraRotation = azimuthRotation * altitudeRotation
            
            // Apply rotation to the camera entity
            cameraEntity.transform.rotation = cameraRotation
            
        default:
            break
        }
        
        gesture.setTranslation(.zero, in: arView)
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

}
