//
//  ViewController.m
//  CityPlaces
//
//  Created by Alexey Stafeyev on 11.08.17.
//  Copyright © 2017 Alexey Stafeyev. All rights reserved.
//

#import "ViewController.h"
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>

NSString *const NGNPinReuseIdentifier = @"pinIdentifier";
NSString *const NGNJSONKey = @"data";
NSString *const NGNFileName = @"PublicArt";
NSString *const NGNFileExtension = @"json";

NSString *const NGNAlertTitleInfo = @"Art object info";
NSString *const NGNTitleOk = @"OK";
NSString *const NGNMessageEmptyDetails = @"No details";
NSString *const NGNMessageNoAuthor = @"No author";
NSString *const NGNMessageNoArtworkName = @"Nameless artwork";

// there will be array of arrays after JSON parsing, and these constant numbers no more than numbers of rows in each array
// from raywenderlich.com

static const NSInteger NGNArtworkName = 16;
static const NSInteger NGNArtworkAuthor = 8;

static const NSInteger NGNArtworkType = 15;
static const NSInteger NGNArtworkYearOfCreation = 14;
static const NSInteger NGNArtworkDescription = 11;

static const NSInteger NGNArtworkLatitude = 18; //double
static const NSInteger NGNArtworkLongitude = 19; //double


#pragma mark - inner classes

@interface NGNPlaceAnnotation : NSObject  <MKAnnotation>

@property (copy, nonatomic) NSString *additionalInfo;

- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate
                             title:(NSString *)title
                          subtitle:(NSString *)subtitle
                    additionalInfo:(NSString * _Nullable)additionalInfo;

- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate
                             title:(NSString *)title
                          subtitle:(NSString *)subtitle;

- (void)setTitle:(NSString *)title;
- (void)setSubtitle:(NSString *)title;

@end

@implementation NGNPlaceAnnotation

@synthesize title = _title;
@synthesize subtitle = _subtitle;
@synthesize coordinate = _coordinate;

- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate title:(NSString *)title subtitle:(NSString *)subtitle {
    return [self initWithCoordinate:coordinate title:title subtitle:subtitle additionalInfo:@"no info"];
}

- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate
                             title:(NSString *)title
                          subtitle:(NSString *)subtitle
                    additionalInfo:(NSString *)additionalInfo {
    self = [super init];
    if (self) {
        _coordinate = coordinate;
        _title = title;
        _subtitle = subtitle;
        _additionalInfo = additionalInfo;
    }
    return self;
}

- (void)setTitle:(NSString *)title {
    _title = title;
}

- (void)setSubtitle:(NSString *)subtitle {
    _subtitle = subtitle;
}

@end


#pragma mark - main class

@interface ViewController () <CLLocationManagerDelegate, MKMapViewDelegate>

@property (strong, nonatomic) IBOutlet MKMapView *mapView;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) __block NSMutableArray<NSArray *> *errorLocationsAnnotationsCorteges; //Cortege with location and annotation with geocode error
@property (strong, nonatomic) dispatch_queue_attr_t myAttributes;
@property (strong, nonatomic) dispatch_queue_t myQueue;
@property (strong, nonatomic) dispatch_group_t myGroup;

- (IBAction)styleMapButtonPressed:(UIBarButtonItem *)sender;
- (IBAction)showUserLocation:(UIBarButtonItem *)sender;

#pragma mark - additional hanler methods

- (void)loadMapDataFromJSON;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.myAttributes = dispatch_queue_attr_make_with_qos_class(nil, QOS_CLASS_USER_INITIATED, DISPATCH_QUEUE_PRIORITY_HIGH);
    self.myQueue = dispatch_queue_create("com.noegon.myqueue", self.myAttributes);
    self.myGroup = dispatch_group_create();
    
    self.errorLocationsAnnotationsCorteges = [[NSMutableArray alloc] init];
    
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
    
    UILongPressGestureRecognizer *tapGesture =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressOnMapHandle:)];
    [self.mapView addGestureRecognizer:tapGesture];
    
    self.mapView.delegate = self;
    self.locationManager.delegate = self;
    
    [self loadMapDataFromJSON];
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedWhenInUse) {
        self.mapView.showsUserLocation = YES;
    } else {
        [self.locationManager requestWhenInUseAuthorization];
    }
    [self.locationManager startUpdatingLocation];
}

- (IBAction)styleMapButtonPressed:(UIBarButtonItem *)sender {
    self.mapView.mapType = sender.tag;
}

- (IBAction)showUserLocation:(UIBarButtonItem *)sender {
    [self.mapView setCenterCoordinate:self.mapView.userLocation.location.coordinate animated:YES];
}

- (void)longPressOnMapHandle:(UIGestureRecognizer *)recognizer {
    CGPoint locationPoint = [recognizer locationInView:recognizer.view.superview];
    CLLocationCoordinate2D coordinate = [self.mapView convertPoint:locationPoint toCoordinateFromView:recognizer.view.superview];
    CLLocation *location = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    [geocoder reverseGeocodeLocation:location completionHandler:
     ^(NSArray<CLPlacemark *> * placemarks, NSError *error) {
         CLPlacemark *placemark = placemarks.firstObject;

         NGNPlaceAnnotation *annotation = [[NGNPlaceAnnotation alloc] initWithCoordinate:coordinate
                                                                                   title:placemark.name
                                                                                subtitle:placemark.locality
                                                                          additionalInfo:@"no info"];
         [self.mapView addAnnotation:annotation];
    }];
}

#pragma mark - MKMapViewDelegate

- (void)mapView:(MKMapView *)mapView didFailToLocateUserWithError:(NSError *)error {
    NSLog(@"%@", error.userInfo);
}

- (MKAnnotationView *) mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>) annotation {
    MKPinAnnotationView *currentPinAnnotation =
        [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:NGNPinReuseIdentifier];
    currentPinAnnotation.canShowCallout = YES;
    currentPinAnnotation.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
    return currentPinAnnotation;
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control {
    NSString *message;
    if ([view.annotation isMemberOfClass:[NGNPlaceAnnotation class]]){
        NGNPlaceAnnotation *annotation = view.annotation;
        message = annotation.additionalInfo;
    }
    else {
        message = NGNMessageEmptyDetails;
    }
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NGNAlertTitleInfo
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* ok = [UIAlertAction actionWithTitle:NGNTitleOk style:UIAlertActionStyleDefault handler:nil];
    [alertController addAction:ok];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view {
    ((MKPinAnnotationView *)view).pinTintColor = [UIColor greenColor];
}

- (void)mapView:(MKMapView *)mapView didDeselectAnnotationView:(MKAnnotationView *)view {
    ((MKPinAnnotationView *)view).pinTintColor = [UIColor redColor];
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation {
    NSLog(@"OldLocation %f %f", oldLocation.coordinate.latitude, oldLocation.coordinate.longitude);
    NSLog(@"NewLocation %f %f", newLocation.coordinate.latitude, newLocation.coordinate.longitude);
}

#pragma mark - additional hanler methods

- (void)loadMapDataFromJSON {
    dispatch_queue_attr_t myAttributes = dispatch_queue_attr_make_with_qos_class(nil, QOS_CLASS_USER_INITIATED, DISPATCH_QUEUE_PRIORITY_HIGH);
    dispatch_queue_t myQueue = dispatch_queue_create("com.noegon.myqueue", myAttributes);
    dispatch_group_t myGroup = dispatch_group_create();
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSString *filePath = [[NSBundle mainBundle] pathForResource:NGNFileName ofType:NGNFileExtension];
        NSData *data = [NSData dataWithContentsOfFile:filePath];
        NSDictionary *parsedJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSArray *artObjectsInfo = parsedJSON[NGNJSONKey];
        
        for (NSArray *artObject in artObjectsInfo) {
            __block NGNPlaceAnnotation *annotation = nil;
            __block NSError *annotationError = nil;

            CLLocationCoordinate2D coordinate =
                CLLocationCoordinate2DMake([artObject[NGNArtworkLatitude] doubleValue],
                                           [artObject[NGNArtworkLongitude] doubleValue]);
            
            CLLocation *location = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
            
            CLGeocoder *geocoder = [[CLGeocoder alloc] init];

            dispatch_group_enter(myGroup);
                        [geocoder reverseGeocodeLocation:location completionHandler:
             ^(NSArray<CLPlacemark *> * placemarks, NSError *error) {
                 dispatch_group_async(myGroup, myQueue, ^{
                     
                         CLPlacemark *placemark = [placemarks objectAtIndex:0];
                         
                         NSString *title = [NSString stringWithFormat:@"%@",
                                            (![artObject[NGNArtworkName] isEqual:[NSNull null]] ?
                                             artObject[NGNArtworkName] :
                                             NGNMessageNoArtworkName)];
                         
                         NSString *subtitle = [NSString stringWithFormat:@"%@ - %@", placemark.locality, placemark.name];
                         
                         NSString *additionalInfo = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n%@",
                                                     artObject[NGNArtworkName],
                                                     artObject[NGNArtworkAuthor],
                                                     artObject[NGNArtworkType],
                                                     artObject[NGNArtworkYearOfCreation],
                                                     artObject[NGNArtworkDescription]];
                         
                         annotation = [[NGNPlaceAnnotation alloc] initWithCoordinate:coordinate
                                                                               title:title
                                                                            subtitle:subtitle
                                                                      additionalInfo:additionalInfo];
                     
                     if (error.code == 2) {
                         dispatch_barrier_async(myQueue, ^{
                             [self.errorLocationsAnnotationsCorteges addObject:@[location, annotation]];
                             annotationError = error;
                         });
                     }
                     dispatch_group_leave(myGroup);
                 });
             }];
            
            dispatch_wait(myGroup, DISPATCH_TIME_FOREVER);
            
            dispatch_group_enter(myGroup);
            dispatch_group_async(myGroup, dispatch_get_main_queue(), ^{
                if (!annotationError) {
                    [self.mapView addAnnotation:annotation];
                }
                dispatch_group_leave(myGroup);
            });
            
            dispatch_wait(myGroup, DISPATCH_TIME_FOREVER);
        }
        
        NSLog(@"%ld", self.errorLocationsAnnotationsCorteges.count);
        
        while (self.errorLocationsAnnotationsCorteges.count > 0) {
            sleep(5);
            [self loadErrorsHandlingWithLocations:self.errorLocationsAnnotationsCorteges];
            NSLog(@"errors: %ld", self.errorLocationsAnnotationsCorteges.count);
        }
    });
}

- (void)loadErrorsHandlingWithLocations:(NSMutableArray <NSArray *> *)locationsAnnotationsCorteges {
    NSMutableArray *resultErrorLocationsAnnotationsCorteges = [locationsAnnotationsCorteges mutableCopy];
    
    dispatch_queue_attr_t myAttributes = dispatch_queue_attr_make_with_qos_class(nil, QOS_CLASS_USER_INITIATED, DISPATCH_QUEUE_PRIORITY_HIGH);
    dispatch_queue_t myQueue = dispatch_queue_create("com.noegon.myqueue", myAttributes);
    dispatch_group_t myGroup = dispatch_group_create();
    
    for (NSArray *locationsAnnotationsCortrge in locationsAnnotationsCorteges) {
        __block NSError *annotationError = nil;
        
        CLGeocoder *geocoder = [[CLGeocoder alloc] init];
        
        dispatch_group_enter(myGroup);
        [geocoder reverseGeocodeLocation:locationsAnnotationsCortrge[0] completionHandler:
         ^(NSArray<CLPlacemark *> * placemarks, NSError *error) {
             dispatch_group_async(myGroup, myQueue, ^{
                 if (!error) {
                     CLPlacemark *placemark = [placemarks objectAtIndex:0];
                     
                     NGNPlaceAnnotation *annotation = locationsAnnotationsCortrge[1];
                     annotation.subtitle = [NSString stringWithFormat:@"%@ - %@", placemark.locality, placemark.name];
                     
                 } else {
                     annotationError = error;
                 }
                 dispatch_group_leave(myGroup);
             });
         }];
        
        dispatch_wait(myGroup, DISPATCH_TIME_FOREVER);
        
        dispatch_group_enter(myGroup);
        dispatch_group_async(myGroup, dispatch_get_main_queue(), ^{
            if (!annotationError) {
                [self.mapView addAnnotation:locationsAnnotationsCortrge[1]];
                [resultErrorLocationsAnnotationsCorteges removeObject:locationsAnnotationsCortrge];
            }
            dispatch_group_leave(myGroup);
        });
        
        dispatch_wait(myGroup, DISPATCH_TIME_FOREVER);
    }
    
    self.errorLocationsAnnotationsCorteges = resultErrorLocationsAnnotationsCorteges;
}

@end
