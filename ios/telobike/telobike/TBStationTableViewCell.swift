//
//  TBStationTableViewCell.swift
//  telobike
//
//  Created by Amit Attias on 10/15/14.
//  Copyright (c) 2014 Elad Ben-Israel. All rights reserved.
//

import UIKit
import CoreLocation

let STATION_CELL_REUSE_IDENTIFIER: String = "STATION_CELL"

class TBStationTableViewCell: UITableViewCell, CLLocationManagerDelegate  {

    // public
    var station: TBStation! {
        didSet {
            self.availabilityView.station = station
            self.stationNameLabel.text = station.stationName
            self.availabilityIndicatorView.fillColor = station.indicatorColor
            
            self.locationManager(self.locationManager, didUpdateLocations: nil)
        }
    }

    // private
    @IBOutlet private var availabilityIndicatorView: TBTintedView!
    @IBOutlet private var availabilityView: TBAvailabilityView!
    @IBOutlet private var subtitleLabel: UILabel!
    @IBOutlet private var stationNameLabel: UILabel!
    private var locationManager: CLLocationManager!
    private var distanceFormatter: MKDistanceFormatter!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        self.locationManager = CLLocationManager()
        self.locationManager.requestWhenInUseAuthorization()
        self.locationManager.startUpdatingLocation()
        self.locationManager.delegate = self;
        
        self.distanceFormatter = MKDistanceFormatter()
        
        self.distanceFormatter.units = .Metric;
        self.distanceFormatter.unitStyle = .Abbreviated;
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.subtitleLabel.hidden = true
    }

    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        // hide label if no location services
        if (CLLocationManager.authorizationStatus() != .Authorized) {
            self.subtitleLabel.hidden = true
        }
        
        if (self.locationManager.location != nil) {
            var distance = self.station.location.distanceFromLocation(self.locationManager.location)

            var desc = NSMutableAttributedString()
            
            if (distance < 100_000) {
                desc.appendAttributedString(NSAttributedString(string: self.distanceFormatter.stringFromDistance(distance), attributes: [NSForegroundColorAttributeName: UIColor.lightGrayColor()]))
            }
            else {
                desc.appendAttributedString(NSAttributedString(string: NSLocalizedString("far", comment: "title when station is further than 100,000m"), attributes: [NSForegroundColorAttributeName: UIColor.lightGrayColor()]))
            }
            
            self.subtitleLabel.attributedText = desc
            self.subtitleLabel.hidden = false
        }
        else {
            self.subtitleLabel.hidden = true
        }

    }

    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        // hide when no location
        self.subtitleLabel.hidden = true
    }
    
    func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        if (status != .Authorized) {
            self.subtitleLabel.hidden = true
        }
    }
}