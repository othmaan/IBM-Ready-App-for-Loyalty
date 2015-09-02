/*
Licensed Materials - Property of IBM
© Copyright IBM Corporation 2015. All Rights Reserved.
*/

import UIKit

enum SortType: Int {
    case Distance = 0, Price = 1
}

@objc protocol SearchManagerDelegate {
    func newSearchResults(result : [GasStation]) -> Void
}

class SearchManager: NSObject {
    
    
    static let sharedInstance = SearchManager()
    
    var delegates : [SearchManagerDelegate] = []
    
    /**
    This method applies the sorting and filtering
    
    - parameter searchText:        the text to search gas stations against
    - parameter sortIndex:         the selected index of the segmented control in the searchViewController
    - parameter amenityIndexPaths: the amenities selected in the SearchViewController's tableView
    */
    func applySortingandFilters(searchText : String, sortType : SortType, amenityIndexPaths : [NSIndexPath]){
        
        //Collect all the data needed for Sorting and Filtering
        let selectedAmenitiesArray : [String] = determineSelectedAmenities(amenityIndexPaths)
        let gasStationArray = getGasStations()
        
        //Find Gas Stations that have properties that contain the text the user entered
        let searchResultsGasStationArray = searchWithText(searchText, gasStationArray: gasStationArray)
        
        //Sort Gas StationArray by selectedSortIndex
        sortGasStations(sortType, gasStationArray: searchResultsGasStationArray) { (stations: [GasStation]) -> () in
            //Filter Array by selected amenities
            if (stations != []) {
                MILAlertViewManager.sharedInstance.hide() //hide alert if shown
                let filteredArray = self.filterAmenities(stations, amenities: selectedAmenitiesArray)
                
                //tell delegates there are new search results
                self.tellDelegatesThereAreNewSearchResults(filteredArray)
            } else {
                MILAlertViewManager.sharedInstance.show(NSLocalizedString("Network Error", comment: ""), callback: {self.applySortingandFilters(searchText, sortType: sortType, amenityIndexPaths: amenityIndexPaths)})
            }

        }
        
    }
    
    
    /**
    This method sorts the gas Stations based on the selected segmented control index. Either sorting by distance or sorting by gas price
    
    - parameter sortType: either Distance or Price
    - parameter gasStationArray: the gas station array to sort
    
    - returns: returns an array of sorted gas stations
    */
    private func sortGasStations(sortType : SortType, gasStationArray : [GasStation], callback: ([GasStation])->()) {
        if(sortType == SortType.Distance){
            SearchManager.sortGasStationByDistance(gasStationArray, callback: { (stations:[GasStation]) -> () in
                callback(stations)
            })
        }
        else if(sortType == SortType.Price){
            callback(SearchManager.sortGasStationByGasPrice(gasStationArray))
        }
        else{
            callback([])
        }
    }
    
    /**
    Gets the closest gas station ro the user
    
    - parameter gasStations: array of gas stations
    
    - returns: the closest gas station
    */
    class func getClosestGasStation(gasStations: [GasStation], callback: (GasStation?)->()) {
        sortGasStationByDistance(gasStations, callback: { (stations: [GasStation]) -> () in
            if (stations.first != nil) {
                callback(stations.first!)
            } else {
                callback(nil)
            }
            
        })
    }
    
    /**
    Gets the cheapest gas station ro the user
    
    - parameter gasStations: array of gas stations
    
    - returns: the cheapest gas station
    */
    class func getCheapestGasStation(gasStations: [GasStation]) -> GasStation {
        let stations = sortGasStationByGasPrice(gasStations)
        return stations.first!
    }
    
    
    /**
    This method sorts the gas stations by distance.
    
    - parameter gasStationArray: the gas station array to sort
    
    - returns: the sorted gas station array by distance
    */
    private class func sortGasStationByDistance(gasStationArray : [GasStation], callback: ([GasStation])->()) {
        var gasStationDistance = [GasStation: CLLocationDistance]()
        
        var gasStationDistancesFound = 0
        if gasStationArray.isEmpty{
            callback([])
        }
        for (index, station) in gasStationArray.enumerate() {
            LocationUtils.sharedInstance.calcDistanceFromUsersLocation(index, gasStation: station, callback: { (actualIndex : Int, distance: CLLocationDistance?, success) -> () in
                if (success) {
                    
                    gasStationDistance[station] = distance
                    gasStationDistancesFound++
                    
                    if gasStationDistancesFound == gasStationArray.count {
                        
                        let sortedGasStationArray = gasStationArray.sort({ gasStationDistance[$0] < gasStationDistance[$1]})
            
                        callback(sortedGasStationArray)
                    }
                } else { //failure
                    callback([])
                }

            })
        }
    }
    
    
    
    
    /**
    This method sorts gas stations by gas price
    
    - parameter gasStationArray: the gas station array to sort
    
    - returns: the sorted gas station array by price
    */
    private class func sortGasStationByGasPrice(gasStationArray : [GasStation]) -> [GasStation]{
        return gasStationArray.sort({ $0.gasPrice < $1.gasPrice})
    }
    
    /**
    This method gets the gas stations from the app delegates user object
    
    - returns: the gas station array from the app delegates user object
    */
    private  func getGasStations() -> [GasStation]{
        return UserDataManager.sharedInstance.currentUser.gasStations
    }
    
    func resetGasStations() -> [GasStation]{
        return UserDataManager.sharedInstance.currentUser.gasStations
    }
    
    /**
    This method filters the gas stations that have the same amenities that are in the amenities parameter
    
    - parameter gasStationArray: the gas station array to filter gas stations out
    - parameter amenities:       the amenities to filter against gas stations
    
    - returns: a gas station are that has the same amenities that are in the amenities paramenter
    */
    private func filterAmenities(gasStationArray : [GasStation], amenities : [String]) -> [GasStation]{
        
        let filteredArray = gasStationArray.filter() {
            
            let amenitiesArray = $0.amenities
            var include = true
            for amenity in amenities {
                if amenity == "openNow" {
                    let nowHour = NSDate().hour()
                    include = include && nowHour >= $0.hours.open.hour() && nowHour < $0.hours.close.hour()
                }else{
                    include = include && amenitiesArray.contains(amenity)
                }
            }
            return include
        }
        return filteredArray
    }
    
    
    /**
    This method determines what amenities were selected based on the selected index paths from the table view in the SearchViewController
    
    - parameter amenityIndexPaths: the selected index paths from the table view in the SearchViewController
    
    - returns: an array of amenities representing the selected amenities from the table view in the SearchViewController
    */
    private func determineSelectedAmenities(amenityIndexPaths : [NSIndexPath]) -> [String]{
        
        var selectedAmenitiesArray : [String] = []
        var amenitiesArray = Amenities().amenitiesArray
        
        for indexPath in amenityIndexPaths {
            let amenityTableViewCellTitle = amenitiesArray[indexPath.row]
            
            let amenityString = Amenities().amenityStringByTableViewCellTitle[amenityTableViewCellTitle]!
            selectedAmenitiesArray.append(amenityString)
        }
        
        return selectedAmenitiesArray
    }
    
    /**
    This method makes a search based on the text parameter. It searches every gas station's name, address, amenity array, and items array from strings that contain the "text" string parameter. If the property contains the "text" string parameter then it includes that gas station in the returned filtered gas station array
    
    - parameter text: the text to search the gas station properties against
    - parameter gasStationArray: the gas station array to filter
    
    - returns: a filtered gas station array
    */
    func searchWithText(text : String, gasStationArray : [GasStation]) -> [GasStation]{
        var searchResultsArray : [GasStation] = []
        
        if(text.length > 0){
            let lowerCaseText = text.lowercaseString
            
            mainloop: for gasStation in gasStationArray {
                
                if(gasStation.name.lowercaseString.containsString(lowerCaseText)){
                    searchResultsArray.append(gasStation)
                    continue
                }
                
                if(gasStation.address.lowercaseString.containsString(lowerCaseText)){
                    searchResultsArray.append(gasStation)
                    continue
                }
                
                for amenity in gasStation.amenities {
                    
                    //check if the gas station amenities contain the "text" string
                    if(amenity.lowercaseString.containsString(lowerCaseText)){
                        searchResultsArray.append(gasStation)
                        continue mainloop
                    }
                    
                    //just incase -- also try to find the equivalent table view cell title that matches up with the gas station amenity -- to see if it contains the "text" string
                    let keys = (Amenities().amenityStringByTableViewCellTitle as NSDictionary).allKeysForObject(amenity)
                    if(keys.count > 0){
                        let tableViewCellTitle = keys[0] as! String
                        
                        if(tableViewCellTitle.lowercaseString.containsString(lowerCaseText)){
                            searchResultsArray.append(gasStation)
                            continue mainloop
                        }
                    }
                }
                
                for item in gasStation.items{
                    if(item.lowercaseString.containsString(lowerCaseText)){
                        searchResultsArray.append(gasStation)
                        continue mainloop
                    }
                }
            }
        }
        else{
            searchResultsArray = gasStationArray
        }
        
        return searchResultsArray
    }
    
    
    /**
    This method tells the delegates that there are new search results
    
    - parameter result: the sorted and filtered gas station array
    */
    func tellDelegatesThereAreNewSearchResults(result : [GasStation]){
        for delegate in delegates {
            delegate.newSearchResults(result)
        }
    }
    
    
}
