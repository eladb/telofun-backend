//
//  TBSecondViewController.m
//  telobike
//
//  Created by Elad Ben-Israel on 9/23/13.
//  Copyright (c) 2013 Elad Ben-Israel. All rights reserved.
//

@import MapKit;
@import QuartzCore;

#import <SVGeocoder/SVGeocoder.h>

#import "TBStation.h"
#import "TBMapViewController.h"
#import "TBServer.h"
#import "NSObject+Binding.h"
#import "UIColor+Style.h"
#import "NSBundle+View.h"
#import "TBNavigationController.h"
#import "TBDrawerView.h"
#import "KMLParser.h"
#import "TBStationAnnotationView.h"
#import "TBStationActivityViewController.h"
#import "TBAvailabilityView.h"

@interface TBMapViewController () <MKMapViewDelegate>

@property (strong, nonatomic) IBOutlet MKMapView* mapView;
@property (strong, nonatomic) IBOutlet UIToolbar* bottomToolbar;

@property (strong, nonatomic) IBOutlet TBDrawerView* stationDetails;
@property (strong, nonatomic) IBOutlet TBAvailabilityView* stationAvailabilityView;

@property (strong, nonatomic) TBServer* server;
@property (strong, nonatomic) NSMutableDictionary*  markers;
@property (strong, nonatomic) KMLParser* kmlParser;

@property (assign, nonatomic) BOOL regionChangingForSelection;

@end

@interface UIView (FlatSubviews)

- (NSArray*)allSubviewsOfClass:(Class)class;

@end

@implementation UIView (FlatSubviews)

- (NSArray *)allSubviewsOfClass:(Class)class {
    NSMutableArray* all = [[NSMutableArray alloc] init];
    if ([self isKindOfClass:class]) {
        [all addObject:self];
    }
    
    for (UIView* subview in self.subviews) {
        NSArray* subviews = [subview allSubviewsOfClass:class];
        [all addObjectsFromArray:subviews];
    }
    
    return all;
}

@end

@implementation TBMapViewController

#pragma mark - View controller events

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.markers = [[NSMutableDictionary alloc] init];
    self.server = [TBServer instance];
    
    [self observeValueOfKeyPath:@"stations" object:self.server with:^(id new, id old) {
        [self refresh:nil];
        [self reselectAnnotation];
    }];
    
    [self observeValueOfKeyPath:@"city" object:self.server with:^(id new, id old) {
        // if we have a selected station, don't update the region
        if (self.selectedStation || self.selectedPlacemark) {
            return;
        }
        
        MKCoordinateRegion region;
        region.center = self.server.city.cityCenter.coordinate;
        region.span = MKCoordinateSpanMake(0.05, 0.05);
        [self.mapView setRegion:region animated:NO];
    }];
    
    [self loadRoutesFromKML];
  
    // map view
    MKUserTrackingBarButtonItem* trackingBarButtonItem = [[MKUserTrackingBarButtonItem alloc] initWithMapView:self.mapView];
    [self.bottomToolbar setItems:[self.bottomToolbar.items arrayByAddingObject:trackingBarButtonItem]];
    self.mapView.showsUserLocation = YES;
    
    [self reselectAnnotation];
    
//    NSArray* imageViews = [self.stationDetails allSubviewsOfClass:[UIImageView class]];
//    NSLog(@"%@", imageViews);
//    for (UIImageView* imageView in imageViews) {
//        CGRect frame = imageView.frame;
//        frame.size.width = 10.0f;
//        frame.size.height = 10.0f;
//        imageView.contentMode = UIViewContentModeScaleAspectFit;
//        imageView.frame = frame;
//    }
//
//    for (UIView* sv in self.stationDetails.subviews) {
//        if ([sv isKindOfClass:[UIToolbar class]]) {
//            UIToolbar* tb = (UIToolbar*)sv;
//            CGRect f = tb.frame;
//            f.size.height = 10.0f;
//            tb.frame = f;
//        }
//    }

//    self.stationDetails.layer.cornerRadius = 10.0f;
//    self.stationDetails.layer.shadowOpacity = 0.6f;
//    self.stationDetails.layer.shadowColor = [[UIColor blackColor] CGColor];
//    self.stationDetails.layer.shadowOffset = CGSizeMake(0, 10);
//    self.stationDetails.layer.borderColor = [[UIColor colorWithWhite:0.0f alpha:0.3f] CGColor];
//    self.stationDetails.layer.borderWidth = 1.0f;
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[TBServer instance] reloadStations:nil];
}

- (void)reselectAnnotation {
    // make sure selected station/placemark are respected after view load
    if (self.selectedPlacemark) {
        self.selectedPlacemark = self.selectedPlacemark;
    }
    
    if (self.selectedStation) {
        self.selectedStation = self.selectedStation;
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    static BOOL oneOff = YES;
    if (oneOff || !self.selectedStation) {
        [self.stationDetails closeAnimated:NO];
//        [self hideStationDetailsAnimated:NO];
        oneOff = NO;
    }
}

#pragma mark - Annotations

- (void)refresh:(id)sender {
    for (TBStation* station in [TBServer instance].stations) {
        
        // if a marker exists for this station id, reuse it
        TBStation* existingMarker = [self.markers objectForKey:station.sid];
        if (existingMarker) {
            existingMarker.dict = station.dict;
            continue;
        }
        
        // add annotation to map (and dictionary)
        [self.mapView addAnnotation:station];
        [self.markers setObject:station forKey:station.sid];
    }
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    static NSString* stationID = @"station";
    static NSString* placemarkID = @"placemark";
    
    if ([annotation isKindOfClass:[TBPlacemarkAnnotation class]]) {
        MKAnnotationView* view = [mapView dequeueReusableAnnotationViewWithIdentifier:placemarkID];
        if (!view) {
            MKPinAnnotationView* v = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:placemarkID];
            view = v;
            v.pinColor = MKPinAnnotationColorRed;
            v.animatesDrop = YES;
            v.canShowCallout = YES;
        }
        view.annotation = annotation;
        return view;
    }
    
    // only if this is a station annotation
    if ([annotation isKindOfClass:[TBStation class]]) {
        MKAnnotationView* view = [self.mapView dequeueReusableAnnotationViewWithIdentifier:stationID];
        if (!view) {
            view = [[TBStationAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:stationID];
        }
        view.annotation = annotation;
        return view;
    }
    
    return nil;
}


#pragma mark - Selection

- (void)setSelectedStation:(TBStation *)selectedStation {
    self.selectedPlacemark = nil;
    
    // look for annotation based on sid
    for (TBStation* annotation in self.mapView.annotations) {
        if (![annotation isKindOfClass:[TBStation class]]) {
            continue; // skip other annotations
        }
        
        if ([annotation.sid isEqualToString:selectedStation.sid]) {
            selectedStation = annotation;
        }
    }
    
    // deselect any annotations
    for (id annoation in self.mapView.selectedAnnotations) {
        [self.mapView deselectAnnotation:annoation animated:YES];
    }

    // hide details of previous station
    if (_selectedStation) {
        [self.stationDetails closeAnimated:YES];
//        [self hideStationDetailsAnimated:YES];
    }
    
    _selectedStation = selectedStation;
    [self.mapView selectAnnotation:selectedStation animated:YES];
    
}

- (void)updateTitle:(NSString*)title {
    self.navigationItem.title = title ? title : self.title;
}

- (void)mapView:(MKMapView *)mapView didDeselectAnnotationView:(MKAnnotationView *)view {
    [self.stationDetails closeAnimated:YES];
//    [self hideStationDetailsAnimated:YES];
    [self updateTitle:nil];
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view {
    NSString* annotationTitle;
    MKCoordinateRegion annotationRegion;

    if ([view.annotation isKindOfClass:[TBStation class]]) {
        _selectedStation = (TBStation*)view.annotation;

        [self.stationDetails openAnimated:YES];
//        self.stationDetails.station = (TBStation*)view.annotation;
//        [self showStationDetailsAnimated:YES];
        
        MKCoordinateRegion region;
        region.span = MKCoordinateSpanMake(0.004, 0.004);
        region.center = self.selectedStation.coordinate;
        
        annotationRegion = region;
        annotationTitle = self.selectedStation.stationName;
        
        self.stationAvailabilityView.station = _selectedStation;
    }
    
    if ([view.annotation isKindOfClass:[TBPlacemarkAnnotation class]]) {
        TBPlacemarkAnnotation* annoation = view.annotation;
        annotationTitle = annoation.placemark.formattedAddress;;
        annotationRegion = MKCoordinateRegionMakeWithDistance(annoation.coordinate, 1000.0f, 1000.0f);;
    }
    
    [self updateTitle:annotationTitle];
    self.regionChangingForSelection = YES;
    [self.mapView setRegion:annotationRegion animated:YES];
}

- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated {
    if (self.regionChangingForSelection) {
        return; // if region is changing for selection, do nothing
    }

    self.selectedStation = nil; // deselect station if user moves map
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    self.regionChangingForSelection = NO;
}

#pragma mark - Station details

- (IBAction)stationDetailsActionClicked:(id)sender {
    TBStationActivityViewController* vc = [[TBStationActivityViewController alloc] initWithStation:self.selectedStation];
    vc.completionHandler = ^(NSString* activityName, BOOL completed){
        NSLog(@"completed with %@", activityName);
    };
    
    [self presentViewController:vc animated:YES completion:nil];
}

#pragma mark - My location

- (void)mapView:(MKMapView *)mapView didFailToLocateUserWithError:(NSError *)error {
    NSLog(@"ERROR: unable to determine location: %@", error);
}

#pragma mark - Routes

- (void)loadRoutesFromKML {
    NSURL* url = [[NSBundle mainBundle] URLForResource:@"routes" withExtension:@"kml"];
    self.kmlParser = [[KMLParser alloc] initWithURL:url];
    [self.kmlParser parseKML];
    [self.mapView addOverlays:self.kmlParser.overlays];
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {
    return [self.kmlParser rendererForOverlay:overlay];
}

#pragma mark - Placemark search result

- (void)setSelectedPlacemark:(TBPlacemarkAnnotation *)selectedPlacemark {

    if (selectedPlacemark) {
        self.selectedStation = nil;

        // only remove previous placemark if there is a new one to select
        // otherwise, we just want to deselect it.
        [self.mapView removeAnnotation:_selectedPlacemark];
        [self.mapView addAnnotation:selectedPlacemark];
    }
    
    _selectedPlacemark = selectedPlacemark;
    [self.mapView selectAnnotation:selectedPlacemark animated:YES];
}

@end
