//
//  ViewController.swift
//  FoodRecognizer
//
//  Created by Giuseppe Ferrara on 25/03/2020.
//  Copyright © 2020 Giuseppe Ferrara. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit
import Vision

enum HandGesture: String {
    case rock = "rock"
    case paper = "paper"
    case scissors = "scissors"
    case none = "none"
}


class ViewController: UIViewController {
    
    // MARK: Camera
    let captureSession = AVCaptureSession()
    var captureDevice: AVCaptureDevice!
    var devicePosition: AVCaptureDevice.Position = .back
    
    // MARK: Vision
    var requests = [VNRequest]()
    let bufferSize = 5
    var gestureBuffer = [HandGesture]()
    var currentGesture: HandGesture = .none {
        didSet {
            gestureBuffer.append(currentGesture)
            if gestureBuffer.count == bufferSize {
                if gestureBuffer.filter({$0 == currentGesture}).count == bufferSize {
                    //send command
                    showAndSendGesture(currentGesture)
                }
                gestureBuffer.removeAll()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        setupVision()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        prepareCamera()
    }
    
    func setupVision() {
        guard let visionModel = try? VNCoreMLModel(for: Food101().model) else {
            fatalError("Can't load vision model")
        }
        let classificationRequest = VNCoreMLRequest(model: visionModel, completionHandler: self.handleClassification(request:error:))
        classificationRequest.imageCropAndScaleOption = .centerCrop
        
        self.requests = [classificationRequest]
    }
    
    func handleClassification(request: VNRequest, error: Error?) {
        guard let observations = request.results else {
            print("no results")
            return
        }
        
        let classifications = observations
            .compactMap({$0 as? VNClassificationObservation})
            .filter({$0.confidence > 0.5})
            .map({$0.identifier})
        print("classifications: \(classifications)")
        
    }
    
    func showAndSendGesture(_ currentGesture: HandGesture){
        DispatchQueue.main.async {
            
        }
    }
    
    
}




extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func prepareCamera() {
        let availableDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: devicePosition).devices
        captureDevice = availableDevices.first
        beginSession()
    }
    
    
    func beginSession() {
        do {
            let captureDeviceInput = try AVCaptureDeviceInput(device: captureDevice)
            captureSession.addInput(captureDeviceInput)
        } catch let error {
            print(error)
        }
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .hd1920x1080
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        dataOutput.alwaysDiscardsLateVideoFrames = true
        
        if captureSession.canAddOutput(dataOutput) {
            captureSession.addOutput(dataOutput)
        }
        
        captureSession.commitConfiguration()
        
        let queue = DispatchQueue(label: "captureQueue")
        dataOutput.setSampleBufferDelegate(self, queue: queue)
        
        captureSession.startRunning()
        
    }
    
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let exifOrientation = self.exifOrientationFromDeviceOrientation()
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: [:])
        
        do {
            try imageRequestHandler.perform(self.requests)
        } catch let error {
            print(error)
        }
        
    }
    
    func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
        let curDeviceOrientation = UIDevice.current.orientation
        let exifOrientation: CGImagePropertyOrientation
        
        switch curDeviceOrientation {
        case .unknown:
            exifOrientation = .down
        case .portrait:
            exifOrientation = .up
        case .portraitUpsideDown:
            exifOrientation = .down
        case .landscapeLeft:
            exifOrientation = .left
        case .landscapeRight:
            exifOrientation = .right
        case .faceUp:
            exifOrientation = .up
        case .faceDown:
            exifOrientation = .up
        @unknown default:
            exifOrientation = .up
        }
        
        return exifOrientation
    }
    
}

