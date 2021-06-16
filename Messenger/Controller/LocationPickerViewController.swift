//
//  LocationPickerViewController.swift
//  Messenger
//
//  Created by user195395 on 6/14/21.
//

import UIKit
import CoreLocation
import MapKit

class LocationPickerViewController: UIViewController {
    private let map : MKMapView = {
        let map = MKMapView()
        
        return map
    }()
    private var coordinates : CLLocationCoordinate2D?
    public var completion: ((CLLocationCoordinate2D) -> Void)?
    private var isPickable = true
    init(coordinates: CLLocationCoordinate2D?) {
        self.coordinates = coordinates
        self.isPickable = coordinates == nil
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Pick Location"
        view.backgroundColor = .systemBackground
        if isPickable {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send",
                                                                style: .done,
                                                                target: self,
                                                                action: #selector(sendButtonTapped))
            map.isUserInteractionEnabled = true
            let gesture = UITapGestureRecognizer(target: self,
                                                 action: #selector(didTapMap(_:)))
            gesture.numberOfTouchesRequired = 1
            gesture.numberOfTapsRequired = 1
            map.addGestureRecognizer(gesture)
        }
        else{
            guard let coordinates = self.coordinates else {
                return
            }
            let pin = MKPointAnnotation()
            pin.coordinate = coordinates
            map.addAnnotation(pin)
        }
        
        
        view.addSubview(map)
    }
    
    @objc func sendButtonTapped(){
        guard let coordinates = coordinates else{
            print("Cant find coordinate")
            return
        }
        navigationController?.popViewController(animated: true)
        completion?(coordinates)
    }
    @objc func didTapMap(_ gesture: UITapGestureRecognizer){
        //get the location of the gesture on the map
        let locationInView = gesture.location(in: map)
        //locate the coordinate
        let coordinates = map.convert(locationInView, toCoordinateFrom: map)
        self.coordinates = coordinates
        //drop a pin
        for annotation in map.annotations{
            map.removeAnnotation(annotation)
        }
        //remove all other pins and keep only the last one
        let pin = MKPointAnnotation()
        //create a pin
        pin.coordinate = coordinates
        //set coordinate of the pin
        map.addAnnotation(pin)
        //draw on map the pin
        
        
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        map.frame = view.bounds
    }
    
    
}
